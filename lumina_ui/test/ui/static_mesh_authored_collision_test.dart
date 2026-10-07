// The Static Mesh editor authors
// simple collision in centimetres, Z up (like everything stored), migrates
// documents written in the GLB's metres / Y up, and what it saves collides in
// Play-In-Editor. Real FBX exports from test-assets/FBX/ through lumina's
// real import pipeline into a temp project.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show ShadcnApp, Scaffold, Size;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/static_mesh_collision.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/static_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/static_mesh_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:vector_math/vector_math_64.dart';

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

File _fbx(String name) => File('${_assets.path}/FBX/StaticMeshes/$name.FBX');

Map<String, dynamic> _storedCollision(String lmas) =>
    jsonDecode(LuminaAsset.fromBytes(File(lmas).readAsBytesSync()).metadata['collision']!) as Map<String, dynamic>;

void _writeMetadata(String lmas, String key, String? value) {
  final asset = LuminaAsset.fromBytes(File(lmas).readAsBytesSync());
  final metadata = Map<String, String>.from(asset.metadata);
  if (value == null) {
    metadata.remove(key);
  } else {
    metadata[key] = value;
  }
  File(lmas).writeAsBytesSync(LuminaAsset(
    assetId: asset.assetId,
    name: asset.name,
    type: asset.type,
    hasThumbnail: asset.hasThumbnail,
    thumbnailPng: asset.thumbnailPng,
    rawPayload: asset.rawPayload,
    rawMatSource: asset.rawMatSource,
    references: asset.references,
    metadata: metadata,
  ).toProtoBufferBytes());
}

