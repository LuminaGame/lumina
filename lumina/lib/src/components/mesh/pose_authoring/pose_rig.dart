import 'dart:convert';
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/mesh/pose_authoring/pose_quat.dart';
import 'package:lumina/src/components/mesh/pose_authoring/pose_rig_detect.dart';

/// The joint limits of a [LuminaPoseRig], in degrees.
class LuminaPoseRigLimits {
  /// The elbow's hinge range (0 straight).
  final double elbowMin, elbowMax;

  /// The knee's hinge range (0 straight).
  final double kneeMin, kneeMax;

  /// Half-angle of the cone the shoulder→hand direction stays in, about the
  /// arm's outward direction across the body.
  final double shoulderCone;

  /// Half-angle of the cone the hip→foot direction stays in, about the
  /// body's down direction.
  final double hipCone;

  /// The neck chain's total yaw, pitch and roll.
  final double neckYaw, neckPitch, neckRoll;

  /// The bend each spine joint may add to its incoming pose.
  final double spineBend;

  const LuminaPoseRigLimits({
    this.elbowMin = 0,
    this.elbowMax = 150,
    this.kneeMin = 0,
    this.kneeMax = 150,
    this.shoulderCone = 150,
    this.hipCone = 120,
    this.neckYaw = 80,
    this.neckPitch = 60,
    this.neckRoll = 40,
    this.spineBend = 20,
  });

  Map<String, dynamic> toJson() => {
        'elbowMin': elbowMin,
        'elbowMax': elbowMax,
        'kneeMin': kneeMin,
        'kneeMax': kneeMax,
        'shoulderCone': shoulderCone,
        'hipCone': hipCone,
        'neckYaw': neckYaw,
        'neckPitch': neckPitch,
        'neckRoll': neckRoll,
        'spineBend': spineBend,
      };

  factory LuminaPoseRigLimits.fromJson(Map<String, dynamic> j) {
    const d = LuminaPoseRigLimits();
    double n(String k, double f) => j[k] is num ? (j[k] as num).toDouble() : f;
    return LuminaPoseRigLimits(
      elbowMin: n('elbowMin', d.elbowMin),
      elbowMax: n('elbowMax', d.elbowMax),
      kneeMin: n('kneeMin', d.kneeMin),
      kneeMax: n('kneeMax', d.kneeMax),
      shoulderCone: n('shoulderCone', d.shoulderCone),
      hipCone: n('hipCone', d.hipCone),
      neckYaw: n('neckYaw', d.neckYaw),
      neckPitch: n('neckPitch', d.neckPitch),
      neckRoll: n('neckRoll', d.neckRoll),
      spineBend: n('spineBend', d.spineBend),
    );
  }
}

/// A limb by bone name: upper, lower, end (shoulder–elbow–hand,
/// hip–knee–foot), plus the twist bones under the upper and lower bone.
class LuminaPoseLimbDefinition {
  final String upper, lower, end;
  final List<String> upperTwist, lowerTwist;

  const LuminaPoseLimbDefinition(this.upper, this.lower, this.end,
      {this.upperTwist = const [], this.lowerTwist = const []});

  Map<String, dynamic> toJson() => {
        'upper': upper,
        'lower': lower,
        'end': end,
        if (upperTwist.isNotEmpty) 'upperTwist': upperTwist,
        if (lowerTwist.isNotEmpty) 'lowerTwist': lowerTwist,
      };

  factory LuminaPoseLimbDefinition.fromJson(Map<String, dynamic> j) => LuminaPoseLimbDefinition(
        j['upper'] as String,
        j['lower'] as String,
        j['end'] as String,
        upperTwist: [for (final v in (j['upperTwist'] as List?) ?? const []) '$v'],
        lowerTwist: [for (final v in (j['lowerTwist'] as List?) ?? const []) '$v'],
      );
}

/// The bones a pose rig drives, by name: what [LuminaPoseRig.detect] finds
/// or a pose rig asset (`.lmas` with a `pose_rig` document) states.
class LuminaPoseRigDefinition {
  /// `arm_l`, `arm_r`, `leg_l`, `leg_r` (only those the skeleton has).
  final Map<String, LuminaPoseLimbDefinition> limbs;

