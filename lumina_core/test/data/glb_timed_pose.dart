import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

/// Forward kinematics of a real GLB at a time of one of its animations
/// (LINEAR / STEP samplers, keys interpolated like the runtime does), or at
/// rest when [animationIndex] is null.
class GlbTimedPose {
  final GlbDocument document;
  final int? animationIndex;
  late final List<Map> _nodes = (document.json['nodes'] as List).cast<Map>();
  late final List<int> _parents = _parentList();
  late final Map<(int, String), (Float32List, Float32List, String)> _tracks =
      _readTracks();
  final Map<int, Matrix4> _cache = {};
  double _time = 0;

  GlbTimedPose(this.document, {this.animationIndex});

  /// Animation length in seconds (0 at rest).
  double get duration {
    var end = 0.0;
    for (final t in _tracks.values) {
      if (t.$1.isNotEmpty) end = math.max(end, t.$1.last);
    }
    return end;
  }

  set time(double value) {
    _time = value;
    _cache.clear();
  }

  int index(String name) => _nodes.indexWhere((n) => n['name'] == name);

  int parentOf(int node) => _parents[node];

  /// Model-space position of [name].
  Vector3 position(String name) => world(index(name)).getTranslation();

  /// Model-space rotation of [name].
  Quaternion rotation(String name) =>
      Quaternion.fromRotation(world(index(name)).getRotation())..normalize();

  Matrix4 world(int node) {
    final cached = _cache[node];
    if (cached != null) return cached;
    final n = _nodes[node];
    final t = n['translation'] as List?;
    final r = n['rotation'] as List?;
    final s = n['scale'] as List?;
    var translation = t == null
        ? Vector3.zero()
        : Vector3.array([for (final v in t) (v as num).toDouble()]);
    var rotation = r == null
        ? Quaternion.identity()
        : Quaternion(
            (r[0] as num).toDouble(),
            (r[1] as num).toDouble(),
            (r[2] as num).toDouble(),
            (r[3] as num).toDouble(),
          );
    final scale = s == null
        ? Vector3.all(1)
        : Vector3.array([for (final v in s) (v as num).toDouble()]);
    final animatedR = _sample(node, 'rotation');
    if (animatedR != null) {
      rotation = Quaternion(
        animatedR[0],
        animatedR[1],
        animatedR[2],
        animatedR[3],
      );
    }
    final animatedT = _sample(node, 'translation');
    if (animatedT != null) translation = Vector3.array(animatedT);
    final local = Matrix4.compose(translation, rotation..normalize(), scale);
    final p = _parents[node];
    final result = p < 0 ? local : world(p) * local;
    _cache[node] = result;
    return result;
  }

  List<double>? _sample(int node, String path) {
    final track = _tracks[(node, path)];
    if (track == null) return null;
    final (input, output, interpolation) = track;
    final width = path == 'rotation' ? 4 : 3;
    List<double> key(int k) => [
      for (var c = 0; c < width; c++) output[k * width + c],
    ];
    if (_time <= input.first) return key(0);
    if (_time >= input.last) return key(input.length - 1);
    var i = 0;
    while (input[i + 1] < _time) {
      i++;
    }
    final a = key(i), b = key(i + 1);
    final f = interpolation == 'STEP'
        ? 0.0
        : (_time - input[i]) / (input[i + 1] - input[i]);
    if (path != 'rotation') {
      return [for (var c = 0; c < 3; c++) a[c] + (b[c] - a[c]) * f];
    }
    final qa = Quaternion(a[0], a[1], a[2], a[3]);
    var qb = Quaternion(b[0], b[1], b[2], b[3]);
    if (qa.x * qb.x + qa.y * qb.y + qa.z * qb.z + qa.w * qb.w < 0) qb = -qb;
    final q = (qa.scaled(1 - f) + qb.scaled(f))..normalize();
    return [q.x, q.y, q.z, q.w];
  }

  List<int> _parentList() {
    final result = List<int>.filled(_nodes.length, -1);
    for (var i = 0; i < _nodes.length; i++) {
      for (final child in (_nodes[i]['children'] as List?) ?? const []) {
        result[child as int] = i;
      }
    }
    return result;
  }

  Map<(int, String), (Float32List, Float32List, String)> _readTracks() {
    final result = <(int, String), (Float32List, Float32List, String)>{};
    if (animationIndex == null) return result;
    final animation =
        (document.json['animations'] as List)[animationIndex!] as Map;
    final samplers = animation['samplers'] as List;
    for (final channel in (animation['channels'] as List).cast<Map>()) {
      final target = channel['target'] as Map;
      final path = target['path'] as String;
      if (path != 'rotation' && path != 'translation') continue;
      final sampler = samplers[channel['sampler'] as int] as Map;
      final interpolation = sampler['interpolation'] as String? ?? 'LINEAR';
      if (interpolation == 'CUBICSPLINE') {
        throw UnsupportedError('CUBICSPLINE samplers are not sampled here');
      }
      result[(target['node'] as int, path)] = (
        _floats(sampler['input'] as int),
        _floats(sampler['output'] as int),
        interpolation,
      );
    }
    return result;
  }

  Float32List _floats(int accessorIndex) {
    final accessor = (document.json['accessors'] as List)[accessorIndex] as Map;
    if (accessor['componentType'] != 5126) {
      throw UnsupportedError('only FLOAT accessors are sampled here');
    }
    final view =
        (document.json['bufferViews'] as List)[accessor['bufferView'] as int]
            as Map;
    final components = const {
      'SCALAR': 1,
      'VEC3': 3,
      'VEC4': 4,
    }[accessor['type']]!;
    final count = accessor['count'] as int;
    final stride = view['byteStride'] as int? ?? components * 4;
    final start =
        (view['byteOffset'] as int? ?? 0) +
        (accessor['byteOffset'] as int? ?? 0);
    final bytes = ByteData.sublistView(document.bin);
    return Float32List.fromList([
      for (var i = 0; i < count; i++)
        for (var c = 0; c < components; c++)
          bytes.getFloat32(start + i * stride + c * 4, Endian.little),
    ]);
  }
}

/// Angle in degrees between two directions.
double angleBetweenDeg(Vector3 a, Vector3 b) =>
    math.acos((a.normalized().dot(b.normalized())).clamp(-1.0, 1.0)) *
    180 /
    math.pi;

/// Angle in degrees of the rotation taking [a] to [b].
double rotationAngleDeg(Quaternion a, Quaternion b) {
  final d = (a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w).abs().clamp(
    0.0,
    1.0,
  );
  return 2 * math.acos(d) * 180 / math.pi;
}
