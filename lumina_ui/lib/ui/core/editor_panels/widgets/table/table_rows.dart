import 'package:lumina_editor_api/lumina_editor_api.dart' show PluginTableColumn, PluginTableRow;

/// One line of a table's body: a group header or a row.
class TableLine {
  const TableLine.group(this.group) : row = null;
  const TableLine.row(PluginTableRow this.row) : group = null;

  final String? group;
  final PluginTableRow? row;
}

/// The body lines of a table for a sort and a filter: rows partitioned by
/// group (in the order groups first appear), each group sorted, a group
/// header before each named group. Computed once per change, never per
/// frame; 2,000 rows sort in a few milliseconds.
List<TableLine> tableLines(List<PluginTableRow> rows, List<PluginTableColumn> columns,
    {String? sortColumn, bool ascending = true, String filter = ''}) {
  final needle = filter.trim().toLowerCase();
  final groups = <String?, List<PluginTableRow>>{};
  for (final r in rows) {
    if (needle.isNotEmpty && !r.cells.values.any((v) => v != null && '$v'.toLowerCase().contains(needle))) continue;
    (groups[r.group] ??= <PluginTableRow>[]).add(r);
  }
  final column = sortColumn == null ? null : columns.where((c) => c.id == sortColumn).firstOrNull;
  final out = <TableLine>[];
  for (final e in groups.entries) {
    final list = e.value;
    if (column != null) {
      final id = column.id;
      // Stable: equal values keep their order.
      final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
      indexed.sort((a, b) {
        final c = compareTableValues(a.$2.cells[id], b.$2.cells[id]);
        if (c != 0) return ascending ? c : -c;
        return a.$1.compareTo(b.$1);
      });
      list
        ..clear()
        ..addAll(indexed.map((x) => x.$2));
    }
    if (e.key != null) out.add(TableLine.group(e.key));
    for (final r in list) {
      out.add(TableLine.row(r));
    }
  }
  return out;
}

/// Orders two cell values: numbers numerically, booleans false first,
/// anything else as text (case-insensitive); empty cells last.
int compareTableValues(Object? a, Object? b) {
  final aEmpty = a == null || a == '';
  final bEmpty = b == null || b == '';
  if (aEmpty || bEmpty) return aEmpty == bEmpty ? 0 : (aEmpty ? 1 : -1);
  if (a is num && b is num) return a.compareTo(b);
  if (a is bool && b is bool) return a == b ? 0 : (a ? 1 : -1);
  return '$a'.toLowerCase().compareTo('$b'.toLowerCase());
}

/// A cell value as the table shows it.
String tableCellText(Object? v) {
  if (v == null) return '';
  if (v is double) {
    final s = v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
    return s.endsWith('.') ? '${s}0' : s;
  }
  return '$v';
}
