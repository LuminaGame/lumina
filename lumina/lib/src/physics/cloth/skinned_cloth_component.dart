import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/animation/motion_matching/pose_search_database_runtime.dart';
import 'package:lumina/src/assets/glb_loader.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/components/mesh/mesh_pose_modifier.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/physics/cloth/cloth_component.dart';
import 'package:lumina/src/physics/ragdoll/ragdoll_skeleton.dart';
import 'package:lumina/src/utility/lumina_assets.dart';

/// How a skinned cloth's simulation vertices follow the skeleton: up to four
/// skeleton entries and weights per vertex, how far each may leave its
/// skinned position (cm; 0 keeps it on the body), and the skeleton's rest
/// pose (mesh space, metres, `LuminaPoseMath` affines).
class LuminaClothSkinData {
  LuminaClothSkinData(this.joints, this.weights, this.maxDistances, this.restAffines);

  final Uint32List joints;
  final Float32List weights;
  final Float32List maxDistances;
  final Float64List restAffines;
}

/// A garment on an animated character: cloth whose vertices are skinned to
/// the character's skeleton, so it moves with the animation and swings
/// within [maxDistance] of where the skin puts it, colliding with the
/// character's limbs (capsules of the physics asset generated from the
/// skeleton) and the world.
///
/// - **Garment**: [meshAsset] (a skinned `.glb` whose joints are named like
///   the character's bones; its skin weights are used), or a generated skirt
///   around [waistBone]: [skirtLength] long, from [waistRadius] at the waist
///   ([waistOffset] above the bone) to [hemRadius] at the hem, in
///   [skirtColumns] x [skirtRows] quads, weighted to the nearest leg and hip
///   bones.
/// - **Freedom**: a vertex may move [maxDistance] cm from its skinned
///   position at the far end of the garment (the hem), less toward its top
///   (`t^1.5`); the top stays on the body.
/// - **Body**: with [collideWithBody], the character's limbs are capsules
///   that move with the animation and push the garment out; the cloth
///   ignores its character's other bodies (its capsule).
///
/// The component attaches itself to [mesh] (at its origin) and reads the
/// animated pose as a pose modifier on it (it never changes the pose).
class LuminaSkinnedClothComponent extends LuminaClothComponent implements LuminaMeshPoseModifier {
  LuminaSkinnedClothComponent({
    super.key,
    this.mesh,
    this.sampler,
    super.meshAsset,
    this.waistBone = 'pelvis',
    this.skirtLength = 45,
    this.waistRadius = 17,
    this.hemRadius = 34,
    this.waistOffset = 6,
    this.skirtColumns = 32,
    this.skirtRows = 12,
    this.maxDistance = 25,
    this.collideWithBody = true,
    super.massKg = 0.6,
    super.stiffness,
    super.bendStiffness = 0.15,
    super.damping = 0.3,
    super.friction = 0.3,
    super.thickness = 1.0,
    super.iterations = 10,
    super.wind,
    super.windDrag,
    super.windTurbulence,
    super.color,
    super.castShadows,
    super.assetProvider,
  }) : super(pinning: LuminaClothPinning.none);

  /// The animated mesh whose skeleton the garment follows.
  LuminaAnimatedMeshComponent? mesh;

  /// The mesh's skeleton (read from [mesh]'s asset when null).
  LuminaGlbAnimationSampler? sampler;

  final String waistBone;
  final double skirtLength, waistRadius, hemRadius, waistOffset;
  final int skirtColumns, skirtRows;
  final double maxDistance;
  final bool collideWithBody;

  LuminaRagdollSkeleton? _skeleton;
  LuminaClothSkinData? _skin;
  Float64List? _world;
  bool _posed = false;
  int poseVersion = 0;

  /// The skeleton the garment follows (all of the mesh's nodes).
  LuminaRagdollSkeleton? get skeleton => _skeleton;

  /// How the simulation vertices are skinned (null until built).
  LuminaClothSkinData? get skin => _skin;

  /// The skeleton's latest world affines (cm, the mesh's render transform
  /// applied; 12 per entry), or null before the first pose.
  Float64List? get worldAffines => _posed ? _world : null;

  @override
  void onRegister(LuminaActor ownerActor) {
    final m = mesh;
    if (m != null && !identical(parentComponent, m)) attachToComponent(m);
    super.onRegister(ownerActor);
  }

