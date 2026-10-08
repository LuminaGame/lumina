[Türkçe](../../tr/lumina/motion-matching.md)

# Motion matching

Motion matching animates a character from a large set of unstructured clips (walk loops, starts, stops, pivots, turns, arcs, strafes, idles) without a hand-built state graph: several times a second it searches the clip frame whose pose and root trajectory best match the character's current pose and the trajectory the player asks for, and switches to it with inertialization. In Lumina it has three parts:

- **Pose search database** (`lumina_core/lib/src/pose_search/`, pure Dart): the asset, the CPU clip sampler, feature extraction, normalization, mirroring, the search and the feature cache.
- **Runtime** (`lumina/lib/src/animation/motion_matching/`): trajectory prediction, the player, inertialization, the mesh pose driver, the actor component and debug drawing.
- **Animation Blueprints**: a **Motion Matching** state pose, in the VM (Play-In-Editor) and in generated Dart, with identical results; and the **Pose Search Database editor** in Lumina Studio.

## The pose search database asset

A pose search database is an `.lmas` asset of type `poseSearchDatabase` whose `raw_payload` is a `LuminaPoseSearchDatabaseDocument` as JSON (`target_mesh` in its metadata). Its feature matrix is cached in a `.posedb` file next to it (`PSD_Locomotion.lmas` → `PSD_Locomotion.posedb`), which the editor writes on **Build** and a game bundles with the rest of `contents/`.

