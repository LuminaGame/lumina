import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_mouse_capture/lumina_mouse_capture.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_mouse_capture_layer.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

import '../../test/helpers/scaffold_game_project.dart';

/// Play used to mount the level and stop: no pawn, no possession, no
/// input. This boots the real editor on a real First Person project, presses
/// the real Play button, and drives real key and mouse events through the
/// viewport's focus node into the running world.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PIE Smoke: pressing Play possesses the template character and takes WASD and mouse look',
      (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_pie_');
    final pDir = Directory('${tempProjectsDir.path}/SmokePie')..createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);

    final template = GameTemplateCatalog.byId(kFirstPersonTemplateId);
    final project = LuminaProject(
      projectName: 'SmokePie',
      activeLevel: 'contents/levels/L_DefaultLevel.lmas',
      template: kFirstPersonTemplateId,
      input: template.input,
    );
    File('${pDir.path}/SmokePie.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    // The real level container, with the real template actors in it. The
    // editor reads these back off disk; nothing is injected from memory.
    File('${pDir.path}/contents/levels/L_DefaultLevel.lmas').writeAsStringSync(jsonEncode(<String, dynamic>{
      'assetId': 'level_L_DefaultLevel',
      'name': 'L_DefaultLevel',
      'type': 'level',
      'relativePath': 'contents/levels/L_DefaultLevel.lmas',
      'rawPayload': null,
      'metadata': <String, dynamic>{'actors': template.levelActors},
    }));

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      expect(vm.actors.any((a) => a.type == 'PlayerStart'), isTrue,
          reason: 'the level on disk must carry the template tree');
      expect(vm.actors.where((a) => a.type == 'Primitive').length, greaterThan(2),
          reason: 'the test room must be there to stand on');

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: MainEditorView(viewModel: vm),
          ),
        ),
      );

      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(40);

      // Each phase's screenshot is followed by the running session on video.
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String name) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png);
        await rec.hold(const Duration(milliseconds: 1200));
      }

      await shot('pie_editor_before_play');

      // --- Press Play, the way a user does ---------------------------------
      final playButton = find.byKey(const ValueKey('toolbar_play'));
      expect(playButton, findsOneWidget, reason: 'the toolbar must offer Play');
      await tester.tap(playButton);
      await settle(40);

      final pie = vm.pieController;
      expect(pie.isPlaying, isTrue, reason: 'Play must start a session');
      expect(pie.lastError, isNull, reason: 'PIE error: ${pie.lastError}');

      final pawn = pie.playerPawn;
      expect(pawn, isNotNull, reason: 'the game mode must spawn and possess the template character');
      expect(pawn!.thirdPerson, isFalse);

      final start = vm.actors.firstWhere((a) => a.type == 'PlayerStart');
      expect(pawn.actorLocation.x, closeTo(start.location[0], 0.5));

      // The view must come from the pawn's eye, not the editor flycam.
      dynamic viewportState() => tester.state(find.byType(ViewportWidget));
      final eye = viewportState().pieCameraEyeForTest as List<double>?;
      expect(eye, isNotNull, reason: 'the possessed camera must drive the Filament view');
      expect(eye![1], closeTo(pawn.actorLocation.y + LuminaTemplateCharacterTuning.firstPersonBaseEyeHeight, 1e-3));
      debugPrint('[pie_smoke] eye=(${eye[0].toStringAsFixed(2)}, ${eye[1].toStringAsFixed(2)}, '
          '${eye[2].toStringAsFixed(2)}) pawn=(${pawn.actorLocation.x.toStringAsFixed(2)}, '
          '${pawn.actorLocation.y.toStringAsFixed(2)}, ${pawn.actorLocation.z.toStringAsFixed(2)})');

      // Editor overlays belong to the editor camera; with the game's camera
      // driving the view they would be drawn in the wrong places.
      expect(viewportState().pieCameraDrivesViewForTest, isTrue);
      await shot('pie_possessed_first_person');

      // --- Walk with W ------------------------------------------------------
      final world = pie.game!.world;
      expect(world!.persistentLevel.actors.contains(pawn), isTrue,
          reason: 'the spawned pawn must be registered in the level it plays in');

      final before = pawn.actorLocation.clone();
      final walkStart = DateTime.now();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      // The walk is recorded as it happens.
      for (var i = 0; i < 8; i++) {
        await settle(2);
        await rec.capture();
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      final walkSeconds = DateTime.now().difference(walkStart).inMilliseconds / 1000.0;
      await settle(10);

      expect(pie.game!.injectedKeysForTest, greaterThan(0),
          reason: 'the key press must reach the running world');
      expect(pie.game!.droppedKeysForTest, 0);

      final moved = pawn.actorLocation - before;
      final walked = math.sqrt(moved.x * moved.x + moved.z * moved.z);
      final speed = walked / walkSeconds;
      debugPrint('[pie_smoke] walked ${walked.toStringAsFixed(1)} cm in '
          '${walkSeconds.toStringAsFixed(2)} s = ${speed.toStringAsFixed(1)} cm/s '
          '(cap ${LuminaTemplateCharacterTuning.maxWalkSpeed}); '
          'height ${pawn.actorLocation.y.toStringAsFixed(1)} cm');
      expect(walked, greaterThan(50.0), reason: 'W must walk the character, got $walked cm');
      // The walk speed the template sets must actually hold; without the clamp
      // the character accelerates without limit and this test would still pass
      // on distance alone.
      expect(speed, lessThan(LuminaTemplateCharacterTuning.maxWalkSpeed * 1.25),
          reason: 'walked at $speed cm/s, faster than the template allows');
      await shot('pie_walked_forward');

      // The floor must hold the character up, and the walls must stop it: both
      // are Primitive actors whose colliders only work when PIE registers the
      // collision subsystem.
      expect(pawn.actorLocation.y, greaterThan(-100.0),
          reason: 'the character fell through the floor to ${pawn.actorLocation.y}');
      // The walls stand at ±1000 cm (stored Y, runtime −Z).
      expect(pawn.actorLocation.z.abs(), lessThan(1100.0),
          reason: 'the character walked through the wall to z=${pawn.actorLocation.z}');

      // --- Mouse look -------------------------------------------------------
      final viewportRect = tester.getRect(find.byType(ViewportWidget));
      final yawBefore = pie.game!.playerController!.controlRotation.y;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: viewportRect.center);
      addTearDown(mouse.removePointer);
      await settle(4);
      for (var i = 0; i < 12; i++) {
        await mouse.moveTo(viewportRect.center + Offset(20.0 * (i + 1), 0));
        await settle(2);
        await rec.capture();
      }
      final yawAfter = pie.game!.playerController!.controlRotation.y;
      debugPrint('[pie_smoke] yaw ${yawBefore.toStringAsFixed(1)} -> ${yawAfter.toStringAsFixed(1)} deg');
      expect((yawAfter - yawBefore).abs(), greaterThan(5.0),
          reason: 'moving the mouse across the viewport must turn the view');
      await shot('pie_mouse_look');

      // --- Strafe left, then right, on video in real time ------------------
      final beforeStrafe = pawn.actorLocation.clone();
      for (final key in [LogicalKeyboardKey.keyA, LogicalKeyboardKey.keyD]) {
        await tester.sendKeyDownEvent(key);
        await rec.hold(const Duration(milliseconds: 800));
        await tester.sendKeyUpEvent(key);
        await rec.hold(const Duration(milliseconds: 300));
      }
      expect(pawn.actorLocation.x != beforeStrafe.x || pawn.actorLocation.z != beforeStrafe.z, isTrue,
          reason: 'A and D must move the character sideways');

      // --- The game owns the mouse: no cursor over the view --
      expect(viewportState().viewportCursorForTest, SystemMouseCursors.none,
          reason: 'while the game has input the cursor is hidden over the viewport');
      vm.commands.execute('debug.pausePie');
      await settle(5);
      await rec.hold(const Duration(seconds: 1));
      expect(pie.isPaused, isTrue);
      expect(viewportState().viewportCursorForTest, isNot(SystemMouseCursors.none),
          reason: 'a paused session gives the cursor back');
      vm.togglePauseSimulation();
      await settle(5);
      await rec.hold(const Duration(seconds: 1));
      expect(pie.isPaused, isFalse);
      expect(viewportState().viewportCursorForTest, SystemMouseCursors.none);

      // --- Stop restores the editor ----------------------------------------
      // The toolbar's own Stop, by key: by icon, the first square
      // is the title bar's Maximize.
      final stopButton = find.byKey(const ValueKey('toolbar_stop'));
      expect(stopButton, findsOneWidget, reason: 'the toolbar must offer Stop');
      await tester.tap(stopButton);
      await settle(30);
      expect(pie.isPlaying, isFalse);
      expect(viewportState().pieCameraEyeForTest, isNull,
          reason: 'Stop must give the view back to the editor camera');
      expect(viewportState().viewportCursorForTest, isNot(SystemMouseCursors.none),
          reason: 'Stop gives the editor its cursor back');
      await shot('pie_stopped_editor_restored');

      rec.save('PIE Smoke: pressing Play possesses the template character and takes WASD and mouse look');
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });


  testWidgets('PIE Smoke: Play captures the mouse — F4 hint, F4 gives the cursor back, a click takes it again, Esc stops',
      (tester) async {
    // On the launcher's Third Person project. The capture backend
    // records and simulates a compositor lock (as on the user's Wayland
    // desktop): the pointer of the person at this machine is never touched.
    // The native lock itself is verified in a nested headless GNOME Shell
    // (lumina test/smoke/input_smoke_test.dart).
    final backend = RecordingMouseCaptureBackend(simulateLock: true);
    LuminaMouseCapture.backend = backend;
    addTearDown(() => LuminaMouseCapture.backend = RecordingMouseCaptureBackend());

    final root = Directory.systemTemp.createTempSync('lumina_smoke_pie_capture_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = (await tester.runAsync(
        () => scaffoldGameProject(root, name: 'pie_capture_smoke', widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(Map<String, dynamic>.from(
        jsonDecode(File('$projectDir/pie_capture_smoke.lmproject').readAsStringSync()) as Map));
    expect(project.template, kThirdPersonTemplateId);
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> settle([int frames = 12]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
    ));
    await settle(40);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<void> shot(String name) async => SmokeArtifacts.saveScreenshot(
        name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
    dynamic viewport() => tester.state(find.byType(ViewportWidget));
    final shield = find.byKey(const ValueKey('pie_mouse_shield'));
    double hintOpacity() =>
        tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('pie_mouse_capture_hint'))).opacity;
    await rec.hold(const Duration(milliseconds: 800));

    // --- Play takes the mouse ---------------------------------------------
    await tester.tap(find.byKey(const ValueKey('toolbar_play')));
    for (var i = 0; i < 100 && !vm.pieController.isPlaying; i++) {
      await settle(2);
    }
    await settle(6);
    final pie = vm.pieController;
    expect(pie.isPlaying, isTrue, reason: 'blocked: ${vm.playBlockers} error: ${pie.lastError}');
    final capture = pie.mouseCapture;
    expect(capture.isCaptured, isTrue, reason: 'Play gives the game the mouse');
    expect(capture.holdsPointer, isTrue);
    final viewCentre = tester.getCenter(find.byType(ViewportWidget));
    expect(backend.requests.where((r) => r.startsWith('capture(')), hasLength(1));
    expect((backend.lastCentre! - viewCentre).distance, lessThan(1.0),
        reason: 'the pointer is held at the game view centre (${backend.lastCentre} vs $viewCentre)');
    expect(viewport().viewportCursorForTest, SystemMouseCursors.none);
    expect(shield, findsOneWidget, reason: 'the held pointer sits on the toolbar: the window is shielded');
    expect(find.text(PieMouseCaptureLayer.captureHint), findsOneWidget);
    expect(hintOpacity(), 1.0);
    await rec.hold(const Duration(milliseconds: 1200));
    await shot('pie_capture_f4_hint');

    // --- Mouse look from the compositor's relative motion -----------------
    // 60 × 25 px = 1500 px to the right: far past where a hidden-but-free
    // pointer would have hit the screen edge and stopped turning.
    double yaw() => pie.game!.playerController!.controlRotation.y;
    final yaw0 = yaw();
    for (var i = 0; i < 60; i++) {
      backend.emitMotion(25, i.isEven ? -1 : 1);
      await settle(1);
      await rec.capture();
    }
    final turned = (yaw() - yaw0).abs();
    debugPrint('[pie_capture_smoke] 1500 px of relative motion turned the view ${turned.toStringAsFixed(1)} deg');
    expect(turned, greaterThan(30.0), reason: 'relative motion keeps turning the camera');
    final yaw1 = yaw();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: viewCentre);
    addTearDown(mouse.removePointer);
    for (var i = 1; i <= 5; i++) {
      await mouse.moveTo(viewCentre + Offset(40.0 * i, 0));
      await settle(1);
    }
    expect(yaw(), closeTo(yaw1, 1e-6), reason: 'the held pointer\'s own deltas are not mouse look');
    await shot('pie_capture_mouse_look');

    // The hint fades after five seconds of play.
    await rec.hold(const Duration(milliseconds: 3200));
    expect(hintOpacity(), 0.0, reason: 'the F4 hint fades');

    // --- F4 gives the cursor back -----------------------------------------
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await settle(4);
    expect(capture.isCaptured, isFalse);
    expect(pie.isPlaying, isTrue, reason: 'F4 only gives the cursor back');
    expect(backend.requests.last, 'release');
    expect(shield, findsNothing);
    expect(viewport().viewportCursorForTest, SystemMouseCursors.basic);
    expect(find.text(PieMouseCaptureLayer.releasedHint), findsOneWidget);
    for (var i = 0; i < 8; i++) {
      await mouse.moveTo(viewCentre + Offset(-30.0 * i, 20.0 * i));
      await settle(1);
      await rec.capture();
    }
    expect(yaw(), closeTo(yaw1, 1e-6), reason: 'released: the mouse belongs to the editor');
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('pie_capture_f4_released');

    // --- A click on the game view takes the mouse again -------------------
    final selection = vm.selectedActorId;
    await tester.tapAt(viewCentre, kind: PointerDeviceKind.mouse);
    await settle(4);
    expect(capture.isCaptured, isTrue);
    expect(backend.requests.last, startsWith('capture('));
    expect(vm.selectedActorId, selection, reason: 'the capturing click is not an editor click');
    expect(shield, findsOneWidget);
    for (var i = 0; i < 30; i++) {
      backend.emitMotion(-20, 0);
      await settle(1);
      await rec.capture();
    }
    expect((yaw() - yaw1).abs(), greaterThan(10.0), reason: 'recaptured: mouse look again');
    await shot('pie_capture_click_recaptured');

    // --- Esc stops Play ----------------------------------------------------
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(10);
    expect(vm.isPlaying, isFalse, reason: 'Esc stops Play');
    expect(pie.isPlaying, isFalse);
    expect(backend.requests.last, 'release');
    expect(backend.isCaptured, isFalse);
    expect(shield, findsNothing);
    expect(viewport().viewportCursorForTest, isNot(SystemMouseCursors.none));
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('pie_capture_esc_stopped');
    debugPrint('[pie_capture_smoke] capture requests: ${backend.requests}');

    final video = rec.save('PIE Smoke: Play captures the mouse — F4 hint, F4 gives the cursor back, a click takes it again, Esc stops');
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
  });
}
