[Türkçe](../../tr/lumina_plugin_process/plugin-processes.md)

# Plugin processes

A plugin can run the part of it that may crash, hang or block in its own process: native libraries through FFI, child processes, network calls, heavy CPU work, file generation. A native crash or an endless loop there ends that process only; Lumina Studio keeps running, marks the plugin stopped, files a plugin crash report and offers Restart. This page covers the process side of that split: the API a plugin process registers with, how it starts and ends, the proxies it reaches the editor through, and the adapter that runs an existing data-only plugin in a process unchanged. The process side is the pure-Dart package `lumina_plugin_process` (see [lumina_plugin_process](index.md)); file paths are relative to its `lumina_plugin_process/` directory unless they start with `lumina_editor_api/`, which re-exports all of it and adds the Flutter parts (the adapter, icons, `PluginProcessChannel`). The wire protocol itself is the `lumina_plugin_protocol` package.

## How a plugin process runs

A plugin opts in with `"isolation": "process"` in its `.lmplugin` and names its `LuminaPluginProcess` subclass as the editor module's `process_class`. The editor binds a loopback port and starts its own executable again with `--lumina-plugin-process <name> --lumina-plugin-port <port> --lumina-plugin-token <token> [--lumina-plugin-project <dir>]` (`PluginProcessLaunch`). In that mode the executable opens no window (on Windows the runner starts a headless engine with no view, on Linux it realizes the view in a window that is never shown; see the editor side in `lumina_ui/plugin-processes.md`): it creates the plugin's process part and calls `runPluginProcessMain(launch, process)`, then exits with the code it returns. The process has the full Flutter/Dart runtime and the plugin's native assets, which are already bundled with the editor build. The process API needs none of Flutter, though: a plain `dart` program can implement and run a plugin process against the same editor (`example/pure_process.dart`, tested by `test/two_process_test.dart`); starting such a program instead of the editor executable is a later step.

`runPluginProcessMain` (`lib/src/run_plugin_process.dart`):

1. Connects to `127.0.0.1:<port>` and sends `host.hello` with the protocol version, the plugin name, the token and its pid. A refused hello (wrong token, another protocol version) ends with a non-zero code.
2. Builds the `PluginProcessContext` from the answer: the open project, the plugin's project settings, the `PluginStorage` directories. With a project open it fetches the level snapshot.
3. Calls `register(context)`, then sends everything registered once with `host.register`. From then on slot button states and menu check marks are sent as they change.
4. Calls `onProjectOpened` when a project is open, then serves the editor's requests: `core.ping` (health check every 2 s), `core.call` (the shell's channel calls), `core.command`, `core.canExecute`, `core.mcpTool`, `core.import`, `core.console`, `core.viewEvent`, `core.projectOpened`, `core.projectClosing`, `core.shutdown`, and the notifications `core.settings` and `core.levelChanged`.

A handler that throws answers its request with an error and writes the error to the editor's log under the plugin's name; the loop goes on. The plugin's code runs in a guarded zone, so an uncaught asynchronous error is logged the same way instead of ending the process. When nothing else handles `LuminaPluginCrashReporter` (always so in a plugin process), the plugin's own crash reports go to the editor's log at error level with the plugin as source; the handler is removed when the loop ends, and under the in-process override the editor's crash reporter stays in charge. A `core.shutdown` that arrives before the answer to `host.register` ends the process cleanly (code 0). CPU-heavy work still belongs in `Isolate.run`: a handler that blocks the isolate stops the health ping too, and after three missed pings the editor restarts the process.

`servePluginProcess({input, output, pluginName, token, process})` runs the same handshake and loop over a byte stream pair the caller already has (for example a socket it connected itself).

### Exit codes

`PluginProcessExitCodes`:

| Code | Name | Meaning |
|---|---|---|
| 0 | `ok` | `core.shutdown` was answered (`onShutdown` ran). |
| 1 | `connectionLost` | The editor closed the connection or went away without a shutdown. |
| 2 | `connectFailed` | The editor's port could not be reached. |
| 3 | `refused` | The editor refused the hello (token or protocol version). |
| 4 | `registerFailed` | `register` threw, or the editor refused the contributions; the error is in the editor log. |

## LuminaPluginProcess

