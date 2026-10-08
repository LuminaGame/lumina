part of '../glb_animation_retargeter.dart';

class _Quat {
  final double x, y, z, w;
  const _Quat(this.x, this.y, this.z, this.w);

  @override
  String toString() =>
      '[${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)}, ${z.toStringAsFixed(4)}, ${w.toStringAsFixed(4)}]';

  static const identity = _Quat(0, 0, 0, 1);

  _Quat operator *(_Quat b) => _Quat(
    w * b.x + x * b.w + y * b.z - z * b.y,
    w * b.y - x * b.z + y * b.w + z * b.x,
    w * b.z + x * b.y - y * b.x + z * b.w,
    w * b.w - x * b.x - y * b.y - z * b.z,
  );

  _Quat inverse() {
    final n = x * x + y * y + z * z + w * w;
    return n == 0 ? identity : _Quat(-x / n, -y / n, -z / n, w / n);
  }

  List<double> rotateVector(List<double> v) {
    final qv = _Quat(v[0], v[1], v[2], 0);
    final res = this * qv * inverse();
    return [res.x, res.y, res.z];
  }

  _Quat normalized() {
    final n = math.sqrt(x * x + y * y + z * z + w * w);
    return n == 0 ? identity : _Quat(x / n, y / n, z / n, w / n);
  }

  _Quat negated() => _Quat(-x, -y, -z, -w);

  double dot(_Quat b) => x * b.x + y * b.y + z * b.z + w * b.w;

  static _Quat slerp(_Quat a, _Quat b, double t) {
    var d = a.dot(b);
    var bb = b;
    if (d < 0) {
      d = -d;
      bb = b.negated();
    }
    if (d > 0.9995) {
      return _Quat(
        a.x + (bb.x - a.x) * t,
        a.y + (bb.y - a.y) * t,
        a.z + (bb.z - a.z) * t,
        a.w + (bb.w - a.w) * t,
      ).normalized();
    }
    final theta = math.acos(d);
    final s = math.sin(theta);
    final wa = math.sin((1 - t) * theta) / s, wb = math.sin(t * theta) / s;
    return _Quat(
      a.x * wa + bb.x * wb,
      a.y * wa + bb.y * wb,
      a.z * wa + bb.z * wb,
      a.w * wa + bb.w * wb,
    );
  }

  /// Scales rotation angle by [weight] (slerp from identity).
  _Quat scaled(double weight) => slerp(identity, this, weight);

  /// Decomposes rotation into swing (perpendicular to axis) and twist (around axis).
  static (_Quat swing, _Quat twist) swingTwist(_Quat q, List<double> axis) {
    final dot = q.x * axis[0] + q.y * axis[1] + q.z * axis[2];
    final twist = _Quat(
      axis[0] * dot,
      axis[1] * dot,
      axis[2] * dot,
      q.w,
    ).normalized();
    if (twist.w == 0 && twist.x == 0 && twist.y == 0 && twist.z == 0) {
      return (q, identity);
    }
    final swing = (q * twist.inverse()).normalized();
    return (swing, twist);
  }

  static _Quat fromTo(List<double> vFrom, List<double> vTo) {
    double len(List<double> v) =>
        math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    final lFrom = len(vFrom), lTo = len(vTo);
    if (lFrom < 1e-6 || lTo < 1e-6) return identity;
    final f = [vFrom[0] / lFrom, vFrom[1] / lFrom, vFrom[2] / lFrom];
    final t = [vTo[0] / lTo, vTo[1] / lTo, vTo[2] / lTo];
    final d = f[0] * t[0] + f[1] * t[1] + f[2] * t[2];
    if (d >= 1.0 - 1e-7) return identity;
    if (d <= -1.0 + 1e-7) {
      final ortho = f[0].abs() < 0.9
          ? const [1.0, 0.0, 0.0]
          : const [0.0, 1.0, 0.0];
      final axis = [
        f[1] * ortho[2] - f[2] * ortho[1],
        f[2] * ortho[0] - f[0] * ortho[2],
        f[0] * ortho[1] - f[1] * ortho[0],
      ];
      final lAxis = len(axis);
      return _Quat(axis[0] / lAxis, axis[1] / lAxis, axis[2] / lAxis, 0.0);
    }
    final axis = [
      f[1] * t[2] - f[2] * t[1],
      f[2] * t[0] - f[0] * t[2],
      f[0] * t[1] - f[1] * t[0],
    ];
    final s = math.sqrt((1.0 + d) * 2.0);
    return _Quat(axis[0] / s, axis[1] / s, axis[2] / s, s / 2.0).normalized();
  }

