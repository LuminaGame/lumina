import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// An editor panel graph on Construct:
/// Make Json Object {name: "Barrel", count: 3} → Count = Json Get Number count,
/// Text = Json To String; Parse Json (Input) → Parsed / Failed (Error).
LuminaWidgetBlueprintDocument _panel() {
  final doc = LuminaWidgetBlueprintDocument(
    widgetClass: 'EPW_Json',
    blueprint: LuminaBlueprintDocument(variables: const [
      LuminaBlueprintVariable(name: 'Count', typeName: 'Float', defaultValue: 0.0),
      LuminaBlueprintVariable(name: 'Text', typeName: 'String', defaultValue: ''),
      LuminaBlueprintVariable(name: 'Input', typeName: 'String', defaultValue: '{not json'),
      LuminaBlueprintVariable(name: 'Outcome', typeName: 'String', defaultValue: ''),
    ]),
  );
  final c = LuminaBlueprintTypeContext.forEditorPanel(doc);
  LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: c);
  var n = 0;
  LuminaBlueprintWire w(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
  final g = doc.blueprint.eventGraph;
  g.nodes.addAll([
    p(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 'construct'),
    p(LuminaJsonBlueprintNodes.makeObject, 'make', {
      'keys': ['name', 'count'],
      'values': ['Barrel', 3],
    }),
    p(LuminaJsonBlueprintNodes.getNumber, 'count', {'field': 'count'}),
    p('variable_set', 'set_count', {'variable': 'Count'}),
    p(LuminaJsonBlueprintNodes.toText, 'text'),
    p('variable_set', 'set_text', {'variable': 'Text'}),
    p('variable_get', 'input', {'variable': 'Input'}),
    p(LuminaJsonBlueprintNodes.parse, 'parse'),
    p('variable_set', 'parsed', {'variable': 'Outcome', 'value': 'parsed'}),
    p('variable_set', 'failed', {'variable': 'Outcome'}),
  ]);
  g.wires.addAll([
    w('construct', 'exec_out', 'set_count', 'exec_in'),
    w('make', 'return_value', 'count', 'json'),
    w('count', 'return_value', 'set_count', 'value'),
    w('set_count', 'exec_out', 'set_text', 'exec_in'),
    w('make', 'return_value', 'text', 'json'),
    w('text', 'return_value', 'set_text', 'value'),
    w('set_text', 'exec_out', 'parse', 'exec_in'),
    w('input', 'value', 'parse', 'text'),
    w('parse', 'exec_out', 'parsed', 'exec_in'),
    w('parse', 'failed', 'failed', 'exec_in'),
    w('parse', 'error', 'failed', 'value'),
  ]);
  return doc;
}

void main() {
  setUp(LuminaJsonBlueprintNodes.ensureRegistered);
  tearDown(() {
    LuminaBlueprintFunctionRegistry.clear();
    LuminaUserWidgets.editor.clear();
  });

  test('Make Json Object, Json Get Number, Json To String and Parse Json run in an editor panel', () {
    final cls = LuminaBlueprintClass.forEditorPanel(_panel());
    expect(cls.diagnostics.where((d) => d.isError), isEmpty);
    LuminaUserWidgets.editor.register('EPW_Json', cls.instantiateUserWidget);
    final world = LuminaWorld(worldType: LuminaWorldType.game)..beginPlay();
    final instance = <String, Object?>{'class': 'EPW_Json', 'inViewport': true, 'elements': <String, Object?>{}};
    final script = LuminaUserWidgets.editor.attach(world, instance)! as LuminaBlueprintUserWidget;
    LuminaUserWidgets.addedToViewport(instance);

    expect(script.variables['Count'], 3.0);
    expect(script.variables['Text'], '{"name":"Barrel","count":3}');
    expect(script.variables['Outcome'], isNot('parsed'), reason: 'invalid text takes the Failed branch');
    expect(script.variables['Outcome'], isNotEmpty, reason: 'Failed carries the parse error');
  });

  test('Json nodes are editor-only: a game graph cannot use them', () {
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
    doc.eventGraph.nodes.add(LuminaBlueprintNodeLibrary.place(LuminaJsonBlueprintNodes.makeArray, nodeId: 'a'));
    expect(validateBlueprint(doc).where((d) => d.isError).map((d) => d.message),
        contains(contains('can only be placed in an editor panel')));
  });

  test('Json Set Field and Has Field copy, never mutate', () {
    final f = LuminaBlueprintFunctionLibrary.functions;
    final original = <String, Object?>{'a': 1};
    final set = f[LuminaJsonBlueprintNodes.setField]!(LuminaBlueprintCallContext(LuminaActor()),
        {'json': original, 'field': 'b', 'value': 'x'})['return_value'] as Map;
    expect(set, {'a': 1, 'b': 'x'});
    expect(original, {'a': 1});
    expect(
        f[LuminaJsonBlueprintNodes.hasField]!(LuminaBlueprintCallContext(LuminaActor()), {'json': set, 'field': 'b'})['return_value'],
        isTrue);
  });
}
