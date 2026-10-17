import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

/// Smoke: a character placed in a level with its origin (the capsule centre)
/// on the ground, as a Blueprint character dropped at height 0 is, stands on
/// the ground in Play instead of falling through it. The level's Ground is a
/// primitive plane (a 10 cm collision slab); the character is simulated for
/// ten seconds and the filmed mannequin and concrete slabs follow the
/// simulated capsule.
void main() {
  const testTitle = 'Character Spawn Smoke: a character placed with its capsule centre on the ground stands on it';
  const usedAssets = ['mannequin/MM_Idle.glb', 'structures/Concrete_slabs/concrete_slabs_6x6.glb'];
  const halfHeight = 88.0;
  const fps = 60;
  const seconds = 10.0;

  test(testTitle, () async {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), world);
    final ground = LuminaPrimitiveActor(
      shape: LuminaPrimitiveShape.plane,
      size: Vector3(6000.0, 0.0, 6000.0),
      color: Vector3(0.37, 0.42, 0.36),
    );
    CollisionProfile.applyBlockAll(ground.collisionComponent);
    world.persistentLevel.registerActor(ground);
    final character = LuminaCharacter(location: Vector3(0.0, 0.0, 0.0));
    character.capsuleComponent
      ..capsuleHalfHeight = halfHeight
      ..capsuleRadius = 40.0;
    world.persistentLevel.registerActor(character);
    world.beginPlay();

    // Simulated capsule bottom (feet) per frame.
    const slabTop = LuminaPrimitiveActor.planeColliderThickness / 2;
    final feet = <double>[];
    for (var f = 0; f < (seconds * fps).round(); f++) {
      character.characterMovement.performMove(1 / fps);
      feet.add(character.actorLocation.y - halfHeight);
    }
    expect(feet.first, closeTo(slabTop, 2.0), reason: 'stood on the ground on the first move');
    expect(feet.reduce(math.min), greaterThan(slabTop - 2.0), reason: 'never sinks into or through the ground');
    expect(feet.last, closeTo(slabTop, 2.0));
    expect(character.characterMovement.isWalking, isTrue);

    await SmokeArtifacts.renderRealAssetMedia(
      testTitle: testTitle,
      usedAssets: usedAssets,
      durationSeconds: seconds,
      onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
        if (assets.length < 2) return;
        final tm = FilamentTransformManager(engine);
        final i = (timeSeconds * fps).floor().clamp(0, feet.length - 1);

        // The slabs, their top at the collision slab's top.
        final slab = assets[1].getBoundingBox();
        final slabSize = slab.max - slab.min;
        final slabScale = 2400.0 / math.max(slabSize.x, slabSize.z);
        tm.setTransform(
          assets[1].rootEntity,
          (Matrix4.identity()
                ..setTranslationRaw(-(slab.min.x + slabSize.x / 2) * slabScale, slabTop - slab.max.y * slabScale,
                    -(slab.min.z + slabSize.z / 2) * slabScale)
                ..scaleByDouble(slabScale, slabScale, slabScale, 1.0))
              .storage
              .toList(),
        );

        // The mannequin, 176 cm tall, its feet on the simulated capsule bottom.
        final body = assets[0].getBoundingBox();
        final bodySize = body.max - body.min;
        final bodyScale = 2 * halfHeight / bodySize.y;
        tm.setTransform(
          assets[0].rootEntity,
          (Matrix4.identity()
                ..setTranslationRaw(0.0, feet[i] - body.min.y * bodyScale, 0.0)
                ..rotateY(timeSeconds * 0.4)
                ..scaleByDouble(bodyScale, bodyScale, bodyScale, 1.0))
              .storage
              .toList(),
        );
        cam.lookAt(eyeX: 320.0, eyeY: 60.0, eyeZ: 320.0, centerX: 0.0, centerY: 70.0, centerZ: 0.0);
      },
    );
    world.cleanup();
  });
}
