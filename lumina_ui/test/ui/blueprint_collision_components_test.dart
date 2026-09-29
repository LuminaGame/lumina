import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';

/// Box / sphere / capsule / cylinder / cone / convex
/// collision components in the Blueprint editor — the Add Component menu,
/// shape fields, preview wireframes, the Collision section (presets, the
/// response grid under Custom) and the `.lmas` round trip, on a real project
/// with the real SM_Casino_Chair FBX (UCX_ hulls) imported through lumina.
void main() {
  final chairFbx = File('${Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets'}/FBX/StaticMeshes/SM_Casino_Chair.FBX');
  late BlueprintTestProject project;
  String? chairMesh;

  setUpAll(() async {
    project = BlueprintTestProject.create(name: 'CollisionProject');
    Directory('${project.dir}/contents/meshes/static').createSync(recursive: true);
    if (chairFbx.existsSync()) {
      final result = await ImportAssetUseCase()(projectDir: project.dir, sourceFilePath: chairFbx.path);
      expect(result.isSuccess, isTrue, reason: result.error);
      chairMesh = result.asset!.relativePath;
    }
  });
  tearDownAll(() => project.dispose());

  Future<BlueprintEditorViewModel> open(String name) async {
    final path = project.createBlueprint(name, parentClass: 'LuminaActor');
    final vm = BlueprintEditorViewModel(assetPath: path);
    await vm.load();
    return vm;
  }

  Future<void> pumpEditor(WidgetTester tester, BlueprintEditorViewModel vm) async {
    tester.view.physicalSize = const Size(1600, 1400);
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

  /// Half the span of the preview's line set [id] along each runtime axis.
  List<double> halfSpans(BlueprintEditorViewModel vm, String id) {
    final set = vm.preview.overlays.singleWhere((s) => s.id == id);
    final lo = [double.infinity, double.infinity, double.infinity];
    final hi = [-double.infinity, -double.infinity, -double.infinity];
    for (var i = 0; i + 2 < set.positions.length; i += 3) {
      for (var k = 0; k < 3; k++) {
        lo[k] = math.min(lo[k], set.positions[i + k]);
        hi[k] = math.max(hi[k], set.positions[i + k]);
      }
    }
    return [for (var k = 0; k < 3; k++) (hi[k] - lo[k]) / 2];
  }

  String extentKey(BlueprintEditorViewModel vm, String id, int axis) => '$id.boxExtent.$axis.${vm.componentTransformRevision}';

  testWidgets('Add Component "col" lists the six collision shapes; Box Collision is a LuminaBoxComponent with 50 cm extents in Details',
      (tester) async {
    final vm = await tester.runAsync(() => open('BP_AddCollision'));
    addTearDown(vm!.dispose);
    await pumpEditor(tester, vm);

    await tester.tap(find.byKey(const ValueKey('add_component_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('add_component_search')), 'col');
    await tester.pumpAndSettle();
    for (final type in const [
      'LuminaBoxComponent',
      'LuminaSphereComponent',
      'LuminaCapsuleComponent',
      'LuminaCylinderComponent',
      'LuminaConeComponent',
      'LuminaConvexComponent',
    ]) {
      expect(find.byKey(ValueKey('add_component_$type')), findsOneWidget, reason: '$type is offered for "col"');
    }
    for (final label in const ['Box Collision', 'Sphere Collision', 'Capsule Collision', 'Cylinder Collision', 'Cone Collision', 'Convex Collision']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('add_component_LuminaCameraComponent')), findsNothing);
    expect(find.byKey(const ValueKey('add_component_LuminaStaticMeshComponent')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('add_component_LuminaBoxComponent')));
    await tester.pumpAndSettle();
    final box = vm.getComponent(vm.selectedComponentId!)!;
    expect(box.type, 'LuminaBoxComponent');
    expect(box.properties['boxExtent'], [50.0, 50.0, 50.0]);
    expect(box.parentId, vm.rootComponent!.id);
    expect(find.text('Box Extent'), findsOneWidget);
    for (var axis = 0; axis < 3; axis++) {
      expect(tester.widget<TextField>(find.byKey(ValueKey(extentKey(vm, box.id, axis)))).initialValue, '50.0');
    }
    expect(find.byKey(const ValueKey('bp_collision_section')), findsOneWidget, reason: 'the Collision section');
    expect(BlueprintComponentRegistry.getDescriptor('LuminaBoxComponent')!.collisionCapable, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Box Extent X 120 widens the preview wireframe and the saved .lmas; undo restores both', (tester) async {
    final vm = await tester.runAsync(() => open('BP_BoxExtent'));
    addTearDown(vm!.dispose);
    final box = vm.addComponent('LuminaBoxComponent')!;
    await pumpEditor(tester, vm);
    expect(halfSpans(vm, box.id).map((v) => v.toStringAsFixed(3)), everyElement('50.000'));

    await tester.enterText(find.byKey(ValueKey(extentKey(vm, box.id, 0))), '120');
    await tester.pump();
    expect(vm.getComponent(box.id)!.properties['boxExtent'], [120.0, 50.0, 50.0]);
    // Authoring X is runtime X (LuminaAxes, Z up → Y up).
    final expected = LuminaAxes.scale([120.0, 50.0, 50.0]);
    final spans = halfSpans(vm, box.id);
    for (var k = 0; k < 3; k++) {
      expect(spans[k], closeTo(expected[k], 1e-6), reason: 'axis $k of the wireframe');
    }
    expect(await tester.runAsync(vm.save), isTrue);
    expect(readBlueprint(vm.assetPath).components.singleWhere((c) => c.id == box.id).properties['boxExtent'], [120.0, 50.0, 50.0]);

    vm.undo();
    await tester.pump();
    expect(vm.getComponent(box.id)!.properties['boxExtent'], [50.0, 50.0, 50.0]);
    expect(halfSpans(vm, box.id).map((v) => v.toStringAsFixed(3)), everyElement('50.000'));
    expect(await tester.runAsync(vm.save), isTrue);
    expect(readBlueprint(vm.assetPath).components.singleWhere((c) => c.id == box.id).properties['boxExtent'], [50.0, 50.0, 50.0]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Trigger fills and greys the grid; Custom enables it; Pawn → Block stores preset custom with the grid', (tester) async {
    final vm = await tester.runAsync(() => open('BP_Presets'));
    addTearDown(vm!.dispose);
    final box = vm.addComponent('LuminaBoxComponent')!;
    await pumpEditor(tester, vm);

    RadioGroup<CollisionResponse> grid(String channel) =>
        tester.widget<RadioGroup<CollisionResponse>>(find.byKey(ValueKey('bp_collision_response_$channel')));
    Future<void> pickPreset(String name) async {
      await tester.tap(find.byKey(const ValueKey('bp_collision_preset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('bp_collision_preset_$name')).last);
      await tester.pumpAndSettle();
    }

    // lumina's default: Block All Dynamic, greyed.
    expect(grid('pawn').enabled, isFalse);
    expect(grid('pawn').value, CollisionResponse.block);

    await pickPreset('trigger');
    var props = vm.getComponent(box.id)!.properties;
    expect(props['preset'], 'trigger');
    expect(props['objectType'], 'worldDynamic');
    expect(props['responses'], {'worldStatic': 'ignore', 'worldDynamic': 'overlap', 'pawn': 'overlap'});
    expect(props['generateOverlapEvents'], isTrue);
    expect(grid('pawn').value, CollisionResponse.overlap);
    expect(grid('worldStatic').value, CollisionResponse.ignore);
    expect(grid('worldDynamic').value, CollisionResponse.overlap);
    for (final c in const ['worldStatic', 'worldDynamic', 'pawn']) {
      expect(grid(c).enabled, isFalse, reason: 'a preset greys the $c row');
    }
    expect(vm.transactions.undoLabel, 'Undo Edit Collision of ${box.name}');

    await pickPreset('custom');
    props = vm.getComponent(box.id)!.properties;
    expect(props['preset'], 'custom');
    expect(props['responses'], {'worldStatic': 'ignore', 'worldDynamic': 'overlap', 'pawn': 'overlap'}, reason: 'Custom starts from the grid');
    expect(grid('pawn').enabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('bp_collision_response_pawn_block')));
    await tester.pumpAndSettle();
    props = vm.getComponent(box.id)!.properties;
    expect(props['preset'], 'custom');
    expect(props['responses'], {'worldStatic': 'ignore', 'worldDynamic': 'overlap', 'pawn': 'block'});
    expect(grid('pawn').value, CollisionResponse.block);

    // One undo step per change.
    vm.undo();
    await tester.pump();
    expect((vm.getComponent(box.id)!.properties['responses'] as Map)['pawn'], 'overlap');
    expect(vm.getComponent(box.id)!.properties['preset'], 'custom');
    vm.redo();
    await tester.pump();

    // The saved document builds the same responses through lumina's mapping.
    expect(await tester.runAsync(vm.save), isTrue);
    final saved = readBlueprint(vm.assetPath);
    final built = LuminaBlueprintComponents.construct(LuminaActor(), saved.components)[box.id] as LuminaBoxComponent;
    expect(built.getResponse(CollisionObjectType.pawn), CollisionResponse.block);
    expect(built.getResponse(CollisionObjectType.worldStatic), CollisionResponse.ignore);
    expect(built.objectType, CollisionObjectType.worldDynamic);
    expect(built.preset, LuminaCollisionPreset.custom);
    await tester.pumpWidget(const SizedBox());
  });

  test('all six components are added, sized, drawn and round-trip the .lmas into real lumina components', () async {
    final vm = await open('BP_AllShapes');
    addTearDown(vm.dispose);
    final ids = <String, String>{};
    for (final type in const [
      'LuminaBoxComponent',
      'LuminaSphereComponent',
      'LuminaCapsuleComponent',
      'LuminaCylinderComponent',
      'LuminaConeComponent',
      'LuminaConvexComponent',
    ]) {
      ids[type] = vm.addComponent(type)!.id;
    }
    expect(vm.getComponent(ids['LuminaSphereComponent']!)!.properties['radius'], 50.0);
    expect(vm.getComponent(ids['LuminaCylinderComponent']!)!.properties, containsPair('halfHeight', 80.0));
    expect(vm.getComponent(ids['LuminaConeComponent']!)!.properties, containsPair('radius', 50.0));

    vm.setProperty(ids['LuminaSphereComponent']!, 'radius', 75.0);
    vm.setProperty(ids['LuminaCylinderComponent']!, 'halfHeight', 120.0);
    vm.setProperty(ids['LuminaConeComponent']!, 'radius', 30.0);
    vm.setProperty(ids['LuminaBoxComponent']!, 'location', [0.0, 200.0, 0.0]);
    expect(vm.setComponentCollision(ids['LuminaBoxComponent']!, {'preset': 'trigger'}), isTrue);
    expect(vm.setComponentCollision(ids['LuminaSphereComponent']!, {'preset': 'overlapAll'}), isTrue);
    expect(vm.setComponentCollision(ids['LuminaCylinderComponent']!, {'preset': 'blockAll'}), isTrue);

    final convex = ids['LuminaConvexComponent']!;
    expect(vm.convexComponentsWithoutHull.map((c) => c.id), [convex], reason: 'no hull yet: a warning');
    if (chairMesh != null) {
      expect(vm.convexHullMeshes, contains(chairMesh), reason: 'the chair carries UCX_ hulls');
      expect(vm.setConvexHullAsset(convex, chairMesh!), isTrue);
      expect((vm.getComponent(convex)!.properties['hullPoints'] as List).length, greaterThanOrEqualTo(4));
      expect(vm.convexComponentsWithoutHull, isEmpty);
    }

    // Every shape is drawn in the preview.
    for (final id in ids.values) {
      expect(vm.preview.overlays.where((s) => s.id == id && s.positions.isNotEmpty), hasLength(1), reason: id);
    }
    final sphereSpan = halfSpans(vm, ids['LuminaSphereComponent']!);
    for (final v in sphereSpan) {
      expect(v, closeTo(75.0, 1e-6));
    }

    expect(await vm.save(), isTrue);
    final reopened = BlueprintEditorViewModel(assetPath: vm.assetPath);
    await reopened.load();
    addTearDown(reopened.dispose);
    for (final id in ids.values) {
      expect(reopened.getComponent(id)!.properties, vm.getComponent(id)!.properties, reason: '$id round-trips');
    }

    final built = LuminaBlueprintComponents.construct(LuminaActor(), readBlueprint(vm.assetPath).components);
    expect(built[ids['LuminaBoxComponent']!], isA<LuminaBoxComponent>());
    expect((built[ids['LuminaBoxComponent']!] as LuminaCollisionComponent).preset, LuminaCollisionPreset.trigger);
    expect((built[ids['LuminaSphereComponent']!] as LuminaSphereComponent).sphereRadius, 75.0);
    expect((built[ids['LuminaSphereComponent']!] as LuminaCollisionComponent).preset, LuminaCollisionPreset.overlapAll);
    expect((built[ids['LuminaCylinderComponent']!] as LuminaCylinderComponent).cylinderHalfHeight, 120.0);
    expect((built[ids['LuminaCylinderComponent']!] as LuminaCollisionComponent).preset, LuminaCollisionPreset.blockAll);
    expect((built[ids['LuminaConeComponent']!] as LuminaConeComponent).coneRadius, 30.0);
    expect(built[ids['LuminaCapsuleComponent']!], isA<LuminaCapsuleComponent>());
    if (chairMesh != null) {
      final hull = built[convex] as LuminaConvexComponent;
      expect(hull.hullAsset, chairMesh);
      expect(hull.buildWireframe(), isNotEmpty);
    }

    // Compile warns about a convex without a hull.
    final bare = vm.addComponent('LuminaConvexComponent')!;
    await vm.compile();
    expect(vm.diagnostics.where((d) => !d.isError && d.message.contains("Convex component '${bare.name}' has no hull asset")), hasLength(1),
        reason: '${vm.diagnostics}');
  });
}
