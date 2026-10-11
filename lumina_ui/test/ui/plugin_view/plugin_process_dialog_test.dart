import 'dart:io';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show EngineLoggerService, LuminaWorkspace;
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:lumina_ui/ui/core/services/crash_reporter.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_dialog_queue.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_launcher.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_manager.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_supervisor.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_supervisor_timings.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_process_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../plugin_process/plugin_process_harness.dart' show dartExecutable, waitFor, waitForStatus;

/// A process part that never runs in this isolate: the pure sample runs as
/// its own `dart` program.
class _PureSamplePart extends LuminaPluginProcess {
  @override
  String get pluginName => 'pure_sample';

  @override
  void register(PluginProcessContext context) {}
}

/// Dialogs a real plugin process (the pure sample, run with `dart`) opens
/// over the editor.
void main() {
  late Directory root;
  late PluginDialogQueue dialogs;
  late PluginProcessManager manager;
  late CrashReporter reporter;

  PluginProcessSupervisor supervisor() => manager.supervisorOf('pure_sample')!;

  Future<void> setUpProcess(WidgetTester tester) async {
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('lumina_plugin_dialog_');
      final registry = PluginExtensionRegistry(logger: EngineLoggerService())
        ..attachStorage(dataRoot: () => Directory(p.join(root.path, 'data')), projectDir: () => null);
      reporter = CrashReporter(dataDir: Directory(p.join(root.path, 'lumina_data')));
      dialogs = PluginDialogQueue();
      manager = PluginProcessManager(
        host: registry,
        processes: {'pure_sample': _PureSamplePart.new},
        launcher: PluginProcessLauncher(
          executable: dartExecutable(),
          leadingArgs: [p.join(LuminaWorkspace.package('lumina_plugin_process'), 'example', 'pure_process.dart')],
        ),
        // The widget test's frames starve the real event loop between
        // pumps: no health checks or restarts get in the way.
        timings: const PluginSupervisorTimings(pingInterval: Duration(minutes: 10), restartBackoff: []),
        crashReporter: () => reporter,
        dialogs: dialogs,
      );
      registry.attachProcesses(manager);
      await supervisor().start();
      await waitForStatus(supervisor(), PluginProcessStatus.running, timeout: const Duration(seconds: 60));
    });
    addTearDown(() => tester.runAsync(() async {
          await manager.shutdownAll();
          await reporter.detachLog();
          try {
            await root.delete(recursive: true);
          } on FileSystemException {
            // Cleaned with the temp folder later.
          }
        }));
  }

  /// The editor stand-in: a counter that keeps ticking behind the layer.
  final ticks = ValueNotifier<int>(0);

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      builder: (context, child) => PluginDialogLayer(queue: dialogs, child: child ?? const SizedBox.shrink()),
      home: Scaffold(
        child: Center(
          child: ValueListenableBuilder<int>(
            valueListenable: ticks,
            builder: (context, v, _) => Text('frame $v', key: const ValueKey('editor_frame')),
          ),
        ),
      ),
    ));
  }

  /// Asks the process to open its name dialog; completes with the answer.
  /// The request is made outside the test's fake clock (real sockets).
  Future<Future<Object?>> ask(WidgetTester tester, String id) async {
    late Future<Object?> answer;
    await tester.runAsync(() async {
      answer = supervisor().call('askName', {'id': id, 'initial': ''}).then<Object?>((v) => v, onError: (Object e) => e);
    });
    return answer;
  }

  Future<void> untilShown(WidgetTester tester, String id) async {
    await tester.runAsync(() => waitFor(() => dialogs.current?.spec.id == id, reason: 'dialog $id'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a dialog opened by the process: typing "Barrel" and Accept answer it; the editor keeps drawing',
      (tester) async {
    await setUpProcess(tester);
    await pumpEditor(tester);
    final answer = await ask(tester, 'a');
    await untilShown(tester, 'a');
    expect(find.byKey(const ValueKey('plugin_dialog_pure_sample_a')), findsOneWidget);
    expect(find.text('Name the actor'), findsOneWidget);

    // The editor frame does not wait on the dialog.
    ticks.value++;
    await tester.pump();
    expect(find.text('frame 1'), findsOneWidget);

    final field = find.byType(EditableText);
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, 'Barrel');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plugin_dialog_action_accept')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    final result = await tester.runAsync(() => answer.timeout(const Duration(seconds: 20)));
    expect(result, {'action': 'accept', 'values': {'name': 'Barrel'}});
    expect(find.byKey(const ValueKey('plugin_dialog_pure_sample_a')), findsNothing);
  });

  testWidgets('Escape on a dismissible dialog answers null; a second request waits for the first', (tester) async {
    await setUpProcess(tester);
    await pumpEditor(tester);
    final first = await ask(tester, 'first');
    await untilShown(tester, 'first');
    final second = await ask(tester, 'second');
    await tester.runAsync(() => waitFor(() => dialogs.pending.length == 2, reason: 'the queued request'));
    await tester.pump();
    expect(find.byKey(const ValueKey('plugin_dialog_pure_sample_second')), findsNothing, reason: 'it waits');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(await tester.runAsync(() => first.timeout(const Duration(seconds: 20))), {'action': null, 'values': <String, Object?>{}});
    await tester.pump();
    expect(find.byKey(const ValueKey('plugin_dialog_pure_sample_second')), findsOneWidget, reason: 'opens after the first');

    await tester.tap(find.byKey(const ValueKey('plugin_dialog_action_cancel')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect((await tester.runAsync(() => second.timeout(const Duration(seconds: 20))) as Map)['action'], 'cancel');
  });

  testWidgets('closeDialog from the process closes it; killing the process closes its dialog', (tester) async {
    await setUpProcess(tester);
    await pumpEditor(tester);
    final closed = await ask(tester, 'closing');
    await untilShown(tester, 'closing');
    expect(await tester.runAsync(() => supervisor().call('closeDialog', {'id': 'closing'})), isTrue);
    expect((await tester.runAsync(() => closed.timeout(const Duration(seconds: 20))) as Map)['action'], isNull);
    await tester.pump();
    expect(find.byKey(const ValueKey('plugin_dialog_pure_sample_closing')), findsNothing);

    final orphan = await ask(tester, 'orphan');
    await untilShown(tester, 'orphan');
    expect(Process.killPid(supervisor().reportedPid!, ProcessSignal.sigkill), isTrue);
    await tester.runAsync(() => waitFor(() => dialogs.current == null, reason: 'the dead process closes its dialog'));
    await tester.pump();
    expect(find.byKey(const ValueKey('plugin_dialog_pure_sample_orphan')), findsNothing);
    final outcome = await tester.runAsync(() => orphan.timeout(const Duration(seconds: 20)));
    expect(outcome, isA<PluginRemoteError>(), reason: 'the caller learns the process went away');
  });
}
