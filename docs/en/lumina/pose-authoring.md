[Türkçe](../../tr/lumina/pose-authoring.md)

# Pose authoring

A skinned character can be posed like a mannequin at runtime: move a hand and the elbow and shoulder bend, move an elbow and the arm plane swings about the shoulder–hand axis while the hand stays, turn the head and the neck shares the turn, pull the chest and the spine bends, move the pelvis and planted feet stay. What is set holds every frame until it changes, and a pose can be captured, saved and restored. `LuminaPoseAuthoringComponent` does it as a pose modifier of the mesh (see `poseModifiers` in [Mesh components](components-mesh-and-particles.md)), after the clip or pose driver and the joint overrides, like the [ragdoll](ragdoll.md).

| Part | Where |
| :--- | :--- |
| The component and its per-frame solve | `lib/src/components/mesh/pose_authoring/pose_authoring_component.dart` (+ `pose_authoring_solve.dart`) |
| Rig: bones, limits, the rig asset | `pose_rig.dart`, detection by bone name in `pose_rig_detect.dart` |
| Handles, capture modes | `pose_handle.dart` |
| Solvers (two-bone, pole, look, spine, pelvis, twist) | `pose_solvers.dart` over `pose_solve_state.dart`; quaternion helpers in `pose_quat.dart` |
| Poses: pose library, save game slots, Play-In-Editor | `pose_library.dart` |
| Blueprint nodes | `pose_authoring_nodes.dart`, `lib/src/blueprint/node_library/pose_authoring.dart`, `lib/src/blueprint/blueprint_function_library/pose_authoring.dart` |

## The rig

`LuminaPoseRig.detect(GlbSkeleton)` finds a humanoid's bones by name: MetaHuman and UEFN mannequin names (`upperarm_l`, `lowerarm_l`, `hand_l`, `thigh_l`, `calf_l`, `foot_l`, `spine_01`…`spine_05`, `neck_01`, `neck_02`, `head`, `pelvis`) and Mixamo names (`mixamorig:LeftArm`, `Spine1`, `Neck`, `Hips`, …).

- **Limbs** (`arm_l`, `arm_r`, `leg_l`, `leg_r`): upper, lower and end bone. `TwoBoneIkChain.detect` (`lumina_core`) finds them; bones that carry no skin weight (a MetaHuman's upper arms and thighs) are found by name when it misses them. The twist bones under the upper and lower bone (`upperarm_twist_01_l`, `lowerarm_twist_02_l`, `calf_twist_01_l`, …) are kept with their place along the bone.
- **Neck chain**: the neck bones above the spine and the head, with each one's share of the head's turn: 0.25 / 0.35 / 0.4 for two neck bones and the head (0.4 / 0.6 for one neck bone).
- **Spine**: the `spine*` / `chest` bones under the neck, pelvis side first; the chest point is the next bone towards the head (`neck_01`).
- **Pelvis**: the bone under the spine.
- A skeleton without legs (or without a neck) has no handles for them and no error. Corrective joints and fingers are not driven; they follow their parents.

The rig works on a pose array of the rig's bones and every ancestor (`nodeNames`, 10 doubles per node: the mesh's local TRS), in the GLB's model frame. The body's up, forward and left come from the rest pose (pelvis → head, the left limbs minus the right ones), so the mesh's forward is never assumed.

**Rig asset**: `LuminaPoseRigDefinition` (limbs, spine, neck, weights, pelvis, limits by bone name) is what detection returns; `toAssetBytes` / `fromAssetBytes` store it in a `.lmas` under `metadata['pose_rig']`. The component reads one from `rigAssetPath` instead of detecting.

**Limits** (`LuminaPoseRigLimits`, degrees): elbow and knee hinge 0–150, shoulder cone 150 about the arm's outward direction, hip cone 120 about down, neck yaw 80, pitch 60, roll 40 (whole chain), spine bend 20 per joint over its incoming pose.

## Handles

| Handle | Kind | What it moves |
| :--- | :--- | :--- |
| `hand_l`, `hand_r`, `foot_l`, `foot_r` | effector | Two-bone IK: the middle joint bends about its own hinge to the angle the law of cosines gives (clamped to the hinge limits and the cone), the limb swings to the target. A rotation is the end bone's world rotation; without one a hand keeps its local rotation and a foot its world one (it stays flat). The lower twist bones share the end's twist about the forearm / shin by their place along it; the upper twist bones hold back the upper bone's own twist. |
| `elbow_l`, `elbow_r`, `knee_l`, `knee_r` | pole | The limb turns about its root–end axis so the middle joint lies towards the handle; the hand or foot stays (at its target, or where the animation put it). |
| `head` | look | The handle sits in front of the face. The neck chain turns so the head moves towards the handle around the first neck bone: yaw about the chest's up and pitch, each clamped, shared by the chain's weights; a rotation adds its roll about the facing direction. |
| `chest` | chest | FABRIK over the spine joints with the spine's root fixed, each joint's bend limited, then the rotations re-derived from the new segment directions (lengths kept). The head follows unless its handle is set; arms re-solve after. |
| `pelvis` | pelvis | The pelvis moves (and turns, with a rotation). Feet with targets stay planted (their legs re-solve last); feet without follow. |

