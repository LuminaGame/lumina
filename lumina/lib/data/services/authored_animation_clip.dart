import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import 'glb_animation_merger.dart';

/// How a channel of an authored clip moves between its keys: the three
/// sampler interpolations of glTF 2.0.
enum AuthoredInterpolation {
  linear('LINEAR', 'Linear'),
  step('STEP', 'Step'),

  /// Written as `CUBICSPLINE` with zero in / out tangents: an ease in and out
  /// at every key. gltfio scales spline tangents by the interpolant instead of
  /// the key spacing, so flat tangents are the one cubic form it and the glTF
  /// specification evaluate the same way.
  cubic('CUBICSPLINE', 'Cubic');

  final String gltfName;
  final String label;
  const AuthoredInterpolation(this.gltfName, this.label);

  static AuthoredInterpolation fromGltf(String? name) => switch (name?.toUpperCase()) {
        'STEP' => AuthoredInterpolation.step,
        'CUBICSPLINE' || 'CUBIC' => AuthoredInterpolation.cubic,
        _ => AuthoredInterpolation.linear,
      };

  static AuthoredInterpolation fromLabel(String label) =>
      values.firstWhere((v) => v.label.toLowerCase() == label.toLowerCase() || v.name == label.toLowerCase(),
          orElse: () => AuthoredInterpolation.linear);
}

/// A bone's local transform: translation, rotation, scale (glTF node TRS).
class BoneTrs {
  final Vector3 t;
  final Quaternion r;
  final Vector3 s;

  BoneTrs(Vector3 t, Quaternion r, Vector3 s)
      : t = Vector3.copy(t),
        r = Quaternion.copy(r),
        s = Vector3.copy(s);

  BoneTrs.identity()
      : t = Vector3.zero(),
        r = Quaternion.identity(),
        s = Vector3.all(1.0);

  /// From `[tx, ty, tz, qx, qy, qz, qw, sx, sy, sz]`.
  factory BoneTrs.fromList(List<double> v) =>
      BoneTrs(Vector3(v[0], v[1], v[2]), Quaternion(v[3], v[4], v[5], v[6]), Vector3(v[7], v[8], v[9]));

  BoneTrs copy() => BoneTrs(t, r, s);

  Matrix4 toMatrix() => Matrix4.compose(t, r, s);

  /// `[tx, ty, tz, qx, qy, qz, qw, sx, sy, sz]`.
  List<double> toList() => [t.x, t.y, t.z, r.x, r.y, r.z, r.w, s.x, s.y, s.z];

  /// The channel [path]'s value: 3 floats, or 4 (x, y, z, w) for rotation.
  List<double> channel(String path) => switch (path) {
        AuthoredChannel.translation => [t.x, t.y, t.z],
        AuthoredChannel.rotation => [r.x, r.y, r.z, r.w],
        _ => [s.x, s.y, s.z],
      };

  /// A copy with [path] set to [values].
  BoneTrs withChannel(String path, List<double> values) => switch (path) {
        AuthoredChannel.translation => BoneTrs(Vector3(values[0], values[1], values[2]), r, s),
        AuthoredChannel.rotation => BoneTrs(t, Quaternion(values[0], values[1], values[2], values[3])..normalize(), s),
        _ => BoneTrs(t, r, Vector3(values[0], values[1], values[2])),
      };
}

/// One animated property of one bone in an authored clip: keys at whole
/// frames, one interpolation for the channel (glTF interpolates per sampler,
/// not per key).
class AuthoredChannel {
  static const String translation = 'translation';
  static const String rotation = 'rotation';
  static const String scale = 'scale';
  static const List<String> paths = [translation, rotation, scale];

  final String path;
  AuthoredInterpolation interpolation;

  /// Frame → value (3 floats; 4 for rotation, x y z w).
  final SplayTreeMap<int, List<double>> keys;

