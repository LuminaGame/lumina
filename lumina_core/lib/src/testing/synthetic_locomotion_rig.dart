import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/src/services/glb_animation_merger.dart';

/// The root's ground motion of a synthetic clip at time t: position (x, z)
/// in metres and yaw in radians (0 faces +Z, positive turns toward +X).
typedef LuminaSyntheticRootPath = ({double x, double z, double yaw}) Function(double t);

/// A clip of [LuminaSyntheticLocomotionRig]: the root follows [root]; the
/// feet swing forward and back by [stride] metres at [cadence] steps per
/// second while [moving] says the character walks.
class LuminaSyntheticClip {
  final String name;
  final double duration;
  final LuminaSyntheticRootPath root;
  final double stride;
  final double cadence;
  final bool Function(double t) moving;

  /// −1 swings the right foot forward first (the mirror of +1).
  final double footSign;

  LuminaSyntheticClip(this.name, this.duration, this.root,
      {this.stride = 0.3, this.cadence = 2.0, this.footSign = 1.0, bool Function(double t)? moving})
      : moving = moving ?? ((_) => true);
}

/// A minimal skinned skeleton (Armature → root → pelvis → foot_l / foot_r,
/// hand_l / hand_r) written as a GLB with keyed clips — a deterministic rig
/// for testing motion matching without an imported character.
abstract final class LuminaSyntheticLocomotionRig {
  static const List<String> bones = ['root', 'pelvis', 'foot_l', 'foot_r', 'hand_l', 'hand_r'];

  /// Standing still for [duration] seconds.
  static LuminaSyntheticClip idle(String name, {double duration = 2.0}) =>
      LuminaSyntheticClip(name, duration, (t) => (x: 0.0, z: 0.0, yaw: 0.0), moving: (_) => false);

  /// Walking in direction ([dx], [dz]) (unit, character frame; facing stays
  /// +Z) at [speed] m/s.
  static LuminaSyntheticClip walk(String name, double dx, double dz,
          {double speed = 1.5, double duration = 2.0, double footSign = 1.0}) =>
      LuminaSyntheticClip(name, duration, (t) => (x: dx * speed * t, z: dz * speed * t, yaw: 0.0), footSign: footSign);

  /// Accelerating from rest to [speed] forward over [ramp] seconds.
  static LuminaSyntheticClip start(String name, {double speed = 1.5, double ramp = 1.0, double duration = 1.5}) =>
      LuminaSyntheticClip(name, duration, (t) {
        final z = t < ramp ? speed * t * t / (2 * ramp) : speed * ramp / 2 + speed * (t - ramp);
        return (x: 0.0, z: z, yaw: 0.0);
      }, moving: (t) => t > 0.1);

  /// Decelerating from [speed] forward to rest over [ramp] seconds, then
  /// standing.
  static LuminaSyntheticClip stop(String name, {double speed = 1.5, double ramp = 1.0, double duration = 1.5}) =>
      LuminaSyntheticClip(name, duration, (t) {
        final tt = math.min(t, ramp);
        return (x: 0.0, z: speed * tt - speed * tt * tt / (2 * ramp), yaw: 0.0);
      }, moving: (t) => t < ramp - 0.1);

  /// Walking forward at [speed] while turning by [turnRadians] over the clip.
  static LuminaSyntheticClip turn(String name, double turnRadians, {double speed = 1.5, double duration = 1.0}) =>
      LuminaSyntheticClip(name, duration, (t) {
        // Integrate the heading: the path is an arc.
        const steps = 60;
        var x = 0.0, z = 0.0;
        for (var i = 0; i < steps; i++) {
          final yaw = turnRadians * ((i + 0.5) * t / steps) / duration;
          x += math.sin(yaw) * speed * t / steps;
          z += math.cos(yaw) * speed * t / steps;
        }
        return (x: x, z: z, yaw: turnRadians * t / duration);
      });

