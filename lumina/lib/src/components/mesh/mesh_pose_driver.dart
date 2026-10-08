import 'dart:typed_data';

/// Supplies a skinned mesh's pose from the CPU instead of gltfio's animator
/// (see `LuminaAnimatedMeshComponent.poseDriver`): each frame the mesh asks
/// for the local transforms of the nodes named [poseNodeNames] and writes
/// them to its skin joints of the same names.
abstract interface class LuminaMeshPoseDriver {
  /// The node names of the pose array, in its order.
  List<String> get poseNodeNames;

  /// The pose after [deltaTime] seconds: 10 doubles per node (translation,
  /// rotation quaternion x y z w, scale), or null to leave the joints as they
  /// are this frame.
  Float64List? evaluatePose(double deltaTime);
}
