import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Event dispatchers bound across Blueprints, interface
/// messages answered only by implementers, and enum assets with Switch on
/// Enum and the conversion nodes.
void main() {
  var wireCount = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${wireCount++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  List<String> printed(List<LuminaBlueprintTraceEvent> trace) => [for (final t in trace) if (t.printed != null) t.printed!];

  tearDown(() {
    LuminaBlueprintEnums.clear();
    LuminaBlueprintInterfaces.clear();
    LuminaBlueprintActorClasses.clear();
  });

  test('BP_Character binds its custom event to the door dispatcher; Call fires it; Unbind All stops it', () {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    // BP_Door: dispatcher OnDoorOpened(Angle: float); Tick → Call OnDoorOpened(90).
    final doorDoc = LuminaBlueprintDocument(dispatchers: [
      LuminaBlueprintDispatcher(name: 'OnDoorOpened', parameters: [const LuminaBlueprintVariable(name: 'Angle', typeName: 'Float', defaultValue: 0.0)]),
    ]);
    final dc = LuminaBlueprintTypeContext.forDocument(doorDoc, className: 'BP_Door');
    final callDispatcher = LuminaBlueprintNodeLibrary.place('call_dispatcher', nodeId: 'open', literals: {'dispatcher': 'OnDoorOpened', 'Angle': 90.0}, context: dc);
    expect(callDispatcher.title, 'Call On Door Opened');
    expect(callDispatcher.pin('Angle')!.type, LuminaPinType.float);
    doorDoc.eventGraph.nodes.addAll([LuminaBlueprintNodeLibrary.place('event_tick', nodeId: 'tick', context: dc), callDispatcher]);
    doorDoc.eventGraph.wires.add(wire('tick', 'exec_tick_out', 'open', 'exec_in'));
    final back = LuminaBlueprintDocument.fromJson(jsonDecode(doorDoc.toFormattedJson()) as Map<String, dynamic>);
    expect(back.dispatchers.single.parameters.single.name, 'Angle');
    final doorClass = LuminaBlueprintClass.fromDocument(back, name: 'BP_Door');
    expect(doorClass.diagnostics, isEmpty, reason: '${doorClass.diagnostics}');
    final door = doorClass.instantiate() as LuminaBlueprintActor;
    w.persistentLevel.registerActor(door);
    // BP_Character: BeginPlay → Bind Event to OnDoorOpened (door, its custom event Opened(Angle)); Opened → print.
    final charDoc = LuminaBlueprintDocument(parentClass: 'LuminaCharacter', variables: [const LuminaBlueprintVariable(name: 'Door', typeName: 'Actor:BP_Door')]);
    final cc = LuminaBlueprintTypeContext.forDocument(charDoc, className: 'BP_Character', actorParents: {'BP_Door': 'LuminaActor'},
        dispatcherOwners: {'BP_Door': back.dispatchers});
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: cc);
    final bind = p('bind_event_to_dispatcher', 'bind', {'dispatcher': 'OnDoorOpened'});
    expect(bind.pin('event')!.type, LuminaPinType.delegate);
    charDoc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      p('get_all_actors_of_class', 'doors', {'class': 'Actor:BP_Door'}),
      p('array_first', 'door', {'type': 'object', 'class': 'Actor:BP_Door'}),
      p(LuminaBlueprintNodeLibrary.variableSet, 'set_door', {'variable': 'Door'}),
      bind,
      p('custom_event', 'opened', {'name': 'Opened', 'parameters': [{'name': 'Angle', 'type': 'Float'}]}),
      p('float_to_string', 'text', {'decimals': 0}),
      p('append', 'line', {'a': 'opened to '}),
      p('print_string', 'say'),
      p('event_tick', 'tick'),
      p('do_n', 'twice', {'n': 2}),
      p('int_equal', 'second', {'b': 2}),
      p('branch', 'if_second'),
      p(LuminaBlueprintNodeLibrary.variableGet, 'door_var', {'variable': 'Door'}),
      p('unbind_all_events', 'unbind', {'dispatcher': 'OnDoorOpened'}),
    ]);
    charDoc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'set_door', 'exec_in'),
      wire('doors', 'return_value', 'door', 'target_array'),
      wire('door', 'return_value', 'set_door', 'value'),
      wire('set_door', 'exec_out', 'bind', 'exec_in'),
      wire('set_door', 'value', 'bind', 'target'),
      wire('opened', 'delegate', 'bind', 'event'),
      wire('opened', 'exec_out', 'say', 'exec_in'),
      wire('opened', 'Angle', 'text', 'in_float'),
      wire('text', 'return_value', 'line', 'b'),
      wire('line', 'return_value', 'say', 'in_string'),
      wire('tick', 'exec_tick_out', 'twice', 'exec_in'),
      wire('twice', 'exit', 'if_second', 'exec_in'),
      wire('twice', 'counter', 'second', 'a'),
      wire('second', 'return_value', 'if_second', 'condition'),
      wire('if_second', 'true_out', 'unbind', 'exec_in'),
      wire('door_var', 'value', 'unbind', 'target'),
    ]);
    final charClass = LuminaBlueprintClass.fromDocument(charDoc, name: 'BP_Character');
    expect(charClass.diagnostics, isEmpty, reason: '${charClass.diagnostics}');
    final character = charClass.instantiate() as LuminaBlueprintCharacter;
    final trace = <LuminaBlueprintTraceEvent>[];
    character.trace = trace.add;
    w.persistentLevel.registerActor(character);
    w.beginPlay();
    expect(door.blueprintDispatcher('OnDoorOpened').isBound, isTrue);
    w.tick(1 / 60);
    expect(printed(trace), ['opened to 90']);
    w.tick(1 / 60);
    expect(printed(trace), ['opened to 90', 'opened to 90']);
    // Tick 2's DoN(2) exit unbound everything: no more calls reach the character.
    expect(door.blueprintDispatcher('OnDoorOpened').isBound, isFalse);
    w.tick(1 / 60);
    w.tick(1 / 60);
    expect(printed(trace).length, 2);
    // Unbind a single delegate as well.
    final delegate = LuminaBlueprintDelegate(character, 'Opened');
    LuminaBlueprintFunctionLibrary.bindEventToDispatcher(character, door, 'OnDoorOpened', delegate);
    expect(door.blueprintDispatcher('OnDoorOpened').isBound, isTrue);
    LuminaBlueprintFunctionLibrary.unbindEventFromDispatcher(character, door, 'OnDoorOpened', delegate);
    expect(door.blueprintDispatcher('OnDoorOpened').isBound, isFalse);
  });

  test('interface BPI_Interactable.Interact: the door answers, the rock ignores it, Does Implement Interface reports both', () {
    LuminaBlueprintInterfaces.register(const LuminaBlueprintInterfaceDocument(name: 'BPI_Interactable', functions: [
      LuminaBlueprintFunctionSignature(name: 'Interact', inputs: [LuminaBlueprintVariable(name: 'Instigator', typeName: 'Actor')]),
      LuminaBlueprintFunctionSignature(name: 'GetPrompt', outputs: [LuminaBlueprintVariable(name: 'Prompt', typeName: 'String', defaultValue: '')]),
    ]));
    final iface = LuminaBlueprintInterfaces.lookup('BPI_Interactable')!;
    final back = LuminaBlueprintInterfaceDocument.fromJson(jsonDecode(jsonEncode(iface.toJson())) as Map<String, dynamic>);
    expect(back.functions.map((f) => f.name), ['Interact', 'GetPrompt']);
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    // BP_Door implements it: Event Interact prints; GetPrompt is a function returning "Open".
    final doorDoc = LuminaBlueprintDocument(interfaces: ['BPI_Interactable']);
    final prompt = LuminaBlueprintFunctionGraph(name: 'GetPrompt', outputs: [const LuminaBlueprintVariable(name: 'Prompt', typeName: 'String', defaultValue: '')]);
    doorDoc.functions.add(prompt);
    final pc = LuminaBlueprintTypeContext.forFunction(doorDoc, prompt, className: 'BP_Door');
    prompt.graph.nodes.addAll([
      LuminaBlueprintNodeLibrary.place('function_entry', nodeId: 'entry', context: pc),
      LuminaBlueprintNodeLibrary.place('function_result', nodeId: 'result', literals: {'Prompt': 'Open'}, context: pc),
    ]);
    prompt.graph.wires.add(wire('entry', 'exec_out', 'result', 'exec_in'));
    final dc = LuminaBlueprintTypeContext.forDocument(doorDoc, className: 'BP_Door');
    final interact = LuminaBlueprintNodeLibrary.place('event_interface_function', nodeId: 'interact',
        literals: {'interface': 'BPI_Interactable', 'function': 'Interact'}, context: dc);
    expect(interact.title, 'Event Interact');
    expect(interact.pin('Instigator')!.objectClass, 'Actor:LuminaActor');
    doorDoc.eventGraph.nodes.addAll([
      interact,
      LuminaBlueprintNodeLibrary.place('get_display_name', nodeId: 'who', context: dc),
      LuminaBlueprintNodeLibrary.place('append', nodeId: 'line', literals: {'a': 'door used by '}, context: dc),
      LuminaBlueprintNodeLibrary.place('print_string', nodeId: 'say', context: dc),
    ]);
    doorDoc.eventGraph.wires.addAll([
      wire('interact', 'exec_out', 'say', 'exec_in'),
      wire('interact', 'Instigator', 'who', 'object'),
      wire('who', 'return_value', 'line', 'b'),
      wire('line', 'return_value', 'say', 'in_string'),
    ]);
    final doorBack = LuminaBlueprintDocument.fromJson(jsonDecode(doorDoc.toFormattedJson()) as Map<String, dynamic>);
    expect(doorBack.interfaces, ['BPI_Interactable']);
    final doorClass = LuminaBlueprintClass.fromDocument(doorBack, name: 'BP_Door');
    expect(doorClass.diagnostics, isEmpty, reason: '${doorClass.diagnostics}');
    final door = doorClass.instantiate() as LuminaBlueprintActor;
    final doorTrace = <LuminaBlueprintTraceEvent>[];
    door.trace = doorTrace.add;
    final rock = LuminaBlueprintClass.fromDocument(LuminaBlueprintDocument(), name: 'BP_Rock').instantiate() as LuminaBlueprintActor;
    w.persistentLevel.registerActor(door);
    w.persistentLevel.registerActor(rock);
    // BP_Player: BeginPlay → Interact (message) on every actor; print GetPrompt of the door; Does Implement on both.
    final playerDoc = LuminaBlueprintDocument(parentClass: 'LuminaCharacter');
    final cc = LuminaBlueprintTypeContext.forDocument(playerDoc, className: 'BP_Player');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: cc);
    final message = p('interface_message', 'msg', {'interface': 'BPI_Interactable', 'function': 'Interact'});
    expect(message.title, 'Interact (Message)');
    expect(message.pin('Instigator')!.type, LuminaPinType.object);
    final promptMsg = p('interface_message', 'prompt', {'interface': 'BPI_Interactable', 'function': 'GetPrompt'});
    expect(promptMsg.pin('Prompt')!.isOutput, isTrue);
    playerDoc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      p('get_all_actors_of_class', 'all', {'class': 'Actor:LuminaActor'}),
      p('for_each_loop', 'each', {'type': 'object', 'class': 'Actor:LuminaActor'}),
      message,
      p('get_player_character', 'me'),
      p('implements_interface', 'impl', {'interface': 'BPI_Interactable'}),
      p('bool_to_string', 'impl_text'),
      p('print_string', 'say_impl'),
      promptMsg,
      p('print_string', 'say_prompt'),
    ]);
    playerDoc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'each', 'exec_in'),
      wire('all', 'return_value', 'each', 'array'),
      wire('each', 'loop_body', 'msg', 'exec_in'),
      wire('each', 'array_element', 'msg', 'target'),
      wire('me', 'return_value', 'msg', 'Instigator'),
      wire('msg', 'exec_out', 'say_impl', 'exec_in'),
      wire('each', 'array_element', 'impl', 'target'),
      wire('impl', 'return_value', 'impl_text', 'in_bool'),
      wire('impl_text', 'return_value', 'say_impl', 'in_string'),
      wire('say_impl', 'exec_out', 'prompt', 'exec_in'),
      wire('each', 'array_element', 'prompt', 'target'),
      wire('prompt', 'exec_out', 'say_prompt', 'exec_in'),
      wire('prompt', 'Prompt', 'say_prompt', 'in_string'),
    ]);
    final playerClass = LuminaBlueprintClass.fromDocument(playerDoc, name: 'BP_Player');
    expect(playerClass.diagnostics, isEmpty, reason: '${playerClass.diagnostics}');
    final player = playerClass.instantiate() as LuminaBlueprintCharacter;
    final trace = <LuminaBlueprintTraceEvent>[];
    player.trace = trace.add;
    w.persistentLevel.registerActor(player);
    w.beginPlay();
    expect(printed(doorTrace), ['door used by BP_Player']);
    // Door: implements true + prompt "Open"; rock and player: false + "" (the message is a no-op without an error).
    expect(printed(trace), ['true', 'Open', 'false', '', 'false', '']);
    expect(player.lastError, isNull);
    expect(door.implementsInterface('BPI_Interactable'), isTrue);
    expect(rock.implementsInterface('BPI_Interactable'), isFalse);
  });

  test('enum E_DoorState: Switch on Enum takes Opening; To String, To Int, Int → Enum clamps with a warning; Equal; count', () {
    final doorState = const LuminaBlueprintEnumDocument(name: 'E_DoorState', values: ['Closed', 'Opening', 'Open']);
    final back = LuminaBlueprintEnumDocument.fromJson(jsonDecode(jsonEncode(doorState.toJson())) as Map<String, dynamic>);
    expect(back.values, ['Closed', 'Opening', 'Open']);
    expect(back.toJson()['kind'], 'enum');
    LuminaBlueprintEnums.register(back);
    final doc = LuminaBlueprintDocument(variables: [const LuminaBlueprintVariable(name: 'State', typeName: 'Enum:E_DoorState', defaultValue: 'Closed')]);
    expect(doc.variables.single.type, LuminaPinType.enumeration);
    expect(doc.variables.single.enumName, 'E_DoorState');
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Enum');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    final sw = p('switch_on_enum', 'sw', {'enum': 'E_DoorState'});
    expect(sw.outputs.map((o) => o.id), ['case_0', 'case_1', 'case_2']);
    expect(sw.outputs.map((o) => o.name), ['Closed', 'Opening', 'Open']);
    expect(sw.pin('selection')!.type, LuminaPinType.enumeration);
    expect(sw.pin('selection')!.enumName, 'E_DoorState');
    final literal = p('enum_literal', 'opening', {'enum': 'E_DoorState', 'value': 'Opening'});
    expect(literal.title, 'E_DoorState');
    expect(literal.pin('return_value')!.enumName, 'E_DoorState');
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      p(LuminaBlueprintNodeLibrary.variableSet, 'set_state', {'variable': 'State'}),
      literal,
      sw,
      p('print_string', 'p_closed', {'in_string': 'closed'}),
      p('print_string', 'p_opening', {'in_string': 'opening'}),
      p('print_string', 'p_open', {'in_string': 'open'}),
      p('enum_to_string', 'name'),
      p('print_string', 'say_name'),
      p('enum_to_int', 'index', {'enum': 'E_DoorState'}),
      p('int_to_string', 'index_text'),
      p('print_string', 'say_index'),
      p('int_to_enum', 'fifth', {'enum': 'E_DoorState', 'value': 5}),
      p('enum_to_string', 'fifth_name'),
      p('print_string', 'say_fifth'),
      p('enum_equal', 'same'),
      p('bool_to_string', 'same_text'),
      p('print_string', 'say_same'),
      p('get_enum_value_count', 'count', {'enum': 'E_DoorState'}),
      p('int_to_string', 'count_text'),
      p('print_string', 'say_count'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'set_state', 'exec_in'),
      wire('opening', 'return_value', 'set_state', 'value'),
      wire('set_state', 'exec_out', 'sw', 'exec_in'),
      wire('set_state', 'value', 'sw', 'selection'),
      wire('sw', 'case_0', 'p_closed', 'exec_in'),
      wire('sw', 'case_1', 'p_opening', 'exec_in'),
      wire('sw', 'case_2', 'p_open', 'exec_in'),
      wire('p_opening', 'exec_out', 'say_name', 'exec_in'),
      wire('set_state', 'value', 'name', 'value'),
      wire('name', 'return_value', 'say_name', 'in_string'),
      wire('say_name', 'exec_out', 'say_index', 'exec_in'),
      wire('set_state', 'value', 'index', 'value'),
      wire('index', 'return_value', 'index_text', 'in_int'),
      wire('index_text', 'return_value', 'say_index', 'in_string'),
      wire('say_index', 'exec_out', 'say_fifth', 'exec_in'),
      wire('fifth', 'return_value', 'fifth_name', 'value'),
      wire('fifth_name', 'return_value', 'say_fifth', 'in_string'),
      wire('say_fifth', 'exec_out', 'say_same', 'exec_in'),
      wire('set_state', 'value', 'same', 'a'),
      wire('opening', 'return_value', 'same', 'b'),
      wire('same', 'return_value', 'same_text', 'in_bool'),
      wire('same_text', 'return_value', 'say_same', 'in_string'),
      wire('say_same', 'exec_out', 'say_count', 'exec_in'),
      wire('count', 'return_value', 'count_text', 'in_int'),
      wire('count_text', 'return_value', 'say_count', 'in_string'),
    ]);
    final json = jsonDecode(doc.toFormattedJson()) as Map<String, dynamic>;
    final swJson = ((json['eventGraph'] as Map)['nodes'] as List).firstWhere((n) => n['id'] == 'sw') as Map;
    final selection = (swJson['inputs'] as List).firstWhere((i) => i['id'] == 'selection') as Map;
    expect(selection['type'], 'enum');
    expect(selection['enum'], 'E_DoorState');
    final docBack = LuminaBlueprintDocument.fromJson(json);
    expect(docBack.eventGraph.node('sw')!.pin('selection')!.enumName, 'E_DoorState');
    final cls = LuminaBlueprintClass.fromDocument(docBack, name: 'BP_Enum');
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final actor = cls.instantiate() as LuminaBlueprintActor;
    final trace = <LuminaBlueprintTraceEvent>[];
    actor.trace = trace.add;
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    w.persistentLevel.registerActor(actor);
    w.beginPlay();
    expect(printed(trace), ['opening', 'Opening', '1', 'Open', 'true', '3']);
    expect(actor.variables['State'], 'Opening');
    expect(LuminaBlueprintFunctionLibrary.intToEnum('E_DoorState', -2), 'Closed');
    // An unknown enum in the document is a validator error.
    doc.eventGraph.nodes.add(p('switch_on_enum', 'bad', {'enum': 'E_Nope'}));
    expect(validateBlueprint(doc, className: 'BP_Enum').where((d) => d.isError).map((d) => d.message), contains(contains("unknown enum 'E_Nope'")));
  });
}
