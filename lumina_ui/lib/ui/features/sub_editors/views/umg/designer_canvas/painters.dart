part of '../designer_canvas.dart';

class _Guide {
  final bool vertical;
  final double at;
  final double from;
  final double to;
  const _Guide({required this.vertical, required this.at, required this.from, required this.to});
}

class _GridPainter extends CustomPainter {
  final double gridSize;
  final bool enabled;
  final double screenScale;
  const _GridPainter({required this.gridSize, required this.enabled, required this.screenScale});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = EditorColors.card);
    if (!enabled) return;
    final minor = Paint()
      // the prototype's `white/8` idiom: translucent so it keeps its weight on any surface
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1 / screenScale;
    final major = Paint()
      // the prototype's `white/16` idiom: translucent so it keeps its weight on any surface
      ..color = const Color(0x28FFFFFF)
      ..strokeWidth = 1 / screenScale;
    final step = screenScale >= 0.9 ? gridSize : gridSize * 8;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), (x % (gridSize * 8) == 0) ? major : minor);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), (y % (gridSize * 8) == 0) ? major : minor);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.gridSize != gridSize || old.enabled != enabled || old.screenScale != screenScale;
}

class _OverlayPainter extends CustomPainter {
  final Map<String, Rect> rects;
  final UmgDocument document;
  final String? selectedId;
  final String? hoverId;
  final List<_Guide> guides;
  final double screenScale;

  const _OverlayPainter({
    required this.rects,
    required this.document,
    required this.selectedId,
    required this.hoverId,
    required this.guides,
    required this.screenScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final px = 1 / screenScale;
    // Faint outline of every panel so empty containers stay discoverable.
    final panelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = px
      // the prototype's `white/13` idiom: translucent so it keeps its weight on any surface
      ..color = const Color(0x22FFFFFF);
    document.root.visit((n, _) {
      final r = rects[n.id];
      if (r == null || n.id == document.root.id) return;
      if (n.type.isPanel) canvas.drawRect(r, panelPaint);
    });
    if (hoverId != null && hoverId != selectedId) {
      final r = rects[hoverId!];
      if (r != null) {
        canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = px
            ..color = EditorColors.primary.withValues(alpha: 0.5),
        );
      }
    }
    if (selectedId != null) {
      final r = rects[selectedId!];
      final node = document.findNode(selectedId!);
      if (r != null && node != null) {
        canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * px
            ..color = EditorColors.primary,
        );
        final label = TextPainter(
          text: TextSpan(
            text: ' ${node.name} · ${node.type.displayName} ',
            // this is the *game* UI being designed, not the editor: the canvas simulates the shipped screen, so it does not follow the editor palette
            style: TextStyle(fontSize: 10 * px, color: const Color(0xFF111111), fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelRect = Rect.fromLTWH(r.left, r.top - label.height - 2 * px, label.width, label.height);
        canvas.drawRect(labelRect, Paint()..color = EditorColors.primary);
        label.paint(canvas, labelRect.topLeft);
      }
    }
    final guidePaint = Paint()
      ..strokeWidth = px
      ..color = EditorColors.accent;
    for (final g in guides) {
      if (g.vertical) {
        canvas.drawLine(Offset(g.at, g.from), Offset(g.at, g.to), guidePaint);
      } else {
        canvas.drawLine(Offset(g.from, g.at), Offset(g.to, g.at), guidePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => true;
}
