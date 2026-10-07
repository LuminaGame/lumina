// design-token-exempt: blend space grid painter colours (samples, the preview point, nearest-sample and drop highlights) follow node-graph conventions, not the editor chrome palette.
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// What a clip row carries when dragged onto a Blend Space grid.
class BlendSpaceClipDrag {
  final String clip;
  const BlendSpaceClipDrag(this.clip);
}

/// Axis values ↔ grid pixels for a Blend Space of one or two axes.
class BlendSpaceGridGeometry {
  static const EdgeInsets padding = EdgeInsets.fromLTRB(46, 16, 16, 34);

  final LuminaBlendSpaceDocument document;
  final Size size;

  const BlendSpaceGridGeometry(this.document, this.size);

  bool get is2D => document.axes.length > 1;
  Rect get area => padding.deflateRect(Offset.zero & size);

  LuminaBlendSpaceAxis get xAxis => document.axes.isNotEmpty ? document.axes[0] : const LuminaBlendSpaceAxis('X', 0, 1);
  LuminaBlendSpaceAxis get yAxis => is2D ? document.axes[1] : const LuminaBlendSpaceAxis('', 0, 1);

  Offset toPixel(double x, double y) {
    final a = area;
    final spanX = (xAxis.max - xAxis.min) == 0 ? 1 : (xAxis.max - xAxis.min);
    final spanY = (yAxis.max - yAxis.min) == 0 ? 1 : (yAxis.max - yAxis.min);
    final px = a.left + (x - xAxis.min) / spanX * a.width;
    final py = is2D ? a.bottom - (y - yAxis.min) / spanY * a.height : a.center.dy;
    return Offset(px, py);
  }

  (double, double) toValue(Offset pixel) {
    final a = area;
    final fx = ((pixel.dx - a.left) / a.width).clamp(0.0, 1.0);
    final fy = ((a.bottom - pixel.dy) / a.height).clamp(0.0, 1.0);
    return (
      xAxis.min + fx * (xAxis.max - xAxis.min),
      is2D ? yAxis.min + fy * (yAxis.max - yAxis.min) : 0.0,
    );
  }
}

/// The Blend Space grid (the Blend Space editor canvas): axes with
/// their divisions, the samples (dragged clips) and the preview point. The
/// sample nearest the preview point is highlighted: lumina plays the nearest
/// sample with a crossfade, not a weighted blend.
class BlendSpaceGrid extends StatefulWidget {
  final LuminaBlendSpaceDocument document;
  final (double, double) point;
  final String? highlightClip;
  final bool readOnly;
  final int divisionsX;
  final int divisionsY;
  final int? selectedSample;
  final void Function(String clip, double x, double y)? onDropClip;
  final ValueChanged<int>? onSelectSample;
  final ValueChanged<int>? onSampleDragStart;
  final void Function(int index, double x, double y)? onSampleDrag;
  final VoidCallback? onSampleDragEnd;
  final void Function(double x, double y)? onPointChanged;

  const BlendSpaceGrid({
    super.key,
    required this.document,
    required this.point,
    this.highlightClip,
    this.readOnly = false,
    this.divisionsX = 4,
    this.divisionsY = 4,
    this.selectedSample,
    this.onDropClip,
    this.onSelectSample,
    this.onSampleDragStart,
    this.onSampleDrag,
    this.onSampleDragEnd,
    this.onPointChanged,
  });

  @override
  State<BlendSpaceGrid> createState() => BlendSpaceGridState();
}

class BlendSpaceGridState extends State<BlendSpaceGrid> {
  final GlobalKey _key = GlobalKey();
  Size _size = Size.zero;

  BlendSpaceGridGeometry get geometry => BlendSpaceGridGeometry(widget.document, _size);

