import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/src/pose_search/pose_math.dart';
import 'package:lumina_core/src/services/glb_animation_merger.dart';

/// One animated property of one node: key times and values as the glTF
/// sampler stores them.
class LuminaGlbChannel {
  /// 0 translation, 1 rotation, 2 scale.
  final int path;
  final Float32List times;
  final Float32List values;

  /// `LINEAR`, `STEP` or `CUBICSPLINE`.
  final String interpolation;

  const LuminaGlbChannel(this.path, this.times, this.values, this.interpolation);

  int get width => path == 1 ? 4 : 3;
}

/// A glTF animation of the mesh: its length and channels by node.
class LuminaGlbClip {
  final String name;
  final double duration;

  /// Per node: its channels (empty for an unanimated node).
  final List<List<LuminaGlbChannel>> channelsByNode;

  const LuminaGlbClip(this.name, this.duration, this.channelsByNode);
}

/// Reads a skinned GLB's node hierarchy and every glTF animation in it, and
/// samples the clips on the CPU the way gltfio's animator does (clamped ends,
/// linear / slerp between keys, step holds; a cubic spline is evaluated
/// linearly between its values).
///
/// Poses are flat [LuminaPoseMath] TRS arrays (10 doubles per node, in node
/// order); world transforms are affines (12 doubles per node).
class LuminaGlbAnimationSampler {
  final List<String> nodeNames;
  final Int32List parents;

  /// Rest TRS of every node.
  final Float64List rest;

  /// Nodes in an order where a parent comes before its children.
  final Int32List order;

  /// The first skin's joints, in skin order (the order a gltfio instance
  /// lists its joint entities).
  final List<int> skinJoints;

  /// Every skin's joints.
  final Set<int> joints;

  final List<LuminaGlbClip> clips;
  final Map<String, int> _clipIndex;

  /// For every node its left/right counterpart by name (itself when none).
  final Int32List mirror;

  LuminaGlbAnimationSampler._(this.nodeNames, this.parents, this.rest, this.order, this.skinJoints, this.joints,
      this.clips, this._clipIndex, this.mirror);

  int get nodeCount => nodeNames.length;

  int indexOfNode(String name) => nodeNames.indexOf(name);

  int? clipIndex(String name) => _clipIndex[name];

  /// The topmost skin joint (no joint above it).
  int? get topJoint {
    for (final i in order) {
      if (!joints.contains(i)) continue;
      var p = parents[i];
      var nested = false;
      while (p >= 0) {
        if (joints.contains(p)) {
          nested = true;
          break;
        }
        p = parents[p];
      }
      if (!nested) return i;
    }
    return null;
  }

  factory LuminaGlbAnimationSampler.fromGlb(Uint8List glb) {
    final doc = GlbDocument.parse(glb, label: 'mesh');
    final json = doc.json;
    final nodes = ((json['nodes'] as List?) ?? const []).cast<Map>();
    final n = nodes.length;
    final parents = Int32List(n)..fillRange(0, n, -1);
    for (var i = 0; i < n; i++) {
      for (final c in (nodes[i]['children'] as List?) ?? const []) {
        parents[c as int] = i;
      }
    }
    final rest = Float64List(n * LuminaPoseMath.trsStride);
    final scratch = Float64List(LuminaPoseMath.affineStride);
    for (var i = 0; i < n; i++) {
      final o = i * LuminaPoseMath.trsStride;
      final node = nodes[i];
      final matrix = node['matrix'] as List?;
      if (matrix != null && matrix.length == 16) {
        final m = [for (final v in matrix) (v as num).toDouble()];
        scratch.setAll(0, [m[0], m[1], m[2], m[4], m[5], m[6], m[8], m[9], m[10], m[12], m[13], m[14]]);
        LuminaPoseMath.decomposeAffine(scratch, 0, rest, o);
        continue;
      }
      List<double> read(String key, List<double> fallback) {
        final v = node[key] as List?;
        return v == null ? fallback : [for (final x in v) (x as num).toDouble()];
      }

      rest.setAll(o, [
        ...read('translation', const [0, 0, 0]),
        ...read('rotation', const [0, 0, 0, 1]),
        ...read('scale', const [1, 1, 1]),
      ]);
    }
    final order = <int>[];
    final seen = <int>{};
    void visit(int i) {
      if (!seen.add(i)) return;
      order.add(i);
      for (final c in (nodes[i]['children'] as List?) ?? const []) {
        visit(c as int);
      }
    }

    for (var i = 0; i < n; i++) {
      if (parents[i] == -1) visit(i);
    }
    final skins = (json['skins'] as List?) ?? const [];
    final skinJoints = skins.isEmpty
        ? <int>[]
        : [for (final j in ((skins.first as Map)['joints'] as List?) ?? const []) j as int];
    final joints = <int>{
      for (final s in skins)
        for (final j in ((s as Map)['joints'] as List?) ?? const []) j as int,
    };
    final names = [for (var i = 0; i < n; i++) (nodes[i]['name'] as String?) ?? 'node_$i'];

    final clips = <LuminaGlbClip>[];
    final clipIndex = <String, int>{};
    final animations = (json['animations'] as List?) ?? const [];
    final reader = _AccessorReader(doc);
    for (var a = 0; a < animations.length; a++) {
      final anim = animations[a] as Map;
      final name = (anim['name'] as String?) ?? 'Animation$a';
      final samplers = ((anim['samplers'] as List?) ?? const []).cast<Map>();
      final byNode = List<List<LuminaGlbChannel>>.generate(n, (_) => <LuminaGlbChannel>[]);
      var duration = 0.0;
      for (final c in ((anim['channels'] as List?) ?? const []).cast<Map>()) {
        final target = c['target'] as Map;
        final node = target['node'] as int?;
        final path = switch (target['path']) { 'translation' => 0, 'rotation' => 1, 'scale' => 2, _ => -1 };
        if (node == null || path < 0 || node >= n) continue;
        final s = samplers[c['sampler'] as int];
        final times = reader.floats(s['input'] as int);
        final values = reader.floats(s['output'] as int);
        if (times.isEmpty) continue;
        duration = math.max(duration, times.last);
        byNode[node].add(LuminaGlbChannel(path, times, values, (s['interpolation'] as String?) ?? 'LINEAR'));
      }
      clipIndex.putIfAbsent(name, () => clips.length);
      clips.add(LuminaGlbClip(name, duration, byNode));
    }
    return LuminaGlbAnimationSampler._(
        names, parents, rest, Int32List.fromList(order), skinJoints, joints, clips, clipIndex, _mirrorTable(names, joints));
  }

