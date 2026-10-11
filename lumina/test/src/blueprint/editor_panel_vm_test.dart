import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

const LuminaBlueprintNodeSpec _fetch = LuminaBlueprintNodeSpec(
  id: 'editor_test_fetch',
  title: 'Fetch',
  category: 'Editor|Test',
  kind: LuminaBlueprintNodeKind.latent,
  headerColor: 0xFF1565C0,
  inputs: [
    LuminaBlueprintPinSpec('exec_in', 'Exec In', LuminaPinType.exec),
    LuminaBlueprintPinSpec('what', 'What', LuminaPinType.string, defaultValue: ''),
  ],
  outputs: [
    LuminaBlueprintPinSpec('exec_out', 'Exec Out', LuminaPinType.exec),
    LuminaBlueprintPinSpec('completed', 'Completed', LuminaPinType.exec),
    LuminaBlueprintPinSpec('failed', 'Failed', LuminaPinType.exec),
    LuminaBlueprintPinSpec('result', 'Result', LuminaPinType.string, defaultValue: ''),
  ],
  editorOnly: true,
);

/// Construct → Fetch (What) → Completed: Result = result; Failed: Result = "failed".
/// A custom event `Spin` runs a For Loop 0..1e9 with a Set in its body.
LuminaWidgetBlueprintDocument _panel() {
  final doc = LuminaWidgetBlueprintDocument(
    widgetClass: 'EPW_Vm',
    blueprint: LuminaBlueprintDocument(variables: const [
      LuminaBlueprintVariable(name: 'Result', typeName: 'String', defaultValue: ''),
      LuminaBlueprintVariable(name: 'I', typeName: 'Int', defaultValue: 0),
    ]),
  );
  final c = LuminaBlueprintTypeContext.forEditorPanel(doc);
  LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: c);
  var n = 0;
  LuminaBlueprintWire w(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
  doc.blueprint.eventGraph
    ..nodes.addAll([
      p(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 'construct'),
      p('editor_test_fetch', 'fetch', {'what': 'status'}),
      p('variable_set', 'ok', {'variable': 'Result'}),
      p('variable_set', 'bad', {'variable': 'Result', 'value': 'failed'}),
      p(LuminaBlueprintNodeLibrary.customEvent, 'spin', {'name': 'Spin'}),
      p('for_loop', 'loop', {'first_index': 0, 'last_index': 1000000000}),
      p('variable_set', 'count', {'variable': 'I'}),
    ])
    ..wires.addAll([
      w('construct', 'exec_out', 'fetch', 'exec_in'),
      w('fetch', 'completed', 'ok', 'exec_in'),
      w('fetch', 'result', 'ok', 'value'),
      w('fetch', 'failed', 'bad', 'exec_in'),
      w('spin', 'exec_out', 'loop', 'exec_in'),
      w('loop', 'loop_body', 'count', 'exec_in'),
      w('loop', 'index', 'count', 'value'),
    ]);
  return doc;
}

void main() {
  late void Function(String pin, Map<String, Object?> outputs) pending;
  late Map<String, Object?> seenInputs;

  setUp(() {
    LuminaBlueprintFunctionRegistry.registerLatent(_fetch, (context, inputs, resume) {
      seenInputs = inputs;
      pending = resume;
    });
  });
  tearDown(() {
    LuminaBlueprintFunctionRegistry.clear();
    LuminaUserWidgets.editor.clear();
  });

  LuminaBlueprintUserWidget start() {
    final cls = LuminaBlueprintClass.forEditorPanel(_panel());
    expect(cls.diagnostics.where((d) => d.isError), isEmpty);
    LuminaUserWidgets.editor.register('EPW_Vm', cls.instantiateUserWidget);
    final world = LuminaWorld(worldType: LuminaWorldType.game)..beginPlay();
    final instance = <String, Object?>{'class': 'EPW_Vm', 'inViewport': true, 'elements': <String, Object?>{}};
    final script = LuminaUserWidgets.editor.attach(world, instance)! as LuminaBlueprintUserWidget;
    LuminaUserWidgets.addedToViewport(instance);
    return script;
  }

  test('a registered latent node resumes the graph at Completed or Failed later', () {
    final script = start();
    expect(seenInputs['what'], 'status');
    expect(script.variables['Result'], '', reason: 'nothing ran yet');
    pending('completed', {'result': 'Ready'});
    expect(script.variables['Result'], 'Ready');
    pending('failed', const {});
    expect(script.variables['Result'], 'failed');
  });

  test('the node budget stops a runaway event and reports it', () {
    final script = start();
    final stopped = <String>[];
    script
      ..maxNodesPerEvent = 1000000
      ..onEventStopped = (event, message) => stopped.add(event);
    final watch = Stopwatch()..start();
    script.callBlueprint('Spin', const {});
    expect(stopped, ['Spin']);
    expect(watch.elapsedMilliseconds, lessThan(5000));
  });

  test('the time budget stops a long event with a "ran too long" message', () {
    final script = start();
    final messages = <String>[];
    script
      ..maxNodesPerEvent = 1 << 40
      ..maxEventDuration = const Duration(milliseconds: 50)
      ..onEventStopped = (event, message) => messages.add(message);
    final watch = Stopwatch()..start();
    script.callBlueprint('Spin', const {});
    expect(watch.elapsedMilliseconds, lessThan(1000));
    expect(messages.single, allOf(startsWith('Stopped:'), contains('Spin'), contains('50 ms')));
  });
}
