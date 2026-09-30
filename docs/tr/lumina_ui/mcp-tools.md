[English](../../en/lumina_ui/mcp-tools.md)

# MCP araç kataloğu

Editörün MCP sunucusunun sunduğu araçlar, onları kaydeden dosyaya göre gruplanmış: her alanın kayıt fonksiyonu ve araçlarının adı, risk seviyesi, başlığı ve tek satırlık açıklaması. Dosya yolları `lumina_ui/` paket dizinine görelidir.

## `lib/ui/features/mcp_server/tools/anim_blueprint_tools.dart`

`void registerAnimBlueprintTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The Animation Blueprint editor as MCP tools: the document (target mesh, clips, blend spaces, variables, the state machine, the compile rows), states and their poses, transitions and their rule graphs, the Update event graph (node / wire / literal edits aimed by `graph`), variables, Compile to `lib/anim/<ABP>.dart` and the Anim Preview Editor. Every edit goes through the tab's `AnimBlueprintEditorViewModel` (opened when needed), so the graph canvas updates live and each call is one `MCP: …` step on the tab's own stack.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_anim_blueprint` | readOnly | Get Animation Blueprint | An Animation Blueprint as its editor shows it: target_mesh, the mesh's clips, the Blend Spaces made for it, variables [{name, type, default}], the state machine {name, entry_state, states [{name, x, y, pose}], transition... |
| `add_anim_state` | mutating | Add Anim state | Adds a state to the state machine at canvas (x, y), optionally with its pose, as one undo step. |
| `rename_anim_state` | mutating | Rename Anim state | Renames a state; its transitions and the entry state follow (one undo step). |
| `delete_anim_state` | mutating | Delete Anim state | Deletes a state and its transitions (one undo step). |
| `move_anim_state` | mutating | Move Anim state | Moves a state to canvas (x, y) as one undo step, as dragging its node does. |
| `set_anim_entry_state` | mutating | Set Anim entry state | Makes a state the state machine's entry state (one undo step). |
| `set_anim_state_pose` | mutating | Set Anim state pose | Sets what a state plays: a clip of the target mesh, a Blend Space sampled by variables, or hold (one undo step). |
| `add_anim_transition` | mutating | Add Anim transition | Adds a transition between two states (one undo step). |
| `delete_anim_transition` | mutating | Delete Anim transition | Deletes a transition and its rule graph (one undo step). |
| `set_anim_transition` | mutating | Set Anim transition | Sets a transition's blend duration (seconds, at least 0) and priority (one undo step). |
| `get_anim_graph` | readOnly | Get Anim graph | One node graph of the Animation Blueprint — the Update event graph ("event") or a transition's rule ("transition:<id>") — with its nodes (id, library id, position, pins with literals and connection state) and wires. |
| `add_anim_graph_node` | mutating | Add Anim graph node | Places a library node (list_blueprint_nodes id) on the Update event graph or a transition rule at (x, y), one undo step. |
| `connect_anim_graph_pins` | mutating | Connect Anim graph pins | Wires an output pin to an input pin of the same graph (one undo step); data pins of the same type only. |
| `set_anim_graph_pin_literal` | mutating | Set Anim graph pin literal | Sets the literal of an unconnected input pin (one undo step). |
| `remove_anim_graph_node` | mutating | Remove Anim graph node | Deletes a node and its wires (one undo step). |
| `remove_anim_graph_wire` | mutating | Remove Anim graph wire | Deletes a wire (one undo step). |
| `add_anim_variable` | mutating | Add Anim variable | Adds a variable (one undo step); a taken name gets a numeric suffix, which the result reports. |
| `rename_anim_variable` | mutating | Rename Anim variable | Renames a variable; its Get / Set nodes and the blend space poses that sample it follow (one undo step). |
| `set_anim_variable` | mutating | Set Anim variable | Changes a variable's type (its nodes re-pin; the default resets to the type's) and / or its default value, one undo step each. |
| `delete_anim_variable` | mutating | Delete Anim variable | Deletes a variable, its Get / Set nodes and their wires (one undo step). |
| `compile_anim_blueprint` | mutating | Compile Animation Blueprint | The editor's Compile: lumina's Anim Blueprint validator and Dart generator plus the check that every transition's Result is connected. |
| `anim_blueprint_preview` | editorState | Anim Blueprint preview | Drives the Anim Preview Editor, which runs the Blueprint on its target mesh: the stand-in owner's speed (cm/s), direction (degrees, right positive) and falling state; variable overrides pinned to a value (the update grap... |

## `lib/ui/features/mcp_server/tools/animation_tools.dart`