  @override
  Future<LuminaClothGeometry> buildClothGeometry() async {
    final m = mesh;
    var s = sampler;
    if (s == null) {
      if (m == null) throw StateError('a skinned cloth needs the animated mesh it is worn on');
      s = sampler = await LuminaPoseSearchDatabaseRuntime.meshSampler(m.meshAssetPath, provider: m.assetProvider);
    }
    final skeleton = _skeleton = LuminaRagdollSkeleton(s, allNodes: true);
    final rest = Float64List(skeleton.nodes.length * LuminaPoseMath.affineStride);
    skeleton.world(skeleton.restPose, _identityAffine, rest);
    _world = Float64List(rest.length);
    m?.poseModifiers.add(this);
    final asset = meshAsset;
    final (geometry, skin) = asset == null || asset.isEmpty
        ? _skirt(skeleton, rest)
        : await _garment(asset, skeleton, rest);
    _skin = skin;
    return geometry;
  }

  static final Float64List _identityAffine = Float64List.fromList([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]);

  // --- Pose ---------------------------------------------------------------------------

  @override
  List<String> get poseModifierNodes => _skeleton?.nodeNames ?? const [];

  @override
  bool modifyPose(Float64List pose, Matrix4 meshTransform, double deltaTime) {
    final skeleton = _skeleton, world = _world;
    if (skeleton == null || world == null) return false;
    // A node the mesh cannot address (a scene root above the skeleton) keeps
    // what this modifier left there: its rest transform, never zeros.
    final rest = skeleton.restPose;
    for (var o = 0; o + LuminaPoseMath.trsStride <= pose.length; o += LuminaPoseMath.trsStride) {
      if (pose[o + 7] == 0 && pose[o + 8] == 0 && pose[o + 9] == 0) {
        pose.setRange(o, o + LuminaPoseMath.trsStride, rest, o);
      }
    }
    skeleton.world(pose, LuminaRagdollSkeleton.affineOf(meshTransform), world);
    _posed = true;
    poseVersion++;
    return false;
  }

  @override
  void onUnregister() {
    mesh?.poseModifiers.remove(this);
    super.onUnregister();
  }

  // --- Garments ----------------------------------------------------------------------

