[Türkçe](../../tr/lumina/character-slots.md)

# Character slots

A character made of several skinned meshes — a body, a face, hair, eyebrows, a beard, garments — is animated once and its parts are swapped by name. Three pieces make that work:

- **Pose following**: a skeletal mesh takes its leader's pose by bone name every frame (`LuminaAnimatedMeshComponent.poseLeader`, Blueprint property `poseFrom`; see [Components: meshes](components-mesh-and-particles.md)).
- **Slots**: components carrying a `slot` name are listed, filled and cleared at run time (`LuminaCharacterSlots`, the *Character|Slots* Blueprint nodes).
- **Body masks**: a garment slot hides the body triangles under it, so skin never pokes through.

| Part | Where |
| :--- | :--- |
| Slots | `lib/src/components/mesh/character_slots.dart` |
| Body masks (engine side) | `lib/src/components/mesh/character_slots/body_masks.dart` |
| Mask computation, skinned GLB geometry, closest-point queries | `lumina_core/lib/src/garment/` (`LuminaBodyMask`, `LuminaSkinnedMeshData`, `LuminaTriangleGrid`) |
| Garment fitting | `lumina_core/lib/src/garment/` (`LuminaGarmentFitter`, `LuminaRbfField`, `LuminaGarmentGlbWriter`); the cache: `lib/src/components/mesh/garment_cache.dart` (`LuminaGarmentCache`) |
| Blueprint nodes | `lib/src/blueprint/node_library/character_slots.dart`, `lib/src/blueprint/blueprint_function_library/character_slots.dart` |

## A slotted Blueprint

Each part is a component of the actor Blueprint with two properties:

| Property | Meaning |
| :--- | :--- |
| `slot` | The slot name (`Body`, `Face`, `Hair`, `Torso`, …). Empty: not a slot. |
| `poseFrom` | The id (else name) of the skeletal mesh component whose pose this one follows; on a Skinned Cloth, the mesh it is worn on. |
| `masksBody` | Optional: whether a garment in this slot hides the body under it (default: true for `Torso`, `Legs`, `Feet`). |

A slot whose mesh is empty is built as an empty scene component and can be filled later. The MetaHuman plugin's split export writes such a Blueprint: `Root` > `Body` > `Face` > `Eyelashes`, `Eyebrows`, `Beard`, `Fuzz`, `Hair`, `Mustache`, plus `Torso`, `Legs`, `Feet` under `Body`. In the Blueprint editor the Details panel shows **Slot** and **Pose From** (a picker over the Blueprint's other skeletal meshes, never the component itself or one already following it) under *CHARACTER* on Skeletal Mesh and Skinned Cloth components.

