# lumina-mcp — workflows

Each block is a `tools/call` sequence (`name` → `arguments`). Ids and paths come from the previous call's result; never guess them.

## 0. Connect (once per session)

```
initialize {protocolVersion:"2025-06-18", capabilities:{}, clientInfo:{name:"…",version:"…"}}   → keep Mcp-Session-Id
notifications/initialized
tools/call project_info {}                                   → units, level, actor_count, pie
```

## 1. Place and arrange actors

```
list_actor_types {}
spawn_actor {type:"Primitive", name:"Crate", location:[200,0,50], scale:[1,1,1]}
spawn_actor {type:"PointLight", name:"Lamp", location:[200,0,250]}
set_actor_property {id:"act_5", property:"light_intensity", value:40000}
set_actor_property {id:"act_5", property:"light_color", value:"#FFD9A0"}
set_actor_transform {id:"act_4", rotation:[0,0,30]}            (one undo step per vector)
duplicate_actor {id:"act_4"}                                   → new id, "Crate_Copy"
set_actor_transform {id:"<copy id>", location:[350,0,50]}
focus_actor {id:"act_4"} ; viewport_screenshot {max_width:1280}  → look at the result
undo {}                                                        (revert the last step if it is wrong)
save_level {}
```

## 2. Import a mesh and give it a material

```
import_asset {path:"/path/to/test-assets/Props/Barrels/fuel_barrel_red.glb"}
   → imported[…]: contents/meshes/… fuel_barrel_red.lmas (+ extracted materials/textures)
spawn_actor_from_asset {asset:"contents/meshes/static/fuel_barrel_red.lmas", location:[0,150,0]}
create_asset {type:"filamat", name:"M_Rust"}                  → contents/materials/M_Rust.lmas (default source)
get_material_source {asset:"M_Rust"}                           (opens the Material editor tab)
set_material_source {asset:"M_Rust", source:"material { name : \"M_Rust\", shadingModel : lit, parameters : [ { type : float, name : roughness, default : 0.8 } ], }\n\nfragment {\n  void material(inout MaterialInputs material) {\n    prepareMaterial(material);\n    material.baseColor = vec4(0.45, 0.2, 0.1, 1.0);\n    material.roughness = materialParams.roughness;\n  }\n}\n"}
compile_material {asset:"M_Rust", save:true}                   → ok / issues[{line,severity,message}]
set_actor_property {id:"<barrel id>", property:"material", value:"contents/materials/M_Rust.lmas"}
select_tab {index:0} ; viewport_screenshot {}
```

A parameter used in the fragment must be declared in the header (`materialParams.<name>`; samplers as `materialParams_<name>` with `requires : [ uv0 ]`). Compile errors name the line relative to the fragment body.

## 3. Author and compile a Blueprint

```
create_asset {type:"actor", name:"BP_Door", parent_class:"LuminaActor"}
get_blueprint {asset:"contents/blueprints/BP_Door.lmas"}      (opens the Blueprint tab; note node ids)
list_blueprint_nodes {query:"print"}                           → id "print_string", inputs exec_in / in_string, output exec_out
add_blueprint_node {asset:"BP_Door", node:"event_beginplay", x:60, y:80}      (skip if get_blueprint already lists one)
add_blueprint_node {asset:"BP_Door", node:"print_string", x:360, y:90}
connect_blueprint_pins {asset:"BP_Door", from_node:"<beginplay id>", from_pin:"exec_out", to_node:"<print id>", to_pin:"exec_in"}
set_blueprint_pin_literal {asset:"BP_Door", node:"<print id>", pin:"in_string", value:"door ready"}
compile_blueprint {asset:"BP_Door", save:true}                 → status, diagnostics, generated_file lib/actors/BP_Door.dart
spawn_actor_from_asset {asset:"contents/blueprints/BP_Door.lmas", location:[0,0,0]}
```

Pins carry types: exec↔exec only, data↔same type (`float` never into `exec_in`); the error names both pins and types. Variables: `variable_get` / `variable_set` with `literals:{variable:"<name>"}`; input events: `event_enhanced_input_action` with `literals:{action:"IA_Jump"}`.

