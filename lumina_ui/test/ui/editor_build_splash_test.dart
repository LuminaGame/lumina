import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/editor_build_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/editor_build_splash.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/editor_host_fixture.dart';
import '../helpers/replay_process.dart';
import '../helpers/temp_project.dart';

/// The editor splash, driven by a real [EditorBuildService]
/// (generation and `pub get` run for real; `flutter build` is the recorded
/// real output of a generated host, replayed line by line).
void main() {
  final recorded = recordedEditorBuildLog();
  final hookDone = [for (var i = 0; i < recorded.length; i++) if (recorded[i].contains('output.json contents:')) i];
  final statusPattern = RegExp(r'^\d{1,3}% - .+$');

  late EditorHostFixture fx;
  late LuminaPluginDescriptor plugin;
  setUp(() async {
    fx = EditorHostFixture.create();
    plugin = await PluginRepository(roots: []).loadInternal(File(p.join(fx.pluginDir.path, 'a_plugin.lmplugin')), PluginOrigin.project);
  });
  tearDown(() => deleteTempProject(fx.temp));

  EditorBuildViewModel buildViewModel(Process Function() build, {bool hasPlugins = true}) {
    final service = EditorBuildService(
      engineRoot: LuminaWorkspace.root,
      // The source copy as links (the real copy is the smoke run's).
      vendor: EditorSourceVendorService(engineRoot: LuminaWorkspace.root, linkPackages: true),
      hostAliasRoot: Directory(p.join(fx.temp.path, 'hosts')),
      cache: EditorBuildCache(root: Directory(p.join(fx.temp.path, 'cache', 'editor-builds'))),
      platform: 'windows',
      flutterExecutable: Platform.isWindows ? 'flutter.bat' : 'flutter',
      flutterInfo: fixedFlutterInfo,
      killTree: (pid) async {},
      processStarter: (exe, args, {workingDirectory, environment}) async => args.first == 'build'
          ? build()
          : defaultEditorBuildProcessStarter(exe, args, workingDirectory: workingDirectory, environment: environment),
    );
    return EditorBuildViewModel(
      projectName: 'HostGame',
      projectDir: fx.projectDir.path,
      engineVersion: kLuminaEngineVersion,
      hasPlugins: hasPlugins,
      // The build's real processes and file IO run on the real event loop;
      // the splash (in the test's fake-async zone) sees its events on pump.
      startBuild: () => Zone.root.run(() => service.start(fx.projectDir.path, [plugin], projectName: 'HostGame')),
    );
  }

  var closed = 0, withoutPlugins = 0, succeeded = 0;
  Future<void> pumpSplash(WidgetTester tester, EditorBuildViewModel vm) async {
    closed = withoutPlugins = succeeded = 0;
    tester.view.physicalSize = EditorBuildSplash.windowSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: EditorBuildSplash(
        viewModel: vm,
        manageWindow: false,
        onSucceeded: (_) => succeeded++,
        onOpenWithoutPlugins: () => withoutPlugins++,
        onClose: () => closed++,
      ),
    ));
  }

  String status(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('editor_build_status'))).data!;

  /// Pumps real IO until [done]; checks the status line on every frame.
  Future<void> drive(WidgetTester tester, EditorBuildViewModel vm, bool Function() done) async {
    for (var i = 0; i < 1500 && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
      if (vm.state == EditorBuildSplashState.running) {
        expect(status(tester), matches(statusPattern));
      }
    }
    expect(done(), isTrue, reason: 'the build reached the expected state (${status(tester)})');
  }

  testWidgets('45 %: native assets on the status line, the golden, Show log and Cancel', (tester) async {
    // The build stops after the second of the three hooks.
    ReplayProcess? proc;
    final vm = buildViewModel(() => proc = ReplayProcess(recorded.take(hookDone[1] + 1).toList(), hang: true));
    await pumpSplash(tester, vm);
    await drive(tester, vm, () => vm.percent >= 45 && vm.phase == EditorBuildPhase.buildingNativeAssets);
    await tester.pump(const Duration(milliseconds: 300));
    expect(status(tester), '45% - Building native assets (flutter_filament)');
    expect(find.text('Lumina Studio'), findsOneWidget);
    expect(find.text('Lumina Editor $kLuminaEngineVersion · HostGame'), findsOneWidget);
    final bar = tester.widget<FractionallySizedBox>(find.byKey(const Key('editor_build_progress_bar')));
    expect(bar.widthFactor, closeTo(vm.fraction, 1e-9));
    await expectLater(find.byKey(const Key('editor_build_splash')),
        matchesGoldenFile('goldens/editor_build_splash_45_${Platform.operatingSystem}.png'));

    // Hovering shows Show log and Cancel.
    expect(tester.widget<AnimatedOpacity>(find.ancestor(of: find.byKey(const Key('editor_build_show_log')), matching: find.byType(AnimatedOpacity))).opacity, 0);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byKey(const Key('editor_build_splash'))));
    addTearDown(mouse.removePointer);
    await mouse.moveBy(const Offset(1, 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<AnimatedOpacity>(find.ancestor(of: find.byKey(const Key('editor_build_show_log')), matching: find.byType(AnimatedOpacity))).opacity, 1);

    // Show log: the last lines of the real build output.
    await tester.tap(find.byKey(const Key('editor_build_show_log')));
    await tester.pump();
    expect(find.byKey(const Key('editor_build_log_tail')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('editor_build_log_tail')), matching: find.textContaining('output.json')), findsWidgets);

    // The whole log scrolls: it opens at the latest line and scrolls back
    // to the earlier ones, which stay in view.
    final logList = find.byKey(const Key('editor_build_log_list'));
    final position = tester.state<ScrollableState>(find.descendant(of: logList, matching: find.byType(Scrollable))).position;
    expect(vm.logLines.length, greaterThan(EditorBuildViewModel.logTailLines));
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, 0, reason: 'the log opens at its latest line');
    await tester.drag(logList, const Offset(0, 60));
    await tester.pump();
    expect(position.pixels, greaterThan(0), reason: 'dragging down scrolls back to earlier lines');

    // Cancel kills the build and goes back to the launcher.
    await tester.tap(find.byKey(const Key('editor_build_cancel')));
    proc?.kill();
    await drive(tester, vm, () => closed == 1);
    expect(vm.state, EditorBuildSplashState.cancelled);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });

  testWidgets('a failed build: "Build failed — see log", the log open, and Open without plugins / Retry / Open log file / Close',
      (tester) async {
    final vm = buildViewModel(() => ReplayProcess([...recorded.take(500), 'error MSB8066: Custom build exited with code 1.', 'Build FAILED.'], code: 1));
    await pumpSplash(tester, vm);
    await drive(tester, vm, () => vm.state == EditorBuildSplashState.failed);
    await tester.pump(const Duration(milliseconds: 300));
    expect(status(tester), 'Build failed — see log');
    expect(find.byKey(const Key('editor_build_log_tail')), findsOneWidget, reason: 'the log opens on failure');
    expect(find.textContaining('Build FAILED.'), findsWidgets);
    for (final label in ['Open without plugins', 'Retry', 'Open log file', 'Close']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(vm.logPath, isNotNull);
    expect(File(vm.logPath!).readAsStringSync(), contains('error MSB8066'));

    await tester.tap(find.text('Open without plugins'));
    expect(withoutPlugins, 1);
    await tester.tap(find.text('Close'));
    expect(closed, 1);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
  // A project without code plugins builds its editor too; a
  // failed build then offers this editor, not "without plugins".
  testWidgets('a failed plugin-less build offers "Open in this editor"', (tester) async {
    final vm = buildViewModel(() => ReplayProcess([...recorded.take(200), 'Build FAILED.'], code: 1), hasPlugins: false);
    await pumpSplash(tester, vm);
    await drive(tester, vm, () => vm.state == EditorBuildSplashState.failed);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Open in this editor'), findsOneWidget);
    expect(find.text('Open without plugins'), findsNothing);
    final before = withoutPlugins;
    await tester.tap(find.text('Open in this editor'));
    expect(withoutPlugins, before + 1, reason: 'the same fallback: the stock editor');
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
