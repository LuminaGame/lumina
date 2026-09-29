import 'package:lumina/lumina.dart';

/// BP_LevelLoader, the loading-screen flow as a Blueprint.
///
/// - BeginPlay prints `loader ready`.
/// - `StartLoading`: Load Level `L_Second`. On Progress stores Percent in
///   `LastPercent`, counts the updates in `Updates` and prints the content
///   that finished; its On Progress Event is bound to the custom event
///   `OnLoadProgress` (Percent, TotalCount, LoadedCount, CurrentContent),
///   which stores Percent in `EventPercent` and prints `event <content>`.
///   On Success prints whether Is Level Loaded says so, then Change Level
///   `L_Second`, whose On Success prints `changed`; On Error prints the
///   error.
/// - `TryBadLevel`: Change Level `L_Nowhere`; On Error prints `bad: <error>`.
/// - `LoadAndGo`: Load And Change Level `L_First`; On Success prints `went`.
/// - `StopLoading`: Cancel Level Load (every level).
int _wires = 0;
LuminaBlueprintWire _w(String from, String fromPin, String to, String toPin) =>
    LuminaBlueprintWire(id: 'lw${_wires++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

LuminaBlueprintDocument levelLoadBlueprint() {
  _wires = 0;
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
    LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
  ], variables: const [
    LuminaBlueprintVariable(name: 'LastPercent', typeName: 'Float', defaultValue: 0.0),
    LuminaBlueprintVariable(name: 'EventPercent', typeName: 'Float', defaultValue: 0.0),
    LuminaBlueprintVariable(name: 'Updates', typeName: 'Int', defaultValue: 0),
  ]);
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_LevelLoader');
  LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  const quiet = {'print_to_screen': false};
  doc.eventGraph.nodes.addAll([
    p('event_beginplay', 'begin'),
    p('print_string', 'say_ready', {...quiet, 'in_string': 'loader ready'}),
    p('custom_event', 'start', {'name': 'StartLoading'}),
    p(LuminaBlueprintNodeLibrary.loadLevel, 'load', {'level_name': 'L_Second'}),
    p(LuminaBlueprintNodeLibrary.variableSet, 'set_pct', {'variable': 'LastPercent'}),
    p(LuminaBlueprintNodeLibrary.variableGet, 'get_updates', {'variable': 'Updates'}),
    p('int_add', 'plus_one', {'b': 1}),
    p(LuminaBlueprintNodeLibrary.variableSet, 'set_updates', {'variable': 'Updates'}),
    p('print_string', 'say_item', quiet),
    p('is_level_loaded', 'loaded', {'level_name': 'L_Second'}),
    p('bool_to_string', 'loaded_text'),
    p('append', 'loaded_line', {'a': 'loaded '}),
    p('print_string', 'say_loaded', quiet),
    p(LuminaBlueprintNodeLibrary.changeLevel, 'change', {'level_name': 'L_Second'}),
    p('print_string', 'say_changed', {...quiet, 'in_string': 'changed'}),
    p('print_string', 'say_change_error', quiet),
    p('print_string', 'say_load_error', quiet),
    p('custom_event', 'progress_event', {
      'name': 'OnLoadProgress',
      'parameters': [
        {'name': 'Percent', 'type': 'Float'},
        {'name': 'TotalCount', 'type': 'Int'},
        {'name': 'LoadedCount', 'type': 'Int'},
        {'name': 'CurrentContent', 'type': 'String'},
      ],
    }),
    p(LuminaBlueprintNodeLibrary.variableSet, 'set_event_pct', {'variable': 'EventPercent'}),
    p('append', 'event_line', {'a': 'event '}),
    p('print_string', 'say_event', quiet),
    p('custom_event', 'bad', {'name': 'TryBadLevel'}),
    p(LuminaBlueprintNodeLibrary.changeLevel, 'bad_change', {'level_name': 'L_Nowhere'}),
    p('append', 'bad_line', {'a': 'bad: '}),
    p('print_string', 'say_bad', quiet),
    p('custom_event', 'go', {'name': 'LoadAndGo'}),
    p(LuminaBlueprintNodeLibrary.loadAndChangeLevel, 'load_and_change', {'level_name': 'L_First'}),
    p('print_string', 'say_went', {...quiet, 'in_string': 'went'}),
    p('custom_event', 'stop', {'name': 'StopLoading'}),
    p('cancel_level_load', 'cancel'),
  ]);
  doc.eventGraph.wires.addAll([
    _w('begin', 'exec_out', 'say_ready', 'exec_in'),
    _w('start', 'exec_out', 'load', 'exec_in'),
    _w('progress_event', 'delegate', 'load', 'on_progress_event'),
    _w('load', 'on_progress', 'set_pct', 'exec_in'),
    _w('load', 'percent', 'set_pct', 'value'),
    _w('set_pct', 'exec_out', 'set_updates', 'exec_in'),
    _w('get_updates', 'value', 'plus_one', 'a'),
    _w('plus_one', 'return_value', 'set_updates', 'value'),
    _w('set_updates', 'exec_out', 'say_item', 'exec_in'),
    _w('load', 'current_content', 'say_item', 'in_string'),
    _w('load', 'on_success', 'say_loaded', 'exec_in'),
    _w('loaded', 'return_value', 'loaded_text', 'in_bool'),
    _w('loaded_text', 'return_value', 'loaded_line', 'b'),
    _w('loaded_line', 'return_value', 'say_loaded', 'in_string'),
    _w('say_loaded', 'exec_out', 'change', 'exec_in'),
    _w('change', 'on_success', 'say_changed', 'exec_in'),
    _w('change', 'on_error', 'say_change_error', 'exec_in'),
    _w('change', 'error', 'say_change_error', 'in_string'),
    _w('load', 'on_error', 'say_load_error', 'exec_in'),
    _w('load', 'error', 'say_load_error', 'in_string'),
    _w('progress_event', 'exec_out', 'set_event_pct', 'exec_in'),
    _w('progress_event', 'Percent', 'set_event_pct', 'value'),
    _w('set_event_pct', 'exec_out', 'say_event', 'exec_in'),
    _w('progress_event', 'CurrentContent', 'event_line', 'b'),
    _w('event_line', 'return_value', 'say_event', 'in_string'),
    _w('bad', 'exec_out', 'bad_change', 'exec_in'),
    _w('bad_change', 'on_error', 'say_bad', 'exec_in'),
    _w('bad_change', 'error', 'bad_line', 'b'),
    _w('bad_line', 'return_value', 'say_bad', 'in_string'),
    _w('go', 'exec_out', 'load_and_change', 'exec_in'),
    _w('load_and_change', 'on_success', 'say_went', 'exec_in'),
    _w('stop', 'exec_out', 'cancel', 'exec_in'),
  ]);
  return doc;
}
