[Türkçe](../../tr/lumina/physics.md)

# Physics

Rigid-body dynamics: the physics subsystem that runs Simulate Physics for a world, rigid bodies and their convex shapes, mass properties, physical materials with friction and restitution, contact generation on top of the collision narrow phase, and the sequential-impulse contact solver. The solver is pure Dart, so it also runs in web builds. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/src/physics/contact_generation.dart`](#libsrcphysicscontact_generationdart)
- [`lib/src/physics/contact_solver.dart`](#libsrcphysicscontact_solverdart)
- [`lib/src/physics/mass_properties.dart`](#libsrcphysicsmass_propertiesdart)
- [`lib/src/physics/physical_material.dart`](#libsrcphysicsphysical_materialdart)
- [`lib/src/physics/physics_subsystem.dart`](#libsrcphysicsphysics_subsystemdart)
- [`lib/src/physics/primitive_physics.dart`](#libsrcphysicsprimitive_physicsdart)
- [`lib/src/physics/rigid_body.dart`](#libsrcphysicsrigid_bodydart)

## `lib/src/physics/contact_generation.dart`

### `class LuminaCollider`

One side of a contact test: a convex [shape] at world [transform] (with scale, which a box and a convex hull honour, as in the collision queries).

**Constructors:**

- `LuminaCollider(this.shape, this.transform)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `shape` | `CollisionShape shape` |  |
| `transform` | `Matrix4 transform` |  |

### `class LuminaContactSet`

The contact of two colliders: one [normal] pointing from A to B and up to four [points] (world, midway between the surfaces) with their penetration [depths] (negative: a gap inside the contact margin).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `normal` | `final Vector3 normal` |  |
| `points` | `final List<Vector3> points` |  |
| `depths` | `final List<double> depths` |  |
| `isEmpty` | `bool get isEmpty` |  |
| `clear` | `void clear()` |  |
| `add` | `void add(Vector3 point, double depth)` |  |

### `abstract final class LuminaContactGenerator`

Contact manifolds for the rigid-body solver: the existing narrow phase (analytic pairs, GJK/EPA) finds the normal and depth, and the touching features of the two shapes are clipped against each other for up to four points, so boxes rest on faces, capsules and cylinders on their sides, and tipping bodies on edges. Box pairs use the separating-axis test directly (faster and exact for the common case).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `defaultMargin` | `static const double defaultMargin` | Points closer than this (cm) to touching still make a contact. |
| `collide` | `static bool collide(LuminaCollider a, LuminaCollider b, LuminaContactSet out, {double margin = defaultMargin})` | Fills [out] with the contact of [a] and [b]; false when they do not touch. [b] may be a heightfield (the landscape); [a] never is. |
| `touchPoints` | `static List<Vector3> touchPoints(CollisionShape a, Matrix4 ta, CollisionShape b, Matrix4 tb, Vector3 nAB, {dou...` | Where [a] and [b] touch along [nAB] (from A to B) when they are within [margin] of each other: the clipped touching features' points (the midpoint of the two nearest points when the features do not overlap). For a pusher and what it pushes (a character's capsule and a body). |
| `feature` | `static List<Vector3> feature(CollisionShape shape, Matrix4 t, Vector3 dir)` | The feature of [shape] (at [t]) that is farthest along [dir]: a face (ordered polygon), an edge (two points) or a vertex, world space. |

## `lib/src/physics/contact_solver.dart`

### `class LuminaContactPoint`

