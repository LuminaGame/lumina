import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina_core/src/formats/lumina_project.dart' show kWorldUnitsCentimetres;
import 'package:lumina_core/src/math/units.dart';

/// The shapes a physics asset body can have.
enum LuminaPhysicsBodyShape { capsule, box, sphere }

/// How a constraint limits the rotation between its two bodies.
enum LuminaPhysicsAngularMode { free, limited, locked }

/// What kind of joint a constraint is: a ball-and-socket (swing cone and
/// twist range) or a hinge (swing locked, twist range only, about the joint
/// frame's X axis).
enum LuminaPhysicsJointType { ball, hinge }

T _byName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return fallback;
}

double _d(Object? raw, double fallback) => raw is num ? raw.toDouble() : fallback;

List<double> _v3(Object? raw, List<double> fallback) =>
    raw is List && raw.length >= 3 ? [for (var i = 0; i < 3; i++) (raw[i] as num).toDouble()] : List<double>.from(fallback);

Map<String, dynamic> _extra(Map<String, dynamic> json, Set<String> known) =>
    {for (final e in json.entries) if (!known.contains(e.key)) e.key: e.value};

/// One rigid body of a physics asset, attached to a bone.
///
/// Lengths are world units (cm). [offsetLocation] / [offsetRotationDegrees]
/// place the shape in the bone's frame (its world rotation, translation in
/// cm, no scale): `bodyWorld = boneWorld · offset`. A capsule lies along its
/// local Y axis; [halfHeight] is the half length including the caps.
class LuminaPhysicsBodyData {
  String bone;
  LuminaPhysicsBodyShape shape;
  double radius;
  double halfHeight;
  List<double> halfExtents;
  List<double> offsetLocation;

  /// Euler XYZ degrees, composed as `Ry · Rx · Rz` (the editor's convention).
  List<double> offsetRotationDegrees;
  double massKg;
  double linearDamping;
  double angularDamping;
  String physicsMaterial;

  /// Keys this version does not know, written back unchanged.
  final Map<String, dynamic> extra;

  LuminaPhysicsBodyData({
    required this.bone,
    this.shape = LuminaPhysicsBodyShape.capsule,
    this.radius = 10.0,
    this.halfHeight = 20.0,
    List<double>? halfExtents,
    List<double>? offsetLocation,
    List<double>? offsetRotationDegrees,
    this.massKg = 1.0,
    this.linearDamping = 0.01,
    this.angularDamping = 0.0,
    this.physicsMaterial = '',
    Map<String, dynamic>? extra,
  })  : halfExtents = halfExtents ?? [10.0, 10.0, 10.0],
        offsetLocation = offsetLocation ?? [0.0, 0.0, 0.0],
        offsetRotationDegrees = offsetRotationDegrees ?? [0.0, 0.0, 0.0],
        extra = extra ?? {};

  /// The capsule's half length, never shorter than its radius.
  double get effectiveHalfHeight => math.max(halfHeight, radius);

  Vector3 get offsetVector => Vector3(offsetLocation[0], offsetLocation[1], offsetLocation[2]);
  Quaternion get offsetQuaternion => LuminaPhysicsAssetData.eulerToQuaternion(offsetRotationDegrees);

  static const Set<String> _known = {
    'bone', 'shape', 'radius', 'half_height', 'half_extents', 'offset_t', 'offset_r', 'mass_kg', //
    'linear_damping', 'angular_damping', 'physics_material',
  };

  Map<String, dynamic> toJson() => {
        ...extra,
        'bone': bone,
        'shape': shape.name,
        'radius': radius,
        'half_height': halfHeight,
        'half_extents': halfExtents,
        'offset_t': offsetLocation,
        'offset_r': offsetRotationDegrees,
        'mass_kg': massKg,
        'linear_damping': linearDamping,
        'angular_damping': angularDamping,
        'physics_material': physicsMaterial,
      };

