[Türkçe](../../tr/plugins/index.md)

# Editor plugins

Lumina Studio can be extended with plugins: Flutter packages that register menu items, panels, toolbar buttons, asset types, importers, details customizations and console commands through `lumina_editor_api`. This page explains how the pieces fit together.

## The pieces

| Piece | Package | Role |
|---|---|---|
| `LuminaEditorPlugin`, `LuminaEditorContext` and the extension types | `lumina_editor_api` | The contract a plugin is written against ([API reference](../lumina_editor_api/api-reference.md)). |
| `LuminaPluginDescriptor`, `PluginRepository` | `lumina_core` | Parse `.lmplugin` manifests and scan the plugin roots ([models and repositories](../lumina_editor_data/repositories.md)). |
| `PluginRegistryService`, `PluginTemplateGeneratorService`, `PluginHostPatcherService` | `lumina_editor_data` (`PluginHostPatcherService`: `lumina_core`) | Resolve which plugins are enabled, generate new plugins from templates and compile code plugins into an editor host ([use cases and services](../lumina_editor_data/services.md)). |
| `PluginExtensionRegistry`, `BuiltInEditorPlugin` | `lumina_ui` | Collect everything plugins register and show it in the editor ([App shell and shared UI](../lumina_ui/core.md)). |
| Plugin Manager, New Plugin wizard | `lumina_ui` | Enable, disable and create plugins ([Plugin manager](../lumina_ui/plugin-manager.md)). |

`lumina_editor_api` exposes the shared formats, plugin process/protocol and game widgets through the split engine packages. A plugin never depends on `lumina_ui`, which would create a cycle between the editor and its plugins.

## Anatomy of a plugin

A plugin is a Flutter package with a `<name>.lmplugin` manifest next to its `pubspec.yaml`:

```json
{
  "name": "lumina_plugin_pcg",
  "friendly_name": "Procedural Content Generation",
  "version": "0.1.0",
  "category": "Procedural",
  "license": "MIT",
  "changelog": "CHANGELOG.md",
  "engine_version": ">=0.0.1 <1.0.0",
  "modules": [
    {
      "name": "lumina_plugin_pcg",
      "type": "editor",
      "entry_library": "lib/lumina_plugin_pcg.dart",
      "registration_class": "LuminaPluginPcgPlugin"
    }
  ]
}
```

The manifest maps onto `LuminaPluginDescriptor`: name, friendly name, version, description, category, authors, the supported engine version range, dependencies on other plugins, and the modules. A plugin without code modules is content-only.

