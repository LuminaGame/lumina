import 'package:lumina_plugin_protocol/src/editor_widget_json.dart';

/// The phase of an editor widget interaction: a drag, scrub or resize is
/// applied locally at once and reported as throttled [preview]s (at most 30
/// a second), one [commit] on release and [cancel] on Escape (the value
/// snaps back). A one-shot action (a click, a cell edit) is a [commit].
abstract final class PluginViewEventPhase {
  static const String preview = 'preview';
  static const String commit = 'commit';
  static const String cancel = 'cancel';

  static const List<String> all = [preview, commit, cancel];
}

/// The `kind`s of the [PluginViewEvent]s the timeline, table and canvas
/// controls send; the `value` is a map with the same keys an editor panel
/// graph's event node outputs (`key_ids`, `delta_frames`, `clip_id`, ...).
abstract final class PluginEditorWidgetEventKind {
  // Timeline.
  static const String playheadChanged = 'playheadChanged';
  static const String playStateChanged = 'playStateChanged';
  static const String clipChanged = 'clipChanged';
  static const String clipTextCommitted = 'clipTextCommitted';
  static const String keysMoved = 'keysMoved';
  static const String keyAdded = 'keyAdded';
  static const String keysDeleted = 'keysDeleted';
  static const String selectionChanged = 'selectionChanged';
  static const String trackContextMenu = 'trackContextMenu';
  // Table.
  static const String cellCommitted = 'cellCommitted';
  static const String rowSelected = 'rowSelected';
  static const String rowDoubleClicked = 'rowDoubleClicked';
  static const String rowContextMenu = 'rowContextMenu';
  static const String sortChanged = 'sortChanged';
  // Canvas.
  static const String itemClicked = 'itemClicked';
  static const String itemDragged = 'itemDragged';
  static const String itemHover = 'itemHover';
  static const String backgroundClicked = 'backgroundClicked';
}

/// Which viewport a timeline drives: element (an editor panel's Viewport
/// element) and node (a node id of its preview scene). The playhead sets
/// that node's animation time locally while playing or scrubbing.
class PluginBoundViewport {
  const PluginBoundViewport({required this.element, required this.node});

  final String element;
  final String node;

  Map<String, Object?> toJson() => {'element': element, 'node': node};

  static PluginBoundViewport fromJson(Object? json, String path) {
    final r = EditorWidgetJsonReader.of(json, path);
    return PluginBoundViewport(element: r.string('element'), node: r.string('node'));
  }
}

// --- Timeline ------------------------------------------------------------------

/// What a timeline track holds: `clips`, `keys` or `both`.
abstract final class PluginTimelineTrackKind {
  static const String clips = 'clips';
  static const String keys = 'keys';
  static const String both = 'both';
  static const List<String> all = [clips, keys, both];
}

/// The glyph of a keyframe.
abstract final class PluginTimelineKeyStyle {
  static const String diamond = 'diamond';
  static const String circle = 'circle';
  static const String square = 'square';
  static const List<String> all = [diamond, circle, square];
}

class PluginTimelineTrack {
  const PluginTimelineTrack({
    required this.id,
    required this.label,
    this.icon,
    this.group,
    this.kind = PluginTimelineTrackKind.keys,
    this.color,
    this.locked = false,
    this.height,
  });

  final String id;
  final String label;

  /// A Lucide icon name (`text`, `footprints`, `hand`).
  final String? icon;

  /// Tracks with the same group sit under one group header.
  final String? group;
  final String kind;

  /// `#RRGGBB` or `#RRGGBBAA`.
  final String? color;
  final bool locked;
  final num? height;

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'icon': ?icon,
        'group': ?group,
        'kind': kind,
        'color': ?color,
        'locked': locked,
        'height': ?height,
      };

  static PluginTimelineTrack fromJson(EditorWidgetJsonReader r) => PluginTimelineTrack(
        id: r.string('id'),
        label: r.optString('label') ?? r.string('id'),
        icon: r.optString('icon'),
        group: r.optString('group'),
        kind: r.oneOf('kind', PluginTimelineTrackKind.all, PluginTimelineTrackKind.keys),
        color: r.optString('color'),
        locked: r.flag('locked', false),
        height: r.optNum('height'),
      );
}

/// A clip on a track: frames [start] to [end] (end exclusive), optional
/// text the user may edit, and its length limits in frames.
class PluginTimelineClip {
  const PluginTimelineClip({
    required this.id,
    required this.track,
    required this.start,
    required this.end,
    this.text,
    this.color,
    this.minLength,
    this.maxLength,
    this.editableText = false,
  });

  final String id;
  final String track;
  final int start;
  final int end;
  final String? text;
  final String? color;
  final int? minLength;
  final int? maxLength;
  final bool editableText;

  int get length => end - start;

