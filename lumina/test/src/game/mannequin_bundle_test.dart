import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// The rebuilt character bundle, loaded through gltfio on a
/// real (headless) engine, plays 25 clips — the eight jogs among
/// them — each with a positive length.
void main() {
  test('the bundle lists 25 clips including the eight jogs, each longer than zero', () async {
    const bundle = LuminaThirdPersonContent.bundledMeshPath;
    if (!File(bundle).existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
    final engine = FilamentEngine.create(backend: FilamentBackend.noop);
    if (engine == null) return markTestSkipped('no native assets');
    final scene = engine.createScene();
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.initializeNativeContext(engine, scene);
    addTearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });
    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: bundle);
    world.persistentLevel.registerActor(LuminaActor(root: mesh));
    world.beginPlay();
    await mesh.loaded;

    expect(mesh.clipNames, hasLength(25));
    expect(mesh.clipNames, LuminaThirdPersonContent.clipNames, reason: 'gltfio index order is the merge order');
    expect(mesh.clipNames, containsAll(LuminaThirdPersonClips.jogs));
    for (final clip in mesh.clipNames) {
      expect(mesh.clipDuration(clip), greaterThan(0.0), reason: clip);
    }
    // The jogs play: the forward jog loops on the mesh.
    mesh.play('Jog_Fwd_Loop');
    world.tick(1 / 60);
    expect(mesh.currentClip, 'Jog_Fwd_Loop');
    expect(mesh.missingClip, isNull);
  });
}
