import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

/// A running game loads its assets through [LuminaAssets] (the
/// Flutter asset bundle in a generated game), never through `File`: the web
/// has no file system. Mounted under [IOOverrides] that throw on any file or
/// directory access.
class _ThirdPersonGame extends LuminaGame {
  _ThirdPersonGame(this.meshPath);
  final String meshPath;

  @override
  LuminaObject? build(LuminaBuildContext context) {
    final world = context.world!;
    world.registerSubsystem(LuminaCollisionSubsystem());
    final actors = <LuminaObject>[
      LuminaActor(root: LuminaSkyComponent.color(color: Vector4(0.35, 0.53, 0.78, 1))),
      // A static mesh with no provider of its own: only LuminaAssets can serve it.
      LuminaActor(root: LuminaStaticMeshComponent(meshAssetPath: meshPath)),
      LuminaTemplateCharacter(thirdPerson: true, meshAssetPath: meshPath, location: Vector3(0, 1, 0)),
    ];
    for (final actor in GameTemplateCatalog.thirdPerson.levelActors) {
      if (actor['type'] != 'Primitive') continue;
      final loc = (actor['location'] as List).cast<double>();
      final props = Map<String, dynamic>.from(((actor['components'] as List).first as Map)['properties'] as Map);
      actors.add(LuminaPrimitiveActor.fromComponentProperties(props, location: Vector3(loc[0], loc[1], loc[2])));
    }
    return LuminaNodeGroup(children: actors);
  }
}

void main() {
  test('a mounted Third Person game loads every asset through LuminaAssets, with no File access', () async {
    const meshPath = 'contents/meshes/skeletal/SKM_Superhero_Female.entity.glb';
    final bundled = File(LuminaThirdPersonContent.bundledMeshPath).readAsBytesSync();
    final served = <String>[];
    LuminaAssets.defaultProvider = (path) async {
      served.add(path);
      if (path != meshPath) throw StateError('no bundled asset $path');
      return Uint8List.fromList(bundled);
    };
    addTearDown(() => LuminaAssets.defaultProvider = null);

    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    final scene = engine.createScene();
    final fileAccess = <String>[];
    final game = _ThirdPersonGame(meshPath);

    await IOOverrides.runZoned(
      () async {
        game.mountGame(engine, scene);
        game.world!.beginPlay();
        for (var i = 0; i < 30; i++) {
          game.tickGame(1 / 60);
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        final character = game.world!.persistentLevel.actors.whereType<LuminaTemplateCharacter>().single;
        await character.bodyMesh!.loaded;
      },
      createFile: (path) {
        fileAccess.add(path);
        throw FileSystemException('file access in a running game', path);
      },
      createDirectory: (path) {
        fileAccess.add(path);
        throw FileSystemException('directory access in a running game', path);
      },
    );

    expect(fileAccess, isEmpty);
    expect(served, contains(meshPath));
    game.disposeGame();
    scene.dispose();
    engine.dispose();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
