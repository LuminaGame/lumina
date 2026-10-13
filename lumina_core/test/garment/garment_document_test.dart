import 'dart:io';
import 'dart:math' as math;

import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';

/// The Garment asset's document and the geometry the fitting editor uses:
/// ray picking, the similarity that aligns landmarks, Euler angles.
void main() {
  test('a garment document round-trips through a .lmas file; presets; thickness clamps; broken payloads read defaults', () async {
    final doc = const LuminaGarmentDocument()
        .copyWith(
          sourceMesh: 'contents/meshes/static/tshirt.lmas',
          referenceBody: 'contents/meshes/skeletal/SKM_Manny_Simple.lmas',
          location: [1, 140, 2],
          rotation: [0, 90, 0],
          scale: [1.2, 1.2, 1.2],
          thickness: 0.8,
          slot: 'Torso',
          simulateAsCloth: true,
          clothSettingsAsset: 'contents/physics/CS_Cotton.lmas',
        )
        .withLandmark(const LuminaGarmentLandmark('Neck', garment: [0, 5, 0], body: [0, 150, 0]))
        .withLandmark(const LuminaGarmentLandmark('Waist', garment: [0, -40, 0]));
    final dir = await Directory.systemTemp.createTemp('garment_doc_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/G_Tshirt.lmas');
    await file.writeAsBytes(doc.toAsset(name: 'G_Tshirt').toProtoBufferBytes());
    final asset = LuminaAsset.fromBytes(await file.readAsBytes());
    expect(asset.type, AssetType.garment);
    expect(asset.references.map((r) => r.slotName), ['source_mesh', 'reference_body']);
    final back = LuminaGarmentDocument.fromAsset(asset);
    expect(back, doc);
    expect(back.landmark('Neck')!.isComplete, isTrue);
    expect(back.landmark('Waist')!.isComplete, isFalse);
    expect(back.withoutLandmark('Neck').landmarks.map((l) => l.name), ['Waist']);
    expect(LuminaGarmentDocument.presets, hasLength(17));
    expect(LuminaGarmentDocument.presets.take(3), ['Neck', 'Shoulder L', 'Shoulder R']);
    expect(const LuminaGarmentDocument().copyWith(thickness: 25).thickness, 10);
    expect(LuminaGarmentDocument.fromProperties(const {'thickness': -3}).thickness, 0);
    expect(LuminaGarmentDocument.fromJson('{not json'), const LuminaGarmentDocument());
    expect(LuminaGarmentDocument.fromAsset(LuminaAsset(assetId: 'x', name: 'x', type: AssetType.garment)), const LuminaGarmentDocument());
  });

  test('the placement applies scale, then rotation X·Y·Z, then translation', () {
    final doc = const LuminaGarmentDocument().copyWith(location: [10, 20, 30], rotation: [0, 0, 90], scale: [2, 2, 2]);
    final p = doc.place([1, 0, 0]);
    expect(p[0], closeTo(10, 1e-9));
    expect(p[1], closeTo(22, 1e-9), reason: 'X turned 90° about Z is +Y, scaled 2');
    expect(p[2], closeTo(30, 1e-9));
  });

  test('a ray picks the nearest triangle in front of it', () {
    // Two parallel quads at z = 0 and z = -5, facing the ray.
    final positions = <double>[-1, -1, 0, 1, -1, 0, 1, 1, 0, -1, 1, 0, -1, -1, -5, 1, -1, -5, 1, 1, -5, -1, 1, -5];
    final triangles = [0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7];
    final hit = LuminaGarmentMath.raycast(positions, triangles, 0.2, 0.3, 10, 0, 0, -1)!;
    expect(hit.t, closeTo(10, 1e-9));
    expect(hit.triangle, lessThan(2));
    expect([hit.x, hit.y, hit.z], [closeTo(0.2, 1e-9), closeTo(0.3, 1e-9), closeTo(0, 1e-9)]);
    expect(LuminaGarmentMath.raycast(positions, triangles, 3, 3, 10, 0, 0, -1), isNull);
    expect(LuminaGarmentMath.raycast(positions, triangles, 0, 0, 10, 0, 0, 1), isNull, reason: 'behind the ray');
  });

  test('the similarity fit recovers scale, rotation and translation from landmark pairs', () {
    final q = LuminaGarmentMath.quaternionFromEuler([10, 35, -20]);
    final truth = LuminaSimilarity(1.3, q, [5, 140, -2]);
    final from = [
      [0.0, 10.0, 0.0],
      [-18.0, 0.0, 2.0],
      [18.0, 0.0, 2.0],
      [0.0, -35.0, 5.0],
      [6.0, -20.0, -9.0],
    ];
    final to = [for (final p in from) truth.apply(p)];
    final fit = LuminaGarmentMath.fitSimilarity(from, to);
    expect(fit.scale, closeTo(1.3, 1e-9));
    for (var i = 0; i < from.length; i++) {
      final p = fit.apply(from[i]);
      for (var k = 0; k < 3; k++) {
        expect(p[k], closeTo(to[i][k], 1e-7));
      }
    }
    final euler = LuminaGarmentMath.eulerFromQuaternion(fit.rotation);
    expect(euler, [closeTo(10, 1e-6), closeTo(35, 1e-6), closeTo(-20, 1e-6)]);
    // One pair: a translation; two: rotation kept, scale fitted.
    expect(LuminaGarmentMath.fitSimilarity([from[0]], [to[0]]).apply(from[0]), [for (final v in to[0]) closeTo(v, 1e-9)]);
    final two = LuminaGarmentMath.fitSimilarity([[0.0, 0.0, 0.0], [0.0, 10.0, 0.0]], [[1.0, 1.0, 1.0], [1.0, 21.0, 1.0]]);
    expect(two.scale, closeTo(2, 1e-9));
    expect(two.rotation, [0, 0, 0, 1]);
    // Euler ↔ quaternion agrees with the document's placement matrix.
    final doc = const LuminaGarmentDocument().copyWith(rotation: [10, 35, -20]);
    final placed = doc.place([3, 4, 5]);
    final rotated = LuminaGarmentMath.rotate(q, [3, 4, 5]);
    for (var k = 0; k < 3; k++) {
      expect(placed[k], closeTo(rotated[k], 1e-9));
    }
    expect(math.sqrt(q.fold(0.0, (s, e) => s + e * e)), closeTo(1, 1e-12));
  });
}
