import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Two editor library nodes as the editor registers them: a read that needs
/// no capability, and a level write that needs `level`.
const LuminaBlueprintNodeSpec _getSelected = LuminaBlueprintNodeSpec(
  id: 'editor_get_selected_actors',
  title: 'Get Selected Actors',
  category: 'Editor|Selection',
  kind: LuminaBlueprintNodeKind.pure,
  headerColor: 0xFF2E7D32,
  outputs: [LuminaBlueprintPinSpec('return_value', 'Return Value', LuminaPinType.array, elementType: LuminaPinType.string)],
  editorOnly: true,
);

const LuminaBlueprintNodeSpec _setTransform = LuminaBlueprintNodeSpec(
  id: 'editor_set_actor_transform',
  title: 'Set Actor Transform',
  category: 'Editor|Level',
  kind: LuminaBlueprintNodeKind.impure,
  headerColor: 0xFF1565C0,
  inputs: [
    LuminaBlueprintPinSpec('exec_in', 'Exec In', LuminaPinType.exec),
    LuminaBlueprintPinSpec('actor_id', 'Actor Id', LuminaPinType.string, defaultValue: ''),
    LuminaBlueprintPinSpec('transform', 'Transform', LuminaPinType.transform),
  ],
  outputs: [LuminaBlueprintPinSpec('exec_out', 'Exec Out', LuminaPinType.exec)],
  editorOnly: true,
  editorCapability: 'level',
);

LuminaWidgetBlueprintDocument _panel(String name) => LuminaWidgetBlueprintDocument(
      widgetClass: name,
      variables: const [LuminaBlueprintWidgetElement(name: 'RenameButton', typeName: 'button')],
    );

