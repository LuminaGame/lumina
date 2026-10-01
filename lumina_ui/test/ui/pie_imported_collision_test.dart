// Imported collision (PIE side): a mesh imported from an Unreal FBX with
// UCX_ hulls plays with its simple collision in Play-In-Editor, built from the
// same data the generated level bakes in. Real FBX exports from
// test-assets/FBX/ through lumina's real import pipeline into a temp project.
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:vector_math/vector_math_64.dart';

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

File _fbx(String name) => File('${_assets.path}/FBX/StaticMeshes/$name.FBX');

void main() {
  final haveAssets = _fbx('SM_Casino_Chair').existsSync() && _fbx('SM_Counter_1').existsSync();
  late Directory project;
  String lmas(String name) => '${project.path}/contents/meshes/static/$name.lmas';

  setUpAll(() async {
    if (!haveAssets) return;
    project = Directory.systemTemp.createTempSync('lumina_ui_pie_ucx_');
    Directory('${project.path}/contents/meshes/static').createSync(recursive: true);
    for (final prop in ['SM_Casino_Chair', 'SM_Counter_1']) {
      final result = await ImportAssetUseCase()(projectDir: project.path, sourceFilePath: _fbx(prop).path);
      expect(result.isSuccess, isTrue, reason: '$prop: ${result.error}');
    }
  });

  tearDownAll(() {
    if (haveAssets && project.existsSync()) project.deleteSync(recursive: true);
  });

  EditorActorNode chairNode({String type = 'Mesh'}) => EditorActorNode(
        id: 'chair',
        name: 'SM_Casino_Chair_1',
        type: type,
        location: [250, -40, 0],
        rotation: [0, 0, 90],
        meshAssetPath: lmas('SM_Casino_Chair'),
      );

  EditorActorNode floorNode() => EditorActorNode(
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

  test('a mesh with imported hulls plays as a LuminaStaticMeshActor with one convex collider per piece', () {
    if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
    final actor = EditorPieGame.mapEditorActor(chairNode());
    expect(actor, isA<LuminaStaticMeshActor>());
    final chair = actor as LuminaStaticMeshActor;
    expect(chair.meshComponent.meshAssetPath, lmas('SM_Casino_Chair'));
    expect(chair.collisionComponents, hasLength(4));
    expect(chair.collisionComponents.every((c) => c.shapeType == CollisionShapeType.convex), isTrue);

    // The same hulls the generated level bakes in.
    final code = DartCodeGeneratorService().generateLevelDart(
      levelName: 'L_Pie',
      actors: const [],
      actorMaps: [chairNode().toMap()],
    );
    for (final hull in chair.collisionHulls) {
      expect(code, contains("LuminaCollisionHull('${hull.name}', ["));
    }
    expect(chair.collisionHulls.map((h) => h.points), MeshCollisionService.hullsForMeshAsset(lmas('SM_Casino_Chair')).map((h) => h.points));
  });

  test('a mesh without hulls keeps the plain mesh actor and no collision', () {
    if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
    final actor = EditorPieGame.mapEditorActor(EditorActorNode(
      id: 'counter',
      name: 'SM_Counter_1',
      type: 'Mesh',
      location: [0, 0, 0],
      meshAssetPath: lmas('SM_Counter_1'),
    )) as LuminaActor;
    expect(actor, isNot(isA<LuminaStaticMeshActor>()));
    expect(actor.rootComponent, isA<LuminaStaticMeshComponent>());
    expect(actor.components.whereType<LuminaCollisionComponent>(), isEmpty);
  });

  for (final withHulls in [true, false]) {
    test(withHulls ? 'in a PIE world a character walking into the chair is stopped by its hulls' : 'without hulls it walks through', () {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      // Same mesh; as a skeletal mesh it has no simple collision (skeletal
      // meshes collide through a physics asset, not UCX_ hulls).
      final chairActor = chairNode(type: withHulls ? 'Mesh' : 'SkeletalMesh');
      final game = EditorPieGame([floorNode(), chairActor]);
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      game.mountIntoWorldForTest(world);
      final collision = world.getSubsystem<LuminaCollisionSubsystem>()!;
      final chair = world.persistentLevel.actors.firstWhere((a) => a.key == const ValueKey('chair'));
      final hullComponents = chair.components.whereType<LuminaCollisionComponent>().toList();
      expect(hullComponents, hasLength(withHulls ? 4 : 0));

      // The chair sits at runtime (250, 0, 40); walk at it from +Z.
      final character = LuminaCharacter(location: Vector3(250, 80.5, 300));
      world.spawnActor(character);
      final overlaps = <LuminaCollisionComponent>[];
      for (var frame = 0; frame < 240; frame++) {
        character.characterMovement.addInputVector(Vector3(0, 0, -1));
        world.tick(1 / 60);
        collision.overlapTest(character.capsuleComponent.worldShape, character.capsuleComponent.worldTransform, overlaps,
            ignore: character.capsuleComponent);
        expect(overlaps.where(hullComponents.contains), isEmpty, reason: 'frame $frame: the capsule is inside the chair');
      }
      if (withHulls) {
        expect(character.actorLocation.z, greaterThan(40), reason: 'stopped in front of the chair');
        expect(character.actorLocation.z, lessThan(300 - 100), reason: 'but it did walk up to it');
      } else {
        expect(character.actorLocation.z, lessThan(-300), reason: 'nothing to stop it');
      }
      world.cleanup();
    });
  }
}
