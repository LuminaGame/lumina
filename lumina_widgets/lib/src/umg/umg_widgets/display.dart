part of 'package:lumina_widgets/src/umg/umg_widgets.dart';

// Display-only UMG widgets: progress bar, skeleton, border.

/// A horizontal progress bar; [progress] is clamped to 0..1 (UMG Progress
/// Bar `Percent`).
class LuminaUmgProgressBar extends StatelessWidget {
  const LuminaUmgProgressBar({super.key, required this.progress, this.color, this.trackColor});

  /// Key of the filled part, for tests and tools that measure it.
  static const Key fillKey = ValueKey<String>('lumina_umg_progress_fill');

  final double progress;
  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
      final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 8.0;
      return ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          width: width,
          height: height,
          color: trackColor ?? LuminaUmgColors.raised,
          alignment: Alignment.centerLeft,
          child: Container(key: fillKey, width: width * progress.clamp(0.0, 1.0), color: color ?? LuminaUmgColors.foreground),
        ),
      );
    });
  }
}

/// A loading placeholder (the shadcn Skeleton component): [lines] stretched
/// rows of [text], each drawn as a rounded bone over the text's own line
/// boxes, so the placeholder takes the space the text would. The bones pulse
/// between 5 % and 10 % of [color]'s alpha over [duration], back and forth
/// (shadcn passes its primary colour).
class LuminaUmgSkeleton extends StatefulWidget {
  const LuminaUmgSkeleton({
    super.key,
    this.lines = 3,
    this.text = 'Loading placeholder text line',
    this.color = LuminaUmgColors.foreground,
    this.duration = const Duration(seconds: 1),
  });

  final int lines;
  final String text;
  final Color color;

  /// One pulse, from the faint to the strong colour.
  final Duration duration;

  @override
  State<LuminaUmgSkeleton> createState() => _LuminaUmgSkeletonState();
}

class _LuminaUmgSkeletonState extends State<LuminaUmgSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);

  @override
  void didUpdateWidget(LuminaUmgSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _pulse
        ..duration = widget.duration
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaults = DefaultTextStyle.of(context);
    final scaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final from = widget.color.withValues(alpha: widget.color.a * 0.05);
    final to = widget.color.withValues(alpha: widget.color.a * 0.1);
    // A box shorter than the lines (a tight designer slot) clips them rather
    // than overflowing.
    return ClipRect(
      child: OverflowBox(
        fit: OverflowBoxFit.deferToChild,
        alignment: AlignmentDirectional.topStart,
        minHeight: 0,
        maxHeight: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < widget.lines; i++)
              CustomPaint(
                painter: _SkeletonBonePainter(
                  text: widget.text,
                  style: defaults.style,
                  align: defaults.textAlign ?? TextAlign.start,
                  scaler: scaler,
                  direction: direction,
                  color: ColorTween(begin: from, end: to).animate(_pulse),
                ),
                // Lays the row out exactly as the text, unpainted.
                child: Text(widget.text, style: const TextStyle(color: Color(0x00000000))),
              ),
          ],
        ),
      ),
    );
  }
}

/// Paints one rounded bone per laid-out line of a paragraph: the line's
/// glyph box (ascent to baseline plus a fifth of the font size), full width
/// for all but the last line of a wrapped paragraph, corner radius half its
/// height.
class _SkeletonBonePainter extends CustomPainter {
  _SkeletonBonePainter({
    required this.text,
    required this.style,
    required this.align,
    required this.scaler,
    required this.direction,
    required this.color,
  }) : super(repaint: color);

  final String text;
  final TextStyle style;
  final TextAlign align;
  final TextScaler scaler;
  final TextDirection direction;
  final Animation<Color?> color;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: size.width);
    final lines = painter.computeLineMetrics();
    final paint = Paint()..color = color.value ?? const Color(0x00000000);
    for (final line in lines) {
      final fontSize = line.ascent - line.descent;
      final descent = line.ascent >= line.height ? 0.0 : fontSize * .2;
      final start = line.left.round();
      final end = (line.left + line.width).round();
      final justify = (start == 0 || end == painter.width) && lines.length > 1 && line.lineNumber < lines.length - 1;
      final rect = Rect.fromLTWH(
        justify ? 0 : line.left,
        line.baseline - fontSize,
        justify ? painter.width : line.width,
        fontSize + descent,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.height * .5)), paint);
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(_SkeletonBonePainter old) =>
      old.text != text || old.style != style || old.align != align || old.scaler != scaler || old.direction != direction || old.color != color;
}

/// A filled, rounded panel around one child (UMG Border).
class LuminaUmgBorder extends StatelessWidget {
  const LuminaUmgBorder({super.key, this.color, this.padding = EdgeInsets.zero, this.radius = 6, this.child});

  final Color? color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: color ?? LuminaUmgColors.surface, borderRadius: BorderRadius.circular(radius)),
      child: child,
    );
  }
}
