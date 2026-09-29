[English](../../en/lumina/animation.md)

# Animasyon

İskelet animasyonu: animasyon clip'leri ve bone track'leri, state machine ve montage harmanlamasıyla anim instance, section ve notify'lı montage'lar, 1D ve 2D blend space'ler, düzenlenebilir keyframe track'leri ve skeleton retargeter. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/src/animation/anim_instance.dart`](#libsrcanimationanim_instancedart)
- [`lib/src/animation/anim_montage.dart`](#libsrcanimationanim_montagedart)
- [`lib/src/animation/animation_clip.dart`](#libsrcanimationanimation_clipdart)
- [`lib/src/animation/blend_space.dart`](#libsrcanimationblend_spacedart)
- [`lib/src/animation/keyframe_track.dart`](#libsrcanimationkeyframe_trackdart)
- [`lib/src/animation/skeleton_retargeter.dart`](#libsrcanimationskeleton_retargeterdart)
- [`lib/src/animation/directional_locomotion_component.dart`](#libsrcanimationdirectional_locomotion_componentdart)
- [`lib/src/animation/locomotion_clip_set.dart`](#libsrcanimationlocomotion_clip_setdart)
- [`lib/src/animation/rig_logic_evaluator.dart`](#libsrcanimationrig_logic_evaluatordart)

## `lib/src/animation/anim_instance.dart`

### `enum _MontageBlendState`

`_MontageBlendState`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class AnimState`

Single node in an animation state machine holding an animation clip or blend space and playback settings.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `poseSource` | `AnimPoseSource poseSource` | `poseSource` alanını (field/property) ve ilişkili veriyi saklar. |
| `looping` | `bool looping` | `looping` alanını (field/property) ve ilişkili veriyi saklar. |
| `playRate` | `double playRate` | `playRate` alanını (field/property) ve ilişkili veriyi saklar. |
| `clip` | `LuminaAnimationClip? get clip` | `clip` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class AnimTransition`

Transition rule connecting two animation states with a condition and cross-fade duration.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `from` | `String from` | `from` alanını (field/property) ve ilişkili veriyi saklar. |
| `to` | `String to` | `to` alanını (field/property) ve ilişkili veriyi saklar. |
| `blendDuration` | `double blendDuration` | `blendDuration` alanını (field/property) ve ilişkili veriyi saklar. |
| `priority` | `int priority` | `priority` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaAnimInstance`

Gameplay-driven animation state machine evaluating transitions and driving skeletal bone poses.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `mesh` | `LuminaSkinnedMeshComponent mesh` | `mesh` alanını (field/property) ve ilişkili veriyi saklar. |
| `setVariable` | `void setVariable(String name, double value)` | Sets a gameplay variable by name. |
| `getVariable` | `double getVariable(String name, [double defaultValue = 0.0])` | Retrieves a gameplay variable by name, returning [defaultValue] if unset. |
| `currentStateName` | `String get currentStateName` | The active state machine state name. |
| `isBlending` | `bool get isBlending` | Whether the state machine is currently cross-fading between two states. |
| `currentStateTime` | `double get currentStateTime` | Accumulated time in seconds within the active state. |
| `currentStateTimeRemaining` | `double get currentStateTimeRemaining` | Remaining seconds before the active state clip ends (clamps to 0 for non-looping clips). |
| `isMontagePlaying` | `bool get isMontagePlaying` | Whether an animation montage is currently active and blending or playing over the base pose. |
| `montagePosition` | `double get montagePosition` | Current playback position in seconds within the active montage clip. |
| `currentMontageSection` | `String? get currentMontageSection` | Name of the montage section currently containing [montagePosition]. |
| `montageJumpToSection` | `void montageJumpToSection(String sectionName)` | Immediately seeks montage playback to the beginning of section [sectionName] without firing intervening notifies. |
| `montageSetNextSection` | `void montageSetNextSection(String from, String to)` | Dynamically changes which section follows section [from] when it reaches its end. |
| `update` | `void update(double deltaTime)` | Advances the animation state machine and any active montage by [deltaTime] seconds. |

