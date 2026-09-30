# Common pitfalls

Lessons from real sessions where a model lost many rounds. Each line: what goes wrong → what to do.

## Before you start

- Guessing node ids, pin ids or class strings → read them: `list_blueprint_nodes` (`query`), `get_blueprint`,
  the node `add_blueprint_node` returns. Pin ids vary (`exec_tick_out`, `exec_move_in`, `then_0`, `true_out`).
- Reasoning about rotation signs in your head → place, then look (`viewport_screenshot`, or a play-test
  screenshot). Forward is +Y at yaw 0; yaw 90 faces +X; positive pitch looks up. Rotations are `[pitch, roll,
  yaw]`: a yaw put in index 1 rolls the object instead.
- Editing `.lmas` files or generated Dart with the file tools → use the editor tools; generated code is
  overwritten.

## Staged, unsaved, uncompiled

- `set_project_settings` / `edit_project_input` only stage → `apply_project_settings`.
- `compile_blueprint` and `compile_material` write nothing without `save: true`; a widget needs `save_widget`.
- A Blueprint with compile errors does not play (`start_pie` fails) → `get_blueprint_diagnostics`, fix, compile.
- An input action used by a Blueprint before it was applied → "Input action … does not exist" at compile.

## Game mode and player

- Default game mode refused as "must be one of …" → the list is in `get_project_settings`
  (`accepted_game_modes`); it is re-read when the settings tab is reused, so a new GameMode Blueprint in any
  folder is accepted once it is saved.
- A GameMode Blueprint's event graph does not run → put logic in the pawn or the Level Blueprint.
- No player in Play → the level has no PlayerStart.
- The player faces +Y although the PlayerStart is rotated → the control rotation starts at yaw 0; add
  `add_controller_yaw_input` on BeginPlay (`camera-spring-arm`).

## Widgets

- `get_widget_element` untyped / "Cannot connect Widget Element to Text Block" → pass `literals`
  `{"class": "WBP_X", "element": "<designer name>"}`; if still untyped, `save_widget` and add the node again, or
  `cast_to` with `class` `WidgetElement:text`. Never `TextBlock`, `Widget:Text`, `Element:text`.
- `get_widget_variable` compiles to "Get Widget names no widget" → `literals` `{"element": "<designer name>"}`
  (not `variable`, `widget` or `widget_id`).
- `create_widget` / `spawn_actor_from_class` / `cast_to` with a path → class strings: `WBP_HUD` for Create
  Widget's `class`, `Actor:BP_X`, `Widget:WBP_X`, `Component:LuminaCameraComponent`.
- Interface messages and dispatchers on a widget → call them on the reference Create Widget returned.

## Materials and meshes

- Material saved but the mesh stays white / grey in Play → `compile_material` with `save: true`, then a slot
  (`set_static_mesh_material_slot` + `save_static_mesh`), the placed actor's `material` property, a Blueprint
  `materialOverride` or the `set_material` node. Not a skeletal mesh override.
- A new material is metallic green (template defaults) → set `baseColor` and `metallic` 0 for non-metals.
- OBJ colours are lost (MTL `Kd` ignored) → set `baseColor` after import, or import GLB / glTF.
- A material that does not compile → read `compile_material`'s issues: matc's messages with their `.mat` lines; see `filament-materials`.

## Lights and camera

- Adding a Point Light to a Blueprint → `LuminaPointLightComponent` works (`intensity` in lumens, `colorHex`,
  `attenuationRadius`, `castShadows`); a Directional Light component does not exist in Blueprints: use a level
  light.
- A mouse-look camera that does not follow the mouse → spring arm `usePawnControlRotation` true.

## Play-testing

- First screenshot shows the editor camera → play at least 1.5 s first.
- `viewport_screenshot` / `pie_sequence` refused while a Blueprint tab is in front → `select_tab` with `index` 0.
- Edits refused with "Stop Play first" → `stop_pie`, edit, `start_pie` again.
- The warning "Class default 'initialHealth' matches no property" on every Play is harmless.
