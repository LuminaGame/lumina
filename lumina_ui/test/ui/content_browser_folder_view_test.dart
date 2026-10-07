import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/create_project_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// Performs the on-disk effects of `flutter create`; `pub get` is a no-op
/// because nothing here resolves packages.
ProcessRunner _scaffoldingRunner() {
  return (String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
    if (args.isNotEmpty && args.first == 'create') {
      final target = args.last;
      final projectName = args[args.indexOf('--project-name') + 1];
      Directory('$target/lib').createSync(recursive: true);
      File('$target/pubspec.yaml').writeAsStringSync(
        'name: $projectName\n'
        'environment:\n'
        '  sdk: ^3.12.0\n'
        'dependencies:\n'
        '  flutter:\n'
        '    sdk: flutter\n',
      );
    }
    return ProcessResult(0, 0, '', '');
  };
}

/// The grid lists only the selected folder (folder tiles
/// first); a search widens to the folder's subtree, Show All to the project;
/// a new Third Person project arrives foldered.
void main() {
  late Directory root;
  late String dir;
  const name = 'cb_folders';
  const clipDir = 'contents/animations/${LuminaThirdPersonContent.meshAssetName}';

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_cb_folder_view_');
    final config = Directory('${root.path}/.config')..createSync(recursive: true);
    final repo = ProjectRepository(configDir: config, processRunner: _scaffoldingRunner());
    final create = CreateProjectViewModel(
      launcherVM: LauncherViewModel(configDir: config, projectRepo: repo),
      projectRepo: repo,
    )
      ..updateName(name)
      ..updateLocation(root.path)
      ..updateTemplate(kThirdPersonTemplateId);
    await create.createProject();
    expect(create.creationError, isNull);
    dir = '${root.path}/$name';
  });
  // A widget test cannot await vm.close() (see deleteTempProject).
  tearDownAll(() => deleteTempProject(root));

  Future<EditorViewModel> openBrowser(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$dir/$name.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    vm.refreshAssets();
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      // The editor shell rebuilds the browser on every view-model change.
      home: Scaffold(
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) => SizedBox(width: 1500, height: 900, child: ContentBrowserWidget(viewModel: vm)),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    return vm;
  }

  Iterable<String> assetTiles(WidgetTester tester) => tester
      .widgetList(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('asset_item_')))
      .map((w) => (w.key as ValueKey<String>).value.substring('asset_item_'.length));

  String countChip(WidgetTester tester) =>
      tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('content_browser_asset_count')), matching: find.byType(Text))).data!;

  Future<void> doubleTap(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 400));
  }

  test('a new Third Person project arrives with widgets/ and input/ folders kept by a marker', () {
    for (final folder in ['blueprints', 'animations/${LuminaThirdPersonContent.meshAssetName}', 'meshes/skeletal', 'levels', 'widgets', 'input']) {
      expect(Directory('$dir/contents/$folder').existsSync(), isTrue, reason: folder);
    }
    expect(File('$dir/contents/widgets/.lumina_folder').existsSync(), isTrue);
    expect(File('$dir/contents/input/.lumina_folder').existsSync(), isTrue);
  });

  testWidgets('selecting contents lists the folder tiles and no assets; the count chip shows 0', (tester) async {
    final vm = await openBrowser(tester);
    vm.selectedFolder = 'contents';
    await tester.pump(const Duration(milliseconds: 100));
    for (final folder in ['animations', 'blueprints', 'levels', 'meshes', 'widgets', 'input']) {
      expect(find.byKey(ValueKey('folder_tile_contents/$folder')), findsOneWidget, reason: folder);
    }
    expect(find.byKey(const ValueKey('folder_tile_contents/animations/${LuminaThirdPersonContent.meshAssetName}')), findsNothing,
        reason: 'only direct children are tiles');
    expect(assetTiles(tester), isEmpty, reason: 'no clip or Blueprint tiles at the root');
    expect(countChip(tester), '0 assets');
  });

  testWidgets('double-clicking animations then SKM_Superhero_Female lists the 21 clips; the breadcrumb follows', (tester) async {
    final vm = await openBrowser(tester);
    await doubleTap(tester, find.byKey(const ValueKey('folder_tile_contents/animations')));
    expect(vm.selectedFolder, 'contents/animations');
    expect(assetTiles(tester), isEmpty);
    await doubleTap(tester, find.byKey(const ValueKey('folder_tile_$clipDir')));
    expect(vm.selectedFolder, clipDir);

    final tiles = assetTiles(tester).toList();
    final clipTiles = tiles.where((p) => vm.realAssets.firstWhere((a) => a.relativePath == p).type == AssetType.animation).toList();
    // 21 clips when this task landed; the template's clip list is the truth.
    expect(clipTiles.length, LuminaThirdPersonContent.clipNames.length);
    for (final clip in LuminaThirdPersonContent.clipNames) {
      expect(clipTiles, contains('$clipDir/$clip.lmas'), reason: clip);
    }
    expect(tiles.every((p) => p.startsWith('$clipDir/') && !p.substring(clipDir.length + 1).contains('/')), isTrue);
    expect(countChip(tester), '${tiles.length} assets');

    final crumb = tester
        .widgetList<Text>(find.descendant(of: find.byKey(const ValueKey('content_browser_breadcrumb')), matching: find.byType(Text)))
        .map((t) => t.data)
        .join(' ');
    expect(crumb, 'contents › animations › ${LuminaThirdPersonContent.meshAssetName}');
  });

  testWidgets('typing "walk" at the root lists the eight walk clips; clearing returns to the folder view', (tester) async {
    final vm = await openBrowser(tester);
    vm.selectedFolder = 'contents';
    await tester.enterText(find.byKey(const ValueKey('content_browser_search')), 'walk');
    await tester.pump(const Duration(milliseconds: 300));
    final tiles = assetTiles(tester).toList();
    for (final clip in LuminaThirdPersonContent.walkClips.values) {
      expect(tiles, contains('$clipDir/$clip.lmas'), reason: clip);
    }
    final clips = tiles.where((p) => vm.realAssets.firstWhere((a) => a.relativePath == p).type == AssetType.animation);
    expect(clips.length, 8);
    expect(find.byKey(const ValueKey('folder_tile_contents/animations')), findsNothing, reason: 'a search shows results, not folders');

    await tester.enterText(find.byKey(const ValueKey('content_browser_search')), '');
    await tester.pump(const Duration(milliseconds: 300));
    expect(assetTiles(tester), isEmpty);
    expect(find.byKey(const ValueKey('folder_tile_contents/animations')), findsOneWidget);
  });

  testWidgets('the Blueprint type filter at the root lists nothing until Show All is on, then both Blueprints', (tester) async {
    final vm = await openBrowser(tester);
    vm.selectedFolder = 'contents';
    await tester.tap(find.text('Blueprint'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(vm.activeTypeFilters, {AssetType.actor});
    expect(assetTiles(tester), isEmpty);

    await tester.tap(find.byKey(const ValueKey('content_browser_show_all')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(vm.showAllAssets, isTrue);
    expect(assetTiles(tester).toSet(), {
      LuminaThirdPersonContent.characterBlueprintPath,
      LuminaThirdPersonContent.gameModeBlueprintPath,
    });
    expect(countChip(tester), '2 assets');
  });

  testWidgets('dragging BP_Chair onto the blueprints tile moves it on disk; it then shows only in that folder', (tester) async {
    final vm = await openBrowser(tester);
    await tester.runAsync(() => vm.createNewAssetOnDisk('', 'BP_Chair.lmas', AssetType.actor));
    vm.selectedFolder = 'contents';
    await tester.pump(const Duration(milliseconds: 100));
    expect(assetTiles(tester), ['contents/BP_Chair.lmas']);

    final tile = find.byKey(const ValueKey('asset_item_contents/BP_Chair.lmas'));
    final target = find.byKey(const ValueKey('folder_tile_contents/blueprints'));
    final gesture = await tester.startGesture(tester.getCenter(tile));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(() async {
      await gesture.up();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 300));

    expect(File('$dir/contents/BP_Chair.lmas').existsSync(), isFalse);
    expect(File('$dir/contents/blueprints/BP_Chair.lmas').existsSync(), isTrue);
    expect(assetTiles(tester), isEmpty, reason: 'gone from the root');
    vm.selectedFolder = 'contents/blueprints';
    await tester.pump(const Duration(milliseconds: 100));
    expect(assetTiles(tester), contains('contents/blueprints/BP_Chair.lmas'));
  });

  test('folder commands create, rename and delete real folders and keep references', () async {
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$dir/$name.lmproject').readAsStringSync()) as Map));
    final vm2 = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false)
      ..refreshAssets();
    addTearDown(vm2.dispose);
    final created = vm2.createContentFolder('contents/blueprints', 'Props');
    expect(created, 'contents/blueprints/Props');
    expect(File('$dir/contents/blueprints/Props/.lumina_folder').existsSync(), isTrue);
    expect(vm2.sourceFolders, contains('contents/blueprints/Props'));
    expect(vm2.createContentFolder('contents/blueprints', 'Props'), 'contents/blueprints/Props_1', reason: 'unique name');

    await vm2.createNewAssetOnDisk('blueprints/Props', 'BP_Lamp.lmas', AssetType.actor);
    final renamed = vm2.renameContentFolder('contents/blueprints/Props', 'Lamps');
    expect(renamed, 'contents/blueprints/Lamps');
    expect(File('$dir/contents/blueprints/Lamps/BP_Lamp.lmas').existsSync(), isTrue);
    expect(vm2.realAssets.any((a) => a.relativePath == 'contents/blueprints/Lamps/BP_Lamp.lmas'), isTrue);

    vm2.selectedFolder = 'contents/blueprints/Lamps';
    expect(await vm2.deleteContentFolder('contents/blueprints/Lamps'), isTrue);
    expect(await vm2.deleteContentFolder('contents/blueprints/Props_1'), isTrue);
    expect(Directory('$dir/contents/blueprints/Lamps').existsSync(), isFalse);
    expect(vm2.selectedFolder, 'contents/blueprints', reason: 'the browser steps out of a deleted folder');
    expect(vm2.realAssets.any((a) => a.relativePath.contains('BP_Lamp')), isFalse);
  });
}
