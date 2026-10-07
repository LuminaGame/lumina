import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Builds a real glTF 2.0 binary (`.glb`) for an engine primitive.
///
/// `Primitive` actors — the template test rooms, and "spawn a cube" — carry a
/// shape and a size instead of an imported model. Rather than teaching every
/// consumer a second geometry path, the shape is turned into an ordinary glTF
/// binary here, so it flows through the same parser, the same renderer, the
/// same picking and the same triangle counter as any imported mesh.
///
/// Geometry is centred on the origin and sized in world units (cm), so the actor's own
/// transform places it. Output is deterministic for a given request.
///
/// Every shape carries `TEXCOORD_0` and `TANGENT`, so a textured (or
/// normal-mapped) material assigned to it draws its texture: each box face and
/// the plane map the whole 0..1 square upright, a sphere and a cylinder wall
/// wrap it once around (u) from top (v = 0) to bottom (v = 1), and cylinder
/// caps map it as a disc. UVs follow glTF (v runs down the image); tangents
/// point along +u, with `w` making `cross(normal, tangent) * w` point up the
/// image, as glTF defines it.
class PrimitiveGlbFactory {
  const PrimitiveGlbFactory._();

  /// Segments around a sphere/cylinder. Enough to read as round in the
  /// viewport without making the editor's scene heavy.
  static const int radialSegments = 24;
  static const int sphereRings = 16;

  /// A `.glb` for [shape] (`box`, `plane`, `sphere`, `cylinder`; anything else
  /// falls back to a box) with the given extents in world units (cm) and base colour.
  static Uint8List build({
    required String shape,
    required double sizeX,
    required double sizeY,
    required double sizeZ,
    String colorHex = '#9AA3AE',
  }) {
    final geo = _geometryFor(shape, sizeX, sizeY, sizeZ);
    return _encodeGlb(geo, _parseHex(colorHex));
  }

  // --- geometry --------------------------------------------------------------

  static _Geometry _geometryFor(String shape, double sx, double sy, double sz) {
    switch (shape.toLowerCase()) {
      case 'plane':
        return _plane(sx, sz);
      case 'sphere':
        return _sphere(sx, sy, sz);
      case 'cylinder':
        return _cylinder(sx, sy, sz);
      case 'box':
      default:
        return _box(sx, sy, sz);
    }
  }

  static _Geometry _box(double sx, double sy, double sz) {
    final hx = sx / 2, hy = sy / 2, hz = sz / 2;
    final positions = <double>[];
    final normals = <double>[];
    final uvs = <double>[];
    final indices = <int>[];

    // Corners bottom-left, bottom-right, top-right, top-left as seen from
    // outside, so each face shows the whole texture upright.
    void face(List<double> a, List<double> b, List<double> c, List<double> d, List<double> n) {
      final base = positions.length ~/ 3;
      for (final v in [a, b, c, d]) {
        positions.addAll(v);
        normals.addAll(n);
      }
      uvs.addAll([0, 1, 1, 1, 1, 0, 0, 0]);
      indices.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
    }

    face([-hx, -hy, hz], [hx, -hy, hz], [hx, hy, hz], [-hx, hy, hz], [0, 0, 1]);
    face([hx, -hy, -hz], [-hx, -hy, -hz], [-hx, hy, -hz], [hx, hy, -hz], [0, 0, -1]);
    face([-hx, hy, hz], [hx, hy, hz], [hx, hy, -hz], [-hx, hy, -hz], [0, 1, 0]);
    face([-hx, -hy, -hz], [hx, -hy, -hz], [hx, -hy, hz], [-hx, -hy, hz], [0, -1, 0]);
    face([hx, -hy, hz], [hx, -hy, -hz], [hx, hy, -hz], [hx, hy, hz], [1, 0, 0]);
    face([-hx, -hy, -hz], [-hx, -hy, hz], [-hx, hy, hz], [-hx, hy, -hz], [-1, 0, 0]);

    return _Geometry(positions, normals, uvs, indices);
  }

  static _Geometry _plane(double sx, double sz) {
    final hx = sx / 2, hz = sz / 2;
    return _Geometry(
      [-hx, 0, hz, hx, 0, hz, hx, 0, -hz, -hx, 0, -hz],
      [0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0],
      // Seen from above, the image top is the far (−Z, authoring +Y) edge.
      [0, 1, 1, 1, 1, 0, 0, 0],
      [0, 1, 2, 0, 2, 3],
    );
  }

