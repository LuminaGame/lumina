import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/animation/directional_locomotion_component.dart';
import 'package:lumina/src/components/camera/camera_component.dart';
import 'package:lumina/src/components/camera/spring_arm_component.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/input/input_action.dart';
import 'package:lumina/src/math/euler.dart';
import 'package:lumina/src/object/character.dart';
import 'package:lumina/src/game/template_content.dart';

/// The movement and camera numbers the First Person / Third Person templates
/// are built from.
///
/// They live here because the same character exists twice: as generated source
/// inside the user's project (`lib/pawns/<project>_character.dart`, which the
/// editor process cannot import), and as [LuminaTemplateCharacter], which
/// Play-In-Editor instantiates directly. `DartCodeGeneratorService` interpolates
/// these constants into the generated source and a parity test fails if the two
/// drift apart.
class LuminaTemplateCharacterTuning {
  const LuminaTemplateCharacterTuning._();

  /// Height of the template characters' eyes above the ground, in cm.
  static const double eyeHeightAboveFeet = 160.0; // cm

  /// The Third Person character's Base Eye Height: its eyes above the
  /// **capsule centre** (the actor location), in cm —
  /// [eyeHeightAboveFeet] on the
  /// [thirdPersonCapsuleHalfHeight] capsule. Every eye-based Blueprint node
  /// and trace starts there.
  static const double baseEyeHeight = eyeHeightAboveFeet - thirdPersonCapsuleHalfHeight; // 70 cm

  /// The capsule the First Person character keeps: `LuminaCharacter`'s
  /// default (1.6 m tall).
  static const double firstPersonCapsuleHalfHeight = 80.0; // cm

  /// The First Person character's Base Eye Height, and its camera's height,
  /// above the capsule centre: [eyeHeightAboveFeet] on the
  /// [firstPersonCapsuleHalfHeight] capsule.
  static const double firstPersonBaseEyeHeight = eyeHeightAboveFeet - firstPersonCapsuleHalfHeight; // 80 cm

  static const double maxWalkSpeed = 600.0; // cm/s
  static const double jumpZVelocity = 500.0; // cm/s
  static const double airControl = 0.35;

  /// Jumps are full height however briefly the button is held (a zero
  /// maximum jump hold time): releasing Jump (Stop Jumping)
  /// never cuts a rising jump. The Blueprint character's graph calls Stop
  /// Jumping on IA_Jump Completed, which a Pressed-trigger mapping fires the
  /// frame after the press.
  static const double jumpCutMultiplier = 1.0;

  /// Capsule the third-person character (1.7 m tall) fits in.
  static const double thirdPersonCapsuleHalfHeight = 90.0; // cm
  static const double thirdPersonCapsuleRadius = 35.0; // cm

  /// Third-person ground speed. The character's walk clips cover 1 m/s at
  /// rate 1 (`LuminaThirdPersonContent.walkReferenceSpeed`), so this plays
  /// them at 3×.
  static const double thirdPersonMaxWalkSpeed = 300.0; // cm/s

  /// Third-person sprint (IA_Sprint held): 1.6× the walk, the jog clips at
  /// 0.8× (`LuminaThirdPersonContent.jogReferenceSpeed`).
  static const double thirdPersonSprintSpeed = thirdPersonMaxWalkSpeed * sprintSpeedMultiplier; // cm/s
  static const double sprintSpeedMultiplier = 1.6;

  /// Seconds the character blends between locomotion clips.
  static const double locomotionCrossFade = 0.2;

  /// Length of the third-person boom, in cm.
  static const double boomLength = 350.0; // cm

  /// Height of the third-person boom's pivot above the capsule centre, in
  /// cm: shoulder height for the character.
  static const double boomHeight = 60.0; // cm

  static const double cameraLagSpeed = 12.0;
  static const double cameraRotationLagSpeed = 14.0;
  static const double boomProbeSize = 25.0; // cm

  /// Degrees of yaw/pitch per pixel of mouse movement.
  static const double lookSensitivity = 0.15;
}

/// The input actions both character templates bind. They mirror the
/// `IA_Move` / `IA_Look` / `IA_Jump` entries the launcher writes into the
/// `.lmproject` manifest, which the user can rebind in Project Settings.
const LuminaInputAction luminaTemplateMoveAction =
    LuminaInputAction('IA_Move', valueType: InputValueType.axis2D);
const LuminaInputAction luminaTemplateLookAction =
    LuminaInputAction('IA_Look', valueType: InputValueType.axis2D);
const LuminaInputAction luminaTemplateJumpAction = LuminaInputAction('IA_Jump');

/// Held free look (Left Alt / the right thumbstick press).
const LuminaInputAction luminaTemplateFreeLookAction = LuminaInputAction('IA_FreeLook');

/// The player character the First Person and Third Person templates scaffold,
/// as a real engine class Play-In-Editor can spawn.
///
/// This is deliberately *not* what the shipped game runs: the launcher writes
/// the equivalent as ordinary source the user owns and edits. Both are built
/// from [LuminaTemplateCharacterTuning], so pressing Play in the editor and
/// running the generated project move the same way.
class LuminaTemplateCharacter extends LuminaCharacter {
  /// True when the camera rides a boom behind the character.
  final bool thirdPerson;

  /// The boom, or null in first person.
  LuminaSpringArmComponent? springArmComponent;

  late final LuminaCameraComponent cameraComponent;

