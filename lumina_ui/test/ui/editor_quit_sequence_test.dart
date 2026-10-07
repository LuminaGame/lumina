import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/window/lumina_window.dart';
import 'package:lumina_ui/ui/core/window/window_state_store.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/fake_native_window.dart';
import '../helpers/temp_project.dart';

/// A plugin whose closing hooks are recorded and, when [hang], never finish.
class _SlowPlugin extends LuminaEditorPlugin {
  _SlowPlugin({this.hang = false});

  final bool hang;
  int shutdowns = 0;

  @override
  String get pluginName => 'slow_plugin';

  @override
  void register(LuminaEditorContext context) {}

  @override
  Future<void> onEditorShutdown() async {
    shutdowns++;
    if (hang) await Completer<void>().future;
  }

  @override
  void unregister(LuminaEditorContext context) {}
}

/// Quitting the editor: the unsaved-changes answer, then the saves and the
/// plugins' closing hooks run under a notice naming each step, the editor
/// keeps painting, a hook that never finishes is cut off, and the window
/// closes exactly once.
void main() {
  const actorCount = 440;
  final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '../../test-assets';
  final barrel = File('$assets/Props/Barrels/bent_barrel.glb');

  late FakeNativeWindow native;
  late Directory root;
  late String projectDir;
  late LuminaWindow window;
  late File levelFile;

  setUp(() {
    native = FakeNativeWindow()..install();
    root = Directory.systemTemp.createTempSync('lumina_quit_');
    window = LuminaWindow(store: WindowStateStore(configDir: Directory('${root.path}/config')..createSync()));
    projectDir = '${root.path}/QuitGame';
    Directory('$projectDir/contents/levels').createSync(recursive: true);
    Directory('$projectDir/contents/meshes').createSync(recursive: true);
    // A level as big as a generated map's: hundreds of StaticMesh actors,
    // each placing its own copy of a real GLB.
    final actors = <Map<String, dynamic>>[
      for (var i = 0; i < actorCount; i++)
        {
          'id': 'road_$i',
          'name': 'Road_$i',
          'type': 'StaticMesh',
          'location': [(i % 20) * 25600.0, (i ~/ 20) * 25600.0, 0.0],
          'rotation': [0.0, 0.0, 0.0],
          'scale': [1.0, 1.0, 1.0],
          'meshAssetPath': (barrel.copySync('$projectDir/contents/meshes/Road_$i.glb')).path.replaceAll(r'\', '/'),
          'components': [
            {'id': 'road_${i}_mesh', 'type': 'LuminaMeshComponent', 'name': 'Mesh Component', 'enabled': true, 'properties': <String, dynamic>{}},
          ],
        },
    ];
    levelFile = File('$projectDir/contents/levels/L_Roads.lmas')
      ..writeAsStringSync(jsonEncode({
        'assetId': 'level_L_Roads',
        'name': 'L_Roads',
        'type': 'level',
        'relativePath': 'contents/levels/L_Roads.lmas',
        'metadata': {'actors': actors},
      }));
    const project = LuminaProject(projectName: 'QuitGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('$projectDir/QuitGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  });

  EditorViewModel? currentVm;

  tearDown(() async {
    if (currentVm != null) {
      await currentVm!.close();
      currentVm = null;
    }
    window.dispose();
    native.uninstall();
    await deleteTempProject(root);
  });

  /// The editor on the big level, with one more actor so the level is dirty.
  Future<EditorViewModel> pumpEditor(WidgetTester tester, {LuminaEditorPlugin? plugin}) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await drainRealIo(tester);
    });
    late EditorViewModel vm;
    await tester.runAsync(() async {
      vm = EditorViewModel(
        initialProject: const LuminaProject(projectName: 'QuitGame', activeLevel: 'contents/levels/L_Main.lmas'),
        projectLocation: root.path,
        enableTimers: false,
        autoInitAssets: false,
      );
      await vm.openLevelGuarded('contents/levels/L_Roads.lmas', ifDirty: UnsavedLevelChoice.discard);
    });
    currentVm = vm;
    if (plugin != null) vm.extensionRegistry.registerPlugin(plugin);
    expect(vm.actors.length, actorCount);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: LuminaWindowScope(window: window, child: MainEditorView(viewModel: vm)),
    ));
    await drainRealIo(tester, rounds: 5);
    return vm;
  }

  /// Every status the quit notice showed, in order, and whether each was
  /// on screen at the next frame.
  List<String> recordNotice(EditorViewModel vm) {
    final shown = <String>[];
    vm.quitStatus.addListener(() {
      final s = vm.quitStatus.value;
      if (s != null && (shown.isEmpty || shown.last != s)) shown.add(s);
    });
    return shown;
  }

  testWidgets('Save shows "Saving <level>…" then "Closing editor…" over the editor, saves the big level, and closes',
      (tester) async {
    final vm = await pumpEditor(tester);
    vm.spawnNewActor('PointLight');
    await tester.pump();
    expect(vm.project.isDirty, isTrue);
    final shown = recordNotice(vm);
    final painted = <String>[];

    await tester.tap(find.byKey(const ValueKey('window_control_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('quit_unsaved_prompt')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quit_unsaved_save')));
    for (var i = 0; i < 200 && !native.destroyed; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final status = find.byKey(const ValueKey('quit_progress_status'));
      if (status.evaluate().isNotEmpty) {
        final text = (tester.widget<Text>(status)).data!;
        if (painted.isEmpty || painted.last != text) painted.add(text);
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }

    expect(native.destroyed, isTrue);
    expect(shown, ['Saving L_Roads…', 'Closing editor…']);
    expect(painted, shown, reason: 'each step is painted before its work runs');
    expect(vm.project.isDirty, isFalse);
    final saved = jsonDecode(levelFile.readAsStringSync()) as Map<String, dynamic>;
    expect((saved['metadata']['actors'] as List).length, actorCount + 1);
  });

  testWidgets("Don't Save writes nothing and closes under \"Closing editor…\"", (tester) async {
    final vm = await pumpEditor(tester);
    vm.spawnNewActor('PointLight');
    await tester.pump();
    final before = levelFile.readAsStringSync();
    final manifest = File('$projectDir/QuitGame.lmproject').readAsStringSync();
    final shown = recordNotice(vm);

    await tester.tap(find.byKey(const ValueKey('window_control_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('quit_unsaved_dont_save')));
    for (var i = 0; i < 50 && !native.destroyed; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(native.destroyed, isTrue);
    expect(shown, ['Closing editor…']);
    expect(levelFile.readAsStringSync(), before, reason: "Don't Save leaves the level on disk as it was");
    expect(File('$projectDir/QuitGame.lmproject').readAsStringSync(), manifest);
    expect(File('$projectDir/lib/levels/l_roads.dart').existsSync(), isFalse, reason: 'no code is generated');
    expect(vm.project.isDirty, isTrue);
  });

  testWidgets('a plugin hook that never finishes is cut off, and a second close meanwhile does not quit twice',
      (tester) async {
    final plugin = _SlowPlugin(hang: true);
    final vm = await pumpEditor(tester, plugin: plugin);
    vm.quitHookTimeout = const Duration(seconds: 2);
    final shown = recordNotice(vm);

    await tester.tap(find.byKey(const ValueKey('window_control_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('quit_unsaved_prompt')), findsNothing, reason: 'the level is clean');
    expect(find.text('Closing plugins…'), findsOneWidget);
    expect(native.destroyed, isFalse, reason: 'the hook is still running');

    // Alt+F4 again while the hook hangs: no prompt, no second sequence.
    await native.emit('close');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('quit_unsaved_prompt')), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    for (var i = 0; i < 20 && !native.destroyed; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(native.destroyed, isTrue, reason: 'the quit went on after the timeout');
    expect(shown, ['Closing plugins…', 'Closing editor…']);
    expect(plugin.shutdowns, 1);
    expect(native.methods.where((m) => m == 'destroy').length, 1);
    expect(vm.logs.any((e) => e.message.contains('onEditorShutdown timed out')), isTrue);
  });

  test('saving the big level for a quit never blocks the UI isolate for long', () async {
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'QuitGame', activeLevel: 'contents/levels/L_Main.lmas'),
      projectLocation: root.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    await vm.openLevelGuarded('contents/levels/L_Roads.lmas', ifDirty: UnsavedLevelChoice.discard);
    vm.spawnNewActor('PointLight');
    // A 1 ms timer measures the longest stretch the event loop was held.
    final clock = Stopwatch()..start();
    var last = 0, longest = 0;
    void tick() {
      final now = clock.elapsedMilliseconds;
      if (now - last > longest) longest = now - last;
      last = now;
    }

    final timer = Timer.periodic(const Duration(milliseconds: 1), (_) => tick());
    // Give background mesh loading a moment to complete.
    await Future<void>.delayed(const Duration(seconds: 3));
    longest = 0;
    await vm.saveLevelAndGenerateCode();
    final saveLongest = longest;
    await vm.prepareQuit();
    timer.cancel();
    vm.dispose();
    expect(vm.project.isDirty, isFalse);
    expect(saveLongest, lessThan(1000), reason: 'saving $actorCount actors held the event loop for $saveLongest ms');
  });
}
