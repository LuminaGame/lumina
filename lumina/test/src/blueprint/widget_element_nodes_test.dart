import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// A widget instance keeps per-element state that the element
/// nodes read and write; the deprecated Set Text (Widget) still works.
void main() {
  const hud = LuminaBlueprintWidgetClass(name: 'WBP_HUD', elements: [
    LuminaBlueprintWidgetElement(name: 'FPSCounter', typeName: 'text', props: {'text': 'FPS: 0', 'fontSize': 18.0}),
    LuminaBlueprintWidgetElement(name: 'Health', typeName: 'progressBar', props: {'percent': 1.0}),
    LuminaBlueprintWidgetElement(name: 'Title', typeName: 'text', props: {'text': 'Lumina'}),
    LuminaBlueprintWidgetElement(name: 'Mode', typeName: 'comboBox'),
    LuminaBlueprintWidgetElement(name: 'Pages', typeName: 'widgetSwitcher'),
  ]);

  setUp(() => LuminaWidgetClassRegistry.register(hud));
  tearDown(LuminaWidgetClassRegistry.clear);

  var wireCount = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${wireCount++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  test('Create Widget builds the elements map from the registered class; unknown classes have none', () {
    final actor = LuminaActor();
    final w = LuminaBlueprintFunctionLibrary.createWidget(actor, 'WBP_HUD') as Map<String, Object?>;
    expect(w.keys, containsAll(['class', 'owner', 'inViewport', 'zOrder', 'visibility', 'elements']));
    final elements = w['elements'] as Map<String, Object?>;
    expect(elements.keys, ['FPSCounter', 'Health', 'Title', 'Mode', 'Pages']);
    final fps = elements['FPSCounter'] as Map<String, Object?>;
    expect(fps['type'], 'text');
    expect(fps['text'], 'FPS: 0');
    expect(fps['fontSize'], 18.0);
    expect(fps['visibility'], 'Visible');
    expect(fps['isEnabled'], true);
    expect(fps['renderOpacity'], 1.0);
    final unknown = LuminaBlueprintFunctionLibrary.createWidget(actor, 'WBP_Nope') as Map<String, Object?>;
    expect(unknown['elements'], isEmpty);
    expect(LuminaBlueprintFunctionLibrary.isValid(unknown), isTrue);
    expect(LuminaBlueprintFunctionLibrary.getWidgetElement(unknown, 'FPSCounter'), isNull);
    expect(LuminaBlueprintFunctionLibrary.classOf(w), 'Widget:WBP_HUD');
    expect(LuminaBlueprintFunctionLibrary.classOf(fps), 'WidgetElement:text');
  });

  test('element setters write into the element map only and notify the widget subsystem once each', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = LuminaActor();
    world.persistentLevel.registerActor(actor);
    final subsystem = world.getSubsystem<LuminaWidgetSubsystem>()!;
    var notified = 0;
    subsystem.activeWidgets.addListener(() => notified++);
    final w = LuminaBlueprintFunctionLibrary.createWidget(actor, 'WBP_HUD') as Map<String, Object?>;
    LuminaBlueprintFunctionLibrary.addToViewport(actor, w);
    notified = 0;
    final fps = LuminaBlueprintFunctionLibrary.getWidgetElement(w, 'FPSCounter');
    final health = LuminaBlueprintFunctionLibrary.getWidgetElement(w, 'Health');
    final mode = LuminaBlueprintFunctionLibrary.getWidgetElement(w, 'Mode');
    final pages = LuminaBlueprintFunctionLibrary.getWidgetElement(w, 'Pages');

    LuminaBlueprintFunctionLibrary.setElementText(actor, fps, 'FPS: 60');
    expect(notified, 1);
    expect(LuminaBlueprintFunctionLibrary.getElementText(fps), 'FPS: 60');
    expect(LuminaBlueprintFunctionLibrary.getElementText(LuminaBlueprintFunctionLibrary.getWidgetElement(w, 'Title')),
        'Lumina', reason: 'the other Text block is untouched');
    expect(w.containsKey('text'), isFalse, reason: 'no shared top-level text');

    LuminaBlueprintFunctionLibrary.setElementPercent(actor, health, 0.25);
    LuminaBlueprintFunctionLibrary.setElementFillColor(actor, health, [1.0, 0.0, 0.0, 1.0]);
    LuminaBlueprintFunctionLibrary.setElementVisibility(actor, health, 'Hidden');
    LuminaBlueprintFunctionLibrary.setElementIsEnabled(actor, fps, false);
    LuminaBlueprintFunctionLibrary.setElementRenderOpacity(actor, fps, 0.5);
    LuminaBlueprintFunctionLibrary.setElementColor(actor, fps, [0.0, 1.0, 0.0, 1.0]);
    LuminaBlueprintFunctionLibrary.setElementFontSize(actor, fps, 32);
    LuminaBlueprintFunctionLibrary.addElementOption(actor, mode, 'Easy');
    LuminaBlueprintFunctionLibrary.addElementOption(actor, mode, 'Hard');
    LuminaBlueprintFunctionLibrary.setElementSelectedOption(actor, mode, 'Hard');
    LuminaBlueprintFunctionLibrary.setElementActiveIndex(actor, pages, 2);
    expect(notified, 12);
    expect(LuminaBlueprintFunctionLibrary.getElementPercent(health), 0.25);
    expect((health as Map)['fillColor'], [1.0, 0.0, 0.0, 1.0]);
    expect(LuminaBlueprintFunctionLibrary.getElementVisibility(health), 'Hidden');
    expect(LuminaBlueprintFunctionLibrary.isElementVisible(health), isFalse);
    expect(LuminaBlueprintFunctionLibrary.isElementVisible(fps), isTrue);
    expect(LuminaBlueprintFunctionLibrary.getElementIsEnabled(fps), isFalse);
    expect((fps as Map)['renderOpacity'], 0.5);
    expect(fps['color'], [0.0, 1.0, 0.0, 1.0]);
    expect(fps['fontSize'], 32.0);
    expect((mode as Map)['options'], ['Easy', 'Hard']);
    expect(LuminaBlueprintFunctionLibrary.getElementSelectedOption(mode), 'Hard');
    LuminaBlueprintFunctionLibrary.clearElementOptions(actor, mode);
    expect(mode['options'], isEmpty);
    expect(LuminaBlueprintFunctionLibrary.getElementSelectedOption(mode), '');
    expect(LuminaBlueprintFunctionLibrary.getElementActiveIndex(pages), 2);
    // Getters on a missing element read the type's default, never throw.
    expect(LuminaBlueprintFunctionLibrary.getElementText(null), '');
    expect(LuminaBlueprintFunctionLibrary.getElementPercent(null), 0.0);
    expect(LuminaBlueprintFunctionLibrary.isElementVisible(null), isFalse);
    world.cleanup();
  });

  test('shadcn elements take the nodes of the type they mean the same as', () {
    bool fits(String element, String node) => LuminaBlueprintObjectClass.isAssignable(
        LuminaBlueprintObjectClass.widgetElement(element), LuminaBlueprintNodeLibrary.spec(node)!.inputs.firstWhere((p) => p.id == 'target').objectClass);
    expect(fits('shadcnProgress', 'set_element_percent'), isTrue);
    expect(fits('shadcnSwitch', 'set_element_is_checked'), isTrue);
    expect(fits('shadcnCheckbox', 'get_element_is_checked'), isTrue);
    expect(fits('shadcnToggle', 'set_element_is_checked'), isTrue);
    expect(fits('shadcnSelect', 'set_element_selected_option'), isTrue);
    expect(fits('shadcnRadioGroup', 'set_element_selected_option'), isTrue);
    expect(fits('shadcnTabs', 'set_element_active_index'), isTrue);
    expect(fits('shadcnSlider', 'set_element_slider_value'), isTrue);
    expect(fits('shadcnTextField', 'set_element_editable_text'), isTrue);
    expect(fits('shadcnPrimaryButton', 'set_element_label'), isTrue);
    expect(fits('shadcnBadge', 'set_element_text'), isTrue);
    expect(fits('shadcnSwitch', 'set_element_percent'), isFalse, reason: 'a Switch is no Progress Bar');
    expect(fits('progressBar', 'set_element_background_color'), isFalse);
    expect(fits('container', 'set_element_background_color'), isTrue);
    expect(LuminaBlueprintObjectClass.displayName('WidgetElement:shadcnCard'), 'Card (shadcn)');
  });

  test('deprecated Set Text (Widget) writes every Text element, and the validator warns', () {
    final actor = LuminaActor();
    final w = LuminaBlueprintFunctionLibrary.createWidget(actor, 'WBP_HUD') as Map<String, Object?>;
    LuminaBlueprintFunctionLibrary.setWidgetText(actor, w, 'legacy');
    expect(w['text'], 'legacy', reason: 'the legacy top-level key the old runtime view reads');
    final elements = w['elements'] as Map<String, Object?>;
    expect((elements['FPSCounter'] as Map)['text'], 'legacy');
    expect((elements['Title'] as Map)['text'], 'legacy');
    expect((elements['Health'] as Map)['percent'], 1.0);
    LuminaBlueprintFunctionLibrary.setWidgetPercent(actor, w, 0.4);
    expect((elements['Health'] as Map)['percent'], 0.4);

    final doc = LuminaBlueprintDocument(eventGraph: LuminaBlueprintGraph(nodes: [
      LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'begin'),
      LuminaBlueprintNodeLibrary.place('set_widget_text', nodeId: 'legacy', literals: {'in_text': 'x'}),
    ], wires: [wire('begin', 'exec_out', 'legacy', 'exec_in')]));
    final diagnostics = validateBlueprint(doc);
    expect(diagnostics.where((d) => d.isError), isEmpty);
    expect(diagnostics.single.message, contains('Use Get <element> → Set Text (Text)'));
  });

  test('VM: BeginPlay creates the HUD, Tick writes FPSCounter; Health is untouched and each Set notifies once', () {
    const variables = [LuminaBlueprintVariable(name: 'HudWidget', typeName: 'Widget:WBP_HUD')];
    final context = LuminaBlueprintTypeContext(variables: variables, widgetClasses: const [hud]);
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    final doc = LuminaBlueprintDocument(variables: variables, eventGraph: LuminaBlueprintGraph(nodes: [
      place('event_beginplay', 'begin'),
      place('create_widget', 'create', {'class': 'WBP_HUD'}),
      place(LuminaBlueprintNodeLibrary.variableSet, 'set', {'variable': 'HudWidget'}),
      place('add_to_viewport', 'show'),
      place('event_tick', 'tick'),
      place(LuminaBlueprintNodeLibrary.variableGet, 'get', {'variable': 'HudWidget'}),
      place(LuminaBlueprintNodeLibrary.getWidgetElement, 'fps', {'element': 'FPSCounter'}),
      place('set_element_text', 'set_text', {'in_text': 'FPS: 60'}),
    ], wires: [
      wire('begin', 'exec_out', 'create', 'exec_in'),
      wire('create', 'exec_out', 'set', 'exec_in'),
      wire('create', 'return_value', 'set', 'value'),
      wire('set', 'exec_out', 'show', 'exec_in'),
      wire('set', 'value', 'show', 'target'),
      wire('tick', 'exec_tick_out', 'set_text', 'exec_in'),
      wire('get', 'value', 'fps', 'target'),
      wire('fps', 'return_value', 'set_text', 'target'),
    ]));
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_HudOwner');
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = cls.instantiate() as LuminaBlueprintInstance;
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    final subsystem = world.getSubsystem<LuminaWidgetSubsystem>()!;
    expect(subsystem.widgets.single['class'], 'WBP_HUD');
    var notified = 0;
    subsystem.activeWidgets.addListener(() => notified++);
    for (var i = 0; i < 5; i++) {
      world.tick(1 / 60);
    }
    final widget = actor.variables['HudWidget'] as Map<String, Object?>;
    final elements = widget['elements'] as Map<String, Object?>;
    expect((elements['FPSCounter'] as Map)['text'], 'FPS: 60');
    expect((elements['Health'] as Map)['percent'], 1.0);
    expect((elements['Title'] as Map)['text'], 'Lumina');
    expect(notified, 5, reason: 'one notification per Set Text');
    world.cleanup();
  });
}
