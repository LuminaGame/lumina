import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

/// The attributes of the one primitive in a factory GLB, read straight from
/// its JSON and BIN chunks: what gltfio hands Filament.
({Map<String, List<double>> attributes, Map<String, int> components, List<int> indices}) _readGlb(Uint8List glb) {
  final data = ByteData.sublistView(glb);
  final jsonLength = data.getUint32(12, Endian.little);
  final json = jsonDecode(utf8.decode(glb.sublist(20, 20 + jsonLength))) as Map<String, dynamic>;
  final binStart = 20 + jsonLength + 8;
  final accessors = (json['accessors'] as List).cast<Map<String, dynamic>>();
  final views = (json['bufferViews'] as List).cast<Map<String, dynamic>>();
  const width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4};
  List<num> read(int accessor) {
    final a = accessors[accessor];
    final view = views[a['bufferView'] as int];
    final offset = binStart + (view['byteOffset'] as int? ?? 0) + (a['byteOffset'] as int? ?? 0);
    final n = (a['count'] as int) * width[a['type']]!;
    return switch (a['componentType'] as int) {
      5126 => [for (var i = 0; i < n; i++) data.getFloat32(offset + i * 4, Endian.little)],
      5123 => [for (var i = 0; i < n; i++) data.getUint16(offset + i * 2, Endian.little)],
      _ => [for (var i = 0; i < n; i++) data.getUint32(offset + i * 4, Endian.little)],
    };
  }

  final primitive = ((json['meshes'] as List).first['primitives'] as List).first as Map<String, dynamic>;
  final attributes = (primitive['attributes'] as Map).cast<String, int>();
  return (
    attributes: {for (final e in attributes.entries) e.key: [for (final v in read(e.value)) v.toDouble()]},
    components: {for (final e in attributes.entries) e.key: width[accessors[e.value]['type']]!},
    indices: [for (final v in read(primitive['indices'] as int)) v.toInt()],
  );
}

