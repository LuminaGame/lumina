import 'package:vector_math/vector_math_64.dart';

/// One joint of a skeleton overlay: its name, its parent's index (-1 for a
/// root) and its position (whatever frame the caller draws in).
class LuminaViewportJoint {
  const LuminaViewportJoint(this.name, this.parent, this.position);
  final String name;
  final int parent;
  final Vector3 position;
}

/// One bone of a skeleton overlay, between two joint indices.
class LuminaSkeletonBone {
  const LuminaSkeletonBone(this.from, this.to, {this.selected = false});
  final int from;
  final int to;

  /// The bone belongs to the selected joint (or descends from it through a
  /// hidden joint).
  final bool selected;
}

/// The skeleton overlay's geometry, written once for every view that draws
/// bones: the UMG Viewport (Filament lines in its 3D view) and the editor's
/// sub-editor viewports (a Flutter painter).
abstract final class LuminaSkeletonOverlay {
  /// The bones to draw: each visible joint to its nearest visible ancestor.
  /// [visible] (matched case-insensitively) leaves the other joints out;
  /// a bone is [LuminaSkeletonBone.selected] when its child joint is
  /// [selected] or its parent bone was.
  static List<LuminaSkeletonBone> bones(List<LuminaViewportJoint> joints, {Set<String>? visible, String? selected}) {
    final lower = visible?.map((n) => n.toLowerCase()).toSet();
    bool shown(int i) => lower == null || lower.contains(joints[i].name.toLowerCase());
    final anchor = List<int>.filled(joints.length, -1);
    final selectedBranch = List<bool>.filled(joints.length, false);
    final out = <LuminaSkeletonBone>[];
    final order = _parentsFirst(joints);
    for (final i in order) {
      final p = joints[i].parent;
      final parentAnchor = p < 0 ? -1 : (shown(p) ? p : anchor[p]);
      final parentSelected = p >= 0 && selectedBranch[p];
      if (shown(i)) {
        final isSelected = joints[i].name == selected;
        if (parentAnchor >= 0) out.add(LuminaSkeletonBone(parentAnchor, i, selected: isSelected || parentSelected));
        anchor[i] = i;
        selectedBranch[i] = isSelected;
      } else {
        anchor[i] = parentAnchor;
        selectedBranch[i] = parentSelected;
      }
    }
    return out;
  }

  /// Joint indices, every parent before its children.
  static List<int> _parentsFirst(List<LuminaViewportJoint> joints) {
    final children = <int, List<int>>{};
    final roots = <int>[];
    for (var i = 0; i < joints.length; i++) {
      final p = joints[i].parent;
      if (p < 0 || p >= joints.length) {
        roots.add(i);
      } else {
        (children[p] ??= []).add(i);
      }
    }
    final out = <int>[];
    final stack = [...roots.reversed];
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      out.add(i);
      stack.addAll((children[i] ?? const <int>[]).reversed);
    }
    return out;
  }

  /// The width of a volumetric ghost limb from joint [name] (child) to
  /// [parentName], in pixels: thick for the torso, thinner down the limbs.
  static double volumetricWidth(String name, String? parentName) {
    final n = name.toLowerCase();
    final pn = parentName?.toLowerCase() ?? '';
    if (n.contains('spine') || n.contains('hips') || n.contains('pelvis')) return 22.0;
    if (n.contains('thigh') || n.contains('upleg') || pn.contains('pelvis') || pn.contains('hips')) return 16.0;
    if (n.contains('calf') || n.contains('leg')) return 12.0;
    if (n.contains('upperarm') || (n.contains('arm') && !n.contains('forearm'))) return 13.0;
    if (n.contains('lowerarm') || n.contains('forearm')) return 9.0;
    if (n.contains('neck') || n.contains('head')) return 14.0;
    return 8.0;
  }
}
