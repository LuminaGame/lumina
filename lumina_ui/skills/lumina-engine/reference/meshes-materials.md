# Meshes and materials: import, material assets, overrides, slots

## Meshes

- `import_asset` (absolute `path`; GLB / glTF / FBX / OBJ) makes a static mesh `.lmas` (`contents/meshes/static/`)
  or a skeletal one (`contents/meshes/skeletal/`), and extracts the file's materials and textures beside it
  (`contents/materials/<Mesh>/`, `contents/textures/<Mesh>/`). The result lists what was written.
- An imported material keeps the glTF `doubleSided` (`doubleSided : true`), `alphaMode` `MASK` (`blending : masked`,
  `maskThreshold` = `alphaCutoff`) and `BLEND` (`blending : fade`, colour premultiplied by its alpha) in its `.mat`
  header, so foliage cards, planes and glass draw both faces / cut out / see-through once compiled. Materials
  imported by an older editor lack these keys: import the model again (or `set_material_settings`).
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

## Putting a material on a mesh (each draws in Play and in a built game)

| Where | How | Affects |
|---|---|---|
| The mesh's slot | `set_static_mesh_material_slot` (`asset` the mesh, `slot` index, `material`), then `save_static_mesh` | every use of that mesh |
| A Blueprint's mesh component | `set_blueprint_component_property` `property` `materialOverride`, `value` the material path | that component, every section |
| A placed level mesh or basic shape | `set_actor_property` `property` `material`, `value` the material path (or the Details Material field); `null` clears it | that actor, every section: viewport, Play and the built game |
| At run time | node `set_material` (`element_index`, `material` = the material path) on a mesh component | that component, one section |

- A skeletal mesh component's `materialOverride` is not drawn yet; use its mesh's slots.
- OBJ import ignores the MTL file (colour `Kd`, dissolve `d`): the material comes out opaque grey; set its
  `baseColor` / `blending` after import, or convert the OBJ to glTF first.
- A level actor's `material` that is not compiled (or not found) is not drawn: the mesh keeps its own and the
  Output Log (and the `set_actor_property` reply) says why.
- Several colours of one mesh: `duplicate_asset` the material, change `baseColor`, `compile_material` with
  `save: true`, assign per component (`materialOverride`) or per duplicated mesh (slots).
- Glow: a material's `emissive` (see `filament-materials`), not a light.

## Checking

`start_pie`, play 1.5 s, screenshot. A mesh that stays white / grey in Play: was the material compiled with
`save: true`, is the path right (`contents/materials/…/M_X.lmas`), is it a skeletal mesh override?
