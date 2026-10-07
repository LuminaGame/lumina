import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/components/base/actor_component.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/ai/ai_controller.dart';
import 'package:lumina/src/ai/blackboard.dart';

/// Execution status result returned by behavior tree nodes.
enum BTNodeResult {
  succeeded,
  failed,
  inProgress,
  aborted,
}

/// Flow abort mode defining how decorator conditions interrupt active branches.
enum BTFlowAbortMode {
  none,
  self,
  lowerPriority,
}

/// Runtime context passed through behavior tree node ticks.
class BTContext {
  final LuminaBlackboard blackboard;
  final LuminaAIController? controller;
  final LuminaActor? ownerActor;
  double dt;

  BTContext({
    required this.blackboard,
    this.controller,
    this.ownerActor,
    this.dt = 0.0,
  });
}

/// Abstract base class for all Behavior Tree nodes (composites, decorators, and tasks).
abstract class BTNode {
  BTNodeResult tick(BTContext ctx, double dt);
  void abort(BTContext ctx) {}
}

/// Composite node that executes children in sequence until one succeeds or remains in progress.
class BTSelector extends BTNode {
  final List<BTNode> children;
  int _runningIndex = 0;

  BTSelector(this.children);

  @override
  BTNodeResult tick(BTContext ctx, double dt) {
    if (children.isEmpty) return BTNodeResult.failed;

    // Check for higher priority aborts among decorators
    for (int i = 0; i < _runningIndex; i++) {
      final child = children[i];
      if (child is BTDecorator && child.observeAborts == BTFlowAbortMode.lowerPriority) {
        if (child.evaluateCondition(ctx)) {
          // Abort current running branch and switch to higher priority child
          children[_runningIndex].abort(ctx);
          _runningIndex = i;
          break;
        }
      }
    }

    for (int i = _runningIndex; i < children.length; i++) {
      final result = children[i].tick(ctx, dt);
      if (result == BTNodeResult.inProgress) {
        _runningIndex = i;
        return BTNodeResult.inProgress;
      }
      if (result == BTNodeResult.succeeded) {
        _runningIndex = 0;
        return BTNodeResult.succeeded;
      }
    }

    _runningIndex = 0;
    return BTNodeResult.failed;
  }

  @override
  void abort(BTContext ctx) {
    if (children.isNotEmpty && _runningIndex < children.length) {
      children[_runningIndex].abort(ctx);
    }
    _runningIndex = 0;
  }
}

/// Composite node that executes children in sequence until one fails or remains in progress.
class BTSequence extends BTNode {
  final List<BTNode> children;
  int _runningIndex = 0;

  BTSequence(this.children);

  @override
  BTNodeResult tick(BTContext ctx, double dt) {
    if (children.isEmpty) return BTNodeResult.failed;

    for (int i = _runningIndex; i < children.length; i++) {
      final result = children[i].tick(ctx, dt);
      if (result == BTNodeResult.inProgress) {
        _runningIndex = i;
        return BTNodeResult.inProgress;
      }
      if (result == BTNodeResult.failed || result == BTNodeResult.aborted) {
        _runningIndex = 0;
        return result;
      }
    }

    _runningIndex = 0;
    return BTNodeResult.succeeded;
  }

  @override
  void abort(BTContext ctx) {
    if (children.isNotEmpty && _runningIndex < children.length) {
      children[_runningIndex].abort(ctx);
    }
    _runningIndex = 0;
  }
}

/// Composite node executing a primary task alongside a background subtree.
class BTSimpleParallel extends BTNode {
  final BTNode primary;
  final BTNode background;

  BTSimpleParallel({required this.primary, required this.background});

  @override
  BTNodeResult tick(BTContext ctx, double dt) {
    final primaryResult = primary.tick(ctx, dt);
    if (primaryResult == BTNodeResult.inProgress) {
      background.tick(ctx, dt);
      return BTNodeResult.inProgress;
    }

    background.abort(ctx);
    return primaryResult;
  }

  @override
  void abort(BTContext ctx) {
    primary.abort(ctx);
    background.abort(ctx);
  }
}

/// Base class for decorator nodes that wrap and conditionally control child execution.
abstract class BTDecorator extends BTNode {
  final BTNode child;
  final BTFlowAbortMode observeAborts;