One persistent contact point of a [LuminaContactManifold].

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `point` | `final Vector3 point` | World position, midway between the surfaces. |
| `localA` | `final Vector3 localA` | [point] in A's frame relative to its centre of mass (for matching the point next step and warm starting it). |
| `depth` | `double depth` | Penetration (negative: a gap inside the contact margin). |
| `normalImpulse` | `double normalImpulse` |  |
| `tangentImpulse1` | `double tangentImpulse1` |  |
| `tangentImpulse2` | `double tangentImpulse2` |  |
| `pseudoImpulse` | `double pseudoImpulse` |  |
| `normalMass` | `double normalMass` |  |
| `tangentMass1` | `double tangentMass1` |  |
| `tangentMass2` | `double tangentMass2` |  |
| `velocityBias` | `double velocityBias` |  |
| `relativeVelocity` | `double relativeVelocity` | Relative normal velocity before the solve (negative: approaching). |
| `maxNormalImpulse` | `double maxNormalImpulse` | The largest normal impulse of this step's passes. |
| `sticking` | `bool sticking` | Whether the surfaces were not sliding at this point (static friction). |
| `rA` | `final Vector3 rA` |  |
| `rB` | `final Vector3 rB` |  |
| `jacobian` | `final Float64List jacobian` | Per direction (normal, tangent 1, tangent 2), 12 values: rA × d, rB × d, and their angular responses I⁻¹(r × d) for A and B. |

### `class LuminaContactManifold`

The contact of body [a] with body [b] or, when [b] is null, with the static collider [componentB]: one normal (A → B) and up to four points, kept between steps so the solver can warm start.

**Constructors:**

- `LuminaContactManifold(this.a, this.b, this.componentA, this.componentB, this.key)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `a` | `final LuminaRigidBody a` |  |
| `b` | `final LuminaRigidBody? b` |  |
| `componentA` | `final LuminaCollisionComponent? componentA` | The colliding pieces: A's shape component and B's (a body shape or the static collider), for hit events. |
| `componentB` | `final LuminaCollisionComponent? componentB` |  |
| `key` | `final String key` |  |
| `normal` | `final Vector3 normal` |  |
| `tangent1` | `final Vector3 tangent1` |  |
| `tangent2` | `final Vector3 tangent2` |  |
| `points` | `final List<LuminaContactPoint> points` |  |
| `friction` | `double friction` |  |
| `staticFriction` | `double staticFriction` |  |
| `restitution` | `double restitution` |  |
| `approachSpeed` | `double approachSpeed` | Relative normal speed before the solve (positive: approaching). |
| `age` | `int age` | Steps this pair has been touching (0 on the step it began). |
| `lastStep` | `int lastStep` | The step the manifold was last refreshed on. |
| `normalImpulse` | `double get normalImpulse` | The total normal impulse of the last solve (kg·cm/s). |
| `update` | `void update(LuminaContactSet set, double matchDistance)` | Takes [set]'s points, carrying the impulses of the points that match the previous step's (within [matchDistance] cm in A's frame). |

### `class LuminaContactSolver`

Sequential-impulse contact solver with warm starting, Coulomb friction (static / dynamic), restitution and split-impulse position correction Bodies without a partner ([LuminaContactManifold.b] null) touch an immovable collider; a sleeping body is immovable too.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `restitutionThreshold` | `double restitutionThreshold` |  |
| `linearSlop` | `double linearSlop` |  |
| `baumgarte` | `double baumgarte` |  |
| `staticFrictionSpeed` | `double staticFrictionSpeed` |  |
| `manifolds` | `final List<LuminaContactManifold> manifolds` |  |
| `prepare` | `void prepare(double dt)` | Masses, restitution targets and warm starting, once per step. |
| `solveVelocities` | `void solveVelocities()` | One velocity pass over every contact: friction, then the normal. |
| `applyRestitution` | `void applyRestitution()` | After the velocity passes: points that were approaching faster than [restitutionThreshold] and did push leave at restitution × that speed. |
| `solvePositions` | `void solvePositions(double dt)` | One split-impulse pass: pushes penetrating bodies apart through the pseudo velocities, which never become momentum. |

## `lib/src/physics/mass_properties.dart`

### `class LuminaMeshPhysics`

What a static mesh asset says about its body: the Static Mesh editor's `metadata.physics = {massKg, centerOfMassOffset}`. [centerOfMassOffset] is authoring space (cm, Z up). A collision component inherits it from its actor's static mesh unless it overrides the mass.

**Constructors:**

- `const LuminaMeshPhysics({this.massKg, this.centerOfMassOffset = const [0.0, 0.0, 0.0]})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `massKg` | `final double? massKg` |  |
| `centerOfMassOffset` | `final List<double> centerOfMassOffset` | Authoring `[x, y, z]`, cm, Z up. |
| `fromJson` | `static LuminaMeshPhysics? fromJson(Object? json)` | Reads `{massKg, centerOfMassOffset}`; null when [json] is not a map. |
| `toJson` | `Map<String, dynamic> toJson()` |  |
| `runtimeCenterOfMassOffset` | `Vector3 get runtimeCenterOfMassOffset` | [centerOfMassOffset] in the runtime frame (cm, Y up). |

