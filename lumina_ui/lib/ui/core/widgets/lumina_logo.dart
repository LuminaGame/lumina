import 'package:flutter/widgets.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Lumina's brand constants: the three blues of the mark and the facets of
/// the Prism L on its 100 × 100 grid. `assets/brand/prism_l.svg` carries the
/// same polygons; the icon renderer (`tool/brand/render_icons.dart`) and
/// [LuminaMark] read this list so the mark is drawn once, everywhere.
abstract final class LuminaBrand {
  static const Color blueDeep = Color(0xFF31A5DA);
  static const Color blueMid = Color(0xFF5DB8E1);
  static const Color blueLight = Color(0xFF81C8E8);

  /// The facets in paint order (the under-shard last, at 55 %).
  static const List<PrismFacet> facets = [
    PrismFacet('stem', [Offset(26, 12), Offset(46, 19), Offset(46, 74), Offset(26, 67)], blueDeep),
    PrismFacet('top-facet', [Offset(26, 12), Offset(46, 19), Offset(54, 8), Offset(34, 1)], blueLight),
    PrismFacet('foot', [Offset(46, 74), Offset(88, 60), Offset(88, 46), Offset(46, 60)], blueMid),
    PrismFacet('foot-facet', [Offset(46, 60), Offset(88, 46), Offset(80, 38), Offset(46, 50)], blueLight),
    PrismFacet('under-shard', [Offset(26, 67), Offset(46, 74), Offset(46, 88), Offset(26, 81)], blueDeep, opacity: 0.55),
  ];

  /// The mono mark: one colour, no under-shard.
  static List<PrismFacet> monoFacets(Color color) =>
      [for (final f in facets.where((f) => f.name != 'under-shard')) PrismFacet(f.name, f.points, color)];
}

/// One polygon of the mark on the 100 × 100 grid.
class PrismFacet {
  const PrismFacet(this.name, this.points, this.color, {this.opacity = 1});
  final String name;
  final List<Offset> points;
  final Color color;
  final double opacity;
}

/// The Prism L at [size] px: the three blues, or one colour with `mono: true`.
class LuminaMark extends StatelessWidget {
  const LuminaMark({super.key, this.size = 30, this.mono = false, this.color});

  final double size;
  final bool mono;

  /// The mono fill; the foreground colour when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final facets = mono ? LuminaBrand.monoFacets(color ?? EditorColors.foreground) : LuminaBrand.facets;
    return Semantics(
      label: 'Lumina',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: PrismLPainter(facets)),
      ),
    );
  }
}

/// Paints [facets] scaled from the 100 × 100 grid into the box.
class PrismLPainter extends CustomPainter {
  const PrismLPainter(this.facets);
  final List<PrismFacet> facets;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    final dx = (size.width - 100 * s) / 2, dy = (size.height - 100 * s) / 2;
    for (final f in facets) {
      final path = Path()..moveTo(dx + f.points.first.dx * s, dy + f.points.first.dy * s);
      for (final p in f.points.skip(1)) {
        path.lineTo(dx + p.dx * s, dy + p.dy * s);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = f.color.withValues(alpha: f.opacity)..isAntiAlias = true);
    }
  }

  @override
  bool shouldRepaint(PrismLPainter old) => !identical(old.facets, facets);
}

/// The lockup: the mark beside `LUMINA` over `Studio`; `compact` puts the mark
/// and `LUMINA` on one line (the status bar, small headers).
class LuminaLockup extends StatelessWidget {
  const LuminaLockup({super.key, this.markSize = 30, this.compact = false, this.foreground, this.muted});

  final double markSize;
  final bool compact;
  final Color? foreground;
  final Color? muted;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? EditorColors.foreground;
    final word = Text(
      'LUMINA',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 12 * 0.12, color: fg, height: 1),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LuminaMark(size: markSize),
        const SizedBox(width: 8),
        if (compact)
          word
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              word,
              const SizedBox(height: 2),
              Text(
                'Studio',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: muted ?? EditorColors.mutedForeground, height: 1),
              ),
            ],
          ),
      ],
    );
  }
}
