import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/physics_asset_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/physics_asset_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/physics_asset_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Quaternion, Vector3;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Builds a real (tiny) binary `.glb` carrying a 3-bone skeleton with skin
/// weights so the physics editor parses genuine bones, genuine bone globals and
/// genuine per-bone vertex influences. No mocks: this is a real glTF
/// container parsed by the real `GlbParserService`, not a stub object graph.
///
/// Hierarchy (local transforms):
///   Armature
///     pelvis      t=(0,0,0)
///       spine_01  t=(0,0.6,0)
///       thigh_l   t=(0.1,-0.2,0)  r=90° about +Z
Uint8List buildSkinnedSkeletonGlb() {
  final posFloats = Float32List.fromList([
    0.0, 0.0, 0.0,
    0.25, 0.1, 0.0,
    0.0, 0.62, 0.0,
    0.0, 0.58, 0.12,
  ]);
  // JOINTS_0 — indices into skins[0].joints: 0=pelvis, 1=spine_01, 2=thigh_l
  final jointsBytes = Uint8List.fromList([
    0, 0, 0, 0,
    0, 0, 0, 0,
    1, 0, 0, 0,
    1, 0, 0, 0,
  ]);
  final weightsFloats = Float32List.fromList([
    1.0, 0.0, 0.0, 0.0,
    0.9, 0.1, 0.0, 0.0,
    1.0, 0.0, 0.0, 0.0,
    0.7, 0.3, 0.0, 0.0,
  ]);
  final indicesShorts = Uint16List.fromList([0, 1, 2, 0, 2, 3]);

  final binBuilder = BytesBuilder();
  binBuilder.add(posFloats.buffer.asUint8List()); // 48
  binBuilder.add(jointsBytes); // 16
  binBuilder.add(weightsFloats.buffer.asUint8List()); // 64
  binBuilder.add(indicesShorts.buffer.asUint8List()); // 12
  final binBytes = binBuilder.toBytes();

  const s = 0.7071067811865476; // sin/cos of 45° -> quaternion for 90° about Z
  final gltf = {
    'asset': {'version': '2.0'},
    'buffers': [
      {'byteLength': binBytes.length}
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 48, 'target': 34962},
      {'buffer': 0, 'byteOffset': 48, 'byteLength': 16, 'target': 34962},
      {'buffer': 0, 'byteOffset': 64, 'byteLength': 64, 'target': 34962},
      {'buffer': 0, 'byteOffset': 128, 'byteLength': 12, 'target': 34963},
    ],
    'accessors': [
      {'bufferView': 0, 'byteOffset': 0, 'componentType': 5126, 'count': 4, 'type': 'VEC3'},
      {'bufferView': 1, 'byteOffset': 0, 'componentType': 5121, 'count': 4, 'type': 'VEC4'},
      {'bufferView': 2, 'byteOffset': 0, 'componentType': 5126, 'count': 4, 'type': 'VEC4'},
      {'bufferView': 3, 'byteOffset': 0, 'componentType': 5123, 'count': 6, 'type': 'SCALAR'},
    ],
    'meshes': [
      {
        'name': 'HeroMesh',
        'primitives': [
          {
            'attributes': {'POSITION': 0, 'JOINTS_0': 1, 'WEIGHTS_0': 2},
            'indices': 3,
          }
        ],
      }
    ],
    'nodes': [
      {'name': 'Armature', 'children': [1]},
      {'name': 'pelvis', 'children': [2, 3], 'translation': [0.0, 0.0, 0.0]},
      {'name': 'spine_01', 'translation': [0.0, 0.6, 0.0]},
      {
        'name': 'thigh_l',
        'translation': [0.1, -0.2, 0.0],
        'rotation': [0.0, 0.0, s, s],
      },
      {'name': 'MeshNode', 'mesh': 0, 'skin': 0},
    ],
    'skins': [
      {
        'joints': [1, 2, 3]
      }
    ],
    'scene': 0,
    'scenes': [
      {
        'nodes': [0, 4]
      }
    ],
  };

  final jsonBytes = utf8.encode(jsonEncode(gltf));
  final jsonPaddedLen = (jsonBytes.length + 3) & ~3;
  final binPaddedLen = (binBytes.length + 3) & ~3;
  final totalLen = 12 + 8 + jsonPaddedLen + 8 + binPaddedLen;
  final out = Uint8List(totalLen);
  final bd = ByteData.sublistView(out);
  bd.setUint32(0, 0x46546C67, Endian.little);
  bd.setUint32(4, 2, Endian.little);
  bd.setUint32(8, totalLen, Endian.little);
  bd.setUint32(12, jsonPaddedLen, Endian.little);
  bd.setUint32(16, 0x4E4F534A, Endian.little);
  out.setRange(20, 20 + jsonBytes.length, jsonBytes);
  for (int i = 20 + jsonBytes.length; i < 20 + jsonPaddedLen; i++) {
    out[i] = 0x20;
  }
  final binHeaderOffset = 20 + jsonPaddedLen;
  bd.setUint32(binHeaderOffset, binPaddedLen, Endian.little);
  bd.setUint32(binHeaderOffset + 4, 0x004E4942, Endian.little);
  out.setRange(binHeaderOffset + 8, binHeaderOffset + 8 + binBytes.length, binBytes);
  return out;
}

