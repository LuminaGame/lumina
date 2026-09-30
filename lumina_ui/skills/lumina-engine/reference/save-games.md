# Save games

## Nodes (Blueprint library ids)

- `does_save_game_exist` (`slot_name`, `user_index`) → bool.
- `load_game_from_slot` (`slot_name`, `user_index`) → the save object (`return_value`), or nothing when the slot
  is empty.
- `create_save_game_object` (`class`, e.g. `SaveGame`) → a new save object.
- `get_save_field` / `set_save_field` with `literals` `{"field": "BestScore"}` (the field name) and `target` = the
  save object; `set_save_field` takes `value`.
- `save_game_to_slot` (`save_game_object`, `slot_name` default `Slot1`, `user_index`) → bool;
  `async_save_game_to_slot` (latent: `completed`, `success`); `delete_game_in_slot`.

## A best-score pattern

1. `event_beginplay` → `does_save_game_exist` (`slot_name` `Best`) → `branch`:
   - true: `load_game_from_slot` → store in a variable → `get_save_field` `BestScore`;
   - false: `create_save_game_object` (`class` `SaveGame`) → store it.
2. When the run ends: compare, `set_save_field` `BestScore`, then `save_game_to_slot` with the same slot name.

## Where slots are written

- In Play-In-Editor: `<project>/Saved/SaveGames/<slot>_user_<index>.sav` (delete it to start fresh).
- In a built game: the user's application data folder (`%APPDATA%\<Project>\SaveGames` on Windows,
  `~/.local/share/<Project>/SaveGames` on Linux, `~/Library/Application Support/<Project>/SaveGames` on macOS).
- Slot names may not contain `/`, `\` or `..`.

## Notes

- Fields are stored by name; `create_save_game_object` works with a class name that has no SaveGame asset (the
  fields are then untyped). Use the same field name and type for set and get.
- Saving is synchronous with `save_game_to_slot`; check its bool result, and verify in Play by restarting
  (`stop_pie`, `start_pie`) and reading the value back.
