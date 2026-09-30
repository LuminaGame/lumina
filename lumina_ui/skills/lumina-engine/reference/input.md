# Input: actions, mapping contexts, keys

## The model

- **Input actions** and **mapping contexts** are not assets: they live in the `.lmproject` (`input`), edited in
  Project Settings ▸ Input. An action has a name (by convention `IA_Jump`) and a value type: `digital` (bool),
  `axis1D` (float) or `axis2D` (vector2D). A mapping context (e.g. `Gameplay`) maps keys to actions, each mapping
  with a `scale` and, for 2D actions, an `axis` `X` or `Y`.
- **Every mapping context of the project is active in Play**, at its priority. There is no Add Mapping Context
  node and nothing to activate.
- Triggers and modifiers are not authorable: a key down fires **Started** on press, **Triggered** every frame it
  is held, **Completed** on release; `scale` / `axis` place the value.
- New game templates come with `IA_Move` and `IA_Look` (axis2D: W/S → Y ±1, A/D → X ∓1, mouse X / Y), `IA_Jump`
  (Space), `IA_Sprint`, `IA_Dash`, `IA_FreeLook` in the `Gameplay` context.

## Adding an action and keys (MCP)

1. `edit_project_input` with `op` `add_action`, `action` `IA_Fire`, `value_type` `digital`.
2. `edit_project_input` with `op` `add_mapping`, `context` `Gameplay`, `action` `IA_Fire`, `key` `LeftMouseButton`
   (for an axis: `scale` -1 / 1, `axis` `X` / `Y`). Other ops: `update_action`, `remove_action`, `add_context`,
   `update_context`, `remove_context`, `update_mapping`, `remove_mapping`.
3. **`apply_project_settings`** — until then the edit is only staged, and a Blueprint that names the action does
   not compile ("Input action … does not exist").
4. A running Play picks the change up at the next `start_pie`.

Key names ignore case, spaces, `_` and `-`: `W`, `KeyW`, `Space`, `SpaceBar`, `LeftShift`, `Enter`, `Escape`,
`ArrowLeft`, `F5`, `LeftMouseButton`, `MouseX`, `MouseY`, `GamepadFaceButtonBottom`. An unknown key is refused.

## Handling an action in a Blueprint

- Add `event_enhanced_input_action` with `literals` `{"action": "IA_Fire"}`. Its exec outputs are `started`,
  `triggered`, `ongoing`, `completed`, `canceled`; `action_value` is typed by the action (bool, float, vector2D).
- Wire the output you need (`started` for a press, `triggered` for every held frame, `completed` for a release):
  only wired outputs are bound.
- **Input events fire only on the possessed Pawn / Character Blueprint** (the player's pawn). An input event in
  an actor or a widget graph never fires: route it through the pawn (a variable reference, an interface message
  or a dispatcher).
- Movement: `add_movement_input` with `world_dir` (e.g. `get_actor_forward_vector`) and `scale_val` from the
  axis value; look: `add_controller_yaw_input` / `add_controller_pitch_input`.

## Testing input in Play

`pie_key` (`key`, `action` `down` | `up` | `tap`, `hold_frames`), `pie_action` (`action` `IA_Jump`, `value`),
`pie_axis`, `pie_mouse_move`, or `pie_sequence` steps (`key`, `action`, `axis`, `mouse_move`) — see
`play-testing`.
