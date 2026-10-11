import 'dart:math' as math;

import 'package:lumina_editor_api/lumina_editor_api.dart' show PluginCanvasItem, PluginCanvasItemKind;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/widgets/canvas/canvas_item_painter.dart';

/// Whether pixel [p] hits [entry] drawn through [view].
bool canvasHit(CanvasEntry entry, CanvasView view, Offset p) {
  final item = entry.item;
  Offset pt(List<num> q) => view.toPixel(q[0].toDouble(), q[1].toDouble());
  Rect? box() {
    final r = item.rect;
    return r == null ? null : Rect.fromPoints(pt([r[0], r[1]]), pt([r[0] + r[2], r[1] + r[3]]));
  }

  switch (item.kind) {
    case PluginCanvasItemKind.line || PluginCanvasItemKind.polyline:
      final points = [for (final q in item.points ?? const <List<num>>[]) pt(q)];
      final tolerance = math.max(4.0, (item.width ?? 1) / 2 + 3);
      for (var i = 0; i + 1 < points.length; i++) {
        if (_segmentDistance(p, points[i], points[i + 1]) <= tolerance) return true;
      }
      return false;
    case PluginCanvasItemKind.circle:
      final c = item.center;
      if (c == null) return false;
      return (p - pt(c)).distance <= (item.radius ?? 4).toDouble() * view.radiusScale + 2;
    case PluginCanvasItemKind.path:
      final path = entry.path;
      return path != null && path.contains(view.toItem(p));
    case PluginCanvasItemKind.text:
      final r = box();
      if (r != null) return r.inflate(2).contains(p);
      final at = item.points?.isNotEmpty == true ? pt(item.points!.first) : Offset.zero;
      return Rect.fromLTWH(at.dx, at.dy, 120, (item.fontSize ?? 11).toDouble() * 1.4).contains(p);
    default:
      final r = box();
      return r != null && r.inflate(2).contains(p);
  }
}

double _segmentDistance(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// The point a drag reports for [item] (item space): a circle's centre, a
/// box's top-left corner, the first point of a line.
Offset canvasAnchor(PluginCanvasItem item) {
  if (item.center != null) return Offset(item.center![0].toDouble(), item.center![1].toDouble());
  if (item.rect != null) return Offset(item.rect![0].toDouble(), item.rect![1].toDouble());
  final p = item.points;
  if (p != null && p.isNotEmpty) return Offset(p.first[0].toDouble(), p.first[1].toDouble());
  return Offset.zero;
}

num _round(double v) => double.parse(v.toStringAsFixed(4));

/// [json] (an item) moved by [d] in item space. A path moves through an
/// `offset` the painter does not know, so paths are not draggable.
Map<String, Object?> canvasMoved(Map<String, Object?> json, Offset d) {
  List<num> shift(List<Object?> p) => [_round((p[0]! as num) + d.dx), _round((p[1]! as num) + d.dy)];
  final out = Map<String, Object?>.of(json);
  if (json['center'] is List) out['center'] = shift(json['center']! as List);
  if (json['rect'] is List) {
    final r = json['rect']! as List;
    out['rect'] = [...shift(r), r[2], r[3]];
  }
  if (json['points'] is List) out['points'] = [for (final p in json['points']! as List) shift(p as List)];
  return out;
}

MouseCursor canvasCursor(String? name) => switch (name) {
      'pointer' => SystemMouseCursors.click,
      'move' => SystemMouseCursors.move,
      'grab' => SystemMouseCursors.grab,
      'crosshair' => SystemMouseCursors.precise,
      'text' => SystemMouseCursors.text,
      _ => MouseCursor.defer,
    };