## `lib/src/animation/anim_montage.dart`

### `class MontageSection`

Single section within an animation montage defining sub-segment start points and chaining.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `startTime` | `double startTime` | `startTime` alanını (field/property) ve ilişkili veriyi saklar. |
| `nextSection` | `String? nextSection` | `nextSection` alanını (field/property) ve ilişkili veriyi saklar. |

### `class AnimNotify`

Timed gameplay notification event fired at an exact timestamp during animation playback.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `time` | `double time` | `time` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaAnimMontage`

An event-driven animation sequence layered over the base state machine pose with sections and notifies.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `clip` | `LuminaAnimationClip clip` | `clip` alanını (field/property) ve ilişkili veriyi saklar. |
| `sections` | `List<MontageSection> sections` | `sections` alanını (field/property) ve ilişkili veriyi saklar. |
| `notifies` | `List<AnimNotify> notifies` | `notifies` alanını (field/property) ve ilişkili veriyi saklar. |
| `blendInTime` | `double blendInTime` | `blendInTime` alanını (field/property) ve ilişkili veriyi saklar. |
| `blendOutTime` | `double blendOutTime` | `blendOutTime` alanını (field/property) ve ilişkili veriyi saklar. |

## `lib/src/animation/animation_clip.dart`

### `class AnimPoseSource`

Abstract pose generator driving bone transforms for skeletal animation.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `phaseDuration` | `double get phaseDuration` | `phaseDuration` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `duration` | `double get duration` | `duration` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `advance` | `void advance(double deltaTime)` | `advance` işlemini gerçekleştirir. |

### `class BoneTrack`

Single bone animation channel containing timed keyframes for translation, rotation, and scale.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `boneIndex` | `int boneIndex` | `boneIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `times` | `List<double> times` | `times` alanını (field/property) ve ilişkili veriyi saklar. |
| `positions` | `List<Vector3> positions` | `positions` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotations` | `List<Quaternion> rotations` | `rotations` alanını (field/property) ve ilişkili veriyi saklar. |
| `scales` | `List<Vector3> scales` | `scales` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaAnimationClip`

An immutable animation sequence holding keyframe tracks for skeleton bones.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `duration` | `double duration` | `duration` alanını (field/property) ve ilişkili veriyi saklar. |
| `tracks` | `List<BoneTrack> tracks` | `tracks` alanını (field/property) ve ilişkili veriyi saklar. |
| `phaseDuration` | `double get phaseDuration` | `phaseDuration` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `advance` | `void advance(double deltaTime)` | `advance` işlemini gerçekleştirir. |

## `lib/src/animation/blend_space.dart`

### `class BlendSample`

Single scatter point sample mapping an animation clip to 1D or 2D parameter space coordinates.

**Yapıcı Metotlar (Constructors):**
- `BlendSample(this.clip, this.x, [this.y = 0.0])`: `BlendSample(this.clip, this.x, [this.y = 0.0])` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `clip` | `LuminaAnimationClip clip` | `clip` alanını (field/property) ve ilişkili veriyi saklar. |
| `x` | `double x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `double y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaBlendSpace1D`

1D Parametric blend space interpolating along a single continuous axis (e.g. Speed).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `minAxis` | `double minAxis` | `minAxis` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxAxis` | `double maxAxis` | `maxAxis` alanını (field/property) ve ilişkili veriyi saklar. |
| `interpolationTime` | `double interpolationTime` | `interpolationTime` alanını (field/property) ve ilişkili veriyi saklar. |
| `samples` | `List<BlendSample> get samples` | `samples` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sampleWeights` | `List<double> get sampleWeights` | `sampleWeights` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `currentParameter` | `double get currentParameter` | `currentParameter` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `normalizedPhase` | `double get normalizedPhase` | `normalizedPhase` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `phaseDuration` | `double get phaseDuration` | `phaseDuration` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `duration` | `double get duration` | `duration` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setParameter` | `void setParameter(double x)` | Sets the raw target parameter along the 1D axis. |
| `advance` | `void advance(double deltaTime)` | `advance` işlemini gerçekleştirir. |

