import 'package:lumina/lumina.dart';

/// `W_WristHud`: the small panel that reads the pose slot, the held handle
/// and the frame rate. Its graph keeps the frame rate current (Event Tick);
/// the slot and handle lines start empty.
///
/// The game shows it as a screen widget on a desktop; in the headset Lumina
/// has no world-space widget yet, so it is not drawn there.
abstract final class MetaXrPosingWidgets {
  static const String hudName = 'W_WristHud';
  static const String hudPath = 'contents/ui/$hudName.lmas';

  /// The `Is Variable` text elements.
  static const List<LuminaBlueprintWidgetElement> variables = [
    LuminaBlueprintWidgetElement(name: 'SlotText', fieldName: 'slotText', typeName: 'text', props: {'text': 'Slot 1'}),
    LuminaBlueprintWidgetElement(name: 'HandleText', fieldName: 'handleText', typeName: 'text', props: {'text': ''}),
    LuminaBlueprintWidgetElement(name: 'FpsText', fieldName: 'fpsText', typeName: 'text', props: {'text': ''}),
  ];

  /// The widget class as the registry knows it.
  static const LuminaBlueprintWidgetClass widgetClass = LuminaBlueprintWidgetClass(name: hudName, elements: variables);

  /// The graph: Event Tick → Set Text (FpsText, "FPS " + 1 / delta).
  static LuminaWidgetBlueprintDocument blueprint() {
    final widget = LuminaWidgetBlueprintDocument(widgetClass: hudName, variables: variables);
    final context = LuminaBlueprintTypeContext.forWidget(widget, widgetClasses: const [widgetClass]);
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire w(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    final g = widget.blueprint.eventGraph;
    g.nodes.addAll([
      p(LuminaBlueprintNodeLibrary.eventWidgetTick, 'tick'),
      p('float_divide', 'fps', {'a': 1.0}),
      p('float_to_string', 'fps_digits', {'decimals': 0}),
      p('append', 'fps_text', {'a': 'FPS '}),
      p(LuminaBlueprintNodeLibrary.getWidgetVariable, 'fps_element', {'element': 'FpsText'}),
      p('set_element_text', 'set_fps'),
    ]);
    g.wires.addAll([
      w('tick', 'exec_out', 'set_fps', 'exec_in'),
      w('tick', 'in_delta_time', 'fps', 'b'),
      w('fps', 'return_value', 'fps_digits', 'in_float'),
      w('fps_digits', 'return_value', 'fps_text', 'b'),
      w('fps_text', 'return_value', 'set_fps', 'in_text'),
      w('fps_element', 'return_value', 'set_fps', 'target'),
    ]);
    return widget;
  }

  static Map<String, dynamic> _text(String id, String name, String text) => {
        'id': id,
        'type': 'text',
        'name': name,
        'fieldName': '${name[0].toLowerCase()}${name.substring(1)}',
        'slot': {
          'kind': 'box',
          'padding': [8.0, 4.0, 8.0, 4.0],
          'fill': false,
          'flex': 1,
          'hAlign': 'start',
          'vAlign': 'center',
        },
        'props': {'text': text, 'color': '#FFFFFF', 'fontSize': 14.0},
        'events': <Object>[],
        'isVariable': true,
        'children': <Object>[],
      };

  /// The widget asset's designer document (the editor's UMG format) with the
  /// graph.
  static Map<String, dynamic> hudAsset() => {
        'version': 1,
        'designResolution': {'width': 1920, 'height': 1080},
        'dpiScale': 1.0,
        'root': {
          'id': 'umg_root',
          'type': 'canvasPanel',
          'name': 'Root Canvas',
          'fieldName': 'rootCanvas',
          'slot': {'kind': 'none'},
          'props': <String, dynamic>{},
          'events': <Object>[],
          'children': [
            {
              'id': 'hud_box',
              'type': 'verticalBox',
              'name': 'HudBox',
              'fieldName': 'hudBox',
              'slot': {
                'kind': 'canvas',
                'anchorMin': [0.0, 1.0],
                'anchorMax': [0.0, 1.0],
                'position': [24.0, -24.0],
                'size': [240.0, 96.0],
                'alignment': [0.0, 1.0],
                'sizeToContent': true,
                'zOrder': 0,
              },
              'props': <String, dynamic>{},
              'events': <Object>[],
              'children': [
                _text('hud_slot', 'SlotText', 'Slot 1'),
                _text('hud_handle', 'HandleText', ''),
                _text('hud_fps', 'FpsText', ''),
              ],
            },
          ],
        },
        LuminaWidgetBlueprintDocument.payloadKey: blueprint().toJson(),
      };
}
