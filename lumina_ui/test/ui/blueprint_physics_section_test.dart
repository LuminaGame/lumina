import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/property_editors/physics_section_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_preview_scene.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';

/// The Physics section of collision and static mesh
/// components in the Blueprint editor — mass inherited from the static
/// mesh's `.lmas` (the Static Mesh editor's Mass), greyed until Override
/// Mass, typed values, undo, the `.lmas` round trip and the centre-of-mass
/// marker; on a real project on disk.
void main() {
  late BlueprintTestProject project;
  const chairMesh = 'contents/meshes/static/SM_Chair.lmas';

  setUpAll(() {
    project = BlueprintTestProject.create(name: 'PhysicsProject');
    Directory('${project.dir}/contents/meshes/static').createSync(recursive: true);
    // SM_Chair as the Static Mesh editor saves it: Mass 23 kg.
    File('${project.dir}/$chairMesh').writeAsBytesSync(LuminaAsset(
      assetId: 'sm_chair',
      name: 'SM_Chair',
      type: AssetType.filamesh,
      metadata: {
        'physics': jsonEncode({'massKg': 23.0, 'centerOfMassOffset': [0.0, 0.0, 5.0]}),
      },
    ).toProtoBufferBytes());
  });
  tearDownAll(() {
    LuminaBlueprintComponents.meshPhysicsResolver = null;
    project.dispose();
  });

  /// BP_Chair: root, the chair mesh, a Box collision under it.
  Future<BlueprintEditorViewModel> openChair(String name) async {
    final path = writeBlueprint(
        project.dir,
        name,
        LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
          LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
          LuminaBlueprintComponent(
              id: 'chair', name: 'Chair', type: 'LuminaStaticMeshComponent', parentId: 'root', properties: {'staticMeshAsset': chairMesh}),
          LuminaBlueprintComponent(id: 'box', name: 'Box', type: 'LuminaBoxComponent', parentId: 'chair', properties: {
            'boxExtent': [30.0, 30.0, 45.0],
            'location': [0.0, 0.0, 45.0],
          }),
        ]));
    final vm = BlueprintEditorViewModel(assetPath: path);
    await vm.load();
    return vm;
  }

  Future<void> pumpEditor(WidgetTester tester, BlueprintEditorViewModel vm) async {
    tester.view.physicalSize = const Size(1600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: BlueprintSubEditor(assetName: vm.fileBasename, assetPath: vm.assetPath, viewModel: vm, showPreviewViewport: false),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Finder field(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(EditableText));

  Future<void> type(WidgetTester tester, Finder f, String text) async {
    await tester.tap(f);
    await tester.pump();
    await tester.enterText(f, text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('BP_Chair\'s Box shows Physics: Mass reads 23.0 kg from SM_Chair, disabled until Override Mass; 5 kg saves; undo restores',
      (tester) async {
    final vm = (await tester.runAsync(() => openChair('BP_Chair')))!;
    addTearDown(vm.dispose);
    await pumpEditor(tester, vm);
    vm.selectComponent('box');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('bp_physics_section')), findsOneWidget);
    expect(find.text('PHYSICS'), findsOneWidget);
    final massField = tester.widget<EditableText>(field('bp_physics_mass'));
    expect(massField.controller.text, startsWith('23.0'), reason: 'inherited from SM_Chair');
    expect(find.text('Inherited from SM_Chair'), findsOneWidget);
    // Disabled until Override Mass: the Mass row ignores input.
    expect(
        find.ancestor(of: find.byKey(const ValueKey('bp_physics_mass')), matching: find.byType(IgnorePointer)).evaluate().any(
            (e) => (e.widget as IgnorePointer).ignoring),
        isTrue);

    await tapKey(tester, 'bp_physics_override_mass');
    expect(vm.transactions.undoLabel, 'Undo Edit Physics of Box');
    await type(tester, field('bp_physics_mass'), '5');
    final physics = vm.getComponent('box')!.properties['physics'] as Map;
    expect(physics['overrideMass'], isTrue);
    expect(physics['massKg'], 5.0);
    expect((physics['meshPhysics'] as Map)['massKg'], 23.0, reason: 'the inherited mass is baked for the generated game');

    await tester.runAsync(vm.save);
    final saved = readBlueprint(vm.assetPath).components.firstWhere((c) => c.id == 'box').properties['physics'] as Map;
    expect(saved['overrideMass'], isTrue);
    expect(saved['massKg'], 5.0);
    // lumina builds it with that mass.
    final built = LuminaBlueprintComponents.construct(LuminaActor(), readBlueprint(vm.assetPath).components)['box'] as LuminaBoxComponent;
    expect(built.resolvedMassKg, 5.0);

    vm.undo();
    await tester.pumpAndSettle();
    expect((vm.getComponent('box')!.properties['physics'] as Map)['massKg'], isNot(5.0));
    vm.undo();
    await tester.pumpAndSettle();
    expect(vm.getComponent('box')!.properties['physics'], isNull, reason: 'back to no Physics section edits');
  });

  testWidgets('Simulate off greys the dynamic fields; gravity, damping, friction, restitution and locks persist', (tester) async {
    final vm = (await tester.runAsync(() => openChair('BP_ChairSettings')))!;
    addTearDown(vm.dispose);
    await pumpEditor(tester, vm);
    vm.selectComponent('box');
    await tester.pumpAndSettle();

    Opacity rowOpacity(String key) =>
        tester.widget<Opacity>(find.ancestor(of: find.byKey(ValueKey(key)), matching: find.byType(Opacity)).first);
    expect(rowOpacity('bp_physics_linearDamping').opacity, 0.5, reason: 'greyed while Simulate Physics is off');
    expect(find.byKey(const ValueKey('bp_physics_linearDamping')), findsOneWidget, reason: 'greyed, not hidden');

    await tapKey(tester, 'bp_physics_simulate');
    expect(rowOpacity('bp_physics_linearDamping').opacity, 1.0);
    await tapKey(tester, 'bp_physics_gravity');
    await type(tester, field('bp_physics_linearDamping'), '0.2');
    await type(tester, field('bp_physics_angularDamping'), '0.4');
    await type(tester, field('bp_physics_friction'), '0.3');
    await type(tester, field('bp_physics_restitution'), '0.6');
    await tapKey(tester, 'bp_physics_lock_position_z');
    await tapKey(tester, 'bp_physics_lock_rotation_x');
    await tester.runAsync(vm.save);

    final physics = readBlueprint(vm.assetPath).components.firstWhere((c) => c.id == 'box').properties['physics'] as Map<String, dynamic>;
    expect(physics['simulate'], isTrue);
    expect(physics['enableGravity'], isFalse);
    expect(physics['linearDamping'], 0.2);
    expect(physics['angularDamping'], 0.4);
    expect(physics['friction'], 0.3);
    expect(physics['restitution'], 0.6);
    expect(physics['locks'], {
      'position': [false, false, true],
      'rotation': [true, false, false],
    });
    final box = LuminaBoxComponent()..applyPhysicsJson(physics);
    expect(box.simulatePhysics && !box.enableGravity && box.lockPositionZ && box.lockRotationX, isTrue);
    expect(box.physicalMaterial!.restitution, 0.6);
  });

  test('the static mesh component has the section too; the viewport marks the selected simulating body\'s centre of mass',
      () async {
    final vm = await openChair('BP_ChairCom');
    addTearDown(vm.dispose);
    expect(BlueprintEditorViewModel.isPhysicsCapable('LuminaStaticMeshComponent'), isTrue);
    expect(BlueprintEditorViewModel.isPhysicsCapable('LuminaSpringArmComponent'), isFalse);
    expect(vm.inheritedPhysics('chair')?.physics.massKg, 23.0);
    expect(vm.physicsMeshOf('box')?.id, 'chair', reason: 'a collision component inherits from its parent mesh');
    expect(vm.setComponentPhysics('box', {'simulate': true}), isTrue);
    vm.selectComponent('box');
    final marker = vm.preview.overlays.where((s) => s.id == 'box.com').toList();
    expect(marker, hasLength(1), reason: 'the centre-of-mass cross');
    // The box's centre plus the mesh's 5 cm (authoring Z = runtime y) offset.
    final box = vm.preview.componentFor('box') as LuminaBoxComponent;
    final com = BlueprintPreviewScene.centerOfMassOf(box);
    expect(com.y - box.worldLocation.y, closeTo(5.0, 1e-6));
    final xs = [for (var i = 0; i < marker.single.positions.length; i += 3) marker.single.positions[i]];
    expect((xs.reduce((a, b) => a + b) / xs.length - com.x).abs(), lessThan(1e-6));
    vm.selectComponent('chair');
    expect(vm.preview.overlays.where((s) => s.id == 'box.com'), isEmpty, reason: 'only for the selected component');
    expect(PhysicsJson.effectiveMass(const {}, vm.inheritedPhysics('box')?.physics, 1.0), 23.0);
  });
}