  /// The rotation that best turns each direction of [from] onto the matching
  /// direction of [to] (least squares over unit directions, Horn's
  /// quaternion method). One pair, or pairs that are all parallel, give the
  /// shortest-arc rotation of their sums.
  static _Quat bestFit(List<List<double>> from, List<List<double>> to) {
    List<double> unit(List<double> v) {
      final l = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
      return l < 1e-9 ? const [0.0, 0.0, 0.0] : [v[0] / l, v[1] / l, v[2] / l];
    }

    final a = [for (final v in from) unit(v)];
    final b = [for (final v in to) unit(v)];
    List<double> sum(List<List<double>> vs) => [
      for (var c = 0; c < 3; c++) vs.fold(0.0, (s, v) => s + v[c]),
    ];
    final fallback = fromTo(sum(a), sum(b));
    // Planar spread of the source directions: below it the twist about
    // their common direction is undetermined.
    var spread = 0.0;
    for (var i = 0; i < a.length; i++) {
      for (var k = i + 1; k < a.length; k++) {
        final x = a[i][1] * a[k][2] - a[i][2] * a[k][1];
        final y = a[i][2] * a[k][0] - a[i][0] * a[k][2];
        final z = a[i][0] * a[k][1] - a[i][1] * a[k][0];
        spread = math.max(spread, math.sqrt(x * x + y * y + z * z));
      }
    }
    if (a.length < 2 || spread < 0.1) return fallback;

    final s = List.generate(3, (_) => List<double>.filled(3, 0));
    for (var i = 0; i < a.length; i++) {
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          s[r][c] += a[i][r] * b[i][c];
        }
      }
    }
    final (xx, xy, xz) = (s[0][0], s[0][1], s[0][2]);
    final (yx, yy, yz) = (s[1][0], s[1][1], s[1][2]);
    final (zx, zy, zz) = (s[2][0], s[2][1], s[2][2]);
    final shift = a.length.toDouble();
    // Shifted so every eigenvalue is positive: power iteration then finds
    // the largest, whose eigenvector (w, x, y, z) is the rotation.
    final n = [
      [xx + yy + zz + shift, yz - zy, zx - xz, xy - yx],
      [yz - zy, xx - yy - zz + shift, xy + yx, zx + xz],
      [zx - xz, xy + yx, -xx + yy - zz + shift, yz + zy],
      [xy - yx, zx + xz, yz + zy, -xx - yy + zz + shift],
    ];
    var v = [fallback.w, fallback.x, fallback.y, fallback.z];
    for (var it = 0; it < 500; it++) {
      final next = [
        for (var r = 0; r < 4; r++)
          n[r][0] * v[0] + n[r][1] * v[1] + n[r][2] * v[2] + n[r][3] * v[3],
      ];
      final l = math.sqrt(next.fold(0.0, (s, e) => s + e * e));
      if (l < 1e-12) return fallback;
      v = [for (final e in next) e / l];
    }
    return _Quat(v[1], v[2], v[3], v[0]).normalized();
  }

  /// Rotation part of a column-major matrix (unit scale assumed after
  /// normalizing the columns).
  static _Quat fromMatrix(List<double> m) {
    double col(int c) => math.sqrt(
      m[c * 4] * m[c * 4] +
          m[c * 4 + 1] * m[c * 4 + 1] +
          m[c * 4 + 2] * m[c * 4 + 2],
    );
    final sx = col(0), sy = col(1), sz = col(2);
    double r(int row, int c, double s) => s == 0 ? 0 : m[c * 4 + row] / s;
    final r00 = r(0, 0, sx), r10 = r(1, 0, sx), r20 = r(2, 0, sx);
    final r01 = r(0, 1, sy), r11 = r(1, 1, sy), r21 = r(2, 1, sy);
    final r02 = r(0, 2, sz), r12 = r(1, 2, sz), r22 = r(2, 2, sz);
    final trace = r00 + r11 + r22;
    if (trace > 0) {
      final s = math.sqrt(trace + 1.0) * 2;
      return _Quat(
        (r21 - r12) / s,
        (r02 - r20) / s,
        (r10 - r01) / s,
        0.25 * s,
      ).normalized();
    } else if (r00 > r11 && r00 > r22) {
      final s = math.sqrt(1.0 + r00 - r11 - r22) * 2;
      return _Quat(
        0.25 * s,
        (r01 + r10) / s,
        (r02 + r20) / s,
        (r21 - r12) / s,
      ).normalized();
    } else if (r11 > r22) {
      final s = math.sqrt(1.0 + r11 - r00 - r22) * 2;
      return _Quat(
        (r01 + r10) / s,
        0.25 * s,
        (r12 + r21) / s,
        (r02 - r20) / s,
      ).normalized();
    }
    final s = math.sqrt(1.0 + r22 - r00 - r11) * 2;
    return _Quat(
      (r02 + r20) / s,
      (r12 + r21) / s,
      0.25 * s,
      (r10 - r01) / s,
    ).normalized();
  }
}

