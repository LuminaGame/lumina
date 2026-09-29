import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_layout_state.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// The Window menu's Outliner, Details, Bottom Panel and
/// Output Log rows are checkbox rows whose check follows the layout.
void main() {
  late Directory root;
  late LuminaProject project;
  late EditorViewModel vm;

  EditorViewModel open() =>
      EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_window_checks_');
    Directory('${root.path}/ChecksGame/contents/levels').createSync(recursive: true);
    project = const LuminaProject(projectName: 'ChecksGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('${root.path}/ChecksGame/ChecksGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = open();
  });

  tearDown(() async {
    vm.dispose();
    await deleteTempProject(root);
  });

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Finder rowFinder(String id) => find.byKey(ValueKey('menu_check_window.$id'));
  bool checked(WidgetTester tester, String id) => tester.widget<MenuCheckbox>(rowFinder(id)).value;

  Future<void> openWindow(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(Menubar), matching: find.text('Window')));
    await settle(tester);
  }

  Future<void> closeMenu(WidgetTester tester) async {
    await tester.tapAt(const Offset(1000, 300));
    await settle(tester);
  }

  /// Clicks row [id] (the menu closes, as every menu item does).
  Future<void> click(WidgetTester tester, String id, String label) async {
    await tester.tap(find.descendant(of: rowFinder(id), matching: find.text(label)));
    await settle(tester);
  }

  Future<Map<String, bool>> readChecks(WidgetTester tester) async {
    await openWindow(tester);
    final out = {
      for (final id in ['toggleOutliner', 'toggleDetails', 'toggleBottomPanel', 'showOutputLog']) id: checked(tester, id),
    };
    await closeMenu(tester);
    return out;
  }

  testWidgets('default layout: three panels checked, Output Log unchecked, Marketplace and Reset Layout plain', (tester) async {
    await pumpEditor(tester);
    await openWindow(tester);
    expect(checked(tester, 'toggleOutliner'), isTrue);
    expect(checked(tester, 'toggleDetails'), isTrue);
    expect(checked(tester, 'toggleBottomPanel'), isTrue);
    expect(checked(tester, 'showOutputLog'), isFalse, reason: 'the Content Browser tab is showing');
    expect(rowFinder('marketplace'), findsNothing);
    expect(rowFinder('resetLayout'), findsNothing);
    expect(find.widgetWithText(MenuButton, 'Marketplace'), findsOneWidget);
    expect(find.widgetWithText(MenuButton, 'Reset Layout'), findsOneWidget);
    // The shortcut label stays the trailing text of a checkbox row.
    for (final id in ['toggleOutliner', 'toggleDetails', 'toggleBottomPanel', 'showOutputLog']) {
      final label = vm.commands.byId('window.$id')!.shortcutLabel;
      if (label.isNotEmpty) expect(find.descendant(of: rowFinder(id), matching: find.text(label)), findsOneWidget);
    }
    await closeMenu(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('clicking Outliner, Details and Bottom Panel toggles each and its check', (tester) async {
    await pumpEditor(tester);
    for (final (id, label, widget) in [
      ('toggleOutliner', 'Outliner', find.byType(OutlinerWidget)),
      ('toggleDetails', 'Details', find.byType(DetailsWidget)),
      ('toggleBottomPanel', 'Bottom Panel', find.byKey(const ValueKey('bottom_panel_pin'))),
    ]) {
      expect(widget, findsOneWidget, reason: '$label is open');
      await openWindow(tester);
      await click(tester, id, label);
      expect(widget, findsNothing, reason: '$label closed from the menu');
      expect((await readChecks(tester))[id], isFalse);
      await openWindow(tester);
      await click(tester, id, label);
      expect(widget, findsOneWidget, reason: '$label reopened from the menu');
      expect((await readChecks(tester))[id], isTrue);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Output Log shows the panel on its tab; the Content Browser tab or browseToAsset un-checks it', (tester) async {
    await pumpEditor(tester);
    await openWindow(tester);
    await click(tester, 'toggleBottomPanel', 'Bottom Panel');
    expect(vm.layoutState.bottomVisible, isFalse);

    await openWindow(tester);
    await click(tester, 'showOutputLog', 'Output Log');
    expect(vm.layoutState.bottomVisible, isTrue);
    expect(vm.layoutState.activeBottomTab, EditorLayoutState.outputLogTab);
    var checks = await readChecks(tester);
    expect(checks['showOutputLog'], isTrue);
    expect(checks['toggleBottomPanel'], isTrue);

    // A click while it shows changes nothing (the tab entry focuses it).
    await openWindow(tester);
    await click(tester, 'showOutputLog', 'Output Log');
    expect(vm.layoutState.isOutputLogOpen, isTrue);

    await tester.tap(find.byKey(const ValueKey('bottom_tab_0')));
    await settle(tester);
    checks = await readChecks(tester);
    expect(checks['showOutputLog'], isFalse, reason: 'the Content Browser tab is showing');
    expect(checks['toggleBottomPanel'], isTrue);

    await openWindow(tester);
    await click(tester, 'showOutputLog', 'Output Log');
    expect((await readChecks(tester))['showOutputLog'], isTrue);
    final folder = Directory('${vm.projectDirPath}/contents/meshes')..createSync(recursive: true);
    File('${folder.path}/SM_Crate.lmas').writeAsBytesSync(const [0]);
    vm.browseToAsset(const RealAssetInfo(fileName: 'SM_Crate.lmas', relativePath: 'contents/meshes/SM_Crate.lmas', type: AssetType.filamesh, bytes: 1));
    await settle(tester);
    expect((await readChecks(tester))['showOutputLog'], isFalse, reason: 'browseToAsset shows the Content Browser tab');
    await drainRealIo(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets("closing the bottom panel with its own control un-checks it", (tester) async {
    await pumpEditor(tester);
    // The bottom panel's own control: unpin, which turns it into a closed
    // Content Drawer (Outliner and Details have no close control of their own).
    await tester.tap(find.byKey(const ValueKey('bottom_panel_pin')));
    await settle(tester);
    expect(vm.layoutState.bottomVisible, isFalse);
    expect((await readChecks(tester))['toggleBottomPanel'], isFalse);
    // The status bar's Content Drawer button opens it again.
    await tester.tap(find.byKey(const ValueKey('status_bar_content_drawer')));
    await settle(tester);
    expect((await readChecks(tester))['toggleBottomPanel'], isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a state change while the menu is open updates its checks', (tester) async {
    await pumpEditor(tester);
    await openWindow(tester);
    expect(checked(tester, 'toggleDetails'), isTrue);
    vm.commands.execute('window.toggleDetails');
    await settle(tester);
    expect(rowFinder('toggleDetails'), findsOneWidget, reason: 'the menu is still open');
    expect(checked(tester, 'toggleDetails'), isFalse);
    vm.commands.execute('window.showOutputLog');
    await settle(tester);
    expect(checked(tester, 'showOutputLog'), isTrue);
    vm.commands.execute('window.toggleDetails');
    await settle(tester);
    expect(checked(tester, 'toggleDetails'), isTrue);
    await closeMenu(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Reset Layout after hiding all three checks them again', (tester) async {
    await pumpEditor(tester);
    for (final (id, label) in [('toggleOutliner', 'Outliner'), ('toggleDetails', 'Details'), ('toggleBottomPanel', 'Bottom Panel')]) {
      await openWindow(tester);
      await click(tester, id, label);
    }
    var checks = await readChecks(tester);
    expect(checks['toggleOutliner'], isFalse);
    expect(checks['toggleDetails'], isFalse);
    expect(checks['toggleBottomPanel'], isFalse);

    await openWindow(tester);
    await tester.tap(find.widgetWithText(MenuButton, 'Reset Layout'));
    await settle(tester);
    checks = await readChecks(tester);
    expect(checks['toggleOutliner'], isTrue);
    expect(checks['toggleDetails'], isTrue);
    expect(checks['toggleBottomPanel'], isTrue);
    expect(checks['showOutputLog'], isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a layout saved with Details hidden loads with Details unchecked', (tester) async {
    vm.commands.execute('window.toggleDetails');
    expect(jsonDecode(File('${vm.projectDirPath}/.lumina/editor_layout.json').readAsStringSync())['detailsVisible'], isFalse);
    vm.dispose();
    vm = open();
    await pumpEditor(tester);
    final checks = await readChecks(tester);
    expect(checks['toggleDetails'], isFalse);
    expect(checks['toggleOutliner'], isTrue);
    expect(checks['toggleBottomPanel'], isTrue);
    expect(find.byType(DetailsWidget), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
