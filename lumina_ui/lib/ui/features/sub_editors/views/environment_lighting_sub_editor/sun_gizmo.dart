part of '../environment_lighting_sub_editor.dart';

/// Compass-style sun gizmo drawn over the viewport: the ring is the horizon
/// (N up, E right), the centre is the zenith. Dragging the disc sets azimuth
/// (angle) and elevation (distance from the centre) directly; the time slider
/// follows through the view model.
class SunGizmo extends StatelessWidget {
  final double elevationDeg;
  final double azimuthDeg;
  final Vector3 sunColor;
  final void Function(double azimuthDeg, double elevationDeg) onDrag;
  final VoidCallback onDragEnd;
  final double size;

  const SunGizmo({
    super.key,
    required this.elevationDeg,
    required this.azimuthDeg,
    required this.sunColor,
    required this.onDrag,
    required this.onDragEnd,
    this.size = 132.0,
  });

  double get _ringRadius => size / 2 - 10;

  /// Azimuth/elevation for a pointer position inside the gizmo.
  ({double azimuth, double elevation}) anglesAt(Offset local) {
    final c = Offset(size / 2, size / 2);
    final v = local - c;
    var az = math.atan2(v.dx, -v.dy) * 180.0 / math.pi;
    if (az < 0) az += 360.0;
    final r = (v.distance / _ringRadius).clamp(0.0, 1.0);
    return (azimuth: az, elevation: (1.0 - r) * 90.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) {
        final a = anglesAt(d.localPosition);
        onDrag(a.azimuth, a.elevation);
      },
      onPanEnd: (_) => onDragEnd(),
      onPanCancel: onDragEnd,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _SunGizmoPainter(
            elevationDeg: elevationDeg,
            azimuthDeg: azimuthDeg,
            ringRadius: _ringRadius,
            sunColor: _toColor(sunColor),
          ),
        ),
      ),
    );
  }
}

class _SunGizmoPainter extends CustomPainter {
  final double elevationDeg;
  final double azimuthDeg;
  final double ringRadius;
  final Color sunColor;

  _SunGizmoPainter({
    required this.elevationDeg,
    required this.azimuthDeg,
    required this.ringRadius,
    required this.sunColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, size.width / 2, Paint()..color = Colors.black.withValues(alpha: 0.55));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = EditorColors.border;
    canvas.drawCircle(c, ringRadius, ring);
    canvas.drawCircle(c, ringRadius * 0.5, ring..color = EditorColors.border.withValues(alpha: 0.6));
    canvas.drawLine(Offset(c.dx - ringRadius, c.dy), Offset(c.dx + ringRadius, c.dy), ring);
    canvas.drawLine(Offset(c.dx, c.dy - ringRadius), Offset(c.dx, c.dy + ringRadius), ring);

    // Day arc: sunrise (E) → zenith → sunset (W).
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.amber.withValues(alpha: 0.35);
    final path = Path();
    for (var h = 6.0; h <= 18.0; h += 0.5) {
      final a = SolarMath.anglesForTime(h);
      final p = _pos(c, a.elevation, a.azimuth);
      if (h == 6.0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, arc);

    for (final (label, angle) in [('N', 0.0), ('E', 90.0), ('S', 180.0), ('W', 270.0)]) {
      final rad = angle * math.pi / 180.0;
      final p = c + Offset(math.sin(rad), -math.cos(rad)) * (ringRadius + 6);
      final tp = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(fontSize: 7, color: EditorColors.mutedForeground)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    final below = elevationDeg < 0;
    final sunPos = _pos(c, elevationDeg, azimuthDeg);
    canvas.drawLine(c, sunPos, Paint()..color = sunColor.withValues(alpha: below ? 0.25 : 0.6)..strokeWidth = 1.0);
    canvas.drawCircle(sunPos, below ? 4.0 : 6.5, Paint()..color = sunColor.withValues(alpha: below ? 0.35 : 1.0));
    canvas.drawCircle(sunPos, below ? 4.0 : 6.5, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = Colors.white.withValues(alpha: 0.7));
  }

  Offset _pos(Offset c, double el, double az) {
    final r = (1.0 - el.clamp(0.0, 90.0) / 90.0) * ringRadius;
    final rad = az * math.pi / 180.0;
    return c + Offset(math.sin(rad) * r, -math.cos(rad) * r);
  }

  @override
  bool shouldRepaint(covariant _SunGizmoPainter old) =>
      old.elevationDeg != elevationDeg || old.azimuthDeg != azimuthDeg || old.sunColor != sunColor;
}
