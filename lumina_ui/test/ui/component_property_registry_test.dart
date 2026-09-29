import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/details/models/component_property_registry.dart';

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
      final fov = desc.properties.firstWhere((p) => p.id == 'fov');
      expect(fov.min, 60.0);
      expect(fov.max, 110.0);
      expect(fov.defaultValue, 90.0);
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
  });
}
