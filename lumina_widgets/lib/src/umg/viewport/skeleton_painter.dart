import 'package:flutter/widgets.dart';
import 'package:lumina/lumina_runtime.dart' show LuminaSkeletonOverlay, LuminaViewportJoint;
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// Draws skeletons over a viewport on a Flutter canvas: the bones and joints
/// of a skeleton (the selected branch highlighted, a visibility filter) and
/// ghost skeletons (thin or volumetric limbs, a labelled badge). The bone
/// structure is [LuminaSkeletonOverlay]'s, the one the UMG Viewport draws
/// as Filament lines; the editor's sub-editor viewports paint it with this.
abstract final class LuminaSkeletonPainter {
  /// Bones and joints of [joints], projected by [project] (null: behind the
  /// camera).
  static void paintBones(
    Canvas canvas,
    List<LuminaViewportJoint> joints,
    Offset? Function(Vector3 position) project, {
    Set<String>? visible,
    String? selected,
    Color bone = const Color(0xD9B026FF),
    Color selectedBone = const Color(0xFFFFD54F),
    Color joint = const Color(0xFF00E5FF),
    Color selectedJoint = const Color(0xFFFFC107),
  }) {
    if (joints.isEmpty) return;
    final points = [for (final j in joints) project(j.position)];
    final bonePaint = Paint()
      ..color = bone
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final selectedPaint = Paint()
      ..color = selectedBone
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    for (final b in LuminaSkeletonOverlay.bones(joints, visible: visible, selected: selected)) {
      final a = points[b.from];
      final c = points[b.to];
      if (a != null && c != null) canvas.drawLine(a, c, b.selected ? selectedPaint : bonePaint);
    }
    final lower = visible?.map((n) => n.toLowerCase()).toSet();
    for (var i = 0; i < joints.length; i++) {
      final p = points[i];
      if (p == null || (lower != null && !lower.contains(joints[i].name.toLowerCase()))) continue;
      final isSelected = joints[i].name == selected;
      canvas.drawCircle(p, isSelected ? 5.0 : 3.0, Paint()..color = isSelected ? selectedJoint : joint);
      if (isSelected) {
        canvas.drawCircle(
          p,
          8.0,
          Paint()
            ..color = selectedBone.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  /// A ghost skeleton: [joints] limited to [posed] (the joints the ghost's
  /// pose names; null: all), thin lines or volumetric limbs with a head
  /// sphere, and [label] in a badge above its top joint.
  static void paintGhost(
    Canvas canvas,
    List<LuminaViewportJoint> joints,
    Offset? Function(Vector3 position) project, {
    required Color color,
    double opacity = 0.6,
    bool volumetric = false,
    Set<String>? posed,
    String? label,
  }) {
    if (joints.isEmpty) return;
    final points = [
      for (var i = 0; i < joints.length; i++) posed == null || posed.contains(joints[i].name) ? project(joints[i].position) : null,
    ];
    final c = color.withValues(alpha: opacity);
    final thin = Paint()
      ..color = c
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    for (final b in LuminaSkeletonOverlay.bones(joints, visible: posed)) {
      final a = points[b.from];
      final e = points[b.to];
      if (a == null || e == null) continue;
      if (volumetric) {
        final width = LuminaSkeletonOverlay.volumetricWidth(joints[b.to].name, joints[b.from].name);
        canvas.drawLine(
          a,
          e,
          Paint()
            ..color = color.withValues(alpha: (opacity * 0.45).clamp(0.0, 1.0))
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
        canvas.drawLine(
          a,
          e,
          Paint()
            ..color = color.withValues(alpha: (opacity * 0.85).clamp(0.0, 1.0))
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      } else {
        canvas.drawLine(a, e, thin);
      }
    }
    Offset? top;
    for (var i = 0; i < joints.length; i++) {
      final p = points[i];
      if (p == null) continue;
      if (volumetric && joints[i].name.toLowerCase().contains('head')) {
        canvas.drawCircle(p, 14.0, Paint()..color = color.withValues(alpha: (opacity * 0.5).clamp(0.0, 1.0)));
        canvas.drawCircle(
          p,
          14.0,
          Paint()
            ..color = c
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      } else {
        canvas.drawCircle(p, volumetric ? 4.0 : 2.5, Paint()..color = c);
      }
      if (top == null || p.dy < top.dy) top = p;
    }
    if (label != null && label.isNotEmpty && top != null) paintBadge(canvas, top, label, color);
  }

  /// A small labelled badge centred above [at].
  static void paintBadge(Canvas canvas, Offset at, String label, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(at.dx - tp.width / 2 - 8, at.dy - 24, tp.width + 16, tp.height + 6), const Radius.circular(5));
    canvas.drawRRect(rect, Paint()..color = const Color(0xDD111115));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );
    tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - 21));
  }
}