Two more fields decide where the code runs (see [Isolated plugins](#isolated-plugins-own-process)): `"isolation"`, `"in_process"` (the default) or `"process"`, and, on the editor module, `"process_class"`, the `LuminaPluginProcess` subclass in the same `entry_library`. A plugin with `"isolation": "process"` must name a `process_class` on an editor module. Its `registration_class` is then the in-process UI shell and may be left out when there is none (a plugin whose process part is a `PluginProcessAdapter`, or that has only declarative panels): the registrar then registers nothing for it in the editor process, so its contributions are never registered twice. An in-process module must name a `registration_class`; an unknown `isolation` value, a `process_class` that is not a Dart class name or a missing one makes the manifest a scan error, listed in the Plugin Manager like any other broken manifest.

```json
{
  "name": "my_tools",
  "version": "0.1.0",
  "isolation": "process",
  "modules": [
    {
      "name": "my_tools",
      "type": "editor",
      "entry_library": "lib/my_tools.dart",
      "registration_class": "MyToolsPlugin",
      "process_class": "MyToolsProcess"
    }
  ]
}
```

The registration class of an editor module extends `LuminaEditorPlugin`. In `register(LuminaEditorContext context)` it contributes its features, and `unregister` removes them again:

```dart
class MyPlugin extends LuminaEditorPlugin {
  @override
  String get pluginName => 'my_plugin';

  @override
  void register(LuminaEditorContext context) {
    context.registerMenuItem('Plugins/My Tools/Run My Tool', myCommand);
    context.registerPanel(myPanel);
    context.registerImporter(myImporter);
  }

  @override
  void unregister(LuminaEditorContext context) {}
}
```

`LuminaEditorContext` accepts:

- menu items (`registerMenuItem`, a menu path and an `EditorCommand`) under `Plugins/<Group>/...` or under a top-level menu the plugin owns (`registerMenu`, an `EditorMenuDescriptor`); the built-in menus refuse plugin items;
- toolbar buttons (`EditorToolbarButton`) and buttons with live state in named slots of the level toolbar or the status bar (`registerSlotButton`, an `EditorSlotButton`);
- dockable panels (`EditorPanelDescriptor`, with a default dock position). A right-dock panel shows in the level editor; with "Always" on (the dock's pin button, "Show in every editor", or Window ▸ *<panel>: Show in Every Editor*) it shows in every editor tab, sub-editors included, as the same panel with its state. `defaultAlwaysVisible: true` makes that the panel's default; the user's choice is saved per panel in `editor_layout.json`;
- asset types (`EditorAssetTypeHandler`: a built-in or custom asset type, display name and icon);
- importers (`EditorImporter`: file extensions and a description; `ImportContext` in, `ImportResult` out);
- details customizations (`DetailsCustomization`: a section in the details panel for a target type);
- console commands for the Output Log (`registerConsoleCommand`);
- pages in Project Settings > Plugins (`registerProjectSettingsSection`), whose applied values the plugin reads from `pluginSettings`.

The context also gives the plugin `panels` (open, close and observe its panels), `storage` (its own JSON store, per user and per open project) and `mcp` (the editor's MCP tools: register the plugin's own tools, list and call any tool in process; see the [MCP tools API](../lumina_editor_api/mcp.md)). In a running Lumina Studio the context is also a `LuminaEditorHostContext`, which exposes the open level, and an `EditorThemeHost`, which exposes the active colour theme.

## Discovery, enabling and restarts

Lumina Studio scans three kinds of plugin roots, project first, then user, then built-in (a plugin found earlier overrides a same-named one found later: intended, so it is logged at info level and the winner's Plugin Manager card says "Overrides the engine copy", never a scan error; only two folders of one root naming the same plugin are an error): `<project>/plugins/`; the per-user folder `~/.local/share/lumina/plugins/` (`%LOCALAPPDATA%\Lumina\plugins` on Windows; `LUMINA_USER_PLUGIN_DIR` overrides it), where the Lumina Marketplace and the Plugin Manager's Import from Folder / Import from Zip install plugins; and the **built-in** plugins, the plugin packages the engine workspace depends on. The built-ins (`lumina_plugin_pcg`, `lumina_plugin_miniai`, `lumina_plugin_trellis_image`) live in the plugins repository and are `lumina_ui` dev dependencies pinned by commit, so they are found through the workspace's resolved packages (`LuminaWorkspace.pluginPackageDirs`: every package in `.dart_tool/package_config.json` that ships `<name>.lmplugin`): the sibling `plugins` checkout in a source workspace (through `pubspec_overrides.yaml`), the pub cache's git checkout in a release checkout. An engine `plugins/` folder (`LUMINA_ENGINE_ROOT`) is still scanned when it exists. `PluginRepository` reads every manifest it finds and reports broken ones as scan errors; `PluginRegistryService` resolves the wanted set of enabled plugins against their dependencies and engine version and reports issues.

Plugins are enabled in **Plugins > Plugin Manager**. Code plugins are compiled into the editor: `EditorHostGeneratorService` adds them to a project editor host's `pubspec.yaml` (a built-in resolved from git as the same git dependency, url, path and commit from the engine's `pubspec.lock`, never a path into the pub cache; any other plugin by its folder, also written as a dependency override so a plugin that depends on it from git resolves the same folder) and generates the registrar, whose `registerAllPlugins` registers every enabled editor module and whose `kPluginProcesses` maps each enabled plugin with `"isolation": "process"` to its process class (passed to `runLuminaEditor` as `processes`). A plugin's `.lmplugin` is part of the project editor's build fingerprint, so changing its `isolation` or `process_class` rebuilds the editor. Enabling a code plugin therefore asks for a restart, and the editor comes back with the plugin registered.

## Isolated plugins (own process)

A code plugin normally runs inside the editor: a synchronous loop freezes it, a native crash in the plugin's FFI library closes it. A plugin with `"isolation": "process"` runs its risky half in its own process instead: the editor starts its own executable again with `--lumina-plugin-process <name>`, supervises it (a health ping every 2 s; three missed pings = hung, killed and restarted; automatic restarts after 1 s, 2 s and 4 s, at most three, then stopped until the user restarts it) and files a `plugin_crash` report when it dies. The editor keeps running.

Such a plugin has two halves:

| Half | Class | Runs in | What belongs there |
|---|---|---|---|
| Process part | `LuminaPluginProcess` subclass, the manifest's `process_class` | the plugin process | everything that can crash, hang or block: native (FFI) libraries, child processes, network, heavy CPU work, file generation, proxied level edits, MCP tools, importers, menu commands that do work |
| UI shell | the `LuminaEditorPlugin`, the manifest's `registration_class` | the editor | panels, tabs, asset editors and 3D viewports with full widgets; it holds no native library, starts no process and does no heavy work |

The process part registers everything as data through `PluginProcessContext` (menu items, slot buttons, importers, MCP tools, console commands, declarative panels described by a `PluginViewSpec`) and answers the shell with `handle(method, handler)`. The shell reaches it through `context.processChannel(pluginName)` (`PluginProcessChannel`: `call`, `events`, `progress`, `state`, `restart`). While the process is not running, the editor covers the shell's panels with the process state and a Restart button. A plugin that is all data needs no shell at all.

**Project override**: a project can force an isolated plugin in process, for debugging, with `.lmproject` `"plugin_isolation": {"<name>": "in_process"}` (`PluginRegistryService.setIsolationOverride`, the Plugin Manager). The same process part then runs inside the editor over an in-memory connection. The override only forces in process: a plugin without a process part always runs in process. The registrar lists every manifest-isolated plugin regardless of the override, so one editor build serves both.

## Kernel plugins (no editor rebuild)

There are three kinds of code plugin, and only two of them need a project editor build:

| Kind | Manifest | Runs | Project editor build |
|---|---|---|---|
| In-process | `registration_class` | inside the editor | yes, on enable, disable and update |
| Compiled isolated | `"isolation": "process"`, `registration_class` + `process_class` | its process part in the editor executable started again | yes |
| **Kernel** | `"isolation": "process"`, `process_class` + `process_entry`, **no** `registration_class` | its process on the Dart VM from a Dart kernel file | **no** |

A kernel plugin has no UI shell: everything it contributes is data (menu items, slot buttons, importers, console
commands, MCP tools, `PluginViewSpec` panels, process-opened dialogs) or plugin content (`can_contain_content`, its
`content/`, for example editor panel Widget Blueprints). Nothing of it is compiled into the editor, so
`EditorHostGeneratorService.editorCodePlugins` and the registrar's `kPluginProcesses` leave it out and it never
changes the project editor's fingerprint: a project whose code plugins are all kernel plugins opens without a project
editor build, and a mixed project builds only for its compiled plugins. Enabling, disabling, installing, updating or
removing one takes effect at once, without a build or a restart.

The editor module names the kernel fields (paths relative to the plugin folder; a path that leaves it is a scan
error, and a `process_kernel` without `process_entry` is one too):

```json
{
  "name": "my_tool",
  "isolation": "process",
  "modules": [{
    "name": "my_tool", "type": "editor", "entry_library": "lib/my_tool.dart",
    "process_class": "MyToolProcess",
    "process_entry": "bin/my_tool_process.dart",
    "process_kernel": "bin/my_tool_process.dill",
    "process_kernel_sdk": "3.13.4"
  }]
}
```

The entry is `Future<void> main(List<String> args) => runPluginProcessEntry(args, MyToolProcess.new);` and may not
reach Flutter or `dart:ui`. `tool/pack_plugin.dart` compiles it with the packer's Dart SDK (`dart compile kernel`),
writes the `.dill` with its `.sha256`, stamps `process_kernel` and `process_kernel_sdk`, and packs the entry source,
`lib/`, `pubspec.yaml`, `pubspec.lock` and `content/`. A kernel only runs on the SDK that built it: the editor
compares the stamp with the SDK of the Flutter SDK it uses for project builds and, when they differ (or the `.dill`
is missing, or the VM refuses it), recompiles the entry once into
`<LuminaDataDir>/plugin_kernels/<name>/<version>/<sdk>/<source hash>.dill` and reuses it while version, source and SDK
match. The shipped `.dill` must match its `.sha256` before it runs. A process plugin without a `registration_class`
cannot be forced in process by the project (`inEditorProcessUnavailableReason`). The **Kernel plugin (no editor
rebuild)** template of the New Plugin wizard (`PluginTemplateType.kernel`) writes such a plugin.

Gaps of the other plugins on the way to editor panels and kernels: gem_x's capture panel, the openxr/metaxr settings,
MetaHuman Creator (needs procedural meshes in the Viewport element), map_generator, trellis and the Unreal importer
keep their Flutter shells until they move to editor panels; openxr stays a compiled isolated plugin because its
native library comes from a build hook, which `dart compile kernel` does not run.

## Creating and publishing a plugin

**Plugins > New Plugin** opens a wizard that calls `PluginTemplateGeneratorService.generate` with a `PluginTemplateSpec` (template type, name, friendly name, author, description, category, `isolated`) and writes a ready-to-build plugin package. With `isolated: true` the package is an isolated plugin: `lib/src/<name>_process.dart` (a process part that registers a menu command, a `ping` handler and a declarative panel; the importer template's importer runs there too), a UI shell whose panel calls `ping` through the channel, a test for each half and a manifest with `"isolation": "process"` and `"process_class"`.

Plugins are packed for the marketplace with `dart run tool/pack_plugin.dart` inside the plugin folder; see the plugins repository for the details.

## Example plugins

The [plugins repository](https://github.com/LuminaGame/plugins) holds MIT-licensed plugins:

- `lumina_plugin_pcg`: procedural content generation (PCG Graph assets and PCG Volume actors that scatter static meshes), the reference example of the plugin API;
- `lumina_plugin_miniai`: an AI assistant panel that works on the project through the editor's MCP tools.
- `lumina_plugin_trellis_image`: Qwen Image 2.1 Q4_K_M text generation and reference editing through stable-diffusion.cpp, followed by an explicit image approval before Trellis 3D generation.

### Trellis Image Studio

Enable `trellis_plugin` 0.3+ and `lumina_plugin_trellis_image`, then restart. Open **Plugins → Trellis Image → Text or Reference to 3D…**. The Windows installer downloads the pinned Vulkan runtime and approximately 11 GB of model files with checksum verification and resumable downloads. For a reference edit, select an imported texture through the editor asset picker and describe the desired change.

**Generate image** creates a reviewable draft. **Approve this image & generate 3D** checks the current image's hash, starts Trellis using its saved quality and texture settings, follows progress events, and opens the completed mesh for review without saving it: an interactive 3D view (`build3DViewport`; orbit, pan, zoom, Lit / Unlit / Wireframe through `Plugin3DViewportOptions.viewMode`) with its triangles, vertices, size and file size, a **Simplify** section (a ratio or a triangle target, Apply / Revert, before → after; Trellis' meshoptimizer simplifier in its plugin process, vertex colours and UVs kept) and **Save to Project** (name + project folder) / **Regenerate** / **Discard**. Nothing reaches the project before Save; the temp output is removed on Discard and when the Trellis process ends. It does not place an actor automatically. **Cancel current job** cancels the owned native job. Native failures and missing models appear in the workspace. Other platforms can configure an existing compatible `sd-cli` manually.

For targeted real-runtime verification, set `LUMINA_QWEN_IMAGE_ROOT` and `LUMINA_TRELLIS_PLUGIN` to installed runtime/plugin folders, with `trellis_plugin` available through local dependency overrides, then run `lumina_ui/integration_test/smoke/trellis_image_smoke_test.dart` through the smoke report runner. The generation scenario verifies that no 3D job starts before approval and that nothing is saved before Save; the review scenario (`LUMINA_TRELLIS_OUTPUT` naming a real Trellis output GLB) shows it in Lit, Unlit and Wireframe, simplifies it to 25% and saves it into a project folder.

## Editor panel Widget Blueprints

A plugin can ship its UI as editor panel Widget Blueprints in its `content/` (`"can_contain_content": true`): designed
in the UMG designer, run by the editor's Blueprint VM, docked without any Dart compile or project editor build. A
content-only plugin made of them is enabled with no restart; its heavy work can live in a process part, which the
panels call and which patches their element states. New Plugin's default template is such a plugin. See
[Editor panels](../lumina_ui/editor-panels.md).

---

[Previous: Plugin processes](../lumina_plugin_process/plugin-processes.md) | [Up: Lumina documentation](../../README.md) | [Next: lumina_ui (Lumina Studio)](../lumina_ui/index.md)
