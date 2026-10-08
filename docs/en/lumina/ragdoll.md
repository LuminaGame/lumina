[Türkçe](../../tr/lumina/ragdoll.md)

# Ragdolls, falls and getting up

A skeletal character can go limp: per-bone rigid bodies from a **physics asset** are created in the world's [physics](physics.md) subsystem, held together by **joints** (ball-and-socket with a swing cone and a twist range, hinges for knees and elbows), collide with the level and with each other, and drive the animated mesh's bones, blended with the animation. A character with a `LuminaRagdollComponent` also reacts to falls (limp in the air on a long fall, a heavy landing on a hard touchdown) and gets up again with the get-up clip that lies like it.

| Part | Where |
| :--- | :--- |
| Physics asset format and generator (pure Dart) | `lumina_core/lib/src/physics_asset/physics_asset_data.dart`, `physics_asset_generator.dart` |
| Joints | `lib/src/physics/physics_joint.dart`, `lib/src/physics/joint_batch.dart` |
| Bodies and joints of one ragdoll | `lib/src/physics/ragdoll/ragdoll.dart` |
| CPU skeleton subset, bodies → bones | `lib/src/physics/ragdoll/ragdoll_skeleton.dart`, `ragdoll_poser.dart` |
| Falls | `lib/src/physics/ragdoll/fall_monitor.dart` |
| Getting up | `lib/src/physics/ragdoll/ragdoll_get_up.dart` |
| The component | `lib/src/physics/ragdoll/ragdoll_component.dart` (+ `ragdoll_component_states.dart`) |
| The mesh hook | `lib/src/components/mesh/mesh_pose_modifier.dart` |
| Blueprint nodes | `lib/src/blueprint/node_library/ragdoll.dart`, `lib/src/blueprint/blueprint_function_library/ragdoll.dart` |
| Generating the asset in a project | `lumina_editor_data/lib/src/services/physics_asset_generation.dart` |

## Physics assets

`LuminaPhysicsAssetData` is the document the [Physics Asset editor](../lumina_ui/sub-editors/physics-asset.md) authors, stored as JSON in a `physicsAsset` `.lmas` under `metadata['physics_asset']` (schema 2, lengths in cm; a schema 1 document in metres is converted on read). Keys this version does not know are kept and written back.

- **Bodies** (`LuminaPhysicsBodyData`): `bone`, `shape` (`capsule` along local Y, `sphere`, `box`), `radius`, `half_height` (including the caps), `half_extents`, `offset_t` / `offset_r` (the shape in the bone's frame: world rotation, cm, Euler XYZ degrees composed `Ry · Rx · Rz`), `mass_kg`, `linear_damping`, `angular_damping`.
- **Constraints** (`LuminaPhysicsConstraintData`): `body_a` (parent side), `body_b` (child side; the joint sits at its bone's origin), `angular_mode` (`free`, `limited`, `locked`), `swing1_deg` (about the joint frame's Y), `swing2_deg` (about Z), `twist_deg` (symmetric, about X), and the runtime keys `type` (`ball` / `hinge`), `twist_min_deg` / `twist_max_deg` (an asymmetric range: a knee bends 0…140°) and `frame_r` (the joint frame in the child bone's frame; absent: the bone's frame). Limits are measured from the **rest pose**.
- **`disabled_collision_pairs`**: body pairs that never collide.

`LuminaPhysicsAssetGenerator.fromSampler(sampler, totalMassKg: 80)` builds one from a skinned GLB's skeleton (`LuminaSkeletonRest`): bodies only on the main bones found by name — pelvis, two spine bodies, head, upper / lower arms, hands, thighs, calves, feet (UE / MetaHuman names `pelvis`, `spine_02`, `spine_04`, `upperarm_l`, … and Mixamo names) — never on twist, corrective, finger or IK bones, so a MetaHuman's hundreds of joints keep their animated transforms under the simulated bones. Sizes follow the character's height (head to feet); capsules lie along each limb toward the next body, the torso capsules across the body, the feet are flat boxes (a round shape would roll). Mass is shared by body (pelvis 15 %, chest 18 %, thighs 11.5 % each, …). Every body but the pelvis gets a joint to its nearest body ancestor: ball joints with anatomical cones and twists, hinges for elbows (bending forward) and knees (bending backward) — the forward comes from the feet. Pairs that overlap at rest are disabled.

`PhysicsAssetGeneration.generateForSkeletalMesh(projectDir, meshAssetPath)` writes `contents/physics/PHYS_<mesh>.lmas` (reference slot `skeletal_mesh`, project-relative), building on a background isolate; an existing asset is kept unless `overwrite`.

## Joints

`LuminaPhysicsJoint` joins `bodyA` and `bodyB`: anchors and joint frames in each body's frame (`LuminaPhysicsJoint.atWorld` takes them from the bodies' current poses). The relative rotation of B's joint frame in A's splits into **swing** (an elliptical cone `swing1` × `swing2`) and **twist** (`twistMin` … `twistMax`); `LuminaJointKind.hinge` locks the swing. `frictionTorque` resists relative turning (muscle tone, so a ragdoll settles instead of rocking); `motorEnabled` + `motorTarget` + `motorRate` + `motorMaxTorque` pull the relative rotation toward a target (a powered ragdoll).

