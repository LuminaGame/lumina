[Türkçe](../../tr/lumina_ui/plugin-processes.md)

# Plugin processes (editor side)

How Lumina Studio runs, watches and restarts the plugins whose `.lmplugin` asks for `"isolation": "process"`. The
plugin side (`LuminaPluginProcess`, `runPluginProcessMain`, the proxies) is described in
[Plugin processes](../lumina_editor_api/plugin-processes.md); the wire protocol in `lumina_plugin_protocol`. File
paths are relative to the `lumina_ui/` package directory.

## In short

- An isolated plugin's process part runs in its own process: the editor's own executable started again with
  `--lumina-plugin-process <name> --lumina-plugin-port <port> --lumina-plugin-token <token> [--lumina-plugin-project <dir>]`.
  In that mode `runLuminaEditor` shows no window, starts no crash session and loads no plugin registry; it runs
  `LuminaEditorHost.pluginProcesses[name]` with `runPluginProcessMain` and exits with its code (an unknown name exits 64
  with a message on stderr).
- **Headless on Windows**: the runner (`windows/runner/main.cpp`, copied into every project editor) sees the flag and
  runs a `flutter::FlutterEngine` with the same entry point arguments and a message loop: no window, no view, no
  surface, Impeller off and the low-power GPU preferred. It registers no native plugin (the editor's are window_manager,
  media_kit, screen_retriever, mouse capture and volume, which need a view; media_kit_video dereferences it while
  registering), and the plugin DLLs are delay-loaded (`windows/CMakeLists.txt`), so libmpv never loads either. A
  process part therefore reaches native code through FFI; a method-channel plugin answers `MissingPluginException`.
  Measured on a release project editor: about 102 MB working set / 117 MB private and 52 threads per plugin process,
  from 136 MB / 157 MB and 118 threads with the hidden runner window.
- **Linux keeps a hidden window**: flutter_linux exports `fl_engine_new_headless` but not `fl_engine_start`, and the
  engine starts only when the implicit `FlView` is realized inside a `GtkWindow`. A plugin process therefore realizes a
  1×1 window that is never mapped (no header bar, skipped by the taskbar, no first-frame show).
- The editor binds a loopback socket on port 0 per plugin, checks the process's `host.hello` (protocol version and a
  random token), and registers the `host.register` contributions under the plugin's name: menu items, slot buttons, MCP
  tools, importers, console commands and declarative panels. Their actions run in the process. The project folder on
  the command line and every folder of the hello answer (project, user and project storage, the plugin's install
  folder) are normalised: one separator style and no `.` or `..` segments.
- A native crash, a hang or a leak in the process never takes the editor down. The editor pings the process every 2 s;
  three unanswered pings in a row mean **hung**: the whole process tree is killed and the plugin restarts. A process that
  ends on its own is **crashed**: a `plugin_crash` crash report is filed and the plugin restarts. Automatic restarts wait
  1 s, 2 s and 4 s; after the third the plugin is **stopped** until the user presses Restart (which starts the count
  again; so does a minute of running).
- While a plugin is not running its contributions stay where they are but are unavailable: menu items and slot buttons
  are disabled (every menu row alike, plain or checkable: greyed label and icon, no hover highlight) with the tooltip
  "`<plugin>` stopped: `<reason>`", its MCP tools answer an error result, and its panels,
  tabs and asset editors show the process guard. A restart registers them again (replacing, never duplicating).
- **Run in editor process (debugging)**: the project's `.lmproject` `plugin_isolation: {"<name>": "in_process"}` (the
  Plugin Manager's switch) runs the same process part inside the editor over the same loopback protocol, status
  **in process**, so a debugger attached to the editor stops in plugin code. A crash or hang there affects the editor.

## States

`PluginProcessState.status` (`lumina_editor_api`), as the Plugin Manager and the guard show it:

