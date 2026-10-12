import 'dart:convert';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

/// The triangles of a GLB for a wireframe: every triangle primitive of the
/// default scene with its node transforms applied (glTF space, metres), as
/// one position array and one index array.
class LuminaViewportWireSource {
  const LuminaViewportWireSource(this.positions, this.indices);

  final Float32List positions;
  final Uint32List indices;

  int get triangleCount => indices.length ~/ 3;

  /// Reads [glb]; null when it is not a GLB, has no triangles or has more
  /// than [maxTriangles] (a wireframe that dense is unreadable and heavy).
  /// Pure Dart: run it on a worker isolate.
  static LuminaViewportWireSource? read(Uint8List glb, {int maxTriangles = 3000000}) {
    if (glb.length < 20) return null;
    final data = ByteData.sublistView(glb);
    if (data.getUint32(0, Endian.little) != 0x46546C67) return null;
    Map<String, Object?>? json;
    var bin = Uint8List(0);
    var at = 12;
    while (at + 8 <= glb.length) {
      final len = data.getUint32(at, Endian.little), type = data.getUint32(at + 4, Endian.little);
      if (at + 8 + len > glb.length) return null;
      final chunk = Uint8List.sublistView(glb, at + 8, at + 8 + len);
      if (type == 0x4E4F534A) json = (jsonDecode(utf8.decode(chunk)) as Map).cast<String, Object?>();
      if (type == 0x004E4942 && bin.isEmpty) bin = chunk;
      at += 8 + len;
    }
    if (json == null) return null;
    final nodes = (json['nodes'] as List? ?? const []).cast<Map>();
    final meshes = (json['meshes'] as List? ?? const []).cast<Map>();
    final accessors = (json['accessors'] as List? ?? const []).cast<Map>();
    final views = (json['bufferViews'] as List? ?? const []).cast<Map>();
    final scenes = (json['scenes'] as List? ?? const []).cast<Map>();
    final sceneIndex = (json['scene'] as num?)?.toInt() ?? 0;
    final roots = scenes.isEmpty
        ? List<int>.generate(nodes.length, (i) => i)
        : [for (final n in (scenes[sceneIndex.clamp(0, scenes.length - 1)]['nodes'] as List? ?? const [])) (n as num).toInt()];

    // Count first, so a too-dense mesh costs no copies.
    final draws = <(Matrix4, Map)>[];
    var triangles = 0, vertices = 0;
    void visit(int index, Matrix4 parent, int depth) {
      if (index < 0 || index >= nodes.length || depth > 64) return;
      final node = nodes[index];
      final world = parent * _local(node) as Matrix4;
      final mesh = node['mesh'];
      if (mesh is num && mesh.toInt() < meshes.length) {
        for (final prim in (meshes[mesh.toInt()]['primitives'] as List? ?? const [])) {
          final p = prim as Map;
          if (((p['mode'] as num?)?.toInt() ?? 4) != 4) continue;
          final pos = (p['attributes'] as Map?)?['POSITION'];
          if (pos is! num) continue;
          final count = (accessors[pos.toInt()]['count'] as num).toInt();
          final idx = p['indices'];
          triangles += (idx is num ? (accessors[idx.toInt()]['count'] as num).toInt() : count) ~/ 3;
          vertices += count;
          draws.add((world, p));
        }
      }
      for (final c in (node['children'] as List? ?? const [])) {
        visit((c as num).toInt(), world, depth + 1);
      }
    }

    for (final r in roots) {
      visit(r, Matrix4.identity(), 0);
    }
    if (triangles == 0 || triangles > maxTriangles) return null;

    final positions = Float32List(vertices * 3);
    final indices = Uint32List(triangles * 3);
    var vBase = 0, iAt = 0;
    final v = Vector3.zero();
    final bd = ByteData.sublistView(bin);
    for (final (world, p) in draws) {
      final pos = _view(accessors[((p['attributes'] as Map)['POSITION'] as num).toInt()], views, bin);
      if (pos == null || pos.$4 != 5126) return null;
      final (start, stride, count, _) = pos;
      for (var i = 0; i < count; i++) {
        final o = start + i * stride;
        v.setValues(bd.getFloat32(o, Endian.little), bd.getFloat32(o + 4, Endian.little), bd.getFloat32(o + 8, Endian.little));
        world.transform3(v);
        positions[(vBase + i) * 3] = v.x;
        positions[(vBase + i) * 3 + 1] = v.y;
        positions[(vBase + i) * 3 + 2] = v.z;
      }
      final idx = p['indices'];
      if (idx is num) {
        final iv = _view(accessors[idx.toInt()], views, bin);
        if (iv == null) return null;
        final (s, st, n, type) = iv;
        for (var i = 0; i < n - n % 3; i++) {
          final o = s + i * st;
          final value = switch (type) {
            5121 => bd.getUint8(o),
            5123 => bd.getUint16(o, Endian.little),
            _ => bd.getUint32(o, Endian.little),
          };
          indices[iAt++] = vBase + value;
        }
      } else {
        for (var i = 0; i < count - count % 3; i++) {
          indices[iAt++] = vBase + i;
        }
      }
      vBase += count;
    }
    return LuminaViewportWireSource(positions, iAt == indices.length ? indices : Uint32List.sublistView(indices, 0, iAt));
  }

  /// Whether [glb]'s JSON names Draco mesh compression (which [read] does
  /// not decode).
  static bool usesDraco(Uint8List glb) {
    if (glb.length < 20) return false;
    final len = ByteData.sublistView(glb).getUint32(12, Endian.little);
    if (20 + len > glb.length) return false;
    return utf8.decode(Uint8List.sublistView(glb, 20, 20 + len), allowMalformed: true).contains('KHR_draco_mesh_compression');
  }

  /// (byte start, stride, count, component type) of an accessor in [bin].
  static (int, int, int, int)? _view(Map accessor, List<Map> views, Uint8List bin) {
    final viewIndex = accessor['bufferView'];
    if (viewIndex is! num || accessor['sparse'] != null) return null;
    final view = views[viewIndex.toInt()];
    final type = (accessor['componentType'] as num).toInt();
    final size = switch (type) { 5121 => 1, 5123 => 2, _ => 4 };
    final components = accessor['type'] == 'VEC3' ? 3 : 1;
    final start = ((view['byteOffset'] as num?)?.toInt() ?? 0) + ((accessor['byteOffset'] as num?)?.toInt() ?? 0);
    final stride = (view['byteStride'] as num?)?.toInt() ?? size * components;
    final count = (accessor['count'] as num).toInt();
    if (count > 0 && start + stride * (count - 1) + size * components > bin.length) return null;
    return (start, stride, count, type);
  }

  static Matrix4 _local(Map node) {
    final m = node['matrix'];
    if (m is List && m.length == 16) return Matrix4.fromList([for (final e in m) (e as num).toDouble()]);
    final t = node['translation'], r = node['rotation'], s = node['scale'];
    Vector3 v3(Object? l, double d) => l is List && l.length >= 3
        ? Vector3((l[0] as num).toDouble(), (l[1] as num).toDouble(), (l[2] as num).toDouble())
        : Vector3.all(d);
    final q = r is List && r.length >= 4
        ? Quaternion((r[0] as num).toDouble(), (r[1] as num).toDouble(), (r[2] as num).toDouble(), (r[3] as num).toDouble())
        : Quaternion.identity();
    return Matrix4.compose(v3(t, 0), q, v3(s, 1));
  }
}
