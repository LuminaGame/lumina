---
name: create-plugin
description: Create a Lumina Studio editor plugin end to end — generate the package with the plugin template generator (in process, or isolated in its own process), register contributions through lumina_editor_api (menu commands, importers, asset types + sub-editor tabs, panels, details customizations, level actors), depend on lumina runtime types without touching lumina_ui internals, install it by symlink into ~/.local/share/lumina/plugins, enable it in the Plugin Manager, and test it (unit + host integration + smoke). Use when the user asks to write, scaffold, extend or install a Lumina plugin, or asks how the plugin API works. lumina_plugin_pcg is the worked example.
---

# create-plugin — write a Lumina Studio plugin

A Lumina plugin is a **source-level Dart package**: the editor discovers it from a `<name>.lmplugin` manifest, and enabling it in the Plugin Manager patches the host's `pubspec.yaml` and `lib/generated/plugin_registrar.dart`, which statically imports the plugin and calls `register()` at the next editor boot. No runtime loading, no reflection. The reference example is `lumina_plugin_pcg` in the [LuminaGame/plugins](https://github.com/LuminaGame/plugins) repo (Procedural Content Generation); read it alongside this skill.

Rules that apply: shadcn_flutter only (never Material), no mock data, every button works, atomic commit per task, PNG + ≥10 s video smoke evidence for editor-visible features, mandatory try-catch around all FFI/native calls with crash reporting via `reportCrash` / `LuminaPluginCrashReporter.reportCrash`.

## 1. Generate the package

**From the editor**: Plugins → **New Plugin...** → pick a template (Blank / Content-only / Editor panel / Importer), optionally isolated (see section 10), name it (`^[a-z][a-z0-9_]*$`, ≤ 64, not a Dart keyword or `flutter`/`lumina`/`lumina_ui`/`lumina_editor_api`/`test`), Create. The wizard runs `flutter create --template=package`, writes the files below, then `dart pub get` + `dart analyze --fatal-infos`; any failure rolls the directory back. The package lands in `<project>/plugins/<name>/`.

**From a script**: `PluginTemplateGeneratorService(projectRoot:, editorApiRoot:).generate(PluginTemplateSpec(templateType:, name:, friendlyName:, author:, description:, category:, isolated:))` in `lumina/lib/data/services/plugin_template_generator_service.dart`. It cannot run under plain `dart run` (`package:lumina` pulls Flutter in); call it from a Flutter test or the editor. For a standalone package (like `lumina_plugin_pcg`, a workspace sibling), run `flutter create --template=package --project-name <name> <dir>` yourself and write the same files:

```
<name>/
  <name>.lmplugin            # manifest — basename MUST equal "name"
  pubspec.yaml               # lumina_editor_api (+ lumina) path deps, shadcn_flutter pinned (0.0.55 = kHostShadcnFlutterVersion)
  lib/<name>.dart            # `library; export 'src/<name>_plugin.dart';`
  lib/src/<name>_plugin.dart # class <PascalName>Plugin extends LuminaEditorPlugin
  resources/icon128.png      # 128×128 PNG shown in the Plugin Manager
  test/<name>_plugin_test.dart
  README.md · CHANGELOG.md · analysis_options.yaml · .gitignore · .metadata
```

With `isolated: true` the generator also writes `lib/src/<name>_process.dart` (`<PascalName>Process extends LuminaPluginProcess`), `test/<name>_process_test.dart`, exports both halves from `lib/<name>.dart`, and sets `"isolation": "process"` + `"process_class": "<PascalName>Process"` in the manifest (section 10).

Manifest fields (`lumina_core/lib/src/formats/lumina_plugin_descriptor.dart`): `name`, `friendly_name`, `version` (semver), `description`, `category`, `authors[]`, `engine_version` (constraint, e.g. `">=0.0.1 <1.0.0"`), `can_contain_content` (true + `content/` dir = content-only plugin, no restart), `dependencies[{name, version}]`, `modules[{name, type: editor|runtime, entry_library: "lib/<name>.dart", registration_class: "<PascalName>Plugin"}]`. `isolation` (`"in_process"`, the default, or `"process"`) and, on the editor module, `process_class` (the `LuminaPluginProcess` subclass in the same `entry_library`; required when `isolation` is `"process"`, else the manifest is a scan error in the Plugin Manager). `registration_class` and `process_class` become literal source in the registrar: a typo fails the host's next analyze, which is intended.

