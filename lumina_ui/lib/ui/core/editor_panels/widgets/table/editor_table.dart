import 'dart:math' as math;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show AssetType, LuminaEditorWidgetEvents;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_library/assets_library.dart' show assetTypesOf;
import 'package:lumina_ui/ui/core/editor_panels/widgets/interaction/editor_interaction.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/table/table_cells.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/table/table_rows.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The native table of editor panels and JSON specs: a sticky header with
/// sort chevrons and resizable columns, an optional text filter row, group
/// rows and 24 px virtualised rows (2,000 and more), typed cells edited in
/// place (text, number, enum through a shadcn `Select`, bool, colour, and
/// asset references through the editor's asset picker), single or Shift /
/// Ctrl multi-selection, double-click and context-menu events.
///
/// [state] is the element state or the spec props ([PluginTableState]).
class EditorTable extends StatefulWidget {
  const EditorTable({super.key, required this.name, required this.state, required this.onEvent, required this.onState, this.assetPicker});

  final String name;
  final Map<String, Object?> state;
  final EditorWidgetEventSink onEvent;
  final EditorWidgetStateSink onState;
  final TableAssetPickerBuilder? assetPicker;

  static const double rowHeight = 24;

  @override
  State<EditorTable> createState() => EditorTableState();
}

class EditorTableState extends State<EditorTable> {
  final EditorStateSnapshot _snapshot = EditorStateSnapshot();
  PluginTableState _table = const PluginTableState();
  List<PluginTableRow> _rows = const [];
  final Map<String, double> _widths = {};
  String? _sortColumn;
  bool _ascending = true;
  final Set<String> _selected = {};
  String? _anchor;
  String _filter = '';
  List<TableLine> _lines = const [];
  (String, String)? _editing;
  String? _error;
  final ScrollController _vertical = ScrollController();
  final ScrollController _horizontal = ScrollController();

  /// The body lines in display order (tests).
  List<TableLine> get lines => _lines;

  /// How many body lines were built so far: only the visible ones build,
  /// whatever the row count (tests).
  int linesBuilt = 0;

  @override
  void initState() {
    super.initState();
    _adopt(first: true);
  }

  @override
  void didUpdateWidget(EditorTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _adopt();
  }

  void _adopt({bool first = false}) {
    final changed = _snapshot.changedKeys(widget.state, PluginTableState.stateKeys);
    if (!first && changed.isEmpty) return;
    try {
      final rowsChanged = first || changed.contains('rows');
      // Rows are parsed only when they changed (a sort or a selection
      // echoed back must not re-read 2,000 rows).
      final t = PluginTableState.fromJson(rowsChanged ? widget.state : {...widget.state, 'rows': const <Object?>[]}, path: widget.name);
      final columnsChanged = first || changed.contains('columns');
      _table = PluginTableState(
        columns: t.columns,
        rows: rowsChanged ? t.rows : _rows,
        sortColumn: t.sortColumn,
        sortAscending: t.sortAscending,
        selection: t.selection,
        selected: t.selected,
        filter: t.filter,
      );
      var relayout = rowsChanged || columnsChanged;
      if (rowsChanged) _rows = t.rows;
      if ((first || changed.contains('sort')) && (t.sortColumn != _sortColumn || t.sortAscending != _ascending)) {
        _sortColumn = t.sortColumn;
        _ascending = t.sortAscending;
        relayout = true;
      }
      if (first || changed.contains('selected')) {
        _selected
          ..clear()
          ..addAll(t.selected);
      }
      _error = null;
      if (relayout) _relayout();
    } on FormatException catch (e) {
      _error = e.message;
    }
  }

  /// How long the last sort / filter of the body took (diagnostics, tests).
  Duration lastRelayout = Duration.zero;

  void _relayout() {
    final sw = Stopwatch()..start();
    _lines = tableLines(_rows, _table.columns, sortColumn: _sortColumn, ascending: _ascending, filter: _filter);
    lastRelayout = sw.elapsed;
  }

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  double _width(PluginTableColumn c) => _widths[c.id] ?? c.width?.toDouble() ?? 120;

  // --- Actions -----------------------------------------------------------------

