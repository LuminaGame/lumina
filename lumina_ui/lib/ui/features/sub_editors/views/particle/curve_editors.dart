import 'dart:ui' as ui;

import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector4;

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// `colorOverLife` gradient bar.
///
/// The strip is painted by sampling [sample] — the runtime's own
/// `LuminaParticleEmitterConfig.sampleColorAt` — so what the editor shows is
/// exactly what the simulation will produce. Click empty space to add a stop,
/// drag a handle to move it (`t` clamped to `[0, 1]`, list re-sorted by the
/// view model), click a handle to select it, right-click to delete.
class ParticleGradientEditor extends StatefulWidget {
  final List<LuminaGradientStop> stops;
  final int? selectedIndex;
  final Vector4 Function(double t) sample;
  final void Function(double t) onAdd;
  final void Function(int index, double t) onMove;
  final void Function(int index) onSelect;
  final void Function(int index) onRemove;

  const ParticleGradientEditor({
    super.key,
    required this.stops,
    required this.selectedIndex,
    required this.sample,
    required this.onAdd,
    required this.onMove,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  State<ParticleGradientEditor> createState() => _ParticleGradientEditorState();
}

class _ParticleGradientEditorState extends State<ParticleGradientEditor> {
  int? _dragIndex;

  static const double _barHeight = 34.0;
  static const double _hitRadius = 9.0;

  int? _hitTest(double dx, double width) {
    if (width <= 0) return null;
    for (var i = 0; i < widget.stops.length; i++) {
      final x = widget.stops[i].t * width;
      if ((x - dx).abs() <= _hitRadius) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) {
          final hit = _hitTest(d.localPosition.dx, width);
          if (hit != null) {
            widget.onSelect(hit);
          } else {
            widget.onAdd((d.localPosition.dx / width).clamp(0.0, 1.0));
          }
        },
        onSecondaryTapDown: (d) {
          final hit = _hitTest(d.localPosition.dx, width);
          if (hit != null) widget.onRemove(hit);
        },
        onHorizontalDragStart: (d) => _dragIndex = _hitTest(d.localPosition.dx, width),
        onHorizontalDragUpdate: (d) {
          final i = _dragIndex;
          if (i == null || i >= widget.stops.length) return;
          widget.onMove(i, (d.localPosition.dx / width).clamp(0.0, 1.0));
        },
        onHorizontalDragEnd: (_) => _dragIndex = null,
        child: SizedBox(
          height: _barHeight + 18,
          width: double.infinity,
          child: CustomPaint(
            painter: _GradientPainter(
              stops: widget.stops,
              sample: widget.sample,
              selectedIndex: widget.selectedIndex,
              barHeight: _barHeight,
            ),
          ),
        ),
      );
    });
  }
}

class _GradientPainter extends CustomPainter {
  final List<LuminaGradientStop> stops;
  final Vector4 Function(double t) sample;
  final int? selectedIndex;
  final double barHeight;

  _GradientPainter({
    required this.stops,
    required this.sample,
    required this.selectedIndex,
    required this.barHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Checkerboard so alpha reads honestly.
    final light = Paint()..color = EditorColors.scrollbar;
    final dark = Paint()..color = EditorColors.borderSolid;
    const cell = 8.0;
    for (var y = 0.0; y < barHeight; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final even = ((x / cell).floor() + (y / cell).floor()) % 2 == 0;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), even ? light : dark);
      }
    }
    // One vertical slice per pixel column sampled through the runtime.
    final paint = Paint();
    for (var x = 0.0; x < size.width; x += 1.0) {
      final t = size.width <= 1 ? 0.0 : x / (size.width - 1);
      final c = sample(t);
      paint.color = ui.Color.fromARGB(
        (c.w.clamp(0.0, 1.0) * 255).round(),
        (c.x.clamp(0.0, 1.0) * 255).round(),
        (c.y.clamp(0.0, 1.0) * 255).round(),
        (c.z.clamp(0.0, 1.0) * 255).round(),
      );
      canvas.drawRect(Rect.fromLTWH(x, 0, 1.0, barHeight), paint);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, barHeight),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = EditorColors.border,
    );

    for (var i = 0; i < stops.length; i++) {
      final s = stops[i];
      final x = s.t * size.width;
      final selected = i == selectedIndex;
      final handle = Path()
        ..moveTo(x, barHeight - 4)
        ..lineTo(x - 6, barHeight + 10)
        ..lineTo(x + 6, barHeight + 10)
        ..close();
      canvas.drawPath(
        handle,
        Paint()
          ..color = ui.Color.fromARGB(
            255,
            (s.rgba.x.clamp(0.0, 1.0) * 255).round(),
            (s.rgba.y.clamp(0.0, 1.0) * 255).round(),
            (s.rgba.z.clamp(0.0, 1.0) * 255).round(),
          ),
      );
      canvas.drawPath(
        handle,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2 : 1
          ..color = selected ? EditorColors.primary : EditorColors.border,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GradientPainter old) => true;
}

