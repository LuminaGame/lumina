[Türkçe](../../tr/lumina/traversal.md)

# Traversal

A character that presses jump in front of an obstacle can hurdle it, vault it or mantle onto it instead of jumping: the obstacle is measured with collision queries, an action and a clip are chosen for it, and the clip plays with **root motion** — its root's translation and yaw move the character — bent by **motion warping** so that the hands land on the measured ledge and the feet on the measured floor. The clip plays in the Animation Blueprint's default slot over the state machine (a Motion Matching state included) and hands the pose back with inertialization.

| Part | Where |
| :--- | :--- |
| Obstacle check and classification | `lib/src/components/movement/traversal/traversal_check.dart` |
| Chooser rows and the clip / start-time pick | `lib/src/components/movement/traversal/traversal_chooser.dart` |
| The component | `lib/src/components/movement/traversal/traversal_component.dart` |
| Motion warping | `lib/src/animation/root_motion/motion_warping.dart` |
| A clip's root motion on the CPU | `lib/src/animation/root_motion/root_motion_track.dart` |
| Root-motion montage player | `lib/src/animation/root_motion/root_motion_montage_player.dart` |
| The slot player interface | `lib/src/animation/root_motion/anim_slot_player.dart` |
| Blueprint nodes | `lib/src/blueprint/node_library/traversal.dart`, `lib/src/blueprint/blueprint_function_library/traversal.dart` |

## The check (`LuminaTraversalCheck`)

All in runtime axes (Y up, cm), heights above the character's feet:

