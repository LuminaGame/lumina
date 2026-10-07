import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import '../helpers/shared_editor_preferences.dart';

/// The live integration binding runs animations on the real clock, so a bare
/// pump loop advances nothing. Each iteration pumps one frame and then yields
/// to the real event loop for the same amount of wall time.
Future<void> settle(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

/// Pumps until [condition] holds or [maxSeconds] of wall time elapse. With
/// [rec], the wait is recorded as a time-lapse: a frame every half second.
Future<bool> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxSeconds = 300,
  SmokeRecorder? rec,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: maxSeconds));
  final sinceFrame = Stopwatch()..start();
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return true;
    await settle(tester, frames: 6);
    if (rec != null && sinceFrame.elapsedMilliseconds >= 500) {
      await rec.captureIfChanged();
      sinceFrame.reset();
    }
  }
  return condition();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempConfigDir;
  late Directory tempProjectsDir;

  setUp(() {
    tempConfigDir = Directory.systemTemp.createTempSync('lumina_tpl_smoke_cfg_');
    tempProjectsDir = Directory.systemTemp.createTempSync('lumina_tpl_smoke_projects_');
  });

  tearDown(() {
    if (tempConfigDir.existsSync()) tempConfigDir.deleteSync(recursive: true);
    if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
  });

  /// Drives the real launcher -> New Project dialog -> real
  /// `flutter create` + `flutter pub get` pipeline for [templateTitle], then
  /// lands in Lumina Studio with the created project open.
  Future<String> createThroughLauncher(
    WidgetTester tester, {
    required GlobalKey boundaryKey,
    required SmokeRecorder rec,
    required String projectName,
    required String templateTitle,
  }) async {
    useSharedEditor(tempConfigDir);
    final vm = LauncherViewModel(configDir: tempConfigDir);

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: LauncherView(viewModel: vm),
        ),
      ),
    );
    await settle(tester);
    await rec.hold(const Duration(seconds: 1));

    // The hub shows "New Project..." in its action bar; with no recents at all
    // only the empty state's "Create New Project" is on screen.
    final newProjectButton = find.text('New Project...').evaluate().isNotEmpty
        ? find.text('New Project...').last
        : find.text('Create New Project').last;
    await tester.tap(newProjectButton);
    await settle(tester);
    await rec.hold(const Duration(seconds: 1));

    final nameField = find.widgetWithText(TextField, 'my_lumina_game').first;
    await tester.tap(nameField);
    await rec.typeText(nameField, projectName);
    await settle(tester, frames: 6);
    await tester.enterText(find.byType(TextField).last, tempProjectsDir.path);
    await settle(tester, frames: 6);
    await rec.hold(const Duration(seconds: 1));

    // Pick the template by its real catalog title — no "(pending)" anywhere.
    expect(find.textContaining('(pending)'), findsNothing);
    await tester.tap(find.text(templateTitle));
    await settle(tester, frames: 6);
    await rec.hold(const Duration(seconds: 1));

    await tester.tap(find.text('Create Project'));
    await settle(tester, frames: 6);

    final landed = await pumpUntil(
      tester,
      () => find.byType(MainEditorView).evaluate().isNotEmpty,
      maxSeconds: 420,
      rec: rec,
    );
    expect(landed, isTrue, reason: '$templateTitle project did not open in Lumina Studio');
    await settle(tester, frames: 60);

    return '${tempProjectsDir.path}/$projectName';
  }

  /// Asserts the on-disk scaffold a character template promises.
  void expectPlayableScaffold(String projectDir, {required bool thirdPerson}) {
    final levelMap = jsonDecode(
      File('$projectDir/contents/levels/L_DefaultLevel.lmas').readAsStringSync(),
    ) as Map<String, dynamic>;
    final actors = (levelMap['metadata']['actors'] as List)
        .map((a) => Map<String, dynamic>.from(a as Map))
        .toList();
    expect(actors.any((a) => a['type'] == 'PlayerStart'), isTrue);
    expect(actors.where((a) => a['type'] == 'Primitive').length, greaterThanOrEqualTo(5));

    final manifestFile = Directory(projectDir)
        .listSync()
        .whereType<File>()
        .firstWhere((f) => f.path.endsWith('.lmproject'));
    final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    expect(manifest['template'], thirdPerson ? kThirdPersonTemplateId : kFirstPersonTemplateId);
    final gameMode = manifest['maps_and_modes']['default_game_mode'] as String;
    final mainSource = File('$projectDir/lib/main.dart').readAsStringSync();
    final levelSource = File('$projectDir/lib/levels/l_default_level.dart').readAsStringSync();
    expect(levelSource, contains('LuminaPrimitiveActor('));

    if (thirdPerson) {
      // The Third Person character and game mode are Blueprints,
      // compiled at scaffold time into lib/actors/ (and ABP_Character into lib/anim/).
      expect(gameMode, LuminaThirdPersonContent.gameModeBlueprintPath);
      for (final path in [
        LuminaThirdPersonContent.characterBlueprintPath,
        LuminaThirdPersonContent.gameModeBlueprintPath,
        LuminaThirdPersonContent.projectAnimBlueprintPath,
        LuminaThirdPersonContent.projectWalkBlendSpacePath,
      ]) {
        expect(File('$projectDir/$path').existsSync(), isTrue, reason: path);
      }
      for (final file in [
        'lib/actors/bp_third_person_character.dart',
        'lib/actors/bp_third_person_game_mode.dart',
        'lib/anim/abp_character.dart',
        'lib/input/project_input.g.dart',
      ]) {
        expect(File('$projectDir/$file').existsSync(), isTrue, reason: 'compiled $file');
      }
      expect(Directory('$projectDir/lib/pawns').existsSync(), isFalse, reason: 'no Dart pawn is written');
      expect(mainSource, contains("luminaGameModeFactories['${LuminaThirdPersonContent.gameModeBlueprintPath}']!()"));

      // The mannequin and its clips are project assets, not engine files.
      final meshAsset = File('$projectDir/${LuminaThirdPersonContent.projectMeshAssetPath}');
      final meshGlb = File('$projectDir/${LuminaThirdPersonContent.projectMeshGlbPath}');
      expect(meshAsset.existsSync(), isTrue, reason: 'the mannequin skeletal mesh asset');
      expect(meshGlb.existsSync(), isTrue, reason: 'the mannequin GLB (mesh + clips)');
      expect(LuminaAsset.fromBytes(meshAsset.readAsBytesSync()).type, AssetType.filameshSk);
      for (final clip in LuminaThirdPersonContent.clipNames) {
        final anim = File('$projectDir/${LuminaThirdPersonContent.projectAnimationDir}/$clip.lmas');
        expect(anim.existsSync(), isTrue, reason: 'clip asset $clip');
        expect(LuminaAsset.fromBytes(anim.readAsBytesSync()).type, AssetType.animation);
      }
      return;
    }

    // First Person keeps its generated Dart pawn and game mode.
    final gameModeClass = gameMode;
    expect(gameModeClass, endsWith('GameMode'));
    final characterClass = gameModeClass.replaceAll('GameMode', 'Character');
    final characterFile = File('$projectDir/lib/pawns/${dartFileName(characterClass)}');
    expect(characterFile.existsSync(), isTrue, reason: 'generated character source');
    final characterSource = characterFile.readAsStringSync();
    expect(characterSource, contains('extends LuminaCharacter'));
    expect(characterSource, contains('bindAction(iaMove'));
    expect(characterSource, contains('bindAction(iaLook'));
    expect(characterSource, contains('bindAction(iaJump'));
    expect(characterSource, contains('location: Vector3(0.0, baseEyeHeight, 0.0)'));
    expect(characterSource, isNot(contains('LuminaSpringArmComponent')));

    final gameModeFile = File('$projectDir/lib/game/${dartFileName(gameModeClass)}');
    expect(gameModeFile.existsSync(), isTrue, reason: 'generated game mode source');
    expect(gameModeFile.readAsStringSync(), contains('defaultPawnFactory: () => $characterClass()'));

    // main.dart installs the game mode and bridges real keyboard/mouse input
    // into the running world; the level logs the player in at the PlayerStart.
    expect(mainSource, contains('world.gameMode ??= $gameModeClass();'));
    expect(mainSource, contains('input.injectKeyDown(key)'));
    expect(mainSource, contains('input.injectAnalog(LuminaKey.mouseX'));
    expect(levelSource, contains('playerController = mode.login();'));
  }

  testWidgets(
    'Launcher Templates Smoke: First Person scaffolds a playable project and opens its seeded outliner',
    (tester) async {
      const title =
          'Launcher Templates Smoke: First Person scaffolds a playable project and opens its seeded outliner';
      final boundaryKey = GlobalKey();
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));

      final projectDir = await createThroughLauncher(
        tester,
        boundaryKey: boundaryKey,
        rec: rec,
        projectName: 'fp_smoke_game',
        templateTitle: 'First Person',
      );

      expectPlayableScaffold(projectDir, thirdPerson: false);

      // The seeded tree is what the editor's outliner shows, straight away.
      expect(find.text('PlayerStart'), findsWidgets);
      expect(find.text('Floor'), findsWidgets);
      expect(find.text('Crate_A'), findsWidgets);

      // The opened project, running in the editor.
      await rec.hold(const Duration(seconds: 1));

      // Walk the seeded outliner: each click selects the actor in the level.
      for (final name in ['Crate_A', 'Floor', 'PlayerStart']) {
        await tester.tap(find.text(name).first);
        await settle(tester, frames: 6);
        await rec.hold(const Duration(milliseconds: 900));
      }

      // Look around the level: a right-button drag turns the camera.
      final viewportRect = tester.getRect(find.byType(ViewportWidget));
      await rec.drag(viewportRect.center, viewportRect.center + const Offset(260, 30),
          steps: 40, buttons: kSecondaryMouseButton);
      await rec.hold(const Duration(seconds: 1));

      final png = await SmokeArtifacts.captureIntegrationPng(
        binding,
        tester,
        boundary: find.byKey(boundaryKey),
      );
      SmokeArtifacts.saveScreenshot(title, png);
      expect(png.length, greaterThan(0));

      rec.save(title);
      expect(File('${SmokeArtifacts.dir.path}/${SmokeArtifacts.sanitizeTestName(title)}.webm').existsSync(), isTrue);
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );

  testWidgets(
    'Launcher Templates Smoke: Third Person opens as a game - the character walks then jogs and jumps on the template map in Play',
    (tester) async {
      const title =
          'Launcher Templates Smoke: Third Person opens as a game - the character walks then jogs and jumps on the template map in Play';
      final boundaryKey = GlobalKey();
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));

      final projectDir = await createThroughLauncher(
        tester,
        boundaryKey: boundaryKey,
        rec: rec,
        projectName: 'tp_smoke_game',
        templateTitle: 'Third Person',
      );

      expectPlayableScaffold(projectDir, thirdPerson: true);

      // The seeded level (the outliner builds only the rows in view, so the
      // editor's actor list is checked).
      final editor = tester.widget<ViewportWidget>(find.byType(ViewportWidget)).viewModel;
      expect(editor.actors.map((a) => a.name), containsAll(['PlayerStart', 'Ground', 'Stair_01', 'Hurdle']));

      // Each phase's screenshot is followed by a second of the running
      // editor/game on video; the waits in between are recorded as they run.
      Future<Uint8List> shot(String phase) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$title $phase', png);
        await rec.hold(const Duration(seconds: 1));
        return png;
      }

      await shot('01 editor');
      dynamic viewportState() => tester.state(find.byType(ViewportWidget));
      final editorActorsBefore = viewportState().editorActorsInSceneForTest as int;
      expect(editorActorsBefore, greaterThan(10), reason: 'the editor draws the template map before Play');

      // --- Play ------------------------------------------------------------
      final vm = tester.widget<ViewportWidget>(find.byType(ViewportWidget)).viewModel;
      final pie = vm.pieController;
      await tester.tap(find.byKey(const ValueKey('toolbar_play')));
      await settle(tester, frames: 30);
      expect(pie.isPlaying, isTrue, reason: 'Play must start a session');
      expect(pie.lastError, isNull, reason: 'PIE error: ${pie.lastError}');

      // Play runs BP_ThirdPersonCharacter
      // in the Blueprint VM, and ABP_Character animates its mannequin.
      final possessed = pie.possessedPawn;
      expect(possessed, isA<LuminaBlueprintCharacter>(), reason: 'the game mode must spawn and possess the Blueprint character');
      final pawn = possessed!;
      expect((pawn as LuminaBlueprintInstance).blueprintClass.name, 'BP_ThirdPersonCharacter');
      expect(pie.playerPawn, isNull, reason: 'the Dart template character is not what plays');
      final anim = (pawn as LuminaBlueprintInstance).blueprintComponents['mesh.anim'] as LuminaAnimBlueprintInstance;
      expect(anim.mesh.meshAssetPath, endsWith(LuminaThirdPersonContent.projectMeshGlbPath.split('/').last),
          reason: 'ABP_Character drives the project mannequin');

      expect(viewportState().editorActorsInSceneForTest, 0,
          reason: 'while playing only the game world is drawn');
      expect(viewportState().editorSunInSceneForTest, isFalse,
          reason: 'the level brings its own sun; the editor preview sun must not double it');
      expect(viewportState().pieCameraDrivesViewForTest, isTrue);

      await settle(tester, frames: 20);
      expect(anim.currentState, 'Idle');
      await shot('02 play idle');

      // Frame rate in the live binding is low and varies, so each phase waits
      // for the state it expects instead of holding a key for a fixed time.
      Future<bool> holdUntil(bool Function() reached, {int maxSeconds = 20}) async {
        final deadline = DateTime.now().add(Duration(seconds: maxSeconds));
        while (DateTime.now().isBefore(deadline)) {
          if (reached()) return true;
          await settle(tester, frames: 3);
          await rec.capture();
        }
        return reached();
      }

      // --- Walk forward with W ---------------------------------------------
      final start = pawn.actorLocation.clone();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      final walking = await holdUntil(() => anim.currentState == 'Walk' && (pawn.actorLocation - start).length > 50.0);
      expect(walking, isTrue, reason: 'W must walk the mannequin forward in the Walk state '
          '(state ${anim.currentState}, moved ${(pawn.actorLocation - start).length} cm)');
      await shot('03 walk forward');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      debugPrint('[tp_smoke] walked ${(pawn.actorLocation - start).length.toStringAsFixed(1)} cm');

      // --- Strafe right with D ---------------------------------------------
      final beforeStrafe = pawn.actorLocation.clone();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      final strafing = await holdUntil(() => anim.currentState == 'Walk' && (pawn.actorLocation - beforeStrafe).length > 50.0);
      expect(strafing, isTrue, reason: 'D must walk the mannequin sideways (state ${anim.currentState})');
      await shot('04 strafe right');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);

      // --- Release: back to idle -------------------------------------------
      final idle = await holdUntil(() => anim.currentState == 'Idle');
      expect(idle, isTrue, reason: 'released, the mannequin must return to Idle (state ${anim.currentState})');

      // --- Sprint with Left Shift + W: the jog row -------------------------
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final jogging = await holdUntil(() => anim.currentState == 'Walk' && anim.mesh.currentClip == LuminaThirdPersonClips.jogs.first);
      expect(jogging, isTrue, reason: 'the held sprint must play the forward jog (clip ${anim.mesh.currentClip})');
      await shot('05 sprint jog');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      expect(await holdUntil(() => anim.currentState == 'Idle'), isTrue, reason: 'released, back to Idle (state ${anim.currentState})');

      // --- Jump with Space: jump, fall loop, land --------------------------
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      final airborne = await holdUntil(() => anim.currentState == 'Jump' || anim.currentState == 'FallLoop', maxSeconds: 5);
      expect(airborne, isTrue, reason: 'Space must jump (state ${anim.currentState})');
      await shot('06 jump');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      final landed = await holdUntil(() => anim.currentState == 'Idle');
      expect(landed, isTrue, reason: 'the jump must land back in Idle (state ${anim.currentState})');

      // --- Turn with the mouse ---------------------------------------------
      final viewportRect = tester.getRect(find.byType(ViewportWidget));
      final yawBefore = pie.game!.playerController!.controlRotation.y;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: viewportRect.center);
      addTearDown(mouse.removePointer);
      for (var i = 0; i < 16; i++) {
        await mouse.moveTo(viewportRect.center + Offset(25.0 * (i + 1), 0));
        await settle(tester, frames: 2);
        await rec.capture();
      }
      final yawAfter = pie.game!.playerController!.controlRotation.y;
      debugPrint('[tp_smoke] yaw ${yawBefore.toStringAsFixed(1)} -> ${yawAfter.toStringAsFixed(1)}');
      expect((yawAfter - yawBefore).abs(), greaterThan(10.0), reason: 'the mouse must turn the view');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      await holdUntil(() => anim.currentState == 'Walk');
      await shot('07 turned and walking');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);

      // --- Stop gives the level back to the editor -------------------------
      final stop = find.byKey(const ValueKey('toolbar_stop'));
      expect(stop, findsOneWidget, reason: 'the toolbar must offer Stop');
      await tester.tap(stop);
      await settle(tester, frames: 30);
      expect(pie.isPlaying, isFalse);
      expect(viewportState().editorActorsInSceneForTest, editorActorsBefore,
          reason: 'Stop must put the editor\'s actors back');
      await shot('08 stopped');

      rec.save(title);
      expect(File('${SmokeArtifacts.dir.path}/${SmokeArtifacts.sanitizeTestName(title)}.webm').existsSync(), isTrue);
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