### `class LuminaShapeMass`

Volume, centroid and inertia of one convex shape at unit density: the inertia is **per unit mass** (kg·cm² per kg) about [centroid], in the shape's own frame, so any mass scales it.

**Constructors:**

- `const LuminaShapeMass(this.volume, this.centroid, this.unitInertia)`
- `factory LuminaShapeMass.box(Vector3 h)`: A box of half extents [h] (cm).
- `factory LuminaShapeMass.sphere(double r)`
- `factory LuminaShapeMass.capsule(double r, double halfHeight)`: A capsule along local +Y: [halfHeight] includes the caps.
- `factory LuminaShapeMass.cylinder(double r, double height)`: A cylinder along local +Y of full [height].
- `factory LuminaShapeMass.cone(double r, double height)`: A cone along local +Y: base at −[height]/2, apex at +[height]/2.
- `factory LuminaShapeMass.convex(ConvexHullShape hull, [Vector3? scale])`: A convex hull, its vertices scaled by [scale]: summed over the tetrahedra its triangles make with an inner point.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `volume` | `final double volume` | cm³. |
| `centroid` | `final Vector3 centroid` |  |
| `unitInertia` | `final Matrix3 unitInertia` | Inertia per unit mass about [centroid] (cm²). |

### `class LuminaMassProperties`

Mass, centre of mass and inertia of a whole body (kg, cm, kg·cm²), in the body's frame.

**Constructors:**

