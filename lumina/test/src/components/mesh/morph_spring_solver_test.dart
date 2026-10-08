import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  final upright = Vector3(0, -980, 0);

  /// Runs [seconds] of frames at 60 fps with a constant [acceleration] and
  /// returns the largest and the final offset along y.
  (double, double) run(LuminaMorphSpringSolver solver, Vector3 acceleration, double seconds, {Vector3? gravity}) {
    var largest = 0.0;
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      solver.advance(1 / 60, acceleration, gravity ?? upright);
      largest = math.max(largest, solver.offset.y.abs());
    }
    return (largest, solver.offset.y);
  }

  test('a constant acceleration settles at inertia·a/ω² with the overshoot of its damping', () {
    final solver = LuminaMorphSpringSolver(frequency: 3, damping: 0.2, limit: 100);
    solver.advance(1 / 60, Vector3.zero(), upright);
    final omega = 2 * math.pi * 3;
    final (largest, last) = run(solver, Vector3(0, 300, 0), 6);
    // Upwards acceleration: the mass lags below.
    expect(last, closeTo(-300 / (omega * omega), 0.01));
    final overshoot = math.exp(-0.2 * math.pi / math.sqrt(1 - 0.04));
    expect(largest / last.abs() - 1, closeTo(overshoot, 0.05));
  });

  test('critical damping never overshoots', () {
    final solver = LuminaMorphSpringSolver(frequency: 3, damping: 1, limit: 100);
    final (largest, last) = run(solver, Vector3(0, 300, 0), 6);
    expect(largest, lessThanOrEqualTo(last.abs() + 1e-6));
  });

  test('tilting the body moves the rest towards the new gravity', () {
    final solver = LuminaMorphSpringSolver(frequency: 2, damping: 0.5, limit: 100);
    solver.advance(1 / 60, Vector3.zero(), upright);
    // Lying on the back: gravity now points along −z of the mesh.
    final lying = Vector3(0, 0, -980);
    run(solver, Vector3.zero(), 6, gravity: lying);
    final omega = 2 * math.pi * 2;
    expect(solver.offset.z, closeTo(-980 / (omega * omega), 0.05));
    expect(solver.offset.y, closeTo(980 / (omega * omega), 0.05));
  });

  test('the offset never exceeds the limit', () {
    final solver = LuminaMorphSpringSolver(frequency: 1, damping: 0.05, limit: 4);
    for (var i = 0; i < 600; i++) {
      solver.advance(1 / 60, Vector3(2000, -3000, 1000), upright);
      expect(solver.offset.length, lessThanOrEqualTo(4 + 1e-9));
    }
  });

  test('reset puts the mass at rest and takes the next gravity as rest', () {
    final solver = LuminaMorphSpringSolver();
    run(solver, Vector3(0, 500, 0), 1);
    expect(solver.offset.length, greaterThan(0.1));
    solver.reset();
    expect(solver.offset.length, 0);
    run(solver, Vector3.zero(), 1, gravity: Vector3(0, 0, -980));
    expect(solver.offset.length, lessThan(1e-9));
  });
}
