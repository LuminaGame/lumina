import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../physics_fixture.dart';
import '../ragdoll/ragdoll_fixture.dart';

/// A mannequin actor wearing a skinned garment in a physics world.
class Dressed {
  Dressed._(this.w, this.actor, this.mesh, this.cloth);

  /// The mannequin at the origin wearing [garment] (a skirt by default), the
  /// world begun and the garment built.
  static Future<Dressed> create({
    LuminaSkinnedClothComponent Function(LuminaAnimatedMeshComponent mesh)? garment,
    LuminaGlbAnimationSampler? sampler,
  }) async {
    final w = PhysicsWorld();
    final root = LuminaSceneComponent(location: Vector3(0, 0, 0));
    final actor = LuminaActor(root: root);
    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: mannyFile.path)..attachToComponent(root);
    actor.addComponent(mesh);
    final cloth =
        garment?.call(mesh) ??
        LuminaSkinnedClothComponent(mesh: mesh, sampler: sampler ?? mannySampler, color: Vector3(0.6, 0.1, 0.4));
    actor.addComponent(cloth);
    w.world.persistentLevel.registerActor(actor);
    w.begin();
    await cloth.ready;
    return Dressed._(w, actor, mesh, cloth);
  }

  final PhysicsWorld w;
  final LuminaActor actor;
  final LuminaAnimatedMeshComponent mesh;
  final LuminaSkinnedClothComponent cloth;

  /// Poses the garment's skeleton with [local] (the rest pose by default)
  /// under the mesh's current render transform.
  void pose([Float64List? local]) =>
      cloth.modifyPose(Float64List.fromList(local ?? cloth.skeleton!.restPose), mesh.renderTransform, 1 / 60);

  /// Poses the garment's skeleton with a sampler's local pose (one TRS per
  /// sampler node, as `LuminaGlbAnimationSampler.sampleLocal` writes it).
  void poseSampled(Float64List samplerLocal) {
    final skeleton = cloth.skeleton!;
    final out = Float64List(skeleton.nodes.length * LuminaPoseMath.trsStride);
    for (var s = 0; s < skeleton.nodes.length; s++) {
      final o = skeleton.nodes[s] * LuminaPoseMath.trsStride;
      out.setRange(s * LuminaPoseMath.trsStride, (s + 1) * LuminaPoseMath.trsStride, samplerLocal, o);
    }
    pose(out);
  }

  /// Runs [seconds] posing the rest pose every frame.
  void run(double seconds) => w.run(seconds, (_) => pose());

  /// The simulated vertices in the world (cm).
  List<Vector3> worldVertices() {
    final p = cloth.currentSimPositions();
    return [
      for (var i = 0; i < p.length ~/ 3; i++)
        cloth.worldTransform.transform3(Vector3(p[3 * i], p[3 * i + 1], p[3 * i + 2])),
    ];
  }

  /// The rest (skinned at rest) vertices in the world (cm).
  List<Vector3> restVertices() {
    final g = cloth.geometry!;
    return [for (var i = 0; i < g.simVertexCount; i++) cloth.worldTransform.transform3(g.simVertex(i))];
  }

  /// The largest edge stretch now against the rest pose (0.1 = 10 %).
  double maxStretch() {
    final g = cloth.geometry!;
    final now = worldVertices();
    final t = g.simTriangles;
    var worst = 0.0;
    for (var k = 0; k < t.length; k += 3) {
      for (var e = 0; e < 3; e++) {
        final a = t[k + e], b = t[k + (e + 1) % 3];
        final rest = g.simVertex(a).distanceTo(g.simVertex(b));
        if (rest < 1e-6) continue;
        worst = math.max(worst, now[a].distanceTo(now[b]) / rest - 1);
      }
    }
    return worst;
  }

  /// How deep (cm) any garment vertex is inside a limb capsule of the
  /// generated physics asset whose bone matches [bones], posed by the
  /// garment's latest world affines.
  double deepestIn(bool Function(String bone) bones) {
    final skeleton = cloth.skeleton!;
    final world = cloth.worldAffines!;
    final now = worldVertices();
    var deepest = 0.0;
    for (final body in LuminaPhysicsAssetGenerator.fromSampler(cloth.sampler!).bodies) {
      if (!bones(body.bone) || body.shape != LuminaPhysicsBodyShape.capsule) continue;
      final slot = skeleton.slotNamed(body.bone);
      if (slot < 0) continue;
      final bone = LuminaRagdollSkeleton.frameOf(world, slot);
      final rotation = bone.rotation * body.offsetQuaternion;
      final centre = bone.position + (body.offsetVector.clone()..applyQuaternion(bone.rotation));
      final axis = Vector3(0, 1, 0)..applyQuaternion(rotation);
      final half = body.effectiveHalfHeight - body.radius;
      for (final v in now) {
        final t = (v - centre).dot(axis).clamp(-half, half);
        deepest = math.max(deepest, body.radius - v.distanceTo(centre + axis * t));
      }
    }
    return deepest;
  }
}
