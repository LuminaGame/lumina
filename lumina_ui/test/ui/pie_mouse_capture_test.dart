import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_mouse_capture/lumina_mouse_capture.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import '../helpers/temp_project.dart';

/// Play's hold on the mouse, on a real First Person project in
/// a temp directory and a real [LuminaWorld] (no Filament: the viewport half
/// is `pie_mouse_capture_editor_test.dart`). Every capture request goes to a
/// recording backend; nothing touches the pointer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late EditorViewModel vm;
  late RecordingMouseCaptureBackend backend;

  void useBackend({bool simulateLock = false}) {
    backend = RecordingMouseCaptureBackend(simulateLock: simulateLock);
    LuminaMouseCapture.backend = backend;
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lumina_pie_mouse_capture_');
    final template = GameTemplateCatalog.byId(kFirstPersonTemplateId);
    vm = EditorViewModel(
      initialProject: LuminaProject(projectName: 'CaptureGame', template: kFirstPersonTemplateId, input: template.input),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    // The template's player start and lights; its primitives need a live
    // engine for their meshes.
    vm.restoreSnapshot(template.levelActors.map(EditorActorNode.fromMap).where((a) => a.type != 'Primitive').toList());
    useBackend();
  });

  // Windows refuses to delete a folder a just-disposed editor still
  // holds; deleteTempProject retries on the real clock.
  tearDown(() async {
    if (vm.pieController.isPlaying) vm.pieController.stopHeadlessForTest();
    vm.dispose();
    LuminaMouseCapture.backend = RecordingMouseCaptureBackend();
    await deleteTempProject(dir);
  });

  Future<EditorPieGameHandle> play() async {
    final game = vm.pieController.startHeadlessForTest(LuminaWorld());
    await pumpEventQueue();
    // The pawn is spawned deferred: the first tick registers it.
    game.tickGame(1 / 60);
    return EditorPieGameHandle(game.playerController!);
  }

  test('Play captures the mouse; F4 gives the cursor back; a click takes it again', () async {
    final pie = vm.pieController;
    final capture = pie.mouseCapture;
    expect(capture.isSessionActive, isFalse);

    await play();
    expect(backend.requests, ['capture()'], reason: 'Play asks for the mouse at once');
    expect(capture.isCaptured, isTrue);
    expect(capture.hidesCursor, isTrue);
    expect(capture.holdsPointer, isFalse, reason: 'this backend has no lock: the hidden-cursor fallback');
    expect(capture.acceptsPointerDeltas, isTrue, reason: 'without relative motion, Flutter pointer deltas turn the camera');
    expect(capture.hintEpoch, 1);

    capture.release();
    expect(backend.requests.last, 'release');
    expect(capture.isCaptured, isFalse);
    expect(capture.isReleased, isTrue);
    expect(capture.hidesCursor, isFalse);
    expect(capture.acceptsPointerDeltas, isFalse);

    capture.recapture();
    expect(backend.requests.last, 'capture()');
    expect(capture.isCaptured, isTrue);
    expect(capture.hintEpoch, 1, reason: 'the F4 hint is shown once per Play, not per click');
  });

  test('released, pointer deltas no longer turn the pawn; captured, they do', () async {
    final handle = await play();
    final pie = vm.pieController;
    final yaw0 = handle.yaw;
    pie.injectPointerDelta(60, 0);
    pie.tick(1 / 60);
    final yaw1 = handle.yaw;
    expect((yaw1 - yaw0).abs(), greaterThan(1.0), reason: 'captured: hover deltas are mouse look');

    pie.mouseCapture.release();
    pie.injectPointerDelta(60, 0);
    pie.tick(1 / 60);
    expect(handle.yaw, closeTo(yaw1, 1e-9), reason: 'released: the mouse belongs to the editor');
  });

  test('with a real lock, relative motion turns the pawn, pointer deltas are ignored, and a loss releases', () async {
    useBackend(simulateLock: true);
    final handle = await play();
    final pie = vm.pieController;
    final capture = pie.mouseCapture;
    expect(capture.holdsPointer, isTrue, reason: 'the backend holds the pointer: the editor must shield its window');
    expect(capture.acceptsPointerDeltas, isFalse);
    expect(capture.isLocked, isTrue, reason: 'the backend confirmed the lock');

    final yaw0 = handle.yaw;
    pie.injectPointerDelta(80, 0);
    pie.tick(1 / 60);
    expect(handle.yaw, closeTo(yaw0, 1e-9), reason: 'the held pointer does not move; its Flutter deltas are not mouse look');

    backend.emitMotion(40, 0);
    await pumpEventQueue();
    pie.tick(1 / 60);
    expect((handle.yaw - yaw0).abs(), greaterThan(1.0), reason: 'relative motion from the compositor is mouse look');

    backend.emitLost();
    await pumpEventQueue();
    expect(capture.isCaptured, isFalse);
    expect(capture.isReleased, isTrue, reason: 'Alt+Tab gives the cursor back; a click takes it again');
    final yaw1 = handle.yaw;
    backend.emitMotion(40, 0);
    await pumpEventQueue();
    pie.tick(1 / 60);
    expect(handle.yaw, closeTo(yaw1, 1e-9), reason: 'no mouse look after the capture was lost');
  });

  test('pause and eject give the pointer back; resume and possess take it again; Stop always releases', () async {
    await play();
    final pie = vm.pieController;
    final capture = pie.mouseCapture;

    pie.pause();
    expect(capture.isCaptured, isFalse);
    expect(capture.isReleased, isFalse, reason: 'paused: no click-to-capture target either');
    expect(backend.requests.last, 'release');
    pie.resume();
    expect(capture.isCaptured, isTrue);
    expect(backend.requests.last, 'capture()');

    pie.eject();
    expect(capture.isCaptured, isFalse);
    expect(backend.requests.last, 'release');
    pie.possess();
    expect(capture.isCaptured, isTrue);

    capture.release();
    pie.pause();
    pie.resume();
    expect(capture.isCaptured, isFalse, reason: 'F4 before pausing: resume keeps the cursor');
    expect(capture.isReleased, isTrue);

    capture.recapture();
    pie.stopHeadlessForTest();
    expect(capture.isSessionActive, isFalse);
    expect(capture.isCaptured, isFalse);
    expect(backend.requests.last, 'release', reason: 'Stop always gives the pointer back');
    expect(backend.isCaptured, isFalse);
  });
}

/// The local player's view, as the tests read it.
class EditorPieGameHandle {
  EditorPieGameHandle(this.controller);

  final LuminaPlayerController controller;

  double get yaw => controller.controlRotation.y;
}
