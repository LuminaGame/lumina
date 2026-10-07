import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_transform.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/play_blocked_dialog.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_compile_status.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../helpers/blueprint_test_project.dart';
import '../helpers/scaffold_game_project.dart';
import '../helpers/temp_project.dart';

/// Blueprints in Play-In-Editor on a real Third Person project scaffolded
/// from the template (its character, game mode and ABP_Character are
/// Blueprints), played headless through the editor's PieController.
void main() {
  late Directory root;
  late String dir;
  const characterPath = LuminaThirdPersonContent.characterBlueprintPath;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_bp05_');
    dir = await scaffoldGameProject(root, name: 'bp_play', widgetLibrary: 'flutter');
  });
  // The editors' git probe may still hold the folder on Windows.
  tearDownAll(() => deleteTempProject(root));
  tearDown(() => BlueprintPieDebugger.instance.clear());

  LuminaProject manifest() =>
      LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/bp_play.lmproject').readAsStringSync()) as Map));

  Future<EditorViewModel> editorFor(WidgetTester tester, {LuminaProject? project}) async {
    final vm = EditorViewModel(
        initialProject: project ?? manifest(), projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();
    return vm;
  }

  Future<BlueprintEditorViewModel> openBlueprint(WidgetTester tester, EditorViewModel vm, String path) async {
    final bp = BlueprintEditorViewModel(assetPath: '$dir/$path');
    await tester.runAsync(bp.load);
    vm.bindTabSession(path, notifier: bp, save: bp.save, isDirty: () => bp.isDirty);
    return bp;
  }

  void run(LuminaWorld world, int frames) {
    for (var i = 0; i < frames; i++) {
      world.tick(1 / 60);
    }
  }

  testWidgets('Play possesses BP_ThirdPersonCharacter in the VM; W walks it exactly as the template character does',
      (tester) async {
    final vm = await editorFor(tester);
    expect(vm.project.mapsAndModes.defaultGameMode, LuminaThirdPersonContent.gameModeBlueprintPath);
    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');

    final world = LuminaWorld();
    final game = vm.pieController.startHeadlessForTest(world);
    final pawn = game.possessedPawn!;
    expect(pawn, isA<LuminaBlueprintCharacter>());
    expect((pawn as LuminaBlueprintInstance).blueprintClass.name, 'BP_ThirdPersonCharacter');
    expect(vm.pieController.pawnClassLabel, 'BP_ThirdPersonCharacter (VM)');
    expect(game.playerPawn, isNull, reason: 'the Dart template character is not used');
    expect(game.playerCamera, isNotNull, reason: 'Play looks through the Blueprint\'s FollowCamera');

    // The same script on the Dart template character, the parity reference.
    final template = EditorPieGame(
      vm.actors.map((a) => EditorActorNode.fromMap(a.toMap())).toList(),
      templateKind: GameTemplateKind.thirdPerson,
      input: vm.pieController.boundInputForProject(),
    );
    final templateWorld = LuminaWorld();
    template.mountIntoWorldForTest(templateWorld);
    expect(template.playerPawn, isNotNull);

    // The pawn's Mesh plays ABP_Character in the VM.
    final anim = (pawn as LuminaBlueprintInstance).blueprintComponents['mesh.anim'];
    expect(anim, isA<LuminaAnimBlueprintInstance>());
    expect((anim as LuminaAnimBlueprintInstance).stateMachine.name, 'Locomotion');

    run(world, 30);
    run(templateWorld, 30);
    expect(anim.currentState, 'Idle');
    final start = pawn.actorLocation.clone();
    game.injectKeyDown(LuminaKey.keyW);
    template.injectKeyDown(LuminaKey.keyW);
    run(world, 90);
    run(templateWorld, 90);
    final moved = pawn.actorLocation - start;
    expect(moved.length, greaterThan(100), reason: 'W walks the Blueprint character');
    final a = pawn.actorLocation;
    final b = template.playerPawn!.actorLocation;
    expect((a - b).length, lessThan(1e-3), reason: 'Blueprint $a vs template $b');
    expect(anim.currentState, 'Walk', reason: 'ABP_Character follows the walking pawn');
    vm.pieController.stopHeadlessForTest();
  });

  testWidgets('LookSensitivity 0 in the open editor compiles on Play, and the mouse no longer turns the view',
      (tester) async {
    final vm = await editorFor(tester);
    final bp = await openBlueprint(tester, vm, characterPath);
    expect(bp.setVariableDefault('LookSensitivity', 0.0), isTrue);
    expect(bp.compileStatus, BlueprintCompileStatus.dirty);

    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    expect(bp.compileStatus, BlueprintCompileStatus.upToDate, reason: 'Play compiled the edited Blueprint first');
    expect(bp.isDirty, isTrue, reason: 'Play does not save; it plays the editor\'s document');

    final world = LuminaWorld();
    final game = vm.pieController.startHeadlessForTest(world);
    run(world, 10);
    final before = game.playerController!.controlRotation.clone();
    for (var i = 0; i < 30; i++) {
      game.injectMouseDelta(40, 10);
      run(world, 1);
    }
    expect((game.playerController!.controlRotation - before).length, lessThan(1e-9));
    vm.pieController.stopHeadlessForTest();
  });

  testWidgets('a float → vector wire stops Play; the dialog names the Blueprint and node and frames it', (tester) async {
    final vm = await editorFor(tester);
    final bp = await openBlueprint(tester, vm, characterPath);
    bp.addVariable('Offset', 'Vector');
    final get = bp.addGraphNode(LuminaBlueprintNodeLibrary.variableGet, const Offset(0, 1400), literals: {'variable': 'Offset'})!;
    final teleport = bp.addGraphNode('set_actor_location', const Offset(300, 1400))!;
    expect(bp.addGraphWire(fromNodeId: get.id, fromPinId: 'value', toNodeId: teleport.id, toPinId: 'new_location'), isNotNull);
    bp.setVariableType('Offset', 'Float');
    // A retype drops the refused wire; a document
    // edited by hand can still carry one, which is what must block Play.
    expect(bp.graphWires.where((w) => w.toNodeId == teleport.id), isEmpty);
    bp.document.eventGraph.wires.add(LuminaBlueprintWire(
        id: 'stale', fromNodeId: get.id, fromPinId: 'value', toNodeId: teleport.id, toPinId: 'new_location'));

    expect(await tester.runAsync(vm.requestPlay), isFalse);
    expect(vm.isPlaying, isFalse);
    final blocker = vm.playBlockers.singleWhere((b) => b.nodeId == teleport.id);
    expect(blocker.blueprintName, 'BP_ThirdPersonCharacter');
    expect(blocker.nodeTitle, 'SetActorLocation');

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: PlayBlockedDialog(
          blockers: vm.playBlockers,
          onOpen: (b) => openBlueprintAtNode(vm, b.blueprintPath, b.nodeId),
          onClose: () {},
        ),
      ),
    ));
    expect(find.text('BP_ThirdPersonCharacter'), findsWidgets);
    expect(find.text('SetActorLocation'), findsOneWidget);
    final row = vm.playBlockers.indexOf(blocker);
    await tester.tap(find.byKey(ValueKey('play_blocker_$row')));
    await tester.pump();
    expect(vm.openTabs.last.category, 'Blueprint');
    expect(vm.openTabs.last.asset?.relativePath, characterPath);

    // The Blueprint editor that opens takes the request and frames the node.
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: BlueprintSubEditor(assetName: 'BP_ThirdPersonCharacter', assetPath: bp.assetPath, viewModel: bp)),
    ));
    await tester.pump();
    await tester.pump();
    expect(bp.selectedNodeIds, {teleport.id});
    expect(BlueprintNavigation.instance.pending, isNull);
  });

  testWidgets('a placed BP_Crate draws its mesh where PIE spawns it', (tester) async {
    final barrel = File('${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb');
    final mesh = 'contents/meshes/static/SM_Barrel.glb';
    File('$dir/$mesh')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(barrel.readAsBytesSync());
    writeBlueprint(
      dir,
      'BP_Crate',
      LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
        LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
        LuminaBlueprintComponent(id: 'crate', name: 'Crate', type: 'LuminaStaticMeshComponent', parentId: 'root', properties: {
          'staticMeshAsset': mesh,
          'location': [0.0, 0.0, 25.0],
          'rotation': [0.0, 0.0, 45.0],
        }),
      ]),
    );
    final vm = await editorFor(tester);
    final asset = vm.realAssets.firstWhere((a) => a.relativePath == 'contents/blueprints/BP_Crate.lmas');
    await tester.runAsync(() => vm.spawnActorFromAsset(asset, location: [300.0, 0.0, 50.0]));
    final placed = vm.actors.firstWhere((a) => a.blueprintClass == asset.relativePath);
    expect(placed.type, 'Blueprint');
    expect(placed.meshData, isNotNull, reason: 'the viewport draws the class\'s mesh');
    expect(placed.toMap()['blueprintClass'], asset.relativePath, reason: 'saved in metadata.actors[]');
    final drawn = EditorTransforms.meshMatrix(placed);

    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    final world = LuminaWorld();
    vm.pieController.startHeadlessForTest(world);
    final runtime = world.persistentLevel.actors.firstWhere((a) => a.key == LuminaObjectKey(placed.id));
    expect(runtime, isA<LuminaBlueprintActor>());
    expect(runtime.actorLocation, LuminaAxes.location([300.0, 0.0, 50.0]));
    final crate = (runtime as LuminaBlueprintInstance).blueprintComponents['crate'] as LuminaStaticMeshComponent;
    // Same place and orientation as the editor draws it:
    // the mesh's root in the viewport is the component's world transform
    // times the glTF metre → cm unit scale.
    final world4 = crate.worldTransform;
    expect((world4.getTranslation() - drawn.getTranslation()).length, lessThan(1e-6));
    final u = EditorTransforms.assetUnitScaleFor(placed);
    final a = world4.getRotation().transformed(Vector3(1, 0, 0));
    final b = (drawn.getRotation()..scale(1 / u)).transformed(Vector3(1, 0, 0));
    expect((a - b).length, lessThan(1e-6));
    vm.pieController.stopHeadlessForTest();
  });

  testWidgets('Maps & Modes Default Pawn Class BP_Other replaces the game mode\'s pawn; clearing it restores it',
      (tester) async {
    writeBlueprint(dir, 'BP_Other', BlueprintEditorViewModel.createDefaultDocument('BP_Other'));
    const otherPath = 'contents/blueprints/BP_Other.lmas';
    final settings = ProjectSettingsViewModel(projectDirPath: dir);
    await tester.runAsync(settings.load);
    expect(settings.gameModeClasses, contains(LuminaThirdPersonContent.gameModeBlueprintPath));
    expect(settings.pawnClasses, containsAll(['', characterPath, otherPath]));

    Future<LuminaProject> applyPawn(String path) async {
      settings.setDefaultPawnClass(path);
      expect(await tester.runAsync(settings.apply), isTrue);
      return manifest();
    }

    final withOther = await applyPawn(otherPath);
    expect(withOther.mapsAndModes.defaultPawnClass, otherPath, reason: 'persisted in the manifest');
    final vm = await editorFor(tester, project: withOther);
    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    var game = vm.pieController.startHeadlessForTest(LuminaWorld());
    expect((game.possessedPawn as LuminaBlueprintInstance).blueprintClass.name, 'BP_Other');
    vm.pieController.stopHeadlessForTest();

    // Cleared in Project Settings and applied to the open editor.
    vm.applyProjectSettings(await applyPawn(''));
    expect(vm.project.mapsAndModes.defaultPawnClass, isEmpty);
    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    game = vm.pieController.startHeadlessForTest(LuminaWorld());
    expect((game.possessedPawn as LuminaBlueprintInstance).blueprintClass.name, 'BP_ThirdPersonCharacter');
    vm.pieController.stopHeadlessForTest();
  });

  testWidgets('a GameMode Blueprint saves parentClass LuminaGameMode with its Default Pawn Class, and no .dart beside it',
      (tester) async {
    final vm = await editorFor(tester);
    await tester.runAsync(() => vm.createBlueprintWithParent(name: 'BP_MyGameMode', parentClass: 'LuminaGameMode'));
    final path = '$dir/contents/blueprints/BP_MyGameMode.lmas';
    final doc = readBlueprint(path);
    expect(doc.parentClass, 'LuminaGameMode');
    expect(doc.classDefaults.containsKey('defaultPawnClass'), isTrue);
    expect(doc.components, isEmpty);
    expect(
        Directory('$dir/contents').listSync(recursive: true).where((f) => f.path.endsWith('.dart')), isEmpty);

    // Its Class Defaults pick the pawn among Pawn / Character Blueprints.
    final bp = BlueprintEditorViewModel(assetPath: path);
    await tester.runAsync(bp.load);
    expect(bp.pawnBlueprints, contains(characterPath));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: BlueprintSubEditor(assetName: 'BP_MyGameMode', assetPath: path, viewModel: bp)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gm_default_pawn_select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gm_default_pawn_item_BP_ThirdPersonCharacter.lmas')).last);
    await tester.pumpAndSettle();
    expect(bp.document.classDefaults['defaultPawnClass'], characterPath);
  });

  testWidgets('with the Blueprint editor open during Play, Space lights IA_Jump Started → Jump within one frame',
      (tester) async {
    final vm = await editorFor(tester);
    final bp = await openBlueprint(tester, vm, characterPath);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: BlueprintSubEditor(assetName: 'BP_ThirdPersonCharacter', assetPath: bp.assetPath, viewModel: bp)),
    ));
    await tester.pump();

    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    final world = LuminaWorld();
    final game = vm.pieController.startHeadlessForTest(world);
    await tester.pump();
    final recorder = bp.eventGraph.debug;
    expect(recorder, isNotNull, reason: 'the open editor follows the possessed pawn');
    run(world, 30);

    final jumpInput = bp.graphNodes.firstWhere(
        (n) => n.registryId == LuminaBlueprintNodeLibrary.enhancedInputAction && n.literals['action'] == 'IA_Jump');
    final jump = bp.graphNodes.firstWhere((n) => n.registryId == 'jump');
    final wire = bp.graphWires.firstWhere((w) => w.fromNodeId == jumpInput.id && w.toNodeId == jump.id);
    expect(recorder!.activeNodeIds.contains(jump.id), isFalse);

    game.injectKeyDown(LuminaKey.keySpace);
    run(world, 1);
    expect(recorder.activeNodeIds, containsAll([jumpInput.id, jump.id]));
    expect(recorder.activeWireIds, contains(wire.id));
    expect(recorder.intensity(jump.id), greaterThan(0.5));
    await tester.pump();
    vm.pieController.stopHeadlessForTest();
    expect(bp.eventGraph.debug, isNull, reason: 'Stop ends the highlighting');
  });
}
