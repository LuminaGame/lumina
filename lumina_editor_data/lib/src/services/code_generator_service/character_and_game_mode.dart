part of '../code_generator_service.dart';

/// The generated character and game mode classes and post-process settings.
mixin _CharacterAndGameModeCodegen on _DartCodeGeneratorServiceState {

  /// Self-contained support code appended to a level that authors `Primitive`
  /// actors. It lives in the level file (rather than a second generated file)
  /// so the level stays derivable from `metadata.actors` alone.
  /// Generates `lib/pawns/<project>_character.dart` — a [LuminaCharacter]
  /// subclass the user owns and edits.
  ///
  /// [thirdPerson] swaps the eye-height camera for a
  /// [LuminaSpringArmComponent] boom with pawn control rotation, camera lag and
  /// a collision probe. The file is written once at project creation and is
  /// **never** touched by the editor's level/main regeneration, so the
  /// `BEGIN USER CODE` regions are safe to extend.
  String generateCharacterDart({
    required String projectName,
    required bool thirdPerson,
  }) {
    final prefix = DartCodeGeneratorService._sanitizeClassName(projectName);
    final className = '${prefix}Character';
    final kind = thirdPerson ? 'third-person' : 'first-person';

    final cameraFields = thirdPerson
        ? '''  /// The boom the camera rides on: follows the controller's rotation,
  /// lags behind the character and pulls in when it hits geometry.
  late final LuminaSpringArmComponent springArmComponent;
  late final LuminaCameraComponent cameraComponent;

  /// The character mesh, and the driver that picks its idle / walk clip from the
  /// way the character moves.
  late final LuminaAnimatedMeshComponent bodyMesh;
  late final LuminaDirectionalLocomotionComponent locomotion;'''
        : '''  /// The eye. Sits at [baseEyeHeight] above the capsule centre.
  late final LuminaCameraComponent cameraComponent;''';

    final walkSpeed = thirdPerson ? LuminaTemplateCharacterTuning.thirdPersonMaxWalkSpeed : LuminaTemplateCharacterTuning.maxWalkSpeed;
    // Measured from the capsule centre.
    final baseEyeHeight =
        thirdPerson ? LuminaTemplateCharacterTuning.baseEyeHeight : LuminaTemplateCharacterTuning.firstPersonBaseEyeHeight;

    final cameraSetup = thirdPerson
        ? '''    capsuleComponent.capsuleHalfHeight = ${LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight};
    capsuleComponent.capsuleRadius = ${LuminaTemplateCharacterTuning.thirdPersonCapsuleRadius};

    // Feet on the capsule's bottom. The locomotion driver is added first so it
    // picks this frame's clip before the mesh applies it.
    bodyMesh = LuminaAnimatedMeshComponent(
      meshAssetPath: mannequinMeshPath,
      assetProvider: loadBundledAsset,
      location: Vector3(0.0, -${LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight}, 0.0),
    );
    locomotion = LuminaDirectionalLocomotionComponent(
      mesh: bodyMesh,
      clips: mannequinLocomotion,
      crossFadeDuration: ${LuminaTemplateCharacterTuning.locomotionCrossFade},
    );
    addComponent(locomotion);
    addComponent(bodyMesh);

    springArmComponent = LuminaSpringArmComponent(
      location: Vector3(0.0, ${LuminaTemplateCharacterTuning.boomHeight}, 0.0),
      targetArmLength: ${LuminaTemplateCharacterTuning.boomLength},
    );
    springArmComponent.bUsePawnControlRotation = true;
    springArmComponent.bEnableCameraLag = true;
    springArmComponent.cameraLagSpeed = ${LuminaTemplateCharacterTuning.cameraLagSpeed};
    springArmComponent.bEnableCameraRotationLag = true;
    springArmComponent.cameraRotationLagSpeed = ${LuminaTemplateCharacterTuning.cameraRotationLagSpeed};
    springArmComponent.bDoCollisionTest = true;
    springArmComponent.probeSize = ${LuminaTemplateCharacterTuning.boomProbeSize};
    addComponent(springArmComponent);

    cameraComponent = LuminaCameraComponent()..isActive = true;
    cameraComponent.attachToComponent(springArmComponent);
    addComponent(cameraComponent);'''
        : '''    cameraComponent = LuminaCameraComponent(
      location: Vector3(0.0, baseEyeHeight, 0.0),
    )..isActive = true;
    addComponent(cameraComponent);''';

    final walkEntries = LuminaThirdPersonContent.walkClips.entries
        .map((e) => "    LuminaLocomotionDirection.${e.key.name}: '${_escape(e.value)}',")
        .join('\n');
    final jogEntries = LuminaThirdPersonContent.jogClips.entries
        .map((e) => "    LuminaLocomotionDirection.${e.key.name}: '${_escape(e.value)}',")
        .join('\n');

    final mannequinImports = thirdPerson
        ? "\nimport 'package:flutter/services.dart';\n"
        : '';

    final mannequinDeclarations = thirdPerson
        ? '''

/// The character mesh, with its idle and walk clips merged in. The Content Browser
/// shows it as `${LuminaThirdPersonContent.projectMeshAssetPath}`, and
/// `pubspec.yaml` bundles its folder, so the game loads it from the asset
/// bundle wherever it runs.
const String mannequinMeshPath = '${LuminaThirdPersonContent.projectMeshGlbPath}';

/// Idle + eight-way walk + eight-way jog, by the names of the clips inside
/// [mannequinMeshPath].
const LuminaLocomotionClipSet mannequinLocomotion = LuminaLocomotionClipSet(
  idle: '${LuminaThirdPersonContent.idleClip}',
  walk: {
$walkEntries
  },
  walkReferenceSpeed: ${LuminaThirdPersonContent.walkReferenceSpeed},
  jog: {
$jogEntries
  },
  jogReferenceSpeed: ${LuminaThirdPersonContent.jogReferenceSpeed},
);

/// Reads a file bundled from the project's `contents/` folders.
Future<Uint8List> loadBundledAsset(String path) async {
  final data = await rootBundle.load(path);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}'''
        : '';

    return '''
// $className — your $kind character.
//
// Lumina Studio generated this file once, when the project was created. It is
// ordinary source you own: the editor's level and main.dart regeneration never
// rewrites it. Extend it inside the BEGIN/END USER CODE regions (or anywhere
// else you like).
//
// ignore_for_file: prefer_const_constructors

import 'dart:math' as math;
$mannequinImports
import '$kLuminaGameLibrary';
import 'package:vector_math/vector_math_64.dart';

/// The input actions the `Gameplay` mapping context drives. They mirror the
/// `IA_Move` / `IA_Look` / `IA_Jump` entries in ${_escape(projectName)}.lmproject,
/// which you can rebind in Project Settings > Input.
const LuminaInputAction iaMove = LuminaInputAction('IA_Move', valueType: InputValueType.axis2D);
const LuminaInputAction iaLook = LuminaInputAction('IA_Look', valueType: InputValueType.axis2D);
const LuminaInputAction iaJump = LuminaInputAction('IA_Jump');$mannequinDeclarations

/// Places a key's raw 1D value onto one axis of a 2D action, scaled — the
/// Enhanced Input "swizzle axis" + "scalar" pair in a single modifier.
class AxisPlacementModifier extends LuminaInputModifier {
  final double toX;
  final double toY;

  const AxisPlacementModifier({this.toX = 0.0, this.toY = 0.0});

  @override
  LuminaInputActionValue modify(LuminaInputActionValue rawValue, double deltaTime) {
    final raw = rawValue.asAxis1D;
    return LuminaInputActionValue.raw(rawValue.type, raw * toX, raw * toY, 0.0);
  }
}

/// Builds the `Gameplay` mapping context: WASD on the move axes, the mouse on
/// the look axes, Space to jump.
LuminaInputMappingContext buildGameplayMappingContext() {
  final context = LuminaInputMappingContext();
  context.mapKey(LuminaKey.keyW, iaMove, modifiers: const [AxisPlacementModifier(toY: 1.0)]);
  context.mapKey(LuminaKey.keyS, iaMove, modifiers: const [AxisPlacementModifier(toY: -1.0)]);
  context.mapKey(LuminaKey.keyA, iaMove, modifiers: const [AxisPlacementModifier(toX: -1.0)]);
  context.mapKey(LuminaKey.keyD, iaMove, modifiers: const [AxisPlacementModifier(toX: 1.0)]);
  context.mapKey(LuminaKey.mouseX, iaLook, modifiers: const [AxisPlacementModifier(toX: 1.0)]);
  context.mapKey(LuminaKey.mouseY, iaLook, modifiers: const [AxisPlacementModifier(toY: -1.0)]);
  context.mapKey(LuminaKey.keySpace, iaJump);
  return context;
}

/// The player character spawned by `${prefix}GameMode` at the level's
/// `PlayerStart`.
class $className extends LuminaCharacter {
$cameraFields

  /// Input component carrying this character's action bindings.
  late final LuminaInputComponent inputComponent;

  /// Degrees of yaw/pitch per pixel of mouse movement.
  double lookSensitivity = ${LuminaTemplateCharacterTuning.lookSensitivity};

  // BEGIN USER CODE: fields
  // END USER CODE

  $className({super.key, super.location, super.rotation}) : super(baseEyeHeight: $baseEyeHeight) {
    characterMovement.maxWalkSpeed = $walkSpeed;
    characterMovement.jumpZVelocity = ${LuminaTemplateCharacterTuning.jumpZVelocity};
    characterMovement.airControl = ${LuminaTemplateCharacterTuning.airControl};
    // Full-height jumps however briefly Jump is held.
    characterMovement.jumpCutMultiplier = ${LuminaTemplateCharacterTuning.jumpCutMultiplier};
    bUseControllerRotationYaw = true;

$cameraSetup

    // BEGIN USER CODE: constructor
    // END USER CODE
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    onSetupInput();
  }

  /// Registers the gameplay mapping context and binds the actions. Called once
  /// when play begins; override or extend to add your own bindings.
  void onSetupInput() {
    final currentWorld = world;
    if (currentWorld == null) return;

    var subsystem = currentWorld.getSubsystem<LuminaInputSubsystem>();
    subsystem ??= currentWorld.registerSubsystem(LuminaInputSubsystem());
    subsystem.addMappingContext(buildGameplayMappingContext());

    inputComponent = LuminaInputComponent();
    addComponent(inputComponent);

    inputComponent.bindAction(iaMove, TriggerState.triggered, onMove);
    inputComponent.bindAction(iaLook, TriggerState.triggered, onLook);
    inputComponent.bindAction(iaJump, TriggerState.started, onJump);
    inputComponent.bindAction(iaJump, TriggerState.completed, onStopJumping);

    // BEGIN USER CODE: input
    // END USER CODE
  }

  /// Drives the character along the control rotation's forward/right axes.
  void onMove(LuminaInputActionValue value) {
    final axis = value.asAxis2D;
    if (axis.x == 0.0 && axis.y == 0.0) return;
    final yawRadians = (controller?.controlRotation.y ?? 0.0) * math.pi / 180.0;
    final forward = Vector3(math.sin(yawRadians), 0.0, -math.cos(yawRadians));
    final right = Vector3(math.cos(yawRadians), 0.0, math.sin(yawRadians));
    characterMovement.addInputVector(forward, axis.y);
    characterMovement.addInputVector(right, axis.x);
  }

  /// Feeds mouse deltas to the controller. Pitch is clamped to +/-89.9 by
  /// [LuminaPlayerController.onTick] — do not clamp it again here.
  void onLook(LuminaInputActionValue value) {
    final axis = value.asAxis2D;
    addControllerYawInput(axis.x * lookSensitivity);
    addControllerPitchInput(axis.y * lookSensitivity);
  }

  /// Jumps through the character movement component.
  void onJump(LuminaInputActionValue value) {
    jump();
  }

  /// Releases the jump (IA_Jump Completed).
  void onStopJumping(LuminaInputActionValue value) {
    characterMovement.stopJumping();
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
''';
  }

  /// Generates `lib/game/<project>_game_mode.dart` — the [LuminaGameMode] that
  /// spawns and possesses the generated character at the level's
  /// [LuminaPlayerStart]. User-owned; never regenerated.
  String generateGameModeDart({required String projectName}) {
    final prefix = DartCodeGeneratorService._sanitizeClassName(projectName);
    final characterClass = '${prefix}Character';
    final className = '${prefix}GameMode';
    return '''
// $className — the rules of your game.
//
// Lumina Studio generated this file once, when the project was created. It is
// ordinary source you own: the editor's level and main.dart regeneration never
// rewrites it.

import '$kLuminaGameLibrary';

import '../pawns/${dartFileName(characterClass)}';

/// Spawns a [$characterClass] at the level's `PlayerStart` and possesses it
/// with the local player's controller.
class $className extends LuminaGameMode {
  $className()
      : super(
          defaultPawnFactory: () => $characterClass(),
          playerControllerFactory: () => LuminaPlayerController(playerName: 'Player'),
        );

  // BEGIN USER CODE: class_body
  // END USER CODE
}
''';
  }

  @override
  String _emitPostProcess(Map<String, dynamic> pp) {
    final fogEnabled = pp['fogEnabled'] is bool ? pp['fogEnabled'] as bool : false;
    final fogDensity = _num(pp['fogDensity'], 0.0) / DartCodeGeneratorService._worldUnitsPerMetre;
    final fogFalloff = _num(pp['fogHeightFalloff'], 1.0) / DartCodeGeneratorService._worldUnitsPerMetre;
    final fogColor = _hexRgb(pp['fogColorHex'], [0.6, 0.7, 0.8]);
    final bloom = _num(pp['bloomIntensity'], 0.0);
    final bloomThreshold = _num(pp['bloomThreshold'], 1000.0);
    final vignette = _num(pp['vignette'], 0.0).clamp(0.0, 1.0);
    final exposure = _num(pp['exposure'], 0.0);
    final saturation = _num(pp['saturation'], 1.0);
    final contrast = _num(pp['contrast'], 1.0);
    final gamma = _num(pp['gamma'], 1.0);
    final b = StringBuffer();
    b.write('LuminaPostProcessSettings.standard().copyWith(');
    b.write('fog: LuminaPostProcessSettings.standard().fog.copyWith(enabled: $fogEnabled, density: ${_f(fogDensity)}, heightFalloff: ${_f(fogFalloff)}, '
        'colorR: ${_f(fogColor[0])}, colorG: ${_f(fogColor[1])}, colorB: ${_f(fogColor[2])}), ');
    b.write('bloom: LuminaPostProcessSettings.standard().bloom.copyWith(enabled: ${bloom > 0}, strength: ${_f((bloom / DartCodeGeneratorService._bloomIntensityMax).clamp(0.0, 1.0))}, highlight: ${_f(bloomThreshold)}), ');
    b.write('vignette: LuminaPostProcessSettings.standard().vignette.copyWith(enabled: ${vignette > 0}, midPoint: ${_f((1.0 - vignette * 0.9).clamp(0.05, 1.0))}), ');
    b.write('colorGrade: LuminaPostProcessSettings.standard().colorGrade.copyWith(exposure: ${_f(exposure)}, saturation: ${_f(saturation)}, contrast: ${_f(contrast)}, '
        'curves: (Vector3.all(${_f(gamma)}), Vector3.all(1.0), Vector3.all(1.0))))');
    return b.toString();
  }
}