`LuminaBlueprintComponents.construct` (used by the Blueprint preview, PIE's VM and generated game code alike) links the pose leaders and registers the slots, so a game behaves as the editor shows.

## `class LuminaCharacterSlots`

`LuminaCharacterSlots.of(actor)` (or `maybeOf`) gives the actor's slots.

| Member | Description |
| :--- | :--- |
| `names` | The slot names, in registration order. |
| `slot(name)` / `component(name)` / `meshOf(name)` | The slot, its component now, its stored mesh reference ('' when empty, null when unknown). |
| `setMesh(name, mesh)` | Fills the slot (a stored mesh path, resolved like the Blueprint's). A skeletal mesh swaps its mesh **in place** (`LuminaStaticMeshComponent.setMeshAsset`): its animation, Animation Blueprint, followers and children stay. An empty slot gets a new skeletal mesh that follows the slot's leader; a Skinned Cloth slot is rebuilt on the new garment. Completes once loaded; false for an unknown slot. |
| `clear(name)` | Empties the slot (children stay under an empty component). |
| `register(name, component, {mesh, leaderSlot, properties})` | Registers a slot built in Dart. |
| `refreshBodyMask(bodySlot)` | Recomputes the body's mask from the garment slots following it. |
| `changes` | A stream of slot names, each time a slot's component changes. |

## Body masks

When a garment slot (`masksBody`) is filled or cleared, or the body itself changes, the body's mask is recomputed on a worker isolate: `LuminaBodyMask.compute` marks a body vertex covered when a garment surface lies within 4 cm outside it and that garment point is at least 3 cm from the garment's open edges (collars, cuffs and hems keep the skin under them drawn); a triangle is covered when its three vertices are. `LuminaBodyMask.applyDegenerate` writes a copy of the body GLB whose covered triangles are degenerate (not drawn), and the body component draws that copy in place (`<body path>#masked-<digest>`). The stored mesh stays the unmasked body; clearing the garments restores it. A Draco-compressed body cannot be patched and stays whole.

## Placed skeletal meshes

A `SkeletalMesh` actor placed in a level plays, in Play-In-Editor and in the generated game alike, as an animated skeletal mesh built by `LuminaLevelSkeletalMesh.build` (`lib/src/game/level_skeletal_mesh.dart`) from its Mesh Component Details: **Cast Shadow**, the level material, its springs, **Slot** (the actor's character slot of that name holds the mesh) and **Pose From** (another `SkeletalMesh` actor, by id: a `LuminaPoseFromActorComponent` makes the mesh follow that actor's mesh by bone name as soon as it is in the world). The generated level emits the same call with the same Details. Draw distances and Volumetric Shadow are not applied (no mesh in Lumina culls by distance yet); an Anim Class on a placed mesh is not played (Animation Blueprints play on Blueprint components).

## Garments in slots

A slot filled with a **Garment** asset (`.lmas` of `AssetType.garment`, see the [Garment editor](../lumina_ui/sub-editors/garment.md)) shows the garment fitted to the body of the slot it follows. `setMesh(slot, garment)` (or `fitGarment(slot, garment)`, which returns the fit report) reads the garment, its source mesh and reference body and the current body (unmasked), and fits it on a worker isolate through `LuminaGarmentCache` (one fit per garment, source, reference body and target body content; the same body again comes from the cache). When the body slot changes, every garment slot following it is fitted to the new body and the body's mask is recomputed. A garment that simulates as cloth becomes a Skinned Cloth worn on the body, with its Cloth Settings.

The fit (`LuminaGarmentFitter`, lumina_core, pure Dart):

1. The garment's source mesh, refined until its mean edge is at most 2.5 cm (`LuminaSkinnedMeshData.refined`), at its placement on the reference body.
2. A smooth deformation from the reference body to the target: bodies with the same topology (vertex for vertex, as MetaHuman bodies) through an RBF field (`LuminaRbfField`, `r³` with an affine part) over 360 farthest-point body vertices; other bodies through the skeleton: each garment vertex follows the reference body's skinning from its rest pose to the target's (joints matched by name).
3. Within 4 cm of the skin a vertex keeps its distance to it (the same triangle and barycentre on a same-topology target, else the nearest target point, along the surface normal), blended out by 10 cm.
4. Push-out: a vertex inside the target body or closer than the garment's thickness moves out along the surface normal; the push is smoothed over the garment and applied again.
5. Optional cloth settle (the garment's `settleSteps`, 0–240): that many 1/60 s steps of gravity with position-based edge constraints at their fitted lengths (16 iterations a step) and the body pushed out after each step; vertices touching the body are held. It runs inside the fit on the worker isolate, so it is cached with it.
6. Skin weights from the nearest target-body surface point (its vertices' weights by barycentre), smoothed over the garment three times, the four strongest normalised.

`LuminaGarmentGlbWriter` writes the result as a skinned GLB over the target body's nodes and joints with the source's materials, served to the slot's component under a `garment:<slot>#<digest>` key. `LuminaGarmentFitReport` gives the largest and mean depth inside the body (cm), the landmark error on the target, whether the correspondence was dense, the vertices pushed and the time. Measured with the T-shirt of `test-assets/Props/Clothes Line/` landmarked on the mannequin Manny: on Quinn nothing inside (0.0 cm), landmark errors 0.8–1.0 cm, about 1.7 s for the refined shirt (measured in the skeletal mesh smoke scenario 06).

The push-out holds at the rest pose; poke-through while animating is hidden by the body mask.

## Blueprint nodes (*Character|Slots*)

| Node | Pins |
| :--- | :--- |
| **Set Slot Mesh** | `slot`, `mesh` (asset path; '' clears) → true when the owner has that slot; the mesh loads in the background. |
| **Clear Slot** | `slot` → true when the owner has that slot. |
| **Fit Garment** | `slot`, `garment` (a Garment `.lmas`) → true when the owner has that slot; the garment is fitted to the slot's body in the background. |
| **Get Slot Mesh** | `slot` → the mesh in it ('' when empty or unknown). |
| **Get Slots** | → the owner's slot names. |

The nodes act on the actor running the graph. The VM and generated Dart give the same results (`blueprint_codegen_parity_test.dart`).
