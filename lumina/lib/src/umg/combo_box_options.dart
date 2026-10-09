import 'package:lumina/src/blueprint/blueprint_model.dart';

/// One option of a Combo Box: the [label] the player sees and the [value] it
/// stands for (a `Vector2` resolution, an enum name, an actor, …). An option
/// added without a value stands for its label.
class LuminaComboBoxOption {
  const LuminaComboBoxOption(this.label, this.value);

  /// An option whose value is its label.
  const LuminaComboBoxOption.text(String label) : this(label, label);

  final String label;
  final Object? value;

  @override
  bool operator ==(Object other) =>
      other is LuminaComboBoxOption && other.label == label && LuminaComboBoxOptions.valueEquals(other.value, value);

  @override
  int get hashCode => label.hashCode;

  @override
  String toString() => 'LuminaComboBoxOption($label, $value)';
}

/// A Combo Box selection as On Selection Changed delivers it: the selected
/// [label] (Selected Item), its [value], its [index] (-1 for none) and how it
/// was made ([selectType], one of [LuminaComboBoxOptions.selectInfos]).
class LuminaComboBoxSelection {
  const LuminaComboBoxSelection(this.label, this.value, this.index, [this.selectType = LuminaComboBoxOptions.direct]);

  /// No option selected.
  static const LuminaComboBoxSelection none = LuminaComboBoxSelection('', null, -1);

  final String label;
  final Object? value;
  final int index;
  final String selectType;

  /// The outputs of On Selection Changed, by pin id.
  Map<String, Object?> get eventArgs => {'selected_item': label, 'value': value, 'index': index, 'select_type': selectType};

  @override
  String toString() => 'LuminaComboBoxSelection($label, $value, $index, $selectType)';
}

/// The options and the selection of a Combo Box element state map (the map
/// `Create Widget` seeds from the designer and the element nodes write).
///
/// Stored forms, all read by [parse]:
/// - the designer's legacy comma-separated string (`'Low,High'`);
/// - a list whose entries are a string (label = value) or a map
///   `{label, value}` (what Add Option writes with a value);
/// - a designer entry `{label, value, type}`, whose literal `value` is
///   converted to the pin type named by `type` (`vector2D` → `Vector2`);
///   without `value` the option stands for its label.
///
/// The selection is `selectedOption` (the label; the designer seeded it as
/// `selected`) plus `selectedIndex`, which tells duplicate labels apart.
abstract final class LuminaComboBoxOptions {
  /// The element state key of the options.
  static const String optionsKey = 'options';

  /// The element state key of the selected label.
  static const String selectedKey = 'selectedOption';

  /// The designer's key of the selected label.
  static const String designerSelectedKey = 'selected';

  /// The element state key of the selected index.
  static const String selectedIndexKey = 'selectedIndex';

  /// `ESelectInfo`: how a selection was made.
  static const String selectInfoEnum = 'ESelectInfo';
  static const String direct = 'Direct';
  static const String onKeyPress = 'OnKeyPress';
  static const String onNavigation = 'OnNavigation';
  static const String onMouseClick = 'OnMouseClick';
  static const List<String> selectInfos = [direct, onKeyPress, onNavigation, onMouseClick];

  /// Every option of a stored [stored] value (see the class doc).
  static List<LuminaComboBoxOption> parse(Object? stored) {
    if (stored is String) {
      return [
        for (final o in stored.split(',').map((o) => o.trim()))
          if (o.isNotEmpty) LuminaComboBoxOption.text(o),
      ];
    }
    if (stored is! List) return const [];
    return [for (final e in stored) ?_entryOf(e)];
  }

  static LuminaComboBoxOption? _entryOf(Object? e) {
    if (e == null) return null;
    if (e is LuminaComboBoxOption) return e;
    if (e is Map) {
      final label = '${e['label'] ?? ''}';
      if (!e.containsKey('value')) return LuminaComboBoxOption.text(label);
      final type = LuminaPinType.parse(e['type'] as String?);
      final value = e['value'];
      return LuminaComboBoxOption(label, type == null ? value : luminaBlueprintLiteral(type, value));
    }
    return LuminaComboBoxOption.text('$e');
  }

