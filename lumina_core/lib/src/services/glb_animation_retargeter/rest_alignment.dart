part of '../glb_animation_retargeter.dart';

/// Target rest rotations (model space) turned so each mapped limb bone lies
/// like its clip bone at rest.
///
/// The trunk (pelvis, spine, neck, head: bones without a side) and the
/// clavicles keep the target's own rest: where two skeletons place those
/// joints is anatomy, not pose, and turning them to the clip's joints tilts
/// the chest and head. Limb bones (arms from the upper arm, legs from the
/// thigh, hands, fingers) are turned onto the clip's rest, which is what
/// carries an A-pose clip onto a T-pose skeleton and back.
///
/// A bone's lie is measured by its nearest mapped descendants (the mapped
/// joints below it with no mapped joint in between) and the clip joints they
/// map to: a hand by its fingers, an upper arm by its forearm. The best-fit
/// rotation from the target's directions to the clip's matching directions
/// turns the target rest; a mapped limb bone without mapped descendants (a
/// finger tip, a toe) takes the turn of its nearest mapped ancestor.
/// Corresponding joints keep a hand from aligning to a different child on
/// each side (metacarpals against fingers), and twist and
/// corrective joints between mapped joints do not bend the measurement.
List<_Quat> _restAlignedByMappedJoints(
  _Skeleton src,
  _Skeleton tgt,
  Map<int, int> mapped,
  List<_Quat> tgtRestWorld,
) {
  final children = List<List<int>>.generate(tgt.count, (_) => <int>[]);
  for (var i = 0; i < tgt.count; i++) {
    final p = tgt.parent[i];
    if (p >= 0) children[p].add(i);
  }
  bool isSourceDescendant(int node, int ancestor) {
    var p = src.parent[node];
    while (p >= 0) {
      if (p == ancestor) return true;
      p = src.parent[p];
    }
    return false;
  }

  final turn = <int, _Quat>{};
  for (final j in tgt.order) {
    final s = mapped[j];
    if (s == null) continue;
    if (_keepsTargetRest(tgt.names[j])) {
      turn[j] = _Quat.identity;
      continue;
    }
    final frontier = <int>[];
    final stack = [...children[j]];
    while (stack.isNotEmpty) {
      final n = stack.removeLast();
      if (mapped.containsKey(n)) {
        frontier.add(n);
      } else {
        stack.addAll(children[n]);
      }
    }
    final from = <List<double>>[];
    final to = <List<double>>[];
    final tgtAt = tgt.restWorldPos(j);
    final srcAt = src.restWorldPos(s);
    for (final d in frontier) {
      final sd = mapped[d]!;
      if (!isSourceDescendant(sd, s)) continue;
      final a = tgt.restWorldPos(d);
      final b = src.restWorldPos(sd);
      final vt = [for (var c = 0; c < 3; c++) a[c] - tgtAt[c]];
      final vs = [for (var c = 0; c < 3; c++) b[c] - srcAt[c]];
      if (GlbAnimationRetargeter._length(vt) < 1e-4 ||
          GlbAnimationRetargeter._length(vs) < 1e-4) {
        continue;
      }
      from.add(vt);
      to.add(vs);
    }
    if (from.isNotEmpty) {
      turn[j] = _Quat.bestFit(from, to);
      continue;
    }
    var p = tgt.parent[j];
    while (p >= 0 && !turn.containsKey(p)) {
      p = tgt.parent[p];
    }
    turn[j] = p >= 0 ? turn[p]! : _Quat.identity;
  }
  return List<_Quat>.generate(tgt.count, (j) {
    final q = turn[j];
    return q == null ? tgtRestWorld[j] : (q * tgtRestWorld[j]).normalized();
  });
}

final RegExp _sided = RegExp(
  r'(_l|_r|_left|_right)$|^(mixamorig:)?(left|right)',
  caseSensitive: false,
);

/// Trunk bones (no side) and clavicles keep the target rest.
bool _keepsTargetRest(String? name) {
  if (name == null) return true;
  final lower = name.toLowerCase();
  return !_sided.hasMatch(lower) ||
      lower.contains('clavicle') ||
      lower.contains('shoulder');
}

/// SOMA rest alignment: each mapped bone turned onto its clip bone's
/// direction (towards its longest child, or the named arm child).
List<_Quat> _somaRestAligned(
  _Skeleton src,
  _Skeleton tgt,
  Map<int, int> mapped,
  List<_Quat> tgtRestWorld,
) => List<_Quat>.generate(tgt.count, (j) {
  final s = mapped[j];
  if (s == null) return tgtRestWorld[j];
  String? targetChild;
  String? sourceChild;
  for (final side in ['l', 'r']) {
    final prefix = side == 'l' ? 'Left' : 'Right';
    if (tgt.names[j] == 'upperarm_$side') {
      targetChild = 'lowerarm_$side';
      sourceChild = '${prefix}ForeArm';
    } else if (tgt.names[j] == 'lowerarm_$side') {
      targetChild = 'hand_$side';
      sourceChild = '${prefix}Hand';
    }
  }
  final vTgt = tgt.boneDirection(j, childName: targetChild);
  final vSrc = src.boneDirection(s, childName: sourceChild);
  if (vTgt != null && vSrc != null) {
    final qAlign = _Quat.fromTo(vTgt, vSrc);
    return (qAlign * tgtRestWorld[j]).normalized();
  }
  return tgtRestWorld[j];
});
