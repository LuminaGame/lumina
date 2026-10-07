import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

import '../helpers/temp_project.dart';

/// A plugin that records every lifecycle call, in order.
class _Probe extends LuminaEditorPlugin {
  _Probe(this.name, this.calls, {this.throwOnClose = false, this.hangOnShutdown = false});

  final String name;
  final List<String> calls;
  final bool throwOnClose;
  final bool hangOnShutdown;
  late PluginStorage storage;

  @override
  String get pluginName => name;

  @override
  void register(LuminaEditorContext context) => storage = context.storage;

  @override
  void onProjectOpened(EditorProjectInfo project) => calls.add('$name.opened ${project.name} ${project.dir}');

  @override
  Future<void> onProjectClosing() async {
    calls.add('$name.closing');
    if (throwOnClose) throw StateError('closing failed');
  }

  @override
  Future<void> onEditorShutdown() async {
    calls.add('$name.shutdown');
    if (hangOnShutdown) await Completer<void>().future;
  }

  @override
  void unregister(LuminaEditorContext context) => calls.add('$name.unregister');
}

void main() {
  late Directory root;
  late Directory data;
  late String projectDir;
  late EditorViewModel vm;
  late List<String> calls;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_plugins14_');
    data = Directory('${root.path}/plugin_data')..createSync();
    PluginDataDir.override = data;
    projectDir = '${root.path}/ProbeGame';
    Directory('$projectDir/contents/levels').createSync(recursive: true);
    const project = LuminaProject(projectName: 'ProbeGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('$projectDir/ProbeGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    calls = [];
  });

  tearDown(() async {
    PluginDataDir.override = null;
    vm.dispose();
    await deleteTempProject(root);
  });

  test('each plugin gets its own user and project store', () async {
    final a = _Probe('probe', calls);
    final b = _Probe('other', calls);
    vm.extensionRegistry.registerPlugin(a);
    vm.extensionRegistry.registerPlugin(b);
    expect(a.storage.userDir.path.replaceAll(r'\', '/'), '${data.path.replaceAll(r'\', '/')}/probe');
    expect(a.storage.projectDir!.path.replaceAll(r'\', '/'), '${projectDir.replaceAll(r'\', '/')}/.lumina/plugins/probe');
    expect(b.storage.userDir.path, isNot(a.storage.userDir.path));
    await a.storage.writeJson('settings', {'x': 1});
    expect(File('${data.path}/probe/settings.json').existsSync(), isTrue);
  });

  test('registering tells the plugin which project is open; close runs onProjectClosing only', () async {
    vm.extensionRegistry.registerPlugin(_Probe('probe', calls));
    expect(calls, ['probe.opened ProbeGame ${vm.projectDirPath}']);
    await vm.shutdownPlugins(exiting: false);
    expect(calls.last, 'probe.closing');
    expect(calls.where((c) => c.contains('shutdown')), isEmpty);
  });

  test('exiting runs closing, shutdown and unregister in order, once; a failing hook does not stop the next plugin', () async {
    vm.extensionRegistry.registerPlugin(_Probe('first', calls, throwOnClose: true));
    vm.extensionRegistry.registerPlugin(_Probe('second', calls));
    calls.clear();
    await vm.shutdownPlugins(exiting: true);
    expect(calls, ['first.closing', 'first.shutdown', 'first.unregister', 'second.closing', 'second.shutdown', 'second.unregister']);
    expect(vm.logger.logs.any((l) => l.level == 'error' && l.source == 'Plugins' && l.message.contains('first') && l.message.contains('closing failed')), isTrue);
    await vm.shutdownPlugins(exiting: true);
    expect(calls, hasLength(6), reason: 'idempotent');
  });

  test('a hook that never completes is abandoned after the timeout', () async {
    vm.extensionRegistry.registerPlugin(_Probe('stuck', calls, hangOnShutdown: true));
    vm.extensionRegistry.registerPlugin(_Probe('after', calls));
    calls.clear();
    await vm.shutdownPlugins(exiting: true, hookTimeout: const Duration(milliseconds: 100));
    expect(calls, contains('after.shutdown'));
    expect(vm.logger.logs.any((l) => l.source == 'Plugins' && l.message.contains('stuck') && l.message.contains('timed out')), isTrue);
  });

  test('restarting through the launcher shuts the plugins down before exiting', () async {
    vm.extensionRegistry.registerPlugin(_Probe('probe', calls));
    calls.clear();
    final original = EditorHandOff.instance;
    addTearDown(() => EditorHandOff.instance = original);
    final events = <String>[];
    EditorHandOff.instance = EditorHandOff(startDetached: (exe, args) async => events.add('start'), exitApp: (code) => events.add('exit $code'));
    await EditorHandOff.instance.restartThroughLauncher(projectDir);
    expect(calls, containsAllInOrder(['probe.closing', 'probe.shutdown', 'probe.unregister']));
    expect(events.last, startsWith('exit'), reason: 'the plugins went first');
  });
}
