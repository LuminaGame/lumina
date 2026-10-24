import 'dart:io';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/viewport_pills.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/level_viewport_chrome.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/toolbar_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The level viewport's Aurora chrome: the pill row top-left (camera, view
/// mode, the snaps, grid, World/Local, Show) with the tool column under it,
/// the stats pill top-right; the level toolbar keeps Play, Blueprints,
/// plugin slots and Quality. Q/W/E/R still switch the column's tool.
void main() {
  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<EditorViewModel> pumpEditor(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('lumina_viewport_pills_');
    addTearDown(() => dir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'PillGame'),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await settle(tester);
    return vm;
  }

  testWidgets('the pill row sits top-left over the viewport with the tool column under it', (tester) async {
    await pumpEditor(tester);
    final viewport = tester.getRect(find.byType(ViewportWidget));
    final camera = tester.getRect(find.byKey(const ValueKey('viewport_pill_camera')));
    expect(camera.left - viewport.left, closeTo(ViewportPillStyle.inset, 1));
    expect(camera.top - viewport.top, closeTo(ViewportPillStyle.inset, 1));
    expect(camera.height, ViewportPillStyle.height);
    // The pills follow in reading order (the row wraps in a narrow view).
    var last = camera;
    var lowest = camera.bottom;
    for (final key in ['viewport_pill_view_mode', 'toggle_translate_snap', 'toggle_rotate_snap', 'toggle_grid_snap', 'viewport_pill_space', 'viewport_pill_show']) {
      final rect = tester.getRect(find.byKey(ValueKey(key)));
      final follows = rect.top > last.top + 0.5 || (rect.top - last.top).abs() <= 0.5 && rect.left > last.left;
      expect(follows, isTrue, reason: '$key follows the previous pill');
      expect(rect.height, ViewportPillStyle.height, reason: key);
      last = rect;
      if (rect.bottom > lowest) lowest = rect.bottom;
    }
    final column = tester.getRect(find.byKey(const ValueKey('viewport_tool_column')));
    expect(column.left, closeTo(camera.left, 0.5));
    expect(column.top, greaterThan(lowest), reason: 'the tool column sits under the pill row');
    expect(tester.getSize(find.byKey(const ValueKey('viewport_tool_select'))).width, ViewportPillStyle.toolButton);
    final stats = tester.getRect(find.byKey(const ValueKey('viewport_stats_pill')));
    expect(stats.top, closeTo(camera.top, 0.5));
    expect(stats.left, greaterThan(viewport.left + viewport.width * 0.4), reason: 'stats in the right cluster');
    expect(stats.right, lessThan(viewport.right));
    expect(find.textContaining('tris ·'), findsOneWidget);
  });

  testWidgets('the level toolbar keeps Play, Blueprints and Quality but no tools, snaps or view menus', (tester) async {
    await pumpEditor(tester);
    final toolbar = find.byType(ToolbarWidget);
    expect(find.descendant(of: toolbar, matching: find.byKey(const ValueKey('toolbar_play'))), findsOneWidget);
    expect(find.descendant(of: toolbar, matching: find.byKey(const ValueKey('toolbar_blueprints'))), findsOneWidget);
    expect(find.descendant(of: toolbar, matching: find.textContaining('Quality: ')), findsOneWidget);
    expect(find.descendant(of: toolbar, matching: find.byKey(const Key('toggle_translate_snap'))), findsNothing);
    expect(find.descendant(of: toolbar, matching: find.byIcon(LucideIcons.mousePointer)), findsNothing);
    expect(find.descendant(of: find.byType(ViewportWidget), matching: find.byKey(const Key('toggle_translate_snap'))), findsOneWidget);
  });

  testWidgets('the tool column follows the active tool, by click and by Q/W/E/R', (tester) async {
    final vm = await pumpEditor(tester);
    await tester.tap(find.byKey(const ValueKey('viewport_tool_rotate')));
    await settle(tester);
    expect(vm.activeTool, 'rotate');
    BoxDecoration fill(String id) =>
        tester.widget<Container>(find.descendant(of: find.byKey(ValueKey('viewport_tool_$id')), matching: find.byType(Container)).first).decoration!
            as BoxDecoration;
    expect(fill('rotate').color!.toARGB32(), EditorColors.primary.toARGB32(), reason: 'the active tool is amber');
    expect(fill('select').color, Colors.transparent);
    await tester.tap(find.byType(ViewportWidget), warnIfMissed: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await settle(tester);
    expect(vm.activeTool, 'translate');
    expect(fill('translate').color!.toARGB32(), EditorColors.primary.toARGB32());
  });

  testWidgets('camera, view mode, World/Local and Show work from their pills', (tester) async {
    final vm = await pumpEditor(tester);
    await tester.tap(find.byKey(const ValueKey('viewport_pill_camera')));
    await settle(tester, frames: 40);
    await tester.tap(find.text('Top').last);
    await settle(tester, frames: 40);
    expect(vm.cameraMode, 'Top');

    await tester.tap(find.byKey(const ValueKey('viewport_pill_view_mode')));
    await settle(tester, frames: 40);
    await tester.tap(find.text('Wireframe').last);
    await settle(tester, frames: 40);
    expect(vm.viewMode, 'Wireframe');

    expect(vm.gizmoSpace, 'world');
    await tester.tap(find.byKey(const ValueKey('viewport_pill_space')));
    await settle(tester, frames: 40);
    expect(vm.gizmoSpace, 'local');
    expect(find.descendant(of: find.byKey(const ValueKey('viewport_pill_space')), matching: find.text('Local')), findsOneWidget);

    final before = LevelViewportPills.showFlags.where((f) => vm.showFlags[f] == true).length;
    expect(find.text('Show · $before'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('viewport_pill_show')));
    await settle(tester, frames: 40);
    final wasOn = vm.showFlags['Collision'] == true;
    await tester.tap(find.text('Collision').last);
    await settle(tester, frames: 40);
    expect(vm.showFlags['Collision'] == true, !wasOn);
    expect(find.text('Show · ${before + (wasOn ? -1 : 1)}'), findsOneWidget);
  });

  test('the stats pill reads triangles and fps', () {
    expect(LevelViewportStatsPill.format(5300, 60), '5.3k tris · 60 fps');
    expect(LevelViewportStatsPill.format(182400, 119.6), '182k tris · 120 fps');
    expect(LevelViewportStatsPill.format(2400000, 30), '2.4M tris · 30 fps');
    expect(LevelViewportStatsPill.format(840, 59.9), '840 tris · 60 fps');
  });
}