| Field | Meaning |
| :--- | :--- |
| `targetMesh` | The skeletal mesh whose GLB holds the clips (every clip a mesh plays lives in its GLB, see [Animation](animation.md)). |
| `clips` | `LuminaPoseSearchClip`: `clip` (the glTF animation name), `loop` (the trajectory wraps), `mirror` (a mirrored copy is searched too), `tags`, `enabled`, `costBias` (added to the clip's cost; negative favours it), `samplingStart` / `samplingEnd` (only frames in this range are jumped to; an end of 0 is the clip's end; the rest still plays on). |
| `schema` | `LuminaPoseSearchSchema`: `sampleRate` (30 Hz), `trajectoryTimes` (−0.33, 0.33, 0.67, 1.0 s), `trajectoryPositionWeight`, `trajectoryFacingWeight`, `bones` (`LuminaPoseSearchBone(name, position:, velocity:)` weights; default `foot_l` / `foot_r` position + velocity, `pelvis` velocity), `rootBone` ('' = the bone named `root` above the skin, else the skin's top joint), `meshYawOffsetDegrees`. |
| `searchInterval` | Seconds between searches (0.1). |
| `continuingPoseBias` | A search only switches when a frame beats continuing by this (0.05). |
| `loopingCostBias` | Added to every looping clip's cost (−0.05: settled poses prefer loops). |
| `blendTime` | Seconds a switch blends over (0.2; the inertialization halflife is a quarter of it). |
| `excludeEndSeconds` | The last seconds of a one-shot clip are never jumped into (0.3). |

### Features

Every sampled frame becomes one row, all in the character's own frame: origin = the root bone projected on the ground, forward = the root's rest forward turned by its rotation (+Z, lateral +X = left, up +Y), in the mesh's model units (metres for glTF):

- per trajectory time: the root's ground position (x, z) and facing direction (x, z) — a loop wraps with its per-cycle displacement, a one-shot clip continues at its end (start) velocity;
- per schema bone: its position, and its **world** velocity rotated into the character frame (a planted foot reads about 0).

Each feature group (trajectory positions, trajectory facings, each bone position, each bone velocity) is normalized by its mean standard deviation; the schema weights are applied at search time (squared), so the Motion Matching pose's `poseWeight` / `trajectoryWeight` scale them without a rebuild. Mirrored rows are derived from the plain rows (lateral components negated, `_l` / `_r` bones swapped).

### Search

`LuminaPoseSearchIndex.search(query, weights:, requiredTags:, bound:)` returns the cheapest searchable row below `bound`: rows are grouped in 16-frame blocks with bounding boxes that give a lower bound (a block that cannot win is skipped), and each row's sum stops as soon as it exceeds the best so far. The pruned search returns exactly the brute-force row (tested on 1000 random queries).

Measured on the Game Animation Sample (UEFN mannequin) set, Windows, Dart JIT:

| Database | Rows (with mirrored) | Build | Search mean / p99 | Player frame (search amortized + pose + inertialization) |
| :--- | :--- | :--- | :--- | :--- |
| 26 idle / walk / run clips | 5 866 | 0.13 s | 22 µs / 42 µs | 71 µs mean |
| 933 Idle + Walk + Run clips | 233 712 | 3.2 s | 474 µs / 1.1 ms (brute force 2.4 ms) | 85 µs mean |

### Building and caching

`LuminaPoseSearchBuilder.buildWithStats(glb, document)` builds the index and reports `LuminaPoseSearchBuildStats` (clips, rows, mirrored rows, dimensions, clips missing from the mesh, bones missing, clips with no root motion, build time). `buildInBackground` runs it on a background isolate. The cache's header carries a fingerprint of the mesh GLB and the document (`LuminaPoseSearchBuilder.fingerprint`); `LuminaPoseSearchIndex.decode` / `encode` read and write it.

## Runtime

### Trajectory prediction

`LuminaTrajectoryPredictor` records where the character has been (the past samples) and predicts where it will be: each horizontal velocity component follows an exact critically damped spring toward the desired velocity (`velocityHalflife` 0.2 s, `LuminaSpringMath.springCharacter`), the facing a spring toward the desired yaw (`facingHalflife` 0.25 s). The desired velocity is the movement component's last input (`LuminaCharacterMovementComponent.lastInputVector`, clamped to length 1) × its walk speed; the desired facing is the movement direction (orient to movement) or the pawn's own facing (strafing).

### The player

`LuminaMotionMatchingPlayer(database)` advances the matched clip each frame and searches when `searchInterval` has passed, when the desired velocity changes sharply (by more than 30 % or 30 world units/s) or when a one-shot clip has ended. The query's pose features are the row of the frame being played; its trajectory is the predicted one, turned into the character frame and model units. A switch happens only when the best frame beats continuing by `continuingPoseBias`, and is blended by `LuminaInertializer`: the difference between the pose shown and the new pose (per node translation and rotation, with their velocities) becomes an offset that decays with a critically damped spring, so there is never a two-pose crossfade. Stats: `searchCount`, `switchCount`, `switches`, `meanSearchMicroseconds`, `maxSearchMicroseconds`, `meanUpdateMicroseconds`, `matchedRootSpeed`.

**Root motion policy: the capsule drives.** The movement component moves the actor; the poser (`LuminaPoseSearchPoser`) removes the clip's root translation and yaw from the displayed pose, so the matched frames follow the capsule. Foot sliding grows with the difference between the capsule's speed and the clip's (`matchedRootSpeed`); match the movement's walk speed to the clips'.

### Showing the pose

`LuminaAnimatedMeshComponent.poseDriver` takes a `LuminaMeshPoseDriver`: while set, the mesh writes the driver's pose (local TRS per node, by name) to its skin joints instead of applying a gltfio clip, then applies joint overrides and updates the bone matrices. Mirrored frames are mirrored on the CPU (`LuminaPoseSearchPoser`, rest-pose corrected), which gltfio could not do.

### `LuminaMotionMatchingComponent`

For a code-driven character: `LuminaMotionMatchingComponent(databasePath: …)` (or `runtime:`) finds the owner's animated mesh and movement component, loads the database with `LuminaPoseSearchDatabaseRuntime.load` (shared per path; the `.posedb` is used when its fingerprint matches, otherwise the index is rebuilt in the background and, on disk, written back), and feeds the player each tick. `orientToMovement` turns the owner toward its movement with the predictor's facing spring; `desiredYaw` gives a facing to keep (strafing); `requiredTags`; `debugDraw` adds the desired (green) and matched (orange) trajectories as world debug lines (`LuminaWorld.addDebugShape`).

## In an Animation Blueprint

A state's pose can be `LuminaAnimPose.motionMatching(database, blendTime:, poseWeight:, trajectoryWeight:, requiredTags:, orientToMovement:, debugDraw:)`. While such a state is active the instance drives the mesh with a motion matching player fed by the owning pawn's movement and writes the clip it plays into the reserved variable `MatchedClip` (declare it to read it in rules or the update graph). Leaving the state hands the mesh back to gltfio at the matched clip and time, so the transition's crossfade starts from it. The VM is built with `LuminaAnimBlueprintClass.fromDocument(document, poseDatabases: {...})`; the generated class carries the documents inline (`_poseDatabases`); the validator reports a missing database. See [Animation Blueprints](blueprint/animation.md).

## Authoring a database

In Lumina Studio: **Content Browser → New → Animation → Pose Search Database**, pick the skeletal mesh, name it (`PSD_<Name>`). The editor shows the mesh's clips as a tree grouped by movement (Walk, Run, Stand, …; click to add or remove, "+" adds a group, the filter and **Add matching** add every clip whose name contains the text), the database's clips with Loop / Mirror / Use toggles, and the Details (tags, cost bias, search range per clip; search settings; the schema). **Build** writes the `.posedb` on a background isolate and reports frames, features, build time and a timed sample search. Then, in an Animation Blueprint for the same mesh, set a state's pose to **Motion Matching** and pick the database.

From code: write the document with `AnimGraphAssetService.writePoseSearchDatabase` (editor) or keep it inline, and build with `LuminaPoseSearchBuilder.buildInBackground(meshGlb, document)`.

Clips imported from FBX keep their root motion when it is keyed on the skeleton's root bone (the importer copies the root bone's translation even when the target mesh's root bone carries no skin weights).

## Limitations

- In-place clips (no root motion) give zero trajectories and only match standing still.
- The capsule drives; there is no root-motion-driven mode and no speed or orientation warping yet.
- Mirroring assumes a left/right symmetric skeleton named `_l` / `_r` (or `Left` / `Right`); a bone without a counterpart mirrors onto itself.
- One database per Motion Matching state (several states may use different ones); databases are tied to one skeletal mesh.
- Cubic-spline clips are evaluated linearly between their key values on the CPU.
