// The Static Mesh editor's authored simple collision
// (`metadata['collision']`) read by MeshCollisionService, on real FBX
// imports in a temp project, and baked into the generated level.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import '../helpers/analyze_generated_project.dart';

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

File _fbx(String name) => File('${_assets.path}/FBX/StaticMeshes/$name.FBX');

/// The mesh's bounds in the authoring frame (cm, Z up), from its GLB (metres,
/// Y up): what the Static Mesh editor generates shapes from.
({List<double> min, List<double> max}) _authoringBounds(GlbMeshData mesh) {
  final a = MeshCollisionService.toAuthoring(mesh.minBounds[0], mesh.minBounds[1], mesh.minBounds[2]);
  final b = MeshCollisionService.toAuthoring(mesh.maxBounds[0], mesh.maxBounds[1], mesh.maxBounds[2]);
  return (
    min: [for (var i = 0; i < 3; i++) a[i] < b[i] ? a[i] : b[i]],
    max: [for (var i = 0; i < 3; i++) a[i] > b[i] ? a[i] : b[i]],
  );
}

/// Writes [collision] (the editor's document) into the mesh `.lmas`.
void _writeCollision(String lmas, Map<String, dynamic>? collision) {
  final asset = LuminaAsset.fromBytes(File(lmas).readAsBytesSync());
  final metadata = Map<String, String>.from(asset.metadata);
  if (collision == null) {
    metadata.remove('collision');
  } else {
    metadata['collision'] = jsonEncode(collision);
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

Aabb3 _drawnBounds(GlbMeshData mesh, LuminaStaticMeshComponent component) {
  final t = component.renderTransform;
  final lo = Vector3.all(double.infinity);
  final hi = Vector3.all(-double.infinity);
  for (var i = 0; i < 8; i++) {
    final w = t.transform3(Vector3(
      i & 1 == 0 ? mesh.minBounds[0] : mesh.maxBounds[0],
      i & 2 == 0 ? mesh.minBounds[1] : mesh.maxBounds[1],
      i & 4 == 0 ? mesh.minBounds[2] : mesh.maxBounds[2],
    ));
    Vector3.min(lo, w, lo);
    Vector3.max(hi, w, hi);
  }
  return Aabb3.minMax(lo, hi);
}

void main() {
  group('authoredCollisionInCentimetres (the one converter)', () {
    test('a legacy document (glTF metres, Y up, unmarked) is converted to cm, Z up, and marked', () {
      final legacy = {
        'complexity': 'default',
        'shapes': [
          {'type': 'box', 'center': [0.0, 0.5, 0.0], 'extents': [0.3, 0.5, 0.2]},
          {'type': 'sphere', 'center': [0.1, 0.2, 0.3], 'radius': 0.4},
          {'type': 'capsule', 'center': [0.0, 1.0, 0.0], 'radius': 0.1, 'halfHeight': 0.8, 'axis': 'Y'},
          {
            'type': 'convex',
            'center': [0.0, 0.0, 0.0],
            'points': [
              [0.1, 0.2, 0.3],
              [-0.1, 0.0, -0.3],
            ],
          },
        ],
      };
      final cm = MeshCollisionService.authoredCollisionInCentimetres(legacy);
      expect(cm['world_units'], 'cm');
      expect(cm['up_axis'], 'z');
      final shapes = (cm['shapes'] as List).cast<Map>();
      expect(shapes[0]['center'], [0.0, 0.0, 50.0]);
      expect(shapes[0]['extents'], [30.0, 20.0, 50.0]);
      expect(shapes[1]['center'], [10.0, -30.0, 20.0]);
      expect(shapes[1]['radius'], 40.0);
      expect(shapes[2]['center'], [0.0, 0.0, 100.0]);
      expect(shapes[2]['radius'], 10.0);
      expect(shapes[2]['halfHeight'], 80.0);
      expect(shapes[2]['axis'], 'Z', reason: 'glTF +Y is authored +Z');
      expect(shapes[3]['points'], [
        [10.0, -30.0, 20.0],
        [-10.0, 30.0, 0.0],
      ]);
      expect(MeshCollisionService.authoredCollisionInCentimetres(cm), cm, reason: 'converting twice is a no-op');
      expect(legacy.containsKey('world_units'), isFalse, reason: 'the input is not modified');
    });

    test('simpleCollisionFromMetadata reads both frames the same way', () {
      final legacy = {
        'collision': jsonEncode({
          'complexity': 'use_simple_as_complex',
          'shapes': [
            {'type': 'box', 'center': [0.0, 0.5, 0.0], 'extents': [0.3, 0.5, 0.2]},
          ],
        }),
      };
      final marked = {
        'collision': jsonEncode({
          'world_units': 'cm',
          'up_axis': 'z',
          'complexity': 'use_simple_as_complex',
          'shapes': [
            {'type': 'box', 'center': [0.0, 0.0, 50.0], 'extents': [30.0, 20.0, 50.0]},
          ],
        }),
      };
      for (final metadata in [legacy, marked]) {
        final c = MeshCollisionService.simpleCollisionFromMetadata(metadata);
        expect(c.complexity, 'use_simple_as_complex');
        expect(c.hulls, isEmpty);
        final box = c.primitives.single;
        expect(box.kind, LuminaCollisionPrimitiveKind.box);
        expect(box.center, [0.0, 0.0, 50.0]);
        expect(box.halfExtents, [30.0, 20.0, 50.0]);
      }
      expect(MeshCollisionService.simpleCollisionFromMetadata(const {}).isEmpty, isTrue);
    });
  });

  final haveAssets = _fbx('SM_Counter_1').existsSync() && _fbx('SM_Casino_Chair').existsSync();
  late Directory project;
  String lmas(String name) => '${project.path}/contents/meshes/static/$name.lmas';
  late GlbMeshData counter;
  late Map<String, dynamic> counterBox;

  setUpAll(() async {
    if (!haveAssets) return;
    project = Directory.systemTemp.createTempSync('lumina_authored_collision_');
    Directory('${project.path}/contents/meshes/static').createSync(recursive: true);
    for (final prop in ['SM_Counter_1', 'SM_Casino_Chair']) {
      final result = await ImportAssetUseCase()(projectDir: project.path, sourceFilePath: _fbx(prop).path);
      expect(result.isSuccess, isTrue, reason: '$prop: ${result.error}');
    }
    counter = (await AssetRepository.loadMeshFromDisk(lmas('SM_Counter_1')))!;
    final b = _authoringBounds(counter);
    // The editor's Box: bounds centre and half extents, cm, Z up.
    counterBox = {
      'world_units': 'cm',
      'up_axis': 'z',
      'complexity': 'default',
      'shapes': [
        {
          'type': 'box',
          'center': [for (var i = 0; i < 3; i++) (b.min[i] + b.max[i]) / 2],
          'extents': [for (var i = 0; i < 3; i++) (b.max[i] - b.min[i]) / 2],
        },
      ],
    };
  });

  tearDownAll(() {
    if (haveAssets && project.existsSync()) project.deleteSync(recursive: true);
  });

  group('on real imports', () {
    test('SM_Counter_1 (no UCX_) with an authored box: one box, and it wraps the drawn counter exactly', () {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      expect(MeshCollisionService.simpleCollisionForMeshAsset(lmas('SM_Counter_1')).isEmpty, isTrue);
      _writeCollision(lmas('SM_Counter_1'), counterBox);
      final collision = MeshCollisionService.simpleCollisionForMeshAsset(lmas('SM_Counter_1'));
      expect(collision.hulls, isEmpty);
      final box = collision.primitives.single;
      expect(box.halfExtents[0] * 2, closeTo(812, 1), reason: 'the counter is 8.12 m long');
      expect(box.halfExtents[2] * 2, closeTo(110, 1), reason: 'and 1.1 m tall, along authored Z');

      final actor = LuminaStaticMeshActor(
        meshAssetPath: lmas('SM_Counter_1'),
        location: LuminaAxes.location([250, -40, 0]),
        rotation: LuminaAxes.rotation([0, 0, 90]),
        collisionHulls: collision.hulls,
        collisionPrimitives: collision.primitives,
      );
      final collider = actor.collisionComponents.single.getAABB();
      final drawn = _drawnBounds(counter, actor.meshComponent);
      for (var axis = 0; axis < 3; axis++) {
        expect(collider.min[axis], closeTo(drawn.min[axis], 0.5), reason: 'axis $axis min');
        expect(collider.max[axis], closeTo(drawn.max[axis], 0.5), reason: 'axis $axis max');
      }
    });

    test('SM_Casino_Chair: its 4 UCX_ pieces plus an authored sphere', () {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      _writeCollision(lmas('SM_Casino_Chair'), {
        'world_units': 'cm',
        'up_axis': 'z',
        'complexity': 'default',
        'shapes': [
          {'type': 'sphere', 'center': [0.0, 0.0, 50.0], 'radius': 45.0},
        ],
      });
      final collision = MeshCollisionService.simpleCollisionForMeshAsset(lmas('SM_Casino_Chair'));
      expect(collision.hulls, hasLength(4));
      expect(collision.primitives.single.kind, LuminaCollisionPrimitiveKind.sphere);
      expect(MeshCollisionService.hullsForMeshAsset(lmas('SM_Casino_Chair')), hasLength(4));
    });

    for (final withBox in [true, false]) {
      test(withBox ? 'a character walking at the counter stops at its authored box' : 'and walks through it without one', () {
        if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
        _writeCollision(lmas('SM_Counter_1'), withBox ? counterBox : null);
        final collision = MeshCollisionService.simpleCollisionForMeshAsset(lmas('SM_Counter_1'));
        final world = LuminaWorld(worldType: LuminaWorldType.game);
        final sys = world.registerSubsystem(LuminaCollisionSubsystem());
        final floor = LuminaActor(location: Vector3(0, -50, 0));
        final floorBox = LuminaCollisionComponent(shapeType: CollisionShapeType.box)..boxExtent = Vector3(3000, 50, 3000);
        CollisionProfile.applyBlockAll(floorBox);
        floor.addComponent(floorBox);
        world.persistentLevel.registerActor(floor);
        final prop = LuminaStaticMeshActor(
          meshAssetPath: lmas('SM_Counter_1'),
          location: LuminaAxes.location([0, 400, 0]),
          collisionPrimitives: collision.primitives,
        );
        world.persistentLevel.registerActor(prop);
        final character = LuminaCharacter(location: Vector3(0, 80.2, 0));
        world.persistentLevel.registerActor(character);
        world.beginPlay();
        final overlaps = <LuminaCollisionComponent>[];
        for (var frame = 0; frame < 300; frame++) {
          character.characterMovement.addInputVector(Vector3(0, 0, -1));
          world.tick(1 / 60);
          sys.overlapTest(character.capsuleComponent.worldShape, character.capsuleComponent.worldTransform, overlaps,
              ignore: character.capsuleComponent);
          expect(overlaps.where(prop.collisionComponents.contains), isEmpty, reason: 'frame $frame');
        }
        if (withBox) {
          final nearFace = prop.collisionComponents.single.getAABB().max.z;
          expect(character.actorLocation.z, closeTo(nearFace + character.capsuleComponent.radius, 0.5));
        } else {
          expect(character.actorLocation.z, lessThan(-1000));
        }
        world.cleanup();
      });
    }
  });

  group('generated level', () {
    Map<String, dynamic> meshActor(String id, String path) => {
          'id': id,
          'name': id,
          'type': 'Mesh',
          'location': [0.0, 0.0, 0.0],
          'meshAssetPath': path,
        };

    test('bakes authored shapes as constants next to the hulls, and analyzes clean', () async {
      if (!haveAssets) return markTestSkipped('test-assets/FBX missing');
      _writeCollision(lmas('SM_Counter_1'), {...counterBox, 'complexity': 'use_complex_as_simple'});
      final code = DartCodeGeneratorService().generateLevelDart(
        levelName: 'L_Authored',
        actors: const [],
        actorMaps: [meshActor('counter', lmas('SM_Counter_1')), meshActor('chair', lmas('SM_Casino_Chair'))],
      );
      final counterLine = code.split('\n').firstWhere((l) => l.contains("LuminaObjectKey('counter')"));
      expect(counterLine, contains('LuminaStaticMeshActor('));
      expect(counterLine, contains('collisionPrimitives: const ['));
      expect(counterLine, isNot(contains('collisionHulls')));
      expect(code, contains('LuminaCollisionPrimitive.box(center: ['));
      expect(code, contains('LuminaCollisionPrimitive.sphere(center: [0.0000, 0.0000, 50.0000], radius: 45.0000)'));
      expect(code, contains("LuminaCollisionHull('UCX_SM_Casino_Chair_1', ["));
      expect(code, contains('Use Complex As Simple'), reason: 'the level says how it plays that setting');
      expect(code, isNot(contains(project.path)));

      final probe = Directory.systemTemp.createTempSync('lumina_authored_levelgen_');
      addTearDown(() => probe.deleteSync(recursive: true));
      File('${probe.path}/pubspec.yaml').writeAsStringSync('''
name: authored_levelgen_probe
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
  lumina:
    path: ${Directory.current.parent.path}/lumina
  vector_math: ^2.1.4
''');
      Directory('${probe.path}/lib/levels').createSync(recursive: true);
      File('${probe.path}/lib/levels/l_authored.dart').writeAsStringSync(code);
      File('${probe.path}/lib/main.dart')
          .writeAsStringSync(DartCodeGeneratorService().generateMainDart(projectName: 'authored_levelgen_probe', levelName: 'L_Authored'));
      final pubGet = await Process.run('flutter', ['pub', 'get', '--offline'], workingDirectory: probe.path, runInShell: Platform.isWindows);
      expect(pubGet.exitCode, 0, reason: 'pub get: ${pubGet.stdout}${pubGet.stderr}');
      final analyze = await analyzeGeneratedProject(probe.path);
      expect(analyze.exitCode, 0, reason: 'generated level must analyze clean:\n${analyze.stdout}\n${analyze.stderr}');
    }, timeout: const Timeout(Duration(minutes: 4)));
  });
}
