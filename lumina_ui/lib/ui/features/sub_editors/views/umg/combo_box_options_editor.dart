import 'package:lumina_editor_data/lumina_editor.dart' show LuminaComboBoxOptions;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';

/// A literal type a Combo Box option's value can take in the designer:
/// `none` (the option stands for its label) or a Blueprint pin type name.
/// Object and struct values come from Blueprint (Add Option), not literals.
typedef UmgComboValueType = ({String id, String label, int components});

/// The Details rows of a Combo Box: one row per option — label, value type,
/// a value editor for that type, move up and remove — then Add Option and the
/// Selected option. Every edit writes the node's `options` list
/// (`{label}` or `{label, value, type}` entries) as one undo step.
class UmgComboBoxOptionsEditor extends StatelessWidget {
  const UmgComboBoxOptionsEditor({super.key, required this.vm, required this.node});

  final UmgEditorViewModel vm;
  final UmgNode node;

  /// The value types the picker offers, in order.
  static const List<UmgComboValueType> valueTypes = [
    (id: 'none', label: 'Label', components: 0),
    (id: 'string', label: 'String', components: 1),
    (id: 'name', label: 'Name', components: 1),
    (id: 'enum', label: 'Enum', components: 1),
    (id: 'integer', label: 'Integer', components: 1),
    (id: 'float', label: 'Float', components: 1),
    (id: 'boolean', label: 'Boolean', components: 0),
    (id: 'vector2D', label: 'Vector 2D', components: 2),
    (id: 'vector', label: 'Vector', components: 3),
    (id: 'color', label: 'Color', components: 4),
  ];

  static const List<String> _axes = ['X', 'Y', 'Z'];
  static const List<String> _channels = ['R', 'G', 'B', 'A'];

  /// The zero value of [type] (what a row gets when its type changes).
  static Object? zeroOf(String type) => switch (type) {
    'string' || 'name' || 'enum' => '',
    'integer' => 0,
    'float' => 0.0,
    'boolean' => false,
    'vector2D' => [0.0, 0.0],
    'vector' => [0.0, 0.0, 0.0],
    'color' => [1.0, 1.0, 1.0, 1.0],
    _ => null,
  };

  List<Map<String, Object?>> get _rows => LuminaComboBoxOptions.migrateDesignerOptions(node.props['options']);

  void _write(List<Map<String, Object?>> rows) => vm.setProp(node.id, 'options', rows);

  void _update(int i, Map<String, Object?> Function(Map<String, Object?> row) change) {
    final rows = _rows;
    rows[i] = change(Map<String, Object?>.of(rows[i]));
    _write(rows);
  }

  void _setType(int i, String type) => _update(i, (row) {
    final label = '${row['label'] ?? ''}';
    return type == 'none'
        ? LuminaComboBoxOptions.designerEntry(label)
        : LuminaComboBoxOptions.designerEntry(label, value: zeroOf(type), type: type);
  });

  void _rename(int i, String label) {
    final old = '${_rows[i]['label'] ?? ''}';
    _update(i, (row) => row..['label'] = label);
    // The selection follows its option's new label.
    if (node.props['selected']?.toString() == old) vm.setProp(node.id, 'selected', label);
  }

  void _move(int i, int to) {
    final rows = _rows;
    if (to < 0 || to >= rows.length) return;
    final row = rows.removeAt(i);
    rows.insert(to, row);
    _write(rows);
  }

  void _remove(int i) {
    final rows = _rows;
    rows.removeAt(i);
    _write(rows);
  }

  void _add() {
    final rows = _rows;
    var n = rows.length + 1;
    while (rows.any((r) => r['label'] == 'Option $n')) {
      n++;
    }
    rows.add(LuminaComboBoxOptions.designerEntry('Option $n'));
    _write(rows);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final labels = [for (final r in rows) '${r['label'] ?? ''}'];
    final selected = node.props['selected']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _caption('Options (label + value)'),
        for (var i = 0; i < rows.length; i++) _row(i, rows[i], rows.length),
        Align(
          alignment: Alignment.centerLeft,
          child: GhostButton(
            key: ValueKey('umg_combo_option_add_${node.id}'),
            density: ButtonDensity.compact,
            onPressed: _add,
            leading: const Icon(LucideIcons.plus, size: 11),
            child: const Text('Add Option', style: TextStyle(fontSize: 9.5)),
          ),
        ),
        const SizedBox(height: 4),
        _caption('Selected'),
        Select<String>(
          key: ValueKey('umg_combo_selected_${node.id}'),
          value: labels.contains(selected) ? selected : null,
          placeholder: const Text('None', style: TextStyle(fontSize: 9.5)),
          itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 9.5)),
          onChanged: (v) {
            if (v != null) vm.setProp(node.id, 'selected', v);
          },
          popup: SelectPopup(
            items: SelectItemList(
              children: [
                for (var i = 0; i < labels.length; i++)
                  SelectItemButton(
                    key: ValueKey('umg_combo_selected_item_${node.id}_$i'),
                    value: labels[i],
                    child: Text(labels[i], style: const TextStyle(fontSize: 9.5)),
                  ),
              ],
            ),
          ).call,
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _caption(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2, top: 2),
    child: Text(text, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
  );