- `const LuminaMassProperties(this.mass, this.centerOfMass, this.inertia, this.volume)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `mass` | `final double mass` |  |
| `centerOfMass` | `final Vector3 centerOfMass` |  |
| `inertia` | `final Matrix3 inertia` | About [centerOfMass], body frame. |
| `volume` | `final double volume` | cm³, of all shapes together. |
| `combine` | `static LuminaMassProperties combine(List<({LuminaShapeMass mass, Vector3 position, Quaternion rotation})> part...` | Combines [parts] (each with its pose in the body frame) sharing one uniform density: [mass] kg in total, the centre of mass moved by [centerOfMassOffset] (body frame). |

## `lib/src/physics/physical_material.dart`

### `enum LuminaPhysicsCombineMode`

How two touching surfaces combine a friction or restitution value. When the two materials ask for different modes the later one in this list wins.

**Values:**

- `average`
- `min`
- `multiply`
- `max`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `displayName` | `String get displayName` | The display name: `Average`, `Min`, … |
| `parse` | `static LuminaPhysicsCombineMode? parse(Object? value)` | Parses a display or enum name; null when unknown. |

### `class LuminaPhysicalMaterial`

A surface's physical response: Coulomb [friction] (dynamic; [staticFriction] while at rest, the dynamic value when null), [restitution] (bounciness, 0–1) and [density] in g/cm³, which gives a body its mass from its volume when nothing else does.

**Constructors:**

- `const LuminaPhysicalMaterial({this.friction = defaultFriction, this.staticFriction, this.restitution = defaultRestitution, this.density = defaultDensity, this.f...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `friction` | `final double friction` |  |
| `staticFriction` | `final double? staticFriction` |  |
| `restitution` | `final double restitution` |  |
| `density` | `final double density` | g/cm³: water is 1. |
| `frictionCombineMode` | `final LuminaPhysicsCombineMode frictionCombineMode` |  |
| `restitutionCombineMode` | `final LuminaPhysicsCombineMode restitutionCombineMode` |  |
| `defaultFriction` | `static const double defaultFriction` |  |
| `defaultRestitution` | `static const double defaultRestitution` |  |
| `defaultDensity` | `static const double defaultDensity` |  |
| `standard` | `static const LuminaPhysicalMaterial standard` | The material a surface without one uses. |
| `effectiveStaticFriction` | `double get effectiveStaticFriction` | The friction that holds a body at rest. |
| `copyWith` | `LuminaPhysicalMaterial copyWith({double? friction, double? restitution, double? density})` |  |
| `combine` | `static double combine(double a, double b, LuminaPhysicsCombineMode mode)` | Combines [a] and [b] by [mode]. |
| `combinedFriction` | `static double combinedFriction(LuminaPhysicalMaterial a, LuminaPhysicalMaterial b)` | The dynamic friction of [a] touching [b]. |
| `combinedStaticFriction` | `static double combinedStaticFriction(LuminaPhysicalMaterial a, LuminaPhysicalMaterial b)` | The static friction of [a] touching [b]. |
| `combinedRestitution` | `static double combinedRestitution(LuminaPhysicalMaterial a, LuminaPhysicalMaterial b)` | The restitution of [a] touching [b]. |

## `lib/src/physics/physics_subsystem.dart`

### `class LuminaPhysicsSubsystem`

Rigid-body dynamics for a world (what a primitive component's Simulate Physics runs on). A pure-Dart solver on the existing narrow phase, so the web build simulates the same; it sits behind this class so a native engine could replace it.

- **Stepping**: fixed [fixedTimeStep] (120 Hz), at most [maxSubsteps] per frame; components are written at the pose interpolated between the last two steps. Pairs are processed in body-creation order, so the same input gives the same result. - **Contacts**: up to four points per pair from [LuminaContactGenerator], warm started across steps; [LuminaContactSolver] runs [velocityIterations] sequential-impulse passes (Coulomb friction, static and dynamic, restitution above [LuminaContactSolver.restitutionThreshold]) and [positionIterations] split-impulse passes. - **World**: every collision component that does not simulate (level geometry, the landscape heightfield, a character's capsule) blocks bodies as an immovable collider; gravity is the world's `gravityZ` (authoring −Z, runtime −Y). - **Sleep**: a group of touching bodies slower than [sleepLinearVelocity] / [sleepAngularVelocity] for [timeToSleep] sleeps; a contact with an awake body, an impulse or a force wakes it. - **Driving**: a simulating component that is its actor's root, or a direct child of the root, moves the whole actor; one deeper in the tree is detached and moves by itself. - **Events**: a contact whose normal impulse clearly exceeds resting (twice the effective weight for a step, and [hitImpulseThreshold]) raises `onComponentHit` and the actors' hit hooks (Blueprint Event Hit) once per frame with [HitResult.normalImpulse].

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `fixedTimeStep` | `double fixedTimeStep` |  |
| `maxSubsteps` | `int maxSubsteps` |  |
| `velocityIterations` | `int velocityIterations` |  |
| `positionIterations` | `int positionIterations` |  |
| `contactMargin` | `double contactMargin` |  |
| `sleepLinearVelocity` | `double sleepLinearVelocity` |  |
| `sleepAngularVelocity` | `double sleepAngularVelocity` |  |
| `timeToSleep` | `double timeToSleep` |  |
| `hitImpulseThreshold` | `double hitImpulseThreshold` |  |
| `interpolate` | `bool interpolate` | Write interpolated poses (true) or the last step's (false). |
| `solver` | `final LuminaContactSolver solver` |  |
| `stepCount` | `int stepCount` | Fixed steps taken so far, and the simulated time (s). |
| `simulatedTime` | `double simulatedTime` |  |
| `lastFrameSteps` | `int lastFrameSteps` | Steps taken in the last frame. |
| `bodies` | `List<LuminaRigidBody> get bodies` | The bodies, in creation order. |
| `contacts` | `List<LuminaContactManifold> get contacts` | The contacts of the last step. |
| `gravity` | `Vector3 get gravity` | Gravity in the runtime frame (cm/s²): the world's authoring Z. |
| `ensure` | `static LuminaPhysicsSubsystem? ensure(LuminaWorld world)` | [world]'s physics subsystem, registering one when it has none. During the subsystem tick (when registering is not allowed) the new subsystem is registered at the start of the next frame. |
| `addBody` | `LuminaRigidBody? addBody(LuminaPrimitivePhysics component)` | Makes [component] a rigid body (see [LuminaPrimitivePhysics]); returns it, or null when the component has no shape to simulate. |
| `removeBody` | `void removeBody(LuminaPrimitivePhysics component)` | Stops simulating [component]: it stays where it is. |
| `refreshMass` | `void refreshMass(LuminaRigidBody body)` | Recomputes [body]'s mass, centre of mass and inertia from its component's settings, keeping its pose and velocities. |
| `refreshShapes` | `void refreshShapes(LuminaRigidBody body)` | Rebuilds [body]'s shapes from its component (after a proxy resize or a collision child change). |
| `resolveMassProperties` | `static LuminaMassProperties resolveMassProperties(LuminaPrimitivePhysics component, [List<LuminaBodyShape>? sh...` | The mass properties [component] simulates with (see [LuminaPrimitivePhysics] for the mass rule). |
| `meshPhysicsOf` | `static LuminaMeshPhysics? meshPhysicsOf(LuminaPrimitivePhysics component)` | The static mesh physics [component] inherits: its own, else the nearest static mesh component's in its actor (a parent, then a child, then any). |
| `advance` | `void advance(double deltaTime)` | Runs the fixed steps [deltaTime] covers, then writes the components and raises the frame's hit events. |
| `step` | `void step(double dt)` | One fixed step of [dt] seconds. |

### `extension LuminaRigidBodyOwner on LuminaRigidBody`

The actor a body drives.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `owner` | `LuminaActor? get owner` |  |

## `lib/src/physics/primitive_physics.dart`

### `mixin LuminaPrimitivePhysics`

The Physics section of a primitive component, mixed into collision components and static mesh components.

With [simulatePhysics] on, the component becomes a rigid body in the world's [LuminaPhysicsSubsystem] when play begins (or when it is switched on during play): it falls, rests, tumbles, rolls, bounces and sleeps, and drives its actor (see [LuminaPhysicsSubsystem]).

Mass: [overrideMass] ? [massKg] : the static mesh's `metadata.physics.massKg` ([meshPhysics], from this component or its actor's static mesh) ?? density × volume. The centre of mass moves by [centerOfMassOffset] when set, else by the mesh's. Vectors are runtime axes (cm, Y up); the JSON is authoring space.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `simulatePhysics` | `bool get simulatePhysics` | Whether this component is a simulated rigid body. |
| `simulatePhysics` | `set simulatePhysics(bool value)` |  |
| `massKg` | `double get massKg` | The mass used when [overrideMass] is on (Mass in Kg). |
| `massKg` | `set massKg(double v)` |  |
| `overrideMass` | `bool get overrideMass` | Whether [massKg] replaces the inherited / computed mass. |
| `overrideMass` | `set overrideMass(bool v)` |  |
| `centerOfMassOffset` | `Vector3? get centerOfMassOffset` | This component's centre-of-mass offset (runtime cm); null inherits the static mesh's. |
| `centerOfMassOffset` | `set centerOfMassOffset(Vector3? v)` |  |
| `meshPhysics` | `LuminaMeshPhysics? get meshPhysics` | The static mesh asset's physics this component inherits (the component mapping resolves it from the mesh `.lmas`, or from the values the editor baked into the component's `physics.meshPhysics`). |
| `meshPhysics` | `set meshPhysics(LuminaMeshPhysics? v)` |  |
| `linearDamping` | `double get linearDamping` |  |
| `linearDamping` | `set linearDamping(double v)` |  |
| `angularDamping` | `double get angularDamping` |  |
| `angularDamping` | `set angularDamping(double v)` |  |
| `enableGravity` | `bool get enableGravity` |  |
| `enableGravity` | `set enableGravity(bool v)` |  |
| `physicalMaterial` | `LuminaPhysicalMaterial? get physicalMaterial` | Friction, restitution and density; null is [LuminaPhysicalMaterial.standard]. |
| `physicalMaterial` | `set physicalMaterial(LuminaPhysicalMaterial? v)` |  |
| `effectivePhysicalMaterial` | `LuminaPhysicalMaterial get effectivePhysicalMaterial` |  |
| `lockPositionX` | `bool get lockPositionX` |  |
| `lockPositionX` | `set lockPositionX(bool v)` |  |
| `lockPositionY` | `bool get lockPositionY` |  |
| `lockPositionY` | `set lockPositionY(bool v)` |  |
| `lockPositionZ` | `bool get lockPositionZ` |  |
| `lockPositionZ` | `set lockPositionZ(bool v)` |  |
| `lockRotationX` | `bool get lockRotationX` |  |
| `lockRotationX` | `set lockRotationX(bool v)` |  |
| `lockRotationY` | `bool get lockRotationY` |  |
| `lockRotationY` | `set lockRotationY(bool v)` |  |
| `lockRotationZ` | `bool get lockRotationZ` |  |
| `lockRotationZ` | `set lockRotationZ(bool v)` |  |
| `applyLocksTo` | `void applyLocksTo(LuminaRigidBody body)` | Writes the locks into [body]'s runtime-axis factors (authoring X, Y, Z are runtime x, z, y). |
| `physicsBody` | `LuminaRigidBody? physicsBody` | The rigid body simulating this component (or the body this collision shape belongs to); null while not simulating. |
| `isSimulatingPhysics` | `bool get isSimulatingPhysics` | Whether a rigid body moves this component. |
| `onComponentSleep` | `void Function(LuminaSceneComponent self)? onComponentSleep` | Called when this component's body falls asleep / wakes up. |
| `onComponentWake` | `void Function(LuminaSceneComponent self)? onComponentWake` |  |
| `resolvedMassKg` | `double get resolvedMassKg` | The mass the body has (or would have when it starts simulating), kg. |
| `toPhysicsJson` | `Map<String, dynamic> toPhysicsJson()` | The component JSON's `physics` map: `{simulate, massKg, overrideMass, centerOfMassOffset, linearDamping, angularDamping, enableGravity, friction, restitution, locks: {position: [x, y, z], rotation: [x, y, z]}}`, vectors and lock axes in authoring space (cm, Z up). A `meshPhysics` entry (`{massKg, centerOfMassOffset}`) carries inherited values the editor resolved from the static mesh. |
| `applyPhysicsJson` | `void applyPhysicsJson(Map<String, dynamic> json)` | Applies [toPhysicsJson]'s shape; keys the map lacks keep their values. |
| `addImpulse` | `void addImpulse(Vector3 impulse, {bool velocityChange = false})` | Add Impulse: kg·cm/s (or cm/s with [velocityChange]), runtime axes. |
| `addImpulseAtLocation` | `void addImpulseAtLocation(Vector3 impulse, Vector3 location)` |  |
| `addForce` | `void addForce(Vector3 force, {bool accelChange = false})` | kg·cm/s² for the next step (cm/s² with [accelChange]). |
| `addForceAtLocation` | `void addForceAtLocation(Vector3 force, Vector3 location)` |  |
| `addTorque` | `void addTorque(Vector3 torque, {bool accelChange = false})` | kg·cm²/s² (rad/s² with [accelChange]). |
| `addAngularImpulse` | `void addAngularImpulse(Vector3 impulse, {bool velocityChange = false})` | kg·cm²/s (rad/s with [velocityChange]). |
| `physicsLinearVelocity` | `Vector3 get physicsLinearVelocity` | cm/s, runtime axes; zero while not simulating. |
| `setPhysicsLinearVelocity` | `void setPhysicsLinearVelocity(Vector3 velocity, {bool addToCurrent = false})` |  |
| `physicsAngularVelocity` | `Vector3 get physicsAngularVelocity` | rad/s, runtime axes. |
| `setPhysicsAngularVelocity` | `void setPhysicsAngularVelocity(Vector3 radiansPerSecond, {bool addToCurrent = false})` |  |
| `wakeRigidBody` | `void wakeRigidBody()` |  |
| `putRigidBodyToSleep` | `void putRigidBodyToSleep()` |  |
| `isAnyRigidBodyAwake` | `bool get isAnyRigidBodyAwake` |  |

## `lib/src/physics/rigid_body.dart`

### `class LuminaBodyShape`

One convex piece of a rigid body: [shape] posed in the body's frame by [position] / [rotation], in world units. A box's half extents already include the component scale; a convex hull is drawn ×[scale].

**Constructors:**

- `LuminaBodyShape(this.shape, {Vector3? position, Quaternion? rotation, Vector3? scale, this.component})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `shape` | `final CollisionShape shape` |  |
| `position` | `final Vector3 position` |  |
| `rotation` | `final Quaternion rotation` |  |
| `scale` | `final Vector3 scale` |  |
| `component` | `final LuminaCollisionComponent? component` | The collision component this piece came from, if any. |
| `worldTransform` | `final Matrix4 worldTransform` | This piece's world transform (with [scale]) at the current step. |
| `worldBounds` | `final Aabb3 worldBounds` | This piece's world bounds at the current step. |
| `massProperties` | `LuminaShapeMass get massProperties` | Volume, centroid and unit inertia of this piece in its own frame. |
| `updateWorld` | `void updateWorld(Vector3 origin, Quaternion orientation)` | Updates [worldTransform] and [worldBounds] for a body frame at [origin] / [orientation]. |

### `class LuminaRigidBody`

A simulated rigid body (a primitive component while Simulate Physics is on). Runtime frame: cm, kg, seconds, Y up.

The body's frame is its component's world frame; [position] is the centre of mass in the world, [orientation] the frame's rotation. [LuminaPhysicsSubsystem] integrates it; gameplay pushes it through [addImpulse] / [addForce] and friends.

**Constructors:**

- `LuminaRigidBody({required this.id, required this.component, required this.shapes, required LuminaMassProperties massProperties, required Vector3 origin, require...`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `id` | `final int id` | Creation order in its subsystem: pairs are processed by it. |
| `component` | `final LuminaSceneComponent component` | The component this body drives (a collision or static mesh component). |
| `shapes` | `final List<LuminaBodyShape> shapes` |  |
| `material` | `LuminaPhysicalMaterial material` |  |
| `mass` | `double mass` |  |
| `inverseMass` | `double inverseMass` |  |
| `localCenterOfMass` | `final Vector3 localCenterOfMass` |  |
| `localInertia` | `final Matrix3 localInertia` |  |
| `inverseInertiaWorld` | `final Matrix3 inverseInertiaWorld` | World-frame inverse inertia at [orientation]. |
| `position` | `final Vector3 position` | Centre of mass, world. |
| `orientation` | `Quaternion orientation` |  |
| `linearVelocity` | `final Vector3 linearVelocity` |  |
| `angularVelocity` | `final Vector3 angularVelocity` | rad/s, world axes. |
| `pseudoLinearVelocity` | `final Vector3 pseudoLinearVelocity` |  |
| `pseudoAngularVelocity` | `final Vector3 pseudoAngularVelocity` |  |
| `previousPosition` | `final Vector3 previousPosition` |  |
| `previousOrientation` | `Quaternion previousOrientation` |  |
| `linearDamping` | `double linearDamping` |  |
| `angularDamping` | `double angularDamping` |  |
| `enableGravity` | `bool enableGravity` |  |
| `linearFactor` | `final Vector3 linearFactor` | 1 on a free axis, 0 on a locked one (runtime axes). |
| `angularFactor` | `final Vector3 angularFactor` |  |
| `sleepTime` | `double sleepTime` |  |
| `isAwake` | `bool get isAwake` | Whether the solver moves it (a body not asleep). |
| `bounds` | `final Aabb3 bounds` | The world bounds of every shape at the current step. |
| `onSleepChanged` | `void Function(LuminaRigidBody body, bool asleep)? onSleepChanged` | Called when the body falls asleep (true) or wakes (false). |
| `setMassProperties` | `void setMassProperties(LuminaMassProperties p)` |  |
| `origin` | `Vector3 get origin` | The body frame's origin in the world (the component's world location). |
| `setOriginTransform` | `void setOriginTransform(Vector3 origin, Quaternion rotation)` | Places the body frame at [origin] / [rotation], keeping the velocities. |
| `updateInertia` | `void updateInertia()` |  |
| `updateWorld` | `void updateWorld()` | Refreshes every shape's world transform and [bounds]. |
| `velocityAt` | `Vector3 velocityAt(Vector3 worldPoint)` | The world velocity of the body's material point at [worldPoint]. |
| `addImpulse` | `void addImpulse(Vector3 impulse, {bool velocityChange = false})` | Changes the momentum by [impulse] (kg·cm/s) through the centre of mass; [velocityChange] treats it as cm/s regardless of mass. |
| `addImpulseAtLocation` | `void addImpulseAtLocation(Vector3 impulse, Vector3 worldPoint)` | [impulse] (kg·cm/s) at [worldPoint]: it also spins the body. |
| `applyImpulse` | `void applyImpulse(Vector3 impulse, Vector3 r)` | [impulse] at offset [r] from the centre of mass, without waking. |
| `addForce` | `void addForce(Vector3 force, {bool accelChange = false})` | A force (kg·cm/s²) applied over the next frame's steps; [accelChange] as cm/s². |
| `addForceAtLocation` | `void addForceAtLocation(Vector3 force, Vector3 worldPoint)` |  |
| `addTorque` | `void addTorque(Vector3 torque, {bool accelChange = false})` | A torque (kg·cm²/s²); [accelChange] as rad/s². |
| `addAngularImpulse` | `void addAngularImpulse(Vector3 impulse, {bool velocityChange = false})` | An angular impulse (kg·cm²/s); [velocityChange] as rad/s. |
| `localInertiaWorld` | `Matrix3 localInertiaWorld()` | The world inertia (not inverted) at [orientation]. |
| `integrateForces` | `void integrateForces(double dt, Vector3 gravity)` | Integrates the accumulated forces and gravity into the velocities. |
| `clearForces` | `void clearForces()` | Drops the forces added for this frame (after its last step). |
| `integrateVelocities` | `void integrateVelocities(double dt)` | Integrates the velocities (plus the split-impulse correction) into the pose and clears the correction. |
| `wake` | `void wake()` | Puts the body in or out of the solver; waking resets its rest timer. |
| `sleep` | `void sleep()` |  |
| `interpolatedOrigin` | `(Vector3, Quaternion) interpolatedOrigin(double alpha)` | The body frame's origin and rotation between the previous step and this one, [alpha] ∈ [0, 1] (render interpolation). |

---

[Previous: Collision](collision.md) | [Up: lumina (engine core)](index.md) | [Next: AI](ai.md)