### `class _GridVertexWeights`

`_GridVertexWeights`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `_GridVertexWeights(this.sampleIndices, this.weights)`: `_GridVertexWeights(this.sampleIndices, this.weights)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sampleIndices` | `List<int> sampleIndices` | `sampleIndices` alanını (field/property) ve ilişkili veriyi saklar. |
| `weights` | `List<double> weights` | `weights` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaBlendSpace2D`

2D Parametric blend space interpolating along a continuous 2D plane (e.g. Direction, Speed).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `minAxis` | `Vector2 minAxis` | `minAxis` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxAxis` | `Vector2 maxAxis` | `maxAxis` alanını (field/property) ve ilişkili veriyi saklar. |
| `gridDivisionsX` | `int gridDivisionsX` | `gridDivisionsX` alanını (field/property) ve ilişkili veriyi saklar. |
| `gridDivisionsY` | `int gridDivisionsY` | `gridDivisionsY` alanını (field/property) ve ilişkili veriyi saklar. |
| `interpolationTime` | `double interpolationTime` | `interpolationTime` alanını (field/property) ve ilişkili veriyi saklar. |
| `samples` | `List<BlendSample> get samples` | `samples` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sampleWeights` | `List<double> get sampleWeights` | `sampleWeights` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `currentParameter` | `Vector2 get currentParameter` | `currentParameter` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `normalizedPhase` | `double get normalizedPhase` | `normalizedPhase` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `phaseDuration` | `double get phaseDuration` | `phaseDuration` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `duration` | `double get duration` | `duration` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setParameters` | `void setParameters(double x, double y)` | Sets raw 2D target parameters (e.g. direction, speed). |
| `advance` | `void advance(double deltaTime)` | `advance` işlemini gerçekleştirir. |

## `lib/src/animation/keyframe_track.dart`

### `enum KeyframeInterpolation`

Interpolation mode for animation keyframes.

### `class Keyframe`

A timed keyframe holding a value and tangents.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `timeSeconds` | `double timeSeconds` | `timeSeconds` alanını (field/property) ve ilişkili veriyi saklar. |
| `value` | `T value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `interpolation` | `KeyframeInterpolation interpolation` | `interpolation` alanını (field/property) ve ilişkili veriyi saklar. |
| `inTangent` | `double inTangent` | `inTangent` alanını (field/property) ve ilişkili veriyi saklar. |
| `outTangent` | `double outTangent` | `outTangent` alanını (field/property) ve ilişkili veriyi saklar. |

### `class FloatCurveTrack`

A mutable float animation curve track.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `curveName` | `String curveName` | `curveName` alanını (field/property) ve ilişkili veriyi saklar. |
| `interpolation` | `KeyframeInterpolation interpolation` | `interpolation` alanını (field/property) ve ilişkili veriyi saklar. |
| `keys` | `List<Keyframe<double>> get keys` | `keys` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `evaluate` | `double evaluate(double t)` | `evaluate` işlemini gerçekleştirir. |

### `class BoneTransformTrack`

A mutable single-bone animation channel containing translation, rotation, and scale keyframe tracks.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `boneIndex` | `int boneIndex` | `boneIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `boneName` | `String boneName` | `boneName` alanını (field/property) ve ilişkili veriyi saklar. |
| `setTranslationKey` | `void setTranslationKey(double timeSeconds, Vector3 val)` | `TranslationKey` parametresini günceller ve sisteme uygular. |
| `setRotationKey` | `void setRotationKey(double timeSeconds, Quaternion val)` | `RotationKey` parametresini günceller ve sisteme uygular. |
| `setScaleKey` | `void setScaleKey(double timeSeconds, Vector3 val)` | `ScaleKey` parametresini günceller ve sisteme uygular. |
| `evaluateTranslation` | `Vector3 evaluateTranslation(double t)` | `evaluateTranslation` işlemini gerçekleştirir. |
| `evaluateRotation` | `Quaternion evaluateRotation(double t)` | `evaluateRotation` işlemini gerçekleştirir. |
| `evaluateScale` | `Vector3 evaluateScale(double t)` | `evaluateScale` işlemini gerçekleştirir. |
| `evaluateLocalTransform` | `Matrix4 evaluateLocalTransform(double t)` | `evaluateLocalTransform` işlemini gerçekleştirir. |

