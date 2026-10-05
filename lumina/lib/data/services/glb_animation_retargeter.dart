import 'dart:math' as math;
import 'dart:typed_data';

import 'glb_animation_merger.dart';

/// How well a clip's animated bones match a skeleton, by name.
class GlbSkeletonMatch {
  /// Animated clip bones the skeleton has.
  final int matched;

  /// Bones the clip animates.
  final int animated;

  /// Animated clip bones the skeleton lacks.
  final List<String> missing;

  const GlbSkeletonMatch({required this.matched, required this.animated, required this.missing});

  /// Share of the clip's animated bones found in the skeleton, 0–1.
  double get score => animated == 0 ? 0 : matched / animated;
}

/// A clip retargeted into a skeletal mesh GLB.
class GlbRetargetResult {
  /// The mesh GLB with the clip appended (or replaced, when one of the same
  /// name was there).
  final Uint8List glb;

  final String clipName;

  /// Index of the clip among the result's animations (the gltfio animator
  /// index).
  final int clipIndex;

  /// Clip length in seconds.
  final double duration;

  /// Skeleton bones that follow a clip bone of the same name.
  final List<String> mappedBones;

  /// Skeleton bones the clip has no bone for; they hold their rest rotation
  /// relative to their parent.
  final List<String> restBones;

  /// Clip bones the skeleton does not have (ignored).
  final List<String> ignoredSourceBones;

  /// Factor applied to the pelvis translation (target leg length over the
  /// clip's leg length).
  final double pelvisTranslationScale;

  const GlbRetargetResult({
    required this.glb,
    required this.clipName,
    required this.clipIndex,
    required this.duration,
    required this.mappedBones,
    required this.restBones,
    required this.ignoredSourceBones,
    required this.pelvisTranslationScale,
  });
}

/// Retargets a skeletal animation onto another skeleton that shares its bone
/// names (the UE4 → UE5 mannequin case) and appends it to that
/// skeleton's GLB, so one gltfio asset (one animator) plays it.
///
/// Unlike [GlbAnimationMerger], which copies channels verbatim onto an
/// identical skeleton, this handles skeletons that differ in hierarchy and
/// proportions (UE5's spine_04/05, neck_02 and metacarpals have no UE4
/// counterpart):
///
/// - **Rotation only.** Every matched bone takes the clip bone's rotation in
///   model space (the clip's forward kinematics); its local rotation follows
///   from its target parent. Skeleton bones the clip lacks keep their rest
///   rotation relative to their parent. Both skeletons must share the bone
///   axis convention and model space — true for glTF exported by Unreal and
///   for FBX normalized by `FbxImportService` (both Y up, facing +Z).
/// - **Translations come from the target skeleton**, except the skeleton root
///   (copied: root motion and placement) and the pelvis (copied, scaled by the
///   target's leg length over the clip's).
///   Clip bone translations are otherwise ignored: an Unreal FBX carries the
///   authoring skeleton's proportions in them.
///
/// Every skeleton joint gets a rotation and a translation channel (constant
/// ones where nothing moves), so switching from another clip of the asset
/// cannot leave a bone where that clip put it.
abstract final class GlbAnimationRetargeter {
  /// All node indices of a target skeleton: skin joints, ancestors up to the
  /// root, and any intermediate bone nodes.
  static Set<int> _skeletonNodeIndices(Map<String, dynamic> json) {
    final skins = (json['skins'] as List?) ?? const [];
    if (skins.isEmpty) return const {};
    final nodes = (json['nodes'] as List?) ?? const [];
    final parent = List<int>.filled(nodes.length, -1);
    for (var i = 0; i < nodes.length; i++) {
      for (final c in ((nodes[i] as Map)['children'] as List?) ?? const []) {
        if (c is int && c >= 0 && c < nodes.length) parent[c] = i;
      }
    }
    final skeletonNodes = <int>{};
    for (final s in skins) {
      if (s is! Map) continue;
      final skeletonRoot = s['skeleton'] as int?;
      if (skeletonRoot != null && skeletonRoot >= 0 && skeletonRoot < nodes.length) {
        skeletonNodes.add(skeletonRoot);
      }
      for (final j in (s['joints'] as List?) ?? const []) {
        if (j is! int || j < 0 || j >= nodes.length) continue;
        var curr = j;
        while (curr >= 0) {
          if (!skeletonNodes.add(curr)) break;
          curr = parent[curr];
        }
      }
    }
    for (final s in skins) {
      if (s is! Map) continue;
      final skeletonRoot = s['skeleton'] as int?;
      if (skeletonRoot != null && skeletonRoot >= 0 && skeletonRoot < nodes.length) {
        void visit(int n) {
          if ((nodes[n] as Map)['mesh'] == null) {
            skeletonNodes.add(n);
            for (final c in ((nodes[n] as Map)['children'] as List?) ?? const []) {
              if (c is int && c >= 0 && c < nodes.length) visit(c);
            }
          }
        }
        visit(skeletonRoot);
      }
    }
    return skeletonNodes;
  }