  BTDecorator({required this.child, this.observeAborts = BTFlowAbortMode.none});

  bool evaluateCondition(BTContext ctx);

  @override
  BTNodeResult tick(BTContext ctx, double dt) {
    if (!evaluateCondition(ctx)) {
      return BTNodeResult.failed;
    }
    return child.tick(ctx, dt);
  }

  @override
  void abort(BTContext ctx) {
    child.abort(ctx);
  }
}

/// Decorator evaluating a blackboard condition before executing its child.
class BTBlackboardDecorator extends BTDecorator {
  final String key;
  final bool? isSet;
  final dynamic equals;

  BTBlackboardDecorator(
    this.key, {
    required super.child,
    this.isSet,
    this.equals,
    super.observeAborts = BTFlowAbortMode.none,
  });

  @override
  bool evaluateCondition(BTContext ctx) {
    if (isSet != null) {
      final exists = ctx.blackboard.hasValue(key);
      final val = ctx.blackboard.getValue<dynamic>(key);
      final boolSet = exists && val != null && val != false;
      return boolSet == isSet;
    }
    if (equals != null) {
      final val = ctx.blackboard.getValue<dynamic>(key);
      return val == equals;
    }
    return ctx.blackboard.hasValue(key);
  }
}

/// Decorator enforcing a cooldown duration after successful child completion.
class BTCooldownDecorator extends BTDecorator {
  final double cooldownSeconds;
  double _timeSinceLastSuccess = double.infinity;
  bool _coolingDown = false;

  BTCooldownDecorator(this.cooldownSeconds, {required super.child});

  @override
  bool evaluateCondition(BTContext ctx) => !_coolingDown;

  @override
  BTNodeResult tick(BTContext ctx, double dt) {
    if (_coolingDown) {
      _timeSinceLastSuccess += dt;
      if (_timeSinceLastSuccess >= cooldownSeconds) {
        _coolingDown = false;
      } else {
        return BTNodeResult.failed;
      }
    }

    final res = child.tick(ctx, dt);
    if (res == BTNodeResult.succeeded) {
      _coolingDown = true;
      _timeSinceLastSuccess = 0.0;
    }
    return res;
  }
}

/// Decorator looping child execution [count] times.
class BTLoopDecorator extends BTDecorator {
  final int count;
  int _currentIteration = 0;

  BTLoopDecorator(this.count, {required super.child});

  @override
  bool evaluateCondition(BTContext ctx) => true;

  @override
  BTNodeResult tick(BTContext ctx, double dt) {
    if (count <= 0) return BTNodeResult.succeeded;

    while (_currentIteration < count) {
      final res = child.tick(ctx, dt);
      if (res == BTNodeResult.inProgress) return BTNodeResult.inProgress;
      if (res == BTNodeResult.failed) {
        _currentIteration = 0;
        return BTNodeResult.failed;
      }
      _currentIteration++;
    }

    _currentIteration = 0;
    return BTNodeResult.succeeded;
  }

  @override
  void abort(BTContext ctx) {
    _currentIteration = 0;
    super.abort(ctx);
  }
}

/// Decorator inverting success into failure and vice versa.
class BTInverterDecorator extends BTDecorator {
  BTInverterDecorator({required super.child});

  @override
  bool evaluateCondition(BTContext ctx) => true;

  @override
  BTNodeResult tick(BTContext ctx, double dt) {
    final res = child.tick(ctx, dt);
    if (res == BTNodeResult.succeeded) return BTNodeResult.failed;
    if (res == BTNodeResult.failed) return BTNodeResult.succeeded;
    return res;
  }
}

/// Leaf task waiting for a fixed duration of simulation time.
class BTWaitTask extends BTNode {
  final double seconds;
  final double randomDeviation;
  double _elapsed = 0.0;
  double _targetDuration = 0.0;
  bool _started = false;

  BTWaitTask(this.seconds, {this.randomDeviation = 0.0});

  @override
  BTNodeResult tick(BTContext ctx, double dt) {
    if (!_started) {
      _started = true;
      _elapsed = 0.0;
      _targetDuration = seconds;
      if (randomDeviation > 0.0) {
        final rand = math.Random().nextDouble() * 2.0 - 1.0;
        _targetDuration = math.max(0.0, seconds + rand * randomDeviation);
      }
    }

    _elapsed += dt;
    if (_elapsed >= _targetDuration) {
      _started = false;
      _elapsed = 0.0;
      return BTNodeResult.succeeded;
    }
    return BTNodeResult.inProgress;
  }

