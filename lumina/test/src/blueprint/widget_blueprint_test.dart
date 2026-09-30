import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

import '../../blueprint/widget_blueprint_fixture.dart';

/// The Widget Blueprint graph: its document, its scope's typing and
/// palette filter, the validator's rules, and the VM running it.
void main() {
  setUp(() => LuminaWidgetClassRegistry.register(clickerWidgetClass));
  tearDown(() {
    LuminaUserWidgets.clear();
    LuminaWidgetClassRegistry.clear();
  });

  LuminaBlueprintTypeContext contextOf(LuminaWidgetBlueprintDocument doc) =>
      LuminaBlueprintTypeContext.forWidget(doc, widgetClasses: const [clickerWidgetClass]);

  LuminaBlueprintPinSpec output(LuminaBlueprintNode node, LuminaBlueprintTypeContext c, String pin) =>
      LuminaBlueprintNodeLibrary.pinsOf(node, c)!.outputs.firstWhere((p) => p.id == pin);

  test('the document round-trips its graph, variables and class', () {
    final doc = clickerBlueprint();
    final back = LuminaWidgetBlueprintDocument.fromJson(doc.toJson());
    expect(back.widgetClass, clickerClass);
    expect(back.variables.map((v) => '${v.name}:${v.typeName}'), ['Title:text', 'StartButton:button', 'Charge:progressBar', 'Volume:slider', 'NameField:editableText']);
    expect(back.blueprint.parentClass, LuminaWidgetBlueprintDocument.parentClass);
    expect(back.blueprint.toJson(), doc.blueprint.toJson());
    expect(back.isEmpty, isFalse);
    expect(LuminaWidgetBlueprintDocument(widgetClass: 'WBP_Empty').isEmpty, isTrue);
  });

  test('forWidget types widget variables, Self and the bound events\' outputs', () {
    final doc = clickerBlueprint();
    final c = contextOf(doc);
    expect(c.isWidgetScope, isTrue);
    expect(c.isLevelScope, isFalse);
    expect(c.selfClass, 'Widget:WBP_Clicker');
    final title = doc.blueprint.eventGraph.node('title')!;
    expect(title.title, 'Title');
    expect(output(title, c, 'return_value').objectClass, 'WidgetElement:text');
    final self = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.getWidgetSelf, nodeId: 'self', context: c);
    expect(output(self, c, 'return_value').objectClass, 'Widget:WBP_Clicker');
    expect(LuminaBlueprintNodeLibrary.canConnect(output(self, c, 'return_value'),
        LuminaBlueprintNodeLibrary.spec('remove_from_parent')!.inputs.firstWhere((p) => p.id == 'target'), context: c), isTrue);

    final clicked = doc.blueprint.eventGraph.node('clicked')!;
    expect(clicked.title, 'On Clicked (StartButton)');
    expect(LuminaBlueprintNodeLibrary.pinsOf(clicked, c)!.outputs.map((p) => p.id), ['exec_out']);
    final volume = doc.blueprint.eventGraph.node('volume_changed')!;
    expect(output(volume, c, 'value').type, LuminaPinType.float);
    final committed = doc.blueprint.eventGraph.node('name_committed')!;
    expect(output(committed, c, 'text').type, LuminaPinType.string);
    expect(output(committed, c, 'commit_method').enumName, LuminaBlueprintNodeLibrary.textCommitEnum);
    // A check box's value is a bool.
    final checkDoc = LuminaWidgetBlueprintDocument(widgetClass: 'WBP_Options', variables: const [
      LuminaBlueprintWidgetElement(name: 'Mute', typeName: 'checkBox'),
    ]);
    final cc = LuminaBlueprintTypeContext.forWidget(checkDoc);
    final mute = LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.eventWidgetElement,
        nodeId: 'mute', literals: {'element': 'Mute', 'event': 'OnValueChanged'}, context: cc);
    expect(output(mute, cc, 'value').type, LuminaPinType.boolean);
    expect(LuminaWidgetEvents.forType('button'), ['OnClicked', 'OnHovered', 'OnUnhovered']);
    expect(LuminaWidgetEvents.forType('editableText'), ['OnValueChanged', 'OnTextCommitted']);
    expect(LuminaWidgetEvents.forType('text'), isEmpty);
  });

  test('availableIn keeps widget nodes in widget graphs and actor events, level and component nodes out', () {
    final widgetContext = contextOf(clickerBlueprint());
    final actorContext = LuminaBlueprintTypeContext.forDocument(LuminaBlueprintDocument(), className: 'BP_Door');
    bool inWidget(String id) => LuminaBlueprintNodeLibrary.availableIn(LuminaBlueprintNodeLibrary.spec(id)!, widgetContext);
    bool inActor(String id) => LuminaBlueprintNodeLibrary.availableIn(LuminaBlueprintNodeLibrary.spec(id)!, actorContext);
    for (final id in LuminaBlueprintNodeLibrary.widgetOnlyNodes) {
      expect(inWidget(id), isTrue, reason: id);
      expect(inActor(id), isFalse, reason: id);
    }
    for (final id in ['event_beginplay', 'event_tick', 'event_actor_begin_overlap', 'event_enhanced_input_action', 'get_level_actor', 'get_component']) {
      expect(inWidget(id), isFalse, reason: id);
    }
    for (final id in ['set_element_text', 'print_string', 'get_player_character', 'get_game_mode', 'custom_event', 'bind_event_to_dispatcher', 'remove_from_parent']) {
      expect(inWidget(id), isTrue, reason: id);
    }
  });

  test('the validator reports widget-scope mistakes on their nodes', () {
    List<String> errorsOf(LuminaWidgetBlueprintDocument doc) => [
          for (final d in validateBlueprint(doc.blueprint, typeContext: contextOf(doc)))
            if (d.isError) '${d.nodeId}: ${d.message}',
        ];
    expect(errorsOf(clickerBlueprint()), isEmpty);

    final doc = clickerBlueprint();
    final c = contextOf(doc);
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: c);
    doc.blueprint.eventGraph.nodes.addAll([
      p(LuminaBlueprintNodeLibrary.getWidgetVariable, 'missing', {'element': 'Missing'}),
      p(LuminaBlueprintNodeLibrary.getWidgetVariable, 'frame', {'element': 'Frame'}),
      p(LuminaBlueprintNodeLibrary.eventWidgetElement, 'title_click', {'element': 'Title', 'event': 'OnClicked'}),
      p(LuminaBlueprintNodeLibrary.eventWidgetElement, 'clicked_again', {'element': 'StartButton', 'event': 'OnClicked'}),
      p(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 'construct_again'),
      p('event_beginplay', 'begin'),
    ]);
    doc.blueprint.components.add(LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'));
    final errors = errorsOf(doc);
    expect(errors, contains(startsWith('null: Widget Blueprints have no components')));
    expect(errors, contains(allOf(startsWith('missing: '), contains("no variable 'Missing'"))));
    expect(errors, contains(allOf(startsWith('frame: '), contains("no variable 'Frame'"))), reason: 'Frame is not Is Variable');
    expect(errors, contains(allOf(startsWith('title_click: '), contains("'Title' has no event 'OnClicked'"))));
    expect(errors, contains(allOf(startsWith('clicked_again: '), contains('placed twice'))));
    expect(errors, contains(allOf(startsWith('construct_again: '), contains('placed twice'))));
    expect(errors, contains(allOf(startsWith('begin: '), contains('cannot be placed in a Widget Blueprint'))));

    // Widget-only nodes outside a widget graph.
    final actor = LuminaBlueprintDocument();
    actor.eventGraph.nodes.add(LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.eventWidgetConstruct, nodeId: 'wc'));
    expect(validateBlueprint(actor, className: 'BP_Door').where((d) => d.isError).map((d) => d.message),
        contains('Event Construct can only be placed in a Widget Blueprint.'));
  });

  test('Set Visibility takes ESlateVisibility; a string no longer wires into it', () {
    final spec = LuminaBlueprintNodeLibrary.spec('set_element_visibility')!;
    final pin = spec.inputs.firstWhere((p) => p.id == 'in_visibility');
    expect(pin.type, LuminaPinType.enumeration);
    expect(pin.enumName, 'ESlateVisibility');
    expect(LuminaBlueprintNodeLibrary.engineEnumValues(pin.enumName), ['Visible', 'Collapsed', 'Hidden', 'HitTestInvisible', 'SelfHitTestInvisible']);
    expect(LuminaBlueprintNodeLibrary.spec('set_widget_visibility')!.inputs.firstWhere((p) => p.id == 'in_visibility').enumName, 'ESlateVisibility');
    const text = LuminaBlueprintPinSpec('return_value', 'Return Value', LuminaPinType.string);
    expect(LuminaBlueprintNodeLibrary.canConnect(text, pin), isFalse);
    expect(LuminaBlueprintNodeLibrary.spec('set_element_is_checked')!.keywords, contains('checked state'));
  });

  test('the VM runs WBP_Clicker: Pre Construct, Construct, Tick, a click, a value change, a commit and Destruct', () {
    final cls = LuminaBlueprintClass.forWidget(clickerBlueprint());
    expect(cls.diagnostics.where((d) => d.isError), isEmpty);
    expect(cls.isUserWidget, isTrue);
    LuminaUserWidgets.register(clickerClass, cls.instantiateUserWidget);

    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.beginPlay();
    final subsystem = world.getSubsystem<LuminaWidgetSubsystem>()!;
    final owner = world.spawnActorImmediately(LuminaActor());
    final widget = LuminaBlueprintFunctionLibrary.createWidget(owner, clickerClass) as Map<String, Object?>;
    final script = LuminaUserWidgets.of(widget)! as LuminaBlueprintUserWidget;
    final printed = <String>[];
    script.trace = (e) {
      if (e.printed != null) printed.add(e.printed!);
    };
    Map<String, Object?> element(String name) => (widget['elements']! as Map)[name] as Map<String, Object?>;

    element('Title')['visibility'] = 'Collapsed';
    LuminaBlueprintFunctionLibrary.addToViewport(owner, widget, 0);
    expect(element('Title')['text'], 'Ready', reason: 'Construct runs after Pre Construct');
    expect(element('Title')['visibility'], 'Visible');

    world.tick(0.05);
    expect(element('Charge')['percent'], closeTo(0.3, 1e-9), reason: 'Tick: In Delta Time × 6');

    LuminaUserWidgets.fire(widget, 'StartButton', 'OnClicked');
    LuminaUserWidgets.fire(widget, 'StartButton', 'OnClicked');
    expect(element('Title')['text'], 'Clicked!');
    expect(script.variables['Clicks'], 2);
    expect(printed, ['clicked', 'clicked']);

    LuminaUserWidgets.fire(widget, 'Volume', 'OnValueChanged', {'value': 0.75});
    expect(element('Charge')['percent'], 0.75);

    LuminaUserWidgets.fire(widget, 'NameField', 'OnTextCommitted', {'text': 'Ada', 'commit_method': 'OnEnter'});
    expect(element('Title')['text'], 'Ada');
    expect(subsystem.widgets, isEmpty, reason: 'Remove from Parent with no Target removed the widget itself');
    expect(printed.last, 'bye', reason: 'Destruct ran');
  });

  test('an interface message sent to the widget Create Widget returned runs the widget graph\'s interface event', () {
    LuminaBlueprintInterfaces.register(const LuminaBlueprintInterfaceDocument(name: 'BPI_ScoreHUD', functions: [
      LuminaBlueprintFunctionSignature(name: 'UpdateScore', inputs: [LuminaBlueprintVariable(name: 'Text', typeName: 'String', defaultValue: '')]),
    ]));
    addTearDown(LuminaBlueprintInterfaces.clear);
    // WBP_Clicker implements BPI_ScoreHUD: Event Update Score → Set Text (Title, Text).
    final doc = clickerBlueprint();
    doc.blueprint.interfaces.add('BPI_ScoreHUD');
    final c = contextOf(doc);
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: c);
    LuminaBlueprintWire w(String id, String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: id, fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    doc.blueprint.eventGraph.nodes.addAll([
      p('event_interface_function', 'update', {'interface': 'BPI_ScoreHUD', 'function': 'UpdateScore'}),
      p('set_element_text', 'score_text'),
    ]);
    doc.blueprint.eventGraph.wires.addAll([
      w('s0', 'update', 'exec_out', 'score_text', 'exec_in'),
      w('s1', 'update', 'Text', 'score_text', 'in_text'),
      w('s2', 'title', 'return_value', 'score_text', 'target'),
    ]);
    final cls = LuminaBlueprintClass.forWidget(doc);
    expect(cls.diagnostics.where((d) => d.isError), isEmpty, reason: '${cls.diagnostics}');
    LuminaUserWidgets.register(clickerClass, cls.instantiateUserWidget);

    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.beginPlay();
    final character = world.spawnActorImmediately(LuminaActor());
    final widget = LuminaBlueprintFunctionLibrary.createWidget(character, clickerClass);
    LuminaBlueprintFunctionLibrary.addToViewport(character, widget, 0);
    final title = LuminaBlueprintFunctionLibrary.getWidgetElement(widget, 'Title') as Map<String, Object?>;
    expect(title['text'], 'Ready');

    expect(LuminaBlueprintFunctionLibrary.doesImplementInterface(character, widget, 'BPI_ScoreHUD'), isTrue,
        reason: 'the widget\'s graph implements the interface');
    expect(LuminaBlueprintFunctionLibrary.doesImplementInterface(character, widget, 'BPI_Other'), isFalse);
    LuminaBlueprintFunctionLibrary.interfaceMessage(character, widget, 'BPI_ScoreHUD', 'UpdateScore', {'Text': 'Score: 42'});
    expect(title['text'], 'Score: 42', reason: 'the message reached the widget\'s Event Update Score');
  });
}
