import 'dart:math' as math;

import 'package:lumina_editor_data/lumina_editor.dart'
    show BoxShape, CapsuleShape, CollisionShape, LuminaUnits, SphereShape, kWorldUnitsCentimetres;
import 'package:vector_math/vector_math_64.dart';

/// The three primitive types the Physics Asset editor authors.
///
/// The engine's collision module also carries cone and cylinder shapes; the
/// schema's [PhysicsShapeType] can grow later without breaking saved documents
/// because it is persisted by name.
enum PhysicsShapeType { capsule, box, sphere }

extension PhysicsShapeTypeLabel on PhysicsShapeType {
  String get label {
    switch (this) {
      case PhysicsShapeType.capsule:
        return 'Capsule';
      case PhysicsShapeType.box:
        return 'Box';
      case PhysicsShapeType.sphere:
        return 'Sphere';
    }
  }
}

/// Angular constraint modes of a joint between two bodies.
enum PhysicsAngularMode { free, limited, locked }

extension PhysicsAngularModeLabel on PhysicsAngularMode {
  String get label {
    switch (this) {
      case PhysicsAngularMode.free:
        return 'Free';
      case PhysicsAngularMode.limited:
        return 'Limited';
      case PhysicsAngularMode.locked:
        return 'Locked';
    }
  }
}

T _enumByName<T>(List<T> values, Object? raw, T fallback) {
  final name = raw?.toString();
  for (final v in values) {
    if (v.toString().split('.').last == name) return v;
  }
  return fallback;
}

double _d(Object? raw, double fallback) => (raw as num?)?.toDouble() ?? fallback;

List<double> _v3(Object? raw, List<double> fallback) {
  if (raw is List && raw.length >= 3) {
    return [for (int i = 0; i < 3; i++) (raw[i] as num).toDouble()];
  }
  return List<double>.from(fallback);
}

/// Euler XYZ degrees -> quaternion, matching the editor's transform convention.
Quaternion quaternionFromEulerDegrees(List<double> eulerDeg) {
  final rx = eulerDeg[0] * math.pi / 180.0;
  final ry = eulerDeg[1] * math.pi / 180.0;
  final rz = eulerDeg[2] * math.pi / 180.0;
  return Quaternion.euler(ry, rx, rz);
}

/// One authored rigid body attached to a single bone of the skeletal mesh.
///
/// Every length is in world units, **centimetres**:
/// radius, half height, box half extents and the offset location. The offset
/// is in the bone's own frame, so the world's up axis does not enter it.
///
/// Masses and damping have no solver behind them yet (lumina runs a kinematic
/// collision stack, not dynamics) but they are part of the persisted schema so
/// a future solver consumes the document unchanged.
class PhysicsBody {
  String boneName;
  PhysicsShapeType shape;

  /// Capsule / sphere radius, in cm.
  double radius;

  /// Half-height of the *full* capsule (the inner segment is
  /// `halfHeight - radius`), in cm. Always clamped to `>= radius`.
  double halfHeight;

  /// Box half extents (x, y, z) in cm.
  List<double> halfExtents;

  /// Offset of the body relative to its bone: location in cm, rotation in
  /// degrees, both in the bone's frame.
  List<double> offsetLocation;
  List<double> offsetRotationDeg;

  double massKg;
  double linearDamping;
  double angularDamping;

  /// Free-text physics-material name (no PM asset type exists yet).
  String physicsMaterial;

  /// Keys this editor does not show (written back unchanged).
  final Map<String, dynamic> extra;

  PhysicsBody({
    required this.boneName,
    required this.shape,
    this.radius = 10.0,
    this.halfHeight = 20.0,
    List<double>? halfExtents,
    List<double>? offsetLocation,
    List<double>? offsetRotationDeg,
    this.massKg = 1.0,
    this.linearDamping = 0.01,
    this.angularDamping = 0.0,
    this.physicsMaterial = '',
    Map<String, dynamic>? extra,
  })  : extra = extra ?? {},
        halfExtents = halfExtents ?? [10.0, 10.0, 10.0],
        offsetLocation = offsetLocation ?? [0.0, 0.0, 0.0],
        offsetRotationDeg = offsetRotationDeg ?? [0.0, 0.0, 0.0];

  /// `pelvis_Capsule` — the name shown in the tree, inspector and validation.
  String get name => '${boneName}_${shape.label}';

  /// Clamped half-height honouring the engine's `halfHeight >= radius` rule.
  double get effectiveHalfHeight => math.max(halfHeight, radius);

  /// The engine value type this body maps onto for narrow-phase tests.
  CollisionShape toCollisionShape() {
    switch (shape) {
      case PhysicsShapeType.capsule:
        return CapsuleShape(radius, effectiveHalfHeight);
      case PhysicsShapeType.box:
        return BoxShape(Vector3(halfExtents[0], halfExtents[1], halfExtents[2]));
      case PhysicsShapeType.sphere:
        return SphereShape(radius);
    }
  }