### `class LuminaMutableAnimSequence`

A mutable animation sequence containing editable bone transform and float curve tracks.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `duration` | `double duration` | `duration` alanını (field/property) ve ilişkili veriyi saklar. |
| `frameRate` | `double frameRate` | `frameRate` alanını (field/property) ve ilişkili veriyi saklar. |
| `boneTracks` | `List<BoneTransformTrack> get boneTracks` | `boneTracks` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `curveTracks` | `List<FloatCurveTrack> get curveTracks` | `curveTracks` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `getOrCreateBoneTrack` | `BoneTransformTrack getOrCreateBoneTrack(int boneIndex, String boneName)` | `OrCreateBoneTrack` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `getOrCreateCurveTrack` | `FloatCurveTrack getOrCreateCurveTrack(String curveName)` | `OrCreateCurveTrack` bilgisini veya alt nesnesini sorgulayıp döndürür. |
| `evaluatePose` | `void evaluatePose(double time, List<Matrix4> outBoneMatrices, Map<String...` | `evaluatePose` işlemini gerçekleştirir. |
| `toImmutableClip` | `LuminaAnimationClip toImmutableClip()` | Bakes mutable tracks into an immutable [LuminaAnimationClip] buffer. |

## `lib/src/animation/skeleton_retargeter.dart`

### `enum RetargetTranslationMode`

Translation scaling mode used when transferring motion between skeletons.

### `class BoneChainMapping`

A mapping definition linking a bone or chain from source skeleton to target skeleton.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `chainName` | `String chainName` | `chainName` alanını (field/property) ve ilişkili veriyi saklar. |
| `sourceStartBone` | `String sourceStartBone` | `sourceStartBone` alanını (field/property) ve ilişkili veriyi saklar. |
| `sourceEndBone` | `String sourceEndBone` | `sourceEndBone` alanını (field/property) ve ilişkili veriyi saklar. |
| `targetStartBone` | `String targetStartBone` | `targetStartBone` alanını (field/property) ve ilişkili veriyi saklar. |
| `targetEndBone` | `String targetEndBone` | `targetEndBone` alanını (field/property) ve ilişkili veriyi saklar. |
| `translationMode` | `RetargetTranslationMode translationMode` | `translationMode` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaSkeletonRetargeter`

Processor that transfers animation tracks and poses from a source skeleton to a target skeleton.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sourceSkeleton` | `Skeleton sourceSkeleton` | `sourceSkeleton` alanını (field/property) ve ilişkili veriyi saklar. |
| `targetSkeleton` | `Skeleton targetSkeleton` | `targetSkeleton` alanını (field/property) ve ilişkili veriyi saklar. |
| `chainMappings` | `List<BoneChainMapping> chainMappings` | `chainMappings` alanını (field/property) ve ilişkili veriyi saklar. |
| `sourceRestPoseOffsets` | `Map<String, Quaternion> sourceRestPoseOffsets` | `sourceRestPoseOffsets` alanını (field/property) ve ilişkili veriyi saklar. |
| `targetRestPoseOffsets` | `Map<String, Quaternion> targetRestPoseOffsets` | `targetRestPoseOffsets` alanını (field/property) ve ilişkili veriyi saklar. |
| `autoMapHumanoidChains` | `static List<BoneChainMapping> autoMapHumanoidChains(Skeleton source, Ske...` | Automatically matches standard humanoid bone naming conventions between two skeletons. |
| `retargetPose` | `void retargetPose(List<Matrix4> sourceLocalPose, List<Matrix4> outTarget...` | Retargets a live evaluated local pose buffer to the target skeleton local pose buffer. |

## `lib/src/animation/directional_locomotion_component.dart`

### `class LuminaDirectionalLocomotionComponent`