  /// Names of the joints of every skin in [glb], including intermediate
  /// skeleton hierarchy nodes.
  static Set<String> jointNames(Uint8List glb) {
    final json = GlbDocument.parse(glb).json;
    final nodes = (json['nodes'] as List?) ?? const [];
    final indices = _skeletonNodeIndices(json);
    return {
      for (final j in indices)
        if ((nodes[j] as Map)['name'] is String) (nodes[j] as Map)['name'] as String,
    };
  }

  /// Names of the nodes animation [animationIndex] of [clip] animates.
  static Set<String> animatedNodeNames(Uint8List clip, {int animationIndex = 0}) {
    final json = GlbDocument.parse(clip).json;
    final nodes = (json['nodes'] as List?) ?? const [];
    final animations = (json['animations'] as List?) ?? const [];
    if (animationIndex < 0 || animationIndex >= animations.length) return const {};
    return {
      for (final c in ((animations[animationIndex] as Map)['channels'] as List?) ?? const [])
        if (((c as Map)['target'] as Map)['node'] is int)
          if ((nodes[(c['target'] as Map)['node'] as int] as Map)['name'] is String)
            (nodes[(c['target'] as Map)['node'] as int] as Map)['name'] as String,
    };
  }

  /// How well [clip]'s animation matches [target]'s skeleton.
  static GlbSkeletonMatch match({required Uint8List target, required Uint8List clip, int animationIndex = 0}) =>
      matchNames(jointNames(target), animatedNodeNames(clip, animationIndex: animationIndex));

  static const Map<String, List<String>> _humanoidSynonyms = {
    'pelvis': ['hips', 'pelvis', 'root'],
    'hips': ['hips', 'pelvis', 'root'],
    'spine_01': ['spine1', 'spine_01', 'spine'],
    'spine1': ['spine1', 'spine_01', 'spine'],
    'spine': ['spine1', 'spine_01', 'spine'],
    'spine_02': ['spine2', 'spine_02'],
    'spine2': ['spine2', 'spine_02'],
    'spine_03': ['chest', 'spine3', 'spine_03'],
    'spine3': ['chest', 'spine3', 'spine_03'],
    'chest': ['chest', 'spine_03', 'spine3'],
    'neck_01': ['neck1', 'neck_01', 'neck'],
    'neck1': ['neck1', 'neck_01', 'neck'],
    'neck': ['neck1', 'neck_01', 'neck'],
    'head': ['head', 'head_01'],
    'clavicle_l': ['leftshoulder', 'clavicle_l', 'shoulder_l'],
    'leftshoulder': ['leftshoulder', 'clavicle_l', 'shoulder_l'],
    'upperarm_l': ['leftarm', 'upperarm_l', 'arm_l'],
    'leftarm': ['leftarm', 'upperarm_l', 'arm_l'],
    'lowerarm_l': ['leftforearm', 'lowerarm_l', 'forearm_l'],
    'leftforearm': ['leftforearm', 'lowerarm_l', 'forearm_l'],
    'hand_l': ['lefthand', 'hand_l'],
    'lefthand': ['lefthand', 'hand_l'],
    'clavicle_r': ['rightshoulder', 'clavicle_r', 'shoulder_r'],
    'rightshoulder': ['rightshoulder', 'clavicle_r', 'shoulder_r'],
    'upperarm_r': ['rightarm', 'upperarm_r', 'arm_r'],
    'rightarm': ['rightarm', 'upperarm_r', 'arm_r'],
    'lowerarm_r': ['rightforearm', 'lowerarm_r', 'forearm_r'],
    'rightforearm': ['rightforearm', 'lowerarm_r', 'forearm_r'],
    'hand_r': ['righthand', 'hand_r'],
    'righthand': ['righthand', 'hand_r'],
    'thigh_l': ['leftupleg', 'thigh_l', 'upleg_l'],
    'leftupleg': ['leftupleg', 'thigh_l', 'upleg_l'],
    'calf_l': ['leftleg', 'calf_l', 'lowerleg_l'],
    'leftleg': ['leftleg', 'calf_l', 'lowerleg_l'],
    'foot_l': ['leftfoot', 'foot_l'],
    'leftfoot': ['leftfoot', 'foot_l'],
    'thigh_r': ['rightupleg', 'thigh_r', 'upleg_r'],
    'rightupleg': ['rightupleg', 'thigh_r', 'upleg_r'],
    'calf_r': ['rightleg', 'calf_r', 'lowerleg_r'],
    'rightleg': ['rightleg', 'calf_r', 'lowerleg_r'],
    'foot_r': ['rightfoot', 'foot_r'],
    'rightfoot': ['rightfoot', 'foot_r'],
  };

