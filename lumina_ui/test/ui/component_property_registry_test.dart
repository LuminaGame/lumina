import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaCameraSettings;
import 'package:lumina_ui/ui/features/details/models/component_property_registry.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';

void main() {
  group('ComponentPropertyRegistry Completeness', () {
    test('LuminaCharacterMovementComponent has exact properties', () {
      final desc = ComponentPropertyRegistry.descriptors['LuminaCharacterMovementComponent']!;
      expect(desc.sections, containsAll(['Character Movement: Walking', 'Character Movement: Jumping & Falling', 'Character Movement: Rotation Settings']));
      
      final walkSpeed = desc.properties.firstWhere((p) => p.id == 'maxWalkSpeed');
      expect(walkSpeed.defaultValue, 600.0);
      expect(walkSpeed.unit, 'cm/s');
      
      final airControl = desc.properties.firstWhere((p) => p.id == 'airControl');
      expect(airControl.min, 0.0);
      expect(airControl.max, 1.0);
      expect(airControl.defaultValue, 0.35);
    });

    test('LuminaSpringArmComponent has exact properties', () {
      final desc = ComponentPropertyRegistry.descriptors['LuminaSpringArmComponent']!;
      final targetArmLength = desc.properties.firstWhere((p) => p.id == 'targetArmLength');
      expect(targetArmLength.defaultValue, 400.0);
      
      final socketOffset = desc.properties.firstWhere((p) => p.id == 'socketOffset');
      expect(socketOffset.defaultValue, [0.0, 50.0, 60.0]);
    });

    test('LuminaCameraComponent has exact properties', () {
      final desc = ComponentPropertyRegistry.descriptors['LuminaCameraComponent']!;
      // The runtime's names and units (LuminaCameraSettings).
      final fov = desc.properties.firstWhere((p) => p.id == 'fieldOfView');
      expect(fov.min, 5.0);
      expect(fov.max, 170.0);
      expect(fov.defaultValue, LuminaCameraSettings.defaultFieldOfView);
      expect(desc.properties.firstWhere((p) => p.id == 'nearClipPlane').unit, 'cm');
      expect(desc.properties.map((p) => p.id).toSet(),
          const LuminaCameraSettings().toProperties().keys.toSet().difference({'autoActivateForPlayer'}));
    });

    test('LuminaCapsuleComponent has exact properties', () {
      final desc = ComponentPropertyRegistry.descriptors['LuminaCapsuleComponent']!;
      final halfHeight = desc.properties.firstWhere((p) => p.id == 'capsuleHalfHeight');
      expect(halfHeight.defaultValue, 88.0);
      final radius = desc.properties.firstWhere((p) => p.id == 'capsuleRadius');
      expect(radius.defaultValue, 34.0);
      
      final presets = desc.properties.firstWhere((p) => p.id == 'collisionPreset');
      expect(presets.enumValues, ['Pawn', 'BlockAll', 'OverlapAll', 'NoCollision', 'Custom']);
    });

    test('LuminaAudioComponent has exact properties', () {
      final desc = ComponentPropertyRegistry.descriptors['LuminaAudioComponent']!;
      final falloff = desc.properties.firstWhere((p) => p.id == 'falloffDistance');
      expect(falloff.defaultValue, 3500.0);
    });

    test('LuminaSpotLightComponent allows 100x higher lumen range up to 10M lm', () {
      final desc = ComponentPropertyRegistry.descriptors['LuminaSpotLightComponent']!;
      final intensity = desc.properties.firstWhere((p) => p.id == 'intensity');
      expect(intensity.unit, 'lm');
      expect(intensity.min, 0.0);
      expect(intensity.max, 10000000.0, reason: '100x higher than 100k lm for large spotlights');
      expect(intensity.hardMin, 0.0);
      expect(intensity.hardMax, double.infinity);

      final bpDesc = BlueprintComponentRegistry.getDescriptor('LuminaSpotLightComponent')!;
      final bpIntensity = bpDesc.properties.firstWhere((p) => p.dartField == 'intensity');
      expect(bpIntensity.min, 0.0);
      expect(bpIntensity.max, 10000000.0);
    });
  });
}
