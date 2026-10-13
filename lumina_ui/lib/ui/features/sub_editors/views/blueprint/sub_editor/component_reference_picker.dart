part of '../blueprint_sub_editor.dart';

/// A [ComponentPropertyType.componentReference] row: a picker over the
/// Blueprint's components of the schema's reference types, without the
/// component itself and those that already follow it (a cycle), plus None.
Widget _componentReferencePicker(BlueprintEditorViewModel vm, ComponentPropertySchema prop, LuminaBlueprintComponent node) {
  final components = vm.document.components;
  final byId = {for (final c in components) c.id: c};
  // Whether [c] reaches [node] through the same property (it follows it).
  bool follows(LuminaBlueprintComponent c) {
    final seen = <String>{};
    for (var ref = c.properties[prop.dartField]; ref is String && ref.isNotEmpty && seen.add(ref);) {
      if (ref == node.id) return true;
      ref = byId[ref]?.properties[prop.dartField];
    }
    return false;
  }

  final options = [
    for (final c in components)
      if (c.id != node.id && prop.referenceTypes.contains(c.type) && !follows(c)) c,
  ];
  final current = node.properties[prop.dartField] as String? ?? '';
  final selected = options.any((c) => c.id == current) ? current : '';
  return Padding(
    key: ValueKey('bp_prop_${node.id}_${prop.dartField}'),
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prop.name, style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        Select<String>(
          key: ValueKey('bp_component_ref_${prop.dartField}'),
          value: selected,
          onChanged: (val) => vm.setProperty(node.id, prop.dartField, val ?? ''),
          itemBuilder: (context, item) => Text(
            item.isEmpty ? 'None' : (byId[item]?.name ?? item),
            style: const TextStyle(fontSize: 11),
          ),
          popup: SelectPopup(
            items: SelectItemList(
              children: [
                const SelectItemButton(value: '', child: Text('None')),
                for (final c in options) SelectItemButton(value: c.id, child: Text(c.name)),
              ],
            ),
          ).call,
        ),
      ],
    ),
  );
}
