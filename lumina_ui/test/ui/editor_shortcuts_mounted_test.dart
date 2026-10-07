import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryMouseButton, PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The editor shell's shortcut layer was never
/// mounted, so no key did anything in the real editor. These tests boot the
/// real `MainEditorView`, not the scope around a bare toolbar.
void main() {
  // The editor viewport's tickers never let pumpAndSettle settle.
  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<EditorViewModel> pumpEditor(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('lumina_shortcuts_mounted_');
    addTearDown(() => dir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'ShortcutGame'),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await settle(tester);
    return vm;
  }

  Future<void> chord(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester, frames: 3);
  }

  Future<void> clickViewport(WidgetTester tester) async {
    await tester.tapAt(tester.getCenter(find.byType(ViewportWidget)), kind: PointerDeviceKind.mouse);
    await settle(tester, frames: 3);
  }

  EditorActorNode spawnLight(EditorViewModel vm) {
    vm.spawnNewActor('PointLight');
    return vm.actors.last;
  }

  final searchField = find.byWidgetPredicate(
      (w) => w is TextField && w.placeholder is Text && (w.placeholder as Text).data == 'Search actors...');

  testWidgets('Q/W/E/R switch the transform tool in the real editor', (tester) async {
    final vm = await pumpEditor(tester);
    expect(vm.activeTool, 'select');
    for (final (key, tool) in [
      (LogicalKeyboardKey.keyW, 'translate'),
      (LogicalKeyboardKey.keyE, 'rotate'),
      (LogicalKeyboardKey.keyR, 'scale'),
      (LogicalKeyboardKey.keyQ, 'select'),
    ]) {
      await tester.sendKeyEvent(key);
      await settle(tester, frames: 2);
      expect(vm.activeTool, tool, reason: '${key.keyLabel} switches to $tool');
    }
  });

  testWidgets('after a click in the viewport, W/E switch tools and Ctrl+D / Delete reach the level', (tester) async {
    final vm = await pumpEditor(tester);
    await clickViewport(tester);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<ViewportWidget>(), isNotNull,
        reason: 'a click in the viewport gives it the keyboard');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await settle(tester, frames: 2);
    expect(vm.activeTool, 'translate', reason: 'without the right mouse button W is the Move tool, not a camera step');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await settle(tester, frames: 2);
    expect(vm.activeTool, 'rotate');

    final actor = spawnLight(vm);
    vm.selectActor(actor);
    await settle(tester, frames: 2);
    final count = vm.actors.length;
    await chord(tester, LogicalKeyboardKey.keyD);
    expect(vm.actors.length, count + 1, reason: 'Ctrl+D duplicates the selection');
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester, frames: 2);
    expect(vm.actors.length, count, reason: 'Delete deletes the selection');
    await chord(tester, LogicalKeyboardKey.keyZ);
    expect(vm.actors.length, count + 1, reason: 'Ctrl+Z undoes the delete');
  });

  testWidgets('during right-mouse fly the viewport keeps W; after it W is the Move tool again', (tester) async {
    final vm = await pumpEditor(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ViewportWidget)),
        kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await settle(tester, frames: 2);
    expect(vm.isFlyNavigating, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await settle(tester, frames: 3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    expect(vm.activeTool, 'select', reason: 'W flies the camera while the right button is held');
    await gesture.up();
    await settle(tester, frames: 2);
    expect(vm.isFlyNavigating, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await settle(tester, frames: 2);
    expect(vm.activeTool, 'translate');
  });

  testWidgets('a text field keeps its keys, and the editor gets them back when it lets go', (tester) async {
    final vm = await pumpEditor(tester);
    final actor = spawnLight(vm);
    vm.selectActor(actor);
    vm.duplicateSelectedActor();
    await settle(tester, frames: 2);
    final count = vm.actors.length;

    await tester.tap(searchField);
    await settle(tester, frames: 3);
    for (final key in [LogicalKeyboardKey.keyW, LogicalKeyboardKey.keyE, LogicalKeyboardKey.keyR, LogicalKeyboardKey.delete]) {
      await tester.sendKeyEvent(key);
      await settle(tester, frames: 2);
    }
    expect(vm.activeTool, 'select', reason: 'typing into the outliner search switched a tool');
    expect(vm.actors.length, count, reason: 'Delete in the search box deleted an actor');
    await chord(tester, LogicalKeyboardKey.keyZ);
    await chord(tester, LogicalKeyboardKey.keyD);
    expect(vm.actors.length, count, reason: 'Ctrl+Z / Ctrl+D belong to the text field while it has focus');

    // What a desktop text field does when the user clicks elsewhere.
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, frames: 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await settle(tester, frames: 2);
    expect(vm.activeTool, 'translate', reason: 'focus left the text field but stayed in the editor');
    await chord(tester, LogicalKeyboardKey.keyZ);
    expect(vm.actors.length, count - 1, reason: 'Ctrl+Z undoes the duplicate');
  });

  testWidgets('a running Play session keeps the letter keys, and Esc stops it', (tester) async {
    final vm = await pumpEditor(tester);
    vm.pieController.startHeadlessForTest(LuminaWorld());
    addTearDown(() {
      if (vm.pieController.isPlaying) vm.pieController.stopHeadlessForTest();
    });
    await settle(tester, frames: 2);
    for (final key in [LogicalKeyboardKey.keyW, LogicalKeyboardKey.keyE, LogicalKeyboardKey.keyR]) {
      await tester.sendKeyEvent(key);
      await settle(tester, frames: 2);
    }
    expect(vm.activeTool, 'select', reason: 'the game has the keyboard while Play runs');
    vm.pieController.stopHeadlessForTest();
    await settle(tester, frames: 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await settle(tester, frames: 2);
    expect(vm.activeTool, 'translate');

    vm.startSimulation();
    await settle(tester, frames: 2);
    expect(vm.isPlaying, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, frames: 2);
    expect(vm.isPlaying, isFalse, reason: 'Esc stops Play');
  });

  testWidgets('level-editing keys do not reach the level from a sub-editor tab', (tester) async {
    final vm = await pumpEditor(tester);
    final actor = spawnLight(vm);
    vm.selectActor(actor);
    vm.openSubEditorTab('plugins', title: 'Plugins');
    await settle(tester);
    expect(vm.activeTabIndex, isNot(0));
    final count = vm.actors.length;
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await chord(tester, LogicalKeyboardKey.keyD);
    expect(vm.actors.length, count, reason: 'a key pressed in the Plugins tab edited the hidden level');
    expect(vm.activeTool, 'select');
  });

  test('view.focusSelected frames the selected actor', () {
    final dir = Directory.systemTemp.createTempSync('lumina_focus_selected_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'FocusGame'),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    final actor = spawnLight(vm);
    actor.location = [320.0, -140.0, 90.0];
    vm.selectActor(actor);
    vm.commands.execute('view.focusSelected');
    expect([vm.cameraPanX, vm.cameraPanY, vm.cameraPanZ], [320.0, -140.0, 90.0]);
  });
}
