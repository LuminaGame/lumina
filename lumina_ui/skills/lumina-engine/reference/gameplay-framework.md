# Gameplay framework: game mode, pawn / character, controller, Maps & Modes

## Who plays

When Play starts, the **game mode** logs the player in: a `LuminaPlayerController` is created, the **default pawn
class** is spawned at a **PlayerStart** (its location and rotation) and possessed. The possessed pawn gets the
input (`input`) and its camera renders (`camera-spring-arm`).

- **No PlayerStart in the level → no player is spawned** (the log says "No Player Start"). Place one:
  `spawn_actor` with `type` `PlayerStart`, above the floor, rotated the way the player should face (yaw 0 faces +Y).
- A Pawn Blueprint (`LuminaPawn`) moves only through your graph; a Character Blueprint (`LuminaCharacter`) has a
  capsule and `CharacterMovement` (walking, falling, `jump`) driven by `add_movement_input`.
- Custom player controller classes are not supported yet: `LuminaPlayerController` is always used.

## Choosing the game mode and the pawn

Project Settings ▸ Maps & Modes (stored in the `.lmproject` under `maps_and_modes`):

| Key | Meaning |
|---|---|
| `maps_and_modes.default_game_mode` | `LuminaGameMode` (default) or a GameMode Blueprint path |
| `maps_and_modes.default_pawn_class` | a Pawn / Character Blueprint path that overrides the mode's pawn; `""` = the mode's |
| `maps_and_modes.game_default_map` | the level a built game opens |
| `maps_and_modes.editor_startup_map` | the level the editor opens |

1. `get_project_settings`: current values plus `accepted_game_modes` (the GameMode Blueprints it accepts).
2. `set_project_settings` with `changes` `{"maps_and_modes.default_game_mode": "contents/blueprints/BP_MyGameMode.lmas"}`
   — the result is **staged**.
3. `apply_project_settings` — now it is saved and used by the next `start_pie`.

A GameMode Blueprint: `create_asset` `type` `actor`, `parent_class` `LuminaGameMode`, then
`set_blueprint_class_default` with `key` `defaultPawnClass` and `value` the pawn's `.lmas` path. Its event graph
does **not** run (only its class defaults are used): put game logic in the pawn, the Level Blueprint or a
manager actor.

Without a GameMode Blueprint, Play uses `LuminaGameMode` with the template character, or the
`default_pawn_class` you set. There is no per-level game mode setting: one project, one default game mode.

## Pawn class defaults

`bUseControllerRotationYaw` (default true: the pawn turns with the controller's yaw),
`bUseControllerRotationPitch`, `bUseControllerRotationRoll`, `baseEyeHeight`.

## Order that works for "make this my player"

1. Create the Character (or Pawn) Blueprint, give it a mesh / camera, compile with `save: true`.
2. Either set `maps_and_modes.default_pawn_class` to it, or make a GameMode Blueprint whose `defaultPawnClass` is
   it and set `maps_and_modes.default_game_mode`; `apply_project_settings`.
3. Make sure the level has a PlayerStart; `start_pie`, play 1.5 s, screenshot, `pie_get_actors` to see the pawn.
