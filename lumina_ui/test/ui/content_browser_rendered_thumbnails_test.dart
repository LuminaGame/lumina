import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing/smoke_artifacts.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Content Browser shows Filament-rendered
/// thumbnails, generated in the background when a project opens and after an
/// asset is saved, cached, and refreshed when stale.
///
/// Real project: a launcher Third Person scaffold (`flutter create` is the
/// only step faked: this is not a build test) plus the barrel, AC unit and
/// banana bunch imported through the real import pipeline, rendered on the
/// GPU (GPU 1 via `FILAMENT_GPU`).

/// `flutter create` writes what the scaffold edits; `pub get` is not needed.
ProcessRunner _scaffoldingRunner() {
  return (String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
    if (args.isNotEmpty && args.first == 'create') {
      final target = args.last;
      final name = args[args.indexOf('--project-name') + 1];
      Directory('$target/lib').createSync(recursive: true);
      File('$target/pubspec.yaml').writeAsStringSync(
        'name: $name\nenvironment:\n  sdk: ^3.12.0\ndependencies:\n  flutter:\n    sdk: flutter\nflutter:\n  uses-material-design: true\n',
      );
    }
    return ProcessResult(0, 0, '', '');
  };
}

const _imports = [
  'Props/Barrels/fuel_barrel_red.glb',
  'Props/AC_units/ac_unit_a_300x300.glb',
  'Props/Banana Bunch/banana_bunch_medium.glb',
];

const _rendered = {AssetType.filamesh, AssetType.filameshSk, AssetType.filamat, AssetType.level};

/// The thumbnail stored in the `.lmas` — its only home (lumina
/// no `.thumbnails/` sidecar is ever written).
Uint8List _cached(String lmasPath) {
  expect(Directory('${File(lmasPath).parent.path}/.thumbnails').existsSync(), isFalse, reason: 'no sidecar beside $lmasPath');
  return base64Decode(_rawLmas(lmasPath)['thumbnail_png'] as String);
}

Map<String, dynamic> _rawLmas(String path) {
  final bytes = File(path).readAsBytesSync();
  final lmas = bytes.length >= 4 && bytes[0] == 0x4C && bytes[1] == 0x4D && bytes[2] == 0x41 && bytes[3] == 0x53;
  return jsonDecode(utf8.decode(lmas ? bytes.sublist(4) : bytes)) as Map<String, dynamic>;
}

void _save(String name, Uint8List png) {
  final dir = Directory('build/thumbnails')..createSync(recursive: true);
  final file = File('${dir.path}/$name')..writeAsBytesSync(png);
  // ignore: avoid_print
  print('thumbnail: ${file.absolute.path}');
}

