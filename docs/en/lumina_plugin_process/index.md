[Türkçe](../../tr/lumina_plugin_process/index.md)

# lumina_plugin_process (the pure-Dart process side of a plugin)

`lumina_plugin_process` holds the part of a Lumina Studio plugin that runs in its own process, in pure Dart: no Flutter, `dart:ui` or FFI anywhere in its import graph. A plugin process written against it can run with `dart run`, and its tests can run with `dart test`. It contains:

- the process-side API: `LuminaPluginProcess`, `PluginProcessContext` and what a process registers (`PluginProcessCommand`, `PluginProcessSlotButton`, `PluginProcessViewPanel`, `PluginProcessImporter`, MCP tools, console commands);
- its runtime: `runPluginProcessMain`, `servePluginProcess`, the request dispatch (`installPluginProcessHandlers`), the level proxy (`PluginLevelProxy`) and the level JSON codecs (`EditorLevelJson`);
- the editor data it reads and writes: the open level (`PluginLevelAccess`, `EditorLevelOperations`, `EditorActorSnapshot`, `EditorComponentSnapshot`, `EditorActorSpec`, `EditorComponentSpec`), `PluginStorage`, `EditorProjectInfo`, `LuminaPluginCrashReporter`, and the MCP types (`McpTool`, `McpArgs`, `McpToolResult`, `EditorMcp`, …);
- the editor side's line to a process, `PluginProcessLink`, and its state types (`PluginProcessState`, `PluginProcessStatus`, `PluginProcessEvent`, `PluginProgress`);
- a loopback test host, `LoopbackHost` (`package:lumina_plugin_process/testing.dart`).

The process API, its lifecycle, exit codes and proxies are described in [Plugin processes](plugin-processes.md).

## Place in the architecture

The package lives in the lumina repository (`lumina_plugin_process/`) and is a member of its pub workspace. It depends only on `lumina_plugin_protocol` (the wire protocol), `lumina_core` (the pure foundation), `path` and `meta`. `lumina_editor_api` depends on it and re-exports its whole public API together with the Flutter adapters, so plugins and the editor keep importing `package:lumina_editor_api/lumina_editor_api.dart` and compile unchanged:

| Stays in `lumina_editor_api` (Flutter) | Why |
| :--- | :--- |
| `PluginProcessAdapter` | It wraps a Flutter `LuminaEditorPlugin`. |
| `pluginIconOf(IconData)`, `iconDataOf(PluginIconSpec)` | `IconData` is a Flutter type; a pure process writes `PluginIconSpec(codePoint, fontFamily: ...)` itself. |
| `PluginProcessChannel` | The shell's line with a `ValueListenable` state for widgets; `PluginProcessChannel.ofLink(link)` wraps a `PluginProcessLink`. |
| `EditorLevelAccess` | The editor's level with a Flutter `Listenable changes`; it shares every operation with `PluginLevelAccess` through `EditorLevelOperations`. |
| `asValueListenable()`, `asListenable()`, `asObservable()`, `asChangeSignal()`, `asEditorLevelAccess()`, `asPluginLevelAccess()` | Views between the pure types and Flutter's; each returns the same view for the same source. |
| `LoopbackHost` of `package:lumina_editor_api/testing.dart` | The pure host plus `channel`, a `PluginProcessChannel`. |

See [Layered architecture](../overview/layers.md).

## Live values without Flutter

