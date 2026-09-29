[Türkçe](../../tr/lumina/animation.md)

# Animation

Skeletal animation: animation clips and bone tracks, the anim instance with its state machine and montage blending, montages with sections and notifies, 1D and 2D blend spaces, editable keyframe tracks and the skeleton retargeter. File paths are relative to the `lumina/` package directory.

**On this page:**

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

`_MontageBlendState`: Enumeration listing system options and state constants.

### `class AnimState`

Single node in an animation state machine holding an animation clip or blend space and playback settings.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `poseSource` | `AnimPoseSource poseSource` | Holds the `poseSource` property or configuration state. |
| `looping` | `bool looping` | Holds the `looping` property or configuration state. |
| `playRate` | `double playRate` | Holds the `playRate` property or configuration state. |
| `clip` | `LuminaAnimationClip? get clip` | Getter accessor returning the current value of `clip`. |

### `class AnimTransition`

Transition rule connecting two animation states with a condition and cross-fade duration.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `from` | `String from` | Holds the `from` property or configuration state. |
| `to` | `String to` | Holds the `to` property or configuration state. |
| `blendDuration` | `double blendDuration` | Holds the `blendDuration` property or configuration state. |
| `priority` | `int priority` | Holds the `priority` property or configuration state. |

### `class LuminaAnimInstance`

Gameplay-driven animation state machine evaluating transitions and driving skeletal bone poses.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `mesh` | `LuminaSkinnedMeshComponent mesh` | Holds the `mesh` property or configuration state. |
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

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `startTime` | `double startTime` | Holds the `startTime` property or configuration state. |
| `nextSection` | `String? nextSection` | Holds the `nextSection` property or configuration state. |

### `class AnimNotify`

Timed gameplay notification event fired at an exact timestamp during animation playback.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `time` | `double time` | Holds the `time` property or configuration state. |

### `class LuminaAnimMontage`

An event-driven animation sequence layered over the base state machine pose with sections and notifies.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `clip` | `LuminaAnimationClip clip` | Holds the `clip` property or configuration state. |
| `sections` | `List<MontageSection> sections` | Holds the `sections` property or configuration state. |
| `notifies` | `List<AnimNotify> notifies` | Holds the `notifies` property or configuration state. |
| `blendInTime` | `double blendInTime` | Holds the `blendInTime` property or configuration state. |
| `blendOutTime` | `double blendOutTime` | Holds the `blendOutTime` property or configuration state. |

## `lib/src/animation/animation_clip.dart`

### `class AnimPoseSource`

Abstract pose generator driving bone transforms for skeletal animation.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `phaseDuration` | `double get phaseDuration` | Getter accessor returning the current value of `phaseDuration`. |
| `duration` | `double get duration` | Getter accessor returning the current value of `duration`. |
| `advance` | `void advance(double deltaTime)` | Executes `advance` operation. |

### `class BoneTrack`

Single bone animation channel containing timed keyframes for translation, rotation, and scale.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `boneIndex` | `int boneIndex` | Holds the `boneIndex` property or configuration state. |
| `times` | `List<double> times` | Holds the `times` property or configuration state. |
| `positions` | `List<Vector3> positions` | Holds the `positions` property or configuration state. |
| `rotations` | `List<Quaternion> rotations` | Holds the `rotations` property or configuration state. |
| `scales` | `List<Vector3> scales` | Holds the `scales` property or configuration state. |

### `class LuminaAnimationClip`

An immutable animation sequence holding keyframe tracks for skeleton bones.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `duration` | `double duration` | Holds the `duration` property or configuration state. |
| `tracks` | `List<BoneTrack> tracks` | Holds the `tracks` property or configuration state. |
| `phaseDuration` | `double get phaseDuration` | Getter accessor returning the current value of `phaseDuration`. |
| `advance` | `void advance(double deltaTime)` | Executes `advance` operation. |

## `lib/src/animation/blend_space.dart`

### `class BlendSample`

Single scatter point sample mapping an animation clip to 1D or 2D parameter space coordinates.

**Constructors:**
- `BlendSample(this.clip, this.x, [this.y = 0.0])`: Initializes `BlendSample(this.clip, this.x, [this.y = 0.0])`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `clip` | `LuminaAnimationClip clip` | Holds the `clip` property or configuration state. |
| `x` | `double x` | Holds the `x` property or configuration state. |
| `y` | `double y` | Holds the `y` property or configuration state. |

### `class LuminaBlendSpace1D`

