[Türkçe](../../tr/lumina/components-core.md)

# Components: base, movement, camera, light, audio, collision

The core component set: actor and scene components, character, projectile, rotating and interpolated movement, the camera component and spring arm, player input bindings, directional, point and spot lights, the audio component and collision components. File paths are relative to the `lumina/` package directory. The camera interpolation helpers (`fInterpTo`, `rInterpTo`, control rotations) live in `lumina_core`: see [Math](../lumina_core/math.md).

**On this page:**

- [`lib/src/components/movement/character_movement_component.dart`](#libsrccomponentsmovementcharacter_movement_componentdart)
- [`lib/src/components/movement/floor_finder.dart`](#libsrccomponentsmovementfloor_finderdart)
- [`lib/src/components/movement/interp_to_movement_component.dart`](#libsrccomponentsmovementinterp_to_movement_componentdart)
- [`lib/src/components/movement/projectile_movement_component.dart`](#libsrccomponentsmovementprojectile_movement_componentdart)
- [`lib/src/components/movement/rotating_movement_component.dart`](#libsrccomponentsmovementrotating_movement_componentdart)
- [`lib/src/components/audio/audio_component.dart`](#libsrccomponentsaudioaudio_componentdart)
- [`lib/src/components/camera/camera_component.dart`](#libsrccomponentscameracamera_componentdart)
- [`lib/src/components/camera/spring_arm_component.dart`](#libsrccomponentscameraspring_arm_componentdart)
- [`lib/src/components/player/input_binding.dart`](#libsrccomponentsplayerinput_bindingdart)
- [`lib/src/components/player/lumina_player_component.dart`](#libsrccomponentsplayerlumina_player_componentdart)
- [`lib/src/components/light/directional_light_component.dart`](#libsrccomponentslightdirectional_light_componentdart)
- [`lib/src/components/light/light_component.dart`](#libsrccomponentslightlight_componentdart)
- [`lib/src/components/light/point_light_component.dart`](#libsrccomponentslightpoint_light_componentdart)
- [`lib/src/components/light/spot_light_component.dart`](#libsrccomponentslightspot_light_componentdart)
- [`lib/src/components/base/actor_component.dart`](#libsrccomponentsbaseactor_componentdart)
- [`lib/src/components/base/scene_component.dart`](#libsrccomponentsbasescene_componentdart)
- [`lib/src/components/collision/capsule_component.dart`](#libsrccomponentscollisioncapsule_componentdart)
- [`lib/src/components/collision/collision_component.dart`](#libsrccomponentscollisioncollision_componentdart)
- [`lib/src/components/collision/box_component.dart`](#libsrccomponentscollisionbox_componentdart)
- [`lib/src/components/collision/cone_component.dart`](#libsrccomponentscollisioncone_componentdart)
- [`lib/src/components/collision/convex_component.dart`](#libsrccomponentscollisionconvex_componentdart)
- [`lib/src/components/collision/cylinder_component.dart`](#libsrccomponentscollisioncylinder_componentdart)
- [`lib/src/components/collision/shape_wireframes.dart`](#libsrccomponentscollisionshape_wireframesdart)
- [`lib/src/components/collision/sphere_component.dart`](#libsrccomponentscollisionsphere_componentdart)
- [`lib/src/components/light/auto_exposure.dart`](#libsrccomponentslightauto_exposuredart)
- [`lib/src/components/movement/kinematic_move_solver.dart`](#libsrccomponentsmovementkinematic_move_solverdart)

## `lib/src/components/movement/character_movement_component.dart`

### `enum MovementMode`

`MovementMode`: Enumeration listing system options and state constants.

### `class LuminaCharacterMovementComponent`

Kinematic movement component for character actors supporting sweeping, sliding, floor finding, slopes, steps, and movement modes.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `updatedComponent` | `LuminaCapsuleComponent? updatedComponent` | Holds the `updatedComponent` property or configuration state. |
| `movementMode` | `MovementMode get movementMode` | Getter accessor returning the current value of `movementMode`. |
| `mode` | `MovementMode get mode` | Getter accessor returning the current value of `mode`. |
| `isFalling` | `bool get isFalling` | Checks current state or capability and returns a boolean value. |
| `isWalking` | `bool get isWalking` | Checks current state or capability and returns a boolean value. |
| `isFlying` | `bool get isFlying` | Checks current state or capability and returns a boolean value. |
| `isSwimming` | `bool get isSwimming` | Checks current state or capability and returns a boolean value. |
| `isCustom` | `bool get isCustom` | Checks current state or capability and returns a boolean value. |
| `isGrounded` | `bool get isGrounded` | Checks current state or capability and returns a boolean value. |
| `velocity` | `Vector3 get velocity` | Getter accessor returning the current value of `velocity`. |
| `rootMotionDelta` | `Vector3 get rootMotionDelta` | Getter accessor returning the current value of `rootMotionDelta`. |
| `inputVector` | `Vector3 get inputVector` | Getter accessor returning the current value of `inputVector`. |
| `addInputVector` | `void addInputVector(Vector3 worldDirection, [double scale = 1.0])` | Accumulates world space input displacement for this tick. |
| `consumeInputVector` | `Vector3 consumeInputVector()` | Consumes and clears the accumulated input vector. |
| `lastInputVector` | `Vector3 get lastInputVector` | The input the last move consumed (world space), after `consumeInputVector` cleared it: what motion matching's trajectory prediction steers toward. |
| `addRootMotionDelta` | `void addRootMotionDelta(Vector3 delta)` | Accumulates root motion displacement to be consumed during the next [performMove]. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Callback invoked when the corresponding event is triggered. |
| `calcVelocity` | `void calcVelocity(double dt, Vector3 inputDir)` | Calculates horizontal acceleration and turning friction from [inputDir]. |
| `applyVelocityBraking` | `void applyVelocityBraking(double dt)` | Applies braking deceleration when input is zero on the ground. |
| `applyVelocityBraking3D` | `void applyVelocityBraking3D(double dt)` | Applies 3D braking deceleration across all three axes. |
| `isJumpHeld` | `bool get isJumpHeld` | Whether a jump initiated by [jump] is still being held. |
| `jump` | `bool jump()` | Initiates a jump if walking and grounded. |
| `stopJumping` | `void stopJumping()` | Releases the jump input. If the character is still rising from a held jump, the remaining upward velocity is scaled by [jumpCutMultiplier] so a short tap produces a lower hop than a held press (variable jump height). |
| `stepUp` | `bool stepUp(HitResult wallHit, Vector3 delta)` | Attempts to step up over obstacles lower than [maxStepHeight]. |
| `safeMove` | `bool safeMove(Vector3 delta, HitResult outHit)` | Sweeps the character's collision capsule by [delta] and moves the owner up to contact. |
| `resolvePenetration` | `bool resolvePenetration(ContactResult contact)` | Pushes the character out of intersecting blocking geometry. |
| `physWalking` | `void physWalking(double dt, Vector3 input)` | Physics integration for [MovementMode.walking]. |
| `physFalling` | `void physFalling(double dt, Vector3 input)` | Physics integration for [MovementMode.falling]. |
| `physFlying` | `void physFlying(double dt, Vector3 input)` | Physics integration for [MovementMode.flying]. |
| `physSwimming` | `void physSwimming(double dt, Vector3 input)` | Physics integration for [MovementMode.swimming]. |
| `physCustom` | `void physCustom(double dt, Vector3 input)` | Physics integration for [MovementMode.custom]. |
| `startNewPhysics` | `void startNewPhysics(double deltaTime)` | Dispatches physics integration per current movement mode. |
| `performMove` | `void performMove(double deltaTime)` | Executes full kinematic move pipeline: input accumulation, per-mode physics, safeMove, slideAlongSurface, and resolvePenetration. |
| `onTick` | `void onTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |

## `lib/src/components/movement/floor_finder.dart`

### `class FloorResult`

Holds the results of a character floor finding sweep.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `floorComponent` | `LuminaCollisionComponent? floorComponent` | Holds the `floorComponent` property or configuration state. |
| `reset` | `void reset()` | Resets values or state back to defaults. |
| `copyFrom` | `void copyFrom(FloorResult other)` | Executes `copyFrom` operation. |

## `lib/src/components/movement/interp_to_movement_component.dart`

### `enum InterpToBehaviourType`

Traversal behavior modes when reaching the end of the interpolation control polyline.

### `class InterpControlPoint`

Control point definition along an interpolation movement path.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `position` | `Vector3 position` | Holds the `position` property or configuration state. |
| `positionIsRelative` | `bool positionIsRelative` | Holds the `positionIsRelative` property or configuration state. |

### `class LuminaInterpToMovementComponent`

Actor component that moves an actor along an arc-length parameterized list of control points.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `duration` | `double duration` | Holds the `duration` property or configuration state. |
| `behaviourType` | `InterpToBehaviourType behaviourType` | Holds the `behaviourType` property or configuration state. |
| `controlPoints` | `List<InterpControlPoint> controlPoints` | Holds the `controlPoints` property or configuration state. |
| `progress` | `double get progress` | Getter accessor returning the current value of `progress`. |
| `isPaused` | `bool get isPaused` | Checks current state or capability and returns a boolean value. |
| `isStopped` | `bool get isStopped` | Checks current state or capability and returns a boolean value. |
| `pause` | `void pause()` | Executes `pause` operation. |
| `resume` | `void resume()` | Executes `resume` operation. |
| `stopMovement` | `void stopMovement()` | Executes `stopMovement` operation. |
| `onBeginPlay` | `void onBeginPlay()` | Callback invoked when the corresponding event is triggered. |
| `onTick` | `void onTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |

## `lib/src/components/movement/projectile_movement_component.dart`

### `class LuminaProjectileMovementComponent`

Actor component that updates an actor's position along a simulated ballistic projectile trajectory.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initialSpeed` | `double initialSpeed` | Holds the `initialSpeed` property or configuration state. |
| `maxSpeed` | `double maxSpeed` | Holds the `maxSpeed` property or configuration state. |
| `projectileGravityScale` | `double projectileGravityScale` | Holds the `projectileGravityScale` property or configuration state. |
| `bRotationFollowsVelocity` | `bool bRotationFollowsVelocity` | Holds the `bRotationFollowsVelocity` property or configuration state. |
| `bShouldBounce` | `bool bShouldBounce` | Holds the `bShouldBounce` property or configuration state. |
| `bounciness` | `double bounciness` | Holds the `bounciness` property or configuration state. |
| `friction` | `double friction` | Holds the `friction` property or configuration state. |
| `bounceVelocityStopSimulatingThreshold` | `double bounceVelocityStopSimulatingThreshold` | Holds the `bounceVelocityStopSimulatingThreshold` property or configuration state. |
| `bInitialVelocityInLocalSpace` | `bool bInitialVelocityInLocalSpace` | Holds the `bInitialVelocityInLocalSpace` property or configuration state. |
| `homingTargetComponent` | `LuminaSceneComponent? homingTargetComponent` | Holds the `homingTargetComponent` property or configuration state. |
| `homingAccelerationMagnitude` | `double homingAccelerationMagnitude` | Holds the `homingAccelerationMagnitude` property or configuration state. |
| `isSimulating` | `bool get isSimulating` | Checks current state or capability and returns a boolean value. |
| `setVelocity` | `void setVelocity(Vector3 v)` | Updates the `Velocity` parameter and applies changes to the system. |
| `setVelocityInLocalSpace` | `void setVelocityInLocalSpace(Vector3 v)` | Updates the `VelocityInLocalSpace` parameter and applies changes to the system. |
| `calculateBounceVelocity` | `Vector3 calculateBounceVelocity(Vector3 inVelocity, Vector3 normal)` | Calculates post-bounce velocity using restitution and tangential friction. |
| `onBeginPlay` | `void onBeginPlay()` | Callback invoked when the corresponding event is triggered. |
| `onTick` | `void onTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |

## `lib/src/components/movement/rotating_movement_component.dart`

### `class LuminaRotatingMovementComponent`

Actor component that continuously spins an actor at a constant angular rate about an optional pivot.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `rotationRate` | `Vector3 rotationRate` | Holds the `rotationRate` property or configuration state. |
| `pivotTranslation` | `Vector3 pivotTranslation` | Holds the `pivotTranslation` property or configuration state. |
| `bRotationInLocalSpace` | `bool bRotationInLocalSpace` | Holds the `bRotationInLocalSpace` property or configuration state. |
| `onTick` | `void onTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |

## `lib/src/components/audio/audio_component.dart`

### `class LuminaAudioComponent`

Scene component that emits 2D or spatialized 3D audio instances via a pluggable audio backend.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `sound` | `LuminaSoundBase? sound` | Holds the `sound` property or configuration state. |
| `autoPlay` | `bool autoPlay` | Holds the `autoPlay` property or configuration state. |
| `spatialized` | `bool spatialized` | Holds the `spatialized` property or configuration state. |
| `isPlaying` | `bool get isPlaying` | Whether audio is actively playing on this component. |
| `handle` | `LuminaAudioHandle? get handle` | The active audio instance handle. |
| `fadeFactor` | `double get fadeFactor` | Current fade multiplier factor (0.0 to 1.0). |
| `onRegister` | `void onRegister(LuminaActor owner)` | Callback invoked when the corresponding event is triggered. |
| `onUnregister` | `void onUnregister()` | Callback invoked when the corresponding event is triggered. |
| `stop` | `void stop()` | Stops audio playback and releases the active handle. |
| `pause` | `void pause()` | Pauses audio playback. |
| `resume` | `void resume()` | Resumes paused playback. |
| `onTick` | `void onTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |
| `notifyFinished` | `void notifyFinished()` | Called by the subsystem when the backend signals that this audio handle has finished. |

## `lib/src/components/camera/camera_component.dart`

### `enum CameraProjectionMode`

`CameraProjectionMode`: Enumeration listing system options and state constants.

### `class CameraNative`

Abstract native interface for camera synchronization and FFI operations.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

### `class _FilamentCameraNative`

`_FilamentCameraNative`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_FilamentCameraNative(this.camera)`: Initializes `_FilamentCameraNative(this.camera)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `camera` | `FilamentCamera camera` | Holds the `camera` property or configuration state. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

### `class CameraShake`

Configuration defining a camera shake effect.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `locationAmplitude` | `Vector3 locationAmplitude` | Holds the `locationAmplitude` property or configuration state. |
| `rotationAmplitudeDegrees` | `Vector3 rotationAmplitudeDegrees` | Holds the `rotationAmplitudeDegrees` property or configuration state. |
| `frequency` | `double frequency` | Holds the `frequency` property or configuration state. |
| `duration` | `double duration` | Holds the `duration` property or configuration state. |
| `decay` | `double decay` | Holds the `decay` property or configuration state. |

### `class CameraRay`

A 3D ray emitted from the camera.

**Constructors:**
- `CameraRay(this.origin, this.direction)`: Initializes `CameraRay(this.origin, this.direction)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `origin` | `Vector3 origin` | Holds the `origin` property or configuration state. |
| `direction` | `Vector3 direction` | Holds the `direction` property or configuration state. |

### `class FrustumPlanes`

Six bounding planes representing the view frustum.

**Constructors:**
- `FrustumPlanes(this.planes)`: Initializes `FrustumPlanes(this.planes)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `planes` | `List<Plane> planes` | Holds the `planes` property or configuration state. |
| `intersectsSphere` | `bool intersectsSphere(Vector3 center, double radius)` | Tests whether a sphere intersects or is inside the frustum. |
| `intersectsAabb` | `bool intersectsAabb(Aabb3 box)` | Tests whether an AABB intersects or is inside the frustum. |

### `class LuminaCameraComponent`

Component wrapping camera projection, view matrix, shake, activation, and raycasting.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `nativeFilamentCamera` | `FilamentCamera? get nativeFilamentCamera` | The underlying [FilamentCamera] instance if bound to Filament, or `null`. |
| `bindNative` | `void bindNative(CameraNative native)` | Binds directly to a [CameraNative] implementation (used in tests or custom adapters). |
| `bindToFilament` | `void bindToFilament(FilamentEngine engine, FilamentView view)` | Binds this component to a native [FilamentEngine] and [FilamentView]. |
| `unbindFromFilament` | `void unbindFromFilament()` | Unbinds and disposes the native camera handle. |
| `activate` | `void activate()` | Activates this camera and deactivates any other camera on the owning actor. |
| `deactivate` | `void deactivate()` | Deactivates this camera. |
| `startCameraShake` | `void startCameraShake(CameraShake shake)` | Starts playing a camera shake effect. |
| `onTick` | `void onTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |
| `getFrustumPlanes` | `FrustumPlanes getFrustumPlanes()` | Extracts the 6 normalized frustum planes from the view-projection matrix. |
| `deprojectScreenToWorld` | `CameraRay deprojectScreenToWorld(Vector2 screenPosition, Vector2 viewpor...` | Deprojects a 2D screen coordinate into a 3D world ray. |
| `projectWorldToScreen` | `Vector3? projectWorldToScreen(Vector3 worldPosition, Vector2 viewportSize)` | Projects a 3D world point to 2D screen pixel coordinates (px, py, clip.w). |
| `syncWithFilamentCamera` | `void syncWithFilamentCamera([dynamic camera])` | Synchronizes projection, lookAt, and exposure parameters with the native Filament camera. |
| `onUnregister` | `void onUnregister()` | Callback invoked when the corresponding event is triggered. |

## `lib/src/components/camera/camera_settings.dart`

### `class LuminaCameraSettings`

A camera's authored settings as one property map, read the one way every consumer agrees on: the level editor's Camera section (a placed `Camera` actor's `LuminaCameraComponent`), Play, the generated game, MCP and the Blueprint camera component all use these names and units: `fieldOfView` (degrees, vertical, 5–170, default 60), `projectionMode` (`Perspective` / `Orthographic`), `orthoWidth` (cm, default 1000), `nearClipPlane` / `farClipPlane` (cm, 10 / 100000), `autoExposure` (default true), `aperture` (f-stops, 16), `shutterSpeed` (seconds, 1/125), `sensitivity` (ISO, 100), `autoActivateForPlayer` (default false). The aspect ratio is the viewport's; aperture, shutter speed and ISO only set the exposure (depth of field comes from a Post Process Volume).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `componentType` | `static const String componentType` | `LuminaCameraComponent`: the component a placed camera's settings live on. |
| `projectionModes` | `static const List<String> projectionModes` | The values `projectionMode` takes. |
| `fromProperties` | `factory LuminaCameraSettings.fromProperties(Map<String, dynamic>? properties)` | Reads a property map; a missing, mistyped or out-of-range value keeps the default (field of view clamped to 5–170°, the far plane kept beyond the near one). |
| `toProperties` | `Map<String, dynamic> toProperties()` | The property map `fromProperties` reads back. |
| `applyTo` | `void applyTo(LuminaCameraComponent camera)` | Writes the settings onto a camera component (not its activation). |

## `lib/src/components/camera/spring_arm_component.dart`

### `class LuminaSpringArmComponent`

`LuminaSpringArmComponent`: Actor component providing spatial 3D transform, visual mesh, lighting, or movement capability.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isCollisionAdjusted` | `bool get isCollisionAdjusted` | Checks current state or capability and returns a boolean value. |
| `unfixedSocketWorldLocation` | `Vector3 get unfixedSocketWorldLocation` | Getter accessor returning the current value of `unfixedSocketWorldLocation`. |
| `currentArmLength` | `double get currentArmLength` | Getter accessor returning the current value of `currentArmLength`. |
| `socketWorldLocation` | `Vector3 get socketWorldLocation` | Calculates desired socket location in world space. |
| `socketWorldRotation` | `Quaternion get socketWorldRotation` | Calculates desired socket rotation in world space. |
| `onTick` | `void onTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |
| `onRenderPrep` | `void onRenderPrep(LuminaWorld world)` | With `bUsePawnControlRotation`, puts the children back at the socket rotation after every actor ticked (moved by the arm's movement since its tick), so an owner turned later in the frame (an Animation Blueprint turning the pawn toward its movement) does not turn or orbit the camera. |

## `lib/src/components/player/input_binding.dart`

### `class InputActionBinding`

Representation of an action binding hook.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `actionName` | `String actionName` | Holds the `actionName` property or configuration state. |
| `state` | `InputTriggerState state` | Holds the `state` property or configuration state. |

### `class InputAxisBinding`

Representation of an axis binding hook.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `axisName` | `String axisName` | Holds the `axisName` property or configuration state. |

## `lib/src/components/player/lumina_player_component.dart`

### `class LuminaPlayerComponent`

Player component attached to player-controlled pawns or actors for handling input bindings.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `unbindAction` | `bool unbindAction(InputActionBinding binding)` | Unbinds a specific action binding handle. |
| `unbindAxis` | `bool unbindAxis(InputAxisBinding binding)` | Unbinds a specific axis binding handle. |
| `clearBindings` | `void clearBindings()` | Clears all registered action and axis bindings. |
| `triggerAction` | `void triggerAction(String actionName, [InputTriggerState state = InputTr...` | Triggers actions bound to [actionName] matching the specified [state]. |
| `triggerAxis` | `void triggerAxis(String axisName, double value)` | Triggers axes bound to [axisName] with [value]. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Callback invoked when the corresponding event is triggered. |
| `onUnregister` | `void onUnregister()` | Callback invoked when the corresponding event is triggered. |

## `lib/src/components/light/directional_light_component.dart`

### `class LuminaDirectionalLightComponent`

Directional or Sun light component with illuminance intensity in lux.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isSun` | `bool isSun` | Holds the `isSun` property or configuration state. |
| `sunAngularRadius` | `double sunAngularRadius` | Holds the `sunAngularRadius` property or configuration state. |
| `sunHaloSize` | `double sunHaloSize` | Holds the `sunHaloSize` property or configuration state. |
| `sunHaloFalloff` | `double sunHaloFalloff` | Holds the `sunHaloFalloff` property or configuration state. |
| `createLightBuilder` | `LightBuilder createLightBuilder()` | Creates, configures, and returns a new `LightBuilder` instance or associated GPU resource. |
| `syncNativeTransform` | `void syncNativeTransform(FilamentLightManager lm, int entity)` | Executes `syncNativeTransform` operation. |

## `lib/src/components/light/light_component.dart`

### `class LuminaLightComponent`

Abstract base scene component representing an illumination source bound to FilamentLightManager.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `lightEntity` | `int? get lightEntity` | Native entity handle for this light component, or null if unbound. |
| `color` | `Vector3 get color` | Linear RGB color (0.0 to 1.0). |
| `color` | `color(Vector3 value)` | Executes `color` operation. |
| `intensity` | `double get intensity` | Light intensity (unit depends on subclass: lux for directional, lumens for point/spot). |
| `intensity` | `intensity(double value)` | Executes `intensity` operation. |
| `castShadows` | `bool get castShadows` | Whether this light casts dynamic shadows. |
| `castShadows` | `castShadows(bool value)` | Executes `castShadows` operation. |
| `shadowOptions` | `ShadowOptions? get shadowOptions` | Shadow map and cascaded shadow map configuration options. |
| `shadowOptions` | `shadowOptions(ShadowOptions? value)` | Executes `shadowOptions` operation. |
| `visible` | `bool get visible` | Whether the light is currently illuminating the scene. |
| `visible` | `visible(bool value)` | Executes `visible` operation. |
| `createLightBuilder` | `LightBuilder createLightBuilder()` | Subclass hook to build the native [LightBuilder] with type-specific properties. |
| `applyIntensity` | `void applyIntensity(FilamentLightManager lm, int entity, double intensity)` | Subclass hook to apply intensity to native light (e.g. lumens vs candela vs lux). |
| `syncNativeTransform` | `void syncNativeTransform(FilamentLightManager lm, int entity)` | Subclass hook to sync transform (position, direction, or both) to [FilamentLightManager]. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Callback invoked when the corresponding event is triggered. |
| `onRenderPrep` | `void onRenderPrep(LuminaWorld world)` | Callback invoked when the corresponding event is triggered. |
| `onUnregister` | `void onUnregister()` | Callback invoked when the corresponding event is triggered. |

## `lib/src/components/light/point_light_component.dart`

### `class LuminaPointLightComponent`

Omnidirectional point light component with luminous flux intensity in lumens (or candela).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `intensityInCandela` | `bool intensityInCandela` | Holds the `intensityInCandela` property or configuration state. |
| `falloffRadius` | `double falloffRadius` | Holds the `falloffRadius` property or configuration state. |
| `attenuationRadius` | `double attenuationRadius` | Attenuation radius alias for `falloffRadius`. |
| `createLightBuilder` | `LightBuilder createLightBuilder()` | Creates, configures, and returns a new `LightBuilder` instance or associated GPU resource. |
| `applyIntensity` | `void applyIntensity(FilamentLightManager lm, int entity, double intensity)` | Executes `applyIntensity` operation. |
| `syncNativeTransform` | `void syncNativeTransform(FilamentLightManager lm, int entity)` | Executes `syncNativeTransform` operation. |

## `lib/src/components/light/spot_light_component.dart`

### `class LuminaSpotLightComponent`

Focused or standard spot light component with cone angles in degrees (converted to radians at FFI boundary).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `intensityInCandela` | `bool intensityInCandela` | Holds the `intensityInCandela` property or configuration state. |
| `falloffRadius` | `double falloffRadius` | Holds the `falloffRadius` property or configuration state. |
| `attenuationRadius` | `double attenuationRadius` | Attenuation radius alias for `falloffRadius`. |
| `innerConeAngleDegrees` | `double get innerConeAngleDegrees` | Getter accessor returning the current value of `innerConeAngleDegrees`. |
| `outerConeAngleDegrees` | `double get outerConeAngleDegrees` | Getter accessor returning the current value of `outerConeAngleDegrees`. |
| `innerConeAngle` | `double innerConeAngle` | Inner cone angle in degrees with live validation and clamp. |
| `outerConeAngle` | `double outerConeAngle` | Outer cone angle in degrees with live validation and clamp. |
| `createLightBuilder` | `LightBuilder createLightBuilder()` | Creates, configures, and returns a new `LightBuilder` instance or associated GPU resource. |
| `applyIntensity` | `void applyIntensity(FilamentLightManager lm, int entity, double intensity)` | Executes `applyIntensity` operation. |
| `syncNativeTransform` | `void syncNativeTransform(FilamentLightManager lm, int entity)` | Executes `syncNativeTransform` operation. |

## `lib/src/components/base/actor_component.dart`

### `class LuminaActorComponent`

Base non-transform component that can be attached to a [LuminaActor].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `bSaveGame` | `bool bSaveGame` | Holds the `bSaveGame` property or configuration state. |
| `componentName` | `String? componentName` | Holds the `componentName` property or configuration state. |
| `effectiveComponentName` | `String get effectiveComponentName` | The stable name of this component for serialization and identification. |
| `owner` | `LuminaActor? get owner` | The actor that owns this component. |
| `world` | `LuminaWorld? get world` | The world this component's owner actor belongs to. |
| `isRegistered` | `bool get isRegistered` | Whether this component is registered with an owner actor. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Called when attached to an owner actor. |
| `onInitialize` | `void onInitialize()` | Called after registration for initialization logic. |
| `onBeginPlay` | `void onBeginPlay()` | Called when the game starts or actor enters world. |
| `onTick` | `void onTick(double deltaTime)` | Called during the world tick update step. |
| `onRenderPrep` | `void onRenderPrep(LuminaWorld world)` | Called during the post-physics render prep phase to sync transforms and native handles. |
| `onUnregister` | `void onUnregister()` | Called when detached or disposed. |

## `lib/src/components/base/scene_component.dart`

### `class LuminaSceneComponent`

Transform component that has a position, rotation, and scale in 3D space.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isVisible`, `onVisibilityChanged` | `bool isVisible` (property), `void onVisibilityChanged(bool visible)` | Whether the component is drawn; setting it calls `onVisibilityChanged`, which render-owning components override (a static mesh leaves and re-enters the scene; its `visible` switch and `isVisible` are kept in step). |
| `isVisibleAtDistance` | `bool isVisibleAtDistance(double distance)` | Evaluates whether this component should be rendered based on camera distance. |
| `relativeLocation` | `Vector3 get relativeLocation` | Getter accessor returning the current value of `relativeLocation`. |
| `relativeLocation` | `relativeLocation(Vector3 v)` | Executes `relativeLocation` operation. |
| `location` | `Vector3 get location` | Alias for relativeLocation. |
| `location` | `location(Vector3 v)` | Executes `location` operation. |
| `relativeRotation` | `Quaternion get relativeRotation` | Getter accessor returning the current value of `relativeRotation`. |
| `relativeRotation` | `relativeRotation(Quaternion q)` | Executes `relativeRotation` operation. |
| `rotation` | `Quaternion get rotation` | Alias for relativeRotation. |
| `rotation` | `rotation(Quaternion q)` | Executes `rotation` operation. |
| `relativeScale` | `Vector3 get relativeScale` | Getter accessor returning the current value of `relativeScale`. |
| `relativeScale` | `relativeScale(Vector3 v)` | Executes `relativeScale` operation. |
| `parentComponent` | `LuminaSceneComponent? get parentComponent` | Getter accessor returning the current value of `parentComponent`. |
| `childComponents` | `List<LuminaSceneComponent> get childComponents` | Getter accessor returning the current value of `childComponents`. |
| `attachToComponent` | `void attachToComponent(LuminaSceneComponent parent)` | Attaches this scene component to a parent scene component. |
| `worldLocation` | `Vector3 get worldLocation` | Calculates world space location. |
| `worldRotation` | `Quaternion get worldRotation` | Calculates world space rotation. |
| `worldTransform` | `Matrix4 get worldTransform` | Calculates world space transform matrix. |
| `forwardVector` | `Vector3 get forwardVector` | Forward direction vector. |
| `rightVector` | `Vector3 get rightVector` | Right direction vector. |
| `upVector` | `Vector3 get upVector` | Up direction vector. |
| `onTransformChanged` | `void onTransformChanged()` | Hook invoked whenever this component's local or inherited transform changes. |

## `lib/src/components/collision/capsule_component.dart`

### `class LuminaCapsuleComponent`

3D Capsule collision component for character bounding geometry and sweep collision.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `capsuleRadius` | `double get capsuleRadius` | Getter accessor returning the current value of `capsuleRadius`. |
| `capsuleRadius` | `capsuleRadius(double r)` | Executes `capsuleRadius` operation. |
| `capsuleHalfHeight` | `double get capsuleHalfHeight` | Getter accessor returning the current value of `capsuleHalfHeight`. |
| `capsuleHalfHeight` | `capsuleHalfHeight(double h)` | Executes `capsuleHalfHeight` operation. |
| `segmentStart` | `Vector3 get segmentStart` | Start point of the inner core line segment in world space. |
| `segmentEnd` | `Vector3 get segmentEnd` | End point of the inner core line segment in world space. |
| `getSegmentPoints` | `List<Vector3> getSegmentPoints()` | Returns segment start and end points in world space. |

## `lib/src/components/collision/collision_component.dart`

### `enum CollisionShapeType`

`CollisionShapeType`: Enumeration listing system options and state constants.

### `class LuminaCollisionComponent`

Component handling collision geometry, layer bitmasking, and early-exit AABB/OBB filtering.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `shapeType` | `CollisionShapeType shapeType` | Holds the `shapeType` property or configuration state. |
| `overlappingComponents` | `List<LuminaCollisionComponent> get overlappingComponents` | Current snapshot of overlapping collision components. |
| `addOverlappingComponent` | `void addOverlappingComponent(LuminaCollisionComponent other)` | Appends a new item to the collection or scene. |
| `removeOverlappingComponent` | `void removeOverlappingComponent(LuminaCollisionComponent other)` | Releases and safely disposes the specified `OverlappingComponent` resource. |
| `axis` | `Vector3 get axis` | The oriented axis vector (along +Y local). |
| `apex` | `Vector3 get apex` | The top apex point in world space for a cone. |
| `worldShape` | `CollisionShape get worldShape` | Decoupled value-type collision shape descriptor. |
| `setLayer` | `void setLayer(int layerIndex)` | Sets the 1-based [layerIndex] for this object. |
| `addTargetLayer` | `void addTargetLayer(int layerIndex)` | Adds a target 1-based [layerIndex] to the interaction mask. |
| `removeTargetLayer` | `void removeTargetLayer(int layerIndex)` | Removes a target 1-based [layerIndex] from the interaction mask. |
| `getResponse` | `CollisionResponse getResponse(CollisionObjectType channel)` | Returns the configured response towards the specified [channel]. |
| `setResponse` | `void setResponse(CollisionObjectType channel, CollisionResponse r)` | Sets the response towards the specified [channel]. |
| `setResponseToAll` | `void setResponseToAll(CollisionResponse r)` | Sets the response towards all channels. |
| `response` | `CollisionResponse get response` | Convenience getter/setter for global response compatibility. |
| `response` | `response(CollisionResponse r) => setResponseToAll(r)` | Executes `response` operation. |
| `markCollisionDirty` | `void markCollisionDirty()` | Marks cached AABB and OBB bounding structures as dirty. |
| `onTransformChanged` | `void onTransformChanged()` | Callback invoked when the corresponding event is triggered. |
| `canInteractWith` | `bool canInteractWith(LuminaCollisionComponent other)` | Evaluates whether this collision component interacts with another based on layer bitmasks. |
| `getAABB` | `Aabb3 getAABB()` | Calculates Axis-Aligned Bounding Box (AABB) for broad-phase filtering. |
| `getOBB` | `Obb3 getOBB()` | Calculates Oriented Bounding Box (OBB) reflecting component transform. |

## `lib/src/components/collision/box_component.dart`

### `class LuminaBoxComponent`

A box collider: [boxExtent] is its half size in world units, oriented by the component's transform.

**Constructors:**

- `LuminaBoxComponent({super.key, super.location, super.rotation, super.scale, Vector3? boxExtent,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `setBoxExtent` | `void setBoxExtent(Vector3 extent)` | Sets the half extents and refreshes the bounds. |
| `buildWireframe` | `List<Vector3> buildWireframe({int segments = 16})` | The 12 edges of the box as 24 points (segment pairs), world space. |

## `lib/src/components/collision/cone_component.dart`

### `class LuminaConeComponent`

A cone collider: base radius [radius] at local −Y [halfHeight], apex at +Y [halfHeight].

**Constructors:**

- `LuminaConeComponent({super.key, super.location, super.rotation, super.scale, super.radius = 50.0, super.halfHeight = 80.0,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `coneRadius` | `double get coneRadius` |  |
| `coneRadius` | `set coneRadius(double r)` |  |
| `coneHalfHeight` | `double get coneHalfHeight` |  |
| `coneHalfHeight` | `set coneHalfHeight(double h)` |  |
| `buildWireframe` | `List<Vector3> buildWireframe({int segments = 16})` | The base ring and four lines to the apex, world space. |

## `lib/src/components/collision/convex_component.dart`

### `class LuminaConvexComponent`

A convex collider around an authored hull (e.g. `UCX_` hulls): [points] are the hull's vertices in the component's local frame (world units); [hullAsset] remembers the mesh asset the hull came from (a project `.lmas` path) for the editor.

**Constructors:**

- `LuminaConvexComponent({super.key, super.location, super.rotation, super.scale, required List<Vector3> points, this.hullAsset,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `hullAsset` | `final String? hullAsset` | The mesh asset whose simple collision this hull is, if any. |
| `buildWireframe` | `List<Vector3> buildWireframe({int segments = 16})` | The hull's unique edges, world space. |

## `lib/src/components/collision/cylinder_component.dart`

### `class LuminaCylinderComponent`

A cylinder collider: [radius] and [halfHeight] along the component's local +Y ([LuminaCollisionComponent.height] stays twice the half height).

**Constructors:**

- `LuminaCylinderComponent({super.key, super.location, super.rotation, super.scale, super.radius = 50.0, super.halfHeight = 80.0,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `cylinderRadius` | `double get cylinderRadius` |  |
| `cylinderRadius` | `set cylinderRadius(double r)` |  |
| `cylinderHalfHeight` | `double get cylinderHalfHeight` |  |
| `cylinderHalfHeight` | `set cylinderHalfHeight(double h)` |  |
| `buildWireframe` | `List<Vector3> buildWireframe({int segments = 16})` | Two cap rings and four side lines, world space. |

## `lib/src/components/collision/shape_wireframes.dart`

### `abstract final class LuminaShapeWireframes`

Line-segment helpers shared by the shape collision components' `buildWireframe`: every loop is closed (its last segment ends on its first point).

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `ring` | `static void ring(List<Vector3> out, Vector3 center, Vector3 u, Vector3 v, double radius, int segments)` | A closed ring of [segments] around [center] in the plane of [u] and [v] (unit axes), radius [radius], as segment pairs appended to [out]. |
| `line` | `static void line(List<Vector3> out, Vector3 a, Vector3 b)` | One segment from [a] to [b]. |

## `lib/src/components/collision/sphere_component.dart`

### `class LuminaSphereComponent`

A sphere collider.

**Constructors:**

- `LuminaSphereComponent({super.key, super.location, super.rotation, super.scale, super.radius = 50.0,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `sphereRadius` | `double get sphereRadius` |  |
| `sphereRadius` | `set sphereRadius(double r)` |  |
| `buildWireframe` | `List<Vector3> buildWireframe({int segments = 16})` | Three great circles (right-up, forward-up, right-forward), world space. |

## `lib/src/components/light/auto_exposure.dart`

### `abstract final class LuminaAutoExposure`

The camera exposure a level's lights call for, the default auto exposure that the editor viewport, Play-In-Editor and the generated game all use.

Every camera used to keep Filament's sunny-16 exposure (f/16, 1/125 s, ISO 100, EV100 ≈ 15) whatever lit the level, so a level lit only by point and spot lights rendered 7–9 stops under-exposed: black. The exposure is now metered from the lights, like an incident light meter (EV100 = log2(E · 100 / C), C = 250):

- a sky light (an image-based light in the scene) is daylight: sunny 16; - a directional light meters its illuminance (lux) — the 80 000 lux and brighter suns templates use stay at sunny 16; - a point or spot light meters its illuminance at [keyDistanceMetres], the distance a lamp typically lights a room from; - the brightest of those is the key; nothing to meter keeps sunny 16.

The result is clamped to [[minEv100], [daylightEv100]], so no level is rendered darker than before. Filament renders no luminance histogram, so this is metered from the lights rather than from the frame.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `aperture` | `static const double aperture` | The default photographic exposure every camera starts from. |
| `shutterSpeed` | `static const double shutterSpeed` |  |
| `sensitivity` | `static const double sensitivity` |  |
| `daylightEv100` | `static final double daylightEv100` | EV100 of the default exposure (sunny 16): log2(N² / t). |
| `minEv100` | `static const double minEv100` | The darkest scene the exposure follows down to: EV100 3, a candle-lit room in the photographic exposure tables. Dimmer lamps than ~1 000 lm render darker instead of being brightened further. |
| `keyDistanceMetres` | `static const double keyDistanceMetres` | Where a point or spot light is metered from (a typical attenuation radius is 10 m; a lamp lights a room from about 2 m). |
| `meterCalibration` | `static const double meterCalibration` | Incident-light meter calibration constant C (lux). |
| `candelaOf` | `static double candelaOf(LuminaLightComponent light)` | The physical luminous intensity (candela) of a point or spot light, as Filament converts its lumens (point: lm / 4π; spot: lm / π). |
| `keyIlluminance` | `static double keyIlluminance(LuminaLightComponent light)` | The illuminance (lux) [light] is metered at. |
| `ev100For` | `static double ev100For(Iterable<LuminaLightComponent> lights, {bool skyLight = false})` | The EV100 [lights] call for; [skyLight] when the scene has an image-based light. |
| `shutterSpeedFor` | `static double shutterSpeedFor(double ev100)` | The shutter speed (s) that gives [ev100] at f/16 and ISO 100: N² / 2^EV. The shutter, not the ISO, carries the exposure, because Filament clamps the ISO to 204 800 (EV100 ≈ 4) but the shutter only at 60 s (EV100 ≈ 2). |
| `exposureFactor` | `static double exposureFactor(double ev100)` | Filament's exposure factor for [ev100]: 1 / (1.2 · 2^EV100). |
| `lightsIn` | `static Iterable<LuminaLightComponent> lightsIn(LuminaWorld world) sync*` | The light components registered in [world]'s levels. |
| `ev100ForWorld` | `static double ev100ForWorld(LuminaWorld world)` | The EV100 [world]'s lights and sky call for. |
| `applyTo` | `static void applyTo(LuminaCameraComponent camera, double ev100)` | Points [camera] at [ev100] through its photographic settings, unless its exposure is set by hand ([LuminaCameraComponent.autoExposure] off). |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `luminaLightColorFromHex` | `Vector3 luminaLightColorFromHex(String? hex, {Vector3? fallback})` | A light colour picked as `#RRGGBB` (sRGB, what the colour picker shows) in the linear RGB Filament's lights take. [fallback] for a missing or malformed value. |
| `luminaSrgbToLinear` | `double luminaSrgbToLinear(double c)` | The sRGB transfer function's inverse for one 0..1 channel. |

## `lib/src/components/movement/kinematic_move_solver.dart`

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `computeSlideVector` | `Vector3 computeSlideVector(Vector3 delta, double time, Vector3 normal, Vector3 out,)` | Computes the slide displacement vector along a plane surface defined by [normal]. |

---

[Previous: Controllers](controller.md) | [Up: lumina (engine core)](index.md) | [Next: Components: meshes and particles](components-mesh-and-particles.md)
