import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// The Combo Box nodes: options pair a label with a value of any type, the
/// selection is set by label, value or index, Get Selected Option returns
/// Label, Value and Index, and a changing setter runs the widget's On
/// Selection Changed with `Direct`.
class _Recorder extends LuminaUserWidget {
  final List<String> calls = [];

  @override
  void onWidgetEvent(String element, String event, Map<String, Object?> args) => calls.add('$element.$event$args');
}

const _ids = [
  'add_element_option',
  'remove_element_option',
  'clear_element_options',
  'set_element_selected_option',
  'set_element_selected_value',
  'set_element_selected_index',
  'clear_element_selection',
  'get_element_selected_option',
  'get_element_selected_index',
  'get_element_option_count',
  'get_element_option_at_index',
  'get_element_option_value',
  'find_element_option_index',
  'find_element_option_index_by_value',
];

const _menu = LuminaBlueprintWidgetClass(name: 'WBP_Menu', elements: [
  LuminaBlueprintWidgetElement(name: 'Resolution', typeName: 'comboBox', props: {
    'options': [
      {'label': 'Native'},
      {'label': '1280×720', 'value': [1280.0, 720.0], 'type': 'vector2D'},
    ],
    'selected': 'Native',
  }),
  LuminaBlueprintWidgetElement(name: 'Mode', typeName: 'comboBox', props: {'options': 'Easy,Hard', 'selected': 'Easy'}),
]);

