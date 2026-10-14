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
| `applyConstructed()` / `ready` | After a Blueprint's construction: fits the slots holding a Garment asset and masks the bodies under masking slots, in the background; `ready` completes when done. |
| `changes` | A stream of slot names, each time a slot's component changes. |

## Body masks

When a Blueprint is built (Play, the generated game, the Blueprint editor's viewport), when a garment slot (`masksBody`) is filled or cleared, or when the body itself changes, the body's mask is recomputed on a worker isolate: `LuminaBodyMask.compute` marks a body vertex covered when a garment surface lies within 4 cm outside it and that garment point is at least 3 cm from the garment's open edges (collars, cuffs and hems keep the skin under them drawn); a triangle is covered when its three vertices are. Only skin can be covered (see below): hair lying on a garment, eyes and teeth stay drawn. `LuminaBodyMask.applyDegenerate` writes a copy of the body GLB whose covered triangles are degenerate (not drawn), and the body component draws that copy in place (`<body path>#masked-<digest>`). The stored mesh stays the unmasked body; clearing the garments restores it. A Draco-compressed body cannot be patched and stays whole.

## Placed skeletal meshes

A `SkeletalMesh` actor placed in a level plays, in Play-In-Editor and in the generated game alike, as an animated skeletal mesh built by `LuminaLevelSkeletalMesh.build` (`lib/src/game/level_skeletal_mesh.dart`) from its Mesh Component Details: **Cast Shadow**, the level material, its springs, **Slot** (the actor's character slot of that name holds the mesh) and **Pose From** (another `SkeletalMesh` actor, by id: a `LuminaPoseFromActorComponent` makes the mesh follow that actor's mesh by bone name as soon as it is in the world). The generated level emits the same call with the same Details. **Min / Max Draw Distance** (metres) hide the mesh nearer / farther than that from the view (`LuminaDrawDistance`, see components-mesh-and-particles); the Details have no Volumetric Shadow, since no fog in the renderer is shadowed by geometry.

**Anim Class** (an Animation Blueprint asset) animates the placed mesh: `LuminaLevelSkeletalMesh.build(animBlueprint:)` adds the class's instance, which picks the mesh's pose every frame (`LuminaLevelSkeletalMesh.animClassPath` reads the Details' asset reference). Play-In-Editor passes the Blueprint VM class from the project's registry (`EditorBlueprintClassRegistry.animClassFor`). For the game, `DartCodeGeneratorService.generateLevelDartAsync` first compiles every Anim Class the level's meshes name into `lib/anim/` (`compileLevelAnimBlueprints`, async file I/O, a large payload decoded on a worker isolate), then emits `animBlueprint: <Class>.create` and imports the class. A class that is missing or does not compile is left out with a comment in the level, and that mesh plays no animation. Every code path that writes a level (Save Level, Generate Code, project creation, templates, samples) goes through the async generator; the synchronous `generateLevelDart(animBlueprints:)` takes classes that are already compiled. The VM class and the compiled one animate a placed mesh the same way: the same trace, states and clips.

## Garments in slots

A slot filled with a **Garment** asset (`.lmas` of `AssetType.garment`, see the [Garment editor](../lumina_ui/sub-editors/garment.md)) shows the garment fitted to the body of the slot it follows. `setMesh(slot, garment)` (or `fitGarment(slot, garment)`, which returns the fit report) reads the garment, its source mesh and reference body and the current body (unmasked), and fits it on a worker isolate through `LuminaGarmentCache` (one fit per garment, source, reference body and target body content; the same body again comes from the cache). When the body slot changes, every garment slot following it is fitted to the new body and the body's mask is recomputed. A garment that simulates as cloth becomes a Skinned Cloth worn on the body, with its Cloth Settings. The fitted mesh keeps one section per source section and is drawn with the source mesh asset's slot materials (`LuminaStaticMeshComponent.slotMaterialSource`), so a garment made from an imported, textured mesh looks the same on every body.

A Blueprint's slot component can hold a Garment asset directly: its Skeletal Mesh Asset picker in the Blueprint editor offers Garment assets. When the Blueprint is built, `luminaRegisterBlueprintSlots` calls `LuminaCharacterSlots.applyConstructed()`, which runs in the background (`ready` completes when it is done):
- the load of a slot component whose mesh is a `.lmas` is held (`LuminaStaticMeshComponent.holdLoadUntil`) until the asset is read, so a Garment `.lmas` is never loaded as a mesh;
- each Garment asset is fitted to the body of the slot it follows;
- every body under a non-empty slot that masks it gets its mask.
Masks are cached by the content of the body and its garments, so the same character built again (a preview rebuilt after an edit) reuses its mask.

The fit (`LuminaGarmentFitter`, lumina_core, pure Dart):

Only the bodies' skin counts (`LuminaSkinnedMeshData.skin()` / `isSkin`): a primitive is not skin when its node, mesh or material name names a groom, eye, tooth and the like (`notSkinNames`: groom, hair, brow, lash, beard, eye, teeth, tongue, saliva, cartilage, …) or when it is drawn with an alpha-masked or blended material while the body has opaque skin (hair cards; a body whose every material is masked is judged by names only). A merged MetaHuman export keeps its head and body parts, nipples included, as skin and leaves out the grooms, eyes, eyelashes, teeth and cartilage. On its own reference body (the same skin) a garment stays where it was placed: no deformation, no re-placement and no cover pass, only vertices inside the skin are pushed out to it (and the cloth settle runs when asked for).

1. The garment's source mesh, refined until its mean edge is at most 2.5 cm (`LuminaSkinnedMeshData.refined`), at its placement on the reference body.
2. A smooth deformation from the reference body to the target: bodies that correspond vertex for vertex (the same mesh layout, or the same UV layout — MetaHuman bodies whose exports split their seams differently; mirrored UVs resolved by the nearest position in each body's normalised bounds) through an RBF field (`LuminaRbfField`, `r³` with an affine part) over 360 farthest-point body vertices; other bodies through the skeleton: each garment vertex follows the reference body's skinning from its rest pose to the target's (joints matched by name).
3. Within 4 cm of the skin a vertex keeps its distance to it (the same triangle and barycentre on a same-topology target, else the nearest target point, along the surface normal), blended out by 10 cm.
4. Push-out: a vertex inside the target body or closer than the garment's thickness moves out along the surface normal; the push is smoothed over the garment and applied again.
5. Optional cloth settle (the garment's `settleSteps`, 0–240): that many 1/60 s steps of gravity with position-based edge constraints at their fitted lengths (16 iterations a step) and the body pushed out after each step; vertices touching the body are held. It runs inside the fit on the worker isolate, so it is cached with it.
6. Cover: every vertex of the target body, every sub-mesh included (a MetaHuman's separate nipple mesh, small bumps), that the garment passes within 3 cm of and that stands in front of the garment surface — or closer than the thickness behind it — lifts the garment triangle over it along its own normal by what is missing (each corner by its barycentric share), the lift spread to the neighbours, then a local push-out; up to ten rounds, until nothing is lifted. This catches the bumps that poke through between the garment's vertices although every vertex clears the skin.
7. Skin weights from the nearest target-body surface point (its vertices' weights by barycentre), smoothed over the garment three times, the four strongest normalised.

`LuminaGarmentGlbWriter` writes the result as a skinned GLB over the target body's nodes and joints with the source's materials, served to the slot's component under a `garment:<slot>#<digest>` key. `LuminaGarmentFitReport` gives the largest and mean depth inside the body (cm), the landmark error on the target, whether the correspondence was dense, the vertices pushed, the largest distance a body point stands in front of the garment where it covers it (`maxPokeThrough`, every sub-mesh) and the time. Measured with the T-shirt of `test-assets/Props/Clothes Line/` landmarked on the mannequin Manny: on Quinn nothing inside and nothing poking through (0.0 cm each), landmark errors 0.4–0.9 cm, about 5 s for the refined shirt; on two MetaHuman bodies with separate nipple meshes both 0.0 cm as well.

The push-out holds at the rest pose; poke-through while animating is hidden by the body mask.

## Blueprint nodes (*Character|Slots*)

| Node | Pins |
| :--- | :--- |
| **Set Slot Mesh** | `slot`, `mesh` (asset path; '' clears) → true when the owner has that slot; the mesh loads in the background. |
| **Clear Slot** | `slot` → true when the owner has that slot. |
| **Fit Garment** | `slot`, `garment` (a Garment `.lmas`) → true when the owner has that slot; the garment is fitted to the slot's body in the background. |
| **Get Slot Mesh** | `slot` → the mesh in it ('' when empty or unknown). |
| **Get Slots** | → the owner's slot names. |

Every slot node has a **Target** pin (an actor): the nodes act on that actor's slots, or on the actor running the graph when Target is not connected. The VM and generated Dart give the same results (`blueprint_codegen_parity_test.dart`).