  Offset _local(Offset global) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? global : box.globalToLocal(global);
  }

  /// Global position of axis values ([x], [y]) on screen, for tests and drags.
  Offset globalOf(double x, double y) {
    final box = _key.currentContext!.findRenderObject() as RenderBox;
    return box.localToGlobal(geometry.toPixel(x, y));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _size = constraints.biggest;
      final g = geometry;
      final samples = widget.document.samples;
      final nearest = widget.document.nearest(widget.point.$1, widget.point.$2);
      final p = g.toPixel(widget.point.$1, widget.point.$2);
      Widget content = Stack(
        key: _key,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: widget.readOnly
                  ? null
                  : (d) {
                      final v = g.toValue(d.localPosition);
                      widget.onPointChanged?.call(v.$1, v.$2);
                    },
              onPanUpdate: widget.readOnly
                  ? null
                  : (d) {
                      final v = g.toValue(_local(d.globalPosition));
                      widget.onPointChanged?.call(v.$1, v.$2);
                    },
              child: CustomPaint(
                painter: _GridPainter(g, widget.divisionsX, g.is2D ? widget.divisionsY : 0),
              ),
            ),
          ),
          for (var i = 0; i < samples.length; i++) _label(g, i, samples[i], nearest: identical(samples[i], nearest)),
          for (var i = 0; i < samples.length; i++) _sample(g, i, samples[i], nearest: identical(samples[i], nearest)),
          Positioned(
            key: const ValueKey('bs_preview_point'),
            left: p.dx - 7,
            top: p.dy - 7,
            child: IgnorePointer(
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 4,
            child: IgnorePointer(
              child: Text(
                'Preview (${widget.point.$1.toStringAsFixed(0)}${g.is2D ? ', ${widget.point.$2.toStringAsFixed(0)}' : ''})'
                '  →  ${nearest?.clip ?? 'no sample'}',
                key: const ValueKey('bs_preview_label'),
                style: const TextStyle(fontSize: 9.5, color: Color(0xFF00E676)),
              ),
            ),
          ),
        ],
      );
      if (!widget.readOnly) {
        final grid = content;
        content = DragTarget<BlendSpaceClipDrag>(
          onAcceptWithDetails: (d) {
            // pointerDragAnchorStrategy: the feedback's origin is the pointer.
            final v = g.toValue(_local(d.offset));
            widget.onDropClip?.call(d.data.clip, v.$1, v.$2);
          },
          builder: (context, candidate, rejected) => Container(
            decoration: BoxDecoration(
              border: Border.all(color: candidate.isEmpty ? const Color(0x00000000) : EditorColors.primary, width: 2),
            ),
            child: grid,
          ),
        );
      }
      return content;
    });
  }

  Widget _sample(BlendSpaceGridGeometry g, int i, LuminaBlendSpaceSample s, {required bool nearest}) {
    final p = g.toPixel(s.x, s.y);
    final selected = widget.selectedSample == i;
    final highlighted = nearest || (widget.highlightClip != null && widget.highlightClip == s.clip && nearest);
    return Positioned(
      key: ValueKey('bs_sample_$i'),
      left: p.dx - 8,
      top: p.dy - 8,
      child: GestureDetector(
        onTap: widget.readOnly ? null : () => widget.onSelectSample?.call(i),
        onPanStart: widget.readOnly ? null : (_) => widget.onSampleDragStart?.call(i),
        onPanUpdate: widget.readOnly
            ? null
            : (d) {
                final v = g.toValue(_local(d.globalPosition));
                widget.onSampleDrag?.call(i, v.$1, v.$2);
              },
        onPanEnd: widget.readOnly ? null : (_) => widget.onSampleDragEnd?.call(),
        child: SizedBox(
          width: 16,
          height: 16,
          child: Center(
            child: Transform.rotate(
              angle: 0.785398,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: highlighted ? const Color(0xFFFFB300) : const Color(0xFFE0E0E0),
                  border: Border.all(color: selected ? EditorColors.primary : const Color(0xFF212121), width: selected ? 2.5 : 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A sample's clip name: right of the diamond in 2D; in 1D alternately
  /// above and below the strip, angled, so neighbours do not overlap.
  Widget _label(BlendSpaceGridGeometry g, int i, LuminaBlendSpaceSample s, {required bool nearest}) {
    final p = g.toPixel(s.x, s.y);
    final text = Text(
      s.clip,
      style: TextStyle(
        fontSize: 8.5,
        color: nearest ? const Color(0xFFFFB300) : EditorColors.foreground,
        fontWeight: nearest ? FontWeight.bold : FontWeight.normal,
      ),
    );
    if (g.is2D) {
      return Positioned(left: p.dx + 10, top: p.dy - 6, child: IgnorePointer(child: text));
    }
    final above = i.isEven;
    return Positioned(
      left: p.dx - 4,
      top: above ? p.dy - 16 : p.dy + 8,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: above ? -0.6 : 0.6,
          alignment: Alignment.centerLeft,
          child: text,
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final BlendSpaceGridGeometry g;
  final int divisionsX;
  final int divisionsY;

  _GridPainter(this.g, this.divisionsX, this.divisionsY);

  void _text(Canvas canvas, String s, Offset at, {Color color = const Color(0xFF9AA0A6), bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: 9, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center ? at - Offset(tp.width / 2, 0) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1B1D21));
    final a = g.area;
    canvas.drawRect(a, Paint()..color = const Color(0xFF23262B));
    final line = Paint()
      ..color = const Color(0xFF3A3F46)
      ..strokeWidth = 1;
    final border = Paint()
      ..color = const Color(0xFF5A6068)
      ..style = PaintingStyle.stroke;
    for (var i = 0; i <= divisionsX; i++) {
      final x = a.left + a.width * i / divisionsX;
      canvas.drawLine(Offset(x, a.top), Offset(x, a.bottom), line);
      final v = g.xAxis.min + (g.xAxis.max - g.xAxis.min) * i / divisionsX;
      _text(canvas, v.toStringAsFixed(0), Offset(x, a.bottom + 4), center: true);
    }
    if (divisionsY > 0) {
      for (var i = 0; i <= divisionsY; i++) {
        final y = a.bottom - a.height * i / divisionsY;
        canvas.drawLine(Offset(a.left, y), Offset(a.right, y), line);
        final v = g.yAxis.min + (g.yAxis.max - g.yAxis.min) * i / divisionsY;
        _text(canvas, v.toStringAsFixed(0), Offset(4, y - 6));
      }
      _text(canvas, g.yAxis.name, Offset(4, a.top - 14), color: EditorColors.primary);
    } else {
      canvas.drawLine(Offset(a.left, a.center.dy), Offset(a.right, a.center.dy), line..color = const Color(0xFF6A7078));
    }
    canvas.drawRect(a, border);
    _text(canvas, g.xAxis.name, Offset(a.center.dx, a.bottom + 17), color: EditorColors.primary, center: true);
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => true;
}