`void registerAnimationTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The Animation editor as MCP tools: clips and timing, notifies, curves and their keys, rate scale, interpolation, additive type, root motion, the preview mesh, the preview transport, Save. The Animation editor has no undo stack (a dirty flag only): these edits are reverted by not saving (the tab's Discard), never by `undo`.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_animation` | readOnly | Get animation | An animation asset as the Animation editor shows it: clips [{index, name, duration_s, frames}], the selected clip, frame_rate, rate_scale, interpolation (Linear / Step), additive_type, root_motion, the preview mesh, noti... |
| `add_animation_notify` | mutating | Add animation notify | Adds a notify at `time` seconds, clamped to the clip (the result says whether it was, and the time used). |
| `move_animation_notify` | mutating | Move animation notify | Moves a notify to `time` seconds, clamped to the clip. |
| `rename_animation_notify` | mutating | Rename animation notify | Renames a notify. |
| `remove_animation_notify` | mutating | Remove animation notify | Deletes a notify. |
| `add_animation_curve` | mutating | Add animation curve | Adds an empty float curve (e.g. |
| `remove_animation_curve` | mutating | Remove animation curve | Deletes a curve and its keys. |
| `add_animation_curve_key` | mutating | Add animation curve key | Adds a key (time seconds, value) to a curve; keys stay sorted by time. |
| `remove_animation_curve_key` | mutating | Remove animation curve key | Deletes the curve's key at `time` seconds (within 0.0001 s, as the curve editor matches it). |
| `set_animation_settings` | mutating | Set animation settings | The Animation editor's asset settings: the default clip (index), frame_rate (> 0), rate_scale, interpolation (${interpolations.join( |
| `animation_preview` | editorState | Animation preview | The Animation editor's transport: "play" / "pause", "seek" to `time` seconds, or "step" `frames` frames (negative steps back). |
| `save_animation` | mutating | Save animation | Writes the animation .lmas: notifies, curves, settings, root motion, the preview mesh (the tab's Save). |

## `lib/ui/features/mcp_server/tools/asset_tools.dart`

`void registerAssetTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The Content Browser as MCP tools: list and search assets, import a file through the real import pipeline, create an asset, open its editor, delete it.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `list_assets` | readOnly | List assets | The project's assets under contents/ (the Content Browser), with their project-relative path, type (${AssetType.values.map((t) => t.name).join( |
| `import_asset` | mutating | Import asset | Imports a file from disk through the editor's import pipeline (Content Browser → Import): GLB / glTF / FBX / OBJ meshes (their materials and textures are extracted alongside), PNG / JPG / WebP / TGA textures, WAV / OGG a... |
| `create_asset` | mutating | Create asset | Creates a new asset under contents/ (Content Browser → New): "filamat" writes a material with the editor's default .mat source; "actor" a Blueprint class (give parent_class: ${parentClasses.join( |
| `open_asset_editor` | editorState | Open asset editor | Opens the asset's editor in a workspace tab, as a double-click in the Content Browser does (Material, Blueprint, Static Mesh, Skeletal Mesh, Animation, Texture, …). |
| `delete_asset` | destructive | Delete asset | Deletes an asset (Content Browser → Delete): its files move to the project trash (.lumina/trash/<trash_id>) and the level actors that reference it are removed (`removed_actors`). |
| `list_trash` | readOnly | List trash | The project trash (.lumina/trash): every deleted asset's entry, newest first — id, when, why, who, its files and the actors it removed. |
| `restore_asset` | mutating | Restore asset | Restores a trash entry (list_trash): its files return to their paths and the actors it removed return to the level. |

## `lib/ui/features/mcp_server/tools/audio_tools.dart`

`void registerAudioTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The Sound editor as MCP tools: the decoded wave's facts, the sound's settings (volume, pitch, class, looping, spatialisation, attenuation), a gain-at-distance probe evaluated by the runtime's own attenuation, Save. No playback: an agent cannot hear.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_audio` | readOnly | Get sound | The Sound editor's asset (opens its tab): sample rate, channels, bit depth, duration in seconds, frame count, and the settings (volume, pitch, pitch randomization, sound class, looping, spatialized, attenuation model, in... |
| `set_audio_settings` | mutating | Set sound settings | The Details panel: volume (0–2), pitch (0.5–2), pitch_randomization (0–1), sound_class (${classes.join( |
| `probe_audio_attenuation` | readOnly | Probe attenuation | The attenuation plot's probe: the gain (0–1) the runtime's attenuation gives at distance_cm (default 1200) with the current settings, before the volume multiplier (effective_gain includes it). |
| `save_audio` | mutating | Save sound | The tab's Save: writes the settings into the .lmas metadata (audio_settings); the wave is unchanged. |

## `lib/ui/features/mcp_server/tools/blend_space_tools.dart`

`void registerBlendSpaceTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The Blend Space editor as MCP tools: axes (name, range, 1D ⇄ 2D), grid divisions, samples (dropped clips snapped to the grid), the preview point and the clip it picks, Save. Every edit goes through the tab's `BlendSpaceEditorViewModel`; document edits are one `MCP: …` step on its stack (the divisions and the preview point are view state).

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_blend_space` | readOnly | Get Blend Space | A Blend Space as its editor shows it: axes [{name, min, max}] (one for 1D, two for 2D), grid divisions, samples [{index, clip, x, y}], the target mesh's clips, the preview point and the nearest sample (the one the previe... |
| `set_blend_space_axis` | mutating | Set Blend Space axis | Renames an axis and / or sets its range (one undo step). |
| `set_blend_space_dimensions` | mutating | Set Blend Space dimensions | Makes the Blend Space 1D (the Y axis and every sample's Y are dropped) or 2D (a Speed axis 0…500 is added), one undo step. |
| `set_blend_space_divisions` | mutating | Set Blend Space divisions | Sets the grid divisions per axis (1…32) that new samples snap to. |
| `add_blend_space_sample` | mutating | Add Blend Space sample | Drops a clip of the target mesh at (x, y), snapped to the grid divisions as a drop on the grid is (one undo step). |
| `set_blend_space_sample` | mutating | Set Blend Space sample | Moves a sample (unsnapped, as typed in its fields) and / or retargets it to another clip (one undo step). |
| `remove_blend_space_sample` | mutating | Remove Blend Space sample | Deletes a sample (one undo step); later samples move down one index. |
| `set_blend_space_preview` | editorState | Set Blend Space preview | Moves the preview point (unsnapped); the preview mesh cross-fades to the nearest sample's clip, which is returned as picked_clip. |
| `save_blend_space` | mutating | Save Blend Space | Writes the Blend Space .lmas (the tab's Save). |

## `lib/ui/features/mcp_server/tools/blueprint_class_tools.dart`

`void registerBlueprintClassTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

A Blueprint class's Components panel, Class Defaults and parent class as MCP tools. Each edit is one undo step on the Blueprint tab and selects the component it touched. The Level Blueprint has no components, class defaults or parent class.

## `lib/ui/features/mcp_server/tools/blueprint_member_tools.dart`

`void registerBlueprintMemberTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

My Blueprint as MCP tools: variables, functions and their signatures and local variables, macros, event dispatchers, implemented interfaces, custom event parameters, timelines, and collapse / expand. Each edit is one undo step on the Blueprint tab (the Level Blueprint's too) and selects or shows what it touched. Names are made unique: every add returns the name it used. There is no "expose" / Instance Editable flag on variables (lumina's variables have name, type and default only).

## `lib/ui/features/mcp_server/tools/blueprint_tool_support.dart`

`const String kBlueprintAssetArg`

Shared by the Blueprint tool sets. `asset` for every Blueprint tool.

`const String kBlueprintGraphArg`

`graph` for the graph tools.

`McpToolResult? mcpRefuseWhilePlaying(EditorViewModel vm)`

A mutation refused while Play-In-Editor runs (the editor freezes edits).

`(BlueprintGraphRef, BlueprintGraphEditor) mcpResolveGraph(BlueprintEditorViewModel editor, String? name)`

The graph [name] names on [editor], and its editor. Throws a -32602 for a graph that is not a node graph or does not exist; never falls back to the event graph.

`BlueprintGraphRef mcpGraphRef(BlueprintEditorViewModel editor, String? name)`

`String mcpGraphName(BlueprintGraphRef ref)`

`Map<String, Object?> mcpBlueprintUndo(BlueprintEditorViewModel editor)`

`Map<String, Object?> mcpVariableJson(LuminaBlueprintVariable v)`

`List<LuminaBlueprintVariable> mcpParseParams(Object? raw, String argName)`

`[{name, type, default?}]` as Blueprint variables; a type lumina cannot parse is a -32602 naming the accepted forms.

`String mcpCheckType(String type)`

[type] when lumina can store it as a variable type, else a -32602.

## `lib/ui/features/mcp_server/tools/blueprint_tools.dart`

`void registerBlueprintTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The Blueprint editor as MCP tools: the node library, a Blueprint's components, members and graphs (the event graph, function and macro graphs, the Level Blueprint), node / wire / literal edits through the graph's editor (each one undo step on the Blueprint tab), compile with lumina's validator and code generator, diagnostics.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `list_blueprint_nodes` | readOnly | List Blueprint nodes | The Blueprint node library (the editor's palette): every node's library id (what add_blueprint_node takes, e.g. |
| `get_blueprint` | readOnly | Get Blueprint | A Blueprint as its editor shows it: parent class, class defaults, components (id, type, name, parent, properties), variables, functions (signature, pure, category, local variables), macros, event dispatchers, implemented... |
| `add_blueprint_node` | mutating | Add Blueprint node | Places a library node (list_blueprint_nodes id) on a graph (the event graph unless `graph` names a function or macro) at canvas position (x, y), as one undo step on the Blueprint tab. |
| `connect_blueprint_pins` | mutating | Connect Blueprint pins | Wires an output pin to an input pin of another node of the same graph (one undo step). |
| `set_blueprint_pin_literal` | mutating | Set Blueprint pin literal | Sets the literal value of an unconnected input pin (one undo step): a string, number, boolean, or [x, y, z] for a vector / rotator pin. |
| `remove_blueprint_node` | mutating | Remove Blueprint node | Deletes a node and its wires from a graph (one undo step). |
| `remove_blueprint_wire` | mutating | Remove Blueprint wire | Deletes a wire (one undo step). |
| `compile_blueprint` | mutating | Compile Blueprint | Compiles the Blueprint (the editor's Compile button): lumina's validator and Dart code generator run on the document as it is; a clean result is written to lib/actors/<blueprint>.dart, snake_case (BP_Door → bp_door.dart;... |
| `get_blueprint_diagnostics` | readOnly | Get Blueprint diagnostics | The Blueprint editor's compile status and the last compile's diagnostics. |

## `lib/ui/features/mcp_server/tools/blueprint_type_tools.dart`

`void registerBlueprintTypeTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The Enumeration and Blueprint Interface editors as MCP tools: an enum's ordered values, an interface's function signatures. Every edit is one step on the asset's own undo stack, which 04's `undo` reaches with the asset.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_enum` | readOnly | Get enumeration | The Enumeration editor's document (opens its tab): its values in order, the selected one, unsaved changes and its undo stack. |
| `add_enum_value` | mutating | Add enum value | Adds a value at the end (+ Add Enumerator): the given identifier (a taken one gets a number), or the next NewEnumerator<n>. |
| `rename_enum_value` | mutating | Rename enum value | Renames the value at index to a new identifier not used by another value. |
| `remove_enum_value` | destructive | Remove enum value | Deletes the value at index. |
| `move_enum_value` | mutating | Move enum value | Reorders: moves the value at index from to index to. |
| `save_enum` | destructive | Save enumeration | The tab's Save: writes the values and — project-wide — rewires the case pins of every "Switch on <enum>" node in every Blueprint of the project so each case keeps its value by name (cases of removed values lose their wir... |
| `get_interface` | readOnly | Get Blueprint Interface | The Blueprint Interface editor's document (opens its tab): its functions with their typed inputs and outputs (a function without outputs is implemented as an event), unsaved changes, its undo stack. |
| `add_interface_function` | mutating | Add interface function | Adds a function without parameters (+ Function), made unique with a number: use the returned name. |
| `rename_interface_function` | mutating | Rename interface function | Renames a function to an identifier no other function uses. |
| `remove_interface_function` | destructive | Remove interface function | Deletes a function from the interface. |
| `set_interface_function_params` | mutating | Set interface function parameters | A function's Inputs and / or Outputs lists, replaced whole: [{name, type}] with the types the signature editor offers. |
| `save_interface` | mutating | Save Blueprint Interface | The tab's Save: writes the function signatures to the .lmas. |

## `lib/ui/features/mcp_server/tools/build_tools.dart`

`const String kMcpBuildPipeline`

The key of the one Build Manager pipeline an editor runs at a time.

`void registerBuildTools(McpToolRegistry registry, EditorViewModel vm, McpJobRegistry jobs)`

The Build menu and the Build Manager as MCP tools (group `build`): the Build Manager's settings, and Build All / Cook & Package started as jobs over the editor's one [BuildManagerViewModel] — the pipeline the menu and the tab drive, so a build the user started is visible here too. Generate Dart Code is `run_codegen` (a project file tool, listed in this group as well); Build Navigation is the level tools' `build_navigation`.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_build_settings` | readOnly | Get build settings | The Build Manager's settings: the asset steps with their enabled flags, selected_targets (the project's packaging targets), configuration (Debug → --debug, Development → --profile, Shipping → --release), extra_flags, bun... |
| `set_build_settings` | mutating | Set build settings | Changes the Build Manager's settings as its tab does: steps {"precompileMaterials": false, …}, targets (the full list to tick; saved to the .lmproject at once, as the tab does), configuration (Debug \| Development \| Shipp... |
| `start_build` | external | Start a build | Build All (the ticked asset steps) or Cook & Package (the steps, then a real flutter build per ticked target — minutes for a release build), started as a job in the Build Manager tab (it opens). |
| `get_build_status` | readOnly | Build status | The Build Manager's current or last run, whoever started it (start_build, the Build menu, the tab): is_running, stage, progress, per-step and per-target statuses, artifact_path, last_pipeline_status, validation issues, a... |
| `launch_web_build` | external | Launch web build | The Build Manager's Launch in Browser: serves the last packaged web build on localhost and opens it in the system browser. |

## `lib/ui/features/mcp_server/tools/code_tools.dart`

`void registerCodeTools(McpToolRegistry registry, EditorViewModel vm)`

The code tools, group `code`: the project's `dart analyze` diagnostics, run with the SDK its packages were resolved with, and the editor's Generate Dart Code, awaited.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `dart_analyze` | readOnly | Analyze the game code | Runs the project's `dart analyze` (the SDK its packages were resolved with) on the project or on paths inside it and returns {ok (no errors), counts {error, warning, info}, diagnostics [{severity, type, code, file, line,... |
| `run_codegen` | mutating | Generate Dart code | Build → Generate Dart Code, awaited: saves the open level (its .lmas) and regenerates lib/main.dart and lib/levels/<level>.dart (snake_case: L_Main → l_main.dart) — the same routine as Save Level. |

## `lib/ui/features/mcp_server/tools/component_tools.dart`

`const Set<String> kMcpPhysicsKeys`

The Physics section's keys, shared with the Blueprint component tools.

`Map<String, dynamic> mcpApplyCollision(McpArgs args, Map<String, dynamic> current, {LuminaCollisionProfile? base})`

A collision edit as the Collision section makes it: a preset first (its table), then object type, per-channel responses, Generate Overlap Events and Collision Enabled on top.

`Map<String, dynamic> mcpApplyPhysics(Map<String, Object?> raw, Map<String, dynamic> current)`

The Physics section's keys of [raw], checked; merged over [current].

`void registerComponentTools(McpToolRegistry registry, EditorViewModel vm)`

Components of level actors: what the Details panel's Add Component popover, the component header's remove button and the Collision and Physics sections do. Each edit is one level undo step and selects the actor, so Details shows it. Level-actor components are a flat list without rename or reparent (the Details panel offers neither).

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `list_component_types` | readOnly | List component types | The component types a user can add. |
| `add_actor_component` | mutating | Add actor component | Details → Add Component on a level actor (one undo step). |
| `remove_actor_component` | destructive | Remove actor component | Details → × on one component of a level actor: removes exactly that component (one undo step that puts it back at its position with its id and properties). |
| `set_actor_component_enabled` | mutating | Enable / disable actor component | Turns one component of a level actor on or off (Details shows "Component Disabled"); one undo step. |
| `set_actor_collision` | mutating | Set actor collision | The Collision section of a collision-capable component (one undo step): a preset (NoCollision, BlockAll, OverlapAll, BlockAllDynamic, OverlapAllDynamic, Pawn, Trigger, Custom) fills object type and responses from its tab... |
| `set_actor_physics` | mutating | Set actor physics | The Physics section of a placed Blueprint's collision shape or static mesh (one undo step, the instance's override saved in the level): physics {simulate, overrideMass, massKg, enableGravity, centerOfMassOffset, friction... |

## `lib/ui/features/mcp_server/tools/content_tools.dart`

`const String kMcpFolderNameError`

The Content Browser folder tile's rename error (content_browser_folder_tile).

`String mcpContentFolder(String raw, {String argument = 'folder'})`

[raw] as a project-relative Content Browser folder: `contents` or a folder under it (`Props` → `contents/Props`). Anything absolute, climbing out or outside `contents/` is `-32602`.

`void registerContentTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions, McpJobRegistry jobs)`

The Content Browser's organisation work as MCP tools (group `content`): the folder tree, New / Rename / Delete folder (to the trash), the drag-to-folder move, asset Rename / Duplicate, collections, Regenerate Thumbnail and File → Import Asset Folder as a job. Every tool shows its result in the Content Browser, as the user's action would.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `list_content_folders` | readOnly | List content folders | The Content Browser's Sources tree under `under` (default "contents"): {path, name, asset_count (assets directly in it), total_assets (with subfolders), favorite, children[]}; plus plugin content roots (enabled content-o... |
| `create_content_folder` | mutating | Create content folder | Content Browser → New Folder: creates `name` under `parent` (with its keep-marker). |
| `rename_content_folder` | mutating | Rename content folder | Content Browser → Rename folder: renames `folder` to `new_name`; every reference to an asset inside follows, and the browser's selection, favourites and the open level's path move with it. |
| `delete_content_folder` | destructive | Delete content folder | Deletes a Content Browser folder and everything in it to the project trash (.lumina/trash/<trash_id>): its assets (level actors that use them are removed), keep-markers and companions. |
| `move_asset` | mutating | Move asset | Moves an asset into a Content Browser folder, as dragging its tile onto the folder does: the .lmas moves (the folder is created when missing) and references to it are rewritten. |
| `rename_asset` | mutating | Rename asset | Content Browser → Rename (F2): renames the .lmas (and its companions) in place; the asset keeps its asset_id, the assets and placed actors that reference it follow. |
| `duplicate_asset` | mutating | Duplicate asset | Content Browser → Duplicate (Ctrl+D): copies the asset beside the original as <name>_1 (_2, …) with a fresh asset_id. |
| `list_collections` | readOnly | List collections | The Content Browser's collections (contents/.collections.json): {name, assets[{asset_id, path}]}. |
| `create_collection` | mutating | Create collection | Content Browser → Collections → +: a new, empty collection. |
| `delete_collection` | mutating | Delete collection | Removes a collection (the list only; its assets stay). |
| `add_to_collection` | mutating | Add to collection | Adds assets to a collection by their asset_id (an asset already in it stays once). |
| `remove_from_collection` | mutating | Remove from collection | Removes assets from a collection (the assets themselves stay). |
| `regenerate_thumbnails` | mutating | Regenerate thumbnails | Content Browser → Regenerate Thumbnail for each asset: queued on the offscreen thumbnail renderer (Filament), which re-embeds the PNG in the .lmas (png_path; no sidecar file). |
| `import_asset_folder` | mutating | Import asset folder | File → Import Asset Folder…: walks a folder on disk (any path) for everything the import pipeline takes (meshes with their companions, textures, sounds), then imports it on the background import queue as a job (kind impo... |

## `lib/ui/features/mcp_server/tools/core_tools.dart`

`Map<String, Object?> mcpUndoState(TransactionManager stack)`

Undo state of [stack] as the tools report it: labels, who made the steps, how many own steps are on top, and the recent history.

`void registerCoreTools( McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions, { required Set<String>? Function() activeGroups, required McpToolRisk Function() maxRisk, })`

The tools every session lists (group `core`): the project, undo / redo on the level or on a Blueprint / Material tab, and the tool catalogue.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `project_info` | readOnly | Project info | The open project: name, engine version, project directory, active level, units and axes, whether the level has unsaved changes, actor count and Play-In-Editor state. |
| `undo` | mutating | Undo | Edit → Undo: reverts the last level edit, or with `asset` the last edit on that Blueprint, Widget Blueprint or Material tab (stack "graph": its node graph), or any asset tab with its own stack (see `asset`; a Landscape's... |
| `redo` | mutating | Redo | Edit → Redo: re-applies the last undone level edit, or with `asset` the last undone edit on that Blueprint, Widget Blueprint or Material tab (stack "graph": its node graph). |
| `undo_state` | readOnly | Undo state | Whether undo / redo are available on the level (or, with `asset`, a Blueprint / Material tab), what they would revert and who made it (undo_origin), how many of this session's steps are on top (agent_depth), and the rece... |
| `list_tool_groups` | readOnly | List tool groups | The tool groups (connect with /mcp?groups=a,b or pass tools/list params.groups to list only some), their tools and how many of each risk; this session's active groups and the editor's risk ceiling (tools above it are nei... |

## `lib/ui/features/mcp_server/tools/details_tools.dart`

`void registerDetailsTools(McpToolRegistry registry, EditorViewModel vm)`

The multi-select Details panel as MCP tools: several actors selected and edited at once — shared transform rows (absolute, or relative per axis as a scrub is), a shared component's property and enabled state, and the × that removes a component type from all of them. Every call selects the actors, so the panel shows the result, and is one undo step.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_multi_edit` | readOnly | Get multi-edit view | Selects the actors and returns what the multi-select Details panel shows: location, rotation and scale per axis (common value, or null where mixed), visibility and lock, and the component types every actor has, with each... |
| `set_actors_transform` | mutating | Set actors transform | The multi-select Details transform rows: sets location, rotation and/or scale on every actor at once — absolute, or added to each actor's own value with relative (a scrub), on one axis only with axis (0 = X, 1 = Y, 2 = Z... |
| `set_actors_component_property` | mutating | Set actors component property | A shared component's property row in the multi-select Details panel: sets the property on every actor that has a component of that type (list_component_types lists types and properties), in one undo step. |
| `set_actors_component_enabled` | mutating | Set actors component enabled | The enabled checkbox of a shared component in the multi-select Details panel: enables or disables the component of that type on every actor that has one, in one undo step. |
| `remove_actors_component` | destructive | Remove actors component | The × of a shared component in the multi-select Details panel: removes every component of that type from every actor (remove_actor_component removes one component of one actor). |

## `lib/ui/features/mcp_server/tools/editor_preferences_tools.dart`

`void registerEditorPreferencesTools(McpToolRegistry registry, EditorViewModel vm)`

Editor Preferences (Edit → Editor Preferences) as MCP tools (group `settings`): the user's own editor settings in `editor_preferences.json`, saved at once as the page does. An open Editor Preferences tab follows through the preferences' listener.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_editor_preferences` | readOnly | Get Editor Preferences | The editor's per-user preferences: flight_camera_control (when W/A/S/D fly the level viewport: rmbHeld \| always \| never), import_workers (1..4 parallel import isolates), marketplace_url (read-only here), and the file the... |
| `set_editor_preferences` | mutating | Set Editor Preferences | Sets flight_camera_control (rmbHeld \| always \| never) and / or import_workers (1..4); saved to editor_preferences.json at once. |

## `lib/ui/features/mcp_server/tools/fs_tools.dart`

`McpFileSnapshots mcpFileSnapshotsOf(EditorViewModel vm)`

The snapshot store of [vm]'s project, shared by the file and code tools.

`Future<McpToolResult> mcpSandboxed(FutureOr<McpToolResult> Function() body) async`

Runs [body], turning a [SandboxViolation] into a tool error with its message (the agent sees why and what to use instead).

`void registerFsTools(McpToolRegistry registry, EditorViewModel vm)`

The project file tools, group `fs`: list, read, search, write, edit and delete files under the open project's root — resolved through [ProjectSandbox], so `..`, absolute paths and symlinks never leave it — with a pre-write snapshot for every change ([McpFileSnapshots]) that `fs_history` lists and `fs_restore` applies. File edits are not on the level's undo stack: `fs_restore` is their undo.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `fs_list` | readOnly | List project files | Lists a folder of the open project (default: its root): [{path, type: file\|dir\|link, bytes, modified}], sorted, project-relative. |
| `fs_read` | readOnly | Read a project file | Reads a text file of the project: lines offset..offset+limit-1 (1-based; default 1 and 2000) as {path, total_lines, start_line, end_line, truncated, sha256, content}. |
| `fs_search` | readOnly | Search project files | Searches the project's text files with a Dart regular expression: [{path, line, column, text}] (1-based), truncated, files_scanned. |
| `fs_write` | mutating | Write a project file | Writes a UTF-8 text file (≤ 1 MiB) in the project, creating its folders: {path, bytes, created, snapshot_id, generated}. |
| `fs_edit` | mutating | Edit a project file | Replaces old_string with new_string in a project text file: old_string must occur exactly once (include surrounding lines to make it unique) unless replace_all. |
| `fs_delete` | destructive | Delete a project file | Moves one project file (not a folder) to the project trash (.lumina/trash; list_trash, and fs_restore with the returned snapshot_id, bring it back): {path, trash_id, snapshot_id}. |
| `fs_history` | readOnly | File snapshots | The file snapshots the file tools took before each change, newest first: [{id, tool, path, existed, bytes, sha256, created, session_id, client, caller}]. |
| `fs_restore` | mutating | Restore a file snapshot | Puts a file back as snapshot_id recorded it (fs_history): the old bytes, or — when the file did not exist then — the current file moved to the project trash. |

## `lib/ui/features/mcp_server/tools/graph_json.dart`

`Map<String, Object?> mcpPinSpec(LuminaBlueprintPinSpec p)`

The node, pin and wire JSON and the node / wire / literal edits of a Blueprint node graph, over any [BlueprintGraphEditor] (extracted from the Blueprint tools so the Animation Blueprint's update graph and transition rules share them). Every edit is the graph editor's own call, so it is one undo step on the stack of the editor that owns the graph.

`Map<String, Object?> mcpNodeJson(BlueprintGraphEditor graph, LuminaBlueprintNode n)`

`Map<String, Object?> mcpWireJson(LuminaBlueprintWire w)`

`Map<String, Object?> mcpGraphJson(BlueprintGraphEditor graph)`

A graph's nodes and wires as `get_*` tools return them.

`McpToolResult mcpGraphAddNode( BlueprintGraphEditor graph, String graphName, McpArgs args, { required String rejected, Map<String, Object?> Function()? extra, })`

Places library node `node` at (`x`, `y`) with optional `literals`. [rejected] explains why the graph refuses a node its filter does not take.

`McpToolResult mcpGraphConnect(BlueprintGraphEditor graph, String graphName, McpArgs args, {Map<String, Object?> Function()? extra})`

Wires `from_node.from_pin` → `to_node.to_pin`.

`McpToolResult mcpGraphSetLiteral(BlueprintGraphEditor graph, String graphName, McpArgs args, {Map<String, Object?> Function()? extra})`

Sets the literal of input pin `pin` on node `node` to `value`.

`McpToolResult mcpGraphRemoveNode(BlueprintGraphEditor graph, String graphName, McpArgs args, {Map<String, Object?> Function()? extra})`

Deletes node `node` and its wires.

`McpToolResult mcpGraphRemoveWire(BlueprintGraphEditor graph, String graphName, McpArgs args, {Map<String, Object?> Function()? extra})`

Deletes wire `wire`.

## `lib/ui/features/mcp_server/tools/job_tools.dart`

`const int kMcpWaitJobMaxMs`

`wait_job`'s longest wait: no call outlives a client's HTTP timeout.

`void registerJobTools(McpToolRegistry registry, McpJobRegistry jobs)`

The job tools (group `core`): list, read (state, progress, result, log pages), long-poll and cancel the long-running operations other tools start.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `list_jobs` | readOnly | List jobs | The long-running operations of this editor session (start_build, play_standalone, set_widget_library, …), newest last: {id, kind, title, state (queued\|running\|succeeded\|failed\|cancelled), progress 0..1 or null, stage, st... |
| `get_job` | readOnly | Get job | One job: state, progress, stage, result (when finished), error, and its log as [{index, level, source, message}] plus next_log_index. |
| `wait_job` | readOnly | Wait for a job | Long-poll: returns as soon as the job leaves running (its state, progress, result, error), or after timeout_ms (default 20000, max …) with timed_out: true. |
| `cancel_job` | editorState | Cancel job | Cancels a running job: a build kills its flutter build, Play Standalone stops the game or its build. |

## `lib/ui/features/mcp_server/tools/landscape_tools.dart`

`void registerLandscapeTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The Landscape editor as MCP tools: create a terrain, import a heightmap, set the sculpt and foliage brushes, replay stroke lists (each stroke one entry on the landscape's own undo stack, which 04's `undo` reaches with the asset), foliage layers and paint / erase strokes, save. The agent speaks centimetres and terrain-local `[x, y]` (Z up, origin at the terrain's centre); the `LANDSCAPE` payload is terrain metres, Y up, so every point converts here once: `worldX = x / 100`, `worldZ = −y / 100`, heights `/ 100` — as the panel's sliders do.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_landscape` | readOnly | Get landscape | The Landscape editor's terrain (opens its tab): grid resolution, world size, max height and height min / max in cm, section count, foliage layers (name, mesh, rules, instance count), the sculpt and foliage brushes, unsav... |
| `create_landscape` | destructive | Create landscape terrain | Manage → New Terrain: replaces the landscape's terrain with a flat grid (its foliage and its undo history go with it; not undoable — close the tab without saving to keep the old one). |
| `import_landscape_heightmap` | mutating | Import heightmap | Manage → Import Heightmap: replaces the terrain with a grayscale PNG (8- or 16-bit, square, a side of n × 64 + 1 pixels). |
| `set_landscape_brush` | mutating | Set sculpt brush | The Sculpt panel's brush: tool (${toolNames.join( |
| `set_foliage_brush` | mutating | Set foliage brush | The Foliage panel's brush: radius in cm (100–20 000), falloff (0–1), paint_density (share of a layer's density one pass lays down, 0–1) and erase_density (what an erase pass leaves, 0 clears). |
| `sculpt_landscape` | mutating | Sculpt landscape | Replays brush strokes as a mouse drag would: each stroke starts at its first point and stamps the brush every ¼ radius along the rest (sculpt raises, invert lowers; smooth, flatten to the height under the first point, no... |
| `add_foliage_layer` | mutating | Add foliage layer | Foliage → Mesh Palette: adds a layer painting a static mesh (list_assets type "filamesh"), selected for paint_foliage, with optional placement rules (density per 1000 × 1000 cm, min_spacing_cm, scale_min / scale_max, ran... |
| `set_foliage_rules` | mutating | Set foliage rules | A foliage layer's placement rules (the layer card's sliders and switches); rules not given keep their values. |
| `remove_foliage_layer` | destructive | Remove foliage layer | Removes a foliage layer and every instance painted with it. |
| `paint_foliage` | mutating | Paint foliage | Drags the foliage brush along each stroke on a layer: paint scatters instances by the layer's rules and the brush's paint density; erase: true removes them (thinned by the erase density). |
| `save_landscape` | mutating | Save landscape | The Landscape tab's Save: writes the heights and foliage layers to the .lmas (a large terrain's heights to its sidecar). |

## `lib/ui/features/mcp_server/tools/level_file_tools.dart`

`const List<String> kMcpIfDirtyChoices`

The `if_dirty` choices of the level-switching tools.

`Map<String, Object?> mcpIfDirtySchema()`

`if_dirty` for every tool that leaves the open level.

`McpToolRisk? mcpDiscardRisk(Map<String, Object?> arguments)`

`open_level` / `open_asset_editor` with `if_dirty: "discard"` drops unsaved work: the approval chain reviews such a call as destructive.

`Future<McpToolResult?> mcpLeaveLevel(EditorViewModel vm, String? ifDirty) async`

Leaves the open level only as a user would: a clean level always; a dirty one per [ifDirty] — `refuse` (null) returns the tool error, `save` saves it first, `discard` drops the changes. Returns null when the level may be left.

`void registerLevelFileTools(McpToolRegistry registry, EditorViewModel vm)`

Level files as MCP tools: the levels File → Open Level lists, the New Level templates, and creating and opening levels with a guard for unsaved work — the UI's own `createLevelFromTemplate` and `openLevelGuarded`.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `list_levels` | readOnly | List levels | The project's levels, as File → Open Level lists them (contents/levels/*.lmas): path, name and whether it is the open level, plus is_dirty (unsaved changes) for the open one. |
| `list_level_templates` | readOnly | List level templates | The templates File → New Level offers (new_level's template): id, title, what it seeds, how many actors and whether it enables World Partition. |
| `new_level` | mutating | New level | File → New Level: writes contents/levels/<name>.lmas from a template (list_level_templates; default "default") and opens it, as one undo step "New Level <name>" whose undo deletes the file and returns to the previous lev... |
| `open_level` | mutating | Open level | File → Open Level: opens a level (a path or a name from list_levels) in the viewport, Outliner and title bar. |

## `lib/ui/features/mcp_server/tools/level_settings_tools.dart`

`const List<String> kDataLayerStates`

The data-layer states the runtime's `DataLayerState` has.

`void registerLevelSettingsTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The level's own settings as MCP tools: World Partition and its data layers (the Details panel with nothing selected), the environment (Tools → Environment Lighting's view model) and navigation (Tools → Navigation's view model, Build → Build Navigation). Every edit is one level undo step.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_level_settings` | readOnly | Get level settings | The open level's own settings: world_partition (enabled, cell_size and loading_range in cm, max_cell_transitions_per_tick, data_layers [{index, name, initial_state}]), actor_cells (the grid cell each actor falls in, as t... |
| `set_world_partition` | mutating | Set World Partition | The level's World Partition section (Details panel with nothing selected): enabled, cell_size (cm, > 0), loading_range (cm, ≥ 0) and max_cell_transitions_per_tick (≥ 1), clamped as the panel clamps. |
| `add_data_layer` | mutating | Add data layer | World Partition → Data Layers → Add: a runtime data layer (initial state "unloaded") the generated code registers with LuminaDataLayerManager. |
| `set_data_layer` | mutating | Set data layer | Renames a data layer and/or sets its initial state (${kDataLayerStates.join( |
| `remove_data_layer` | mutating | Remove data layer | Removes a data layer (its Details row × ), by index or name. |
| `set_level_environment` | mutating | Set level environment | Tools → Environment Lighting: sets any of the sun, sky, fog and post-process fields through the Environment Lighting view model (opening its tab; the Sun and SkyAmbience actors are created if missing). |
| `reset_level_environment` | mutating | Reset level environment | Environment Lighting → Reset: every sun, sky, fog and post-process field back to the defaults, as one undo step (opening the Environment Lighting tab). |
| `set_navigation_settings` | mutating | Set navigation settings | Tools → Navigation: the navigation grid's settings through the Navigation view model (opening its tab), clamped to its ranges: ${navFields.map((f) => |
| `build_navigation` | mutating | Build navigation | Build → Build Navigation: runs the real grid bake inside the level's NavMeshBoundsVolume actors (opening the Navigation tab) and returns {walkable_cells, cols, rows, cell_size, obstacle_count, volume_count, duration_ms}. |

## `lib/ui/features/mcp_server/tools/level_tools.dart`

`void registerLevelTools(McpToolRegistry registry, EditorViewModel vm)`

The project and level tools: what the Outliner, the Details panel and the Edit menu let a user do, as MCP tools over the real [EditorViewModel]. Every mutation goes through the view model's own transaction-recording methods, so Edit → Undo reverts it.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `list_actors` | readOnly | List actors | The actors of the open level (the World Outliner), with id, name, type, parent, transform, visibility, lock and selection. |
| `get_actor` | readOnly | Get actor | Everything the editor knows about one actor: transform, mobility, light settings, material, mesh asset path, Blueprint class and its components with their properties. |
| `list_actor_types` | readOnly | List actor types | The actor types spawn_actor accepts (the editor's Place Actors catalog): id, label, category, what placing one does, and whether a level may hold only one. |
| `spawn_actor` | mutating | Spawn actor | Places a new actor of a catalog type (list_actor_types) in the level, optionally named and transformed, as one undo step. |
| `spawn_actor_from_asset` | mutating | Spawn actor from asset | Places a project asset in the level as the Content Browser's "Place in 3D Scene" does: a mesh .lmas becomes a Mesh actor drawing that mesh, a Blueprint .lmas an instance of that class, a landscape .lmas a Landscape actor... |
| `set_actor_transform` | mutating | Set actor transform | Sets an actor's location, rotation and/or scale (absolute values), as typing them into the Details panel does. |
| `set_actor_property` | mutating | Set actor property | Sets one property of an actor, as the Details panel does, in one undo step. |
| `rename_actor` | mutating | Rename actor | Renames an actor or an Outliner folder (type "Folder") as one undo step. |
| `delete_actor` | mutating | Delete actor | Deletes an actor or an Outliner folder (type "Folder") and, by default, its children, as one undo step; undo brings them back with the same ids. |
| `duplicate_actor` | mutating | Duplicate actor | Duplicates an actor and its children (Edit → Duplicate), as one undo step. |
| `select_actors` | editorState | Select actors | Selects actors in the Outliner, viewport and Details panel (replaces the selection unless additive). |
| `clear_selection` | editorState | Clear selection | Deselects every actor. |
| `save_level` | mutating | Save level | Saves the open level (File → Save Level): writes the level .lmas, regenerates the game's Dart code (lib/main.dart, lib/levels/<level>.dart, snake_case) and clears the dirty flag. |

## `lib/ui/features/mcp_server/tools/log_tools.dart`

`void registerLogTools(McpToolRegistry registry, EditorViewModel vm)`

The Output Log as MCP tools: filtered reads with a tail and a cursor, and clear.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `read_output_log` | readOnly | Read output log | The editor's Output Log (engine, import, compile, Play and MCP lines), newest last: [{index, timestamp, level, source, message}]. |
| `clear_output_log` | editorState | Clear output log | Empties the Output Log. |

## `lib/ui/features/mcp_server/tools/maintenance_tools.dart`

`void registerMaintenanceTools(McpToolRegistry registry, EditorViewModel vm)`

Tools → Clear Derived Data Cache as an MCP tool (group `content`).

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `clear_derived_data_cache` | destructive | Clear Derived Data Cache | Tools → Clear Derived Data Cache: empties the project's DerivedDataCache/ (the texture-budgeted GLBs built for oversized assets) and returns what it freed {entries, bytes}. |

## `lib/ui/features/mcp_server/tools/marketplace_tools.dart`

`const String kMcpMarketplaceSignIn`

What every account-bound Marketplace tool says when nobody is signed in: credentials stay with the user.

`void registerMarketplaceTools(McpToolRegistry registry, EditorViewModel vm, McpJobRegistry jobs)`

Window → Marketplace as MCP tools (groups `content` + `plugin`): status, search, a listing's details, Get (Free) and Add to Project / Install as a job, what is installed. There is no sign-in, no sign-out and no uninstall tool, and no call returns a token or session.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `marketplace_status` | readOnly | Marketplace status | The Marketplace server (Editor Preferences → Marketplace Server) and whether the user is signed in (user {username, display_name}). |
| `marketplace_search` | readOnly | Search the Marketplace | Searches the Marketplace catalogue (the window's Browse view): {total, results[{id, title, publisher, category, install_kind, latest_version, licenses, in_library, installed}]}. |
| `marketplace_get_listing` | readOnly | Get Marketplace listing | One listing as its detail page shows it: description, versions, licenses, screenshot URLs, can_install and the install button's label (Add to Project, Install Plugin, …). |
| `marketplace_add_to_library` | external | Add Marketplace listing to library | The listing page's "Get (Free)": adds a free listing to the signed-in user's library on the server. |
| `marketplace_install` | external | Install from the Marketplace | Add to Project / Install Plugin / Install Theme: opens Window → Marketplace and downloads, verifies and installs the listing's latest version as a job (kind marketplace_install; progress follows the download, cancel_job... |
| `marketplace_list_installed` | readOnly | List Marketplace installs | What the Marketplace installed (Window → Marketplace → Installed): {id, title, installed_to, version, install_kind, licenses, license_file}. |

## `lib/ui/features/mcp_server/tools/material_graph_tools.dart`

`void registerMaterialGraphTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The Material editor's node graph as MCP tools: the expression catalog, the graph with typed pins, wires, the output pins the shading model uses and the type checker's diagnostics; node / wire / setting edits through the graph's own editor, each one `MCP: …` step on the graph's stack that regenerates the `.mat` source as a mouse edit does; parameter values, sampler texture bindings and the header settings. The graph and the source tools always agree: a source edit re-parses into the graph when it is next read.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `list_material_nodes` | readOnly | List material nodes | The Material editor's expression catalog: id (pass it as `node` to add_material_node, e.g. |
| `get_material_graph` | readOnly | Get material graph | The material as the Material editor's node graph (opens its tab): nodes (id, node, title, x, y, settings, typed inputs / outputs with their connection state, the sampler and bound texture of texture nodes), wires, the ou... |
| `add_material_node` | mutating | Add material node | Places an expression node at x, y (graph units) with optional `settings` (keys from list_material_nodes: a constant's value, a parameter's name and default, a Texture Sample's sampler `parameter`, …). |
| `connect_material_pins` | mutating | Connect material pins | Wires output from_pin of from_node into input to_pin of to_node (an input keeps one wire: an existing one is replaced). |
| `remove_material_node` | mutating | Remove material node | Deletes a node and its wires. |
| `remove_material_wire` | mutating | Remove material wire | Deletes one wire by id (get_material_graph, or connect_material_pins' result). |
| `set_material_node_setting` | mutating | Set material node setting | Sets one node setting, as the node's Details do: a constant's `value` (number or [2–4 numbers]), a parameter's `name` / `default`, a Texture Sample's sampler `parameter`, a mask's r/g/b/a, a Custom node's code / inputs /... |
| `arrange_material_graph` | mutating | Arrange material graph | The graph toolbar's Arrange: lays the nodes out again, right to left from the output. |
| `set_material_parameter` | mutating | Set material parameter | Sets a declared parameter's value, as the Parameters panel does (the preview follows): a number for float, [2 / 3 / 4 numbers] for float2 / float3 / float4 and colours, a boolean for bool. |
| `set_material_texture` | mutating | Set material texture | Binds a sampler parameter (a Texture Sample's or TextureParameter's sampler) to a texture asset (list_assets type "texture"), as the node's thumbnail picker does; no `texture` clears it. |
| `set_material_settings` | mutating | Set material settings | The Material editor's header settings: shading_model (${shadings.keys.join( |

## `lib/ui/features/mcp_server/tools/material_tools.dart`

`void registerMaterialTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The Material editor as MCP tools: read and set the `.mat` source, compile it with the real filamat compiler, read the issues. Edits go through the material's editor tab (opened when needed), so the code view updates live and the tab's Save writes the `.lmas`.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_material_source` | readOnly | Get material source | The material's .mat source (Filament material definition: a `material { … }` header with shadingModel, blending, parameters, and a `fragment { void material(inout MaterialInputs material) { … } }` body), plus the parsed... |
| `set_material_source` | mutating | Set material source | Replaces the material's .mat source in its editor tab (the code view updates), like typing it. |
| `compile_material` | mutating | Compile material | Compiles the material's current source with the real filamat compiler (the editor's Compile button): ok, compile time, compiled size and issues [{line, severity, message}]. |
| `get_material_issues` | readOnly | Get material issues | The material editor's current issues (syntax checks and the last compile): [{line, severity, message}]. |

## `lib/ui/features/mcp_server/tools/outliner_tools.dart`

`void registerOutlinerTools(McpToolRegistry registry, EditorViewModel vm)`

The World Outliner as MCP tools: folders, Move to Folder, attach (a drop on an actor row), detach and solo — over the view-model methods the Outliner widget calls, each call one undo step. Renaming and deleting a folder are `rename_actor` / `delete_actor` (a folder is an actor of type "Folder").

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `create_folder` | mutating | Create Outliner folder | Outliner → New Folder: a folder (an editor-only grouping node, type "Folder") in the root or in another folder, optionally wrapping actors (they move in and keep their world locations). |
| `move_to_folder` | mutating | Move to folder | The Outliner's "Move to Folder ▸ <folder> / (Root)": moves actors or folders into a folder (or the root when folder_id is omitted), keeping world locations, as one undo step. |
| `attach_actors` | mutating | Attach actors | Attaches actors under another actor, as dropping them on its Outliner row does, in one undo step. |
| `detach_actors` | mutating | Detach actors | Detaches actors from their parent into the root or a folder: the Outliner's "Move to Folder ▸ (Root) / <folder>" (the UI has no separate Detach). |
| `solo_actor` | mutating | Solo actor | Outliner → Solo: hides everything but the actor, its ancestors and its descendants. |
| `clear_solo` | mutating | Clear solo | Outliner → Clear Solo: restores the visibility of every actor exactly as it was before solo_actor. |

## `lib/ui/features/mcp_server/tools/particle_tools.dart`

`void registerParticleTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The Particle editor as MCP tools: the emitter stack (add, duplicate, rename, enable, delete), each emitter's stage values (spawn, lifetime and velocity, forces, timing, over-life curves, render), the preview simulation, Save. The Particle editor has no undo stack (a dirty flag only): these edits are reverted by not saving (the tab's Discard), never by `undo`. The stage setters act on the selected emitter, so every tool selects the emitter it edits first, as a click in the stack would, and says which one it edited.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_particle_system` | readOnly | Get particle system | A particle system as the Particle editor shows it: the simulation backend, the emitter stack [{index, name, enabled, stages: {spawn: {spawn_rate, max_particles, bursts}, lifetime: {lifetime [min, max], speed [min, max],... |
| `add_particle_emitter` | mutating | Add particle emitter | Adds an emitter with the engine defaults at the end of the stack and selects it; a name in use gets a number. |
| `duplicate_particle_emitter` | mutating | Duplicate particle emitter | Copies an emitter below itself ("<name> Copy") and selects the copy. |
| `rename_particle_emitter` | mutating | Rename particle emitter | Renames an emitter. |
| `set_particle_emitter_enabled` | mutating | Enable particle emitter | Enables or disables an emitter (a disabled one is saved but neither previewed nor run). |
| `delete_particle_emitter` | mutating | Delete particle emitter | Deletes an emitter; the last one is kept (a system always has one). |
| `set_particle_emitter` | mutating | Set particle emitter | Sets an emitter's stage values (selecting it first). |
| `add_particle_burst` | mutating | Add particle burst | Adds a burst of `count` particles at `time` seconds into each loop (0 ≤ time < duration, count ≥ 1; otherwise refused and nothing changes). |
| `set_particle_burst` | mutating | Set particle burst | Changes a burst's time and / or count (a rejected value changes nothing). |
| `remove_particle_burst` | mutating | Remove particle burst | Deletes a burst. |
| `add_particle_color_stop` | mutating | Add particle colour stop | Adds a colour-over-life stop at t (0…1 of a particle's life) with [r, g, b, a] 0…1. |
| `set_particle_color_stop` | mutating | Set particle colour stop | Moves a colour stop to t and / or changes its colour (stops re-sort by t). |
| `remove_particle_color_stop` | mutating | Remove particle colour stop | Deletes a colour stop. |
| `add_particle_size_point` | mutating | Add particle size point | Adds a size-over-life point: scale at t (0…1 of a particle's life). |
| `set_particle_size_point` | mutating | Set particle size point | Moves a size point to t and / or changes its scale (points re-sort by t). |
| `remove_particle_size_point` | mutating | Remove particle size point | Deletes a size point. |
| `set_particle_render` | mutating | Set particle render | The Render stage: billboard: true draws the built-in quad; mesh draws each particle as a static mesh asset (list_assets type "filamesh"), saved as a reference of the system. |
| `particle_preview` | editorState | Particle preview | The preview transport over the real engine simulation (fixed seed): "play" / "pause", "step" `frames` ticks of 1/60 s (default 1), "reset" the simulation; sim_speed (0.1…2) scales play. |
| `save_particle_system` | mutating | Save particle system | Writes the particle system .lmas with its mesh references (the tab's Save). |

## `lib/ui/features/mcp_server/tools/physics_asset_tools.dart`

`List<String> mcpNearestNames(String wanted, Iterable<String> names, {int count = 3})`

The bones of [names] closest to [wanted] by edit distance (at most [count]), for a tool error that names what the agent probably meant.

`void registerPhysicsAssetTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The Physics Asset editor as MCP tools: bind a skeletal mesh, add / replace / remove bodies auto-sized to their bones, body primitive and physics properties, constraints and their angular limits, collision disables, the narrow-phase overlap validation, Save. Bodies are centimetres. The editor keeps no undo stack.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_physics_asset` | readOnly | Get physics asset | The Physics Asset editor's document (opens its tab): the bound skeletal mesh and its link error, bones with their parents, bodies (shape, sizes and offsets in cm, mass, damping, physics material), constraints (angular mo... |
| `bind_physics_skeletal_mesh` | mutating | Bind skeletal mesh | The toolbar's Skeletal Mesh picker: binds (or rebinds) the mesh whose bones the bodies follow. |
| `add_physics_body` | mutating | Add physics body | Add Body on a bone: a ${shapes.join( |
| `set_physics_body` | mutating | Set physics body | A body's Details: radius_cm, half_height_cm, extent_cm [x, y, z] (box half extents), offset_location_cm and offset_rotation_deg [x, y, z] relative to the bone, mass_kg, linear_damping, angular_damping, physics_material. |
| `remove_physics_body` | destructive | Remove physics body | Deletes a bone's body and every constraint and disabled pair that referenced it. |
| `add_physics_constraint` | mutating | Add physics constraint | Joins the bodies on bone_a (parent) and bone_b; both must carry a body. |
| `set_physics_constraint` | mutating | Set physics constraint | A constraint's angular mode (${modes.join( |
| `remove_physics_constraint` | destructive | Remove physics constraint | Deletes a constraint. |
| `set_physics_collision_pair` | mutating | Set collision between bodies | Enables or disables collision between the bodies on two bones (the body context menu's Collision → Enable / Disable). |
| `validate_physics_asset` | readOnly | Validate physics asset | The toolbar's Validate: runs the real narrow phase over every body pair in bind pose and lists the overlapping pairs (penetration in cm) and the disabled pairs it skipped, plus the document errors that block Save. |
| `save_physics_asset` | mutating | Save physics asset | The tab's Save: writes the bodies (cm, schema v2), constraints, disabled pairs and the skeletal mesh reference. |

## `lib/ui/features/mcp_server/tools/pie_sequence_tool.dart`

`const int kMcpMaxSequenceSteps`

`pie_sequence`'s step limit (50).

`const int kMcpMaxSequenceScreenshots`

`pie_sequence`'s screenshot limit (10).

`const int kMcpSequenceSettleFrames`

The frames `pie_sequence` steps after starting Play, at most, until the player's pawn exists (30).

`const Duration kMcpSequenceMountTimeout`

How long `pie_sequence` waits for a Play it started to mount (15 s).

`void registerPieSequenceTool( McpToolRegistry registry, EditorViewModel vm, McpPlayTesting play, { required GlobalKey viewportBoundaryKey, })`

A scripted play test in one call: `pie_sequence` starts Play when needed, runs its steps through the play-testing tools' own handlers (`pie_key`, `pie_action`, `pie_axis`, `pie_click`, `pie_mouse_move`, `pie_play_for`, `pie_advance`), captures labelled viewport screenshots and checks light assertions on the player, and returns a per-step log. It stops at the first failing step, releases the keys the calling session holds, and stops a Play it started when a step fails.

Adımlar: `{"key": "W", "hold_ms": 800}` (o kadar oyun süresi basılı tutulan bir tuş, 60 fps kare adımlarıyla), `{"key": "W", "state": "down" | "up"}`, `{"action": "IA_Jump"}`, `{"action": "IA_Move", "value": [0, 1], "hold_ms": 500}`, `{"axis": "MouseX", "value": 40}`, `{"click": {"x": 640, "y": 360}}`, `{"mouse_move": {"dx": 30, "dy": 0}}`, `{"play_ms": 500}` (viewport'ta gerçek zamanlı oynatma), `{"advance_frames": 10}`, `{"screenshot": true}`, `{"expect": {"player_moved": true, "min_distance_cm": 100, "log_contains": "metin"}}`; her adım bir `label` taşıyabilir. Argümanlar: `steps` (zorunlu), `start` (varsayılan true), `stop_at_end` (varsayılan false), `keep_pie_on_error` (varsayılan false), `screenshot_max_width` (varsayılan 1280). Sınırlar (hiçbir şey çalışmadan denetlenir, `-32602`): 50 adım, 10 ekran görüntüsü, toplam 10 000 ms oyun süresi. Dizinin başlattığı Play meshlerini ilk gerçek zamanlı anlarda yükler; ilk ekran görüntüsünden önce `{"play_ms": 1000}` ile başlayın.

Örnek çağrı:

```json
{"name": "pie_sequence", "arguments": {"screenshot_max_width": 1280, "steps": [
  {"play_ms": 1500, "label": "land"},
  {"screenshot": true, "label": "before walking"},
  {"key": "W", "hold_ms": 1000, "label": "walk"},
  {"action": "IA_Jump", "label": "jump"},
  {"advance_frames": 12},
  {"screenshot": true, "label": "after walking and jumping"},
  {"expect": {"player_moved": true, "min_distance_cm": 200}}
]}}
```

Sonuç (içerik: JSON özeti, ardından `Step 1 "before walking": 1280×521 PNG of the viewport, player at [...] cm.` + görüntü, `Step 5 "after walking and jumping": …` + görüntü; `structuredContent` kısaltılmış):

```json
{"ok": true, "started_pie": true, "stopped_pie": false, "released_keys": [],
 "steps": [{"index": 2, "kind": "key", "label": "walk", "ok": true,
            "result": {"key": "KeyW", "action": "tap", "frames": 60, "held_keys": [], "player_location": [...]},
            "player_location": [...], "log": [...]}, "..."],
 "screenshots": [{"step": 1, "label": "before walking", "width": 1280, "height": 521, "player_location": [...]},
                 {"step": 5, "label": "after walking and jumping", "width": 1280, "height": 521, "player_location": [...]}],
 "final_status": {"playing": true, "paused": true, "held_keys": [], "...": "..."}}
```

Başarısız bir adım (örneğin projenin bağlamadığı bir action) diziyi bitirir: `isError: true`, `failed_step`, `error` (`Step 1 (action) failed: No input action "IA_Nope" in this project. Actions and their keys: …`); dizinin başlattığı Play, `keep_pie_on_error` verilmedikçe durdurulur.

**Araçlar:**

| Tool | Risk | Title | Description |
| :--- | :--- | :--- | :--- |
| `pie_sequence` | editorState | Run a scripted play test | A whole play test in one call: starts Play when it is not running, runs up to 50 steps (key, action, axis, click, mouse_move, play_ms, advance_frames, screenshot, expect) and leaves Play paused; returns a per-step log, the screenshots as captioned images and the final pie_status. |

## `lib/ui/features/mcp_server/tools/play_testing_tools.dart`

`const int kMcpMaxAdvanceFrames`

`pie_advance`'s frame limit.

`const int kMcpMaxPlayForMs`

`pie_play_for`'s wall-clock limit.

`List<double> mcpAuthoringRotation(Quaternion q)`

Authoring degrees `[x, y, z]` of a runtime rotation (the inverse of [LuminaAxes.rotation]).

`McpToolResult? mcpPieRefusal(EditorViewModel vm)`

Null while a Play-In-Editor world runs, else the tool error the play-testing tools answer with.

`List<double>? mcpPlayerLocation(EditorViewModel vm)`

Where the possessed pawn is (cm, Z up, rounded to 0.001), or null.

`void registerPlayTestingTools( McpToolRegistry registry, EditorViewModel vm, McpPlayTesting play, { required GlobalKey viewportBoundaryKey, })`

Play-testing tools (group `pie`): keys, axes, mouse and input actions into the running Play-In-Editor game — through the project's own key bindings, so triggers and modifiers run as for a player — a click and typed text into its UMG widgets, frame-exact advance and wall-clock play, and the runtime actors read back.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `pie_key` | editorState | Press a key in Play | A key in the running game, as a player presses it: action "down" holds it (across pie_advance / pie_play_for frames) until "up"; "tap" is down, hold_frames (default 1) advanced frames, then up. |
| `pie_axis` | editorState | Move an analog axis in Play | An analog value for the next frame: key "MouseX" / "MouseY" (pixels of mouse movement), "GamepadLeftStickX" / "GamepadLeftStickY" / right stick / triggers (-1..1). |
| `pie_mouse_move` | editorState | Move the mouse in Play | A relative mouse movement in pixels (dx right, dy down) for the next frame — the game's mouse look, as when the game has captured the mouse. |
| `pie_action` | editorState | Trigger an input action in Play | Fires an input action by pressing the keys the project binds to it (Play's mapping contexts), for hold_frames advanced frames (default 1), then releasing them — so the action's modifiers and triggers run exactly... |
| `pie_click` | editorState | Click in the Play viewport | A pointer down + up at (x, y) viewport pixels (the coordinate space of viewport_screenshot at its natural size): hits the UMG widgets the game added to the viewport (buttons, text fields). |
| `pie_type_text` | editorState | Type into a Play text field | Types text into the focused text field of the game's UMG widgets (click it with pie_click first), at its cursor; submit: true then commits it (Enter: the field's On Text Committed). |
| `pie_advance` | editorState | Advance Play by frames | Frame-exact play-testing: pauses the game if it runs and advances it by frames (1..…) of dt seconds (default 1/60). With `screenshot: true` (here and in `pie_play_for`) the level viewport is brought to the front when a sub-editor tab hides it, and the PNG is taken after its next frames. |
| `pie_play_for` | editorState | Play for a while | Resumes the game, lets the viewport run it for ms of wall-clock time (≤ …), and pauses it again (unless pause_after: false). |
| `pie_get_actors` | readOnly | Runtime actors | The actors of the running game's level: {id (the editor actor id, null for spawned ones), class (the Blueprint class or the native class), native_class, name, location (cm, Z up), rotation (degrees), velocity (cm/s, char... |

## `lib/ui/features/mcp_server/tools/play_tools.dart`

`const String kMcpStandalone`

The key of Play Standalone's one game process.

`void registerPlayTools(McpToolRegistry registry, EditorViewModel vm, {required McpPlayTesting play, required McpJobRegistry jobs})`

Play-In-Editor as MCP tools: start, stop, pause, resume, step, and the session's status, over `requestPlay` and the `PieController`; also eject / possess and Play Standalone as a job.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `pie_status` | readOnly | Play-In-Editor status | Whether Play-In-Editor is running or paused, which pawn class the player possesses and where it is (cm, Z up), the last runtime error, and the Blueprint blockers / warnings of the last Play attempt. |
| `start_pie` | editorState | Start Play-In-Editor | Presses Play: open Blueprints compile first; compile errors keep Play from starting and come back as a tool error listing the Blueprint, node and message. Play runs in the level viewport: an open sub-editor tab gives way to the level tab, and the call returns once the viewport has drawn Play's first frames. |
| `stop_pie` | editorState | Stop Play-In-Editor | Stops Play and restores the editor's level, selection and camera from before Play. |
| `pause_pie` | editorState | Pause Play-In-Editor | Pauses the running game (timers, physics and audio freeze). |
| `resume_pie` | editorState | Resume Play-In-Editor | Resumes a paused game. |
| `step_pie` | editorState | Step Play-In-Editor | Advances the paused game by one frame (1/60 s). |
| `eject_pie` | editorState | Eject from the player | The toolbar's Eject: the game keeps running but takes no input (the editor camera flies instead); keys agents hold are released. |
| `possess_pie` | editorState | Possess the player | Takes the player back after eject_pie: keys, axes and actions reach the game again. |
| `play_standalone` | external | Play Standalone | Debug → Play Standalone as a job: open Blueprints compile (errors are a tool error, as for start_pie), the level is saved and the game code generated, then a real flutter build <host> --debug runs and the game starts as... |
| `stop_standalone` | editorState | Stop Play Standalone | Stops the standalone game (or its build) and cancels its job; returns the standalone status. |
| `standalone_status` | readOnly | Play Standalone status | Play Standalone's state (idle \| building \| running), the game's pid, the last pid and exit code, and the job running it. |

## `lib/ui/features/mcp_server/tools/plugin_tools.dart`

`const String kMcpPluginRestartMessage`

What `set_plugin_enabled` says when a code plugin changed: the editor needs a restart the agent must never trigger (the user owns it).

`void registerPluginTools(McpToolRegistry registry, EditorViewModel vm, McpJobRegistry jobs)`

Edit → Plugins as MCP tools (group `plugin`): list the plugins with their state, enable / disable one (reporting when a restart is needed, never restarting), and File → New Plugin as a job.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `list_plugins` | readOnly | List plugins | The Plugin Manager's list: {name, friendly_name, version, category, origin (engine\|project\|user), enabled, content_only, restart_pending, dependencies, issues}, plus restart_required (a code plugin changed since the edit... |
| `set_plugin_enabled` | mutating | Set plugin enabled | The Plugin Manager's Enabled checkbox: enables (with the dependencies it needs) or disables a plugin; the choice is saved in the .lmproject. |
| `create_plugin` | external | Create plugin | File → New Plugin (the wizard) as a job (kind create_plugin): generates the plugin under the project's plugins/ from a template — blank / editorPanel / importer are Dart packages (the generator runs dart pub get and dart... |

## `lib/ui/features/mcp_server/tools/project_settings_tools.dart`

`LuminaKey mcpKeyNamed(String name, {String argument = 'key'})`

The key an agent names (`W`, `Space`, `KeyW`, `LeftShift`, `MouseX`, `GamepadFaceButtonBottom`), or a `-32602` listing examples.

`String mcpKeyLabel(LuminaKey key)`

What the Project Settings key picker stores as a mapping's `key` label.

`void registerProjectSettingsTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions, McpJobRegistry jobs)`

Project Settings (Edit → Project Settings) as MCP tools (group `settings`): read every category; stage changes on the Project Settings tab's own working copy (the tab shows them, dirty, as if typed); edit the input actions and mapping contexts; the project icon and the web loading logo; Apply & Save or Revert. Only `apply_project_settings` (and `set_widget_library`) write the `.lmproject`, as the tab's Apply does; plugin settings and unknown manifest keys ride along untouched.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_project_settings` | readOnly | Get Project Settings | Every Project Settings category (or one): description, scalability, input (actions; mapping contexts with priority and mappings {action, key, scale, axis, modifiers, triggers}), maps_and_modes (with the accepted values),... |
| `set_project_settings` | mutating | Stage Project Settings | Stages changes on the Project Settings tab (it opens and turns dirty, as if typed); nothing is saved until apply_project_settings. |
| `edit_project_input` | mutating | Edit input actions and mappings | Stages an input edit on the Project Settings tab (Input category). |
| `set_project_icon` | mutating | Set project icon | Stages the project icon: {path} copies an SVG / PNG / JPG / WebP that renders into branding/app_icon.<ext> (an absolute path, or project-relative), {default: true} goes back to the Lumina logo. |
| `set_web_loading_logo` | mutating | Set web loading logo | Stages the web build's loading-screen logo: {path} (PNG, JPG, WebP, SVG, GIF; copied into branding/web_loading_logo.<ext>), {use_project_icon: true} or {none: true}. |
| `apply_project_settings` | mutating | Apply & Save Project Settings | The Project Settings tab's Apply & Save: validates every category and writes the .lmproject (and the app icons / web loading screen when those changed). |
| `revert_project_settings` | mutating | Revert Project Settings | Discards the Project Settings tab's unapplied edits and reloads the .lmproject. |
| `set_widget_library` | external | Set UMG widget library | Switches the game's UMG widget library (shadcn \| flutter) and applies Project Settings as a job (kind project_settings_apply): pubspec.yaml changes, flutter pub get runs (network), every UMG widget is regenerated, and th... |

## `lib/ui/features/mcp_server/tools/selection_tools.dart`

`void registerSelectionTools(McpToolRegistry registry, EditorViewModel vm)`

Editörün o anki seçimi tek bir salt okunur araç olarak (gruplar `level` ve `asset`): seçili level aktörleri (birincil olan Details panelinin konusudur), Content Browser'da seçili asset'ler ve klasör, etkin çalışma alanı sekmesi ve alt editörün kendi seçimi.

`Map<String, Object?> mcpSelectionSnapshot(EditorViewModel vm, {bool includeComponents = true, bool includeProperties = false})`

`get_selection`'ın döndürdüğü seçim; varsayılanlarla `lumina://selection` kaynağı olarak da sunulur. `include_components` (varsayılan true) her aktörün bileşenlerini `{id, type, name, enabled, asset_refs}` listeler; `include_properties` (varsayılan false) her bileşenin tüm Details `properties` alanını (`get_actor`'ın döndürdüğü gibi) ve seçili her graf düğümünün pinlerini ekler.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_selection` | readOnly | Get selection | What the user has selected now: the selected level actors in selection order (id, name, type, transform, mobility, parent, Blueprint class, mesh / material asset paths, components with the assets they reference) with the primary one (the Details panel's subject) marked; the Content Browser's selected assets and current folder; the active workspace tab (the level or a sub-editor and its asset) with the sub-editor's own selection... |

Sonuç: `level {count, primary_actor_id, actors[{id, name, type, primary, location, rotation, scale, mobility, visible, locked, parent{id, name, type}?, blueprint{path, class_name}?, mesh_asset_path, material_path, components[…]}]}`, `content_browser {current_folder, count, primary_asset, assets[{path, name, type, primary}]}`, `active_tab {index, id, title, category, kind: "level" | "sub_editor", asset{path, name, type}?, is_dirty, selection}`, `open_tabs[{index, title, category, asset_path}]`. `selection`, view model'i bir seçim tutan alt editörün kendi seçimidir: Blueprint (`graph`, `selected_node_ids`, `selected_nodes`, `selected_component_id`), Material (`selected_node_ids`, `selected_nodes`), Skeletal Mesh (`bone`, `socket`), Widget (`widget_id`), Animation Blueprint (`state`, `transition`, `variable`), Animation (`clip`, `keyframe_ids`), Blend Space (`sample`), Sequencer (`track_id`, `keys`), Particle (`emitter_index`), Physics Asset (`body_bone`, `constraint`, `bone`), Enumeration (`value_index`), Interface (`function`); aksi halde null.

## `lib/ui/features/mcp_server/tools/sequencer_tools.dart`

`const String kMcpMovieRender`

The job key one movie render holds.

`void registerSequencerTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions, McpJobRegistry jobs)`

The Sequencer as MCP tools: tracks bound to level actors (transform, property, visibility), keys with interpolation and tangents, frame rate, length, playback range and looping, scrubbing (the level preview moves live; `stop_sequence` restores it) and the Movie Render Queue as a long-running job. Every edit goes through the tab's `SequencerViewModel`, one `MCP: …` step on its stack.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_sequence` | readOnly | Get sequence | A Level Sequence as the Sequencer shows it: fps, length_frames, playback_range [start, end], looping, the playhead (current_frame), tracks [{id, actor_id, actor_name, kind, property, missing_actor, channels [{name, keys... |
| `add_sequencer_track` | mutating | Add Sequencer track | Binds a level actor (list_actors id) to a new track (one undo step): "transform" (Location / Rotation / Scale .X/.Y/.Z channels), "property" (one channel named `property`, e.g. |
| `delete_sequencer_track` | mutating | Delete Sequencer track | Deletes a track and its keys (one undo step). |
| `rename_sequencer_track` | mutating | Rename Sequencer track | Renames a track's label (its actor binding is unchanged), one undo step. |
| `rebind_sequencer_track` | mutating | Rebind Sequencer track | Binds a track to another level actor (a missing actor's track is fixed this way), one undo step. |
| `add_sequencer_key` | mutating | Add Sequencer key | Keys a channel at a frame (clamped to the sequence length); a key already on that frame is updated. |
| `move_sequencer_key` | mutating | Move Sequencer key | Moves a key to another frame (clamped to the length; keys re-sort, so its index may change — the result gives the new one). |
| `delete_sequencer_key` | mutating | Delete Sequencer key | Deletes a key (one undo step); later keys move down one index. |
| `set_sequencer_key` | mutating | Set Sequencer key | Edits a key as the curve editor does: its value, interpolation, in / out tangents (value units per frame) and whether the tangents are broken (edited independently). |
| `set_sequence_playback` | mutating | Set sequence playback | The sequence's frame rate (fps > 0; a step on the undo stack), length (frames, at least 10; a step), and the transport's playback range [start, end] and looping (view state of the tab, not saved). |
| `scrub_sequence` | editorState | Scrub sequence | Moves the playhead to a frame; the bound level actors take the evaluated pose at once (the viewport, Outliner and Details show it). |
| `stop_sequence` | editorState | Stop sequence | The transport's Stop: stops playback, returns the playhead to the range start and restores every actor the preview moved to its authored transform. |
| `render_sequence` | mutating | Render sequence | The Movie Render Queue: renders frames start_frame…end_frame (inclusive; default the playback range) offscreen through Filament at width × height (even, 16…4096) and fps (default the sequence's) as a PNG sequence plus re... |
| `save_sequence` | mutating | Save sequence | Writes the Level Sequence .lmas (the tab's Save). |

## `lib/ui/features/mcp_server/tools/skeletal_mesh_tools.dart`

`void registerSkeletalMeshTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The Skeletal Mesh editor as MCP tools: bones and sockets, material slots and their texture bindings, per-bone retargeting, morph-target and RigLogic preview weights, vertex weight sums, Save. The Skeletal Mesh editor has no undo stack (a dirty flag only): these edits are reverted by not saving (the tab's Discard), never by `undo`.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_skeleton` | readOnly | Get skeleton | A skeletal mesh's rig as the Skeletal Mesh editor shows it: bones [{name, parent}] (filtered by a case-insensitive bone_filter), sockets [{name, parent_bone, location, rotation, scale, preview_asset}], per-bone retargeti... |
| `add_skeletal_socket` | mutating | Add skeletal socket | Adds a socket on a bone (at the bone, unrotated, unit scale). |
| `rename_skeletal_socket` | mutating | Rename skeletal socket | Renames a socket; a name in use is refused. |
| `reparent_skeletal_socket` | mutating | Reparent skeletal socket | Moves a socket to another bone; its relative transform is kept. |
| `set_skeletal_socket` | mutating | Set skeletal socket | Sets a socket's relative location, rotation and scale, and the asset previewed on it (a mesh .lmas, project-relative; "" clears it). |
| `remove_skeletal_socket` | mutating | Remove skeletal socket | Deletes a socket. |
| `get_skeletal_material_slots` | readOnly | Get skeletal material slots | The mesh's material slots [{index, name, source_material, material, samplers, textures {param: texture}}] as the Material Slots panel shows them, plus the project's materials and textures to bind. |
| `set_skeletal_material_slot` | mutating | Set skeletal material slot | Binds a material to a slot (the slot's samplers are re-read and the preview recompiles), or clears it when material is omitted or null. |
| `set_skeletal_slot_texture` | mutating | Set skeletal slot texture | Binds a texture to a sampler parameter of the slot's material, or clears the binding when texture is omitted. |
| `set_bone_retargeting` | mutating | Set bone retargeting | A bone's translation retargeting, as the Skeleton tree's menu sets it: ${retargetOptions.join( |
| `set_skeletal_preview_weights` | mutating | Set skeletal preview weights | The Morph Targets and RigLogic panels' sliders: morph weights (0…1) by name, RigLogic control values by name (a DNA the user loaded in the editor), or reset: true to zero both first. |
| `get_vertex_weights` | readOnly | Get vertex weights | The skin weight sum of each given vertex (1.0 when normalised) and its bone influences, as the weight inspector shows them. |
| `save_skeletal_mesh` | mutating | Save skeletal mesh | Writes the skeletal mesh .lmas: sockets, retargeting, morph defaults, material slot and texture bindings (the tab's Save). |

## `lib/ui/features/mcp_server/tools/source_control_tools.dart`

`void registerSourceControlTools(McpToolRegistry registry, EditorViewModel vm)`

Source Control as MCP tools (group `scm`), over the editor's own [SourceControlViewModel] (the status bar, the Content Browser's badges and the commit dialog): status, init, commit, file history, revert and the repo-local identity. Push, pull and branches are not in the editor's UI, so they are not exposed.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `source_control_status` | readOnly | Source control status | git status of the project, as the Source Control status bar and the Content Browser badges show it: {available, is_repo, identity_required, last_error, last_commit, changes[{path, state (modified\|added\|deleted\|renamed\|un... |
| `source_control_init` | mutating | Initialize git repository | Source Control → Initialize Git Repository: git init, the Lumina .gitignore and an initial commit. |
| `source_control_commit` | mutating | Commit | Source Control → Commit: commits exactly `paths` (project-relative, from source_control_status) or, with all: true, every change, with `message`. |
| `source_control_history` | readOnly | File history | Source Control → History of a file (default: the open level): [{hash, abbrev, author, date, subject}], newest first. |
| `source_control_revert` | destructive | Revert file | Source Control → Revert: discards the working-tree changes of one file (git restore); the editor reloads it. |
| `source_control_set_identity` | mutating | Set git identity | The identity form: writes user.name / user.email into this repository's own git config (never the global one) and finishes an initial commit an identity error interrupted. |

## `lib/ui/features/mcp_server/tools/static_mesh_tools.dart`

`void registerStaticMeshTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The Static Mesh editor as MCP tools: stats, LODs (add, remove, ratio, screen size, material overrides, LOD group, forced preview LOD), simple collision (box, sphere, capsule, convex hull, none, complexity, mass, centre of mass) and material slots, then Save. The editor has no undo stack: every edit is the tab's dirty state.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_static_mesh` | readOnly | Get static mesh | The Static Mesh editor's asset (opens its tab): triangles, vertices, UV channels, sections, bounds (cm, Z up), material slots with their bound material, LODs (reduction ratio, screen size, triangles, vertices, material o... |
| `add_static_mesh_lod` | mutating | Add LOD | LOD Settings → Add LOD: a decimated level after the last (at most LOD3), its triangle count measured by the real decimator. |
| `remove_static_mesh_lod` | destructive | Remove LOD | Removes a LOD level (1…3; LOD0 is the source mesh); the ones after it move up. |
| `set_static_mesh_lod` | mutating | Set LOD | A LOD level's reduction ratio (0.05–1, LOD1…3), screen size (strictly between its neighbours' screen sizes) and material overrides {slot name: material asset or null}. |
| `set_static_mesh_lod_group` | mutating | Set LOD group | LOD Group preset (${lodGroups.join( |
| `set_static_mesh_preview_lod` | editorState | Set preview LOD | The viewport's forced LOD: the level to preview, or no level (null) for LOD0 / auto. |
| `set_static_mesh_collision` | mutating | Set collision | Collision → Add simple collision: box, sphere or capsule fitted to the bounds, convex (one hull over the mesh's vertices), or none (removes it); complexity (${complexities.join( |
| `set_static_mesh_material_slot` | mutating | Set material slot | Binds a material asset (list_assets type "filamat") to a material slot by index, as the slot's picker does, or clears it (material null: the mesh's own material shows). |
| `save_static_mesh` | mutating | Save static mesh | The tab's Save: writes LODs, collision (cm, Z up), physics and material slots to the .lmas, keeping the import's payload, thumbnail and other references. |

## `lib/ui/features/mcp_server/tools/texture_tools.dart`

`void registerTextureTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The Texture editor as MCP tools: the texture's size, mip chain and settings, every setting the Details column's selects offer (exactly their values), the mip / channel view, Reimport and Save. The editor has no undo stack: settings are the tab's dirty state.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_texture` | readOnly | Get texture | The Texture editor's asset (opens its tab): size, mip chain, settings (sRGB, group, compression, quality, mip generation, filter, address modes), uncompressed and estimated compressed size in bytes, the source file Reimp... |
| `set_texture_settings` | mutating | Set texture settings | The Details column: srgb, group (Normalmap also turns sRGB off), compression, quality, mip_gen (NoMipmaps keeps one level), filter, address_x / address_y — only the values the selects offer. |
| `set_texture_view` | editorState | Set texture view | What the Texture editor's canvas shows: the mip level and the R / G / B / A channel isolator, or alpha as greyscale. |
| `reimport_texture` | mutating | Reimport texture | The toolbar's Reimport: reads the texture's source file again, rebuilds the mips and the thumbnail and writes the .lmas (with the current settings). |
| `save_texture` | mutating | Save texture | The tab's Save: writes the settings into the .lmas metadata (texture_settings). |

## `lib/ui/features/mcp_server/tools/umg_tools.dart`

`void registerUmgTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions)`

The UMG designer as MCP tools: the palette, the widget tree, add / remove / move / wrap / replace, names and Is Variable, slots, props (textures through the designer's texture binding), designer settings, bound widget events, Save and Compile to `lib/widgets/WBP_<Name>.dart`. Every edit goes through the Widget tab's `UmgEditorViewModel` (opened when needed), so the canvas and hierarchy update live and each call is one `MCP: …` step on the tab's own stack. The widget's graph is edited with the Blueprint tools (`asset` = the Widget Blueprint).

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `list_widget_types` | readOnly | List widget types | The UMG designer's palette: each widget type's id (pass it as `type`), display name, category (panels, common, shadcn), child capacity (none, one, many), the slot kind its children get (canvas, box, overlay, single), def... |
| `get_widget_tree` | readOnly | Get widget tree | A Widget Blueprint as the designer holds it (opens its tab): design resolution, DPI scale, the project's widget library, the tree from the root panel (id, name, field_name, type, is_variable, slot with the fields of its... |
| `add_widget` | mutating | Add widget | Places a new widget, as a drop from the palette does: `type` from list_widget_types under `parent` (at `index`, else last). |
| `remove_widget` | mutating | Remove widget | Deletes a widget and its children (Delete in the hierarchy). |
| `move_widget` | mutating | Move widget | Reparents and / or reorders a widget, as a drag in the hierarchy does: under `parent` at `index` (default last; the same parent reorders). |
| `rename_widget` | mutating | Rename widget | Renames a widget; the name becomes its generated Dart field, so it must make a Dart identifier no other widget uses. |
| `set_widget_is_variable` | mutating | Set widget Is Variable | Is Variable: whether the widget is a member of the Widget Blueprint's graph (Get <Element>, bound events). |
| `set_widget_slot` | mutating | Set widget slot | Edits the widget's slot, as the Details panel's Slot section does. |
| `set_widget_properties` | mutating | Set widget properties | Sets props of a widget, as the Details panel does: `props` {key: value} with keys from the type's default_props (list_widget_types) — text, fontSize, colours as "#RRGGBB" / "#RRGGBBAA", percent, … An Image's `texture` /... |
| `bind_widget_event` | mutating | Bind widget event | The green + beside a Widget Event in Details: makes the widget a variable, records the binding and creates (or finds) the bound "On <Event> (<widget>)" node in the Widget Blueprint's event graph, showing the graph. |
| `unbind_widget_event` | mutating | Unbind widget event | Removes a widget event binding and its bound node from the graph (one step on each stack it touches). |
| `set_widget_designer` | editorState | Set widget designer | The designer's view: the simulated screen `resolution` (a preset label or "<w>x<h>": ${UmgResolution.presets.map((r) => r.key).join( |
| `save_widget` | mutating | Save widget | Writes the Widget Blueprint's .lmas (tree, graph, designer settings, texture references) — the tab's Save. |
| `compile_widget` | mutating | Compile widget | The designer's Compile: saves the .lmas, checks the tree for the project's widget library and the graph, then writes lib/widgets/wbp_<name>.dart (snake_case; it writes both files). |

## `lib/ui/features/mcp_server/tools/view_tools.dart`

`void registerViewTools( McpToolRegistry registry, EditorViewModel vm, { required GlobalKey viewportBoundaryKey, required GlobalKey editorBoundaryKey, required McpEditorSessions sessions, required GlobalKey Function(String tabId) subEditorBoundaryKeyFor, })`

The level viewport as MCP tools: a screenshot of the viewport or the whole editor window as MCP image content, and the camera (orbit yaw / pitch / distance / target, ortho modes, view mode, focus, frame), plus `asset_editor_screenshot`: an asset's sub-editor tab (UMG designer, material graph, …) as MCP image content.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `viewport_screenshot` | readOnly | Viewport screenshot | A PNG of the level viewport (default) or of the whole editor window, as it is on screen right now (Filament render included), returned as MCP image content plus a text line with its size and the camera. |
| `asset_editor_screenshot` | readOnly | Asset editor screenshot | A PNG of an asset's editor tab as it is on screen (the UMG designer or graph, the Material editor's graph, code and preview sphere, the Anim Blueprint, Blend Space, Animation, Skeletal Mesh, Sequencer and Particle editor... |
| `select_tab` | editorState | Select workspace tab | Shows a workspace tab: 0 is the level (viewport, Outliner, Details), 1… the open sub-editors (open_asset_editor returns them). |
| `get_camera` | readOnly | Get camera | The level viewport's camera: mode (Perspective or an ortho view), orbit yaw and pitch in degrees, distance in cm from the target, the orbit target [x, y, z] in cm (authoring space), the view mode (Lit / Unlit / Wireframe... |
| `set_camera` | editorState | Set camera | Moves the level viewport's camera: any of yaw, pitch (degrees), distance (cm), target [x, y, z] (cm), mode (${cameraModes.join( |
| `focus_actor` | editorState | Focus actor | Points the camera at an actor and frames it (the F key), selecting it. |
| `frame_level` | editorState | Frame level | Pulls the camera back to hold the whole level. |

## `lib/ui/features/mcp_server/tools/viewport_settings_tools.dart`

`const List<String> kMcpShowFlags`

The six show flags the viewport toolbar's Show menu toggles.

`const List<String> kMcpBufferVisualizations`

The buffers the toolbar's Buffer Visualization menu offers.

`const List<String> kMcpQualityPresets`

The quality presets of the viewport's quality popover.

`void registerViewportSettingsTools(McpToolRegistry registry, EditorViewModel vm)`

The viewport toolbar as MCP tools: snapping and the grid, show flags, buffer visualisation and render quality. These are editor settings, not level content: no undo step, persisted with the project's editor viewport / quality settings exactly as the toolbar persists them.

**Araçlar:**

| Araç | Risk | Başlık | Açıklama |
| :--- | :--- | :--- | :--- |
| `get_viewport_settings` | readOnly | Get viewport settings | The viewport toolbar's settings: snapping (translate / rotate / scale enabled and step), grid_visible and grid_step (cm), the six show flags, view_mode, buffer_visualization, the camera speed level (1–8) and quality (pre... |
| `set_viewport_snapping` | editorState | Set viewport snapping | The toolbar's snap toggles, step menus and grid button. |
| `set_show_flags` | editorState | Set show flags | The toolbar's Show menu: turns show flags on or off (${kMcpShowFlags.join( |
| `set_buffer_visualization` | editorState | Set buffer visualization | View mode → Buffer Visualization: shows one G-buffer channel (${kMcpBufferVisualizations.join( |
| `set_viewport_quality` | editorState | Set viewport quality | The viewport's quality popover: preset (${kMcpQualityPresets.join( |

---

[Önceki: MCP sunucusu](mcp-server.md) | [Üst: lumina_ui (Lumina Studio)](index.md) | [Sonraki: Windows paketleme](windows-packaging.md)