  AuthoredChannel(this.path, {this.interpolation = AuthoredInterpolation.linear, Map<int, List<double>>? keys})
      : keys = SplayTreeMap<int, List<double>>() {
    if (!paths.contains(path)) throw ArgumentError.value(path, 'path', 'not translation, rotation or scale');
    keys?.forEach((f, v) => this.keys[f] = List<double>.from(v));
  }

  int get width => path == rotation ? 4 : 3;

  void setKey(int frame, List<double> values) {
    if (values.length != width) {
      throw ArgumentError('a $path key needs $width values, got ${values.length}');
    }
    keys[frame] = path == rotation ? _normalized(values) : List<double>.from(values);
  }

  bool removeKey(int frame) => keys.remove(frame) != null;

  /// Moves the key at [from] to [to], replacing a key there. False when
  /// [from] has no key.
  bool moveKey(int from, int to) {
    final v = keys.remove(from);
    if (v == null) return false;
    keys[to] = v;
    return true;
  }

  AuthoredChannel copy() => AuthoredChannel(path, interpolation: interpolation, keys: keys);

  /// The value at [frame] (fractional), evaluated as gltfio's animator does:
  /// the end keys hold outside the keyed range, `STEP` holds the earlier key,
  /// `LINEAR` lerps (rotation: shortest-path slerp), `CUBICSPLINE` with flat
  /// tangents eases (rotation: component-wise, then normalised). Rotation keys
  /// are first brought into one hemisphere, as the writer stores them.
  List<double> sample(double frame) {
    if (keys.isEmpty) throw StateError('$path has no keys');
    final frames = keys.keys.toList();
    final values = path == rotation ? _alignedQuaternions(frames.map((f) => keys[f]!).toList()) : [for (final f in frames) keys[f]!];
    if (frames.length == 1 || frame <= frames.first) return List<double>.from(values.first);
    if (frame >= frames.last) return List<double>.from(values.last);
    // lower_bound: the first key at or after [frame].
    var next = 0;
    while (frames[next] < frame) {
      next++;
    }
    if (frames[next] == frame) return List<double>.from(values[next]);
    final prev = next - 1;
    final a = values[prev];
    final b = values[next];
    final u = (frame - frames[prev]) / (frames[next] - frames[prev]);
    switch (interpolation) {
      case AuthoredInterpolation.step:
        return List<double>.from(a);
      case AuthoredInterpolation.cubic:
        final tt = u * u;
        final ttt = tt * u;
        final s2 = -2 * ttt + 3 * tt;
        final s0 = 1 - s2;
        final out = [for (var i = 0; i < a.length; i++) s0 * a[i] + s2 * b[i]];
        return path == rotation ? _normalized(out) : out;
      case AuthoredInterpolation.linear:
        if (path == rotation) return slerp(a, b, u);
        return [for (var i = 0; i < a.length; i++) (1 - u) * a[i] + u * b[i]];
    }
  }

  /// Shortest-path slerp of two `x y z w` quaternions, as Filament's `slerp`.
  static List<double> slerp(List<double> p, List<double> q, double t) {
    final d = p[0] * q[0] + p[1] * q[1] + p[2] * q[2] + p[3] * q[3];
    final absd = d.abs();
    if (1 - absd < 1e-6) {
      final s = d < 0 ? -1.0 : 1.0;
      return _normalized([for (var i = 0; i < 4; i++) (1 - t) * p[i] * s + t * q[i]]);
    }
    final a = math.acos(absd.clamp(-1.0, 1.0));
    final sina = math.sqrt(1 - absd * absd);
    final s0 = math.sin(a * (1 - t)) / sina;
    final s1 = math.sin(a * t) / sina * (d < 0 ? -1.0 : 1.0);
    return _normalized([for (var i = 0; i < 4; i++) s0 * p[i] + s1 * q[i]]);
  }

