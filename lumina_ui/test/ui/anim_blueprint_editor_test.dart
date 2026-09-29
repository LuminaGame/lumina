import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_compile_status.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/anim_blueprint/anim_blueprint.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blend_space/blend_space.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/anim_test_project.dart';
import '../helpers/blueprint_test_project.dart';
import '../helpers/scaffold_game_project.dart';

/// The Animation Blueprint editor on a real scaffolded Third Person project (the
/// Quinn mannequin and its clips on disk), with no mocks.
void main() {
  late Directory root;
  late String dir;
  const quinn = LuminaThirdPersonContent.projectMeshAssetPath;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_abp_editor_');
    dir = await scaffoldGameProject(root, name: 'abp_project', widgetLibrary: 'flutter');
    ensureTemplateAnimAssets(dir);
  });
  tearDownAll(() => root.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: child)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<AnimBlueprintEditorViewModel> openAbp(WidgetTester tester, String relPath) async {
    // The Filament viewport never settles in a widget test; the preview runs
    // in a world without a renderer (the smoke renders it on GPU 1).
    await pump(
      tester,
      AnimBlueprintSubEditor(
        assetName: AnimGraphAssetService.baseName(relPath),
        assetPath: '$dir/$relPath',
        showPreviewViewport: false,
      ),
    );
    return tester.state<AnimBlueprintSubEditorState>(find.byType(AnimBlueprintSubEditor)).viewModel;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  Future<void> dragMouse(WidgetTester tester, Offset from, Offset to, {int steps = 8}) async {
    final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    for (var i = 1; i <= steps; i++) {
      await g.moveTo(Offset.lerp(from, to, i / steps)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('creating an Animation Blueprint for Quinn writes ABP_*.lmas; it opens with Output Pose and Blueprint Update Animation',
      (tester) async {
    String? created;
    await pump(
      tester,
      CreateAnimAssetDialog(projectDir: dir, kind: AnimAssetKind.animBlueprint, onCreated: (p) => created = p, onCancel: () {}),
    );
    expect(find.text('SKM_Superhero_Female'), findsWidgets, reason: 'the project mesh is the default target');
    await tester.enterText(find.byKey(const ValueKey('anim_asset_name')), 'ABP_Hero');
    await tester.tap(find.byKey(const ValueKey('anim_asset_create')));
    await tester.pump();
    expect(created, 'contents/animations/SKM_Superhero_Female/ABP_Hero.lmas');
    final asset = LuminaAsset.fromBytes(File('$dir/$created').readAsBytesSync());
    expect(asset.type, AssetType.animBlueprint);
    expect(asset.metadata[AnimGraphAssetService.targetMeshKey], quinn);
    expect(asset.references.single.assetPath, quinn);
    final doc = LuminaAnimBlueprintDocument.fromJson(jsonDecode(utf8.decode(asset.rawPayload!)) as Map<String, dynamic>);
    expect(doc.targetMesh, quinn);

    await openAbp(tester, created!);
    expect(find.byKey(const ValueKey('animgraph_output_pose')), findsOneWidget);
    expect(find.text('Output Pose'), findsOneWidget);
    expect(find.text('Locomotion'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('abp_tab_EventGraph')));
    await tester.pump();
    expect(find.text('Event Blueprint Update Animation'), findsOneWidget);
    expect(find.text('EventGraph'), findsWidgets);
    await close(tester);
  });

  testWidgets('Add State ×2 and a transition are saved; undo removes the transition, then the state', (tester) async {
    final path = AnimGraphAssetService.createAnimBlueprint(dir, name: 'ABP_States', meshRelPath: quinn);
    final vm = await openAbp(tester, path);
    await tester.tap(find.byKey(const ValueKey('animgraph_open_machine')));
    await tester.pump();
    expect(find.byKey(const ValueKey('abp_state_machine')), findsOneWidget);
    expect(find.text('AnimGraph'), findsWidgets);

    final graph = find.byType(AnimStateMachineGraph);
    AnimStateMachineGraphState sm() => tester.state<AnimStateMachineGraphState>(graph);
    Future<void> addStateAt(Offset local) async {
      await tester.tapAt(tester.getTopLeft(graph) + local, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sm_menu_add_state')));
      await tester.pumpAndSettle();
    }

    // Empty canvas above and below Idle (the graph frames its states on open).
    await addStateAt(sm().toScreen(const Offset(420, -100)));
    await addStateAt(sm().toScreen(const Offset(420, 200)));
    expect(vm.machine!.states.map((s) => s.name), ['Idle', 'NewState', 'NewState2']);

    await dragMouse(tester, tester.getTopLeft(graph) + sm().handleCenter('NewState')!,
        tester.getTopLeft(graph) + sm().stateCenter('NewState2')!);
    expect(vm.machine!.transitions.map((t) => '${t.from}>${t.to}'), ['NewState>NewState2']);
    expect(find.byKey(const ValueKey('transition_newstate_to_newstate2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('abp_save')));
    await tester.pump();
    final saved = AnimGraphAssetService.readAnimBlueprint(dir, path)!;
    expect(saved.stateMachine!.states.map((s) => s.name), containsAll(['NewState', 'NewState2']));
    expect(saved.stateMachine!.transitions.single.id, 'newstate_to_newstate2');
    expect(saved.stateMachine!.transitions.single.resultNode, isNotNull, reason: 'a new rule starts with its Result');

    vm.undo();
    await tester.pump();
    expect(vm.machine!.transitions, isEmpty);
    expect(vm.machine!.states, hasLength(3));
    vm.undo();
    await tester.pump();
    expect(vm.machine!.states.map((s) => s.name), ['Idle', 'NewState']);
    await close(tester);
  });

  testWidgets('a rule IsFalling == true built by dragging the variable compiles clean; an unconnected Result names the transition',
      (tester) async {
    final path = AnimGraphAssetService.createAnimBlueprint(dir, name: 'ABP_Rules', meshRelPath: quinn);
    final vm = await openAbp(tester, path);

    // My Blueprint: + → rename → Bool.
    await tester.tap(find.byKey(const ValueKey('var_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('var_menu_NewVar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('var_menu_rename')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('var_rename_field')), 'IsFalling');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('var_type_IsFalling')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('var_type_item_Bool')).last);
    await tester.pumpAndSettle();
    expect(vm.document.variables.single.type, LuminaPinType.boolean);

    vm.addState(const Offset(420, 60), base: 'InAir');
    final id = vm.addTransition('Idle', 'InAir')!;
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('details_open_rule')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('abp_rule_$id')), findsOneWidget);
    expect(find.text('Idle → InAir'), findsWidgets, reason: 'the breadcrumb names the transition');

    await tester.runAsync(vm.compile);
    await tester.pump();
    expect(vm.compileStatus, BlueprintCompileStatus.error);
    final unconnected = vm.compileRows.singleWhere((r) => r.diagnostic.isError);
    expect(unconnected.diagnostic.message, contains("Transition '$id' (Idle → InAir)"));
    expect(unconnected.diagnostic.message, contains('Result is not connected'));

    // Ctrl-drag IsFalling onto the rule graph: a Get; wire it to Result.
    final canvas = find.byType(BlueprintGraphCanvas);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await dragMouse(tester, tester.getCenter(find.byKey(const ValueKey('var_row_IsFalling'))),
        tester.getTopLeft(canvas) + const Offset(120, 140));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    final rule = vm.ruleEditor(id);
    final get = rule.nodes.firstWhere((n) => n.registryId == LuminaBlueprintNodeLibrary.variableGet);
    expect(get.title, 'Get IsFalling');
    final state = tester.state<BlueprintGraphCanvasState>(canvas);
    await dragMouse(tester, tester.getTopLeft(canvas) + state.pinScreenPosition(get.id, 'value', output: true)!,
        tester.getTopLeft(canvas) + state.pinScreenPosition('result', 'can_enter', output: false)!);
    expect(rule.wires.single.toNodeId, 'result');

    await tester.runAsync(vm.compile);
    await tester.pump();
    expect(vm.compileRows, isEmpty, reason: '${vm.compileRows.map((r) => r.diagnostic)}');
    expect(vm.compileStatus, BlueprintCompileStatus.upToDate);
    expect(File('$dir/lib/anim/abp_rules.dart').readAsStringSync(), contains('class AbpRules extends LuminaAnimBlueprintInstance'));
    await close(tester);
  });

  testWidgets('Blend Space: two dropped clips are saved; the preview point near the walk plays the walk clip', (tester) async {
    final path = AnimGraphAssetService.createBlendSpace(dir, name: 'BS_Test', meshRelPath: quinn);
    await pump(tester, BlendSpaceSubEditor(assetName: 'BS_Test', assetPath: '$dir/$path', showPreviewViewport: false));
    final vm = tester.state<BlendSpaceSubEditorState>(find.byType(BlendSpaceSubEditor)).viewModel;
    expect(vm.clips, contains('Walk_Fwd_Loop'));
    final grid = find.byType(BlendSpaceGrid);
    BlendSpaceGridState g() => tester.state<BlendSpaceGridState>(grid);

    await dragMouse(tester, tester.getCenter(find.byKey(const ValueKey('bs_clip_Idle_Loop'))), g().globalOf(0, 0));
    await dragMouse(tester, tester.getCenter(find.byKey(const ValueKey('bs_clip_Walk_Fwd_Loop'))), g().globalOf(0, 250));
    expect(vm.document.samples.map((s) => (s.clip, s.x, s.y)),
        [('Idle_Loop', 0.0, 0.0), ('Walk_Fwd_Loop', 0.0, 250.0)]);

    await tester.tap(find.byKey(const ValueKey('bs_save')));
    await tester.pump();
    final saved = AnimGraphAssetService.readBlendSpace(dir, path)!;
    expect(saved.samples.map((s) => (s.clip, s.x, s.y)), [('Idle_Loop', 0.0, 0.0), ('Walk_Fwd_Loop', 0.0, 250.0)]);

    await dragMouse(tester, g().globalOf(-90, 100), g().globalOf(0, 240));
    expect(vm.previewPoint.$1, closeTo(0, 1.0));
    expect(vm.previewPoint.$2, closeTo(240, 1.0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(vm.previewClip, 'Walk_Fwd_Loop', reason: 'the preview mesh plays the nearest sample');
    expect(find.textContaining('→  Walk_Fwd_Loop'), findsOneWidget);
    await close(tester);
  });

  testWidgets('ABP_Character previews GroundSpeed 250 / Direction 90 as the strafe-right walk; IsFalling switches to FallLoop',
      (tester) async {
    final vm = await openAbp(tester, LuminaThirdPersonContent.projectAnimBlueprintPath);
    await tester.pump(const Duration(milliseconds: 200));
    expect(vm.previewState, 'Idle', reason: vm.previewError ?? '');

    await tester.tap(find.byKey(const ValueKey('override_toggle_GroundSpeed')));
    await tester.pump();
    expect(vm.overrides.containsKey('GroundSpeed'), isTrue);
    vm.setOverride('GroundSpeed', 250.0);
    vm.setOverride('Direction', 90.0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(vm.previewState, 'Walk');
    expect(vm.previewClip, 'Walk_Right_Loop');

    await tester.tap(find.byKey(const ValueKey('animgraph_open_machine')));
    await tester.pump();
    expect(find.descendant(of: find.byKey(const ValueKey('anim_state_Walk')), matching: find.byKey(const ValueKey('anim_state_active_marker'))),
        findsOneWidget);

    // Walk leaves the ground into Jump (IsRising) or
    // FallLoop (dropped off: IsFalling and not IsRising); ABP_Character also has
    // Land, IdleBreak, Dash and WallJump.
    expect(vm.machine!.states.map((s) => s.name),
        containsAll(['Idle', 'IdleBreak', 'Walk', 'Jump', 'FallLoop', 'Land', 'Dash', 'WallJump']));
    vm.setOverride('IsFalling', true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(vm.previewState, 'FallLoop');
    expect(find.descendant(of: find.byKey(const ValueKey('anim_state_FallLoop')), matching: find.byKey(const ValueKey('anim_state_active_marker'))),
        findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('anim_state_Walk')), matching: find.byKey(const ValueKey('anim_state_active_marker'))),
        findsNothing);

    // The stand-in owner drives the real update graph once nothing is pinned.
    vm.clearOverride('GroundSpeed');
    vm.clearOverride('Direction');
    vm.clearOverride('IsFalling');
    vm.setOwner(speed: 250, direction: -90, falling: false);
    await tester.pump(const Duration(milliseconds: 600));
    expect(vm.previewState, 'Walk');
    expect(vm.previewClip, 'Walk_Left_Loop');
    await close(tester);
  });

  testWidgets("a Skeletal Mesh component's Anim Class lists only its mesh's ABPs and saves the path", (tester) async {
    // A second skeletal mesh with its own Animation Blueprint.
    final other = '$dir/contents/meshes/skeletal/SKM_Other.lmas';
    File('$dir/$quinn').copySync(other);
    final otherAbp = AnimGraphAssetService.createAnimBlueprint(dir,
        name: 'ABP_Other', meshRelPath: 'contents/meshes/skeletal/SKM_Other.lmas');
    expect(otherAbp, isNotEmpty);

    final doc = BlueprintEditorViewModel.createDefaultDocument('BP_AnimHero');
    doc.components.firstWhere((c) => c.name == 'Mesh').properties['skeletalMeshAsset'] = quinn;
    final bpPath = writeBlueprint(dir, 'BP_AnimHero', doc);
    final vm = BlueprintEditorViewModel(assetPath: bpPath);
    await tester.runAsync(vm.load);
    await pump(tester, BlueprintSubEditor(assetName: 'BP_AnimHero', assetPath: bpPath, viewModel: vm));
    await tester.tap(find.text('Mesh'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('anim_class_select')));
    await tester.tap(find.byKey(const ValueKey('anim_class_select')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('anim_class_item_ABP_Character.lmas')), findsOneWidget);
    expect(find.byKey(const ValueKey('anim_class_item_ABP_Other.lmas')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('anim_class_item_ABP_Character.lmas')));
    await tester.pumpAndSettle();
    final mesh = vm.document.components.firstWhere((c) => c.name == 'Mesh');
    expect(mesh.properties['animClass'], LuminaThirdPersonContent.projectAnimBlueprintPath);
    expect(mesh.properties['animMode'], 'Use Animation Blueprint');

    await tester.runAsync(vm.save);
    final stored = readBlueprint(bpPath).components.firstWhere((c) => c.name == 'Mesh');
    expect(stored.properties['animClass'], LuminaThirdPersonContent.projectAnimBlueprintPath);

    // The game: compiling generates the ABP class and the Blueprint uses it.
    expect(await tester.runAsync(vm.compile), isTrue, reason: '${vm.diagnostics}');
    expect(File('$dir/lib/anim/abp_character.dart').existsSync(), isTrue);
    expect(File('$dir/lib/actors/bp_anim_hero.dart').readAsStringSync(), contains('AbpCharacter'));

    // PIE runs Blueprints in lumina's VM: the saved path resolves to the VM's
    // Animation Blueprint class, which animates the mesh component.
    final abp = AnimGraphAssetService.readAnimBlueprint(dir, stored.properties['animClass'] as String)!;
    // The project's blend spaces (BS_Walk, and BS_Locomotion the Walk state plays).
    final spaces = {
      for (final path in LuminaThirdPersonContent.blendSpaces.keys) path: AnimGraphAssetService.readBlendSpace(dir, path)!,
    };
    final animClass = LuminaAnimBlueprintClass.fromDocument(abp, name: 'ABP_Character', blendSpaces: spaces);
    final cls = LuminaBlueprintClass.fromDocument(readBlueprint(bpPath),
        name: 'BP_AnimHero', animBlueprints: (p) => p == stored.properties['animClass'] ? animClass.factory : null);
    expect(cls.diagnostics.where((d) => d.message.contains('Animation Blueprint')), isEmpty);
    final actor = cls.instantiate();
    expect(actor.components.whereType<LuminaAnimBlueprintInstance>(), hasLength(1));
  });

  testWidgets('target skeletal mesh can be changed in Animation Blueprint editor details panel', (tester) async {
    // Scaffold an extra skeletal mesh in the project
    const mannyRel = 'contents/meshes/skeletal/SKM_Manny.lmas';
    final mannyFile = File('$dir/$mannyRel')..parent.createSync(recursive: true);
    mannyFile.writeAsBytesSync(LuminaAsset(
      assetId: 'skm_manny_test',
      name: 'SKM_Manny',
      type: AssetType.filameshSk,
      references: const [],
    ).toProtoBufferBytes());

    final abpPath = 'contents/animations/SKM_Superhero_Female/ABP_TargetMeshTest.lmas';
    AnimGraphAssetService.createAnimBlueprint(dir, name: 'ABP_TargetMeshTest', meshRelPath: quinn);

    final vm = await openAbp(tester, abpPath);
    expect(vm.targetMesh, quinn);
    expect(vm.availableSkeletalMeshes.any((m) => m.relativePath == mannyRel), isTrue);

    // Verify Target Skeletal Mesh select widget exists in details panel
    expect(find.byKey(const ValueKey('abp_target_mesh_select')), findsOneWidget);
    expect(find.text('Target Skeletal Mesh'), findsOneWidget);

    // Change target mesh via ViewModel
    vm.setTargetMesh(mannyRel);
    await tester.pump();

    expect(vm.targetMesh, mannyRel);
    expect(vm.document.targetMesh, mannyRel);
    expect(vm.isDirty, isTrue);

    // Undo should restore previous mesh
    vm.undo();
    await tester.pump();
    expect(vm.targetMesh, quinn);

    // Redo should apply new mesh again
    vm.redo();
    await tester.pump();
    expect(vm.targetMesh, mannyRel);

    // Save and verify disk asset has updated target mesh
    await tester.runAsync(vm.save);
    final diskAsset = LuminaAsset.fromBytes(File('$dir/$abpPath').readAsBytesSync());
    expect(diskAsset.metadata[AnimGraphAssetService.targetMeshKey], mannyRel);
    final diskDoc = LuminaAnimBlueprintDocument.fromJson(jsonDecode(utf8.decode(diskAsset.rawPayload!)) as Map<String, dynamic>);
    expect(diskDoc.targetMesh, mannyRel);

    await close(tester);
  });
}
