import 'package:lumina_core/lumina_core.dart';

import 'package:lumina/src/components/mesh/pose_authoring/pose_rig.dart';

/// Finds a humanoid's pose rig bones by name: MetaHuman and UEFN mannequin
/// names (`upperarm_l`, `spine_01`…`spine_05`, `neck_01`, `head`,
/// `pelvis`), Mixamo names (`mixamorig:LeftArm`, `Spine1`, `Hips`) and the
/// like.
abstract final class LuminaPoseRigDetector {
  /// The rig definition of [skeleton]; parts it lacks (no legs, no neck)
  /// are left out.
  static LuminaPoseRigDefinition detect(GlbSkeleton skeleton, {LuminaPoseRigLimits limits = const LuminaPoseRigLimits()}) {
    final limbs = <String, LuminaPoseLimbDefinition>{};
    String name(int n) => skeleton.names[n] ?? '';
    for (final chain in TwoBoneIkChain.detect(skeleton)) {
      final key = switch (chain.name) {
        'LeftArm' => 'arm_l',
        'RightArm' => 'arm_r',
        'LeftLeg' => 'leg_l',
        _ => 'leg_r',
      };
      limbs[key] = _limb(skeleton, chain.upper, chain.lower, chain.end);
    }
    // Bones that carry no skin weights (a MetaHuman's upper arms and
    // thighs) are still bones: find the limbs by name when the joint-only
    // detection missed them.
    for (final (key, endNames) in const [
      ('arm_l', ['hand_l', 'Hand_L', 'LeftHand']),
      ('arm_r', ['hand_r', 'Hand_R', 'RightHand']),
      ('leg_l', ['foot_l', 'Foot_L', 'LeftFoot']),
      ('leg_r', ['foot_r', 'Foot_R', 'RightFoot']),
    ]) {
      if (limbs.containsKey(key)) continue;
      for (var i = 0; i < skeleton.count; i++) {
        if (!endNames.contains(_bare(name(i)))) continue;
        final lower = skeleton.parent[i];
        final upper = lower < 0 ? -1 : skeleton.parent[lower];
        if (upper >= 0) limbs[key] = _limb(skeleton, upper, lower, i);
        break;
      }
    }

    var head = -1;
    for (var i = 0; i < skeleton.count; i++) {
      if (_bare(name(i)).toLowerCase() == 'head') {
        head = i;
        if (skeleton.isJoint(i)) break;
      }
    }
    final neck = <int>[];
    final spine = <int>[];
    int? pelvis;
    if (head >= 0) {
      var n = skeleton.parent[head];
      while (n >= 0 && _bare(name(n)).toLowerCase().contains('neck')) {
        neck.insert(0, n);
        n = skeleton.parent[n];
      }
      while (n >= 0 && _isSpine(_bare(name(n)).toLowerCase())) {
        spine.insert(0, n);
        n = skeleton.parent[n];
      }
      if (n >= 0 && spine.isNotEmpty) pelvis = n;
      neck.add(head);
    }
    if (pelvis == null) {
      for (var i = 0; i < skeleton.count; i++) {
        final b = _bare(name(i)).toLowerCase();
        if (b == 'pelvis' || b == 'hips') {
          pelvis = i;
          break;
        }
      }
    }
    return LuminaPoseRigDefinition(
      limbs: limbs,
      spine: [for (final n in spine) name(n)],
      neck: [for (final n in neck) name(n)],
      neckWeights: neckWeightsFor(neck.length),
      pelvis: pelvis == null ? null : name(pelvis),
      limits: limits,
    );
  }

  /// The default share of the head's turn per neck chain bone: 0.25 / 0.35
  /// / 0.4 for two neck bones and the head.
  static List<double> neckWeightsFor(int count) => switch (count) {
        0 => const [],
        1 => const [1.0],
        2 => const [0.4, 0.6],
        3 => const [0.25, 0.35, 0.4],
        _ => [for (var i = 0; i < count - 1; i++) 0.6 / (count - 1), 0.4],
      };

  static bool _isSpine(String bare) => bare.contains('spine') || bare.contains('chest');

  /// [name] without a namespace (`mixamorig:Head` → `Head`).
  static String _bare(String name) {
    final i = name.lastIndexOf(':');
    return i < 0 ? name : name.substring(i + 1);
  }

  static LuminaPoseLimbDefinition _limb(GlbSkeleton s, int upper, int lower, int end) {
    List<String> twists(int parent) => [
          for (var i = 0; i < s.count; i++)
            if (s.parent[i] == parent && _bare(s.names[i] ?? '').toLowerCase().contains('twist')) s.names[i]!,
        ];
    return LuminaPoseLimbDefinition(s.names[upper]!, s.names[lower]!, s.names[end]!,
        upperTwist: twists(upper), lowerTwist: twists(lower));
  }
}