  /// Body-relative-to-bone transform (`offset` in `entityWorld x G_bone x offset`).
  Matrix4 get offsetTransform => Matrix4.compose(
        Vector3(offsetLocation[0], offsetLocation[1], offsetLocation[2]),
        quaternionFromEulerDegrees(offsetRotationDeg),
        Vector3(1.0, 1.0, 1.0),
      );

  Map<String, dynamic> toJson() => {
        ...extra,
        'bone': boneName,
        'shape': shape.name,
        'radius': radius,
        'half_height': halfHeight,
        'half_extents': halfExtents,
        'offset_t': offsetLocation,
        'offset_r': offsetRotationDeg,
        'mass_kg': massKg,
        'linear_damping': linearDamping,
        'angular_damping': angularDamping,
        'physics_material': physicsMaterial,
      };

  /// Reads a body; [lengthScale] converts its stored lengths to cm (1 for a
  /// cm document, [LuminaUnits.unitsPerMetre] for a legacy metre one).
  factory PhysicsBody.fromJson(Map<String, dynamic> j, {double lengthScale = 1.0}) {
    List<double> lengths(Object? raw, List<double> fallback) =>
        [for (final v in _v3(raw, fallback)) raw is List ? v * lengthScale : v];
    return PhysicsBody(
      boneName: j['bone'] as String? ?? '',
      shape: _enumByName(PhysicsShapeType.values, j['shape'], PhysicsShapeType.capsule),
      radius: j['radius'] is num ? _d(j['radius'], 0.0) * lengthScale : 10.0,
      halfHeight: j['half_height'] is num ? _d(j['half_height'], 0.0) * lengthScale : 20.0,
      halfExtents: lengths(j['half_extents'], const [10.0, 10.0, 10.0]),
      offsetLocation: lengths(j['offset_t'], const [0.0, 0.0, 0.0]),
      offsetRotationDeg: _v3(j['offset_r'], const [0.0, 0.0, 0.0]),
      massKg: _d(j['mass_kg'], 1.0),
      linearDamping: _d(j['linear_damping'], 0.01),
      angularDamping: _d(j['angular_damping'], 0.0),
      physicsMaterial: j['physics_material'] as String? ?? '',
      extra: _extraKeys(j, const {
        'bone', 'shape', 'radius', 'half_height', 'half_extents', 'offset_t', 'offset_r', 'mass_kg', //
        'linear_damping', 'angular_damping', 'physics_material',
      }),
    );
  }
}

/// The entries of [json] outside [known]: what the runtime reads and this
/// editor does not show (a joint's hinge range and frame) survives a save.
Map<String, dynamic> _extraKeys(Map<String, dynamic> json, Set<String> known) =>
    {for (final e in json.entries) if (!known.contains(e.key)) e.key: e.value};

/// A joint definition between two authored bodies, keyed by their bone names.
class PhysicsConstraint {
  /// Parent-side body bone name.
  String bodyA;

  /// Child-side body bone name; the constraint takes its display name from it.
  String bodyB;

  PhysicsAngularMode angularMode;
  double swing1Deg;
  double swing2Deg;
  double twistDeg;

  /// Keys this editor does not show (the joint type, an asymmetric twist
  /// range, the joint frame), written back unchanged.
  final Map<String, dynamic> extra;

  PhysicsConstraint({
    required this.bodyA,
    required this.bodyB,
    this.angularMode = PhysicsAngularMode.limited,
    this.swing1Deg = 45.0,
    this.swing2Deg = 45.0,
    this.twistDeg = 30.0,
    Map<String, dynamic>? extra,
  }) : extra = extra ?? {};

  /// `spine_01_Constraint`.
  String get name => '${bodyB}_Constraint';

  bool get limitsEnabled => angularMode == PhysicsAngularMode.limited;

  bool touches(String bone) => bodyA == bone || bodyB == bone;

  Map<String, dynamic> toJson() => {
        ...extra,
        'body_a': bodyA,
        'body_b': bodyB,
        'angular_mode': angularMode.name,
        'swing1_deg': swing1Deg,
        'swing2_deg': swing2Deg,
        'twist_deg': twistDeg,
      };

  factory PhysicsConstraint.fromJson(Map<String, dynamic> j) => PhysicsConstraint(
        bodyA: j['body_a'] as String? ?? '',
        bodyB: j['body_b'] as String? ?? '',
        angularMode: _enumByName(PhysicsAngularMode.values, j['angular_mode'], PhysicsAngularMode.limited),
        swing1Deg: _d(j['swing1_deg'], 45.0),
        swing2Deg: _d(j['swing2_deg'], 45.0),
        twistDeg: _d(j['twist_deg'], 30.0),
        extra: _extraKeys(j, const {'body_a', 'body_b', 'angular_mode', 'swing1_deg', 'swing2_deg', 'twist_deg'}),
      );
}

