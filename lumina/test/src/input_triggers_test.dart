import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('Input Triggers Tests (Input Task 03)', () {
    test('Pressed trigger: keydown then 3 ticks held fires triggered exactly once on first tick; release and re-press fires once more', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final fireAction = LuminaInputAction('Fire');

      context.mapKey(
        LuminaKey.keySpace,
        fireAction,
        triggers: [LuminaPressedTrigger()],
      );

      subsystem.addMappingContext(context);
      final comp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(comp);

      int triggeredCount = 0;
      comp.bindAction(fireAction, TriggerState.triggered, (_) => triggeredCount++);

      // Press and hold for 3 ticks
      subsystem.injectKeyDown(LuminaKey.keySpace);
      subsystem.tick(1.0 / 60.0);
      expect(triggeredCount, equals(1));

      subsystem.tick(1.0 / 60.0);
      subsystem.tick(1.0 / 60.0);
      expect(triggeredCount, equals(1));

      // Release
      subsystem.injectKeyUp(LuminaKey.keySpace);
      subsystem.tick(1.0 / 60.0);
      expect(triggeredCount, equals(1));

      // Press again
      subsystem.injectKeyDown(LuminaKey.keySpace);
      subsystem.tick(1.0 / 60.0);
      expect(triggeredCount, equals(2));
    });

    test('Released trigger: keydown + 2 ticks produces 0 triggered, keyup tick produces exactly 1', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final reloadAction = LuminaInputAction('Reload');

      context.mapKey(
        LuminaKey.keySpace,
        reloadAction,
        triggers: [LuminaReleasedTrigger()],
      );

      subsystem.addMappingContext(context);
      final comp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(comp);

      int triggeredCount = 0;
      comp.bindAction(reloadAction, TriggerState.triggered, (_) => triggeredCount++);

      subsystem.injectKeyDown(LuminaKey.keySpace);
      subsystem.tick(1.0 / 60.0);
      subsystem.tick(1.0 / 60.0);
      expect(triggeredCount, equals(0));

      subsystem.injectKeyUp(LuminaKey.keySpace);
      subsystem.tick(1.0 / 60.0);
      expect(triggeredCount, equals(1));
    });

    test('Hold trigger (threshold 1.0, dt = 1/60): ongoing for ticks 1..59, triggered on tick 60, no repeat when isOneShot is true', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final chargeAction = LuminaInputAction('Charge');

      context.mapKey(
        LuminaKey.keySpace,
        chargeAction,
        triggers: [LuminaHoldTrigger(holdTimeThreshold: 1.0, isOneShot: true)],
      );

      subsystem.addMappingContext(context);
      final comp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(comp);

      int startedCount = 0;
      int ongoingCount = 0;
      int triggeredCount = 0;

      comp.bindAction(chargeAction, TriggerState.started, (_) => startedCount++);
      comp.bindAction(chargeAction, TriggerState.ongoing, (_) => ongoingCount++);
      comp.bindAction(chargeAction, TriggerState.triggered, (_) => triggeredCount++);

      subsystem.injectKeyDown(LuminaKey.keySpace);

      // Ticks 1 to 59
      for (int i = 1; i <= 59; i++) {
        subsystem.tick(1.0 / 60.0);
      }
      expect(startedCount, equals(1));
      expect(ongoingCount, equals(58));
      expect(triggeredCount, equals(0));

      // Tick 60 (total time = 1.0s)
      subsystem.tick(1.0 / 60.0);
      expect(triggeredCount, equals(1));

      // Ticks 61 to 65 (one shot -> no more triggered)
      for (int i = 0; i < 5; i++) {
        subsystem.tick(1.0 / 60.0);
      }
      expect(triggeredCount, equals(1));
    });

    test('Hold canceled: hold 0.5s then release emits started, ongoing, and canceled with 0 triggered', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final chargeAction = LuminaInputAction('Charge');

      context.mapKey(
        LuminaKey.keySpace,
        chargeAction,
        triggers: [LuminaHoldTrigger(holdTimeThreshold: 1.0)],
      );

      subsystem.addMappingContext(context);
      final comp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(comp);

      final events = <TriggerState>[];
      for (final s in TriggerState.values) {
        comp.bindAction(chargeAction, s, (_) => events.add(s));
      }

      subsystem.injectKeyDown(LuminaKey.keySpace);
      // 30 ticks = 0.5s
      for (int i = 0; i < 30; i++) {
        subsystem.tick(1.0 / 60.0);
      }

      subsystem.injectKeyUp(LuminaKey.keySpace);
      subsystem.tick(1.0 / 60.0);

      expect(events.contains(TriggerState.started), isTrue);
      expect(events.contains(TriggerState.ongoing), isTrue);
      expect(events.contains(TriggerState.canceled), isTrue);
      expect(events.contains(TriggerState.triggered), isFalse);
    });

    test('Hold with isOneShot: false fires triggered every tick after threshold', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final chargeAction = LuminaInputAction('Charge');

      context.mapKey(
        LuminaKey.keySpace,
        chargeAction,
        triggers: [LuminaHoldTrigger(holdTimeThreshold: 0.1, isOneShot: false)],
      );

      subsystem.addMappingContext(context);
      final comp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(comp);

      int triggeredCount = 0;
      comp.bindAction(chargeAction, TriggerState.triggered, (_) => triggeredCount++);

      subsystem.injectKeyDown(LuminaKey.keySpace);
      // dt = 0.05
      subsystem.tick(0.05); // t = 0.05 (ongoing)
      subsystem.tick(0.05); // t = 0.10 (triggered 1)
      subsystem.tick(0.05); // t = 0.15 (triggered 2)
      subsystem.tick(0.05); // t = 0.20 (triggered 3)
      subsystem.tick(0.05); // t = 0.25 (triggered 4)
      subsystem.tick(0.05); // t = 0.30 (triggered 5)

      expect(triggeredCount, equals(5));
    });

    test('Tap trigger (0.2s): quick release triggers, long press cancels', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final tapAction = LuminaInputAction('Dodge');

      context.mapKey(
        LuminaKey.keySpace,
        tapAction,
        triggers: [LuminaTapTrigger(tapReleaseTimeThreshold: 0.2)],
      );

      subsystem.addMappingContext(context);
      final comp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(comp);

      int triggeredCount = 0;
      int canceledCount = 0;
      comp.bindAction(tapAction, TriggerState.triggered, (_) => triggeredCount++);
      comp.bindAction(tapAction, TriggerState.canceled, (_) => canceledCount++);

      // 1. Quick press: 0.1s then release
      subsystem.injectKeyDown(LuminaKey.keySpace);
      subsystem.tick(0.1);
      subsystem.injectKeyUp(LuminaKey.keySpace);
      subsystem.tick(0.01);

      expect(triggeredCount, equals(1));
      expect(canceledCount, equals(0));

      // 2. Long press: 0.3s then release
      subsystem.injectKeyDown(LuminaKey.keySpace);
      subsystem.tick(0.15);
      subsystem.tick(0.15); // crosses 0.2 threshold -> canceled
      expect(canceledCount, equals(1));

      subsystem.injectKeyUp(LuminaKey.keySpace);
      subsystem.tick(0.01);

      expect(triggeredCount, equals(1)); // No extra triggered
    });

    test('Pulse trigger: fires at start and at intervals while held', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final pulseAction = LuminaInputAction('PulseFire');

      context.mapKey(
        LuminaKey.keySpace,
        pulseAction,
        triggers: [LuminaPulseTrigger(interval: 0.5, triggerOnStart: true)],
      );

      subsystem.addMappingContext(context);
      final comp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(comp);

      int pulseCount = 0;
      comp.bindAction(pulseAction, TriggerState.triggered, (_) => pulseCount++);

      subsystem.injectKeyDown(LuminaKey.keySpace);
      // 16 ticks of dt = 0.1 (total 1.6s) -> pulses at t = 0.0, 0.5, 1.0, 1.5
      for (int i = 0; i < 16; i++) {
        subsystem.tick(0.1);
      }

      expect(pulseCount, equals(4));
    });

    test('Full event sequence for implicit trigger (press 2 ticks then release)', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final jumpAction = LuminaInputAction('Jump');

      context.mapKey(LuminaKey.keySpace, jumpAction); // No explicit triggers

      subsystem.addMappingContext(context);
      final comp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(comp);

      final sequence = <TriggerState>[];
      for (final s in TriggerState.values) {
        comp.bindAction(jumpAction, s, (_) => sequence.add(s));
      }

      subsystem.injectKeyDown(LuminaKey.keySpace);
      subsystem.tick(1.0 / 60.0); // tick 1: started, triggered
      subsystem.tick(1.0 / 60.0); // tick 2: triggered

      subsystem.injectKeyUp(LuminaKey.keySpace);
      subsystem.tick(1.0 / 60.0); // tick 3: completed

      expect(sequence, equals([
        TriggerState.started,
        TriggerState.triggered,
        TriggerState.triggered,
        TriggerState.completed,
      ]));
    });

    test('Two triggers on one mapping: Tap and Hold coexist independently', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final action = LuminaInputAction('DodgeOrCharge');

      context.mapKey(
        LuminaKey.keySpace,
        action,
        triggers: [
          LuminaTapTrigger(tapReleaseTimeThreshold: 0.2),
          LuminaHoldTrigger(holdTimeThreshold: 1.0),
        ],
      );

      subsystem.addMappingContext(context);
      final comp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(comp);

      int triggeredCount = 0;
      comp.bindAction(action, TriggerState.triggered, (_) => triggeredCount++);

      // Quick tap (0.1s)
      subsystem.injectKeyDown(LuminaKey.keySpace);
      subsystem.tick(0.1);
      subsystem.injectKeyUp(LuminaKey.keySpace);
      subsystem.tick(0.01);
      expect(triggeredCount, equals(1));

      // Long hold (1.0s)
      subsystem.injectKeyDown(LuminaKey.keySpace);
      for (int i = 0; i < 10; i++) {
        subsystem.tick(0.1);
      }
      expect(triggeredCount, equals(2));
    });

    test('reset(): removing mapping context resets trigger state', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final holdTrigger = LuminaHoldTrigger(holdTimeThreshold: 1.0);
      final action = LuminaInputAction('HoldAction');

      context.mapKey(LuminaKey.keySpace, action, triggers: [holdTrigger]);
      subsystem.addMappingContext(context);

      final comp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(comp);

      int triggeredCount = 0;
      comp.bindAction(action, TriggerState.triggered, (_) => triggeredCount++);

      subsystem.injectKeyDown(LuminaKey.keySpace);
      // Hold for 0.5s
      for (int i = 0; i < 30; i++) {
        subsystem.tick(1.0 / 60.0);
      }

      // Remove context mid-hold
      subsystem.removeMappingContext(context);

      // Re-add context
      subsystem.addMappingContext(context);

      // Another 0.5s from fresh state will not reach 1.0s
      for (int i = 0; i < 30; i++) {
        subsystem.tick(1.0 / 60.0);
      }
      expect(triggeredCount, equals(0));

      // Full additional 30 ticks reaches 1.0s
      for (int i = 0; i < 30; i++) {
        subsystem.tick(1.0 / 60.0);
      }
      expect(triggeredCount, equals(1));
    });
  });
}
