# Levels, actors, components, transforms

## Units and axes

- 1 unit = **1 cm** (gravity 980 cm/s²), angles in **degrees**, **Z up**. glTF files are in metres; the importer
  converts them.
- A transform is `location [x, y, z]`, `rotation [x, y, z]`, `scale [x, y, z]`, as the Details panel shows it.
- **Rotation** `[x, y, z]` = degrees about the X, Y and Z axes, applied **yaw (about Z) first, then about X, then
  about Y**. Index 2 is **yaw**. Index 0 turns about X, the right axis (pitch); index 1 about Y, the forward axis
  (roll). Some tool descriptions name the three differently; the axes are what count.
- **Forward**: at rotation 0 an actor faces **+Y**; right is +X, up is +Z.
  - yaw 0 → faces +Y, yaw 90 → +X, yaw -90 → -X, yaw 180 → -Y.
  - a positive x rotation (pitch) of an actor or component tilts its forward down (x = 30: forward points 30° below
    the horizon).
- Scale 1 is the asset's own size; a `Primitive` shape's size is its component's `sizeX` / `sizeY` / `sizeZ`
  times the actor scale.
- A mesh keeps the orientation it was modelled with: if a glTF character faces the wrong way, turn the mesh (its
  component's yaw), not the actor.

## Levels

- A level is `contents/levels/<Name>.lmas`; its actors, environment and Level Blueprint are in it. `open_level`,
  `new_level` (from `list_level_templates`), `save_level` (writes the file and regenerates the level's Dart).
- Project Settings ▸ Maps & Modes names the startup and game levels (see `gameplay-framework`).

## Actors

- `list_actor_types` is the live catalog. Common types: `Primitive` (a box / sphere / cylinder shape with
  `colorHex`), `StaticMesh`, `SkeletalMesh`, `DirectionalLight`, `PointLight`, `SpotLight`, `PlayerStart`, `Pawn`,
  `Camera`, `Environment` (sky and atmosphere, one per level), `ExponentialHeightFog`, `PostProcessVolume`,
  `NavMeshBoundsVolume`.
- `spawn_actor` with `type`, `name`, `location`, `rotation`, `scale`, `parent_id`. `spawn_actor_from_asset` with
  `asset`: a mesh `.lmas` becomes a Mesh actor, a Blueprint `.lmas` an instance of that class.
- `set_actor_transform` (absolute values), `set_actor_property` (`mobility` `Static` | `Stationary` | `Movable`,
  `visible`, `locked`, lights' `light_intensity` / `light_color` / `cast_shadows`, or a component property as
  `"<component id or type>.<property>"`, e.g. `LuminaProceduralMeshComponent.colorHex`), `rename_actor`,
  `duplicate_actor`, `delete_actor`.
- Read: `list_actors`, `get_actor` (components and their properties), `get_selection`.
- Hierarchy: `attach_actors` keeps only the world location (the child's location becomes relative; rotation and
  scale are not composed), `detach_actors`; Outliner folders: `create_folder`, `move_to_folder`.
- Components on a level actor: `list_component_types`, `add_actor_component`, `remove_actor_component`,
  `set_actor_collision`, `set_actor_physics`. Several actors at once: `set_actors_transform`,
  `set_actors_component_property`.
- A Blueprint instance takes its components from the Blueprint class: change them in the Blueprint
  (`blueprints`), not on the placed actor.

## Order that works

1. `project_info`, `list_actors` (what is there), `list_actor_types`.
2. Spawn, then set transform / properties; check with `get_actor` or a `viewport_screenshot` after `set_camera`
   (`target`, `distance`, `yaw`, `pitch`) or `focus_actor`.
3. `save_level` when a step is done. Everything is undoable (`undo`), one step per call.
