import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/host/launch_model_files.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Smoke — model files opened with Lumina Studio from the file manager.
///
/// The real editor started with two model paths (what Explorer's or a Linux
/// file manager's "Open with" passes): the launcher says it will import them
/// into the project the user opens; the opened project imports the glTF
/// barrel and the FBX casino chair through the import queue and shows the
/// barrel in its mesh editor, which is orbited. PNGs of the launcher and of
/// the mesh editor, plus a WebM of the whole scenario.
///
/// Runs on GPU 1 (NVIDIA RTX PRO 2000) — `tool/smoke_report.dart` injects the
/// GPU environment.
Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const usedAssets = ['Props/Barrels/fuel_barrel_red.glb', 'FBX/StaticMeshes/SM_Casino_Chair.FBX'];
  const testName = 'OS Integration Smoke: model files opened with Lumina Studio are imported into the opened project';

  testWidgets(testName, (tester) async {
    final assets = SmokeArtifacts.testAssetsDir.path;
    for (final rel in usedAssets) {
      if (!File('$assets/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    final root = Directory.systemTemp.createTempSync('os_open_with_smoke_');
    EditorViewModel? vm;
    try {
      // The arguments a file manager passes.
      final files = (await tester.runAsync(() => LaunchModelFiles.resolve([for (final rel in usedAssets) '$assets/$rel'])))!;
      expect(files, hasLength(2));
      LaunchModelFiles.pending.value = files;

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final boundaryKey = GlobalKey();

      // 1. The launcher names the files it will import.
      final launcher = LauncherViewModel(configDir: Directory(p.join(root.path, '.config'))..createSync(recursive: true));
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: LauncherView(viewModel: launcher)),
      ));
      await _settle(tester, 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      expect(find.textContaining('Open or create a project to import fuel_barrel_red.glb, SM_Casino_Chair.FBX into it'),
          findsOneWidget);
      await rec.hold(const Duration(seconds: 2));
      SmokeArtifacts.saveScreenshot(
        'os_open_with_launcher_banner',
        await SmokeArtifacts.captureWidgetPng(tester, find.byKey(boundaryKey)),
        usedAssets: usedAssets,
      );

      // 2. The user opens a project: it imports the files.
      final project = (await tester.runAsync(() => ProjectRepository(configDir: Directory(p.join(root.path, '.config')))
          .createProject(projectName: 'open_with_smoke', projectLocation: root.path)))!;
      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
      final editor = vm;
      await tester.runAsync(() => editor.ensureDefaultLevelAssets());
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
      ));
      bool isBarrel(RealAssetInfo? a) => a != null && p.basename(a.relativePath).contains('fuel_barrel_red');
      for (var i = 0; i < 600 && !editor.openTabs.any((t) => isBarrel(t.asset)); i++) {
        await rec.hold(const Duration(milliseconds: 100));
      }
      expect(LaunchModelFiles.pending.value, isEmpty);
      expect(isBarrel(editor.currentTab.asset), isTrue, reason: 'the first imported model opened in its editor');
      for (var i = 0; i < 300 && editor.isBatchImporting; i++) {
        await rec.hold(const Duration(milliseconds: 100));
      }
      final meshes = p.join(editor.projectDirPath, 'contents', 'meshes', 'static');
      expect(File(p.join(meshes, 'fuel_barrel_red.lmas')).existsSync(), isTrue);
      expect(File(p.join(meshes, 'SM_Casino_Chair.lmas')).existsSync(), isTrue);
      await rec.hold(const Duration(seconds: 2));

      // 3. Orbit the barrel in the mesh editor's preview.
      final preview = tester.getCenter(find.byType(SubEditor3DViewport).first);
      await rec.drag(preview - const Offset(160, 0), preview + const Offset(160, 0), steps: 60);
      await rec.hold(const Duration(seconds: 1));
      SmokeArtifacts.saveScreenshot(
        'os_open_with_imported_in_mesh_editor',
        await SmokeArtifacts.captureWidgetPng(tester, find.byKey(boundaryKey)),
        usedAssets: usedAssets,
      );
      await rec.drag(preview + const Offset(160, 0), preview - const Offset(120, 0), steps: 60);
      await rec.hold(const Duration(seconds: 6));
      expect(rec.recorded, greaterThanOrEqualTo(const Duration(seconds: 10)));
      rec.save(testName, usedAssets: usedAssets);
    } finally {
      LaunchModelFiles.pending.value = const [];
      vm?.dispose();
      try {
        if (root.existsSync()) root.deleteSync(recursive: true);
      } on FileSystemException catch (_) {}
    }
  });
}
