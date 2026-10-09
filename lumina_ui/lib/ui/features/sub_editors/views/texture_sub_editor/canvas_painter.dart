part of '../texture_sub_editor.dart';

class _TextureCanvasPainter extends CustomPainter {
  final ui.Image? image;
  final double zoom;
  final ui.Offset pan;
  final int mipWidth;
  final int mipHeight;

  _TextureCanvasPainter({
    required this.image,
    required this.zoom,
    required this.pan,
    required this.mipWidth,
    required this.mipHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Checkerboard background for alpha transparency
    final checkPaint1 = Paint()..color = EditorColors.popover;
    final checkPaint2 = Paint()..color = EditorColors.secondary;
    const checkSize = 16.0;

    for (double y = 0; y < size.height; y += checkSize) {
      for (double x = 0; x < size.width; x += checkSize) {
        final isEven = ((x / checkSize).floor() + (y / checkSize).floor()) % 2 == 0;
        canvas.drawRect(Rect.fromLTWH(x, y, checkSize, checkSize), isEven ? checkPaint1 : checkPaint2);
      }
    }

    if (image == null || mipWidth == 0 || mipHeight == 0) return;

    final center = Offset(size.width / 2, size.height / 2) + pan;
    final drawW = mipWidth * zoom;
    final drawH = mipHeight * zoom;
    final destRect = Rect.fromCenter(center: center, width: drawW, height: drawH);

    // 2. Draw Decoded Image (Nearest-neighbor FilterQuality.none for pixel-crisp display at zoom >= 1.0)
    final imagePaint = Paint()
      ..filterQuality = zoom >= 1.0 ? FilterQuality.none : FilterQuality.low
      ..isAntiAlias = zoom < 1.0;

    canvas.drawImageRect(
      image!,
      Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble()),
      destRect,
      imagePaint,
    );

    // 3. Draw Pixel Grid Overlay when zoomed in >= 800%
    if (zoom >= 8.0) {
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..strokeWidth = 0.5;

      final stepX = drawW / mipWidth;
      final stepY = drawH / mipHeight;

      for (int x = 0; x <= mipWidth; x++) {
        final gx = destRect.left + x * stepX;
        canvas.drawLine(Offset(gx, destRect.top), Offset(gx, destRect.bottom), gridPaint);
      }
      for (int y = 0; y <= mipHeight; y++) {
        final gy = destRect.top + y * stepY;
        canvas.drawLine(Offset(destRect.left, gy), Offset(destRect.right, gy), gridPaint);
      }
    }

    // Border around texture
    final borderPaint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(destRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _TextureCanvasPainter oldDelegate) => true;
}
