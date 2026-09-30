---
name: lumina-mcp
description: Operate a running Lumina Studio editor through its built-in MCP server (Streamable HTTP on 127.0.0.1 + bearer token, or the stdio bridge). Use when an AI agent must place or arrange actors, import assets, edit and compile materials or Blueprints, run Play-In-Editor, read the Output Log, or screenshot the viewport of the editor the user has open — or when the user asks how to connect Claude Code (or another MCP client) to Lumina Studio.
---

# lumina-mcp — drive Lumina Studio through MCP

Lumina Studio (`lumina_ui`) runs a Model Context Protocol server **inside the editor process**. Everything a tool does goes through the editor's own view-model commands: it is visible live in the Outliner, Details and viewport, and every level mutation is one **Edit → Undo** step. Nothing here bypasses the UI.

Full argument shapes: `reference/tools.md`. Ready-made call sequences: `reference/workflows.md`.

## 1. Find or start the server

1. The user launches the editor (`cd lumina_ui && flutter run -d linux`) and opens a project. The server starts with the project when the setting is on (**default: on**).
2. **Tools → AI Agent Access (MCP)...** shows the status (`LISTENING` + URL), the switch, the connection file, the token (masked, reveal/regenerate) and the registration commands with Copy buttons.
3. The connection file is `~/.config/lumina/mcp_server.json` (or `$LUMINA_CONFIG_DIR/mcp_server.json`), mode 0600, written on start and deleted on stop:
   ```json
   {"version":1,"url":"http://127.0.0.1:7741/mcp","port":7741,"token":"<64 hex>","pid":12345,"project":"MyGame","projectDir":"/home/…/MyGame","startedAt":"…"}
   ```
   No file → no editor is running with the server on (or it predates the feature: **an editor started before commit d63e0f2 must be restarted**). A stale file from a crashed editor is overwritten by the next start; the bridge answers `-32000` for it.
4. Preferred port **7741**; when taken, an ephemeral port is used and the panel says so (the file always has the real one). One token per editor session — after a restart the HTTP registration must be re-added; the stdio bridge never needs re-registration.
5. Quick check from a shell: `dart lumina_ui/tool/mcp_handshake_check.dart` (add `--claude` to also test `claude mcp add` under a throwaway HOME).

## 2. Register the client

- **Claude Code, HTTP** (copy from the panel; token changes per session):
  `claude mcp add --transport http lumina http://127.0.0.1:7741/mcp --header "Authorization: Bearer <token>"`
- **Claude Code, stdio bridge** (stable across restarts, ports and token regeneration):
  `claude mcp add lumina -- dart /path/to/lumina/lumina_ui/bin/lumina_mcp_bridge.dart`
- **Any other client**: `POST <url>` with `Content-Type: application/json`, `Accept: application/json, text/event-stream`, `Authorization: Bearer <token>`, one JSON-RPC 2.0 request (or a batch) per POST; the answer is `application/json`. Notifications get `202` with no body. `GET /mcp` is `405` (the server never pushes messages, so there is no SSE stream); any other path is `404`.

## 3. Handshake and session

1. `initialize` with `protocolVersion` (`2025-11-25`, `2025-06-18` or `2025-03-26`; anything else is answered with `2025-06-18`). The response carries `serverInfo.name == "lumina-studio"`, `capabilities.tools` / `capabilities.resources`, and an `instructions` line, plus the header **`Mcp-Session-Id`**.
2. Send `notifications/initialized` (→ 202).
3. Echo `Mcp-Session-Id` on every later request: missing → HTTP 400, unknown → 404 (re-initialize). `DELETE /mcp` with the header ends the session.
4. Call `project_info` first: project name, dir, active level, `world_units: cm`, `up_axis: z`, dirty flag, actor count, PIE state, undo state.

## 4. Units and axes

The editor's authoring space, exactly as the Details panel shows it: **centimetres**, **degrees**, **Z up**. `location: [x, y, z]` cm; `rotation: [roll, pitch, yaw]` degrees about X, Y, Z; `scale: [x, y, z]` factors. A glTF metre model is drawn ×100, so a 1 m barrel spans ~100 cm at scale 1. Camera distance is cm; camera `target` is the orbit pivot in the same space.

## 5. Tool catalogue (48 tools, by area)

Exact schemas: `reference/tools.md`. Names in `tools/list` are stable.