Solve order per frame: pelvis → spine → head → arms → legs, one pass.

```dart
final poser = LuminaPoseAuthoringComponent(mesh: mesh); // or found on BeginPlay
character.addComponent(poser);
await poser.ready;                                       // the rig, read from the mesh's GLB on a worker isolate
poser.setHandleTarget('hand_r', handWorld, worldRotation: gripWorld);
poser.setHandleTarget('elbow_r', elbowWorld);
poser.handleWorldTransform('head');                      // where a handle is now (world, unit scale)
poser.findNearestHandle(cursorWorld, maxDistance: 8);    // (name, distance) or null
poser.clearHandle('elbow_r');
poser.resetToReference();
```

- `setHandleTarget(name, worldLocation, {worldRotation})` takes world units (cm). The target enters the mesh's model frame on the next solve, through the mesh's render transform (its world transform times the asset unit scale), and stays there: with `captureMode` **`holdTargets`** (default) targets live in component space, so the pose follows the actor, and clearing a handle gives its limb back to the incoming pose; with **`bakeToPose`** every solved pose becomes the next frame's base, so clearing leaves the limb where it is. Before the rig loads a target is kept for when it does.
- `weight` (0–1) blends the solved pose over the incoming animation. To hold a mannequin's pose, play nothing (or a hold clip) and keep `weight` 1.
- A node the transform manager still holds as last written is treated as unanimated: its base is the pose from before the write, so the solve never builds on its own output.
- `onHandleChanged` and the owner's `onPoseHandleChanged(handle)` (the Blueprint event) run when a target is set or cleared.
- `lastSolveMicros`: the last solve's cost.

## Poses

- `toAuthoredPose(name)` captures the pose shown (local TRS of every rig joint) as an `AuthoredPose` (`lumina_core`).
- `applyAuthoredPose(pose, blendSeconds:)` drops every target and shows `pose`, blended in from the pose shown; handles set later solve over it. `resetToReference()` drops targets, an applied pose and what was baked.
- `LuminaPoseLibrary.load(assetPath, provider:)` reads a mesh's `PoseLibrary.lmas` (what the Animation Editor writes, `contents/animations/<Mesh>/PoseLibrary.lmas`) through `LuminaAssets` (a game's bundle, or the disk); `parse(bytes)` reads one in memory.
- `savePose(slot, name)` / `loadPose(slot, name, blendSeconds:)` keep poses in a save game slot (`customSaveData['lumina_poses']`, other data in the slot is kept), through `LuminaPoseLibrary.saveToSlot` / `loadFromSlot`. While Play-In-Editor runs (`LuminaPoseLibrary.editorProjectDir`, set by Play), Save Pose also writes the pose into the mesh's `PoseLibrary.lmas` in the project, on a worker isolate.

## Blueprint nodes

**Animation|Pose Authoring** (VM and generated code call the same `LuminaPoseAuthoringNodes` functions; locations in authoring axes, rotators in degrees; every node but Add Pose Authoring works on the owner's first pose authoring component):

- `add_pose_authoring` (Mesh → the component; the owner's first skeletal mesh when unwired; an existing one on that mesh is returned),
- `set_pose_handle_target` (Handle, Location, Use Rotation, Rotation → accepted),
- `get_pose_handle_transform` (Handle → Location, Rotation),
- `clear_pose_handle` (Handle), `reset_pose`,
- `find_nearest_pose_handle` (Location, Max Distance → Handle, Distance; `''` and −1 when none),
- `capture_pose` (Name → Pose, a JSON string) / `apply_pose` (Pose, Blend Time → applied),
- `save_pose` (Slot, Name) / `load_pose` (Slot, Name, Blend Time) → success,
- **Event On Pose Handle Changed** (`event_pose_handle_changed` → Handle), dispatched from `LuminaActor.onPoseHandleChanged`.

`LuminaPoseAuthoringComponent` is also a Blueprint component type (`LuminaPoseAuthoringComponent.fromProperties`: `rigAsset`, `weight`, `captureMode`).

## Numbers

On this machine (Windows, RTX PRO 2000 for the smoke) a mannequin rig has 41 slots; every one of its 11 handles held, a solve takes about 0.025 ms; inside the smoke's rendered frames the median is about 0.1–0.19 ms (it shares the CPU with rendering and frame reads). Targets are reached to 1e-13 cm when in reach; bone lengths are kept to 1e-4 cm.

## Limits

One pass, no iteration across chains: a hand target out of reach after the chest bent stays short of it. Fingers are not posed (a later hand preset). The spine's bend limit is measured over the incoming pose, not as an absolute range. MetaHuman corrective joints follow their parents rigidly (their rig logic does not run at runtime).
