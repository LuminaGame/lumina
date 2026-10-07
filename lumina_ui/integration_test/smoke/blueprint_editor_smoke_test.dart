import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart' show FilamentLightManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_core/lumina_core.dart' show kThirdPersonTemplateId;
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/standalone_game_runner.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_blueprint_debug_panel.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_compile_status.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_graph_ref.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_asset_catalog.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint_enum/enum_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../test/helpers/blueprint_test_project.dart';
import '../../test/helpers/scaffold_game_project.dart';
import '../../test/helpers/widget_class_test_project.dart';

/// A launcher Third Person project, a new Character
/// Blueprint, and the Third Person Move / Look / Jump graph built the
/// way a user builds it: right-click palette searches, Enhanced Input actions
/// picked from the project, pin drags, a My Blueprint variable dragged in,
/// then Compile → Up to date and the class written to lib/actors/.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('blueprint editor: author the Third Person input graph', (tester) async {
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bp04_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = (await tester.runAsync(
        () => scaffoldGameProject(root, name: 'bp_third_person', widgetLibrary: 'flutter')))!;
    final assetPath = writeBlueprint(projectDir, 'BP_ThirdPersonHero',
        BlueprintEditorViewModel.createDefaultDocument('BP_ThirdPersonHero', parentClass: 'LuminaCharacter'));
    final vm = BlueprintEditorViewModel(assetPath: assetPath);
    await tester.runAsync(vm.load);
    expect(vm.inputActions.map((a) => a.name), containsAll(['IA_Move', 'IA_Look', 'IA_Jump']));

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Bounded settling: in the live integration binding shadcn's popovers keep
    // scheduling frames, so pumpAndSettle can time out.
    Future<void> settle([int frames = 12]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: BlueprintSubEditor(assetName: 'BP_ThirdPersonHero', assetPath: assetPath, viewModel: vm)),
      ),
    ));
    await settle();

    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(milliseconds: 900));

    final canvas = find.byType(BlueprintGraphCanvas);
    BlueprintGraphCanvasState state() => tester.state<BlueprintGraphCanvasState>(canvas);
    Offset topLeft() => tester.getTopLeft(canvas);

    // Zoom the canvas out with the wheel so the whole graph fits.
    final wheel = TestPointer(1, PointerDeviceKind.mouse);
    final corner = topLeft() + const Offset(4, 4);
    await tester.sendEventToBinding(wheel.hover(corner));
    for (var i = 0; i < 5; i++) {
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
      await rec.hold(const Duration(milliseconds: 100));
    }
    expect(state().zoom, closeTo(0.5, 1e-9));

    Offset screen(double x, double y) => topLeft() + Offset(x, y) * state().zoom + state().panOffset;

    Future<LuminaBlueprintNode> place(String query, String key, double x, double y) async {
      await tester.tapAt(screen(x, y), buttons: kSecondaryButton);
      await settle();
      await rec.capture();
      await tester.enterText(find.byKey(const ValueKey('palette_search')), query);
      await settle();
      await rec.capture();
      await rec.capture();
      final before = vm.graphNodes.map((n) => n.id).toSet();
      await tester.tap(find.byKey(ValueKey('palette_entry_$key')));
      await settle();
      await rec.capture();
      return vm.graphNodes.firstWhere((n) => !before.contains(n.id));
    }

    Future<void> pickAction(LuminaBlueprintNode node, String action) async {
      await tester.tap(find.byKey(ValueKey('node_action_select_${node.id}')));
      await settle();
      await rec.capture();
      await tester.tap(find.byKey(ValueKey('action_item_$action')).last);
      await settle();
      await rec.capture();
    }

    Offset pin(LuminaBlueprintNode n, String pinId, {required bool output}) =>
        topLeft() + state().pinScreenPosition(n.id, pinId, output: output)!;

    Future<void> wire(LuminaBlueprintNode a, String out, LuminaBlueprintNode b, String inp) async {
      await rec.drag(pin(a, out, output: true), pin(b, inp, output: false), steps: 6);
      await settle();
      expect(vm.graphWires.where((w) => w.fromNodeId == a.id && w.fromPinId == out && w.toNodeId == b.id && w.toPinId == inp),
          hasLength(1),
          reason: '${a.title}.$out → ${b.title}.$inp');
    }

    // --- My Blueprint: the LookSensitivity variable -------------------------
    await tester.tap(find.text('My Blueprint'));
    await settle();
    await rec.hold(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('var_add')));
    await settle();
    await rec.hold(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('var_menu_NewVar')));
    await settle();
    await tester.tap(find.byKey(const ValueKey('var_menu_rename')));
    await settle();
    await rec.typeText(find.byKey(const ValueKey('var_rename_field')), 'LookSensitivity', perCharacter: const Duration(milliseconds: 40));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle();
    await tester.tap(find.text('LookSensitivity'));
    await settle();
    await tester.enterText(
        find.descendant(of: find.byKey(const ValueKey('variable_default_LookSensitivity_0')), matching: find.byType(EditableText)),
        '0.4');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle();
    await rec.hold(const Duration(milliseconds: 400));
    expect(vm.document.variable('LookSensitivity')!.defaultValue, 0.4);

    // --- Move --------------------------------------------------------------
    final move = await place('enhanced', 'event_enhanced_input_action', 0, 0);
    await pickAction(move, 'IA_Move');
    final moveAxis = await place('break vector2d', 'break_vector2d', 300, 20);
    final control = await place('control rotation', 'get_control_rotation', 0, 280);
    final parts = await place('break rotator', 'break_rotator', 240, 280);
    final yawOnly = await place('make rotator', 'make_rotator', 620, 280);
    final forward = await place('forward vector', 'get_forward_vector', 920, 150);
    final right = await place('right vector', 'get_right_vector', 920, 400);
    final moveForward = await place('movement', 'add_movement_input', 1320, 20);
    final moveRight = await place('movement', 'add_movement_input', 1320, 330);
    await rec.hold(const Duration(milliseconds: 300));

    await wire(move, 'action_value', moveAxis, 'in_vec');
    await wire(control, 'return_value', parts, 'in_rot');
    await wire(parts, 'z', yawOnly, 'z');
    await wire(yawOnly, 'return_value', forward, 'in_rot');
    await wire(yawOnly, 'return_value', right, 'in_rot');
    await wire(move, 'triggered', moveForward, 'exec_move_in');
    await wire(forward, 'return_value', moveForward, 'world_dir');
    await wire(moveAxis, 'y', moveForward, 'scale_val');
    await wire(moveForward, 'exec_move_out', moveRight, 'exec_move_in');
    await wire(right, 'return_value', moveRight, 'world_dir');
    await wire(moveAxis, 'x', moveRight, 'scale_val');
    await rec.hold(const Duration(milliseconds: 500));

    // --- Look --------------------------------------------------------------
    final look = await place('enhanced', 'event_enhanced_input_action', 0, 560);
    await pickAction(look, 'IA_Look');
    final lookAxis = await place('break vector2d', 'break_vector2d', 300, 580);
    // LookSensitivity from My Blueprint: Ctrl-drag places a Get.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await rec.drag(tester.getCenter(find.byKey(const ValueKey('var_row_LookSensitivity'))), screen(330, 800), steps: 10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle();
    final sensitivity = vm.graphNodes.firstWhere((n) => n.registryId == LuminaBlueprintNodeLibrary.variableGet);
    final yawScaled = await place('multiply', 'float_multiply', 620, 560);
    final pitchScaled = await place('multiply', 'float_multiply', 620, 760);
    final yaw = await place('yaw', 'add_controller_yaw_input', 900, 560);
    final pitch = await place('pitch', 'add_controller_pitch_input', 1200, 640);

    await wire(look, 'action_value', lookAxis, 'in_vec');
    await wire(lookAxis, 'x', yawScaled, 'a');
    await wire(sensitivity, 'value', yawScaled, 'b');
    await wire(lookAxis, 'y', pitchScaled, 'a');
    await wire(sensitivity, 'value', pitchScaled, 'b');
    await wire(look, 'triggered', yaw, 'exec_in');
    await wire(yawScaled, 'return_value', yaw, 'val');
    await wire(yaw, 'exec_out', pitch, 'exec_in');
    await wire(pitchScaled, 'return_value', pitch, 'val');
    await rec.hold(const Duration(milliseconds: 500));

    // --- Jump --------------------------------------------------------------
    final jumpInput = await place('enhanced', 'event_enhanced_input_action', 0, 960);
    await pickAction(jumpInput, 'IA_Jump');
    final jump = await place('jump', 'jump', 300, 960);
    final stop = await place('stop jumping', 'stop_jumping', 300, 1100);
    await wire(jumpInput, 'started', jump, 'exec_in');
    await wire(jumpInput, 'completed', stop, 'exec_in');
    await rec.hold(const Duration(milliseconds: 800));

    expect(vm.graphNodes, hasLength(19));
    expect(vm.graphWires, hasLength(22));
    SmokeArtifacts.saveScreenshot('blueprint_editor_third_person_graph',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));

    // --- Compile ------------------------------------------------------------
    await tester.tap(find.byKey(const ValueKey('bp_compile')));
    for (var i = 0; i < 100 && vm.compileStatus != BlueprintCompileStatus.upToDate; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle();
    await rec.hold(const Duration(milliseconds: 1500));
    expect(vm.diagnostics, isEmpty, reason: '${vm.diagnostics}');
    expect(vm.compileStatus, BlueprintCompileStatus.upToDate);
    expect(find.descendant(of: find.byKey(const ValueKey('bp_compile_badge')), matching: find.text('Up to date')), findsOneWidget);
    expect(find.text('Compile complete: no errors or warnings.'), findsOneWidget);
    final generated = File('$projectDir/lib/actors/bp_third_person_hero.dart');
    expect(generated.readAsStringSync(), contains('class BpThirdPersonHero extends LuminaCharacter'));
    SmokeArtifacts.saveScreenshot('blueprint_editor_compiler_results_up_to_date',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));

    await tester.runAsync(vm.save);
    await rec.hold(const Duration(milliseconds: 600));
    expect(readBlueprint(assetPath).eventGraph.nodes, hasLength(19));

    final video = rec.save('blueprint editor: author the Third Person input graph');
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
  });

  testWidgets('blueprint editor: Play runs the Third Person Blueprint', (tester) async {
    // The launcher's Third Person project (its
    // character, game mode and ABP_Character are Blueprints),
    // opened in the real editor; Play runs BP_ThirdPersonCharacter in the VM
    // with the docked Blueprint tab lighting up the nodes as they run.
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bp05_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = (await tester.runAsync(
        () => scaffoldGameProject(root, name: 'bp_play_smoke', widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(Map<String, dynamic>.from(
        jsonDecode(File('$projectDir/bp_play_smoke.lmproject').readAsStringSync()) as Map));
    expect(project.mapsAndModes.defaultGameMode, LuminaThirdPersonContent.gameModeBlueprintPath);

    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.layoutState.bottomHeight = 330; // room for the docked graph

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
    await rec.hold(const Duration(milliseconds: 800));

    // The docked Blueprint tab waits for Play.
    // (the bottom tab bar's "Blueprint" sits on the "Output Log" tab's row)
    final tabRow = tester.getCenter(find.text('Output Log').first).dy;
    final tab = find.text('Blueprint').evaluate().firstWhere(
        (e) => (tester.getCenter(find.byElementPredicate((x) => x == e)).dy - tabRow).abs() < 3);
    await tester.tap(find.byElementPredicate((e) => e == tab));
    await settle(4);
    expect(vm.layoutState.activeBottomTab, 2);
    expect(find.textContaining('Press Play'), findsOneWidget);
    await rec.hold(const Duration(milliseconds: 600));

    // --- Play, the way a user does -------------------------------------------
    await tester.tap(find.byKey(const ValueKey('toolbar_play')));
    for (var i = 0; i < 100 && !vm.pieController.isPlaying; i++) {
      await settle(2);
    }
    await settle(30);
    final pie = vm.pieController;
    expect(pie.isPlaying, isTrue, reason: 'blocked: ${vm.playBlockers} error: ${pie.lastError}');
    expect(pie.lastError, isNull);
    final pawn = pie.possessedPawn!;
    expect(pawn, isA<LuminaBlueprintCharacter>());
    expect((pawn as LuminaBlueprintInstance).blueprintClass.name, 'BP_ThirdPersonCharacter');
    expect(pie.playerPawn, isNull, reason: 'the Dart template character is not what plays');
    expect(find.text('PIE · BP_ThirdPersonCharacter (VM)'), findsOneWidget);
    final anim = (pawn as LuminaBlueprintInstance).blueprintComponents['mesh.anim'] as LuminaAnimBlueprintInstance;
    expect(anim.mesh.meshAssetPath, endsWith('.glb'), reason: 'ABP_Character drives the mannequin');
    dynamic viewport() => tester.state(find.byType(ViewportWidget));
    expect(viewport().pieCameraDrivesViewForTest, isTrue, reason: 'Play looks through FollowCamera');

    // The docked panel follows the possessed pawn.
    final panel = tester.state<PieBlueprintDebugPanelState>(find.byType(PieBlueprintDebugPanel));
    for (var i = 0; i < 50 && panel.graphViewModel?.eventGraph.debug == null; i++) {
      await settle(2);
    }
    expect(panel.debuggedPath, LuminaThirdPersonContent.characterBlueprintPath);
    expect(find.text('Debugging BP_ThirdPersonCharacter'), findsOneWidget);
    final recorder = panel.graphViewModel!.eventGraph.debug!;
    final canvasFinder = find.byType(BlueprintGraphCanvas);
    final canvasState = tester.state<BlueprintGraphCanvasState>(canvasFinder);
    final wheel = TestPointer(7, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(wheel.hover(tester.getCenter(canvasFinder)));
    for (var i = 0; i < 4; i++) {
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
      await rec.hold(const Duration(milliseconds: 80));
    }
    await tester.sendEventToBinding(wheel.removePointer());
    canvasState.frameNode('look');
    await settle(4);
    await rec.hold(const Duration(milliseconds: 800));
    await shot('blueprint_pie_possessed_third_person');

    // --- Walk with W: the Blueprint's IA_Move graph moves the pawn ----------
    final start = pawn.actorLocation.clone();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    var sawMove = false;
    var sawWalk = false;
    for (var i = 0; i < 30; i++) {
      await settle(2);
      sawMove = sawMove || recorder.activeNodeIds.contains('move');
      sawWalk = sawWalk || anim.currentState == 'Walk';
      if (i == 20) await shot('blueprint_pie_walk_game_view');
      await rec.capture();
    }
    final walked = pawn.actorLocation - start;
    debugPrint('[bp05_smoke] walked ${walked.length.toStringAsFixed(1)} cm; state ${anim.currentState}; '
        'keys ${pie.game!.injectedKeysForTest}/${pie.game!.droppedKeysForTest}; vars ${anim.variables}');
    expect(sawWalk, isTrue, reason: 'ABP_Character follows the walking pawn into Walk');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    await settle(6);
    expect(walked.length, greaterThan(50), reason: 'W walks BP_ThirdPersonCharacter');
    expect(sawMove, isTrue, reason: 'the docked graph lit IA_Move while walking');

    // --- Mouse look through the Blueprint's LookSensitivity -----------------
    final viewRect = tester.getRect(find.byType(ViewportWidget));
    final yawBefore = pie.game!.playerController!.controlRotation.y;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: viewRect.center);
    addTearDown(mouse.removePointer);
    await settle(4);
    for (var i = 0; i < 24; i++) {
      await mouse.moveTo(viewRect.center + Offset(12.0 * (i + 1), 0));
      await settle(2);
      await rec.capture();
    }
    final yawAfter = pie.game!.playerController!.controlRotation.y;
    debugPrint('[bp05_smoke] yaw ${yawBefore.toStringAsFixed(1)} -> ${yawAfter.toStringAsFixed(1)}');
    expect((yawAfter - yawBefore).abs(), greaterThan(5.0), reason: 'IA_Look turns the view');

    // --- Back and to the side: S and D through the same IA_Move graph --------
    for (final key in [LogicalKeyboardKey.keyS, LogicalKeyboardKey.keyD]) {
      final from = pawn.actorLocation.clone();
      await tester.sendKeyDownEvent(key);
      for (var i = 0; i < 24; i++) {
        await settle(2);
        await rec.capture();
      }
      await tester.sendKeyUpEvent(key);
      await settle(4);
      final moved = (pawn.actorLocation - from).length;
      debugPrint('[bp05_smoke] ${key.keyLabel} moved ${moved.toStringAsFixed(1)} cm');
      expect(moved, greaterThan(30), reason: '${key.keyLabel} moves BP_ThirdPersonCharacter');
    }

    // --- Jump: IA_Jump Started → Jump lights up in the docked graph ---------
    canvasState.frameNode('jump');
    await settle(4);
    await rec.hold(const Duration(milliseconds: 600));
    final ground = pawn.actorLocation.y;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    var peak = ground;
    var sawInAir = false;
    var lit = false;
    for (var i = 0; i < 6; i++) {
      await settle(1);
      lit = lit || (recorder.activeNodeIds.containsAll(['jump_input', 'jump']));
      await rec.capture();
    }
    expect(lit, isTrue, reason: 'IA_Jump Started → Jump highlighted, got ${recorder.activeNodeIds}');
    await shot('blueprint_pie_jump_graph_highlight');
    for (var i = 0; i < 30; i++) {
      await settle(2);
      peak = peak < pawn.actorLocation.y ? pawn.actorLocation.y : peak;
      // The airborne states are Jump and FallLoop.
      sawInAir = sawInAir || anim.currentState == 'Jump' || anim.currentState == 'FallLoop';
      await rec.capture();
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await settle(6);
    debugPrint('[bp05_smoke] jump peak ${(peak - ground).toStringAsFixed(1)} cm, InAir seen: $sawInAir');
    expect(peak - ground, greaterThan(20), reason: 'the Blueprint Jump node launched the character');
    expect(sawInAir, isTrue, reason: 'ABP_Character enters Jump / FallLoop');

    // --- A running jump: W held, Space pressed mid-stride --------------------
    canvasState.frameNode('move');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    for (var i = 0; i < 12; i++) {
      await settle(2);
      await rec.capture();
    }
    final runFrom = pawn.actorLocation.clone();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    var runPeak = runFrom.y;
    for (var i = 0; i < 24; i++) {
      await settle(2);
      runPeak = runPeak < pawn.actorLocation.y ? pawn.actorLocation.y : runPeak;
      await rec.capture();
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    await settle(6);
    debugPrint('[bp05_smoke] running jump peak ${(runPeak - runFrom.y).toStringAsFixed(1)} cm');
    expect(runPeak - runFrom.y, greaterThan(20), reason: 'the running jump leaves the ground');
    await rec.hold(const Duration(milliseconds: 1200));

    // --- Stop gives the editor back; the panel waits for the next Play ------
    await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
    await settle(30);
    expect(pie.isPlaying, isFalse);
    expect(find.textContaining('Press Play'), findsOneWidget);
    await rec.hold(const Duration(milliseconds: 800));

    final video = rec.save('blueprint editor: Play runs the Third Person Blueprint');
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
  });

  testWidgets('blueprint editor: a Dart function exposed to Blueprints', (tester) async {
    // A launcher Third Person project (the real
    // `flutter create`, so it has its Linux runner), an annotated Dart
    // function written into its lib/, the node in the palette, placed and
    // compiled into BP_ThirdPersonCharacter, and Play Standalone building and
    // running the game, whose log reaches the Output Log.
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bp06_');
    addTearDown(() => root.deleteSync(recursive: true));
    const name = 'fn_smoke_game';
    final repo = ProjectRepository();
    await tester.runAsync(() async {
      await for (final p in repo.createProjectStream(
          projectName: name, projectLocation: root.path, template: kThirdPersonTemplateId, widgetLibrary: kUmgWidgetLibraryFlutter)) {
        debugPrint('[create] ${p.message}');
      }
    });
    final projectDir = '${root.path}/$name';
    expect(File('$projectDir/linux/CMakeLists.txt').existsSync(), isTrue, reason: 'the launcher creates the Linux runner');
    File('$projectDir/lib/health.dart').writeAsStringSync('''
import 'package:lumina/lumina_runtime.dart';

/// Hit points by actor: 100 until damaged.
final Expando<double> _health = Expando<double>('health');

/// Takes [amount] hit points from the actor running the node.
@BlueprintCallable(category: 'Game|Health', keywords: ['hurt', 'hit'])
void applyDamage(LuminaActor self, double amount) {
  final left = (_health[self] ?? 100.0) - amount;
  _health[self] = left < 0.0 ? 0.0 : left;
  print('[applyDamage] \${self.runtimeType} took \$amount, \${_health[self]} left');
}
''');
    const applyDamageId = 'fn:package:$name/health.dart#applyDamage';
    final project = (await tester.runAsync(() => repo.loadProject('$projectDir/$name.lmproject')))!;
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    addTearDown(() => vm.standalone.stop());
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
    await settle(30);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<void> shot(String name) async => SmokeArtifacts.saveScreenshot(
        name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));

    // The editor scanned lib/ when the project opened.
    for (var i = 0; i < 600 && vm.blueprintFunctions.functions.isEmpty; i++) {
      await settle(2);
    }
    expect(vm.blueprintFunctions.functions.map((f) => f.spec.id), [applyDamageId],
        reason: '${vm.blueprintFunctions.diagnostics}');
    await rec.hold(const Duration(milliseconds: 600));

    // --- The node in BP_ThirdPersonCharacter's palette -----------------------
    final asset = vm.realAssets.firstWhere((a) => a.relativePath == LuminaThirdPersonContent.characterBlueprintPath);
    vm.openSubEditorTab('Blueprint', asset: asset);
    await settle(20);
    final bp = tester.state<BlueprintSubEditorState>(find.byType(BlueprintSubEditor)).viewModel;
    for (var i = 0; i < 200 && bp.graphNodes.isEmpty; i++) {
      await settle(2);
    }
    expect(bp.graphNodes, isNotEmpty);
    await rec.hold(const Duration(milliseconds: 600));

    final canvas = find.byType(BlueprintGraphCanvas);
    BlueprintGraphCanvasState state() => tester.state<BlueprintGraphCanvasState>(canvas);
    Offset topLeft() => tester.getTopLeft(canvas);
    final wheel = TestPointer(9, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(wheel.hover(topLeft() + const Offset(4, 4)));
    for (var i = 0; i < 5; i++) {
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
      await rec.hold(const Duration(milliseconds: 80));
    }
    await tester.sendEventToBinding(wheel.removePointer());
    Offset screen(double x, double y) => topLeft() + Offset(x, y) * state().zoom + state().panOffset;

    Future<LuminaBlueprintNode> place(String query, String key, double x, double y, {String? shotName}) async {
      await tester.tapAt(screen(x, y), buttons: kSecondaryButton);
      await settle();
      await rec.capture();
      await rec.typeText(find.byKey(const ValueKey('palette_search')), query, perCharacter: const Duration(milliseconds: 60));
      await settle();
      await rec.hold(const Duration(milliseconds: 500));
      if (shotName != null) await shot(shotName);
      final before = bp.graphNodes.map((n) => n.id).toSet();
      await tester.tap(find.byKey(ValueKey('palette_entry_$key')));
      await settle();
      await rec.capture();
      return bp.graphNodes.firstWhere((n) => !before.contains(n.id));
    }

    final begin = await place('beginplay', 'event_beginplay', 0, 1000);
    final damage = await place('damage', applyDamageId, 420, 1000, shotName: 'blueprint_fn_palette_project_function');
    expect(damage.title, 'Apply Damage');
    await rec.drag(
      topLeft() + state().pinScreenPosition(begin.id, 'exec_out', output: true)!,
      topLeft() + state().pinScreenPosition(damage.id, 'exec_in', output: false)!,
      steps: 8,
    );
    await settle();
    expect(bp.graphWires.where((w) => w.fromNodeId == begin.id && w.toNodeId == damage.id), hasLength(1));
    final amount = find.descendant(of: find.byKey(ValueKey('literal_${damage.id}_amount_0')), matching: find.byType(EditableText));
    await rec.typeText(amount, '25', perCharacter: const Duration(milliseconds: 80));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle();
    expect(bp.graphNodes.firstWhere((n) => n.id == damage.id).literals['amount'], 25.0);

    await tester.tap(find.byKey(const ValueKey('bp_compile')));
    for (var i = 0; i < 200 && bp.compileStatus != BlueprintCompileStatus.warning && bp.compileStatus != BlueprintCompileStatus.error; i++) {
      await settle(2);
    }
    await rec.hold(const Duration(milliseconds: 1200));
    expect(bp.diagnostics.where((d) => d.isError), isEmpty, reason: '${bp.diagnostics}');
    expect(bp.diagnostics.where((d) => d.nodeId == damage.id).single.message, contains('requires Play Standalone'));
    expect(File('$projectDir/lib/actors/bp_third_person_character.dart').readAsStringSync(),
        contains('fn_${name}_health.applyDamage(this, 25.0)'));
    await tester.tap(find.byKey(const ValueKey('bp_save')));
    await settle(6);

    // --- Play Standalone -----------------------------------------------------
    vm.selectTab(0);
    await settle(6);
    final logTab = find.text('Output Log').first;
    await tester.tap(logTab);
    await settle(4);
    await tester.tap(find.byKey(const ValueKey('play_mode_dropdown')));
    await settle(6);
    await rec.hold(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const ValueKey('play_mode_standalone')));
    await settle(4);

    // The build (a minute or more: native assets included) as a time-lapse, a
    // frame whenever the view changes; then the game until applyDamage logs.
    final sw = Stopwatch()..start();
    bool hit() => vm.standalone.output.any((l) => l.contains('[applyDamage]'));
    var sawBuilding = false;
    while (sw.elapsed < const Duration(minutes: 12) && !hit()) {
      sawBuilding |= vm.standalone.state == StandaloneState.building;
      if (sawBuilding && vm.standalone.state == StandaloneState.idle) break; // failed
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await rec.captureIfChanged();
    }
    debugPrint('[bp06_smoke] standalone ${vm.standalone.state} after ${sw.elapsed.inSeconds} s; pid ${vm.standalone.lastPid}');
    expect(hit(), isTrue, reason: 'the game logs from applyDamage:\n${vm.standalone.output.reversed.take(40).toList().reversed.join('\n')}');
    expect(vm.standalone.state, StandaloneState.running);
    await settle(4); // the toolbar rebuilds on the runner's state
    expect(find.byKey(const ValueKey('standalone_status')), findsOneWidget);
    await settle(6);
    await rec.hold(const Duration(milliseconds: 1500));
    expect(vm.logger.logs.any((l) => l.source == 'Standalone' && l.message.contains('[applyDamage]')), isTrue);
    // The Output Log follows its tail: the game's line is on screen.
    expect(find.textContaining('[applyDamage]'), findsWidgets);
    await shot('blueprint_fn_standalone_output_log');

    // --- Stop ends the game process -----------------------------------------
    final pid = vm.standalone.lastPid!;
    expect(Directory('/proc/$pid').existsSync(), isTrue);
    await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
    for (var i = 0; i < 200 && vm.standalone.isActive; i++) {
      await settle(2);
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    expect(vm.standalone.isActive, isFalse);
    expect(Directory('/proc/$pid').existsSync(), isFalse, reason: 'Stop ends the game (pid $pid)');
    await rec.hold(const Duration(milliseconds: 1000));

    final video = rec.save('blueprint editor: a Dart function exposed to Blueprints');
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
  }, timeout: const Timeout(Duration(minutes: 20)));

  testWidgets('blueprint editor: FPS HUD authored with context-sensitive nodes', (tester) async {
    // A launcher Third Person project with a real
    // WBP_HUD (Text FPSCounter, Progress Bar Health). The user's flow, from
    // pin drags only: Create Widget → Promote to Variable → Get on Tick →
    // Get FPSCounter → Set Text; each drag's palette lists only what the
    // pin's class allows. Then Compile and Play: the widget instance's
    // FPSCounter element carries "FPS: <n>" while Health keeps its percent.
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bp07_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = (await tester.runAsync(
        () => scaffoldGameProject(root, name: 'bp_hud_smoke', widgetLibrary: 'flutter')))!;
    writeWidgetBlueprint(projectDir, 'WBP_HUD', hudDocument());
    final assetPath = '$projectDir/${LuminaThirdPersonContent.characterBlueprintPath}';
    final vm = BlueprintEditorViewModel(assetPath: assetPath);
    await tester.runAsync(vm.load);
    expect(vm.widgetClassCatalog!.widgetClass('WBP_HUD')!.elements.map((e) => e.name), ['FPSCounter', 'Health']);

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
      child: ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: BlueprintSubEditor(assetName: 'BP_ThirdPersonCharacter', assetPath: assetPath, viewModel: vm)),
      ),
    ));
    await settle();
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<void> shot(String name) async => SmokeArtifacts.saveScreenshot(
        name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
    await rec.hold(const Duration(milliseconds: 800));

    final canvas = find.byType(BlueprintGraphCanvas);
    BlueprintGraphCanvasState state() => tester.state<BlueprintGraphCanvasState>(canvas);
    Offset topLeft() => tester.getTopLeft(canvas);
    Offset screen(double x, double y) => topLeft() + Offset(x, y) * state().zoom + state().panOffset;
    Offset pin(LuminaBlueprintNode n, String pinId, {required bool output}) =>
        topLeft() + state().pinScreenPosition(n.id, pinId, output: output)!;

    // The template graph sits above; the HUD graph goes below it (its comment
    // boxes stack downwards).
    final baseY = templateGraphBottom(vm) + 300;
    final wheel = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(wheel.hover(topLeft() + const Offset(4, 4)));
    for (var i = 0; i < 4; i++) {
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
      await rec.hold(const Duration(milliseconds: 80));
    }
    await tester.sendEventToBinding(wheel.removePointer());

    Future<LuminaBlueprintNode> placeAt(String query, String key, double x, double y) async {
      state().frameCanvasPoint(Offset(x + 300, y + 100));
      await settle(2);
      await tester.tapAt(screen(x, y), buttons: kSecondaryButton);
      await settle();
      await rec.typeText(find.byKey(const ValueKey('palette_search')), query, perCharacter: const Duration(milliseconds: 30));
      await settle();
      await rec.capture();
      final before = vm.graphNodes.map((n) => n.id).toSet();
      await tester.tap(find.byKey(ValueKey('palette_entry_$key')));
      await settle();
      return vm.graphNodes.firstWhere((n) => !before.contains(n.id));
    }

    /// Drags [pinId] of [from] onto empty canvas at ([x], [y]), which opens
    /// the context-sensitive palette; picks the row keyed [key].
    Future<LuminaBlueprintNode> dragAndPick(LuminaBlueprintNode from, String pinId, double x, double y, String key,
        {String? query, String? screenshot, List<String> absent = const []}) async {
      // Both the source pin and the drop point in view.
      state().frameCanvasPoint(Offset((from.x + x) / 2 + 80, (from.y + y) / 2 + 60));
      await settle(2);
      await rec.drag(pin(from, pinId, output: true), screen(x, y), steps: 12);
      await settle();
      expect(find.text('Node Palette — Context Sensitive'), findsOneWidget, reason: 'drag off ${from.title}.$pinId');
      for (final a in absent) {
        expect(find.byKey(ValueKey('palette_entry_$a')), findsNothing, reason: '$a is not offered from ${from.title}.$pinId');
      }
      if (query != null) {
        await rec.typeText(find.byKey(const ValueKey('palette_search')), query, perCharacter: const Duration(milliseconds: 30));
        await settle();
      }
      await rec.hold(const Duration(milliseconds: 400));
      if (screenshot != null) await shot(screenshot);
      final before = vm.graphNodes.map((n) => n.id).toSet();
      await tester.tap(find.byKey(ValueKey('palette_entry_$key')));
      await settle();
      await rec.capture();
      return vm.graphNodes.firstWhere((n) => !before.contains(n.id));
    }

    // --- BeginPlay → Create Widget (WBP_HUD) → Promote → Add to Viewport ---
    final begin = await placeAt('beginplay', 'event_beginplay', 0, baseY);
    final create = await dragAndPick(begin, 'exec_out', 320, baseY, 'create_widget', query: 'create widget');
    // The node names the project's WBP_HUD from the start; the combobox
    // shows it and offers the project's classes.
    expect(vm.getGraphNode(create.id)!.literals['class'], 'WBP_HUD');
    state().frameNode(create.id);
    await settle(2);
    await tester.tap(find.byKey(ValueKey('literal_${create.id}_class_select')));
    await settle(20);
    await rec.hold(const Duration(milliseconds: 500));
    expect(find.byKey(ValueKey('literal_${create.id}_class_opt_WBP_HUD')), findsWidgets, reason: 'the class combobox lists WBP_HUD');
    await tester.tap(find.byKey(ValueKey('literal_${create.id}_class_opt_WBP_HUD')).last);
    await settle(20);
    await rec.hold(const Duration(milliseconds: 400));
    expect(vm.getGraphNode(create.id)!.literals['class'], 'WBP_HUD');
    expect(vm.eventGraph.pin(create.id, 'return_value', output: true)!.objectClass, 'Widget:WBP_HUD');
    final set = await dragAndPick(create, 'return_value', 700, baseY + 40, BlueprintPalette.promoteToVariableId,
        screenshot: 'blueprint_context_palette_widget_pin',
        absent: ['set_element_text', 'set_element_percent', 'get_component_CameraBoom']);
    expect(set.title, 'Set HudWidget');
    expect(vm.document.variable('HudWidget')!.typeName, 'Widget:WBP_HUD');
    final add = await dragAndPick(set, 'value', 1050, baseY, 'add_to_viewport', query: 'viewport');
    expect(vm.eventGraph.addWire(fromNodeId: set.id, fromPinId: 'exec_out', toNodeId: add.id, toPinId: 'exec_in'), isNotNull);

    // --- Tick → Get HudWidget → Is Valid? → Get FPSCounter → Set Text ------
    // The template already has an Event Tick (lumina 33bd632: Tick → Line
    // Trace Forward → Set WallAhead); the FPS chain splices after its last
    // exec node instead of placing a second one.
    final tick = vm.graphNodes.singleWhere((n) => n.registryId == 'event_tick');
    var tailNode = tick;
    var tailPin = 'exec_tick_out';
    while (true) {
      final next = vm.graphWires.where((w) => w.fromNodeId == tailNode.id && w.fromPinId == tailPin).firstOrNull;
      if (next == null) break;
      final to = vm.getGraphNode(next.toNodeId)!;
      final exec = vm.eventGraph.pinsOf(to).outputs.where((p) => p.type == LuminaPinType.exec).firstOrNull;
      if (exec == null) break;
      tailNode = to;
      tailPin = exec.id;
    }
    expect(tailNode.id, isNot(tick.id), reason: 'the template\'s Tick chain');
    // The HUD rows below the template graph in view for the variable drop.
    state().frameCanvasPoint(Offset(300, baseY + 420));
    await settle(2);
    await tester.tap(find.text('My Blueprint'));
    await settle();
    await rec.hold(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('component_row_CameraBoom')), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await rec.drag(tester.getCenter(find.byKey(const ValueKey('var_row_HudWidget'))), screen(0, baseY + 480), steps: 12);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle();
    final get = vm.graphNodes.firstWhere((n) => n.registryId == LuminaBlueprintNodeLibrary.variableGet && n.literals['variable'] == 'HudWidget');
    final valid = await dragAndPick(get, 'value', 320, baseY + 320, 'is_valid_branch', query: 'is valid');
    expect(vm.eventGraph.addWire(fromNodeId: tailNode.id, fromPinId: tailPin, toNodeId: valid.id, toPinId: 'exec_in'), isNotNull);
    final fps = await dragAndPick(get, 'value', 320, baseY + 520, 'get_widget_element_FPSCounter', query: 'fps',
        absent: ['get_widget_element_PlayButton']);
    expect(fps.title, 'Get FPSCounter');
    expect(vm.eventGraph.pin(fps.id, 'return_value', output: true)!.objectClass, 'WidgetElement:text');
    final setText = await dragAndPick(fps, 'return_value', 700, baseY + 320, 'set_element_text',
        screenshot: 'blueprint_context_palette_text_block_pin', absent: ['set_element_percent', 'add_to_viewport']);
    expect(setText.title, 'Set Text (Text)');
    expect(vm.eventGraph.addWire(fromNodeId: valid.id, fromPinId: 'is_valid', toNodeId: setText.id, toPinId: 'exec_in'), isNotNull);

    // 1 / Delta Seconds → Round → To String → Format Text "FPS: {0}".
    // The template's Tick sits far right of the HUD graph: place the divide
    // from the palette and wire Delta Seconds to it.
    final divide = await placeAt('float / float', 'float_divide', 320, baseY + 720);
    vm.setPinLiteral(divide.id, 'a', 1.0);
    expect(vm.eventGraph.addWire(fromNodeId: tick.id, fromPinId: 'delta_seconds', toNodeId: divide.id, toPinId: 'b'), isNotNull);
    final round = await dragAndPick(divide, 'return_value', 560, baseY + 720, 'round', query: 'round');
    final toString = await dragAndPick(round, 'return_value', 780, baseY + 720, 'int_to_string', query: 'to string (int)');
    final format = await placeAt('format text', 'format_string', 1000, baseY + 720);
    state().frameCanvasPoint(Offset(900, baseY + 600));
    await settle(2);
    await rec.drag(pin(toString, 'return_value', output: true), pin(format, 'arg_0', output: false), steps: 10);
    await settle();
    await rec.drag(pin(format, 'return_value', output: true), pin(setText, 'in_text', output: false), steps: 10);
    await settle();
    expect(vm.graphWires.any((w) => w.fromNodeId == format.id && w.toNodeId == setText.id && w.toPinId == 'in_text'), isTrue);
    state().frameCanvasPoint(Offset(600, baseY + 400));
    await settle(2);
    await rec.hold(const Duration(milliseconds: 600));
    await shot('blueprint_fps_hud_graph');

    // --- Compile and save ----------------------------------------------------
    await tester.tap(find.byKey(const ValueKey('bp_compile')));
    for (var i = 0; i < 100 && vm.compileStatus == BlueprintCompileStatus.dirty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle();
    expect(vm.diagnostics.where((d) => d.isError), isEmpty, reason: '${vm.diagnostics}');
    await tester.runAsync(vm.save);
    await rec.hold(const Duration(milliseconds: 600));

    // --- Play in the main editor: the HUD instance carries per-element state -
    final project = LuminaProject.fromMap(Map<String, dynamic>.from(
        jsonDecode(File('$projectDir/bp_hud_smoke.lmproject').readAsStringSync()) as Map));
    final editor = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(editor.ensureDefaultLevelAssets);
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
    ));
    await settle(40);
    await rec.hold(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('toolbar_play')));
    for (var i = 0; i < 100 && !editor.pieController.isPlaying; i++) {
      await settle(2);
    }
    final pie = editor.pieController;
    expect(pie.isPlaying, isTrue, reason: 'blocked: ${editor.playBlockers} error: ${pie.lastError}');
    expect(LuminaWidgetClassRegistry.lookup('WBP_HUD')!.elements, hasLength(2), reason: 'Play registered the widget classes');
    await settle(60);
    final subsystem = pie.game!.world!.getSubsystem<LuminaWidgetSubsystem>()!;
    final instance = subsystem.activeWidgets.value.singleWhere((w) => w['class'] == 'WBP_HUD');
    final elements = instance['elements'] as Map;
    expect((elements['FPSCounter'] as Map)['text'], matches(RegExp(r'^FPS: \d+$')));
    expect((elements['Health'] as Map)['percent'], 0.75);
    await rec.hold(const Duration(milliseconds: 1200));
    await shot('blueprint_fps_hud_pie');

    await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
    await settle(20);
    expect(pie.isPlaying, isFalse);
    final video = rec.save('blueprint editor: FPS HUD authored with context-sensitive nodes');
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
    vm.dispose();
  }, timeout: const Timeout(Duration(minutes: 15)));

  testWidgets('blueprint editor: functions, events and debug draw', (tester) async {
    // On a launcher Third Person project: My Blueprint
    // + New Function with an input typed in Details, a Custom Event and an
    // Event Dispatcher, a Timeline opened in its curve tab with a float
    // track, an Enumeration asset edited in its own editor, a comment box,
    // then Tick → Draw Debug Line / Sphere + Print String (to screen), Compile, Save
    // and Play: the level viewport draws the line and the HUD line.
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bp09_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = (await tester.runAsync(
        () => scaffoldGameProject(root, name: 'bp_fn_smoke', widgetLibrary: 'flutter')))!;
    final assetPath = '$projectDir/${LuminaThirdPersonContent.characterBlueprintPath}';
    final vm = BlueprintEditorViewModel(assetPath: assetPath);
    await tester.runAsync(vm.load);

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
      child: ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: BlueprintSubEditor(assetName: 'BP_ThirdPersonCharacter', assetPath: assetPath, viewModel: vm)),
      ),
    ));
    await settle();
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<void> shot(String name) async => SmokeArtifacts.saveScreenshot(
        name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
    await rec.hold(const Duration(milliseconds: 600));

    // --- My Blueprint: + New Function, its input typed in Details ---------
    await tester.tap(find.text('My Blueprint'));
    await settle();
    await tester.tap(find.byKey(const ValueKey('fn_add')));
    await settle();
    expect(vm.activeGraph, const BlueprintGraphRef.function('NewFunction'));
    expect(find.byKey(const ValueKey('graph_tab_function:NewFunction')), findsOneWidget);
    expect(find.byKey(const ValueKey('bp_function_details')), findsOneWidget);
    await rec.hold(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('fn_input_add')));
    await settle();
    expect(vm.document.function('NewFunction')!.inputs.map((v) => v.name), ['NewParam']);
    await tester.tap(find.byKey(const ValueKey('fn_output_add')));
    await settle();
    final fnEditor = vm.graphEditor(const BlueprintGraphRef.function('NewFunction'));
    expect(fnEditor.nodes.map((n) => n.registryId), containsAll(['function_entry', 'function_result']));
    expect(vm.renameFunction('NewFunction', 'AddHealth'), isTrue);
    await settle();
    expect(find.byKey(const ValueKey('graph_tab_function:AddHealth')), findsOneWidget);
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('blueprint_function_tab');

    // --- A dispatcher and a custom event on the event graph ----------------
    await tester.tap(find.byKey(const ValueKey('dispatcher_add')));
    await settle();
    expect(vm.document.dispatchers.map((d) => d.name), ['NewEventDispatcher']);
    await tester.tap(find.byKey(const ValueKey('graph_tab_eventGraph:')));
    await settle();
    final canvas = find.byType(BlueprintGraphCanvas);
    BlueprintGraphCanvasState state() => tester.state<BlueprintGraphCanvasState>(canvas);
    Offset topLeft() => tester.getTopLeft(canvas);
    Offset screen(double x, double y) => topLeft() + Offset(x, y) * state().zoom + state().panOffset;
    // Below the template graph's comment boxes.
    final baseY = templateGraphBottom(vm) + 300;
    final wheel = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(wheel.hover(topLeft() + const Offset(4, 4)));
    for (var i = 0; i < 4; i++) {
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
      await rec.hold(const Duration(milliseconds: 60));
    }
    await tester.sendEventToBinding(wheel.removePointer());
    state().frameCanvasPoint(Offset(400, baseY + 100));
    await settle(2);
    await tester.tapAt(screen(0, baseY), buttons: kSecondaryButton);
    await settle();
    expect(find.byKey(const ValueKey('palette_entry_action_add_custom_event')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('palette_entry_action_add_custom_event')));
    await settle();
    await tester.enterText(find.byKey(const ValueKey('graph_name_field')), 'OnScored');
    await rec.hold(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('graph_name_ok')));
    await settle();
    // The template character already declares a custom event; ours is the named one.
    final event = vm.graphNodes.singleWhere((n) => n.registryId == LuminaBlueprintNodeLibrary.customEvent && n.literals['name'] == 'OnScored');
    expect(event.literals['name'], 'OnScored');
    expect(vm.eventGraph.paletteEntries().any((e) => e.registryId == LuminaBlueprintNodeLibrary.callCustomEvent), isTrue);

    // --- A Timeline: opened from Details into its curve tab ----------------
    final timeline = vm.addGraphNode('timeline', Offset(0, baseY + 300))!;
    vm.eventGraph.select(timeline.id);
    await settle();
    expect(find.byKey(ValueKey('details_open_timeline_${timeline.id}')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('details_open_timeline_${timeline.id}')));
    await settle();
    expect(find.byKey(const ValueKey('bp_timeline_editor')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timeline_add_float')));
    await settle();
    expect(vm.timelineTracks(timeline.id).map((t) => t.name), ['NewFloatTrack']);
    vm.setTimelineKeys(timeline.id, 'NewFloatTrack', [
      const LuminaTimelineKey(0.0, [0.0], LuminaTimelineInterp.cubic),
      const LuminaTimelineKey(1.0, [90.0], LuminaTimelineInterp.cubic),
    ]);
    await settle();
    // Click the curve to add a key in the middle.
    final curve = find.byKey(const ValueKey('timeline_curve_NewFloatTrack'));
    await tester.tapAt(tester.getCenter(curve));
    await settle();
    expect(vm.timelineTracks(timeline.id).single.keys.length, 3);
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('blueprint_timeline_tab');

    // --- A comment around the timeline, back on the event graph -----------
    await tester.tap(find.byKey(const ValueKey('graph_tab_eventGraph:')));
    await settle();
    vm.eventGraph.select(timeline.id);
    final comment = state().addCommentAroundSelection()!;
    expect(comment.registryId, 'comment');
    await settle();

    // --- Tick → Draw Debug Line → Draw Debug Sphere → Print String --------
    // The line runs across the view (authoring X) at the player start, the
    // sphere sits 3 m ahead of it (authoring +Y is the pawn's forward).
    final tick = vm.graphNodes.firstWhere((n) => n.registryId == 'event_tick', orElse: () => vm.addGraphNode('event_tick', Offset(0, baseY + 700))!);
    final line = vm.addGraphNode('draw_debug_line', Offset(400, baseY + 700), literals: {
      'line_start': [-250.0, 0.0, 120.0],
      'line_end': [250.0, 0.0, 120.0],
      'line_color': [1.0, 0.2, 0.2, 1.0],
      'duration': 0.5,
      'thickness': 3.0,
    })!;
    final sphere = vm.addGraphNode('draw_debug_sphere', Offset(800, baseY + 700), literals: {
      'center': [0.0, 300.0, 100.0],
      'radius': 50.0,
      'segments': 16,
      'line_color': [0.2, 1.0, 0.3, 1.0],
      'duration': 0.5,
      'thickness': 2.0,
    })!;
    final print = vm.addGraphNode('print_string', Offset(1200, baseY + 700), literals: {
      'in_string': 'Debug draw from Blueprint',
      'print_to_screen': true,
      'print_to_log': false,
      'key': 'smoke',
      'duration': 0.0,
    })!;
    final tickOut = vm.graphWires.where((w) => w.fromNodeId == tick.id && w.fromPinId == 'exec_tick_out').firstOrNull;
    if (tickOut != null) vm.addGraphWire(fromNodeId: print.id, fromPinId: 'exec_out', toNodeId: tickOut.toNodeId, toPinId: tickOut.toPinId);
    expect(vm.addGraphWire(fromNodeId: tick.id, fromPinId: 'exec_tick_out', toNodeId: line.id, toPinId: 'exec_in'), isNotNull);
    expect(vm.addGraphWire(fromNodeId: line.id, fromPinId: 'exec_out', toNodeId: sphere.id, toPinId: 'exec_in'), isNotNull);
    expect(vm.addGraphWire(fromNodeId: sphere.id, fromPinId: 'exec_out', toNodeId: print.id, toPinId: 'exec_in'), isNotNull);
    state().frameNode(line.id);
    await settle(2);
    await rec.hold(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('bp_compile')));
    for (var i = 0; i < 100 && vm.compileStatus == BlueprintCompileStatus.dirty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle();
    expect(vm.diagnostics.where((d) => d.isError), isEmpty, reason: '${vm.diagnostics}');
    await tester.runAsync(vm.save);
    await rec.hold(const Duration(milliseconds: 400));

    // --- Enumeration asset in its editor ----------------------------------
    final enumRel = BlueprintAssetCatalog.writeEnum(projectDir, const LuminaBlueprintEnumDocument(name: 'E_DoorState'));
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: BlueprintEnumSubEditor(assetName: 'E_DoorState', assetPath: '$projectDir/$enumRel')),
      ),
    ));
    await settle();
    final enumState = tester.state<BlueprintEnumSubEditorState>(find.byType(BlueprintEnumSubEditor));
    for (final v in ['Closed', 'Opening', 'Open']) {
      enumState.viewModel.addValue(v);
      await settle(3);
    }
    await tester.tap(find.byKey(const ValueKey('enum_up_Open')));
    await settle();
    expect(enumState.viewModel.values, ['Closed', 'Open', 'Opening']);
    await tester.tap(find.byKey(const ValueKey('enum_save')));
    await settle();
    expect(BlueprintAssetCatalog.readEnum('$projectDir/$enumRel')!.values, ['Closed', 'Open', 'Opening']);
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('blueprint_enum_editor');

    // --- Play in the main editor: the debug overlay and the HUD line -------
    final project = LuminaProject.fromMap(Map<String, dynamic>.from(
        jsonDecode(File('$projectDir/bp_fn_smoke.lmproject').readAsStringSync()) as Map));
    final editor = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(editor.ensureDefaultLevelAssets);
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
    ));
    await settle(40);
    await rec.hold(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('toolbar_play')));
    for (var i = 0; i < 100 && !editor.pieController.isPlaying; i++) {
      await settle(2);
    }
    final pie = editor.pieController;
    expect(pie.isPlaying, isTrue, reason: 'blocked: ${editor.playBlockers} error: ${pie.lastError}');
    await settle(90);
    final world = pie.game!.world!;
    expect(world.debugShapes.where((s) => s.kind == LuminaDebugShapeKind.line), isNotEmpty);
    expect(world.debugShapes.where((s) => s.kind == LuminaDebugShapeKind.sphere), isNotEmpty);
    expect(world.screenMessages['smoke']?.text, 'Debug draw from Blueprint');
    expect(find.byKey(const ValueKey('pie_screen_messages')), findsOneWidget);
    expect(find.byKey(const ValueKey('pie_debug_shapes')), findsOneWidget);
    await rec.hold(const Duration(milliseconds: 2500));
    await shot('blueprint_pie_debug_draw');
    await rec.hold(const Duration(milliseconds: 1500));

    await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
    await settle(20);
    expect(pie.isPlaying, isFalse);
    final video = rec.save('blueprint editor: functions, events and debug draw');
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
    vm.dispose();
  }, timeout: const Timeout(Duration(minutes: 15)));

  testWidgets('blueprint editor: collision shapes and presets', (tester) async {
    // A launcher Third Person project with the real
    // SM_Casino_Chair FBX imported (its UCX_ hulls) and a BP_Chair drawing
    // it. In the Blueprint editor: Add Component "col" → Box Collision and
    // Sphere Collision; the box is widened in Details and given Block All,
    // the sphere Trigger (the grid greys and shows the table), then Custom
    // with Pawn → Block. The 3D Viewport draws both wireframes.
    const usedAssets = ['FBX/StaticMeshes/SM_Casino_Chair.FBX'];
    final chairFbx = File('${Directory.current.parent.path}/test-assets/FBX/StaticMeshes/SM_Casino_Chair.FBX');
    expect(chairFbx.existsSync(), isTrue, reason: 'test-assets present');
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bp10_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: 'bp_collision_smoke', widgetLibrary: 'flutter')))!;
    final imported = (await tester.runAsync(() => ImportAssetUseCase()(projectDir: projectDir, sourceFilePath: chairFbx.path)))!;
    expect(imported.isSuccess, isTrue, reason: imported.error);
    writeBlueprint(
      projectDir,
      'BP_Chair',
      LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
        LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
        LuminaBlueprintComponent(id: 'chair', name: 'Chair', type: 'LuminaStaticMeshComponent', parentId: 'root', properties: {
          'staticMeshAsset': imported.asset!.relativePath,
        }),
      ]),
    );
    final project = LuminaProject.fromMap(Map<String, dynamic>.from(
        jsonDecode(File('$projectDir/bp_collision_smoke.lmproject').readAsStringSync()) as Map));
    final editor = EditorViewModel(initialProject: project, projectLocation: root.path);
    addTearDown(editor.dispose);
    await tester.runAsync(editor.ensureDefaultLevelAssets);
    editor.refreshAssets();

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
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
    ));
    await settle(40);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<void> shot(String name) async => SmokeArtifacts.saveScreenshot(
        name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
        usedAssets: usedAssets);
    await rec.hold(const Duration(milliseconds: 600));

    // --- Open BP_Chair on its 3D Viewport ------------------------------------
    final asset = editor.realAssets.firstWhere((a) => a.relativePath == 'contents/blueprints/BP_Chair.lmas');
    editor.openSubEditorTab('Blueprint', asset: asset);
    await settle(20);
    final bp = tester.state<BlueprintSubEditorState>(find.byType(BlueprintSubEditor)).viewModel;
    for (var i = 0; i < 200 && bp.document.components.length < 2; i++) {
      await settle(2);
    }
    await tester.tap(find.text('3D Viewport'));
    await settle(6);
    LuminaStaticMeshComponent? chairMesh() => bp.preview.componentFor('chair') as LuminaStaticMeshComponent?;
    for (var i = 0; i < 400 && !(bp.preview.hasNativeWorld && (chairMesh()?.isLoaded ?? false)); i++) {
      await rec.hold(const Duration(milliseconds: 100));
    }
    expect(bp.preview.hasNativeWorld, isTrue);
    expect(chairMesh()?.isLoaded, isTrue, reason: '${bp.preview.diagnostics}');
    await rec.hold(const Duration(milliseconds: 800));

    // --- Add Component "col": Box Collision, then Sphere Collision -----------
    Future<LuminaBlueprintComponent> addFromMenu(String type) async {
      await tester.tap(find.byKey(const ValueKey('add_component_button')));
      await settle(10);
      await rec.typeText(find.byKey(const ValueKey('add_component_search')), 'col', perCharacter: const Duration(milliseconds: 120));
      await settle(6);
      for (final t in const ['Box', 'Sphere', 'Capsule', 'Cylinder', 'Cone', 'Convex']) {
        expect(find.byKey(ValueKey('add_component_Lumina${t}Component')), findsOneWidget, reason: '$t Collision offered');
      }
      await rec.hold(const Duration(milliseconds: 700));
      await tester.tap(find.byKey(ValueKey('add_component_$type')));
      await settle(10);
      return bp.getComponent(bp.selectedComponentId!)!;
    }

    Future<void> pickPreset(String name) async {
      await tester.ensureVisible(find.byKey(const ValueKey('bp_collision_preset')));
      await settle(4);
      await tester.tap(find.byKey(const ValueKey('bp_collision_preset')));
      await settle(12);
      await rec.hold(const Duration(milliseconds: 500));
      // The popup lists eight presets; a short window scrolls it.
      final item = find.byKey(ValueKey('bp_collision_preset_$name'));
      await tester.ensureVisible(item.last);
      await settle(4);
      await tester.tap(item.last);
      await settle(12);
      await rec.hold(const Duration(milliseconds: 600));
    }

    final box = await addFromMenu('LuminaBoxComponent');
    expect(box.type, 'LuminaBoxComponent');
    expect(box.properties['boxExtent'], [50.0, 50.0, 50.0]);
    bp.setProperty(box.id, 'location', [0.0, 0.0, 50.0]);
    await settle(6);
    // Widen it along X in Details.
    final extentX = find.byKey(ValueKey('${box.id}.boxExtent.0.${bp.componentTransformRevision}'));
    await tester.ensureVisible(extentX);
    await settle(4);
    await rec.typeText(extentX, '120', perCharacter: const Duration(milliseconds: 150));
    await settle(8);
    expect(bp.getComponent(box.id)!.properties['boxExtent'], [120.0, 50.0, 50.0]);
    await pickPreset('blockAll');
    expect(bp.getComponent(box.id)!.properties['preset'], 'blockAll');

    final sphere = await addFromMenu('LuminaSphereComponent');
    bp.setProperty(sphere.id, 'location', [0.0, 160.0, 60.0]);
    bp.setProperty(sphere.id, 'radius', 70.0);
    await settle(6);
    await pickPreset('trigger');
    final props = bp.getComponent(sphere.id)!.properties;
    expect(props['preset'], 'trigger');
    expect(props['responses'], {'worldStatic': 'ignore', 'worldDynamic': 'overlap', 'pawn': 'overlap'});
    RadioGroup<CollisionResponse> grid(String channel) =>
        tester.widget<RadioGroup<CollisionResponse>>(find.byKey(ValueKey('bp_collision_response_$channel')));
    expect(grid('pawn').enabled, isFalse, reason: 'a preset greys the grid');
    await tester.ensureVisible(find.byKey(const ValueKey('bp_collision_section')));
    await settle(6);
    await rec.hold(const Duration(milliseconds: 800));
    await shot('blueprint_collision_details_trigger_grid');

    await pickPreset('custom');
    expect(grid('pawn').enabled, isTrue);
    await tester.tap(find.byKey(const ValueKey('bp_collision_response_pawn_block')));
    await settle(10);
    await rec.hold(const Duration(milliseconds: 800));
    expect(bp.getComponent(sphere.id)!.properties['preset'], 'custom');
    expect((bp.getComponent(sphere.id)!.properties['responses'] as Map)['pawn'], 'block');
    await shot('blueprint_collision_details_custom_grid');

    // --- Both wireframes in the 3D Viewport -----------------------------------
    for (final id in [box.id, sphere.id]) {
      expect(bp.preview.overlays.where((s) => s.id == id && s.positions.isNotEmpty), hasLength(1), reason: id);
    }
    bp.selectComponent(box.id);
    await settle(10);
    await rec.hold(const Duration(milliseconds: 1500));
    final rect = tester.getRect(find.byType(SubEditor3DViewport));
    await rec.drag(rect.center + const Offset(-140, 10), rect.center + const Offset(120, 40), steps: 60);
    await rec.hold(const Duration(milliseconds: 1200));
    await shot('blueprint_collision_viewport_wireframes');

    expect(await tester.runAsync(bp.save), isTrue);
    final saved = readBlueprint(bp.assetPath);
    expect(saved.components.singleWhere((c) => c.id == box.id).properties['preset'], 'blockAll');
    expect(saved.components.singleWhere((c) => c.id == sphere.id).properties['preset'], 'custom');
    await rec.hold(const Duration(milliseconds: 600));
    final video = rec.save('blueprint editor: collision shapes and presets', usedAssets: usedAssets);
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
  }, timeout: const Timeout(Duration(minutes: 15)));

  testWidgets('blueprint editor: physics settings', (tester) async {
    // A launcher Third Person project with the real
    // chair GLB imported (test-assets/Props/Chair) and its Static Mesh Mass
    // set to 23 kg. BP_Chair: a Box collision sized to the chair with the
    // chair mesh under it. The Box's Physics section shows the mass
    // inherited from the mesh (greyed until Override Mass); Simulate Physics
    // on, saved. BP_Chair placed 150 cm above the floor ahead of the Player
    // Start falls in Play, and walking into it tips it over (GPU 1).
    final chairGlb = File('${SmokeArtifacts.testAssetsDir.absolute.path}/Props/Chair/chair_mountable.glb');
    expect(chairGlb.existsSync(), isTrue, reason: 'test-assets present');
    final usedAssets = [chairGlb.path];
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bp12_');
    addTearDown(() => root.deleteSync(recursive: true));
    const name = 'bp_physics_smoke';
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: name, widgetLibrary: 'flutter')))!;
    final imported = (await tester.runAsync(() => ImportAssetUseCase()(projectDir: projectDir, sourceFilePath: chairGlb.path)))!;
    expect(imported.isSuccess, isTrue, reason: imported.error);
    final meshPath = imported.asset!.relativePath;
    // The Static Mesh editor's Mass, as it saves it.
    final lmas = File('$projectDir/$meshPath');
    final meshAsset = LuminaAsset.fromBytes(lmas.readAsBytesSync());
    lmas.writeAsBytesSync(LuminaAsset(
      assetId: meshAsset.assetId,
      name: meshAsset.name,
      type: meshAsset.type,
      hasThumbnail: meshAsset.hasThumbnail,
      thumbnailPng: meshAsset.thumbnailPng,
      rawPayload: meshAsset.rawPayload,
      rawMatSource: meshAsset.rawMatSource,
      references: meshAsset.references,
      metadata: {...meshAsset.metadata, 'physics': jsonEncode({'massKg': 23.0, 'centerOfMassOffset': [0.0, 0.0, 0.0]})},
    ).toProtoBufferBytes());
    // The chair's bounds (glTF metres, Y up) → a Box in authoring cm, Z up.
    final mesh = (await tester.runAsync(() => GlbParserService.parseGlb(chairGlb.readAsBytesSync())))!;
    final half = [for (var i = 0; i < 3; i++) (mesh.maxBounds[i] - mesh.minBounds[i]) * 50.0];
    final center = [for (var i = 0; i < 3; i++) (mesh.maxBounds[i] + mesh.minBounds[i]) * 50.0];
    writeBlueprint(
      projectDir,
      'BP_Chair',
      LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
        LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
        LuminaBlueprintComponent(id: 'box', name: 'Box', type: 'LuminaBoxComponent', parentId: 'root', properties: {
          'boxExtent': [half[0], half[2], half[1]],
          'location': [center[0], -center[2], center[1]],
        }),
        LuminaBlueprintComponent(id: 'chair', name: 'Chair', type: 'LuminaStaticMeshComponent', parentId: 'box', properties: {
          'staticMeshAsset': meshPath,
          'location': [-center[0], center[2], -center[1]],
        }),
      ]),
    );
    // Placed 150 cm up, 3.5 m ahead of the Player Start.
    final manifest = Map<String, dynamic>.from(jsonDecode(File('$projectDir/$name.lmproject').readAsStringSync()) as Map);
    final levelPath = manifest['active_level'] as String;
    final level = LuminaLevelRepository(projectDir).load(levelPath)!;
    final start = level.actors.firstWhere((a) => a['type'] == 'PlayerStart');
    final startLoc = [for (final v in start['location'] as List) (v as num).toDouble()];
    level.actors = [
      ...level.actors,
      {
        'id': 'chair_01',
        'name': 'Chair_01',
        'type': 'Blueprint',
        'blueprintClass': 'contents/blueprints/BP_Chair.lmas',
        'location': [startLoc[0] + 350.0, startLoc[1], 150.0],
        'rotation': [0.0, 0.0, 0.0],
        'scale': [1.0, 1.0, 1.0],
      },
    ];
    LuminaLevelRepository(projectDir).save(level);

    final editor = EditorViewModel(initialProject: LuminaProject.fromMap(manifest), projectLocation: root.path);
    addTearDown(editor.dispose);
    await tester.runAsync(editor.ensureDefaultLevelAssets);
    editor.refreshAssets();

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
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
    ));
    await settle(40);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<void> shot(String name) async => SmokeArtifacts.saveScreenshot(
        name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
        usedAssets: usedAssets);
    await rec.hold(const Duration(milliseconds: 600));

    // --- BP_Chair's Box: the Physics section --------------------------------
    final asset = editor.realAssets.firstWhere((a) => a.relativePath == 'contents/blueprints/BP_Chair.lmas');
    editor.openSubEditorTab('Blueprint', asset: asset);
    await settle(20);
    final bp = tester.state<BlueprintSubEditorState>(find.byType(BlueprintSubEditor)).viewModel;
    for (var i = 0; i < 200 && bp.document.components.length < 3; i++) {
      await settle(2);
    }
    await tester.tap(find.text('3D Viewport'));
    await settle(6);
    LuminaStaticMeshComponent? chairMesh() => bp.preview.componentFor('chair') as LuminaStaticMeshComponent?;
    for (var i = 0; i < 400 && !(bp.preview.hasNativeWorld && (chairMesh()?.isLoaded ?? false)); i++) {
      await rec.hold(const Duration(milliseconds: 100));
    }
    expect(chairMesh()?.isLoaded, isTrue, reason: '${bp.preview.diagnostics}');
    bp.selectComponent('box');
    await settle(10);
    await tester.ensureVisible(find.byKey(const ValueKey('bp_physics_section')));
    await settle(6);
    final massText = tester
        .widget<EditableText>(find.descendant(of: find.byKey(const ValueKey('bp_physics_mass')), matching: find.byType(EditableText)))
        .controller
        .text;
    expect(massText, startsWith('23.0'), reason: 'inherited from the chair mesh');
    expect(find.text('Inherited from ${meshPath.split('/').last.replaceAll('.lmas', '')}'), findsOneWidget);
    await rec.hold(const Duration(milliseconds: 900));
    await shot('blueprint_physics_section_inherited_mass');
    await tester.tap(find.byKey(const ValueKey('bp_physics_simulate')));
    await settle(10);
    expect((bp.getComponent('box')!.properties['physics'] as Map)['simulate'], isTrue);
    expect(bp.preview.overlays.where((s) => s.id == 'box.com'), hasLength(1), reason: 'the centre-of-mass marker');
    await rec.hold(const Duration(milliseconds: 1200));
    await shot('blueprint_physics_section_simulate_on');
    expect(await tester.runAsync(bp.save), isTrue);
    await rec.hold(const Duration(milliseconds: 500));

    // --- Play: the chair falls, and the character tips it ------------------
    editor.selectTab(0);
    await settle(10);
    await tester.tap(find.byKey(const ValueKey('toolbar_play')));
    for (var i = 0; i < 100 && !editor.pieController.isPlaying; i++) {
      await settle(2);
    }
    final pie = editor.pieController;
    expect(pie.isPlaying, isTrue, reason: 'blocked: ${editor.playBlockers} error: ${pie.lastError}');
    final world = pie.game!.world!;
    final chair = world.persistentLevel.actors.firstWhere((a) => a.key == const LuminaObjectKey('chair_01')) as LuminaBlueprintInstance;
    final box = chair.blueprintComponents['box'] as LuminaBoxComponent;
    expect(box.isSimulatingPhysics, isTrue);
    expect(box.resolvedMassKg, 23.0);
    final dropFrom = box.worldLocation.y;
    for (var i = 0; i < 75; i++) {
      await settle(2);
      await rec.capture();
    }
    expect(dropFrom - box.worldLocation.y, greaterThan(100), reason: 'it fell (from $dropFrom to ${box.worldLocation.y})');
    double tilt() {
      final up = Vector3(0, 1, 0)..applyQuaternion(box.worldRotation);
      return math.acos(up.y.clamp(-1.0, 1.0)) * 180 / math.pi;
    }

    expect(tilt(), lessThan(5), reason: 'it landed upright');
    await shot('blueprint_physics_pie_chair_landed');
    final pawn = pie.possessedPawn!;
    var peak = 0.0;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    for (var i = 0; i < 70; i++) {
      // Face the chair while walking into it.
      final d = box.worldLocation - pawn.actorLocation;
      pie.game!.playerController!.controlRotation.y = math.atan2(d.x, -d.z) * 180 / math.pi;
      await settle(2);
      peak = math.max(peak, tilt());
      await rec.capture();
      if (peak > 45) break;
    }
    for (var i = 0; i < 8; i++) {
      await settle(2);
      peak = math.max(peak, tilt());
      await rec.capture();
    }
    await shot('blueprint_physics_pie_chair_tipped');
    // Keep walking over and past the toppled chair for a moment, then stop.
    for (var i = 0; i < 37; i++) {
      await settle(2);
      peak = math.max(peak, tilt());
      await rec.capture();
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    for (var i = 0; i < 60; i++) {
      await settle(2);
      peak = math.max(peak, tilt());
      await rec.capture();
    }
    expect(peak, greaterThan(30), reason: 'walking into it tipped it (peak ${peak.toStringAsFixed(1)}°)');
    await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
    await settle(10);
    await rec.hold(const Duration(milliseconds: 600));
    final video = rec.save('blueprint editor: physics settings', usedAssets: usedAssets);
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
  }, timeout: const Timeout(Duration(minutes: 15)));

  testWidgets('blueprint editor: level blueprint opens a placed door', (tester) async {
    // A launcher Third Person project (the real
    // `flutter create`, so Play Standalone can build it) with a placed BP_Door
    // (an AC unit from test-assets). The Level Blueprint opens from the
    // toolbar's Blueprints button right of Perspective; Door_01 selected in
    // the outliner becomes "Create a Reference to Door_01"; Level BeginPlay →
    // Door_01 → Call Open plus a swing timeline; Compile, Save into the level;
    // Play opens the door in the viewport (GPU 1) and Play Standalone runs the
    // built game's level script, which logs from the door.
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bp11_');
    addTearDown(() => root.deleteSync(recursive: true));
    const name = 'level_bp_smoke';
    final repo = ProjectRepository();
    await tester.runAsync(() async {
      await for (final p in repo.createProjectStream(
          projectName: name, projectLocation: root.path, template: kThirdPersonTemplateId, widgetLibrary: kUmgWidgetLibraryFlutter)) {
        debugPrint('[create] ${p.message}');
      }
    });
    final projectDir = '${root.path}/$name';
    expect(File('$projectDir/linux/CMakeLists.txt').existsSync(), isTrue);
    const levelPath = 'contents/levels/L_DefaultLevel.lmas';
    const doorPath = 'contents/blueprints/BP_Door.lmas';
    const logDoorId = 'fn:package:$name/door_log.dart#logDoor';
    final acUnit = '${SmokeArtifacts.testAssetsDir.absolute.path}/Props/AC_units/ac_unit_b_600x600.glb';
    final usedAssets = [acUnit];

    // The door logs to the game's stdout (Print String goes to the screen
    // and the VM log; the standalone process's output is the evidence).
    File('$projectDir/lib/door_log.dart').writeAsStringSync("""
import 'package:lumina/lumina_runtime.dart';

/// Writes a door event to the game's output.
@BlueprintCallable(category: 'Game|Door', keywords: ['door', 'log'])
void logDoor(LuminaActor self, String text) {
  print('[door] \${self.runtimeType} \$text');
}
""");
    const meshPath = 'contents/meshes/static/SM_DoorUnit.glb';
    File('$projectDir/$meshPath')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(File(acUnit).readAsBytesSync());
    // BP_Door: its custom event Open prints "Door opened" and logs "opened".
    final door = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
      LuminaBlueprintComponent(id: 'unit', name: 'DoorUnit', type: 'LuminaStaticMeshComponent', parentId: 'root', properties: {
        'staticMeshAsset': meshPath,
        'location': [0.0, 0.0, 0.0],
        'rotation': [0.0, 0.0, 0.0],
        'scale': [1.0, 1.0, 1.0],
      }),
    ]);
    final doorCtx = LuminaBlueprintTypeContext.forDocument(door, className: 'BP_Door');
    door.eventGraph.nodes.addAll([
      LuminaBlueprintNodeLibrary.place('custom_event', nodeId: 'open', x: 0, y: 0, literals: {'name': 'Open'}, context: doorCtx),
      LuminaBlueprintNodeLibrary.place('print_string', nodeId: 'opened', x: 320, y: 0, literals: {'in_string': 'Door opened', 'key': 'door'}, context: doorCtx),
      LuminaBlueprintNode(id: 'log', registryId: logDoorId, title: 'Log Door', x: 640, y: 0, literals: {'text': 'opened'}),
    ]);
    door.eventGraph.wires.addAll(const [
      LuminaBlueprintWire(id: 'd0', fromNodeId: 'open', fromPinId: 'exec_out', toNodeId: 'opened', toPinId: 'exec_in'),
      LuminaBlueprintWire(id: 'd1', fromNodeId: 'opened', fromPinId: 'exec_out', toNodeId: 'log', toPinId: 'exec_in'),
    ]);
    writeBlueprint(projectDir, 'BP_Door', door);
    // Door_01 in front of the player start.
    final level = LuminaLevelRepository(projectDir).load(levelPath)!;
    final start = level.actors.firstWhere((a) => a['type'] == 'PlayerStart');
    final startLoc = [for (final v in start['location'] as List) (v as num).toDouble()];
    level.actors = [
      ...level.actors,
      {
        'id': 'door_01',
        'name': 'Door_01',
        'type': 'Blueprint',
        'blueprintClass': doorPath,
        'location': [startLoc[0] + 450.0, startLoc[1], 0.0],
        'rotation': [0.0, 0.0, 0.0],
        'scale': [1.0, 1.0, 1.0],
      },
    ];
    LuminaLevelRepository(projectDir).save(level);

    final project = (await tester.runAsync(() => repo.loadProject('$projectDir/$name.lmproject')))!;
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    addTearDown(() => vm.standalone.stop());
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
    await settle(30);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<File> shot(String name) async => SmokeArtifacts.saveScreenshot(
        name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
        usedAssets: usedAssets);
    for (var i = 0; i < 600 && vm.blueprintFunctions.functions.isEmpty; i++) {
      await settle(2);
    }
    expect(vm.blueprintFunctions.functions.map((f) => f.spec.id), contains(logDoorId), reason: '${vm.blueprintFunctions.diagnostics}');
    // BP_Door is a class of the project's generated game.
    final doorVm = BlueprintEditorViewModel(assetPath: '$projectDir/$doorPath');
    addTearDown(doorVm.dispose);
    await tester.runAsync(doorVm.load);
    expect(await tester.runAsync(doorVm.compile), isTrue, reason: '${doorVm.diagnostics}');
    expect(File('$projectDir/lib/actors/bp_door.dart').existsSync(), isTrue);
    await rec.hold(const Duration(milliseconds: 600));

    // --- Door_01 selected in the outliner; Blueprints ▸ Open Level Blueprint
    vm.selectActorById('door_01');
    await settle(6);
    await tester.tap(find.byKey(const ValueKey('toolbar_blueprints')));
    await settle(8);
    await rec.hold(const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('blueprints_open_level_blueprint')), findsOneWidget);
    await shot('blueprint_level_toolbar_blueprints_menu');
    await tester.tap(find.byKey(const ValueKey('blueprints_open_level_blueprint')));
    await settle(20);
    expect(vm.currentTab.title, 'L_DefaultLevel (Level Blueprint)');
    final bp = vm.levelBlueprintEditor()!;
    expect(find.text('LEVEL BLUEPRINT · L_DefaultLevel'), findsOneWidget);
    expect(find.text('3D Viewport'), findsNothing);
    await rec.hold(const Duration(milliseconds: 700));

    final canvas = find.byType(BlueprintGraphCanvas);
    BlueprintGraphCanvasState state() => tester.state<BlueprintGraphCanvasState>(canvas);
    Offset topLeft() => tester.getTopLeft(canvas);
    Offset screen(double x, double y) => topLeft() + Offset(x, y) * state().zoom + state().panOffset;
    Offset pin(LuminaBlueprintNode n, String pinId, {required bool output}) =>
        topLeft() + state().pinScreenPosition(n.id, pinId, output: output)!;

    Future<LuminaBlueprintNode> placeAt(double x, double y, String key, {String? query, String? screenshot}) async {
      state().frameCanvasPoint(Offset(x + 300, y + 100));
      await settle(2);
      await tester.tapAt(screen(x, y), buttons: kSecondaryButton);
      await settle();
      await rec.capture();
      if (query != null) {
        await rec.typeText(find.byKey(const ValueKey('palette_search')), query, perCharacter: const Duration(milliseconds: 40));
        await settle();
      }
      await rec.hold(const Duration(milliseconds: 500));
      if (screenshot != null) await shot(screenshot);
      final before = bp.graphNodes.map((n) => n.id).toSet();
      await tester.tap(find.byKey(ValueKey('palette_entry_$key')));
      await settle();
      await rec.capture();
      return bp.graphNodes.firstWhere((n) => !before.contains(n.id));
    }

    // Right-click with Door_01 selected: "Create a Reference to Door_01" first.
    final doorRef = await placeAt(40, 260, 'create_reference_Door_01', screenshot: 'blueprint_level_create_reference_menu');
    expect(doorRef.title, 'Door_01');
    expect(bp.eventGraph.pin(doorRef.id, 'return_value', output: true)!.objectClass, 'Actor:BP_Door');
    final begin = await placeAt(0, 0, 'event_level_begin_play', query: 'level beginplay');

    // Off Door_01's pin: the context palette offers BP_Door's Open.
    state().frameCanvasPoint(const Offset(250, 200));
    await settle(2);
    await rec.drag(pin(doorRef, 'return_value', output: true), screen(380, 60), steps: 12);
    await settle();
    expect(find.text('Node Palette — Context Sensitive'), findsOneWidget);
    await rec.typeText(find.byKey(const ValueKey('palette_search')), 'open', perCharacter: const Duration(milliseconds: 40));
    await settle();
    await rec.hold(const Duration(milliseconds: 500));
    var before = bp.graphNodes.map((n) => n.id).toSet();
    await tester.tap(find.byKey(const ValueKey('palette_entry_call_custom_event_Actor:BP_Door_Open')));
    await settle();
    final open = bp.graphNodes.firstWhere((n) => !before.contains(n.id));
    expect(bp.graphWires.where((w) => w.fromNodeId == doorRef.id && w.toNodeId == open.id && w.toPinId == 'target'), hasLength(1));
    await rec.drag(pin(begin, 'exec_out', output: true), pin(open, 'exec_in', output: false), steps: 10);
    await settle();
    expect(bp.graphWires.where((w) => w.fromNodeId == begin.id && w.toNodeId == open.id), hasLength(1));

    // Then the door swings 90° over a second (a Timeline turning Door_01).
    final g = bp.eventGraph;
    final swing = g.addNode('timeline', const Offset(700, 0), literals: {
      'name': 'DoorSwing',
      'length': 1.0,
      'tracks': [
        {
          'name': 'Yaw',
          'type': 'float',
          'keys': [
            {'time': 0.0, 'value': 0.0},
            {'time': 1.0, 'value': 90.0},
          ],
        },
      ],
    })!;
    final rot = g.addNode('make_rotator', const Offset(1000, 220))!;
    final turn = g.addNode('set_actor_rotation', const Offset(1300, 0))!;
    expect(g.addWire(fromNodeId: open.id, fromPinId: 'exec_out', toNodeId: swing.id, toPinId: 'play_from_start'), isNotNull);
    expect(g.addWire(fromNodeId: swing.id, fromPinId: 'update', toNodeId: turn.id, toPinId: 'exec_in'), isNotNull);
    expect(g.addWire(fromNodeId: doorRef.id, fromPinId: 'return_value', toNodeId: turn.id, toPinId: 'target'), isNotNull);
    expect(g.addWire(fromNodeId: swing.id, fromPinId: 'Yaw', toNodeId: rot.id, toPinId: 'z'), isNotNull);
    expect(g.addWire(fromNodeId: rot.id, fromPinId: 'return_value', toNodeId: turn.id, toPinId: 'new_rotation'), isNotNull);
    state().frameCanvasPoint(const Offset(650, 150));
    await settle(6);
    await rec.hold(const Duration(milliseconds: 600));

    // --- Compile, Save into the level --------------------------------------
    await tester.tap(find.byKey(const ValueKey('bp_compile')));
    for (var i = 0; i < 100 && bp.compileStatus != BlueprintCompileStatus.upToDate && bp.compileStatus != BlueprintCompileStatus.error; i++) {
      await settle(2);
    }
    expect(bp.compileStatus, BlueprintCompileStatus.upToDate, reason: '${bp.diagnostics}');
    await tester.tap(find.byKey(const ValueKey('bp_save')));
    await settle(6);
    expect(bp.isDirty, isFalse);
    final stored = LuminaLevelRepository(projectDir).loadLevelBlueprint(levelPath);
    expect(stored.blueprint.eventGraph.nodes.map((n) => n.id), containsAll([begin.id, doorRef.id, open.id, swing.id]));
    await rec.hold(const Duration(milliseconds: 800));
    await shot('blueprint_level_editor_tab');

    // --- Play: the door opens in the viewport -------------------------------
    vm.selectTab(0);
    await settle(10);
    await tester.tap(find.byKey(const ValueKey('toolbar_play')));
    for (var i = 0; i < 100 && !vm.pieController.isPlaying; i++) {
      await settle(2);
    }
    final pie = vm.pieController;
    expect(pie.isPlaying, isTrue, reason: 'blocked: ${vm.playBlockers} error: ${pie.lastError}');
    final world = pie.game!.gameInstance.world!;
    expect(world.persistentLevel.scriptActor, isA<LuminaBlueprintLevelScript>());
    final doorActor = world.persistentLevel.actors.firstWhere((a) => a.key == const LuminaObjectKey('door_01'));
    final startRotation = doorActor.actorRotation.clone();
    var sawOpened = false;
    for (var i = 0; i < 60; i++) {
      await settle(2);
      sawOpened |= world.screenMessages.values.any((m) => m.text == 'Door opened');
      await rec.capture();
    }
    final turned = (doorActor.actorRotation - startRotation).length;
    debugPrint('[bp11_smoke] door opened: $sawOpened, rotation delta $turned; ${BlueprintPieDebugger.instance.targets.keys}');
    expect(sawOpened, isTrue, reason: 'Level BeginPlay called Open on Door_01');
    expect(turned, greaterThan(0.3), reason: 'the level timeline swung the door');
    expect(BlueprintPieDebugger.instance.targets.keys, contains(levelPath), reason: 'the debugger follows the level script');
    await shot('blueprint_level_pie_door_open');
    await rec.hold(const Duration(milliseconds: 800));
    await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
    await settle(30);
    expect(pie.isPlaying, isFalse);

    // --- Play Standalone: the built game runs the level script -------------
    final logTab = find.text('Output Log').first;
    await tester.tap(logTab);
    await settle(4);
    await tester.tap(find.byKey(const ValueKey('play_mode_dropdown')));
    await settle(6);
    await rec.hold(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('play_mode_standalone')));
    await settle(4);
    expect(File('$projectDir/lib/levels/l_default_level.dart').readAsStringSync(), contains('class _LDefaultLevelScript'));
    final sw = Stopwatch()..start();
    String? line() => vm.standalone.output.where((l) => l.contains('[door]')).firstOrNull;
    var sawBuilding = false;
    while (sw.elapsed < const Duration(minutes: 12) && line() == null) {
      sawBuilding |= vm.standalone.state == StandaloneState.building;
      if (sawBuilding && vm.standalone.state == StandaloneState.idle) break; // failed
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await rec.captureIfChanged();
    }
    debugPrint('[bp11_smoke] standalone ${vm.standalone.state} after ${sw.elapsed.inSeconds} s: ${line()}');
    expect(line(), isNotNull, reason: 'the built game logs from the door:\n${vm.standalone.output.reversed.take(40).toList().reversed.join('\n')}');
    expect(line(), contains('opened'));
    await settle(10);
    await rec.hold(const Duration(milliseconds: 1200));
    final standaloneShot = await shot('blueprint_level_standalone_output_log');
    // The game's line in the sidecar, next to its screenshot.
    final sidecar = File(standaloneShot.path.replaceAll(RegExp(r'\.png$'), '.json'));
    final meta = jsonDecode(sidecar.readAsStringSync()) as Map<String, dynamic>;
    meta['standaloneLog'] = line();
    sidecar.writeAsStringSync(jsonEncode(meta));
    await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
    for (var i = 0; i < 200 && vm.standalone.isActive; i++) {
      await settle(2);
    }
    expect(vm.standalone.isActive, isFalse);
    await rec.hold(const Duration(milliseconds: 800));

    final video = rec.save('blueprint editor: level blueprint opens a placed door', usedAssets: usedAssets);
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
  }, timeout: const Timeout(Duration(minutes: 20)));

  testWidgets('blueprint editor: a point light component lights a sunless level in Play', (tester) async {
    // A launcher Third Person project with its sun and sky deleted and the
    // real red fuel barrel imported. BP_Lantern draws the barrel; in the
    // Blueprint editor a Point Light is added from Add Component and given a
    // warm colour, 60 000 lm and a 15 m radius, 1.5 m above the barrel.
    // BP_Lantern placed ahead of the Player Start lights the dark level in
    // Play (the frame is measured with the light on and off), and the light
    // moves with the actor.
    final barrelGlb = File('${SmokeArtifacts.testAssetsDir.absolute.path}/Props/Barrels/fuel_barrel_red.glb');
    expect(barrelGlb.existsSync(), isTrue, reason: 'test-assets present');
    final usedAssets = [barrelGlb.path];
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bp_lamp_');
    addTearDown(() => root.deleteSync(recursive: true));
    const name = 'bp_lamp_smoke';
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: name, widgetLibrary: 'flutter')))!;
    final imported = (await tester.runAsync(() => ImportAssetUseCase()(projectDir: projectDir, sourceFilePath: barrelGlb.path)))!;
    expect(imported.isSuccess, isTrue, reason: imported.error);
    writeBlueprint(
      projectDir,
      'BP_Lantern',
      LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
        LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
        LuminaBlueprintComponent(id: 'barrel', name: 'Barrel', type: 'LuminaStaticMeshComponent', parentId: 'root', properties: {
          'staticMeshAsset': imported.asset!.relativePath,
        }),
      ]),
    );
    // The level without its sun and sky, BP_Lantern 4 m ahead of the Player Start.
    final manifest = Map<String, dynamic>.from(jsonDecode(File('$projectDir/$name.lmproject').readAsStringSync()) as Map);
    final level = LuminaLevelRepository(projectDir).load(manifest['active_level'] as String)!;
    final start = level.actors.firstWhere((a) => a['type'] == 'PlayerStart');
    final startLoc = [for (final v in start['location'] as List) (v as num).toDouble()];
    level.actors = [
      for (final a in level.actors)
        if (a['name'] != 'DirectionalLight_Sun' && a['name'] != 'SkyAtmosphere_Env') a,
      {
        'id': 'lantern_01',
        'name': 'Lantern_01',
        'type': 'Blueprint',
        'blueprintClass': 'contents/blueprints/BP_Lantern.lmas',
        'location': [startLoc[0] + 400.0, startLoc[1], 0.0],
        'rotation': [0.0, 0.0, 0.0],
        'scale': [1.0, 1.0, 1.0],
      },
    ];
    LuminaLevelRepository(projectDir).save(level);

    final editor = EditorViewModel(initialProject: LuminaProject.fromMap(manifest), projectLocation: root.path);
    addTearDown(editor.dispose);
    await tester.runAsync(editor.ensureDefaultLevelAssets);
    editor.refreshAssets();
    expect(editor.actors.where((a) => a.type.contains('Light') || a.type == 'Environment'), isEmpty);

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
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
    ));
    await settle(40);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<Uint8List> capture() => SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(milliseconds: 600));

    // --- BP_Lantern: Add Component → Point Light, set in Details -------------
    final asset = editor.realAssets.firstWhere((a) => a.relativePath == 'contents/blueprints/BP_Lantern.lmas');
    editor.openSubEditorTab('Blueprint', asset: asset);
    await settle(20);
    final bp = tester.state<BlueprintSubEditorState>(find.byType(BlueprintSubEditor)).viewModel;
    for (var i = 0; i < 200 && bp.document.components.length < 2; i++) {
      await settle(2);
    }
    await tester.tap(find.text('3D Viewport'));
    await settle(6);
    LuminaStaticMeshComponent? barrelMesh() => bp.preview.componentFor('barrel') as LuminaStaticMeshComponent?;
    for (var i = 0; i < 400 && !(bp.preview.hasNativeWorld && (barrelMesh()?.isLoaded ?? false)); i++) {
      await rec.hold(const Duration(milliseconds: 100));
    }
    expect(barrelMesh()?.isLoaded, isTrue, reason: '${bp.preview.diagnostics}');
    await tester.tap(find.byKey(const ValueKey('add_component_button')));
    await settle(10);
    await rec.typeText(find.byKey(const ValueKey('add_component_search')), 'light', perCharacter: const Duration(milliseconds: 120));
    await settle(6);
    await rec.hold(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const ValueKey('add_component_LuminaPointLightComponent')));
    await settle(10);
    final lamp = bp.getComponent(bp.selectedComponentId!)!;
    expect(lamp.type, 'LuminaPointLightComponent');
    expect(lamp.properties['attenuationRadius'], 1000.0);
    bp.beginComponentTransformDrag(lamp.id);
    bp.updateComponentTransform(lamp.id, location: [0.0, 0.0, 150.0]);
    bp.endComponentTransformDrag();
    bp.commitProperty(lamp.id, 'intensity', 60000.0);
    bp.commitProperty(lamp.id, 'attenuationRadius', 1500.0);
    await settle(8);
    // The colour typed into Details' colour field.
    final colorField = find.descendant(of: find.byKey(ValueKey('bp_prop_${lamp.id}_colorHex')), matching: find.byType(EditableText));
    await tester.ensureVisible(colorField);
    await settle(4);
    await tester.tap(colorField);
    await settle(2);
    await tester.enterText(colorField, '#FFB347');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(8);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(8);
    expect(bp.getComponent(lamp.id)!.properties['colorHex'], '#FFB347');
    await rec.hold(const Duration(milliseconds: 1200));
    SmokeArtifacts.saveScreenshot('blueprint_point_light_component_details', await capture(), usedAssets: usedAssets);
    expect(bp.preview.componentFor(lamp.id), isA<LuminaPointLightComponent>(), reason: 'the preview builds the light');
    expect(await tester.runAsync(bp.save), isTrue);
    await rec.hold(const Duration(milliseconds: 500));

    // --- Play: the lantern lights the dark level ----------------------------
    editor.selectTab(0);
    await settle(10);
    await tester.tap(find.byKey(const ValueKey('toolbar_play')));
    for (var i = 0; i < 100 && !editor.pieController.isPlaying; i++) {
      await settle(2);
    }
    final pie = editor.pieController;
    expect(pie.isPlaying, isTrue, reason: 'blocked: ${editor.playBlockers} error: ${pie.lastError}');
    final world = pie.game!.world!;
    final lantern = world.persistentLevel.actors.firstWhere((a) => a.key == const LuminaObjectKey('lantern_01')) as LuminaBlueprintInstance;
    final light = lantern.blueprintComponents[lamp.id] as LuminaPointLightComponent;
    for (var i = 0; i < 40; i++) {
      await settle(2);
      await rec.capture();
    }
    expect(light.lightEntity, isNotNull, reason: 'a native Filament light');
    expect(light.intensity, 60000.0);
    expect(light.falloffRadius, 1500.0);
    final lm = FilamentLightManager(world.filamentEngine);
    List<double> nativePos() => lm.getPosition(light.lightEntity!).sublist(0, 3);

    /// Mean luminance (0–255) of the lower half of the game view.
    double viewLuma(Uint8List png) {
      final image = img.decodePng(png)!;
      final r = tester.getRect(find.byType(ViewportWidget));
      var sum = 0.0;
      var n = 0;
      for (var y = (r.top + r.height / 2).round(); y < r.bottom.round() - 2; y += 4) {
        for (var x = r.left.round() + 2; x < r.right.round() - 2; x += 4) {
          final p = image.getPixel(x, y);
          sum += 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;
          n++;
        }
      }
      return sum / n;
    }

    final litPng = await capture();
    final lit = viewLuma(litPng);
    SmokeArtifacts.saveScreenshot('blueprint_point_light_pie_lit', litPng, usedAssets: usedAssets, metrics: {'view_luma': lit.toStringAsFixed(1)});
    light.visible = false;
    for (var i = 0; i < 20; i++) {
      await settle(2);
      await rec.capture();
    }
    final darkPng = await capture();
    final dark = viewLuma(darkPng);
    SmokeArtifacts.saveScreenshot('blueprint_point_light_pie_off', darkPng, usedAssets: usedAssets, metrics: {'view_luma': dark.toStringAsFixed(1)});
    debugPrint('[bp_lamp_smoke] view luma lit ${lit.toStringAsFixed(1)}, off ${dark.toStringAsFixed(1)}');
    expect(dark, lessThan(10), reason: 'no sun, no sky, no lamp: dark');
    expect(lit, greaterThan(math.max(dark * 4, dark + 10)), reason: 'the Blueprint light lights the level');
    light.visible = true;
    for (var i = 0; i < 20; i++) {
      await settle(2);
      await rec.capture();
    }

    // --- The light follows its actor ----------------------------------------
    final from = lantern.actorLocation.clone();
    for (var i = 1; i <= 60; i++) {
      lantern.actorLocation = from + Vector3(0, 0, -5.0 * i); // runtime −Z is authoring +Y
      await settle(2);
      await rec.capture();
    }
    final expected = light.worldLocation;
    expect(expected.z, closeTo(from.z - 300, 1e-3));
    final pos = nativePos();
    expect(pos, [closeTo(expected.x, 1e-2), closeTo(expected.y, 1e-2), closeTo(expected.z, 1e-2)],
        reason: 'the Filament light moved with the actor');
    final movedPng = await capture();
    SmokeArtifacts.saveScreenshot('blueprint_point_light_pie_moved', movedPng, usedAssets: usedAssets,
        metrics: {'view_luma': viewLuma(movedPng).toStringAsFixed(1), 'light_position': pos.map((v) => v.toStringAsFixed(1)).join(', ')});
    // A flickering lantern: the intensity is set live while it plays.
    for (var i = 0; i < 60; i++) {
      light.intensity = 60000.0 * (0.55 + 0.45 * math.cos(i * math.pi / 15));
      await settle(2);
      await rec.capture();
    }
    light.intensity = 60000.0;
    await settle(4);
    await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
    await settle(20);
    await rec.hold(const Duration(milliseconds: 800));
    final video = rec.save('blueprint editor: a point light component lights a sunless level in Play', usedAssets: usedAssets);
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
  }, timeout: const Timeout(Duration(minutes: 15)));

  testWidgets('blueprint editor: spring arm Use Pawn Control Rotation', (tester) async {
    // The launcher's Third Person project. BP_ThirdPersonCharacter's
    // CameraBoom shows Use Pawn Control Rotation (on) in Details; switched
    // off and saved, looking up in Play pitches the controller but not the
    // camera (the character turns with the controller's yaw, never its
    // pitch); switched back on, the camera pitches with the mouse.
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bp_arm_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: 'bp_arm_smoke', widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(Map<String, dynamic>.from(
        jsonDecode(File('$projectDir/bp_arm_smoke.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();

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
    await rec.hold(const Duration(milliseconds: 600));

    final asset = vm.realAssets.firstWhere((a) => a.relativePath == LuminaThirdPersonContent.characterBlueprintPath);
    Finder useControlSwitch() => find.descendant(
        of: find.ancestor(of: find.text('Use Pawn Control Rotation'), matching: find.byType(Row)).first,
        matching: find.byType(Switch));

    /// Opens the character, selects CameraBoom, sets the switch to [on] in
    /// Details and saves.
    Future<void> setUseControl(bool on, String shotName) async {
      vm.openSubEditorTab('Blueprint', asset: asset);
      await settle(20);
      final bp = tester.state<BlueprintSubEditorState>(find.byType(BlueprintSubEditor)).viewModel;
      for (var i = 0; i < 200 && bp.getComponent('boom') == null; i++) {
        await settle(2);
      }
      bp.selectComponent('boom');
      await settle(10);
      await tester.ensureVisible(find.text('Use Pawn Control Rotation'));
      await settle(6);
      await rec.hold(const Duration(milliseconds: 800));
      if (tester.widget<Switch>(useControlSwitch()).value != on) {
        await tester.tap(useControlSwitch());
        await settle(8);
      }
      expect(bp.getComponent('boom')!.properties['usePawnControlRotation'], on);
      expect(tester.widget<Switch>(useControlSwitch()).value, on);
      await rec.hold(const Duration(milliseconds: 800));
      await shot(shotName);
      expect(await tester.runAsync(bp.save), isTrue);
      await rec.hold(const Duration(milliseconds: 400));
    }

    double angleDiff(double a, double b) => ((a - b + 540) % 360 - 180).abs();

    /// Plays, moves the mouse up the view and returns how far the
    /// controller and the camera pitched (degrees).
    Future<({double control, double camera})> playAndLook(bool expectUseControl, String shotName) async {
      vm.selectTab(0);
      await settle(10);
      await tester.tap(find.byKey(const ValueKey('toolbar_play')));
      for (var i = 0; i < 100 && !vm.pieController.isPlaying; i++) {
        await settle(2);
      }
      await settle(30);
      final pie = vm.pieController;
      expect(pie.isPlaying, isTrue, reason: 'blocked: ${vm.playBlockers} error: ${pie.lastError}');
      final pawn = pie.possessedPawn! as LuminaBlueprintInstance;
      final boom = pawn.blueprintComponents['boom'] as LuminaSpringArmComponent;
      expect(boom.bUsePawnControlRotation, expectUseControl);
      double cameraPitch() => luminaQuaternionToControlRotation(boom.socketWorldRotation).x;
      final controlBefore = pie.game!.playerController!.controlRotation.x;
      final cameraBefore = cameraPitch();
      final viewRect = tester.getRect(find.byType(ViewportWidget));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: viewRect.center);
      await settle(4);
      for (var i = 0; i < 30; i++) {
        await mouse.moveTo(viewRect.center + Offset(0, -6.0 * (i + 1)));
        await settle(2);
        await rec.capture();
      }
      // The rotation lag catches up.
      for (var i = 0; i < 40; i++) {
        await settle(2);
        await rec.capture();
      }
      await mouse.removePointer();
      await shot(shotName);
      final turned = (
        control: angleDiff(pie.game!.playerController!.controlRotation.x, controlBefore),
        camera: angleDiff(cameraPitch(), cameraBefore),
      );
      debugPrint('[bp_arm_smoke] usePawnControlRotation=$expectUseControl: control '
          'pitched ${turned.control.toStringAsFixed(1)} deg, camera ${turned.camera.toStringAsFixed(1)} deg');
      await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
      await settle(30);
      expect(pie.isPlaying, isFalse);
      return turned;
    }

    await setUseControl(false, 'blueprint_spring_arm_use_pawn_control_rotation_off_details');
    final off = await playAndLook(false, 'blueprint_spring_arm_pie_look_with_arm_fixed');
    expect(off.control, greaterThan(10), reason: 'the mouse pitches the controller');
    expect(off.camera, lessThan(2), reason: 'an arm without Use Pawn Control Rotation keeps the camera still');

    await setUseControl(true, 'blueprint_spring_arm_use_pawn_control_rotation_on_details');
    final on = await playAndLook(true, 'blueprint_spring_arm_pie_look_with_arm_following');
    expect(on.control, greaterThan(10), reason: 'the mouse pitches the controller');
    expect(on.camera, closeTo(on.control, 3), reason: 'the arm follows the control rotation');

    await rec.hold(const Duration(milliseconds: 800));
    final video = rec.save('blueprint editor: spring arm Use Pawn Control Rotation');
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
  }, timeout: const Timeout(Duration(minutes: 15)));
}

/// The canvas y below every node and comment box of [vm]'s Event Graph, as
/// the Blueprint editor draws them, rounded up to 100: where a smoke adds its
/// own nodes under the template graph.
double templateGraphBottom(BlueprintEditorViewModel vm) {
  final bottom = vm.eventGraph.nodes.map((n) => BlueprintNodeLayout.of(vm.eventGraph, n).rect.bottom).reduce(math.max);
  return (bottom / 100).ceil() * 100.0;
}