  PluginTimelineClip copyWith({int? start, int? end, String? text}) => PluginTimelineClip(
        id: id,
        track: track,
        start: start ?? this.start,
        end: end ?? this.end,
        text: text ?? this.text,
        color: color,
        minLength: minLength,
        maxLength: maxLength,
        editableText: editableText,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'track': track,
        'start': start,
        'end': end,
        'text': ?text,
        'color': ?color,
        'minLength': ?minLength,
        'maxLength': ?maxLength,
        'editableText': editableText,
      };

  static PluginTimelineClip fromJson(EditorWidgetJsonReader r) => PluginTimelineClip(
        id: r.string('id'),
        track: r.string('track'),
        start: r.integer('start'),
        end: r.integer('end'),
        text: r.optString('text'),
        color: r.optString('color'),
        minLength: r.optInt('minLength'),
        maxLength: r.optInt('maxLength'),
        editableText: r.flag('editableText', false),
      );
}

class PluginTimelineKey {
  const PluginTimelineKey({
    required this.id,
    required this.track,
    required this.frame,
    this.style = PluginTimelineKeyStyle.diamond,
    this.color,
    this.selected = false,
  });

  final String id;
  final String track;
  final int frame;
  final String style;
  final String? color;
  final bool selected;

  PluginTimelineKey copyWith({int? frame, bool? selected}) => PluginTimelineKey(
        id: id,
        track: track,
        frame: frame ?? this.frame,
        style: style,
        color: color,
        selected: selected ?? this.selected,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'track': track,
        'frame': frame,
        'style': style,
        'color': ?color,
        'selected': selected,
      };

  static PluginTimelineKey fromJson(EditorWidgetJsonReader r) => PluginTimelineKey(
        id: r.string('id'),
        track: r.string('track'),
        frame: r.integer('frame'),
        style: r.oneOf('style', PluginTimelineKeyStyle.all, PluginTimelineKeyStyle.diamond),
        color: r.optString('color'),
        selected: r.flag('selected', false),
      );
}

/// A timeline's state: the `elements[<name>]` keys of an editor panel's
/// Timeline element and the props of a JSON spec `timeline` control.
/// Frames are integers; seconds derive from [fps]. [zoom] is pixels per
/// frame, [scroll] the first visible frame.
class PluginTimelineState {
  const PluginTimelineState({
    this.fps = 30,
    this.length = 300,
    this.playhead = 0,
    this.playing = false,
    this.loop = false,
    this.zoom = 4,
    this.scroll = 0,
    this.tracks = const [],
    this.clips = const [],
    this.keys = const [],
    this.rangeStart,
    this.rangeEnd,
    this.snap = 1,
    this.boundViewport,
  });

  final int fps;
  final int length;
  final int playhead;
  final bool playing;
  final bool loop;
  final num zoom;
  final num scroll;
  final List<PluginTimelineTrack> tracks;
  final List<PluginTimelineClip> clips;
  final List<PluginTimelineKey> keys;

  /// The loop range (`range: {start, end}`); the whole length when absent.
  final int? rangeStart;
  final int? rangeEnd;

  /// Clip and key moves snap to multiples of this many frames.
  final int snap;
  final PluginBoundViewport? boundViewport;

  /// The keys of [toJson] (the element state keys a timeline owns).
  static const List<String> stateKeys = [
    'fps', 'length', 'playhead', 'playing', 'loop', 'zoom', 'scroll', 'tracks', 'clips', 'keys', 'range', 'snap',
    'boundViewport',
  ];

  Map<String, Object?> toJson() => {
        'fps': fps,
        'length': length,
        'playhead': playhead,
        'playing': playing,
        'loop': loop,
        'zoom': zoom,
        'scroll': scroll,
        'tracks': [for (final t in tracks) t.toJson()],
        'clips': [for (final c in clips) c.toJson()],
        'keys': [for (final k in keys) k.toJson()],
        if (rangeStart != null && rangeEnd != null) 'range': {'start': rangeStart, 'end': rangeEnd},
        'snap': snap,
        if (boundViewport != null) 'boundViewport': boundViewport!.toJson(),
      };

  /// Reads a state (extra keys, like an element's `type` and `visibility`,
  /// are ignored); a malformed field is a [FormatException] naming it.
  static PluginTimelineState fromJson(Map<String, Object?> json, {String path = 'timeline'}) {
    final r = EditorWidgetJsonReader(json, path);
    final range = r.optObject('range');
    final rr = range == null ? null : EditorWidgetJsonReader(range, '$path.range');
    final bound = json['boundViewport'];
    final fps = r.integer('fps', fallback: 30);
    if (fps <= 0) r.fail('fps', 'must be above 0');
    return PluginTimelineState(
      fps: fps,
      length: r.integer('length', fallback: 300),
      playhead: r.integer('playhead', fallback: 0),
      playing: r.flag('playing', false),
      loop: r.flag('loop', false),
      zoom: r.number('zoom', 4),
      scroll: r.number('scroll', 0),
      tracks: r.objects('tracks', PluginTimelineTrack.fromJson),
      clips: r.objects('clips', PluginTimelineClip.fromJson),
      keys: r.objects('keys', PluginTimelineKey.fromJson),
      rangeStart: rr?.integer('start'),
      rangeEnd: rr?.integer('end'),
      snap: r.integer('snap', fallback: 1),
      boundViewport: bound == null ? null : PluginBoundViewport.fromJson(bound, '$path.boundViewport'),
    );
  }
}

