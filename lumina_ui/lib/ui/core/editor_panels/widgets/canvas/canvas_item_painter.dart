import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:lumina_editor_api/lumina_editor_api.dart' show PluginCanvasItem, PluginCanvasItemKind;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/widgets/canvas/svg_path.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/interaction/editor_interaction.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// How a canvas maps its item space to pixels: `pixel = (item - origin) *
/// scale`, per axis.
@immutable
class CanvasView {
  const CanvasView(this.originX, this.originY, this.scaleX, this.scaleY);

  final double originX;
  final double originY;
  final double scaleX;
  final double scaleY;

  Offset toPixel(double x, double y) => Offset((x - originX) * scaleX, (y - originY) * scaleY);
  Offset toItem(Offset p) => Offset(p.dx / scaleX + originX, p.dy / scaleY + originY);
  double get radiusScale => math.min(scaleX, scaleY);

  @override
  bool operator ==(Object other) =>
      other is CanvasView && other.originX == originX && other.originY == originY && other.scaleX == scaleX && other.scaleY == scaleY;

  @override
  int get hashCode => Object.hash(originX, originY, scaleX, scaleY);
}

/// One item of the draw list with what it caches: its JSON (what a new
/// state is diffed against), its parsed SVG path and its decoded image. A
/// new state reuses the entry of every item whose JSON is unchanged, so
/// only changed items repaint.
class CanvasEntry {
  CanvasEntry(this.item, this.json)
      : path = item.kind == PluginCanvasItemKind.path && item.path != null ? parseSvgPath(item.path!) : null,
        image = null;

  CanvasEntry._(this.item, this.json, this.path, this.image);

  final PluginCanvasItem item;
  final Map<String, Object?> json;
  final Path? path;
  final ui.Image? image;

  /// This entry with its image decoded (a new entry: the item repaints).
  CanvasEntry withImage(ui.Image image) => CanvasEntry._(item, json, path, image);
}

/// Paints one canvas item on its own layer.
class CanvasItemPainter extends CustomPainter {
  CanvasItemPainter(this.entry, this.view, {this.hovered = false});

  final CanvasEntry entry;
  final CanvasView view;
  final bool hovered;

  /// Paints per item id (tests check that one item's change repaints only it).
  static final Map<String, int> paints = {};

  @override
  void paint(Canvas canvas, Size size) {
    final item = entry.item;
    paints[item.id] = (paints[item.id] ?? 0) + 1;
    final stroke = item.stroke == null
        ? null
        : (Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (item.width ?? 1).toDouble() + (hovered ? 1 : 0)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = editorWidgetColor(item.stroke, EditorColors.foreground));
    final fill = item.fill == null ? null : (Paint()..color = editorWidgetColor(item.fill, EditorColors.foreground));
    Offset pt(List<num> p) => view.toPixel(p[0].toDouble(), p[1].toDouble());
    Rect? box() {
      final r = item.rect;
      if (r == null) return null;
      return Rect.fromPoints(pt([r[0], r[1]]), pt([r[0] + r[2], r[1] + r[3]]));
    }

    switch (item.kind) {
      case PluginCanvasItemKind.line || PluginCanvasItemKind.polyline:
        final points = item.points ?? const [];
        if (points.length < 2) return;
        final p = Path()..moveTo(pt(points.first).dx, pt(points.first).dy);
        for (final q in points.skip(1)) {
          final o = pt(q);
          p.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(
            p,
            stroke ??
                (Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1
                  ..color = EditorColors.foreground));
      case PluginCanvasItemKind.rect:
        final r = box();
        if (r == null) return;
        if (fill != null) canvas.drawRect(r, fill);
        if (stroke != null) canvas.drawRect(r, stroke);
      case PluginCanvasItemKind.circle:
        final c = item.center;
        if (c == null) return;
        final r = (item.radius ?? 4).toDouble() * view.radiusScale;
        if (fill != null) canvas.drawCircle(pt(c), r, fill);
        if (stroke != null) canvas.drawCircle(pt(c), r, stroke);
        if (fill == null && stroke == null) canvas.drawCircle(pt(c), r, Paint()..color = EditorColors.foreground);
      case PluginCanvasItemKind.path:
        final path = entry.path;
        if (path == null) return;
        canvas.save();
        canvas.translate(-view.originX * view.scaleX, -view.originY * view.scaleY);
        canvas.scale(view.scaleX, view.scaleY);
        if (fill != null) canvas.drawPath(path, fill);
        canvas.restore();
        if (stroke != null) {
          // Strokes keep their pixel width.
          final scaled = path.transform(Float64List.fromList([
            view.scaleX, 0, 0, 0, //
            0, view.scaleY, 0, 0,
            0, 0, 1, 0,
            -view.originX * view.scaleX, -view.originY * view.scaleY, 0, 1,
          ]));
          canvas.drawPath(scaled, stroke);
        }
      case PluginCanvasItemKind.text:
        final at = item.rect != null ? pt([item.rect![0], item.rect![1]]) : (item.points?.isNotEmpty == true ? pt(item.points!.first) : Offset.zero);
        final r = box();
        final tp = TextPainter(
          text: TextSpan(
            text: item.text ?? '',
            style: TextStyle(fontSize: (item.fontSize ?? 11).toDouble(), color: editorWidgetColor(item.fill ?? item.stroke, EditorColors.foreground)),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: r == null ? double.infinity : math.max(0, r.width));
        tp.paint(canvas, at);
      case PluginCanvasItemKind.image:
        final r = box();
        final image = entry.image;
        if (r == null) return;
        if (image == null) {
          canvas.drawRect(r, Paint()..color = EditorColors.placeholderFill);
          return;
        }
        canvas.drawImageRect(image, Offset.zero & Size(image.width.toDouble(), image.height.toDouble()), r, Paint()..filterQuality = FilterQuality.medium);
        if (stroke != null) canvas.drawRect(r, stroke);
    }
  }

  @override
  bool shouldRepaint(CanvasItemPainter old) => !identical(old.entry, entry) || old.view != view || old.hovered != hovered;
}
