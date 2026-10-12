import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina_runtime.dart' show LuminaInputSubsystem, LuminaKey;
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_mouse_capture/lumina_mouse_capture.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_mouse_capture_layer.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The whole editor on a real First Person project whose input binds Escape
/// to a menu action: in Play, Esc is the game's key (captured or released)
/// and Shift+Esc stops Play. A project that does not bind Escape keeps Esc
/// as the stop key. The capture backend records; the real pointer is never
/// touched.
void main() {
  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<EditorViewModel> pumpEditor(WidgetTester tester, {required bool bindEscape}) async {
    LuminaMouseCapture.backend = RecordingMouseCaptureBackend();
    addTearDown(() => LuminaMouseCapture.backend = RecordingMouseCaptureBackend());
    final dir = Directory.systemTemp.createTempSync('lumina_pie_escape_');
    addTearDown(() => dir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final template = GameTemplateCatalog.byId(kFirstPersonTemplateId);
    var input = template.input;
    if (bindEscape) {
      final contexts = [...input.mappingContexts];
      contexts[0] = contexts[0].copyWith(mappings: [
        ...contexts[0].mappings,
        ProjectInputMapping(action: 'IA_Menu', keyId: LogicalKeyboardKey.escape.keyId, keyLabel: 'Escape'),
      ]);
      input = input.copyWith(
        actions: [...input.actions, const ProjectInputAction(name: 'IA_Menu', executeWhenPaused: true)],
        mappingContexts: contexts,
      );
    }
    final vm = EditorViewModel(
      initialProject: LuminaProject(projectName: 'EscapeGame', template: kFirstPersonTemplateId, input: input),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    vm.restoreSnapshot(template.levelActors.map(EditorActorNode.fromMap).where((a) => a.type != 'Primitive').toList());
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    final size = tester.getSize(find.byType(ViewportWidget));
    dynamic viewport() => tester.state(find.byType(ViewportWidget));
    for (var i = 0; i < 60 && viewport().nativeProjectForTest(0.0, 0.0, 0.0, size) == null; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle(tester, frames: 5);
    vm.startSimulation();
    await settle(tester, frames: 10);
    expect(vm.pieController.isPlaying, isTrue, reason: 'PIE error: ${vm.pieController.lastError}');
    return vm;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester, frames: 2);
  }

  bool escapeHeld(EditorViewModel vm) =>
      vm.pieController.game!.gameInstance.world!.getSubsystem<LuminaInputSubsystem>()!.isKeyDown(LuminaKey.keyEscape);

  testWidgets('a game that binds Escape gets Esc, captured and released; Shift+Esc stops Play', (tester) async {
    final vm = await pumpEditor(tester, bindEscape: true);
    final pie = vm.pieController;
    expect(pie.gameBindsEscape, isTrue);
    expect(pie.mouseCapture.isCaptured, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await settle(tester, frames: 3);
    expect(pie.isPlaying, isTrue, reason: 'Esc is the game\'s key');
    expect(escapeHeld(vm), isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await settle(tester, frames: 3);
    expect(escapeHeld(vm), isFalse);

    // Released by F4: the editor shell's Esc does not stop Play either.
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await settle(tester, frames: 3);
    expect(pie.mouseCapture.isCaptured, isFalse);
    expect(find.text(PieMouseCaptureLayer.releasedHintGameEscape), findsOneWidget);
    expect(find.text(PieMouseCaptureLayer.releasedHint), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, frames: 3);
    expect(vm.isPlaying, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await settle(tester, frames: 5);
    expect(vm.isPlaying, isFalse, reason: 'Shift+Esc stops Play');
    expect(pie.isPlaying, isFalse);
    await unmount(tester);
  });

  testWidgets('Shift+Esc also stops Play while the game has the mouse', (tester) async {
    final vm = await pumpEditor(tester, bindEscape: true);
    expect(vm.pieController.mouseCapture.isCaptured, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await settle(tester, frames: 5);
    expect(vm.isPlaying, isFalse);
    await unmount(tester);
  });

  testWidgets('a game that does not bind Escape: Esc stops Play and the hint says Esc', (tester) async {
    final vm = await pumpEditor(tester, bindEscape: false);
    final pie = vm.pieController;
    expect(pie.gameBindsEscape, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await settle(tester, frames: 3);
    expect(find.text(PieMouseCaptureLayer.releasedHint), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, frames: 5);
    expect(vm.isPlaying, isFalse);
    await unmount(tester);
  });
}