// --- Table ---------------------------------------------------------------------

/// The value kind of a table column.
abstract final class PluginTableColumnKind {
  static const String text = 'text';
  static const String number = 'number';
  static const String enumeration = 'enum';
  static const String boolean = 'bool';
  static const String assetRef = 'assetRef';
  static const String color = 'color';
  static const List<String> all = [text, number, enumeration, boolean, assetRef, color];
}

/// How a row reads: `normal`, `warning` or `error`.
abstract final class PluginTableRowTone {
  static const String normal = 'normal';
  static const String warning = 'warning';
  static const String error = 'error';
  static const List<String> all = [normal, warning, error];
}

class PluginTableColumn {
  const PluginTableColumn({
    required this.id,
    required this.label,
    this.kind = PluginTableColumnKind.text,
    this.editable = false,
    this.options = const [],
    this.typeFilter,
    this.width,
    this.sortable = true,
  });

  final String id;
  final String label;
  final String kind;
  final bool editable;

  /// An `enum` column's values.
  final List<String> options;

  /// An `assetRef` column's asset types (`SkeletalMesh`, comma-separated).
  final String? typeFilter;
  final num? width;
  final bool sortable;

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'kind': kind,
        'editable': editable,
        if (options.isNotEmpty) 'options': options,
        'typeFilter': ?typeFilter,
        'width': ?width,
        'sortable': sortable,
      };

  static PluginTableColumn fromJson(EditorWidgetJsonReader r) => PluginTableColumn(
        id: r.string('id'),
        label: r.optString('label') ?? r.string('id'),
        kind: r.oneOf('kind', PluginTableColumnKind.all, PluginTableColumnKind.text),
        editable: r.flag('editable', false),
        options: r.strings('options'),
        typeFilter: r.optString('typeFilter'),
        width: r.optNum('width'),
        sortable: r.flag('sortable', true),
      );
}

class PluginTableRow {
  const PluginTableRow({required this.id, this.cells = const {}, this.group, this.tone = PluginTableRowTone.normal, this.tooltip});

  final String id;

  /// Column id → JSON value.
  final Map<String, Object?> cells;
  final String? group;
  final String tone;
  final String? tooltip;

  Map<String, Object?> toJson() => {
        'id': id,
        'cells': cells,
        'group': ?group,
        'tone': tone,
        'tooltip': ?tooltip,
      };

  static PluginTableRow fromJson(EditorWidgetJsonReader r) => PluginTableRow(
        id: r.string('id'),
        cells: r.optObject('cells') ?? const {},
        group: r.optString('group'),
        tone: r.oneOf('tone', PluginTableRowTone.all, PluginTableRowTone.normal),
        tooltip: r.optString('tooltip'),
      );
}

/// A table's state ([PluginTimelineState]'s counterpart): columns, rows,
/// the sort (`sort: {column, ascending}`), the selection mode
/// (`single` | `multi`), the selected row ids and whether a text filter row
/// shows.
class PluginTableState {
  const PluginTableState({
    this.columns = const [],
    this.rows = const [],
    this.sortColumn,
    this.sortAscending = true,
    this.selection = 'single',
    this.selected = const [],
    this.filter = false,
  });

  final List<PluginTableColumn> columns;
  final List<PluginTableRow> rows;
  final String? sortColumn;
  final bool sortAscending;
  final String selection;
  final List<String> selected;
  final bool filter;

  static const List<String> stateKeys = ['columns', 'rows', 'sort', 'selection', 'selected', 'filter'];

  Map<String, Object?> toJson() => {
        'columns': [for (final c in columns) c.toJson()],
        'rows': [for (final r in rows) r.toJson()],
        if (sortColumn != null) 'sort': {'column': sortColumn, 'ascending': sortAscending},
        'selection': selection,
        'selected': selected,
        'filter': filter,
      };

  static PluginTableState fromJson(Map<String, Object?> json, {String path = 'table'}) {
    final r = EditorWidgetJsonReader(json, path);
    final sort = r.optObject('sort');
    final sr = sort == null ? null : EditorWidgetJsonReader(sort, '$path.sort');
    return PluginTableState(
      columns: r.objects('columns', PluginTableColumn.fromJson),
      rows: r.objects('rows', PluginTableRow.fromJson),
      sortColumn: sr?.optString('column'),
      sortAscending: sr?.flag('ascending', true) ?? true,
      selection: r.oneOf('selection', const ['single', 'multi'], 'single'),
      selected: r.strings('selected'),
      filter: r.flag('filter', false),
    );
  }
}
