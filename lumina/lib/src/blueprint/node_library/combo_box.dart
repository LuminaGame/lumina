part of '../node_library.dart';

// --- Combo Box ------------------------------------------------

/// A Combo Box node: impure (exec in / out) or pure, the element first.
LuminaBlueprintNodeSpec _comboNode(String id, String title, List<String> keywords,
        {bool pure = false, List<LuminaBlueprintPinSpec> inputs = const [], List<LuminaBlueprintPinSpec> outputs = const []}) =>
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: 'Widget|Combo Box',
      kind: pure ? LuminaBlueprintNodeKind.pure : LuminaBlueprintNodeKind.impure,
      headerColor: pure ? _pure : _function,
      keywords: ['widget', 'ui', 'element', 'combo', 'combo box', 'dropdown', 'option', ...keywords],
      inputs: [if (!pure) _execIn, _element('comboBox'), ...inputs],
      outputs: [if (!pure) _execOut, ...outputs],
    );

/// The Combo Box's options — a label the player sees and a value of any type
/// (wildcard pins take a type when wired) — and its selection, by label,
/// value or index.
final List<LuminaBlueprintNodeSpec> _comboBoxNodes = <LuminaBlueprintNodeSpec>[
  _comboNode('add_element_option', 'Add Option', const ['add', 'value', 'label', 'item'],
      inputs: [_s('option', 'Label'), _any('value', 'Value')]),
  _comboNode('remove_element_option', 'Remove Option', const ['remove', 'delete', 'label'],
      inputs: [_s('option', 'Option')], outputs: [_ret(LuminaPinType.boolean)]),
  _comboNode('clear_element_options', 'Clear Options', const ['clear', 'options', 'empty', 'reset']),
  _comboNode('set_element_selected_option', 'Set Selected Option', const ['select', 'selected', 'label'],
      inputs: [_s('option', 'Option')]),
  _comboNode('set_element_selected_value', 'Set Selected Value', const ['select', 'selected', 'value'],
      inputs: [_any('value', 'Value')]),
  _comboNode('set_element_selected_index', 'Set Selected Index', const ['select', 'selected', 'index'],
      inputs: [_i('index', 'Index')]),
  _comboNode('clear_element_selection', 'Clear Selection', const ['clear', 'selection', 'deselect', 'none']),
  _comboNode('get_element_selected_option', 'Get Selected Option', const ['selected', 'get', 'value', 'label', 'index'],
      pure: true,
      outputs: [_ret(LuminaPinType.string, name: 'Label'), _any('value', 'Value'), _i('index', 'Index', -1)]),
  _comboNode('get_element_selected_index', 'Get Selected Index', const ['selected', 'get', 'index'],
      pure: true, outputs: [_ret(LuminaPinType.integer)]),
  _comboNode('get_element_option_count', 'Get Option Count', const ['count', 'length', 'number', 'options'],
      pure: true, outputs: [_ret(LuminaPinType.integer)]),
  _comboNode('get_element_option_at_index', 'Get Option at Index', const ['label', 'index', 'get', 'at'],
      pure: true, inputs: [_i('index', 'Index')], outputs: [_ret(LuminaPinType.string)]),
  _comboNode('get_element_option_value', 'Get Option Value', const ['value', 'index', 'get'],
      pure: true, inputs: [_i('index', 'Index')], outputs: [_any(_returnValue, 'Return Value')]),
  _comboNode('find_element_option_index', 'Find Option Index', const ['find', 'index', 'label', 'search'],
      pure: true, inputs: [_s('option', 'Option')], outputs: [_ret(LuminaPinType.integer)]),
  _comboNode('find_element_option_index_by_value', 'Find Option Index by Value', const ['find', 'index', 'value', 'search'],
      pure: true, inputs: [_any('value', 'Value')], outputs: [_ret(LuminaPinType.integer)]),
];

/// On Selection Changed's outputs; [node]'s `type` / `class` literals type
/// the Value.
List<LuminaBlueprintPinSpec> _selectionChangedOutputs(LuminaBlueprintNode node) {
  final type = LuminaPinType.parse(node.literals['type'] as String?);
  final cls = node.literals['class'];
  final value = type == null || type == LuminaPinType.wildcard || type == LuminaPinType.exec
      ? _any('value', 'Value')
      : LuminaBlueprintPinSpec('value', 'Value', type, objectClass: cls is String && cls.isNotEmpty ? cls : null);
  return [
    _s('selected_item', 'Selected Item'),
    value,
    _i('index', 'Index', -1),
    _enum('select_type', 'Select Type', LuminaComboBoxOptions.selectInfoEnum),
  ];
}
