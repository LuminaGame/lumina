import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The time ruler: frame ticks with frame numbers, and seconds labels at
/// each whole second, spaced for the zoom; the loop range is shaded.
class TimelineRulerPainter extends CustomPainter {
  TimelineRulerPainter({
    required this.zoom,
    required this.scroll,
    required this.fps,
    required this.length,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final double zoom;
  final double scroll;
  final int fps;
  final int length;
  final int rangeStart;
  final int rangeEnd;

  static const List<int> _multiples = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 1200, 3000];

  /// The labelled tick step in frames: at least 56 px apart.
  int get labelStep {
    for (final m in _multiples) {
      if (m * zoom >= 56) return m;
    }
    return _multiples.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = EditorColors.cardHeader);
    double x(num f) => (f - scroll) * zoom;
    // The loop range and the end of the timeline.
    final r0 = x(rangeStart).clamp(0.0, size.width);
    final r1 = x(rangeEnd).clamp(0.0, size.width);
    if (r1 > r0) canvas.drawRect(Rect.fromLTRB(r0, size.height - 3, r1, size.height), Paint()..color = EditorColors.primary.withValues(alpha: 0.55));
    final endX = x(length);
    // The out-of-range band: a black scrim over the track colours.
    if (endX < size.width) canvas.drawRect(Rect.fromLTRB(math.max(0, endX), 0, size.width, size.height), Paint()..color = const Color(0x55000000));
    final tick = Paint()
      ..color = EditorColors.mutedForeground.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    final step = labelStep;
    final minor = step >= 5 ? step ~/ 5 : 1;
    final first = (scroll / minor).floor() * minor;
    final last = math.min(length.toDouble(), scroll + size.width / zoom).ceil();
    for (var f = first; f <= last; f += minor) {
      if (f < 0) continue;
      final px = x(f);
      final major = f % step == 0;
      canvas.drawLine(Offset(px, size.height - (major ? 10 : 5)), Offset(px, size.height), tick);
      if (!major) continue;
      final second = fps > 0 && f % fps == 0;
      final label = second ? '$f · ${f ~/ fps}s' : '$f';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 9, color: second ? EditorColors.foreground : EditorColors.mutedForeground),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(px + 3, 2));
    }
    canvas.drawLine(Offset(0, size.height - 0.5), Offset(size.width, size.height - 0.5), Paint()..color = EditorColors.border);
  }

  @override
  bool shouldRepaint(TimelineRulerPainter old) =>
      old.zoom != zoom ||
      old.scroll != scroll ||
      old.fps != fps ||
      old.length != length ||
      old.rangeStart != rangeStart ||
      old.rangeEnd != rangeEnd;
}