void main() {
  late Directory tempDir;
  late File meshFile;
  late File physicsFile;

  /// Writes the real skeletal-mesh `.lmas` and a real PHYSICS_ASSET `.lmas`
  /// that references it through an `AssetReference{slot_name: 'skeletal_mesh'}`.
  void writeFixture({bool linkMesh = true, Map<String, String> extraMeta = const {}}) {
    meshFile = File('${tempDir.path}/contents/meshes/SKM_Hero.lmas');
    meshFile.parent.createSync(recursive: true);
    meshFile.writeAsBytesSync(LuminaAsset(
      assetId: 'SKM_Hero',
      name: 'SKM_Hero',
      type: AssetType.filameshSk,
      rawPayload: buildSkinnedSkeletonGlb(),
    ).toProtoBufferBytes());

    physicsFile = File('${tempDir.path}/contents/physics/PHYS_Hero.lmas');
    physicsFile.parent.createSync(recursive: true);
    physicsFile.writeAsBytesSync(LuminaAsset(
      assetId: 'PHYS_Hero',
      name: 'PHYS_Hero',
      type: AssetType.physicsAsset,
      metadata: extraMeta,
      references: linkMesh
          ? [
              AssetReference(
                slotName: 'skeletal_mesh',
                assetId: 'SKM_Hero',
                assetPath: meshFile.path,
              ),
            ]
          : const [],
    ).toProtoBufferBytes());
  }

  Future<PhysicsAssetEditorViewModel> loadVm() async {
    final vm = PhysicsAssetEditorViewModel(assetPath: physicsFile.path);
    await vm.load();
    return vm;
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('phat_ui_test_');
    writeFixture();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('loads real bones from the referenced skeletal mesh — none of the old hardcoded bodies', () async {
    final vm = await loadVm();

    expect(vm.hasError, isFalse);
    expect(vm.skeletalMeshPath, meshFile.path);
    expect(vm.allBoneNames, containsAll(<String>['pelvis', 'spine_01', 'thigh_l']));
    expect(vm.document.bodies, isEmpty, reason: 'a fresh physics asset authors nothing');
    for (final fake in const ['pelvis_Capsule', 'spine_01_Box', 'spine_02_Box', 'thigh_l_Capsule', 'thigh_r_Capsule', 'head_Sphere']) {
      expect(vm.document.bodies.any((b) => b.name == fake), isFalse, reason: '$fake was stub data');
    }
  });

  test('missing skeletal-mesh link is a real error state, and binding one repairs it', () async {
    writeFixture(linkMesh: false);
    final vm = await loadVm();

    expect(vm.hasSkeletalMesh, isFalse);
    expect(vm.linkError, isNotNull);
    expect(vm.allBoneNames, isEmpty);

    await vm.bindSkeletalMesh(meshFile.path, assetId: 'SKM_Hero');
    expect(vm.hasSkeletalMesh, isTrue);
    expect(vm.allBoneNames, contains('pelvis'));
    expect(vm.isDirty, isTrue);

    expect(await vm.save(), isTrue);
    final reread = LuminaAsset.fromBytes(physicsFile.readAsBytesSync());
    expect(reread.references.any((r) => r.slotName == 'skeletal_mesh' && r.assetPath == meshFile.path), isTrue);
  });

  test('Add Body auto-sizes the capsule from the bone segment and rejects a duplicate body', () async {
    final vm = await loadVm();

    expect(vm.addBody('pelvis', PhysicsShapeType.capsule), isTrue);
    final body = vm.document.bodyForBone('pelvis')!;
    expect(body.name, 'pelvis_Capsule');
    // pelvis -> spine_01 segment is 0.6 m in the glTF, 60 cm in the world:
    // halfHeight tracks the segment, in cm.
    expect(body.halfHeight, closeTo(30.0, 1e-9));
    expect(body.radius, greaterThan(0.0));
    expect(body.halfHeight, greaterThanOrEqualTo(body.radius), reason: 'engine capsule rule halfHeight >= radius');
    expect(vm.selectedBody?.boneName, 'pelvis', reason: 'the inspector opens on the new body');

    expect(vm.addBody('pelvis', PhysicsShapeType.sphere), isFalse);
    expect(vm.lastError, contains('Replace Body'));
    expect(vm.document.bodies.where((b) => b.boneName == 'pelvis').length, 1);

    // Replace keeps the sizing but changes the shape.
    expect(vm.replaceBody('pelvis', PhysicsShapeType.sphere), isTrue);
    expect(vm.document.bodyForBone('pelvis')!.shape, PhysicsShapeType.sphere);
    expect(vm.document.bodyForBone('pelvis')!.radius, closeTo(body.radius, 1e-9));
  });

  test('body edits, constraints and disabled pairs round-trip through the .lmas on disk', () async {
    final vm = await loadVm();
    vm.addBody('pelvis', PhysicsShapeType.capsule);
    vm.addBody('spine_01', PhysicsShapeType.capsule);
    vm.addBody('thigh_l', PhysicsShapeType.capsule);

    vm.setBodyShape('spine_01', PhysicsShapeType.box);
    vm.setBodyExtent('spine_01', 0, 25.0);
    vm.setBodyExtent('spine_01', 1, 35.0);
    vm.setBodyExtent('spine_01', 2, 15.0);
    vm.setBodyMass('spine_01', 12.5);
    vm.setBodyAngularDamping('spine_01', 0.5);
    vm.setBodyLinearDamping('spine_01', 0.11);
    vm.setBodyPhysicsMaterial('spine_01', 'PM_Flesh');
    vm.setBodyOffsetLocation('spine_01', 1, 5.0);

    vm.addConstraint('pelvis', 'spine_01');
    vm.setConstraintMode('spine_01_Constraint', PhysicsAngularMode.limited);
    vm.setConstraintSwing1('spine_01_Constraint', 42.0);
    vm.setConstraintTwist('spine_01_Constraint', -17.5);
    vm.disableCollisionBetween('thigh_l', 'pelvis');

    expect(vm.isDirty, isTrue);
    expect(await vm.save(), isTrue);
    expect(vm.isDirty, isFalse);

    final reopened = PhysicsAssetEditorViewModel(assetPath: physicsFile.path);
    await reopened.load();
    final box = reopened.document.bodyForBone('spine_01')!;
    expect(box.shape, PhysicsShapeType.box);
    expect(box.halfExtents, [closeTo(25.0, 1e-9), closeTo(35.0, 1e-9), closeTo(15.0, 1e-9)]);
    expect(box.massKg, closeTo(12.5, 1e-9));
    expect(box.angularDamping, closeTo(0.5, 1e-9));
    expect(box.linearDamping, closeTo(0.11, 1e-9));
    expect(box.physicsMaterial, 'PM_Flesh');
    expect(box.offsetLocation[1], closeTo(5.0, 1e-9));
    expect(reopened.document.bodies.length, 3);

    final c = reopened.document.constraints.single;
    expect(c.name, 'spine_01_Constraint');
    expect(c.bodyA, 'pelvis');
    expect(c.bodyB, 'spine_01');
    expect(c.angularMode, PhysicsAngularMode.limited);
    expect(c.swing1Deg, closeTo(42.0, 1e-9));
    expect(c.twistDeg, closeTo(-17.5, 1e-9));
    expect(reopened.isCollisionDisabled('pelvis', 'thigh_l'), isTrue, reason: 'pair order must not matter');

    // The versioned document really lives in the asset metadata.
    final raw = LuminaAsset.fromBytes(physicsFile.readAsBytesSync());
    final decoded = jsonDecode(raw.metadata['physics_asset']!) as Map<String, dynamic>;
    expect(decoded['v'], PhysicsAssetDocument.schemaVersion);
    expect(decoded[PhysicsAssetDocument.worldUnitsKey], kWorldUnitsCentimetres);
    expect((decoded['bodies'] as List).length, 3);
  });

  test('constraints default to Limited, Locked disables the degree limits, dangling endpoints block Save', () async {
    final vm = await loadVm();
    vm.addBody('pelvis', PhysicsShapeType.capsule);
    vm.addBody('spine_01', PhysicsShapeType.capsule);

    expect(vm.addConstraint('pelvis', 'spine_01'), isTrue);
    final c = vm.document.constraints.single;
    expect(c.name, 'spine_01_Constraint');
    expect(c.angularMode, PhysicsAngularMode.limited);
    expect(vm.constraintLimitsEnabled(c), isTrue);

    vm.setConstraintMode(c.name, PhysicsAngularMode.locked);
    expect(vm.constraintLimitsEnabled(vm.document.constraints.single), isFalse);
    vm.setConstraintMode(c.name, PhysicsAngularMode.limited);

    // Degrees clamp to the -180..180 range.
    vm.setConstraintSwing2(c.name, 400.0);
    expect(vm.document.constraints.single.swing2Deg, closeTo(180.0, 1e-9));

    // A constraint on the same bone twice is rejected, as is one to itself.
    expect(vm.addConstraint('pelvis', 'spine_01'), isFalse);
    expect(vm.addConstraint('pelvis', 'pelvis'), isFalse);

    // Forcing a dangling endpoint blocks Save with an inline error.
    vm.document.constraints.single.bodyA = 'ghost_bone';
    expect(vm.validationErrors, isNotEmpty);
    expect(vm.validationErrors.first, contains('ghost_bone'));
    expect(await vm.save(), isFalse);
  });

  test('removing a body cascades to its constraints and disabled pairs', () async {
    final vm = await loadVm();
    vm.addBody('pelvis', PhysicsShapeType.capsule);
    vm.addBody('spine_01', PhysicsShapeType.capsule);
    vm.addBody('thigh_l', PhysicsShapeType.capsule);
    vm.addConstraint('pelvis', 'spine_01');
    vm.disableCollisionBetween('thigh_l', 'pelvis');

    expect(vm.removeBody('spine_01'), isTrue);
    expect(vm.document.constraints, isEmpty, reason: 'the constraint lost an endpoint');
    expect(vm.document.bodyForBone('spine_01'), isNull);

    expect(vm.removeBody('thigh_l'), isTrue);
    expect(vm.document.disabledCollisionPairs, isEmpty);
    expect(vm.validationErrors, isEmpty);
    expect(await vm.save(), isTrue);

    final reopened = PhysicsAssetEditorViewModel(assetPath: physicsFile.path);
    await reopened.load();
    expect(reopened.document.bodies.single.boneName, 'pelvis');
    expect(reopened.document.constraints, isEmpty);
    expect(reopened.document.disabledCollisionPairs, isEmpty);
  });

  test('Validate Overlaps runs the engine narrow phase in bind pose and skips disabled pairs', () async {
    final vm = await loadVm();
    vm.addBody('pelvis', PhysicsShapeType.capsule);
    vm.addBody('spine_01', PhysicsShapeType.capsule);

    // Two capsules whose centres sit 60 cm apart (pelvis -> spine_01) with
    // radius 40 cm each: analytic capsuleVsCapsule depth = 80 - 60 = 20 cm.
    for (final bone in ['pelvis', 'spine_01']) {
      vm.setBodyRadius(bone, 40.0);
      vm.setBodyHalfHeight(bone, 40.0);
    }

    final results = vm.validateOverlaps();
    expect(results.length, 1);
    expect(results.single.isColliding, isTrue);
    expect(results.single.penetrationDepth, closeTo(20.0, 1e-6));
    expect(results.single.disabled, isFalse);
    expect(vm.lastValidationIsBindPose, isTrue);

    // Shrink one body: clean.
    vm.setBodyRadius('spine_01', 10.0);
    vm.setBodyHalfHeight('spine_01', 10.0);
    final clean = vm.validateOverlaps();
    expect(clean.where((r) => r.isColliding), isEmpty);

    // Disabled pairs are skipped but still labelled.
    vm.setBodyRadius('spine_01', 40.0);
    vm.setBodyHalfHeight('spine_01', 40.0);
    vm.disableCollisionBetween('pelvis', 'spine_01');
    final skipped = vm.validateOverlaps();
    expect(skipped.single.disabled, isTrue);
    expect(skipped.single.isColliding, isFalse, reason: 'a disabled pair is never reported as a hit');
  });

  test('body world transform equals entityWorld x G_bone x offset, in cm', () async {
    final vm = await loadVm();
    vm.entityWorld = Matrix4.translation(Vector3(300.0, 0.0, -100.0));
    vm.addBody('thigh_l', PhysicsShapeType.capsule);
    // Replace the auto-size's along-the-bone placement with a known offset.
    vm.setBodyOffsetLocation('thigh_l', 0, 5.0);
    vm.setBodyOffsetLocation('thigh_l', 1, 0.0);
    vm.setBodyOffsetLocation('thigh_l', 2, 2.0);
    for (var axis = 0; axis < 3; axis++) {
      vm.setBodyOffsetRotation('thigh_l', axis, 0.0);
    }

    // thigh_l's global is pelvis(identity) x (t=(0.1,-0.2,0) m, r=90° about Z),
    // drawn at the mesh's scale: t=(10,-20,0) cm, the same rotation.
    final gBone = Matrix4.compose(
      Vector3(10.0, -20.0, 0.0),
      Quaternion(0.0, 0.0, 0.7071067811865476, 0.7071067811865476),
      Vector3(1.0, 1.0, 1.0),
    );
    final offset = Matrix4.compose(
      Vector3(5.0, 0.0, 2.0),
      Quaternion.identity(),
      Vector3(1.0, 1.0, 1.0),
    );
    final expected = vm.entityWorld.multiplied(gBone).multiplied(offset);
    final actual = vm.bodyWorldTransform(vm.document.bodyForBone('thigh_l')!);
    for (int i = 0; i < 16; i++) {
      expect(actual.storage[i], closeTo(expected.storage[i], 1e-6), reason: 'element $i');
    }
    expect(vm.boneGlobal('spine_01')!.getTranslation().y, closeTo(60.0, 1e-6));
  });

  test('view modes gate the overlay line sets', () async {
    final vm = await loadVm();
    vm.addBody('pelvis', PhysicsShapeType.capsule);
    vm.addBody('spine_01', PhysicsShapeType.box);
    vm.addBody('thigh_l', PhysicsShapeType.sphere);
    vm.addConstraint('pelvis', 'spine_01');

    vm.setViewMode(PhysicsViewMode.wireframeBodies);
    var overlay = vm.buildOverlay();
    expect(overlay.where((s) => !s.isConstraint).length, 3, reason: 'one wireframe per authored body');
    expect(overlay.where((s) => s.isConstraint).length, 1);
    for (final set in overlay) {
      expect(set.positions.length % 3, 0);
      expect(set.lineIndices.length.isEven, isTrue);
      expect(set.lineIndices, isNotEmpty);
    }

    vm.setViewMode(PhysicsViewMode.constraintsOnly);
    overlay = vm.buildOverlay();
    expect(overlay.where((s) => !s.isConstraint), isEmpty, reason: 'body wireframes are hidden');
    expect(overlay.where((s) => s.isConstraint).length, 1, reason: 'constraint markers stay');

    vm.setViewMode(PhysicsViewMode.solidBodies);
    overlay = vm.buildOverlay();
    expect(overlay.where((s) => !s.isConstraint).length, 3);
    expect(overlay.firstWhere((s) => !s.isConstraint).filled, isTrue);

    vm.selectBody('spine_01');
    overlay = vm.buildOverlay();
    expect(overlay.firstWhere((s) => s.name == 'spine_01_Box').isSelected, isTrue);
  });

  testWidgets('PhysicsAssetSubEditor renders the real tree, inspector and validation — no ragdoll theater', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = (await tester.runAsync(loadVm))!;
    vm.addBody('pelvis', PhysicsShapeType.capsule);
    vm.addBody('spine_01', PhysicsShapeType.capsule);
    vm.setBodyRadius('pelvis', 40.0);
    vm.setBodyHalfHeight('pelvis', 40.0);
    vm.setBodyRadius('spine_01', 40.0);
    vm.setBodyHalfHeight('spine_01', 40.0);
    vm.addConstraint('pelvis', 'spine_01');

    Future<void> settle([int frames = 6]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 32));
      }
    }

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: PhysicsAssetSubEditor(
            assetName: 'PHYS_Hero',
            assetPath: physicsFile.path,
            viewModel: vm,
          ),
        ),
      ),
    );
    await tester.pump();

    // Real bones, real body rows, real constraint row.
    expect(find.text('pelvis'), findsWidgets);
    expect(find.text('spine_01'), findsWidgets);
    expect(find.text('pelvis_Capsule'), findsWidgets);
    expect(find.text('spine_01_Constraint'), findsWidgets);

    // The stub's fake simulation UI is gone for good.
    expect(find.text('Simulate Ragdoll'), findsNothing);
    expect(find.text('Stop Simulation'), findsNothing);
    expect(find.textContaining('LIVE SIMULATION ACTIVE'), findsNothing);
    expect(find.text('thigh_r_Capsule'), findsNothing);
    expect(find.text('head_Sphere'), findsNothing);

    // Selecting a body opens the body inspector.
    await tester.tap(find.byKey(const ValueKey('physics_body_row_pelvis')));
    await settle();
    expect(vm.selectedBody?.boneName, 'pelvis');
    expect(find.byKey(const ValueKey('physics_body_mass')), findsOneWidget);

    // Selecting the constraint swaps the inspector and Locked disables limits.
    await tester.tap(find.byKey(const ValueKey('physics_constraint_row_spine_01_Constraint')));
    await settle();
    expect(vm.selectedConstraint?.name, 'spine_01_Constraint');
    final swing1 = find.byKey(const ValueKey('physics_constraint_swing1'));
    expect(swing1, findsOneWidget);
    expect(tester.widget<TextField>(swing1).enabled, isTrue);

    vm.setConstraintMode('spine_01_Constraint', PhysicsAngularMode.locked);
    await settle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('physics_constraint_swing1'))).enabled, isFalse);

    // Validate Overlaps reports the real interpenetrating pair on screen.
    await tester.tap(find.byKey(const ValueKey('physics_validate_overlaps')));
    await settle();
    expect(find.textContaining('Bind Pose'), findsWidgets);
    expect(find.textContaining('pelvis_Capsule'), findsWidgets);
    expect(find.textContaining('depth 20.00 cm'), findsWidgets);
  });

  // The constraint inspector shares its fields across constraints
  // the way the body inspector does.
  testWidgets('selecting another constraint leaves the first one untouched and the asset clean', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = (await tester.runAsync(loadVm))!;
    vm.addBody('pelvis', PhysicsShapeType.capsule);
    vm.addBody('spine_01', PhysicsShapeType.capsule);
    vm.addBody('thigh_l', PhysicsShapeType.capsule);
    vm.addConstraint('pelvis', 'spine_01');
    vm.addConstraint('pelvis', 'thigh_l');
    vm.setConstraintSwing1('spine_01_Constraint', 42.0);
    vm.setConstraintTwist('spine_01_Constraint', -17.5);
    expect((await tester.runAsync(vm.save))!, isTrue);
    vm.selectConstraint('spine_01_Constraint');

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: PhysicsAssetSubEditor(assetName: 'PHYS_Hero', assetPath: physicsFile.path, viewModel: vm)),
    ));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('physics_constraint_row_thigh_l_Constraint')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(vm.selectedConstraint?.name, 'thigh_l_Constraint');
    final first = vm.document.constraintByName('spine_01_Constraint')!;
    expect(first.swing1Deg, 42.0);
    expect(first.twistDeg, -17.5);
    expect(vm.document.constraintByName('thigh_l_Constraint')!.swing1Deg, 45.0);
    expect(vm.isDirty, isFalse);
    expect(tester.takeException(), isNull);
  });
}
