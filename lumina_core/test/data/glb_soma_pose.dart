import 'dart:typed_data';
import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

/// Forward kinematics from real GLB node transforms and animation accessors.
class GlbPose {
  final GlbDocument document;
  final int? animationIndex;
  int frame = 0;
  late final List<Map> nodes = (document.json['nodes'] as List).cast<Map>();
  late final List<int> parents = _parents();
  GlbPose(this.document, {this.animationIndex});
  int index(String name) => nodes.indexWhere((n) => n['name'] == name);
  List<int> _parents() {
    final result = List<int>.filled(nodes.length, -1);
    for (var i = 0; i < nodes.length; i++) {
      for (final child in (nodes[i]['children'] as List?) ?? []) {
        result[child as int] = i;
      }
    }
    return result;
  }

  Matrix4 world(int index) {
    final node = nodes[index];
    final matrix = node['matrix'] as List?;
    final translation = Vector3.zero();
    final rotation = Quaternion.identity();
    final scale = Vector3.all(1);
    if (matrix != null) {
      Matrix4.fromList(
        matrix.cast<num>().map((v) => v.toDouble()).toList(),
      ).decompose(translation, rotation, scale);
    } else {
      final t = node['translation'] as List?;
      final r = node['rotation'] as List?;
      final s = node['scale'] as List?;
      if (t != null) {
        translation.setValues(
          (t[0] as num).toDouble(),
          (t[1] as num).toDouble(),
          (t[2] as num).toDouble(),
        );
      }
      if (r != null) {
        rotation.setValues(
          (r[0] as num).toDouble(),
          (r[1] as num).toDouble(),
          (r[2] as num).toDouble(),
          (r[3] as num).toDouble(),
        );
      }
      if (s != null) {
        scale.setValues(
          (s[0] as num).toDouble(),
          (s[1] as num).toDouble(),
          (s[2] as num).toDouble(),
        );
      }
    }
    if (animationIndex != null) {
      final animation = (document.json['animations'] as List)[animationIndex!] as Map;
      for (final channel in (animation['channels'] as List).cast<Map>()) {
        final target = channel['target'] as Map;
        if (target['node'] != index) continue;
        final sampler = (animation['samplers'] as List)[channel['sampler'] as int] as Map;
        final accessor = (document.json['accessors'] as List)[sampler['output'] as int] as Map;
        final view = (document.json['bufferViews'] as List)[accessor['bufferView'] as int] as Map;
        final count = accessor['count'] as int;
        final components = accessor['type'] == 'VEC4' ? 4 : 3;
        final offset =
            (view['byteOffset'] as int? ?? 0) +
            (accessor['byteOffset'] as int? ?? 0) +
            frame.clamp(0, count - 1) * (view['byteStride'] as int? ?? components * 4);
        final bytes = ByteData.sublistView(document.bin);
        double value(int c) => bytes.getFloat32(offset + c * 4, Endian.little);
        switch (target['path']) {
          case 'rotation':
            rotation.setValues(value(0), value(1), value(2), value(3));
          case 'translation':
            translation.setValues(value(0), value(1), value(2));
          case 'scale':
            scale.setValues(value(0), value(1), value(2));
        }
      }
    }
    final local = Matrix4.compose(translation, rotation, scale);
    return parents[index] < 0 ? local : world(parents[index]) * local;
  }
}