  static int? _resolveSourceBone(
    String targetName,
    Map<String, int> srcByName,
    Map<String, int> srcByNameLower,
  ) {
    final direct = srcByName[targetName] ?? srcByNameLower[targetName.toLowerCase()];
    if (direct != null) return direct;

    final lower = targetName.toLowerCase();
    final clean = lower.startsWith('mixamorig:') ? lower.substring(10) : lower;
    final directClean = srcByNameLower[clean];
    if (directClean != null) return directClean;

    final candidates = _humanoidSynonyms[clean];
    if (candidates != null) {
      for (final cand in candidates) {
        final match = srcByNameLower[cand];
        if (match != null) return match;
      }
    }
    return null;
  }

  static GlbSkeletonMatch matchNames(Set<String> targetJoints, Set<String> animated) {
    final targetLower = {for (final j in targetJoints) j.toLowerCase()};
    bool matches(String animBone) {
      if (targetJoints.contains(animBone)) return true;
      final lower = animBone.toLowerCase();
      if (targetLower.contains(lower)) return true;
      final clean = lower.startsWith('mixamorig:') ? lower.substring(10) : lower;
      if (targetLower.contains(clean)) return true;
      final synonyms = _humanoidSynonyms[clean];
      if (synonyms != null) {
        for (final s in synonyms) {
          if (targetLower.contains(s)) return true;
        }
      }
      return false;
    }
    final missing = [for (final n in animated) if (!matches(n)) n]..sort();
    return GlbSkeletonMatch(matched: animated.length - missing.length, animated: animated.length, missing: missing);
  }

