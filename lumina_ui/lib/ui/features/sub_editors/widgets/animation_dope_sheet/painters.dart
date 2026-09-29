part of '../animation_dope_sheet_widget.dart';

class _DopeSheetRulerPainter extends CustomPainter {
  final double duration;
  final double fps;
  final double currentPosition;

  _DopeSheetRulerPainter({
    required this.duration,
    required this.fps,
    required this.currentPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = EditorColors.border
      ..strokeWidth = 1.0;

    final majorTickPaint = Paint()
      ..color = EditorColors.mutedForeground
      ..strokeWidth = 1.5;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final totalFrames = (duration * fps).round().clamp(1, 9999);
    final pxPerFrame = size.width / totalFrames;

    for (int f = 0; f <= totalFrames; f++) {
      final x = f * pxPerFrame;
      final isMajor = f % 5 == 0;

      if (isMajor) {
        canvas.drawLine(Offset(x, size.height - 12), Offset(x, size.height), majorTickPaint);

        textPainter.text = TextSpan(
          text: '$f',
          style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x + 2, 2));
      } else {
        canvas.drawLine(Offset(x, size.height - 6), Offset(x, size.height), tickPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DopeSheetRulerPainter oldDelegate) {
    return oldDelegate.duration != duration ||
        oldDelegate.fps != fps ||
        oldDelegate.currentPosition != currentPosition;
  }
}

class _DopeSheetGridPainter extends CustomPainter {
  final double duration;
  final double fps;

  _DopeSheetGridPainter({
    required this.duration,
    required this.fps,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = EditorColors.border.withOpacity(0.2)
      ..strokeWidth = 1.0;

    final majorLinePaint = Paint()
      ..color = EditorColors.border.withOpacity(0.45)
      ..strokeWidth = 1.0;

    final totalFrames = (duration * fps).round().clamp(1, 9999);
    final pxPerFrame = size.width / totalFrames;

    for (int f = 0; f <= totalFrames; f++) {
      final x = f * pxPerFrame;
      final isMajor = f % 5 == 0;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), isMajor ? majorLinePaint : linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DopeSheetGridPainter oldDelegate) {
    return oldDelegate.duration != duration || oldDelegate.fps != fps;
  }
}
