import 'dart:io';
import 'dart:math' as math;

import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';

/// Skinned GLB geometry in centimetres, closest-point queries, and the body
/// triangles a garment covers, on the mannequin from `test-assets/`.
void main() {
  final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';
  final manny = File('$assets/mannequin/SKM_Manny_Simple.glb');
  final skip = manny.existsSync() ? false : 'test-assets/mannequin/SKM_Manny_Simple.glb is missing';

  late LuminaSkinnedMeshData body;
  setUpAll(() {
    if (manny.existsSync()) body = LuminaSkinnedMeshData.fromGlb(manny.readAsBytesSync());
  });

  /// The name of the joint weighing most on vertex [v].
  String dominant(int v) => body.nodeNames[body.joints![v * 4]];

  test('a skinned GLB reads in centimetres with its skin and joint rest poses', () {
    expect(body.isSkinned, isTrue);
    var minY = double.infinity, maxY = -double.infinity;
    for (var v = 0; v < body.vertexCount; v++) {
      minY = math.min(minY, body.positions[v * 3 + 1]);
      maxY = math.max(maxY, body.positions[v * 3 + 1]);
    }
    expect(maxY - minY, closeTo(180.5, 1.0), reason: 'the mannequin is 1.8 m tall');
    expect(body.vertexCount, 20101 + 28604);
    expect(body.primitives, hasLength(2));
    for (var v = 0; v < body.vertexCount; v += 997) {
      final w = body.weights!;
      expect(w[v * 4] + w[v * 4 + 1] + w[v * 4 + 2] + w[v * 4 + 3], closeTo(1, 1e-5));
    }
    final head = body.nodeNamed('head');
    expect(head, greaterThanOrEqualTo(0));
    expect(body.nodePosition(head).$2, closeTo(160, 15));
    expect(body.inverseBind.containsKey(head), isTrue);
  }, skip: skip);

  test('the closest surface point of a mesh is found within the search distance', () {
    final grid = LuminaTriangleGrid(body.positions, body.triangles);
    final (hx, hy, hz) = body.nodePosition(body.nodeNamed('head'));
    final inside = grid.closest(hx, hy, hz)!;
    expect(inside.distance, inInclusiveRange(3, 15), reason: 'the head joint is inside the head');
    final outside = grid.closest(hx, hy + 60, hz, maxDistance: 5);
    expect(outside, isNull, reason: 'nothing within 5 cm of a point 60 cm above the head');
    // Brute force agrees.
    var best = double.infinity;
    for (var v = 0; v < body.vertexCount; v++) {
      final dx = body.positions[v * 3] - hx, dy = body.positions[v * 3 + 1] - hy, dz = body.positions[v * 3 + 2] - hz;
      best = math.min(best, math.sqrt(dx * dx + dy * dy + dz * dz));
    }
    expect(inside.distance, lessThanOrEqualTo(best + 1e-9));
  }, skip: skip);

  test('a shell 1 cm outside the torso covers the torso and none of the head, hands or feet', () {
    final torso = RegExp(r'^(spine_0[1-5]|pelvis)$');
    final positions = <double>[];
    final triangles = <int>[];
    final shellOf = <int, int>{};
    for (var t = 0; t < body.triangleCount; t++) {
      final vs = [for (var k = 0; k < 3; k++) body.triangles[t * 3 + k]];
      if (!vs.every((v) => torso.hasMatch(dominant(v)))) continue;
      for (final v in vs) {
        triangles.add(shellOf.putIfAbsent(v, () {
          positions.addAll([
            for (var c = 0; c < 3; c++) body.positions[v * 3 + c] + body.normals[v * 3 + c],
          ]);
          return positions.length ~/ 3 - 1;
        }));
      }
    }
    final shell = LuminaSkinnedMeshData.fromArrays(positions, triangles);
    final covered = LuminaBodyMask.compute(body, [shell]);
    var torsoTriangles = 0, torsoCovered = 0;
    for (var t = 0; t < body.triangleCount; t++) {
      final names = [for (var k = 0; k < 3; k++) dominant(body.triangles[t * 3 + k])];
      if (names.every(torso.hasMatch)) {
        torsoTriangles++;
        if (covered[t] == 1) torsoCovered++;
      }
      if (names.any((n) => RegExp(r'head|hand|foot|ball|neck').hasMatch(n))) {
        expect(covered[t], 0, reason: 'triangle $t of ${names.join('/')}');
      }
    }
    // The shell's open edges (at the neck, arms and hips) keep a margin drawn.
    expect(torsoCovered / torsoTriangles, greaterThan(0.6), reason: '$torsoCovered of $torsoTriangles');

    final masked = LuminaSkinnedMeshData.fromGlb(LuminaBodyMask.applyDegenerate(body, covered));
    expect(masked.vertexCount, body.vertexCount);
    expect(masked.triangleCount, body.triangleCount);
    for (var t = 0; t < body.triangleCount; t++) {
      final a = masked.triangles[t * 3], b = masked.triangles[t * 3 + 1], c = masked.triangles[t * 3 + 2];
      if (covered[t] == 1) {
        expect(a == b && b == c, isTrue, reason: 'covered triangle $t is degenerate');
      } else {
        expect([a, b, c], [body.triangles[t * 3], body.triangles[t * 3 + 1], body.triangles[t * 3 + 2]]);
      }
    }
  }, skip: skip);
}