  /// A skirt around [waistBone] in mesh space, its vertices weighted to the
  /// nearest hip and leg bones.
  (LuminaClothGeometry, LuminaClothSkinData) _skirt(LuminaRagdollSkeleton skeleton, Float64List rest) {
    var waist = skeleton.slotNamed(waistBone);
    if (waist < 0) waist = skeleton.slotNamed('Hips');
    if (waist < 0) throw StateError('the skeleton has no "$waistBone" bone for the skirt');
    final centre = _position(rest, waist);
    final cols = math.max(6, skirtColumns), rows = math.max(1, skirtRows);
    final top = centre.y + waistOffset / 100;
    final positions = Float32List(cols * (rows + 1) * 3);
    final uvs = Float32List(cols * (rows + 1) * 2);
    for (var r = 0; r <= rows; r++) {
      final t = r / rows;
      final radius = (waistRadius + (hemRadius - waistRadius) * t) / 100;
      for (var c = 0; c < cols; c++) {
        final a = 2 * math.pi * c / cols;
        final i = r * cols + c;
        positions
          ..[3 * i] = (centre.x + radius * math.sin(a)) * 100
          ..[3 * i + 1] = (top - skirtLength / 100 * t) * 100
          ..[3 * i + 2] = (centre.z + radius * 0.85 * math.cos(a)) * 100;
        uvs
          ..[2 * i] = c / cols
          ..[2 * i + 1] = t;
      }
    }
    final indices = <int>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final a = r * cols + c, b = r * cols + (c + 1) % cols;
        final d = a + cols, e = b + cols;
        indices.addAll([a, d, b, b, d, e]);
      }
    }
    final geometry = LuminaClothGeometry.weld(positions, uvs, Uint32List.fromList(indices));
    final bones = _legBones(skeleton, rest);
    final n = geometry.simVertexCount;
    final joints = Uint32List(n * 4), weights = Float32List(n * 4), maxD = Float32List(n);
    for (var i = 0; i < n; i++) {
      final p = geometry.simVertex(i) / 100;
      final t = ((top - p.y) / (skirtLength / 100)).clamp(0.0, 1.0);
      if (t < 1e-3) {
        joints[4 * i] = waist;
        weights[4 * i] = 1;
      } else {
        _weigh(p, bones, rest, joints, weights, 4 * i);
      }
      maxD[i] = t < 1e-3 ? 0 : maxDistance * math.pow(t, 1.5);
    }
    return (geometry, LuminaClothSkinData(joints, weights, maxD, rest));
  }

  /// A skinned garment asset: its own weights, joints matched by name.
  Future<(LuminaClothGeometry, LuminaClothSkinData)> _garment(
      String path, LuminaRagdollSkeleton skeleton, Float64List rest) async {
    final bytes = await LuminaAssets.resolve(assetProvider)(path);
    GlbMeshData? mesh;
    try {
      mesh = await Isolate.run(() => GlbReader.parse(bytes, decoders: GlbDecoders(draco: LuminaGlbLoader.decoders.draco)),
          debugName: 'garment mesh');
    } on UnsupportedError {
      mesh = await LuminaGlbLoader.parse(bytes);
    }
    if (mesh == null) throw StateError('not a readable GLB: $path');
    final geometry = LuminaClothGeometry.fromMesh(mesh);
    final vj = mesh.jointsPerVertex, vw = mesh.weightsPerVertex;
    if (vj == null || vw == null) throw StateError('$path has no skin weights');
    final n = geometry.simVertexCount;
    final joints = Uint32List(n * 4), weights = Float32List(n * 4), maxD = Float32List(n);
    final done = List<bool>.filled(n, false);
    final slotOfNode = <int, int>{};
    for (var r = 0; r < geometry.renderVertexCount; r++) {
      final s = geometry.renderToSim[r];
      if (done[s]) continue;
      done[s] = true;
      for (var k = 0; k < 4; k++) {
        final node = vj[4 * r + k];
        final slot = slotOfNode.putIfAbsent(node, () => skeleton.slotNamed(mesh!.allNodes[node].name));
        if (slot < 0) continue;
        joints[4 * s + k] = slot;
        weights[4 * s + k] = vw[4 * r + k];
      }
    }
    final b = geometry.bounds;
    final height = math.max(b.max.y - b.min.y, 1e-3);
    for (var i = 0; i < n; i++) {
      final t = ((b.max.y - geometry.simVertex(i).y) / height).clamp(0.0, 1.0);
      maxD[i] = t < 0.05 ? 0 : maxDistance * math.pow(t, 1.5);
    }
    return (geometry, LuminaClothSkinData(joints, weights, maxD, rest));
  }

  static final RegExp _legBone = RegExp(r'pelvis|hips|thigh|upleg|calf|^(left|right)?leg$|knee|shin', caseSensitive: false);

  /// Hip and leg bones as segments from each bone to its first child.
  static List<(int, Vector3, Vector3)> _legBones(LuminaRagdollSkeleton skeleton, Float64List rest) {
    final out = <(int, Vector3, Vector3)>[];
    for (var slot = 0; slot < skeleton.nodes.length; slot++) {
      final name = skeleton.nodeNames[slot];
      if (!_legBone.hasMatch(name) || name.contains('twist') || name.contains('ik_')) continue;
      final from = _position(rest, slot);
      var to = from;
      for (var c = 0; c < skeleton.nodes.length; c++) {
        if (skeleton.parents[c] == slot) {
          to = _position(rest, c);
          break;
        }
      }
      out.add((slot, from, to));
    }
    return out;
  }

  /// Weights of [p] to its two nearest bone segments (inverse square
  /// distance).
  static void _weigh(Vector3 p, List<(int, Vector3, Vector3)> bones, Float64List rest, Uint32List joints,
      Float32List weights, int o) {
    final scored = [
      for (final (slot, a, b) in bones) (slot, _segmentDistance(p, a, b)),
    ]..sort((x, y) => x.$2.compareTo(y.$2));
    final take = scored.take(2).toList();
    var total = 0.0;
    for (final (_, d) in take) {
      total += 1 / math.pow(d + 0.02, 2);
    }
    for (var k = 0; k < take.length; k++) {
      joints[o + k] = take[k].$1;
      weights[o + k] = (1 / math.pow(take[k].$2 + 0.02, 2)) / total;
    }
  }

  static double _segmentDistance(Vector3 p, Vector3 a, Vector3 b) {
    final ab = b - a;
    final len2 = ab.length2;
    final t = len2 < 1e-12 ? 0.0 : ((p - a).dot(ab) / len2).clamp(0.0, 1.0);
    return (a + ab * t).distanceTo(p);
  }

  static Vector3 _position(Float64List affines, int slot) {
    final o = slot * LuminaPoseMath.affineStride;
    return Vector3(affines[o + 9], affines[o + 10], affines[o + 11]);
  }
}