void main() {
  setUp(() => LuminaWidgetClassRegistry.register(_menu));
  tearDown(() {
    LuminaUserWidgets.clear();
    LuminaWidgetClassRegistry.clear();
  });

  Map<String, Object?> element(Map<String, Object?> widget, String name) =>
      LuminaBlueprintFunctionLibrary.getWidgetElement(widget, name)! as Map<String, Object?>;

  test('options carry labels and values; selection by label, value and index; getters and finders', () {
    final actor = LuminaActor();
    final widget = LuminaBlueprintFunctionLibrary.createWidget(actor, 'WBP_Menu') as Map<String, Object?>;
    final res = element(widget, 'Resolution');
    const lib = LuminaBlueprintFunctionLibrary.getElementSelection;

    expect(lib(res), (returnValue: 'Native', value: 'Native', index: 0), reason: 'the designer selection and its value');
    LuminaBlueprintFunctionLibrary.addElementOption(actor, res, '1920×1080', Vector2(1920, 1080));
    LuminaBlueprintFunctionLibrary.addElementOption(actor, res, 'Plain');
    expect(res['options'], [
      'Native',
      {'label': '1280×720', 'value': Vector2(1280, 720)},
      {'label': '1920×1080', 'value': Vector2(1920, 1080)},
      'Plain',
    ], reason: 'the designer literal became its Vector 2D; a value-less option stays a string');
    expect(LuminaBlueprintFunctionLibrary.getElementOptionCount(res), 4);
    expect(LuminaBlueprintFunctionLibrary.getElementOptionAtIndex(res, 2), '1920×1080');
    expect(LuminaBlueprintFunctionLibrary.getElementOptionAtIndex(res, 9), '');
    expect(LuminaBlueprintFunctionLibrary.getElementOptionValue(res, 1), Vector2(1280, 720));
    expect(LuminaBlueprintFunctionLibrary.getElementOptionValue(res, 3), 'Plain');
    expect(LuminaBlueprintFunctionLibrary.getElementOptionValue(res, -1), isNull);
    expect(LuminaBlueprintFunctionLibrary.findElementOptionIndex(res, 'Plain'), 3);
    expect(LuminaBlueprintFunctionLibrary.findElementOptionIndex(res, 'Nope'), -1);
    expect(LuminaBlueprintFunctionLibrary.findElementOptionIndexByValue(res, Vector2(1920, 1080)), 2);
    expect(LuminaBlueprintFunctionLibrary.findElementOptionIndexByValue(res, Vector2(1, 1)), -1);

    LuminaBlueprintFunctionLibrary.setElementSelectedValue(actor, res, Vector2(1280, 720));
    expect(lib(res), (returnValue: '1280×720', value: Vector2(1280, 720), index: 1));
    LuminaBlueprintFunctionLibrary.setElementSelectedValue(actor, res, Vector2(5, 5));
    expect(lib(res).index, 1, reason: 'an unknown value changes nothing');
    LuminaBlueprintFunctionLibrary.setElementSelectedIndex(actor, res, 2);
    expect(LuminaBlueprintFunctionLibrary.getElementSelectedOption(res), '1920×1080');
    expect(LuminaBlueprintFunctionLibrary.getElementSelectedIndex(res), 2);
    LuminaBlueprintFunctionLibrary.setElementSelectedIndex(actor, res, 7);
    expect(LuminaBlueprintFunctionLibrary.getElementSelectedIndex(res), 2, reason: 'out of range changes nothing');
    LuminaBlueprintFunctionLibrary.setElementSelectedOption(actor, res, 'Plain');
    expect(lib(res), (returnValue: 'Plain', value: 'Plain', index: 3));
    LuminaBlueprintFunctionLibrary.setElementSelectedOption(actor, res, 'Custom');
    expect(lib(res), (returnValue: 'Custom', value: null, index: -1), reason: 'a label no option has is still shown');

    LuminaBlueprintFunctionLibrary.setElementSelectedIndex(actor, res, 2);
    expect(LuminaBlueprintFunctionLibrary.removeElementOption(actor, res, 'Native'), isTrue);
    expect(lib(res), (returnValue: '1920×1080', value: Vector2(1920, 1080), index: 1), reason: 'the index follows the option');
    expect(LuminaBlueprintFunctionLibrary.removeElementOption(actor, res, 'Native'), isFalse);
    expect(LuminaBlueprintFunctionLibrary.removeElementOption(actor, res, '1920×1080'), isTrue);
    expect(lib(res), (returnValue: '', value: null, index: -1), reason: 'removing the selected option clears the selection');

    LuminaBlueprintFunctionLibrary.setElementSelectedIndex(actor, res, 0);
    LuminaBlueprintFunctionLibrary.clearElementSelection(actor, res);
    expect(lib(res), (returnValue: '', value: null, index: -1));
    LuminaBlueprintFunctionLibrary.clearElementOptions(actor, res);
    expect(LuminaBlueprintFunctionLibrary.getElementOptionCount(res), 0);

    final mode = element(widget, 'Mode');
    expect(LuminaBlueprintFunctionLibrary.getElementSelectedOption(mode), 'Easy', reason: 'the legacy designer string');
    LuminaBlueprintFunctionLibrary.addElementOption(actor, mode, 'Insane');
    expect(mode['options'], ['Easy', 'Hard', 'Insane']);
  });

  test('a setter that changes the selection runs On Selection Changed (Direct) once; an unchanged one does not', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final owner = LuminaActor();
    world.persistentLevel.registerActor(owner);
    world.beginPlay();
    LuminaUserWidgets.register('WBP_Menu', _Recorder.new);
    final widget = LuminaBlueprintFunctionLibrary.createWidget(owner, 'WBP_Menu') as Map<String, Object?>;
    final script = LuminaUserWidgets.of(widget)! as _Recorder;
    final res = element(widget, 'Resolution');
    expect(LuminaUserWidgets.instanceOfElement(res), same(widget));

    LuminaBlueprintFunctionLibrary.setElementSelectedIndex(owner, res, 1);
    LuminaBlueprintFunctionLibrary.setElementSelectedIndex(owner, res, 1);
    LuminaBlueprintFunctionLibrary.setElementSelectedValue(owner, res, Vector2(1280, 720));
    LuminaBlueprintFunctionLibrary.setElementSelectedOption(owner, res, 'Native');
    LuminaBlueprintFunctionLibrary.clearElementSelection(owner, res);
    LuminaBlueprintFunctionLibrary.addElementOption(owner, res, 'More');
    expect(script.calls, [
      'Resolution.OnSelectionChanged{selected_item: 1280×720, value: [1280.0,720.0], index: 1, select_type: Direct}',
      'Resolution.OnSelectionChanged{selected_item: Native, value: Native, index: 0, select_type: Direct}',
      'Resolution.OnSelectionChanged{selected_item: , value: null, index: -1, select_type: Direct}',
    ]);
    world.cleanup();
  });

  test('every Combo Box node has a spec, a VM function and a call shape; wildcard values take a type', () {
    for (final id in _ids) {
      final spec = LuminaBlueprintNodeLibrary.builtIn(id);
      expect(spec, isNotNull, reason: id);
      expect(spec!.category, 'Widget|Combo Box', reason: id);
      expect(spec.keywords, containsAll(['combo', 'dropdown']), reason: id);
      expect(spec.inputs.firstWhere((p) => p.id == 'target').objectClass, 'WidgetElement:comboBox', reason: id);
      expect(LuminaBlueprintFunctionLibrary.builtInFunctions[id], isNotNull, reason: id);
      expect(LuminaBlueprintFunctionLibrary.callShapes[id], isNotNull, reason: id);
    }
    final add = LuminaBlueprintNodeLibrary.builtIn('add_element_option')!;
    expect([for (final p in add.inputs) if (p.type != LuminaPinType.exec) (p.id, p.name, p.type)], [
      ('target', 'Target', LuminaPinType.object),
      ('option', 'Label', LuminaPinType.string),
      ('value', 'Value', LuminaPinType.wildcard),
    ]);
    final get = LuminaBlueprintNodeLibrary.builtIn('get_element_selected_option')!;
    expect([for (final p in get.outputs) (p.id, p.name, p.type)], [
      ('return_value', 'Label', LuminaPinType.string),
      ('value', 'Value', LuminaPinType.wildcard),
      ('index', 'Index', LuminaPinType.integer),
    ]);

    const context = LuminaBlueprintTypeContext();
    final typed = LuminaBlueprintNodeLibrary.place('get_element_selected_option', nodeId: 'g', literals: {'type': 'vector2D'});
    expect(LuminaBlueprintNodeLibrary.pinsOf(typed, context)!.outputs.firstWhere((p) => p.id == 'value').type, LuminaPinType.vector2D);
    for (final id in ['add_element_option', 'set_element_selected_value', 'get_element_option_value', 'find_element_option_index_by_value']) {
      final n = LuminaBlueprintNodeLibrary.place(id, nodeId: id, literals: {'type': 'integer'});
      expect(LuminaBlueprintNodeLibrary.adoptsWildcardType(n), isTrue, reason: id);
      final pins = LuminaBlueprintNodeLibrary.pinsOf(n, context)!;
      expect([...pins.inputs, ...pins.outputs].where((p) => p.type == LuminaPinType.wildcard), isEmpty, reason: id);
    }
    expect(LuminaBlueprintNodeLibrary.engineEnumValues('ESelectInfo'), LuminaComboBoxOptions.selectInfos);
  });

  test('On Selection Changed: listed for combo boxes after On Value Changed, with Selected Item, Value, Index, Select Type', () {
    expect(LuminaWidgetEvents.forType('comboBox'), ['OnValueChanged', 'OnSelectionChanged']);
    expect(LuminaWidgetEvents.forType('shadcnSelect'), ['OnValueChanged']);
    final widget = LuminaWidgetBlueprintDocument(widgetClass: 'WBP_Menu', variables: _menu.elements);
    final context = LuminaBlueprintTypeContext.forWidget(widget, widgetClasses: const [_menu]);
    LuminaBlueprintNode place(Map<String, dynamic> literals) =>
        LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.eventWidgetElement, nodeId: 'e', literals: literals, context: context);

    final untyped = place({'element': 'Resolution', 'event': 'OnSelectionChanged'});
    expect(untyped.title, 'On Selection Changed (Resolution)');
    final outs = LuminaBlueprintNodeLibrary.pinsOf(untyped, context)!.outputs;
    expect([for (final p in outs) (p.id, p.type)], [
      ('exec_out', LuminaPinType.exec),
      ('selected_item', LuminaPinType.string),
      ('value', LuminaPinType.wildcard),
      ('index', LuminaPinType.integer),
      ('select_type', LuminaPinType.enumeration),
    ]);
    expect(outs.last.enumName, 'ESelectInfo');
    expect(LuminaBlueprintNodeLibrary.adoptsWildcardType(untyped), isTrue);
    final typed = place({'element': 'Resolution', 'event': 'OnSelectionChanged', 'type': 'vector2D'});
    expect(LuminaBlueprintNodeLibrary.pinsOf(typed, context)!.outputs.firstWhere((p) => p.id == 'value').type, LuminaPinType.vector2D);
    final valueChanged = place({'element': 'Resolution', 'event': 'OnValueChanged'});
    expect(LuminaBlueprintNodeLibrary.adoptsWildcardType(valueChanged), isFalse);
    expect(LuminaBlueprintNodeLibrary.pinsOf(valueChanged, context)!.outputs.map((p) => p.id), ['exec_out', 'value']);
  });

  test('a graph saved before options had values loads and runs unchanged in the VM', () {
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_OldMenu');
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    doc.eventGraph.nodes.addAll([
      place('event_beginplay', 'begin'),
      place('create_widget', 'create', {'class': 'WBP_Menu'}),
      place(LuminaBlueprintNodeLibrary.getWidgetElement, 'mode', {'element': 'Mode'}),
      place('clear_element_options', 'clear'),
      place('add_element_option', 'add_low', {'option': 'Low'}),
      place('add_element_option', 'add_high', {'option': 'High'}),
      place('set_element_selected_option', 'select', {'option': 'High'}),
      place('get_element_selected_option', 'selected'),
      place('print_string', 'say', {'print_to_screen': false}),
    ]);
    const chain = ['begin', 'create', 'clear', 'add_low', 'add_high', 'select', 'say'];
    for (var k = 0; k + 1 < chain.length; k++) {
      doc.eventGraph.wires.add(wire(chain[k], 'exec_out', chain[k + 1], 'exec_in'));
    }
    for (final user in ['clear', 'add_low', 'add_high', 'select', 'selected']) {
      doc.eventGraph.wires.add(wire('mode', 'return_value', user, 'target'));
    }
    doc.eventGraph.wires
      ..add(wire('create', 'return_value', 'mode', 'target'))
      ..add(wire('selected', 'return_value', 'say', 'in_string'));

    // As saved before: Add Option had no Value pin, Get Selected Option one
    // string output.
    final json = doc.toJson();
    for (final node in (json['eventGraph'] as Map)['nodes'] as List) {
      final m = node as Map<String, dynamic>;
      if (m['registryId'] == 'add_element_option') {
        m['inputs'] = [for (final p in m['inputs'] as List) if ((p as Map)['id'] != 'value') p];
      }
      if (m['registryId'] == 'get_element_selected_option') {
        m['outputs'] = [for (final p in m['outputs'] as List) if ((p as Map)['id'] == 'return_value') {...p, 'name': 'Return Value'}];
      }
    }
    final loaded = LuminaBlueprintDocument.fromJson(json);
    expect(validateBlueprint(loaded, className: 'BP_OldMenu').where((d) => d.isError).map((d) => d.message), isEmpty);

    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = LuminaBlueprintClass.fromDocument(loaded, name: 'BP_OldMenu').instantiate();
    final trace = <LuminaBlueprintTraceEvent>[];
    (actor as LuminaBlueprintRuntime).trace = trace.add;
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    world.tick(1 / 60);
    expect([for (final t in trace) if (t.printed != null) t.printed], ['High']);
    world.cleanup();
  });
}
