import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_layout_state.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';

/// The Details inspector docked under the Outliner in one
/// resizable left column, a resizable bottom panel that is open by default,
/// and the pin / Content Drawer flow — all persisted to the real
/// `<projectDir>/.lumina/editor_layout.json`.
void main() {
  late Directory root;
  late EditorViewModel viewModel;

  File layoutFile() => File('${viewModel.projectDirPath}/.lumina/editor_layout.json');
  Map<String, dynamic> layoutJson() => jsonDecode(layoutFile().readAsStringSync()) as Map<String, dynamic>;

  setUp(() {
    root = Directory.systemTemp.createTempSync('editor_shell_dock_');
    File('${root.path}/my_project.lmproject').writeAsStringSync('{}');
    viewModel = EditorViewModel(projectLocation: root.path, enableTimers: false, autoInitAssets: false);
  });

  tearDown(() {
    viewModel.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> pumpEditor(WidgetTester tester) async {
    // A desktop-sized window: the default 800×600 test window leaves the
    // default panes little room to move.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: MainEditorView(viewModel: viewModel),
    ));
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// The vertical splitter inside the left column (Outliner / Details) or the
  /// centre column (viewport / bottom panel), told apart by where it sits.
  Offset draggerCenter(WidgetTester tester, {required bool inLeftColumn}) {
    final outlinerRight = tester.getBottomRight(find.byType(OutlinerWidget)).dx;
    final centers = find
        .byType(VerticalResizableDragger)
        .evaluate()
        .map((e) => tester.getCenter(find.byElementPredicate((c) => identical(c, e))))
        .where((c) => inLeftColumn ? c.dx <= outlinerRight + 1 : c.dx > outlinerRight + 1)
        .toList();
    expect(centers, hasLength(1), reason: 'one vertical splitter per column');
    return centers.single;
  }

  testWidgets('Details is docked under the Outliner on the left; no right column', (tester) async {
    await pumpEditor(tester);

    final outliner = tester.getRect(find.byType(OutlinerWidget));
    final details = tester.getRect(find.byType(DetailsWidget));
    final viewport = tester.getRect(find.byType(ViewportWidget));

    expect(details.left, moreOrLessEquals(outliner.left, epsilon: 1), reason: 'same column');
    expect(details.top, greaterThanOrEqualTo(outliner.bottom), reason: 'Details sits below the Outliner');
    expect(details.right, lessThanOrEqualTo(viewport.left + 1), reason: 'Details is left of the viewport');
    expect(outliner.right, lessThanOrEqualTo(viewport.left + 1));
    // Nothing to the right of the viewport: it reaches the window's edge.
    expect(viewport.right, moreOrLessEquals(tester.view.physicalSize.width, epsilon: 1));
    expect(details.height, moreOrLessEquals(EditorLayoutState.defaultDetailsHeight, epsilon: 1));
    expect(outliner.width, moreOrLessEquals(EditorLayoutState.defaultOutlinerWidth, epsilon: 1));
  });

  testWidgets('Bottom panel is open and pinned by default; no drawer button', (tester) async {
    await pumpEditor(tester);

    expect(viewModel.layoutState.bottomVisible, isTrue);
    expect(viewModel.layoutState.bottomPinned, isTrue);
    expect(find.byType(ContentBrowserWidget), findsOneWidget);
    final pin = find.byKey(const ValueKey('bottom_panel_pin'));
    expect(pin, findsOneWidget);
    expect(find.descendant(of: pin, matching: find.byIcon(LucideIcons.pin)), findsOneWidget);
    expect(find.byKey(const ValueKey('status_bar_content_drawer')), findsNothing);
    // The pin sits at the right end of the panel's tab bar.
    final pinCenter = tester.getCenter(pin);
    final browser = tester.getRect(find.byType(ContentBrowserWidget));
    expect(pinCenter.dx, greaterThan(browser.right - 40));
    expect(pinCenter.dy, lessThan(browser.top));
  });

  testWidgets('Unpin closes the panel into a Content Drawer that the status bar button opens; pin docks it again', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byKey(const ValueKey('bottom_panel_pin')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(viewModel.layoutState.bottomPinned, isFalse);
    expect(viewModel.layoutState.bottomVisible, isFalse);
    expect(find.byType(ContentBrowserWidget), findsNothing, reason: 'the drawer closed');
    expect(find.byKey(const ValueKey('bottom_panel_pin')), findsNothing);
    final drawerButton = find.byKey(const ValueKey('status_bar_content_drawer'));
    expect(drawerButton, findsOneWidget);
    expect(find.descendant(of: drawerButton, matching: find.byIcon(LucideIcons.folder)), findsOneWidget);
    expect(layoutJson()['bottomPinned'], isFalse);
    expect(layoutJson()['bottomVisible'], isFalse);
    // The button is at the left end of the status bar, below the viewport.
    final buttonCenter = tester.getCenter(drawerButton);
    expect(buttonCenter.dx, lessThan(60));
    expect(buttonCenter.dy, greaterThan(tester.getRect(find.byType(ViewportWidget)).bottom));

    await tester.tap(drawerButton);
    await tester.pump(const Duration(milliseconds: 300));
    expect(viewModel.layoutState.bottomVisible, isTrue);
    expect(find.byType(ContentBrowserWidget), findsOneWidget, reason: 'the drawer opened');
    expect(find.descendant(of: drawerButton, matching: find.byIcon(LucideIcons.folderOpen)), findsOneWidget);
    expect(layoutJson()['bottomVisible'], isTrue);
    // Open but unpinned: the pin button shows the unpinned glyph.
    expect(find.descendant(of: find.byKey(const ValueKey('bottom_panel_pin')), matching: find.byIcon(LucideIcons.pinOff)), findsOneWidget);

    await tester.tap(drawerButton);
    await tester.pump(const Duration(milliseconds: 300));
    expect(viewModel.layoutState.bottomVisible, isFalse);
    expect(find.byType(ContentBrowserWidget), findsNothing);

    // Open it and pin it back: docked, the drawer button goes away.
    await tester.tap(drawerButton);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('bottom_panel_pin')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(viewModel.layoutState.bottomPinned, isTrue);
    expect(viewModel.layoutState.bottomVisible, isTrue);
    expect(find.byKey(const ValueKey('status_bar_content_drawer')), findsNothing);
    expect(find.byType(ContentBrowserWidget), findsOneWidget);
    expect(layoutJson()['bottomPinned'], isTrue);

    // A fresh view model on the same project restores the pinned, open panel.
    final restored = EditorViewModel(projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    addTearDown(restored.dispose);
    expect(restored.layoutState.bottomPinned, isTrue);
    expect(restored.layoutState.bottomVisible, isTrue);
  });

  testWidgets('Dragging the three splitters persists the sizes and a fresh view model restores them', (tester) async {
    await pumpEditor(tester);
    final detailsBefore = tester.getRect(find.byType(DetailsWidget)).height;
    final columnBefore = tester.getRect(find.byType(OutlinerWidget)).width;
    final bottomBefore = tester.getRect(find.byType(ContentBrowserWidget)).bottom - tester.getRect(find.byType(ViewportWidget)).bottom;

    // Outliner / Details splitter, 60 px up: Details grows.
    await tester.dragFrom(draggerCenter(tester, inLeftColumn: true), const Offset(0, -60), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(viewModel.layoutState.detailsHeight, closeTo(detailsBefore + 60, 25));
    expect((layoutJson()['detailsHeight'] as num).toDouble(), closeTo(detailsBefore + 60, 25));
    expect(tester.getRect(find.byType(DetailsWidget)).height, closeTo(detailsBefore + 60, 25));

    // Left column / centre splitter, 80 px right: the column widens.
    await tester.dragFrom(tester.getCenter(find.byElementPredicate((e) =>
        // The workspace splitter, not the Content Browser's own.
        e.widget is HorizontalResizableDragger && e.findAncestorWidgetOfExactType<ContentBrowserWidget>() == null)), const Offset(80, 0), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(viewModel.layoutState.outlinerWidth, closeTo(columnBefore + 80, 25));
    expect((layoutJson()['outlinerWidth'] as num).toDouble(), closeTo(columnBefore + 80, 25));
    expect(tester.getRect(find.byType(OutlinerWidget)).width, closeTo(columnBefore + 80, 25));

    // Viewport / bottom panel splitter, 50 px up: the bottom panel grows.
    await tester.dragFrom(draggerCenter(tester, inLeftColumn: false), const Offset(0, -50), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(viewModel.layoutState.bottomHeight, closeTo(bottomBefore + 50, 25));
    expect((layoutJson()['bottomHeight'] as num).toDouble(), closeTo(bottomBefore + 50, 25));

    final restored = EditorViewModel(projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    addTearDown(restored.dispose);
    expect(restored.layoutState.detailsHeight, viewModel.layoutState.detailsHeight);
    expect(restored.layoutState.outlinerWidth, viewModel.layoutState.outlinerWidth);
    expect(restored.layoutState.bottomHeight, viewModel.layoutState.bottomHeight);
  });

  testWidgets('An old three-column editor_layout.json loads under the new defaults', (tester) async {
    final file = File('${viewModel.projectDirPath}/.lumina/editor_layout.json');
    file.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode({
      'outlinerWidth': 250.0,
      'detailsWidth': 260.0,
      'bottomHeight': 200.0,
      'outlinerVisible': true,
      'detailsVisible': true,
      'bottomVisible': false,
      'activeBottomTab': 1,
    }));

    final migrated = EditorViewModel(projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    addTearDown(migrated.dispose);
    expect(migrated.layoutState.outlinerWidth, 250.0, reason: 'the left column keeps its width');
    expect(migrated.layoutState.bottomHeight, 200.0);
    expect(migrated.layoutState.detailsHeight, EditorLayoutState.defaultDetailsHeight, reason: 'detailsWidth is ignored');
    expect(migrated.layoutState.bottomVisible, isTrue, reason: 'a pre-drawer file comes up open');
    expect(migrated.layoutState.bottomPinned, isTrue, reason: '…and pinned');
    expect(migrated.layoutState.activeBottomTab, 1);
    expect(migrated.layoutState.toJson().containsKey('detailsWidth'), isFalse);
    expect(migrated.layoutState.toJson()['bottomPinned'], isTrue);
  });

  testWidgets('Window menu hides Details alone, then both, and Reset Layout restores everything', (tester) async {
    await pumpEditor(tester);
    final ctx = tester.element(find.byType(MainEditorView));
    final workspaceLeft = tester.getRect(find.byType(OutlinerWidget)).left;

    viewModel.commands.execute('window.toggleDetails', ctx);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(DetailsWidget), findsNothing);
    expect(find.byType(OutlinerWidget), findsOneWidget);
    expect(tester.getRect(find.byType(OutlinerWidget)).bottom, moreOrLessEquals(tester.getRect(find.byType(ContentBrowserWidget)).bottom, epsilon: 1),
        reason: 'the Outliner fills the whole left column, down to the workspace bottom');
    expect(layoutJson()['detailsVisible'], isFalse);

    viewModel.commands.execute('window.toggleOutliner', ctx);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(OutlinerWidget), findsNothing);
    expect(find.byType(DetailsWidget), findsNothing);
    expect(tester.getRect(find.byType(ViewportWidget)).left, moreOrLessEquals(workspaceLeft, epsilon: 1), reason: 'the left column is gone');

    // Unpin and shrink a pane so Reset has something to undo.
    viewModel.setBottomPinned(false);
    viewModel.setPaneSize(bottomHeight: 300, outlinerWidth: 400, detailsHeight: 200);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ContentBrowserWidget), findsNothing);

    viewModel.commands.execute('window.resetLayout', ctx);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(OutlinerWidget), findsOneWidget);
    expect(find.byType(DetailsWidget), findsOneWidget);
    expect(find.byType(ContentBrowserWidget), findsOneWidget);
    expect(viewModel.layoutState.bottomPinned, isTrue);
    expect(viewModel.layoutState.bottomVisible, isTrue);
    expect(viewModel.layoutState.outlinerWidth, EditorLayoutState.defaultOutlinerWidth);
    expect(viewModel.layoutState.detailsHeight, EditorLayoutState.defaultDetailsHeight);
    expect(viewModel.layoutState.bottomHeight, EditorLayoutState.defaultBottomHeight);
    expect(tester.getRect(find.byType(OutlinerWidget)).width, moreOrLessEquals(EditorLayoutState.defaultOutlinerWidth, epsilon: 1));
    expect(tester.getRect(find.byType(DetailsWidget)).height, moreOrLessEquals(EditorLayoutState.defaultDetailsHeight, epsilon: 1));
    final json = layoutJson();
    expect(json['bottomPinned'], isTrue);
    expect(json['outlinerWidth'], EditorLayoutState.defaultOutlinerWidth);
    expect(json.containsKey('detailsWidth'), isFalse);
  });
}