  /// Spine bones, pelvis side first.
  final List<String> spine;

  /// Neck bones, then the head, root side first.
  final List<String> neck;

  /// Each [neck] bone's share of the head's turn (sums to 1).
  final List<double> neckWeights;

  final String? pelvis;
  final LuminaPoseRigLimits limits;

  const LuminaPoseRigDefinition({
    this.limbs = const {},
    this.spine = const [],
    this.neck = const [],
    this.neckWeights = const [],
    this.pelvis,
    this.limits = const LuminaPoseRigLimits(),
  });

  /// The `.lmas` metadata key holding a pose rig document.
  static const String metadataKey = 'pose_rig';

  Map<String, dynamic> toJson() => {
        'limbs': {for (final e in limbs.entries) e.key: e.value.toJson()},
        'spine': spine,
        'neck': neck,
        'neckWeights': neckWeights,
        if (pelvis != null) 'pelvis': pelvis,
        'limits': limits.toJson(),
      };

  factory LuminaPoseRigDefinition.fromJson(Map<String, dynamic> j) => LuminaPoseRigDefinition(
        limbs: {
          for (final e in ((j['limbs'] as Map?) ?? const {}).entries)
            '${e.key}': LuminaPoseLimbDefinition.fromJson(Map<String, dynamic>.from(e.value as Map)),
        },
        spine: [for (final v in (j['spine'] as List?) ?? const []) '$v'],
        neck: [for (final v in (j['neck'] as List?) ?? const []) '$v'],
        neckWeights: [for (final v in (j['neckWeights'] as List?) ?? const []) (v as num).toDouble()],
        pelvis: j['pelvis'] as String?,
        limits: LuminaPoseRigLimits.fromJson(Map<String, dynamic>.from((j['limits'] as Map?) ?? const {})),
      );

  /// The definition in a pose rig `.lmas` ([bytes]).
  static LuminaPoseRigDefinition fromAssetBytes(Uint8List bytes) {
    final raw = LuminaAsset.fromBytes(bytes).metadata[metadataKey] ?? '';
    if (raw.isEmpty) throw const FormatException('the asset has no pose rig document');
    return LuminaPoseRigDefinition.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  /// A pose rig `.lmas` holding this definition for the mesh [meshPath].
  Uint8List toAssetBytes({required String assetId, String name = 'PoseRig', String meshPath = ''}) => LuminaAsset(
        assetId: assetId,
        name: name,
        type: AssetType.unknown,
        metadata: {metadataKey: jsonEncode(toJson()), if (meshPath.isNotEmpty) 'source_mesh': meshPath},
      ).toProtoBufferBytes();
}

/// What a limb of a built rig is.
enum LuminaPoseLimbKind { arm, leg }

/// A limb of a built [LuminaPoseRig]: slots of its bones in the rig's pose
/// array, and its twist bones with their place along the bone (0 at the
/// joint, 1 at the next one).
class LuminaPoseLimb {
  final String name;
  final LuminaPoseLimbKind kind;
  final int upper, lower, end;
  final List<(int, double)> upperTwist, lowerTwist;

  /// The middle joint's bend direction when the limb is straight (the elbow
  /// back, the knee forward), in the model frame of the rest pose.
  final Vector3 restBendHint;

  /// The direction the cone limit is centred on, in the parent bone's frame.
  final Vector3 coneAxisInParent;

  const LuminaPoseLimb(this.name, this.kind, this.upper, this.lower, this.end, this.upperTwist, this.lowerTwist,
      this.restBendHint, this.coneAxisInParent);
}

/// A humanoid pose rig over a skeleton: the bones the pose authoring
/// solvers move, as slots of a pose array that holds them and every
/// ancestor (10 doubles per node, the mesh's local TRS; see
/// `LuminaMeshPoseModifier`).
class LuminaPoseRig {
  final GlbSkeleton skeleton;
  final LuminaPoseRigDefinition definition;

  /// Skeleton node per slot, parents first.
  final List<int> nodes;
  final List<String> nodeNames;

  /// Slot of each slot's parent (−1 for a node posed in the model frame).
  final Int32List parents;