1. A capsule (`traceRadius` 30, `traceHalfHeight` 60) swept from the character along its facing finds a near-vertical face (`|normal.y| ≤ maxWallSlope` 0.5). The sweep reaches `minTraceDistance` (75 cm) at rest and `maxTraceDistance` (350 cm) at `fastSpeed` (500 cm/s); a ray into the face at the contact height places it exactly.
2. A ray down from above the face finds the top: the **front ledge** (the top front edge on the face, with the face's horizontal normal) and the **obstacle height**, which must lie in `minLedgeHeight`–`maxLedgeHeight` (50–275 cm); a wall reaching above the maximum is rejected first.
3. The character's capsule swept from where it stands to just above the ledge must be free (room to rise).
4. Rays marching down across the top every 4 cm (refined by bisection) find the back edge: the **back ledge** and the **obstacle depth** (`maxDepthScan` 150 cm). The capsule swept across the top must be free, else the depth stops where it hits and there is no back ledge.
5. The capsule swept down behind the back ledge by the obstacle height plus `backFloorReach` (20 cm) finds the **back floor**; the **back ledge height** is the top above it.
6. A capsule on top just behind the front ledge must fit (room on top).

Classification (`LuminaTraversalActionType`):

| Action | When |
| :--- | :--- |
| `hurdle` | back ledge, back floor, depth < 59 cm, back ledge height ≥ 50 cm |
| `mantle` | back ledge, back floor within 10 cm of the top and depth < 59 cm; or depth ≥ 59 cm |
| `vault` | back ledge, no back floor within reach (a drop behind; the character falls after), depth < 59 cm |
| `none` | nothing fits (`reason` says why); a mantle without room on top is `none` too |

`LuminaTraversalCheckResult` carries every measurement, the hit component and `facingYaw` (into the obstacle).

## Chooser rows (`LuminaTraversalAnimation`)

One row per clip: `action`, `clip` (a glTF animation of the character's mesh), `minHeight`/`maxHeight`, `minDepth`/`maxDepth`, `minSpeed`/`maxSpeed` (horizontal cm/s; a row fits when `min ≤ value ≤ max`, speed `< max`), `blendOutTime` (the clip may end here when the player steers), `endTime`, `playRate`, `blendTime` (inertialization in and out), `maxStartTime` and the warp `windows`. Rows round-trip through JSON (`toJson` / `fromJson`), which is how a Blueprint component stores them.

`LuminaTraversalChooser.choose` keeps the rows that fit the check and whose clip the mesh has, then picks the clip and start time (every 1/30 s up to `maxStartTime`) whose feet (`foot_l`, `foot_r`, or the schema's position bones) are closest to the pose shown now, both with the root's motion removed — so a left-foot or right-foot variant starts on the matching step.

## Motion warping (`LuminaMotionWarper`)

A `LuminaWarpWindow` names a target (`FrontLedge`, `BackLedge`, `BackFloor`), a clip time range, whether it warps translation and / or rotation, whether it keeps the clip's vertical motion (`ignoreVertical`), and the **warp point**: the root itself, or an offset from the root at the window end (`warpPointOffset`, root frame: x lateral, y up, z forward, cm) — given, or measured from a bone of the clip (`warpPointBone`, e.g. a bone parked where the clip's ledge was authored).

Inside a window, at every step the clip's remaining root displacement to the window end is scaled, axis by axis in the target's frame, to the remaining distance to the target (an axis on which the clip barely moves reaches its target linearly in time instead); the yaw turns to the target's the same way. So the root keeps the clip's shape and arrives exactly on the target at the window's end; steps are split at window boundaries. Outside windows the root follows the clip.

## Root-motion montages (`LuminaRootMotionMontagePlayer`)

`LuminaRootMotionMontage` names the clip, start / end / blend-out time, play rate, blend time and windows. The player samples the clip from the mesh's GLB on the CPU (`LuminaGlbAnimationSampler`, the same one the motion matching databases of the mesh use, through `LuminaPoseSearchDatabaseRuntime.meshSampler`), shows the pose with all of the root's motion removed (ground position, facing and height relative to the start) and moves its `owner` instead: every `advance` places the actor (feet `feetOffset` below its location) on the warped root and turns it to the warped yaw. It is a `LuminaMeshPoseDriver` and a `LuminaAnimSlotPlayer`: `begin(fromPose:, fromVelocity:)` starts from the pose shown before and blends from it by inertialization; `pose` / `poseVelocity` are what the next pose source blends from. `rootVelocity` is the clip root's velocity at the current time (what the character keeps moving with).

`LuminaRootMotionTrack` is the clip's root ground frame sampled at 60 Hz: `delta(a, b)` in the root's frame (cm), `velocityAt`, `boneOffset(node, t)`.

## The Animation Blueprint slot

`LuminaAnimBlueprintInstance.playSlot(player)` plays a `LuminaAnimSlotPlayer` in the default slot over the state machine: it starts from the pose the mesh shows (the Motion Matching player's pose and velocity), takes the mesh, and is advanced every tick before the mesh applies it while the state machine holds its state. When the player finishes, a Motion Matching state blends from the slot's last pose (`LuminaMotionMatchingPlayer.blendFrom`: inertialization plus a search at once); `stopSlot()` ends it early. VM and generated Animation Blueprints share this code, so both behave the same.

## The component (`LuminaTraversalComponent`)

| Member | Meaning |
| :--- | :--- |
| `animations` | The chooser rows. |
| `tryTraversalAction()` | Checks, chooses and plays; false (nothing changes) when the character is not walking, no action or clip fits, or the clips are not loaded yet. |
| `checkTraversal()` | Only the check. |
| `isTraversing`, `currentAction`, `player`, `lastCheck`, `lastChoice`, `actionCount` | State. |
| `stopTraversal()` | Ends the action (interrupted). |
| `onTraversalFinished` | `(action, interrupted)`. |
| `customMovementMode` | The custom movement mode index set while an action plays (1). |
| `rootBone`, `meshYawOffsetDegrees` | The rig of the clips when they are not the motion matching database's (`rootBone` also overrides the database's root: the bone that carries the clips' root motion). |
| `minLedgeHeight`, `maxLedgeHeight`, `minTraceDistance`, `maxTraceDistance`, `debugDraw`, `enabled` | Check tunables; `debugDraw` marks the ledges and floor for a second. |
| `useRig(rig)` | Uses a rig built in code. |

While an action plays the movement component is parked in `MovementMode.custom` with zero velocity; the actor's location is set from the warped root every frame (after the movement tick, so depenetration never fights the path — the checks made sure there is room). When it ends the character walks (or falls, after a vault) with the clip's exit velocity, capped at its walk speed. With an Animation Blueprint the action plays in its slot; without one the component drives the mesh itself and hands it back to the previous pose driver (blending when it is a motion matching player).

Blueprints add it as a component of type `LuminaTraversalComponent` (`animations` as JSON rows in its properties) and call it with the **Try Traversal Action** node (Success), **Traversal Check** (Action Type, Obstacle Height, Obstacle Depth, Back Ledge Height, Has Front Ledge) and **Is Traversing**. A jump that tries traversal first: `IA_Jump Started → Try Traversal Action → Branch (Success) → False: Jump`.

## Tests

`test/src/components/movement/traversal_check_test.dart` (boxes: hurdle, vault, low / high mantle, platform, too high / low, no room, nothing ahead, trace length by speed), `test/src/animation/root_motion/` (warping math, root track, player, blend in / out), `test/src/components/movement/traversal_component_test.dart` (a Blueprint character hurdling and mantling, Jump fallback, the slot handing back to motion matching), `lumina_editor_data/test/blueprint/traversal_blueprint_parity_test.dart` (VM and generated Dart alike), `lumina_editor_data/test/samples/gasp_traversal_fbx_test.dart` (real traversal clips on boxes: every warp target reached within 1 cm), and the GPU smoke `lumina_editor_data/test/smoke/traversal_smoke_test.dart`.