  /// The GLB: the skeleton (with a skin over its bones) and one animation
  /// per clip, keyed at [fps].
  static Uint8List build(List<LuminaSyntheticClip> clips, {double fps = 30.0}) {
    final bin = BytesBuilder();
    final accessors = <Map<String, dynamic>>[];
    final bufferViews = <Map<String, dynamic>>[];
    int addFloats(List<double> values, String type, {bool minMax = false}) {
      final width = const {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[type]!;
      final offset = bin.length;
      final data = Float32List.fromList(values);
      bin.add(data.buffer.asUint8List());
      bufferViews.add({'buffer': 0, 'byteOffset': offset, 'byteLength': data.lengthInBytes});
      accessors.add({
        'bufferView': bufferViews.length - 1,
        'componentType': 5126,
        'count': values.length ~/ width,
        'type': type,
        if (minMax) 'min': [values.reduce(math.min)],
        if (minMax) 'max': [values.reduce(math.max)],
      });
      return accessors.length - 1;
    }

    // Nodes: 0 Armature, 1 root, 2 pelvis, 3 foot_l, 4 foot_r, 5 hand_l, 6 hand_r.
    final nodes = <Map<String, dynamic>>[
      {'name': 'Armature', 'children': [1]},
      {'name': 'root', 'children': [2]},
      {'name': 'pelvis', 'translation': [0.0, 0.9, 0.0], 'children': [3, 4, 5, 6]},
      {'name': 'foot_l', 'translation': [0.1, -0.85, 0.0]},
      {'name': 'foot_r', 'translation': [-0.1, -0.85, 0.0]},
      {'name': 'hand_l', 'translation': [0.25, 0.5, 0.0]},
      {'name': 'hand_r', 'translation': [-0.25, 0.5, 0.0]},
    ];
    final inverseBind = <double>[];
    for (final n in [1, 2, 3, 4, 5, 6]) {
      // World translation of the bone at rest (root at origin).
      final t = switch (n) {
        2 => [0.0, 0.9, 0.0],
        3 => [0.1, 0.05, 0.0],
        4 => [-0.1, 0.05, 0.0],
        5 => [0.25, 1.4, 0.0],
        6 => [-0.25, 1.4, 0.0],
        _ => [0.0, 0.0, 0.0],
      };
      inverseBind.addAll([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -t[0], -t[1], -t[2], 1]);
    }
    final ibm = bin.length;
    bin.add(Float32List.fromList(inverseBind).buffer.asUint8List());
    bufferViews.add({'buffer': 0, 'byteOffset': ibm, 'byteLength': inverseBind.length * 4});
    accessors.add({'bufferView': bufferViews.length - 1, 'componentType': 5126, 'count': 6, 'type': 'MAT4'});
    final ibmAccessor = accessors.length - 1;

    final animations = <Map<String, dynamic>>[];
    for (final clip in clips) {
      final frames = math.max(1, (clip.duration * fps).round());
      final times = [for (var i = 0; i <= frames; i++) clip.duration * i / frames];
      final input = addFloats(times, 'SCALAR', minMax: true);
      final rootT = <double>[], rootR = <double>[], footL = <double>[], footR = <double>[];
      for (final t in times) {
        final r = clip.root(t);
        rootT.addAll([r.x, 0.0, r.z]);
        rootR.addAll([0.0, math.sin(r.yaw / 2), 0.0, math.cos(r.yaw / 2)]);
        final swing = clip.footSign * (clip.moving(t) ? clip.stride * math.sin(2 * math.pi * clip.cadence / 2 * t) : 0.0);
        footL.addAll([0.1, -0.85, swing]);
        footR.addAll([-0.1, -0.85, -swing]);
      }
      final samplers = <Map<String, dynamic>>[];
      final channels = <Map<String, dynamic>>[];
      void channel(int node, String path, List<double> values) {
        samplers.add({'input': input, 'output': addFloats(values, path == 'rotation' ? 'VEC4' : 'VEC3'), 'interpolation': 'LINEAR'});
        channels.add({'sampler': samplers.length - 1, 'target': {'node': node, 'path': path}});
      }

      channel(1, 'translation', rootT);
      channel(1, 'rotation', rootR);
      channel(3, 'translation', footL);
      channel(4, 'translation', footR);
      animations.add({'name': clip.name, 'samplers': samplers, 'channels': channels});
    }
    while (bin.length % 4 != 0) {
      bin.addByte(0);
    }
    final bytes = bin.toBytes();
    final json = <String, dynamic>{
      'asset': {'version': '2.0', 'generator': 'Lumina synthetic locomotion rig'},
      'scene': 0,
      'scenes': [
        {'nodes': [0]},
      ],
      'nodes': nodes,
      'skins': [
        {'joints': [1, 2, 3, 4, 5, 6], 'inverseBindMatrices': ibmAccessor},
      ],
      'animations': animations,
      'accessors': accessors,
      'bufferViews': bufferViews,
      'buffers': [
        {'byteLength': bytes.length},
      ],
    };
    return GlbDocument(json, bytes).encode();
  }
}
