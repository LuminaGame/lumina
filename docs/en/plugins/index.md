[Türkçe](../../tr/plugins/index.md)

# Editor plugins

Lumina Studio can be extended with plugins: Flutter packages that register menu items, panels, toolbar buttons, asset types, importers, details customizations and console commands through `lumina_editor_api`. This page explains how the pieces fit together.

## The pieces

| Piece | Package | Role |
|---|---|---|
| `LuminaEditorPlugin`, `LuminaEditorContext` and the extension types | `lumina_editor_api` | The contract a plugin is written against ([API reference](../lumina_editor_api/api-reference.md)). |
| `LuminaPluginDescriptor`, `PluginRepository` | `lumina` (data layer) | Parse `.lmplugin` manifests and scan the plugin roots ([models and repositories](../lumina/data-models.md)). |
| `PluginRegistryService`, `PluginTemplateGeneratorService`, `PluginHostPatcherService` | `lumina` (data layer) | Resolve which plugins are enabled, generate new plugins from templates and compile code plugins into an editor host ([use cases and services](../lumina/data-services.md)). |
| `PluginExtensionRegistry`, `BuiltInEditorPlugin` | `lumina_ui` | Collect everything plugins register and show it in the editor ([App shell and shared UI](../lumina_ui/core.md)). |
| Plugin Manager, New Plugin wizard | `lumina_ui` | Enable, disable and create plugins ([Plugin manager](../lumina_ui/plugin-manager.md)). |

`lumina_editor_api` depends only on `lumina`. A plugin therefore never depends on `lumina_ui`, which would create a cycle between the editor and its plugins.

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
- dockable panels (`EditorPanelDescriptor`, with a default dock position);
- asset types (`EditorAssetTypeHandler`: a built-in or custom asset type, display name and icon);
- importers (`EditorImporter`: file extensions and a description; `ImportContext` in, `ImportResult` out);
- details customizations (`DetailsCustomization`: a section in the details panel for a target type);
- console commands for the Output Log (`registerConsoleCommand`);
- pages in Project Settings > Plugins (`registerProjectSettingsSection`), whose applied values the plugin reads from `pluginSettings`.

The context also gives the plugin `panels` (open, close and observe its panels), `storage` (its own JSON store, per user and per open project) and `mcp` (the editor's MCP tools: register the plugin's own tools, list and call any tool in process; see the [MCP tools API](../lumina_editor_api/mcp.md)). In a running Lumina Studio the context is also a `LuminaEditorHostContext`, which exposes the open level, and an `EditorThemeHost`, which exposes the active colour theme.

## Discovery, enabling and restarts

Lumina Studio scans three kinds of plugin roots, project first, then user, then built-in (a plugin found earlier hides a same-named one found later): `<project>/plugins/`; the per-user folder `~/.local/share/lumina/plugins/` (`%LOCALAPPDATA%\Lumina\plugins` on Windows; `LUMINA_USER_PLUGIN_DIR` overrides it), where the Lumina Marketplace and the Plugin Manager's Import from Folder / Import from Zip install plugins; and the **built-in** plugins, the plugin packages the engine workspace depends on. The built-ins (`lumina_plugin_pcg`, `lumina_plugin_miniai`) live in the plugins repository and are `lumina_ui` dev dependencies pinned by commit, so they are found through the workspace's resolved packages (`LuminaWorkspace.pluginPackageDirs`: every package in `.dart_tool/package_config.json` that ships `<name>.lmplugin`): the sibling `plugins` checkout in a source workspace (through `pubspec_overrides.yaml`), the pub cache's git checkout in a release checkout. An engine `plugins/` folder (`LUMINA_ENGINE_ROOT`) is still scanned when it exists. `PluginRepository` reads every manifest it finds and reports broken ones as scan errors; `PluginRegistryService` resolves the wanted set of enabled plugins against their dependencies and engine version and reports issues.

Plugins are enabled in **Plugins > Plugin Manager**. Code plugins are compiled into the editor: `EditorHostGeneratorService` adds them to a project editor host's `pubspec.yaml` (a built-in resolved from git as the same git dependency, url, path and commit from the engine's `pubspec.lock`, never a path into the pub cache; any other plugin by its folder) and generates the registrar, whose `registerAllPlugins` registers every enabled editor module. Enabling a code plugin therefore asks for a restart, and the editor comes back with the plugin registered.

## Creating and publishing a plugin

**Plugins > New Plugin** opens a wizard that calls `PluginTemplateGeneratorService.generate` with a `PluginTemplateSpec` (template type, name, friendly name, author, description, category) and writes a ready-to-build plugin package.

Plugins are packed for the marketplace with `dart run tool/pack_plugin.dart` inside the plugin folder; see the plugins repository for the details.

## Example plugins

The [plugins repository](https://github.com/LuminaGame/plugins) holds two MIT-licensed plugins that also serve as templates:

- `lumina_plugin_pcg`: procedural content generation (PCG Graph assets and PCG Volume actors that scatter static meshes), the reference example of the plugin API;
- `lumina_plugin_miniai`: an AI assistant panel that works on the project through the editor's MCP tools.

---

[Previous: MCP tools API](../lumina_editor_api/mcp.md) | [Up: Lumina documentation](../../README.md) | [Next: lumina_ui (Lumina Studio)](../lumina_ui/index.md)