## 3a. A door Blueprint with components, a function, a variable and a timeline

```
create_asset {type:"actor", name:"BP_Door", parent_class:"LuminaActor"}
list_component_types {context:"blueprint"}                     → which types are available (and why not)
add_blueprint_component {asset:"BP_Door", type:"LuminaStaticMeshComponent"}      → component.id "<mesh>"
set_blueprint_component_property {asset:"BP_Door", component:"<mesh>", property:"staticMeshAsset", value:"contents/meshes/static/<door>.lmas"}
rename_blueprint_component {asset:"BP_Door", component:"<mesh>", name:"DoorMesh"}
add_blueprint_component {asset:"BP_Door", type:"LuminaBoxComponent", parent:"<mesh>"}   → "<box>"
set_blueprint_component_collision {asset:"BP_Door", component:"<box>", preset:"Trigger", generate_overlap_events:true}
add_blueprint_variable {asset:"BP_Door", name:"OpenAngle", type:"Float", default:90}   → variable.name (made unique)
add_blueprint_function {asset:"BP_Door", name:"OpenDoor"}      → graph "function:OpenDoor"
set_blueprint_function_signature {asset:"BP_Door", function:"OpenDoor", inputs:[{name:"Angle", type:"Float"}]}
get_blueprint {asset:"BP_Door", graph:"function:OpenDoor"}     → the entry node's id and its Angle pin
add_blueprint_node {asset:"BP_Door", graph:"function:OpenDoor", node:"print_string"}
connect_blueprint_pins {asset:"BP_Door", graph:"function:OpenDoor", from_node:"<entry>", from_pin:"exec_out", to_node:"<print>", to_pin:"exec_in"}
add_blueprint_node {asset:"BP_Door", node:"timeline"}          → "<tl>" (event graph)
set_blueprint_timeline {asset:"BP_Door", node:"<tl>", length:2, auto_play:true}
add_timeline_track {asset:"BP_Door", node:"<tl>", name:"Alpha", type:"float"}
set_timeline_keys {asset:"BP_Door", node:"<tl>", track:"Alpha", keys:[{time:0, value:[0]}, {time:2, value:[1], interp:"cubic"}]}
compile_blueprint {asset:"BP_Door", save:true}                 → lib/actors/BP_Door.dart has OpenDoor(…)
spawn_actor_from_asset {asset:"contents/blueprints/BP_Door.lmas"}
set_actor_collision {actor_id:"<placed>", component:"<box>", preset:"OverlapAll"}   (this instance only: an override)
```

Each Blueprint edit is one step on the Blueprint tab's own stack (`undo {asset:"BP_Door"}`); the level's stack is untouched. A signature edit returns `removed_wires` — reconnect what it dropped. Deleting a variable or function returns the `removed_nodes` that used it.

## 3b. Wire the Level Blueprint

```
get_blueprint {asset:"level"}                                  (opens "<Level> (Level Blueprint)"; note an existing event_beginplay)
add_blueprint_node {asset:"level", node:"event_beginplay", x:60, y:80}        (skip if listed)
add_blueprint_node {asset:"level", node:"print_string", literals:{in_string:"Level ready"}}
connect_blueprint_pins {asset:"level", from_node:"<beginplay>", from_pin:"exec_out", to_node:"<print>", to_pin:"exec_in"}
compile_blueprint {asset:"level", save:true}                   → generated_code (the level script); the graph is saved into the level .lmas
save_level {}                                                  → writes lib/levels/<Level>.dart
```

`asset:"level"` is always the active level at call time (switching levels closes the old Level Blueprint tab). Component, class-default and parent-class tools refuse it.

## 4. Run Play-In-Editor and read the log

```
start_pie {}            → tool error listing Blueprint blockers when a compile fails
pie_status {}           → playing, pawn_class, player_location (cm, Z up)
read_output_log {contains:"PIE"}
read_output_log {level:"error", tail:50}
pause_pie {} ; step_pie {} ; resume_pie {}
stop_pie {}             → the level, selection and camera are restored
```

While Play runs every mutating level tool answers `isError` "… Call stop_pie first."; read tools work. Poll the log with `since_index: <previous next_index> - 1`.

## 5. Take a screenshot

