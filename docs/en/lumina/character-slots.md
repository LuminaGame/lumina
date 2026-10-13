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

## Blueprint nodes (*Character|Slots*)

| Node | Pins |
| :--- | :--- |
| **Set Slot Mesh** | `slot`, `mesh` (asset path; '' clears) → true when the owner has that slot; the mesh loads in the background. |
| **Clear Slot** | `slot` → true when the owner has that slot. |
| **Get Slot Mesh** | `slot` → the mesh in it ('' when empty or unknown). |
| **Get Slots** | → the owner's slot names. |

The nodes act on the actor running the graph. The VM and generated Dart give the same results (`blueprint_codegen_parity_test.dart`).