  static _Geometry _sphere(double sx, double sy, double sz) {
    final rx = sx / 2, ry = sy / 2, rz = sz / 2;
    final positions = <double>[];
    final normals = <double>[];
    final uvs = <double>[];
    final indices = <int>[];

    for (var ring = 0; ring <= sphereRings; ring++) {
      final v = ring / sphereRings;
      final phi = v * math.pi;
      for (var seg = 0; seg <= radialSegments; seg++) {
        final t = seg / radialSegments;
        final theta = t * 2 * math.pi;
        final nx = math.sin(phi) * math.cos(theta);
        final ny = math.cos(phi);
        final nz = math.sin(phi) * math.sin(theta);
        positions.addAll([nx * rx, ny * ry, nz * rz]);
        normals.addAll(_normalize(nx / (rx == 0 ? 1 : rx), ny / (ry == 0 ? 1 : ry), nz / (rz == 0 ? 1 : rz)));
        // θ grows towards the viewer's left seen from outside, so u runs
        // against it; v = 0 at the top pole.
        uvs.addAll([1 - t, v]);
      }
    }
    final stride = radialSegments + 1;
    for (var ring = 0; ring < sphereRings; ring++) {
      for (var seg = 0; seg < radialSegments; seg++) {
        final a = ring * stride + seg;
        final b = a + stride;
        // Counter-clockwise seen from outside.
        indices.addAll([a, a + 1, b, a + 1, b + 1, b]);
      }
    }
    return _Geometry(positions, normals, uvs, indices);
  }

  static _Geometry _cylinder(double sx, double sy, double sz) {
    final rx = sx / 2, rz = sz / 2, hy = sy / 2;
    final positions = <double>[];
    final normals = <double>[];
    final uvs = <double>[];
    final indices = <int>[];

    // Side wall: two rings of split vertices so the caps keep their own normals.
    // The texture wraps once around (u against θ, as on the sphere), top at v = 0.
    for (var seg = 0; seg <= radialSegments; seg++) {
      final t = seg / radialSegments;
      final theta = t * 2 * math.pi;
      final cx = math.cos(theta), cz = math.sin(theta);
      positions.addAll([cx * rx, -hy, cz * rz]);
      normals.addAll(_normalize(cx, 0, cz));
      uvs.addAll([1 - t, 1]);
      positions.addAll([cx * rx, hy, cz * rz]);
      normals.addAll(_normalize(cx, 0, cz));
      uvs.addAll([1 - t, 0]);
    }
    for (var seg = 0; seg < radialSegments; seg++) {
      final a = seg * 2;
      indices.addAll([a, a + 1, a + 2, a + 2, a + 1, a + 3]);
    }

    // Caps: the texture as a disc, upright as on the plane, seen from above
    // (top cap) or from below (bottom cap).
    for (final top in [true, false]) {
      final y = top ? hy : -hy;
      final centre = positions.length ~/ 3;
      positions.addAll([0, y, 0]);
      normals.addAll([0, top ? 1 : -1, 0]);
      uvs.addAll([0.5, 0.5]);
      final rimStart = positions.length ~/ 3;
      for (var seg = 0; seg <= radialSegments; seg++) {
        final theta = seg / radialSegments * 2 * math.pi;
        final cx = math.cos(theta), cz = math.sin(theta);
        positions.addAll([cx * rx, y, cz * rz]);
        normals.addAll([0, top ? 1 : -1, 0]);
        uvs.addAll([top ? 0.5 + cx * 0.5 : 0.5 - cx * 0.5, 0.5 + cz * 0.5]);
      }
      for (var seg = 0; seg < radialSegments; seg++) {
        final a = rimStart + seg;
        if (top) {
          indices.addAll([centre, a + 1, a]);
        } else {
          indices.addAll([centre, a, a + 1]);
        }
      }
    }
    return _Geometry(positions, normals, uvs, indices);
  }