```
select_tab {index:0}                                           (the level tab must be showing)
set_camera {yaw:-35, pitch:25, distance:600, target:[200,0,50]}   or   focus_actor {id:"act_4"}   or   frame_level {}
viewport_screenshot {max_width:1280}                           → image/png content + "<w>×<h> PNG of the viewport. Camera: …"
viewport_screenshot {target:"editor", max_width:1600}          → the whole window (panels, tabs, Output Log)
```

`set_camera {mode:"Top", view_mode:"Wireframe"}` gives a plan view; return with `{mode:"Perspective", view_mode:"Lit"}`.

## 5a. Change game code

```
fs_search {pattern:"@BlueprintCallable", glob:"lib/**/*.dart"}   → where the project's Blueprint functions live
fs_read {path:"lib/agent/barrel_math.dart"}                     → content + sha256
fs_edit {path:"lib/agent/barrel_math.dart", old_string:"…", new_string:"…"}   → diff + snapshot_id
   (or fs_write {path, content, expected_sha256:<sha256 from fs_read>} for a new / whole file)
dart_analyze {paths:["lib/agent"]}                               → ok, diagnostics[{severity, code, file, line, message}]
   … fix every error with fs_edit, analyze again until ok: true …
run_codegen {}                                                   → lib/main.dart + lib/levels/<level>.dart regenerated
compile_blueprint {asset:"<each stale_blueprints entry>", save:true}
start_pie {}  (or ask the user for Play Standalone: project Dart functions run only there)
```

An `@BlueprintCallable` / `@BlueprintPure` function written under `lib/` reaches the Blueprint palette within seconds (the editor watches `lib/`). Don't hand-edit generated files (`generated: true`); `run_codegen` / `compile_blueprint` overwrite them. To undo a file change: `fs_history {path}` → `fs_restore {snapshot_id}` (a restore is itself snapshotted, so it can be undone too).

## 5b. Block out a new level

```
list_level_templates {}                                           → empty / default / open_world
new_level {name:"L_Yard", template:"default", if_dirty:"save"}    → contents/levels/L_Yard.lmas, now open (undo deletes it)
spawn_actor_from_asset {asset:"<mesh>.lmas", location:[…]}        (once per prop; list_assets type "filamesh")
create_folder {name:"Props", wrap_ids:[<prop ids>]}               → folder_id (the Outliner expands it)
attach_actors {ids:[<banana>], parent_id:<card>}                  → keeps the world location
set_actors_transform {ids:[<prop ids>], scale:[2,2,2]}            → one undo step; locked actors listed in skipped
solo_actor {id:<card>}  …  clear_solo {}                          → check one prop alone, then restore
set_world_partition {enabled:true}; add_data_layer {name:"Interiors"}
set_level_environment {time_of_day:18.5, fog_enabled:true, fog_density:0.03}   → the Environment Lighting tab opens
spawn_actor {type:"NavMeshBoundsVolume"}; build_navigation {}      → walkable_cells > 0
set_viewport_snapping {translate_enabled:true, translate_step:50}; set_show_flags {flags:{Collision:true}}
save_level {}; open_level {level:"L_Main"}                         → refused while unsaved unless if_dirty says what to do
```

`get_level_settings {}` reads the partition, layers, environment and navigation back; `get_multi_edit {ids}` shows what the multi-select Details panel shows. `select_tab {index:0}` returns to the level after the Environment Lighting / Navigation tabs open.

## 5c. Play-test a change

```
start_pie {}                                                       → Play starts (Blueprint blockers are a tool error)
pie_advance {frames:30}                                            → the pawn spawns and lands; paused afterwards
pie_key {key:"W", action:"down"}                                   → held until "up"
pie_advance {frames:60, actors:true}                               → player_location moved; actors[] with location / velocity
pie_key {key:"W", action:"up"}
pie_action {action:"IA_Jump"} ; pie_advance {frames:10, screenshot:true}   → mid-jump PNG (Z rose)
pie_action {action:"IA_Move", value:[1,0], hold_frames:30}         → strafes right (presses D, the project's binding)
pie_axis {key:"MouseX", value:40} ; pie_advance {frames:1}         → the view turns
pie_play_for {ms:2000, screenshot:true}                            → real-time play in the viewport, then paused
pie_get_actors {class_contains:"Character"}                        → the possessed pawn's transform
pie_click {x:640, y:360} ; pie_type_text {text:"hello", submit:true}   → UMG buttons and text fields
stop_pie {}                                                        → held keys released, the level restored
```

