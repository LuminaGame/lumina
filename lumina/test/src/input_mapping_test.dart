import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('Enhanced Input System Tests (Input Task 01)', () {
    test('Map keySpace -> Jump, bind triggered, injectKeyDown and tick triggers callback with asBool == true', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final jumpAction = LuminaInputAction('Jump');
      context.mapKey(LuminaKey.keySpace, jumpAction);

      subsystem.addMappingContext(context);

      final inputComp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(inputComp);

      LuminaInputActionValue? receivedValue;
      int callCount = 0;

      inputComp.bindAction(jumpAction, TriggerState.triggered, (val) {
        callCount++;
        receivedValue = val;
      });

      subsystem.injectKeyDown(LuminaKey.keySpace);
      subsystem.tick(1.0 / 60.0);

      expect(callCount, equals(1));
      expect(receivedValue, isNotNull);
      expect(receivedValue!.asBool, isTrue);
      expect(receivedValue!.asAxis1D, equals(1.0));
    });

    test('LuminaInputActionValue implicit conversions table', () {
      final boolVal = const LuminaInputActionValue.bool(true);
      expect(boolVal.asBool, isTrue);
      expect(boolVal.asAxis1D, equals(1.0));
      expect(boolVal.asAxis2D, equals(Vector2(1.0, 0.0)));
      expect(boolVal.magnitude, equals(1.0));

      final axis2DVal = LuminaInputActionValue.axis2D(Vector2(0.5, 0.0));
      expect(axis2DVal.asBool, isTrue);
      expect(axis2DVal.asAxis1D, equals(0.5));
      expect(axis2DVal.magnitude, equals(0.5));

      final axis1DZero = const LuminaInputActionValue.axis1D(0.0);
      expect(axis1DZero.asBool, isFalse);
      expect(axis1DZero.asAxis1D, equals(0.0));
      expect(axis1DZero.magnitude, equals(0.0));
    });

    test('Priority shadowing: higher priority context shadows lower priority context mapping', () {
      final subsystem = LuminaInputSubsystem();
      final contextA = LuminaInputMappingContext();
      final contextB = LuminaInputMappingContext();

      final jumpAction = LuminaInputAction('Jump');
      final pauseAction = LuminaInputAction('Pause');

      contextA.mapKey(LuminaKey.keySpace, jumpAction);
      contextB.mapKey(LuminaKey.keySpace, pauseAction);

      subsystem.addMappingContext(contextA, priority: 0);
      subsystem.addMappingContext(contextB, priority: 10);

      final inputComp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(inputComp);

      int jumpCount = 0;
      int pauseCount = 0;

      inputComp.bindAction(jumpAction, TriggerState.triggered, (_) => jumpCount++);
      inputComp.bindAction(pauseAction, TriggerState.triggered, (_) => pauseCount++);

      subsystem.injectKeyDown(LuminaKey.keySpace);
      subsystem.tick(1.0 / 60.0);

      expect(jumpCount, equals(0));
      expect(pauseCount, equals(1));

      subsystem.removeMappingContext(contextB);
      subsystem.tick(1.0 / 60.0);

      expect(jumpCount, equals(1));
      expect(pauseCount, equals(1));
    });

    test('Two keys driving one action sums contributions', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final moveAction = LuminaInputAction('Move', valueType: InputValueType.axis1D);

      context.mapKey(LuminaKey.keyW, moveAction);
      context.mapKey(LuminaKey.gamepadLeftStickY, moveAction);

      subsystem.addMappingContext(context);

      final inputComp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(inputComp);

      double receivedAxis = 0.0;
      int callCount = 0;

      inputComp.bindAction(moveAction, TriggerState.triggered, (val) {
        callCount++;
        receivedAxis = val.asAxis1D;
      });

      subsystem.injectKeyDown(LuminaKey.keyW);
      subsystem.injectAnalog(LuminaKey.gamepadLeftStickY, 0.5);
      subsystem.tick(1.0 / 60.0);

      expect(callCount, equals(1));
      expect(receivedAxis, equals(1.5));
    });

    test('Unmapped key produces no callback, no throw, subsystem state unchanged', () {
      final subsystem = LuminaInputSubsystem();
      final inputComp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(inputComp);

      subsystem.injectKeyDown(LuminaKey.mouseLeft);
      expect(() => subsystem.tick(1.0 / 60.0), returnsNormally);
    });

    test('unmapKey stops subsequent event dispatch', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final jumpAction = LuminaInputAction('Jump');
      context.mapKey(LuminaKey.keySpace, jumpAction);

      subsystem.addMappingContext(context);

      final inputComp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(inputComp);

      int count = 0;
      inputComp.bindAction(jumpAction, TriggerState.triggered, (_) => count++);

      context.unmapKey(LuminaKey.keySpace, jumpAction);
      subsystem.injectKeyDown(LuminaKey.keySpace);
      subsystem.tick(1.0 / 60.0);

      expect(count, equals(0));
    });

    test('Analog values do not latch across ticks', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final lookAction = LuminaInputAction('LookRight', valueType: InputValueType.axis1D);
      context.mapKey(LuminaKey.mouseX, lookAction);

      subsystem.addMappingContext(context);

      final inputComp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(inputComp);

      final values = <double>[];
      inputComp.bindAction(lookAction, TriggerState.triggered, (val) {
        values.add(val.asAxis1D);
      });

      subsystem.injectAnalog(LuminaKey.mouseX, 0.25);
      subsystem.tick(1.0 / 60.0);
      expect(values, equals([0.25]));

      // Next tick without injection does not dispatch lookAction
      subsystem.tick(1.0 / 60.0);
      expect(values, equals([0.25]));
    });

    test('Component teardown unregisters and dispatches nothing', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final jumpAction = LuminaInputAction('Jump');
      context.mapKey(LuminaKey.keySpace, jumpAction);
      subsystem.addMappingContext(context);

      final actor = LuminaPawn();
      final inputComp = LuminaInputComponent(subsystem: subsystem);
      actor.addComponent(inputComp);

      int count = 0;
      inputComp.bindAction(jumpAction, TriggerState.triggered, (_) => count++);

      actor.removeComponent(inputComp);

      subsystem.injectKeyDown(LuminaKey.keySpace);
      subsystem.tick(1.0 / 60.0);

      expect(count, equals(0));
    });

    test('Adding same mapping context twice replaces/updates without double dispatch', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final jumpAction = LuminaInputAction('Jump');
      context.mapKey(LuminaKey.keySpace, jumpAction);

      subsystem.addMappingContext(context, priority: 0);
      subsystem.addMappingContext(context, priority: 5);

      final inputComp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(inputComp);

      int count = 0;
      inputComp.bindAction(jumpAction, TriggerState.triggered, (_) => count++);

      subsystem.injectKeyDown(LuminaKey.keySpace);
      subsystem.tick(1.0 / 60.0);

      expect(count, equals(1));
    });
  });
}