  /// Per-vertex glTF tangents `(x, y, z, w)`: the direction of +u in the
  /// surface, from the UV gradients of the triangles around the vertex, made
  /// perpendicular to its normal; `w` is +1 when `cross(normal, tangent)`
  /// points up the image (towards v = 0), −1 on a mirrored mapping. A vertex
  /// that is only in collapsed triangles (a sphere pole) gets any tangent in
  /// its surface.
  static List<double> _tangents(_Geometry geo) {
    final count = geo.positions.length ~/ 3;
    final tan = List<double>.filled(count * 3, 0.0);
    final bit = List<double>.filled(count * 3, 0.0);
    final p = geo.positions, uv = geo.uvs;
    for (var k = 0; k + 2 < geo.indices.length; k += 3) {
      final i0 = geo.indices[k], i1 = geo.indices[k + 1], i2 = geo.indices[k + 2];
      final e1 = [for (var c = 0; c < 3; c++) p[i1 * 3 + c] - p[i0 * 3 + c]];
      final e2 = [for (var c = 0; c < 3; c++) p[i2 * 3 + c] - p[i0 * 3 + c]];
      final du1 = uv[i1 * 2] - uv[i0 * 2], dv1 = uv[i1 * 2 + 1] - uv[i0 * 2 + 1];
      final du2 = uv[i2 * 2] - uv[i0 * 2], dv2 = uv[i2 * 2 + 1] - uv[i0 * 2 + 1];
      final det = du1 * dv2 - du2 * dv1;
      if (det.abs() < 1e-12) continue;
      final r = 1.0 / det;
      for (final i in [i0, i1, i2]) {
        for (var c = 0; c < 3; c++) {
          tan[i * 3 + c] += (e1[c] * dv2 - e2[c] * dv1) * r;
          bit[i * 3 + c] += (e2[c] * du1 - e1[c] * du2) * r;
        }
      }
    }

    final out = <double>[];
    for (var i = 0; i < count; i++) {
      final n = [geo.normals[i * 3], geo.normals[i * 3 + 1], geo.normals[i * 3 + 2]];
      double dot(List<double> a, List<double> b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
      List<double> inSurface(List<double> v) {
        final d = dot(v, n);
        return [v[0] - n[0] * d, v[1] - n[1] * d, v[2] - n[2] * d];
      }

      var t = inSurface([tan[i * 3], tan[i * 3 + 1], tan[i * 3 + 2]]);
      if (dot(t, t) < 1e-12) t = inSurface(n[0].abs() < 0.9 ? [1.0, 0.0, 0.0] : [0.0, 0.0, 1.0]);
      final unit = _normalize(t[0], t[1], t[2]);
      // cross(n, t) against the accumulated dP/dv, which points down the image.
      final cx = n[1] * unit[2] - n[2] * unit[1];
      final cy = n[2] * unit[0] - n[0] * unit[2];
      final cz = n[0] * unit[1] - n[1] * unit[0];
      final w = cx * bit[i * 3] + cy * bit[i * 3 + 1] + cz * bit[i * 3 + 2] > 0 ? -1.0 : 1.0;
      out.addAll([unit[0], unit[1], unit[2], w]);
    }
    return out;
  }

  static List<double> _normalize(double x, double y, double z) {
    final len = math.sqrt(x * x + y * y + z * z);
    if (len < 1e-9) return [0, 1, 0];
    return [x / len, y / len, z / len];
  }

  static List<double> _parseHex(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length != 6) return [0.6, 0.64, 0.68];
    final value = int.tryParse(h, radix: 16);
    if (value == null) return [0.6, 0.64, 0.68];
    return [
      ((value >> 16) & 0xFF) / 255.0,
      ((value >> 8) & 0xFF) / 255.0,
      (value & 0xFF) / 255.0,
    ];
  }

  // --- glTF container --------------------------------------------------------

