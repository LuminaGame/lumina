[English](../../en/lumina/components-core.md)

# Bileşenler: temel, hareket, kamera, ışık, ses, çarpışma

Temel component seti: actor ve scene component'leri, character, projectile, rotating ve interpolated movement, kamera component'i ve spring arm, oyuncu input binding'leri, directional, point ve spot ışıklar, ses component'i ve collision component'leri. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/src/components/movement/character_movement_component.dart`](#libsrccomponentsmovementcharacter_movement_componentdart)
- [`lib/src/components/movement/floor_finder.dart`](#libsrccomponentsmovementfloor_finderdart)
- [`lib/src/components/movement/interp_to_movement_component.dart`](#libsrccomponentsmovementinterp_to_movement_componentdart)
- [`lib/src/components/movement/projectile_movement_component.dart`](#libsrccomponentsmovementprojectile_movement_componentdart)
- [`lib/src/components/movement/rotating_movement_component.dart`](#libsrccomponentsmovementrotating_movement_componentdart)
- [`lib/src/components/audio/audio_component.dart`](#libsrccomponentsaudioaudio_componentdart)
- [`lib/src/components/camera/camera_component.dart`](#libsrccomponentscameracamera_componentdart)
- [`lib/src/components/camera/camera_math.dart`](#libsrccomponentscameracamera_mathdart)
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

`MovementMode`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class LuminaCharacterMovementComponent`

Kinematic movement component for character actors supporting sweeping, sliding, floor finding, slopes, steps, and movement modes.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `updatedComponent` | `LuminaCapsuleComponent? updatedComponent` | `updatedComponent` alanını (field/property) ve ilişkili veriyi saklar. |
| `movementMode` | `MovementMode get movementMode` | `movementMode` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `mode` | `MovementMode get mode` | `mode` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isFalling` | `bool get isFalling` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isWalking` | `bool get isWalking` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isFlying` | `bool get isFlying` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isSwimming` | `bool get isSwimming` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isCustom` | `bool get isCustom` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isGrounded` | `bool get isGrounded` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `velocity` | `Vector3 get velocity` | `velocity` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `rootMotionDelta` | `Vector3 get rootMotionDelta` | `rootMotionDelta` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `inputVector` | `Vector3 get inputVector` | `inputVector` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `addInputVector` | `void addInputVector(Vector3 worldDirection, [double scale = 1.0])` | Accumulates world space input displacement for this tick. |
| `consumeInputVector` | `Vector3 consumeInputVector()` | Consumes and clears the accumulated input vector. |
| `addRootMotionDelta` | `void addRootMotionDelta(Vector3 delta)` | Accumulates root motion displacement to be consumed during the next [performMove]. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
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
| `onTick` | `void onTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/components/movement/floor_finder.dart`

### `class FloorResult`

Holds the results of a character floor finding sweep.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `floorComponent` | `LuminaCollisionComponent? floorComponent` | `floorComponent` alanını (field/property) ve ilişkili veriyi saklar. |
| `reset` | `void reset()` | Değerleri veya durumları varsayılan ayarlarına sıfırlar. |
| `copyFrom` | `void copyFrom(FloorResult other)` | `copyFrom` işlemini gerçekleştirir. |

## `lib/src/components/movement/interp_to_movement_component.dart`

### `enum InterpToBehaviourType`

Traversal behavior modes when reaching the end of the interpolation control polyline.

### `class InterpControlPoint`

Control point definition along an interpolation movement path.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `position` | `Vector3 position` | `position` alanını (field/property) ve ilişkili veriyi saklar. |
| `positionIsRelative` | `bool positionIsRelative` | `positionIsRelative` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaInterpToMovementComponent`

Actor component that moves an actor along an arc-length parameterized list of control points.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `duration` | `double duration` | `duration` alanını (field/property) ve ilişkili veriyi saklar. |
| `behaviourType` | `InterpToBehaviourType behaviourType` | `behaviourType` alanını (field/property) ve ilişkili veriyi saklar. |
| `controlPoints` | `List<InterpControlPoint> controlPoints` | `controlPoints` alanını (field/property) ve ilişkili veriyi saklar. |
| `progress` | `double get progress` | `progress` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isPaused` | `bool get isPaused` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isStopped` | `bool get isStopped` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `pause` | `void pause()` | `pause` işlemini gerçekleştirir. |
| `resume` | `void resume()` | `resume` işlemini gerçekleştirir. |
| `stopMovement` | `void stopMovement()` | `stopMovement` işlemini gerçekleştirir. |
| `onBeginPlay` | `void onBeginPlay()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onTick` | `void onTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/components/movement/projectile_movement_component.dart`

### `class LuminaProjectileMovementComponent`

Actor component that updates an actor's position along a simulated ballistic projectile trajectory.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initialSpeed` | `double initialSpeed` | `initialSpeed` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxSpeed` | `double maxSpeed` | `maxSpeed` alanını (field/property) ve ilişkili veriyi saklar. |
| `projectileGravityScale` | `double projectileGravityScale` | `projectileGravityScale` alanını (field/property) ve ilişkili veriyi saklar. |
| `bRotationFollowsVelocity` | `bool bRotationFollowsVelocity` | `bRotationFollowsVelocity` alanını (field/property) ve ilişkili veriyi saklar. |
| `bShouldBounce` | `bool bShouldBounce` | `bShouldBounce` alanını (field/property) ve ilişkili veriyi saklar. |
| `bounciness` | `double bounciness` | `bounciness` alanını (field/property) ve ilişkili veriyi saklar. |
| `friction` | `double friction` | `friction` alanını (field/property) ve ilişkili veriyi saklar. |
| `bounceVelocityStopSimulatingThreshold` | `double bounceVelocityStopSimulatingThreshold` | `bounceVelocityStopSimulatingThreshold` alanını (field/property) ve ilişkili veriyi saklar. |
| `bInitialVelocityInLocalSpace` | `bool bInitialVelocityInLocalSpace` | `bInitialVelocityInLocalSpace` alanını (field/property) ve ilişkili veriyi saklar. |
| `homingTargetComponent` | `LuminaSceneComponent? homingTargetComponent` | `homingTargetComponent` alanını (field/property) ve ilişkili veriyi saklar. |
| `homingAccelerationMagnitude` | `double homingAccelerationMagnitude` | `homingAccelerationMagnitude` alanını (field/property) ve ilişkili veriyi saklar. |
| `isSimulating` | `bool get isSimulating` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `setVelocity` | `void setVelocity(Vector3 v)` | `Velocity` parametresini günceller ve sisteme uygular. |
| `setVelocityInLocalSpace` | `void setVelocityInLocalSpace(Vector3 v)` | `VelocityInLocalSpace` parametresini günceller ve sisteme uygular. |
| `calculateBounceVelocity` | `Vector3 calculateBounceVelocity(Vector3 inVelocity, Vector3 normal)` | Calculates post-bounce velocity using restitution and tangential friction. |
| `onBeginPlay` | `void onBeginPlay()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onTick` | `void onTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/components/movement/rotating_movement_component.dart`

### `class LuminaRotatingMovementComponent`

Actor component that continuously spins an actor at a constant angular rate about an optional pivot.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `rotationRate` | `Vector3 rotationRate` | `rotationRate` alanını (field/property) ve ilişkili veriyi saklar. |
| `pivotTranslation` | `Vector3 pivotTranslation` | `pivotTranslation` alanını (field/property) ve ilişkili veriyi saklar. |
| `bRotationInLocalSpace` | `bool bRotationInLocalSpace` | `bRotationInLocalSpace` alanını (field/property) ve ilişkili veriyi saklar. |
| `onTick` | `void onTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/components/audio/audio_component.dart`

### `class LuminaAudioComponent`

Scene component that emits 2D or spatialized 3D audio instances via a pluggable audio backend.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sound` | `LuminaSoundBase? sound` | `sound` alanını (field/property) ve ilişkili veriyi saklar. |
| `autoPlay` | `bool autoPlay` | `autoPlay` alanını (field/property) ve ilişkili veriyi saklar. |
| `spatialized` | `bool spatialized` | `spatialized` alanını (field/property) ve ilişkili veriyi saklar. |
| `isPlaying` | `bool get isPlaying` | Whether audio is actively playing on this component. |
| `handle` | `LuminaAudioHandle? get handle` | The active audio instance handle. |
| `fadeFactor` | `double get fadeFactor` | Current fade multiplier factor (0.0 to 1.0). |
| `onRegister` | `void onRegister(LuminaActor owner)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `stop` | `void stop()` | Stops audio playback and releases the active handle. |
| `pause` | `void pause()` | Pauses audio playback. |
| `resume` | `void resume()` | Resumes paused playback. |
| `onTick` | `void onTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `notifyFinished` | `void notifyFinished()` | Called by the subsystem when the backend signals that this audio handle has finished. |

## `lib/src/components/camera/camera_component.dart`

### `enum CameraProjectionMode`

`CameraProjectionMode`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class CameraNative`

Abstract native interface for camera synchronization and FFI operations.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

### `class _FilamentCameraNative`

`_FilamentCameraNative`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_FilamentCameraNative(this.camera)`: `_FilamentCameraNative(this.camera)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `camera` | `FilamentCamera camera` | `camera` alanını (field/property) ve ilişkili veriyi saklar. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

### `class CameraShake`

Configuration defining a camera shake effect.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `locationAmplitude` | `Vector3 locationAmplitude` | `locationAmplitude` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotationAmplitudeDegrees` | `Vector3 rotationAmplitudeDegrees` | `rotationAmplitudeDegrees` alanını (field/property) ve ilişkili veriyi saklar. |
| `frequency` | `double frequency` | `frequency` alanını (field/property) ve ilişkili veriyi saklar. |
| `duration` | `double duration` | `duration` alanını (field/property) ve ilişkili veriyi saklar. |
| `decay` | `double decay` | `decay` alanını (field/property) ve ilişkili veriyi saklar. |

### `class CameraRay`

A 3D ray emitted from the camera.

**Yapıcı Metotlar (Constructors):**
- `CameraRay(this.origin, this.direction)`: `CameraRay(this.origin, this.direction)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `origin` | `Vector3 origin` | `origin` alanını (field/property) ve ilişkili veriyi saklar. |
| `direction` | `Vector3 direction` | `direction` alanını (field/property) ve ilişkili veriyi saklar. |

### `class FrustumPlanes`

Six bounding planes representing the view frustum.

**Yapıcı Metotlar (Constructors):**
- `FrustumPlanes(this.planes)`: `FrustumPlanes(this.planes)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `planes` | `List<Plane> planes` | `planes` alanını (field/property) ve ilişkili veriyi saklar. |
| `intersectsSphere` | `bool intersectsSphere(Vector3 center, double radius)` | Tests whether a sphere intersects or is inside the frustum. |
| `intersectsAabb` | `bool intersectsAabb(Aabb3 box)` | Tests whether an AABB intersects or is inside the frustum. |

### `class LuminaCameraComponent`

Component wrapping camera projection, view matrix, shake, activation, and raycasting.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `nativeFilamentCamera` | `FilamentCamera? get nativeFilamentCamera` | The underlying [FilamentCamera] instance if bound to Filament, or `null`. |
| `bindNative` | `void bindNative(CameraNative native)` | Binds directly to a [CameraNative] implementation (used in tests or custom adapters). |
| `bindToFilament` | `void bindToFilament(FilamentEngine engine, FilamentView view)` | Binds this component to a native [FilamentEngine] and [FilamentView]. |
| `unbindFromFilament` | `void unbindFromFilament()` | Unbinds and disposes the native camera handle. |
| `activate` | `void activate()` | Activates this camera and deactivates any other camera on the owning actor. |
| `deactivate` | `void deactivate()` | Deactivates this camera. |
| `startCameraShake` | `void startCameraShake(CameraShake shake)` | Starts playing a camera shake effect. |
| `onTick` | `void onTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `getFrustumPlanes` | `FrustumPlanes getFrustumPlanes()` | Extracts the 6 normalized frustum planes from the view-projection matrix. |
| `deprojectScreenToWorld` | `CameraRay deprojectScreenToWorld(Vector2 screenPosition, Vector2 viewpor...` | Deprojects a 2D screen coordinate into a 3D world ray. |
| `projectWorldToScreen` | `Vector3? projectWorldToScreen(Vector3 worldPosition, Vector2 viewportSize)` | Projects a 3D world point to 2D screen pixel coordinates (px, py, clip.w). |
| `syncWithFilamentCamera` | `void syncWithFilamentCamera([dynamic camera])` | Synchronizes projection, lookAt, and exposure parameters with the native Filament camera. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/components/camera/camera_settings.dart`

### `class LuminaCameraSettings`

Bir kameranın yazılmış ayarları tek bir özellik haritası olarak; her tüketici aynı şekilde okur: level editörünün Camera bölümü (yerleştirilmiş bir `Camera` aktörünün `LuminaCameraComponent`'i), Play, üretilen oyun, MCP ve Blueprint kamera bileşeni hep bu adları ve birimleri kullanır: `fieldOfView` (derece, dikey, 5–170, varsayılan 60), `projectionMode` (`Perspective` / `Orthographic`), `orthoWidth` (cm, varsayılan 1000), `nearClipPlane` / `farClipPlane` (cm, 10 / 100000), `autoExposure` (varsayılan true), `aperture` (f-stop, 16), `shutterSpeed` (saniye, 1/125), `sensitivity` (ISO, 100), `autoActivateForPlayer` (varsayılan false). En-boy oranı viewport'unkidir; diyafram, enstantane ve ISO yalnızca pozlamayı belirler (alan derinliği bir Post Process Volume'dan gelir).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `componentType` | `static const String componentType` | `LuminaCameraComponent`: yerleştirilmiş bir kameranın ayarlarının durduğu bileşen. |
| `projectionModes` | `static const List<String> projectionModes` | `projectionMode`'un alabileceği değerler. |
| `fromProperties` | `factory LuminaCameraSettings.fromProperties(Map<String, dynamic>? properties)` | Bir özellik haritasını okur; eksik, yanlış tipte ya da aralık dışı bir değer varsayılanı korur (görüş alanı 5–170°'ye sıkıştırılır, uzak düzlem yakın düzlemin ötesinde tutulur). |
| `toProperties` | `Map<String, dynamic> toProperties()` | `fromProperties`'in geri okuduğu özellik haritası. |
| `applyTo` | `void applyTo(LuminaCameraComponent camera)` | Ayarları bir kamera bileşenine yazar (etkinleştirmesine dokunmaz). |

## `lib/src/components/camera/camera_math.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`double fInterpTo(double current, double target, double deltaTime, double interpSpeed)`**: Smoothly interpolates a double from [current] to [target] at [interpSpeed].

### `extension QuaternionEuler`

`QuaternionEuler`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `extension` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `eulerAngles` | `Vector3 get eulerAngles` | Extracts Euler angles (Pitch, Yaw, Roll) to a Vector3 (X=Pitch, Y=Yaw, Z=Roll) |
| `setFromEulerAngles` | `void setFromEulerAngles(Vector3 euler)` | Sets the quaternion from Euler angles (Pitch, Yaw, Roll) in Vector3 (X=Pitch, Y=Yaw, Z=Roll) |

## `lib/src/components/camera/spring_arm_component.dart`

### `class LuminaSpringArmComponent`

`LuminaSpringArmComponent`: Aktörlere bağlanarak 3B uzaysal konum, görsel mesh, aydınlatma veya hareket kabiliyeti kazandıran bileşendir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isCollisionAdjusted` | `bool get isCollisionAdjusted` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `unfixedSocketWorldLocation` | `Vector3 get unfixedSocketWorldLocation` | `unfixedSocketWorldLocation` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `currentArmLength` | `double get currentArmLength` | `currentArmLength` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `socketWorldLocation` | `Vector3 get socketWorldLocation` | Calculates desired socket location in world space. |
| `socketWorldRotation` | `Quaternion get socketWorldRotation` | Calculates desired socket rotation in world space. |
| `onTick` | `void onTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/components/player/input_binding.dart`

### `class InputActionBinding`

Representation of an action binding hook.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `actionName` | `String actionName` | `actionName` alanını (field/property) ve ilişkili veriyi saklar. |
| `state` | `InputTriggerState state` | `state` alanını (field/property) ve ilişkili veriyi saklar. |

### `class InputAxisBinding`

Representation of an axis binding hook.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `axisName` | `String axisName` | `axisName` alanını (field/property) ve ilişkili veriyi saklar. |

## `lib/src/components/player/lumina_player_component.dart`

### `class LuminaPlayerComponent`

Player component attached to player-controlled pawns or actors for handling input bindings.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `unbindAction` | `bool unbindAction(InputActionBinding binding)` | Unbinds a specific action binding handle. |
| `unbindAxis` | `bool unbindAxis(InputAxisBinding binding)` | Unbinds a specific axis binding handle. |
| `clearBindings` | `void clearBindings()` | Clears all registered action and axis bindings. |
| `triggerAction` | `void triggerAction(String actionName, [InputTriggerState state = InputTr...` | Triggers actions bound to [actionName] matching the specified [state]. |
| `triggerAxis` | `void triggerAxis(String axisName, double value)` | Triggers axes bound to [axisName] with [value]. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/components/light/directional_light_component.dart`

### `class LuminaDirectionalLightComponent`

Directional or Sun light component with illuminance intensity in lux.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isSun` | `bool isSun` | `isSun` alanını (field/property) ve ilişkili veriyi saklar. |
| `sunAngularRadius` | `double sunAngularRadius` | `sunAngularRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `sunHaloSize` | `double sunHaloSize` | `sunHaloSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `sunHaloFalloff` | `double sunHaloFalloff` | `sunHaloFalloff` alanını (field/property) ve ilişkili veriyi saklar. |
| `createLightBuilder` | `LightBuilder createLightBuilder()` | Yeni bir `LightBuilder` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |
| `syncNativeTransform` | `void syncNativeTransform(FilamentLightManager lm, int entity)` | `syncNativeTransform` işlemini gerçekleştirir. |

## `lib/src/components/light/light_component.dart`

### `class LuminaLightComponent`

Abstract base scene component representing an illumination source bound to FilamentLightManager.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `lightEntity` | `int? get lightEntity` | Native entity handle for this light component, or null if unbound. |
| `color` | `Vector3 get color` | Linear RGB color (0.0 to 1.0). |
| `color` | `color(Vector3 value)` | `color` işlemini gerçekleştirir. |
| `intensity` | `double get intensity` | Light intensity (unit depends on subclass: lux for directional, lumens for point/spot). |
| `intensity` | `intensity(double value)` | `intensity` işlemini gerçekleştirir. |
| `castShadows` | `bool get castShadows` | Whether this light casts dynamic shadows. |
| `castShadows` | `castShadows(bool value)` | `castShadows` işlemini gerçekleştirir. |
| `shadowOptions` | `ShadowOptions? get shadowOptions` | Shadow map and cascaded shadow map configuration options. |
| `shadowOptions` | `shadowOptions(ShadowOptions? value)` | `shadowOptions` işlemini gerçekleştirir. |
| `visible` | `bool get visible` | Whether the light is currently illuminating the scene. |
| `visible` | `visible(bool value)` | `visible` işlemini gerçekleştirir. |
| `createLightBuilder` | `LightBuilder createLightBuilder()` | Subclass hook to build the native [LightBuilder] with type-specific properties. |
| `applyIntensity` | `void applyIntensity(FilamentLightManager lm, int entity, double intensity)` | Subclass hook to apply intensity to native light (e.g. lumens vs candela vs lux). |
| `syncNativeTransform` | `void syncNativeTransform(FilamentLightManager lm, int entity)` | Subclass hook to sync transform (position, direction, or both) to [FilamentLightManager]. |
| `onRegister` | `void onRegister(LuminaActor ownerActor)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onRenderPrep` | `void onRenderPrep(LuminaWorld world)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `onUnregister` | `void onUnregister()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/components/light/point_light_component.dart`

### `class LuminaPointLightComponent`

Omnidirectional point light component with luminous flux intensity in lumens (or candela).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `intensityInCandela` | `bool intensityInCandela` | `intensityInCandela` alanını (field/property) ve ilişkili veriyi saklar. |
| `falloffRadius` | `double falloffRadius` | `falloffRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `attenuationRadius` | `double attenuationRadius` | `falloffRadius` için zayıflama yarıçapı (cm) takma adı (alias). |
| `createLightBuilder` | `LightBuilder createLightBuilder()` | Yeni bir `LightBuilder` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |
| `applyIntensity` | `void applyIntensity(FilamentLightManager lm, int entity, double intensity)` | `applyIntensity` işlemini gerçekleştirir. |
| `syncNativeTransform` | `void syncNativeTransform(FilamentLightManager lm, int entity)` | `syncNativeTransform` işlemini gerçekleştirir. |

## `lib/src/components/light/spot_light_component.dart`

### `class LuminaSpotLightComponent`

Focused or standard spot light component with cone angles in degrees (converted to radians at FFI boundary).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `intensityInCandela` | `bool intensityInCandela` | `intensityInCandela` alanını (field/property) ve ilişkili veriyi saklar. |
| `falloffRadius` | `double falloffRadius` | `falloffRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `attenuationRadius` | `double attenuationRadius` | `falloffRadius` için zayıflama yarıçapı (cm) takma adı (alias). |
| `innerConeAngleDegrees` | `double get innerConeAngleDegrees` | `innerConeAngleDegrees` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `outerConeAngleDegrees` | `double get outerConeAngleDegrees` | `outerConeAngleDegrees` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `innerConeAngle` | `double innerConeAngle` | Derece cinsinden iç koni açısı erişimcisi ve doğrulayıcı ayarlayıcısı. |
| `outerConeAngle` | `double outerConeAngle` | Derece cinsinden dış koni açısı erişimcisi ve doğrulayıcı ayarlayıcısı. |
| `createLightBuilder` | `LightBuilder createLightBuilder()` | Yeni bir `LightBuilder` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |
| `applyIntensity` | `void applyIntensity(FilamentLightManager lm, int entity, double intensity)` | `applyIntensity` işlemini gerçekleştirir. |
| `syncNativeTransform` | `void syncNativeTransform(FilamentLightManager lm, int entity)` | `syncNativeTransform` işlemini gerçekleştirir. |

## `lib/src/components/base/actor_component.dart`

### `class LuminaActorComponent`

Base non-transform component that can be attached to a [LuminaActor].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `bSaveGame` | `bool bSaveGame` | `bSaveGame` alanını (field/property) ve ilişkili veriyi saklar. |
| `componentName` | `String? componentName` | `componentName` alanını (field/property) ve ilişkili veriyi saklar. |
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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isVisible`, `onVisibilityChanged` | `bool isVisible` (özellik), `void onVisibilityChanged(bool visible)` | Bileşenin çizilip çizilmediği; ayarlamak `onVisibilityChanged`'i çağırır, render kaynağı olan bileşenler bunu geçersiz kılar (bir static mesh sahneden çıkar ve geri girer; `visible` anahtarı ile `isVisible` eşit tutulur). |
| `isVisibleAtDistance` | `bool isVisibleAtDistance(double distance)` | Evaluates whether this component should be rendered based on camera distance. |
| `relativeLocation` | `Vector3 get relativeLocation` | `relativeLocation` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `relativeLocation` | `relativeLocation(Vector3 v)` | `relativeLocation` işlemini gerçekleştirir. |
| `location` | `Vector3 get location` | Alias for relativeLocation. |
| `location` | `location(Vector3 v)` | `location` işlemini gerçekleştirir. |
| `relativeRotation` | `Quaternion get relativeRotation` | `relativeRotation` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `relativeRotation` | `relativeRotation(Quaternion q)` | `relativeRotation` işlemini gerçekleştirir. |
| `rotation` | `Quaternion get rotation` | Alias for relativeRotation. |
| `rotation` | `rotation(Quaternion q)` | `rotation` işlemini gerçekleştirir. |
| `relativeScale` | `Vector3 get relativeScale` | `relativeScale` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `relativeScale` | `relativeScale(Vector3 v)` | `relativeScale` işlemini gerçekleştirir. |
| `parentComponent` | `LuminaSceneComponent? get parentComponent` | `parentComponent` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `childComponents` | `List<LuminaSceneComponent> get childComponents` | `childComponents` özelliğinin anlık değerini okuyan getter erişimcisi. |
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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `capsuleRadius` | `double get capsuleRadius` | `capsuleRadius` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `capsuleRadius` | `capsuleRadius(double r)` | `capsuleRadius` işlemini gerçekleştirir. |
| `capsuleHalfHeight` | `double get capsuleHalfHeight` | `capsuleHalfHeight` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `capsuleHalfHeight` | `capsuleHalfHeight(double h)` | `capsuleHalfHeight` işlemini gerçekleştirir. |
| `segmentStart` | `Vector3 get segmentStart` | Start point of the inner core line segment in world space. |
| `segmentEnd` | `Vector3 get segmentEnd` | End point of the inner core line segment in world space. |
| `getSegmentPoints` | `List<Vector3> getSegmentPoints()` | Returns segment start and end points in world space. |

## `lib/src/components/collision/collision_component.dart`

### `enum CollisionShapeType`

`CollisionShapeType`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class LuminaCollisionComponent`

Component handling collision geometry, layer bitmasking, and early-exit AABB/OBB filtering.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `shapeType` | `CollisionShapeType shapeType` | `shapeType` alanını (field/property) ve ilişkili veriyi saklar. |
| `overlappingComponents` | `List<LuminaCollisionComponent> get overlappingComponents` | Current snapshot of overlapping collision components. |
| `addOverlappingComponent` | `void addOverlappingComponent(LuminaCollisionComponent other)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeOverlappingComponent` | `void removeOverlappingComponent(LuminaCollisionComponent other)` | Belirtilen `OverlappingComponent` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
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
| `response` | `response(CollisionResponse r) => setResponseToAll(r)` | `response` işlemini gerçekleştirir. |
| `markCollisionDirty` | `void markCollisionDirty()` | Marks cached AABB and OBB bounding structures as dirty. |
| `onTransformChanged` | `void onTransformChanged()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `canInteractWith` | `bool canInteractWith(LuminaCollisionComponent other)` | Evaluates whether this collision component interacts with another based on layer bitmasks. |
| `getAABB` | `Aabb3 getAABB()` | Calculates Axis-Aligned Bounding Box (AABB) for broad-phase filtering. |
| `getOBB` | `Obb3 getOBB()` | Calculates Oriented Bounding Box (OBB) reflecting component transform. |

## `lib/src/components/collision/box_component.dart`

### `class LuminaBoxComponent`

A box collider: [boxExtent] is its half size in world units, oriented by the component's transform.

**Yapıcı Metotlar (Constructors):**

- `LuminaBoxComponent({super.key, super.location, super.rotation, super.scale, Vector3? boxExtent,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `setBoxExtent` | `void setBoxExtent(Vector3 extent)` | Sets the half extents and refreshes the bounds. |
| `buildWireframe` | `List<Vector3> buildWireframe({int segments = 16})` | The 12 edges of the box as 24 points (segment pairs), world space. |

## `lib/src/components/collision/cone_component.dart`

### `class LuminaConeComponent`

A cone collider: base radius [radius] at local −Y [halfHeight], apex at +Y [halfHeight].

**Yapıcı Metotlar (Constructors):**

- `LuminaConeComponent({super.key, super.location, super.rotation, super.scale, super.radius = 50.0, super.halfHeight = 80.0,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `coneRadius` | `double get coneRadius` |  |
| `coneRadius` | `set coneRadius(double r)` |  |
| `coneHalfHeight` | `double get coneHalfHeight` |  |
| `coneHalfHeight` | `set coneHalfHeight(double h)` |  |
| `buildWireframe` | `List<Vector3> buildWireframe({int segments = 16})` | The base ring and four lines to the apex, world space. |

## `lib/src/components/collision/convex_component.dart`

### `class LuminaConvexComponent`

A convex collider around an authored hull (e.g. `UCX_` hulls): [points] are the hull's vertices in the component's local frame (world units); [hullAsset] remembers the mesh asset the hull came from (a project `.lmas` path) for the editor.

**Yapıcı Metotlar (Constructors):**

- `LuminaConvexComponent({super.key, super.location, super.rotation, super.scale, required List<Vector3> points, this.hullAsset,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `hullAsset` | `final String? hullAsset` | The mesh asset whose simple collision this hull is, if any. |
| `buildWireframe` | `List<Vector3> buildWireframe({int segments = 16})` | The hull's unique edges, world space. |

## `lib/src/components/collision/cylinder_component.dart`

### `class LuminaCylinderComponent`

A cylinder collider: [radius] and [halfHeight] along the component's local +Y ([LuminaCollisionComponent.height] stays twice the half height).

**Yapıcı Metotlar (Constructors):**

- `LuminaCylinderComponent({super.key, super.location, super.rotation, super.scale, super.radius = 50.0, super.halfHeight = 80.0,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `cylinderRadius` | `double get cylinderRadius` |  |
| `cylinderRadius` | `set cylinderRadius(double r)` |  |
| `cylinderHalfHeight` | `double get cylinderHalfHeight` |  |
| `cylinderHalfHeight` | `set cylinderHalfHeight(double h)` |  |
| `buildWireframe` | `List<Vector3> buildWireframe({int segments = 16})` | Two cap rings and four side lines, world space. |

## `lib/src/components/collision/shape_wireframes.dart`

### `abstract final class LuminaShapeWireframes`

Line-segment helpers shared by the shape collision components' `buildWireframe`: every loop is closed (its last segment ends on its first point).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `ring` | `static void ring(List<Vector3> out, Vector3 center, Vector3 u, Vector3 v, double radius, int segments)` | A closed ring of [segments] around [center] in the plane of [u] and [v] (unit axes), radius [radius], as segment pairs appended to [out]. |
| `line` | `static void line(List<Vector3> out, Vector3 a, Vector3 b)` | One segment from [a] to [b]. |

## `lib/src/components/collision/sphere_component.dart`

### `class LuminaSphereComponent`

A sphere collider.

**Yapıcı Metotlar (Constructors):**

- `LuminaSphereComponent({super.key, super.location, super.rotation, super.scale, super.radius = 50.0,})`

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `luminaLightColorFromHex` | `Vector3 luminaLightColorFromHex(String? hex, {Vector3? fallback})` | A light colour picked as `#RRGGBB` (sRGB, what the colour picker shows) in the linear RGB Filament's lights take. [fallback] for a missing or malformed value. |
| `luminaSrgbToLinear` | `double luminaSrgbToLinear(double c)` | The sRGB transfer function's inverse for one 0..1 channel. |

## `lib/src/components/movement/kinematic_move_solver.dart`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `computeSlideVector` | `Vector3 computeSlideVector(Vector3 delta, double time, Vector3 normal, Vector3 out,)` | Computes the slide displacement vector along a plane surface defined by [normal]. |

---

[Önceki: Controller'lar](controller.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Bileşenler: mesh'ler ve parçacıklar](components-mesh-and-particles.md)
