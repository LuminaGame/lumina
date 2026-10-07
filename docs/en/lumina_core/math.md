[Türkçe](../../tr/lumina_core/math.md)

# Math: units, axes and rotations

The math rules every layer shares: one world unit is one centimetre (`LuminaUnits`), stored transforms are Z-up and the runtime is Y-up (`LuminaAxes`), the editor's Euler and control-rotation conventions, interpolation helpers and transform snapshots. File paths are relative to the `lumina_core/` package directory.

**On this page:**

- [`lib/src/math/axes.dart`](#libsrcmathaxesdart)
- [`lib/src/math/camera_math.dart`](#libsrcmathcamera_mathdart)
- [`lib/src/math/euler.dart`](#libsrcmatheulerdart)
- [`lib/src/math/transform_snapshot.dart`](#libsrcmathtransform_snapshotdart)
- [`lib/src/math/units.dart`](#libsrcmathunitsdart)

## `lib/src/math/axes.dart`

### `abstract final class LuminaAxes`

Authoring ↔ runtime axes.

Levels are authored and stored **Z-up**: `location`, `rotation` and `scale` in `metadata.actors` (and a basic shape's `sizeX` / `sizeY` / `sizeZ`) are what the Details panel shows. The runtime (Filament, glTF) is **Y-up**. This is the one place the rule is written; the level code generator, Play-In-Editor and the editor viewport all go through it, so the editor and the game agree.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `location` | `static Vector3 location(List<num> authoring)` | Authoring `(x, y, z)` (Z up) → runtime `(x, z, −y)` (Y up). |
| `toAuthoringLocation` | `static List<double> toAuthoringLocation(Vector3 runtime)` | Runtime `(x, y, z)` → authoring `(x, −z, y)`. |
| `scale` | `static Vector3 scale(List<num> authoring)` | Per-axis scale follows its axis: `(sx, sy, sz)` → `(sx, sz, sy)`. |
| `extent` | `static Vector3 extent(List<num> authoring)` | An extent (a size along each axis, like a basic shape's `sizeX` / `sizeY` / `sizeZ`) follows its axis with no sign: `(x, y, z)` → `(x, z, y)`, so the authored Z (the height) is the runtime Y. |
| `toAuthoringExtent` | `static List<double> toAuthoringExtent(Vector3 runtime)` | Runtime extent `(x, y, z)` → authoring `(x, z, y)`. |
| `rotation` | `static Quaternion rotation(List<num> authoringDegrees)` | Authoring rotation `[x, y, z]` in degrees about the authoring X, Y and Z axes: authoring forward is +Y, so x is **pitch**, y **roll** and z **yaw**, applied yaw first, then pitch, then roll. Positive yaw turns right (yaw 90 faces +X), positive pitch looks up, positive roll dips the left side (the up vector leans to −X). These are the numbers a Blueprint rotator (`LuminaRotator`) holds and the controller's yaw means, so an actor placed at yaw 90 reads yaw 90 from Get Actor Rotation. In runtime axes this is `Ry(−z) · Rx(x) · Rz(y)`. |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `luminaAuthoringRotation` | `Quaternion luminaAuthoringRotation(double xDeg, double yDeg, double zDeg)` | [LuminaAxes.rotation] for three angles: what generated level code calls with the authored values, so the level file still reads like the Details panel. |

## `lib/src/math/camera_math.dart`

**Top-level Functions:**

- **`double fInterpTo(double current, double target, double deltaTime, double interpSpeed)`**: Smoothly interpolates a double from [current] to [target] at [interpSpeed].

### `extension QuaternionEuler`

`QuaternionEuler`: `extension` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `eulerAngles` | `Vector3 get eulerAngles` | Extracts Euler angles (Pitch, Yaw, Roll) to a Vector3 (X=Pitch, Y=Yaw, Z=Roll) |
| `setFromEulerAngles` | `void setFromEulerAngles(Vector3 euler)` | Sets the quaternion from Euler angles (Pitch, Yaw, Roll) in Vector3 (X=Pitch, Y=Yaw, Z=Roll) |

## `lib/src/math/euler.dart`

**Top-level Functions:**

- **`Quaternion luminaEulerDegreesToQuaternion(double xDeg, double yDeg, double zDeg)`**: Converts editor Euler angles in degrees (pitch X, yaw Y, roll Z) into a unit quaternion using the `Rz · Ry · Rx` composition the editor viewport, Play-In-Editor and generated level code all share.  Built through a rotation matrix rather than quaternion multiplication so it matches `Matrix4.rotationZ * rotationY * rotationX` exactly (vector_math's `Quaternion.rotate` uses the opposite handedness from its matrices).
- **`Quaternion luminaEulerListToQuaternion(List<num>? euler)`**: Same as [luminaEulerDegreesToQuaternion] for a `[x, y, z]` list; missing components default to 0.

## `lib/src/math/transform_snapshot.dart`

### `class LuminaTransformSnapshot`

A snapshot of a location and rotation.

**Constructors:**
- `LuminaTransformSnapshot.zero()`: Creates a [LuminaTransformSnapshot] at the origin with zero rotation.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `location` | `Vector3 location` | The location vector. |
| `rotation` | `Quaternion rotation` | The rotation quaternion. |

## `lib/src/math/units.dart`

### `abstract final class LuminaUnits`

World units: one world unit is one **centimetre**. This is the only place the metre ↔ unit factor is written; every conversion goes through it.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `unitsPerMetre` | `static const double unitsPerMetre` | World units in one metre. |
| `gravity` | `static const double gravity` | Standard gravity, cm/s² (magnitude; it pulls down). |
| `metres` | `static double metres(double m)` | [m] metres in world units. |
| `toMetres` | `static double toMetres(double units)` | [units] world units in metres. |
| `lightPower` | `static double lightPower(double physical)` | The Filament power for a physical point/spot light value (lumens or candela). Filament is physically based in metres: illuminance is I/d² with d in world units, so a centimetre world needs the power scaled by the square of [unitsPerMetre] to light the same at the same physical distance. |
| `dynamicLightingNear` | `static const double dynamicLightingNear` | Range the froxel light grid covers, in world units (10 cm to 500 m). |
| `dynamicLightingFar` | `static const double dynamicLightingFar` |  |

---

[Previous: lumina_core (pure-Dart foundation)](index.md) | [Up: lumina_core (pure-Dart foundation)](index.md) | [Next: File formats and repositories](formats.md)