  /// [lengthScale] converts stored lengths to cm (100 for a metre document).
  factory LuminaPhysicsBodyData.fromJson(Map<String, dynamic> j, {double lengthScale = 1.0}) {
    List<double> lengths(Object? raw, List<double> fallback) =>
        [for (final v in _v3(raw, fallback)) raw is List ? v * lengthScale : v];
    return LuminaPhysicsBodyData(
      bone: j['bone'] as String? ?? '',
      shape: _byName(LuminaPhysicsBodyShape.values, j['shape'], LuminaPhysicsBodyShape.capsule),
      radius: j['radius'] is num ? _d(j['radius'], 0) * lengthScale : 10.0,
      halfHeight: j['half_height'] is num ? _d(j['half_height'], 0) * lengthScale : 20.0,
      halfExtents: lengths(j['half_extents'], const [10.0, 10.0, 10.0]),
      offsetLocation: lengths(j['offset_t'], const [0.0, 0.0, 0.0]),
      offsetRotationDegrees: _v3(j['offset_r'], const [0.0, 0.0, 0.0]),
      massKg: _d(j['mass_kg'], 1.0),
      linearDamping: _d(j['linear_damping'], 0.01),
      angularDamping: _d(j['angular_damping'], 0.0),
      physicsMaterial: j['physics_material'] as String? ?? '',
      extra: _extra(j, _known),
    );
  }
}

/// A joint between the bodies of [bodyA] (the parent side) and [bodyB] (the
/// child side), by bone name.
///
/// The joint sits at [bodyB]'s bone origin. Its frame is [frameRotationDegrees]
/// in [bodyB]'s bone frame (Euler as the body offsets; null: the bone's own
/// frame): X is the twist axis, the swing cone is [swing1Degrees] about Y and
/// [swing2Degrees] about Z, measured from the rest pose. A hinge turns about
/// X only, between [twistMinDegrees] and [twistMaxDegrees].
class LuminaPhysicsConstraintData {
  String bodyA;
  String bodyB;
  LuminaPhysicsAngularMode angularMode;
  LuminaPhysicsJointType type;
  double swing1Degrees;
  double swing2Degrees;

  /// Symmetric twist (the editor's field); [twistMinDegrees] /
  /// [twistMaxDegrees] override it when set.
  double twistDegrees;
  double? twistMinDegrees;
  double? twistMaxDegrees;
  List<double>? frameRotationDegrees;
  final Map<String, dynamic> extra;

  LuminaPhysicsConstraintData({
    required this.bodyA,
    required this.bodyB,
    this.angularMode = LuminaPhysicsAngularMode.limited,
    this.type = LuminaPhysicsJointType.ball,
    this.swing1Degrees = 45.0,
    this.swing2Degrees = 45.0,
    this.twistDegrees = 30.0,
    this.twistMinDegrees,
    this.twistMaxDegrees,
    this.frameRotationDegrees,
    Map<String, dynamic>? extra,
  }) : extra = extra ?? {};

  double get effectiveTwistMin => twistMinDegrees ?? -twistDegrees;
  double get effectiveTwistMax => twistMaxDegrees ?? twistDegrees;

  Quaternion get frameQuaternion =>
      frameRotationDegrees == null ? Quaternion.identity() : LuminaPhysicsAssetData.eulerToQuaternion(frameRotationDegrees!);

  static const Set<String> _known = {
    'body_a', 'body_b', 'angular_mode', 'swing1_deg', 'swing2_deg', 'twist_deg', //
    'type', 'twist_min_deg', 'twist_max_deg', 'frame_r',
  };

  Map<String, dynamic> toJson() => {
        ...extra,
        'body_a': bodyA,
        'body_b': bodyB,
        'angular_mode': angularMode.name,
        'swing1_deg': swing1Degrees,
        'swing2_deg': swing2Degrees,
        'twist_deg': twistDegrees,
        'type': type.name,
        'twist_min_deg': ?twistMinDegrees,
        'twist_max_deg': ?twistMaxDegrees,
        'frame_r': ?frameRotationDegrees,
      };

  factory LuminaPhysicsConstraintData.fromJson(Map<String, dynamic> j) => LuminaPhysicsConstraintData(
        bodyA: j['body_a'] as String? ?? '',
        bodyB: j['body_b'] as String? ?? '',
        angularMode: _byName(LuminaPhysicsAngularMode.values, j['angular_mode'], LuminaPhysicsAngularMode.limited),
        type: _byName(LuminaPhysicsJointType.values, j['type'], LuminaPhysicsJointType.ball),
        swing1Degrees: _d(j['swing1_deg'], 45.0),
        swing2Degrees: _d(j['swing2_deg'], 45.0),
        twistDegrees: _d(j['twist_deg'], 30.0),
        twistMinDegrees: j['twist_min_deg'] is num ? _d(j['twist_min_deg'], 0) : null,
        twistMaxDegrees: j['twist_max_deg'] is num ? _d(j['twist_max_deg'], 0) : null,
        frameRotationDegrees: j['frame_r'] is List ? _v3(j['frame_r'], const [0, 0, 0]) : null,
        extra: _extra(j, _known),
      );
}

