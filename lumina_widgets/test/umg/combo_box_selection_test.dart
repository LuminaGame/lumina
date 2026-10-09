import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';
import 'package:vector_math/vector_math_64.dart';

/// A Combo Box bound to a widget instance, as a generated widget wires it:
/// the labels come from the element's options, a pick goes through
/// `selectComboOption` (writing `selectedOption` + `selectedIndex`) and the
/// widget's graph gets On Value Changed (the label) and On Selection Changed
/// (label, value, index, `OnMouseClick`).
class _Recorder extends LuminaUserWidget {
  final List<String> calls = [];

  @override
  void onWidgetEvent(String element, String event, Map<String, Object?> args) => calls.add('$event$args');
}

const _menu = LuminaBlueprintWidgetClass(name: 'WBP_Video', elements: [
  LuminaBlueprintWidgetElement(name: 'Resolution', typeName: 'comboBox', props: {
    'options': [
      {'label': '1280×720', 'value': [1280.0, 720.0], 'type': 'vector2D'},
      {'label': 'Same', 'value': 1, 'type': 'integer'},
      {'label': 'Same', 'value': 2, 'type': 'integer'},
    ],
    'selected': '1280×720',
  }),
]);

void main() {
  setUp(() => LuminaWidgetClassRegistry.register(_menu));
  tearDown(() {
    LuminaUserWidgets.clear();
    LuminaWidgetClassRegistry.clear();
  });

  testWidgets('picking an option writes the selection and fires both events with the value', (tester) async {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final owner = LuminaActor();
    world.persistentLevel.registerActor(owner);
    LuminaUserWidgets.register('WBP_Video', _Recorder.new);
    final instance = LuminaBlueprintFunctionLibrary.createWidget(owner, 'WBP_Video') as Map<String, Object?>;
    final script = LuminaUserWidgets.of(instance)! as _Recorder;
    final res = LuminaBlueprintFunctionLibrary.getWidgetElement(instance, 'Resolution')! as Map<String, Object?>;
    LuminaBlueprintFunctionLibrary.addElementOption(owner, res, '1920×1080', Vector2(1920, 1080));

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Overlay(initialEntries: [
        OverlayEntry(
          builder: (_) => Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 220,
              child: StatefulBuilder(
                builder: (context, setState) => LuminaUmgComboBox(
                  value: LuminaUmgElementBinding.value<String?>(res, 'selectedOption', null),
                  selectedIndex: LuminaComboBoxOptions.selectedIndex(res),
                  options: LuminaUmgElementBinding.options(res, const []),
                  onSelected: (i) => setState(() {
                    final s = LuminaUmgElementBinding.selectComboOption(instance, 'Resolution', null, index: i);
                    LuminaUserWidgets.fire(instance, 'Resolution', 'OnValueChanged', {'value': s.label});
                    LuminaUserWidgets.fire(instance, 'Resolution', 'OnSelectionChanged', s.eventArgs);
                  }),
                ),
              ),
            ),
          ),
        ),
      ]),
    ));
    expect(find.text('1280×720'), findsOneWidget);
    await tester.tap(find.text('1280×720'));
    await tester.pump();
    expect(find.text('1920×1080'), findsOneWidget);
    await tester.tap(find.text('1920×1080'));
    await tester.pump();
    expect(res['selectedOption'], '1920×1080');
    expect(res['selectedIndex'], 3);
    expect(LuminaBlueprintFunctionLibrary.getElementSelection(res), (returnValue: '1920×1080', value: Vector2(1920, 1080), index: 3));
    expect(script.calls, [
      'OnValueChanged{value: 1920×1080}',
      'OnSelectionChanged{selected_item: 1920×1080, value: [1920.0,1080.0], index: 3, select_type: OnMouseClick}',
    ]);

    // Duplicate labels: the index picks the second `Same`, value 2.
    await tester.tap(find.text('1920×1080'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lumina_umg_combo_option_2')));
    await tester.pump();
    expect(LuminaBlueprintFunctionLibrary.getElementSelection(res), (returnValue: 'Same', value: 2, index: 2));
    expect(script.calls.last, 'OnSelectionChanged{selected_item: Same, value: 2, index: 2, select_type: OnMouseClick}');

    // A preview (no instance) reads the designer's options.
    final preview = LuminaUmgElementBinding.selectComboOption(null, 'Resolution', 'Same', fallbackOptions: _menu.elements.first.props['options']);
    expect((preview.label, preview.value, preview.index), ('Same', 1, 1));
    world.cleanup();
  });
}
