import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../physics_fixture.dart';

Directory get testAssets =>
    Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

File get mannyFile => File('${testAssets.path}/mannequin/SKM_Manny_Simple.glb');

/// Why a mannequin test skips, or false.
Object get mannySkip => mannyFile.existsSync() ? false : 'test-assets/mannequin/SKM_Manny_Simple.glb is missing';

LuminaGlbAnimationSampler? _sampler;

/// The test-assets mannequin's skeleton (no clips), parsed once.
LuminaGlbAnimationSampler get mannySampler => _sampler ??= LuminaGlbAnimationSampler.fromGlb(mannyFile.readAsBytesSync());

/// A mesh render transform: the mesh at [at] (cm), glTF metres → cm, turned
/// by [rotation].
Matrix4 meshTransformAt(Vector3 at, {Quaternion? rotation}) =>
    Matrix4.compose(at, rotation ?? Quaternion.identity(), Vector3.all(LuminaUnits.unitsPerMetre));

/// The mannequin's rest-pose bone frames of [skeleton]'s body bones under
/// [mesh].
Map<String, LuminaBoneFrame> restFrames(LuminaRagdollSkeleton skeleton, LuminaPhysicsAssetData asset, Matrix4 mesh) {
  final world = skeleton.restWorld(LuminaRagdollSkeleton.affineOf(mesh));
  return {
    for (final b in asset.bodies)
      if (skeleton.slotNamed(b.bone) >= 0) b.bone: LuminaRagdollSkeleton.frameOf(world, skeleton.slotNamed(b.bone)),
  };
}

/// A world with a floor and a mannequin ragdoll built at rest under [mesh].
class RagdollWorld {
  RagdollWorld(Matrix4 mesh, {LuminaPhysicsAssetData? asset}) {
    w = PhysicsWorld();
    owner = LuminaActor(root: LuminaSceneComponent());
    w.world.persistentLevel.registerActor(owner);
    w.begin();
    this.asset = asset ?? LuminaPhysicsAssetGenerator.fromSampler(mannySampler);
    skeleton = LuminaRagdollSkeleton(mannySampler, bones: [for (final b in this.asset.bodies) mannySampler.indexOfNode(b.bone)]);
    rest = restFrames(skeleton, this.asset, mesh);
    ragdoll = LuminaRagdoll.create(physics: w.physics, owner: owner, asset: this.asset, skeleton: skeleton, rest: rest);
  }

  late final PhysicsWorld w;
  late final LuminaActor owner;
  late final LuminaPhysicsAssetData asset;
  late final LuminaRagdollSkeleton skeleton;
  late final Map<String, LuminaBoneFrame> rest;
  late final LuminaRagdoll ragdoll;

  /// The lowest point of any body (cm).
  double get lowest {
    var y = double.infinity;
    for (final b in ragdoll.bodies) {
      y = y < b.body.bounds.min.y ? y : b.body.bounds.min.y;
    }
    return y;
  }

  void dispose() => w.dispose();
}

/// A flat TRS pose copy.
Float64List copyPose(Float64List p) => Float64List.fromList(p);

/// The test-assets mannequin with two authored get-up clips: `GetUp_Front`
/// starts lying face down, `GetUp_Back` face up (pelvis turned ±90° about
/// the lateral axis, 15 cm above the ground), both standing in their rest
/// pose after one second; plus `Flail`, the arms raised.
Uint8List mannyWithGetUps() {
  var glb = mannyFile.readAsBytesSync();
  final sampler = LuminaGlbAnimationSampler.fromGlb(glb);
  final rest = sampler.restWorld();
  final pelvis = sampler.indexOfNode('pelvis');
  final parent = sampler.parents[pelvis];
  List<double> localFor(Quaternion turn, double height) {
    // Desired pelvis world: turned about +X, lowered to [height] m.
    final pr = Float64List(4);
    LuminaPoseMath.affineRotation(rest, pelvis * 12, pr, 0);
    final q = turn * Quaternion(pr[0], pr[1], pr[2], pr[3]);
    final world = Float64List(12);
    final m = q.asRotationMatrix().storage;
    world.setRange(0, 9, m);
    world[9] = rest[pelvis * 12 + 9];
    world[10] = height;
    world[11] = rest[pelvis * 12 + 11];
    final inv = Float64List(12), local = Float64List(12), trs = Float64List(10);
    LuminaPoseMath.invertAffine(rest, parent * 12, inv, 0);
    LuminaPoseMath.multiplyAffine(inv, 0, world, 0, local, 0);
    LuminaPoseMath.decomposeAffine(local, 0, trs, 0);
    return trs.toList();
  }

  final restLocal = sampler.rest.sublist(pelvis * 10, pelvis * 10 + 10).toList();
  for (final (name, angle) in [('GetUp_Front', math.pi / 2), ('GetUp_Back', -math.pi / 2)]) {
    final lying = localFor(Quaternion.axisAngle(Vector3(1, 0, 0), angle), 0.15);
    final clip = AuthoredAnimationClip(name: name, frameRate: 30, lengthFrames: 30)
      ..setKey('pelvis', AuthoredChannel.translation, 0, lying.sublist(0, 3))
      ..setKey('pelvis', AuthoredChannel.rotation, 0, lying.sublist(3, 7))
      ..setKey('pelvis', AuthoredChannel.translation, 30, restLocal.sublist(0, 3))
      ..setKey('pelvis', AuthoredChannel.rotation, 30, restLocal.sublist(3, 7));
    glb = GlbAuthoredClipWriter.write(meshGlb: glb, clip: clip).glb;
  }
  final upper = sampler.indexOfNode('upperarm_l');
  final up = sampler.rest.sublist(upper * 10 + 3, upper * 10 + 7).toList();
  final raised = (Quaternion(up[0], up[1], up[2], up[3]) * Quaternion.axisAngle(Vector3(0, 0, 1), 1.0))..normalize();
  final flail = AuthoredAnimationClip(name: 'Flail', frameRate: 30, lengthFrames: 30)
    ..setKey('upperarm_l', AuthoredChannel.rotation, 0, [raised.x, raised.y, raised.z, raised.w])
    ..setKey('upperarm_l', AuthoredChannel.rotation, 30, up);
  return GlbAuthoredClipWriter.write(meshGlb: glb, clip: flail).glb;
}