## 2. Depend on the API, never on lumina_ui

```yaml
dependencies:
  lumina_editor_api:     {path: ../lumina_editor_api}      # the plugin API, Flutter side (host ↔ plugin cycle breaker)
  lumina_plugin_process: {path: ../lumina_plugin_process}  # isolated plugins: the pure-Dart process API
  lumina_core:           {path: ../lumina_core}            # pure formats and services: LuminaAsset, AssetType, LuminaProject, GlbReader, LandscapeData …
  shadcn_flutter: 0.0.55                                    # exact host version
```

(Generated plugins take them as git dependencies of the lumina repo, `path: <package>`, with a gitignored `pubspec_overrides.yaml` pointing at a local checkout.) Import the narrowest package that has what you use:

| Package | Import | For |
|---|---|---|
| `lumina_core` (pure Dart) | `package:lumina_core/lumina_core.dart` | `.lmas` / `.lmproject` / level / plugin formats, `PluginRepository`, `EngineLoggerService`, `LuminaWorkspace`, `LuminaDataDir`, units and axes, `GlbReader`, observables |
| `lumina_plugin_process` (pure Dart) | `package:lumina_plugin_process/lumina_plugin_process.dart` | a process part: `LuminaPluginProcess`, `PluginProcessContext`, MCP types, `PluginStorage`, `PluginDownloader`, `kCustomAssetTypeKey` |
| `lumina` (engine, Flutter package without widgets) | `package:lumina/lumina.dart` | actors, components, the world, materials: only when you use engine types |
| `lumina_widgets` | `package:lumina_widgets/lumina_widgets.dart` | `LuminaGameWidget`, UMG and media widgets in a shell |
| `lumina_editor_data` | `package:lumina_editor_data/lumina_editor.dart` (umbrella: core + engine + editor data + widgets) | the asset repository, `GlbParserService` (Filament's Draco decoder), importers, codegen |
| `lumina_editor_api` | `package:lumina_editor_api/lumina_editor_api.dart` | the shell: `LuminaEditorPlugin`, panels, `EditorAssetPicker`, `PluginProcessChannel` (re-exports `lumina_plugin_process`) |

Never `package:lumina/data/...` or `package:lumina/src/...` (those paths are gone), and never `package:lumina_ui/...`: it does not resolve from a plugin and would recreate the pub cycle. Everything editor-side reaches you through `LuminaEditorContext` / `LuminaEditorHostContext` (`lumina_editor_api/lib/src/api_types.dart`, `editor_level.dart`). Inside the plugin, import its own files by `package:<name>/...` URI, never by a relative path (enable `always_use_package_imports` in `analysis_options.yaml`).

## 3. Register contributions

```dart
class MyToolsPlugin extends LuminaEditorPlugin {
  EditorLevelAccess? _level;                 // null under a bare (test) context
  @override String get pluginName => 'my_tools';
  @override
  void register(LuminaEditorContext context) {
    if (context is LuminaEditorHostContext) _level = context.level;
    context.registerMenuItem('Plugins/My Tools/Do Thing', EditorCommand(
      id: 'tools.my_tools.doThing', label: 'Do Thing', icon: LucideIcons.sparkles,
      canExecute: () => _level != null, execute: (ctx) => _doThing(ctx)),
      options: const EditorMenuItemOptions(section: 'run'));
  }
}
```

One minimal example per extension point, with how the host routes it, is in `reference/extension_points.md`. Summary:

| Point | Registrar | Where it shows |
|---|---|---|
| Menu | `registerMenuItem('Plugins/<Group>/<Item>', EditorCommand, options: EditorMenuItemOptions(order:, section:, checked:))` | the **Plugins** menu, one submenu per group, nested to any depth |
| Own menu | `registerMenu(EditorMenuDescriptor(id:, title:, placement:))` + `registerMenuItem('<title>/…', cmd)` | a top-level menu after Plugins (`beforeWindow`) or before Help (`beforeHelp`); at most 3 plugin menus, the rest fold into Plugins ▸ `<title>` |
| Slot button | `registerSlotButton(EditorSlotButton(id:, slot:, state: ValueNotifier(EditorButtonState(...)), command:, menu:))` | a named slot: right of Blueprints, toolbar end, status bar left / right; label, tone, active, badge, busy follow the notifier (legacy `registerToolbarButton` → `group` names the slot, else toolbar end) |
| Panel | `registerPanel(EditorPanelDescriptor)` | a bottom-panel tab, or the right dock for `PanelDefaultDock.right`; a checked Window-menu row |
| Asset type | `registerAssetType(EditorAssetTypeHandler(customTypeId:, editorFactory:))` | an `.lmas` with `metadata.custom_type == customTypeId` double-clicks into `editorFactory` as a sub-editor tab; the host sets `metadata.asset_path` |
| Importer | `registerImporter(EditorImporter(extensions:, import:))` | import pipeline / drag-drop for those extensions |
| Details | `registerDetailsCustomization(DetailsCustomization(targetTypeId: '<ActorType>', builder:))` | a section in Details for that actor type; `DetailsTarget.target` is an `EditorActorSnapshot`, `setProperty('<Component>.<prop>' \| name \| location \| rotation \| scale, v)` is undoable |
| Console | `registerConsoleCommand(name, help, handler)` | Output Log input |
| Panels | `context.panels` (`EditorPanels`: show / hide / toggle / `visibility(id)`) | `PanelDefaultDock.right` panels live in the right dock (closed until shown); others are bottom tabs; each gets a checked Window-menu row |
| MCP | `context.mcp` (`EditorMcp`: `registerTool`, `listTools`, `callTool`, `calls`) | tools named `<plugin>.<name>`, visible to external agents over HTTP too; in-process calls pass the same approval chain and undo attribution |
| Storage | `context.storage` (`PluginStorage.readJson` / `writeJson`, `project: true` for the open project) | `~/.local/share/lumina/plugin_data/<plugin>/` and `<project>/.lumina/plugins/<plugin>/`, atomic |
| Lifecycle | override `onProjectOpened`, `onProjectClosing`, `onEditorShutdown`, `unregister` | called by the host on open / Exit Studio / window close / restart, each bounded by a timeout; **extend** `LuminaEditorPlugin` (not `implements`) to inherit the no-op defaults. A crash runs no hook: guard child processes (pid files) |
| Level | `context.level` (`EditorLevelAccess`; `runTransaction(label, body)` groups edits into one undo step) | `actors` snapshots (cm, Z up), `addActors` / `removeActors` / `setComponentProperty` (one undo entry each), `selectActors`, `saveLevel`, `openAssetEditor`, `log` |

**Custom actors**: a plugin actor is any `type` string plus components with a `properties` map (`EditorActorSpec(type: 'PcgVolume', components: [EditorComponentSpec(type: 'LuminaPcgComponent', properties: {...})])`). Unknown types generate as an empty `LuminaSceneComponent` actor and PIE ignores them; give the game real geometry by spawning ordinary `StaticMesh` actors with an absolute `meshAssetPath` (see `PcgVolumeService.generate`). Codegen/PIE ignore `parentId` — store world positions.

**Custom assets**: write a `LuminaAsset(type: AssetType.unknown, rawPayload: <your bytes>, metadata: {kCustomAssetTypeKey: '<id>'})` with `toProtoBufferBytes()` under `<project>/contents/…/<Name>.lmas` (see `PcgGraphAsset`). The Content Browser lists it; your `editorFactory` edits it and writes it back to `asset.metadata[kAssetPathMetadataKey]`.

## 4. Install, enable, restart

Scan roots (priority project > user > engine): `<project>/plugins/`, `~/.local/share/lumina/plugins/`, `$LUMINA_ENGINE_ROOT` (default `<cwd>/../plugins`). Development install of a workspace checkout:

```bash
mkdir -p ~/.local/share/lumina/plugins
ln -s /path/to/plugins/lumina_plugin_pcg ~/.local/share/lumina/plugins/lumina_plugin_pcg
```

Then Plugins → Plugin Manager... → toggle the switch → the restart banner appears (code plugins) → restart the editor (`flutter run` again). Check `lumina_ui/pubspec.yaml`'s `# BEGIN LUMINA PLUGINS` block and `lib/generated/plugin_registrar.dart` name your class. Content-only plugins mount `content/` live, no restart. Disable removes the block; a plugin others depend on asks for cascade.

**Uninstall**: select the plugin in the Plugin Manager → **Remove** (user and project plugins; built-ins cannot be removed). The dialog lists what is deleted first. A linked development install (the symlink above, or a Windows junction from `mklink /J`) is removed as a link only: your checkout keeps every file. An enabled plugin is disabled in the project (with the plugins that depend on it) and the editor host rebuilt on restart; its saved data (`plugin_data/<name>/`, `<project>/.lumina/plugins/<name>/`) is deleted only when you tick the box. Agents use `remove_plugin` (`dry_run: true` first).

## 5. Test it

- **Package unit tests** (`flutter test` in the plugin): pure logic + a registration test against a bare `extends LuminaEditorContext` double (the wizard ships one; an isolated plugin also gets a recording `PluginProcessContext` for its process part) and, for level features, a `LuminaEditorHostContext` double whose `EditorLevelAccess` keeps actors in memory and writes a real `.lmas` on `saveLevel` (`lumina_plugin_pcg/test/test_support.dart` `FileLevel`). Use real assets from the `test-assets` checkout ([LuminaGame/test-assets](https://github.com/LuminaGame/test-assets)) (copy into a temp project's `contents/`).
- **Host integration test** (lumina_ui `integration_test/<name>_flow_test.dart`): add the plugin as a **dev** dependency of lumina_ui, symlink it into a temp project's `plugins/`, assert `vm.pluginRegistry.entries` discovers it, then `vm.extensionRegistry.beginRegistration(name); plugin.register(vm.extensionRegistry); endRegistration()` (exactly what the registrar does after a restart) and drive the commands; assert on disk. Never call `vm.enablePlugin` in tests — it patches the real host pubspec.
- **Smoke** (`integration_test/smoke/plugins_smoke_test.dart`): boot `MainEditorView` in a `RepaintBoundary`, `SmokeRecorder` for ≥10 s at ≥1024×768/30 fps, drive the real menu and Details buttons, `SmokeArtifacts.saveScreenshot` + `rec.save`. Run on GPU 1 in the batch (`tool/ci.sh --smoke lumina_ui`).
- Widget tests of your panels: `ShadcnApp(theme: ThemeData(colorScheme: ColorSchemes.darkZinc, radius: 0.5), home: Scaffold(child: …))`.

## 6. Version and ship

`version` in both `pubspec.yaml` and the manifest; a `CHANGELOG.md` entry per release; bump the manifest `engine_version` when you rely on a newer API (the Plugin Manager shows a failing constraint badge and disables the switch). One repo per plugin, `git init`, commit the initial generated shape first, then the feature.

## 7. Pitfalls (from building lumina_plugin_pcg)

- `implements LuminaEditorContext` must implement **every** member, so a new member breaks every test double: `extends LuminaEditorContext` inherits the members that have a default (`saveAsset`, `processChannel`, `reportCrash`); prefer `LuminaEditorHostContext` for new host capabilities (that is why the level lives there). Adding `registerMenu` and the `options` parameter of `registerMenuItem` to `LuminaEditorContext` itself meant updating the doubles (the wizard's generated test, lumina_plugin_pcg's test, lumina_editor_api's contract test).
- `LuminaAsset` has no path: the host puts the absolute `.lmas` path in `metadata[kAssetPathMetadataKey]` only for `editorFactory`; elsewhere resolve paths yourself against `level.projectDirPath`.
- Units: the level is cm, Z up; `LandscapeData` is metres, Y up, centred on its actor; glTF meshes are metres and the viewport scales them ×100. `PcgLandscapeSurface` shows the mapping.
- `meshAssetPath` must be absolute and the file must exist, or the instance draws nothing and codegen emits a bare scene actor.
- `Select<T>` in shadcn 0.0.55: `popup: SelectPopup(items: SelectItemList(children: [SelectItemButton(value:, child:)])).call`, `itemBuilder: (context, v) => …`; `ColorSchemes.darkZinc` is a value, not a function.
- The wizard pins `shadcn_flutter: 0.0.55`; a `^` range can resolve a different copy than the host and break `showOverlay`.
- Menu path rules (enforced by the host registry): `Plugins/<Group>/…` or `<your registered menu title>/…` only. `File/`, `Edit/`, `View/`, `Build/`, `Debug/`, `Window/`, `Help/` (and another plugin's menu) reject the item with an `invalidMenuPath` issue on your Plugin Manager row and an Output Log error; a title equal to a built-in or another plugin's menu is a `menuConflict`. Legacy `Tools/<Group>/…` still works (moved to `Plugins/<Group>/…`) with one deprecation warning.
- `dart analyze` from the plugin dir is the cheap check; `flutter test` needs the batch (one test process at a time on this machine).

## 8. FFI and Native Calls: Mandatory Try-Catch & Crash Reporting

When a plugin makes FFI or native C/C++ calls:
1. **Always wrap native calls in `try-catch`**:
   ```dart
   try {
     final result = nativeBinding.computeData(ptr);
   } catch (error, stack) {
     // Report the crash attributed to this plugin so Lumina Studio can display the crash dialog gracefully
     reportCrash(error, stack, context: 'computing PCG native mesh buffer');
   }
   ```
2. **Crash reporting API**:
   - `LuminaEditorPlugin.reportCrash(error, stack, context: '...')`: Available directly within your plugin class.
   - `LuminaPluginCrashReporter.reportCrash(error, stack, plugin: '<pluginName>', context: '...')`: Available anywhere (services, workers, FFI wrappers) through `package:lumina_editor_api/lumina_editor_api.dart`.
   - `context.reportCrash(error, stack, plugin: '<pluginName>', context: '...')`: Available via `LuminaEditorContext`.

## 9. Asset Selection: Mandatory EditorAssetPicker

Whenever your plugin prompts or allows the user to select an asset (e.g. static mesh, skeletal mesh, material, texture, animation, audio, actor blueprint), you **MUST** use `EditorAssetPicker` from `package:lumina_editor_api/lumina_editor_api.dart`. Never use raw text fields, generic file dialogs, or custom dropdowns for selecting assets.

### Usage Example:
```dart
import 'package:lumina_core/lumina_core.dart' show AssetType;
import 'package:lumina_editor_api/lumina_editor_api.dart';

Widget buildMeshSelector(LuminaEditorHostContext hostContext, String? currentPath, ValueChanged<String?> onChanged) {
  return EditorAssetPicker(
    hostContext: hostContext,
    selectedPath: currentPath,
    typeFilter: const {AssetType.filamesh, AssetType.filameshSk},
    placeholder: 'Select Mesh...',
    allowClear: true,
    expand: true,
    onSelected: onChanged,
  );
}
```
`EditorAssetPicker` delegates directly to `LuminaEditorHostContext.buildAssetPicker` to provide the unified searchable asset catalog, live thumbnail rendering, clear action, and type filtering.

## 10. Isolated plugins: a process part and a UI shell

A plugin with `"isolation": "process"` runs its risky half in **its own process**: the editor starts its own executable again with `--lumina-plugin-process <name>`, supervises it (health ping every 2 s, three missed = hung → restart; automatic restarts 1 s / 2 s / 4 s, at most three) and files a `plugin_crash` report when it dies. The editor keeps running when the plugin hangs, leaks or crashes natively.

| Half | Class | Lives in | What belongs there |
|---|---|---|---|
| Process part | `<PascalName>Process extends LuminaPluginProcess` (manifest `process_class`) | the plugin process | everything that can crash, hang or block: FFI / native libraries, `Process.start` child processes, network, heavy CPU (still inside `Isolate.run`, so the health ping answers), file generation, level edits (proxied to the editor as undoable transactions), MCP tools, importers, menu commands that do work |
| UI shell | `<PascalName>Plugin extends LuminaEditorPlugin` (manifest `registration_class`) | the editor | panels, tabs, asset editors with full shadcn widgets, 3D viewports. It holds **no** native library, starts **no** process and does **no** heavy work |

**Process side** (`PluginProcessContext`, everything crosses as data): `handle(method, handler)` answers the shell; `emit(name, data)` sends it events; `progress(task, step:, done:, total:, finished:)` reports long jobs; `log`; `registerMenuItem(path, PluginProcessCommand(id:, label:, run:))`, `registerSlotButton`, `registerImporter(PluginProcessImporter)`, `registerMcpTool`, `registerConsoleCommand`; `registerViewPanel(PluginProcessViewPanel(id:, title:, initial: PluginViewSpec, onEvent: (event, view) => view.patch(...)))` for a declarative panel the editor renders itself (no shell needed); `level` (proxied `PluginLevelAccess`: the `EditorLevelAccess` operations, `changes` a pure `ChangeSignal`), `storage`, `pluginSettings` (`Observable`), `saveAsset`, `showPanel` / `hidePanel` / `openTab`, `callMcpTool`. Lifecycle: `register`, `onProjectOpened`, `onProjectClosing` (bounded), `onShutdown` (stop child processes, free native resources).

The process side is the **pure-Dart package `package:lumina_plugin_process`** (no Flutter, `dart:ui` or FFI; `lumina_editor_api` re-exports all of it, so importing `lumina_editor_api.dart` keeps working). Live values are `lumina_core`'s `Observable` / `ObservableValue` / `ChangeSignal` (same `value` / `addListener` / `removeListener` as Flutter's): a slot button's `state` is an `ObservableValue<PluginButtonStateSpec>`, a menu item's `checked` an `Observable<bool>`; from Flutter code adapt with `notifier.asObservable()` / `observable.asValueListenable()`. Icons cross as `PluginIconSpec` (`pluginIconOf(IconData)` is the Flutter helper). A process part that imports only `lumina_plugin_process` + `lumina_core` (+ its own FFI package) is Flutter-free and its tests run with `dart test` against `package:lumina_plugin_process/testing.dart`'s `LoopbackHost` (see that package's `example/pure_process.dart` and `test/two_process_test.dart`).

**Keep the process part pure.** Its library (the one declaring `process_class`) and the plugin libraries it imports use `lumina_plugin_process` + `lumina_core` (+ the plugin's own FFI package and pure pub packages), not `lumina_editor_api`, `shadcn_flutter` or `package:flutter/...`: icons as `PluginIconSpec(codePoint, fontFamily: 'LucideIcons', fontPackage: 'shadcn_flutter')`, `ChangeEmitter` / `ObservableValue` instead of `ChangeNotifier` / `ValueNotifier`, `Isolate.run` instead of `compute`, `EngineLoggerService` instead of `debugPrint`, data models in files of their own (a model file that imports shadcn for an icon drags Flutter in). `test/architecture/process_part_reach_test.dart` (generated with every isolated plugin) records it: `PluginProcessReach.ofPlugin(Directory.current)` walks the process part's imports through the plugin's package config; `allowed` lists the packages it imports directly, `flutterBound` the ones among them that tie it to Flutter, each with the reason (for example the engine, or `lumina_editor_data`'s Draco-decoding `GlbParserService`). An empty `flutterBound` means the process part could run as a plain `dart` program.

**Shell side** (`PluginProcessChannel`, from `context.processChannel(pluginName)` in `register`): `call(method, args, timeout)` (30 s default; long jobs answer early and report progress), `events([name])`, `progress`, `state` (`PluginProcessState`: starting / running / hung / crashed / stopped / inProcess / disabled) and `restart()`. A failed call throws `PluginRemoteError` (`code`: `unavailable`, `timeout`, or the handler's error); while the process is not running the editor covers the shell's panels with its state and a Restart button, so the shell only handles its own calls' errors.

```dart
// lib/src/my_tools_process.dart: runs in the plugin process
class MyToolsProcess extends LuminaPluginProcess {
  @override String get pluginName => 'my_tools';
  @override
  void register(PluginProcessContext context) {
    context.handle('bake', (args) async {
      final out = await Isolate.run(() => heavyBake(args['seed'] as int)); // or FFI, or Process.start
      return {'path': out};
    });
  }
}
// lib/src/my_tools_plugin.dart: the in-editor shell
class MyToolsPlugin extends LuminaEditorPlugin {
  @override String get pluginName => 'my_tools';
  @override
  void register(LuminaEditorContext context) {
    final channel = context.processChannel(pluginName);
    context.registerPanel(EditorPanelDescriptor(id: 'panel.my_tools', title: 'My Tools',
        builder: (_) => MyToolsPanel(channel: channel)));   // calls channel.call('bake', {'seed': 1})
  }
}
```

A plugin that is all data (menus, MCP tools, importers, storage, level access) needs no shell: `PluginProcessAdapter` runs an unchanged data-only `LuminaEditorPlugin` inside the process. A project forces an isolated plugin in process for debugging with `.lmproject` `"plugin_isolation": {"my_tools": "in_process"}` (Plugin Manager): the same process part runs inside the editor, over an in-memory connection. The registrar (`kPluginProcesses` in `plugin_registrar.dart`) lists every enabled plugin whose manifest says `process`, so one editor build serves both. Test the process part through a recording `PluginProcessContext` (the generated `test/<name>_process_test.dart`: `LoopbackHost.start()` + `runPluginProcessMain`, a real loopback socket; Flutter tests import `package:lumina_editor_api/testing.dart`, whose host adds `host.channel`, pure ones `package:lumina_plugin_process/testing.dart` with `host.link`) and the shell's panel with `PluginProcessChannel.detached(name)` (every call fails with `unavailable`). Extension-point examples: `reference/extension_points.md` ▸ *Process part*.