`lib/src/plugin_process.dart`. The process part of a plugin.

| Member | Description |
|---|---|
| `String get pluginName` | The `.lmplugin` `name`, the same as the shell's `LuminaEditorPlugin.pluginName`. |
| `FutureOr<void> register(PluginProcessContext context)` | Registers handlers and contributions; called once per process run, after the handshake. |
| `FutureOr<void> onProjectOpened(EditorProjectInfo project)` | A project was opened (also right after `register` when one is open). |
| `Future<void> onProjectClosing()` | The project is closing: finish pending writes. Bounded by the editor. |
| `Future<void> onShutdown()` | The process is about to exit: stop child processes, release native resources. |

## PluginProcessContext

What a plugin process registers with and reaches the editor through. Everything crosses the boundary as data.

| Member | Description |
|---|---|
| `project`, `pluginSettings`, `storage` | The open project, the plugin's applied project settings (an `Observable<Map<String, Object?>>`, updated by `core.settings`) and its `PluginStorage` (the directories the editor named in the hello; the project store follows `core.projectOpened` / `core.projectClosing`). |
| `level` | The open level as a `PluginLevelAccess` proxy, see below. |
| `handle(method, handler)` | Answers the shell's `PluginProcessChannel.call(method, args)`; the handler returns JSON. |
| `emit(name, [data])` | An event for the shell (`PluginProcessChannel.events`). |
| `progress(task, step:, done:, total:, message:, finished:)` | Progress of a long job, shown by the shell and the Plugin Manager. |
| `log(message, level:)` | A line in the editor's log under the plugin's name. |
| `saveAsset(relativePath:, bytes:, generateThumbnail:)` | Saves an asset through the editor (thumbnail, Content Browser refresh). |
| `registerMenu`, `registerMenuItem`, `registerSlotButton` | Menus, menu items (with an optional `checked` `Observable<bool>`) and slot buttons (their `state` an `Observable<PluginButtonStateSpec>`, usually an `ObservableValue`) whose commands (`PluginProcessCommand`) run in the process; a command with `canExecute` is asked before the editor enables it. |
| `registerMcpTool`, `registerImporter`, `registerConsoleCommand` | MCP tools, importers (`PluginProcessImporter`; throw `PluginImportError(message)` to fail with that message) and console commands handled in the process. |
| `registerViewPanel(PluginProcessViewPanel)` | A declarative panel: the editor renders its `PluginViewSpec`, events arrive in `onEvent` with a `PluginViewHandle` whose `replace` / `patch` update it. Control ids must be unique in the whole view, sections and rows included (`PluginViewSpec.duplicateControlIds()` lists clashes). |
| `pluginDir` | The folder the plugin is installed in (holding its `.lmplugin`), from the hello answer: where it finds files it ships (executables, models). `Isolate.resolvePackageUri` does not work in a release build. Null when the editor does not know it. |
| `view(viewId)` | The `PluginViewHandle` of a registered view, to update it outside its own events (after an MCP tool call, a finished job); null for an unknown id. |
| `showPanel`, `hidePanel`, `openTab`, `callMcpTool` | Panel visibility, the shell's tabs, and any editor MCP tool. |

Contributions are sent once: registering a menu item, button, tool, importer, console command or panel after `register` has returned is a `StateError`. `handle` works at any time. The implementation is `ConnectedPluginProcessContext` (`lib/src/process_context.dart`); the request handlers are installed by `installPluginProcessHandlers` (`lib/src/process_dispatch.dart`).

The live values are `lumina_core`'s pure change types (`Observable`, `ObservableValue`, `ChangeSignal`). They have the same `value` / `addListener` / `removeListener` members as Flutter's `ValueListenable`, so process code that only calls those reads the same. A Flutter program converts with `asValueListenable()` / `asObservable()` (`lumina_editor_api`).

## The level proxy

`PluginLevelProxy` (`lib/src/level_proxy.dart`) implements `PluginLevelAccess` over `host.level` requests; the editor makes every edit as an undoable transaction of its own level, exactly as for an in-process plugin.