A plugin process's live values are `lumina_core`'s change types (see [lumina_core](../lumina_core/index.md#change-notification-without-flutter)), re-exported by this package:

| Value | Type |
| :--- | :--- |
| `PluginProcessContext.pluginSettings` | `Observable<Map<String, Object?>>` |
| `PluginProcessSlotButton.state` | `Observable<PluginButtonStateSpec>` (usually an `ObservableValue` the process sets) |
| `registerMenuItem(..., checked:)` | `Observable<bool>?` |
| `PluginLevelAccess.changes` | `ChangeSignal` |
| `PluginProcessLink.state` | `Observable<PluginProcessState>` |

They have the members Flutter's `ValueListenable` has (`value`, `addListener`, `removeListener`), so process code that only calls those is the same either way.

## A plugin process in pure Dart

`example/pure_process.dart` is a complete one: a menu command, a slot button whose `ObservableValue` state changes, an MCP tool, and handlers that edit the level through the editor.

```dart
import 'dart:io';

import 'package:lumina_plugin_process/lumina_plugin_process.dart';

class PureSampleProcess extends LuminaPluginProcess {
  final status = ObservableValue(const PluginButtonStateSpec(icon: PluginIconSpec(0xe88e), tooltip: 'Idle'));

  @override
  String get pluginName => 'pure_sample';

  @override
  void register(PluginProcessContext context) {
    context.handle('placeCrates', (args) => context.level.runTransaction('Place crates', () {
          return context.level.addActors([
            for (var i = 0; i < (args['count'] as int); i++)
              EditorActorSpec(name: 'Crate$i', type: 'StaticMesh', location: [i * 100.0, 0, 0]),
          ]);
        }));
    context.registerSlotButton(PluginProcessSlotButton(
      id: 'pure_sample.status',
      slot: 'statusBarRight',
      state: status,
      command: PluginProcessCommand(id: 'pure_sample.status', label: 'Status', run: () {}),
    ));
  }
}

Future<void> main(List<String> args) async {
  final launch = PluginProcessLaunch.parse(args);
  if (launch == null) exit(64);
  exit(await runPluginProcessMain(launch, PureSampleProcess()));
}
```

The editor still starts its own executable as the plugin process today. Starting a pure-Dart executable like this one instead (one `dart build cli` binary per plugin) is a later step; the API and the protocol do not change for it.

## Testing with LoopbackHost

`LoopbackHost.start()` binds a loopback port and plays the editor's side over a real socket: it answers the handshake, takes the contributions (`host.contributions`), serves `host.*` requests against a small level of its own (`host.level`, with an undo stack of labelled steps) and real directories (`host.root`), and records every notification (`host.notifications`, `host.next(method)`). `host.call(method, args)` sends a `core.*` request; `host.link` is the line a UI shell gets.

The process under test can run in the test's own isolate:

```dart
final host = await LoopbackHost.start();
final exit = runPluginProcessMain(host.launch('pure_sample'), PureSampleProcess());
await host.contributions;
expect(await host.link.call('placeCrates', {'count': 2}), hasLength(2));
await host.call(PluginMethods.shutdown);
expect(await exit, PluginProcessExitCodes.ok);
```

or as a separate program started with `host.launch(name).toArgs()`. `test/two_process_test.dart` starts `dart run example/pure_process.dart` as a real child process and checks the handshake, the contributions, `core.ping`, `core.call`, settings updates, a level transaction, an MCP tool, a menu command and a clean shutdown with exit code 0.

Flutter tests import `package:lumina_editor_api/testing.dart` instead: its `LoopbackHost` is the same host with `channel`, the `PluginProcessChannel` a shell widget takes.

## What a plugin's process part reaches

`package:lumina_plugin_process/testing.dart` also has `PluginProcessReach`, which a plugin's `test/architecture/process_part_reach_test.dart` uses to record what its process part imports:

```dart
const allowed = {'lumina_core', 'lumina_plugin_process', 'path'};
const flutterBound = <String, String>{};   // package → why it needs Flutter

final reach = PluginProcessReach.ofPlugin(Directory.current);
expect(reach.directPackages, allowed, reason: reach.ownLibraries.join('\n'));
expect(reach.directFlutterPackages, flutterBound.keys.toSet(), reason: reach.describeFlutter());
if (flutterBound.isEmpty) expect(reach.flutterPackages, isEmpty, reason: reach.describeFlutter());
```

`ofPlugin` reads the `.lmplugin`, finds the library under `lib/` that declares each `process_class` and walks its `import` / `export` directives (conditional variants included; directives are read from the library header, so `import` lines inside string templates do not count) through the plugin's `.dart_tool/package_config.json`. `directPackages` are the packages the plugin's own reached libraries import; `allPackages` everything reached; `flutterPackages` the reached packages that are part of the Flutter SDK or whose pubspec depends on `sdk: flutter` (`dart:ui` counts as `flutter`); `directFlutterPackages` the direct ones among them; `describeFlutter()` the import chain of each. A process part whose `flutterBound` is empty can run as a plain `dart` program; one that is not names the reason for each package (the engine, `lumina_editor_data`'s Draco-decoding `GlbParserService`, a Flutter plugin package). The plugin template writes this test for every isolated plugin.

`PluginDownloader` (with `PluginFileDef`, `PluginDownloadProgress`, `PluginDownloadCancellationException`) downloads model and data files with SHA-256 checks, authorization headers, free-space checks and progress, and `kCustomAssetTypeKey` / `kAssetPathMetadataKey` are the `.lmas` metadata keys of plugin asset types: both are here so a process part can use them without the Flutter plugin API.

## Tests of the package

Run with `dart test` from `lumina_plugin_process/` (no Flutter involved):

| File | Covers |
| :--- | :--- |
| `test/architecture/pure_dart_test.dart` | Walks every library of the package and every package it imports; fails on Flutter, `dart:ui`, FFI, the engine or the editor. |
| `test/run_plugin_process_handshake_test.dart` | Hello, token and version checks, exit codes, the plugin folder, crash reports, failed registration. |
| `test/run_plugin_process_requests_test.dart` | `core.call`, commands, MCP tools, importers, console commands, declarative views, live slot and menu state, settings, events, progress, editor calls, project hooks. |
| `test/level_proxy_test.dart` | The level proxy: snapshots, transactions, synchronous edits, `core.levelChanged`, the JSON codecs. |
| `test/two_process_test.dart` | A pure-Dart plugin process as a real `dart run` child. |
| `test/process_reach_test.dart` | `PluginProcessReach` on real temp plugin folders: header scan, a pure process part, one that reaches Flutter, a plugin without a process part. |
| `test/plugin_downloader_test.dart` | `PluginDownloader`: free-space check, verified files skipped, cancellation, the server's content length. |

---

[Previous: MCP tools API](../lumina_editor_api/mcp.md) | [Up: Lumina documentation](../../README.md) | [Next: Plugin processes](plugin-processes.md)