`LuminaPhysicsSubsystem.addJoint` / `removeJoint`. Each step the awake joints (`LuminaJointBatch`) are solved next to the contacts: point and angular rows with warm starting, passes alternating direction, then `jointIterations` (6) joint-only passes; angular limits correct 20 % of an error past a 0.02 rad slop per step; after integration `jointPositionIterations` (4) passes pull the anchors together. Joined bodies stop colliding with each other and share an island (they sleep and wake together). Bodies of one actor collide with each other only when both set `LuminaRigidBody.collidesWithOwnBodies` and neither lists the other in `ignoredBodies`.

## A ragdoll

`LuminaRagdoll.create(physics:, owner:, asset:, skeleton:, rest:, start:, velocities:)` makes a collision component and rigid body per asset body (owned by `owner`, not registered with the collision subsystem, so the owner's capsule and traces never see them), builds the joints at the rest frames, then moves the bodies onto the `start` frames with the bones' velocities. Bodies use friction 0.9 and no restitution; joint friction is `jointFrictionPerKg` (3000 kg·cm²/s² per kg) × the child's mass.

- `boneFrames()` — the bone frames the bodies give now (`bodyWorld · offset⁻¹`).
- `addImpulse(impulse, bone:, location:)`, `addVelocity`, `driveToward(frames, maxTorque:, rate:)` (motors toward the relative rotations of a pose), `setDamping`.
- `kineticEnergy`, `maxSpeed`, `centerOfMassSpeed`, `isSettled(speed)`, `maxJointError`, `destroy()`.

`LuminaRagdollSkeleton` is a subset of a mesh's nodes closed under parents (or all of them) with their rest pose; poses are flat TRS arrays, world affines are in the mesh's render-transform frame (world cm). `LuminaRagdollPoser.apply(pose, meshAffine, targets, weight)` writes world frames into the local pose, parents first: a driven bone's world frame becomes `lerp(animated, target, weight)` and its local transform follows from its parent's new frame; driven bones below another driven bone keep their animated local translation (no stretching); the rest ride along.

## The mesh hook

`LuminaAnimatedMeshComponent.poseModifiers` run after the clip or the pose driver and the joint overrides: the mesh reads the local transforms of a modifier's `poseModifierNodes` into a pose array, calls `modifyPose(pose, meshTransform, dt)` and writes them back when it returns true. The Animation Blueprint, motion matching and slot montages keep running underneath.

## The component

`LuminaRagdollComponent` (Blueprint type `LuminaRagdollComponent`, built from its properties in PIE and generated games):

| Property | Default | |
| :--- | :--- | :--- |
| `physicsAsset` | `''` | A `physicsAsset` `.lmas`; empty generates one from the mesh's skeleton. |
| `blendWeight`, `blendInTime`, `blendOutTime` | 1, 0.08 s, 0.4 s | Physics ↔ animation weight and fades. |
| `powered`, `motorStrength` | false, 2·10⁶ | Motors toward the animated pose (kg·cm²/s² per kg). |
| `autoRagdollOnFall`, `ragdollFallSpeed`, `ragdollLandingSpeed`, `hardLandingSpeed` | true, 1300, 1200, 750 cm/s | `LuminaFallMonitor` on the movement component. |
| `flailClip`, `flailStrength` | `''`, 6·10⁵ | What the motors follow while the ragdoll falls. |
| `hardLandingClip` | `''` | Played over the animation on a hard touchdown (`onHardLanding`). |
| `autoGetUp`, `settleSpeed`, `settleTime`, `maxRagdollTime` | true, 8 cm/s, 0.6 s, 8 s | When a ragdoll gets up. |
| `getUpClips`, `getUpBlendIn`, `getUpBlendOut` | `[]`, 0.3 s, 0.35 s | Candidate get-up clips and their blends. |
| `meshYawOffsetDegrees` | 0 | The mesh's authored forward, as its Animation Blueprint says. |

The mesh's skeleton and clips are read on the CPU from its GLB through `LuminaPoseSearchDatabaseRuntime.meshSampler` (shared with motion matching, parsed once on a background isolate); the physics asset's `.lmas` is parsed on a background isolate.

- **`startRagdoll({impulse, bone, location})`**: the bodies start on the animated bones with the velocities of the last two frames; the movement component waits in custom mode `ragdollMovementMode` (71) and the capsule follows the pelvis on the ground (the camera follows). Refused while another system holds the capsule in a custom mode (a traversal action).
- **Falls**: falling faster than `ragdollFallSpeed` goes limp in the air (motors toward `flailClip` while the pelvis is more than 60 cm above the ground); a touchdown faster than `ragdollLandingSpeed` goes limp, faster than `hardLandingSpeed` plays `hardLandingClip`.
- **Settling**: once the centre of mass moves slower than 3 × `settleSpeed`, damping rises (3 / 6) to still the last wobble; below `settleSpeed` (and every body below 4 ×) for `settleTime` the bodies sleep and, with `autoGetUp`, the character gets up (or after `maxRagdollTime`).
- **Getting up** (`LuminaRagdollGetUp`): among `getUpClips`, the clip whose first frame lies the same way (the pelvis's forward pointing down or up) and closest in key-bone layout; the mesh is placed so that frame lies where the ragdoll lies (body axis pelvis → head, the pelvis over the ragdoll's, the ground under it), the clip plays with its root motion moving the character, blending in from the ragdoll's last pose over `getUpBlendIn` and out to the live animation over `getUpBlendOut`; then the movement component walks again. Without a fitting clip the animation blends back in over `blendOutTime`.
- `stopRagdoll({getUp})`, `toggleRagdoll()`, `addImpulse(impulse, bone:, location:, startIfAnimated:)`, `playHardLanding([clip])`, `state` (`animated`, `ragdoll`, `gettingUp`, `blendingOut`), `ragdoll`, `getUpPlan`, `ready`, `loadError`, callbacks `onRagdollStarted`, `onRagdollEnded`, `onGetUpStarted`, `onHardLanding`.

## Blueprint nodes

**Physics|Ragdoll** (on the owner's ragdoll component; VM and generated code call the same `LuminaBlueprintFunctionLibrary` functions): `start_ragdoll` (→ Started), `stop_ragdoll` (Get Up), `toggle_ragdoll`, `is_ragdoll`, `add_ragdoll_impulse` (Impulse in authoring axes, Bone Name; starts the ragdoll when animated).

## Numbers

On this machine (Windows, RTX PRO 2000 for the smoke): a 16-body, 15-joint mannequin ragdoll steps in 0.08–0.17 ms at 120 Hz awake; dropped from 1.5 m it never gains energy, keeps every joint within 0.5 cm and settles in about 2 s; dropped from 15 m with get-up clips it goes limp in the air and is standing again about 4 s after the drop. The MetaHuman of the [Game Animation Sample example](../lumina_editor_data/game-animation-sample.md) gets 16 bodies; touching down at about 1200 cm/s stretches its joints by up to 9 cm for a few frames, lying down they hold within 0.01 cm.

## Limits

The solver has no continuous collision: a limb moving faster than about 5 cm per step can sink that far into the floor for a step before it is pushed out. Self-collision is between non-adjacent bodies that do not overlap at rest. There is no partial ragdoll (a limp arm on an animated body) and no hit reaction blending beyond impulses on a full ragdoll.

---

[Previous: Physics](physics.md) | [Up: lumina (engine core)](index.md) | [Next: AI](ai.md)