- The synchronous getters (`actors`, `selectedActorIds`, `undoTopLabel`, `activeLevelPath`, `projectDirPath`) read the last `snapshot`: fetched after the handshake, after each of the proxy's own edits, and on every `core.levelChanged`, before `changes` fires.
- `removeActors`, `setComponentProperty` and `selectActors` are synchronous in the API: they update the local copy at once, send the request and refresh when it is answered; a failure is written to the editor log. A labelled edit made outside a transaction becomes `undoTopLabel` at once, and `undoIfTop` answers from that label (the editor checks again before undoing).
- `addActors`, `saveLevel` and `openLevel` wait for the editor (up to 60 s, since they load files).
- `runTransaction(label, body)` sends `beginTransaction`, runs `body` with the transaction id in its zone, and sends `endTransaction`; every edit made inside carries the id, so the editor records them as one undo step. A call inside another joins it.

`EditorLevelJson` (`lib/src/level_json.dart`) encodes and decodes the actor snapshot and actor spec JSON both sides use.

`PluginLevelAccess` and the editor's `EditorLevelAccess` (`lumina_editor_api`) share every operation (`EditorLevelOperations`, `lib/src/editor_level.dart`) and differ only in `changes`: a pure `ChangeSignal` in the process, a Flutter `Listenable` in the editor. `level.asEditorLevelAccess()` and `level.asPluginLevelAccess()` convert one into the other; the adapter below hands a data-only plugin the first.

## Running an existing plugin in a process: PluginProcessAdapter

`PluginProcessAdapter(plugin)` (`lumina_editor_api/lib/src/process/plugin_process_adapter.dart`; it wraps a Flutter `LuminaEditorPlugin`, so it stays in `lumina_editor_api`) is a `LuminaPluginProcess` that runs an unchanged `LuminaEditorPlugin` whose contributions are data. Its `register` receives a `LuminaEditorHostContext` (`PluginAdapterContext`) that maps:

| In-process API | In the plugin process |
|---|---|
| `registerMenu`, `registerMenuItem` (order, section, `checked`) | menu contributions; commands run with a null `BuildContext`, `canExecute` is asked by the editor |
| `registerSlotButton`, `registerToolbarButton` | slot buttons; `EditorButtonState` changes are sent as they happen; a toolbar button goes to the slot its `group` names (`levelToolbarEnd` otherwise) |
| `registerConsoleCommand`, `registerImporter`, `mcp.registerTool` | console commands, importers (an `ImportResult.failure` becomes the editor's error) and MCP tools |
| `mcp.callTool`, `storage`, `pluginSettings`, `saveAsset`, `openTab`, `panels.show` / `hide` | the editor through the process context; `panels.isVisible` / `visibility` follow the plugin's own calls |
| `level` (via `context is LuminaEditorHostContext`) | the level proxy, as an `EditorLevelAccess` |
| `reportCrash` | an error line in the editor log |
| `onProjectOpened`, `onProjectClosing` | forwarded |
| `onEditorShutdown`, then `unregister` | on `core.shutdown` |

What builds widgets cannot leave the editor's process. `registerPanel`, `registerTab`, `registerAssetType`, `registerDetailsCustomization`, `registerProjectSettingsSection`, `build3DViewport` and `buildAssetPicker` throw `UnsupportedError('<API> needs the editor process: …')`, so registration fails with that message in the editor log (exit code 4). Such a plugin keeps those parts in its in-process UI shell, which talks to its process part through `LuminaEditorContext.processChannel(pluginName)`, or describes its panels with `PluginProcessViewPanel`.

```dart
// A data-only plugin, unchanged, as the editor module's process class.
class MyPluginProcess extends PluginProcessAdapter {
  MyPluginProcess() : super(MyPlugin());
}
```

## Icons as data

Commands, slot button states and declarative buttons carry icons as `PluginIconSpec` (code point, font family, font package, text direction). `pluginIconOf(IconData)` builds one from a Flutter icon; `iconDataOf(PluginIconSpec)` turns it back into an `IconData` for the editor to draw (`lumina_editor_api/lib/src/process/plugin_icons.dart`; a pure-Dart process writes the `PluginIconSpec` itself). The glyph comes from the editor's bundled icon fonts: the process runs from the editor's executable, so the const icons a plugin names keep their glyphs when release builds tree-shake the fonts.

---

[Previous: lumina_plugin_process](index.md) | [Up: lumina_plugin_process](index.md) | [Next: Editor plugins](../plugins/index.md)