/// `Primitive` actors (the template test rooms, and "spawn a cube") carry a
/// shape and a size rather than an imported model. The editor still needs real
/// geometry to draw, so the shape is turned into a real glTF binary that goes
/// through the same parser and the same renderer as any imported mesh.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a box GLB parses back with the requested size and colour', () async {
    final bytes = PrimitiveGlbFactory.build(
      shape: 'box',
      sizeX: 2.0,
      sizeY: 1.0,
      sizeZ: 4.0,
      colorHex: '#FF8800',
    );
    // A real glTF binary container, not a blob we invented.
    expect(bytes.length, greaterThan(12));
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'glTF');

    final mesh = await GlbParserService.parseGlb(bytes);
    expect(mesh, isNotNull);
    // The parser hands back de-indexed triangles, so a box is 12 triangles of
    // 3 vertices; the 24 split vertices it was authored with are expanded.
    expect(mesh!.indices.length, 36);
    expect(mesh.positions.length ~/ 3, 36);
    expect(mesh.minBounds[0], closeTo(-1.0, 1e-5));
    expect(mesh.maxBounds[0], closeTo(1.0, 1e-5));
    expect(mesh.minBounds[1], closeTo(-0.5, 1e-5));
    expect(mesh.maxBounds[1], closeTo(0.5, 1e-5));
    expect(mesh.minBounds[2], closeTo(-2.0, 1e-5));
    expect(mesh.maxBounds[2], closeTo(2.0, 1e-5));
    // The requested colour rides on the primitive's material slot, which is
    // where the renderer reads it from.
    expect(mesh.subPrimitives, isNotEmpty);
    final slot = mesh.subPrimitives.first.baseColor;
    expect(slot[0], closeTo(1.0, 0.02));
    expect(slot[1], closeTo(0x88 / 255, 0.02));
    expect(slot[2], closeTo(0.1, 0.02), reason: 'the parser clamps a channel to 0.1');
    expect(mesh.rawPayload, isNotNull, reason: 'the viewport feeds rawPayload to Filament');
  });

  test('every shape produces parseable geometry with sane winding and normals', () async {
    for (final shape in ['box', 'plane', 'sphere', 'cylinder']) {
      final mesh = await GlbParserService.parseGlb(
        PrimitiveGlbFactory.build(shape: shape, sizeX: 1.0, sizeY: 1.0, sizeZ: 1.0),
      );
      expect(mesh, isNotNull, reason: '$shape must parse');
      expect(mesh!.positions.length, greaterThan(0), reason: '$shape has vertices');
      expect(mesh.indices.length % 3, 0, reason: '$shape is a triangle list');
      expect(mesh.indices.length, greaterThan(0));
      final maxIndex = mesh.indices.reduce((a, b) => a > b ? a : b);
      expect(maxIndex, lessThan(mesh.positions.length ~/ 3), reason: '$shape indices stay in range');
      // Bounds are centred on the origin so the actor transform places it.
      expect(mesh.minBounds[1], lessThanOrEqualTo(0.0));
      expect(mesh.maxBounds[1], greaterThanOrEqualTo(0.0));
    }
  });

  test('a plane is flat and a sphere is round', () async {
    final plane = (await GlbParserService.parseGlb(
      PrimitiveGlbFactory.build(shape: 'plane', sizeX: 10.0, sizeY: 1.0, sizeZ: 10.0),
    ))!;
    expect(plane.maxBounds[1] - plane.minBounds[1], closeTo(0.0, 1e-6), reason: 'no thickness');
    expect(plane.maxBounds[0] - plane.minBounds[0], closeTo(10.0, 1e-5));

    final sphere = (await GlbParserService.parseGlb(
      PrimitiveGlbFactory.build(shape: 'sphere', sizeX: 2.0, sizeY: 2.0, sizeZ: 2.0),
    ))!;
    expect(sphere.maxBounds[0] - sphere.minBounds[0], closeTo(2.0, 0.05));
    expect(sphere.maxBounds[1] - sphere.minBounds[1], closeTo(2.0, 0.05));
    expect(sphere.maxBounds[2] - sphere.minBounds[2], closeTo(2.0, 0.05));
  });

  test('an unknown shape falls back to a box rather than throwing', () async {
    final mesh = await GlbParserService.parseGlb(
      PrimitiveGlbFactory.build(shape: 'dodecahedron', sizeX: 1.0, sizeY: 1.0, sizeZ: 1.0),
    );
    expect(mesh, isNotNull);
    expect(mesh!.indices.length, 36);
  });

  test('the same request produces byte-identical output', () {
    final a = PrimitiveGlbFactory.build(shape: 'cylinder', sizeX: 1.5, sizeY: 3.0, sizeZ: 1.5);
    final b = PrimitiveGlbFactory.build(shape: 'cylinder', sizeX: 1.5, sizeY: 3.0, sizeZ: 1.5);
    expect(a, b, reason: 'deterministic, so the editor can cache by shape+size');
  });

  group('texture coordinates and tangents', () {
    const shapes = ['box', 'plane', 'sphere', 'cylinder'];

    Vector3 v3(List<double> a, int i) => Vector3(a[i * 3], a[i * 3 + 1], a[i * 3 + 2]);

    test('every shape carries TEXCOORD_0 in 0..1 and a unit TANGENT with handedness', () {
      for (final shape in shapes) {
        final glb = _readGlb(PrimitiveGlbFactory.build(shape: shape, sizeX: 200.0, sizeY: 100.0, sizeZ: 300.0));
        final count = glb.attributes['POSITION']!.length ~/ 3;
        final uv = glb.attributes['TEXCOORD_0'];
        final tangent = glb.attributes['TANGENT'];
        expect(uv, isNotNull, reason: '$shape: without TEXCOORD_0 every vertex samples one texel');
        expect(tangent, isNotNull, reason: '$shape: a normal map needs tangents');
        expect(glb.components['TEXCOORD_0'], 2);
        expect(glb.components['TANGENT'], 4);
        expect(uv!.length, count * 2, reason: shape);
        expect(tangent!.length, count * 4, reason: shape);
        expect(uv.every((c) => c >= 0.0 && c <= 1.0), isTrue, reason: '$shape UVs stay in 0..1');
        final us = [for (var i = 0; i < count; i++) uv[i * 2]];
        final vs = [for (var i = 0; i < count; i++) uv[i * 2 + 1]];
        expect(us.reduce(math.min), 0.0, reason: '$shape spans the whole texture');
        expect(us.reduce(math.max), 1.0, reason: shape);
        expect(vs.reduce(math.min), 0.0, reason: shape);
        expect(vs.reduce(math.max), 1.0, reason: shape);
        final normals = glb.attributes['NORMAL']!;
        for (var i = 0; i < count; i++) {
          final t = Vector3(tangent[i * 4], tangent[i * 4 + 1], tangent[i * 4 + 2]);
          expect(t.length, closeTo(1.0, 1e-4), reason: '$shape tangent $i is unit length');
          expect(t.dot(v3(normals, i)).abs(), lessThan(1e-4), reason: '$shape tangent $i lies in the surface');
          expect(tangent[i * 4 + 3].abs(), 1.0, reason: '$shape tangent w is the bitangent sign');
        }
      }
    });

    test('each box face maps the whole texture, upright, seen from outside', () {
      final glb = _readGlb(PrimitiveGlbFactory.build(shape: 'box', sizeX: 100.0, sizeY: 100.0, sizeZ: 100.0));
      final uv = glb.attributes['TEXCOORD_0']!;
      final normals = glb.attributes['NORMAL']!;
      final positions = glb.attributes['POSITION']!;
      expect(positions.length ~/ 3, 24, reason: 'four split vertices per face');
      for (var face = 0; face < 6; face++) {
        final corners = {for (var k = 0; k < 4; k++) '${uv[(face * 4 + k) * 2]},${uv[(face * 4 + k) * 2 + 1]}'};
        expect(corners, {'0.0,0.0', '1.0,0.0', '1.0,1.0', '0.0,1.0'}, reason: 'face $face uses the full 0..1 square');
        final n = v3(normals, face * 4);
        // Side faces: glTF's v runs down the image, so v = 0 is the top.
        if (n.y.abs() < 0.5) {
          for (var k = 0; k < 4; k++) {
            final i = face * 4 + k;
            expect(uv[i * 2 + 1], positions[i * 3 + 1] > 0 ? 0.0 : 1.0, reason: 'face $face: the image top is up');
          }
        }
      }
    });

    test('triangles face outwards and the texture is not mirrored on any shape', () {
      for (final shape in shapes) {
        final glb = _readGlb(PrimitiveGlbFactory.build(shape: shape, sizeX: 100.0, sizeY: 100.0, sizeZ: 100.0));
        final p = glb.attributes['POSITION']!;
        final n = glb.attributes['NORMAL']!;
        final uv = glb.attributes['TEXCOORD_0']!;
        final t = glb.attributes['TANGENT']!;
        var checked = 0;
        for (var k = 0; k < glb.indices.length; k += 3) {
          final i0 = glb.indices[k], i1 = glb.indices[k + 1], i2 = glb.indices[k + 2];
          final e1 = v3(p, i1) - v3(p, i0);
          final e2 = v3(p, i2) - v3(p, i0);
          final face = e1.cross(e2);
          if (face.length < 1e-6) continue; // a pole's collapsed triangle
          final normal = (v3(n, i0) + v3(n, i1) + v3(n, i2)).normalized();
          expect(face.normalized().dot(normal), greaterThan(0.0),
              reason: '$shape triangle ${k ~/ 3} is wound counter-clockwise seen from outside');
          // The triangle's UV gradients: dP/du (image right) and dP/dv (image down).
          final du1 = uv[i1 * 2] - uv[i0 * 2], dv1 = uv[i1 * 2 + 1] - uv[i0 * 2 + 1];
          final du2 = uv[i2 * 2] - uv[i0 * 2], dv2 = uv[i2 * 2 + 1] - uv[i0 * 2 + 1];
          final det = du1 * dv2 - du2 * dv1;
          if (det.abs() < 1e-9) continue;
          final dPdu = (e1 * dv2 - e2 * dv1) / det;
          final dPdv = (e2 * du1 - e1 * du2) / det;
          // Right × down points into the surface when the image reads the right way round from outside.
          expect(dPdu.cross(dPdv).dot(normal), lessThan(0.0), reason: '$shape triangle ${k ~/ 3} shows the texture mirrored');
          for (final i in [i0, i1, i2]) {
            final tangent = Vector3(t[i * 4], t[i * 4 + 1], t[i * 4 + 2]);
            expect(tangent.dot(dPdu), greaterThan(0.0), reason: '$shape vertex $i: the tangent follows +u');
            // glTF: bitangent = cross(normal, tangent) * w, pointing up the image (towards v = 0).
            final bitangent = v3(n, i).cross(tangent) * t[i * 4 + 3];
            expect(bitangent.dot(dPdv), lessThan(0.0), reason: '$shape vertex $i: the bitangent points up the image');
          }
          checked++;
        }
        expect(checked, greaterThan(0), reason: shape);
      }
    });
  });
}
