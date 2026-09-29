import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// Arrays of typed objects and values, and the hit-result
/// struct; array, colour, transform and hit-result pins round-trip in JSON.
void main() {
  final ctx = LuminaBlueprintCallContext(LuminaActor());
  Object? call(String id, Map<String, Object?> inputs) => LuminaBlueprintFunctionLibrary.functions[id]!(ctx, inputs)['return_value'];

  var wireCount = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${wireCount++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  test('Make Array of three actors: length, get, contains, filter by class; out-of-range Get is null', () {
    final door = LuminaBlueprintClass.fromDocument(LuminaBlueprintDocument(), name: 'BP_Door').instantiate();
    final door2 = LuminaBlueprintClass.fromDocument(LuminaBlueprintDocument(), name: 'BP_Door').instantiate();
    final plain = LuminaActor();
    final array = call('make_array', {'item_0': door, 'item_1': plain, 'item_2': door2}) as List<Object?>;
    expect(call('array_length', {'target_array': array}), 3);
    expect(call('array_get', {'target_array': array, 'index': 1}), same(plain));
    expect(call('array_contains', {'target_array': array, 'item_to_find': door2}), isTrue);
    expect(call('array_contains', {'target_array': array, 'item_to_find': LuminaActor()}), isFalse);
    expect(call('array_find', {'target_array': array, 'item_to_find': door2}), 2);
    expect(call('array_first', {'target_array': array}), same(door));
    expect(call('array_last', {'target_array': array}), same(door2));
    expect(call('array_last_index', {'target_array': array}), 2);
    expect(call('array_is_empty', {'target_array': array}), isFalse);
    expect(call('array_filter_by_class', {'target_array': array, 'class': 'Actor:BP_Door'}), [door, door2]);
    expect(call('array_filter_by_class', {'target_array': array, 'class': 'Actor:LuminaActor'}), [door, plain, door2]);
    expect(call('array_get', {'target_array': array, 'index': 7}), isNull);
    expect(call('array_get', {'target_array': array, 'index': -1}), isNull);
    // Values compare by value: vectors, colours.
    final vectors = call('make_array', {'item_0': Vector3(1, 0, 0), 'item_1': Vector3(0, 1, 0)}) as List<Object?>;
    expect(call('array_contains', {'target_array': vectors, 'item_to_find': Vector3(0, 1, 0)}), isTrue);
    expect(call('array_find', {'target_array': [[1.0, 0.0, 0.0, 1.0]], 'item_to_find': [1.0, 0.0, 0.0, 1.0]}), 0);
    // Impure array nodes mutate in place.
    LuminaBlueprintFunctionLibrary.functions['array_add']!(ctx, {'target_array': array, 'new_item': plain});
    expect(array.length, 4);
    LuminaBlueprintFunctionLibrary.functions['array_remove_index']!(ctx, {'target_array': array, 'index': 0});
    expect(array.first, same(plain));
    LuminaBlueprintFunctionLibrary.functions['array_set']!(ctx, {'target_array': array, 'index': 5, 'item': door, 'size_to_fit': true});
    expect(array.length, 6);
    expect(array[5], same(door));
    expect(array[4], isNull);
    LuminaBlueprintFunctionLibrary.functions['array_shuffle']!(ctx, {'target_array': array});
    expect(array.length, 6);
    LuminaBlueprintFunctionLibrary.functions['array_clear']!(ctx, {'target_array': array});
    expect(array, isEmpty);
    expect(call('array_is_empty', {'target_array': array}), isTrue);
  });

  test('Make Array pins follow the count and type literals; typed element pins wire to typed inputs', () {
    final make = LuminaBlueprintNodeLibrary.place('make_array', nodeId: 'mk', literals: {'count': 3, 'type': 'float'});
    expect(make.inputs.map((p) => p.id), ['item_0', 'item_1', 'item_2']);
    expect(make.inputs.first.type, LuminaPinType.float);
    expect(make.pin('return_value')!.type, LuminaPinType.array);
    expect(make.pin('return_value')!.elementType, LuminaPinType.float);
    final actors = LuminaBlueprintNodeLibrary.place('make_array', nodeId: 'mk2', literals: {'count': 1, 'type': 'object', 'class': 'Actor:BP_Door'});
    expect(actors.inputs.single.objectClass, 'Actor:BP_Door');
    expect(actors.pin('return_value')!.objectClass, 'Actor:BP_Door');
    final get = LuminaBlueprintNodeLibrary.place('array_get', nodeId: 'get', literals: {'type': 'float'});
    expect(get.pin('return_value')!.type, LuminaPinType.float);
    expect(get.pin('target_array')!.elementType, LuminaPinType.float);
    final untyped = LuminaBlueprintNodeLibrary.place('array_get', nodeId: 'get2');
    expect(untyped.pin('return_value')!.type, LuminaPinType.wildcard);
    final wild = LuminaBlueprintNodeLibrary.pinsOf(untyped, const LuminaBlueprintTypeContext())!.outputs.single;
    final floatIn = LuminaBlueprintNodeLibrary.spec('float_add')!.inputs.first;
    expect(LuminaBlueprintNodeLibrary.canConnect(wild, floatIn), isTrue, reason: 'a wildcard connects to any data pin');
    expect(LuminaBlueprintNodeLibrary.canConnect(wild, LuminaBlueprintNodeLibrary.spec('branch')!.inputs.first), isFalse,
        reason: 'never to exec');
    final strings = LuminaBlueprintNodeLibrary.spec('string_split')!.outputs.single;
    final floats = LuminaBlueprintNodeLibrary.pinsOf(make, const LuminaBlueprintTypeContext())!.outputs.single;
    final eachArray = LuminaBlueprintNodeLibrary.spec('for_each_loop')!.inputs.last;
    expect(LuminaBlueprintNodeLibrary.canConnect(strings, eachArray), isTrue, reason: 'an untyped array pin takes any array');
    expect(LuminaBlueprintNodeLibrary.connectionError(strings, get.inputs.first.let((p) => LuminaBlueprintPinSpec(p.id, p.name, p.type!, elementType: p.elementType))),
        'Cannot connect array of string to array of float.');
    expect(LuminaBlueprintNodeLibrary.canConnect(floats, get.inputs.first.let((p) => LuminaBlueprintPinSpec(p.id, p.name, p.type!, elementType: p.elementType))), isTrue);
  });

  test('array, colour, transform and hit-result pins and variables round-trip in .lmas JSON', () {
    const variables = [
      LuminaBlueprintVariable(name: 'Doors', typeName: 'Array:Actor:BP_Door', defaultValue: []),
      LuminaBlueprintVariable(name: 'Tint', typeName: 'Color', defaultValue: [1.0, 0.5, 0.0, 1.0]),
      LuminaBlueprintVariable(name: 'Spawn', typeName: 'Transform', defaultValue: {'location': [1.0, 2.0, 3.0], 'rotation': [0.0, 0.0, 90.0], 'scale': [1.0, 1.0, 1.0]}),
      LuminaBlueprintVariable(name: 'LastHit', typeName: 'HitResult'),
      LuminaBlueprintVariable(name: 'Scores', typeName: 'Array:Int', defaultValue: [1, 2]),
    ];
    expect(variables[0].type, LuminaPinType.array);
    expect(variables[0].elementType, LuminaPinType.object);
    expect(variables[0].objectClass, 'Actor:BP_Door');
    expect(variables[1].type, LuminaPinType.color);
    expect(variables[2].type, LuminaPinType.transform);
    expect(variables[3].type, LuminaPinType.hitResult);
    expect(variables[4].elementType, LuminaPinType.integer);
    const context = LuminaBlueprintTypeContext(variables: variables);
    final doc = LuminaBlueprintDocument(variables: variables, eventGraph: LuminaBlueprintGraph(nodes: [
      LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.variableGet, nodeId: 'doors', literals: {'variable': 'Doors'}, context: context),
      LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.variableSet, nodeId: 'tint', literals: {'variable': 'Tint', 'value': [0.0, 0.0, 1.0, 1.0]}, context: context),
      LuminaBlueprintNodeLibrary.place('make_transform', nodeId: 'xf', literals: {'location': [5.0, 0.0, 0.0]}),
      LuminaBlueprintNodeLibrary.place('break_hit_result', nodeId: 'hit'),
      LuminaBlueprintNodeLibrary.place('make_array', nodeId: 'mk', literals: {'count': 2, 'type': 'integer', 'item_0': 7, 'item_1': 9}),
    ]));
    final json = doc.toJson();
    final doors = (json['eventGraph'] as Map)['nodes'][0]['outputs'][0] as Map;
    expect(doors['type'], 'array');
    expect(doors['of'], 'object');
    expect(doors['class'], 'Actor:BP_Door');
    final back = LuminaBlueprintDocument.fromJson(doc.toJson());
    expect(back.toFormattedJson(), doc.toFormattedJson());
    final doorsPin = back.eventGraph.node('doors')!.pin('value')!;
    expect(doorsPin.type, LuminaPinType.array);
    expect(doorsPin.elementType, LuminaPinType.object);
    expect(doorsPin.objectClass, 'Actor:BP_Door');
    expect(back.eventGraph.node('tint')!.pin('value')!.type, LuminaPinType.color);
    expect(back.eventGraph.node('xf')!.pin('return_value')!.type, LuminaPinType.transform);
    expect(back.eventGraph.node('hit')!.pin('hit')!.type, LuminaPinType.hitResult);
    expect(back.eventGraph.node('hit')!.pin('hit_actor')!.objectClass, 'Actor:LuminaActor');
    expect(back.eventGraph.node('mk')!.pin('item_1')!.type, LuminaPinType.integer);
    // The VM starts the variables from their stored defaults, typed.
    final cls = LuminaBlueprintClass.fromDocument(back, name: 'BP_Pins');
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final actor = cls.instantiate() as LuminaBlueprintInstance;
    expect(actor.variables['Doors'], isA<List<Object?>>());
    expect(actor.variables['Tint'], [1.0, 0.5, 0.0, 1.0]);
    expect((actor.variables['Spawn'] as Map)['rotation'], [0.0, 0.0, 90.0]);
    expect(actor.variables['LastHit'], isNull);
    expect(actor.variables['Scores'], [1, 2]);
  });

  test('Add on a variable array persists across ticks; a Set copies the array (value semantics)', () {
    const variables = [
      LuminaBlueprintVariable(name: 'Log', typeName: 'Array:String', defaultValue: []),
      LuminaBlueprintVariable(name: 'Copy', typeName: 'Array:String', defaultValue: []),
    ];
    const context = LuminaBlueprintTypeContext(variables: variables);
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    final doc = LuminaBlueprintDocument(variables: variables, eventGraph: LuminaBlueprintGraph(nodes: [
      place('event_tick', 'tick'),
      place(LuminaBlueprintNodeLibrary.variableGet, 'log', {'variable': 'Log'}),
      place('array_add', 'add', {'type': 'string', 'new_item': 'tick'}),
      place(LuminaBlueprintNodeLibrary.variableSet, 'copy', {'variable': 'Copy'}),
      place('array_length', 'len'),
      place('int_to_string', 'len_text'),
      place('print_string', 'say'),
    ], wires: [
      wire('tick', 'exec_tick_out', 'add', 'exec_in'),
      wire('log', 'value', 'add', 'target_array'),
      wire('add', 'exec_out', 'copy', 'exec_in'),
      wire('log', 'value', 'copy', 'value'),
      wire('copy', 'exec_out', 'say', 'exec_in'),
      wire('log', 'value', 'len', 'target_array'),
      wire('len', 'return_value', 'len_text', 'in_int'),
      wire('len_text', 'return_value', 'say', 'in_string'),
    ]));
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_Log');
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = cls.instantiate() as LuminaBlueprintInstance;
    final trace = <LuminaBlueprintTraceEvent>[];
    actor.trace = trace.add;
    w.persistentLevel.registerActor(actor);
    w.beginPlay();
    for (var i = 0; i < 3; i++) {
      w.tick(1 / 60);
    }
    expect(actor.variables['Log'], ['tick', 'tick', 'tick']);
    expect(actor.variables['Copy'], ['tick', 'tick', 'tick']);
    expect(identical(actor.variables['Copy'], actor.variables['Log']), isFalse, reason: 'Set copied the list');
    expect([for (final t in trace) if (t.printed != null) t.printed], ['1', '2', '3']);
    w.cleanup();
  });

  test('Break Hit Result on Make Hit Result returns the same fields', () {
    final actor = LuminaActor();
    final capsule = LuminaCapsuleComponent();
    final hit = call('make_hit_result', {
      'blocking_hit': true,
      'location': Vector3(1, 2, 3),
      'impact_point': Vector3(1, 2, 2.5),
      'impact_normal': Vector3(0, 0, 1),
      'distance': 42.0,
      'hit_actor': actor,
      'hit_component': capsule,
    });
    expect(hit, isA<Map<String, Object?>>());
    final parts = LuminaBlueprintFunctionLibrary.functions['break_hit_result']!(ctx, {'hit': hit});
    expect(parts['blocking_hit'], isTrue);
    expect(parts['location'], Vector3(1, 2, 3));
    expect(parts['impact_point'], Vector3(1, 2, 2.5));
    expect(parts['impact_normal'], Vector3(0, 0, 1));
    expect(parts['distance'], 42.0);
    expect(parts['hit_actor'], same(actor));
    expect(parts['hit_component'], same(capsule));
    final none = LuminaBlueprintFunctionLibrary.functions['break_hit_result']!(ctx, {'hit': null});
    expect(none['blocking_hit'], isFalse);
    expect(none['location'], Vector3.zero());
    expect(none['hit_actor'], isNull);
  });
}

extension<T> on T {
  R let<R>(R Function(T it) f) => f(this);
}
