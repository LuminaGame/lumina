// The generated character source (the code generator) carries the same
// tuning and the same animated mannequin as the engine's template character,
// which Play-In-Editor spawns.
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

void main() {
  group('parity with the generated character source', () {
    final generated = DartCodeGeneratorService()
        .generateCharacterDart(projectName: 'parity_game', thirdPerson: true);
    final generatedFirstPerson = DartCodeGeneratorService()
        .generateCharacterDart(projectName: 'parity_game', thirdPerson: false);

    test('the generated source carries the same tuning numbers as the PIE character', () {
      expect(generated, contains('maxWalkSpeed = ${LuminaTemplateCharacterTuning.thirdPersonMaxWalkSpeed}'));
      expect(generatedFirstPerson, contains('maxWalkSpeed = ${LuminaTemplateCharacterTuning.maxWalkSpeed}'));
      expect(generated, contains('capsuleHalfHeight = ${LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight}'));
      expect(generated, contains('capsuleRadius = ${LuminaTemplateCharacterTuning.thirdPersonCapsuleRadius}'));
      expect(generated, contains('Vector3(0.0, ${LuminaTemplateCharacterTuning.boomHeight}, 0.0)'));
      expect(generated, contains('cameraLagSpeed = ${LuminaTemplateCharacterTuning.cameraLagSpeed}'));
      expect(generated, contains('probeSize = ${LuminaTemplateCharacterTuning.boomProbeSize}'));
      expect(generated, contains('jumpZVelocity = ${LuminaTemplateCharacterTuning.jumpZVelocity}'));
      expect(generated, contains('airControl = ${LuminaTemplateCharacterTuning.airControl}'));
      expect(generated, contains('targetArmLength: ${LuminaTemplateCharacterTuning.boomLength}'));
      expect(generated, contains('lookSensitivity = ${LuminaTemplateCharacterTuning.lookSensitivity}'));
      expect(generatedFirstPerson,
          contains('super(baseEyeHeight: ${LuminaTemplateCharacterTuning.firstPersonBaseEyeHeight})'));
      expect(generated, contains('super(baseEyeHeight: ${LuminaTemplateCharacterTuning.baseEyeHeight})'));
    });

    test('the generated third-person character carries the same animated mannequin', () {
      expect(generated, contains('LuminaAnimatedMeshComponent('));
      expect(generated, contains('LuminaDirectionalLocomotionComponent('));
      expect(generated, contains("'${LuminaThirdPersonContent.projectMeshGlbPath}'"));
      expect(generated, contains('walkReferenceSpeed: ${LuminaThirdPersonContent.walkReferenceSpeed}'));
      expect(generated, contains('crossFadeDuration: ${LuminaTemplateCharacterTuning.locomotionCrossFade}'));
      expect(generated, contains("idle: '${LuminaThirdPersonContent.idleClip}'"));
      LuminaThirdPersonContent.walkClips.forEach((direction, clip) {
        expect(generated, contains("LuminaLocomotionDirection.${direction.name}: '$clip'"));
      });
      // The driver is added before the mesh, like the PIE character.
      expect(generated.indexOf('addComponent(locomotion)'), lessThan(generated.indexOf('addComponent(bodyMesh)')));

      expect(generatedFirstPerson, isNot(contains('LuminaAnimatedMeshComponent')));
      expect(generatedFirstPerson, isNot(contains('package:flutter/services.dart')));
    });
  });
}