The same walk-and-jump check as **one call** (Play started if needed, left paused; a small model needs no round trips):

```
pie_sequence {screenshot_max_width:1280, steps:[
  {play_ms:1500, label:"land"},                                     → real time: the pawn lands, the viewport loads its meshes
  {screenshot:true, label:"before walking"},
  {key:"W", hold_ms:1000, label:"walk"},                            → W held for 60 stepped frames, then released
  {action:"IA_Jump"}, {advance_frames:12},
  {screenshot:true, label:"after walking and jumping"},
  {expect:{player_moved:true, min_distance_cm:200}}]}
→ steps[] (player_location and new log lines after each), two captioned PNGs, final_status; the first failing step ends it
```

Frame-exact checks use `pie_advance` (deterministic, works while paused); `pie_play_for` needs the level viewport showing. To change what `IA_Jump` presses, rebind it (`edit_project_input`, `apply_project_settings`) and `start_pie` again. The standalone game (`play_standalone`) is a separate process: no input or actor readback there.

## 5d. Change a setting, cook and poll

```
set_project_settings {changes:{"physics.gravity_z":-490}}          → staged; the Project Settings tab shows it (dirty)
apply_project_settings {}                                          → {saved:true, manifest_path}
set_build_settings {targets:["linux"], configuration:"Shipping"}   → cook_arguments.linux has --release
start_build {kind:"build_all"} ; wait_job {id}                     → per-step statuses
start_build {kind:"cook_and_package"}                              → {job_id} at once
get_job {id, since_log_index:0}  … poll with next_log_index …      → stage, progress, the flutter build log
wait_job {id, timeout_ms:25000}  … repeat while timed_out …        → succeeded: targets.linux.package_dir
cancel_job {id}                                                    → kills flutter build (cancelled)
```

`get_build_status {}` also shows a build the user started from the Build menu. A failed Validate Assets skips the cook unless `continue_on_validation_failure: true`.

## 5e. Organise imported content

```
import_asset_folder {path:"/abs/Props/Barrels", target_folder:"contents/Props", dry_run:true}   → the plan: imports[{source,target}], unsupported
import_asset_folder {path:"/abs/Props/Barrels", target_folder:"contents/Props"}                → {job_id}; wait_job {id} → {imported, failed, skipped}
create_content_folder {parent:"contents/Props", name:"Hero"}                                  → contents/Props/Hero
move_asset {asset:"contents/Props/fuel_barrel_red.lmas", folder:"contents/Props/Hero"}        → path; placed actors follow
create_collection {name:"Hero Props"} ; add_to_collection {collection:"Hero Props", assets:[…]}
regenerate_thumbnails {assets:[…]}
```

Call the dry run first on a folder you have not seen. `conflict_policy: "rename"` imports a second copy as `name_1`; `"overwrite"` re-imports in place (ids kept). A deleted folder (`delete_content_folder`) is one `undo` away.

## 5f. Install from the Marketplace

```
marketplace_status {}                                   → signed_in? — if false, ask the user to sign in in Window → Marketplace
marketplace_search {query:"Barrel"}                     → results[{id, title, install_kind, …}]
marketplace_get_listing {id}                            → licenses, can_install, install_label
marketplace_install {id, folder:"contents/Marketplace"} → {job_id}; wait_job {id} → {installed_to, license_file, …}
marketplace_list_installed {}
```

A plugin listing installs disabled: `set_plugin_enabled {name, enabled:true}`; a code plugin answers `restart_required: true` — tell the user to click Restart Editor, never try to restart. Uninstalling is the user's (Window → Marketplace → Installed, or the Plugin Manager's Remove); an agent asked to remove a plugin calls `remove_plugin {name, dry_run: true}`, shows the user what would be deleted, and removes it only once they agree.

## 5g. Commit my changes

