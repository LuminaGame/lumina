import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Play-In-Editor cannot import the character the launcher generates
/// into the user's project, because that is source in another package. It needs
/// an in-process equivalent, and the two must not drift: the generated source
/// interpolates the same named constants this class is built from.
void main() {
  group('LuminaTemplateCharacter', () {
    test('first person puts a camera at eye height and no boom', () {
      final character = LuminaTemplateCharacter(thirdPerson: false);

      expect(character.baseEyeHeight, LuminaTemplateCharacterTuning.firstPersonBaseEyeHeight);
      expect(character.springArmComponent, isNull, reason: 'first person has no boom');
      expect(character.cameraComponent.isActive, isTrue);
      expect(character.cameraComponent.relativeLocation.y,
          closeTo(LuminaTemplateCharacterTuning.firstPersonBaseEyeHeight, 1e-9));
      // Measured from the capsule centre, the camera is 160 cm above the feet.
      expect(character.capsuleComponent.halfHeight, LuminaTemplateCharacterTuning.firstPersonCapsuleHalfHeight);
      expect(character.capsuleComponent.halfHeight + character.cameraComponent.relativeLocation.y,
          closeTo(LuminaTemplateCharacterTuning.eyeHeightAboveFeet, 1e-9));
    });

    test('third person keeps its eyes 160 cm above the feet, measured from the capsule centre', () {
      final character = LuminaTemplateCharacter(thirdPerson: true);
      expect(LuminaTemplateCharacterTuning.baseEyeHeight, 70.0);
      expect(LuminaTemplateCharacterTuning.firstPersonBaseEyeHeight, 80.0);
      expect(character.baseEyeHeight, LuminaTemplateCharacterTuning.baseEyeHeight);
      expect(character.capsuleComponent.halfHeight + character.baseEyeHeight,
          closeTo(LuminaTemplateCharacterTuning.eyeHeightAboveFeet, 1e-9));
    });

    test('third person rides a spring arm that uses control rotation and probes geometry', () {
      final character = LuminaTemplateCharacter(thirdPerson: true);
      final boom = character.springArmComponent;

      expect(boom, isNotNull);
      expect(boom!.targetArmLength, LuminaTemplateCharacterTuning.boomLength);
      expect(boom.bUsePawnControlRotation, isTrue);
      expect(boom.bDoCollisionTest, isTrue);
      expect(character.cameraComponent.parentComponent, same(boom));
    });

    test('movement tuning is applied to the character movement component', () {
      final character = LuminaTemplateCharacter(thirdPerson: false);
      expect(character.characterMovement.maxWalkSpeed, LuminaTemplateCharacterTuning.maxWalkSpeed);
      expect(character.characterMovement.jumpZVelocity, LuminaTemplateCharacterTuning.jumpZVelocity);
      expect(character.characterMovement.airControl, LuminaTemplateCharacterTuning.airControl);
      expect(character.bUseControllerRotationYaw, isTrue);
    });

    test('third person uses the mannequin-sized capsule and walk speed', () {
      final character = LuminaTemplateCharacter(thirdPerson: true);
      expect(character.capsuleComponent.capsuleHalfHeight, LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight);
      expect(character.capsuleComponent.capsuleRadius, LuminaTemplateCharacterTuning.thirdPersonCapsuleRadius);
      expect(character.characterMovement.maxWalkSpeed, LuminaTemplateCharacterTuning.thirdPersonMaxWalkSpeed);
    });

    test('third person with a mesh carries the animated mannequin, feet on the capsule bottom', () {
      final character = LuminaTemplateCharacter(
        thirdPerson: true,
        meshAssetPath: '/project/${LuminaThirdPersonContent.projectMeshGlbPath}',
      );
      final mesh = character.bodyMesh;
      final locomotion = character.locomotion;
      expect(mesh, isNotNull);
      expect(locomotion, isNotNull);
      expect(mesh!.meshAssetPath, '/project/${LuminaThirdPersonContent.projectMeshGlbPath}');
      expect(mesh.relativeLocation.y, closeTo(-character.capsuleComponent.capsuleHalfHeight, 1e-9));
      expect(locomotion!.mesh, same(mesh));
      expect(locomotion.clips.idle, LuminaThirdPersonContent.idleClip);
      expect(locomotion.clips.walk, LuminaThirdPersonContent.walkClips);
      expect(locomotion.crossFadeDuration, LuminaTemplateCharacterTuning.locomotionCrossFade);

      // The driver must pick the clip before the mesh applies it each frame.
      final order = character.components;
      expect(order.indexOf(locomotion), lessThan(order.indexOf(mesh)));
    });

    test('without a mesh (an older project) the third-person character has no body', () {
      final character = LuminaTemplateCharacter(thirdPerson: true);
      expect(character.bodyMesh, isNull);
      expect(character.locomotion, isNull);
    });

    test('first person never gets a body mesh', () {
      final character = LuminaTemplateCharacter(thirdPerson: false, meshAssetPath: 'ignored.glb');
      expect(character.bodyMesh, isNull);
      expect(character.characterMovement.maxWalkSpeed, LuminaTemplateCharacterTuning.maxWalkSpeed);
    });

    test('a move input drives the character along the control rotation', () {
      final world = LuminaWorld();
      final character = LuminaTemplateCharacter(thirdPerson: false);
      world.persistentLevel.registerActor(character);
      world.beginPlay();

      final controller = LuminaPlayerController();
      controller.possess(character);
      controller.controlRotation.y = 0.0;

      character.onMove(LuminaInputActionValue.raw(InputValueType.axis2D, 0.0, 1.0, 0.0));

      // Yaw 0 looks down -Z, the engine's forward.
      final input = character.characterMovement.consumeInputVector();
      expect(input.z, lessThan(0.0));
      expect(input.x.abs(), lessThan(1e-6));
    });

    test('a look input turns the controller and never re-clamps pitch itself', () {
      final character = LuminaTemplateCharacter(thirdPerson: false);
      final controller = LuminaPlayerController();
      controller.possess(character);

      character.onLook(LuminaInputActionValue.raw(InputValueType.axis2D, 100.0, 0.0, 0.0));
      expect(controller.controlRotation.y,
          closeTo(100.0 * LuminaTemplateCharacterTuning.lookSensitivity, 1e-9));

      // 10 000 px of pitch: the character must not clamp; the controller does.
      character.onLook(LuminaInputActionValue.raw(InputValueType.axis2D, 0.0, 10000.0, 0.0));
      expect(controller.controlRotation.x.abs(), greaterThan(89.9),
          reason: 'clamping belongs to LuminaPlayerController.onTick, not here');
    });
  });
}