/// The whole authored PHYSICS_ASSET payload, persisted as versioned JSON in
/// `LuminaAsset.metadata['physics_asset']`.
///
/// Lengths are centimetres, and the JSON says so with `world_units: 'cm'`
/// (the manifest's marker). Schema 1 documents carry no marker:
/// they were authored in metres before the engine switched, and [fromJson]
/// converts them. The conversion is exact, since every length is
/// bone-relative.
class PhysicsAssetDocument {
  /// 2: lengths in cm, `world_units` marker. 1: metres, no marker.
  static const int schemaVersion = 2;

  /// JSON key of the units marker.
  static const String worldUnitsKey = 'world_units';

  final List<PhysicsBody> bodies;
  final List<PhysicsConstraint> constraints;

  /// Unordered bone-name pairs whose bodies never collide.
  final List<List<String>> disabledCollisionPairs;

  /// True when this document was read from metre-authored JSON with bodies
  /// and converted to cm on load; the next save writes it in cm.
  final bool migratedFromMetres;

  PhysicsAssetDocument({
    List<PhysicsBody>? bodies,
    List<PhysicsConstraint>? constraints,
    List<List<String>>? disabledCollisionPairs,
    this.migratedFromMetres = false,
  })  : bodies = bodies ?? [],
        constraints = constraints ?? [],
        disabledCollisionPairs = disabledCollisionPairs ?? [];

  PhysicsBody? bodyForBone(String boneName) {
    for (final b in bodies) {
      if (b.boneName == boneName) return b;
    }
    return null;
  }

  PhysicsConstraint? constraintByName(String name) {
    for (final c in constraints) {
      if (c.name == name) return c;
    }
    return null;
  }

  List<PhysicsConstraint> constraintsForBone(String boneName) =>
      constraints.where((c) => c.bodyB == boneName).toList();

  bool isPairDisabled(String a, String b) {
    for (final p in disabledCollisionPairs) {
      if (p.length < 2) continue;
      if ((p[0] == a && p[1] == b) || (p[0] == b && p[1] == a)) return true;
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
        'v': schemaVersion,
        worldUnitsKey: kWorldUnitsCentimetres,
        'bodies': bodies.map((b) => b.toJson()).toList(),
        'constraints': constraints.map((c) => c.toJson()).toList(),
        'disabled_collision_pairs': disabledCollisionPairs,
      };

  factory PhysicsAssetDocument.fromJson(Map<String, dynamic> j) {
    final metres = j[worldUnitsKey] != kWorldUnitsCentimetres;
    final rawBodies = (j['bodies'] as List?) ?? const [];
    return PhysicsAssetDocument(
        migratedFromMetres: metres && rawBodies.isNotEmpty,
        bodies: rawBodies
            .map((e) => PhysicsBody.fromJson(Map<String, dynamic>.from(e as Map),
                lengthScale: metres ? LuminaUnits.unitsPerMetre : 1.0))
            .toList(),
        constraints: ((j['constraints'] as List?) ?? const [])
            .map((e) => PhysicsConstraint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        disabledCollisionPairs: ((j['disabled_collision_pairs'] as List?) ?? const [])
            .map((e) => (e as List).map((s) => s.toString()).toList())
            .where((p) => p.length >= 2)
            .toList(),
      );
  }
}

/// One pair result of the `Validate Overlaps` bind-pose narrow-phase pass.
class PhysicsOverlapResult {
  final String bodyA;
  final String bodyB;
  final double penetrationDepth;
  final bool isColliding;

  /// True when the pair is on the disabled-collision list (skipped, not tested).
  final bool disabled;

  /// Bone names, for click-to-select from the result list.
  final String boneA;
  final String boneB;

  const PhysicsOverlapResult({
    required this.bodyA,
    required this.bodyB,
    required this.boneA,
    required this.boneB,
    required this.penetrationDepth,
    required this.isColliding,
    required this.disabled,
  });
}

/// Viewport overlay modes offered by the `View Modes` select.
enum PhysicsViewMode { solidBodies, wireframeBodies, constraintsOnly }

extension PhysicsViewModeLabel on PhysicsViewMode {
  String get label {
    switch (this) {
      case PhysicsViewMode.solidBodies:
        return 'Solid Bodies';
      case PhysicsViewMode.wireframeBodies:
        return 'Wireframe Bodies';
      case PhysicsViewMode.constraintsOnly:
        return 'Constraints Only';
    }
  }
}

/// A batch of world-space line segments for one body or constraint marker,
/// ready to hand to `FilamentWireframeMesh.createLineSegments`.
class PhysicsOverlayLineSet {
  final String name;
  final bool isConstraint;
  final bool isSelected;

  /// Rendered dimmed because the body sits on a disabled-collision pair.
  final bool dimmed;

  /// Solid-bodies mode asks the 2D painter for a translucent fill.
  final bool filled;

  /// Flat xyz triples in world space.
  final List<double> positions;

  /// Index pairs into [positions] / 3.
  final List<int> lineIndices;

  const PhysicsOverlayLineSet({
    required this.name,
    required this.positions,
    required this.lineIndices,
    this.isConstraint = false,
    this.isSelected = false,
    this.dimmed = false,
    this.filled = false,
  });
}
