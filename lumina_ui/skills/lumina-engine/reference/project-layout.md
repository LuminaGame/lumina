# Project layout: .lmproject, contents/, .lmas assets, generated code

## Files

```
<Project>/
  <Project>.lmproject     the manifest (JSON): project_name, active_level, input, maps_and_modes, physics, packaging, …
  contents/               every asset, one .lmas file each
    levels/  meshes/static/  meshes/skeletal/  materials/  textures/  animations/  audio/
    blueprints/  widgets/  enums/  interfaces/  particles/  landscapes/  ui/
  lib/                    Dart generated from the assets (main.dart, levels/, actors/, widgets/) + your own code
  .lumina/                editor data: trash/ (deleted assets), plugins/<plugin>/ (plugin data, chats)
  Saved/SaveGames/        save slots written while playing in the editor
```

- An **`.lmas`** is one asset: the 4 bytes `LMAS` followed by JSON (`asset_id`, `name`, `type`, `metadata`,
  `references`, base64 `raw_payload`). Types: `level`, `filamesh` (static mesh), `filameshSk` (skeletal mesh),
  `filamat` (material), `texture`, `actor` (Blueprint class, Enumeration, Interface), `widget` (Widget Blueprint),
  `animation`, `animBlueprint`, `blendSpace`, `particle`, `audio`, `landscape`, `physicsAsset`, `sequencer`.
- Asset paths are **project-relative and `/`-separated**: `contents/blueprints/BP_Door.lmas`. Many tools also take
  a unique file name (`BP_Door`).

## Source of truth

- The `.lmas` files and the `.lmproject` are the truth. `lib/` is generated from them:
  - `save_level` writes the level `.lmas` and regenerates `lib/main.dart` and `lib/levels/<level>.dart`;
  - `compile_blueprint` writes `lib/actors/<snake_name>.dart` (`BP_Door` → `bp_door.dart`, class `BpDoor`) and
    the registry `lib/actors/actors.g.dart`; nothing is written while the Blueprint has errors;
  - `compile_widget` writes `lib/widgets/wbp_<name>.dart`.
- **Never** write an `.lmas` with the file tools (`fs_write`, `fs_edit`) and never hand-edit generated Dart: the
  next save or compile overwrites it (only the marked user-code regions in `lib/actors/` survive). Use the editor
  tools; they are undoable and keep the editor in sync.
- Play-In-Editor plays the editor's state (open, unsaved Blueprint documents included); a built game plays the
  generated Dart.

## Useful tools, in order

1. `project_info` (name, active level, units, dirty flag, Play state), `list_levels`, `list_assets`
   (filter by type or folder), `list_content_folders`.
2. Import: `import_asset` with an absolute `path` (GLB / glTF / FBX / OBJ meshes with their materials and
   textures, PNG / JPG / WebP / TGA textures, WAV / OGG audio). Use the paths the result returns: meshes are
   auto-organised into `contents/meshes/static/` (or `skeletal/`), extracted materials into
   `contents/materials/<Mesh>/`, textures into `contents/textures/<Mesh>/`, even when you pass `folder`.
   `import_asset_folder` imports a whole folder.
3. New assets: `create_asset` with `type` and `name` (`filamat` material, `actor` Blueprint with `parent_class`,
   `widget` Widget Blueprint, `actor` + `blueprint_kind` `enum` / `interface`); `open_asset_editor` opens its tab.
4. Organise: `move_asset` (references to the asset are rewritten), `rename_asset`, `duplicate_asset`,
   `delete_asset` (to `.lumina/trash`; `list_trash`, `restore_asset`).
5. Levels: `new_level`, `open_level`, `save_level`.
6. Code: `run_codegen` saves the open level and regenerates `lib/main.dart` and `lib/levels/` (as `save_level`);
   `dart_analyze` checks the project's Dart.