  void _sortBy(PluginTableColumn c) {
    if (!c.sortable) return;
    setState(() {
      _ascending = _sortColumn == c.id ? !_ascending : true;
      _sortColumn = c.id;
      _relayout();
    });
    widget.onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onSortChanged, PluginEditorWidgetEventKind.sortChanged,
        {'column': c.id, 'ascending': _ascending}));
    widget.onState({'sort': {'column': c.id, 'ascending': _ascending}}, edit: false);
  }

  void _select(String id) {
    final multi = _table.selection == 'multi';
    final keyboard = HardwareKeyboard.instance;
    final before = {..._selected};
    if (multi && keyboard.isShiftPressed && _anchor != null) {
      final ids = [for (final l in _lines) if (l.row != null) l.row!.id];
      final a = ids.indexOf(_anchor!);
      final b = ids.indexOf(id);
      if (a >= 0 && b >= 0) {
        _selected
          ..clear()
          ..addAll(ids.sublist(math.min(a, b), math.max(a, b) + 1));
      }
    } else if (multi && (keyboard.isControlPressed || keyboard.isMetaPressed)) {
      _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
      _anchor = id;
    } else {
      _selected
        ..clear()
        ..add(id);
      _anchor = id;
    }
    if (setEquals(before, _selected)) return;
    setState(() {});
    final ids = [for (final l in _lines) if (l.row != null && _selected.contains(l.row!.id)) l.row!.id];
    widget.onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onRowSelected, PluginEditorWidgetEventKind.rowSelected, {'row_ids': ids}));
    widget.onState({'selected': ids}, edit: false);
  }

  void _commitCell(PluginTableRow row, PluginTableColumn column, Object? value) {
    final next = PluginTableRow(id: row.id, cells: {...row.cells, column.id: value}, group: row.group, tone: row.tone, tooltip: row.tooltip);
    setState(() {
      _rows = [for (final r in _rows) r.id == row.id ? next : r];
      _relayout();
    });
    widget.onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onCellCommitted, PluginEditorWidgetEventKind.cellCommitted,
        {'row_id': row.id, 'column_id': column.id, 'value': value, 'text': value == null ? '' : '$value'}));
    widget.onState({'rows': [for (final r in _rows) r.toJson()]}, edit: true);
  }

  Duration? _lastDown;
  String? _lastDownRow;
  Offset _lastDownAt = Offset.zero;

  void _bodyDown(PointerDownEvent e) {
    final row = _rowAt(e.localPosition.dy);
    if (row == null) return;
    if (e.buttons == kSecondaryMouseButton) {
      widget.onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onRowContextMenu, PluginEditorWidgetEventKind.rowContextMenu, {'row_id': row.id}));
      return;
    }
    if (e.buttons != kPrimaryMouseButton) return;
    final last = _lastDown;
    final double = last != null &&
        _lastDownRow == row.id &&
        e.timeStamp > last &&
        e.timeStamp - last <= kDoubleTapTimeout &&
        (e.position - _lastDownAt).distance <= kDoubleTapSlop;
    _lastDown = double ? null : e.timeStamp;
    _lastDownRow = row.id;
    _lastDownAt = e.position;
    if (double) {
      _doubleTap(row, e.localPosition.dx);
    } else {
      _select(row.id);
    }
  }

  /// The row at [y] in the body (below the header), or null.
  PluginTableRow? _rowAt(double y) {
    final i = ((y + (_vertical.hasClients ? _vertical.offset : 0)) / EditorTable.rowHeight).floor();
    return i >= 0 && i < _lines.length ? _lines[i].row : null;
  }

  void _doubleTap(PluginTableRow row, double x) {
    // The column under the pointer: an editable text / number / colour cell
    // opens its field, anything else is a row double-click.
    var left = 0.0;
    for (final c in _table.columns) {
      final w = _width(c);
      if (x >= left && x < left + w) {
        const inline = {PluginTableColumnKind.text, PluginTableColumnKind.number, PluginTableColumnKind.color};
        if (c.editable && inline.contains(c.kind)) {
          setState(() => _editing = (row.id, c.id));
          return;
        }
        break;
      }
      left += w;
    }
    widget.onEvent(EditorWidgetEvent(LuminaEditorWidgetEvents.onRowDoubleClicked, PluginEditorWidgetEventKind.rowDoubleClicked, {'row_id': row.id}));
  }

  // --- Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) return EditorWidgetStateError(message: 'Table ${widget.name}: $error');
    final columns = _table.columns;
    final total = columns.fold<double>(0, (s, c) => s + _width(c));
    return Container(
      key: ValueKey('editor_table_${widget.name}'),
      color: EditorColors.sidebar,
      child: LayoutBuilder(builder: (context, constraints) {
        final width = math.max(total, constraints.maxWidth.isFinite ? constraints.maxWidth : total);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_table.filter) _filterRow(),
          Expanded(
            child: Scrollbar(
              controller: _horizontal,
              child: SingleChildScrollView(
                controller: _horizontal,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _header(columns),
                    Expanded(
                      // One pointer handler for every row (rows stay cheap
                      // to build): the line under the pointer by offset. A
                      // double click is told from the pointer times, so the
                      // cells' own buttons (enum, asset, bool) react at once.
                      child: Listener(
                          onPointerDown: _bodyDown,
                          child: ListView.builder(
                            key: ValueKey('editor_table_${widget.name}_rows'),
                            controller: _vertical,
                            itemExtent: EditorTable.rowHeight,
                            itemCount: _lines.length,
                            itemBuilder: (context, i) => _line(_lines[i], columns),
                          ),
                        ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }

  Widget _filterRow() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: const BoxDecoration(color: EditorColors.cardHeader, border: Border(bottom: BorderSide(color: EditorColors.border))),
        child: TextField(
          key: ValueKey('editor_table_${widget.name}_filter'),
          placeholder: const Text('Filter rows'),
          style: const TextStyle(fontSize: 10.5),
          features: const [InputFeature.leading(Icon(LucideIcons.search, size: 12))],
          onChanged: (v) => setState(() {
            _filter = v;
            _relayout();
          }),
        ),
      );

  Widget _header(List<PluginTableColumn> columns) => Container(
        height: EditorTable.rowHeight,
        decoration: const BoxDecoration(color: EditorColors.cardHeader, border: Border(bottom: BorderSide(color: EditorColors.border))),
        child: Row(children: [
          for (final c in columns)
            SizedBox(
              width: _width(c),
              child: Stack(children: [
                Positioned.fill(
                  child: GestureDetector(
                    key: ValueKey('editor_table_${widget.name}_header_${c.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _sortBy(c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(children: [
                        Expanded(
                          child: Text(c.label,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
                        ),
                        if (_sortColumn == c.id)
                          Icon(_ascending ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 12, color: EditorColors.mutedForeground),
                      ]),
                    ),
                  ),
                ),
                // The resize handle on the column's right edge.
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 5,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      key: ValueKey('editor_table_${widget.name}_resize_${c.id}'),
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (d) => setState(() => _widths[c.id] = math.max(40, _width(c) + d.delta.dx)),
                      onHorizontalDragEnd: (_) => widget.onState({
                        'columns': [
                          for (final x in _table.columns) {...x.toJson(), 'width': double.parse(_width(x).toStringAsFixed(1))},
                        ],
                      }, edit: false),
                      child: const VerticalDivider(width: 5, thickness: 1, color: EditorColors.border),
                    ),
                  ),
                ),
              ]),
            ),
        ]),
      );

  Widget _line(TableLine line, List<PluginTableColumn> columns) {
    linesBuilt++;
    final group = line.group;
    if (group != null) {
      return Container(
        key: ValueKey('editor_table_${widget.name}_group_$group'),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerLeft,
        decoration: const BoxDecoration(color: EditorColors.cardHeader, border: Border(bottom: BorderSide(color: EditorColors.border))),
        child: Row(children: [
          const Icon(LucideIcons.chevronDown, size: 12, color: EditorColors.mutedForeground),
          const SizedBox(width: 4),
          Text(group, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
        ]),
      );
    }
    final row = line.row!;
    final selected = _selected.contains(row.id);
    final tone = switch (row.tone) {
      PluginTableRowTone.error => EditorColors.logError,
      PluginTableRowTone.warning => EditorColors.logWarning,
      _ => EditorColors.foreground,
    };
    Widget body = Container(
      key: ValueKey('editor_table_${widget.name}_row_${row.id}'),
      decoration: BoxDecoration(
        color: selected ? EditorColors.selectionBg : EditorColors.sidebar,
        border: Border(
          bottom: const BorderSide(color: EditorColors.border),
          left: BorderSide(color: row.tone == PluginTableRowTone.normal ? Colors.transparent : tone, width: 2),
        ),
      ),
      child: Row(children: [
        for (final c in columns)
          SizedBox(
            key: ValueKey('editor_table_${widget.name}_cell_${row.id}_${c.id}'),
            width: _width(c),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: EditorTableCell(
                column: c,
                value: row.cells[c.id],
                editing: _editing == (row.id, c.id),
                textColor: identical(c, columns.first) ? tone : EditorColors.foreground,
                assetPicker: widget.assetPicker,
                types: _types(c),
                onCommit: (v) => _commitCell(row, c, v),
                onEndEdit: () {
                  if (_editing == (row.id, c.id)) setState(() => _editing = null);
                },
              ),
            ),
          ),
      ]),
    );
    final tip = row.tooltip;
    if (tip != null && tip.isNotEmpty) {
      body = Tooltip(tooltip: (context) => TooltipContainer(child: Text(tip).small()), child: body);
    }
    return body;
  }

  final Map<String, Set<AssetType>?> _typeCache = {};

  Set<AssetType>? _types(PluginTableColumn c) =>
      c.kind != PluginTableColumnKind.assetRef ? null : _typeCache.putIfAbsent(c.typeFilter ?? '', () => assetTypesOf(c.typeFilter ?? ''));
}
