import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The text-style and container element nodes write the designer keys the
/// UMG element bindings render (shadow, outline, container style).
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
}
