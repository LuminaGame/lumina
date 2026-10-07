import 'package:lumina/src/object/pawn.dart';
import 'package:lumina/src/components/collision/capsule_component.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/components/movement/character_movement_component.dart';
import 'package:lumina/src/components/mesh/skeletal_mesh_component.dart';

/// Character pawn class equipped with capsule collision, movement component, and mesh.
class LuminaCharacter extends LuminaPawn {
  late final LuminaCapsuleComponent capsuleComponent;
  late final LuminaCharacterMovementComponent characterMovement;
  late final LuminaSkinnedMeshComponent meshComponent;

  LuminaCharacter({
    super.key,
    super.location,
    super.rotation,
    double? baseEyeHeight,
  }) {
    // The Pawn preset: object type Pawn, blocking everything.
    capsuleComponent = LuminaCapsuleComponent(radius: 40.0, halfHeight: 80.0)..objectType = CollisionObjectType.pawn;
    characterMovement = LuminaCharacterMovementComponent();
    meshComponent = LuminaSkinnedMeshComponent();

    // Base Eye Height is measured from the capsule centre: 0.8 of
    // the half height puts the eyes at 90 % of the body height from the feet.
    this.baseEyeHeight = baseEyeHeight ?? (capsuleComponent.halfHeight * 0.8);

    addComponent(capsuleComponent);
    addComponent(characterMovement);
    addComponent(meshComponent);
  }

  void jump() {
    characterMovement.jump();
  }
}