  static Uint8List _encodeGlb(_Geometry geo, List<double> baseColor) {
    final vertexCount = geo.positions.length ~/ 3;
    final positions = Float32List.fromList(geo.positions);
    final normals = Float32List.fromList(geo.normals);
    final tangents = Float32List.fromList(_tangents(geo));
    final uvs = Float32List.fromList(geo.uvs);
    final useShortIndices = vertexCount <= 65535;
    final indexBytes = useShortIndices
        ? Uint16List.fromList(geo.indices).buffer.asUint8List()
        : Uint32List.fromList(geo.indices).buffer.asUint8List();

    final bin = BytesBuilder();
    final posOffset = 0;
    bin.add(positions.buffer.asUint8List());
    while (bin.length % 4 != 0) {
      bin.addByte(0);
    }
    final normOffset = bin.length;
    bin.add(normals.buffer.asUint8List());
    while (bin.length % 4 != 0) {
      bin.addByte(0);
    }
    final tanOffset = bin.length;
    bin.add(tangents.buffer.asUint8List());
    final uvOffset = bin.length;
    bin.add(uvs.buffer.asUint8List());
    final idxOffset = bin.length;
    bin.add(indexBytes);
    while (bin.length % 4 != 0) {
      bin.addByte(0);
    }
    final binBytes = bin.toBytes();

    double minOf(int axis) {
      var m = double.infinity;
      for (var i = axis; i < geo.positions.length; i += 3) {
        if (geo.positions[i] < m) m = geo.positions[i];
      }
      return m == double.infinity ? 0.0 : m;
    }

    double maxOf(int axis) {
      var m = -double.infinity;
      for (var i = axis; i < geo.positions.length; i += 3) {
        if (geo.positions[i] > m) m = geo.positions[i];
      }
      return m == -double.infinity ? 0.0 : m;
    }

    final gltf = <String, dynamic>{
      'asset': {'version': '2.0', 'generator': 'lumina PrimitiveGlbFactory'},
      'scene': 0,
      'scenes': [
        {'nodes': [0]}
      ],
      'nodes': [
        {'mesh': 0, 'name': 'Primitive'}
      ],
      'meshes': [
        {
          'name': 'Primitive',
          'primitives': [
            {
              'attributes': {'POSITION': 0, 'NORMAL': 1, 'TANGENT': 2, 'TEXCOORD_0': 3},
              'indices': 4,
              'material': 0,
              'mode': 4,
            }
          ],
        }
      ],
      'materials': [
        {
          'name': 'M_Primitive',
          'pbrMetallicRoughness': {
            'baseColorFactor': [baseColor[0], baseColor[1], baseColor[2], 1.0],
            'metallicFactor': 0.0,
            'roughnessFactor': 0.85,
          },
        }
      ],
      'accessors': [
        {
          'bufferView': 0,
          'componentType': 5126,
          'count': vertexCount,
          'type': 'VEC3',
          'min': [minOf(0), minOf(1), minOf(2)],
          'max': [maxOf(0), maxOf(1), maxOf(2)],
        },
        {'bufferView': 1, 'componentType': 5126, 'count': vertexCount, 'type': 'VEC3'},
        {'bufferView': 2, 'componentType': 5126, 'count': vertexCount, 'type': 'VEC4'},
        {'bufferView': 3, 'componentType': 5126, 'count': vertexCount, 'type': 'VEC2'},
        {
          'bufferView': 4,
          'componentType': useShortIndices ? 5123 : 5125,
          'count': geo.indices.length,
          'type': 'SCALAR',
        },
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': posOffset, 'byteLength': positions.lengthInBytes, 'target': 34962},
        {'buffer': 0, 'byteOffset': normOffset, 'byteLength': normals.lengthInBytes, 'target': 34962},
        {'buffer': 0, 'byteOffset': tanOffset, 'byteLength': tangents.lengthInBytes, 'target': 34962},
        {'buffer': 0, 'byteOffset': uvOffset, 'byteLength': uvs.lengthInBytes, 'target': 34962},
        {'buffer': 0, 'byteOffset': idxOffset, 'byteLength': indexBytes.length, 'target': 34963},
      ],
      'buffers': [
        {'byteLength': binBytes.length}
      ],
    };

    final jsonBuilder = BytesBuilder()..add(utf8.encode(jsonEncode(gltf)));
    while (jsonBuilder.length % 4 != 0) {
      jsonBuilder.addByte(0x20);
    }
    final jsonBytes = jsonBuilder.toBytes();

    final total = 12 + 8 + jsonBytes.length + 8 + binBytes.length;
    final out = BytesBuilder();
    final header = ByteData(12)
      ..setUint32(0, 0x46546C67, Endian.little) // "glTF"
      ..setUint32(4, 2, Endian.little)
      ..setUint32(8, total, Endian.little);
    out.add(header.buffer.asUint8List());

    final jsonHeader = ByteData(8)
      ..setUint32(0, jsonBytes.length, Endian.little)
      ..setUint32(4, 0x4E4F534A, Endian.little); // "JSON"
    out.add(jsonHeader.buffer.asUint8List());
    out.add(jsonBytes);

    final binHeader = ByteData(8)
      ..setUint32(0, binBytes.length, Endian.little)
      ..setUint32(4, 0x004E4942, Endian.little); // "BIN\0"
    out.add(binHeader.buffer.asUint8List());
    out.add(binBytes);

    return out.toBytes();
  }
}

class _Geometry {
  final List<double> positions;
  final List<double> normals;
  final List<double> uvs;
  final List<int> indices;
  const _Geometry(this.positions, this.normals, this.uvs, this.indices);
}
