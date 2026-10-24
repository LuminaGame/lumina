import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/editor_island.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Aurora islands: every docked panel of the level workspace is a
/// rounded card (island fill, 1 px border, 12 px radius) on the window's
/// ground with 8 px gutters, under a 36 px upper-case header; stacked
/// islands keep resizing through the splitter grip; a selected tree row's
/// amber fill starts at the row's own indent.
void main() {
  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<EditorViewModel> pumpEditor(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('lumina_islands_');
    addTearDown(() => dir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'IslandGame'),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    // Pinned: the bottom panel is an island under the viewport.
    vm.layoutState.bottomPinned = true;
    vm.layoutState.bottomVisible = true;
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await settle(tester);
    return vm;
  }

  test('EditorIsland is the island fill, a 1 px border and a 12 px radius', () {
    final d = EditorIslandStyle.decoration();
    expect(d.color!.toARGB32(), EditorColors.sidebar.toARGB32());
    expect((d.border! as Border).top.color.toARGB32(), EditorColors.border.toARGB32());
    expect((d.border! as Border).top.width, 1);
    expect(d.borderRadius, BorderRadius.circular(12));
    expect(EditorIslandStyle.gap, 8);
    expect(EditorIslandStyle.headerHeight, 36);
  });

  testWidgets('Outliner, Details, viewport and the bottom panel are islands with 8 px gutters', (tester) async {
    await pumpEditor(tester);
    for (final key in ['island_outliner', 'island_details', 'island_viewport', 'island_bottom_panel']) {
      final island = find.byKey(ValueKey(key));
      expect(island, findsOneWidget, reason: '$key is an island');
      final box = tester.widget<Container>(find.descendant(of: island, matching: find.byType(Container)).first);
      expect((box.decoration! as BoxDecoration).borderRadius, BorderRadius.circular(EditorIslandStyle.radius), reason: key);
    }
    expect(find.descendant(of: find.byKey(const ValueKey('island_outliner')), matching: find.byType(OutlinerWidget)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('island_details')), matching: find.byType(DetailsWidget)), findsOneWidget);

    final outliner = tester.getRect(find.byKey(const ValueKey('island_outliner')));
    final details = tester.getRect(find.byKey(const ValueKey('island_details')));
    final viewport = tester.getRect(find.byKey(const ValueKey('island_viewport')));
    final bottom = tester.getRect(find.byKey(const ValueKey('island_bottom_panel')));
    final ground = tester.getRect(find.byType(MainEditorView));
    expect(outliner.left - ground.left, closeTo(EditorIslandStyle.gap, 0.5), reason: 'the gutter at the window edge');
    expect(viewport.left - outliner.right, closeTo(EditorIslandStyle.gap, 0.5), reason: 'the gutter beside the left column');
    expect(details.top - outliner.bottom, closeTo(EditorIslandStyle.gripGap, 0.5), reason: 'the grip gutter between stacked islands');
    expect(bottom.top - viewport.bottom, closeTo(EditorIslandStyle.gripGap, 0.5));
    expect(find.byKey(const ValueKey('island_grip')), findsNWidgets(2));
  });

  testWidgets('island headers are 36 px and upper case', (tester) async {
    await pumpEditor(tester);
    expect(find.text('WORLD OUTLINER'), findsOneWidget);
    expect(find.text('DETAILS'), findsOneWidget);
    final headers = tester.widgetList<EditorIslandHeader>(find.byType(EditorIslandHeader)).toList();
    expect(headers.length, greaterThanOrEqualTo(2));
    for (final h in find.byType(EditorIslandHeader).evaluate()) {
      expect(tester.getSize(find.byWidget(h.widget)).height, EditorIslandStyle.headerHeight);
    }
  });

  testWidgets('dragging the grip between the Outliner and the Details resizes them', (tester) async {
    final vm = await pumpEditor(tester);
    final before = tester.getRect(find.byKey(const ValueKey('island_details'))).height;
    final outliner = tester.getRect(find.byKey(const ValueKey('island_outliner')));
    final gripCentre = Offset(outliner.center.dx, outliner.bottom + EditorIslandStyle.gripGap / 2);
    await tester.dragFrom(gripCentre, const Offset(0, -80));
    await settle(tester);
    final after = tester.getRect(find.byKey(const ValueKey('island_details'))).height;
    expect(after, closeTo(before + 80, 2), reason: 'the Details island grew by the drag');
    expect(vm.layoutState.detailsHeight, closeTo(after, 2), reason: 'and the layout state remembers it');
  });

  testWidgets("a selected depth-2 outliner row's amber fill starts at its indent", (tester) async {
    final vm = await pumpEditor(tester);
    vm.spawnNewActor('PointLight');
    await settle(tester);
    final light = vm.actors.last;
    vm.createFolderFromSelection();
    await settle(tester);
    final outer = vm.actors.firstWhere((a) => a.type == 'Folder');
    vm.selectActorById(outer.id);
    vm.createFolderFromSelection();
    await settle(tester);
    final inner = vm.actors.firstWhere((a) => a.type == 'Folder' && a.parentId == outer.id);
    light.parentId = inner.id;
    vm.expandAllInOutliner();
    vm.selectActorById(light.id);
    await settle(tester);

    final row = find.byKey(ValueKey('outliner_row_${light.id}'));
    expect(row, findsOneWidget);
    // The painted fill: the decorated box inside the row's margin.
    final fill = find.descendant(
      of: row,
      matching: find.byWidgetPredicate((w) =>
          w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == EditorColors.primary),
    ).first;
    final box = tester.widget<DecoratedBox>(fill);
    final rowRect = tester.getRect(fill);
    final island = tester.getRect(find.byKey(const ValueKey('island_outliner')));
    final depth = 2;
    expect(rowRect.left - island.left, closeTo(1 + 6 + depth * EditorDensity.indentStep, 1.5),
        reason: 'the fill starts at the indent (island border + inner gutter + two steps), not at the panel edge');
    expect((box.decoration as BoxDecoration).borderRadius, BorderRadius.circular(EditorIslandStyle.rowRadius));
    final name = tester.widget<Text>(find.descendant(of: row, matching: find.text(light.name)));
    expect(name.style!.color!.toARGB32(), EditorColors.primaryForeground.toARGB32(), reason: 'dark text on the amber fill');
  });
}
