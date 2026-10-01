# Meshes and materials: import, material assets, overrides, slots

## Meshes

- `import_asset` (absolute `path`; GLB / glTF / FBX / OBJ / Collada `.dae` / 3DS / PLY / DirectX `.x` / STL) makes a
  static mesh `.lmas` (`contents/meshes/static/`)
  or a skeletal one (`contents/meshes/skeletal/`), and extracts the file's materials and textures beside it
  (`contents/materials/<Mesh>/`, `contents/textures/<Mesh>/`). The result lists what was written.
- An imported material keeps the glTF `doubleSided` (`doubleSided : true`), `alphaMode` `MASK` (`blending : masked`,
  `maskThreshold` = `alphaCutoff`) and `BLEND` (`blending : fade`, colour premultiplied by its alpha) in its `.mat`
  header, so foliage cards, planes and glass draw both faces / cut out / see-through once compiled. Materials
  imported by an older editor lack these keys: import the model again (or `set_material_settings`).
- Place: `spawn_actor_from_asset` with the mesh `asset`; in a Blueprint: a `LuminaStaticMeshComponent` with
  `staticMeshAsset` = the mesh path (`set_blueprint_component_property`); swap at run time with `set_static_mesh`.
- Inspect: `get_static_mesh` (sections, `material_slots`, LODs, collision), `set_static_mesh_collision`.
- For simple shapes use a `Primitive` actor (box / plane / sphere / cylinder with `colorHex`) instead of importing.
  Shapes carry UVs and tangents, so a textured material assigned to one draws its texture: the whole image on
  each box face and on the plane, wrapped once around a sphere or a cylinder, a disc on the cylinder caps.

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
- OBJ import reads the `.mtl` its `mtllib` names and the textures that MTL references, from next to the OBJ:
  `Kd` colour, `d` / `Tr` transparency (`blending : fade`), `map_Kd`, `map_Bump` / `bump` / `norm` (normal map),
  map_d (cut-out → `masked`, else `fade`) and `map_Ks`. Keep the `.mtl` and its textures beside the OBJ (or pick
  the textures' folder as Textures Folder); a missing one is named in the Output Log and the import goes on without it.
- Collada, 3DS, PLY and DirectX files are converted from where they are, so the textures they reference (relative
  paths, bare names) are found and embedded like an FBX's: next to the file, in its `Textures/` folders or the
  Textures Folder. Folder and file names match in any case, also on Linux (`Maps/wood.png` finds `maps/wood.png`).
  A missing texture is named once in the Output Log; a file Assimp cannot read fails the import and writes nothing.
- Every mesh carries glTF texture coordinates (v = 0 at the image top): glTF imports as they are, FBX / OBJ / Collada /
  3DS / PLY / X converted to them, basic shapes generated that way. Imported materials declare `flipUV : false` so
  they sample them unchanged. Models imported before 2026-10-01 (FBX / OBJ / Collada / 3DS / PLY / X meshes, and any
  imported material compiled from a source without `flipUV : false`) draw their textures upside down: import them
  again; nothing migrates them.
- A level actor's `material` that is not compiled (or not found) is not drawn: the mesh keeps its own and the
  Output Log (and the `set_actor_property` reply) says why.
- The textures a material's samplers name (an imported material's `baseColorMap`, `normalMap`, … or a texture set
  with `set_material_texture`) are drawn wherever the material is assigned: viewport, Play, built game. A texture
  that cannot be read is logged as a warning (in the level viewport: the Output Log) and its sampler stays unbound
  (it samples black). Saving a texture (Texture editor Save / Reimport, `set_texture_settings` + `save_texture`,
  `reimport_texture`) redraws every level actor whose material samples it, and the Blueprint editor's 3D Viewport,
  without reassigning; Play loads it fresh.
- Blueprint: Create Dynamic Material Instance → Set Texture Parameter Value (`parameter_name` = the sampler, `value`
  = a texture asset path `contents/textures/…/T_X.lmas`, or an image file) binds it with the texture's settings, as
  the material's own textures are bound; a texture that cannot be read is logged once and binds nothing.
  At BeginPlay the component's Material Override is usually still loading: Create Dynamic Material Instance then
  hands out a pending instance, made once the material has loaded, with every Set … Parameter Value applied in order.
- Several colours of one mesh: `duplicate_asset` the material, change `baseColor`, `compile_material` with
  `save: true`, assign per component (`materialOverride`) or per duplicated mesh (slots).
- Glow: a material's `emissive` (see `filament-materials`), not a light.

## Checking

`start_pie`, play 1.5 s, screenshot. A mesh that stays white / grey in Play: was the material compiled with
`save: true`, is the path right (`contents/materials/…/M_X.lmas`), is it a skeletal mesh override?
