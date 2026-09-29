import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/source_control/services/git_service.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/services/content_folders.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_layout_state.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_folder_tree.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Sources rail is a collapsible folder tree,
/// collapsed below `contents` by default, with a persisted splitter to the
/// asset grid. Everything runs on a real temp project on disk.
void main() {
  late Directory root;
  late String dir;
  const name = 'tree_proj';

  void folder(String rel) {
    final d = Directory('$dir/$rel')..createSync(recursive: true);
    ContentFolders.writeMarker(d.path);
  }

  void asset(String rel, AssetType type) {
    final file = File('$dir/$rel')..parent.createSync(recursive: true);
    final base = rel.split('/').last.replaceAll('.lmas', '');
    file.writeAsBytesSync(LuminaAsset(assetId: 'asset_$base', name: base, type: type).toProtoBufferBytes());
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_cb_tree_');
    dir = '${root.path}/$name';
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.lmproject').writeAsStringSync(jsonEncode({'project_name': name}));
    folder('contents/animations/SKM_Superhero_Female');
    folder('contents/blueprints');
    folder('contents/props/barrels');
    folder('contents/props/kitchen/tin_cans');
    asset('contents/materials/M_Wood.lmas', AssetType.filamat);
    asset('contents/props/kitchen/tin_cans/SM_Can.lmas', AssetType.filamesh);
    asset('contents/SM_Crate.lmas', AssetType.filamesh);
  });
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  EditorViewModel newVm() {
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: name),
      projectLocation: root.path,
      enableTimers: false,
      autoInitAssets: false,
    )..refreshAssets();
    return vm;
  }

  Map<String, dynamic> layoutJson(EditorViewModel vm) =>
      jsonDecode(File('${vm.projectDirPath}/.lumina/editor_layout.json').readAsStringSync()) as Map<String, dynamic>;

  Finder row(String path) => find.byKey(ValueKey('source_folder_row_$path'));
  Finder chevron(String path) => find.byKey(ValueKey('source_folder_chevron_$path'));
  Finder rail() => find.byKey(const ValueKey('content_browser_sources_rail'));
  Finder sourcesDragger() =>
      find.descendant(of: find.byType(ContentBrowserWidget), matching: find.byType(HorizontalResizableDragger));

  Iterable<String> builtRows(WidgetTester tester) => tester
      .widgetList(find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('source_folder_row_')))
      .map((w) => (w.key as ValueKey<String>).value.substring('source_folder_row_'.length));

  Future<EditorViewModel> openBrowser(WidgetTester tester, {double height = 900, EditorViewModel? existing}) async {
    tester.view.physicalSize = Size(1600, height + 100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final vm = existing ?? newVm();
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) => SizedBox(width: 1500, height: height, child: ContentBrowserWidget(viewModel: vm)),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    return vm;
  }

  Future<EditorViewModel> openEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final vm = newVm();
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump(const Duration(milliseconds: 500));
    return vm;
  }

  /// A splitter drag the way a hand moves: many small steps (the resizer
  /// refuses a single jump larger than the space it can borrow).
  Future<void> dragSplitter(WidgetTester tester, double dx, {int steps = 20}) async {
    final gesture = await tester.startGesture(tester.getCenter(sourcesDragger()), kind: PointerDeviceKind.mouse);
    await tester.pump();
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(dx / steps, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> doubleTap(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('EditorLayoutState', () {
    test('defaults, JSON round-trip, clamping and reset', () {
      final fresh = EditorLayoutState();
      expect(fresh.sourcesWidth, EditorLayoutState.defaultSourcesWidth);
      expect(EditorLayoutState.defaultSourcesWidth, 144);
      expect(fresh.expandedFolders, {'contents'});

      final old = EditorLayoutState.fromJson({'outlinerWidth': 250.0, 'bottomPinned': true});
      expect(old.sourcesWidth, EditorLayoutState.defaultSourcesWidth, reason: 'a file from before the splitter');
      expect(old.expandedFolders, {'contents'});

      final round = EditorLayoutState.fromJson(jsonDecode(jsonEncode(
          (EditorLayoutState()
                ..sourcesWidth = 260
                ..expandedFolders = {'contents', 'contents/props'})
              .toJson())) as Map<String, dynamic>);
      expect(round.sourcesWidth, 260);
      expect(round.expandedFolders, {'contents', 'contents/props'});

      expect(EditorLayoutState.fromJson({'sourcesWidth': 5000}).sourcesWidth, EditorLayoutState.maxSourcesWidth);
      expect(EditorLayoutState.fromJson({'sourcesWidth': 3}).sourcesWidth, EditorLayoutState.minSourcesWidth);

      final serial = round.resetSerial;
      round.resetToDefault();
      expect(round.sourcesWidth, EditorLayoutState.defaultSourcesWidth);
      expect(round.expandedFolders, {'contents'});
      expect(round.resetSerial, serial + 1);
    });
  });

  group('flattenFolderTree', () {
    test('lists roots and the children of expanded folders only, depth-first by name', () {
      const folders = ['contents', 'contents/b', 'contents/a', 'contents/a/x', 'contents/b/y', '/abs/plugin/content'];
      final rows = flattenFolderTree(folders, {'contents', 'contents/a'});
      expect(rows.map((r) => r.path), ['contents', 'contents/a', 'contents/a/x', 'contents/b', '/abs/plugin/content']);
      expect(rows.map((r) => r.depth), [0, 1, 2, 1, 0]);
      expect(rows.map((r) => r.hasChildren), [true, true, false, true, false]);
      expect(rows.map((r) => r.expanded), [true, true, false, false, false]);
    });
  });

  testWidgets('fresh layout: contents is open with its direct children, deeper rows are not built', (tester) async {
    await openBrowser(tester);
    expect(builtRows(tester),
        ['contents', 'contents/animations', 'contents/blueprints', 'contents/materials', 'contents/props']);
    expect(row('contents/props/barrels'), findsNothing);
    expect(row('contents/animations/SKM_Superhero_Female'), findsNothing);
    expect(chevron('contents'), findsOneWidget);
    expect(chevron('contents/props'), findsOneWidget);
    expect(chevron('contents/blueprints'), findsNothing, reason: 'a leaf folder has no chevron');
  });

  testWidgets('the chevron toggles a folder without selecting it; children are indented one step deeper', (tester) async {
    final vm = await openBrowser(tester);
    vm.selectedFolder = 'contents/materials';
    await tester.pump();
    await tester.tap(chevron('contents/props'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(row('contents/props/barrels'), findsOneWidget);
    expect(row('contents/props/kitchen'), findsOneWidget);
    expect(vm.selectedFolder, 'contents/materials', reason: 'a chevron click does not select');
    final parentName = tester.getTopLeft(find.descendant(of: row('contents/props'), matching: find.text('props')));
    final childName = tester.getTopLeft(find.descendant(of: row('contents/props/barrels'), matching: find.text('barrels')));
    expect(childName.dx - parentName.dx, moreOrLessEquals(EditorDensity.indentStep, epsilon: 1));
    expect(find.descendant(of: row('contents/props'), matching: find.byIcon(LucideIcons.folderOpen)), findsOneWidget);

    await tester.tap(chevron('contents/props'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(row('contents/props/barrels'), findsNothing);
  });

  testWidgets('double-click toggles; a single click selects and drives the grid', (tester) async {
    final vm = await openBrowser(tester);
    await doubleTap(tester, row('contents/props'));
    expect(vm.isFolderExpanded('contents/props'), isTrue);
    expect(row('contents/props/kitchen'), findsOneWidget);
    await doubleTap(tester, row('contents/props'));
    expect(vm.isFolderExpanded('contents/props'), isFalse);
    expect(row('contents/props/kitchen'), findsNothing);

    await tester.tap(row('contents/materials'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(vm.selectedFolder, 'contents/materials');
    expect(find.byKey(const ValueKey('asset_item_contents/materials/M_Wood.lmas')), findsOneWidget);
  });

  testWidgets('Right expands, Left collapses, Left again selects the parent', (tester) async {
    final vm = await openBrowser(tester);
    await tester.tap(row('contents/props'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(vm.selectedFolder, 'contents/props');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(vm.isFolderExpanded('contents/props'), isTrue);
    expect(row('contents/props/barrels'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(vm.isFolderExpanded('contents/props'), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(vm.selectedFolder, 'contents');
  });

  testWidgets('navigating from outside the tree opens it down to the folder', (tester) async {
    final vm = await openBrowser(tester);
    vm.selectedFolder = 'contents/props/kitchen/tin_cans';
    await tester.pump(const Duration(milliseconds: 100));
    expect(vm.isFolderExpanded('contents/props'), isTrue);
    expect(vm.isFolderExpanded('contents/props/kitchen'), isTrue);
    expect(vm.isFolderExpanded('contents/props/kitchen/tin_cans'), isFalse, reason: 'ancestors only');
    expect(row('contents/props/kitchen/tin_cans'), findsOneWidget);
    expect(tester.widget<ContentFolderRow>(find.byWidgetPredicate((w) => w is ContentFolderRow && w.path == 'contents/props/kitchen/tin_cans')).selected,
        isTrue);

    // Browse to asset on a fresh tree.
    vm.setFolderExpanded('contents/props', false);
    vm.setFolderExpanded('contents/props/kitchen', false);
    vm.selectedFolder = 'contents';
    await tester.pump();
    expect(row('contents/props/kitchen/tin_cans'), findsNothing);
    vm.browseToAsset(vm.realAssets.firstWhere((a) => a.fileName == 'SM_Can.lmas'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(row('contents/props/kitchen/tin_cans'), findsOneWidget);
  });

  test('expansion persists to editor_layout.json, follows a rename and is pruned by a delete', () async {
    final vm = newVm();
    addTearDown(vm.dispose);
    vm.toggleFolderExpanded('contents/props');
    vm.setFolderExpanded('contents/props/kitchen', true);
    expect((layoutJson(vm)['expandedFolders'] as List).toSet(), {'contents', 'contents/props', 'contents/props/kitchen'});

    final again = newVm();
    addTearDown(again.dispose);
    expect(again.isFolderExpanded('contents/props'), isTrue);
    expect(again.isFolderExpanded('contents/props/kitchen'), isTrue);

    expect(vm.renameContentFolder('contents/props', 'stuff'), 'contents/stuff');
    expect(vm.isFolderExpanded('contents/stuff'), isTrue);
    expect(vm.isFolderExpanded('contents/stuff/kitchen'), isTrue);
    expect(vm.isFolderExpanded('contents/props'), isFalse);
    expect((layoutJson(vm)['expandedFolders'] as List), isNot(contains('contents/props')));

    expect(await vm.deleteContentFolder('contents/stuff'), isTrue);
    expect(vm.layoutState.expandedFolders, {'contents'});
    expect((layoutJson(vm)['expandedFolders'] as List).toSet(), {'contents'});
  });

  testWidgets('a collapsed folder shows the aggregated source-control badge of its subtree', (tester) async {
    if ((await tester.runAsync(() => Process.run('git', ['--version'])))!.exitCode != 0) return;
    // Git work must be born in the real zone (runAsync), view model included.
    final seeded = (await tester.runAsync(() async {
      final vm = newVm();
      await vm.sourceControl.service.init(gitignoreContent: GitService.defaultGitignore, initialCommitMessage: 'init');
      File('$dir/contents/props/kitchen/tin_cans/SM_Can.lmas').writeAsBytesSync(
          LuminaAsset(assetId: 'asset_SM_Can', name: 'SM_Can_v2', type: AssetType.filamesh).toProtoBufferBytes());
      await vm.sourceControl.refresh();
      await vm.sourceControl.whenIdle;
      return vm;
    }))!;
    expect(seeded.sourceControl.folderState('contents/props'), GitFileState.modified);
    final vm = await openBrowser(tester, existing: seeded);
    await tester.pump(const Duration(milliseconds: 100));
    expect(vm.isFolderExpanded('contents/props'), isFalse);
    final badge = find.byKey(const ValueKey('sc_badge_folder:contents/props'));
    expect(badge, findsOneWidget);
    expect(find.descendant(of: badge, matching: find.text('M')), findsOneWidget);
    expect(find.byKey(const ValueKey('sc_badge_folder:contents/blueprints')), findsNothing);
  });

  testWidgets('right-clicking a tree row opens the folder menu with Import Folder Here...', (tester) async {
    await openBrowser(tester);
    await tester.tapAt(tester.getCenter(row('contents/props')), buttons: kSecondaryMouseButton);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Import Folder Here...'), findsOneWidget);
    expect(find.text('New Folder...'), findsOneWidget);
    expect(find.text('Rename...'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('dropping an asset tile onto a collapsed tree folder moves it on disk', (tester) async {
    final vm = await openBrowser(tester);
    vm.selectedFolder = 'contents';
    await tester.pump(const Duration(milliseconds: 100));
    final tile = find.byKey(const ValueKey('asset_item_contents/SM_Crate.lmas'));
    expect(tile, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(tile));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(row('contents/props')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(() async {
      await gesture.up();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(File('$dir/contents/SM_Crate.lmas').existsSync(), isFalse);
    expect(File('$dir/contents/props/SM_Crate.lmas').existsSync(), isTrue);
    expect(vm.isFolderExpanded('contents/props'), isFalse, reason: 'a drop does not expand');
  });

  testWidgets('the Sources / grid splitter resizes, clamps, persists and Reset Layout restores it', (tester) async {
    final vm = await openEditor(tester);
    expect(tester.getSize(rail()).width, moreOrLessEquals(EditorLayoutState.defaultSourcesWidth, epsilon: 1));
    expect(sourcesDragger(), findsOneWidget);

    await tester.dragFrom(tester.getCenter(sourcesDragger()), const Offset(120, 0), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(rail()).width, closeTo(EditorLayoutState.defaultSourcesWidth + 120, 25));
    expect(vm.layoutState.sourcesWidth, closeTo(EditorLayoutState.defaultSourcesWidth + 120, 25));
    expect((layoutJson(vm)['sourcesWidth'] as num).toDouble(), vm.layoutState.sourcesWidth);
    expect(vm.layoutState.outlinerWidth, EditorLayoutState.defaultOutlinerWidth, reason: 'the shell splitter did not move');

    final restored = newVm();
    addTearDown(restored.dispose);
    expect(restored.layoutState.sourcesWidth, vm.layoutState.sourcesWidth);

    await dragSplitter(tester, 800, steps: 40);
    expect(tester.getSize(rail()).width, moreOrLessEquals(EditorLayoutState.maxSourcesWidth, epsilon: 1));
    await dragSplitter(tester, -800, steps: 40);
    expect(tester.getSize(rail()).width, moreOrLessEquals(EditorLayoutState.minSourcesWidth, epsilon: 1));

    vm.toggleFolderExpanded('contents/props');
    await tester.pump(const Duration(milliseconds: 100));
    vm.commands.execute('window.resetLayout', tester.element(find.byType(MainEditorView)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(vm.layoutState.sourcesWidth, EditorLayoutState.defaultSourcesWidth);
    expect(vm.layoutState.expandedFolders, {'contents'});
    expect(tester.getSize(rail()).width, moreOrLessEquals(EditorLayoutState.defaultSourcesWidth, epsilon: 1));
    expect(row('contents/props/barrels'), findsNothing);
    expect(layoutJson(vm)['sourcesWidth'], EditorLayoutState.defaultSourcesWidth);
  });

  testWidgets('the splitter works in the unpinned Content Drawer', (tester) async {
    final vm = await openEditor(tester);
    vm.setBottomPinned(false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ContentBrowserWidget), findsNothing);
    vm.toggleContentDrawer();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ContentBrowserWidget), findsOneWidget);

    await tester.dragFrom(tester.getCenter(sourcesDragger()), const Offset(90, 0), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(rail()).width, closeTo(EditorLayoutState.defaultSourcesWidth + 90, 25));
    expect(vm.layoutState.sourcesWidth, closeTo(EditorLayoutState.defaultSourcesWidth + 90, 25));
  });

  testWidgets('with 400 folders, expanding their parent builds only the rows in view', (tester) async {
    for (var i = 0; i < 400; i++) {
      folder('contents/bulk/f${i.toString().padLeft(3, '0')}');
    }
    final vm = await openBrowser(tester, height: 600);
    vm.setFolderExpanded('contents/bulk', true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(row('contents/bulk/f000'), findsOneWidget);
    final built = builtRows(tester).length;
    expect(built, lessThan(100), reason: '$built rows built for 406 visible folders');
    expect(row('contents/bulk/f399'), findsNothing);
  });
}