  /// Consecutive quaternions flipped into the hemisphere of the one before.
  static List<List<double>> _alignedQuaternions(List<List<double>> qs) {
    final out = <List<double>>[];
    for (final q in qs) {
      if (out.isNotEmpty) {
        final p = out.last;
        final d = p[0] * q[0] + p[1] * q[1] + p[2] * q[2] + p[3] * q[3];
        if (d < 0) {
          out.add([-q[0], -q[1], -q[2], -q[3]]);
          continue;
        }
      }
      out.add(List<double>.from(q));
    }
    return out;
  }

  /// [keys]' values in frame order as written to glTF (rotations aligned).
  List<List<double>> writtenValues() {
    final vs = [for (final v in keys.values) v];
    return path == rotation ? _alignedQuaternions(vs) : vs;
  }

  static List<double> _normalized(List<double> q) {
    final len = math.sqrt(q.fold<double>(0, (a, v) => a + v * v));
    if (len < 1e-12) return const [0.0, 0.0, 0.0, 1.0];
    return [for (final v in q) v / len];
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'interpolation': interpolation.gltfName,
        'keys': [
          for (final e in keys.entries) {'frame': e.key, 'value': e.value},
        ],
      };

  factory AuthoredChannel.fromJson(Map<String, dynamic> json) => AuthoredChannel(
        json['path'] as String,
        interpolation: AuthoredInterpolation.fromGltf(json['interpolation'] as String?),
        keys: {
          for (final k in (json['keys'] as List? ?? const []))
            ((k as Map)['frame'] as num).toInt(): [for (final v in (k['value'] as List)) (v as num).toDouble()],
        },
      );
}

/// An animation sequence authored in the editor: keys at whole frames on
/// bones' translation / rotation / scale channels, a frame rate and a length.
///
/// The `.lmas` keeps it as JSON (`authored_clip`), the editor's exact source;
/// `GlbAuthoredClipWriter` turns it into the glTF animation that every player
/// (gltfio, by clip name, from the skeletal mesh's GLB) uses.
class AuthoredAnimationClip {
  String name;
  double frameRate;
  int lengthFrames;

  /// Bone name → channel path → channel.
  final Map<String, Map<String, AuthoredChannel>> tracks;

  AuthoredAnimationClip({
    required this.name,
    this.frameRate = 30.0,
    required this.lengthFrames,
    Map<String, Map<String, AuthoredChannel>>? tracks,
  }) : tracks = tracks ?? {} {
    if (frameRate <= 0) throw ArgumentError.value(frameRate, 'frameRate', 'must be positive');
    if (lengthFrames < 1) throw ArgumentError.value(lengthFrames, 'lengthFrames', 'must be at least 1');
  }

  double get duration => lengthFrames / frameRate;

  /// The bones that have at least one key, in insertion order.
  List<String> get bones => [
        for (final e in tracks.entries)
          if (e.value.values.any((c) => c.keys.isNotEmpty)) e.key,
      ];

  AuthoredChannel? channel(String bone, String path) => tracks[bone]?[path];

  /// Sets (or replaces) the key at [frame] on [bone]'s [path]; a new channel
  /// gets [interpolation].
  void setKey(String bone, String path, int frame, List<double> values,
      {AuthoredInterpolation interpolation = AuthoredInterpolation.linear}) {
    if (frame < 0 || frame > lengthFrames) {
      throw RangeError.range(frame, 0, lengthFrames, 'frame');
    }
    final ch = tracks.putIfAbsent(bone, () => {}).putIfAbsent(path, () => AuthoredChannel(path, interpolation: interpolation));
    ch.setKey(frame, values);
  }

  bool hasKey(String bone, int frame, [String? path]) {
    final t = tracks[bone];
    if (t == null) return false;
    if (path != null) return t[path]?.keys.containsKey(frame) ?? false;
    return t.values.any((c) => c.keys.containsKey(frame));
  }

  /// Removes [bone]'s keys at [frame] ([path] only, or every channel); drops
  /// channels and tracks left empty. True when a key was removed.
  bool removeKey(String bone, int frame, [String? path]) {
    final t = tracks[bone];
    if (t == null) return false;
    var removed = false;
    for (final p in path == null ? AuthoredChannel.paths : [path]) {
      final ch = t[p];
      if (ch != null && ch.removeKey(frame)) removed = true;
      if (ch != null && ch.keys.isEmpty) t.remove(p);
    }
    if (t.isEmpty) tracks.remove(bone);
    return removed;
  }