  /// Retargets animation [animationIndex] of [clip] onto [target]'s skeleton
  /// and returns [target] with it appended as [clipName] (replacing an
  /// animation of that name).
  ///
  /// Throws [FormatException] when either input is not a GLB, [target] has no
  /// skin, the animation index is out of range, or no bone matches.
  static GlbRetargetResult retargetInto({
    required Uint8List target,
    required Uint8List clip,
    required String clipName,
    int animationIndex = 0,
  }) {
    final tDoc = GlbDocument.parse(target, label: 'target');
    final cDoc = GlbDocument.parse(clip, label: 'clip');
    final src = _Skeleton(cDoc);
    final tgt = _Skeleton(tDoc);

    final buffers = (tDoc.json['buffers'] as List?) ?? const [];
    if (buffers.length > 1) {
      throw FormatException('target uses ${buffers.length} buffers; only single-buffer GLBs can be merged into');
    }

    final joints = _skeletonNodeIndices(tDoc.json);
    if (joints.isEmpty) throw const FormatException('target has no skin; there is no skeleton to retarget onto');

    final animations = (cDoc.json['animations'] as List?) ?? const [];
    if (animationIndex < 0 || animationIndex >= animations.length) {
      throw FormatException('clip has ${animations.length} animations; asked for $animationIndex');
    }
    final tracks = _Tracks(cDoc, animations[animationIndex] as Map);

    // Name → node, for both sides (case-sensitive first, then case-insensitive fallback).
    final srcByName = <String, int>{};
    final srcByNameLower = <String, int>{};
    for (var i = 0; i < src.count; i++) {
      final n = src.names[i];
      if (n != null) {
        srcByName.putIfAbsent(n, () => i);
        srcByNameLower.putIfAbsent(n.toLowerCase(), () => i);
      }
    }
    final mapped = <int, int>{}; // target node → source node
    for (final j in joints) {
      final name = tgt.names[j];
      final s = name == null ? null : _resolveSourceBone(name, srcByName, srcByNameLower);
      if (s != null) mapped[j] = s;
    }
    if (mapped.isEmpty) {
      throw const FormatException('no skeleton bone of the target matches a bone of the clip by name');
    }

    // The skeleton root: the matched joint no other matched joint is above.
    int? rootT;
    for (final j in tgt.order) {
      if (!mapped.containsKey(j)) continue;
      var p = tgt.parent[j];
      var nested = false;
      while (p >= 0) {
        if (mapped.containsKey(p)) {
          nested = true;
          break;
        }
        p = tgt.parent[p];
      }
      if (!nested) {
        rootT = j;
        break;
      }
    }
    final rootS = mapped[rootT]!;

    int? pelvisT;
    for (final j in mapped.keys) {
      final name = tgt.names[j]!.toLowerCase();
      if (name == 'pelvis' || name == 'hips' || name.endsWith(':hips')) {
        pelvisT = j;
        break;
      }
    }

    // Pelvis translation scale: leg lengths (thigh→calf→foot), from the clip's
    // own translation keys when it has them (its authoring proportions).
    double legLength(_Skeleton sk, _Tracks? tr, String side) {
      double len(String bone) {
        final i = sk.names.indexOf(bone);
        if (i < 0) return 0;
        final key = tr?.translationAtFirstKey(i);
        final t = key ?? sk.restT[i];
        return math.sqrt(t[0] * t[0] + t[1] * t[1] + t[2] * t[2]);
      }

      final calf = len('calf_$side'), foot = len('foot_$side');
      return calf > 0 && foot > 0 ? calf + foot : 0;
    }

    var pelvisScale = 1.0;
    final srcLeg = legLength(src, tracks, 'l') > 0 ? legLength(src, tracks, 'l') : legLength(src, tracks, 'r');
    final tgtLeg = legLength(tgt, null, 'l') > 0 ? legLength(tgt, null, 'l') : legLength(tgt, null, 'r');
    if (srcLeg > 0 && tgtLeg > 0) {
      pelvisScale = tgtLeg / srcLeg;
    } else if (pelvisT != null) {
      final ps = mapped[pelvisT]!;
      final a = _length(src.restT[ps]), b = _length(tgt.restT[pelvisT]);
      if (a > 0 && b > 0) pelvisScale = b / a;
    }

    // Time grid: every key time of the clip.
    final times = tracks.keyTimes();
    final frames = times.isEmpty ? [0.0] : times;
    final duration = frames.last;

    // Per frame: source model-space rotations → target local rotations.
    final rotOut = <int, List<_Quat>>{for (final j in joints) j: <_Quat>[]};
    final srcWorld = List<_Quat>.filled(src.count, _Quat.identity);
    final tgtWorld = List<_Quat>.filled(tgt.count, _Quat.identity);
    // Parents of the skeleton roots, at rest on the target side.
    final tgtRootParent = tgt.restWorld(tgt.parent[rootT!]);
    final rootAlign = (tgt.restWorld(rootT) * src.restWorld(rootS).inverse()).normalized();
    final srcRestWorld = List<_Quat>.generate(src.count, (i) => src.restWorld(i));
    final tgtRestWorld = List<_Quat>.generate(tgt.count, (j) => tgt.restWorld(j));

    // Check whether the target skeleton shares the bone axis convention
    // and rest pose orientation of the source skeleton (e.g. UE4 Manny → UE5 Quinn).
    // When skeletons share the bone axes, direct model-space rotation transfer
    // preserves the authored world orientations.
    // When skeletons differ in bone axis convention (e.g. Unreal +X vs Blender/glTF +Y,
    // where thigh or pelvis can differ by 90-180°), direct model-space transfer
    // twists and contorts the mesh, so we apply the delta rotation relative
    // to the target's own rest pose.
    final sharesRestAxes = !mapped.entries.any((e) {
      final name = tgt.names[e.key]?.toLowerCase() ?? '';
      if (name != 'pelvis' &&
          name != 'hips' &&
          !name.endsWith(':hips') &&
          name != 'thigh_l' &&
          name != 'thigh_r' &&
          name != 'spine_01' &&
          name != 'spine') {
        return false;
      }
      final diff = (rootAlign * srcRestWorld[e.value] * tgtRestWorld[e.key].inverse()).normalized();
      final angle = 2 * math.acos(diff.w.abs().clamp(0.0, 1.0));
      return angle > (25.0 * math.pi / 180.0);
    });

    // When rest poses differ (e.g. source T-pose vs target A-pose, such as MetaHuman
    // where arms slant down 50°+), align each target bone's rest world orientation to
    // the source rest bone direction. This ensures animation deltas authored from
    // T-pose apply relative to an aligned reference instead of compounding the slant
    // and causing arms/hands to cross inward.
    final tgtRestAligned = List<_Quat>.generate(tgt.count, (j) {
      final s = mapped[j];
      if (s == null) return tgtRestWorld[j];
      final vTgt = tgt.boneDirection(j);
      final vSrc = src.boneDirection(s);
      if (vTgt != null && vSrc != null) {
        final qAlign = _Quat.fromTo(vTgt, vSrc);
        return (qAlign * tgtRestWorld[j]).normalized();
      }
      return tgtRestWorld[j];
    });

    for (final t in frames) {
      for (final i in src.order) {
        final local = tracks.rotation(i, t) ?? src.restR[i];
        final p = src.parent[i];
        srcWorld[i] = p < 0 ? local : srcWorld[p] * local;
      }
      for (final j in tgt.order) {
        final p = tgt.parent[j];
        final parentWorld = p < 0 ? _Quat.identity : tgtWorld[p];
        final s = mapped[j];
        if (s != null) {
          if (sharesRestAxes) {
            tgtWorld[j] = (rootAlign * srcWorld[s]).normalized();
          } else {
            final delta = (srcWorld[s] * srcRestWorld[s].inverse()).normalized();
            tgtWorld[j] = (delta * tgtRestAligned[j]).normalized();
          }
          if (joints.contains(j)) rotOut[j]!.add((parentWorld.inverse() * tgtWorld[j]).normalized());
        } else {
          final local = tgt.restR[j];
          tgtWorld[j] = parentWorld * local;
          if (joints.contains(j)) rotOut[j]!.add(local);
        }
      }
    }

    // Translations: root copied, pelvis scaled, the rest from the skeleton.
    List<List<double>>? sampledTranslation(int targetJoint, double scale, {bool isPelvis = false}) {
      final s = mapped[targetJoint];
      if (s == null || !tracks.hasTranslation(s)) return null;
      final qAlign = isPelvis
          ? (tgt.restR[rootT!].inverse() * src.restR[rootS]).normalized()
          : (tgt.parent[rootT!] < 0 ? _Quat.identity : tgtRootParent * src.restWorld(src.parent[rootS]).inverse()).normalized();
      return [
        for (final t in frames) [
          for (final v in qAlign.rotateVector(tracks.translation(s, t)!)) v * scale,
        ],
      ];
    }

    final rootTranslation = sampledTranslation(rootT, 1.0);
    final pelvisTranslation = pelvisT == null ? null : sampledTranslation(pelvisT, pelvisScale, isPelvis: true);

    // ---- Write the animation into the target GLB.
    final json = tDoc.json;
    final bin = BytesBuilder(copy: false)..add(tDoc.bin);
    var binLength = tDoc.bin.length;
    final bufferViews = (json['bufferViews'] as List?)?.toList() ?? <dynamic>[];
    final accessors = (json['accessors'] as List?)?.toList() ?? <dynamic>[];

    int addAccessor(Float32List data, String type, int count, {List<double>? min, List<double>? max}) {
      final padding = ((binLength + 3) & ~3) - binLength;
      if (padding > 0) bin.add(Uint8List(padding));
      final offset = binLength + padding;
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      bin.add(Uint8List.fromList(bytes));
      binLength = offset + bytes.length;
      bufferViews.add(<String, dynamic>{'buffer': 0, 'byteOffset': offset, 'byteLength': bytes.length});
      accessors.add(<String, dynamic>{
        'bufferView': bufferViews.length - 1,
        'componentType': 5126,
        'count': count,
        'type': type,
        'min': ?min,
        'max': ?max,
      });
      return accessors.length - 1;
    }

    final frameInput = addAccessor(Float32List.fromList(frames), 'SCALAR', frames.length,
        min: [frames.first], max: [frames.last]);
    final constTimes = duration > 0 ? [0.0, duration] : [0.0];
    final constInput = addAccessor(Float32List.fromList(constTimes), 'SCALAR', constTimes.length,
        min: [constTimes.first], max: [constTimes.last]);

    final samplers = <Map<String, dynamic>>[];
    final channels = <Map<String, dynamic>>[];
    void channel(int node, String path, int input, int output) {
      samplers.add({'input': input, 'output': output, 'interpolation': 'LINEAR'});
      channels.add({
        'sampler': samplers.length - 1,
        'target': {'node': node, 'path': path},
      });
    }

    final sortedJoints = joints.toList()..sort();
    for (final j in sortedJoints) {
      // Rotation.
      final keys = rotOut[j]!;
      final varies = mapped.containsKey(j);
      if (varies) {
        final data = Float32List(keys.length * 4);
        _Quat? prev;
        for (var k = 0; k < keys.length; k++) {
          var q = keys[k];
          if (prev != null && prev.dot(q) < 0) q = q.negated(); // shortest path between keys
          prev = q;
          data.setAll(k * 4, [q.x, q.y, q.z, q.w]);
        }
        channel(j, 'rotation', frameInput, addAccessor(data, 'VEC4', keys.length));
      } else {
        final q = tgt.restR[j];
        final data = Float32List.fromList([for (var k = 0; k < constTimes.length; k++) ...[q.x, q.y, q.z, q.w]]);
        channel(j, 'rotation', constInput, addAccessor(data, 'VEC4', constTimes.length));
      }

      // Translation.
      final sampled = j == rootT ? rootTranslation : (j == pelvisT ? pelvisTranslation : null);
      if (sampled != null) {
        final data = Float32List(sampled.length * 3);
        for (var k = 0; k < sampled.length; k++) {
          data.setAll(k * 3, sampled[k]);
        }
        channel(j, 'translation', frameInput, addAccessor(data, 'VEC3', sampled.length));
      } else {
        final t = tgt.restT[j];
        final data = Float32List.fromList([for (var k = 0; k < constTimes.length; k++) ...t]);
        channel(j, 'translation', constInput, addAccessor(data, 'VEC3', constTimes.length));
      }
    }

    final existing = ((json['animations'] as List?) ?? const []).toList();
    final replaced = existing.indexWhere((a) => (a as Map)['name'] == clipName);
    final animation = <String, dynamic>{'name': clipName, 'channels': channels, 'samplers': samplers};
    final int clipIndex;
    if (replaced >= 0) {
      existing[replaced] = animation;
      clipIndex = replaced;
    } else {
      existing.add(animation);
      clipIndex = existing.length - 1;
    }
    json['animations'] = existing;
    json['bufferViews'] = bufferViews;
    json['accessors'] = accessors;
    final merged = bin.takeBytes();
    json['buffers'] = [
      <String, dynamic>{'byteLength': merged.length},
    ];

    final mappedNames = [for (final j in sortedJoints) if (mapped.containsKey(j)) tgt.names[j]!];
    final restNames = [for (final j in sortedJoints) if (!mapped.containsKey(j)) tgt.names[j] ?? '#$j'];
    final targetNames = {for (final j in joints) tgt.names[j]};
    final ignored = [
      for (final i in tracks.animatedNodes)
        if (src.names[i] != null && !targetNames.contains(src.names[i])) src.names[i]!,
    ]..sort();

    return GlbRetargetResult(
      glb: GlbDocument(json, merged).encode(),
      clipName: clipName,
      clipIndex: clipIndex,
      duration: duration,
      mappedBones: mappedNames,
      restBones: restNames,
      ignoredSourceBones: ignored,
      pelvisTranslationScale: pelvisScale,
    );
  }

