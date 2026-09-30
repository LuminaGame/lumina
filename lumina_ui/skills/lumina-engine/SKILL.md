---
name: lumina-engine
description: How the Lumina game engine works, for AI models that build games in Lumina Studio through its MCP tools - project layout and the source of truth, units and axes, Blueprints and compile, game mode and pawn defaults, input actions, widgets, materials, lights, camera, play-testing, save games and common pitfalls. Read the overview first, then the topic of the area you work in.
---

# Lumina engine guide

Lumina is a 3D game engine written in Dart and Flutter on Google Filament; Lumina Studio is its editor. You work
on the open project through the editor's MCP tools. Every edit call is one undo step labelled `MCP: …`.

## Rules that hold everywhere

- **Units and axes**: 1 unit = 1 cm, angles in degrees, **Z is up**. A rotation is `[pitch, roll, yaw]` in degrees
  about X, Y, Z (the Details panel's X, Y, Z; yaw applied first), the same triple for level actors, Blueprint
  components and Blueprint rotators. At rotation 0 an actor's **forward is +Y** and its right is +X; positive yaw
  turns right (yaw 90 faces +X, yaw -90 faces -X, yaw 180 faces -Y), positive pitch looks up.
- **Source of truth**: the `.lmas` assets under `contents/` and the `.lmproject` manifest. The Dart code in `lib/`
  is generated from them (level save, Blueprint compile); never edit `.lmas` files or generated code by hand, use
  the tools.
- **Blueprints** run in Play-In-Editor from their graphs, as they are in the editor; `compile_blueprint` checks
  them and writes their Dart (`lib/actors/`) for a built game. Fix every compile error before Play.
- **The player**: the level needs a PlayerStart; the game mode comes from Project Settings ▸ Maps & Modes
  (`maps_and_modes.default_game_mode`), its `defaultPawnClass` is the pawn you play.
- **Input** actions and mapping contexts live in Project Settings (`edit_project_input`, then
  `apply_project_settings`); a possessed Pawn / Character Blueprint handles them with
  `event_enhanced_input_action` nodes.
- **Look before you act**: `project_info` first, `get_selection` for "this", `list_actors`, `get_blueprint`,
  `list_blueprint_nodes` (node ids and pin ids: never guess them).
- **Play-test**: `start_pie`, then let the game run at least 1.5 s (`pie_play_for` with `ms` >= 1500, or a
  `{"play_ms": 1500}` step in `pie_sequence`) before the first screenshot; earlier frames can show the editor
  camera. `stop_pie` before editing again: edits are refused while Play runs.
- A tool result that says "staged" is not applied yet (Project Settings: `apply_project_settings`); a Blueprint,
  widget or material is written to disk only with `save: true` / `save_widget`.
