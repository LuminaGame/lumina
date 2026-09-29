import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('Input Modifiers Tests (Input Task 02)', () {
    test('Radial DeadZone (lower 0.2, upper 1.0) on axis1D values', () {
      final deadZone = LuminaDeadZoneModifier(lowerThreshold: 0.2, upperThreshold: 1.0, type: DeadZoneType.radial);

      expect(deadZone.modify(const LuminaInputActionValue.axis1D(0.1), 0.0).asAxis1D, closeTo(0.0, 1e-9));
      expect(deadZone.modify(const LuminaInputActionValue.axis1D(0.2), 0.0).asAxis1D, closeTo(0.0, 1e-9));
      expect(deadZone.modify(const LuminaInputActionValue.axis1D(0.6), 0.0).asAxis1D, closeTo(0.5, 1e-9));
      expect(deadZone.modify(const LuminaInputActionValue.axis1D(1.0), 0.0).asAxis1D, closeTo(1.0, 1e-9));
    });

    test('Radial DeadZone on Vector2 preserves direction and handles sub-threshold', () {
      final deadZone = LuminaDeadZoneModifier(lowerThreshold: 0.2, upperThreshold: 1.0, type: DeadZoneType.radial);

      final sub = deadZone.modify(LuminaInputActionValue.axis2D(Vector2(0.1, 0.1)), 0.0);
      expect(sub.asAxis2D, equals(Vector2.zero()));

      final superVal = deadZone.modify(LuminaInputActionValue.axis2D(Vector2(0.6, 0.0)), 0.0);
      expect(superVal.asAxis2D.x, closeTo(0.5, 1e-9));
      expect(superVal.asAxis2D.y, closeTo(0.0, 1e-9));

      final diag = deadZone.modify(LuminaInputActionValue.axis2D(Vector2(0.6, 0.6)), 0.0);
      // Direction is preserved (x == y and positive)
      expect(diag.asAxis2D.x, closeTo(diag.asAxis2D.y, 1e-9));
      expect(diag.asAxis2D.x, greaterThan(0.0));
    });

    test('Axial DeadZone on Vector2(0.1, 0.6) independent per-axis zeroing', () {
      final deadZone = LuminaDeadZoneModifier(lowerThreshold: 0.2, upperThreshold: 1.0, type: DeadZoneType.axial);

      final res = deadZone.modify(LuminaInputActionValue.axis2D(Vector2(0.1, 0.6)), 0.0);
      expect(res.asAxis2D.x, closeTo(0.0, 1e-9));
      expect(res.asAxis2D.y, closeTo(0.5, 1e-9));
    });

    test('Negate modifier defaults and per-axis flags', () {
      final negateAll = LuminaNegateModifier();
      expect(negateAll.modify(const LuminaInputActionValue.axis1D(0.5), 0.0).asAxis1D, closeTo(-0.5, 1e-9));

      final negateXOnly = LuminaNegateModifier(x: true, y: false, z: false);
      final res = negateXOnly.modify(LuminaInputActionValue.axis2D(Vector2(0.3, 0.7)), 0.0);
      expect(res.asAxis2D.x, closeTo(-0.3, 1e-9));
      expect(res.asAxis2D.y, closeTo(0.7, 1e-9));
    });

    test('Scalar modifier uniform and per-axis', () {
      final uniformScalar = LuminaScalarModifier.uniform(2.0);
      expect(uniformScalar.modify(const LuminaInputActionValue.axis1D(0.25), 0.0).asAxis1D, closeTo(0.5, 1e-9));

      final perAxisScalar = LuminaScalarModifier(x: 2.0, y: 0.5);
      final res = perAxisScalar.modify(LuminaInputActionValue.axis2D(Vector2(1.0, 1.0)), 0.0);
      expect(res.asAxis2D.x, closeTo(2.0, 1e-9));
      expect(res.asAxis2D.y, closeTo(0.5, 1e-9));
    });

    test('ResponseCurve modifier preserves sign and applies exponent', () {
      final exp2 = LuminaResponseCurveModifier(exponent: 2.0);
      expect(exp2.modify(const LuminaInputActionValue.axis1D(0.5), 0.0).asAxis1D, closeTo(0.25, 1e-9));
      expect(exp2.modify(const LuminaInputActionValue.axis1D(-0.5), 0.0).asAxis1D, closeTo(-0.25, 1e-9));
      expect(exp2.modify(const LuminaInputActionValue.axis1D(1.0), 0.0).asAxis1D, closeTo(1.0, 1e-9));

      final expHalf = LuminaResponseCurveModifier(exponent: 0.5);
      expect(expHalf.modify(const LuminaInputActionValue.axis1D(0.25), 0.0).asAxis1D, closeTo(0.5, 1e-9));
    });

    test('Chain order affects output: [DeadZone, Scalar] vs [Scalar, DeadZone]', () {
      final dz = LuminaDeadZoneModifier(lowerThreshold: 0.2, upperThreshold: 1.0, type: DeadZoneType.radial);
      final sc = LuminaScalarModifier.uniform(0.5);

      final val = const LuminaInputActionValue.axis1D(0.6);

      // DeadZone first: (0.6 - 0.2) / 0.8 = 0.5; then Scalar * 0.5 = 0.25
      final chain1 = sc.modify(dz.modify(val, 0.0), 0.0);
      expect(chain1.asAxis1D, closeTo(0.25, 1e-9));

      // Scalar first: 0.6 * 0.5 = 0.3; then DeadZone: (0.3 - 0.2) / 0.8 = 0.125
      final chain2 = dz.modify(sc.modify(val, 0.0), 0.0);
      expect(chain2.asAxis1D, closeTo(0.125, 1e-9));
    });

    test('Modifier output preserves InputValueType across a 3-modifier chain', () {
      final dz = LuminaDeadZoneModifier();
      final sc = LuminaScalarModifier.uniform(1.5);
      final rc = LuminaResponseCurveModifier(exponent: 2.0);

      var val = LuminaInputActionValue.axis2D(Vector2(0.5, 0.5));
      val = dz.modify(val, 0.0);
      val = sc.modify(val, 0.0);
      val = rc.modify(val, 0.0);

      expect(val.type, equals(InputValueType.axis2D));
    });

    test('End-to-end through subsystem: modifiers in mapping chain executed in order', () {
      final subsystem = LuminaInputSubsystem();
      final context = LuminaInputMappingContext();
      final lookAction = LuminaInputAction('LookRight', valueType: InputValueType.axis1D);

      context.mapKey(
        LuminaKey.gamepadLeftStickX,
        lookAction,
        modifiers: [
          LuminaDeadZoneModifier(lowerThreshold: 0.2, upperThreshold: 1.0),
          LuminaNegateModifier(),
        ],
      );

      subsystem.addMappingContext(context);

      final inputComp = LuminaInputComponent(subsystem: subsystem);
      subsystem.registerComponent(inputComp);

      double received = 0.0;
      inputComp.bindAction(lookAction, TriggerState.triggered, (val) {
        received = val.asAxis1D;
      });

      subsystem.injectAnalog(LuminaKey.gamepadLeftStickX, 0.6);
      subsystem.tick(1.0 / 60.0);

      // 0.6 -> DeadZone(0.2..1.0) gives 0.5 -> Negate gives -0.5
      expect(received, closeTo(-0.5, 1e-9));
    });
  });
}