  static double _length(List<double> v) => math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
}

// ---------------------------------------------------------------------------

class _Quat {
  final double x, y, z, w;
  const _Quat(this.x, this.y, this.z, this.w);

  @override
  String toString() => '[${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)}, ${z.toStringAsFixed(4)}, ${w.toStringAsFixed(4)}]';

  static const identity = _Quat(0, 0, 0, 1);


  _Quat operator *(_Quat b) => _Quat(
        w * b.x + x * b.w + y * b.z - z * b.y,
        w * b.y - x * b.z + y * b.w + z * b.x,
        w * b.z + x * b.y - y * b.x + z * b.w,
        w * b.w - x * b.x - y * b.y - z * b.z,
      );

  _Quat inverse() {
    final n = x * x + y * y + z * z + w * w;
    return n == 0 ? identity : _Quat(-x / n, -y / n, -z / n, w / n);
  }

  List<double> rotateVector(List<double> v) {
    final qv = _Quat(v[0], v[1], v[2], 0);
    final res = this * qv * inverse();
    return [res.x, res.y, res.z];
  }

  _Quat normalized() {
    final n = math.sqrt(x * x + y * y + z * z + w * w);
    return n == 0 ? identity : _Quat(x / n, y / n, z / n, w / n);
  }

  _Quat negated() => _Quat(-x, -y, -z, -w);