/// A physics asset: per-bone bodies, the joints between them and the body
/// pairs that never collide. Stored as JSON in a `physicsAsset` `.lmas`
/// under `metadata['physics_asset']` (the Physics Asset editor's document,
/// schema 2, lengths in cm; schema 1 documents were metres).
class LuminaPhysicsAssetData {
  static const int schemaVersion = 2;
  static const String metadataKey = 'physics_asset';
  static const String skeletalMeshSlot = 'skeletal_mesh';
  static const String worldUnitsKey = 'world_units';

  final List<LuminaPhysicsBodyData> bodies;
  final List<LuminaPhysicsConstraintData> constraints;
  final List<List<String>> disabledCollisionPairs;
  final Map<String, dynamic> extra;

  LuminaPhysicsAssetData({
    List<LuminaPhysicsBodyData>? bodies,
    List<LuminaPhysicsConstraintData>? constraints,
    List<List<String>>? disabledCollisionPairs,
    Map<String, dynamic>? extra,
  })  : bodies = bodies ?? [],
        constraints = constraints ?? [],
        disabledCollisionPairs = disabledCollisionPairs ?? [],
        extra = extra ?? {};

  LuminaPhysicsBodyData? bodyForBone(String bone) {
    for (final b in bodies) {
      if (b.bone == bone) return b;
    }
    return null;
  }

  bool isPairDisabled(String a, String b) {
    for (final p in disabledCollisionPairs) {
      if ((p[0] == a && p[1] == b) || (p[0] == b && p[1] == a)) return true;
    }
    return false;
  }

  double get totalMassKg => bodies.fold(0.0, (s, b) => s + b.massKg);

  Map<String, dynamic> toJson() => {
        ...extra,
        'v': schemaVersion,
        worldUnitsKey: kWorldUnitsCentimetres,
        'bodies': [for (final b in bodies) b.toJson()],
        'constraints': [for (final c in constraints) c.toJson()],
        'disabled_collision_pairs': disabledCollisionPairs,
      };

  factory LuminaPhysicsAssetData.fromJson(Map<String, dynamic> j) {
    final metres = j[worldUnitsKey] != kWorldUnitsCentimetres;
    return LuminaPhysicsAssetData(
      bodies: [
        for (final e in (j['bodies'] as List?) ?? const [])
          LuminaPhysicsBodyData.fromJson(Map<String, dynamic>.from(e as Map),
              lengthScale: metres ? LuminaUnits.unitsPerMetre : 1.0),
      ],
      constraints: [
        for (final e in (j['constraints'] as List?) ?? const [])
          LuminaPhysicsConstraintData.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
      disabledCollisionPairs: [
        for (final e in (j['disabled_collision_pairs'] as List?) ?? const [])
          if (e is List && e.length >= 2) [e[0].toString(), e[1].toString()],
      ],
      extra: _extra(j, const {'v', worldUnitsKey, 'bodies', 'constraints', 'disabled_collision_pairs'}),
    );
  }

  /// Euler XYZ degrees → quaternion as the editor composes it: `Ry · Rx · Rz`.
  static Quaternion eulerToQuaternion(List<double> degrees) {
    const k = math.pi / 180.0;
    return Quaternion.euler(degrees[1] * k, degrees[0] * k, degrees[2] * k);
  }

  /// The inverse of [eulerToQuaternion].
  static List<double> quaternionToEuler(Quaternion q) {
    final m = q.normalized().asRotationMatrix();
    // Row-major entries of R = Ry(a) · Rx(b) · Rz(c).
    final m02 = m.entry(0, 2), m12 = m.entry(1, 2), m22 = m.entry(2, 2), m10 = m.entry(1, 0), m11 = m.entry(1, 1);
    const k = 180.0 / math.pi;
    final b = math.asin((-m12).clamp(-1.0, 1.0));
    double a, c;
    if (m12.abs() < 0.99999) {
      a = math.atan2(m02, m22);
      c = math.atan2(m10, m11);
    } else {
      // Gimbal lock: put everything into a.
      a = math.atan2(-m.entry(2, 0), m.entry(0, 0));
      c = 0.0;
    }
    return [b * k, a * k, c * k];
  }
}
