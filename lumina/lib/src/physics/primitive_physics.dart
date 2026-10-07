import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/math/axes.dart';
import 'package:lumina/src/physics/mass_properties.dart';
import 'package:lumina/src/physics/physical_material.dart';
import 'package:lumina/src/physics/physics_subsystem.dart';
import 'package:lumina/src/physics/rigid_body.dart';

/// The Physics section of a primitive component, mixed into
/// collision components and static mesh components.
///
/// With [simulatePhysics] on, the component becomes a rigid body in the
/// world's [LuminaPhysicsSubsystem] when play begins (or when it is switched
/// on during play): it falls, rests, tumbles, rolls, bounces and sleeps, and
/// drives its actor (see [LuminaPhysicsSubsystem]).
///
/// Mass: [overrideMass] ? [massKg] : the static mesh's `metadata.physics.massKg`
/// ([meshPhysics], from this component or its actor's static mesh) ?? density
/// × volume. The centre of mass moves by [centerOfMassOffset] when set, else by
/// the mesh's. Vectors are runtime axes (cm, Y up); the JSON is authoring space.
mixin LuminaPrimitivePhysics on LuminaSceneComponent {
  bool _simulatePhysics = false;

  /// Whether this component is a simulated rigid body.
  bool get simulatePhysics => _simulatePhysics;
  set simulatePhysics(bool value) {
    if (value == _simulatePhysics) return;
    _simulatePhysics = value;
    final world = owner?.world;
    if (world == null || !(owner?.hasBegunPlay ?? false)) return;
    if (value) {
      LuminaPhysicsSubsystem.ensure(world)?.addBody(this);
    } else {
      world.getSubsystem<LuminaPhysicsSubsystem>()?.removeBody(this);
    }
  }

  double _massKg = 0.0;
  bool _overrideMass = false;

  /// The mass used when [overrideMass] is on (Mass in Kg).
  double get massKg => _massKg;
  set massKg(double v) {
    _massKg = v;
    _refreshMass();
  }

  /// Whether [massKg] replaces the inherited / computed mass.
  bool get overrideMass => _overrideMass;
  set overrideMass(bool v) {
    _overrideMass = v;
    _refreshMass();
  }

  Vector3? _centerOfMassOffset;

  /// This component's centre-of-mass offset (runtime cm); null inherits the
  /// static mesh's.
  Vector3? get centerOfMassOffset => _centerOfMassOffset;
  set centerOfMassOffset(Vector3? v) {
    _centerOfMassOffset = v?.clone();
    _refreshMass();
  }

  LuminaMeshPhysics? _meshPhysics;

  /// The static mesh asset's physics this component inherits (the component
  /// mapping resolves it from the mesh `.lmas`, or from the values the editor
  /// baked into the component's `physics.meshPhysics`).
  LuminaMeshPhysics? get meshPhysics => _meshPhysics;
  set meshPhysics(LuminaMeshPhysics? v) {
    _meshPhysics = v;
    _refreshMass();
  }

  double _linearDamping = 0.01;
  double _angularDamping = 0.0;
  bool _enableGravity = true;
  LuminaPhysicalMaterial? _physicalMaterial;

  double get linearDamping => _linearDamping;
  set linearDamping(double v) {
    _linearDamping = v < 0 ? 0 : v;
    physicsBody?.linearDamping = _linearDamping;
  }

  double get angularDamping => _angularDamping;
  set angularDamping(double v) {
    _angularDamping = v < 0 ? 0 : v;
    physicsBody?.angularDamping = _angularDamping;
  }

  bool get enableGravity => _enableGravity;
  set enableGravity(bool v) {
    _enableGravity = v;
    final body = physicsBody;
    if (body != null) {
      body.enableGravity = v;
      body.wake();
    }
  }

  /// Friction, restitution and density; null is [LuminaPhysicalMaterial.standard].
  LuminaPhysicalMaterial? get physicalMaterial => _physicalMaterial;
  set physicalMaterial(LuminaPhysicalMaterial? v) {
    _physicalMaterial = v;
    physicsBody?.material = effectivePhysicalMaterial;
    _refreshMass();
  }

  LuminaPhysicalMaterial get effectivePhysicalMaterial => _physicalMaterial ?? LuminaPhysicalMaterial.standard;

  // Constraints: authoring axes (X, Y horizontal, Z up), as the Details panel.
  bool _lockPositionX = false, _lockPositionY = false, _lockPositionZ = false;
  bool _lockRotationX = false, _lockRotationY = false, _lockRotationZ = false;

  bool get lockPositionX => _lockPositionX;
  set lockPositionX(bool v) => _setLock(() => _lockPositionX = v);
  bool get lockPositionY => _lockPositionY;
  set lockPositionY(bool v) => _setLock(() => _lockPositionY = v);
  bool get lockPositionZ => _lockPositionZ;
  set lockPositionZ(bool v) => _setLock(() => _lockPositionZ = v);
  bool get lockRotationX => _lockRotationX;
  set lockRotationX(bool v) => _setLock(() => _lockRotationX = v);
  bool get lockRotationY => _lockRotationY;
  set lockRotationY(bool v) => _setLock(() => _lockRotationY = v);
  bool get lockRotationZ => _lockRotationZ;
  set lockRotationZ(bool v) => _setLock(() => _lockRotationZ = v);

  void _setLock(void Function() set) {
    set();
    final body = physicsBody;
    if (body != null) applyLocksTo(body);
  }

  /// Writes the locks into [body]'s runtime-axis factors (authoring X, Y, Z
  /// are runtime x, z, y).
  void applyLocksTo(LuminaRigidBody body) {
    body.linearFactor.setValues(_lockPositionX ? 0 : 1, _lockPositionZ ? 0 : 1, _lockPositionY ? 0 : 1);
    body.angularFactor.setValues(_lockRotationX ? 0 : 1, _lockRotationZ ? 0 : 1, _lockRotationY ? 0 : 1);
  }

  /// The rigid body simulating this component (or the body this collision
  /// shape belongs to); null while not simulating.
  LuminaRigidBody? physicsBody;

  /// Whether a rigid body moves this component.
  bool get isSimulatingPhysics => physicsBody != null;

  /// Called when this component's body falls asleep / wakes up.
  void Function(LuminaSceneComponent self)? onComponentSleep;
  void Function(LuminaSceneComponent self)? onComponentWake;

  /// The mass the body has (or would have when it starts simulating), kg.
  double get resolvedMassKg => physicsBody?.mass ?? LuminaPhysicsSubsystem.resolveMassProperties(this).mass;

  void _refreshMass() {
    final body = physicsBody;
    if (body == null) return;
    owner?.world?.getSubsystem<LuminaPhysicsSubsystem>()?.refreshMass(body);
  }

  // --- JSON (component mapping, editor) ---------------------------------------

  /// The component JSON's `physics` map: `{simulate, massKg, overrideMass,
  /// centerOfMassOffset, linearDamping, angularDamping, enableGravity,
  /// friction, restitution, locks: {position: [x, y, z], rotation: [x, y, z]}}`,
  /// vectors and lock axes in authoring space (cm, Z up). A `meshPhysics`
  /// entry (`{massKg, centerOfMassOffset}`) carries inherited values the
  /// editor resolved from the static mesh.
  Map<String, dynamic> toPhysicsJson() => {
        'simulate': _simulatePhysics,
        'massKg': _massKg,
        'overrideMass': _overrideMass,
        if (_centerOfMassOffset != null) 'centerOfMassOffset': LuminaAxes.toAuthoringLocation(_centerOfMassOffset!),
        'linearDamping': _linearDamping,
        'angularDamping': _angularDamping,
        'enableGravity': _enableGravity,
        'friction': effectivePhysicalMaterial.friction,
        'restitution': effectivePhysicalMaterial.restitution,
        'locks': {
          'position': [_lockPositionX, _lockPositionY, _lockPositionZ],
          'rotation': [_lockRotationX, _lockRotationY, _lockRotationZ],
        },
      };

  /// Applies [toPhysicsJson]'s shape; keys the map lacks keep their values.
  void applyPhysicsJson(Map<String, dynamic> json) {
    double? number(String k) => json[k] is num ? (json[k] as num).toDouble() : null;
    bool? flag(String k) => json[k] is bool ? json[k] as bool : null;
    _massKg = number('massKg') ?? _massKg;
    _overrideMass = flag('overrideMass') ?? _overrideMass;
    final com = json['centerOfMassOffset'];
    if (com is List && com.length >= 3 && com.every((e) => e is num)) {
      _centerOfMassOffset = LuminaAxes.location(com.cast<num>());
    }
    final mesh = LuminaMeshPhysics.fromJson(json['meshPhysics']);
    if (mesh != null) _meshPhysics = mesh;
    linearDamping = number('linearDamping') ?? _linearDamping;
    angularDamping = number('angularDamping') ?? _angularDamping;
    enableGravity = flag('enableGravity') ?? _enableGravity;
    final friction = number('friction'), restitution = number('restitution'), density = number('density');
    if (friction != null || restitution != null || density != null) {
      physicalMaterial = effectivePhysicalMaterial.copyWith(friction: friction, restitution: restitution, density: density);
    }
    final locks = json['locks'];
    if (locks is Map) {
      List<bool>? axes(String k) {
        final v = locks[k];
        return v is List && v.length >= 3 ? [for (final e in v.take(3)) e == true] : null;
      }

      final p = axes('position'), r = axes('rotation');
      if (p != null) {
        _lockPositionX = p[0];
        _lockPositionY = p[1];
        _lockPositionZ = p[2];
      }
      if (r != null) {
        _lockRotationX = r[0];
        _lockRotationY = r[1];
        _lockRotationZ = r[2];
      }
      final body = physicsBody;
      if (body != null) applyLocksTo(body);
    }
    _refreshMass();
    final simulate = flag('simulate');
    if (simulate != null) simulatePhysics = simulate;
  }

  // --- Gameplay (Blueprint Physics nodes) ---------------------------------------

  /// Add Impulse: kg·cm/s (or cm/s with [velocityChange]), runtime axes.
  void addImpulse(Vector3 impulse, {bool velocityChange = false}) =>
      physicsBody?.addImpulse(impulse, velocityChange: velocityChange);

  void addImpulseAtLocation(Vector3 impulse, Vector3 location) => physicsBody?.addImpulseAtLocation(impulse, location);

  /// kg·cm/s² for the next step (cm/s² with [accelChange]).
  void addForce(Vector3 force, {bool accelChange = false}) => physicsBody?.addForce(force, accelChange: accelChange);

  void addForceAtLocation(Vector3 force, Vector3 location) => physicsBody?.addForceAtLocation(force, location);

  /// kg·cm²/s² (rad/s² with [accelChange]).
  void addTorque(Vector3 torque, {bool accelChange = false}) => physicsBody?.addTorque(torque, accelChange: accelChange);

  /// kg·cm²/s (rad/s with [velocityChange]).
  void addAngularImpulse(Vector3 impulse, {bool velocityChange = false}) =>
      physicsBody?.addAngularImpulse(impulse, velocityChange: velocityChange);

  /// cm/s, runtime axes; zero while not simulating.
  Vector3 get physicsLinearVelocity => physicsBody?.linearVelocity.clone() ?? Vector3.zero();

  void setPhysicsLinearVelocity(Vector3 velocity, {bool addToCurrent = false}) {
    final body = physicsBody;
    if (body == null) return;
    if (addToCurrent) {
      body.linearVelocity.add(velocity);
    } else {
      body.linearVelocity.setFrom(velocity);
    }
    body.wake();
  }

  /// rad/s, runtime axes.
  Vector3 get physicsAngularVelocity => physicsBody?.angularVelocity.clone() ?? Vector3.zero();

  void setPhysicsAngularVelocity(Vector3 radiansPerSecond, {bool addToCurrent = false}) {
    final body = physicsBody;
    if (body == null) return;
    if (addToCurrent) {
      body.angularVelocity.add(radiansPerSecond);
    } else {
      body.angularVelocity.setFrom(radiansPerSecond);
    }
    body.wake();
  }

  void wakeRigidBody() => physicsBody?.wake();

  void putRigidBodyToSleep() => physicsBody?.sleep();

  bool get isAnyRigidBodyAwake => physicsBody?.isAwake ?? false;

  // --- Lifecycle ----------------------------------------------------------------

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    if (!_simulatePhysics) return;
    final world = owner?.world;
    if (world != null) LuminaPhysicsSubsystem.ensure(world)?.addBody(this);
  }

  @override
  void onUnregister() {
    if (physicsBody != null && identical(physicsBody!.component, this)) {
      owner?.world?.getSubsystem<LuminaPhysicsSubsystem>()?.removeBody(this);
    }
    super.onUnregister();
  }
}