/// Node hierarchy of a GLB: names, parents, rest TRS and a parent-first
/// order.
class _Skeleton {
  final List<String?> names;
  final List<int> parent;
  final List<List<double>> restT;
  final List<_Quat> restR;
  final List<int> order;

  int get count => names.length;

  factory _Skeleton(GlbDocument doc) {
    final nodes = (doc.json['nodes'] as List?) ?? const [];
    final names = <String?>[];
    final parent = List<int>.filled(nodes.length, -1);
    final restT = <List<double>>[];
    final restR = <_Quat>[];
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i] as Map;
      names.add(n['name'] as String?);
      for (final c in (n['children'] as List?) ?? const []) {
        parent[c as int] = i;
      }
      final matrix = n['matrix'] as List?;
      if (matrix != null && matrix.length == 16) {
        final m = [for (final v in matrix) (v as num).toDouble()];
        restT.add([m[12], m[13], m[14]]);
        restR.add(_Quat.fromMatrix(m));
      } else {
        final t = (n['translation'] as List?) ?? const [0, 0, 0];
        final r = (n['rotation'] as List?) ?? const [0, 0, 0, 1];
        restT.add([for (final v in t) (v as num).toDouble()]);
        restR.add(
          _Quat(
            (r[0] as num).toDouble(),
            (r[1] as num).toDouble(),
            (r[2] as num).toDouble(),
            (r[3] as num).toDouble(),
          ).normalized(),
        );
      }
    }
    final order = <int>[];
    void visit(int i) {
      order.add(i);
      for (final c in ((nodes[i] as Map)['children'] as List?) ?? const []) {
        visit(c as int);
      }
    }

    for (var i = 0; i < nodes.length; i++) {
      if (parent[i] < 0) visit(i);
    }
    return _Skeleton._(names, parent, restT, restR, order);
  }

  _Skeleton._(this.names, this.parent, this.restT, this.restR, this.order);

  /// Rest rotation of [node] in model space (identity for -1).
  _Quat restWorld(int node) {
    var q = _Quat.identity;
    var i = node;
    final chain = <int>[];
    while (i >= 0) {
      chain.add(i);
      i = parent[i];
    }
    for (final n in chain.reversed) {
      q = q * restR[n];
    }
    return q;
  }

  /// Rest position of [node] in model space ([0, 0, 0] for -1).
  List<double> restWorldPos(int node) {
    if (node < 0) return const [0.0, 0.0, 0.0];
    final chain = <int>[];
    var curr = node;
    while (curr >= 0) {
      chain.add(curr);
      curr = parent[curr];
    }
    var pos = [0.0, 0.0, 0.0];
    var rot = _Quat.identity;
    for (final n in chain.reversed) {
      final tRot = rot.rotateVector(restT[n]);
      pos = [pos[0] + tRot[0], pos[1] + tRot[1], pos[2] + tRot[2]];
      rot = rot * restR[n];
    }
    return pos;
  }

  /// Rest model-space direction of bone [node], pointing towards its primary child.
  List<double>? boneDirection(int node, {String? childName}) {
    if (node < 0 || node >= count) return null;
    final nodePos = restWorldPos(node);
    int? bestChild;
    var maxL = 0.0;
    for (var i = 0; i < parent.length; i++) {
      if (parent[i] == node) {
        if (childName != null && names[i] != childName) continue;
        final cPos = restWorldPos(i);
        final dx = cPos[0] - nodePos[0],
            dy = cPos[1] - nodePos[1],
            dz = cPos[2] - nodePos[2];
        final l = math.sqrt(dx * dx + dy * dy + dz * dz);
        if (l > maxL) {
          maxL = l;
          bestChild = i;
        }
      }
    }
    if (bestChild != null && maxL > 0.001) {
      final cPos = restWorldPos(bestChild);
      return [
        (cPos[0] - nodePos[0]) / maxL,
        (cPos[1] - nodePos[1]) / maxL,
        (cPos[2] - nodePos[2]) / maxL,
      ];
    }
    final p = parent[node];
    if (p >= 0) {
      final pPos = restWorldPos(p);
      final dx = nodePos[0] - pPos[0],
          dy = nodePos[1] - pPos[1],
          dz = nodePos[2] - pPos[2];
      final l = math.sqrt(dx * dx + dy * dy + dz * dz);
      if (l > 0.001) return [dx / l, dy / l, dz / l];
    }
    return null;
  }

  /// Detects whether this skeleton is in A-Pose or T-Pose based on upper arm downward slant.
  SkeletonArmPose detectArmPose() {
    for (final name in ['upperarm_l', 'upperarm_r', 'leftarm', 'rightarm']) {
      final idx = names.indexWhere((n) {
        if (n == null) return false;
        final clean = n.toLowerCase().startsWith('mixamorig:')
            ? n.toLowerCase().substring(10)
            : n.toLowerCase();
        return clean == name;
      });
      if (idx >= 0) {
        final dir = boneDirection(idx);
        if (dir != null) {
          // In Y-up coordinate space, downward slant > 20° has dir[1] < -0.35.
          return dir[1] < -0.35 ? SkeletonArmPose.aPose : SkeletonArmPose.tPose;
        }
      }
    }
    return SkeletonArmPose.tPose;
  }
}

