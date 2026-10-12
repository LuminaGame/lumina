import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// A packed motion a plugin process writes (`KMO1`): `frames × joints × 10`
/// local transforms (`[x, y, z, qx, qy, qz, qw, sx, sy, sz]`, the mesh's glTF
/// frame) at [frameRate], the joints in the target mesh's skeleton order
/// ([skeletonOrder]). A Viewport plays it on a skeletal node with
/// `Viewport Play Animation File`.
class LuminaViewportMotion {
  LuminaViewportMotion({required this.frames, required this.joints, required this.frameRate, required this.data});

  /// The file's magic.
  static const String packedMagic = 'KMO1';
  static const int _header = 16;

  final int frames;
  final int joints;
  final double frameRate;
  final Float32List data;

  /// The motion's length in seconds.
  double get duration => frames <= 1 ? 0.0 : (frames - 1) / frameRate;

  /// Whether [bytes] start with the packed motion magic.
  static bool isPacked(Uint8List bytes) => bytes.length >= 4 && String.fromCharCodes(bytes.sublist(0, 4)) == packedMagic;

  /// Decodes a packed motion file; throws [FormatException] for anything else.
  static LuminaViewportMotion decode(Uint8List bytes) {
    if (!isPacked(bytes) || bytes.length < _header) throw const FormatException('not a packed motion file (KMO1)');
    final h = ByteData.sublistView(bytes, 0, _header);
    final frames = h.getInt32(4, Endian.little);
    final joints = h.getInt32(8, Endian.little);
    final fps = h.getFloat32(12, Endian.little);
    if (frames < 0 || joints < 0) throw const FormatException('negative motion size');
    final count = frames * joints * 10;
    if (bytes.length != _header + count * 4) {
      throw FormatException('motion file has ${bytes.length} bytes, expected ${_header + count * 4}');
    }
    final data = Float32List(count);
    final view = ByteData.sublistView(bytes, _header);
    for (var i = 0; i < count; i++) {
      data[i] = view.getFloat32(i * 4, Endian.little);
    }
    return LuminaViewportMotion(frames: frames, joints: joints, frameRate: fps > 0 ? fps : 30.0, data: data);
  }

  /// Encodes [motion] (what a plugin process writes; tests).
  static Uint8List encode(LuminaViewportMotion motion) {
    final out = ByteData(_header + motion.data.length * 4);
    for (var i = 0; i < 4; i++) {
      out.setUint8(i, packedMagic.codeUnitAt(i));
    }
    out
      ..setInt32(4, motion.frames, Endian.little)
      ..setInt32(8, motion.joints, Endian.little)
      ..setFloat32(12, motion.frameRate, Endian.little);
    for (var i = 0; i < motion.data.length; i++) {
      out.setFloat32(_header + i * 4, motion.data[i], Endian.little);
    }
    return out.buffer.asUint8List();
  }

  /// The pose at [seconds] (frame-blended linearly, rotations normalised):
  /// joint name → 10 values, the names from [order].
  Map<String, List<double>> poseAt(double seconds, List<String> order, {bool loop = true}) {
    if (frames == 0 || joints == 0) return const {};
    var t = seconds * frameRate;
    final last = (frames - 1).toDouble();
    if (loop && last > 0) {
      t = t % (last + 1);
    } else {
      t = t.clamp(0.0, last);
    }
    final f0 = t.floor().clamp(0, frames - 1);
    final f1 = loop ? (f0 + 1) % frames : (f0 + 1).clamp(0, frames - 1);
    final a = t - f0;
    final out = <String, List<double>>{};
    for (var j = 0; j < joints && j < order.length; j++) {
      final o0 = (f0 * joints + j) * 10;
      final o1 = (f1 * joints + j) * 10;
      final v = List<double>.generate(10, (k) => data[o0 + k] * (1 - a) + data[o1 + k] * a);
      // Quaternion: shortest path, renormalised.
      final dot = data[o0 + 3] * data[o1 + 3] + data[o0 + 4] * data[o1 + 4] + data[o0 + 5] * data[o1 + 5] + data[o0 + 6] * data[o1 + 6];
      if (dot < 0) {
        for (var k = 3; k < 7; k++) {
          v[k] = data[o0 + k] * (1 - a) - data[o1 + k] * a;
        }
      }
      final len = v[3] * v[3] + v[4] * v[4] + v[5] * v[5] + v[6] * v[6];
      if (len > 1e-12) {
        final inv = 1 / math.sqrt(len);
        for (var k = 3; k < 7; k++) {
          v[k] *= inv;
        }
      }
      out[order[j]] = v;
    }
    return out;
  }

