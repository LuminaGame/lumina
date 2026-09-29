import 'package:lumina/lumina.dart';

/// The blend spaces ABP_Character plays, by the path its states name (BS_Walk
/// and, the Walk state's BS_Locomotion).
Map<String, LuminaBlendSpaceDocument> templateBlendSpaces() => LuminaThirdPersonContent.blendSpaces;

/// ABP_Character compiled for the VM.
LuminaAnimBlueprintClass templateAnimClass() => LuminaAnimBlueprintClass.fromDocument(
      LuminaThirdPersonContent.animBlueprint,
      name: LuminaThirdPersonContent.animBlueprintName,
      blendSpaces: templateBlendSpaces(),
    );

/// The Third Person character Blueprint with a Skeletal Mesh animated by
/// ABP_Character (the template's `LuminaThirdPersonContent.characterBlueprint`).
LuminaBlueprintDocument templateCharacterBlueprint({
  List<LuminaInputAction> inputActions = const [],
  String meshAsset = LuminaThirdPersonContent.bundledMeshPath,
}) =>
    LuminaThirdPersonContent.characterBlueprint(inputActions: inputActions, meshAsset: meshAsset);

/// Lengths of the bundle's clips (seconds), as gltfio reports them from
/// `SKM_Superhero_Female.glb`; headless rigs never load the mesh, so the
/// instance is told them through `clipDurationFallbacks`.
const Map<String, double> templateClipDurations = {
  'Idle_Loop': 2.5,
  'Walk_Fwd_Loop': 1.333,
  'Walk_Fwd_Right_Loop': 1.333,
  'Walk_Right_Loop': 1.333,
  'Walk_Bwd_Right_Loop': 1.333,
  'Walk_Bwd_Loop': 1.333,
  'Walk_Bwd_Left_Loop': 1.333,
  'Walk_Left_Loop': 1.333,
  'Walk_Fwd_Left_Loop': 1.333,
  'Jump_Start': 1.333,
  'Jump_Loop': 2.5,
  'Jump_Land': 1.267,
  'Roll': 1.467,
  'NinjaJump_Start': 0.967,
  'Idle_Talking_Loop': 2.933,
  'Idle_FoldArms_Loop': 2.5,
  'Yes': 2.5,
  'Jog_Fwd_Loop': 0.933,
  'Jog_Fwd_Right_Loop': 0.933,
  'Jog_Right_Loop': 0.933,
  'Jog_Bwd_Right_Loop': 0.933,
  'Jog_Bwd_Loop': 0.933,
  'Jog_Bwd_Left_Loop': 0.933,
  'Jog_Left_Loop': 0.933,
  'Jog_Fwd_Left_Loop': 0.933,
};

/// Turn-in-place clips a bundle may add (the template's has none), by the
/// yaw each turns through, and ABP_Character built with states for them.
const Map<String, double> testTurnClips = {
  'Turn_Left_90': -90.0,
  'Turn_Left_180': -180.0,
  'Turn_Right_90': 90.0,
  'Turn_Right_180': 180.0,
};

LuminaAnimBlueprintClass turningAnimClass() => LuminaAnimBlueprintClass.fromDocument(
      LuminaThirdPersonContent.animBlueprintWith(turns: testTurnClips),
      name: LuminaThirdPersonContent.animBlueprintName,
      blendSpaces: templateBlendSpaces(),
    );

/// [templateClipDurations] plus the 2 s [testTurnClips].
const Map<String, double> turningClipDurations = {
  ...templateClipDurations,
  'Turn_Left_90': 2.0,
  'Turn_Left_180': 2.0,
  'Turn_Right_90': 2.0,
  'Turn_Right_180': 2.0,
};
