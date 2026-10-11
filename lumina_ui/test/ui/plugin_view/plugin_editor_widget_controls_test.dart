import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show EngineLoggerService, LuminaWorkspace;
import 'package:lumina_ui/ui/core/editor_panels/widgets/canvas/editor_canvas.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/table/editor_table.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/timeline/editor_timeline.dart';
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:lumina_ui/ui/core/services/crash_reporter.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_launcher.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_manager.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_supervisor.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_supervisor_timings.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_native_control.dart';
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

/// The timeline, table and canvas spec controls of a real plugin process
/// (the pure sample's Motion panel): rendered by the editor's native
/// widgets, a key drag reaching the process as previews and one commit, the
/// process's patch moving the key, and an unanswered commit reverting after
/// the answer timeout with a toast.
void main() {
  late Directory root;
  late PluginExtensionRegistry registry;
  late PluginProcessManager manager;
  late CrashReporter reporter;

  PluginProcessSupervisor supervisor() => manager.supervisorOf('pure_sample')!;

  Future<void> setUpProcess(WidgetTester tester) async {
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('lumina_plugin_widgets_');
      registry = PluginExtensionRegistry(logger: EngineLoggerService())
        ..attachStorage(dataRoot: () => Directory(p.join(root.path, 'data')), projectDir: () => null);
      reporter = CrashReporter(dataDir: Directory(p.join(root.path, 'lumina_data')));
      manager = PluginProcessManager(
        host: registry,
        processes: {'pure_sample': _PureSamplePart.new},
        launcher: PluginProcessLauncher(
          executable: dartExecutable(),
          leadingArgs: [p.join(LuminaWorkspace.package('lumina_plugin_process'), 'example', 'pure_process.dart')],
        ),
        timings: const PluginSupervisorTimings(pingInterval: Duration(minutes: 10), restartBackoff: []),
        crashReporter: () => reporter,
      );
      registry.attachProcesses(manager);
      await supervisor().start();
      await waitForStatus(supervisor(), PluginProcessStatus.running, timeout: const Duration(seconds: 60));
      await waitFor(() => registry.allPanels.any((d) => d.id == 'pure_sample.motion'), reason: 'the Motion panel');
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

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final panel = registry.allPanels.firstWhere((d) => d.id == 'pure_sample.motion');
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SingleChildScrollView(child: SizedBox(width: 900, child: Builder(builder: panel.builder)))),
    ));
    await tester.pump();
  }

  Future<List<String>> processEvents(WidgetTester tester) async =>
      [for (final e in (await tester.runAsync(() => supervisor().call('motionEvents', const {})))! as List) '$e'];

  /// The pixel of [frame] on [track] in the timeline's track area.
  Offset keyAt(WidgetTester tester, String track, int frame) {
    final s = tester.state<EditorTimelineState>(find.byType(EditorTimeline));
    final l = s.model.layout();
    final row = l.rowOf(track)!;
    return tester.getTopLeft(find.byKey(const ValueKey('editor_timeline_timeline_tracks'))) + Offset(l.xOf(frame), row.top + row.height / 2);
  }

  int frameOf(WidgetTester tester, String key) =>
      tester.state<EditorTimelineState>(find.byType(EditorTimeline)).model.keys.firstWhere((k) => k.id == key).frame;

  Future<void> dragKey(WidgetTester tester, int frames) async {
    final g = await tester.startGesture(keyAt(tester, 'root', 30), kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    for (var i = 1; i <= 20; i++) {
      await g.moveTo(keyAt(tester, 'root', 30) + Offset(frames * 3.0 * i / 20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump();
  }

  testWidgets('the spec timeline, table and canvas render through the native widgets; a key drag sends previews and one commit '
      'and the process patch moves the key', (tester) async {
    await setUpProcess(tester);
    await pumpPanel(tester);
    expect(find.byType(EditorTimeline), findsOneWidget);
    expect(find.byType(EditorTable), findsOneWidget);
    expect(find.byType(EditorCanvas), findsOneWidget);
    expect(find.byKey(const ValueKey('editor_table_bones_row_pelvis')), findsOneWidget);
    expect(frameOf(tester, 'k1'), 30);

    await dragKey(tester, 2);
    expect(frameOf(tester, 'k1'), 32, reason: 'shown at once');
    late List<String> events;
    for (var i = 0; i < 100; i++) {
      events = await processEvents(tester);
      if (events.any((e) => e.endsWith(':commit'))) break;
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    }
    final keyEvents = [for (final e in events) if (e.startsWith('timeline:keysMoved')) e];
    expect(keyEvents.where((e) => e.endsWith(':preview')), isNotEmpty);
    expect(keyEvents.where((e) => e.endsWith(':commit')), hasLength(1));
    expect(keyEvents.last, 'timeline:keysMoved:commit');
    // The process answers with the moved keys: the patch replaces the overlay.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(PluginNativeControl.answerTimeout + const Duration(seconds: 1));
    expect(frameOf(tester, 'k1'), 32, reason: 'answered: kept after the timeout');
    expect(find.byKey(const ValueKey('plugin_native_control_reverted_timeline')), findsNothing);
  });

  testWidgets('a commit with no patch for 10 s reverts with a toast', (tester) async {
    await setUpProcess(tester);
    await tester.runAsync(() => supervisor().call('holdAnswers', {'hold': true}));
    await pumpPanel(tester);
    await dragKey(tester, 4);
    expect(frameOf(tester, 'k1'), 34);
    await tester.pump(const Duration(seconds: 9));
    expect(frameOf(tester, 'k1'), 34, reason: 'still waiting');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(frameOf(tester, 'k1'), 30, reason: 'reverted');
    expect(find.byKey(const ValueKey('plugin_native_control_reverted_timeline')), findsOneWidget);
    // The view events' requests finish (the process acknowledged each).
    final sent = await processEvents(tester);
    expect(sent.where((e) => e == 'timeline:keysMoved:commit'), hasLength(1));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
