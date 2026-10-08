import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

void main() {
  LuminaFallOutcome fall(LuminaFallMonitor m, List<double> speeds) {
    var last = LuminaFallOutcome.none;
    for (final v in speeds) {
      final o = m.update(falling: true, verticalVelocity: v);
      if (o != LuminaFallOutcome.none) last = o;
    }
    final landing = m.update(falling: false, verticalVelocity: 0);
    return landing != LuminaFallOutcome.none ? landing : last;
  }

  test('falling faster than the ragdoll speed goes limp in the air, once', () {
    final m = LuminaFallMonitor();
    expect(m.update(falling: true, verticalVelocity: -1200), LuminaFallOutcome.none);
    expect(m.update(falling: true, verticalVelocity: -1400), LuminaFallOutcome.ragdoll);
    expect(m.update(falling: true, verticalVelocity: -1500), LuminaFallOutcome.none);
    // Landing after an in-air ragdoll does nothing more.
    expect(m.update(falling: false, verticalVelocity: 0), LuminaFallOutcome.none);
    expect(m.lastImpactSpeed, 1500);
  });

  test('touchdown speed picks heavy landing, ragdoll or nothing', () {
    expect(fall(LuminaFallMonitor(), [-100, -400]), LuminaFallOutcome.none);
    expect(fall(LuminaFallMonitor(), [-300, -800]), LuminaFallOutcome.hardLanding);
    expect(fall(LuminaFallMonitor(ragdollFallSpeed: 5000), [-600, -1250]), LuminaFallOutcome.ragdoll);
    final m = LuminaFallMonitor();
    fall(m, [-800]);
    expect(m.lastImpactSpeed, 800);
  });

  test('walking never triggers', () {
    final m = LuminaFallMonitor();
    for (var i = 0; i < 100; i++) {
      expect(m.update(falling: false, verticalVelocity: 0), LuminaFallOutcome.none);
    }
  });
}
