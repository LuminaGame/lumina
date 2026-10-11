import 'package:lumina_plugin_protocol/src/editor_widget_json.dart';

/// The shapes a canvas draws.
abstract final class PluginCanvasItemKind {
  static const String line = 'line';
  static const String polyline = 'polyline';
  static const String rect = 'rect';
  static const String circle = 'circle';

  /// SVG path data (`M 0 0 L 10 10 Z`): M, L, H, V, C, Q, Z (absolute and relative).
  static const String path = 'path';
  static const String text = 'text';

  /// An image: a project asset path or a file the plugin wrote.
  static const String image = 'image';

  static const List<String> all = [line, polyline, rect, circle, path, text, image];
}

/// The coordinate space of a canvas: `local` pixels or `normalized` 0–1 of
/// the canvas size.
abstract final class PluginCanvasSpace {
  static const String local = 'local';
  static const String normalized = 'normalized';
  static const List<String> all = [local, normalized];
}

/// One item of a canvas draw list. Geometry by kind: [points] (`line`,
/// `polyline`: `[[x, y], ...]`), [rect] (`rect`, `image`, `text`'s box:
/// `[x, y, w, h]`), [center] + [radius] (`circle`), [path] (`path`), [text]
/// at [rect]'s or [points]' first corner (`text`), [image].
class PluginCanvasItem {
  const PluginCanvasItem({
    required this.id,
    required this.kind,
    this.points,
    this.rect,
    this.center,
    this.radius,
    this.path,
    this.text,
    this.fontSize,
    this.image,
    this.stroke,
    this.fill,
    this.width,
    this.hit = false,
    this.draggable = false,
    this.cursor,
  });

  final String id;
  final String kind;
  final List<List<num>>? points;
  final List<num>? rect;
  final List<num>? center;
  final num? radius;
  final String? path;
  final String? text;
  final num? fontSize;
  final String? image;

  /// `#RRGGBB` / `#RRGGBBAA` colours.
  final String? stroke;
  final String? fill;

  /// Stroke width in pixels.
  final num? width;

  /// Whether clicks and hovers report this item.
  final bool hit;
  final bool draggable;

  /// `pointer`, `move`, `grab`, `crosshair` or `text`.
  final String? cursor;

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind,
        'points': ?points,
        'rect': ?rect,
        'center': ?center,
        'radius': ?radius,
        'path': ?path,
        'text': ?text,
        'fontSize': ?fontSize,
        'image': ?image,
        'stroke': ?stroke,
        'fill': ?fill,
        'width': ?width,
        'hit': hit,
        'draggable': draggable,
        'cursor': ?cursor,
      };

  /// Reads one item from its JSON (a decode error names [path]).
  static PluginCanvasItem fromJsonMap(Map<String, Object?> json, {String path = 'item'}) =>
      fromJson(EditorWidgetJsonReader(json, path));

  static PluginCanvasItem fromJson(EditorWidgetJsonReader r) {
    final rawPoints = r.list('points');
    List<List<num>>? points;
    if (r.json['points'] != null) {
      points = [
        for (var i = 0; i < rawPoints.length; i++)
          if (rawPoints[i] is List && (rawPoints[i] as List).length == 2 && (rawPoints[i] as List).every((e) => e is num))
            [for (final e in rawPoints[i] as List) e as num]
          else
            r.fail('points', 'must be a list of [x, y] pairs (item $i is not)'),
      ];
    }
    final rect = r.numbers('rect');
    if (rect != null && rect.length != 4) r.fail('rect', 'must be [x, y, w, h]');
    final center = r.numbers('center');
    if (center != null && center.length != 2) r.fail('center', 'must be [x, y]');
    return PluginCanvasItem(
      id: r.string('id'),
      kind: r.json['kind'] == null ? r.fail('kind', 'is required') : r.oneOf('kind', PluginCanvasItemKind.all, ''),
      points: points,
      rect: rect,
      center: center,
      radius: r.optNum('radius'),
      path: r.optString('path'),
      text: r.optString('text'),
      fontSize: r.optNum('fontSize'),
      image: r.optString('image'),
      stroke: r.optString('stroke'),
      fill: r.optString('fill'),
      width: r.optNum('width'),
      hit: r.flag('hit', false),
      draggable: r.flag('draggable', false),
      cursor: r.optString('cursor'),
    );
  }
}

/// A canvas's state: [space], a [background] colour, the draw list
/// ([items], diffed by id) and an optional view box (`viewBox: {x, y,
/// width, height, pan, zoom}`, in the item space) the user may pan and zoom.
class PluginCanvasState {
  const PluginCanvasState({
    this.space = PluginCanvasSpace.local,
    this.background,
    this.items = const [],
    this.viewBox,
    this.panZoom = false,
  });

  final String space;
  final String? background;
  final List<PluginCanvasItem> items;

  /// `[x, y, width, height]` of the item space shown.
  final List<num>? viewBox;

  /// Whether the user may pan (middle drag / wheel) and zoom (Ctrl + wheel).
  final bool panZoom;

  static const List<String> stateKeys = ['space', 'background', 'items', 'viewBox'];

  Map<String, Object?> toJson() => {
        'space': space,
        'background': ?background,
        'items': [for (final i in items) i.toJson()],
        if (viewBox != null)
          'viewBox': {'x': viewBox![0], 'y': viewBox![1], 'width': viewBox![2], 'height': viewBox![3], 'panZoom': panZoom},
      };

  static PluginCanvasState fromJson(Map<String, Object?> json, {String path = 'canvas'}) {
    final r = EditorWidgetJsonReader(json, path);
    final box = r.optObject('viewBox');
    final br = box == null ? null : EditorWidgetJsonReader(box, '$path.viewBox');
    return PluginCanvasState(
      space: r.oneOf('space', PluginCanvasSpace.all, PluginCanvasSpace.local),
      background: r.optString('background'),
      items: r.objects('items', PluginCanvasItem.fromJson),
      viewBox: br == null ? null : [br.number('x', 0), br.number('y', 0), br.number('width', 1), br.number('height', 1)],
      panZoom: br?.flag('panZoom', false) ?? false,
    );
  }
}
