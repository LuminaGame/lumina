import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Enable Input on an actor Blueprint that is not the player's pawn binds
/// its input actions: they reach it like a pawn's.
void main() {
  test('an actor that ran Enable Input receives its input actions', () {
    const action = LuminaInputAction('IA_Poke');
    final context = LuminaBlueprintTypeContext(
        variables: const [LuminaBlueprintVariable(name: 'Pokes', typeName: 'Int', defaultValue: 0)], inputActions: const [action]);
    LuminaBlueprintNode place(String id, String registryId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(registryId, nodeId: id, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    final doc = LuminaBlueprintDocument(
      parentClass: 'LuminaActor',
      variables: const [LuminaBlueprintVariable(name: 'Pokes', typeName: 'Int', defaultValue: 0)],
      eventGraph: LuminaBlueprintGraph(nodes: [
        place('begin', 'event_beginplay'),
        place('pc', 'get_player_controller', {'player_index': 0}),
        place('enable', 'enable_input'),
        place('poke', LuminaBlueprintNodeLibrary.enhancedInputAction, {'action': 'IA_Poke'}),
        place('get', LuminaBlueprintNodeLibrary.variableGet, {'variable': 'Pokes'}),
        place('add', 'int_add', {'b': 1}),
        place('set', LuminaBlueprintNodeLibrary.variableSet, {'variable': 'Pokes'}),
      ], wires: [
        wire('begin', 'exec_out', 'enable', 'exec_in'),
        wire('pc', 'return_value', 'enable', 'player_controller'),
        wire('poke', 'started', 'set', 'exec_in'),
        wire('get', 'value', 'add', 'a'),
        wire('add', 'return_value', 'set', 'value'),
      ]),
    );
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final input = world.registerSubsystem(LuminaInputSubsystem());
    final mapping = LuminaInputMappingContext()..mapKey(LuminaKey.keyE, action);
    input.addMappingContext(mapping);
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_Poked', inputActions: const [action]);
    expect(cls.diagnostics.where((d) => d.isError), isEmpty, reason: '${cls.diagnostics}');
    final actor = cls.instantiate() as LuminaBlueprintRuntime;
    world.persistentLevel.registerActor(actor as LuminaActor);
    world.beginPlay();
    world.tick(1 / 60);
    expect(actor.blueprintInputBound, isTrue);
    input.injectKeyDown(LuminaKey.keyE);
    world.tick(1 / 60);
    input.injectKeyUp(LuminaKey.keyE);
    world.tick(1 / 60);
    expect((actor as dynamic).variables['Pokes'], 1);
  });
}