  /// Counterparts by name: `_l`/`_r` (suffix or infix), `l_`/`r_` prefix,
  /// `Left`/`Right`, `left`/`right`.
  static Int32List _mirrorTable(List<String> names, Set<int> joints) {
    final table = Int32List.fromList(List<int>.generate(names.length, (i) => i));
    final index = <String, int>{for (var i = 0; i < names.length; i++) names[i]: i};
    const swaps = [('_l', '_r'), ('_L', '_R'), ('Left', 'Right'), ('left', 'right')];
    String? counterpart(String name) {
      for (final (a, b) in swaps) {
        if (name.endsWith(a)) return '${name.substring(0, name.length - a.length)}$b';
        if (name.endsWith(b)) return '${name.substring(0, name.length - b.length)}$a';
        if (name.contains('${a}_')) return name.replaceFirst('${a}_', '${b}_');
        if (name.contains('${b}_')) return name.replaceFirst('${b}_', '${a}_');
        if (name.contains(a) && a.length > 2) return name.replaceFirst(a, b);
        if (name.contains(b) && b.length > 2) return name.replaceFirst(b, a);
      }
      if (name.startsWith('l_')) return 'r_${name.substring(2)}';
      if (name.startsWith('r_')) return 'l_${name.substring(2)}';
      return null;
    }

    for (var i = 0; i < names.length; i++) {
      final other = counterpart(names[i]);
      final j = other == null ? null : index[other];
      if (j != null) table[i] = j;
    }
    return table;
  }

  /// Every node's local TRS of [clip] at [time] into [out] (the rest pose
  /// where a node has no channel). [time] is clamped to the keys.
  void sampleLocal(int clip, double time, Float64List out) {
    out.setRange(0, rest.length, rest);
    final c = clips[clip];
    for (var node = 0; node < nodeCount; node++) {
      final channels = c.channelsByNode[node];
      if (channels.isEmpty) continue;
      for (final ch in channels) {
        _sampleChannel(ch, time, out, node * LuminaPoseMath.trsStride + (ch.path == 0 ? 0 : (ch.path == 1 ? 3 : 7)));
      }
    }
  }

  /// [sampleLocal] for [node] only (its rest TRS where it has no channel).
  void sampleNodeLocal(int clip, int node, double time, Float64List out, int oo) {
    out.setRange(oo, oo + LuminaPoseMath.trsStride, rest, node * LuminaPoseMath.trsStride);
    for (final ch in clips[clip].channelsByNode[node]) {
      _sampleChannel(ch, time, out, oo + (ch.path == 0 ? 0 : (ch.path == 1 ? 3 : 7)));
    }
  }

  static final Float64List _qa = Float64List(4), _qb = Float64List(4);