  @override
  void abort(BTContext ctx) {
    _started = false;
    _elapsed = 0.0;
  }
}

/// Leaf task commanding an AIController to move to a destination location or actor from blackboard.
class BTMoveToTask extends BTNode {
  final String blackboardKey;
  final double acceptanceRadius;
  bool _issued = false;
  PathFollowingResult? _result;

  BTMoveToTask({
    this.blackboardKey = 'targetLocation',
    this.acceptanceRadius = 50.0,
  });

  @override
  BTNodeResult tick(BTContext ctx, double dt) {
    final controller = ctx.controller;
    if (controller == null) return BTNodeResult.failed;

    if (!_issued) {
      _issued = true;
      _result = null;

      controller.onMoveCompleted = (res) {
        _result = res;
      };

      final target = ctx.blackboard.getValue<dynamic>(blackboardKey);
      if (target is Vector3) {
        final req = controller.moveToLocation(target, acceptanceRadius: acceptanceRadius);
        if (req == PathFollowingRequestResult.alreadyAtGoal) {
          _issued = false;
          return BTNodeResult.succeeded;
        } else if (req == PathFollowingRequestResult.failed) {
          _issued = false;
          return BTNodeResult.failed;
        }
      } else if (target is LuminaActor) {
        final req = controller.moveToActor(target, acceptanceRadius: acceptanceRadius);
        if (req == PathFollowingRequestResult.alreadyAtGoal) {
          _issued = false;
          return BTNodeResult.succeeded;
        } else if (req == PathFollowingRequestResult.failed) {
          _issued = false;
          return BTNodeResult.failed;
        }
      } else {
        _issued = false;
        return BTNodeResult.failed;
      }
    }

    if (_result != null) {
      final finalRes = _result!;
      _issued = false;
      _result = null;
      return finalRes == PathFollowingResult.success ? BTNodeResult.succeeded : BTNodeResult.failed;
    }

    return BTNodeResult.inProgress;
  }

  @override
  void abort(BTContext ctx) {
    if (_issued) {
      ctx.controller?.stopMovement();
      _issued = false;
      _result = null;
    }
  }
}

/// Custom leaf task delegating execution to closure callbacks.
class BTCallbackTask extends BTNode {
  final BTNodeResult Function(BTContext ctx) onTickCallback;
  final void Function(BTContext ctx)? onAbortCallback;

  BTCallbackTask(this.onTickCallback, {void Function(BTContext ctx)? onAbort})
      : onAbortCallback = onAbort;

  @override
  BTNodeResult tick(BTContext ctx, double dt) => onTickCallback(ctx);

  @override
  void abort(BTContext ctx) => onAbortCallback?.call(ctx);
}

/// Actor component managing and ticking an active Behavior Tree.
class LuminaBehaviorTreeComponent extends LuminaActorComponent {
  final BTNode root;
  final LuminaBlackboard blackboard;
  LuminaAIController? controller;
  final double tickInterval;

  bool _isRunning = false;
  double _timeSinceLastTick = 0.0;

  LuminaBehaviorTreeComponent({
    required this.root,
    required this.blackboard,
    this.controller,
    this.tickInterval = 0.0,
  });

  bool get isRunning => _isRunning;

  void start() {
    _isRunning = true;
    _timeSinceLastTick = 0.0;
  }

  void stop() {
    if (_isRunning) {
      final ctx = BTContext(
        blackboard: blackboard,
        controller: controller,
        ownerActor: owner,
      );
      root.abort(ctx);
      _isRunning = false;
    }
  }

  void restart() {
    stop();
    start();
  }

  @override
  void onTick(double deltaTime) {
    if (!_isRunning) return;

    if (tickInterval > 0.0) {
      _timeSinceLastTick += deltaTime;
      if (_timeSinceLastTick < tickInterval) return;
      _timeSinceLastTick = 0.0;
    }

    final ctx = BTContext(
      blackboard: blackboard,
      controller: controller,
      ownerActor: owner,
      dt: deltaTime,
    );

    root.tick(ctx, deltaTime);
  }
}