| Status | Meaning |
|---|---|
| `starting` | Started; the handshake or `host.register` is not done yet (bounded by 60 s, then it counts as hung). |
| `running` | Registered and answering pings. |
| `inProcess` | Running inside the editor (the project's override). |
| `hung` | Missed three pings (or never started): being killed, a restart follows. |
| `crashed` | Ended on its own (`exitCode`, `reason` "exited with code N"; the process's own exit codes are explained: 1 lost the connection, 2 could not connect, 3 handshake refused, 4 its `register()` threw); a restart follows. |
| `stopped` | Gave up after the automatic restarts, or stopped on purpose; Restart starts it. |
| `disabled` | The plugin is disabled (the detached channel of a plugin with no process). |

## `lib/ui/core/services/plugin_process/plugin_process_supervisor.dart`

### `class PluginProcessSupervisor`

One per isolated plugin; it is also that plugin's `PluginProcessChannel`, the object `context.processChannel(name)`
hands the plugin's in-process shell.

| Member | Purpose |
|---|---|
| `start()` | One process run: loopback port, token, launch (or the in-process runner), handshake, registration, pings. |
| `restart()` | The user's Restart: graceful `core.shutdown`, killed after 3 s if still alive, then `start`; resets the automatic restart count. |
| `stop({reason})` / `shutdown()` | Stops for good (`core.shutdown`, then kill); `shutdown` also releases the supervisor (editor exit). |
| `projectClosing()` / `projectOpened(project)` | `core.projectClosing` (bounded by 5 s) / `core.projectOpened`. The hello answer already names the open project. |
| `call(method, args, timeout)` | The shell's call (`core.call`), 30 s by default; `unavailable` while not running, `timeout`, or `closed` at once when the process dies. |
| `events([name])`, `progress` | `host.event` and `host.progress` of the process. |
| `state`, `unavailableReason`, `lastExitCode`, `reportedPid`, `startCount` | The current state, "`<plugin>` stopped: `<reason>`", the last exit code, the pid the process said hello with, the starts so far. |
| `logTail`, `logRevision` | The process's stdout and stderr, its `host.log` lines and the supervisor's notes (last 300 lines); `logRevision` counts additions. |
| `viewOf(viewId)`, `sendViewEvent(event)` | A declarative panel's current spec (`host.view` replaces or patches it) and sending a user action (`core.viewEvent`). |
| `inProcessRunner` | Set for the in-process override (takes effect at the next start). |

Requests the process makes are answered here (`supervisor_host_handlers.dart`): `host.level` over the open level
(`EditorLevelJson` shapes; `beginTransaction`/`endTransaction` bracket one undo step, every edit inside — or carrying
its `tx` — joins it, and an open transaction ends when the connection closes; `snapshot` answers null with no level),
`host.saveAsset` (without bytes it only refreshes the Content Browser and the thumbnail), `host.panels`, `host.tabs`,
`host.mcp.call`, `host.log` into the Output Log under the plugin's name (or the `source` it gives), `host.slotState`,
`host.menuChecked`. The process is told `core.settings` when Project Settings applies its block and `core.levelChanged`
(debounced) when the level changes.

Bounds (`PluginSupervisorTimings`): ping 2 s × 3, restarts 1/2/4 s, start 60 s, `call` 30 s, menu and console
commands 30 s, MCP tools and importers 30 min (a generation may take minutes: pings catch a hang, a dying process fails
the call at once), `core.projectClosing` 5 s, shutdown grace 3 s.

### `class ProcessBackedCommand`

The `EditorCommand` of a process menu item, slot button or slot menu entry: runs `core.command`, disabled with its
`unavailableReason` while the process is not running; the menu bar shows the reason as a tooltip.

## `lib/ui/core/services/plugin_process/plugin_process_manager.dart`

### `class PluginProcessManager`

The supervisors of the isolated plugins compiled into the editor (`LuminaEditorHost.pluginProcesses`), also those with
no in-process shell. `EditorViewModel.pluginProcesses` creates it, attaches it to the extension registry before the
shells register and starts every process after them. `supervisorOf(name)`, `isIsolated(name)`, `startAll()`,
`setRunInEditorProcess(name, bool)` (switches mode and restarts; the channel object stays the same),
`projectClosing()`, `shutdownAll()` (wired into `shutdownPlugins`, so `EditorHandOff.beforeExit` and closing the project
stop the processes).

## Other files

| File | Purpose |
|---|---|
| `plugin_process_launcher.dart` | `PluginProcessLauncher`: the program (default `Platform.resolvedExecutable`) plus `PluginProcessLaunch.toArgs()`, stdout/stderr piped; tests start a Dart script. `killProcessTree` (`taskkill /T /F`, or `pgrep -P` + SIGKILL). |
| `plugin_process_host.dart` | `PluginProcessHost`: what the supervisor needs from the editor; `PluginExtensionRegistry` implements it. |
| `plugin_isolation_overrides.dart` | Reads and writes the project's `plugin_isolation` in-process override. |
| `plugin_process_entry.dart` | `runPluginProcessFromArgs`: the plugin-process mode of `runLuminaEditor`. |
| `lucide_icon_table.dart` | Lucide icons by code point: an icon sent as data maps back to a constant, so release builds keep tree-shaking icon fonts (other fonts show the plug icon). |
| `lib/ui/core/widgets/plugin_process_guard.dart` | `PluginProcessGuard`: the panel untouched while running, a small spinner while starting, otherwise the panel dimmed under "`<plugin>` stopped: `<reason>`" with **Restart** and **Details** (the log tail). |
| `lib/ui/core/widgets/plugin_process_view_panel.dart` | `PluginProcessPanelView`: a declarative panel's body, `PluginViewRenderer` over the current spec. |
| `lib/ui/core/plugin_extension_registry_processes.dart` | The registry's process side: shell panels, tabs and asset editors of isolated plugins are wrapped in the guard; process contributions are kept apart from the shell's, so either registers again without removing the other. |

## Crash reports

A process death is `CrashReportKind.pluginCrash` (wire `plugin_crash`): `CrashReporter.recordPluginCrash` files it with
the plugin name, the exit code and the process's log tail, and the crash report screen shows "A PLUGIN PROCESS STOPPED".
The editor's session marker is not touched. A hang the editor ended is not a crash report.
