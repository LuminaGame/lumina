import 'package:vector_math/vector_math_64.dart';

/// How a [LuminaPoseHandle] moves its part of the body.
enum LuminaPoseHandleKind {
  /// A hand or foot: the end of a two-bone limb.
  effector,

  /// An elbow or knee: the pole its limb bends towards.
  pole,

  /// The head: the neck chain turns it towards the handle.
  look,

  /// The chest: the spine bends to reach the handle.
  chest,

  /// The pelvis: moved and turned directly.
  pelvis,
}

/// How a pose authoring component keeps what its handles set.
enum LuminaPoseCaptureMode {
  /// Targets stay in the mesh's component space and are solved every frame
  /// over the incoming pose: the pose follows the actor, and clearing a
  /// handle gives its limb back to the animation.
  holdTargets,

  /// Every solved pose is kept as the base of the next frame: clearing a
  /// handle leaves its limb where it is.
  bakeToPose,
}

/// One grab point of a posable character (`hand_l`, `elbow_r`, `head`,
/// `chest`, `pelvis`, …) and the target it holds.
class LuminaPoseHandle {
  final String name;
  final LuminaPoseHandleKind kind;

  /// The bone whose transform the handle shows.
  final String bone;

  LuminaPoseHandle(this.name, this.kind, this.bone);

  /// Whether the handle holds a target now.
  bool get hasTarget => modelTarget != null || pendingWorldTarget != null;

  /// A target set in world units, turned into the mesh's model frame on the
  /// next solve.
  Vector3? pendingWorldTarget;
  Quaternion? pendingWorldRotation;

  /// The target in the mesh's model frame (the GLB's), once resolved.
  Vector3? modelTarget;
  Quaternion? modelRotation;

  void clear() {
    pendingWorldTarget = null;
    pendingWorldRotation = null;
    modelTarget = null;
    modelRotation = null;
  }

  /// The handle's kind by name.
  static LuminaPoseHandleKind kindOf(String name) => switch (name) {
        'elbow_l' || 'elbow_r' || 'knee_l' || 'knee_r' => LuminaPoseHandleKind.pole,
        'head' => LuminaPoseHandleKind.look,
        'chest' => LuminaPoseHandleKind.chest,
        'pelvis' => LuminaPoseHandleKind.pelvis,
        _ => LuminaPoseHandleKind.effector,
      };
}