  static void _sampleChannel(LuminaGlbChannel ch, double time, Float64List out, int oo) {
    final times = ch.times;
    final w = ch.width;
    final cubic = ch.interpolation == 'CUBICSPLINE';
    final stride = cubic ? w * 3 : w;
    final valueOffset = cubic ? w : 0;
    final last = times.length - 1;
    int i0, i1;
    double alpha;
    if (time <= times[0]) {
      i0 = i1 = 0;
      alpha = 0;
    } else if (time >= times[last]) {
      i0 = i1 = last;
      alpha = 0;
    } else {
      var lo = 0, hi = last;
      while (hi - lo > 1) {
        final mid = (lo + hi) >> 1;
        if (times[mid] <= time) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      i0 = lo;
      i1 = hi;
      final span = times[i1] - times[i0];
      alpha = span > 1e-9 ? (time - times[i0]) / span : 0.0;
      if (ch.interpolation == 'STEP') alpha = 0;
    }
    final v = ch.values;
    final a = i0 * stride + valueOffset, b = i1 * stride + valueOffset;
    if (b + w > v.length) return;
    if (w == 4) {
      for (var k = 0; k < 4; k++) {
        _qa[k] = v[a + k];
        _qb[k] = v[b + k];
      }
      LuminaPoseMath.slerp(_qa, 0, _qb, 0, alpha, out, oo);
    } else {
      for (var k = 0; k < 3; k++) {
        out[oo + k] = v[a + k] + (v[b + k] - v[a + k]) * alpha;
      }
    }
  }

  /// World affines of every node for the local TRS pose [local] into [out]
  /// (`nodeCount * 12`).
  void world(Float64List local, Float64List out) {
    final tmp = _tmpAffine;
    for (final node in order) {
      final p = parents[node];
      final o = node * LuminaPoseMath.affineStride;
      if (p < 0) {
        LuminaPoseMath.composeTrs(local, node * LuminaPoseMath.trsStride, out, o);
      } else {
        LuminaPoseMath.composeTrs(local, node * LuminaPoseMath.trsStride, tmp, 0);
        LuminaPoseMath.multiplyAffine(out, p * LuminaPoseMath.affineStride, tmp, 0, out, o);
      }
    }
  }

  final Float64List _tmpAffine = Float64List(LuminaPoseMath.affineStride);

  /// The chain of [node] and its ancestors, root first.
  List<int> chainOf(int node) {
    final chain = <int>[];
    var n = node;
    while (n >= 0) {
      chain.add(n);
      n = parents[n];
    }
    return chain.reversed.toList();
  }

  /// [node]'s world affine for [clip] at [time] (only its chain is sampled),
  /// into [out]/[oo].
  void nodeWorld(int clip, List<int> chain, double time, Float64List out, int oo) {
    final trs = _chainTrs;
    final affine = _chainAffine;
    final acc = _chainAcc;
    for (var k = 0; k < chain.length; k++) {
      sampleNodeLocal(clip, chain[k], time, trs, 0);
      if (k == 0) {
        LuminaPoseMath.composeTrs(trs, 0, acc, 0);
      } else {
        LuminaPoseMath.composeTrs(trs, 0, affine, 0);
        final copy = Float64List.fromList(acc);
        LuminaPoseMath.multiplyAffine(copy, 0, affine, 0, acc, 0);
      }
    }
    out.setRange(oo, oo + LuminaPoseMath.affineStride, acc);
  }

  final Float64List _chainTrs = Float64List(LuminaPoseMath.trsStride);
  final Float64List _chainAffine = Float64List(LuminaPoseMath.affineStride);
  final Float64List _chainAcc = Float64List(LuminaPoseMath.affineStride);

  /// World affines of the rest pose.
  Float64List restWorld() {
    final out = Float64List(nodeCount * LuminaPoseMath.affineStride);
    world(rest, out);
    return out;
  }
}

/// Reads float accessors (and normalized integer ones) from a GLB.
class _AccessorReader {
  final GlbDocument doc;
  final List accessors;
  final List bufferViews;
  final ByteData data;

  _AccessorReader(this.doc)
      : accessors = (doc.json['accessors'] as List?) ?? const [],
        bufferViews = (doc.json['bufferViews'] as List?) ?? const [],
        data = ByteData.sublistView(doc.bin);

  Float32List floats(int index) {
    final acc = accessors[index] as Map;
    final count = acc['count'] as int;
    final width = const {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[acc['type']] ?? 1;
    final out = Float32List(count * width);
    final bvIndex = acc['bufferView'] as int?;
    if (bvIndex == null) return out;
    final bv = bufferViews[bvIndex] as Map;
    final type = acc['componentType'] as int;
    final size = switch (type) { 5126 => 4, 5122 || 5123 => 2, 5120 || 5121 => 1, _ => 4 };
    final stride = (bv['byteStride'] as int?) ?? size * width;
    final start = ((bv['byteOffset'] as int?) ?? 0) + ((acc['byteOffset'] as int?) ?? 0);
    for (var i = 0; i < count; i++) {
      for (var k = 0; k < width; k++) {
        final o = start + i * stride + k * size;
        out[i * width + k] = switch (type) {
          5126 => data.getFloat32(o, Endian.little),
          5122 => math.max(data.getInt16(o, Endian.little) / 32767.0, -1.0),
          5123 => data.getUint16(o, Endian.little) / 65535.0,
          5120 => math.max(data.getInt8(o) / 127.0, -1.0),
          5121 => data.getUint8(o) / 255.0,
          _ => 0.0,
        };
      }
    }
    return out;
  }
}