  /// Moves [bone]'s keys at [from] to [to] on every channel (replacing keys
  /// there). True when a key moved.
  bool moveKey(String bone, int from, int to, [String? path]) {
    if (to < 0 || to > lengthFrames) throw RangeError.range(to, 0, lengthFrames, 'to');
    final t = tracks[bone];
    if (t == null) return false;
    var moved = false;
    for (final p in path == null ? AuthoredChannel.paths : [path]) {
      if (t[p]?.moveKey(from, to) ?? false) moved = true;
    }
    return moved;
  }

  /// Every frame [bone] has a key on (any channel), ascending.
  List<int> keyFrames(String bone) {
    final frames = SplayTreeSet<int>();
    for (final c in tracks[bone]?.values ?? const <AuthoredChannel>[]) {
      frames.addAll(c.keys.keys);
    }
    return frames.toList();
  }

  /// [bone]'s [path] at [timeSeconds], or null when it has no such channel.
  List<double>? sample(String bone, String path, double timeSeconds) {
    final ch = tracks[bone]?[path];
    if (ch == null || ch.keys.isEmpty) return null;
    return ch.sample(timeSeconds * frameRate);
  }

  /// Every node's local transform at [timeSeconds]: the keyed channels over
  /// the skeleton's rest pose.
  Map<int, BoneTrs> samplePose(GlbSkeleton skeleton, double timeSeconds) {
    final pose = <int, BoneTrs>{};
    for (var i = 0; i < skeleton.count; i++) {
      pose[i] = skeleton.rest(i);
    }
    for (final entry in tracks.entries) {
      final node = skeleton.indexOf(entry.key);
      if (node < 0) continue;
      var trs = pose[node]!;
      for (final ch in entry.value.values) {
        if (ch.keys.isEmpty) continue;
        trs = trs.withChannel(ch.path, ch.sample(timeSeconds * frameRate));
      }
      pose[node] = trs;
    }
    return pose;
  }

  AuthoredAnimationClip copy() => AuthoredAnimationClip(
        name: name,
        frameRate: frameRate,
        lengthFrames: lengthFrames,
        tracks: {
          for (final e in tracks.entries) e.key: {for (final c in e.value.entries) c.key: c.value.copy()},
        },
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'frame_rate': frameRate,
        'length_frames': lengthFrames,
        'tracks': [
          for (final e in tracks.entries)
            {
              'bone': e.key,
              'channels': [for (final c in e.value.values) c.toJson()],
            },
        ],
      };

  String encode() => jsonEncode(toJson());

  factory AuthoredAnimationClip.fromJson(Map<String, dynamic> json) => AuthoredAnimationClip(
        name: json['name'] as String,
        frameRate: (json['frame_rate'] as num?)?.toDouble() ?? 30.0,
        lengthFrames: (json['length_frames'] as num).toInt(),
        tracks: {
          for (final t in (json['tracks'] as List? ?? const []))
            ((t as Map)['bone'] as String): {
              for (final c in (t['channels'] as List? ?? const []))
                ((c as Map)['path'] as String): AuthoredChannel.fromJson(Map<String, dynamic>.from(c)),
            },
        },
      );

  static AuthoredAnimationClip decode(String source) =>
      AuthoredAnimationClip.fromJson(Map<String, dynamic>.from(jsonDecode(source) as Map));

  @override
  bool operator ==(Object other) => other is AuthoredAnimationClip && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

/// The node hierarchy of a skinned GLB: names, parents, rest TRS and the
/// skin joints, enough to pose and draw its skeleton.
class GlbSkeleton {
  final List<String?> names;
  final List<int> parent;
  final List<BoneTrs> _rest;

