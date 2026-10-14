import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';

/// The garment fit and the body mask on small bodies built as GLBs: only
/// skin counts (a hair card, an eye or teeth of a merged character mesh is
/// neither pushed out of, lifted over nor masked), and a garment fitted to
/// its own reference body stays exactly where it was authored.
void main() {
  /// A bumpy sphere (cm in, metres in the GLB): radius [r] modulated by
  /// [bumps] cm, [rings] × [segments] quads.
  ({List<double> positions, List<int> indices}) sphere(double r, {double bumps = 0, int rings = 24, int segments = 32, double scale = 1}) {
    final p = <double>[], idx = <int>[];
    for (var i = 0; i <= rings; i++) {
      final theta = math.pi * i / rings;
      for (var j = 0; j <= segments; j++) {
        final phi = 2 * math.pi * j / segments;
        final rr = r + bumps * math.sin(3 * theta) * math.cos(4 * phi);
        p.addAll([
          rr * math.sin(theta) * math.cos(phi) * scale,
          rr * math.cos(theta) * scale,
          rr * math.sin(theta) * math.sin(phi) * scale,
        ]);
      }
    }
    for (var i = 0; i < rings; i++) {
      for (var j = 0; j < segments; j++) {
        final a = i * (segments + 1) + j, b = a + segments + 1;
        idx.addAll([a, a + 1, b, a + 1, b + 1, b]);
      }
    }
    return (positions: p, indices: idx);
  }

  /// A card [w] × [h] cm at depth [z] cm in front of +Z, its normal facing
  /// into the body (as hair cards often do).
  ({List<double> positions, List<int> indices}) card(double w, double h, double z, double y) {
    final p = <double>[], idx = <int>[];
    const n = 8;
    for (var i = 0; i <= n; i++) {
      for (var j = 0; j <= n; j++) {
        p.addAll([-w / 2 + w * j / n, y - h / 2 + h * i / n, z]);
      }
    }
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final a = i * (n + 1) + j, b = a + n + 1;
        idx.addAll([a, b, a + 1, a + 1, b, b + 1]);
      }
    }
    return (positions: p, indices: idx);
  }

  /// A GLB with one node and mesh per part; a [masked] part's material is
  /// alpha-masked (hair cards).
  Uint8List glb(List<({String name, List<double> positions, List<int> indices, bool masked})> parts, {List<double>? colors}) {
    final bin = BytesBuilder();
    final views = <Map<String, Object?>>[], accessors = <Map<String, Object?>>[];
    final meshes = <Map<String, Object?>>[], nodes = <Map<String, Object?>>[], materials = <Map<String, Object?>>[];
    for (final part in parts) {
      final pos = Float32List.fromList([for (final v in part.positions) v / 100]);
      final lo = [double.infinity, double.infinity, double.infinity], hi = [-double.infinity, -double.infinity, -double.infinity];
      for (var i = 0; i < pos.length; i++) {
        lo[i % 3] = math.min(lo[i % 3], pos[i]);
        hi[i % 3] = math.max(hi[i % 3], pos[i]);
      }
      views.add({'buffer': 0, 'byteOffset': bin.length, 'byteLength': pos.lengthInBytes});
      bin.add(pos.buffer.asUint8List());
      accessors.add({'bufferView': views.length - 1, 'componentType': 5126, 'count': pos.length ~/ 3, 'type': 'VEC3', 'min': lo, 'max': hi});
      final ind = Uint32List.fromList(part.indices);
      views.add({'buffer': 0, 'byteOffset': bin.length, 'byteLength': ind.lengthInBytes});
      bin.add(ind.buffer.asUint8List());
      accessors.add({'bufferView': views.length - 1, 'componentType': 5125, 'count': ind.length, 'type': 'SCALAR'});
      final indexAccessor = accessors.length - 1;
      int? colorAccessor;
      if (colors != null) {
        final c = Float32List.fromList(colors);
        views.add({'buffer': 0, 'byteOffset': bin.length, 'byteLength': c.lengthInBytes});
        bin.add(c.buffer.asUint8List());
        accessors.add({'bufferView': views.length - 1, 'componentType': 5126, 'count': c.length ~/ 4, 'type': 'VEC4'});
        colorAccessor = accessors.length - 1;
      }
      materials.add({'name': 'M_${part.name}', if (part.masked) 'alphaMode': 'MASK'});
      meshes.add({
        'name': part.name,
        'primitives': [
          {
            'attributes': {'POSITION': indexAccessor - 1, 'COLOR_0': ?colorAccessor},
            'indices': indexAccessor,
            'material': materials.length - 1,
          },
        ],
      });
      nodes.add({'name': part.name, 'mesh': meshes.length - 1});
    }
    final bytes = bin.toBytes();
    final json = {
      'asset': {'version': '2.0'},
      'scene': 0,
      'scenes': [
        {'nodes': [for (var i = 0; i < nodes.length; i++) i]},
      ],
      'nodes': nodes,
      'meshes': meshes,
      'materials': materials,
      'accessors': accessors,
      'bufferViews': views,
      'buffers': [
        {'byteLength': bytes.length},
      ],
    };
    return GlbDocument(json, bytes).encode();
  }

  final skinPart = sphere(20);
  final hair = card(24, 30, 21, 0);
  ({String name, List<double> positions, List<int> indices, bool masked}) part(String name, ({List<double> positions, List<int> indices}) m,
          {bool masked = false}) =>
      (name: name, positions: m.positions, indices: m.indices, masked: masked);
  final bodyOnly = LuminaSkinnedMeshData.fromGlb(glb([part('body', skinPart)]));
  final merged = LuminaSkinnedMeshData.fromGlb(glb([
    part('body', skinPart),
    part('groom_Hair_L_Straight', hair, masked: true),
    part('eyeLeft_lod0', card(2, 2, 19.5, 6)),
    part('teeth_lod0', card(3, 1, 18, -4)),
  ]));
  // The same bodies 3 % wider: what a slot refits to.
  final wideSkin = sphere(20, scale: 1.03);
  final wideBodyOnly = LuminaSkinnedMeshData.fromGlb(glb([part('body', wideSkin)]));
  final wideMerged = LuminaSkinnedMeshData.fromGlb(glb([
    part('body', wideSkin),
    part('groom_Hair_L_Straight', card(24 * 1.03, 30 * 1.03, 21 * 1.03, 0), masked: true),
    part('eyeLeft_lod0', card(2 * 1.03, 2 * 1.03, 19.5 * 1.03, 6 * 1.03)),
    part('teeth_lod0', card(3 * 1.03, 1 * 1.03, 18 * 1.03, -4 * 1.03)),
  ]));
  // A shirt 2 cm off the skin, 1 cm outside the hair card.
  final shell = sphere(22, rings: 18, segments: 24);
  final garment = LuminaSkinnedMeshData.fromArrays(shell.positions, shell.indices);
  const doc = LuminaGarmentDocument(sourceMesh: 'shirt.glb', referenceBody: 'body.glb', thickness: 0.5);

  test('only skin primitives count: grooms, eyes and teeth of a merged mesh are not skin', () {
    expect(merged.primitives, hasLength(4));
    expect([for (final p in merged.primitives) merged.isSkin(p)], [true, false, false, false]);
    expect(merged.skin().vertexCount, bodyOnly.vertexCount);
    expect(merged.skin().triangleCount, bodyOnly.triangleCount);
    expect(bodyOnly.skin(), same(bodyOnly), reason: 'a body that is all skin is used as it is');
  });

  test("a merged mesh's hair card neither moves the fitted garment nor gets masked", () {
    final onMerged = LuminaGarmentFitter.fit(source: garment, document: doc, referenceBody: merged, targetBody: wideMerged);
    final onSkin = LuminaGarmentFitter.fit(source: garment, document: doc, referenceBody: bodyOnly, targetBody: wideBodyOnly);
    var worst = 0.0;
    for (var i = 0; i < onSkin.positions.length; i++) {
      worst = math.max(worst, (onMerged.positions[i] - onSkin.positions[i]).abs());
    }
    expect(worst, lessThan(0.05), reason: 'the hair card changed the fit by $worst cm');
    expect(onMerged.report.maxPokeThrough, closeTo(onSkin.report.maxPokeThrough, 1e-9), reason: 'the hair card is not lifted over');

    final fitted = LuminaSkinnedMeshData.fromArrays(onMerged.positions, onMerged.triangles);
    final covered = LuminaBodyMask.compute(wideMerged, [fitted]);
    int coveredIn(LuminaGlbPrimitiveRef p) => [for (var t = 0; t < p.triangleCount; t++) covered[p.firstTriangle + t]].where((c) => c == 1).length;
    expect(coveredIn(wideMerged.primitives[0]), greaterThan(0), reason: 'the skin under the shirt is masked');
    for (final p in wideMerged.primitives.skip(1)) {
      expect(coveredIn(p), 0, reason: '${wideMerged.nodeNames[p.node]} is never masked');
    }
  });

  test('a garment fitted to its own reference body stays where it was authored', () {
    final bumpy = LuminaSkinnedMeshData.fromGlb(glb([part('body', sphere(20, bumps: 1.5))]));
    // 0.7–3.5 cm off the bumps, over convex and concave parts alike.
    final coat = LuminaSkinnedMeshData.fromArrays(sphere(22, rings: 30, segments: 40).positions, sphere(22, rings: 30, segments: 40).indices);
    final fit = LuminaGarmentFitter.fit(source: coat, document: doc, referenceBody: bumpy, targetBody: bumpy);
    var worst = 0.0;
    for (var i = 0; i < coat.positions.length; i++) {
      worst = math.max(worst, (fit.positions[i] - coat.positions[i]).abs());
    }
    expect(worst, lessThan(1e-6), reason: 'moved up to $worst cm');
    // Placed by the document: still identity on the same body.
    final moved = doc.copyWith(location: [0, 5, 0]);
    final fit2 = LuminaGarmentFitter.fit(source: coat, document: moved, referenceBody: bumpy, targetBody: bumpy);
    expect(fit2.positions[1], closeTo(coat.positions[1] + 5, 1e-6));
  });

  test('a garment coloured per vertex keeps its colours through the fit and in the written GLB', () {
    final colours = [for (var v = 0; v < shell.positions.length ~/ 3; v++) ...[0.8, 0.1 * (v % 7), 0.05, 1.0]];
    final dress = LuminaSkinnedMeshData.fromGlb(glb([part('dress', shell)], colors: colours));
    expect(dress.colors, isNotNull);
    expect(dress.colors!.sublist(0, 8), [closeTo(0.8, 1e-6), 0, closeTo(0.05, 1e-6), 1, closeTo(0.8, 1e-6), closeTo(0.1, 1e-6), closeTo(0.05, 1e-6), 1]);
    final refined = dress.refined(maxEdge: 1);
    expect(refined.colors!.length, refined.vertexCount * 4, reason: 'new vertices take their edge midpoints');
    final fit = LuminaGarmentFitter.fit(source: dress, document: doc, referenceBody: bodyOnly, targetBody: wideBodyOnly);
    final written = LuminaSkinnedMeshData.fromGlb(LuminaGarmentGlbWriter.write(fit: fit, source: dress, targetBody: wideBodyOnly));
    expect(written.colors, isNotNull, reason: 'COLOR_0 written');
    for (var i = 0; i < 40; i++) {
      expect(written.colors![i], closeTo(dress.colors![i], 1e-6));
    }
    expect(bodyOnly.colors, isNull, reason: 'no COLOR_0, no colours');
  });
}
