import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A level with 150 actors opens in the editor: the meshes stream in over
/// frames, nearest the camera first, while the viewport keeps drawing and the
/// stat strip counts what is left.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const usedAssets = ['Props/Barrels/fuel_barrel_red.glb'];
  const actorCount = 150;

  testWidgets('Streaming Smoke: 150 actors fill the viewport over frames while the editor keeps drawing', (tester) async {
    const name = 'Streaming Smoke: 150 actors fill the viewport over frames while the editor keeps drawing';
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_stream_smoke_');
    const project = LuminaProject(projectName: 'StreamSmoke', activeLevel: 'contents/levels/L_Main.lmas');
    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      final src = File('${SmokeArtifacts.testAssetsDir.path}/${usedAssets.first}');
      expect(src.existsSync(), isTrue, reason: 'seed asset must exist');
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: src.path));
      final imported = vm.realAssets.firstWhere((a) => a.fileName.startsWith('fuel_barrel_red'));
      await tester.runAsync(() => vm.spawnActorFromAsset(imported, location: [0.0, 0.0, 0.0]));
      final seed = vm.actors.firstWhere((a) => a.meshAssetPath != null && a.type != 'Folder');
      final meshPath = seed.meshAssetPath!;

      // The level as a save would hold it: 150 barrels on a grid, none with
      // mesh data yet (that is what the stream loads).
      final grid = <EditorActorNode>[
        for (final a in vm.actors)
          if (a.id != seed.id) a,
        for (var i = 0; i < actorCount; i++)
          EditorActorNode(
            id: 'barrel_$i',
            name: 'Barrel $i',
            type: seed.type,
            location: [(i % 15) * 150.0 - 1050.0, (i ~/ 15) * 150.0 - 675.0, 0.0],
            meshAssetPath: meshPath,
          ),
      ];
      vm.restoreSnapshot(grid);
      vm.restoreCameraSnapshot([-35, 30, 2600, 0, 0, 0]);

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: boundaryKey, child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm))),
      );

      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(40);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      // The empty grid first: the video must show the level before it fills.
      await rec.hold(const Duration(seconds: 3));

      final viewportFinder = find.byType(ViewportWidget);
      final dynamic viewportState = viewportFinder.evaluate().isEmpty ? null : tester.state(viewportFinder);
      int bound() => (viewportState?.editorActorsInSceneForTest as int?) ?? -1;

      Future<Uint8List> shot(String label) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($label)', png, usedAssets: usedAssets);
        return png;
      }

      await shot('before');
      final before = bound();
      // The stream, as a project open starts it: the viewport fills in while
      // the recorder keeps asking for frames.
      final loading = vm.loadLevelMeshes(reframeWhenDone: true);
      var sawCounter = false;
      var partial = -1;
      final started = DateTime.now();
      while (DateTime.now().difference(started) < const Duration(seconds: 40)) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        await rec.captureIfChanged();
        if (vm.meshesLoading) sawCounter = true;
        final b = bound();
        if (b > 0 && b < actorCount && partial < 0) {
          partial = b;
          await shot('streaming');
        }
        if (!vm.meshesLoading && b >= actorCount) break;
      }
      await tester.runAsync(() => loading);
      await settle(30);
      // Orbit the loaded level: the camera moves while every barrel is in.
      for (var i = 0; i < 120; i++) {
        vm.orbitCamera(3, i < 60 ? 0.5 : -0.5);
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        await rec.captureIfChanged();
      }
      await rec.hold(const Duration(seconds: 2));
      await shot('loaded');
      rec.save(name, usedAssets: usedAssets);

      debugPrint('[streaming_smoke] bound before: $before, first partial frame: $partial, at the end: ${bound()}');
      expect(sawCounter, isTrue, reason: 'the stat strip counted the stream');
      expect(find.textContaining('Meshes:'), findsNothing, reason: 'the counter leaves once everything is in');
      if (viewportState != null) {
        expect(partial, greaterThan(0), reason: 'meshes appeared over frames, not all at once');
        expect(bound(), greaterThanOrEqualTo(actorCount), reason: 'every barrel is in the scene at the end');
      }
      for (final a in vm.actors.where((a) => a.id.startsWith('barrel_'))) {
        expect(a.meshData, isNotNull, reason: '${a.id} has its mesh');
      }
      vm.dispose();
    } finally {
      try {
        tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {
        // a cache writer may still hold a file; the OS temp folder is cleaned later
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
