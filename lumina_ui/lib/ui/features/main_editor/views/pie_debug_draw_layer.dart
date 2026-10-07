// design-token-exempt: debug shapes and Print String lines draw in the colours the Blueprint nodes asked for, over the 3D render.
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import 'package:lumina_ui/ui/features/main_editor/services/pie_debug_projection.dart';

/// Projects a runtime point to the viewport, or null when off camera.
typedef PieDebugProject = Offset? Function(Vector3 runtime);

/// The level viewport's Play overlay for `LuminaWorld.debugShapes` and
/// `LuminaWorld.screenMessages`:
/// lines, spheres, boxes, points, arrows, capsules and strings the running
/// Blueprints drew, projected through the game camera, and the Print String
/// lines top-left in their colours. Repaints
/// every frame while [world] plays; the world drops expired records itself.
class PieDebugDrawLayer extends StatefulWidget {
  final LuminaWorld? Function() world;

  /// The projection for the current frame (the game camera's, or the editor
  /// camera's once ejected); null draws only the screen messages.
  final PieDebugProjector? Function() projection;

  const PieDebugDrawLayer({super.key, required this.world, required this.projection});

  @override
  State<PieDebugDrawLayer> createState() => PieDebugDrawLayerState();
}

class PieDebugDrawLayerState extends State<PieDebugDrawLayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final world = widget.world();
      if (world != null && (world.debugShapes.isNotEmpty || world.screenMessages.isNotEmpty || _drewSomething)) setState(() {});
    })
      ..start();
  }

  bool _drewSomething = false;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final world = widget.world();
    final shapes = world?.debugShapes ?? const <LuminaDebugShape>[];
    final messages = world?.screenMessages.values.toList() ?? const <LuminaScreenMessage>[];
    _drewSomething = shapes.isNotEmpty || messages.isNotEmpty;
    final projection = widget.projection();
    return IgnorePointer(
      child: Stack(
        children: [
          if (projection != null && shapes.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                key: const ValueKey('pie_debug_shapes'),
                painter: PieDebugShapePainter(shapes: List.of(shapes), projection: projection),
              ),
            ),
          if (messages.isNotEmpty)
            Positioned(
              key: const ValueKey('pie_screen_messages'),
              left: 12,
              top: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final m in messages)
                    Padding(
                      key: ValueKey('pie_screen_message_${m.key}'),
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        m.text,
                        style: TextStyle(
                          color: PieDebugShapePainter.colorOf(m.color),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          shadows: const [Shadow(color: Color(0xFF000000), blurRadius: 2)],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Draws [shapes] through [projection]: a polyline per shape, circles for
/// spheres and points, a wire box, an arrow head, a capsule outline and a
/// label for strings.
class PieDebugShapePainter extends CustomPainter {
  final List<LuminaDebugShape> shapes;
  final PieDebugProjector projection;

  PieDebugShapePainter({required this.shapes, required this.projection});

  static Color colorOf(List<double> c) => Color.fromARGB(
        ((c.length > 3 ? c[3] : 1.0) * 255).round().clamp(0, 255),
        ((c.isNotEmpty ? c[0] : 1.0) * 255).round().clamp(0, 255),
        ((c.length > 1 ? c[1] : 1.0) * 255).round().clamp(0, 255),
        ((c.length > 2 ? c[2] : 1.0) * 255).round().clamp(0, 255),
      );

  /// How many shapes were drawn on the last paint (for tests).
  int drawn = 0;

  void _line(Canvas canvas, Vector3 a, Vector3 b, Paint paint) {
    final p = projection.project(a);
    final q = projection.project(b);
    if (p == null || q == null) return;
    canvas.drawLine(p, q, paint);
  }

  void _circle(Canvas canvas, Vector3 center, double radius, Paint paint, {Vector3? axisA, Vector3? axisB}) {
    final a = axisA ?? Vector3(1, 0, 0);
    final b = axisB ?? Vector3(0, 0, 1);
    Offset? last;
    for (var i = 0; i <= 24; i++) {
      final t = i / 24 * math.pi * 2;
      final p = projection.project(center + a * (radius * math.cos(t)) + b * (radius * math.sin(t)));
      if (p != null && last != null) canvas.drawLine(last, p, paint);
      last = p;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    drawn = 0;
    for (final s in shapes) {
      if (s.points.isEmpty) continue;
      final paint = Paint()
        ..color = colorOf(s.color)
        ..strokeWidth = math.max(1.0, s.thickness)
        ..style = PaintingStyle.stroke;
      drawn++;
      switch (s.kind) {
        case LuminaDebugShapeKind.line:
          if (s.points.length >= 2) _line(canvas, s.points[0], s.points[1], paint);
        case LuminaDebugShapeKind.arrow:
          if (s.points.length >= 2) {
            _line(canvas, s.points[0], s.points[1], paint);
            final p = projection.project(s.points[0]);
            final q = projection.project(s.points[1]);
            if (p != null && q != null && (q - p).distance > 1) {
              final dir = (q - p) / (q - p).distance;
              final head = math.max(4.0, s.radius * projection.scaleAt(s.points[1]));
              final left = Offset(-dir.dy, dir.dx);
              canvas.drawLine(q, q - dir * head + left * (head * 0.5), paint);
              canvas.drawLine(q, q - dir * head - left * (head * 0.5), paint);
            }
          }
        case LuminaDebugShapeKind.sphere:
          _circle(canvas, s.points[0], s.radius, paint, axisA: Vector3(1, 0, 0), axisB: Vector3(0, 0, 1));
          _circle(canvas, s.points[0], s.radius, paint, axisA: Vector3(1, 0, 0), axisB: Vector3(0, 1, 0));
          _circle(canvas, s.points[0], s.radius, paint, axisA: Vector3(0, 1, 0), axisB: Vector3(0, 0, 1));
        case LuminaDebugShapeKind.point:
          final p = projection.project(s.points[0]);
          if (p != null) canvas.drawCircle(p, math.max(2.0, s.radius), Paint()..color = colorOf(s.color));
        case LuminaDebugShapeKind.box:
          final e = s.extent ?? Vector3(50, 50, 50);
          final r = s.rotation ?? Quaternion.identity();
          final corners = [
            for (final sx in [-1.0, 1.0])
              for (final sy in [-1.0, 1.0])
                for (final sz in [-1.0, 1.0]) s.points[0] + r.rotated(Vector3(e.x * sx, e.y * sy, e.z * sz)),
          ];
          for (var i = 0; i < 8; i++) {
            for (var j = i + 1; j < 8; j++) {
              // Corners differing in exactly one axis share an edge.
              final diff = (i ^ j);
              if (diff == 1 || diff == 2 || diff == 4) _line(canvas, corners[i], corners[j], paint);
            }
          }
        case LuminaDebugShapeKind.capsule:
          final half = s.extent?.y ?? s.radius;
          final r = s.rotation ?? Quaternion.identity();
          final axis = r.rotated(Vector3(0, 1, 0));
          final side = r.rotated(Vector3(1, 0, 0));
          final other = r.rotated(Vector3(0, 0, 1));
          final top = s.points[0] + axis * (half - s.radius);
          final bottom = s.points[0] - axis * (half - s.radius);
          _circle(canvas, top, s.radius, paint, axisA: side, axisB: other);
          _circle(canvas, bottom, s.radius, paint, axisA: side, axisB: other);
          for (final d in [side, -side, other, -other]) {
            _line(canvas, top + d * s.radius, bottom + d * s.radius, paint);
          }
        case LuminaDebugShapeKind.string:
          final p = projection.project(s.points[0]);
          if (p != null && s.text != null) {
            final tp = TextPainter(
              text: TextSpan(
                text: s.text,
                style: TextStyle(color: colorOf(s.color), fontSize: 12, fontWeight: FontWeight.w600, shadows: const [Shadow(color: Color(0xFF000000), blurRadius: 2)]),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
          }
      }
    }
  }

  @override
  bool shouldRepaint(covariant PieDebugShapePainter oldDelegate) => true;
}
