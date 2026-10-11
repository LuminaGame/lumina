import 'package:flutter/services.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show PluginTableColumn, PluginTableColumnKind;
import 'package:lumina_editor_data/lumina_editor.dart' show AssetType;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/widgets/interaction/editor_interaction.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/table/table_rows.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Builds the editor's asset picker for an `assetRef` cell
/// (`EditorAssetPicker` in an editor panel and in a plugin's spec).
typedef TableAssetPickerBuilder = Widget Function(BuildContext context,
    {required String? selectedPath, required Set<AssetType>? types, required ValueChanged<String?> onSelected});

/// One cell: the value as text (a swatch for colours, a check box for
/// booleans), or its editor: a shadcn `Select` for `enum`, the asset picker
/// for `assetRef`, a text field while a text, number or colour cell is
/// edited. [onCommit] fires once per edit with the new JSON value.
class EditorTableCell extends StatelessWidget {
  const EditorTableCell({
    super.key,
    required this.column,
    required this.value,
    required this.editing,
    required this.onCommit,
    required this.onEndEdit,
    this.assetPicker,
    this.types,
    this.textColor = EditorColors.foreground,
  });

  final PluginTableColumn column;
  final Object? value;

  /// A text / number / colour cell shows its inline field.
  final bool editing;
  final ValueChanged<Object?> onCommit;
  final VoidCallback onEndEdit;
  final TableAssetPickerBuilder? assetPicker;
  final Set<AssetType>? types;
  final Color textColor;

  Widget _text(String s, {Color? color}) => Text(
        s,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(fontSize: 10.5, color: color ?? textColor),
      );

  @override
  Widget build(BuildContext context) {
    final editable = column.editable;
    switch (column.kind) {
      case PluginTableColumnKind.boolean:
        return Align(
          alignment: Alignment.centerLeft,
          child: Checkbox(
            state: value == true ? CheckboxState.checked : CheckboxState.unchecked,
            onChanged: editable ? (s) => onCommit(s == CheckboxState.checked) : null,
          ),
        );
      case PluginTableColumnKind.enumeration when editable:
        final v = value is String && column.options.contains(value) ? value as String : null;
        return Select<String>(
          value: v,
          placeholder: _text('—', color: EditorColors.mutedForeground),
          onChanged: (s) {
            if (s != null && s != value) onCommit(s);
          },
          itemBuilder: (context, item) => _text(item),
          popup: SelectPopup(
            items: SelectItemList(children: [for (final o in column.options) SelectItemButton(value: o, child: Text(o))]),
          ).call,
        );
      case PluginTableColumnKind.assetRef when editable && assetPicker != null:
        final path = value is String && (value as String).isNotEmpty ? value as String : null;
        return assetPicker!(context, selectedPath: path, types: types, onSelected: (p) {
          if (p != value) onCommit(p);
        });
      case PluginTableColumnKind.color:
        if (editing) return _TableCellField(initial: tableCellText(value), onCommit: onCommit, onEnd: onEndEdit);
        return Row(children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: editorWidgetColor(value is String ? value as String : null, const Color(0x00000000)),
              border: Border.all(color: EditorColors.border),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(child: _text(tableCellText(value))),
        ]);
      default:
        if (editing) {
          final number = column.kind == PluginTableColumnKind.number;
          return _TableCellField(
            initial: tableCellText(value),
            number: number,
            onCommit: (v) {
              if (!number) return onCommit(v);
              final n = num.tryParse('$v'.trim());
              if (n != null) onCommit(n == n.roundToDouble() && value is int ? n.toInt() : n);
            },
            onEnd: onEndEdit,
          );
        }
        final s = column.kind == PluginTableColumnKind.assetRef && value is String
            ? (value as String).split('/').last
            : tableCellText(value);
        return _text(s, color: column.kind == PluginTableColumnKind.number ? EditorColors.secondaryForeground : null);
    }
  }
}

/// The inline editor of a text, number or colour cell: Enter commits,
/// Escape or leaving the field ends without a commit.
class _TableCellField extends StatefulWidget {
  const _TableCellField({required this.initial, required this.onCommit, required this.onEnd, this.number = false});

  final String initial;
  final bool number;
  final ValueChanged<Object?> onCommit;
  final VoidCallback onEnd;

  @override
  State<_TableCellField> createState() => _TableCellFieldState();
}

class _TableCellFieldState extends State<_TableCellField> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);
  final FocusNode _focus = FocusNode();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _end();
    });
  }

  void _end() {
    if (_done) return;
    _done = true;
    widget.onEnd();
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        onKeyEvent: (node, e) {
          if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
            _end();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          key: const ValueKey('editor_table_cell_field'),
          controller: _c,
          focusNode: _focus,
          autofocus: true,
          style: const TextStyle(fontSize: 10.5),
          onSubmitted: (v) {
            if (_done) return;
            _done = true;
            if (v != widget.initial) widget.onCommit(v);
            widget.onEnd();
          },
        ),
      );
}
