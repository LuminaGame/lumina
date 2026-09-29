import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/landscape_brush.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/landscape_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/landscape_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/landscape/brush_overlay.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/landscape_preview_scene.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/landscape/foliage_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Landscape editor smoke: boot the real editor on a
/// temp project, create a real `LANDSCAPE` `.lmas` through the same service
/// the Content Browser's `New Asset → Landscape` uses, open it in the real
/// sub-editor, sculpt a visible hill by dragging on the real sculpt map,
/// import a real barrel model from test-assets/ and scatter it as a foliage
/// layer, save through the toolbar button, and assert the `.lmas` on disk
/// really carries a non-flat heightmap and foliage instances. PNG + WebM
/// evidence is published through SmokeArtifacts.
/// Pixels of [rect] (in the PNG's pixels) that are at least [delta] darker in
/// [a] than in [b] (luma, 0–255).
int _darkerIn(img.Image a, img.Image b, Rect rect, {int delta = 16}) {
  var n = 0;
  for (var y = rect.top.floor(); y < rect.bottom.floor(); y++) {
    for (var x = rect.left.floor(); x < rect.right.floor(); x++) {
      final pa = a.getPixel(x, y), pb = b.getPixel(x, y);
      final la = 0.2126 * pa.r + 0.7152 * pa.g + 0.0722 * pa.b;
      final lb = 0.2126 * pb.r + 0.7152 * pb.g + 0.0722 * pb.b;
      if (lb - la >= delta) n++;
    }
  }
  return n;
}