1D Parametric blend space interpolating along a single continuous axis (e.g. Speed).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `minAxis` | `double minAxis` | Holds the `minAxis` property or configuration state. |
| `maxAxis` | `double maxAxis` | Holds the `maxAxis` property or configuration state. |
| `interpolationTime` | `double interpolationTime` | Holds the `interpolationTime` property or configuration state. |
| `samples` | `List<BlendSample> get samples` | Getter accessor returning the current value of `samples`. |
| `sampleWeights` | `List<double> get sampleWeights` | Getter accessor returning the current value of `sampleWeights`. |
| `currentParameter` | `double get currentParameter` | Getter accessor returning the current value of `currentParameter`. |
| `normalizedPhase` | `double get normalizedPhase` | Getter accessor returning the current value of `normalizedPhase`. |
| `phaseDuration` | `double get phaseDuration` | Getter accessor returning the current value of `phaseDuration`. |
| `duration` | `double get duration` | Getter accessor returning the current value of `duration`. |
| `setParameter` | `void setParameter(double x)` | Sets the raw target parameter along the 1D axis. |
| `advance` | `void advance(double deltaTime)` | Executes `advance` operation. |

### `class _GridVertexWeights`

`_GridVertexWeights`: `class` representing the data model or functionality of the module.

**Constructors:**
- `_GridVertexWeights(this.sampleIndices, this.weights)`: Initializes `_GridVertexWeights(this.sampleIndices, this.weights)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `sampleIndices` | `List<int> sampleIndices` | Holds the `sampleIndices` property or configuration state. |
| `weights` | `List<double> weights` | Holds the `weights` property or configuration state. |

### `class LuminaBlendSpace2D`

2D Parametric blend space interpolating along a continuous 2D plane (e.g. Direction, Speed).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `minAxis` | `Vector2 minAxis` | Holds the `minAxis` property or configuration state. |
| `maxAxis` | `Vector2 maxAxis` | Holds the `maxAxis` property or configuration state. |
| `gridDivisionsX` | `int gridDivisionsX` | Holds the `gridDivisionsX` property or configuration state. |
| `gridDivisionsY` | `int gridDivisionsY` | Holds the `gridDivisionsY` property or configuration state. |
| `interpolationTime` | `double interpolationTime` | Holds the `interpolationTime` property or configuration state. |
| `samples` | `List<BlendSample> get samples` | Getter accessor returning the current value of `samples`. |
| `sampleWeights` | `List<double> get sampleWeights` | Getter accessor returning the current value of `sampleWeights`. |
| `currentParameter` | `Vector2 get currentParameter` | Getter accessor returning the current value of `currentParameter`. |
| `normalizedPhase` | `double get normalizedPhase` | Getter accessor returning the current value of `normalizedPhase`. |
| `phaseDuration` | `double get phaseDuration` | Getter accessor returning the current value of `phaseDuration`. |
| `duration` | `double get duration` | Getter accessor returning the current value of `duration`. |
| `setParameters` | `void setParameters(double x, double y)` | Sets raw 2D target parameters (e.g. direction, speed). |
| `advance` | `void advance(double deltaTime)` | Executes `advance` operation. |

## `lib/src/animation/keyframe_track.dart`

### `enum KeyframeInterpolation`

Interpolation mode for animation keyframes.

### `class Keyframe`

A timed keyframe holding a value and tangents.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `timeSeconds` | `double timeSeconds` | Holds the `timeSeconds` property or configuration state. |
| `value` | `T value` | Holds the `value` property or configuration state. |
| `interpolation` | `KeyframeInterpolation interpolation` | Holds the `interpolation` property or configuration state. |
| `inTangent` | `double inTangent` | Holds the `inTangent` property or configuration state. |
| `outTangent` | `double outTangent` | Holds the `outTangent` property or configuration state. |

### `class FloatCurveTrack`

A mutable float animation curve track.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `curveName` | `String curveName` | Holds the `curveName` property or configuration state. |
| `interpolation` | `KeyframeInterpolation interpolation` | Holds the `interpolation` property or configuration state. |
| `keys` | `List<Keyframe<double>> get keys` | Getter accessor returning the current value of `keys`. |
| `evaluate` | `double evaluate(double t)` | Executes `evaluate` operation. |

### `class BoneTransformTrack`

A mutable single-bone animation channel containing translation, rotation, and scale keyframe tracks.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `boneIndex` | `int boneIndex` | Holds the `boneIndex` property or configuration state. |
| `boneName` | `String boneName` | Holds the `boneName` property or configuration state. |
| `setTranslationKey` | `void setTranslationKey(double timeSeconds, Vector3 val)` | Updates the `TranslationKey` parameter and applies changes to the system. |
| `setRotationKey` | `void setRotationKey(double timeSeconds, Quaternion val)` | Updates the `RotationKey` parameter and applies changes to the system. |
| `setScaleKey` | `void setScaleKey(double timeSeconds, Vector3 val)` | Updates the `ScaleKey` parameter and applies changes to the system. |
| `evaluateTranslation` | `Vector3 evaluateTranslation(double t)` | Executes `evaluateTranslation` operation. |
| `evaluateRotation` | `Quaternion evaluateRotation(double t)` | Executes `evaluateRotation` operation. |
| `evaluateScale` | `Vector3 evaluateScale(double t)` | Executes `evaluateScale` operation. |
| `evaluateLocalTransform` | `Matrix4 evaluateLocalTransform(double t)` | Executes `evaluateLocalTransform` operation. |

### `class LuminaMutableAnimSequence`

A mutable animation sequence containing editable bone transform and float curve tracks.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `duration` | `double duration` | Holds the `duration` property or configuration state. |
| `frameRate` | `double frameRate` | Holds the `frameRate` property or configuration state. |
| `boneTracks` | `List<BoneTransformTrack> get boneTracks` | Getter accessor returning the current value of `boneTracks`. |
| `curveTracks` | `List<FloatCurveTrack> get curveTracks` | Getter accessor returning the current value of `curveTracks`. |
| `getOrCreateBoneTrack` | `BoneTransformTrack getOrCreateBoneTrack(int boneIndex, String boneName)` | Queries and returns the `OrCreateBoneTrack` value or child object. |
| `getOrCreateCurveTrack` | `FloatCurveTrack getOrCreateCurveTrack(String curveName)` | Queries and returns the `OrCreateCurveTrack` value or child object. |
| `evaluatePose` | `void evaluatePose(double time, List<Matrix4> outBoneMatrices, Map<String...` | Executes `evaluatePose` operation. |
| `toImmutableClip` | `LuminaAnimationClip toImmutableClip()` | Bakes mutable tracks into an immutable [LuminaAnimationClip] buffer. |

## `lib/src/animation/skeleton_retargeter.dart`

### `enum RetargetTranslationMode`

Translation scaling mode used when transferring motion between skeletons.

### `class BoneChainMapping`

A mapping definition linking a bone or chain from source skeleton to target skeleton.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `chainName` | `String chainName` | Holds the `chainName` property or configuration state. |
| `sourceStartBone` | `String sourceStartBone` | Holds the `sourceStartBone` property or configuration state. |
| `sourceEndBone` | `String sourceEndBone` | Holds the `sourceEndBone` property or configuration state. |
| `targetStartBone` | `String targetStartBone` | Holds the `targetStartBone` property or configuration state. |
| `targetEndBone` | `String targetEndBone` | Holds the `targetEndBone` property or configuration state. |
| `translationMode` | `RetargetTranslationMode translationMode` | Holds the `translationMode` property or configuration state. |

### `class LuminaSkeletonRetargeter`

Processor that transfers animation tracks and poses from a source skeleton to a target skeleton.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `sourceSkeleton` | `Skeleton sourceSkeleton` | Holds the `sourceSkeleton` property or configuration state. |
| `targetSkeleton` | `Skeleton targetSkeleton` | Holds the `targetSkeleton` property or configuration state. |
| `chainMappings` | `List<BoneChainMapping> chainMappings` | Holds the `chainMappings` property or configuration state. |
| `sourceRestPoseOffsets` | `Map<String, Quaternion> sourceRestPoseOffsets` | Holds the `sourceRestPoseOffsets` property or configuration state. |
| `targetRestPoseOffsets` | `Map<String, Quaternion> targetRestPoseOffsets` | Holds the `targetRestPoseOffsets` property or configuration state. |
| `autoMapHumanoidChains` | `static List<BoneChainMapping> autoMapHumanoidChains(Skeleton source, Ske...` | Automatically matches standard humanoid bone naming conventions between two skeletons. |
| `retargetPose` | `void retargetPose(List<Matrix4> sourceLocalPose, List<Matrix4> outTarget...` | Retargets a live evaluated local pose buffer to the target skeleton local pose buffer. |

## `lib/src/animation/directional_locomotion_component.dart`

### `class LuminaDirectionalLocomotionComponent`

Drives an animated character mesh from its owner's movement: idle when still, one of eight walk cycles by the direction it moves relative to the way it faces, played at a rate matched to its ground speed, and a held pose while falling.

Add it to the character **before** [mesh], so each frame the clip is chosen from this frame's velocity before the mesh applies it.

The component also turns [mesh] from its authored forward (glTF +Z, see [meshYawOffsetDegrees]) to the actor's forward, −Z, with a constant relative yaw; the mesh otherwise inherits the owner's rotation. The owner's `forwardVector` is the drawn −Z, so the character looks where it walks.

**Constructors:**

- `LuminaDirectionalLocomotionComponent({super.key, required this.mesh, required this.clips, this.crossFadeDuration = 0.2, this.meshYawOffsetDegrees = 0.0,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `mesh` | `final LuminaAnimatedMeshComponent mesh` |  |
| `clips` | `final LuminaLocomotionClipSet clips` |  |
| `crossFadeDuration` | `double crossFadeDuration` | Seconds a clip change blends over. |
| `meshYawOffsetDegrees` | `double meshYawOffsetDegrees` | Yaw, in degrees, from the mesh's authored forward to +Z. glTF assets face +Z, so 0 for them. |
| `lastPose` | `LuminaLocomotionPose? lastPose` | What was selected on the last tick. |

## `lib/src/animation/locomotion_clip_set.dart`

### `enum LuminaLocomotionDirection`

The eight 45° sectors a strafing character can walk in, relative to the way it faces. Declared clockwise seen from above, starting straight ahead.

**Values:**

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

**Constructors:**

- `const LuminaLocomotionClipSet({required this.idle, required this.walk, required this.walkReferenceSpeed, this.jog = const {}, this.jogReferenceSpeed = 0.0, this...`
- `factory LuminaLocomotionClipSet.validated({required String idle, required Map<LuminaLocomotionDirection, String> walk, required double walkReferenceSpeed, doubl...`: Like the default constructor, but checks that every direction has a clip.

**Members:**

| Member | Signature | Description |
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

**Constructors:**

- `const LuminaLocomotionPose(this.clip, this.playRate)`
- `const LuminaLocomotionPose.hold({this.playRate = 0.0})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `clip` | `final String? clip` | The clip to play, or null when [holdCurrent] is set. |
| `playRate` | `final double playRate` |  |
| `holdCurrent` | `final bool holdCurrent` | Keep whatever is playing (at [playRate]) instead of switching. |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `selectLocomotionPose` | `LuminaLocomotionPose selectLocomotionPose({required LuminaLocomotionClipSet clips, required Vector3 velocity,...` | Chooses idle or one of the eight walk cycles for a character moving with [velocity] while facing [facing] (both world space, Y up). |

## `lib/src/animation/rig_logic_evaluator.dart`

### `class RigLogicEvaluationResult`

Evaluation result containing calculated blend shapes, joint deltas, and animated maps.

**Constructors:**

- `const RigLogicEvaluationResult({required this.blendShapeWeights, required this.rawBlendShapes, required this.jointOutputs, required this.animatedMapOutputs,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `blendShapeWeights` | `final Map<String, double> blendShapeWeights` | Calculated blend shape channel weights mapped by channel name. |
| `rawBlendShapes` | `final List<double> rawBlendShapes` | Raw float list of blend shape weights in channel index order. |
| `jointOutputs` | `final List<double> jointOutputs` | Raw joint outputs (9 floats per joint: Tx, Ty, Tz, Rx, Ry, Rz, Sx, Sy, Sz). |
| `animatedMapOutputs` | `final List<double> animatedMapOutputs` | Raw animated map (wrinkle map) multiplier outputs. |

### `class RigLogicEvaluator`

Evaluates MetaHuman DNA facial rigs using OpenRigLogic C++ engine.

Converts raw/GUI control inputs into microsecond-evaluated blend shape weights and skeletal joint transforms that drive 3D facial animation.

**Constructors:**

- `factory RigLogicEvaluator.fromFile(String path)`: Creates a [RigLogicEvaluator] by reading a binary `.dna` file from disk.
- `factory RigLogicEvaluator.fromMemory(Uint8List bytes)`: Creates a [RigLogicEvaluator] from an in-memory byte buffer containing `.dna` data.

**Members:**

| Member | Signature | Description |
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

[Previous: Input](input.md) | [Up: lumina (engine core)](index.md) | [Next: Audio](audio.md)
