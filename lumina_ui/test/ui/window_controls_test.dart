import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/window/lumina_window.dart';
import 'package:lumina_ui/ui/core/window/window_controls.dart';
import 'package:lumina_ui/ui/core/window/window_state_store.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/menu_bar_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/fake_native_window.dart';

/// Lumina draws its own window chrome. The menu bar row is
/// the title bar (drag to move, double-click to maximize) with minimize,
/// maximize ⇄ restore, fullscreen and close at its right end; closing a
/// dirty level asks first.
void main() {
  late FakeNativeWindow native;
  late Directory configDir;
  late LuminaWindow window;

  setUp(() {
    native = FakeNativeWindow()..install();
    configDir = Directory.systemTemp.createTempSync('lumina_window_controls_');
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
    final dir = Directory.systemTemp.createTempSync('lumina_window_editor_');
    addTearDown(() => dir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'WindowGame'),
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

  test('the app asks for no native title bar', () {
    // main() is runLuminaEditor in lib/editor_entry.dart.
    final main = File('lib/editor_entry.dart').readAsStringSync();
    expect(main, contains('TitleBarStyle.hidden'));
    expect(main, isNot(contains('TitleBarStyle.normal')));
    // Linux: no GTK header bar either (window_manager's hidden style then
    // undecorates the GtkWindow itself).
    final runner = File('linux/runner/my_application.cc').readAsStringSync();
    expect(runner, contains('gboolean use_header_bar = FALSE;'));
  });

  test('startup hides the title bar and turns close into a request', () async {
    await window.startup(const WindowOptions(size: Size(1920, 1080), titleBarStyle: TitleBarStyle.hidden));
    expect(native.titleBarStyle, 'hidden');
    expect(native.preventClose, isTrue, reason: 'the WM close button goes through the unsaved-changes prompt');
  });

  testWidgets('the menu bar row carries minimize, maximize, fullscreen and close at its right end', (tester) async {
    await pumpEditor(tester);
    for (final key in ['window_control_minimize', 'window_control_maximize', 'window_control_fullscreen', 'window_control_close']) {
      expect(inMenuBar(find.byKey(ValueKey(key))), findsOneWidget, reason: '$key in the menu bar row');
    }
    final bar = tester.getRect(find.byType(MenuBarWidget));
    final close = tester.getRect(find.byKey(const ValueKey('window_control_close')));
    expect(bar.right - close.right, lessThan(12), reason: 'close is the right-most control');
    expect(tester.getRect(find.byKey(const ValueKey('window_control_minimize'))).left,
        lessThan(tester.getRect(find.byKey(const ValueKey('window_control_maximize'))).left));
    expect(inMenuBar(find.byKey(const ValueKey('window_title_drag_area'))), findsOneWidget);
  });

  testWidgets('the launcher header shows the window controls too', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = LauncherViewModel(configDir: configDir);
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: LuminaWindowScope(window: window, child: LauncherView(viewModel: vm)),
    ));
    await settle(tester);
    for (final key in ['window_control_minimize', 'window_control_maximize', 'window_control_close']) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('launcher_title_drag_area')), findsOneWidget);
  });

  testWidgets('maximize maximizes and flips to restore; double-clicking the title bar toggles it', (tester) async {
    await pumpEditor(tester);
    expect(find.byKey(const ValueKey('window_control_maximize_icon')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('window_control_maximize')));
    await settle(tester);
    expect(native.maximized, isTrue);
    expect(window.isMaximized, isTrue);
    expect(find.byKey(const ValueKey('window_control_restore_icon')), findsOneWidget, reason: 'the icon follows the window');

    await tester.tap(find.byKey(const ValueKey('window_control_maximize')));
    await settle(tester);
    expect(native.maximized, isFalse);
    expect(find.byKey(const ValueKey('window_control_maximize_icon')), findsOneWidget);

    final drag = find.byKey(const ValueKey('window_title_drag_area'));
    await tester.tap(drag);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(drag);
    await settle(tester, frames: 30);
    expect(native.maximized, isTrue, reason: 'double-click on the title bar maximizes');
    expect(find.byKey(const ValueKey('window_control_restore_icon')), findsOneWidget);

    await tester.tap(drag);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(drag);
    await settle(tester, frames: 30);
    expect(native.maximized, isFalse, reason: 'and double-click again restores');
  });

  testWidgets('the icon reports the real state when the WM ignores maximize', (tester) async {
    native.honoursMaximize = false;
    await pumpEditor(tester);
    await tester.tap(find.byKey(const ValueKey('window_control_maximize')));
    await settle(tester);
    expect(window.isMaximized, isFalse);
    expect(find.byKey(const ValueKey('window_control_maximize_icon')), findsOneWidget);
    // …and a maximize the WM does on its own (a tiling layout) shows up.
    native.maximized = true;
    await native.emit('maximize');
    await settle(tester);
    expect(find.byKey(const ValueKey('window_control_restore_icon')), findsOneWidget);
  });

  testWidgets('the resize border grips every edge and corner, and steps aside while maximized', (tester) async {
    // The border is Linux's (an undecorated GTK window has no WM handles).
    LuminaWindow.debugOsOverride = 'linux';
    addTearDown(() => LuminaWindow.debugOsOverride = null);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: const SizedBox.expand(),
      builder: (context, child) => LuminaWindowFrame(window: window, child: child!),
    ));
    await settle(tester);
    for (final edge in ResizeEdge.values) {
      final grip = find.byKey(ValueKey('window_resize_${edge.name}'));
      expect(grip, findsOneWidget, reason: '${edge.name} grip');
      native.calls.clear();
      await tester.drag(grip, const Offset(10, 10));
      await settle(tester, frames: 2);
      final call = native.calls.where((c) => c.method == 'startResizing').single;
      expect((call.arguments as Map)['resizeEdge'], edge.name);
    }
    await window.toggleMaximize();
    await settle(tester);
    expect(find.byKey(const ValueKey('window_resize_top')), findsNothing, reason: 'a maximized window has no border to drag');
  });

  testWidgets('dragging the title bar moves the window; minimize minimizes', (tester) async {
    await pumpEditor(tester);
    await tester.drag(find.byKey(const ValueKey('window_title_drag_area')), const Offset(40, 20));
    await settle(tester);
    expect(native.methods, contains('startDragging'));
    await tester.tap(find.byKey(const ValueKey('window_control_minimize')));
    await settle(tester);
    expect(native.minimized, isTrue);
  });

  testWidgets('F11, the fullscreen button and View ▸ Fullscreen toggle fullscreen', (tester) async {
    final vm = await pumpEditor(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await settle(tester);
    expect(native.fullScreen, isTrue);
    expect(window.isFullScreen, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    await settle(tester);
    expect(native.fullScreen, isFalse);

    await tester.tap(find.byKey(const ValueKey('window_control_fullscreen')));
    await settle(tester);
    expect(native.fullScreen, isTrue);

    final cmd = vm.commands.byId('view.fullscreen');
    expect(cmd, isNotNull);
    expect(cmd!.shortcutLabel, 'F11');
    cmd.execute(tester.element(find.byType(MenuBarWidget)));
    await settle(tester);
    expect(native.fullScreen, isFalse);
  });

  testWidgets('close on a clean level quits at once', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.byKey(const ValueKey('window_control_close')));
    await settle(tester);
    expect(find.byKey(const ValueKey('quit_unsaved_prompt')), findsNothing);
    expect(native.destroyed, isTrue);
  });

  testWidgets('close with a dirty level asks, and only quits after Save or Don\'t Save', (tester) async {
    final vm = await pumpEditor(tester);
    vm.spawnNewActor('PointLight');
    await settle(tester);
    expect(vm.project.isDirty, isTrue);

    // The close button…
    await tester.tap(find.byKey(const ValueKey('window_control_close')));
    await settle(tester);
    expect(find.byKey(const ValueKey('quit_unsaved_prompt')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quit_unsaved_cancel')));
    await settle(tester, frames: 40);
    expect(find.byKey(const ValueKey('quit_unsaved_prompt')), findsNothing);
    expect(native.destroyed, isFalse, reason: 'Cancel keeps the editor open');

    // …and the window manager's close (Alt+F4, taskbar) take the same path.
    await native.emit('close');
    await settle(tester);
    expect(find.byKey(const ValueKey('quit_unsaved_prompt')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quit_unsaved_dont_save')));
    await settle(tester);
    expect(native.destroyed, isTrue, reason: 'Don\'t Save quits');
  });

  testWidgets('Save in the quit prompt writes the level, then quits', (tester) async {
    final vm = await pumpEditor(tester);
    vm.spawnNewActor('PointLight');
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('window_control_close')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('quit_unsaved_save')));
    for (var i = 0; i < 100 && !native.destroyed; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(vm.project.isDirty, isFalse, reason: 'the level was saved');
    expect(native.destroyed, isTrue);
  });
}
