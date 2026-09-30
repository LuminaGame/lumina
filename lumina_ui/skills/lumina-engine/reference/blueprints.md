# Blueprints: graphs, events, variables, components, compile

## What a Blueprint is

- An `actor` asset (`contents/blueprints/BP_*.lmas`): parent class, components, event graph, functions, macros,
  variables, dispatchers, implemented interfaces, class defaults.
- `create_asset` with `type` `actor`, `name`, `parent_class`: `LuminaActor` (default), `LuminaPawn`,
  `LuminaCharacter` or `LuminaGameMode`. Widget Blueprints are `type` `widget` (see `umg-widgets`); Enumerations and
  Interfaces are `actor` with `blueprint_kind` `enum` / `interface`.
- New Blueprints come with components: a Character has `CapsuleComponent` (root), `ArrowComponent`,
  `CameraBoom` (spring arm), `FollowCamera`, `Mesh` (skeletal mesh) and `CharacterMovement`; a Pawn has
  `DefaultSceneRoot`, `StaticMeshComponent`, `CameraComponent`. Keep the template Mesh's rotation unless a
  screenshot shows the character facing the wrong way.

## Look first

`get_blueprint` (components, variables, graphs with node ids and pin ids) · `list_blueprint_nodes` with `query`
(node library ids, titles, pins and pin types) · `list_component_types`. **Never guess a node id or a pin id**:
they differ between nodes (Event Tick's exec output is `exec_tick_out`, Add Movement Input's are `exec_move_in` /
`exec_move_out`, Branch's are `true_out` / `false_out`, Sequence's `then_0`, `then_1`). `add_blueprint_node`
returns the new node with its pin ids.

## Editing a graph

1. `add_blueprint_node` with `asset`, `node` (library id), `x`, `y`, optional `graph` (`event` default,
   `function:<Name>`, `macro:<Name>`) and `literals` (pin values and node settings).
2. `connect_blueprint_pins` with `from_node`, `from_pin`, `to_node`, `to_pin` (exec to exec; data pins of
   compatible types; a refused wire names the Cast it needs).
3. `set_blueprint_pin_literal` for unconnected inputs.
4. `compile_blueprint` with `save: true` (without it nothing is written) and fix every diagnostic
   (`get_blueprint_diagnostics`).

Node settings go in `literals`: an input action node's `action`, a variable node's `variable`, a custom
event's `name`, Create Widget's `class`, Get Element's `element` (+ `class`), Cast To's `class`, an interface
node's `interface` + `function`, a dispatcher node's `dispatcher`.
**Class strings**: `Actor:BP_Door`, `Widget:WBP_HUD`, `Component:LuminaCameraComponent`, `WidgetElement:text`
(for `cast_to`, `spawn_actor_from_class` and variable types). A plain path or `TextBlock` is refused.

## Common nodes (library ids)

- Events: `event_beginplay`, `event_tick` (`delta_seconds`), `event_enhanced_input_action`, `event_begin_overlap`
  / `event_end_overlap` (`other_actor`), `event_actor_begin_overlap`, `event_hit`, `custom_event`.
- Flow: `branch`, `sequence`, `delay` (`duration`), `set_timer_by_event`, `for_loop`.
- Actors: `get_actor_location`, `set_actor_location` (`new_location`), `set_actor_rotation`,
  `get_actor_forward_vector`, `spawn_actor_from_class`, `destroy_actor`, `get_component` (by component name),
  `add_tag` / `actor_has_tag`.
- Pawn: `get_player_pawn`, `get_player_controller`, `add_movement_input` (`world_dir`, `scale_val`),
  `add_controller_yaw_input` / `add_controller_pitch_input` (`val`), `jump`, `stop_jumping`.
- Values: `variable_get` / `variable_set` (literal `variable`), `make_rotator`, `format_string`, `cast_to`.
- Debug: `print_string` (`in_string`): drawn on the game screen, visible in a play-test screenshot.

## Variables, functions, components

- `add_blueprint_variable` (types `Float`, `Bool`, `Int`, `String`, `Name`, `Vector`, `Rotator`, `Color`,
  `Transform`, `Actor`, `Widget`, `Enum:E_X`, `Array:Float`, or a class string such as `Widget:WBP_HUD`);
  `set_blueprint_variable_default`. `add_blueprint_function` + `set_blueprint_function_signature`,
  `add_blueprint_dispatcher`, `implement_blueprint_interface`.
- Components: `add_blueprint_component` with a type from `list_component_types` (e.g.
  `LuminaStaticMeshComponent`, `LuminaPointLightComponent`, `LuminaSpringArmComponent`), `parent`;
  `set_blueprint_component_property` (property by field name, e.g. `staticMeshAsset`, `materialOverride`,
  `targetArmLength`); `set_blueprint_component_transform` (relative location, rotation as for actors: index 2 is
  yaw, scale); `set_blueprint_class_default` (a GameMode's `defaultPawnClass`).

## Where it runs

- **Play-In-Editor interprets the graphs** node by node, from the editor's current documents (unsaved edits
  included); `start_pie` compiles the open Blueprints first and fails on errors.
- **A built game** runs the Dart that `compile_blueprint` wrote to `lib/actors/`.
- Graph edits are refused while Play runs: `stop_pie` first.