  /// The skeleton order of a mesh GLB's packed motions: the joints of every
  /// skin and their ancestors, by glTF node index, as node names (a
  /// MetaHuman's first skin is only part of the head; its arms and legs are
  /// in later skins or are ancestors no skin lists).
  static List<String> skeletonOrder(Uint8List glb) => LuminaViewportSkeleton.parse(glb).names;

  static Map? _json(Uint8List glb) {
    if (glb.length < 20) return null;
    final d = ByteData.sublistView(glb);
    if (d.getUint32(0, Endian.little) != 0x46546C67) return null;
    final length = d.getUint32(12, Endian.little);
    if (d.getUint32(16, Endian.little) != 0x4E4F534A || 20 + length > glb.length) return null;
    final decoded = jsonDecode(utf8.decode(glb.sublist(20, 20 + length)));
    return decoded is Map ? decoded : null;
  }
}

/// The skeleton a Viewport poses on a skeletal mesh, read from its GLB:
/// the joints of every skin and their ancestors in glTF node order
/// ([LuminaViewportMotion.skeletonOrder]), where each joint's entity is
/// found on an instance ([slots]: its skin and index in that skin, null for
/// an ancestor no skin lists) and its parent in this list ([parents]).
class LuminaViewportSkeleton {
  const LuminaViewportSkeleton(this.names, this.slots, this.parents);

  static const LuminaViewportSkeleton empty = LuminaViewportSkeleton([], [], []);

  final List<String> names;
  final List<(int, int)?> slots;
  final List<int> parents;

  int get length => names.length;

  static LuminaViewportSkeleton parse(Uint8List glb) {
    final json = LuminaViewportMotion._json(glb);
    if (json == null) return empty;
    final nodes = json['nodes'];
    final skins = json['skins'];
    if (nodes is! List || skins is! List || skins.isEmpty) return empty;
    final parent = List<int>.filled(nodes.length, -1);
    for (var i = 0; i < nodes.length; i++) {
      final c = nodes[i] is Map ? (nodes[i] as Map)['children'] : null;
      if (c is List) {
        for (final k in c) {
          if (k is int && k < parent.length) parent[k] = i;
        }
      }
    }
    final slot = <int, (int, int)>{};
    final set = <int>{};
    for (var s = 0; s < skins.length; s++) {
      final joints = skins[s] is Map ? (skins[s] as Map)['joints'] : null;
      if (joints is! List) continue;
      for (var k = 0; k < joints.length; k++) {
        final j = joints[k];
        if (j is! int || j < 0 || j >= nodes.length) continue;
        slot.putIfAbsent(j, () => (s, k));
        set.add(j);
        for (var p = parent[j]; p >= 0 && set.add(p); p = parent[p]) {}
      }
    }
    final ordered = set.toList()..sort();
    final index = {for (var i = 0; i < ordered.length; i++) ordered[i]: i};
    return LuminaViewportSkeleton(
      [for (final i in ordered) nodes[i] is Map ? '${(nodes[i] as Map)['name'] ?? 'joint_$i'}' : 'joint_$i'],
      [for (final i in ordered) slot[i]],
      [for (final i in ordered) index[parent[i]] ?? -1],
    );
  }

  /// The entity of each joint on an instance: a skin joint from
  /// [jointsAt] (a skin's joint entities), an ancestor as the parent
  /// ([parentOf]) of one of its children; 0 where none resolves.
  List<int> entities(List<int> Function(int skin) jointsAt, int Function(int entity) parentOf) {
    final skins = <int, List<int>>{};
    final out = List<int>.filled(length, 0);
    for (var i = 0; i < length; i++) {
      final s = slots[i];
      if (s == null) continue;
      final list = skins[s.$1] ??= jointsAt(s.$1);
      if (s.$2 < list.length) out[i] = list[s.$2];
    }
    // Ancestors from their children, deepest first (repeat until stable).
    for (var changed = true; changed;) {
      changed = false;
      for (var i = 0; i < length; i++) {
        final p = parents[i];
        if (p < 0 || out[p] != 0 || out[i] == 0) continue;
        out[p] = parentOf(out[i]);
        if (out[p] != 0) changed = true;
      }
    }
    return out;
  }
}