/// The rotation/translation tracks of one animation, sampled by time.
class _Tracks {
  final Map<int, (Float32List, Float32List, String)> _rotation = {};
  final Map<int, (Float32List, Float32List, String)> _translation = {};

  _Tracks(GlbDocument doc, Map animation) {
    final samplers = (animation['samplers'] as List?) ?? const [];
    for (final c in (animation['channels'] as List?) ?? const []) {
      final target = (c as Map)['target'] as Map;
      final node = target['node'] as int?;
      final path = target['path'] as String?;
      if (node == null || (path != 'rotation' && path != 'translation')) {
        continue;
      }
      final sampler = samplers[c['sampler'] as int] as Map;
      final input = _readFloats(doc, sampler['input'] as int);
      final output = _readFloats(doc, sampler['output'] as int);
      final interpolation = (sampler['interpolation'] as String?) ?? 'LINEAR';
      (path == 'rotation' ? _rotation : _translation)[node] = (
        input,
        output,
        interpolation,
      );
    }
  }

  Iterable<int> get animatedNodes => {..._rotation.keys, ..._translation.keys};

  bool hasTranslation(int node) => _translation.containsKey(node);

  List<double> keyTimes() {
    final set = <int>{};
    for (final track in [..._rotation.values, ..._translation.values]) {
      for (final t in track.$1) {
        set.add((t * 10000).round());
      }
    }
    final sorted = set.toList()..sort();
    return [for (final t in sorted) t / 10000.0];
  }