void main() {
  final haveAssets = _fbx('SM_Counter_1').existsSync() && _fbx('SM_Casino_Chair').existsSync();
  late Directory project;
  late String counter;
  late String chair;

  setUpAll(() async {
    if (!haveAssets) return;
    project = Directory.systemTemp.createTempSync('lumina_ui_authored_collision_');
    Directory('${project.path}/contents/meshes/static').createSync(recursive: true);
    final result = await ImportAssetUseCase()(projectDir: project.path, sourceFilePath: _fbx('SM_Counter_1').path);
    expect(result.isSuccess, isTrue, reason: result.error);
    counter = '${project.path}/${result.asset!.relativePath}';
    final chairImport = await ImportAssetUseCase()(projectDir: project.path, sourceFilePath: _fbx('SM_Casino_Chair').path);
    expect(chairImport.isSuccess, isTrue, reason: chairImport.error);
    chair = '${project.path}/${chairImport.asset!.relativePath}';
  });

  tearDownAll(() {
    if (haveAssets && project.existsSync()) project.deleteSync(recursive: true);
  });

  /// The counter with the Static Mesh editor's generated Box saved — what the
  /// save test leaves behind and the tests after it build on. Each of those
  /// makes it itself: a sharded run (`--total-shards`) runs every
  /// test of this file in its own process, where no earlier test ran.
  Future<void> saveGeneratedBox() async {
    final vm = StaticMeshEditorViewModel(assetPath: counter);
    await vm.load();
    vm.generateCollision(StaticMeshCollisionShapeType.box);
    expect(await vm.save(), isTrue);
  }

  group('authored in centimetres, Z up', () {
    test('the Stats card reads the counter in cm with its height along Z', () async {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      final vm = StaticMeshEditorViewModel(assetPath: counter);
      await vm.load();
      expect(vm.boundsWidth, closeTo(812, 1), reason: 'X: 8.12 m long');
      expect(vm.boundsDepth, closeTo(272, 1), reason: 'Y: 2.72 m deep');
      expect(vm.boundsHeight, closeTo(110, 1), reason: 'Z: 1.1 m tall');
      expect(vm.minBounds[2], closeTo(0, 0.5), reason: 'stands on z = 0');
    });

    test('a generated Box is saved in cm, Z up, and says so', () async {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      final vm = StaticMeshEditorViewModel(assetPath: counter);
      await vm.load();
      vm.generateCollision(StaticMeshCollisionShapeType.box);
      final box = vm.collisionShapes.single;
      expect(box.extents![0], closeTo(406, 0.5));
      expect(box.extents![1], closeTo(136, 0.5));
      expect(box.extents![2], closeTo(55, 0.5));
      expect(box.center[2], closeTo(55, 0.5), reason: 'half its height above the floor');
      vm.generateCollision(StaticMeshCollisionShapeType.capsule);
      expect(vm.collisionShapes.single.axis, 'X', reason: 'the counter\'s long axis');
      vm.generateCollision(StaticMeshCollisionShapeType.box);
      expect(await vm.save(), isTrue);

      final stored = _storedCollision(counter);
      expect(stored['world_units'], 'cm');
      expect(stored['up_axis'], 'z');
      final shape = (stored['shapes'] as List).single as Map;
      expect(shape['type'], 'box');
      expect((shape['extents'] as List)[2], closeTo(55, 0.5));
    });

    test('a document written in metres, Y up is converted on load without dirtying the asset', () async {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      await saveGeneratedBox();
      final before = _storedCollision(counter);
      // What the editor wrote before the fix: the same box in glTF metres, Y up.
      _writeMetadata(counter, 'collision', jsonEncode({
        'complexity': 'use_simple_as_complex',
        'shapes': [
          {'type': 'box', 'center': [0.0, 0.55, 0.0], 'extents': [4.06, 0.55, 1.36]},
          {'type': 'capsule', 'center': [0.0, 0.55, 0.0], 'radius': 0.55, 'halfHeight': 3.51, 'axis': 'X'},
        ],
      }));
      final vm = StaticMeshEditorViewModel(assetPath: counter);
      await vm.load();
      expect(vm.collisionMigratedFromMetres, isTrue);
      expect(vm.isDirty, isFalse);
      expect(vm.collisionComplexity, 'use_simple_as_complex');
      final box = vm.collisionShapes.first;
      expect(box.center, [0.0, 0.0, 55.0]);
      expect(box.extents, [406.0, 136.0, 55.0]);
      final capsule = vm.collisionShapes.last;
      expect(capsule.radius, 55.0);
      expect(capsule.halfHeight, 351.0);
      expect(capsule.axis, 'X');
      await vm.save();
      expect(_storedCollision(counter)['world_units'], 'cm', reason: 'the next Save writes cm');
      final reloaded = StaticMeshEditorViewModel(assetPath: counter);
      await reloaded.load();
      expect(reloaded.collisionMigratedFromMetres, isFalse, reason: 'never converted twice');
      expect(reloaded.collisionShapes.first.extents, [406.0, 136.0, 55.0]);
      _writeMetadata(counter, 'collision', jsonEncode(before));
    });
  });

  // "Convex (hull)" wrote the 8 bounding-box corners.
  test('Convex (hull) is the hull of the mesh\'s vertices, in cm, Z up', () async {
    if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
    final vm = StaticMeshEditorViewModel(assetPath: chair);
    await vm.load();
    vm.generateCollision(StaticMeshCollisionShapeType.convex);
    final points = [for (final p in vm.collisionShapes.single.points!) Vector3(p[0], p[1], p[2])];
    final vertices = [
      for (var i = 0; i < vm.glbMesh!.positions.length; i += 3)
        Vector3.array(MeshCollisionService.toAuthoring(
            vm.glbMesh!.positions[i], vm.glbMesh!.positions[i + 1], vm.glbMesh!.positions[i + 2])),
    ];
    bool isCorner(Vector3 p) => [
          for (var a = 0; a < 3; a++)
            (p[a] - vm.minBounds[a]).abs() < 0.01 || (p[a] - vm.maxBounds[a]).abs() < 0.01,
        ].every((b) => b);
    expect(points.length, greaterThan(8));
    expect(points.where(isCorner).length, lessThan(8), reason: 'not the bounding box');
    for (final p in points) {
      expect(vertices.any((v) => v.distanceTo(p) < 0.01), isTrue, reason: '$p is a mesh vertex');
    }
    final hull = ConvexHullShape(points);
    for (final v in vertices) {
      for (final plane in hull.planes) {
        expect(plane.normal.dot(v) - plane.offset, lessThan(0.05), reason: 'vertex $v is inside the hull');
      }
    }
    expect(vm.boundsHeight, closeTo(96.8, 0.5));
  });

  // The collision view toggle only recoloured its icon.
  testWidgets('the collision view draws the generated shapes over the mesh, in the viewport\'s frame, and hides them', (tester) async {
    if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = StaticMeshEditorViewModel(assetPath: counter);
    await tester.runAsync(() => vm.load());
    vm.generateCollision(StaticMeshCollisionShapeType.box);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: StaticMeshSubEditor(assetName: 'SM_Counter_1', assetPath: counter, viewModel: vm)),
    ));
    SubEditor3DViewport viewport() => tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport));

    expect(vm.showCollisionWireframe, isTrue);
    final lines = viewport().collisionLines!;
    expect(lines.positions.length, 8 * 3, reason: 'a box: 8 corners');
    expect(lines.indices.length, 12 * 2, reason: '12 edges');
    // The viewport draws the GLB as it is (metres, Y up): the box's corners
    // are the mesh's bounds there.
    final mesh = vm.glbMesh!;
    for (var i = 0; i < lines.positions.length; i += 3) {
      for (var a = 0; a < 3; a++) {
        final v = lines.positions[i + a];
        expect((v - mesh.minBounds[a]).abs() < 1e-3 || (v - mesh.maxBounds[a]).abs() < 1e-3, isTrue,
            reason: 'corner coordinate $v on axis $a is a bound of the GLB');
      }
    }

    vm.toggleCollisionWireframe();
    await tester.pump();
    expect(viewport().collisionLines, isNull, reason: 'toggled off');
    vm.toggleCollisionWireframe();
    vm.generateCollision(StaticMeshCollisionShapeType.sphere);
    await tester.pump();
    expect(viewport().collisionLines!.indices.length, 3 * 32 * 2, reason: 'a sphere: three 32-segment circles');
    vm.generateCollision(StaticMeshCollisionShapeType.capsule);
    await tester.pump();
    expect(viewport().collisionLines!.indices, isNotEmpty);
    vm.removeCollision();
    await tester.pump();
    expect(viewport().collisionLines, isNull, reason: 'nothing to draw');
  });

  testWidgets('Use Complex As Simple says the runtime plays it with its simple collision', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final file = File('${Directory.systemTemp.createTempSync('lumina_ui_complexity_').path}/SM_Box.lmas');
    addTearDown(() => file.parent.deleteSync(recursive: true));
    const asset = LuminaAsset(assetId: 'SM_Box', name: 'SM_Box', type: AssetType.filamesh, metadata: {'sections': '1'});
    file.writeAsBytesSync(asset.toProtoBufferBytes());
    final vm = StaticMeshEditorViewModel(assetPath: file.path, initialAsset: asset);
    await tester.runAsync(() => vm.load());
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: StaticMeshSubEditor(assetName: 'SM_Box', assetPath: file.path, viewModel: vm)),
    ));
    const note = 'No per-triangle collision at runtime yet: this mesh plays with its simple collision, as Default.';
    expect(find.text(note), findsNothing);
    vm.setCollisionComplexity('use_complex_as_simple');
    await tester.pump();
    expect(find.text(note), findsOneWidget);
  });

  group('what the editor saves collides in Play-In-Editor', () {
    EditorActorNode counterNode() => EditorActorNode(
          id: 'counter',
          name: 'SM_Counter_1_1',
          type: 'Mesh',
          location: [250, -40, 0],
          rotation: [0, 0, 90],
          meshAssetPath: counter,
        );

    test('PIE maps the counter to a LuminaStaticMeshActor whose authored box wraps the drawn mesh', () async {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      final vm = StaticMeshEditorViewModel(assetPath: counter);
      await vm.load();
      vm.generateCollision(StaticMeshCollisionShapeType.box);
      await vm.save();

      final actor = EditorPieGame.mapEditorActor(counterNode());
      expect(actor, isA<LuminaStaticMeshActor>());
      final counterActor = actor as LuminaStaticMeshActor;
      expect(counterActor.collisionHulls, isEmpty, reason: 'SM_Counter_1 has no UCX_ hull');
      expect(counterActor.collisionComponents.single.shapeType, CollisionShapeType.box);

      final mesh = (await AssetRepository.loadMeshFromDisk(counter))!;
      final t = counterActor.meshComponent.renderTransform;
      final lo = Vector3.all(double.infinity), hi = Vector3.all(-double.infinity);
      for (var i = 0; i < 8; i++) {
        final w = t.transform3(Vector3(
          i & 1 == 0 ? mesh.minBounds[0] : mesh.maxBounds[0],
          i & 2 == 0 ? mesh.minBounds[1] : mesh.maxBounds[1],
          i & 4 == 0 ? mesh.minBounds[2] : mesh.maxBounds[2],
        ));
        Vector3.min(lo, w, lo);
        Vector3.max(hi, w, hi);
      }
      final box = counterActor.collisionComponents.single.getAABB();
      for (var axis = 0; axis < 3; axis++) {
        expect(box.min[axis], closeTo(lo[axis], 0.5), reason: 'axis $axis min');
        expect(box.max[axis], closeTo(hi[axis], 0.5), reason: 'axis $axis max');
      }
    });

    test('in a PIE world a character walking at the counter stops at its authored box', () async {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      await saveGeneratedBox();
      final floor = EditorActorNode(
        id: 'floor',
        name: 'Floor',
        type: 'Primitive',
        location: [0, 0, -10],
        components: [
          EditorComponentNode(
            id: 'floor_mesh',
            name: 'Mesh',
            type: 'LuminaProceduralMeshComponent',
            properties: {'shape': 'box', 'sizeX': 3000.0, 'sizeY': 3000.0, 'sizeZ': 20.0, 'colorHex': '#808080'},
          ),
        ],
      );
      final game = EditorPieGame([floor, counterNode()]);
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      game.mountIntoWorldForTest(world);
      final collision = world.getSubsystem<LuminaCollisionSubsystem>()!;
      final prop = world.persistentLevel.actors.firstWhere((a) => a.key == const LuminaObjectKey('counter')) as LuminaStaticMeshActor;
      // Yaw 90 turns the counter's length (authoring +X) to authoring −Y, so
      // it runs along runtime +z from its pivot at z 40, and its depth
      // (authoring −Y) to −X, ending at x 250. Walk at its middle along −x.
      final box = prop.collisionComponents.single.getAABB();
      expect(box.min.z, lessThan(445), reason: 'the walk line crosses the counter');
      expect(box.max.z, greaterThan(445), reason: 'the walk line crosses the counter');
      final character = LuminaCharacter(location: Vector3(700, 80.5, 445));
      world.spawnActor(character);
      final overlaps = <LuminaCollisionComponent>[];
      for (var frame = 0; frame < 240; frame++) {
        character.characterMovement.addInputVector(Vector3(-1, 0, 0));
        world.tick(1 / 60);
        collision.overlapTest(character.capsuleComponent.worldShape, character.capsuleComponent.worldTransform, overlaps,
            ignore: character.capsuleComponent);
        expect(overlaps.where(prop.collisionComponents.contains), isEmpty, reason: 'frame $frame');
      }
      final face = box.max.x;
      expect(character.actorLocation.x, closeTo(face + character.capsuleComponent.radius, 0.5));
      world.cleanup();
    });
  });
}