  /// The visible, animated character (the Third Person template's character mesh),
  /// or null in first person and for a project that has no mesh to show.
  LuminaAnimatedMeshComponent? bodyMesh;

  /// Chooses [bodyMesh]'s idle / walk clips from the movement; null with it.
  LuminaDirectionalLocomotionComponent? locomotion;

  double lookSensitivity = LuminaTemplateCharacterTuning.lookSensitivity;

  /// [meshAssetPath] is the third-person character GLB (with its clips merged
  /// in, see [LuminaThirdPersonContent]); first person ignores it.
  LuminaTemplateCharacter({
    super.key,
    super.location,
    super.rotation,
    required this.thirdPerson,
    String? meshAssetPath,
  }) : super(
          baseEyeHeight: thirdPerson
              ? LuminaTemplateCharacterTuning.baseEyeHeight
              : LuminaTemplateCharacterTuning.firstPersonBaseEyeHeight,
        ) {
    characterMovement.maxWalkSpeed = thirdPerson
        ? LuminaTemplateCharacterTuning.thirdPersonMaxWalkSpeed
        : LuminaTemplateCharacterTuning.maxWalkSpeed;
    characterMovement.jumpZVelocity = LuminaTemplateCharacterTuning.jumpZVelocity;
    characterMovement.airControl = LuminaTemplateCharacterTuning.airControl;
    characterMovement.jumpCutMultiplier = LuminaTemplateCharacterTuning.jumpCutMultiplier;
    bUseControllerRotationYaw = true;

    if (thirdPerson) {
      capsuleComponent.capsuleHalfHeight = LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight;
      capsuleComponent.capsuleRadius = LuminaTemplateCharacterTuning.thirdPersonCapsuleRadius;

      if (meshAssetPath != null) {
        // Feet on the capsule's bottom; the locomotion driver turns it.
        final mesh = LuminaAnimatedMeshComponent(
          meshAssetPath: meshAssetPath,
          location: Vector3(0.0, -LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight, 0.0),
        );
        final driver = LuminaDirectionalLocomotionComponent(
          mesh: mesh,
          clips: LuminaThirdPersonContent.mannequinLocomotion,
          crossFadeDuration: LuminaTemplateCharacterTuning.locomotionCrossFade,
        );
        // The driver picks this frame's clip before the mesh applies it.
        addComponent(driver);
        addComponent(mesh);
        bodyMesh = mesh;
        locomotion = driver;
      }

      final boom = LuminaSpringArmComponent(
        location: Vector3(0.0, LuminaTemplateCharacterTuning.boomHeight, 0.0),
        targetArmLength: LuminaTemplateCharacterTuning.boomLength,
      )
        ..bUsePawnControlRotation = true
        ..bEnableCameraLag = true
        ..cameraLagSpeed = LuminaTemplateCharacterTuning.cameraLagSpeed
        ..bEnableCameraRotationLag = true
        ..cameraRotationLagSpeed = LuminaTemplateCharacterTuning.cameraRotationLagSpeed
        ..bDoCollisionTest = true
        ..probeSize = LuminaTemplateCharacterTuning.boomProbeSize;
      springArmComponent = boom;
      addComponent(boom);

      cameraComponent = LuminaCameraComponent()..isActive = true;
      cameraComponent.attachToComponent(boom);
      addComponent(cameraComponent);
    } else {
      cameraComponent = LuminaCameraComponent(
        location: Vector3(0.0, LuminaTemplateCharacterTuning.firstPersonBaseEyeHeight, 0.0),
      )..isActive = true;
      addComponent(cameraComponent);
    }
  }

  /// Drives the character along the control rotation's forward/right axes.
  void onMove(LuminaInputActionValue value) {
    final axis = value.asAxis2D;
    if (axis.x == 0.0 && axis.y == 0.0) return;
    // Free look: the body heading, not the orbiting camera's.
    final yaw = freeLook ? luminaPawnQuaternionToEuler(actorRotation).y : (controller?.controlRotation.y ?? 0.0);
    final yawRadians = yaw * math.pi / 180.0;
    final forward = Vector3(math.sin(yawRadians), 0.0, -math.cos(yawRadians));
    final right = Vector3(math.cos(yawRadians), 0.0, math.sin(yawRadians));
    characterMovement.addInputVector(forward, axis.y);
    characterMovement.addInputVector(right, axis.x);
  }

  /// Feeds mouse deltas to the controller. Pitch is clamped by
  /// [LuminaPlayerController.onTick]; it is deliberately not clamped again here.
  void onLook(LuminaInputActionValue value) {
    final axis = value.asAxis2D;
    addControllerYawInput(axis.x * lookSensitivity);
    addControllerPitchInput(axis.y * lookSensitivity);
  }

  /// Jumps through the character movement component.
  void onJump(LuminaInputActionValue value) => jump();

  /// Releases the jump (IA_Jump Completed).
  void onStopJumping(LuminaInputActionValue value) => characterMovement.stopJumping();

  /// Free look (IA_FreeLook Started / Completed): the Third
  /// Person camera orbits while the body keeps its heading and the head
  /// follows; the First Person character has nothing to turn, so it ignores it.
  void onFreeLook(LuminaInputActionValue value) {
    if (!thirdPerson) return;
    freeLook = value.asBool;
  }

  /// Ends free look (IA_FreeLook Completed / Canceled: the dispatched value
  /// is the last held one, so the release cannot be read from it).
  void onStopFreeLook(LuminaInputActionValue value) {
    if (!thirdPerson) return;
    freeLook = false;
  }
}