  /// The rest pose, 10 doubles per slot.
  final Float64List restPose;

  final Map<String, LuminaPoseLimb> limbs;
  final List<int> spine;

  /// The slot whose position is the top of the spine (the chest handle):
  /// the next bone towards the head, or −1.
  final int spineTip;
  final List<int> neck;
  final List<double> neckWeights;
  final int pelvis;

  /// Up, forward and left of the body in the rest pose (model frame).
  final Vector3 restUp, restForward, restLeft;

  /// The rest frame's up/forward/left in the frame of the neck's parent
  /// bone's rest rotation (so the neck limits follow the chest).
  final Vector3 neckUpInParent, neckForwardInParent;

  /// Where the head handle sits, in the head bone's frame (before its
  /// scale): in front of the face, so turning the head moves it around the
  /// neck.
  final Vector3 headHandleOffset;

  LuminaPoseRig._(
    this.skeleton,
    this.definition,
    this.nodes,
    this.nodeNames,
    this.parents,
    this.restPose,
    this.limbs,
    this.spine,
    this.spineTip,
    this.neck,
    this.neckWeights,
    this.pelvis,
    this.restUp,
    this.restForward,
    this.restLeft,
    this.neckUpInParent,
    this.neckForwardInParent,
    this.headHandleOffset,
  );

  LuminaPoseRigLimits get limits => definition.limits;

  int get length => nodes.length;

  /// The slot of the node named [name], or −1.
  int slotNamed(String name) => nodeNames.indexOf(name);

  /// Finds the humanoid bones of [skeleton] by name (MetaHuman / UEFN
  /// mannequin, Mixamo and the like) and builds the rig.
  static LuminaPoseRig detect(GlbSkeleton skeleton, {LuminaPoseRigLimits limits = const LuminaPoseRigLimits()}) =>
      LuminaPoseRig.fromDefinition(skeleton, LuminaPoseRigDetector.detect(skeleton, limits: limits));