```
source_control_status {}                                         → is_repo? (false → source_control_init {})
source_control_status {summaries:true}                           → changes[{path, state, added, removed}]
source_control_commit {all:true, message:"Agent: add barrels"}   → {hash}   (or paths:[…] for a subset)
source_control_history {path:"contents/Props/fuel_barrel_red.lmas"}
```

An identity error → ask the user for a name and e-mail, then `source_control_set_identity` and commit again. `source_control_revert` throws that file's edits away for good — confirm with the user first.

## 5h. Lay out a HUD widget

```
create_asset {type:"widget", name:"WBP_Hud"}
get_widget_tree {asset:"WBP_Hud"}                                                       → root.id
add_widget {asset, type:"verticalBox", parent:"root", x:40, y:40, name:"StatsBox"}
add_widget {asset, type:"text", parent:"StatsBox", name:"HealthLabel", props:{text:"Health", fontSize:24}}
add_widget {asset, type:"progressBar", parent:"StatsBox", name:"HealthBar", props:{percent:0.75}}
set_widget_slot {asset, widget:"StatsBox", anchor_preset:"topLeft", size:[320,120]}
add_widget {asset, type:"button", parent:"root", name:"HealButton", x:40, y:200}
bind_widget_event {asset, widget:"HealButton", event:"OnClicked"}                        → node_id, exec_pin
add_blueprint_node {asset:"WBP_Hud", node:"print_string"} ; connect_blueprint_pins {…from_node:node_id, from_pin:"exec_out"…}
compile_widget {asset}                                                                  → ok, file_path (lib/widgets/WBP_Hud.dart)
asset_editor_screenshot {asset}                                                         → look at it
```

Props keys come from `list_widget_types` `default_props`; a texture goes in an Image's `texture` as a texture asset path. `compile_widget` fails (no Dart file) when a shadcn widget sits in a project on the `flutter` widget library.

## 5i. Author a material as nodes

```
create_asset {type:"filamat", name:"M_Crate"}
list_material_nodes {query:"texture"}
add_material_node {asset, node:"mat_texture_sample", x:-600, y:0, settings:{parameter:"Albedo"}}  → node.id
add_material_node {asset, node:"mat_vector_parameter", x:-600, y:200, settings:{name:"Tint"}}
add_material_node {asset, node:"mat_multiply", x:-300, y:80}
connect_material_pins {asset, from_node:<sample>, from_pin:"rgb", to_node:<multiply>, to_pin:"a"}   (and Tint.rgb → b)
connect_material_pins {asset, from_node:<multiply>, from_pin:"out", to_node:"material_output", to_pin:"base_color"}
set_material_texture {asset, parameter:"Albedo", texture:"contents/textures/…"}
compile_material {asset, save:true}
```

Check `sync.ahead` after each edit: true means a type error (see `diagnostics`), the source is stale and compile refuses — fix or `remove_material_wire`. `get_material_source` shows the generated `.mat`.

## 5j. Animate a mannequin, key a sequence, spray particles

```
create_asset {type:"animBlueprint", name:"Agent", target_mesh:"contents/meshes/skeletal/SKM_Superhero_Female.lmas"}  → path
get_anim_blueprint {asset}                                                              → clips, state_machine (a new ABP has Idle)
add_anim_variable {asset, name:"GroundSpeed", type:"float", default:0}
add_anim_state {asset, name:"Moving", x:400, y:120, pose:{kind:"clip", clip:<clips[i]>}}
add_anim_transition {asset, from:"Idle", to:"Moving", blend_duration:0.2}               → id, result_node
add_anim_graph_node {asset, graph:"transition:idle_to_moving", node:"variable_get", literals:{variable:"GroundSpeed"}}
add_anim_graph_node {asset, graph:…, node:"float_greater", literals:{b:10}} ; connect_anim_graph_pins … → result_node.can_enter
compile_anim_blueprint {asset, save:true}                                               → lib/anim/ABP_Agent.dart
anim_blueprint_preview {asset, overrides:{GroundSpeed:300}, frames:60}                  → preview_state "Moving"

create_asset {type:"sequencer", name:"SEQ_Flyby"}
add_sequencer_track {asset, actor:<list_actors id>, kind:"transform"}                  → track.id, 9 channels
add_sequencer_key {asset, track, channel:"Location.Z", frame:60, value:200, interpolation:"cubic"}
scrub_sequence {asset, frame:30} … stop_sequence {asset}                                (the level moves as a preview, then is restored)
render_sequence {asset, width:1280, height:720, output_name:"flyby", save_first:true}   → job_id ; wait_job {id}

create_asset {type:"particle", name:"PS_Sparks"} ; add_particle_emitter {asset, name:"Embers"}
set_particle_emitter {asset, emitter:"Embers", spawn_rate:120, lifetime:[0.5,1.5]} ; particle_preview {asset, action:"step", frames:30}
save_particle_system {asset} ; asset_editor_screenshot {asset}
```

