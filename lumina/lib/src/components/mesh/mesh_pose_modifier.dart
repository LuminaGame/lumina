import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

/// Rewrites part of a skinned mesh's pose after the animation (see
/// `LuminaAnimatedMeshComponent.poseModifiers`): a ragdoll replacing bones
/// with its bodies, a get-up clip blending in over the live animation.
///
/// Every frame, after the clip or the pose driver and the joint overrides,
/// the mesh reads the local transforms of the nodes named [poseModifierNodes]
/// into a pose array (10 doubles per node: translation, rotation quaternion
/// x y z w, scale; a node the mesh cannot address keeps what the modifier
/// left there) and calls [modifyPose]; when it returns true the mesh writes
/// every node back before the bone matrices update.
abstract interface class LuminaMeshPoseModifier {
  /// The nodes this modifier reads and writes, in pose order. A new list
  /// (not the same instance) makes the mesh resolve them again.
  List<String> get poseModifierNodes;

  /// [pose] holds the animated local transforms of [poseModifierNodes];
  /// [meshTransform] is the mesh's render transform (its world transform
  /// times the asset's unit scale), the frame its root nodes are posed in.
  bool modifyPose(Float64List pose, Matrix4 meshTransform, double deltaTime);
}