| Area | Tools |
|---|---|
| Project & level | `project_info`, `list_actors`, `get_actor`, `list_actor_types`, `spawn_actor`, `spawn_actor_from_asset`, `set_actor_transform`, `set_actor_property`, `rename_actor`, `delete_actor`, `duplicate_actor`, `select_actors`, `clear_selection`, `save_level`, `undo`, `redo`, `undo_state` |
| Assets (Content Browser) | `list_assets`, `import_asset`, `create_asset`, `open_asset_editor`, `delete_asset` |
| Materials | `get_material_source`, `set_material_source`, `compile_material`, `get_material_issues` |
| Blueprints | `list_blueprint_nodes`, `get_blueprint`, `add_blueprint_node`, `connect_blueprint_pins`, `set_blueprint_pin_literal`, `remove_blueprint_node`, `remove_blueprint_wire`, `compile_blueprint`, `get_blueprint_diagnostics` |
| UMG Widget Blueprints | `list_widget_types`, `get_widget_tree`, `add_widget`, `remove_widget`, `move_widget`, `wrap_widget`, `replace_widget`, `rename_widget`, `set_widget_is_variable`, `set_widget_slot`, `set_widget_properties`, `bind_widget_event`, `unbind_widget_event`, `set_widget_designer`, `save_widget`, `compile_widget` (the widget's graph: the Blueprint tools) |
| Material node graph | `list_material_nodes`, `get_material_graph`, `add_material_node`, `connect_material_pins`, `remove_material_node`, `remove_material_wire`, `set_material_node_setting`, `arrange_material_graph`, `set_material_parameter`, `set_material_texture`, `set_material_settings`; `asset_editor_screenshot` shows any asset's editor tab |
| Animation, Sequencer, particles | Anim Blueprints (`get_anim_blueprint`, `add_anim_state`, `add_anim_transition`, `add_anim_graph_node {graph:"transition:<id>"}`, `add_anim_variable`, `compile_anim_blueprint`, `anim_blueprint_preview`, …), Blend Spaces (`get_blend_space`, `add_blend_space_sample`, …), animations (`get_animation`, `add_animation_notify`, `add_animation_curve_key`, …), skeletal meshes (`get_skeleton`, `add_skeletal_socket`, `set_skeletal_material_slot`, …), Sequencer (`get_sequence`, `add_sequencer_track`, `add_sequencer_key`, `scrub_sequence`, `render_sequence` as a job, …), particles (`get_particle_system`, `add_particle_emitter`, `set_particle_emitter`, `particle_preview`, …) |
| Asset editors | Landscape (`get_landscape`, `create_landscape`, `import_landscape_heightmap`, `set_landscape_brush`, `sculpt_landscape {strokes}`, `add_foliage_layer`, `paint_foliage`, `save_landscape`, …), Static Mesh (`get_static_mesh`, `add_static_mesh_lod`, `set_static_mesh_lod`, `set_static_mesh_collision`, `set_static_mesh_material_slot`, …), Texture (`get_texture`, `set_texture_settings`, `set_texture_view`, `reimport_texture`, …), Physics Asset (`bind_physics_skeletal_mesh`, `add_physics_body`, `add_physics_constraint`, `validate_physics_asset`, …), Sound (`get_audio`, `set_audio_settings`, `probe_audio_attenuation`, …), Enumerations / Blueprint Interfaces (`get_enum`, `add_enum_value`, `save_enum`, `get_interface`, `set_interface_function_params`, …) |
| Play-In-Editor | `pie_status`, `start_pie`, `stop_pie`, `pause_pie`, `resume_pie`, `step_pie`; `pie_sequence` runs a whole scripted play test in one call |
| Viewport & camera | `viewport_screenshot`, `select_tab`, `get_camera`, `set_camera`, `focus_actor`, `frame_level` |
| Output Log | `read_output_log`, `clear_output_log` |

Resources (`resources/read`): `lumina://project` (the `.lmproject` as JSON), `lumina://output-log` (last 500 lines), `lumina://selection` (what the user has selected, as `get_selection` returns it).

Identifiers you pass around: actor **ids** (`act_3`, from `list_actors`, never names); asset **project-relative paths** (`contents/meshes/fuel_barrel_red.lmas`, from `list_assets`; a bare unique file name also works); Blueprint **node ids** (`node_…`, from `get_blueprint`) versus **library ids** (`print_string`, from `list_blueprint_nodes`); **pin ids** (`exec_out`, `in_string`).

## 6. Workflows

See `reference/workflows.md` for the full call sequences. In short:

- **Place and arrange actors**: `list_actor_types` → `spawn_actor {type, name?, location?, rotation?, scale?}` → `set_actor_transform` / `set_actor_property` → `focus_actor` + `viewport_screenshot` to check → `save_level`.
- **Import a mesh and assign a material**: `import_asset {path}` (absolute GLB/glTF/FBX/OBJ/PNG/WAV path; extracted materials/textures come along) → `spawn_actor_from_asset {asset}` → `create_asset {type: "filamat", name}` → `set_material_source` → `compile_material {save: true}` → `set_actor_property {property: "material", value: "<path>"}`.
- **Author and compile a Blueprint**: `create_asset {type: "actor", name, parent_class}` → `get_blueprint` (opens the tab) → `list_blueprint_nodes {query}` → `add_blueprint_node` → `connect_blueprint_pins` → `set_blueprint_pin_literal` → `compile_blueprint {save: true}` → fix what `diagnostics` names.
- **Run Play and read the log**: `start_pie` → `pie_status` (pawn class, player location) → `read_output_log {contains: "PIE"}` / `{level: "error"}` → `stop_pie` (restores the level, selection and camera).
- **Play-test in one call**: `pie_sequence {steps: [{play_ms: 1000}, {screenshot: true, label: "start"}, {key: "W", hold_ms: 800}, {action: "IA_Jump"}, {advance_frames: 10}, {screenshot: true, label: "after jump"}, {expect: {player_moved: true}}]}` → starts Play if needed, a per-step log (player location, new log lines), the screenshots as captioned images, `final_status`; stops at the first failing step.
- **Screenshot**: `set_camera {yaw, pitch, distance, target}` or `focus_actor` → `viewport_screenshot {max_width}` → MCP image content (`image/png`) + a text line; `target: "editor"` for the whole window. The level tab must be showing (`select_tab {index: 0}`).

## 7. Errors, refusals and undo

- **Protocol errors** (`error` in the JSON-RPC envelope): `-32700` parse, `-32600` invalid request, `-32601` unknown method, **`-32602`** bad tool name or arguments — the message names the argument and the fix (`Tool "spawn_actor" requires argument "type"`, `No actor with id "nope". Call list_actors…`), `-32603` internal, `-32000` (bridge only) editor unreachable.
- **Tool errors** (`result.isError: true`, the text says what to change): unknown actor type (lists the types), a refused spawn (`This level already has a Sky & Atmosphere…`), a locked actor, a name a sibling already uses, a compile failure (`compile_material` / `compile_blueprint` return `isError` with the issues/diagnostics as well), and **`The level cannot be edited while Play-In-Editor runs. Call stop_pie first.`** for any mutating level tool while Play runs.
- **Undo**: every mutating level tool is one transaction on the editor's undo stack — the same stack as Edit → Undo, so the user can revert the agent and vice versa. Each `set_actor_transform` vector (location / rotation / scale) is its own step; a `spawn_actor` with a pose is one step; `undo` / `redo` return the label reverted; `undo_state` tells what would be undone next. Blueprint edits are steps on the **Blueprint tab's** undo stack; material source edits live on the material tab's dirty state (Discard reverts; `compile_material {save: true}` writes). `import_asset`, `create_asset` and `delete_asset` write files and are **not** undoable.
- Text results carry pretty-printed JSON; the same object is in `structuredContent` for clients that read it. `annotations.readOnlyHint` marks the read-only tools.

## 8. Security model

- Loopback only (`127.0.0.1`); nothing outside the machine can reach the server.
- Every request needs `Authorization: Bearer <token>`; 32 random bytes minted per editor session, stored only in the 0600 connection file, compared in constant time; 401 + `WWW-Authenticate: Bearer` otherwise.
- The user can turn the server off (Tools → AI Agent Access, persisted in `~/.config/lumina/mcp_server_settings.json`), regenerate the token, and sees every call in the panel's Recent calls list and in the Output Log (`source: MCP`).
- Tools do only what the UI can do; there is no shell, file-system or arbitrary-code tool. Do not read or copy the token anywhere except into the client's own configuration.

## 9. Pitfalls

- Tests never use the real port: start `McpServerService(vm, configDir: <temp>)` with `start(port: 0)` (`test/helpers/mcp_test_client.dart` is a ready HTTP client).
- Screenshots: a sub-editor tab hides the level viewport → `select_tab {index: 0}` first, or `target: "editor"`.
- `spawn_actor_from_asset` places at `[0, 0, 0]` by default; `focus_actor` then `viewport_screenshot` to see it.
- A GameMode Blueprint cannot be placed; set it in Project Settings → Maps & Modes.
- Batch requests are accepted, but keep one request per POST for readable errors.