Animation, Skeletal Mesh and Particle edits have no undo: not saving (the tab's Discard) is the revert.

## 5k. Shape a landscape, tune a mesh, a texture, a ragdoll, a sound and an enum

```
create_asset {type:"landscape", name:"LS_Valley", grid_resolution:257, world_size_cm:51200, max_height_cm:20000}
import_landscape_heightmap {asset, path:"C:/maps/valley257.png"}          (optional; 16-bit PNG, side n × 64 + 1)
sculpt_landscape {asset, strokes:[{points:[[0,0],[2000,0],[4000,0]], radius_cm:1500, strength:0.8},
                                  {points:[[4000,0],[4010,0]], tool:"flatten"}]}   → per-stroke touched range
add_foliage_layer {asset, mesh:"contents/meshes/static/fuel_barrel_red.lmas", rules:{density:80, slope_max_deg:30}}
paint_foliage {asset, layer:0, strokes:[{points:[[-9000,-11000],[9000,-11000]]}]}  → instances_placed
undo {asset}                                                             (reverts the last stroke only)
save_landscape {asset} ; asset_editor_screenshot {asset}

add_static_mesh_lod {asset} ; set_static_mesh_lod_group {asset, group:"Architecture"} ; set_static_mesh_collision {asset, shape:"convex"} ; save_static_mesh {asset}
set_texture_settings {asset, srgb:false, group:"Normalmap", compression:"ASTC"} ; save_texture {asset}
create_asset {type:"physicsAsset", name:"PHYS_Manny"} ; bind_physics_skeletal_mesh {asset, mesh}
add_physics_body {asset, bone:"pelvis", shape:"capsule"} ; add_physics_constraint {asset, bone_a:"pelvis", bone_b:"spine_01"} ; validate_physics_asset {asset} ; save_physics_asset {asset}
set_audio_settings {asset, attenuation_model:"linear", inner_radius_cm:200, falloff_distance_cm:800} ; probe_audio_attenuation {asset, distance_cm:600} → gain 0.5
create_asset {type:"actor", name:"E_Weather", blueprint_kind:"enum"} ; add_enum_value {asset, name:"Sunny"} ; save_enum {asset}
```

Static Mesh, Texture, Physics Asset and Sound edits have no undo: not saving is the revert. Landscape points are terrain-local cm, not level coordinates.

## 6. Recover from mistakes

- Wrong level edit → `undo {}` (or several); `undo_state {}` says what the next one reverts.
- Wrong Blueprint edit → `undo {asset:"<Blueprint>"}` (or `asset:"level"` for the Level Blueprint) — the Blueprint tab's own stack — or `remove_blueprint_node` / `remove_blueprint_wire`.
- Wrong material source → `set_material_source` again; nothing is on disk until `compile_material {save:true}`.
- Wrong widget or material graph edit → `undo {asset}` (the designer / the source) or `undo {asset, stack:"graph"}` (the widget's graph / the material's node graph).
- Wrong file change → `fs_history {path:"lib/…"}` then `fs_restore {snapshot_id}`; a deleted file comes back the same way (or `restore_asset` with its `trash_id`).
- `-32602` → fix the named argument (ids from `list_actors`, paths from `list_assets`, node ids from `get_blueprint`).
- `-32000` from the bridge / connection refused → the editor is not running with the server on; ask the user to open the project and check Tools → AI Agent Access (MCP).