  double dot(_Quat b) => x * b.x + y * b.y + z * b.z + w * b.w;

  static _Quat slerp(_Quat a, _Quat b, double t) {
    var d = a.dot(b);
    var bb = b;
    if (d < 0) {
      d = -d;
      bb = b.negated();
    }
    if (d > 0.9995) {
      return _Quat(
        a.x + (bb.x - a.x) * t,
        a.y + (bb.y - a.y) * t,
        a.z + (bb.z - a.z) * t,
        a.w + (bb.w - a.w) * t,
      ).normalized();
    }
    final theta = math.acos(d);
    final s = math.sin(theta);
    final wa = math.sin((1 - t) * theta) / s, wb = math.sin(t * theta) / s;
    return _Quat(a.x * wa + bb.x * wb, a.y * wa + bb.y * wb, a.z * wa + bb.z * wb, a.w * wa + bb.w * wb);
  }

  static _Quat fromTo(List<double> vFrom, List<double> vTo) {
    double len(List<double> v) => math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    final lFrom = len(vFrom), lTo = len(vTo);
    if (lFrom < 1e-6 || lTo < 1e-6) return identity;
    final f = [vFrom[0] / lFrom, vFrom[1] / lFrom, vFrom[2] / lFrom];
    final t = [vTo[0] / lTo, vTo[1] / lTo, vTo[2] / lTo];
    final d = f[0] * t[0] + f[1] * t[1] + f[2] * t[2];
    if (d >= 1.0 - 1e-7) return identity;
    if (d <= -1.0 + 1e-7) {
      final ortho = f[0].abs() < 0.9 ? const [1.0, 0.0, 0.0] : const [0.0, 1.0, 0.0];
      final axis = [
        f[1] * ortho[2] - f[2] * ortho[1],
        f[2] * ortho[0] - f[0] * ortho[2],
        f[0] * ortho[1] - f[1] * ortho[0],
      ];
      final lAxis = len(axis);
      return _Quat(axis[0] / lAxis, axis[1] / lAxis, axis[2] / lAxis, 0.0);
    }
    final axis = [
      f[1] * t[2] - f[2] * t[1],
      f[2] * t[0] - f[0] * t[2],
      f[0] * t[1] - f[1] * t[0],
    ];
    final s = math.sqrt((1.0 + d) * 2.0);
    return _Quat(axis[0] / s, axis[1] / s, axis[2] / s, s / 2.0).normalized();
  }

  /// Rotation part of a column-major matrix (unit scale assumed after
  /// normalizing the columns).
  static _Quat fromMatrix(List<double> m) {
    double col(int c) => math.sqrt(m[c * 4] * m[c * 4] + m[c * 4 + 1] * m[c * 4 + 1] + m[c * 4 + 2] * m[c * 4 + 2]);
    final sx = col(0), sy = col(1), sz = col(2);
    double r(int row, int c, double s) => s == 0 ? 0 : m[c * 4 + row] / s;
    final r00 = r(0, 0, sx), r10 = r(1, 0, sx), r20 = r(2, 0, sx);
    final r01 = r(0, 1, sy), r11 = r(1, 1, sy), r21 = r(2, 1, sy);
    final r02 = r(0, 2, sz), r12 = r(1, 2, sz), r22 = r(2, 2, sz);
    final trace = r00 + r11 + r22;
    if (trace > 0) {
      final s = math.sqrt(trace + 1.0) * 2;
      return _Quat((r21 - r12) / s, (r02 - r20) / s, (r10 - r01) / s, 0.25 * s).normalized();
    } else if (r00 > r11 && r00 > r22) {
      final s = math.sqrt(1.0 + r00 - r11 - r22) * 2;
      return _Quat(0.25 * s, (r01 + r10) / s, (r02 + r20) / s, (r21 - r12) / s).normalized();
    } else if (r11 > r22) {
      final s = math.sqrt(1.0 + r11 - r00 - r22) * 2;
      return _Quat((r01 + r10) / s, 0.25 * s, (r12 + r21) / s, (r02 - r20) / s).normalized();
    }
    final s = math.sqrt(1.0 + r22 - r00 - r11) * 2;
    return _Quat((r02 + r20) / s, (r12 + r21) / s, 0.25 * s, (r10 - r01) / s).normalized();
  }
}

