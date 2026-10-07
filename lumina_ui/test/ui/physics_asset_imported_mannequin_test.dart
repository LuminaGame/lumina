import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/physics_asset_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/physics_preview_scene.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/physics_asset_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/physics_asset_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// The real skinned mannequin: `LUMINA_TEST_ASSETS` or the workspace's
/// test-assets (the tests skip without it).
String _mannequinPath() {
  final env = Platform.environment['LUMINA_TEST_ASSETS'];
  final candidates = [
    if (env != null && env.isNotEmpty) '$env/mannequin/SKM_Manny_Simple.glb',
    '${Directory.current.parent.path}/test-assets/mannequin/SKM_Manny_Simple.glb',
  ];
  return candidates.firstWhere((p) => File(p).existsSync(), orElse: () => candidates.first);
}

/// Regression coverage: the physics asset editor must load the imported
/// mannequin `.lmas` it references.
///
/// The physics smoke imported the real mannequin and then bound its physics
/// asset to the first asset whose name contained "manny". The import emits a
/// whole family (textures, materials, mesh) and the textures sort first, so the
/// physics asset referenced `T_Manny_02_BN.lmas`, and the editor reported that
/// "the referenced skeletal mesh could not be parsed", which sent the bug after
/// the mesh loader instead of the reference.
///
/// It also carries the regression coverage for bodies authored in metres
/// with the skeletal mesh never drawn: bodies are authored in centimetres, at the scale the mesh is drawn with.
void main() {
  final mannequin = _mannequinPath();
  late Directory projectDir;
  late List<RealAssetInfo> imported;

  setUpAll(() async {
    if (!File(mannequin).existsSync()) return;
    projectDir = Directory.systemTemp.createTempSync('phat_imported_manny_');
    final repo = AssetRepository();
    await repo.importExternalFile(projectPath: projectDir.path, sourceFilePath: mannequin);
    imported = repo.scanProjectContents(projectDir.path);
  });

  tearDownAll(() {
    if (File(mannequin).existsSync() && projectDir.existsSync()) {
      projectDir.deleteSync(recursive: true);
    }
  });

  /// A real PHYSICS_ASSET `.lmas` whose `skeletal_mesh` slot points at [target].
  Future<PhysicsAssetEditorViewModel> physicsAssetBoundTo(
    RealAssetInfo target, {
    String suffix = '',
    Map<String, String> metadata = const {},
  }) async {
    final file = File('${projectDir.path}/contents/physics/PHYS_Manny_${target.type.name}$suffix.lmas');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(LuminaAsset(
      assetId: 'PHYS_Manny_${target.type.name}$suffix',
      name: 'PHYS_Manny',
      type: AssetType.physicsAsset,
      metadata: metadata,
      references: [
        AssetReference(
          slotName: PhysicsAssetEditorViewModel.skeletalMeshSlot,
          assetId: target.assetId ?? '',
          assetPath: target.lmasPath ?? '${projectDir.path}/${target.relativePath}',
        ),
      ],
    ).toProtoBufferBytes());
    final vm = PhysicsAssetEditorViewModel(assetPath: file.path);
    await vm.load();
    return vm;
  }

  test('a physics asset bound to the imported mannequin mesh resolves its real bones', () async {
    if (!File(mannequin).existsSync()) return markTestSkipped('needs a mannequin GLB');
    final mesh = imported.singleWhere((a) => a.type == AssetType.filameshSk);

    final vm = await physicsAssetBoundTo(mesh);

    expect(vm.hasSkeletalMesh, isTrue, reason: vm.linkError ?? '');
    expect(vm.allBoneNames, containsAll(<String>['pelvis', 'spine_01']));
  });

  test('a reference to a non-mesh asset of the import family names that asset, not a parse failure', () async {
    if (!File(mannequin).existsSync()) return markTestSkipped('needs a mannequin GLB');
    // What the smoke picked: the first "manny" asset of the family is a texture.
    final texture = imported.firstWhere((a) => a.type == AssetType.texture);

    final vm = await physicsAssetBoundTo(texture);

    expect(vm.hasSkeletalMesh, isFalse);
    expect(vm.linkError, isNot(contains('could not be parsed')),
        reason: 'the texture is a valid asset; it is just not a mesh');
    expect(vm.linkError, contains(texture.fileName.replaceAll('.lmas', '')));
    expect(vm.linkError, contains('not a skeletal mesh'));
  });

  group('bodies are authored in centimetres, at the scale the mesh is drawn with', () {
    RealAssetInfo skeletalMesh() => imported.singleWhere((a) => a.type == AssetType.filameshSk);

    test('an auto-sized pelvis body is tens of centimetres, from bone lengths in cm', () async {
      if (!File(mannequin).existsSync()) return markTestSkipped('needs a mannequin GLB');
      final vm = await physicsAssetBoundTo(skeletalMesh(), suffix: '_autosize');

      // The GLB is glTF metres: pelvis -> spine_01 is a few centimetres.
      final pelvis = vm.glbMesh!.allNodes.firstWhere((n) => n.name == 'pelvis');
      final spine = pelvis.children.firstWhere((n) => n.name == 'spine_01');
      final segmentMetres = Vector3(spine.translation![0], spine.translation![1], spine.translation![2]).length;
      expect(vm.boneSegmentLength('pelvis'), closeTo(segmentMetres * LuminaUnits.unitsPerMetre, 1e-6),
          reason: 'bone lengths are measured in world units (cm)');

      expect(vm.addBody('pelvis', PhysicsShapeType.capsule), isTrue);
      final body = vm.document.bodyForBone('pelvis')!;
      expect(body.radius, inInclusiveRange(5.0, 50.0), reason: 'a pelvis is tens of cm across, not ${body.radius}');
      expect(body.effectiveHalfHeight, inInclusiveRange(5.0, 60.0));
      expect(body.effectiveHalfHeight, greaterThanOrEqualTo(body.radius));
    });

    test('bone and body transforms sit on the mesh as it is drawn (glTF metres x unitsPerMetre)', () async {
      if (!File(mannequin).existsSync()) return markTestSkipped('needs a mannequin GLB');
      final vm = await physicsAssetBoundTo(skeletalMesh(), suffix: '_scale');
      final meshTop = vm.glbMesh!.maxBounds[1];

      // The pelvis is about half way up the mannequin, in cm.
      final pelvisY = vm.boneGlobal('pelvis')!.getTranslation().y;
      expect(pelvisY, inInclusiveRange(80.0, 110.0), reason: 'pelvis height in cm, not $pelvisY');
      expect(pelvisY / (meshTop * LuminaUnits.unitsPerMetre), inInclusiveRange(0.45, 0.6));

      // The body sits half way along the pelvis -> spine_01 segment, in cm.
      vm.addBody('pelvis', PhysicsShapeType.capsule);
      final world = vm.bodyWorldTransform(vm.document.bodyForBone('pelvis')!);
      final midpoint = (vm.boneGlobal('pelvis')!.getTranslation() + vm.boneGlobal('spine_01')!.getTranslation()) * 0.5;
      expect((world.getTranslation() - midpoint).length, lessThan(1e-6));
    });

    test('auto-sized bodies run along their bones, centred on the segment', () async {
      if (!File(mannequin).existsSync()) return markTestSkipped('needs a mannequin GLB');
      final vm = await physicsAssetBoundTo(skeletalMesh(), suffix: '_along');
      for (final (bone, child) in [('thigh_l', 'calf_l'), ('calf_l', 'foot_l'), ('upperarm_r', 'lowerarm_r')]) {
        vm.addBody(bone, PhysicsShapeType.capsule);
        final body = vm.document.bodyForBone(bone)!;
        final from = vm.boneGlobal(bone)!.getTranslation();
        final to = vm.boneGlobal(child)!.getTranslation();
        final world = vm.bodyWorldTransform(body);
        // The engine capsule's axis is the body's local +Y.
        final axis = world.getRotation().transformed(Vector3(0, 1, 0));
        final bone3 = to - from;
        expect(axis.dot(bone3.normalized()).abs(), greaterThan(0.999), reason: '$bone capsule runs along the bone');
        expect((world.getTranslation() - (from + to) * 0.5).length, lessThan(0.01), reason: '$bone centred');
        expect(body.effectiveHalfHeight, closeTo(math.max(bone3.length / 2, body.radius), 1e-6),
            reason: '$bone spans its ${bone3.length.toStringAsFixed(1)} cm segment');
        expect(body.radius, inInclusiveRange(3.0, 20.0), reason: '$bone radius ${body.radius} cm reaches its skin');
      }
    });

    test('the preview draws the mesh at the scale the bodies are authored at', () async {
      if (!File(mannequin).existsSync()) return markTestSkipped('needs a mannequin GLB');
      final vm = await physicsAssetBoundTo(skeletalMesh(), suffix: '_preview');
      final drawn = PhysicsPreviewScene.meshComponentFor(vm.skeletalMeshPath!, vm.glbMesh!.rawPayload!);

      expect(drawn.assetUnitScale, PhysicsAssetEditorViewModel.meshUnitScale);
      // The mannequin's root nodes carry no transform: pelvis local = global.
      final pelvisMetres = vm.glbMesh!.allNodes.firstWhere((n) => n.name == 'pelvis').translation![1];
      expect(vm.boneGlobal('pelvis')!.getTranslation().y, closeTo(pelvisMetres * drawn.assetUnitScale, 1e-6));
      expect(vm.meshWorldBounds!.max.y, closeTo(vm.glbMesh!.maxBounds[1] * drawn.assetUnitScale, 1e-6));
      expect(vm.meshWorldBounds!.max.y, inInclusiveRange(170.0, 190.0), reason: 'a 180 cm mannequin');
    });

    testWidgets('the viewport frames the mannequin and its bodies in cm, and Details read cm', (tester) async {
      if (!File(mannequin).existsSync()) return markTestSkipped('needs a mannequin GLB');
      await tester.binding.setSurfaceSize(const Size(1500, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = (await tester.runAsync(() => physicsAssetBoundTo(skeletalMesh(), suffix: '_view')))!;
      vm.addBody('head', PhysicsShapeType.sphere);
      vm.addBody('pelvis', PhysicsShapeType.capsule); // selected: the inspector shows it

      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: PhysicsAssetSubEditor(assetName: 'PHYS_Manny', assetPath: vm.assetPath, viewModel: vm)),
      ));
      await tester.pump();

      final viewport = tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport));
      final bounds = vm.meshWorldBounds!;
      final height = bounds.max.y - bounds.min.y;
      expect(viewport.yUpCamera, isTrue, reason: 'the preview world is the Y-up runtime');
      expect(bounds.containsVector3(viewport.initialCameraTarget!), isTrue);
      expect(viewport.initialCameraDistance, greaterThan(height), reason: 'the whole 180 cm mannequin is in view');
      expect(viewport.initialCameraDistance, lessThan(height * 4), reason: 'and not a speck in the distance');
      for (final body in vm.document.bodies) {
        final centre = vm.bodyWorldTransform(body).getTranslation();
        expect((centre - viewport.initialCameraTarget!).length, lessThan(viewport.initialCameraDistance!),
            reason: '${body.name} is in the framed volume');
      }
      expect(viewport.gridStep, 10.0, reason: 'a 10 cm grid');
      expect(viewport.gridExtent, greaterThanOrEqualTo(height));

      expect(vm.selectedBody?.boneName, 'pelvis');
      expect(find.text('Radius (cm)'), findsOneWidget);
      expect(find.text('Half Height (cm, full capsule)'), findsOneWidget);
      expect(find.text('Offset Location (cm, vs bone)'), findsOneWidget);
      expect(find.textContaining('(m'), findsNothing, reason: 'no metre labels are left');

      // Close the editor while the mannequin may still be loading: the
      // cancelled load's poll timer resolves.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    test('Validate Overlaps reports in centimetres and still separates clean pairs', () async {
      if (!File(mannequin).existsSync()) return markTestSkipped('needs a mannequin GLB');
      final vm = await physicsAssetBoundTo(skeletalMesh(), suffix: '_overlap');
      vm.addBody('pelvis', PhysicsShapeType.capsule);
      vm.addBody('spine_01', PhysicsShapeType.box);
      vm.addBody('head', PhysicsShapeType.sphere);

      final hits = vm.validateOverlaps().where((r) => r.isColliding).toList();
      expect(hits.map((r) => {r.boneA, r.boneB}), contains(equals({'pelvis', 'spine_01'})),
          reason: 'neighbouring pelvis and spine_01 bodies interpenetrate');
      expect(hits.any((r) => r.boneA == 'head' || r.boneB == 'head'), isFalse,
          reason: 'the head is far from the pelvis and spine_01');
      final depth = hits.firstWhere((r) => {r.boneA, r.boneB}.containsAll(['pelvis', 'spine_01'])).penetrationDepth;
      expect(depth, greaterThan(1.0), reason: 'depth in cm, not metres ($depth)');
    });

    test('a document authored in metres (no units marker) is converted to cm on load and saved in cm', () async {
      if (!File(mannequin).existsSync()) return markTestSkipped('needs a mannequin GLB');
      final metreDoc = jsonEncode({
        'v': 1,
        'bodies': [
          {
            'bone': 'pelvis',
            'shape': 'capsule',
            'radius': 0.15,
            'half_height': 0.2,
            'half_extents': [0.1, 0.2, 0.1],
            'offset_t': [0.01, 0.0, -0.02],
            'offset_r': [0.0, 90.0, 0.0],
            'mass_kg': 12.0,
          },
          {'bone': 'spine_01', 'shape': 'box', 'radius': 0.1, 'half_height': 0.1, 'half_extents': [0.12, 0.05, 0.1]},
        ],
        'constraints': [],
        'disabled_collision_pairs': [],
      });
      final vm = await physicsAssetBoundTo(skeletalMesh(),
          suffix: '_metres', metadata: {PhysicsAssetEditorViewModel.metadataKey: metreDoc});

      final pelvis = vm.document.bodyForBone('pelvis')!;
      expect(pelvis.radius, closeTo(15.0, 1e-9));
      expect(pelvis.halfHeight, closeTo(20.0, 1e-9));
      expect(pelvis.offsetLocation, [closeTo(1.0, 1e-9), closeTo(0.0, 1e-9), closeTo(-2.0, 1e-9)]);
      expect(pelvis.offsetRotationDeg[1], closeTo(90.0, 1e-9), reason: 'angles are not lengths');
      expect(pelvis.massKg, closeTo(12.0, 1e-9), reason: 'mass is not a length');
      expect(vm.document.bodyForBone('spine_01')!.halfExtents,
          [closeTo(12.0, 1e-9), closeTo(5.0, 1e-9), closeTo(10.0, 1e-9)]);

      vm.setBodyMass('pelvis', 13.0);
      expect(await vm.save(), isTrue);
      final saved = jsonDecode(LuminaAsset.fromBytes(File(vm.assetPath).readAsBytesSync())
          .metadata[PhysicsAssetEditorViewModel.metadataKey]!) as Map<String, dynamic>;
      expect(saved['world_units'], kWorldUnitsCentimetres);
      expect((saved['bodies'] as List).first['radius'], closeTo(15.0, 1e-9));

      final reopened = PhysicsAssetEditorViewModel(assetPath: vm.assetPath);
      await reopened.load();
      expect(reopened.document.bodyForBone('pelvis')!.radius, closeTo(15.0, 1e-9),
          reason: 'a cm document is not converted a second time');
    });
  });

  group('selecting another body changes nothing but the selection', () {
    testWidgets('select head, then pelvis: head keeps its radius and the asset stays clean', (tester) async {
      if (!File(mannequin).existsSync()) return markTestSkipped('needs a mannequin GLB');
      await tester.binding.setSurfaceSize(const Size(1500, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final mesh = imported.singleWhere((a) => a.type == AssetType.filameshSk);
      final vm = (await tester.runAsync(() => physicsAssetBoundTo(mesh, suffix: '_switch')))!;
      vm.addBody('pelvis', PhysicsShapeType.capsule);
      vm.addBody('head', PhysicsShapeType.capsule);
      vm.setBodyRadius('head', 17.688);
      vm.setBodyHalfHeight('head', 21.25);
      vm.setBodyPhysicsMaterial('head', 'PM_Head');
      vm.setBodyRadius('pelvis', 14.777608345957216);
      vm.setBodyHalfHeight('pelvis', 16.964);
      vm.setBodyPhysicsMaterial('pelvis', 'PM_Flesh');
      expect((await tester.runAsync(vm.save))!, isTrue);
      vm.selectBody('head');
      expect(vm.isDirty, isFalse);

      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: PhysicsAssetSubEditor(assetName: 'PHYS_Manny', assetPath: vm.assetPath, viewModel: vm)),
      ));
      await tester.pump();

      void expectUntouched() {
        final head = vm.document.bodyForBone('head')!;
        final pelvis = vm.document.bodyForBone('pelvis')!;
        expect(head.radius, 17.688, reason: 'head radius');
        expect(head.halfHeight, 21.25, reason: 'head half height');
        expect(head.physicsMaterial, 'PM_Head');
        expect(pelvis.radius, 14.777608345957216, reason: 'pelvis radius, not rounded to the field');
        expect(pelvis.halfHeight, 16.964);
        expect(pelvis.physicsMaterial, 'PM_Flesh');
        expect(vm.isDirty, isFalse, reason: 'selecting is not an edit');
        expect(tester.takeException(), isNull, reason: 'no edit may run while the inspector builds');
      }

      await tester.tap(find.byKey(const ValueKey('physics_body_row_pelvis')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(vm.selectedBody?.boneName, 'pelvis');
      expectUntouched();

      await tester.tap(find.byKey(const ValueKey('physics_body_row_head')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(vm.selectedBody?.boneName, 'head');
      expectUntouched();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
