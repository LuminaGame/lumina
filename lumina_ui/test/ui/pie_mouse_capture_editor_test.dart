import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina_mouse_capture/lumina_mouse_capture.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_mouse_capture_layer.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The whole editor on a real First Person project: Play takes
/// the mouse (hidden cursor, F4 hint), F4 gives it back, a click on the game
/// view takes it again, Esc stops Play. The capture backend records; nothing
/// touches the pointer of the person at this machine.
void main() {
  late RecordingMouseCaptureBackend backend;

  // The viewport's tickers never let pumpAndSettle settle.
  Future<void> settle(WidgetTester tester, {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<EditorViewModel> pumpEditor(WidgetTester tester, {bool simulateLock = false}) async {
    backend = RecordingMouseCaptureBackend(simulateLock: simulateLock);
    LuminaMouseCapture.backend = backend;
    addTearDown(() => LuminaMouseCapture.backend = RecordingMouseCaptureBackend());

    final dir = Directory.systemTemp.createTempSync('lumina_pie_capture_editor_');
    addTearDown(() => dir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final template = GameTemplateCatalog.byId(kFirstPersonTemplateId);
    final vm = EditorViewModel(
      initialProject: LuminaProject(projectName: 'CaptureEditor', template: kFirstPersonTemplateId, input: template.input),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    vm.restoreSnapshot(template.levelActors.map(EditorActorNode.fromMap).where((a) => a.type != 'Primitive').toList());
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    // Play mounts into the viewport's Filament scene: wait for the engine.
    final size = tester.getSize(find.byType(ViewportWidget));
    dynamic viewport() => tester.state(find.byType(ViewportWidget));
    for (var i = 0; i < 60 && viewport().nativeProjectForTest(0.0, 0.0, 0.0, size) == null; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle(tester, frames: 5);
    return vm;
  }

  Future<void> play(WidgetTester tester, EditorViewModel vm) async {
    vm.startSimulation();
    await settle(tester, frames: 10);
    expect(vm.pieController.isPlaying, isTrue, reason: 'PIE error: ${vm.pieController.lastError}');
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester, frames: 2);
  }

  dynamic viewportState(WidgetTester tester) => tester.state(find.byType(ViewportWidget));

  double hintOpacity(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('pie_mouse_capture_hint'))).opacity;

  testWidgets('Play captures at the game view centre, hides the cursor and shows the F4 hint for five seconds',
      (tester) async {
    final vm = await pumpEditor(tester);
    await play(tester, vm);

    final centre = tester.getCenter(find.byType(ViewportWidget));
    expect(backend.requests, hasLength(1));
    expect(backend.lastCentre, isNotNull, reason: 'the viewport supplies where the pointer is parked');
    expect((backend.lastCentre! - centre).distance, lessThan(1.0),
        reason: 'captured at the game view centre ${backend.lastCentre} vs $centre');
    expect(vm.pieController.mouseCapture.isCaptured, isTrue);
    expect(viewportState(tester).viewportCursorForTest, SystemMouseCursors.none);

    expect(find.text(PieMouseCaptureLayer.captureHint), findsOneWidget);
    expect(hintOpacity(tester), 1.0, reason: 'the hint is prominent when Play takes the mouse');
    await tester.pump(const Duration(seconds: 6));
    await settle(tester, frames: 50);
    expect(hintOpacity(tester), 0.0, reason: 'and fades after five seconds');

    vm.stopSimulation();
    await settle(tester);
    await unmount(tester);
  });

  testWidgets('F4 gives the cursor back, the click that takes it again selects nothing, Esc stops Play',
      (tester) async {
    final vm = await pumpEditor(tester);
    await play(tester, vm);
    final pie = vm.pieController;

    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await settle(tester, frames: 3);
    expect(backend.requests.last, 'release');
    expect(pie.mouseCapture.isCaptured, isFalse);
    expect(pie.isPlaying, isTrue, reason: 'F4 only gives the cursor back');
    expect(viewportState(tester).viewportCursorForTest, SystemMouseCursors.basic);
    expect(find.text(PieMouseCaptureLayer.releasedHint), findsOneWidget);

    final before = pie.game!.playerController!.controlRotation.y;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byType(ViewportWidget)));
    addTearDown(mouse.removePointer);
    for (var i = 1; i <= 6; i++) {
      await mouse.moveTo(tester.getCenter(find.byType(ViewportWidget)) + Offset(30.0 * i, 0));
      await settle(tester, frames: 2);
    }
    expect(pie.game!.playerController!.controlRotation.y, closeTo(before, 1e-9),
        reason: 'released: moving over the game view does not turn the camera');

    final selectionBefore = vm.selectedActorId;
    await tester.tapAt(tester.getCenter(find.byType(ViewportWidget)), kind: PointerDeviceKind.mouse);
    await settle(tester, frames: 3);
    expect(backend.requests.last, startsWith('capture('), reason: 'a click on the game view takes the mouse again');
    expect(pie.mouseCapture.isCaptured, isTrue);
    expect(vm.selectedActorId, selectionBefore, reason: 'the capturing click is not an editor click');
    expect(find.text(PieMouseCaptureLayer.releasedHint), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, frames: 5);
    expect(vm.isPlaying, isFalse, reason: 'Esc stops Play while the game has the mouse');
    expect(pie.isPlaying, isFalse);
    expect(backend.requests.last, 'release');
    expect(backend.isCaptured, isFalse);
    expect(viewportState(tester).viewportCursorForTest, isNot(SystemMouseCursors.none));
    await unmount(tester);
  });

  testWidgets('Esc also stops Play once F4 released the mouse', (tester) async {
    final vm = await pumpEditor(tester);
    await play(tester, vm);
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await settle(tester, frames: 3);
    expect(vm.pieController.mouseCapture.isCaptured, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester, frames: 5);
    expect(vm.isPlaying, isFalse, reason: 'the editor shell\'s Esc stops Play too');
    expect(vm.pieController.isPlaying, isFalse);
    await unmount(tester);
  });

  testWidgets('with a real pointer lock the window is shielded, relative motion is mouse look, and a loss releases',
      (tester) async {
    final vm = await pumpEditor(tester, simulateLock: true);
    await play(tester, vm);
    final pie = vm.pieController;
    await settle(tester, frames: 3);

    expect(find.byKey(const ValueKey('pie_mouse_shield')), findsOneWidget,
        reason: 'the held pointer may sit on any editor button');
    expect(tester.takeException(), isNull,
        reason: 'the shield is an OverlayEntry child, never a Positioned');
    final stop = find.byKey(const ValueKey('toolbar_stop'));
    await tester.tap(stop, kind: PointerDeviceKind.mouse, warnIfMissed: false);
    await settle(tester, frames: 3);
    expect(pie.isPlaying, isTrue, reason: 'a click under the shield never presses an editor button');

    final yaw0 = pie.game!.playerController!.controlRotation.y;
    backend.emitMotion(50, 0);
    await settle(tester, frames: 3);
    expect((pie.game!.playerController!.controlRotation.y - yaw0).abs(), greaterThan(1.0),
        reason: 'relative motion from the compositor turns the camera');

    backend.emitLost();
    await settle(tester, frames: 3);
    expect(pie.mouseCapture.isCaptured, isFalse);
    expect(find.byKey(const ValueKey('pie_mouse_shield')), findsNothing);
    expect(find.text(PieMouseCaptureLayer.releasedHint), findsOneWidget);

    await tester.tap(stop, kind: PointerDeviceKind.mouse);
    await settle(tester, frames: 5);
    expect(pie.isPlaying, isFalse, reason: 'released, the toolbar works again');
    await unmount(tester);
  });
}
