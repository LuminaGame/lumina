import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_data/lumina_editor_data.dart';
import 'package:vector_math/vector_math_64.dart';

final String _assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';
final File _manny = File('$_assets/mannequin/SKM_Manny_Simple.glb');

/// The example character's ragdoll: its clips go into the character mesh,
/// the Blueprint carries the ragdoll component, and R toggles it.
void main() {
  test('the ragdoll clips go into the character mesh, the rest of the folder into the library', () {
    const root = 'C:/export';
    final files = [
      for (final name in [...GaspRagdoll.getUpClips, GaspRagdoll.flailClip, 'M_ragdoll_reach_up'])
        '$root/${GaspExport.animationsFolder}/Ragdoll/$name.fbx',
      '$root/${GaspExport.animationsFolder}/Jump/${GaspRagdoll.hardLandingClip}.fbx',
    ];
    final export = GaspExport.parse(root, const {}, files);
    expect(GaspRagdoll.clips(export), {...GaspRagdoll.getUpClips, GaspRagdoll.flailClip, GaspRagdoll.hardLandingClip});
    final jobs = {for (final j in GameAnimationSampleBuilder.jobsFor(export)) j.name: j};
    for (final clip in GaspRagdoll.clips(export)) {
      expect(jobs[clip]!.library, isFalse, reason: clip);
    }
    expect(jobs['M_ragdoll_reach_up']!.library, isTrue);
  });

  test('the character Blueprint carries the ragdoll and R toggles it', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), world);
    world.registerSubsystem(LuminaPhysicsSubsystem());
    world.persistentLevel.registerActor(LuminaPrimitiveActor(
      shape: LuminaPrimitiveShape.box,
      size: Vector3(20000.0, 100.0, 20000.0),
      color: Vector3.all(0.5),
      location: Vector3(0.0, -50.0, 0.0),
    ));
    final bound = ProjectInputBinder.bind(GaspCharacterContent.input);
    expect(bound.unboundKeys, isEmpty);
    expect(GaspCharacterContent.input.actions.map((a) => a.name), contains(GaspRagdoll.inputAction));
    final input = world.registerSubsystem(LuminaInputSubsystem());
    for (final c in bound.contexts) {
      input.addMappingContext(c.context, priority: c.priority);
    }
    final actions = bound.actions.values.toList();
    const mesh = 'contents/meshes/skeletal/SK_Test.lmas';
    final document = GaspCharacterContent.characterBlueprint(meshAssetPath: mesh, inputActions: actions);
    final component = document.components.firstWhere((c) => c.type == 'LuminaRagdollComponent');
    expect(component.properties['physicsAsset'], PhysicsAssetGeneration.assetPathFor(mesh));
    final cls = LuminaBlueprintClass.fromDocument(document,
        name: GaspCharacterContent.characterName, inputActions: actions, animBlueprints: (_) => null);
    expect(cls.diagnostics.where((d) => d.isError), isEmpty, reason: '${cls.diagnostics}');
    final character = cls.instantiate(location: Vector3(0.0, 100.0, 0.0)) as LuminaCharacter;
    final ragdoll = character.getComponent<LuminaRagdollComponent>()!;
    expect(ragdoll.getUpClips, GaspRagdoll.getUpClips);
    expect(ragdoll.fallMonitor.ragdollFallSpeed, GaspRagdoll.ragdollFallSpeed);
    // The test mesh is never drawn: the ragdoll gets the mannequin's
    // skeleton directly.
    final sampler = LuminaGlbAnimationSampler.fromGlb(_manny.readAsBytesSync());
    ragdoll.setUp(sampler, LuminaPhysicsAssetGenerator.fromSampler(sampler));
    final pc = LuminaPlayerController();
    world.persistentLevel.registerActor(character);
    pc.possess(character);
    world.beginPlay();
    void tick(int frames) {
      for (var i = 0; i < frames; i++) {
        pc.onTick(1 / 60);
        world.tick(1 / 60);
      }
    }

    void tap(LuminaKey key) {
      input.injectKeyDown(key);
      tick(2);
      input.injectKeyUp(key);
      tick(2);
    }

    tick(30);
    tap(LuminaKey.keyR);
    expect(ragdoll.isRagdoll, isTrue, reason: 'R goes limp');
    expect(character.characterMovement.movementMode, MovementMode.custom);
    tick(60);
    tap(LuminaKey.keyR);
    expect(ragdoll.isRagdoll, isFalse, reason: 'R again gets up');
    tick(60);
    expect(ragdoll.state, LuminaRagdollState.animated);
    expect(character.characterMovement.movementMode, MovementMode.walking);
    world.cleanup();
  }, skip: _manny.existsSync() ? false : 'test-assets/mannequin/SKM_Manny_Simple.glb is missing');
}