/// `sizeOverLife` curve canvas: points `(t, scale)` with linear segments,
/// drawn by sampling the runtime's `sampleSizeAt`.
class ParticleCurveEditor extends StatefulWidget {
  final List<LuminaCurvePoint> points;
  final int? selectedIndex;
  final double Function(double t) sample;
  final void Function(double t, double scale) onAdd;
  final void Function(int index, double t, double scale) onMove;
  final void Function(int index) onSelect;
  final void Function(int index) onRemove;

  /// Vertical range of the canvas (scale axis).
  final double maxScale;

  const ParticleCurveEditor({
    super.key,
    required this.points,
    required this.selectedIndex,
    required this.sample,
    required this.onAdd,
    required this.onMove,
    required this.onSelect,
    required this.onRemove,
    this.maxScale = 2.0,
  });

  @override
  State<ParticleCurveEditor> createState() => _ParticleCurveEditorState();
}

class _ParticleCurveEditorState extends State<ParticleCurveEditor> {
  int? _dragIndex;
  static const double _height = 110.0;
  static const double _hitRadius = 10.0;

  ({double t, double scale}) _toValue(Offset local, Size size) {
    final t = (local.dx / size.width).clamp(0.0, 1.0);
    final scale = ((1.0 - local.dy / size.height) * widget.maxScale).clamp(0.0, widget.maxScale);
    return (t: t, scale: scale);
  }

  int? _hitTest(Offset local, Size size) {
    for (var i = 0; i < widget.points.length; i++) {
      final p = widget.points[i];
      final x = p.t * size.width;
      final y = (1.0 - (p.scale / widget.maxScale).clamp(0.0, 1.0)) * size.height;
      if ((Offset(x, y) - local).distance <= _hitRadius) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, _height);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) {
          final hit = _hitTest(d.localPosition, size);
          if (hit != null) {
            widget.onSelect(hit);
          } else {
            final v = _toValue(d.localPosition, size);
            widget.onAdd(v.t, v.scale);
          }
        },
        onSecondaryTapDown: (d) {
          final hit = _hitTest(d.localPosition, size);
          if (hit != null) widget.onRemove(hit);
        },
        onPanStart: (d) => _dragIndex = _hitTest(d.localPosition, size),
        onPanUpdate: (d) {
          final i = _dragIndex;
          if (i == null || i >= widget.points.length) return;
          final v = _toValue(d.localPosition, size);
          widget.onMove(i, v.t, v.scale);
        },
        onPanEnd: (_) => _dragIndex = null,
        child: SizedBox(
          height: _height,
          width: double.infinity,
          child: CustomPaint(
            painter: _CurvePainter(
              points: widget.points,
              sample: widget.sample,
              selectedIndex: widget.selectedIndex,
              maxScale: widget.maxScale,
            ),
          ),
        ),
      );
    });
  }
}

class _CurvePainter extends CustomPainter {
  final List<LuminaCurvePoint> points;
  final double Function(double t) sample;
  final int? selectedIndex;
  final double maxScale;

  _CurvePainter({
    required this.points,
    required this.sample,
    required this.selectedIndex,
    required this.maxScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = EditorColors.background,
    );
    final grid = Paint()
      ..color = EditorColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final path = Path();
    for (var px = 0.0; px <= size.width; px += 1.0) {
      final t = size.width <= 1 ? 0.0 : px / (size.width - 1);
      final v = sample(t);
      final y = (1.0 - (v / maxScale).clamp(0.0, 1.0)) * size.height;
      if (px == 0.0) {
        path.moveTo(px, y);
      } else {
        path.lineTo(px, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = EditorColors.primary,
    );

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = p.t * size.width;
      final y = (1.0 - (p.scale / maxScale).clamp(0.0, 1.0)) * size.height;
      final selected = i == selectedIndex;
      canvas.drawCircle(
        Offset(x, y),
        selected ? 5.0 : 3.5,
        Paint()..color = selected ? EditorColors.primary : EditorColors.foreground,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) => true;
}
