[Türkçe](../../tr/lumina_ui/index.md)

# lumina_ui (Lumina Studio)

`lumina_ui` is Lumina Studio, the desktop editor for Lumina projects. It is a Flutter app built with shadcn_flutter and a hand-written ChangeNotifier MVVM, and it drives the engine through `lumina` and `flutter_filament`.

## Place in the architecture

`lumina_ui` is the top layer. It depends on `lumina` (runtime and data layer), `lumina_editor_api` (the plugin contract it implements), `flutter_filament` (used directly by the viewports and previews), the native packages of the tools repository and `lumina_marketplace_shared` from the marketplace repository. New 3D features are routed through `lumina` rather than through direct `flutter_filament` calls. See [Layered architecture](../overview/layers.md).

## Structure

- **UI toolkit**: shadcn_flutter widgets throughout the editor UI, rather than Material widgets.
- **State**: a hand-written ChangeNotifier MVVM. `EditorViewModel` is the central view model of the main editor; every sub-editor has its own view model.
- **Features** live under `lib/ui/features/<feature>/` with `views/`, `view_models/`, `services/` and `models/` subfolders. Sub-editor views that share a domain live in their own folder (`views/blueprint/`, `views/material/`, `views/sequencer/`, `views/umg/`, ...).
- **Shared UI** lives under `lib/ui/core/`: theme, property editors, scene services and the plugin extension registry.
- **Real data only**: projects are real folders with `.lmproject` and `.lmas` files (by default under `~/Lumina Projects/`), and tests use temporary directories instead of mocks.

## Reference pages

| Page | Covers |
|---|---|
| [App shell and shared UI](core.md) | App entry, built-in plugin, plugin extension registry, theme, property editors, scene services. |
| [App shell and shared UI (continued, part 1)](core-continued.md) | More files under `lib/`, `lib/testing/`, `lib/ui/core/`, `lib/ui/core/host/`, `lib/ui/core/property_editors/`, `lib/ui/core/services/`, `lib/ui/core/theme/`, `lib/ui/core/widgets/`. |
| [App shell and shared UI (continued, part 2)](core-continued-2.md) | More files under `lib/ui/core/window/`, the media players and declarative plugin panels (`PluginViewRenderer`). |
| [Main editor: views](main-editor-views.md) | Viewport, outliner, details, content browser, toolbar, menu bar, output log, dialogs. |
| [Main editor: views (continued)](main-editor-views-continued.md) | More files under `lib/ui/features/main_editor/views/`. |
| [Main editor: view model and services](main-editor-state.md) | `EditorViewModel`, quality settings, gizmos, Play-In-Editor, snapping, picking, shortcuts, commands, transactions. |
| [Main editor: view model and services (continued)](main-editor-state-continued.md) | More files under `lib/ui/features/main_editor/services/`, `lib/ui/features/main_editor/services/pie_controller/`, `lib/ui/features/main_editor/view_models/`, `lib/ui/features/main_editor/view_models/editor_view_model/`. |
| [Launcher and details](launcher-and-details.md) | Project launcher, create-project dialog, component property registry, multi-edit. |
| [Plugin manager](plugin-manager.md) | Plugin manager view and view model, new-plugin wizard. |
| [Plugin processes](plugin-processes.md) | Isolated plugins: supervisor, states, restarts, the process guard, `plugin_crash` reports, the in-editor override, the plugin-process mode of the executable. |
| [Source control](source-control.md) | Git service, source control view model, commit, history, revert and identity dialogs. |
| [Marketplace](marketplace.md) | Signing in, browsing, installing listings and license records. |
| [MCP server](mcp-server.md) | The editor's Model Context Protocol server: transport, sessions, registry, jobs, sandbox, snapshots, panel. |
| [MCP tool catalogue](mcp-tools.md) | Every MCP tool the editor offers, by area, with its risk level. |
| [Windows packaging](windows-packaging.md) | Building and signing the MSIX package of Lumina Studio. |
| [Sub-editors](sub-editors/index.md) | The asset editors that open in their own tabs. |

---

[Previous: Editor plugins](../plugins/index.md) | [Up: Lumina documentation](../../README.md) | [Next: App shell and shared UI](core.md)
