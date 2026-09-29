// design-token-exempt: node-graph painter colours (grid, node bodies, pin types, the debugger's executed-node amber) follow node-graph conventions, not the editor chrome palette.
part of '../graph_canvas.dart';

class _GraphPainter extends CustomPainter {
  final BlueprintGraphEditor editor;
  final Map<String, BlueprintNodeLayout> layouts;
  final Offset pan;
  final double zoom;
  final Offset? dragStart;
  final Offset? dragEnd;
  final LuminaPinType? dragType;
  final bool dragFromOutput;
  final bool dragRefused;
  final Offset? marqueeStart;
  final Offset? marqueeEnd;
  final bool dropHighlight;
  final BlueprintTraceRecorder? debug;

  _GraphPainter({
    this.debug,
    required this.editor,
    required this.layouts,
    required this.pan,
    required this.zoom,
    required this.dragStart,
    required this.dragEnd,
    required this.dragType,
    required this.dragFromOutput,
    required this.dragRefused,
    required this.marqueeStart,
    required this.marqueeEnd,
    required this.dropHighlight,
  });

  Offset _s(Offset c) => c * zoom + pan;

  void _wire(Canvas canvas, Offset a, Offset b, Paint paint) {
    final path = Path()..moveTo(a.dx, a.dy);
    final control = math.max((b.dx - a.dx).abs() * 0.5, 40.0 * zoom);
    path.cubicTo(a.dx + control, a.dy, b.dx - control, b.dy, b.dx, b.dy);
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = EditorColors.graphCanvas);
    final minor = Paint()
      ..color = const Color(0xFF212327)
      ..strokeWidth = 1.0;
    final major = Paint()
      ..color = const Color(0xFF2B2E33)
      ..strokeWidth = 1.0;
    final step = 16.0 * zoom;
    if (step > 4) {
      var i = ((-pan.dx) / step).floor();
      for (var x = pan.dx % step; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), (i++ % 8 == 0) ? major : minor);
      }
      i = ((-pan.dy) / step).floor();
      for (var y = pan.dy % step; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), (i++ % 8 == 0) ? major : minor);
      }
    }

    for (final w in editor.wires) {
      final from = layouts[w.fromNodeId];
      final to = layouts[w.toNodeId];
      if (from == null || to == null) continue;
      final a = from.pinCenter(w.fromPinId, output: true);
      final b = to.pinCenter(w.toPinId, output: false);
      final mismatch = editor.wireHasProblem(w);
      final type = editor.pin(w.fromNodeId, w.fromPinId, output: true)?.type;
      final paint = Paint()
        ..color = mismatch ? EditorColors.destructive : editor.wireColor(w)
        ..strokeWidth = (type == LuminaPinType.exec ? 2.6 : 2.0) * zoom
        ..style = PaintingStyle.stroke;
      final p = _s(a ?? Offset(from.rect.right, from.rect.top + 20));
      final q = _s(b ?? Offset(to.rect.left, to.rect.top + 20));
      _wire(canvas, p, q, paint);
      // Blueprint debugger: an exec wire just taken glows, and a pulse runs
      // along it over 0.5 s.
      final lit = debug?.intensity(w.id, wire: true) ?? 0;
      if (lit > 0) {
        _wire(
            canvas,
            p,
            q,
            Paint()
              ..color = const Color(0xFFFFB300).withValues(alpha: lit)
              ..strokeWidth = 4.5 * zoom
              ..style = PaintingStyle.stroke);
        final t = 1 - lit;
        final control = math.max((q.dx - p.dx).abs() * 0.5, 40.0 * zoom);
        final c1 = Offset(p.dx + control, p.dy);
        final c2 = Offset(q.dx - control, q.dy);
        final u = 1 - t;
        final pulse = p * (u * u * u) + c1 * (3 * u * u * t) + c2 * (3 * u * t * t) + q * (t * t * t);
        canvas.drawCircle(pulse, 4.5 * zoom, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: lit));
      }
    }

    if (dragStart != null && dragEnd != null) {
      final paint = Paint()
        ..color = dragRefused ? EditorColors.destructive : BlueprintPinStyle.color(dragType).withValues(alpha: 0.85)
        ..strokeWidth = 2.0 * zoom
        ..style = PaintingStyle.stroke;
      final a = _s(dragStart!);
      final b = _s(dragEnd!);
      if (dragFromOutput) {
        _wire(canvas, a, b, paint);
      } else {
        _wire(canvas, b, a, paint);
      }
    }

    if (marqueeStart != null && marqueeEnd != null) {
      final rect = Rect.fromPoints(_s(marqueeStart!), _s(marqueeEnd!));
      canvas.drawRect(rect, Paint()..color = EditorColors.primary.withValues(alpha: 0.12));
      canvas.drawRect(
          rect,
          Paint()
            ..color = EditorColors.primary
            ..style = PaintingStyle.stroke);
    }
    if (dropHighlight) {
      canvas.drawRect(
          (Offset.zero & size).deflate(2),
          Paint()
            ..color = EditorColors.primary
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => true;
}

/// The exec pin's arrow: a right-pointing pentagon drawn
/// as an outline while the pin is unwired and filled once it is wired.
class BlueprintExecPinPainter extends CustomPainter {
  final bool filled;
  final Color color;
  const BlueprintExecPinPainter({required this.filled, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(1, 1)
      ..lineTo(w * 0.55, 1)
      ..lineTo(w - 1, h / 2)
      ..lineTo(w * 0.55, h - 1)
      ..lineTo(1, h - 1)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.4
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant BlueprintExecPinPainter old) => old.filled != filled || old.color != color;
}
