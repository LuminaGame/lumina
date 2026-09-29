[Türkçe](../../tr/lumina/collision.md)

# Collision

The collision module: shapes (sphere, box, capsule, cone, cylinder), collision layers and profiles, hit results, the collision subsystem, and the GJK/EPA narrow phase that computes contacts. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/src/collision/collision_filter.dart`](#libsrccollisioncollision_filterdart)
- [`lib/src/collision/collision_query.dart`](#libsrccollisioncollision_querydart)
- [`lib/src/collision/collision_subsystem.dart`](#libsrccollisioncollision_subsystemdart)
- [`lib/src/collision/gjk_epa.dart`](#libsrccollisiongjk_epadart)
- [`lib/src/collision/narrow_phase.dart`](#libsrccollisionnarrow_phasedart)
- [`lib/src/collision/shapes.dart`](#libsrccollisionshapesdart)
- [`lib/src/collision/collision_hull.dart`](#libsrccollisioncollision_hulldart)
- [`lib/src/collision/collision_preset.dart`](#libsrccollisioncollision_presetdart)
- [`lib/src/collision/collision_primitive.dart`](#libsrccollisioncollision_primitivedart)
- [`lib/src/collision/convex_hull.dart`](#libsrccollisionconvex_hulldart)
- [`lib/src/collision/heightfield.dart`](#libsrccollisionheightfielddart)
- [`lib/src/collision/raycast_math.dart`](#libsrccollisionraycast_mathdart)

## `lib/src/collision/collision_filter.dart`

**Top-level Functions:**

- **`CollisionResponse effectiveResponse(LuminaCollisionComponent a, LuminaCollisionComponent b)`**: Resolves the effective mutual response between components [a] and [b].

### `enum CollisionObjectType`

Semantic object-type channel for collision interaction.

### `enum CollisionResponse`

Interaction response between two colliding objects.

### `class CollisionLayers`

32-bit layer bitmask helpers and layer constant definitions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `layer` | `static int layer(int layerIndex)` | Returns the single-bit mask for 1-based [layerIndex] (1 to 32). |
| `maskOf` | `static int maskOf(Iterable<int> layerIndices)` | Combines multiple 1-based layer indices into a single 32-bit mask. |

### `class CollisionProfile`

Standard preset configurations for collision components.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `applyBlockAll` | `static void applyBlockAll(LuminaCollisionComponent c)` | Profile that blocks all channels. |
| `applyOverlapAll` | `static void applyOverlapAll(LuminaCollisionComponent c)` | Profile that overlaps all channels. |
| `applyPawn` | `static void applyPawn(LuminaCollisionComponent c)` | Standard Pawn profile: blocks static & dynamic geometry, overlaps other pawns. |
| `applyNoCollision` | `static void applyNoCollision(LuminaCollisionComponent c)` | Disables collision completely. |

## `lib/src/collision/collision_query.dart`

### `class HitResult`

Container describing a raycast or geometric sweep impact.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `component` | `LuminaCollisionComponent? component` | The component that was struck. |
| `reset` | `void reset()` | Resets this container to default state for pool reuse. |

## `lib/src/collision/collision_subsystem.dart`

### `class LuminaCollisionSubsystem`

Central world subsystem managing broad-phase filtering, overlap/hit event dispatch, and geometric queries.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `register` | `void register(LuminaCollisionComponent c)` | Registers a collision component with this subsystem. |
| `unregister` | `void unregister(LuminaCollisionComponent c)` | Unregisters a collision component and terminates any active overlap relationships. |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |
| `updateCollision` | `void updateCollision(double deltaTime)` | Executes broad phase, narrow phase, and fires overlap/hit events for all registered components. |

## `lib/src/collision/gjk_epa.dart`

**Top-level Functions:**

- **`Vector3 support(CollisionShape shape, Matrix4 transform, Vector3 direction, Vector3 out)`**: Computes the furthest support point on [shape] in [direction] in world space.

### `class SimplexVertex`

Support point on the Minkowski difference $A - B$.

### `class GjkSimplex`

Simplex structure for 3D GJK algorithm.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `push` | `void push(Vector3 p, Vector3 a, Vector3 b)` | Executes `push` operation. |
| `reset` | `void reset()` | Resets values or state back to defaults. |

### `class _EpaFace`

`_EpaFace`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_EpaFace(this.a, this.b, this.c, this.normal, this.distance)`: Initializes `_EpaFace(this.a, this.b, this.c, this.normal, this.distance)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `c` | `int a, b, c` | Holds the `c` property or configuration state. |
| `normal` | `Vector3 normal` | Holds the `normal` property or configuration state. |
| `distance` | `double distance` | Holds the `distance` property or configuration state. |

## `lib/src/collision/narrow_phase.dart`

### `class ContactResult`

Mutable container for contact geometry and penetration information.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `reset` | `void reset()` | Resets values or state back to defaults. |

## `lib/src/collision/shapes.dart`

### `class CollisionShape`

Base class for geometric collision shape descriptors decoupled from the scene graph.

**Constructors:**
- `CollisionShape()`: Initializes `CollisionShape()`.

### `class SphereShape`

Sphere collision shape defined by its [radius].

**Constructors:**
- `SphereShape(this.radius)`: Initializes `SphereShape(this.radius)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `radius` | `double radius` | Holds the `radius` property or configuration state. |

