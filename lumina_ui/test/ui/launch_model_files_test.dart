import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/host/launch_model_files.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/launcher/views/pending_model_import_banner.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Lumina Studio started from a file manager's "Open with" on a model file:
/// the path arrives as an argument, the launcher says it will import it into
/// the project the user opens, and the opened editor imports it and shows it
/// in its sub-editor.
void main() {
  final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';
  final barrel = File('$assets/Props/Barrels/fuel_barrel_red.glb');

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('lumina_launch_files_'));
  tearDown(() {
    LaunchModelFiles.pending.value = const [];
    LaunchModelFiles.pendingAssets.value = const [];
    try {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {
      // Windows: a background thumbnail may still hold a file a moment.
    }
  });

  File touch(String name) => File(p.join(temp.path, name))..writeAsStringSync('x');

  group('LaunchModelFiles.resolve', () {
    test('a positional model path, made absolute', () async {
      final glb = touch('fuel.glb');
      expect(await LaunchModelFiles.resolve([glb.path]), [p.normalize(glb.absolute.path)]);
    });

    test('--import in both spellings, any case of extension', () async {
      final fbx = touch('Chair.FBX');
      final obj = touch('cube.obj');
      final gltf = touch('scene.gltf');
      expect(await LaunchModelFiles.resolve(['--import', fbx.path, '--import=${obj.path}', gltf.path]),
          [fbx.path, obj.path, gltf.path].map((f) => p.normalize(File(f).absolute.path)).toList());
    });

    test('other files, missing files and flag values are not imports', () async {
      final txt = touch('notes.txt');
      final glb = touch('tree.glb');
      final project = Directory(p.join(temp.path, 'Game'))..createSync();
      final files = await LaunchModelFiles.resolve([
        txt.path,
        p.join(temp.path, 'gone.glb'),
        '--project',
        project.path,
        '--launcher-exe',
        p.join(temp.path, 'other.glb'),
        '--no-plugins',
        glb.path,
      ]);
      expect(files, [p.normalize(glb.absolute.path)]);
    });

    test('a file named twice is imported once', () async {
      final glb = touch('rock.glb');
      expect(await LaunchModelFiles.resolve([glb.path, '--import', glb.path]), hasLength(1));
    });
  });

  test('the hand-off to a project editor carries the pending files', () {
    expect(LaunchModelFiles.handOffArguments(['/a/x.glb', '/b/y.fbx']), ['--import', '/a/x.glb', '--import', '/b/y.fbx']);
    expect(LaunchModelFiles.handOffArguments(const []), isEmpty);
  });

  group('Lumina assets (.lmas)', () {
    test('a positional .lmas or --open-asset is an asset to open, not a model to import', () async {
      final a = touch('SM_Rock.lmas');
      final b = touch('M_Rock.LMAS');
      final args = [a.path, '--open-asset', b.path, '--open-asset=${p.join(temp.path, 'gone.lmas')}'];
      expect(await LaunchModelFiles.resolveAssets(args), [a.path, b.path].map((f) => p.normalize(File(f).absolute.path)).toList());
      expect(await LaunchModelFiles.resolve(args), isEmpty);
    });

    test('its project is the nearest folder above it with a .lmproject', () async {
      final project = Directory(p.join(temp.path, 'Game'))..createSync();
      File(p.join(project.path, 'Game.lmproject')).writeAsStringSync('{"project_name": "Game"}');
      final asset = File(p.join(project.path, 'contents', 'meshes', 'static', 'SM_Rock.lmas'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('{}');
      expect(await LaunchModelFiles.projectOf(asset.path), p.normalize(project.absolute.path));
      expect(await LaunchModelFiles.projectOf(touch('loose.lmas').path), isNull);
    });

    test('the hand-off carries the assets to open', () {
      expect(LaunchModelFiles.assetHandOffArguments(['/g/contents/a.lmas']), ['--open-asset', '/g/contents/a.lmas']);
    });
  });

  test('take empties the pending list once', () {
    LaunchModelFiles.pending.value = ['/a/x.glb'];
    expect(LaunchModelFiles.take(), ['/a/x.glb']);
    expect(LaunchModelFiles.take(), isEmpty);
  });

  testWidgets('the launcher names the pending files and can drop them', (tester) async {
    LaunchModelFiles.pending.value = [p.join(temp.path, 'fuel_barrel_red.glb'), p.join(temp.path, 'SM_Casino_Chair.FBX')];
    final vm = LauncherViewModel(configDir: Directory(p.join(temp.path, 'config'))..createSync());
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: LauncherView(viewModel: vm)));
    await tester.pumpAndSettle();
    expect(find.byType(PendingModelImportBanner), findsOneWidget);
    expect(find.textContaining('Open or create a project to import fuel_barrel_red.glb, SM_Casino_Chair.FBX into it'),
        findsOneWidget);
    await tester.tap(find.text("Don't import"));
    await tester.pumpAndSettle();
    expect(LaunchModelFiles.pending.value, isEmpty);
    expect(find.textContaining('Open or create a project to import'), findsNothing);
  });

  testWidgets('without pending files the launcher shows no banner', (tester) async {
    final vm = LauncherViewModel(configDir: Directory(p.join(temp.path, 'config'))..createSync());
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: LauncherView(viewModel: vm)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Open or create a project to import'), findsNothing);
  });

  testWidgets('the opened project imports the pending model and opens it in its editor', (tester) async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final dir = Directory(p.join(temp.path, 'OpenWithGame'))..createSync(recursive: true);
    Directory(p.join(dir.path, 'contents', 'levels')).createSync(recursive: true);
    File(p.join(dir.path, 'OpenWithGame.lmproject'))
        .writeAsStringSync('{"project_name": "OpenWithGame", "active_level": "contents/levels/L_Main.lmas"}');
    final vm = EditorViewModel(
      initialProject: LuminaProject(projectName: 'OpenWithGame'),
      projectLocation: temp.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    LaunchModelFiles.pending.value = [barrel.path];

    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    final clock = Stopwatch()..start();
    bool isBarrel(RealAssetInfo? a) => a != null && p.basename(a.relativePath).contains('fuel_barrel_red');
    bool opened() => vm.openTabs.any((t) => isBarrel(t.asset));
    while (!opened() && clock.elapsed < const Duration(seconds: 90)) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(LaunchModelFiles.pending.value, isEmpty, reason: 'the pending list is consumed once');
    final mesh = File(p.join(dir.path, 'contents', 'meshes', 'static', 'fuel_barrel_red.lmas'));
    expect(mesh.existsSync(), isTrue, reason: 'the model was imported into the project');
    expect(opened(), isTrue, reason: 'the imported mesh opened in its sub-editor');
    expect(isBarrel(vm.currentTab.asset), isTrue, reason: 'its tab is the active one');
    // The import panel dismisses itself 5 s after a clean batch.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('an .lmas opened with Lumina Studio opens in its editor in its project', (tester) async {
    if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final dir = Directory(p.join(temp.path, 'AssetGame'))..createSync(recursive: true);
    Directory(p.join(dir.path, 'contents', 'levels')).createSync(recursive: true);
    File(p.join(dir.path, 'AssetGame.lmproject'))
        .writeAsStringSync('{"project_name": "AssetGame", "active_level": "contents/levels/L_Main.lmas"}');
    await tester.runAsync(() => AssetRepository().importExternalFile(projectPath: dir.path, sourceFilePath: barrel.path));
    final mesh = p.join(dir.path, 'contents', 'meshes', 'static', 'fuel_barrel_red.lmas');
    expect(File(mesh).existsSync(), isTrue);
    expect(await tester.runAsync(() => LaunchModelFiles.projectOf(mesh)), p.normalize(dir.absolute.path));

    final vm = EditorViewModel(
      initialProject: LuminaProject(projectName: 'AssetGame'),
      projectLocation: temp.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    LaunchModelFiles.pendingAssets.value = [p.normalize(mesh)];
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    bool opened() => vm.openTabs.any((t) => t.asset != null && p.basename(t.asset!.relativePath) == 'fuel_barrel_red.lmas');
    for (var i = 0; i < 100 && !opened(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(opened(), isTrue, reason: 'the asset opened in its editor');
    expect(LaunchModelFiles.pendingAssets.value, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
