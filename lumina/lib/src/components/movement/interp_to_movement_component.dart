import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import '../../object/actor.dart';
import '../base/actor_component.dart';

/// Traversal behavior modes when reaching the end of the interpolation control polyline.
enum InterpToBehaviourType {
  oneShot,
  oneShotReverse,
  loopReset,
  pingPong,
}

/// Control point definition along an interpolation movement path.
class InterpControlPoint {
  final Vector3 position;
  final bool positionIsRelative;

  const InterpControlPoint(this.position, {this.positionIsRelative = true});
}

/// Actor component that moves an actor along an arc-length parameterized list of control points.
class LuminaInterpToMovementComponent extends LuminaActorComponent {
  double duration;
  InterpToBehaviourType behaviourType;
  final List<InterpControlPoint> controlPoints;

  void Function(int pointIndex, Vector3 position)? onWaypointReached;
  void Function()? onInterpToStop;

  double _progress = 0.0;
  double _direction = 1.0;
  bool _isPaused = false;
  bool _isStopped = false;

  final List<Vector3> _resolvedPoints = [];
  final List<double> _segmentLengths = [];
  final List<double> _accumulatedDistances = [];
  double _totalLength = 0.0;

  LuminaInterpToMovementComponent({
    this.duration = 1.0,
    this.behaviourType = InterpToBehaviourType.oneShot,
    this.controlPoints = const [],
  });

  double get progress => _progress;
  bool get isPaused => _isPaused;
  bool get isStopped => _isStopped;

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
  }

  void stopMovement() {
    if (!_isStopped) {
      _isStopped = true;
      onInterpToStop?.call();
    }
  }

  void restartMovement({double initialDirection = 1.0}) {
    _isStopped = false;
    _isPaused = false;
    _direction = initialDirection;
    if (behaviourType == InterpToBehaviourType.oneShotReverse || initialDirection < 0.0) {
      _progress = 1.0;
    } else {
      _progress = 0.0;
    }
    if (owner != null && _resolvedPoints.isNotEmpty) {
      owner!.actorLocation = _evaluatePosition(_progress);
    }
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _resolvedPoints.clear();
    _segmentLengths.clear();
    _accumulatedDistances.clear();
    _totalLength = 0.0;

    if (controlPoints.length < 2) return;

    final baseOrigin = owner?.actorLocation ?? Vector3.zero();
    for (final cp in controlPoints) {
      if (cp.positionIsRelative) {
        _resolvedPoints.add(baseOrigin + cp.position);
      } else {
        _resolvedPoints.add(cp.position.clone());
      }
    }

    _accumulatedDistances.add(0.0);
    for (int i = 0; i < _resolvedPoints.length - 1; i++) {
      final segLen = (_resolvedPoints[i + 1] - _resolvedPoints[i]).length;
      _segmentLengths.add(segLen);
      _totalLength += segLen;
      _accumulatedDistances.add(_totalLength);
    }

    if (behaviourType == InterpToBehaviourType.oneShotReverse) {
      _progress = 1.0;
      _direction = -1.0;
    } else {
      _progress = 0.0;
      _direction = 1.0;
    }

    if (owner != null) {
      owner!.actorLocation = _evaluatePosition(_progress);
    }
  }

  @override
  void onTick(double deltaTime) {
    if (_isStopped || _isPaused || owner == null || deltaTime <= 0.0 || duration <= 0.0 || _resolvedPoints.length < 2) {
      return;
    }

    final oldProgress = _progress;
    _progress += (_direction * deltaTime) / duration;

    // Check intermediate waypoints
    _checkWaypoints(oldProgress, _progress);

    // Handle end-of-path modes
    if (behaviourType == InterpToBehaviourType.oneShot) {
      if (_progress >= 1.0) {
        _progress = 1.0;
        _isStopped = true;
        owner!.actorLocation = _evaluatePosition(1.0);
        onInterpToStop?.call();
        return;
      }
    } else if (behaviourType == InterpToBehaviourType.oneShotReverse) {
      if (_progress <= 0.0) {
        _progress = 0.0;
        _isStopped = true;
        owner!.actorLocation = _evaluatePosition(0.0);
        onInterpToStop?.call();
        return;
      }
    } else if (behaviourType == InterpToBehaviourType.loopReset) {
      if (_progress >= 1.0) {
        _progress = _progress % 1.0;
        onWaypointReached?.call(0, _resolvedPoints.first);
      }
    } else if (behaviourType == InterpToBehaviourType.pingPong) {
      if (_progress >= 1.0) {
        _progress = (2.0 - _progress).clamp(0.0, 1.0);
        _direction = -1.0;
        onWaypointReached?.call(_resolvedPoints.length - 1, _resolvedPoints.last);
      } else if (_progress <= 0.0) {
        _progress = (-_progress).clamp(0.0, 1.0);
        _direction = 1.0;
        onWaypointReached?.call(0, _resolvedPoints.first);
      }
    }

    owner!.actorLocation = _evaluatePosition(_progress.clamp(0.0, 1.0));
  }

  void _checkWaypoints(double oldProg, double newProg) {
    if (_totalLength <= 1e-9) return;
    final minP = math.min(oldProg, newProg);
    final maxP = math.max(oldProg, newProg);

    for (int i = 0; i < _resolvedPoints.length; i++) {
      final wpNorm = _accumulatedDistances[i] / _totalLength;
      if (wpNorm > minP && wpNorm <= maxP) {
        onWaypointReached?.call(i, _resolvedPoints[i]);
      }
    }
  }

  Vector3 _evaluatePosition(double normProgress) {
    if (_resolvedPoints.isEmpty) return Vector3.zero();
    if (_resolvedPoints.length == 1 || _totalLength <= 1e-9) return _resolvedPoints.first;

    final targetDist = normProgress.clamp(0.0, 1.0) * _totalLength;

    for (int i = 0; i < _segmentLengths.length; i++) {
      final segStart = _accumulatedDistances[i];
      final segEnd = _accumulatedDistances[i + 1];
      final segLen = _segmentLengths[i];

      if (targetDist <= segEnd || i == _segmentLengths.length - 1) {
        if (segLen <= 1e-9) return _resolvedPoints[i];
        final factor = ((targetDist - segStart) / segLen).clamp(0.0, 1.0);
        final p0 = _resolvedPoints[i];
        final p1 = _resolvedPoints[i + 1];
        return p0 + (p1 - p0) * factor;
      }
    }

    return _resolvedPoints.last;
  }
}
