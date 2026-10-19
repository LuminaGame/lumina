import 'dart:math' as math;

import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

/// A level box (authoring space: cm, Z up) with its yaw, for contact
/// measurements against the character's joints.
class GaspBox {
  final String name;
  final List<double> center;
  final List<double> size;

  /// Rotation about Z (degrees); boxes tilted about other axes are skipped.
  final double yawDegrees;

  const GaspBox(this.name, this.center, this.size, this.yawDegrees);

  double get top => center[2] + size[2] / 2;

  /// [p] (authoring) in the box's frame, relative to its centre.
  List<double> local(List<double> p) {
    final a = -yawDegrees * math.pi / 180.0;
    final dx = p[0] - center[0], dy = p[1] - center[1];
    return [dx * math.cos(a) - dy * math.sin(a), dx * math.sin(a) + dy * math.cos(a), p[2] - center[2]];
  }

  /// How deep [p] (authoring) is inside the box (cm; ≤ 0 outside: minus the
  /// distance to the box).
  double depth(List<double> p) {
    final l = local(p);
    final d = [for (var i = 0; i < 3; i++) l[i].abs() - size[i] / 2];
    final outside = math.sqrt([for (final v in d) math.max(v, 0.0) * math.max(v, 0.0)].reduce((a, b) => a + b));
    if (outside > 0) return -outside;
    return -d.reduce(math.max);
  }

  /// Whether [p] (authoring) is over the box's top face (within [margin] cm
  /// of it horizontally).
  bool over(List<double> p, {double margin = 0.0}) {
    final l = local(p);
    return l[0].abs() <= size[0] / 2 + margin && l[1].abs() <= size[1] / 2 + margin;
  }
}

/// The level's boxes (not the floor, not tilted).
List<GaspBox> gaspBoxes(List<Map> actors) => [
      for (final a in actors)
        if (a['type'] == 'Primitive' && a['name'] != 'Floor')
          () {
            final p = Map<String, dynamic>.from(((a['components'] as List).first as Map)['properties'] as Map);
            final rot = ((a['rotation'] as List?) ?? const [0, 0, 0]).cast<num>();
            if (rot[0].abs() > 0.01 || rot[1].abs() > 0.01) return null;
            return GaspBox(
              a['name'] as String,
              [for (final v in (a['location'] as List)) (v as num).toDouble()],
              [for (final k in ['sizeX', 'sizeY', 'sizeZ']) (p[k] as num?)?.toDouble() ?? 100.0],
              rot[2].toDouble(),
            );
          }(),
    ].whereType<GaspBox>().toList();

/// The joints whose positions stand for the body when measuring how far it
/// goes into the level: torso, head, limbs.
const gaspBodyJoints = [
  'pelvis',
  'spine_03',
  'spine_05',
  'neck_01',
  'head',
  'thigh_l',
  'thigh_r',
  'calf_l',
  'calf_r',
  'foot_l',
  'foot_r',
  'upperarm_l',
  'upperarm_r',
  'lowerarm_l',
  'lowerarm_r',
  'hand_l',
  'hand_r',
];

/// [joint]'s position in authoring space (cm, Z up), or null.
List<double>? gaspJoint(LuminaAnimatedMeshComponent mesh, String joint) {
  final m = mesh.jointWorldTransform(joint);
  if (m == null) return null;
  final t = m.getTranslation();
  return LuminaAxes.toAuthoringLocation(Vector3(t.x, t.y, t.z));
}

/// The deepest any of [joints] is inside any of [boxes] now: (depth cm,
/// joint, box name); depth ≤ 0 when none is inside.
(double, String, String) gaspDeepestJoint(
    LuminaAnimatedMeshComponent mesh, List<GaspBox> boxes, {List<String> joints = gaspBodyJoints}) {
  var best = (-1e9, '', '');
  for (final j in joints) {
    final p = gaspJoint(mesh, j);
    if (p == null) continue;
    for (final b in boxes) {
      final d = b.depth(p);
      if (d > best.$1) best = (d, j, b.name);
    }
  }
  return best;
}
