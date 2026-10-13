import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Named character slots built from a Blueprint: listed, filled (a mesh
/// swapped in place), cleared, garments masking the body, on a real
/// headless engine with the mannequins from `test-assets/`.
void main() {
  final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.parent.path}/test-assets';
  final manny = '$assets/mannequin/SKM_Manny_Simple.glb';
  final quinn = '$assets/mannequin/exports/SKM_Quinn_Simple.glb';
  final skip = File(manny).existsSync() && File(quinn).existsSync() ? false : 'the mannequins are missing from test-assets';

  late FilamentEngine engine;
  late FilamentScene scene;
  late LuminaWorld world;

  setUp(() {
    engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    scene = engine.createScene();
    world = LuminaWorld(worldType: LuminaWorldType.game);
    world.initializeNativeContext(engine, scene);
  });

  tearDown(() {
    world.cleanup();
    scene.dispose();
    engine.dispose();
  });

  LuminaBlueprintComponent mesh(String id, String slot, String asset, {String? parent, String? from}) =>
      LuminaBlueprintComponent(
        id: id,
        name: slot,
        type: 'LuminaSkeletalMeshComponent',
        parentId: parent,
        isSceneComponent: true,
        properties: {'skeletalMeshAsset': asset, 'slot': slot, 'poseFrom': ?from},
      );

  Future<(LuminaActor, Map<String, LuminaActorComponent>)> character(List<LuminaBlueprintComponent> components) async {
    final actor = LuminaActor(root: LuminaSceneComponent());
    final built = LuminaBlueprintComponents.construct(actor, components, resolveAsset: (s) => s);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    for (final c in built.values) {
      if (c is LuminaAnimatedMeshComponent) await c.loaded;
    }
    return (actor, built);
  }

  test('a Blueprint\'s slotted components are listed with their meshes; empty slots stay fillable', () async {
    final (actor, built) = await character([
      mesh('body', 'Body', manny),
      mesh('hair', 'Hair', '', parent: 'body', from: 'body'),
      mesh('torso', 'Torso', '', parent: 'body', from: 'Body'),
    ]);
    final slots = LuminaCharacterSlots.of(actor);
    expect(slots.names, ['Body', 'Hair', 'Torso']);
    expect(slots.meshOf('Body'), manny);
    expect(slots.meshOf('Hair'), '');
    expect(slots.slot('Hair')!.leaderSlot, 'Body');
    expect(slots.slot('Torso')!.masksBody, isTrue);
    expect(slots.slot('Hair')!.masksBody, isFalse);
    expect(slots.component('Body'), same(built['body']));
    expect(slots.meshOf('Nope'), isNull);
    expect(await slots.setMesh('Nope', manny), isFalse);
    expect(await slots.clear('Nope'), isFalse);
  }, skip: skip);

  test('filling a slot follows the leader; refilling swaps in place; clearing keeps the slot', () async {
    final (actor, built) = await character([
      mesh('body', 'Body', manny),
      mesh('hair', 'Hair', '', parent: 'body', from: 'body'),
    ]);
    final slots = LuminaCharacterSlots.of(actor);
    final body = built['body'] as LuminaAnimatedMeshComponent;
    expect(await slots.setMesh('Hair', quinn), isTrue);
    final hair = slots.component('Hair') as LuminaAnimatedMeshComponent;
    expect(hair.isLoaded, isTrue);
    expect(hair.poseLeader, same(body));
    expect(hair.parentComponent, same(body));
    expect(actor.components, contains(hair));
    await hair.poseLinkReady;
    world.tick(1 / 60);
    expect(hair.followedBones, contains('pelvis'));

    // Refilled in place: the same component draws the other mesh.
    expect(await slots.setMesh('Hair', manny), isTrue);
    expect(slots.component('Hair'), same(hair));
    expect(hair.meshAssetPath, manny);
    expect(hair.isLoaded, isTrue);
    await hair.poseLinkReady;
    world.tick(1 / 60);
    expect(hair.followedBones, isNotEmpty);

    // A new body keeps its followers.
    expect(await slots.setMesh('Body', quinn), isTrue);
    expect(slots.component('Body'), same(body));
    expect(body.meshAssetPath, quinn);
    await hair.poseLinkReady;
    world.tick(1 / 60);
    expect(hair.poseLeader, same(body));
    expect(hair.followedBones, contains('head'));

    expect(await slots.clear('Hair'), isTrue);
    expect(slots.meshOf('Hair'), '');
    expect(slots.component('Hair'), isNot(isA<LuminaAnimatedMeshComponent>()));
    expect(actor.components, isNot(contains(hair)));
    expect(body.poseFollowers, isEmpty);
    expect(slots.names, ['Body', 'Hair']);
  }, skip: skip);

  test('a garment slot masks the body under it; clearing it restores the body', () async {
    final (actor, built) = await character([
      mesh('body', 'Body', manny),
      mesh('torso', 'Torso', '', parent: 'body', from: 'body'),
    ]);
    final slots = LuminaCharacterSlots.of(actor);
    final body = built['body'] as LuminaAnimatedMeshComponent;
    expect(await slots.setMesh('Torso', quinn), isTrue);
    expect(body.meshAssetPath, startsWith('$manny#masked-'));
    expect(body.isLoaded, isTrue);
    expect(slots.meshOf('Body'), manny, reason: 'the stored mesh stays the unmasked body');
    expect(await slots.clear('Torso'), isTrue);
    expect(body.meshAssetPath, manny);
    expect(body.isLoaded, isTrue);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('a skinned cloth can be a slot, worn on the mesh its poseFrom names', () {
    final actor = LuminaActor(root: LuminaSceneComponent());
    final built = LuminaBlueprintComponents.construct(actor, [
      mesh('body', 'Body', manny),
      LuminaBlueprintComponent(
        id: 'skirt',
        name: 'Skirt',
        type: 'LuminaSkinnedClothComponent',
        parentId: 'body',
        isSceneComponent: true,
        properties: {'slot': 'Legs', 'poseFrom': 'body'},
      ),
    ], resolveAsset: (s) => s);
    final slots = LuminaCharacterSlots.of(actor);
    expect(slots.names, ['Body', 'Legs']);
    final skirt = built['skirt'] as LuminaSkinnedClothComponent;
    expect(slots.component('Legs'), same(skirt));
    expect(skirt.mesh, same(built['body']));
    expect(slots.slot('Legs')!.masksBody, isTrue);
  }, skip: skip);

  test('the slot nodes have specs, VM functions and call shapes', () {
    for (final id in ['set_slot_mesh', 'clear_slot', 'get_slot_mesh', 'get_slots']) {
      expect(LuminaBlueprintNodeLibrary.spec(id), isNotNull, reason: id);
      expect(LuminaBlueprintNodeLibrary.spec(id)!.category, 'Character|Slots');
      expect(LuminaBlueprintFunctionLibrary.builtInFunctions.containsKey(id), isTrue, reason: id);
      expect(LuminaBlueprintFunctionLibrary.callShapes.containsKey(id), isTrue, reason: id);
    }
    if (!File(manny).existsSync() || !File(quinn).existsSync()) return markTestSkipped('the mannequins are missing');
    final noSlots = LuminaActor(root: LuminaSceneComponent());
    expect(LuminaBlueprintFunctionLibrary.getSlots(noSlots), isEmpty);
    expect(LuminaBlueprintFunctionLibrary.setSlotMesh(noSlots, null, 'Hair', 'x.glb'), isFalse);
    expect(LuminaBlueprintFunctionLibrary.getSlotMesh(noSlots, null, 'Hair'), '');
    // With a Target, the nodes act on that actor's slots, not the caller's.
    final character = LuminaActor(root: LuminaSceneComponent());
    LuminaBlueprintComponents.construct(character, [mesh('body', 'Body', manny), mesh('hair', 'Hair', '', parent: 'body', from: 'body')],
        resolveAsset: (s) => s);
    expect(LuminaBlueprintFunctionLibrary.getSlots(noSlots, character), ['Body', 'Hair']);
    expect(LuminaBlueprintFunctionLibrary.setSlotMesh(noSlots, character, 'Hair', quinn), isTrue);
    expect(LuminaBlueprintFunctionLibrary.getSlotMesh(noSlots, character, 'Hair'), quinn);
    expect(LuminaBlueprintFunctionLibrary.clearSlot(noSlots, character, 'Hair'), isTrue);
    expect(LuminaBlueprintFunctionLibrary.getSlotMesh(noSlots, character, 'Hair'), '');
    expect(LuminaBlueprintFunctionLibrary.getSlots(noSlots), isEmpty, reason: 'the caller has none');
  });
}
