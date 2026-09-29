import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaBlackboard Tests', () {
    test('setValue, getValue with type safety, and observer notification', () {
      final bb = LuminaBlackboard();
      bb.setValue<int>('hp', 50);

      expect(bb.getValue<int>('hp'), equals(50));
      expect(bb.getValue<String>('hp'), isNull); // Type mismatch returns null

      int notificationCount = 0;
      final unsubscribe = bb.addObserver('hp', (key) {
        notificationCount++;
      });

      bb.setValue<int>('hp', 40);
      expect(notificationCount, equals(1));

      // Same value should NOT trigger notification
      bb.setValue<int>('hp', 40);
      expect(notificationCount, equals(1));

      // Unsubscribe stops further notifications
      unsubscribe();
      bb.setValue<int>('hp', 30);
      expect(notificationCount, equals(1));
    });

    test('clearValue removes key and triggers observer', () {
      final bb = LuminaBlackboard();
      bb.setValue('speed', 10.0);
      expect(bb.hasValue('speed'), isTrue);

      bool clearedObserved = false;
      bb.addObserver('speed', (_) => clearedObserved = true);

      bb.clearValue('speed');
      expect(bb.hasValue('speed'), isFalse);
      expect(bb.getValue<double>('speed'), isNull);
      expect(clearedObserved, isTrue);
    });
  });

  group('BehaviorTree Tests', () {
    test('BTSelector stops at first succeeded child and does not tick remaining children', () {
      int tick1 = 0, tick2 = 0, tick3 = 0;
      final selector = BTSelector([
        BTCallbackTask((ctx) {
          tick1++;
          return BTNodeResult.failed;
        }),
        BTCallbackTask((ctx) {
          tick2++;
          return BTNodeResult.succeeded;
        }),
        BTCallbackTask((ctx) {
          tick3++;
          return BTNodeResult.succeeded;
        }),
      ]);

      final ctx = BTContext(blackboard: LuminaBlackboard(), dt: 0.016);
      final res = selector.tick(ctx, 0.016);

      expect(res, equals(BTNodeResult.succeeded));
      expect(tick1, equals(1));
      expect(tick2, equals(1));
      expect(tick3, equals(0));
    });

    test('BTSequence ticks children until first failure', () {
      int tick1 = 0, tick2 = 0, tick3 = 0;
      final sequence = BTSequence([
        BTCallbackTask((ctx) {
          tick1++;
          return BTNodeResult.succeeded;
        }),
        BTCallbackTask((ctx) {
          tick2++;
          return BTNodeResult.succeeded;
        }),
        BTCallbackTask((ctx) {
          tick3++;
          return BTNodeResult.failed;
        }),
      ]);

      final ctx = BTContext(blackboard: LuminaBlackboard(), dt: 0.016);
      final res = sequence.tick(ctx, 0.016);

      expect(res, equals(BTNodeResult.failed));
      expect(tick1, equals(1));
      expect(tick2, equals(1));
      expect(tick3, equals(1));
    });

    test('Latent resume in BTSequence with BTWaitTask', () {
      int counter = 0;
      final sequence = BTSequence([
        BTWaitTask(0.05),
        BTCallbackTask((ctx) {
          counter++;
          return BTNodeResult.succeeded;
        }),
      ]);

      final ctx = BTContext(blackboard: LuminaBlackboard(), dt: 0.016);

      // Ticks 1, 2, 3: wait is inProgress, counter not ticked
      for (int i = 0; i < 3; i++) {
        final res = sequence.tick(ctx, 0.016); // 0.016, 0.032, 0.048 < 0.05
        expect(res, equals(BTNodeResult.inProgress));
        expect(counter, equals(0));
      }

      // Tick 4: wait finishes (0.064 >= 0.05), sequence advances and runs counter
      final res4 = sequence.tick(ctx, 0.016);
      expect(res4, equals(BTNodeResult.succeeded));
      expect(counter, equals(1));
    });

    test('BTBlackboardDecorator with lowerPriority abort mode interrupts running branch', () {
      final bb = LuminaBlackboard();
      int branch0Tick = 0;
      int branch1Tick = 0;
      bool branch1Aborted = false;

      final branch0 = BTBlackboardDecorator(
        'hasTarget',
        isSet: true,
        observeAborts: BTFlowAbortMode.lowerPriority,
        child: BTCallbackTask((ctx) {
          branch0Tick++;
          return BTNodeResult.succeeded;
        }),
      );

      final branch1 = BTCallbackTask(
        (ctx) {
          branch1Tick++;
          return BTNodeResult.inProgress;
        },
        onAbort: (ctx) {
          branch1Aborted = true;
        },
      );

      final root = BTSelector([branch0, branch1]);
      final btc = LuminaBehaviorTreeComponent(root: root, blackboard: bb);
      btc.start();

      // Tick 1: hasTarget is not set -> branch 0 condition false -> branch 1 runs (inProgress)
      btc.onTick(0.016);
      expect(branch0Tick, equals(0));
      expect(branch1Tick, equals(1));
      expect(branch1Aborted, isFalse);

      // Set hasTarget on blackboard
      bb.setValue('hasTarget', true);

      // Tick 2: lowerPriority decorator detects condition change -> aborts branch 1 and executes branch 0
      btc.onTick(0.016);
      expect(branch1Aborted, isTrue);
      expect(branch0Tick, equals(1));
    });

    test('BTMoveToTask issues moveToLocation on controller and tracks completion', () {
      final pawn = LuminaPawn(location: Vector3.zero());
      final ai = LuminaAIController();
      ai.possess(pawn);

      final bb = LuminaBlackboard();
      bb.setValue('targetLocation', Vector3(500.0, 0.0, 0.0)); // 5 m in cm

      final moveTask = BTMoveToTask(blackboardKey: 'targetLocation');
      final ctx = BTContext(blackboard: bb, controller: ai, dt: 0.016);

      final res1 = moveTask.tick(ctx, 0.016);
      expect(res1, equals(BTNodeResult.inProgress));
      expect(ai.moveStatus, equals(PathFollowingStatus.moving));

      // Invoke onMoveCompleted manually on controller
      ai.onMoveCompleted?.call(PathFollowingResult.success);

      final res2 = moveTask.tick(ctx, 0.016);
      expect(res2, equals(BTNodeResult.succeeded));
    });

    test('BTCooldownDecorator prevents execution until cooldown expires', () {
      int execCount = 0;
      final child = BTCallbackTask((ctx) {
        execCount++;
        return BTNodeResult.succeeded;
      });
      final cd = BTCooldownDecorator(1.0, child: child);
      final ctx = BTContext(blackboard: LuminaBlackboard(), dt: 0.016);

      // 1. Initial tick succeeds
      expect(cd.tick(ctx, 0.016), equals(BTNodeResult.succeeded));
      expect(execCount, equals(1));

      // 2. Next ticks during cooldown fail
      expect(cd.tick(ctx, 0.4), equals(BTNodeResult.failed));
      expect(execCount, equals(1));
      expect(cd.tick(ctx, 0.4), equals(BTNodeResult.failed)); // total 0.8s < 1.0s
      expect(execCount, equals(1));

      // 3. Tick after accumulated >= 1.0s succeeds again
      expect(cd.tick(ctx, 0.3), equals(BTNodeResult.succeeded)); // total 1.1s >= 1.0s
      expect(execCount, equals(2));
    });

    test('LuminaBehaviorTreeComponent loop and tickInterval throttling', () {
      int tickCount = 0;
      final root = BTCallbackTask((ctx) {
        tickCount++;
        return BTNodeResult.succeeded;
      });

      final bb = LuminaBlackboard();
      final btc = LuminaBehaviorTreeComponent(root: root, blackboard: bb, tickInterval: 0.1);
      btc.start();

      // dt = 0.016. Should only tick after 0.1s accumulated (every ~7 frames)
      for (int i = 0; i < 6; i++) {
        btc.onTick(0.016);
      }
      expect(tickCount, equals(0));

      btc.onTick(0.016); // 7 * 0.016 = 0.112 >= 0.1
      expect(tickCount, equals(1));

      for (int i = 0; i < 6; i++) {
        btc.onTick(0.016);
      }
      expect(tickCount, equals(1));

      btc.onTick(0.016);
      expect(tickCount, equals(2));
    });

    test('BTSimpleParallel ticks background while primary in progress and aborts background when primary completes', () {
      int bgTicks = 0;
      bool bgAborted = false;

      final parallel = BTSimpleParallel(
        primary: BTWaitTask(0.032),
        background: BTCallbackTask(
          (ctx) {
            bgTicks++;
            return BTNodeResult.inProgress;
          },
          onAbort: (ctx) {
            bgAborted = true;
          },
        ),
      );

      final ctx = BTContext(blackboard: LuminaBlackboard(), dt: 0.016);

      expect(parallel.tick(ctx, 0.016), equals(BTNodeResult.inProgress));
      expect(bgTicks, equals(1));
      expect(bgAborted, isFalse);

      expect(parallel.tick(ctx, 0.02), equals(BTNodeResult.succeeded));
      expect(bgAborted, isTrue);
    });
  });
}