### `class BoxShape`

Box collision shape defined by [halfExtents].

**Constructors:**
- `BoxShape(this.halfExtents)`: Initializes `BoxShape(this.halfExtents)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `halfExtents` | `Vector3 halfExtents` | Holds the `halfExtents` property or configuration state. |

### `class CapsuleShape`

Capsule collision shape defined by [radius] and [halfHeight] of the full capsule.

**Constructors:**
- `CapsuleShape(this.radius, this.halfHeight)`: Initializes `CapsuleShape(this.radius, this.halfHeight)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `radius` | `double radius` | Holds the `radius` property or configuration state. |
| `halfHeight` | `double halfHeight` | Holds the `halfHeight` property or configuration state. |

### `class ConeShape`

Cone collision shape defined by base [radius] and [height].

**Constructors:**
- `ConeShape(this.radius, this.height)`: Initializes `ConeShape(this.radius, this.height)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `radius` | `double radius` | Holds the `radius` property or configuration state. |
| `height` | `double height` | Holds the `height` property or configuration state. |

### `class CylinderShape`

Cylinder collision shape defined by [radius] and [height].

**Constructors:**
- `CylinderShape(this.radius, this.height)`: Initializes `CylinderShape(this.radius, this.height)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `radius` | `double radius` | Holds the `radius` property or configuration state. |
| `height` | `double height` | Holds the `height` property or configuration state. |

## `lib/src/collision/collision_hull.dart`

### `class LuminaCollisionHull`

One convex element of a static mesh's simple collision, as authored.

[points] are flattened `x, y, z` in **centimetres, Z up**, in the mesh's model space: the frame the level's `metadata.actors` and the Details panel use. The generated level carries them as constants and Play-In-Editor builds the same values from the mesh asset, so a shipped (or web) game never reads `.lmas` metadata. [runtimePoints] converts them to the runtime's Y-up frame through [LuminaAxes], the one place that rule is written.

**Constructors:**

- `const LuminaCollisionHull(this.name, this.points, {this.shape = 'convex'})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` | The source mesh name, e.g. `UCX_SM_Casino_Chair` (a piece of a disconnected `UCX_` mesh gets a `_<n>` suffix). |
| `points` | `final List<double> points` | Authored points: `x, y, z` triples, cm, Z up. |
| `shape` | `final String shape` | The FBX collision-mesh name prefix it came from: `convex` (UCX_), `box` (UBX_), `sphere` (USP_) or `capsule` (UCP_). Every kind collides as the convex hull of its points. |
| `pointCount` | `int get pointCount` | Number of authored points. |
| `runtimePoints` | `List<Vector3> get runtimePoints` | The points in the runtime's frame (cm, Y up), relative to the mesh. |

## `lib/src/collision/collision_preset.dart`

### `enum LuminaCollisionPreset`

Collision presets:

