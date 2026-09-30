# Meshes and materials: import, material assets, overrides, slots

## Meshes

- `import_asset` (absolute `path`; GLB / glTF / FBX / OBJ) makes a static mesh `.lmas` (`contents/meshes/static/`)
  or a skeletal one (`contents/meshes/skeletal/`), and extracts the file's materials and textures beside it
  (`contents/materials/<Mesh>/`, `contents/textures/<Mesh>/`). The result lists what was written.
- Place: `spawn_actor_from_asset` with the mesh `asset`; in a Blueprint: a `LuminaStaticMeshComponent` with
  `staticMeshAsset` = the mesh path (`set_blueprint_component_property`); swap at run time with `set_static_mesh`.
- Inspect: `get_static_mesh` (sections, `material_slots`, LODs, collision), `set_static_mesh_collision`.
- For simple shapes use a `Primitive` actor (box / sphere / cylinder with `colorHex`) instead of importing.

## Material assets

- A material is a `filamat` `.lmas`: the Filament `.mat` source, its compiled package and the saved parameter
  values. There are no material instance assets.
- `create_asset` with `type` `filamat` writes the editor's default material: lit, with parameters `baseColor`
  (float4, green by default), `roughness`, `metallic` (0.8 by default: change it for non-metals),
  `normalStrength` and an `albedoMap` sampler.
- Change values: `set_material_parameter` (`asset`, `name`, `value`: a number or `[r, g, b, a]`, linear 0..1),
  `set_material_texture` (`parameter` sampler, `texture` asset), `set_material_settings` (`shading_model`,
  `blending`, `double_sided`). Graph editing: `get_material_graph`, `add_material_node`, `connect_material_pins`.
- Write the source yourself: see `filament-materials` (`get_material_source`, `set_material_source`).
- **`compile_material` with `save: true`** writes the `.lmas`; without `save` nothing reaches disk and Play keeps
  the old material. Check `get_material_issues`.

## Putting a material on a mesh (all three draw in Play and in a built game)

| Where | How | Affects |
|---|---|---|
| The mesh's slot | `set_static_mesh_material_slot` (`asset` the mesh, `slot` index, `material`), then `save_static_mesh` | every use of that mesh |
| A Blueprint's mesh component | `set_blueprint_component_property` `property` `materialOverride`, `value` the material path | that component, every section |
| At run time | node `set_material` (`element_index`, `material` = the material path) on a mesh component | that component, one section |

- A skeletal mesh component's `materialOverride` is not drawn yet; use its mesh's slots.
- OBJ import ignores the MTL colour (`Kd`): the material comes out grey; set its `baseColor` after import.
- A level Mesh actor's `material` property (`set_actor_property`, the Details material field) is stored in the
  level but not drawn in Play: use the mesh slot, or place a Blueprint whose component has a `materialOverride`.
- Several colours of one mesh: `duplicate_asset` the material, change `baseColor`, `compile_material` with
  `save: true`, assign per component (`materialOverride`) or per duplicated mesh (slots).
- Glow: a material's `emissive` (see `filament-materials`), not a light.

## Checking

`start_pie`, play 1.5 s, screenshot. A mesh that stays white / grey in Play: was the material compiled with
`save: true`, is the path right (`contents/materials/…/M_X.lmas`), is it a skeletal mesh override?
