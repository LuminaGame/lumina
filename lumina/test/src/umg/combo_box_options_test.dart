import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Combo Box options: every stored form reads as (label, value) pairs, the
/// designer's legacy string migrates to the list form, and the selection is
/// the selected label plus an index that tells duplicate labels apart.
void main() {
  test('parse reads the legacy string, plain labels and labelled values', () {
    expect(LuminaComboBoxOptions.parse('A, B,,C'),
        const [LuminaComboBoxOption.text('A'), LuminaComboBoxOption.text('B'), LuminaComboBoxOption.text('C')]);
    final options = LuminaComboBoxOptions.parse([
      'x',
      {'label': '1920×1080', 'value': [1920, 1080], 'type': 'vector2D'},
      {'label': 'Fast', 'value': 2, 'type': 'integer'},
      {'label': 'Actor', 'value': LuminaActor()},
      {'label': 'Bare'},
    ]);
    expect(options.map((o) => o.label), ['x', '1920×1080', 'Fast', 'Actor', 'Bare']);
    expect(options[0].value, 'x');
    expect(options[1].value, Vector2(1920, 1080));
    expect(options[2].value, 2);
    expect(options[3].value, isA<LuminaActor>());
    expect(options[4].value, 'Bare', reason: 'no value: the option stands for its label');
    expect(LuminaComboBoxOptions.parse(null), isEmpty);
    expect(LuminaComboBoxOptions.labels('Low,High'), ['Low', 'High']);
  });

  test('entries stay plain strings unless an option carries its own value', () {
    expect(LuminaComboBoxOptions.entry(const LuminaComboBoxOption.text('Easy')), 'Easy');
    expect(LuminaComboBoxOptions.entry(LuminaComboBoxOption('720p', Vector2(1280, 720))), {'label': '720p', 'value': Vector2(1280, 720)});
    expect(LuminaComboBoxOptions.designerEntry('Low'), {'label': 'Low'});
    expect(LuminaComboBoxOptions.designerEntry('4K', value: [3840.0, 2160.0], type: 'vector2D'),
        {'label': '4K', 'value': [3840.0, 2160.0], 'type': 'vector2D'});
  });

  test('migrateDesignerOptions turns the legacy string into the list form and keeps lists', () {
    expect(LuminaComboBoxOptions.migrateDesignerOptions('Low,High'), [
      {'label': 'Low'},
      {'label': 'High'},
    ]);
    expect(LuminaComboBoxOptions.migrateDesignerOptions([
      'Old',
      {'label': 'Fast', 'value': 2, 'type': 'integer'},
    ]), [
      {'label': 'Old'},
      {'label': 'Fast', 'value': 2, 'type': 'integer'},
    ]);
    expect(LuminaComboBoxOptions.migrateDesignerOptions(null), isEmpty);
  });

  test('valueEquals compares vectors, numbers, lists and maps by content', () {
    expect(LuminaComboBoxOptions.valueEquals(Vector2(1, 2), Vector2(1, 2)), isTrue);
    expect(LuminaComboBoxOptions.valueEquals(Vector3(1, 2, 3), Vector3(1, 2, 4)), isFalse);
    expect(LuminaComboBoxOptions.valueEquals(2, 2.0), isTrue);
    expect(LuminaComboBoxOptions.valueEquals([1.0, 0.0, 0.0, 1.0], [1.0, 0.0, 0.0, 1.0]), isTrue);
    expect(LuminaComboBoxOptions.valueEquals({'a': [1]}, {'a': [1]}), isTrue);
    expect(LuminaComboBoxOptions.valueEquals('DLSS', 'FSR3'), isFalse);
  });

  test('the selection: designer label, stored index for duplicates, writes report a change', () {
    final element = <String, Object?>{
      'options': ['Low', 'High', 'High'],
      'selected': 'High',
    };
    expect(LuminaComboBoxOptions.selectedLabel(element), 'High', reason: 'the designer key seeds the selection');
    expect(LuminaComboBoxOptions.selectedIndex(element), 1);
    final options = LuminaComboBoxOptions.of(element);
    expect(LuminaComboBoxOptions.writeSelection(element, options, 2), isTrue);
    expect(LuminaComboBoxOptions.selectedIndex(element), 2, reason: 'the index tells the duplicate labels apart');
    expect(LuminaComboBoxOptions.writeSelection(element, options, 2), isFalse);
    final s = LuminaComboBoxOptions.selected(element, LuminaComboBoxOptions.onMouseClick);
    expect((s.label, s.value, s.index, s.selectType), ('High', 'High', 2, 'OnMouseClick'));
    expect(s.eventArgs, {'selected_item': 'High', 'value': 'High', 'index': 2, 'select_type': 'OnMouseClick'});
    expect(LuminaComboBoxOptions.writeSelection(element, options, -1), isTrue);
    expect(LuminaComboBoxOptions.selected(element).index, -1);
    expect(LuminaComboBoxOptions.selectInfos, ['Direct', 'OnKeyPress', 'OnNavigation', 'OnMouseClick']);
  });
}