Drives an animated character mesh from its owner's movement: idle when still, one of eight walk cycles by the direction it moves relative to the way it faces, played at a rate matched to its ground speed, and a held pose while falling.

Add it to the character **before** [mesh], so each frame the clip is chosen from this frame's velocity before the mesh applies it.

The component also turns [mesh] from its authored forward (glTF +Z, see [meshYawOffsetDegrees]) to the actor's forward, −Z, with a constant relative yaw; the mesh otherwise inherits the owner's rotation. The owner's `forwardVector` is the drawn −Z, so the character looks where it walks.

**Yapıcı Metotlar (Constructors):**

- `LuminaDirectionalLocomotionComponent({super.key, required this.mesh, required this.clips, this.crossFadeDuration = 0.2, this.meshYawOffsetDegrees = 0.0,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `mesh` | `final LuminaAnimatedMeshComponent mesh` |  |
| `clips` | `final LuminaLocomotionClipSet clips` |  |
| `crossFadeDuration` | `double crossFadeDuration` | Seconds a clip change blends over. |
| `meshYawOffsetDegrees` | `double meshYawOffsetDegrees` | Yaw, in degrees, from the mesh's authored forward to +Z. glTF assets face +Z, so 0 for them. |
| `lastPose` | `LuminaLocomotionPose? lastPose` | What was selected on the last tick. |

## `lib/src/animation/locomotion_clip_set.dart`

### `enum LuminaLocomotionDirection`

The eight 45° sectors a strafing character can walk in, relative to the way it faces. Declared clockwise seen from above, starting straight ahead.

**Değerler:**

- `forward`
- `forwardRight`
- `right`
- `backwardRight`
- `backward`
- `backwardLeft`
- `left`
- `forwardLeft`

### `class LuminaLocomotionClipSet`

The clips a directional locomotion driver chooses between: one idle and one walk cycle per [LuminaLocomotionDirection], plus an optional jog cycle per direction for speeds nearer [jogReferenceSpeed].

**Yapıcı Metotlar (Constructors):**

- `const LuminaLocomotionClipSet({required this.idle, required this.walk, required this.walkReferenceSpeed, this.jog = const {}, this.jogReferenceSpeed = 0.0, this...`
- `factory LuminaLocomotionClipSet.validated({required String idle, required Map<LuminaLocomotionDirection, String> walk, required double walkReferenceSpeed, doubl...`: Like the default constructor, but checks that every direction has a clip.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `idle` | `final String idle` |  |
| `walk` | `final Map<LuminaLocomotionDirection, String> walk` |  |
| `jog` | `final Map<LuminaLocomotionDirection, String> jog` | The jog cycle per direction, empty when the set has none. |
| `jogReferenceSpeed` | `final double jogReferenceSpeed` | Ground speed, in cm/s, at which the jog clips play at rate 1 without the feet sliding; 0 without jog clips. |
| `walkReferenceSpeed` | `final double walkReferenceSpeed` | Ground speed, in m/s, at which the walk clips play at rate 1 without the feet sliding. |
| `idleSpeedThreshold` | `final double idleSpeedThreshold` | Horizontal speed, in m/s, below which the character idles. |
| `minWalkRate` | `final double minWalkRate` | Play-rate bounds, so a crawl does not freeze the cycle and a sprint does not turn it into a blur. |
| `maxWalkRate` | `final double maxWalkRate` |  |
| `allClips` | `List<String> get allClips` | Every clip the set names: idle first, then the walks and the jogs in direction order. |
| `isWalkClip` | `bool isWalkClip(String? clip)` | Whether [clip] is one of this set's walk cycles. |
| `isCycleClip` | `bool isCycleClip(String? clip)` | Whether [clip] is one of this set's walk or jog cycles (their footfalls line up, so switching between them keeps the phase). |
| `hasJog` | `bool get hasJog` | Whether the set jogs: eight jog clips and a positive reference speed. |

### `class LuminaLocomotionPose`

What a locomotion driver should play this frame.

**Yapıcı Metotlar (Constructors):**

- `const LuminaLocomotionPose(this.clip, this.playRate)`
- `const LuminaLocomotionPose.hold({this.playRate = 0.0})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `clip` | `final String? clip` | The clip to play, or null when [holdCurrent] is set. |
| `playRate` | `final double playRate` |  |
| `holdCurrent` | `final bool holdCurrent` | Keep whatever is playing (at [playRate]) instead of switching. |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `selectLocomotionPose` | `LuminaLocomotionPose selectLocomotionPose({required LuminaLocomotionClipSet clips, required Vector3 velocity,...` | Chooses idle or one of the eight walk cycles for a character moving with [velocity] while facing [facing] (both world space, Y up). |

## `lib/src/animation/rig_logic_evaluator.dart`

### `class RigLogicEvaluationResult`

Evaluation result containing calculated blend shapes, joint deltas, and animated maps.

**Yapıcı Metotlar (Constructors):**

- `const RigLogicEvaluationResult({required this.blendShapeWeights, required this.rawBlendShapes, required this.jointOutputs, required this.animatedMapOutputs,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `blendShapeWeights` | `final Map<String, double> blendShapeWeights` | Calculated blend shape channel weights mapped by channel name. |
| `rawBlendShapes` | `final List<double> rawBlendShapes` | Raw float list of blend shape weights in channel index order. |
| `jointOutputs` | `final List<double> jointOutputs` | Raw joint outputs (9 floats per joint: Tx, Ty, Tz, Rx, Ry, Rz, Sx, Sy, Sz). |
| `animatedMapOutputs` | `final List<double> animatedMapOutputs` | Raw animated map (wrinkle map) multiplier outputs. |

### `class RigLogicEvaluator`

Evaluates MetaHuman DNA facial rigs using OpenRigLogic C++ engine.

Converts raw/GUI control inputs into microsecond-evaluated blend shape weights and skeletal joint transforms that drive 3D facial animation.

**Yapıcı Metotlar (Constructors):**

- `factory RigLogicEvaluator.fromFile(String path)`: Creates a [RigLogicEvaluator] by reading a binary `.dna` file from disk.
- `factory RigLogicEvaluator.fromMemory(Uint8List bytes)`: Creates a [RigLogicEvaluator] from an in-memory byte buffer containing `.dna` data.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `isDisposed` | `bool get isDisposed` |  |
| `characterName` | `String get characterName` |  |
| `lodCount` | `int get lodCount` |  |
| `jointCount` | `int get jointCount` |  |
| `blendShapeCount` | `int get blendShapeCount` |  |
| `rawControlCount` | `int get rawControlCount` |  |
| `guiControlCount` | `int get guiControlCount` |  |
| `animatedMapCount` | `int get animatedMapCount` |  |
| `rawControlNames` | `List<String> get rawControlNames` |  |
| `blendShapeNames` | `List<String> get blendShapeNames` |  |
| `jointNames` | `List<String> get jointNames` |  |
| `animatedMapNames` | `List<String> get animatedMapNames` |  |
| `lod` | `int get lod` |  |
| `lod` | `set lod(int value)` |  |
| `indexOfRawControl` | `int? indexOfRawControl(String name)` |  |
| `getRawControl` | `double getRawControl(int index)` |  |
| `getControlByName` | `double? getControlByName(String name)` |  |
| `setRawControl` | `void setRawControl(int index, double value)` |  |
| `setControlByName` | `bool setControlByName(String name, double value)` |  |
| `applyControls` | `void applyControls(Map<String, double> controls)` |  |
| `resetControls` | `void resetControls()` |  |
| `evaluate` | `RigLogicEvaluationResult evaluate()` | Evaluates the rig logic graph with current control inputs and returns blend shape weights, joint deltas, and animated maps. |
| `applyToSkinnedMesh` | `RigLogicEvaluationResult applyToSkinnedMesh(LuminaSkinnedMeshComponent mesh)` | Evaluates current control state and pushes matching blend shape weights directly into [mesh] (via [LuminaSkinnedMeshComponent.setMorphTarget]). |
| `dispose` | `void dispose()` |  |

---

[Önceki: Girdi (input)](input.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Ses](audio.md)
