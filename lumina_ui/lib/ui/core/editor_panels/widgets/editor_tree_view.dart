import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_panel_docking.dart' show editorPanelIcon;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// One row's data: `{id, label, icon, children}` from the element's `items`.
class EditorTreeItem {
  EditorTreeItem(this.id, this.label, this.icon, this.children);

  final String id;
  final String label;
  final String? icon;
  final List<EditorTreeItem> children;

  /// Reads `items` (a Json array of maps, or plain strings).
  static List<EditorTreeItem> parse(Object? items) => [
        if (items is List)
          for (final e in items)
            if (e is Map)
              EditorTreeItem('${e['id'] ?? e['label'] ?? ''}', '${e['label'] ?? e['id'] ?? ''}', e['icon'] as String?, parse(e['children']))
            else
              EditorTreeItem('$e', '$e', null, const []),
      ];
}

/// What a row reports: selection (with the whole selection), double click,
/// the context menu (with where the pointer was), expansion.
typedef EditorTreeEvent = void Function(String event, Map<String, Object?> args);

/// The editor widget set's Tree View and List View: rows exactly like the
/// Level Editor's Outliner (24 px, an indent per depth, chevrons, the
/// selection bar and hover tint, a type icon). A list is a tree without
/// children and allows multi-select (Ctrl toggles, Shift extends).
class EditorTreeView extends StatefulWidget {
  const EditorTreeView({
    super.key,
    required this.elementName,
    required this.items,
    required this.selected,
    required this.expanded,
    required this.onEvent,
    required this.onSelection,
    required this.onExpanded,
    this.multiSelect = false,
    this.onPointer,
  });

  final String elementName;
  final List<EditorTreeItem> items;
  final List<String> selected;
  final List<String> expanded;
  final bool multiSelect;
  final EditorTreeEvent onEvent;
  final void Function(List<String> selected) onSelection;
  final void Function(List<String> expanded) onExpanded;
  final void Function(Offset global)? onPointer;

  static const double rowHeight = EditorDensity.rowHeight;

  @override
  State<EditorTreeView> createState() => _EditorTreeViewState();
}

class _EditorTreeViewState extends State<EditorTreeView> {
  String? _hover;
  String? _anchor;
  ({String id, DateTime at})? _lastTap;

  List<({EditorTreeItem item, int depth})> _flatten() {
    final out = <({EditorTreeItem item, int depth})>[];
    void walk(List<EditorTreeItem> items, int depth) {
      for (final i in items) {
        out.add((item: i, depth: depth));
        if (i.children.isNotEmpty && widget.expanded.contains(i.id)) walk(i.children, depth + 1);
      }
    }

    walk(widget.items, 0);
    return out;
  }

  void _select(String id, List<({EditorTreeItem item, int depth})> rows) {
    final keys = HardwareKeyboard.instance;
    final ctrl = keys.isControlPressed || keys.isMetaPressed;
    final shift = keys.isShiftPressed;
    var next = <String>[id];
    if (widget.multiSelect && ctrl) {
      next = [...widget.selected];
      next.contains(id) ? next.remove(id) : next.add(id);
    } else if (widget.multiSelect && shift && _anchor != null) {
      final ids = [for (final r in rows) r.item.id];
      final a = ids.indexOf(_anchor!);
      final b = ids.indexOf(id);
      if (a >= 0 && b >= 0) next = ids.sublist(a < b ? a : b, (a < b ? b : a) + 1);
    }
    if (!shift) _anchor = id;
    widget.onSelection(next);
    widget.onEvent('OnItemSelected', {'item_id': id, 'selected_ids': next});
  }

  void _toggle(String id) {
    final open = !widget.expanded.contains(id);
    widget.onExpanded(open ? [...widget.expanded, id] : [for (final e in widget.expanded) if (e != id) e]);
    widget.onEvent('OnItemExpanded', {'item_id': id, 'expanded': open});
  }

  @override
  Widget build(BuildContext context) {
    final rows = _flatten();
    return Container(
      color: EditorColors.sidebar,
      child: ListView.builder(
        key: ValueKey('editor_tree_${widget.elementName}'),
        itemCount: rows.length,
        itemExtent: EditorTreeView.rowHeight,
        itemBuilder: (context, index) {
          final row = rows[index];
          final item = row.item;
          final selected = widget.selected.contains(item.id);
          final expandable = item.children.isNotEmpty;
          final open = widget.expanded.contains(item.id);
          return MouseRegion(
            onEnter: (_) => setState(() => _hover = item.id),
            onExit: (_) => setState(() => _hover = _hover == item.id ? null : _hover),
            child: Listener(
              onPointerDown: (e) {
                widget.onPointer?.call(e.position);
                if ((e.buttons & kSecondaryMouseButton) != 0) {
                  if (!selected) _select(item.id, rows);
                  widget.onEvent('OnItemContextMenu', {'item_id': item.id});
                }
              },
              child: GestureDetector(
                key: ValueKey('editor_tree_row_${widget.elementName}_${item.id}'),
                behavior: HitTestBehavior.opaque,
                // A double click is two taps on one row in 300 ms; a single
                // tap selects at once (no double-tap delay).
                onTap: () {
                  final now = DateTime.now();
                  final last = _lastTap;
                  _lastTap = (id: item.id, at: now);
                  if (last != null && last.id == item.id && now.difference(last.at) < const Duration(milliseconds: 300)) {
                    _lastTap = null;
                    widget.onEvent('OnItemDoubleClicked', {'item_id': item.id});
                    return;
                  }
                  _select(item.id, rows);
                },
                child: Container(
                  height: EditorTreeView.rowHeight,
                  padding: EdgeInsets.only(
                      left: EditorDensity.gutter + row.depth * EditorDensity.indentStep, right: EditorDensity.gutter),
                  decoration: BoxDecoration(
                    color: selected ? EditorColors.selectionBg : (_hover == item.id ? EditorColors.rowHover : Colors.transparent),
                    border: selected
                        ? const Border(left: BorderSide(color: EditorColors.primary, width: EditorDensity.selectionBarWidth))
                        : null,
                  ),
                  child: Row(children: [
                    if (expandable)
                      GestureDetector(
                        key: ValueKey('editor_tree_chevron_${widget.elementName}_${item.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _toggle(item.id),
                        child: Icon(open ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                            size: 14, color: EditorColors.mutedForeground),
                      )
                    else
                      const SizedBox(width: 14),
                    const SizedBox(width: 4),
                    Icon(item.icon == null ? (expandable ? LucideIcons.folder : LucideIcons.box) : editorPanelIcon(item.icon),
                        size: 12, color: EditorColors.mutedForeground),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(item.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: selected ? EditorColors.accentForeground : EditorColors.foreground)),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
