part of '../blueprint_function_library.dart';

/// [LuminaBlueprintFunctionLibrary.callShapes]: the Combo Box nodes.
const Map<String, LuminaBlueprintCallShape> _comboBoxCallShapes = <String, LuminaBlueprintCallShape>{
  'add_element_option': LuminaBlueprintCallShape('addElementOption', ['target', 'option', 'value'], self: true),
  'remove_element_option': LuminaBlueprintCallShape('removeElementOption', ['target', 'option'],
      self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'clear_element_options': LuminaBlueprintCallShape('clearElementOptions', ['target'], self: true),
  'set_element_selected_option': LuminaBlueprintCallShape('setElementSelectedOption', ['target', 'option'], self: true),
  'set_element_selected_value': LuminaBlueprintCallShape('setElementSelectedValue', ['target', 'value'], self: true),
  'set_element_selected_index': LuminaBlueprintCallShape('setElementSelectedIndex', ['target', 'index'], self: true),
  'clear_element_selection': LuminaBlueprintCallShape('clearElementSelection', ['target'], self: true),
  'get_element_selected_option':
      LuminaBlueprintCallShape('getElementSelection', ['target'], outputs: ['return_value', 'value', 'index']),
  'get_element_selected_index': LuminaBlueprintCallShape('getElementSelectedIndex', ['target'], outputs: LuminaBlueprintFunctionLibrary._r),
  'get_element_option_count': LuminaBlueprintCallShape('getElementOptionCount', ['target'], outputs: LuminaBlueprintFunctionLibrary._r),
  'get_element_option_at_index':
      LuminaBlueprintCallShape('getElementOptionAtIndex', ['target', 'index'], outputs: LuminaBlueprintFunctionLibrary._r),
  'get_element_option_value':
      LuminaBlueprintCallShape('getElementOptionValue', ['target', 'index'], outputs: LuminaBlueprintFunctionLibrary._r),
  'find_element_option_index':
      LuminaBlueprintCallShape('findElementOptionIndex', ['target', 'option'], outputs: LuminaBlueprintFunctionLibrary._r),
  'find_element_option_index_by_value':
      LuminaBlueprintCallShape('findElementOptionIndexByValue', ['target', 'value'], outputs: LuminaBlueprintFunctionLibrary._r),
};

/// [LuminaBlueprintFunctionLibrary.builtInFunctions]: the Combo Box nodes.
final Map<String, LuminaBlueprintFunction> _comboBoxFunctions = <String, LuminaBlueprintFunction>{
  'add_element_option': (c, i) {
    _addElementOption(c.self, i['target'], i['option'] as String? ?? '', i['value']);
    return const {};
  },
  'remove_element_option': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(_removeElementOption(c.self, i['target'], i['option'] as String? ?? '')),
  'clear_element_options': (c, i) {
    _clearElementOptions(c.self, i['target']);
    return const {};
  },
  'set_element_selected_option': (c, i) {
    _setElementSelectedOption(c.self, i['target'], i['option'] as String? ?? '');
    return const {};
  },
  'set_element_selected_value': (c, i) {
    _setElementSelectedValue(c.self, i['target'], i['value']);
    return const {};
  },
  'set_element_selected_index': (c, i) {
    _setElementSelectedIndex(c.self, i['target'], LuminaBlueprintFunctionLibrary._n(i['index'], 0));
    return const {};
  },
  'clear_element_selection': (c, i) {
    _clearElementSelection(c.self, i['target']);
    return const {};
  },
  'get_element_selected_option': (c, i) {
    final r = _getElementSelection(i['target']);
    return {'return_value': r.returnValue, 'value': r.value, 'index': r.index};
  },
  'get_element_selected_index': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getElementSelectedIndex(i['target'])),
  'get_element_option_count': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getElementOptionCount(i['target'])),
  'get_element_option_at_index': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(_getElementOptionAtIndex(i['target'], LuminaBlueprintFunctionLibrary._n(i['index'], 0))),
  'get_element_option_value': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(_getElementOptionValue(i['target'], LuminaBlueprintFunctionLibrary._n(i['index'], 0))),
  'find_element_option_index': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(_findElementOptionIndex(i['target'], i['option'] as String? ?? '')),
  'find_element_option_index_by_value': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(_findElementOptionIndexByValue(i['target'], i['value'])),
};

/// Tells the widget layer the element changed and, when [selectionChanged],
/// runs the owning widget's On Selection Changed (`Direct`).
void _comboChanged(LuminaActor self, Map<String, Object?> element, {bool selectionChanged = false}) {
  self.world?.getSubsystem<LuminaWidgetSubsystem>()?.notifyChanged();
  if (!selectionChanged) return;
  final instance = LuminaUserWidgets.instanceOfElement(element);
  final name = element['name'];
  if (instance == null || name is! String) return;
  LuminaUserWidgets.fire(instance, name, LuminaWidgetEvents.onSelectionChanged, LuminaComboBoxOptions.selected(element).eventArgs);
}

/// Writes [options] back as the element's runtime list (a string per option
/// whose value is its label, `{label, value}` otherwise), keeping the
/// selected index pointing at the same option.
void _writeOptions(Map<String, Object?> element, List<LuminaComboBoxOption> options) =>
    element[LuminaComboBoxOptions.optionsKey] = <Object?>[for (final o in options) LuminaComboBoxOptions.entry(o)];