| Preset            | Object type  | World Static | World Dynamic | Pawn    | Enabled | |-------------------|--------------|--------------|---------------|---------|---------| | NoCollision       | worldStatic  | ignore       | ignore        | ignore  | no      | | BlockAll          | worldStatic  | block        | block         | block   | yes     | | OverlapAll        | worldStatic  | overlap      | overlap       | overlap | yes     | | BlockAllDynamic   | worldDynamic | block        | block         | block   | yes     | | OverlapAllDynamic | worldDynamic | overlap      | overlap       | overlap | yes     | | Pawn              | pawn         | block        | block         | block   | yes     | | Trigger           | worldDynamic | ignore       | overlap       | overlap | yes     | | Custom            | (as set)     | (as set)     | (as set)      | (as set)| (as set)|

The effective response between two components is the weaker of the two (Ignore < Overlap < Block, [effectiveResponse]).

**Values:**

- `noCollision`
- `blockAll`
- `overlapAll`
- `blockAllDynamic`
- `overlapAllDynamic`
- `pawn`
- `trigger`
- `custom`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `displayName` | `String get displayName` | The display name: `BlockAllDynamic`, `NoCollision`, … |
| `parse` | `static LuminaCollisionPreset? parse(String? s)` | Parses `Trigger`, `trigger`, `Block All Dynamic`, `blockAllDynamic`; null for anything else. |

### `class LuminaCollisionProfile`

A collision component's whole collision setup: what it is, how it answers each channel, whether it raises overlap events and whether it collides at all. Value type; [LuminaCollisionComponent.profile] reads and writes it.

**Constructors:**

- `LuminaCollisionProfile({this.objectType = CollisionObjectType.worldDynamic, Map<CollisionObjectType, CollisionResponse> responses = const {}, this.generateOverl...`
- `factory LuminaCollisionProfile.forPreset(LuminaCollisionPreset preset, {bool generateOverlapEvents = true})`: The profile of [preset] (the table above). [custom] is `BlockAllDynamic`'s grid: a starting point the user then edits.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `objectType` | `final CollisionObjectType objectType` |  |
| `responses` | `final Map<CollisionObjectType, CollisionResponse> responses` |  |
| `generateOverlapEvents` | `final bool generateOverlapEvents` |  |
| `collisionEnabled` | `final bool collisionEnabled` |  |
| `preset` | `LuminaCollisionPreset get preset` | The preset whose table this profile matches ([generateOverlapEvents] aside); [LuminaCollisionPreset.custom] when none does. A disabled profile is [LuminaCollisionPreset.noCollision] whatever its grid. |
| `copyWith` | `LuminaCollisionProfile copyWith({CollisionObjectType? objectType, Map<CollisionObjectType, CollisionResponse>?...` |  |
| `toJson` | `Map<String, dynamic> toJson()` | The editor's / Blueprint component's collision JSON: `{'preset', 'objectType', 'responses': {'worldStatic': 'block', …}, 'generateOverlapEvents', 'collisionEnabled'}`. |
| `fromJson` | `static LuminaCollisionProfile fromJson(Map<String, dynamic> json, {LuminaCollisionProfile? base})` | Reads [toJson]'s shape, on top of [base] (this component's current setup). A `preset` other than `custom` fills the grid first; explicit `objectType` / `responses` / `generateOverlapEvents` / `collisionEnabled` keys then win, so a custom grid round-trips exactly. Keys the map lacks keep [base]'s values. |
| `hasCollisionKeys` | `static bool hasCollisionKeys(Map<String, dynamic> json)` | Whether [json] carries any of the collision keys. |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `luminaParseCollisionObjectType` | `CollisionObjectType? luminaParseCollisionObjectType(String? s)` | Parses a channel / object type name (`WorldStatic`, `worldDynamic`, `Pawn`, `World Static`); null for anything else. |
| `luminaParseCollisionResponse` | `CollisionResponse? luminaParseCollisionResponse(String? s)` | Parses a response name (`Ignore`, `overlap`, `Block`); null otherwise. |
| `luminaCollisionObjectTypeName` | `String luminaCollisionObjectTypeName(CollisionObjectType t)` | The display name of a channel: `WorldStatic`, `WorldDynamic`, `Pawn`. |
| `luminaCollisionResponseName` | `String luminaCollisionResponseName(CollisionResponse r)` | The display name of a response: `Ignore`, `Overlap`, `Block`. |

## `lib/src/collision/collision_primitive.dart`

### `enum LuminaCollisionPrimitiveKind`

The kinds of authored primitive simple collision.

**Values:**

- `box`
- `sphere`
- `capsule`

