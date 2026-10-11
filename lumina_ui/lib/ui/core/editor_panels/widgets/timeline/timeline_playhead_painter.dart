import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The playhead over the ruler and the tracks: its own layer, repainted by
/// [playhead] alone, so playback never repaints clips, keys or the ruler.
class TimelinePlayheadPainter extends CustomPainter {
  TimelinePlayheadPainter({required this.playhead, required this.zoom, required this.scroll, required this.rulerHeight})
      : super(repaint: playhead);

  final ValueListenable<double> playhead;
  final double zoom;
  final double scroll;
  final double rulerHeight;

  /// How often any playhead layer painted (tests).
  static int paints = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    final x = (playhead.value.floorToDouble() - scroll) * zoom;
    if (x < -6 || x > size.width + 6) return;
    final paint = Paint()
      ..color = EditorColors.primary
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(x, rulerHeight - 4), Offset(x, size.height), paint);
    final head = Path()
      ..moveTo(x - 5, 2)
      ..lineTo(x + 5, 2)
      ..lineTo(x + 5, rulerHeight - 9)
      ..lineTo(x, rulerHeight - 4)
      ..lineTo(x - 5, rulerHeight - 9)
      ..close();
    canvas.drawPath(head, Paint()..color = EditorColors.primary);
  }

  @override
  bool shouldRepaint(TimelinePlayheadPainter old) =>
      old.zoom != zoom || old.scroll != scroll || !identical(old.playhead, playhead) || old.rulerHeight != rulerHeight;
}