/// Node hierarchy of a GLB: names, parents, rest TRS and a parent-first
/// order.
class _Skeleton {
  final List<String?> names;
  final List<int> parent;
  final List<List<double>> restT;
  final List<_Quat> restR;
  final List<int> order;

  int get count => names.length;

  factory _Skeleton(GlbDocument doc) {
    final nodes = (doc.json['nodes'] as List?) ?? const [];
    final names = <String?>[];
    final parent = List<int>.filled(nodes.length, -1);
    final restT = <List<double>>[];
    final restR = <_Quat>[];
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i] as Map;
      names.add(n['name'] as String?);
      for (final c in (n['children'] as List?) ?? const []) {
        parent[c as int] = i;
      }
      final matrix = n['matrix'] as List?;
      if (matrix != null && matrix.length == 16) {
        final m = [for (final v in matrix) (v as num).toDouble()];
        restT.add([m[12], m[13], m[14]]);
        restR.add(_Quat.fromMatrix(m));
      } else {
        final t = (n['translation'] as List?) ?? const [0, 0, 0];
        final r = (n['rotation'] as List?) ?? const [0, 0, 0, 1];
        restT.add([for (final v in t) (v as num).toDouble()]);
        restR.add(_Quat((r[0] as num).toDouble(), (r[1] as num).toDouble(), (r[2] as num).toDouble(), (r[3] as num).toDouble())
            .normalized());
      }
    }
    final order = <int>[];
    void visit(int i) {
      order.add(i);
      for (final c in ((nodes[i] as Map)['children'] as List?) ?? const []) {
        visit(c as int);
      }
    }

    for (var i = 0; i < nodes.length; i++) {
      if (parent[i] < 0) visit(i);
    }
    return _Skeleton._(names, parent, restT, restR, order);
  }

  _Skeleton._(this.names, this.parent, this.restT, this.restR, this.order);

  /// Rest rotation of [node] in model space (identity for -1).
  _Quat restWorld(int node) {
    var q = _Quat.identity;
    var i = node;
    final chain = <int>[];
    while (i >= 0) {
      chain.add(i);
      i = parent[i];
    }
    for (final n in chain.reversed) {
      q = q * restR[n];
    }
    return q;
  }

  /// Rest position of [node] in model space ([0, 0, 0] for -1).
  List<double> restWorldPos(int node) {
    if (node < 0) return const [0.0, 0.0, 0.0];
    final chain = <int>[];
    var curr = node;
    while (curr >= 0) {
      chain.add(curr);
      curr = parent[curr];
    }
    var pos = [0.0, 0.0, 0.0];
    var rot = _Quat.identity;
    for (final n in chain.reversed) {
      final tRot = rot.rotateVector(restT[n]);
      pos = [pos[0] + tRot[0], pos[1] + tRot[1], pos[2] + tRot[2]];
      rot = rot * restR[n];
    }
    return pos;
  }

  /// Rest model-space direction of bone [node], pointing towards its primary child.
  List<double>? boneDirection(int node) {
    if (node < 0 || node >= count) return null;
    final nodePos = restWorldPos(node);
    int? bestChild;
    var maxL = 0.0;
    for (var i = 0; i < parent.length; i++) {
      if (parent[i] == node) {
        final cPos = restWorldPos(i);
        final dx = cPos[0] - nodePos[0], dy = cPos[1] - nodePos[1], dz = cPos[2] - nodePos[2];
        final l = math.sqrt(dx * dx + dy * dy + dz * dz);
        if (l > maxL) {
          maxL = l;
          bestChild = i;
        }
      }
    }
    if (bestChild != null && maxL > 0.001) {
      final cPos = restWorldPos(bestChild);
      return [(cPos[0] - nodePos[0]) / maxL, (cPos[1] - nodePos[1]) / maxL, (cPos[2] - nodePos[2]) / maxL];
    }
    final p = parent[node];
    if (p >= 0) {
      final pPos = restWorldPos(p);
      final dx = nodePos[0] - pPos[0], dy = nodePos[1] - pPos[1], dz = nodePos[2] - pPos[2];
      final l = math.sqrt(dx * dx + dy * dy + dz * dz);
      if (l > 0.001) return [dx / l, dy / l, dz / l];
    }
    return null;
  }
}