  /// Builds the rig [definition] states over [skeleton]; names the skeleton
  /// lacks are left out.
  factory LuminaPoseRig.fromDefinition(GlbSkeleton skeleton, LuminaPoseRigDefinition definition) {
    int node(String? name) => name == null ? -1 : skeleton.indexOf(name);
    final wanted = <int>{};
    void want(int n) {
      for (var p = n; p >= 0 && wanted.add(p); p = skeleton.parent[p]) {}
    }

    final limbDefs = <String, LuminaPoseLimbDefinition>{};
    definition.limbs.forEach((name, l) {
      if (node(l.upper) < 0 || node(l.lower) < 0 || node(l.end) < 0) return;
      limbDefs[name] = l;
      for (final b in [l.upper, l.lower, l.end, ...l.upperTwist, ...l.lowerTwist]) {
        if (node(b) >= 0) want(node(b));
      }
    });
    final spineNodes = [for (final b in definition.spine) if (node(b) >= 0) node(b)];
    final neckNodes = [for (final b in definition.neck) if (node(b) >= 0) node(b)];
    spineNodes.forEach(want);
    neckNodes.forEach(want);
    final pelvisNode = node(definition.pelvis);
    if (pelvisNode >= 0) want(pelvisNode);
    // The chest point: the bone after the last spine bone towards the head.
    var tipNode = -1;
    if (spineNodes.isNotEmpty) {
      final last = spineNodes.last;
      if (neckNodes.isNotEmpty) {
        for (var n = neckNodes.first; n >= 0; n = skeleton.parent[n]) {
          if (skeleton.parent[n] == last) {
            tipNode = n;
            break;
          }
        }
      }
      if (tipNode < 0) {
        for (var i = 0; i < skeleton.count; i++) {
          if (skeleton.parent[i] == last) {
            tipNode = i;
            break;
          }
        }
      }
      if (tipNode >= 0) want(tipNode);
    }

    final order = [for (final n in skeleton.order) if (wanted.contains(n)) n];
    final slotOf = {for (var i = 0; i < order.length; i++) order[i]: i};
    final parents = Int32List.fromList([
      for (final n in order) skeleton.parent[n] < 0 ? -1 : (slotOf[skeleton.parent[n]] ?? -1),
    ]);
    final rest = Float64List(order.length * 10);
    for (var i = 0; i < order.length; i++) {
      rest.setAll(i * 10, skeleton.rest(order[i]).toList());
    }
    final names = [for (final n in order) skeleton.names[n] ?? 'node_$n'];

    // Rest frames in the model space.
    final state = _RestFrames(parents, rest);
    Vector3 at(int n) => state.pos[slotOf[n]!];
    Vector3 up = Vector3(0, 1, 0);
    if (neckNodes.isNotEmpty && (pelvisNode >= 0 || spineNodes.isNotEmpty)) {
      final d = at(neckNodes.last) - at(pelvisNode >= 0 ? pelvisNode : spineNodes.first);
      if (d.length2 > 1e-12) up = d.normalized();
    }
    final left = Vector3.zero();
    for (final side in const [('arm_l', 'arm_r'), ('leg_l', 'leg_r')]) {
      final a = limbDefs[side.$1], b = limbDefs[side.$2];
      if (a != null && b != null) left.add(at(node(a.upper)) - at(node(b.upper)));
    }
    var leftAxis = LuminaPoseQuat.across(left, up);
    if (leftAxis.length2 < 1e-12) leftAxis = LuminaPoseQuat.across(Vector3(1, 0, 0), up);
    leftAxis.normalize();
    final forward = leftAxis.cross(up)..normalize();

    final limbs = <String, LuminaPoseLimb>{};
    limbDefs.forEach((name, l) {
      final kind = name.startsWith('leg') ? LuminaPoseLimbKind.leg : LuminaPoseLimbKind.arm;
      final u = slotOf[node(l.upper)]!, lo = slotOf[node(l.lower)]!, e = slotOf[node(l.end)]!;
      List<(int, double)> twists(List<String> bones, int from, int to) {
        final length = (state.pos[to] - state.pos[from]).length;
        return [
          for (final b in bones)
            if (node(b) >= 0 && length > 1e-12)
              (slotOf[node(b)]!, ((state.pos[slotOf[node(b)]!] - state.pos[from]).length / length).clamp(0.0, 1.0)),
        ];
      }

      final isLeft = name.endsWith('_l');
      final hint = kind == LuminaPoseLimbKind.arm ? -forward : forward.clone();
      final coneWorld = kind == LuminaPoseLimbKind.arm ? (isLeft ? leftAxis.clone() : -leftAxis) : -up;
      final parent = parents[u];
      final coneLocal =
          parent < 0 ? coneWorld : LuminaPoseQuat.qRotate(LuminaPoseQuat.qConj(state.rot[parent]), coneWorld);
      limbs[name] = LuminaPoseLimb(name, kind, u, lo, e, twists(l.upperTwist, u, lo), twists(l.lowerTwist, lo, e), hint,
          coneLocal..normalize());
    });

    final neckSlots = [for (final n in neckNodes) slotOf[n]!];
    var weights = definition.neckWeights;
    if (weights.length != neckSlots.length) weights = LuminaPoseRigDetector.neckWeightsFor(neckSlots.length);
    var neckUp = up, neckFwd = forward;
    if (neckSlots.isNotEmpty && parents[neckSlots.first] >= 0) {
      final inv = LuminaPoseQuat.qConj(state.rot[parents[neckSlots.first]]);
      neckUp = LuminaPoseQuat.qRotate(inv, up);
      neckFwd = LuminaPoseQuat.qRotate(inv, forward);
    }
    // The head handle: in front of the face at about eye height, a fifth of
    // the pelvis–head distance away from the head bone.
    var headOffset = Vector3.zero();
    if (neckSlots.isNotEmpty) {
      final h = neckSlots.last;
      final base = pelvisNode >= 0 ? state.pos[slotOf[pelvisNode]!] : state.pos[neckSlots.first];
      var size = (state.pos[h] - base).length * 0.2;
      if (size < 1e-9) size = 0.1;
      final world = forward * size + up * (size * 0.5);
      final s = state.scale[h] == 0 ? 1.0 : state.scale[h];
      headOffset = LuminaPoseQuat.qRotate(LuminaPoseQuat.qConj(state.rot[h]), world) / s;
    }
    return LuminaPoseRig._(
      skeleton,
      definition,
      order,
      names,
      parents,
      rest,
      limbs,
      [for (final n in spineNodes) slotOf[n]!],
      tipNode < 0 ? -1 : slotOf[tipNode]!,
      neckSlots,
      List.unmodifiable(weights),
      pelvisNode < 0 ? -1 : slotOf[pelvisNode]!,
      up,
      forward,
      leftAxis,
      neckUp,
      neckFwd,
      headOffset,
    );
  }

