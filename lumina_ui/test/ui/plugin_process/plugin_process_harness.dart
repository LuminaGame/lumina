import 'dart:async';
import 'dart:io';

import 'package:lumina_editor_data/lumina_editor.dart' show EngineLoggerService;
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:lumina_ui/ui/core/services/crash_reporter.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_launcher.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_manager.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_supervisor.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_supervisor_timings.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/host_editor_mcp.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:path/path.dart' as p;

import 'fixtures/fake_plugin_client.dart';

export 'fixtures/fake_plugin_client.dart';

/// The Dart executable of the Flutter SDK running the tests (the fixture
/// is a plain Dart program).
String dartExecutable() {
  final exe = Platform.isWindows ? 'dart.exe' : 'dart';
  final roots = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?) p.join(root, 'bin', 'cache', 'dart-sdk', 'bin', exe),
  ];
  // flutter_tester lives under <flutter>/bin/cache/artifacts/engine/<platform>/.
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 6; i++) {
    roots.add(p.join(dir.path, 'dart-sdk', 'bin', exe));
    dir = dir.parent;
  }
  for (final c in roots) {
    if (File(c).existsSync()) return c;
  }
  return 'dart';
}

/// `lumina_ui/test/ui/plugin_process/fixtures/fake_plugin_process.dart`.
String fixtureScript() {
  final candidates = [
    p.join(Directory.current.path, 'test', 'ui', 'plugin_process', 'fixtures', 'fake_plugin_process.dart'),
    p.join(Directory.current.path, 'lumina_ui', 'test', 'ui', 'plugin_process', 'fixtures', 'fake_plugin_process.dart'),
  ];
  return candidates.firstWhere((c) => File(c).existsSync());
}

/// Test-friendly clock: fast pings and back-off.
const PluginSupervisorTimings kFastTimings = PluginSupervisorTimings(
  pingInterval: Duration(milliseconds: 300),
  missedPingsForHung: 3,
  restartBackoff: [Duration(milliseconds: 200), Duration(milliseconds: 200), Duration(milliseconds: 200)],
  startTimeout: Duration(seconds: 30),
  callTimeout: Duration(seconds: 5),
  commandTimeout: Duration(seconds: 5),
  shutdownTimeout: Duration(seconds: 2),
  levelChangeDebounce: Duration(milliseconds: 50),
);

/// A process part that is never constructed in a child (the fixture is a
/// separate program); the in-process override runs the fixture's client.
class FakeProcessPart extends LuminaPluginProcess {
  @override
  String get pluginName => kFakePluginName;

  @override
  void register(PluginProcessContext context) {}
}

/// A real registry, crash reporter and process manager over a temp
/// directory, running the fixture as the isolated plugin `fake_plugin`.
class PluginProcessHarness {
  PluginProcessHarness._(this.root, this.registry, this.crashReporter, this.mcpTools);

  final Directory root;
  final PluginExtensionRegistry registry;
  final CrashReporter crashReporter;
  final McpToolRegistry mcpTools;
  late final PluginProcessManager manager;
  bool inEditor = false;

  String get controlPath => p.join(root.path, 'control.txt');
  File get commandMarker => File('$controlPath.cmd');

  set mode(String mode) => File(controlPath).writeAsStringSync(mode);

  PluginProcessSupervisor get supervisor => manager.supervisorOf(kFakePluginName)!;

  /// [registry]: an editor's own (its level, panels and project); else a
  /// bare registry over a temp folder.
  static Future<PluginProcessHarness> create({
    PluginSupervisorTimings timings = kFastTimings,
    bool inEditor = false,
    PluginExtensionRegistry? registry,
  }) async {
    final root = await Directory.systemTemp.createTemp('lumina_plugin_process_');
    final tools = McpToolRegistry();
    if (registry == null) {
      registry = PluginExtensionRegistry(logger: EngineLoggerService());
      registry
        ..attachMcp(() => HostEditorMcp(tools))
        ..attachStorage(dataRoot: () => Directory(p.join(root.path, 'data')), projectDir: () => p.join(root.path, 'project'))
        ..attachProjectInfo(() => EditorProjectInfo(name: 'Fixture', dir: p.join(root.path, 'project')));
    }
    final reporter = CrashReporter(dataDir: Directory(p.join(root.path, 'lumina_data')));
    final h = PluginProcessHarness._(root, registry, reporter, tools)..inEditor = inEditor;
    final dart = dartExecutable();
    h.manager = PluginProcessManager(
      host: registry,
      processes: {kFakePluginName: FakeProcessPart.new},
      inEditorProcess: () => h.inEditor ? {kFakePluginName} : const {},
      launcher: PluginProcessLauncher(
        executable: dart,
        leadingArgs: [fixtureScript(), h.controlPath],
        runInShell: Platform.isWindows && dart == 'dart',
      ),
      timings: timings,
      inEditorRunner: (launch, _) => runFakePlugin(launch, controlPath: h.controlPath, inEditor: true),
      crashReporter: () => reporter,
    );
    registry.attachProcesses(h.manager);
    return h;
  }

  Future<void> dispose() async {
    await manager.shutdownAll();
    await crashReporter.detachLog();
    for (var i = 0; i < 10; i++) {
      try {
        await root.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  }
}

/// Polls [condition] every 25 ms until it holds or [timeout] passes.
Future<void> waitFor(bool Function() condition, {Duration timeout = const Duration(seconds: 30), String? reason}) async {
  final sw = Stopwatch()..start();
  while (!condition()) {
    if (sw.elapsed > timeout) throw TimeoutException('waited ${timeout.inSeconds} s for ${reason ?? 'a condition'}');
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

/// Waits until [s] reaches [status].
Future<void> waitForStatus(PluginProcessSupervisor s, PluginProcessStatus status, {Duration timeout = const Duration(seconds: 30)}) =>
    waitFor(() => s.state.value.status == status, timeout: timeout, reason: '${s.pluginName} to be ${status.name} (is ${s.state.value})');