/// Add Option: appends [option] standing for [value] (no value: the label).
void _addElementOption(LuminaActor self, Object? target, [String option = '', Object? value]) {
  if (target is! Map<String, Object?>) return;
  final options = [...LuminaComboBoxOptions.of(target), LuminaComboBoxOption(option, value ?? option)];
  _writeOptions(target, options);
  _comboChanged(self, target);
}

/// Remove Option: removes the first option labelled [option]; false when
/// none has that label. Removing the selected option clears the selection.
bool _removeElementOption(LuminaActor self, Object? target, [String option = '']) {
  if (target is! Map<String, Object?>) return false;
  final options = LuminaComboBoxOptions.of(target);
  final index = LuminaComboBoxOptions.indexOfLabel(options, option);
  if (index < 0) return false;
  final selected = LuminaComboBoxOptions.selectedIndex(target, options);
  options.removeAt(index);
  _writeOptions(target, options);
  var changed = false;
  if (selected == index) {
    changed = LuminaComboBoxOptions.writeSelection(target, options, -1);
  } else if (selected > index) {
    target[LuminaComboBoxOptions.selectedIndexKey] = selected - 1;
  }
  _comboChanged(self, target, selectionChanged: changed);
  return true;
}

/// Clear Options: no options and no selection.
void _clearElementOptions(LuminaActor self, Object? target) {
  if (target is! Map<String, Object?>) return;
  target[LuminaComboBoxOptions.selectedKey] = '';
  target[LuminaComboBoxOptions.selectedIndexKey] = -1;
  target[LuminaComboBoxOptions.optionsKey] = <Object?>[];
  _comboChanged(self, target);
}

/// Set Selected Option: selects the first option labelled [option]. A label
/// no option has is still shown (index -1), as before options had values.
void _setElementSelectedOption(LuminaActor self, Object? target, [String option = '']) {
  if (target is! Map<String, Object?>) return;
  final options = LuminaComboBoxOptions.of(target);
  final before = (LuminaComboBoxOptions.selectedLabel(target), LuminaComboBoxOptions.selectedIndex(target, options));
  final index = LuminaComboBoxOptions.indexOfLabel(options, option);
  target[LuminaComboBoxOptions.selectedKey] = option;
  target[LuminaComboBoxOptions.selectedIndexKey] = index;
  _comboChanged(self, target, selectionChanged: before != (option, index));
}

/// Set Selected Value: selects the first option whose value equals [value];
/// nothing changes when none does.
void _setElementSelectedValue(LuminaActor self, Object? target, [Object? value]) {
  if (target is! Map<String, Object?>) return;
  final options = LuminaComboBoxOptions.of(target);
  final index = LuminaComboBoxOptions.indexOfValue(options, value);
  if (index < 0) return;
  _comboChanged(self, target, selectionChanged: LuminaComboBoxOptions.writeSelection(target, options, index));
}

/// Set Selected Index: selects option [index]; -1 clears the selection, any
/// other index outside the options changes nothing.
void _setElementSelectedIndex(LuminaActor self, Object? target, [int index = 0]) {
  if (target is! Map<String, Object?>) return;
  final options = LuminaComboBoxOptions.of(target);
  if (index != -1 && (index < 0 || index >= options.length)) return;
  _comboChanged(self, target, selectionChanged: LuminaComboBoxOptions.writeSelection(target, options, index));
}

/// Clear Selection: nothing selected.
void _clearElementSelection(LuminaActor self, Object? target) => _setElementSelectedIndex(self, target, -1);

/// The selected label ('' for none) — the Dart API Get Selected Option
/// always had.
String _getElementSelectedOption(Object? target) => LuminaComboBoxOptions.selectedLabel(target);

/// Get Selected Option: the selected Label, its Value (null for none) and
/// its Index (-1 for none).
({String returnValue, Object? value, int index}) _getElementSelection(Object? target) {
  final s = LuminaComboBoxOptions.selected(target);
  return (returnValue: s.label, value: s.value, index: s.index);
}

int _getElementSelectedIndex(Object? target) => LuminaComboBoxOptions.selectedIndex(target);

int _getElementOptionCount(Object? target) => LuminaComboBoxOptions.of(target).length;

/// The label of option [index], or '' outside the options.
String _getElementOptionAtIndex(Object? target, [int index = 0]) {
  final options = LuminaComboBoxOptions.of(target);
  return index >= 0 && index < options.length ? options[index].label : '';
}

/// The value of option [index], or null outside the options.
Object? _getElementOptionValue(Object? target, [int index = 0]) {
  final options = LuminaComboBoxOptions.of(target);
  return index >= 0 && index < options.length ? options[index].value : null;
}

int _findElementOptionIndex(Object? target, [String option = '']) =>
    LuminaComboBoxOptions.indexOfLabel(LuminaComboBoxOptions.of(target), option);

int _findElementOptionIndexByValue(Object? target, [Object? value]) =>
    LuminaComboBoxOptions.indexOfValue(LuminaComboBoxOptions.of(target), value);