  Widget _row(int i, Map<String, Object?> row, int count) {
    final label = '${row['label'] ?? ''}';
    final type = row['type'] is String && row.containsKey('value') ? row['type'] as String : 'none';
    final kind = valueTypes.firstWhere((t) => t.id == type, orElse: () => valueTypes.first);
    return Container(
      key: ValueKey('umg_combo_option_row_${node.id}_$i'),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: EditorColors.card,
        border: Border.all(color: EditorColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('umg_combo_option_label_${node.id}_${i}_$label'),
                  initialValue: label,
                  placeholder: const Text('Label', style: TextStyle(fontSize: 9.5)),
                  style: const TextStyle(fontSize: 9.5),
                  onSubmitted: (v) => _rename(i, v),
                ),
              ),
              IconButton.ghost(
                key: ValueKey('umg_combo_option_up_${node.id}_$i'),
                density: ButtonDensity.compact,
                icon: const Icon(LucideIcons.chevronUp, size: 11),
                onPressed: i == 0 ? null : () => _move(i, i - 1),
              ),
              IconButton.ghost(
                key: ValueKey('umg_combo_option_down_${node.id}_$i'),
                density: ButtonDensity.compact,
                icon: const Icon(LucideIcons.chevronDown, size: 11),
                onPressed: i == count - 1 ? null : () => _move(i, i + 1),
              ),
              IconButton.ghost(
                key: ValueKey('umg_combo_option_remove_${node.id}_$i'),
                density: ButtonDensity.compact,
                icon: const Icon(LucideIcons.trash2, size: 11),
                onPressed: () => _remove(i),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Select<String>(
            key: ValueKey('umg_combo_option_type_${node.id}_$i'),
            value: kind.id,
            itemBuilder: (context, item) => Text(_typeLabel(item), style: const TextStyle(fontSize: 9.5)),
            onChanged: (v) {
              if (v != null && v != kind.id) _setType(i, v);
            },
            popup: SelectPopup(
              items: SelectItemList(
                children: [
                  for (final t in valueTypes)
                    SelectItemButton(
                      key: ValueKey('umg_combo_option_type_item_${node.id}_${i}_${t.id}'),
                      value: t.id,
                      child: Text(t.label, style: const TextStyle(fontSize: 9.5)),
                    ),
                ],
              ),
            ).call,
          ),
          if (kind.id != 'none') ...[const SizedBox(height: 3), _valueEditor(i, kind, row['value'])],
        ],
      ),
    );
  }

  static String _typeLabel(String id) => valueTypes.firstWhere((t) => t.id == id, orElse: () => valueTypes.first).label;

  Widget _valueEditor(int i, UmgComboValueType kind, Object? value) {
    if (kind.id == 'boolean') {
      return Row(
        children: [
          const Expanded(
            child: Text('Value', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          ),
          Switch(
            key: ValueKey('umg_combo_option_bool_${node.id}_$i'),
            value: value == true,
            onChanged: (v) => _update(i, (row) => row..['value'] = v),
          ),
        ],
      );
    }
    if (kind.components == 1) {
      final text = value == null ? '' : '$value';
      return TextField(
        key: ValueKey('umg_combo_option_value_${node.id}_${i}_0_$text'),
        initialValue: text,
        placeholder: Text(kind.label, style: const TextStyle(fontSize: 9.5)),
        style: const TextStyle(fontSize: 9.5),
        onSubmitted: (v) => _update(i, (row) => row..['value'] = _parse(kind.id, v)),
      );
    }
    final list = value is List ? value : const [];
    final names = kind.id == 'color' ? _channels : _axes;
    return Row(
      children: [
        for (var c = 0; c < kind.components; c++) ...[
          if (c > 0) const SizedBox(width: 3),
          Text(names[c], style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(width: 2),
          Expanded(
            child: TextField(
              key: ValueKey('umg_combo_option_value_${node.id}_${i}_${c}_${c < list.length ? list[c] : ''}'),
              initialValue: c < list.length ? '${list[c]}' : '0',
              style: const TextStyle(fontSize: 9.5),
              onSubmitted: (v) => _update(i, (row) {
                final current = row['value'] is List ? List<Object?>.of(row['value'] as List) : <Object?>[];
                while (current.length < kind.components) {
                  current.add(0.0);
                }
                current[c] = double.tryParse(v.trim()) ?? 0.0;
                return row..['value'] = [for (final n in current) n is num ? n.toDouble() : 0.0];
              }),
            ),
          ),
        ],
      ],
    );
  }

  static Object _parse(String type, String text) => switch (type) {
    'integer' => int.tryParse(text.trim()) ?? (double.tryParse(text.trim())?.round() ?? 0),
    'float' => double.tryParse(text.trim()) ?? 0.0,
    _ => text,
  };
}
