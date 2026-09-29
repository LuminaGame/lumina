import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

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

  test('shadow and outline setters write the designer keys of any text-bearing element, one notification each', () {
    for (final id in ['set_element_shadow_enabled', 'set_element_shadow_color', 'set_element_shadow_offset', 'set_element_outline']) {
      final spec = LuminaBlueprintNodeLibrary.spec(id)!;
      expect(spec.category, 'Widget|Text');
      expect(spec.inputs.firstWhere((p) => p.id == 'target').objectClass, LuminaBlueprintObjectClass.widgetElementKind,
          reason: '$id takes any element: Button, Check Box, Editable Text and Combo Box labels carry text too');
      expect(LuminaBlueprintFunctionLibrary.callShapes.containsKey(id), isTrue, reason: '$id is generated as a call');
    }
    expect(LuminaBlueprintNodeLibrary.spec('set_element_shadow_offset')!.inputs.last.type, LuminaPinType.vector2D);
    expect(LuminaBlueprintNodeLibrary.spec('set_element_outline')!.inputs.map((p) => p.id), ['exec_in', 'target', 'in_size', 'in_color']);

    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = LuminaActor();
    world.persistentLevel.registerActor(actor);
    var notified = 0;
    world.getSubsystem<LuminaWidgetSubsystem>()!.activeWidgets.addListener(() => notified++);
    final w = LuminaBlueprintFunctionLibrary.createWidget(actor, 'WBP_HUD') as Map<String, Object?>;
    LuminaBlueprintFunctionLibrary.addToViewport(actor, w);
    notified = 0;
    final fps = LuminaBlueprintFunctionLibrary.getWidgetElement(w, 'FPSCounter') as Map<String, Object?>;
    final mode = LuminaBlueprintFunctionLibrary.getWidgetElement(w, 'Mode') as Map<String, Object?>;

    LuminaBlueprintFunctionLibrary.setElementShadowEnabled(actor, fps, true);
    LuminaBlueprintFunctionLibrary.setElementShadowColor(actor, fps, [1.0, 0.0, 0.0, 0.5]);
    LuminaBlueprintFunctionLibrary.setElementShadowOffset(actor, fps, Vector2(3, 4));
    LuminaBlueprintFunctionLibrary.setElementOutline(actor, mode, 2, [0.0, 0.0, 0.0, 1.0]);
    expect(notified, 4, reason: 'a two-key setter still notifies once');
    expect(fps['shadowEnabled'], isTrue);
    expect(fps['shadowColor'], [1.0, 0.0, 0.0, 0.5]);
    expect(fps['shadowOffsetX'], 3.0);
    expect(fps['shadowOffsetY'], 4.0);
    expect(mode['outlineSize'], 2.0);
    expect(mode['outlineColor'], [0.0, 0.0, 0.0, 1.0]);
    expect(LuminaUmgElementBinding.shadow(fps, LuminaUmgTextShadow.defaults).shadows,
        [const Shadow(color: Color(0x80FF0000), offset: Offset(3, 4))], reason: 'what the widget binding renders');
    expect(LuminaUmgElementBinding.outline(mode, LuminaUmgTextOutline.defaults), const LuminaUmgTextOutline(size: 2, color: Color(0xFF000000)));
    LuminaBlueprintFunctionLibrary.setElementOutline(actor, mode, -1, [0.0, 0.0, 0.0, 1.0]);
    expect(mode['outlineSize'], 0.0, reason: 'a negative size is no outline');
    // A missing element is ignored, never a throw.
    LuminaBlueprintFunctionLibrary.setElementShadowOffset(actor, null, Vector2(1, 1));
    LuminaBlueprintFunctionLibrary.setElementOutline(actor, null, 1, [0.0, 0.0, 0.0, 1.0]);
    world.cleanup();
  });

  test('VM: Get FPSCounter → Set Shadow Enabled → Set Shadow Color and Opacity → Set Shadow Offset → Set Outline on BeginPlay', () {
    const variables = [LuminaBlueprintVariable(name: 'HudWidget', typeName: 'Widget:WBP_HUD')];
    final context = LuminaBlueprintTypeContext(variables: variables, widgetClasses: const [hud]);
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    final doc = LuminaBlueprintDocument(variables: variables, eventGraph: LuminaBlueprintGraph(nodes: [
      place('event_beginplay', 'begin'),
      place('create_widget', 'create', {'class': 'WBP_HUD'}),
      place(LuminaBlueprintNodeLibrary.variableSet, 'set', {'variable': 'HudWidget'}),
      place('add_to_viewport', 'show'),
      place(LuminaBlueprintNodeLibrary.getWidgetElement, 'fps', {'element': 'FPSCounter'}),
      place('set_element_shadow_enabled', 'enable'),
      place('set_element_shadow_color', 'color', {'in_color': [0.0, 0.0, 1.0, 0.5]}),
      place('set_element_shadow_offset', 'offset', {'in_offset': [2.0, -2.0]}),
      place('set_element_outline', 'outline', {'in_size': 1.5, 'in_color': [1.0, 1.0, 0.0, 1.0]}),
    ], wires: [
      wire('begin', 'exec_out', 'create', 'exec_in'),
      wire('create', 'exec_out', 'set', 'exec_in'),
      wire('create', 'return_value', 'set', 'value'),
      wire('set', 'exec_out', 'show', 'exec_in'),
      wire('set', 'value', 'show', 'target'),
      wire('set', 'value', 'fps', 'target'),
      wire('show', 'exec_out', 'enable', 'exec_in'),
      wire('fps', 'return_value', 'enable', 'target'),
      wire('enable', 'exec_out', 'color', 'exec_in'),
      wire('fps', 'return_value', 'color', 'target'),
      wire('color', 'exec_out', 'offset', 'exec_in'),
      wire('fps', 'return_value', 'offset', 'target'),
      wire('offset', 'exec_out', 'outline', 'exec_in'),
      wire('fps', 'return_value', 'outline', 'target'),
    ]));
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_ShadowOwner');
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = cls.instantiate() as LuminaBlueprintInstance;
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    final fps = ((actor.variables['HudWidget'] as Map)['elements'] as Map)['FPSCounter'] as Map<String, Object?>;
    expect(LuminaUmgElementBinding.shadow(fps, LuminaUmgTextShadow.defaults),
        const LuminaUmgTextShadow(enabled: true, color: Color(0x800000FF), offsetX: 2, offsetY: -2));
    expect(LuminaUmgElementBinding.outline(fps, LuminaUmgTextOutline.defaults), const LuminaUmgTextOutline(size: 1.5, color: Color(0xFFFFFF00)));
    world.cleanup();
  });

  test('Container setters write background, border, corner radius and padding under the designer keys', () {
    for (final id in ['set_element_background_color', 'set_element_border_color', 'set_element_corner_radius', 'set_element_padding']) {
      final spec = LuminaBlueprintNodeLibrary.spec(id)!;
      expect(spec.category, 'Widget|Container');
      expect(spec.inputs.firstWhere((p) => p.id == 'target').objectClass, 'WidgetElement:container');
      expect(LuminaBlueprintFunctionLibrary.callShapes.containsKey(id), isTrue);
    }
    expect(LuminaBlueprintNodeLibrary.spec('set_element_padding')!.inputs.map((p) => p.id), ['exec_in', 'target', 'left', 'top', 'right', 'bottom']);

    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = LuminaActor();
    world.persistentLevel.registerActor(actor);
    var notified = 0;
    world.getSubsystem<LuminaWidgetSubsystem>()!.activeWidgets.addListener(() => notified++);
    final panel = <String, Object?>{'type': 'container', 'name': 'Panel', 'backgroundColor': '#1E1E2AFF'};
    LuminaBlueprintFunctionLibrary.setElementBackgroundColor(actor, panel, [1.0, 0.0, 0.0, 1.0]);
    LuminaBlueprintFunctionLibrary.setElementBorderColor(actor, panel, [0.0, 1.0, 0.0, 1.0]);
    LuminaBlueprintFunctionLibrary.setElementCornerRadius(actor, panel, 12);
    LuminaBlueprintFunctionLibrary.setElementPadding(actor, panel, 1, 2, 3, 4);
    expect(notified, 4);
    final style = LuminaUmgElementBinding.containerStyle(panel, const LuminaUmgContainerStyle());
    expect(style.backgroundColor, const Color(0xFFFF0000));
    expect(style.borderColor, const Color(0xFF00FF00));
    expect(style.cornerRadius, BorderRadius.circular(12));
    expect(style.padding, const EdgeInsets.fromLTRB(1, 2, 3, 4));
    LuminaBlueprintFunctionLibrary.setElementCornerRadius(actor, panel, -3);
    expect(panel['cornerRadius'], 0.0);
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