  /// The labels of [stored].
  static List<String> labels(Object? stored) => [for (final o in parse(stored)) o.label];

  /// The stored entry of [option] in an element state's list: the label
  /// alone when the value is the label, else `{label, value}`.
  static Object entry(LuminaComboBoxOption option) =>
      option.value is String && option.value == option.label ? option.label : <String, Object?>{'label': option.label, 'value': option.value};

  /// A designer document entry: a literal [value] of pin type [type]
  /// (`vector2D`, `integer`, …); a null [type] or [value] stands for the label.
  static Map<String, Object?> designerEntry(String label, {Object? value, String? type}) => {
        'label': label,
        if (type != null && value != null) 'value': value,
        if (type != null && value != null) 'type': type,
      };

  /// A designer document's options in the list form: the legacy
  /// comma-separated string becomes one `{label}` entry per option; a list is
  /// kept (string entries become `{label}`).
  static List<Map<String, Object?>> migrateDesignerOptions(Object? stored) {
    if (stored is String) return [for (final l in labels(stored)) designerEntry(l)];
    if (stored is! List) return [];
    return [
      for (final e in stored)
        if (e is Map) {for (final k in e.entries) '${k.key}': k.value} else if (e != null) designerEntry('$e'),
    ];
  }

  /// The options of element state [element].
  static List<LuminaComboBoxOption> of(Object? element) => element is Map ? parse(element[optionsKey]) : const [];

  /// The selected label of [element] ('' for none).
  static String selectedLabel(Object? element) {
    if (element is! Map) return '';
    final v = element[selectedKey] ?? element[designerSelectedKey];
    return v == null ? '' : '$v';
  }

  /// The selected index of [element]: the stored index while it still points
  /// at the selected label, else the first option with that label, else -1.
  static int selectedIndex(Object? element, [List<LuminaComboBoxOption>? options]) {
    if (element is! Map) return -1;
    final all = options ?? of(element);
    final label = selectedLabel(element);
    final stored = element[selectedIndexKey];
    if (stored is int && stored >= 0 && stored < all.length && all[stored].label == label) return stored;
    if (label.isEmpty) return -1;
    return all.indexWhere((o) => o.label == label);
  }

  /// The selection of [element] ([LuminaComboBoxSelection.none] when nothing
  /// is selected; a label no option has keeps its label, value null, index -1).
  static LuminaComboBoxSelection selected(Object? element, [String selectType = direct]) {
    final all = of(element);
    final index = selectedIndex(element, all);
    if (index < 0) {
      final label = selectedLabel(element);
      return label.isEmpty ? LuminaComboBoxSelection.none : LuminaComboBoxSelection(label, null, -1, selectType);
    }
    return LuminaComboBoxSelection(all[index].label, all[index].value, index, selectType);
  }

  /// Writes the selection of option [index] of [options] (-1: none) into
  /// [element]; returns whether the selection changed.
  static bool writeSelection(Map<String, Object?> element, List<LuminaComboBoxOption> options, int index) {
    final before = (selectedLabel(element), selectedIndex(element, options));
    final label = index >= 0 && index < options.length ? options[index].label : '';
    final i = index >= 0 && index < options.length ? index : -1;
    element[selectedKey] = label;
    element[selectedIndexKey] = i;
    return before != (label, i);
  }

  /// The index of the first option labelled [label], or -1.
  static int indexOfLabel(List<LuminaComboBoxOption> options, String label) => options.indexWhere((o) => o.label == label);

  /// The index of the first option whose value equals [value], or -1.
  static int indexOfValue(List<LuminaComboBoxOption> options, Object? value) =>
      options.indexWhere((o) => valueEquals(o.value, value));

  /// Whether two option values are equal: by content for lists and maps
  /// (colours, transforms), by `==` otherwise (vectors and rotators compare
  /// their components; numbers compare as numbers).
  static bool valueEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is num && b is num) return a == b;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!valueEquals(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k) || !valueEquals(a[k], b[k])) return false;
      }
      return true;
    }
    return a == b;
  }
}