void main() {
  late Directory root;
  late String projectDir;
  late LuminaProject project;
  FilamentThumbnailRenderer? renderer;
  late EditorViewModel vm;
  var vmCreated = false;
  final seen = <String>{};
  var assetsPresent = true;

  setUpAll(() async {
    for (final rel in _imports) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$rel').existsSync()) assetsPresent = false;
    }
    root = Directory.systemTemp.createTempSync('cb_thumbnails_');
    final config = Directory('${root.path}/.config')..createSync(recursive: true);
    project = await ProjectRepository(configDir: config, processRunner: _scaffoldingRunner()).createProject(
      projectName: 'thumb_game',
      projectLocation: root.path,
      template: kThirdPersonTemplateId,
    );
    projectDir = '${root.path}/thumb_game';
    if (assetsPresent) {
      for (final rel in _imports) {
        await AssetRepository().importExternalFile(
          projectPath: projectDir,
          sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$rel',
        );
      }
    }
    final ibl = File('assets/ibl/default_env/default_env_ibl.ktx');
    renderer = FilamentThumbnailRenderer(iblKtx: ibl.existsSync() ? ibl.readAsBytesSync() : null);
  });

  /// The editor opened on the project, every stale thumbnail rendered — what
  /// the first test sets up and the next two build on. They open it
  /// themselves when it is not there yet: a sharded run
  /// (`--total-shards`) runs each test of this file in its own process.
  Future<EditorViewModel> openEditor() async {
    if (vmCreated) return vm;
    vm = EditorViewModel(
      initialProject: project,
      projectLocation: root.path,
      enableTimers: false,
      autoGenerateThumbnails: true,
      thumbnailService: ThumbnailService(renderer: renderer!),
    );
    vmCreated = true;
    vm.addListener(() => seen.addAll(vm.pendingThumbnails));
    await vm.ensureDefaultLevelAssets();
    await vm.thumbnailQueueIdle;
    return vm;
  }

  tearDownAll(() {
    if (vmCreated) vm.dispose();
    renderer?.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('opening a Third Person project queues every asset without a current thumbnail and renders them', () async {
    if (!assetsPresent) return markTestSkipped('test-assets missing');
    final before = AssetRepository().scanProjectContents(projectDir);
    final stale = before.where(ThumbnailService.isStaleInfo).map((a) => a.lmasPath!).toSet();
    final current = before.where((a) => !ThumbnailService.isStaleInfo(a)).map((a) => a.lmasPath!).toSet();
    // The scaffold's level and mannequin and every imported mesh, material and
    // texture carry, at best, a CPU badge from before this task.
    for (final a in before.where((a) => _rendered.contains(a.type) || a.type == AssetType.texture)) {
      expect(stale, contains(a.lmasPath), reason: '${a.fileName} has no current thumbnail');
    }
    expect(before.any((a) => a.type == AssetType.level), isTrue);
    expect(before.any((a) => a.type == AssetType.filameshSk), isTrue, reason: 'the Quinn mannequin');
    expect(before.where((a) => a.type == AssetType.filamesh), hasLength(_imports.length));
    expect(before.any((a) => a.type == AssetType.filamat), isTrue);
    expect(before.any((a) => a.type == AssetType.texture), isTrue);

    expect(vmCreated, isFalse, reason: 'this test opens the project');
    await openEditor();

    expect(seen, containsAll(stale), reason: 'every stale asset was queued');
    expect(seen.intersection(current), isEmpty, reason: 'assets with a current thumbnail are left alone');
    expect(vm.thumbnailQueueLength, 0);

    for (final a in AssetRepository().scanProjectContents(projectDir)) {
      if (!_rendered.contains(a.type) && a.type != AssetType.texture) continue;
      final map = _rawLmas(a.lmasPath!);
      final png = base64Decode(map['thumbnail_png'] as String);
      final source = (map['metadata'] as Map)[ThumbnailService.sourceKey];
      expect(source, a.type == AssetType.texture ? ThumbnailService.sourceImage : ThumbnailService.sourceFilament,
          reason: a.fileName);
      expect(_cached(a.lmasPath!), orderedEquals(png), reason: a.fileName);
      expect(ThumbnailService.isStaleInfo(a), isFalse, reason: a.fileName);
      // The tile shows exactly this thumbnail.
      final tile = vm.realAssets.firstWhere((t) => t.lmasPath == a.lmasPath);
      expect(tile.thumbnailBytes, orderedEquals(png), reason: a.fileName);
      _save('project_${a.fileName.replaceAll('.lmas', '')}.png', png);
    }
    // The level is still the editor's JSON document with its actors.
    final level = vm.realAssets.firstWhere((a) => a.type == AssetType.level).lmasPath!;
    expect(File(level).readAsStringSync(), startsWith('{'));
    expect(((_rawLmas(level)['metadata'] as Map)['actors'] as List), isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('saving an edited material re-renders its thumbnail; unchanged assets are not re-rendered', () async {
    if (!assetsPresent) return markTestSkipped('test-assets missing');
    await openEditor();
    final material = vm.realAssets.firstWhere((a) => a.type == AssetType.filamat);
    final mesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh);
    final materialPng = _cached(material.lmasPath!);
    final meshPng = _cached(mesh.lmasPath!);
    final meshCacheTime = File(mesh.lmasPath!).lastModifiedSync();
    final meshLmasTime = File(mesh.lmasPath!).lastModifiedSync();

    // Open it in a Material Editor tab, as the Content Browser does.
    vm.openSubEditorTab('Material', asset: material);
    final editor = MaterialEditorViewModel(assetPath: material.lmasPath!);
    await editor.load();
    vm.bindTabSession(material.lmasPath!, notifier: editor, save: editor.save, isDirty: () => editor.isDirty);
    await vm.thumbnailQueueIdle;
    seen.clear();

    // Tint the imported base colour blue, compile, save.
    final tinted = editor.currentCode.replaceFirst(
      RegExp(r'material\.baseColor = vec4\([^)]*\);'),
      'material.baseColor = vec4(0.05, 0.15, 0.9, 1.0);',
    );
    expect(tinted, isNot(editor.currentCode), reason: 'the imported source sets a literal base colour');
    editor.currentCode = tinted;
    expect(await editor.compile(), isTrue);
    expect(await editor.save(), isTrue);

    expect(vm.pendingThumbnails, contains(material.lmasPath), reason: 'the save queued a new thumbnail');
    await vm.thumbnailQueueIdle;

    final after = _cached(material.lmasPath!);
    expect(after, isNot(orderedEquals(materialPng)), reason: 'the thumbnail was rendered again');
    expect(base64Decode(_rawLmas(material.lmasPath!)['thumbnail_png'] as String), orderedEquals(after));
    _save('material_after_save.png', after);

    expect(seen, {material.lmasPath}, reason: 'only the saved asset was re-rendered');
    expect(_cached(mesh.lmasPath!), orderedEquals(meshPng));
    expect(File(mesh.lmasPath!).lastModifiedSync(), meshCacheTime);
    expect(File(mesh.lmasPath!).lastModifiedSync(), meshLmasTime);

    // Reopening the project finds nothing to do.
    seen.clear();
    vm.refreshAssets();
    await vm.thumbnailQueueIdle;
    expect(seen, isEmpty);
    editor.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('importing a mesh renders thumbnails for everything the import emitted, and only for that', () async {
    final can = File('${SmokeArtifacts.testAssetsDir.path}/Props/JerryCan/jerrycan.glb');
    if (!assetsPresent || !can.existsSync()) return markTestSkipped('test-assets missing');
    await openEditor();
    final before = vm.realAssets.map((a) => a.lmasPath!).toSet();
    await vm.thumbnailQueueIdle;
    seen.clear();

    await vm.processImportPipeline(sourceFilePath: can.path);
    final emitted = vm.realAssets.where((a) => !before.contains(a.lmasPath)).toList();
    expect(emitted.map((a) => a.type), containsAll([AssetType.filamesh, AssetType.filamat, AssetType.texture]));
    await vm.thumbnailQueueIdle;

    expect(seen, emitted.map((a) => a.lmasPath).toSet(), reason: 'the import queued exactly what it emitted');
    for (final a in emitted) {
      final map = _rawLmas(a.lmasPath!);
      expect((map['metadata'] as Map)[ThumbnailService.sourceKey],
          a.type == AssetType.texture ? ThumbnailService.sourceImage : ThumbnailService.sourceFilament,
          reason: a.fileName);
      final tile = vm.realAssets.firstWhere((t) => t.lmasPath == a.lmasPath);
      expect(tile.thumbnailBytes, orderedEquals(_cached(a.lmasPath!)), reason: a.fileName);
      _save('import_${a.fileName.replaceAll('.lmas', '')}.png', tile.thumbnailBytes!);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('a Content Browser tile shows the rendered PNG, and Regenerate Thumbnail renders it again', (tester) async {
    if (!assetsPresent) return markTestSkipped('test-assets missing');
    await tester.binding.setSurfaceSize(const Size(1600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Runs on its own too: render whatever the first test has not.
    await tester.runAsync(() async {
      final service = ThumbnailService(renderer: renderer!);
      for (final a in AssetRepository().scanProjectContents(projectDir)) {
        await service.generate(a.lmasPath!);
      }
    });
    final browserVm = EditorViewModel(
      initialProject: project,
      projectLocation: root.path,
      enableTimers: false,
      autoInitAssets: false,
      thumbnailService: ThumbnailService(renderer: renderer!),
    )..showAllAssets = true; // The root lists its own folder only; Show All lists the project as this test expects.
    addTearDown(browserVm.dispose);
    final mesh = browserVm.realAssets.firstWhere((a) => a.type == AssetType.filamesh);
    final cached = _cached(mesh.lmasPath!);

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      // Hosted like MainEditorView hosts it: rebuilt whenever the editor
      // notifies, which is how a tile updates as its thumbnail lands.
      home: Scaffold(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 1300,
            height: 700,
            child: ListenableBuilder(
              listenable: browserVm,
              builder: (context, _) => ContentBrowserWidget(viewModel: browserVm),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    for (final a in browserVm.realAssets.where((a) => _rendered.contains(a.type) || a.type == AssetType.texture)) {
      final image = find.byKey(ValueKey('asset_thumbnail_${a.relativePath}'));
      expect(image, findsOneWidget, reason: '${a.fileName} shows its thumbnail, not the type icon');
      final provider = tester.widget<Image>(image).image as MemoryImage;
      expect(provider.bytes, orderedEquals(_cached(a.lmasPath!)), reason: a.fileName);
    }
    expect(
      (tester.widget<Image>(find.byKey(ValueKey('asset_thumbnail_${mesh.relativePath}'))).image as MemoryImage).bytes,
      orderedEquals(cached),
    );

    // Right-click → Regenerate Thumbnail renders the (current) thumbnail again.
    String renderedAt() => (_rawLmas(mesh.lmasPath!)['metadata'] as Map)[ThumbnailService.renderedAtKey] as String;
    final renderedBefore = renderedAt();
    // A right-click held like a hand holds it (past the tap deadline, where the
    // context menu's secondary-tap-down fires).
    final press = await tester.startGesture(
      tester.getCenter(find.byKey(ValueKey('asset_item_${mesh.relativePath}'))),
      buttons: kSecondaryButton,
    );
    await tester.pump(const Duration(milliseconds: 150));
    await press.up();
    await tester.pumpAndSettle();
    expect(find.text('Regenerate Thumbnail'), findsOneWidget);
    final queued = <String>{};
    browserVm.addListener(() => queued.addAll(browserVm.pendingThumbnails));
    // Press the item (its hit area sits under the popup's entrance animation in
    // the test binding, so invoke the button the way a click does), outside the
    // fake clock: the render runs on the GPU and its loader polls real time.
    final item = find.ancestor(of: find.text('Regenerate Thumbnail'), matching: find.byType(MenuButton));
    final button = tester.widget<MenuButton>(item);
    final itemContext = tester.element(item);
    await tester.runAsync(() async => button.onPressed!(itemContext));
    expect(queued, contains(mesh.lmasPath));
    // While it renders, the queue's progress card floats over the browser.
    var sawProgress = false;
    for (var i = 0; i < 2000 && browserVm.thumbnailQueueLength > 0; i++) {
      await tester.pump();
      if (find.text('Generating Thumbnails (1 left)').evaluate().isNotEmpty) sawProgress = true;
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    }
    expect(sawProgress, isTrue, reason: 'the "Generating Thumbnails" card showed while the render ran');
    await tester.runAsync(() async {
      await browserVm.thumbnailQueueIdle;
      // Past the cache file's mtime granularity.
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(find.byKey(const ValueKey('thumbnail_queue_progress')), findsNothing);
    expect(renderedAt(), isNot(renderedBefore), reason: 'a current thumbnail was rendered again on request');
    expect(browserVm.thumbnailQueueLength, 0);
    final regenerated = browserVm.realAssets.firstWhere((a) => a.lmasPath == mesh.lmasPath);
    expect(regenerated.thumbnailSource, ThumbnailService.sourceFilament);
    expect(regenerated.thumbnailBytes, orderedEquals(_cached(mesh.lmasPath!)));
    // …and the tile shows the new render.
    expect(
      (tester.widget<Image>(find.byKey(ValueKey('asset_thumbnail_${mesh.relativePath}'))).image as MemoryImage).bytes,
      orderedEquals(_cached(mesh.lmasPath!)),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