  /// The handles this rig has: `hand_*`/`elbow_*` per arm, `foot_*`/`knee_*`
  /// per leg, `head` (a neck chain), `chest` (a spine), `pelvis`.
  List<String> get handleNames => [
        for (final side in const ['l', 'r']) ...[
          if (limbs.containsKey('arm_$side')) ...['hand_$side', 'elbow_$side'],
          if (limbs.containsKey('leg_$side')) ...['foot_$side', 'knee_$side'],
        ],
        if (neck.isNotEmpty) 'head',
        if (spine.isNotEmpty && spineTip >= 0) 'chest',
        if (pelvis >= 0) 'pelvis',
      ];

  /// The slot whose world transform a handle shows, or −1.
  int handleSlot(String handle) => switch (handle) {
        'hand_l' => limbs['arm_l']?.end ?? -1,
        'hand_r' => limbs['arm_r']?.end ?? -1,
        'elbow_l' => limbs['arm_l']?.lower ?? -1,
        'elbow_r' => limbs['arm_r']?.lower ?? -1,
        'foot_l' => limbs['leg_l']?.end ?? -1,
        'foot_r' => limbs['leg_r']?.end ?? -1,
        'knee_l' => limbs['leg_l']?.lower ?? -1,
        'knee_r' => limbs['leg_r']?.lower ?? -1,
        'head' => neck.isEmpty ? -1 : neck.last,
        'chest' => spineTip,
        'pelvis' => pelvis,
        _ => -1,
      };

  /// A copy of the rest pose.
  Float64List restPoseCopy() => Float64List.fromList(restPose);

  /// The world transform of slot [slot] in [pose] under [meshTransform] (the
  /// mesh's render transform).
  Matrix4 worldTransformOf(Float64List pose, Matrix4 meshTransform, int slot) {
    final chain = <int>[];
    for (var s = slot; s >= 0; s = parents[s]) {
      chain.insert(0, s);
    }
    final m = meshTransform.clone();
    for (final s in chain) {
      final o = s * 10;
      m.multiply(Matrix4.compose(Vector3(pose[o], pose[o + 1], pose[o + 2]),
          Quaternion(pose[o + 3], pose[o + 4], pose[o + 5], pose[o + 6]), Vector3(pose[o + 7], pose[o + 8], pose[o + 9])));
    }
    return m;
  }

  /// The world position of the node named [bone] in [pose].
  Vector3 worldPositionOf(Float64List pose, Matrix4 meshTransform, String bone) =>
      worldTransformOf(pose, meshTransform, slotNamed(bone)).getTranslation();
}

/// Model-space positions and rotations of a rest pose.
class _RestFrames {
  final List<Vector3> pos = [];
  final List<Quaternion> rot = [];
  final List<double> scale = [];

  _RestFrames(Int32List parents, Float64List pose) {
    for (var i = 0; i < parents.length; i++) {
      final o = i * 10;
      final t = Vector3(pose[o], pose[o + 1], pose[o + 2]);
      final r = Quaternion(pose[o + 3], pose[o + 4], pose[o + 5], pose[o + 6])..normalize();
      final p = parents[i];
      if (p < 0) {
        pos.add(t);
        rot.add(r);
        scale.add(pose[o + 7]);
      } else {
        pos.add(pos[p] + LuminaPoseQuat.qRotate(rot[p], t * scale[p]));
        rot.add(LuminaPoseQuat.qMul(rot[p], r)..normalize());
        scale.add(scale[p] * pose[o + 7]);
      }
    }
  }
}
