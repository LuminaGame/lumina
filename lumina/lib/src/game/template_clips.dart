/// The clip set of the Third Person template's character bundle, kept free
/// of engine imports so `tool/build_third_person_content.dart` (plain
/// `dart run`, no Flutter) can read it. `LuminaThirdPersonContent` exposes
/// the same constants to the engine.
///
/// The character and its clips are Quaternius' CC0 "Universal Base
/// Characters" and "Universal Animation Library" 1 and 2 (see
/// `assets/templates/third_person/LICENSE.txt`). The libraries animate
/// forward only: the side and backward walk / jog cycles are derived from
/// the forward ones by the build tool (see [walks]).
class LuminaThirdPersonClips {
  const LuminaThirdPersonClips._();

  /// Name of the skeletal mesh asset, in the bundle and in a project.
  static const String meshAssetName = 'SKM_Superhero_Female';

  /// The merged GLB, relative to the lumina package root.
  static const String bundledMeshPath = 'assets/templates/third_person/$meshAssetName.glb';

  static const String idle = 'Idle_Loop';
  static const String jump = 'Jump_Start';
  static const String fallLoop = 'Jump_Loop';
  static const String land = 'Jump_Land';

  /// The dash plays a dodge roll.
  static const String dash = 'Roll';

  /// The wall jump plays the second library's flip jump.
  static const String wallJump = 'NinjaJump_Start';

  /// Clips exported with root motion on the `root` bone, which the merger
  /// strips. The libraries' in-place exports carry none.
  static const Set<String> rootMotionClips = {};

  /// The idle breaks one of which plays after standing still a while.
  static const List<String> idleBreaks = ['Idle_Talking_Loop', 'Idle_FoldArms_Loop', 'Yes'];

  /// Turn-in-place clips by the yaw (degrees, right positive) each turns
  /// through. The libraries have none, so a standing character simply turns
  /// with its capsule.
  static const Map<String, double> turns = {};

  /// The eight-way walk, in [LuminaLocomotionDirection] order
  /// (forward, then clockwise). Only the forward cycle is authored; the
  /// build tool turns it toward the other forward directions and plays it
  /// backward for the backward ones (see [directionDegrees]).
  static const List<String> walks = [
    'Walk_Fwd_Loop',
    'Walk_Fwd_Right_Loop',
    'Walk_Right_Loop',
    'Walk_Bwd_Right_Loop',
    'Walk_Bwd_Loop',
    'Walk_Bwd_Left_Loop',
    'Walk_Left_Loop',
    'Walk_Fwd_Left_Loop',
  ];

  /// The eight-way jog, in the same order and derived the same way: the
  /// sprint row of the locomotion blend space.
  static const List<String> jogs = [
    'Jog_Fwd_Loop',
    'Jog_Fwd_Right_Loop',
    'Jog_Right_Loop',
    'Jog_Bwd_Right_Loop',
    'Jog_Bwd_Loop',
    'Jog_Bwd_Left_Loop',
    'Jog_Left_Loop',
    'Jog_Fwd_Left_Loop',
  ];

  /// Direction (degrees, right positive) of each entry of [walks] / [jogs].
  static const List<double> directionDegrees = [0.0, 45.0, 90.0, 135.0, 180.0, -135.0, -90.0, -45.0];

  /// The aim offset's bone chain on this skeleton and each bone's share of
  /// the aim (its head bone is `Head`).
  static const List<(String, double)> aimOffsetBones = [('spine_03', 0.15), ('neck_01', 0.25), ('Head', 0.6)];

  /// Every clip in the bundle, in the order the tool merges them (which is the
  /// gltfio animation index order).
  static const List<String> names = [
    idle,
    ...walks,
    jump,
    fallLoop,
    land,
    dash,
    wallJump,
    ...idleBreaks,
    ...jogs,
  ];
}
