import 'dart:io';

import 'package:flutter/services.dart' show LogicalKeyboardKey;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/lumina_logo.dart';
import 'package:lumina_ui/ui/core/widgets/typed_tab_bar.dart';
import 'package:lumina_ui/ui/core/window/lumina_window.dart';
import 'package:lumina_ui/ui/core/window/window_state_store.dart';
import 'package:lumina_ui/ui/features/main_editor/shortcuts/quick_open_palette.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/menu_bar_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/fake_native_window.dart';

/// The Aurora menu bar: a 48 px row on the rail with the Prism L lockup at
/// the left, the nine menus in order, the Ctrl K command field in the
/// middle and, at the right, source control, undo, redo, the project · level
/// chip (an amber dot only while the level is unsaved), then fullscreen,
/// minimize, maximize and close. Under it, the typed workspace tab bar.
void main() {
  late FakeNativeWindow native;
  late Directory configDir;
  late LuminaWindow window;

  setUp(() {
    native = FakeNativeWindow()..install();
    configDir = Directory.systemTemp.createTempSync('lumina_menu_bar_aurora_');
    window = LuminaWindow(store: WindowStateStore(configDir: configDir));
  });
  tearDown(() {
    window.dispose();
    native.uninstall();
    if (configDir.existsSync()) configDir.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<EditorViewModel> pumpEditor(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('lumina_menu_bar_editor_');
    addTearDown(() => dir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'AuroraGame'),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: LuminaWindowScope(window: window, child: MainEditorView(viewModel: vm)),
    ));
    await settle(tester);
    return vm;
  }

  Finder inMenuBar(Finder f) => find.descendant(of: find.byType(MenuBarWidget), matching: f);

  testWidgets('48 px on the rail: lockup left, nine menus in order, the command field, the right cluster', (tester) async {
    await pumpEditor(tester);
    final bar = tester.getRect(find.byType(MenuBarWidget));
    expect(bar.height, MenuBarWidget.height);
    expect(MenuBarWidget.height, 48);
    final box = tester.widget<Container>(find.descendant(of: find.byType(MenuBarWidget), matching: find.byType(Container)).first);
    expect((box.decoration! as BoxDecoration).color!.toARGB32(), EditorColors.rail.toARGB32());

    // The lockup is the left-most thing in the row.
    final lockup = tester.getRect(inMenuBar(find.byType(LuminaLockup)));
    expect(lockup.left - bar.left, lessThan(40));
    expect(inMenuBar(find.text('LUMINA')), findsOneWidget);

    // File Edit View Build Debug Tools Plugins Window Help, left to right.
    double lastLeft = -1;
    for (final title in MenuBarWidget.menuTitles) {
      final rect = tester.getRect(inMenuBar(find.text(title)));
      expect(rect.left, greaterThan(lastLeft), reason: '$title follows the previous menu');
      expect(rect.left, greaterThan(lockup.right), reason: '$title sits after the lockup');
      lastLeft = rect.left;
    }

    // The command field in the middle, with its shortcut.
    final field = tester.getRect(find.byKey(const ValueKey('menu_bar_command_field')));
    expect(field.left, greaterThan(lastLeft));
    expect(inMenuBar(find.text('Ctrl K')), findsOneWidget);

    // Source control, undo, redo, the chip, then fullscreen, minimize, maximize, close.
    final order = [
      'menu_bar_source_control',
      'menu_bar_edit.undo',
      'menu_bar_edit.redo',
      'menu_bar_project_chip',
      'window_control_fullscreen',
      'window_control_minimize',
      'window_control_maximize',
      'window_control_close',
    ];
    double last = field.right;
    for (final key in order) {
      final rect = tester.getRect(inMenuBar(find.byKey(ValueKey(key))));
      expect(rect.left, greaterThanOrEqualTo(last), reason: '$key follows the previous control');
      last = rect.left;
    }
    expect(bar.right - tester.getRect(find.byKey(const ValueKey('window_control_close'))).right, lessThan(12));
    final drag = tester.getRect(inMenuBar(find.byKey(const ValueKey('window_title_drag_area'))));
    expect(field.left - drag.left, greaterThanOrEqualTo(MenuBarWidget.dragMargin), reason: 'an empty stretch to drag left of the field');
    expect(drag.right - field.right, greaterThanOrEqualTo(MenuBarWidget.dragMargin), reason: 'and right of it');
    expect(tester.getRect(find.byKey(const ValueKey('menu_bar_project_chip'))).width, lessThanOrEqualTo(MenuBarWidget.chipMaxWidth));
  });

  testWidgets('the chip names the project and the level, and shows the amber dot only while the level is dirty',
      (tester) async {
    final vm = await pumpEditor(tester);
    expect(inMenuBar(find.textContaining('AuroraGame')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu_bar_unsaved_dot')), findsNothing);
    vm.spawnNewActor('PointLight');
    await settle(tester);
    expect(vm.project.isDirty, isTrue);
    expect(find.byKey(const ValueKey('menu_bar_unsaved_dot')), findsOneWidget);
    final dot = tester.widget<Container>(find.byKey(const ValueKey('menu_bar_unsaved_dot')));
    expect((dot.decoration! as BoxDecoration).color!.toARGB32(), EditorColors.primary.toARGB32());
  });

  testWidgets('the command field opens the quick-open palette', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.byKey(const ValueKey('menu_bar_command_field')));
    await settle(tester);
    expect(find.byType(QuickOpenPaletteWidget), findsOneWidget);
  });

  testWidgets('Ctrl K opens the quick-open palette', (tester) async {
    await pumpEditor(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(find.byType(QuickOpenPaletteWidget), findsOneWidget);
  });

  testWidgets('the workspace strip under the menu bar is the typed tab bar with the level tab', (tester) async {
    await pumpEditor(tester);
    final strip = tester.getRect(find.byType(EditorTypedTabBar));
    expect(strip.height, EditorTypedTabBar.barHeight);
    expect(strip.top, closeTo(tester.getRect(find.byType(MenuBarWidget)).bottom, 0.5));
    expect(find.byKey(const ValueKey('workspace_tab_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace_tab_add')), findsOneWidget);
  });
}