  /// Skin joints of every skin, in node order.
  final List<int> joints;

  /// Nodes in an order where a parent comes before its children.
  final List<int> order;

  GlbSkeleton._(this.names, this.parent, this._rest, this.joints, this.order);

  factory GlbSkeleton.fromGlb(Uint8List glb) => GlbSkeleton.fromJson(GlbDocument.parse(glb, label: 'mesh').json);

  factory GlbSkeleton.fromJson(Map<String, dynamic> json) {
    final nodes = ((json['nodes'] as List?) ?? const []).cast<Map>();
    final parent = List<int>.filled(nodes.length, -1);
    for (var i = 0; i < nodes.length; i++) {
      for (final c in (nodes[i]['children'] as List?) ?? const []) {
        parent[c as int] = i;
      }
    }
    final rest = <BoneTrs>[];
    for (final n in nodes) {
      final matrix = n['matrix'] as List?;
      if (matrix != null && matrix.length == 16) {
        final m = Matrix4.fromList([for (final v in matrix) (v as num).toDouble()]);
        final t = Vector3.zero();
        final r = Quaternion.identity();
        final s = Vector3.zero();
        m.decompose(t, r, s);
        rest.add(BoneTrs(t, r, s));
        continue;
      }
      List<double> read(String key, List<double> fallback) {
        final v = n[key] as List?;
        return v == null ? fallback : [for (final x in v) (x as num).toDouble()];
      }

      final t = read('translation', const [0, 0, 0]);
      final r = read('rotation', const [0, 0, 0, 1]);
      final s = read('scale', const [1, 1, 1]);
      rest.add(BoneTrs(Vector3(t[0], t[1], t[2]), Quaternion(r[0], r[1], r[2], r[3]), Vector3(s[0], s[1], s[2])));
    }
    final jointSet = SplayTreeSet<int>();
    for (final s in (json['skins'] as List?) ?? const []) {
      for (final j in ((s as Map)['joints'] as List?) ?? const []) {
        jointSet.add(j as int);
      }
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

    for (var i = 0; i < nodes.length; i++) {
      if (parent[i] == -1) visit(i);
    }
    return GlbSkeleton._(
      [for (final n in nodes) n['name'] as String?],
      parent,
      rest,
      jointSet.toList(),
      order,
    );
  }

  int get count => names.length;

  int indexOf(String name) => names.indexOf(name);

  BoneTrs rest(int node) => _rest[node].copy();

  bool isJoint(int node) => joints.contains(node);

  /// The topmost skin joint (no joint above it): the skeleton's root bone.
  int? get root {
    for (final i in order) {
      if (!joints.contains(i)) continue;
      var p = parent[i];
      var nested = false;
      while (p >= 0) {
        if (joints.contains(p)) {
          nested = true;
          break;
        }
        p = parent[p];
      }
      if (!nested) return i;
    }
    return null;
  }

  /// The joint directly below [root] with the most descendants (the pelvis).
  int? get rootChild {
    final r = root;
    if (r == null) return null;
    int? best;
    var bestCount = -1;
    for (final j in joints) {
      if (parent[j] != r) continue;
      final n = _descendants(j);
      if (n > bestCount) {
        best = j;
        bestCount = n;
      }
    }
    return best;
  }

  int _descendants(int node) {
    var n = 0;
    for (var i = 0; i < count; i++) {
      var p = parent[i];
      while (p >= 0) {
        if (p == node) {
          n++;
          break;
        }
        p = parent[p];
      }
    }
    return n;
  }

  /// World matrices of every node for the local transforms [pose] (the rest
  /// pose where it has none), in the GLB's frame.
  List<Matrix4> worldMatrices([Map<int, BoneTrs>? pose]) {
    final world = List<Matrix4>.filled(count, Matrix4.identity());
    for (final i in order) {
      final local = (pose?[i] ?? _rest[i]).toMatrix();
      final p = parent[i];
      world[i] = p < 0 ? local : world[p] * local;
    }
    return world;
  }
}