### `class LuminaCollisionPrimitive`

One authored primitive of a static mesh's simple collision (box, sphere or capsule), as the Static Mesh editor authors it: in the mesh's model space, **centimetres, Z up** (the frame of `metadata.actors`). The generated level carries these as constants and Play-In-Editor builds the same values from the mesh asset; [LuminaAxes] turns them into the runtime's Y-up frame.

**Constructors:**

- `const LuminaCollisionPrimitive.box({required this.center, required this.halfExtents})`
- `const LuminaCollisionPrimitive.sphere({required this.center, required this.radius})`
- `const LuminaCollisionPrimitive.capsule({required this.center, required this.radius, required this.halfLength, this.axis = 'Z',})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `kind` | `final LuminaCollisionPrimitiveKind kind` |  |
| `center` | `final List<double> center` | Centre, cm, Z up. |
| `halfExtents` | `final List<double> halfExtents` | A box's half extents along the mesh's X, Y, Z (the box is axis-aligned in the mesh frame). Empty for the other kinds. |
| `radius` | `final double radius` | A sphere's or capsule's radius, cm. |
| `halfLength` | `final double halfLength` | Half a capsule's cylinder, between its caps, cm. |
| `axis` | `final String axis` | A capsule's axis in the mesh frame: `X`, `Y` or `Z`. |
| `runtimeCenter` | `Vector3 get runtimeCenter` | [center] in the runtime frame (cm, Y up), unscaled. |
| `createComponent` | `LuminaCollisionComponent createComponent(Vector3 runtimeScale)` | A collision component for this primitive, sized for [runtimeScale] (the owning actor's scale, runtime axes). |
| `applyTo` | `void applyTo(LuminaCollisionComponent component, Vector3 runtimeScale)` | Sizes and places [component] for [runtimeScale], scaling simple collision: a box per axis, a sphere by the smallest \|scale\|, a capsule's radius by the smaller cross-axis scale and its length by its own axis. Child scene components do not inherit their parent's scale, so the offset is scaled here too. |

## `lib/src/collision/convex_hull.dart`

### `class ConvexHullPlane`

One face plane of a [ConvexHullShape]: points `p` of the hull satisfy `normal · p <= offset`, and `normal` points out of the hull.

**Constructors:**

- `const ConvexHullPlane(this.normal, this.offset)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `normal` | `final Vector3 normal` |  |
| `offset` | `final double offset` |  |

### `class ConvexHullShape`

Convex collision shape: the convex hull of a point set, in the owning component's local frame and world units.

The hull is built once, when the shape is created: points closer than [weldTolerance] are merged (an imported hull carries each corner once per face normal), points inside the hull are dropped, and what is left are the hull's [vertices], its outward [triangles] and one [planes] entry per flat face. Collision queries only read these.

A point set with no volume (fewer than four points, or all of them on one line or plane) is [isDegenerate]: it still collides — GJK works on any point set — and ray casts treat it as its local bounding box.

**Constructors:**

