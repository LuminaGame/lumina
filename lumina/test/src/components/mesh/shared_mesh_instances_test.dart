import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Many components drawing one cached skinned mesh each get their own
/// instance, and every one finishes loading.
void main() {
  test('twelve instances of one cached skinned mesh all finish loading', () async {
    const bundle = LuminaThirdPersonContent.bundledMeshPath;
    if (!File(bundle).existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    final scene = engine.createScene();
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    addTearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });
    final meshes = [for (var i = 0; i < 12; i++) LuminaAnimatedMeshComponent(meshAssetPath: bundle)];
    for (final m in meshes) {
      world.persistentLevel.registerActor(LuminaActor(root: m));
    }
    world.beginPlay();
    for (var i = 0; i < meshes.length; i++) {
      await meshes[i].loaded.timeout(const Duration(seconds: 20), onTimeout: () => fail('instance $i never finished loading'));
    }
    final roots = {for (final m in meshes) m.rootEntity};
    expect(roots, hasLength(12), reason: 'each component draws its own instance');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('eleven instances playing and following one another through headless ticks never overflow the engine', () async {
    const bundle = LuminaThirdPersonContent.bundledMeshPath;
    if (!File(bundle).existsSync()) return markTestSkipped('build tool/build_third_person_content.dart first');
    final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    final scene = engine.createScene();
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    addTearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });
    final meshes = [for (var i = 0; i < 11; i++) LuminaAnimatedMeshComponent(meshAssetPath: bundle)];
    for (final m in meshes) {
      world.persistentLevel.registerActor(LuminaActor(root: m));
    }
    world.beginPlay();
    for (final m in meshes) {
      await m.loaded;
    }
    final leader = meshes.first;
    leader.play(LuminaThirdPersonContent.idleClip);
    for (final f in meshes.skip(1)) {
      f.poseLeader = leader;
      await f.poseLinkReady;
    }
    for (var i = 0; i < 300; i++) {
      world.tick(1 / 60);
    }
    expect(meshes.last.followedBones, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