void main() {
  setUp(() {
    LuminaBlueprintFunctionRegistry.register(_getSelected, (_, _) => {'return_value': <Object?>[]});
    LuminaBlueprintFunctionRegistry.register(_setTransform, (_, _) => const {});
  });
  tearDown(() {
    LuminaBlueprintFunctionRegistry.clear();
    LuminaWidgetClassRegistry.clear();
  });

  bool available(String id, LuminaBlueprintTypeContext context) =>
      LuminaBlueprintNodeLibrary.availableIn(LuminaBlueprintNodeLibrary.spec(id)!, context);

  test('an editor panel offers the editor library and widget events but no game-only nodes', () {
    final context = LuminaBlueprintTypeContext.forEditorPanel(_panel('EPW_BatchRename'), capabilities: {'assets'});
    expect(context.isEditorScope, isTrue);
    expect(context.isWidgetScope, isTrue);
    expect(available('editor_get_selected_actors', context), isTrue);
    expect(available(LuminaBlueprintNodeLibrary.eventWidgetElement, context), isTrue);
    expect(available(LuminaBlueprintNodeLibrary.eventWidgetConstruct, context), isTrue);
    expect(available('print_string', context), isTrue);
    for (final id in [
      'get_player_character',
      LuminaBlueprintNodeLibrary.enhancedInputAction,
      'open_level',
      'set_game_paused',
      'spawn_actor_from_class',
      'get_all_actors_of_class',
      'quit_game',
      'save_game_to_slot',
    ]) {
      expect(available(id, context), isFalse, reason: '$id acts on the game');
    }
  });

  test('a game graph does not offer editor-only nodes', () {
    final actor = LuminaBlueprintTypeContext.forDocument(LuminaBlueprintDocument(parentClass: 'LuminaActor'));
    expect(available('editor_get_selected_actors', actor), isFalse);
    final widget = LuminaBlueprintTypeContext.forWidget(_panel('WBP_Hud'));
    expect(available('editor_get_selected_actors', widget), isFalse);
    expect(available('get_player_character', widget), isTrue);
  });

  test('a node needing an undeclared capability is a validator error naming it', () {
    final doc = _panel('EPW_BatchRename');
    final context = LuminaBlueprintTypeContext.forEditorPanel(doc, capabilities: {'assets'});
    doc.blueprint.eventGraph.nodes.addAll([
      LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.eventWidgetConstruct, nodeId: 'construct', context: context),
      LuminaBlueprintNodeLibrary.place('editor_set_actor_transform', nodeId: 'move', context: context),
    ]);
    doc.blueprint.eventGraph.wires.add(
        LuminaBlueprintWire(id: 'w', fromNodeId: 'construct', fromPinId: 'exec_out', toNodeId: 'move', toPinId: 'exec_in'));
    final errors = validateBlueprint(doc.blueprint, typeContext: context).where((d) => d.isError).toList();
    expect(errors, hasLength(1));
    expect(errors.single.nodeId, 'move');
    expect(errors.single.message, allOf(contains('Set Actor Transform'), contains("'level'")));

    final withLevel = LuminaBlueprintClass.forEditorPanel(doc, capabilities: {'assets', 'level'});
    expect(withLevel.hasErrors, isFalse);
    expect(withLevel.isEditorPanel, isTrue);
    expect(LuminaBlueprintClass.forEditorPanel(doc, capabilities: {'assets'}).hasErrors, isTrue);
  });

  test('a game-only node in an editor panel is a validator error', () {
    final doc = _panel('EPW_Bad');
    final context = LuminaBlueprintTypeContext.forEditorPanel(doc);
    doc.blueprint.eventGraph.nodes.add(LuminaBlueprintNodeLibrary.place('get_player_character', nodeId: 'p', context: context));
    final errors = validateBlueprint(doc.blueprint, typeContext: context).where((d) => d.isError);
    expect(errors.map((e) => e.message), contains(contains('cannot be placed in an editor panel')));
  });

  test('Create Widget of an editor panel class in a game actor graph is a validator error', () {
    LuminaWidgetClassRegistry.register(const LuminaBlueprintWidgetClass(name: 'EPW_BatchRename', isEditorPanel: true));
    LuminaWidgetClassRegistry.register(const LuminaBlueprintWidgetClass(name: 'WBP_Hud'));
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
    final context = LuminaBlueprintTypeContext.forDocument(doc);
    doc.eventGraph.nodes.addAll([
      LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'begin', context: context),
      LuminaBlueprintNodeLibrary.place('create_widget', nodeId: 'panel', literals: {'class': 'EPW_BatchRename'}, context: context),
      LuminaBlueprintNodeLibrary.place('create_widget', nodeId: 'hud', literals: {'class': 'WBP_Hud'}, context: context),
    ]);
    doc.eventGraph.wires.addAll([
      LuminaBlueprintWire(id: 'w0', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'panel', toPinId: 'exec_in'),
      LuminaBlueprintWire(id: 'w1', fromNodeId: 'panel', fromPinId: 'exec_out', toNodeId: 'hud', toPinId: 'exec_in'),
    ]);
    final errors = validateBlueprint(doc, typeContext: LuminaBlueprintTypeContext.forDocument(doc))
        .where((d) => d.isError)
        .toList();
    expect(errors, hasLength(1));
    expect(errors.single.nodeId, 'panel');
    expect(errors.single.message, contains('editor panel'));
  });

  test('an editor-only node in a game graph is a validator error', () {
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
    doc.eventGraph.nodes.add(LuminaBlueprintNodeLibrary.place('editor_get_selected_actors', nodeId: 'sel'));
    final errors = validateBlueprint(doc).where((d) => d.isError).toList();
    expect(errors.map((e) => e.message), contains(contains('can only be placed in an editor panel')));
  });

  test('editor widgets bind their events; any element takes On Asset Dropped only in an editor panel', () {
    final doc = LuminaWidgetBlueprintDocument(widgetClass: 'EPW_Tree', variables: const [
      LuminaBlueprintWidgetElement(name: 'Actors', typeName: LuminaEditorWidgetEvents.treeView),
      LuminaBlueprintWidgetElement(name: 'DropZone', typeName: 'border'),
    ]);
    final context = LuminaBlueprintTypeContext.forEditorPanel(doc);
    final selected = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.eventWidgetElement,
        nodeId: 'sel', literals: {'element': 'Actors', 'event': LuminaEditorWidgetEvents.onItemSelected}, context: context);
    expect(selected.title, 'On Item Selected (Actors)');
    expect(selected.outputs.map((p) => p.id), containsAll(['item_id', 'selected_ids']));
    final dropped = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.eventWidgetElement,
        nodeId: 'drop', literals: {'element': 'DropZone', 'event': LuminaEditorWidgetEvents.onAssetDropped}, context: context);
    expect(dropped.outputs.map((p) => p.id), containsAll(['asset_path', 'asset_type']));
    doc.blueprint.eventGraph.nodes.addAll([selected, dropped]);
    expect(validateBlueprint(doc.blueprint, typeContext: context).where((d) => d.isError), isEmpty);
    final game = LuminaBlueprintTypeContext.forWidget(doc);
    expect(validateBlueprint(doc.blueprint, typeContext: game).where((d) => d.isError).map((d) => d.nodeId), contains('drop'));
  });
}