- `factory ConvexHullShape(List<Vector3> points)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `weldTolerance` | `static const double weldTolerance` | Points closer than this (world units) are one hull vertex. |
| `vertices` | `final List<Vector3> vertices` | The hull's corners (local frame). |
| `triangles` | `final List<int> triangles` | Outward-facing triangles, three indices into [vertices] each (empty when [isDegenerate]). |
| `planes` | `final List<ConvexHullPlane> planes` | One plane per flat face (coplanar triangles share one); the six local bounding-box planes when [isDegenerate]. |
| `localMin` | `final Vector3 localMin` | Local bounds of [vertices]. |
| `localMax` | `final Vector3 localMax` |  |
| `isDegenerate` | `final bool isDegenerate` | Whether the points enclose no volume. |
| `localCenter` | `Vector3 get localCenter` | Centre of the local bounds. |
| `localSupport` | `Vector3 localSupport(Vector3 localDirection)` | The vertex farthest along [localDirection] (local frame). |

## `lib/src/collision/heightfield.dart`

### `class HeightfieldShape`

A landscape's heightmap as a collision shape: the walkable, sweep-able heightfield collider.

The shape is in the **component's local frame**: runtime Y-up, terrain metres × [unitsPerMetre] (centimetres in a game world), the exact vertices `LandscapeMeshBuilder` draws — so a capsule stands on the triangles it sees. The component's world transform (the placed Landscape actor's location, rotation and scale) is applied by the queries. The shape reads [data] live: a sculpt that edits the heightmap edits the collider.

Only spheres, capsules and rays test against it (a character's capsule, the floor probe, line traces). Box and convex shapes report no contact.

**Constructors:**

- `const HeightfieldShape(this.data, {this.unitsPerMetre = 1.0})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `data` | `final LandscapeData data` |  |
| `unitsPerMetre` | `final double unitsPerMetre` | Local units per terrain metre. |
| `heightAt` | `double heightAt(double localX, double localZ)` | Surface height (local units) under a local XZ position. |
| `normalAt` | `Vector3 normalAt(double localX, double localZ)` | Unit surface normal under a local XZ position (local frame). |
| `contains` | `bool contains(double localX, double localZ)` | True when a local XZ position is inside the terrain's footprint. |
| `localBounds` | `Aabb3 get localBounds` | The box the terrain can occupy, local units: its footprint × the payload's whole `0..maxHeight` range (a sculpt cannot leave it). |
| `cellSize` | `double get cellSize` | One cell's side, local units. |
| `vertexAt` | `Vector3 vertexAt(int col, int row)` | Local position of grid sample ([col], [row]) on the surface. |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `closestPointOnTriangle` | `Vector3 closestPointOnTriangle(Vector3 p, Vector3 a, Vector3 b, Vector3 c)` | Closest point on triangle (a, b, c) to [p] (Ericson, Real-Time Collision Detection 5.1.5). |
| `closestPointsSegmentTriangle` | `double closestPointsSegmentTriangle(Vector3 p, Vector3 q, Vector3 a, Vector3 b, Vector3 c, Vector3 outSeg, Vec...` | Closest points between segment [p, q] and triangle (a, b, c): the closest pair is at a segment endpoint, between the segment and a triangle edge, or (when the segment pierces the triangle) on the triangle itself. Writes them to [outSeg] / [outTri] and returns their distance. |
| `capsuleVsHeightfield` | `bool capsuleVsHeightfield(CapsuleShape sA, Matrix4 tA, HeightfieldShape sB, Matrix4 tB, ContactResult out)` | Capsule ([sA] at [tA]) against heightfield ([sB] at [tB]). |
| `sphereVsHeightfield` | `bool sphereVsHeightfield(SphereShape sA, Matrix4 tA, HeightfieldShape sB, Matrix4 tB, ContactResult out)` | Sphere ([sA] at [tA]) against heightfield ([sB] at [tB]). |
| `rayVsHeightfield` | `double? rayVsHeightfield(Vector3 origin, Vector3 dir, HeightfieldShape hf, Matrix4 transform, Vector3 normalOu...` | Ray ([origin], unit [dir], world) against a heightfield at [transform]. |

## `lib/src/collision/raycast_math.dart`

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `pointInCapsule` | `bool pointInCapsule(Vector3 point, Vector3 segStart, Vector3 segEnd, double radius,)` | Tests whether [point] is inside or on the boundary of a capsule. |
| `rayVsSphere` | `double? rayVsSphere(Vector3 origin, Vector3 dir, Vector3 center, double radius,)` | Ray vs Sphere intersection test returning distance `t` or `null`. |
| `rayVsBox` | `double? rayVsBox(Vector3 origin, Vector3 dir, Matrix4 boxTransform, Vector3 halfExtents,)` | Ray vs Oriented Box intersection test returning distance `t` or `null`. |
| `rayVsCapsule` | `double? rayVsCapsule(Vector3 origin, Vector3 dir, Vector3 segStart, Vector3 segEnd, double radius,)` | Ray vs Capsule intersection test (cylinder body + two hemispherical caps). |
| `rayVsConvexHull` | `double? rayVsConvexHull(Vector3 origin, Vector3 dir, ConvexHullShape hull, Matrix4 transform, Vector3 outNorma...` | Ray vs [ConvexHullShape] drawn with [transform] (which may carry scale), returning the distance `t` along [dir] (normalized) or `null`. |

---

[Previous: Audio](audio.md) | [Up: lumina (engine core)](index.md) | [Next: Physics](physics.md)