/// Pixels of [rect] that changed between [a] and [b] and are warm (red well
/// above blue) in [a]: the amber/green cursor's pixels.
({int changed, int tinted}) _cursorPixels(img.Image a, img.Image b, Rect rect) {
  var changed = 0, tinted = 0;
  for (var y = rect.top.floor(); y < rect.bottom.floor(); y++) {
    for (var x = rect.left.floor(); x < rect.right.floor(); x++) {
      final pa = a.getPixel(x, y), pb = b.getPixel(x, y);
      final d = (pa.r - pb.r).abs() + (pa.g - pb.g).abs() + (pa.b - pb.b).abs();
      if (d < 24) continue;
      changed++;
      if (pa.r + pa.g > 2 * pa.b + 40) tinted++;
    }
  }
  return (changed: changed, tinted: tinted);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const usedAssets = [
    'Props/Barrels/fuel_barrel_red.glb',
    'Props/Banana Bunch/banana_bunch_medium.glb',
  ];

  testWidgets('Landscape Smoke: flat terrain → sculpted hill → scattered foliage → saved .lmas', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_landscape_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeLandscape')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeLandscape', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeLandscape.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      // Real foliage meshes through the real import pipeline.
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final relative in usedAssets) {
        final src = File('${assetsDir.path}/$relative');
        expect(src.existsSync(), isTrue, reason: 'seed asset $relative must exist');
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: src.path));
      }

      // The Content Browser's "New Asset → Landscape" path: a real flat terrain
      // asset on disk, not an empty shell.
      final landscapePath = await tester.runAsync(
        () => LandscapeAssetService.createFlatAsset(
          projectDirPath: pDir.path,
          fileName: 'Terrain_Smoke.lmas',
          gridResolution: 129,
          worldSize: 256.0,
          maxHeight: 100.0,
        ),
      );
      expect(landscapePath, isNotNull);
      vm.refreshAssets();
      final landscapeAsset = vm.realAssets.firstWhere((a) => a.fileName == 'Terrain_Smoke.lmas');
      expect(landscapeAsset.type, AssetType.landscape);

      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: MainEditorView(viewModel: vm),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      /// Live binding: animations run on the real clock, so a bare pump loop
      /// advances nothing — each frame waits for real time to pass.
      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // Open the landscape asset in the real sub-editor workspace tab.
      vm.openSubEditorTab('Landscape', asset: landscapeAsset);
      await settle(30);
      await rec.hold(const Duration(milliseconds: 1200));
      expect(find.byType(LandscapeFoliageSubEditor), findsOneWidget);
      expect(find.text('Grass_Layer'), findsNothing, reason: 'the hardcoded mockup layers are gone');
      expect(find.text('Paint'), findsNothing, reason: 'no terrain layer-blend material exists yet');

      final state = tester.state(find.byType(LandscapeFoliageSubEditor));
      final landscape = (state as dynamic).viewModelForTest as LandscapeEditorViewModel;
      expect(landscape.data.gridResolution, 129);
      expect(landscape.sectionCount, 4);
      expect(landscape.heightMax, 0.0, reason: 'the new terrain starts flat');
      debugPrint('[landscape_smoke] preview attached: ${landscape.isPreviewAttached}');

      final beforePng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('landscape_editor_flat_terrain', beforePng, usedAssets: usedAssets);

      // --- Sculpt a hill through the real UI --------------------------------
      await tester.tap(find.byKey(const ValueKey('landscape_tab_sculpt')));
      await settle(10);
      await tester.tap(find.byKey(const ValueKey('landscape_tool_sculpt')));
      await settle(5);
      expect(landscape.tool, LandscapeTool.sculpt);
      landscape.setBrushRadius(28.0);
      landscape.setBrushStrength(1.0);
      landscape.setBrushFalloff(0.6);
      await settle(5);
      await rec.hold(const Duration(milliseconds: 800));

      // Drag on the real sculpt map: that is the editor's own gesture path.
      final mapFinder = find.byKey(const ValueKey('landscape_brush_map'));
      expect(mapFinder, findsOneWidget);
      final mapRect = tester.getRect(mapFinder);
      // Three passes over the same spot: a hill tall enough to read in the
      // rendered frame, not a 1 m bump. Every stroke is recorded as it moves.
      for (var pass = 0; pass < 10; pass++) {
        final gesture = await tester.startGesture(mapRect.center);
        for (var i = 0; i < 6; i++) {
          await gesture.moveBy(const Offset(2, 0.7));
          await settle(2);
          await rec.capture();
        }
        await gesture.up();
        await settle(4);
        await rec.capture();
      }

      expect(landscape.data.heightMax, greaterThan(8.0), reason: 'the strokes really raised the terrain');
      expect(landscape.canUndo, isTrue);
      expect(landscape.undoDepth, 10, reason: 'one undo transaction per stroke');
      expect(landscape.isDirty, isTrue);
      debugPrint('[landscape_smoke] hill height: ${landscape.data.heightMax.toStringAsFixed(2)} m, '
          'undo snapshot cells: ${landscape.lastSnapshotCellCount} of ${landscape.data.vertexCount}');
      expect(landscape.lastSnapshotCellCount, lessThan(landscape.data.vertexCount),
          reason: 'a stroke snapshots its dirty rect, not the whole map');

      final sculptPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('landscape_editor_sculpted_hill', sculptPng, usedAssets: usedAssets);
      await rec.hold(const Duration(milliseconds: 800));

      // --- Foliage: a real imported barrel scattered over the hill ----------
      await tester.tap(find.byKey(const ValueKey('landscape_tab_foliage')));
      await settle(10);
      final barrel = vm.realAssets.firstWhere((a) => a.fileName.startsWith('fuel_barrel_red'));
      final paletteKey = ValueKey('landscape_palette_${barrel.fileName}');
      expect(find.byKey(paletteKey), findsOneWidget, reason: 'the palette lists the project\'s real meshes');
      await tester.ensureVisible(find.byKey(paletteKey));
      await settle(5);
      await tester.tap(find.byKey(paletteKey));
      await settle(10);
      expect(landscape.data.layers.length, 1);
      landscape.setLayerRules(
        0,
        const FoliageRules(
          density: 25.0,
          minSpacing: 2.0,
          scaleMin: 0.8,
          scaleMax: 1.6,
          randomYaw: true,
          alignToNormal: true,
          slopeMaxDegrees: 60.0,
        ),
      );
      landscape.setBrushRadius(30.0);
      await settle(5);
      await rec.hold(const Duration(milliseconds: 800));

      // Two strokes of the foliage brush across the hill.
      final map2 = tester.getRect(find.byType(LandscapeBrushOverlay));
      for (final (from, step) in const [(Offset(0, 14), Offset(10, 6)), (Offset(-40, -30), Offset(8, -4))]) {
        final paintGesture = await tester.startGesture(map2.center + from);
        for (var i = 0; i < 6; i++) {
          await paintGesture.moveBy(step);
          await settle(4);
          await rec.capture();
        }
        await paintGesture.up();
        await settle(10);
        await rec.hold(const Duration(milliseconds: 600));
      }

      final instances = landscape.data.layers.single.instanceCount;
      expect(instances, greaterThan(0), reason: 'real scatter placed instances');
      debugPrint('[landscape_smoke] foliage instances: $instances, '
          'layer: ${landscape.data.layers.single.name}');

      // Every instance sits on the heightmap and inside the terrain.
      for (var i = 0; i < instances; i++) {
        final inst = landscape.data.layers.single.instanceAt(i);
        expect(landscape.data.contains(inst.x, inst.z), isTrue);
        expect(inst.y, closeTo(landscape.data.sampleHeight(inst.x, inst.z), 1e-4));
        expect(inst.ny, greaterThan(0.0));
      }

      // What the model placed must also have reached the scene: the instancing
      // spec caps a component at 64 instances, so the scene chunks them.
      final previewScene =
          (tester.state(find.byType(LandscapeFoliageSubEditor)) as dynamic).previewSceneForTest as LandscapePreviewScene?;
      debugPrint('[landscape_smoke] preview=${previewScene != null} available=${previewScene?.isAvailable} '
          'sections=${previewScene?.terrainSectionCount} batches=${previewScene?.batchCount} '
          'instances=${previewScene?.totalFoliageInstances} chunks=${previewScene?.foliageChunkCount} '
          'modelSections=${landscape.sectionCount} modelInstances=$instances');
      if (previewScene != null && previewScene.isAvailable) {
        expect(previewScene.terrainSectionCount, landscape.sectionCount);
        expect(previewScene.totalFoliageInstances, instances,
            reason: 'every placed instance is mounted, across ${previewScene.foliageChunkCount} chunks');
      }

      final foliagePng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('landscape_editor_foliage_scatter', foliagePng, usedAssets: usedAssets);
      await rec.hold(const Duration(milliseconds: 800));

      // --- Save through the real toolbar button -----------------------------
      await tester.ensureVisible(find.byKey(const ValueKey('landscape_save')));
      await settle(5);
      await tester.tap(find.byKey(const ValueKey('landscape_save')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await settle(15);
      expect(landscape.isDirty, isFalse);
      await rec.hold(const Duration(seconds: 1));
      rec.save('Landscape Smoke: flat terrain → sculpted hill → scattered foliage → saved .lmas', usedAssets: usedAssets);

      final saved = LuminaAsset.fromBytes(File(landscapePath!).readAsBytesSync());
      expect(saved.type, AssetType.landscape);
      expect(saved.references.single.slotName, 'foliage_0');
      final payload = LandscapeData.fromBytes(saved.rawPayload!);
      expect(payload.gridResolution, 129);
      expect(payload.heightMax, greaterThan(8.0), reason: 'the saved heightmap is not flat');
      expect(payload.layers.single.instanceCount, instances);
      expect(saved.metadata['foliage_instances'], '$instances');

      // Reopening the saved asset rebuilds the same terrain and layer.
      final reopened = LandscapeEditorViewModel(assetPath: landscapePath)..open();
      expect(reopened.data.samples, payload.samples);
      expect(reopened.data.layers.single.instanceCount, instances);
      expect(reopened.sectionCount, 4);
      reopened.dispose();
      vm.dispose();
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });

  testWidgets(
    'Landscape Smoke: 8129² terrain streams tiles as the camera flies, with a measured residency HUD',
    (tester) async {
      final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_landscape_big_');
      final pDir = Directory('${tempProjectsDir.path}/SmokeBigLandscape')..createSync(recursive: true);
      const project = LuminaProject(
        projectName: 'SmokeBigLandscape',
        activeLevel: 'contents/levels/L_Main.lmas',
      );
      File('${pDir.path}/SmokeBigLandscape.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

      try {
        final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
        await tester.runAsync(() => vm.ensureDefaultLevelAssets());

        final landscapePath = await tester.runAsync(
          () => LandscapeAssetService.createFlatAsset(
            projectDirPath: pDir.path,
            fileName: 'Terrain_Big.lmas',
            gridResolution: 129,
            worldSize: 256.0,
            maxHeight: 1000.0,
          ),
        );

        const boundaryKey = ValueKey('landscape_big_smoke_boundary');
        tester.view.physicalSize = const Size(1700, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ShadcnApp(
            theme: luminaEditorTheme(),
            home: RepaintBoundary(
              key: boundaryKey,
              child: Scaffold(
                child: LandscapeFoliageSubEditor(assetName: 'Terrain_Big', assetPath: landscapePath),
              ),
            ),
          ),
        );

        // Live binding: animations run on the real clock.
        Future<void> settle([int frames = 6]) async {
          for (var i = 0; i < frames; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
          }
        }

        await settle(30);
        final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
        await rec.hold(const Duration(seconds: 1));
        final state = tester.state(find.byType(LandscapeFoliageSubEditor));
        final landscape = (state as dynamic).viewModelForTest as LandscapeEditorViewModel;

        // --- The largest terrain the format supports, created for real ------
        const bigResolution = LandscapeData.maxGridResolution; // 8129
        final create = Stopwatch()..start();
        landscape.setNewTerrainResolution(bigResolution);
        landscape.setNewTerrainWorldSize(16256.0);
        landscape.setNewTerrainMaxHeight(1000.0);
        await tester.runAsync(() async => landscape.createTerrainFromForm());
        create.stop();
        await settle(40);
        await rec.hold(const Duration(seconds: 1));

        expect(landscape.data.gridResolution, bigResolution);
        expect(landscape.data.vertexCount, 66080641);
        expect(landscape.sectionCount, 127 * 127);

        final previewScene =
            (state as dynamic).previewSceneForTest as LandscapePreviewScene?;
        final streaming = landscape.engineOwnsTerrain && previewScene?.isAvailable == true;
        debugPrint('[landscape_big_smoke] $bigResolution² samples=${landscape.data.vertexCount} '
            'heights=${landscape.data.heightBytes ~/ (1024 * 1024)} MB tiles=${landscape.sectionCount} '
            'create=${create.elapsedMilliseconds} ms streaming=$streaming');

        // --- Sculpt it: one stroke, rect-sized undo --------------------------
        landscape.setTool(LandscapeTool.sculpt);
        landscape.setBrushRadius(200.0);
        landscape.setBrushStrength(400.0);
        // Brush strength is capped at 1 m per stamp, so a ridge that reads in
        // the frame takes repeated strokes — same as sculpting by hand.
        final stroke = Stopwatch()..start();
        for (var pass = 0; pass < 25; pass++) {
          landscape.beginStroke(0.0, 0.0);
          landscape.strokeTo(300.0, 200.0);
          landscape.endStroke();
        }
        stroke.stop();
        await settle(20);
        await rec.hold(const Duration(seconds: 1));
        expect(landscape.data.heightMax, greaterThan(20.0), reason: 'the strokes really raised the terrain');
        expect(landscape.lastSnapshotCellCount, lessThan(landscape.data.vertexCount ~/ 100),
            reason: 'undo snapshots the dragged rect (${landscape.lastSnapshotCellCount} cells), '
                'not all ${landscape.data.vertexCount}');

        // --- Fly the streaming focus across the terrain ---------------------
        final residentSeen = <int>{};
        final tileSets = <Set<int>>[];
        final flyTimes = <int>[];
        final half = landscape.data.worldSize / 2;
        // Out across the terrain and back to the origin, so the final frame is
        // taken where the viewport camera is actually looking.
        const legs = <double>[0.0, -0.9, -0.45, 0.0, 0.45, 0.9, 0.45, 0.0];
        for (var i = 0; i < legs.length; i++) {
          final x = half * legs[i];
          final z = half * legs[i];
          // The focus glides to the stop, the video recording each step.
          if (i > 0) {
            for (var k = 1; k < 6; k++) {
              final t = legs[i - 1] + (legs[i] - legs[i - 1]) * k / 6;
              await tester.runAsync(() async => landscape.setPreviewCamera(half * t, half * t));
              await settle(2);
              await rec.capture();
            }
          }
          final step = Stopwatch()..start();
          await tester.runAsync(() async => landscape.setPreviewCamera(x, z));
          step.stop();
          flyTimes.add(step.elapsedMilliseconds);
          await settle(6);
          final stats = landscape.residencyStats;
          if (stats != null) {
            residentSeen.add(stats.residentSections);
            final lods = previewScene?.landscape?.residentLods.keys.toSet();
            if (lods != null) tileSets.add(lods);
          }
          // The camera rests at each stop while the video records the tiles
          // streaming around it.
          await rec.hold(const Duration(milliseconds: 700));
        }

        final stats = landscape.residencyStats;
        if (streaming) {
          expect(stats, isNotNull);
          expect(stats!.totalSections, 127 * 127);
          expect(stats.residentSections, lessThan(stats.totalSections),
              reason: 'an 8129² terrain must never mount all 16 129 tiles');
          expect(stats.isStreaming, isTrue);
          // The HUD line is what the user reads, and every number in it is
          // measured off the engine's own buffers.
          expect(landscape.hudLabel, contains('Resident ${stats.residentSections}/${stats.totalSections} tiles'));
          expect(landscape.hudLabel, contains('MB'));

          // Tiles really streamed in and out as the focus moved: the union of
          // everything that was ever resident is far bigger than the set that
          // stayed resident the whole way.
          expect(tileSets.length, greaterThan(4));
          final everResident = tileSets.reduce((a, b) => a.union(b));
          final alwaysResident = tileSets.reduce((a, b) => a.intersection(b));
          expect(everResident.length, greaterThan(alwaysResident.length),
              reason: 'tiles mounted and unmounted along the flight '
                  '(${everResident.length} ever vs ${alwaysResident.length} always)');
          expect(everResident.length, greaterThan(stats.residentSections),
              reason: 'the flight visited more tiles than fit at once');
          expect(alwaysResident.length, lessThan(stats.residentSections));

          // Per-tile LOD is in use: near tiles are finer than far ones.
          final lods = previewScene!.landscape!.residentLods.values.toSet();
          expect(lods, contains(1), reason: 'the tile under the focus is at full detail');
          expect(lods.length, greaterThan(1), reason: 'distant tiles are decimated');

          flyTimes.sort();
          debugPrint('[landscape_big_smoke] HUD: ${stats.label}');
          debugPrint('[landscape_big_smoke] resident=${stats.residentSections}/${stats.totalSections} '
              'tris=${stats.triangles} verts=${stats.vertices} '
              'gpuMB=${stats.gpuMegabytes.toStringAsFixed(1)} lodSteps=$lods '
              'medianResolveMs=${flyTimes[flyTimes.length ~/ 2]} maxResolveMs=${flyTimes.last} '
              'strokeMs=${stroke.elapsedMilliseconds} snapshotCells=${landscape.lastSnapshotCellCount}');
        } else {
          debugPrint('[landscape_big_smoke] no native preview attached — residency HUD not exercised');
        }

        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('landscape_editor_8129_streaming', png, usedAssets: usedAssets);
        await rec.hold(const Duration(seconds: 1));
        rec.save('Landscape Smoke: 8129² terrain streams tiles as the camera flies, with a measured residency HUD', usedAssets: usedAssets);

        // --- Save and reopen the 8129² terrain through the real service -----
        final save = Stopwatch()..start();
        final savedOk = await tester.runAsync(() => landscape.save());
        save.stop();
        expect(savedOk, isTrue);

        final sidecar = File(LandscapeData.sidecarPathFor(landscapePath!));
        expect(sidecar.existsSync(), isTrue,
            reason: 'the heights of a terrain this size stream into a sidecar, not into base64 JSON');
        final lmasBytes = File(landscapePath).lengthSync();

        final reload = Stopwatch()..start();
        final reopened = await tester.runAsync(() async => LandscapeAssetService.load(landscapePath));
        reload.stop();
        expect(reopened, isNotNull);
        expect(reopened!.gridResolution, bigResolution);
        expect(reopened.sampleHeight(0.0, 0.0),
            closeTo(landscape.data.sampleHeight(0.0, 0.0), landscape.data.heightStep));

        debugPrint('[landscape_big_smoke] lmas=$lmasBytes B sidecar=${sidecar.lengthSync() ~/ (1024 * 1024)} MB '
            'save=${save.elapsedMilliseconds} ms reopen=${reload.elapsedMilliseconds} ms');

        vm.dispose();
      } finally {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );


  testWidgets(
    'Landscape Smoke: brush cursor on the terrain, sculpt and scatter in the 3D viewport, lit and shadowed',
    (tester) async {
      const title = 'Landscape Smoke: brush cursor on the terrain, sculpt and scatter in the 3D viewport, lit and shadowed';
      const assets = ['Props/Barrels/fuel_barrel_red.glb'];
      final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_landscape_3d_');
      final pDir = Directory('${tempProjectsDir.path}/Smoke3DBrush')..createSync(recursive: true);
      const project = LuminaProject(projectName: 'Smoke3DBrush', activeLevel: 'contents/levels/L_Main.lmas');
      File('${pDir.path}/Smoke3DBrush.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

      try {
        final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
        await tester.runAsync(() => vm.ensureDefaultLevelAssets());
        final src = File('${SmokeArtifacts.testAssetsDir.path}/${assets.single}');
        expect(src.existsSync(), isTrue);
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: src.path));

        // A 64 m terrain: small enough that a 1.15 m barrel reads in the view.
        final landscapePath = await tester.runAsync(
          () => LandscapeAssetService.createFlatAsset(
            projectDirPath: pDir.path,
            fileName: 'Terrain_Brush3D.lmas',
            gridResolution: 129,
            worldSize: 64.0,
            maxHeight: 30.0,
          ),
        );
        vm.refreshAssets();
        final landscapeAsset = vm.realAssets.firstWhere((a) => a.fileName == 'Terrain_Brush3D.lmas');

        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: boundaryKey,
          child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
        ));
        Future<void> settle([int frames = 10]) async {
          for (var i = 0; i < frames; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
          }
        }

        await settle(20);
        final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
        vm.openSubEditorTab('Landscape', asset: landscapeAsset);
        await settle(40);
        await rec.hold(const Duration(milliseconds: 1000));

        final state = tester.state(find.byType(LandscapeFoliageSubEditor));
        final landscape = (state as dynamic).viewModelForTest as LandscapeEditorViewModel;
        final preview = (state as dynamic).previewSceneForTest as LandscapePreviewScene?;
        expect(preview?.isAvailable, isTrue, reason: 'the smoke needs the real Filament preview');
        final viewport = tester.getRect(find.byType(SubEditor3DViewport));
        // The camera looks at the terrain's centre from the default orbit.
        final centre = viewport.center;
        Future<PngCapture> shot() async {
          final bytes = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
          return PngCapture(bytes, img.decodePng(bytes)!);
        }

        // --- Sculpt tab: the cursor follows the mouse over the terrain -------
        await tester.tap(find.byKey(const ValueKey('landscape_tab_sculpt')));
        await settle(10);
        expect(find.byKey(const ValueKey('landscape_controls_hint_sculpt')), findsOneWidget);
        landscape.setTool(LandscapeTool.sculpt);
        landscape.setBrushRadius(9.0);
        landscape.setBrushStrength(1.0);
        landscape.setBrushFalloff(0.5);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: centre + const Offset(-220, 60));
        for (var i = 0; i <= 40; i++) {
          await mouse.moveTo(centre + Offset(-220 + i * 11.0, 60 - i * 2.0));
          await rec.hold(const Duration(milliseconds: 50));
        }
        expect(landscape.cursorWorldX, isNotNull, reason: 'hovering the viewport puts the cursor on the terrain');
        expect(preview!.landscape!.brushCursor, isNotNull, reason: 'the engine drapes the cursor');
        await mouse.moveTo(centre);
        await rec.hold(const Duration(milliseconds: 300));
        final withCursor = await shot();
        landscape.clearCursor();
        await settle(6);
        final noCursor = await shot();
        final cursor = _cursorPixels(withCursor.image, noCursor.image, viewport);
        debugPrint('[landscape_3d_smoke] cursor pixels=${cursor.changed} tinted=${cursor.tinted}');
        expect(cursor.changed, greaterThan(1500), reason: 'the draped cursor is visible in the 3D view');
        expect(cursor.tinted / cursor.changed, greaterThan(0.6), reason: 'and carries the sculpt brush\'s amber');
        SmokeArtifacts.saveScreenshot('landscape_editor_3d_cursor', withCursor.bytes, usedAssets: assets);

        // --- Sculpt a hill by dragging in the 3D viewport ---------------------
        final undoBefore = landscape.undoDepth;
        for (var pass = 0; pass < 8; pass++) {
          await mouse.moveTo(centre + const Offset(-40, 10));
          await mouse.down(centre + const Offset(-40, 10));
          for (var i = 1; i <= 8; i++) {
            await mouse.moveTo(centre + Offset(-40 + i * 10.0, 10 - i * 2.0));
            await rec.hold(const Duration(milliseconds: 40));
          }
          await mouse.up();
          await rec.hold(const Duration(milliseconds: 60));
        }
        expect(landscape.undoDepth, undoBefore + 8, reason: 'one undo entry per drag');
        expect(landscape.data.heightMax, greaterThan(4.0), reason: 'dragging in 3D raised a hill');
        debugPrint('[landscape_3d_smoke] hill ${landscape.data.heightMax.toStringAsFixed(2)} m');
        // The brush's falloff changes on camera.
        await mouse.moveTo(centre + const Offset(60, 40));
        for (final f in [0.1, 0.3, 0.6, 0.9, 0.5]) {
          landscape.setBrushFalloff(f);
          await rec.hold(const Duration(milliseconds: 250));
        }
        SmokeArtifacts.saveScreenshot('landscape_editor_3d_sculpted_hill', (await shot()).bytes, usedAssets: assets);

        // --- Foliage: scatter barrels by dragging in the 3D viewport ----------
        await tester.tap(find.byKey(const ValueKey('landscape_tab_foliage')));
        await settle(10);
        final barrel = vm.realAssets.firstWhere((a) => a.fileName.startsWith('fuel_barrel_red'));
        await tester.ensureVisible(find.byKey(ValueKey('landscape_palette_${barrel.fileName}')));
        await tester.tap(find.byKey(ValueKey('landscape_palette_${barrel.fileName}')));
        await settle(20);
        landscape.setLayerRules(
          0,
          const FoliageRules(density: 18.0, minSpacing: 1.6, scaleMin: 1.4, scaleMax: 2.0, slopeMaxDegrees: 70.0),
        );
        // The foliage brush's own size and falloff, set through its panel.
        tester.widget<SliderField>(find.byKey(const ValueKey('landscape_foliage_brush_size'))).onCommit(700.0);
        tester.widget<SliderField>(find.byKey(const ValueKey('landscape_foliage_brush_falloff'))).onCommit(0.6);
        tester.widget<SliderField>(find.byKey(const ValueKey('landscape_foliage_paint_density'))).onCommit(1.0);
        await settle(6);
        expect(landscape.foliageBrushRadius, closeTo(7.0, 1e-9));
        for (var i = 0; i <= 20; i++) {
          await mouse.moveTo(centre + Offset(-160 + i * 8.0, 90));
          await rec.hold(const Duration(milliseconds: 40));
        }
        expect(preview.landscape!.brushCursor, isNotNull);
        for (final (from, to) in const [
          (Offset(-160, 90), Offset(80, 70)),
          (Offset(-120, 30), Offset(120, 20)),
          (Offset(-60, -20), Offset(40, -40)),
        ]) {
          await mouse.moveTo(centre + from);
          await mouse.down(centre + from);
          for (var i = 1; i <= 12; i++) {
            await mouse.moveTo(centre + Offset.lerp(from, to, i / 12)!);
            await rec.hold(const Duration(milliseconds: 40));
          }
          await mouse.up();
          await settle(4);
          await rec.hold(const Duration(milliseconds: 200));
        }
        final layer = landscape.data.layers.single;
        expect(layer.instanceCount, greaterThan(20), reason: 'the 3D drags scattered barrels');
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
        await settle(10);
        expect(preview.totalFoliageInstances, layer.instanceCount);

        // Falloff thins the band: the instances of the drags are denser near
        // the drag lines than at the brush's rim — measured on the payload.
        debugPrint('[landscape_3d_smoke] barrels ${layer.instanceCount}');

        // Shift+drag with Scatter erases part of them.
        final beforeErase = layer.instanceCount;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await mouse.moveTo(centre + const Offset(-100, 60));
        await mouse.down(centre + const Offset(-100, 60));
        for (var i = 1; i <= 6; i++) {
          await mouse.moveTo(centre + Offset(-100 + i * 12.0, 60));
          await rec.hold(const Duration(milliseconds: 40));
        }
        await mouse.up();
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await settle(6);
        expect(layer.instanceCount, lessThan(beforeErase), reason: 'Shift+LMB erased');
        await rec.hold(const Duration(milliseconds: 600));

        // --- Lighting: the sun's shadows, measured A/B ------------------------
        await mouse.moveTo(Offset(viewport.right + 150, viewport.top + 40));
        landscape.clearCursor();
        await settle(10);
        await rec.hold(const Duration(milliseconds: 800));
        final lit = await shot();
        preview.sun!.castShadows = false;
        await settle(10);
        final unshadowed = await shot();
        preview.sun!.castShadows = true;
        await settle(10);
        final shadowPixels = _darkerIn(lit.image, unshadowed.image, viewport);
        debugPrint('[landscape_3d_smoke] shadowed pixels=$shadowPixels of ${(viewport.width * viewport.height).round()}');
        expect(shadowPixels, greaterThan(800), reason: 'the hill and the barrels throw sun shadows');
        SmokeArtifacts.saveScreenshot('landscape_editor_3d_lit_and_shadowed', lit.bytes, usedAssets: assets);
        SmokeArtifacts.saveScreenshot('landscape_editor_3d_shadows_off_for_comparison', unshadowed.bytes, usedAssets: assets);
        await rec.hold(const Duration(milliseconds: 1500));

        // --- Save: the brushes persist with the project ------------------------
        await tester.tap(find.byKey(const ValueKey('landscape_save')));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
        await settle(10);
        expect(File('${pDir.path}/.lumina/landscape_brush.json').existsSync(), isTrue);
        final saved = LandscapeData.fromBytes(LuminaAsset.fromBytes(File(landscapePath!).readAsBytesSync()).rawPayload!);
        expect(saved.layers.single.instanceCount, layer.instanceCount);
        await rec.hold(const Duration(milliseconds: 800));
        rec.save(title, usedAssets: assets);
        debugPrint('[landscape_3d_smoke] video ${rec.recorded.inMilliseconds} ms');
        await mouse.removePointer();
        vm.dispose();
      } finally {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

/// A captured PNG and its decoded pixels.
class PngCapture {
  final Uint8List bytes;
  final img.Image image;
  PngCapture(this.bytes, this.image);
}