  List<double>? translationAtFirstKey(int node) {
    final track = _translation[node];
    if (track == null || track.$2.length < 3) return null;
    final o = track.$3 == 'CUBICSPLINE' ? 3 : 0;
    return [track.$2[o], track.$2[o + 1], track.$2[o + 2]];
  }

  _Quat? rotation(int node, double t) {
    final track = _rotation[node];
    if (track == null) return null;
    final (input, output, interp) = track;
    final (i, f) = _segment(input, t);
    _Quat at(int k) {
      final o = interp == 'CUBICSPLINE' ? (k * 3 + 1) * 4 : k * 4;
      return _Quat(
        output[o],
        output[o + 1],
        output[o + 2],
        output[o + 3],
      ).normalized();
    }

    if (f == 0 || interp == 'STEP' || i + 1 >= input.length) return at(i);
    return _Quat.slerp(at(i), at(i + 1), f);
  }

  List<double>? translation(int node, double t) {
    final track = _translation[node];
    if (track == null) return null;
    final (input, output, interp) = track;
    final (i, f) = _segment(input, t);
    List<double> at(int k) {
      final o = interp == 'CUBICSPLINE' ? (k * 3 + 1) * 3 : k * 3;
      return [output[o], output[o + 1], output[o + 2]];
    }

    if (f == 0 || interp == 'STEP' || i + 1 >= input.length) return at(i);
    final a = at(i), b = at(i + 1);
    return [for (var k = 0; k < 3; k++) a[k] + (b[k] - a[k]) * f];
  }

  /// Key index at or before [t] and the fraction towards the next key.
  static (int, double) _segment(Float32List input, double t) {
    if (input.isEmpty || t <= input.first) return (0, 0);
    if (t >= input.last) return (input.length - 1, 0);
    var lo = 0, hi = input.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (input[mid] <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = input[hi] - input[lo];
    return (lo, span <= 0 ? 0 : (t - input[lo]) / span);
  }

  /// Float view of an accessor: FLOAT, or normalized BYTE/UBYTE/SHORT/USHORT.
  static Float32List _readFloats(GlbDocument doc, int index) {
    final acc = (doc.json['accessors'] as List)[index] as Map;
    final count = acc['count'] as int;
    final components =
        const {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[acc['type']] ?? 1;
    final out = Float32List(count * components);
    final bvIndex = acc['bufferView'] as int?;
    if (bvIndex == null) return out;
    final bv = (doc.json['bufferViews'] as List)[bvIndex] as Map;
    final componentType = acc['componentType'] as int;
    final size = const {
      5120: 1,
      5121: 1,
      5122: 2,
      5123: 2,
      5126: 4,
    }[componentType];
    if (size == null) {
      throw FormatException(
        'unsupported animation accessor componentType $componentType',
      );
    }
    final stride = (bv['byteStride'] as int?) ?? size * components;
    final start =
        ((bv['byteOffset'] as int?) ?? 0) + ((acc['byteOffset'] as int?) ?? 0);
    final data = ByteData.sublistView(doc.bin);
    for (var i = 0; i < count; i++) {
      for (var c = 0; c < components; c++) {
        final at = start + i * stride + c * size;
        out[i * components + c] = switch (componentType) {
          5126 => data.getFloat32(at, Endian.little),
          5120 => math.max(data.getInt8(at) / 127.0, -1.0),
          5121 => data.getUint8(at) / 255.0,
          5122 => math.max(data.getInt16(at, Endian.little) / 32767.0, -1.0),
          _ => data.getUint16(at, Endian.little) / 65535.0,
        };
      }
    }
    return out;
  }
}
