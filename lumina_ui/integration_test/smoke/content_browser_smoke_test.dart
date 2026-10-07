import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina/testing.dart' show ImportFolderFixture;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/asset_type_style.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_data.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_store.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/create_project_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/import_asset_options_dialog.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/graph_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../helpers/shared_editor_preferences.dart';

/// Pumps a bounded run of frames on the live clock: the editor viewport runs
/// tickers for as long as it is mounted, so `pumpAndSettle` never settles.
Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

/// The Content Browser's search field.
Finder _searchField() => find.descendant(
      of: find.byType(ContentBrowserWidget),
      matching: find.byWidgetPredicate((w) =>
          w is TextField && w.placeholder is Text && ((w.placeholder as Text).data ?? '').startsWith('Search Assets')),
    );

/// The Content Browser tile (the draggable card) for [fileName].
Finder _tile(String fileName) =>
    find.byWidgetPredicate((w) => w is Draggable<RealAssetInfo> && w.data?.fileName == fileName);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Content Browser Smoke Test: Search, filters, collections', (WidgetTester tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_cb_');
    final vm = EditorViewModel(projectDirPath: tempProjectsDir.path, enableTimers: false, autoInitAssets: false);

    try {
      // Real test assets, through the real import pipeline.
      await vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/Props/AC_units/ac_unit_a_300x300.glb');
      await vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/empty_barrel.glb');
      vm.refreshAssets();

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: MainEditorView(viewModel: vm),
          ),
        ),
      ));
      await _settle(tester, 40);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // Type into the search box: the grid narrows as the query grows.
      await tester.tap(_searchField());
      await rec.typeText(_searchField(), 'barrel', perCharacter: const Duration(milliseconds: 150));
      await rec.hold(const Duration(milliseconds: 500));
      expect(vm.searchQuery, 'barrel');
      expect(vm.visibleAssets.where((a) => a.type == AssetType.filamesh).map((a) => a.fileName.toLowerCase()),
          everyElement(contains('barrel')), reason: 'the AC unit mesh is filtered out');
      await rec.hold(const Duration(seconds: 1));

      // Only meshes.
      vm.activeTypeFilters = {AssetType.filamesh};
      await _settle(tester);
      expect(vm.visibleAssets.every((a) => a.type == AssetType.filamesh), isTrue);
      await rec.hold(const Duration(seconds: 1));

      // Click the barrel's tile: it is selected.
      final barrel = vm.visibleAssets.first;
      await tester.tap(_tile(barrel.fileName));
      await _settle(tester);
      await rec.hold(const Duration(seconds: 1));

      final png = await SmokeArtifacts.captureIntegrationPng(
        IntegrationTestWidgetsFlutterBinding.instance, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('content_browser_filtered', png, usedAssets: const [
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Barrels/empty_barrel.glb',
      ]);

      // A collection with the barrel in it, then shown on its own.
      vm.createCollection('TestCollection');
      vm.addToCollection('TestCollection', barrel.assetId!);
      vm.searchQuery = '';
      await tester.enterText(_searchField(), '');
      vm.activeTypeFilters = {};
      await _settle(tester);
      await rec.hold(const Duration(seconds: 1));
      vm.activeCollection = 'TestCollection';
      await _settle(tester);
      expect(vm.visibleAssets.map((a) => a.assetId), [barrel.assetId]);
      await rec.hold(const Duration(seconds: 1));

      // Back to everything, then find the AC unit by typing.
      vm.activeCollection = null;
      await _settle(tester);
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(_searchField());
      await rec.typeText(_searchField(), 'ac_unit', perCharacter: const Duration(milliseconds: 150));
      await rec.hold(const Duration(milliseconds: 500));
      expect(vm.visibleAssets.any((a) => a.fileName.toLowerCase().contains('ac_unit')), isTrue);
      await rec.hold(const Duration(seconds: 1));

      // New Asset ▸ New Material: the material starts from the Material
      // Editor's template, so double-clicking it opens a node graph of the
      // template's nodes wired into the Material node (not one Custom
      // (Fragment) node).
      await tester.enterText(_searchField(), '');
      vm.searchQuery = '';
      await _settle(tester);
      final materialsBefore = vm.realAssets.where((a) => a.type == AssetType.filamat).map((a) => a.fileName).toSet();
      await tester.tap(find.text('New Asset').first);
      await _settle(tester);
      await rec.hold(const Duration(milliseconds: 700));
      await tester.tap(find.text('New Material (.lmas)'));
      await _settle(tester, 20);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await _settle(tester);
      final newMaterial =
          vm.realAssets.where((a) => a.type == AssetType.filamat && !materialsBefore.contains(a.fileName)).single;
      final newMaterialName = newMaterial.fileName.replaceAll('.lmas', '');
      final newSource =
          LuminaAsset.fromBytes(File('${vm.projectDirPath}/${newMaterial.relativePath}').readAsBytesSync()).rawMatSource;
      expect(newSource, MaterialEditorViewModel.newMaterialSource(newMaterialName));
      vm.selectedFolder = 'contents/materials';
      await _settle(tester);
      await rec.hold(const Duration(milliseconds: 700));
      final newTile = _tile(newMaterial.fileName);
      expect(newTile, findsOneWidget);
      await tester.tap(newTile);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 90)));
      await tester.tap(newTile);
      await _settle(tester, 20);
      for (var i = 0; i < 100 && find.byType(MaterialSubEditor).evaluate().isEmpty; i++) {
        await _settle(tester, 2);
      }
      expect(find.byType(MaterialSubEditor), findsOneWidget, reason: '$newMaterialName opens in the Material Editor');
      await rec.hold(const Duration(milliseconds: 1500));
      await tester.tap(find.text('Node Graph').first);
      await _settle(tester, 20);
      await rec.hold(const Duration(milliseconds: 1500));
      final materialVm = tester.widget<MaterialGraphView>(find.byType(MaterialGraphView)).viewModel;
      final graphNodes = materialVm.graph.graph.nodes;
      expect(graphNodes.where((n) => n.registryId == MaterialNodes.customFragment), isEmpty,
          reason: '${graphNodes.map((n) => n.registryId).toList()}');
      expect({
        for (final w in materialVm.graph.graph.wires)
          if (w.toNodeId == MaterialNodes.outputNodeId) w.toPinId,
      }, containsAll([MaterialNodes.baseColor, MaterialNodes.roughness, MaterialNodes.metallic]));
      final graphPng = await SmokeArtifacts.captureIntegrationPng(
          IntegrationTestWidgetsFlutterBinding.instance, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('content_browser_new_material_graph', graphPng, usedAssets: const [
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Barrels/empty_barrel.glb',
      ]);
      await rec.hold(const Duration(seconds: 1));
      rec.save('Content Browser Smoke Test: Search, filters, collections', usedAssets: const [
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Barrels/empty_barrel.glb',
      ]);
    } finally {
      vm.dispose();
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });

  // The Content Browser shows Filament-rendered
  // thumbnails, generated in the background as a project opens and as assets
  // are imported.
  testWidgets('content browser: rendered thumbnails', (WidgetTester tester) async {
    const imports = [
      'Props/Barrels/fuel_barrel_red.glb',
      'Props/AC_units/ac_unit_a_300x300.glb',
      'Props/Banana Bunch/banana_bunch_medium.glb',
    ];
    for (final rel in imports) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    final root = Directory.systemTemp.createTempSync('cb_thumbs_smoke_');
    EditorViewModel? vm;
    try {
      // A launcher Third Person project: the real scaffold, real flutter create.
      final project = (await tester.runAsync(() => ProjectRepository(
            configDir: Directory('${root.path}/.config')..createSync(recursive: true),
          ).createProject(projectName: 'thumb_smoke', projectLocation: root.path, template: kThirdPersonTemplateId)))!;

      vm = EditorViewModel(
        initialProject: project,
        projectLocation: root.path,
        enableTimers: false,
        // enableTimers: false turns automatic thumbnails off unless asked.
        autoGenerateThumbnails: true,
      );
      final editor = vm;
      var progressSeen = false;
      bool progressShown() => find.byKey(const ValueKey('thumbnail_queue_progress')).evaluate().isNotEmpty;

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: RepaintBoundary(key: boundaryKey, child: Scaffold(child: MainEditorView(viewModel: editor))),
      ));
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      // Opening the project queues every asset without a current thumbnail:
      // the card shows while they render.
      for (var i = 0; i < 20; i++) {
        await rec.hold(const Duration(milliseconds: 100));
        progressSeen |= progressShown();
      }
      expect(find.byType(ContentBrowserWidget), findsOneWidget, reason: 'the Content Browser tab is showing');

      // Import the three props; each import queues its thumbnails and the
      // tiles fill in as they render, on video while the import runs.
      for (final rel in imports) {
        var imported = false;
        final importing = editor
            .processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$rel')
            .whenComplete(() => imported = true);
        while (!imported) {
          await rec.hold(const Duration(milliseconds: 100));
          progressSeen |= progressShown();
        }
        await importing;
        await rec.hold(const Duration(milliseconds: 500));
        progressSeen |= progressShown();
      }

      // The queue drains on screen.
      final drainWatch = Stopwatch()..start();
      while (editor.thumbnailQueueLength > 0 && drainWatch.elapsed < const Duration(minutes: 3)) {
        progressSeen |= progressShown();
        await rec.hold(const Duration(milliseconds: 250));
      }
      await tester.runAsync(() => editor.thumbnailQueueIdle);
      await _settle(tester);
      expect(progressSeen, isTrue, reason: 'the "Generating Thumbnails" card showed while the queue ran');
      expect(editor.thumbnailQueueLength, 0);
      await rec.hold(const Duration(milliseconds: 800));

      // Every renderable asset carries a current Filament render (textures:
      // their own image), cached on disk.
      const rendered = {AssetType.filamesh, AssetType.filameshSk, AssetType.filamat, AssetType.level};
      for (final a in editor.realAssets) {
        if (!rendered.contains(a.type) && a.type != AssetType.texture) continue;
        expect(a.thumbnailSource,
            a.type == AssetType.texture ? ThumbnailService.sourceImage : ThumbnailService.sourceFilament,
            reason: a.fileName);
        // Stored in the .lmas only (no sidecar).
        expect(Directory('${File(a.lmasPath!).parent.path}/.thumbnails').existsSync(), isFalse, reason: a.fileName);
        final cached = LuminaAsset.fromBytes(File(a.lmasPath!).readAsBytesSync()).thumbnailPng!;
        expect(a.thumbnailBytes, orderedEquals(cached), reason: a.fileName);
        if (rendered.contains(a.type)) {
          final decoded = img.decodePng(a.thumbnailBytes!);
          expect(decoded, isNotNull, reason: a.fileName);
          expect((decoded!.width, decoded.height), (256, 256), reason: a.fileName);
        }
        expect(ThumbnailService.isStaleInfo(a), isFalse, reason: a.fileName);
      }

      // Each imported mesh's tile shows exactly its rendered PNG: search for
      // it, as a user would, and look at the tile.
      final meshes = editor.realAssets.where((a) => a.type == AssetType.filamesh).toList();
      expect(meshes, hasLength(imports.length));
      for (final mesh in meshes) {
        final query = mesh.fileName.replaceAll('.lmas', '');
        await tester.tap(_searchField());
        await rec.typeText(_searchField(), query.substring(0, query.length.clamp(0, 12)), perCharacter: const Duration(milliseconds: 80));
        await rec.hold(const Duration(milliseconds: 400));
        final image = find.byKey(ValueKey('asset_thumbnail_${mesh.relativePath}'));
        expect(image, findsOneWidget, reason: '${mesh.fileName} tile');
        final provider = tester.widget<Image>(image).image;
        expect(provider, isA<MemoryImage>());
        expect((provider as MemoryImage).bytes, orderedEquals(LuminaAsset.fromBytes(File(mesh.lmasPath!).readAsBytesSync()).thumbnailPng!),
            reason: '${mesh.fileName} tile shows the render stored in its .lmas');
        await rec.hold(const Duration(milliseconds: 700));
      }

      // The barrel is really drawn: at least 20% of its thumbnail differs
      // from the backdrop pixel.
      final barrel = meshes.firstWhere((a) => a.fileName.toLowerCase().contains('barrel'));
      final barrelPng = img.decodePng(barrel.thumbnailBytes!)!;
      final bg = barrelPng.getPixel(0, 0);
      var differ = 0;
      for (final p in barrelPng) {
        if ((p.r - bg.r).abs() + (p.g - bg.g).abs() + (p.b - bg.b).abs() > 12) differ++;
      }
      expect(differ / (barrelPng.width * barrelPng.height), greaterThanOrEqualTo(0.2),
          reason: 'the barrel thumbnail is mostly backdrop');

      // Clear the search: the whole project, every tile a real render.
      await tester.enterText(_searchField(), '');
      await _settle(tester, 20);
      await rec.hold(const Duration(seconds: 1));

      final Uint8List png = await SmokeArtifacts.captureIntegrationPng(
        IntegrationTestWidgetsFlutterBinding.instance, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('content browser: rendered thumbnails', png, usedAssets: imports);
      rec.save('content browser: rendered thumbnails', usedAssets: imports);
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 15)));

  // The grid lists the selected folder only (subfolders
  // as tiles); a search widens to the subtree, Show All to the project; a new
  // Third Person project arrives foldered.
  testWidgets('content browser: folder view', (WidgetTester tester) async {
    const barrelRel = 'Props/Barrels/empty_barrel.glb';
    if (!File('${SmokeArtifacts.testAssetsDir.path}/$barrelRel').existsSync()) {
      markTestSkipped('test asset missing: $barrelRel');
      return;
    }
    final root = Directory.systemTemp.createTempSync('cb_folders_smoke_');
    EditorViewModel? vm;
    try {
      // The launcher's real pipeline: flutter create + Third Person scaffold +
      // the widgets/ and input/ folders.
      final config = Directory('${root.path}/.config')..createSync(recursive: true);
      final repo = ProjectRepository(configDir: config);
      useSharedEditor(config);
      final create = CreateProjectViewModel(launcherVM: LauncherViewModel(configDir: config, projectRepo: repo), projectRepo: repo)
        ..updateName('folders_smoke')
        ..updateLocation(root.path)
        ..updateTemplate(kThirdPersonTemplateId);
      await tester.runAsync(create.createProject);
      expect(create.creationError, isNull);
      final project = create.activeProject!;
      final dir = '${root.path}/folders_smoke';
      expect(File('$dir/contents/widgets/.lumina_folder').existsSync(), isTrue);
      expect(File('$dir/contents/input/.lumina_folder').existsSync(), isTrue);

      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
      final editor = vm;
      await tester.runAsync(() => editor.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrelRel'));
      editor.refreshAssets();
      editor.selectedFolder = 'contents';

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: MainEditorView(viewModel: editor))),
      ));
      await _settle(tester, 40);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // The root: folder tiles, no assets.
      for (final folder in ['animations', 'blueprints', 'levels', 'meshes', 'widgets', 'input']) {
        expect(find.byKey(ValueKey('folder_tile_contents/$folder')), findsOneWidget, reason: folder);
      }
      expect(editor.visibleAssets, isEmpty);
      await rec.hold(const Duration(milliseconds: 1500));
      SmokeArtifacts.saveScreenshot(
          'content browser: folder view',
          await SmokeArtifacts.captureIntegrationPng(IntegrationTestWidgetsFlutterBinding.instance, tester, boundary: find.byKey(boundaryKey)),
          usedAssets: const [barrelRel]);

      Future<void> enter(String folder) async {
        final tile = find.byKey(ValueKey('folder_tile_$folder'));
        await tester.tap(tile);
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(tile);
        await rec.hold(const Duration(milliseconds: 900));
        expect(editor.selectedFolder, folder);
      }

      // Into meshes/static: the imported barrel.
      await enter('contents/meshes');
      await enter('contents/meshes/static');
      expect(editor.visibleAssets.map((a) => a.fileName), contains('empty_barrel.lmas'));
      await rec.hold(const Duration(seconds: 1));

      // Back to the root through the breadcrumb, then into the clips.
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('content_browser_breadcrumb')), matching: find.text('contents')));
      await rec.hold(const Duration(milliseconds: 700));
      await enter('contents/animations');
      const clipDir = 'contents/animations/${LuminaThirdPersonContent.meshAssetName}';
      await enter(clipDir);
      final clips = editor.visibleAssets.where((a) => a.type == AssetType.animation).toList();
      expect(clips, hasLength(LuminaThirdPersonContent.clipNames.length));
      await rec.hold(const Duration(milliseconds: 1500));
      SmokeArtifacts.saveScreenshot(
          'content browser: folder view (animation folder)',
          await SmokeArtifacts.captureIntegrationPng(IntegrationTestWidgetsFlutterBinding.instance, tester, boundary: find.byKey(boundaryKey)),
          usedAssets: const [barrelRel]);

      // A search from the root reaches the whole subtree.
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('content_browser_breadcrumb')), matching: find.text('contents')));
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(_searchField());
      await rec.typeText(_searchField(), 'walk', perCharacter: const Duration(milliseconds: 150));
      await rec.hold(const Duration(seconds: 1));
      expect(editor.visibleAssets.where((a) => a.type == AssetType.animation), hasLength(8));
      await tester.enterText(_searchField(), '');
      await rec.hold(const Duration(milliseconds: 800));
      expect(editor.visibleAssets, isEmpty);

      // Blueprint filter: nothing at the root until Show All.
      await tester.tap(find.descendant(of: find.byType(ContentBrowserWidget), matching: find.text('Blueprint')));
      await rec.hold(const Duration(milliseconds: 800));
      expect(editor.visibleAssets, isEmpty);
      await tester.tap(find.byKey(const ValueKey('content_browser_show_all')));
      await rec.hold(const Duration(milliseconds: 1200));
      expect(editor.visibleAssets.map((a) => a.relativePath).toSet(),
          {LuminaThirdPersonContent.characterBlueprintPath, LuminaThirdPersonContent.gameModeBlueprintPath});
      await rec.hold(const Duration(seconds: 1));
      rec.save('content browser: folder view', usedAssets: const [barrelRel]);
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
  // A 30-mesh import runs in the background — the dialog
  // closes at once, the progress panel counts the files, the tiles land one
  // by one while the editor keeps drawing, and the longest frame is recorded.
  testWidgets('content browser: background batch import', (WidgetTester tester) async {
    final sources = _batchSources();
    if (sources.length < 30) {
      markTestSkipped('test assets missing: need 30 meshes under Props/light_fixtures and Props/signs_generic');
      return;
    }
    final used = [for (final s in sources) s.substring(SmokeArtifacts.testAssetsDir.path.length + 1)];
    final root = Directory.systemTemp.createTempSync('cb_batch_smoke_');
    EditorViewModel? vm;
    try {
      final dir = Directory('${root.path}/batch_smoke')..createSync(recursive: true);
      Directory('${dir.path}/contents/levels').createSync(recursive: true);
      File('${dir.path}/batch_smoke.lmproject')
          .writeAsStringSync('{"project_name": "batch_smoke", "active_level": "contents/levels/L_Main.lmas"}');
      vm = EditorViewModel(
        initialProject: const LuminaProject(projectName: 'batch_smoke'),
        projectLocation: root.path,
        enableTimers: false,
        autoGenerateThumbnails: true,
      );
      final editor = vm;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: RepaintBoundary(key: boundaryKey, child: Scaffold(child: MainEditorView(viewModel: editor))),
      ));
      await _settle(tester, 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));
      editor.selectedFolder = 'contents/meshes/static';

      // The same measurements on the idle editor, for comparison.
      final idleClock = Stopwatch()..start();
      var idleLast = 0;
      var idleStall = Duration.zero;
      final idleProbe = Timer.periodic(const Duration(milliseconds: 4), (_) {
        final now = idleClock.elapsedMicroseconds;
        final gap = Duration(microseconds: now - idleLast);
        if (gap > idleStall) idleStall = gap;
        idleLast = now;
      });
      var idleFrame = Duration.zero;
      for (var i = 0; i < 30; i++) {
        final frame = Stopwatch()..start();
        await tester.pump(const Duration(milliseconds: 33));
        frame.stop();
        if (frame.elapsed > idleFrame) idleFrame = frame.elapsed;
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 33)));
        await rec.capture();
        idleLast = idleClock.elapsedMicroseconds;
      }
      idleProbe.cancel();

      // Import Asset → the options dialog for 30 files → Import Asset.
      showImportAssetOptionsDialog(tester.element(find.byType(ContentBrowserWidget)), editor, sources);
      await rec.hold(const Duration(milliseconds: 1200));
      expect(find.text('Source Files: 30 files selected'), findsOneWidget);

      // The UI isolate's longest stall during the batch: a 4 ms timer's
      // worst lateness — editor frames, the queue's steps, Filament
      // thumbnails — leaving out the smoke's own video capture.
      final probeClock = Stopwatch()..start();
      var lastTick = 0;
      var longestStall = Duration.zero;
      final probe = Timer.periodic(const Duration(milliseconds: 4), (_) {
        final now = probeClock.elapsedMicroseconds;
        final gap = Duration(microseconds: now - lastTick);
        if (gap > longestStall) longestStall = gap;
        lastTick = now;
      });
      Future<void> captureFrame() async {
        await rec.capture();
        lastTick = probeClock.elapsedMicroseconds;
      }
      final batchClock = Stopwatch()..start();
      String headline() => tester.widget<Text>(find.byKey(const ValueKey('import_progress_headline'))).data!;
      await tester.tap(find.text('Import Asset'));
      await tester.pump();
      expect(headline(), startsWith('Importing 1 / 30 · '));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Import Asset Options'), findsNothing, reason: 'the dialog closed at once');

      var longestFrame = Duration.zero;
      var frames = 0;
      var midBatchShot = false;
      var interacted = false;
      final landed = <int>[];
      while (editor.isBatchImporting && batchClock.elapsed < const Duration(minutes: 5)) {
        final frame = Stopwatch()..start();
        await tester.pump(const Duration(milliseconds: 33));
        frame.stop();
        frames++;
        if (frame.elapsed > longestFrame) longestFrame = frame.elapsed;
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 33)));
        await captureFrame();
        landed.add(editor.visibleAssets.length);
        // The editor stays usable: minimise the panel to its status-bar chip,
        // look at the Output Log, come back, and open the panel again.
        if (midBatchShot && !interacted && editor.importJobs.finished >= 14) {
          interacted = true;
          await tester.tap(find.byKey(const ValueKey('import_progress_collapse')));
          await tester.pump();
          expect(find.byKey(const ValueKey('status_bar_import_chip')), findsOneWidget);
          await tester.tap(find.text('Output Log'));
          await tester.pump();
          expect(editor.layoutState.activeBottomTab, 1);
          await tester.tap(find.text('Content Browser').first);
          await tester.pump();
          expect(editor.layoutState.activeBottomTab, 0);
          await tester.tap(find.byKey(const ValueKey('status_bar_import_chip')));
          await tester.pump();
          expect(find.byKey(const ValueKey('import_progress_panel')), findsOneWidget);
        }
        if (!midBatchShot && editor.importJobs.finished >= 8) {
          midBatchShot = true;
          await tester.tap(find.byKey(const ValueKey('import_progress_details')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 33));
          SmokeArtifacts.saveScreenshot(
            'content browser: background batch import (progress panel mid-batch)',
            await SmokeArtifacts.captureIntegrationPng(
                IntegrationTestWidgetsFlutterBinding.instance, tester, boundary: find.byKey(boundaryKey)),
            usedAssets: used,
            metrics: {'finished': editor.importJobs.finished, 'total': 30, 'headline': headline()},
          );
        }
      }
      final batchTime = batchClock.elapsed;
      probe.cancel();
      expect(editor.isBatchImporting, isFalse, reason: 'the batch finished within 5 minutes');
      expect(midBatchShot, isTrue);
      expect(editor.importJobs.imported, 30);
      expect(editor.visibleAssets.length, 30);
      expect(landed.toSet().length, greaterThan(5), reason: 'the tiles landed one by one');
      expect(editor.importQueue.longestMainIsolateStep, lessThan(const Duration(milliseconds: 100)));
      await rec.hold(const Duration(seconds: 1));
      expect(headline(), 'Imported 30 of 30');

      // Thumbnails drain; the folder is full of real renders.
      final drain = Stopwatch()..start();
      while (editor.thumbnailQueueLength > 0 && drain.elapsed < const Duration(minutes: 3)) {
        await rec.hold(const Duration(milliseconds: 250));
      }
      await tester.runAsync(() => editor.thumbnailQueueIdle);
      await rec.hold(const Duration(seconds: 1));
      final metrics = <String, Object?>{
        'files': 30,
        'batch_ms': batchTime.inMilliseconds,
        'longest_queue_ui_step_ms': editor.importQueue.longestMainIsolateStep.inMicroseconds / 1000,
        'longest_queue_ui_step_by_kind_ms': {
          for (final e in editor.importQueue.longestMainIsolateStepByKind.entries) e.key: e.value.inMicroseconds / 1000,
        },
        'longest_frame_pump_ms': longestFrame.inMicroseconds / 1000,
        'longest_ui_isolate_stall_ms': longestStall.inMicroseconds / 1000,
        'frames_during_batch': frames,
        'idle_editor_longest_frame_pump_ms': idleFrame.inMicroseconds / 1000,
        'idle_editor_longest_ui_isolate_stall_ms': idleStall.inMicroseconds / 1000,
      };
      // ignore: avoid_print
      print('content browser batch import metrics: $metrics');
      SmokeArtifacts.saveScreenshot(
        'content browser: background batch import',
        await SmokeArtifacts.captureIntegrationPng(IntegrationTestWidgetsFlutterBinding.instance, tester, boundary: find.byKey(boundaryKey)),
        usedAssets: used,
        metrics: metrics,
      );
      // Find one of the new lamps by typing, then clear the search.
      await tester.tap(_searchField());
      await rec.typeText(_searchField(), 'spotlight', perCharacter: const Duration(milliseconds: 120));
      await rec.hold(const Duration(milliseconds: 800));
      expect(editor.visibleAssets.where((a) => a.type == AssetType.filamesh).map((a) => a.fileName),
          containsAll(['spotlight.off.lmas', 'spotlight.on.lmas']));
      await tester.enterText(_searchField(), '');
      await rec.hold(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 6));
      await rec.hold(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('import_progress_panel')), findsNothing, reason: 'a clean batch dismisses itself');
      rec.save('content browser: background batch import', usedAssets: used);
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 15)));

  // File → Import Asset Folder… on a nested folder of
  // real Props kits (built in a temp dir; test-assets is only read): the
  // summary dialog, the background batch, the mirrored folder tree.
  testWidgets('content browser: import asset folder', (WidgetTester tester) async {
    if (!ImportFolderFixture.available) {
      markTestSkipped('test assets missing: ${ImportFolderFixture.usedAssets}');
      return;
    }
    final root = Directory.systemTemp.createTempSync('cb_folder_import_smoke_');
    EditorViewModel? vm;
    try {
      final fixture = ImportFolderFixture.build(Directory('${root.path}/src')..createSync());
      // Deeper kits: Props/Outdoor/Hay_bales/, Props/Workshop/Tools/, …
      const extraKits = {'Outdoor/Hay_bales': 'Hay_bales', 'Outdoor/road_cone': 'road_cone', 'Kitchen/Tin Cans': 'Tin Cans', 'Workshop/Tools': 'Tools'};
      final used = [...ImportFolderFixture.usedAssets];
      for (final e in extraKits.entries) {
        final from = Directory('${SmokeArtifacts.testAssetsDir.path}/Props/${e.value}');
        final to = Directory('${fixture.root}/Props/${e.key}')..createSync(recursive: true);
        // Recursively: Tools/ keeps each tool in its own subfolder.
        for (final f in from.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.glb'))) {
          final rel = f.path.substring(from.path.length + 1);
          File('${to.path}/$rel').parent.createSync(recursive: true);
          f.copySync('${to.path}/$rel');
          used.add('Props/${e.value}/$rel');
        }
      }
      // The scanner on the whole of test-assets/Props (read only), for scale.
      final fullClock = Stopwatch()..start();
      final full = await tester.runAsync(() => ImportFolderScanner.scanInBackground('${SmokeArtifacts.testAssetsDir.path}/Props'));
      final fullScanMs = fullClock.elapsedMilliseconds;

      final dir = Directory('${root.path}/folder_import_smoke')..createSync(recursive: true);
      Directory('${dir.path}/contents/levels').createSync(recursive: true);
      File('${dir.path}/folder_import_smoke.lmproject')
          .writeAsStringSync('{"project_name": "folder_import_smoke", "active_level": "contents/levels/L_Main.lmas"}');
      vm = EditorViewModel(
        initialProject: const LuminaProject(projectName: 'folder_import_smoke'),
        projectLocation: root.path,
        enableTimers: false,
        autoGenerateThumbnails: true,
      );
      final editor = vm;
      editor.importFolderPicker = () async => fixture.root;
      editor.selectedFolder = 'contents';
      final boundaryKey = GlobalKey();
      // Around the app, so the dialog and menus (overlays) are on camera.
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: MainEditorView(viewModel: editor))),
      ));
      await _settle(tester, 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));
      Future<void> shot(String suffix, Map<String, Object?> metrics) async => SmokeArtifacts.saveScreenshot(
            'content browser: import asset folder ($suffix)',
            await SmokeArtifacts.captureIntegrationPng(IntegrationTestWidgetsFlutterBinding.instance, tester, boundary: find.byKey(boundaryKey)),
            usedAssets: used,
            metrics: metrics,
          );

      // File → Import Asset Folder…
      await tester.tap(find.text('File'));
      await rec.hold(const Duration(milliseconds: 900));
      expect(find.text('Ctrl+Shift+I'), findsOneWidget);
      await tester.tap(find.text('Import Asset Folder...'));
      final wait = Stopwatch()..start();
      while (find.byKey(const ValueKey('import_folder_dialog')).evaluate().isEmpty && wait.elapsed < const Duration(seconds: 30)) {
        await rec.hold(const Duration(milliseconds: 100));
      }
      await rec.hold(const Duration(milliseconds: 800));
      String text(String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      final files = ImportFolderFixture.expectedPrimaries.length + used.length - ImportFolderFixture.usedAssets.length;
      expect(text('import_folder_headline'), startsWith('$files files to import · '));
      expect(find.text('Skipped (2)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('import_folder_target_field')));
      await rec.typeText(find.byKey(const ValueKey('import_folder_target_field')), 'contents/Imported', perCharacter: const Duration(milliseconds: 90));
      await rec.hold(const Duration(milliseconds: 900));
      expect(text('import_folder_example'), endsWith('→ contents/Imported/Props/AC_units/'));
      expect(text('import_folder_plan'), 'Imports $files files');
      await shot('summary dialog', {'files': files, 'skipped': 2, 'full_props_scan_files': full!.files.length, 'full_props_scan_ms': fullScanMs});

      // Import: the dialog closes, the batch runs in the background.
      final batchClock = Stopwatch()..start();
      await tester.tap(find.byKey(const ValueKey('import_folder_confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('import_folder_dialog')), findsNothing);
      expect(editor.selectedFolder, 'contents/Imported');
      var midShot = false;
      final folderCounts = <int>[];
      while (editor.isBatchImporting && batchClock.elapsed < const Duration(minutes: 5)) {
        await tester.pump(const Duration(milliseconds: 33));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 33)));
        await rec.capture();
        folderCounts.add(Directory('${editor.projectDirPath}/contents/Imported/Props').existsSync()
            ? Directory('${editor.projectDirPath}/contents/Imported/Props').listSync().whereType<Directory>().length
            : 0);
        if (!midShot && editor.importJobs.finished >= 6) {
          midShot = true;
          await tester.tap(find.byKey(const ValueKey('import_progress_details')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 33));
          await shot('progress panel', {'finished': editor.importJobs.finished, 'total': files});
        }
      }
      final batchMs = batchClock.elapsedMilliseconds;
      expect(editor.isBatchImporting, isFalse);
      expect(midShot, isTrue);
      expect(editor.importJobs.imported, files);
      expect(folderCounts.toSet().length, greaterThan(2), reason: 'the mirrored folders appeared as files landed');

      Future<void> enter(String folder) async {
        final tile = find.byKey(ValueKey('folder_tile_$folder'));
        await tester.tap(tile);
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(tile);
        await rec.hold(const Duration(milliseconds: 900));
        expect(editor.selectedFolder, folder);
      }

      await rec.hold(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('folder_tile_contents/Imported/Props')), findsOneWidget);
      await enter('contents/Imported/Props');
      expect(editor.visibleFolders.map((f) => f.split('/').last),
          ['AC_units', 'Access_cards', 'Banana Bunch', 'Barrels', 'Gltf', 'Kitchen', 'Outdoor', 'Textures', 'Workshop']);
      await rec.hold(const Duration(seconds: 1));
      await shot('mirrored folders', {'batch_ms': batchMs, 'folders': editor.visibleFolders.length});

      // Into a mirrored kit: its meshes, with their rendered thumbnails.
      await enter('contents/Imported/Props/Barrels');
      final drain = Stopwatch()..start();
      while (editor.thumbnailQueueLength > 0 && drain.elapsed < const Duration(minutes: 3)) {
        await rec.hold(const Duration(milliseconds: 250));
      }
      await tester.runAsync(() => editor.thumbnailQueueIdle);
      await rec.hold(const Duration(seconds: 1));
      expect(editor.visibleAssets.map((a) => a.fileName), containsAll(['bent_barrel.lmas', 'dented_barrel.lmas', 'empty_barrel.lmas']));
      await shot('mirrored kit', {'assets': editor.visibleAssets.length});
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('content_browser_breadcrumb')), matching: find.text('Props')));
      await rec.hold(const Duration(milliseconds: 700));
      await enter('contents/Imported/Props/Workshop');
      await enter('contents/Imported/Props/Workshop/Tools');
      await rec.hold(const Duration(seconds: 1));
      expect(editor.visibleFolders.map((f) => f.split('/').last), ['handsaw', 'horse yoke', 'rake'],
          reason: 'three levels deep, mirrored');
      await tester.pump(const Duration(seconds: 6));
      await rec.hold(const Duration(milliseconds: 600));
      // ignore: avoid_print
      print('content browser folder import metrics: files=$files batch_ms=$batchMs '
          'full_props_scan_files=${full.files.length} full_props_scan_ms=$fullScanMs');
      rec.save('content browser: import asset folder', usedAssets: used);
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 15)));

  // The Sources rail is a collapsible tree, collapsed
  // below `contents` by default, and a splitter widens it beside the grid.
  testWidgets('content browser: collapsible folder tree and sources splitter', (WidgetTester tester) async {
    // Real Props meshes, imported into nested kit folders of a temp project.
    const kits = {
      'contents/Props/Barrels': ['Props/Barrels/empty_barrel.glb', 'Props/Barrels/fuel_barrel_red.glb', 'Props/Barrels/dented_barrel.glb'],
      'contents/Props/AC_units': ['Props/AC_units/ac_unit_a_300x300.glb'],
      'contents/Props/Kitchen/Banana Bunch': ['Props/Banana Bunch/banana_bunch_medium.glb'],
      'contents/Props/Access_cards': ['Props/Access_cards/access_card_blue.glb'],
    };
    final used = [for (final l in kits.values) ...l];
    for (final rel in used) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    final root = Directory.systemTemp.createTempSync('cb_folder_tree_smoke_');
    EditorViewModel? vm;
    try {
      const name = 'folder_tree_smoke';
      final dir = Directory('${root.path}/$name')..createSync(recursive: true);
      Directory('${dir.path}/contents/levels').createSync(recursive: true);
      File('${dir.path}/$name.lmproject').writeAsStringSync('{"project_name": "$name", "active_level": "contents/levels/L_Main.lmas"}');
      // More folders, some with long names the default rail width cuts off.
      for (final f in [
        'contents/Environment/Industrial_Warehouse_Interior_Props',
        'contents/Environment/Outdoor_Foliage_And_Rocks',
        'contents/Characters/Interactables',
        'contents/Audio/Ambience',
      ]) {
        Directory('${dir.path}/$f').createSync(recursive: true);
        File('${dir.path}/$f/.lumina_folder').writeAsStringSync('kept\n');
      }
      vm = EditorViewModel(
        initialProject: const LuminaProject(projectName: name),
        projectLocation: root.path,
        enableTimers: false,
        autoGenerateThumbnails: true,
      );
      final editor = vm;
      for (final e in kits.entries) {
        for (final rel in e.value) {
          await tester.runAsync(() => editor.processImportPipeline(
                sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$rel',
                targetSubFolder: e.key,
                autoOrganizeFiles: false,
              ));
        }
      }
      editor.refreshAssets();
      editor.selectedFolder = 'contents';
      expect(editor.layoutState.expandedFolders, {'contents'}, reason: 'a fresh layout opens only the root');
      // A taller bottom panel, so the tree has room on camera.
      editor.setPaneSize(bottomHeight: 560);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: MainEditorView(viewModel: editor))),
      ));
      await _settle(tester, 30);
      // Thumbnails render off camera first, so the video never idles on them.
      await tester.runAsync(() => editor.thumbnailQueueIdle);
      await _settle(tester, 10);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Finder row(String path) => find.byKey(ValueKey('source_folder_row_$path'));
      Finder chevron(String path) => find.byKey(ValueKey('source_folder_chevron_$path'));
      final rail = find.byKey(const ValueKey('content_browser_sources_rail'));
      final dragger = find.descendant(of: find.byType(ContentBrowserWidget), matching: find.byType(HorizontalResizableDragger));
      Future<void> shot(String suffix, Map<String, Object?> metrics) async => SmokeArtifacts.saveScreenshot(
            'content browser: collapsible folder tree and sources splitter ($suffix)',
            await SmokeArtifacts.captureIntegrationPng(IntegrationTestWidgetsFlutterBinding.instance, tester, boundary: find.byKey(boundaryKey)),
            usedAssets: used,
            metrics: metrics,
          );
      int builtRows() => find
          .byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('source_folder_row_'))
          .evaluate()
          .length;

      // 1. Collapsed by default: contents and its direct children only.
      await rec.hold(const Duration(milliseconds: 1200));
      expect(row('contents/Props'), findsOneWidget);
      expect(row('contents/Environment'), findsOneWidget);
      expect(row('contents/Props/Barrels'), findsNothing);
      expect(chevron('contents/Props'), findsOneWidget);
      final collapsedRows = builtRows();
      await shot('collapsed by default', {'rows': collapsedRows, 'folders': editor.sourceFolders.length});

      // 2. Expand Props with its chevron, then Barrels; click Barrels.
      await tester.tap(chevron('contents/Props'));
      await rec.hold(const Duration(milliseconds: 900));
      expect(row('contents/Props/Barrels'), findsOneWidget);
      expect(row('contents/Props/Kitchen'), findsOneWidget);
      await tester.tap(chevron('contents/Props/Kitchen'));
      await rec.hold(const Duration(milliseconds: 900));
      expect(row('contents/Props/Kitchen/Banana Bunch'), findsOneWidget);
      await tester.tap(row('contents/Props/Barrels'));
      await rec.hold(const Duration(milliseconds: 900));
      expect(editor.selectedFolder, 'contents/Props/Barrels');
      // Right arrow opens the selected folder (its materials subfolder).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await rec.hold(const Duration(milliseconds: 900));
      expect(editor.isFolderExpanded('contents/Props/Barrels'), isTrue);
      expect(editor.visibleAssets.map((a) => a.fileName), containsAll(['empty_barrel.lmas', 'fuel_barrel_red.lmas', 'dented_barrel.lmas']));
      await shot('folder expanded', {'rows': builtRows(), 'assets': editor.visibleAssets.length});

      // 3. Drag the Sources / grid splitter wider: the long names show.
      final before = tester.getSize(rail).width;
      await tester.tap(chevron('contents/Environment'));
      await rec.hold(const Duration(milliseconds: 700));
      final from = tester.getCenter(dragger);
      await rec.drag(from, from + const Offset(180, 0), steps: 36);
      await rec.hold(const Duration(milliseconds: 900));
      final after = tester.getSize(rail).width;
      expect(after, closeTo(before + 180, 25));
      expect(editor.layoutState.sourcesWidth, closeTo(after, 1));
      final saved = File('${editor.projectDirPath}/.lumina/editor_layout.json').readAsStringSync();
      expect(saved, contains('"sourcesWidth"'));
      expect(saved, contains('contents/Props/Barrels'));
      await shot('splitter dragged wider', {'rail_before': before, 'rail_after': after});

      // 4. Left collapses Barrels again; a breadcrumb hop keeps the tree.
      await tester.tap(row('contents/Props/Barrels'));
      await rec.hold(const Duration(milliseconds: 500));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await rec.hold(const Duration(milliseconds: 900));
      expect(editor.isFolderExpanded('contents/Props/Barrels'), isFalse);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('content_browser_breadcrumb')), matching: find.text('Props')));
      await rec.hold(const Duration(milliseconds: 900));
      expect(editor.selectedFolder, 'contents/Props');
      await rec.hold(const Duration(seconds: 1));
      // ignore: avoid_print
      print('content browser folder tree metrics: collapsed_rows=$collapsedRows rail_before=$before rail_after=$after');
      rec.save('content browser: collapsible folder tree and sources splitter', usedAssets: used);
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  // Every asset tile carries a strip in its
  // asset type's colour under the thumbnail, and names its type.
  testWidgets('content browser: asset type color strips', (WidgetTester tester) async {
    const imports = ['Props/Barrels/fuel_barrel_red.glb', 'Props/AC_units/ac_unit_a_300x300.glb', 'Props/Access_cards/access_card_blue.glb'];
    for (final rel in imports) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    // The layout this scenario was built on (the Linux runner's 1920×1080):
    // the Windows runner opens at 1280×720, too short for the 520 px browser.
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final root = Directory.systemTemp.createTempSync('cb_type_strips_smoke_');
    EditorViewModel? vm;
    try {
      // The launcher's real pipeline: the Third Person template brings the
      // skeletal mesh, its animations, the blend spaces, ABP and Blueprints.
      final config = Directory('${root.path}/.config')..createSync(recursive: true);
      final repo = ProjectRepository(configDir: config);
      useSharedEditor(config);
      final create = CreateProjectViewModel(launcherVM: LauncherViewModel(configDir: config, projectRepo: repo), projectRepo: repo)
        ..updateName('type_strips')
        ..updateLocation(root.path)
        ..updateTemplate(kThirdPersonTemplateId);
      await tester.runAsync(create.createProject);
      expect(create.creationError, isNull);
      vm = EditorViewModel(
        initialProject: create.activeProject!,
        projectLocation: root.path,
        enableTimers: false,
        autoGenerateThumbnails: true,
      );
      final editor = vm;
      // Static meshes, their materials and textures from test-assets/Props.
      for (final rel in imports) {
        await tester.runAsync(() => editor.processImportPipeline(
              sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$rel',
              targetSubFolder: 'contents/Props',
              autoOrganizeFiles: false,
            ));
      }
      editor.refreshAssets();

      // One collection with a few of every kind, so the grid shows them all.
      List<RealAssetInfo> ofType(AssetType t, int n) => editor.realAssets.where((a) => a.type == t).take(n).toList();
      final picked = [
        ...ofType(AssetType.filameshSk, 1),
        ...ofType(AssetType.animation, 4),
        ...ofType(AssetType.blendSpace, 2),
        ...ofType(AssetType.animBlueprint, 1),
        ...ofType(AssetType.actor, 2),
        ...ofType(AssetType.level, 1),
        ...ofType(AssetType.filamesh, 3),
        ...ofType(AssetType.filamat, 2),
        ...ofType(AssetType.texture, 2),
      ];
      final kinds = picked.map((a) => a.type).toSet();
      expect(kinds, containsAll([
        AssetType.filameshSk, AssetType.animation, AssetType.blendSpace, AssetType.animBlueprint,
        AssetType.actor, AssetType.level, AssetType.filamesh, AssetType.filamat, AssetType.texture,
      ]), reason: 'template + Props give every kind the scenario shows');
      editor.createCollection('Type Strips');
      for (final a in picked) {
        editor.addToCollection('Type Strips', a.assetId!);
      }
      editor.setPaneSize(bottomHeight: 520);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: MainEditorView(viewModel: editor))),
      ));
      await _settle(tester, 30);
      // Thumbnails render off camera first.
      await tester.runAsync(() => editor.thumbnailQueueIdle);
      editor.activeCollection = 'Type Strips';
      await _settle(tester, 20);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(milliseconds: 1500));
      expect(editor.visibleAssets.length, picked.length);

      Finder strip(RealAssetInfo a) => find.byKey(ValueKey('asset_type_strip_${a.relativePath}'));

      /// Samples every strip's centre in a fresh capture and compares it with
      /// its token under the active theme; returns the capture.
      Future<(Uint8List, Map<String, Object?>)> measure(String theme) async {
        final png = await SmokeArtifacts.captureIntegrationPng(IntegrationTestWidgetsFlutterBinding.instance, tester,
            boundary: find.byKey(boundaryKey));
        final image = img.decodePng(png)!;
        final origin = tester.getTopLeft(find.byKey(boundaryKey));
        final scale = image.width / tester.getSize(find.byKey(boundaryKey)).width;
        final samples = <String, Object?>{};
        var worst = 0;
        for (final a in picked) {
          expect(strip(a), findsOneWidget, reason: a.fileName);
          final r = tester.getRect(strip(a));
          final px = image.getPixel(((r.center.dx - origin.dx) * scale).floor(), ((r.center.dy - origin.dy) * scale).floor());
          final want = AssetTypeStyle.of(a.type).color.toARGB32();
          final wr = (want >> 16) & 0xFF, wg = (want >> 8) & 0xFF, wb = want & 0xFF;
          final d = [(px.r.toInt() - wr).abs(), (px.g.toInt() - wg).abs(), (px.b.toInt() - wb).abs()].reduce((x, y) => x > y ? x : y);
          worst = d > worst ? d : worst;
          expect(d, lessThanOrEqualTo(6),
              reason: '$theme ${a.fileName} (${a.type.name}) strip pixel '
                  '(${px.r},${px.g},${px.b}) vs token ${want.toRadixString(16)}');
          samples['${a.type.name}:${a.fileName}'] = '#${px.r.toInt().toRadixString(16).padLeft(2, '0')}'
              '${px.g.toInt().toRadixString(16).padLeft(2, '0')}${px.b.toInt().toRadixString(16).padLeft(2, '0')}';
          expect(tester.widget<Text>(find.byKey(ValueKey('asset_type_label_${a.relativePath}'))).data,
              AssetTypeStyle.of(a.type).displayName);
        }
        samples['max_channel_delta'] = worst;
        return (png, samples);
      }

      /// The tiles' bounding box, cropped from [png] and doubled (nearest).
      Uint8List closeUp(Uint8List png) {
        final image = img.decodePng(png)!;
        final origin = tester.getTopLeft(find.byKey(boundaryKey));
        final scale = image.width / tester.getSize(find.byKey(boundaryKey)).width;
        var box = tester.getRect(find.byKey(ValueKey('asset_tile_card_${picked.first.relativePath}')));
        for (final a in picked.skip(1)) {
          box = box.expandToInclude(tester.getRect(find.byKey(ValueKey('asset_tile_card_${a.relativePath}'))));
        }
        box = box.inflate(6);
        final crop = img.copyCrop(image,
            x: ((box.left - origin.dx) * scale).round(),
            y: ((box.top - origin.dy) * scale).round(),
            width: (box.width * scale).round(),
            height: (box.height * scale).round());
        return img.encodePng(img.copyResize(crop, width: crop.width * 2, interpolation: img.Interpolation.nearest));
      }

      final used = [...imports, 'lumina: assets/templates/third_person/SKM_Superhero_Female.glb'];
      final (darkPng, darkSamples) = await measure('Lumina Dark');
      SmokeArtifacts.saveScreenshot('content browser: asset type color strips (grid)', darkPng,
          usedAssets: used, metrics: {'tiles': picked.length, 'kinds': kinds.length, ...darkSamples});
      SmokeArtifacts.saveScreenshot('content browser: asset type color strips (close-up)', closeUp(darkPng),
          usedAssets: used, metrics: {'scale': 2});
      await rec.hold(const Duration(seconds: 2));

      // Hover a skeletal mesh tile: the tooltip's swatch names the type.
      final skm = picked.firstWhere((a) => a.type == AssetType.filameshSk);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getTopLeft(find.byKey(boundaryKey)));
      await mouse.moveTo(tester.getCenter(find.byKey(ValueKey('asset_tile_card_${skm.relativePath}'))));
      await rec.hold(const Duration(milliseconds: 1800));
      expect(find.byType(TooltipContainer), findsWidgets);
      expect(find.descendant(of: find.byType(TooltipContainer), matching: find.byType(AssetTypeSwatch)), findsOneWidget);
      SmokeArtifacts.saveScreenshot(
          'content browser: asset type color strips (tooltip)',
          await SmokeArtifacts.captureIntegrationPng(IntegrationTestWidgetsFlutterBinding.instance, tester,
              boundary: find.byKey(boundaryKey)),
          usedAssets: used);
      await mouse.moveTo(tester.getTopLeft(find.byKey(boundaryKey)) + const Offset(4, 4));
      await rec.hold(const Duration(milliseconds: 800));

      // Select an animation: the selection border frames the tile, strip kept.
      final anim = picked.firstWhere((a) => a.type == AssetType.animation);
      await tester.tap(_tile(anim.fileName));
      await rec.hold(const Duration(milliseconds: 1200));

      // Lumina Light recolours the strips live.
      EditorTheme.apply(EditorThemeData.luminaLight);
      await rec.hold(const Duration(milliseconds: 1500));
      final (lightPng, lightSamples) = await measure('Lumina Light');
      SmokeArtifacts.saveScreenshot('content browser: asset type color strips (light theme)', lightPng,
          usedAssets: used, metrics: lightSamples);
      await rec.hold(const Duration(milliseconds: 1500));
      EditorTheme.apply(EditorThemeData.luminaDark);
      await rec.hold(const Duration(milliseconds: 1500));
      await mouse.removePointer();
      // ignore: avoid_print
      print('content browser type strip metrics: tiles=${picked.length} kinds=${kinds.length} '
          'dark_max_delta=${darkSamples['max_channel_delta']} light_max_delta=${lightSamples['max_channel_delta']}');
      rec.save('content browser: asset type color strips', usedAssets: used);
    } finally {
      EditorTheme.apply(EditorThemeData.luminaDark);
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}

/// 30 real meshes for the batch import: every light fixture, then signs.
List<String> _batchSources() {
  List<String> glbs(String folder) {
    final dir = Directory('${SmokeArtifacts.testAssetsDir.path}/Props/$folder');
    if (!dir.existsSync()) return const [];
    return [
      for (final e in dir.listSync())
        if (e is File && e.path.endsWith('.glb')) e.path,
    ]..sort();
  }

  final lights = glbs('light_fixtures');
  return [...lights, ...glbs('signs_generic').take(30 - lights.length)];
}
