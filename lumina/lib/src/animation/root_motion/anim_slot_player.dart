import 'dart:typed_data';

import 'package:lumina/src/components/mesh/mesh_pose_driver.dart';

/// A pose source played in an Animation Blueprint's default slot, over its
/// state machine (see `LuminaAnimBlueprintInstance.playSlot`): the instance
/// starts it from the pose the mesh shows, advances it every tick before
/// the mesh applies it, and when it finishes hands its pose back to the
/// state machine (inertialized when a Motion Matching state plays).
abstract interface class LuminaAnimSlotPlayer implements LuminaMeshPoseDriver {
  /// Starts from [fromPose] / [fromVelocity] (TRS per node and its
  /// per-node linear + angular velocity, in [fromNodes]' order) so the
  /// first frame shows that pose and blends away from it; null pops.
  void begin({Float64List? fromPose, Float64List? fromVelocity, List<String>? fromNodes});

  /// Advances [deltaTime] seconds; false once finished (the last pose is
  /// still the one to show this frame).
  bool advance(double deltaTime);

  bool get finished;

  /// The pose shown by the last advance and its velocity (6 doubles per
  /// node), for the hand back.
  Float64List get pose;
  Float64List get poseVelocity;

  /// Called once when the slot stops playing it: [interrupted] when it was
  /// stopped or replaced before finishing.
  void end({required bool interrupted});
}
