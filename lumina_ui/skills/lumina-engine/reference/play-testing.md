# Play-testing in Play-In-Editor (PIE)

## The loop

1. Save and compile what you changed (`compile_blueprint` with `save: true`, `save_widget`,
   `compile_material` with `save: true`, `apply_project_settings`, `save_level`).
2. `select_tab` with `index` 0 (the level tab) if a sub-editor tab is in front.
3. `start_pie`: compiles the open Blueprints (a compile error fails the call), switches to the level tab and
   returns once Play draws. The player spawns at the PlayerStart.
4. **Let it run at least 1.5 s** before the first screenshot: `pie_play_for` with `ms` 1500 and `screenshot`
   true. Earlier frames can still show the editor camera while meshes load.
5. Drive it: `pie_key` (`key`, `action` `down` / `up` / `tap`, `hold_frames`), `pie_action` (`action` `IA_Jump`,
   `value`), `pie_axis`, `pie_mouse_move` (`dx`, `dy`), `pie_click`, `pie_type_text`; advance with
   `pie_play_for` (wall-clock `ms` up to 10 000, pauses after unless `pause_after` false) or `pie_advance`
   (`frames`, exact steps). Both return a screenshot with `screenshot` true and the runtime actors with `actors`.
6. Inspect: `pie_get_actors` (`class_contains`: runtime classes, locations), `read_output_log` (`contains`,
   `level`, `since_index`), `pie_status`.
7. `stop_pie` before editing again: Blueprint, component, level, asset and undo edits are refused while Play runs.

## One call: `pie_sequence`

`pie_sequence` with `steps`, e.g.
`[{"play_ms": 1500}, {"screenshot": true, "label": "start"}, {"key": "W", "hold_ms": 800},
{"action": "IA_Jump"}, {"play_ms": 500}, {"screenshot": true}, {"expect": {"player_moved": true,
"min_distance_cm": 100}}]`. Step kinds: `key` (+ `hold_ms` / `hold_frames` / `state`), `action` (+ `value`),
`axis` (+ `value`), `click`, `mouse_move`, `play_ms`, `advance_frames`, `screenshot`, `expect` (`player_moved`,
`min_distance_cm`, `log_contains`). It starts Play (`start`, default true), leaves it paused (`stop_at_end`
false), and stops at the first failing step. Limits: 50 steps, 10 screenshots, 10 000 ms of game time. It refuses
to start while a sub-editor tab is active: `select_tab` 0 first.

## Screenshots

- In Play, the PIE tools' `screenshot` flag shows the game camera. `viewport_screenshot` (`max_width`) shows the
  level viewport and refuses while a sub-editor tab is in front; switching tabs during Play can lose the game
  view.
- `asset_editor_screenshot` shows a sub-editor (Blueprint graph, widget designer, material).
- What you print with `print_string` is drawn on the game screen: read it in the screenshot.

## When something does not happen

- Nothing spawns: no PlayerStart, or the default game mode / pawn is not what you think (`gameplay-framework`).
- Input does nothing: the action was staged but not applied, the event is not on the possessed pawn, or its
  output pin is not wired (`input`).
- The view shows the editor camera: you took the screenshot too early, or from the wrong tab.
- A Blueprint change is missing: it did not compile, or you are still playing the previous start (`stop_pie`,
  then `start_pie`).