/// The rotation/translation tracks of one animation, sampled by time.
class _Tracks {
  final Map<int, (Float32List, Float32List, String)> _rotation = {};
  final Map<int, (Float32List, Float32List, String)> _translation = {};

  _Tracks(GlbDocument doc, Map animation) {
    final samplers = (animation['samplers'] as List?) ?? const [];
    for (final c in (animation['channels'] as List?) ?? const []) {
      final target = (c as Map)['target'] as Map;
      final node = target['node'] as int?;
      final path = target['path'] as String?;
      if (node == null || (path != 'rotation' && path != 'translation')) continue;
      final sampler = samplers[c['sampler'] as int] as Map;
      final input = _readFloats(doc, sampler['input'] as int);
      final output = _readFloats(doc, sampler['output'] as int);
      final interpolation = (sampler['interpolation'] as String?) ?? 'LINEAR';
      (path == 'rotation' ? _rotation : _translation)[node] = (input, output, interpolation);
    }
  }

  Iterable<int> get animatedNodes => {..._rotation.keys, ..._translation.keys};

  bool hasTranslation(int node) => _translation.containsKey(node);

  List<double> keyTimes() {
    final set = <int>{};
    for (final track in [..._rotation.values, ..._translation.values]) {
      for (final t in track.$1) {
        set.add((t * 10000).round());
      }
    }
    final sorted = set.toList()..sort();
    return [for (final t in sorted) t / 10000.0];
  }

  List<double>? translationAtFirstKey(int node) {
    final track = _translation[node];
    if (track == null || track.$2.length < 3) return null;
    final o = track.$3 == 'CUBICSPLINE' ? 3 : 0;
    return [track.$2[o], track.$2[o + 1], track.$2[o + 2]];
  }

  _Quat? rotation(int node, double t) {
    final track = _rotation[node];
    if (track == null) return null;
    final (input, output, interp) = track;
    final (i, f) = _segment(input, t);
    _Quat at(int k) {
      final o = interp == 'CUBICSPLINE' ? (k * 3 + 1) * 4 : k * 4;
      return _Quat(output[o], output[o + 1], output[o + 2], output[o + 3]).normalized();
    }

    if (f == 0 || interp == 'STEP' || i + 1 >= input.length) return at(i);
    return _Quat.slerp(at(i), at(i + 1), f);
  }

  List<double>? translation(int node, double t) {
    final track = _translation[node];
    if (track == null) return null;
    final (input, output, interp) = track;
    final (i, f) = _segment(input, t);
    List<double> at(int k) {
      final o = interp == 'CUBICSPLINE' ? (k * 3 + 1) * 3 : k * 3;
      return [output[o], output[o + 1], output[o + 2]];
    }

    if (f == 0 || interp == 'STEP' || i + 1 >= input.length) return at(i);
    final a = at(i), b = at(i + 1);
    return [for (var k = 0; k < 3; k++) a[k] + (b[k] - a[k]) * f];
  }

  /// Key index at or before [t] and the fraction towards the next key.
  static (int, double) _segment(Float32List input, double t) {
    if (input.isEmpty || t <= input.first) return (0, 0);
    if (t >= input.last) return (input.length - 1, 0);
    var lo = 0, hi = input.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (input[mid] <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = input[hi] - input[lo];
    return (lo, span <= 0 ? 0 : (t - input[lo]) / span);
  }

  /// Float view of an accessor: FLOAT, or normalized BYTE/UBYTE/SHORT/USHORT.
  static Float32List _readFloats(GlbDocument doc, int index) {
    final acc = (doc.json['accessors'] as List)[index] as Map;
    final count = acc['count'] as int;
    final components = const {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[acc['type']] ?? 1;
    final out = Float32List(count * components);
    final bvIndex = acc['bufferView'] as int?;
    if (bvIndex == null) return out;
    final bv = (doc.json['bufferViews'] as List)[bvIndex] as Map;
    final componentType = acc['componentType'] as int;
    final size = const {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5126: 4}[componentType];
    if (size == null) throw FormatException('unsupported animation accessor componentType $componentType');
    final stride = (bv['byteStride'] as int?) ?? size * components;
    final start = ((bv['byteOffset'] as int?) ?? 0) + ((acc['byteOffset'] as int?) ?? 0);
    final data = ByteData.sublistView(doc.bin);
    for (var i = 0; i < count; i++) {
      for (var c = 0; c < components; c++) {
        final at = start + i * stride + c * size;
        out[i * components + c] = switch (componentType) {
          5126 => data.getFloat32(at, Endian.little),
          5120 => math.max(data.getInt8(at) / 127.0, -1.0),
          5121 => data.getUint8(at) / 255.0,
          5122 => math.max(data.getInt16(at, Endian.little) / 32767.0, -1.0),
          _ => data.getUint16(at, Endian.little) / 65535.0,
        };
      }
    }
    return out;
  }
}
