// GENERATED CODE - DO NOT MODIFY BY HAND (edit only inside USER CODE regions)
// Lumina Studio UMG Designer: WBP_Clicker (designed at 1920x1080, DPI 1.0)
// ignore_for_file: file_names, unused_import, unnecessary_import, unused_shown_name, unused_element, unused_field, unused_local_variable, prefer_const_constructors, camel_case_types, non_constant_identifier_names, unnecessary_this, dead_code, dead_null_aware_expression

import 'package:lumina_widgets/lumina_game.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2, Vector3;
import 'package:shadcn_flutter/shadcn_flutter.dart';

// BEGIN USER CODE: imports
// END USER CODE

/// `WBP_Clicker` as designed in Lumina Studio.
class WbpClicker extends StatefulWidget {
  const WbpClicker({super.key, this.instance});

  /// The widget instance this class renders (the map `Create Widget` built):
  /// every element reads its live state from it through
  /// `LuminaUmgElementBinding`. Null in a preview: the designer's values apply.
  final Map<String, Object?>? instance;

  @override
  State<WbpClicker> createState() => _WbpClickerState();
}

class _WbpClickerState extends State<WbpClicker> {
  // BEGIN USER CODE: class_body
  // END USER CODE

  /// `OnClicked` of `StartButton` (Button).
  void _onClickedStartButton() {
    LuminaUserWidgets.fire(widget.instance, 'StartButton', 'OnClicked');
    // BEGIN USER CODE: on_clicked_startButton
    // END USER CODE
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('rootCanvas'),
      builder: (context, constraints) {
        final w = constraints.hasBoundedWidth ? constraints.maxWidth : 1920.0;
        final h = constraints.hasBoundedHeight ? constraints.maxHeight : 1080.0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // StartButton (Button)
            _umgCanvasSlot(
              _umgCanvasRect(w, h, 0.0, 0.0, 0.0, 0.0, 40.0, 40.0, 160.0, 44.0, 0.0, 0.0),
              false,
              LuminaUmgElement(
                instance: widget.instance,
                name: 'StartButton',
                builder: (context, e) => Button(
                  key: const ValueKey('startButton'),
                  style: const ButtonStyle.primary(),
                  onPressed: LuminaUmgElementBinding.isEnabled(e) ? _onClickedStartButton : null,
                  child: LuminaUmgText(LuminaUmgElementBinding.value<String>(e, 'label', 'Start'), style: TextStyle(fontSize: LuminaUmgElementBinding.value<double>(e, 'fontSize', 14.0), color: LuminaUmgElementBinding.color(e, 'color', Color(0xFFFFFFFF)), shadows: LuminaUmgElementBinding.shadow(e, const LuminaUmgTextShadow(enabled: false, color: Color(0xB3000000), offsetX: 1.0, offsetY: 1.0, blur: 0.0)).shadows), outline: LuminaUmgElementBinding.outline(e, const LuminaUmgTextOutline(size: 0.0, color: Color(0xFF000000)))),
                ),
              ),
            ),
            // Title (Text)
            _umgCanvasSlot(
              _umgCanvasRect(w, h, 0.0, 0.0, 0.0, 0.0, 40.0, 120.0, 200.0, 32.0, 0.0, 0.0),
              false,
              LuminaUmgElement(
                instance: widget.instance,
                name: 'Title',
                builder: (context, e) => LuminaUmgText(
                  key: const ValueKey('title'),
                  LuminaUmgElementBinding.value<String>(e, 'text', 'Waiting'),
                  style: TextStyle(fontSize: LuminaUmgElementBinding.value<double>(e, 'fontSize', 16.0), color: LuminaUmgElementBinding.color(e, 'color', Color(0xFFFFFFFF)), shadows: LuminaUmgElementBinding.shadow(e, const LuminaUmgTextShadow(enabled: false, color: Color(0xB3000000), offsetX: 1.0, offsetY: 1.0, blur: 0.0)).shadows),
                  outline: LuminaUmgElementBinding.outline(e, const LuminaUmgTextOutline(size: 0.0, color: Color(0xFF000000))),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Widget `WBP_Clicker`'s graph, compiled by Lumina: the script
/// `Create Widget` gives every instance of the widget in the built game.
class WbpClickerGraph extends LuminaUserWidget with LuminaBlueprintRuntime {
  WbpClickerGraph() {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'WBP_Clicker';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
  ];

  @override
  void onTick(double deltaSeconds) {
    super.onTick(deltaSeconds);
    advanceBlueprintLatent(deltaSeconds);
  }

  @override
  void onWidgetConstruct() {
    _onConstruct();
  }

  /// The bound element events (`On Clicked (StartButton)`, …) by element and event.
  @override
  void onWidgetEvent(String element, String event, Map<String, Object?> args) {
    switch ((element, event)) {
      case ('StartButton', 'OnClicked'):
        _onClicked();
    }
  }

  /// Event Construct (node construct).
  void _onConstruct() {
    final p0 = LuminaBlueprintFunctionLibrary.getWidgetVariable(this, 'Title');
    if (trace != null) blueprintTrace('construct', 'title', 'get_widget_variable', {'return_value': p0});
    LuminaBlueprintFunctionLibrary.setElementVisibility(this, p0, 'Visible');
    if (trace != null) blueprintTrace('construct', 'show', 'set_element_visibility', {'target': p0, 'in_visibility': 'Visible'});
  }

  /// On Clicked (StartButton) (node clicked).
  void _onClicked() {
    final p1 = LuminaBlueprintFunctionLibrary.getWidgetVariable(this, 'Title');
    if (trace != null) blueprintTrace('clicked', 'title', 'get_widget_variable', {'return_value': p1});
    LuminaBlueprintFunctionLibrary.setElementText(this, p1, 'Clicked!');
    if (trace != null) blueprintTrace('clicked', 'set_text', 'set_element_text', {'target': p1, 'in_text': 'Clicked!'});
  }
}

/// Resolves a Canvas Panel slot with anchor semantics inside a parent of [w]x[h].
Rect _umgCanvasRect(double w, double h, double minX, double minY, double maxX, double maxY, double posX, double posY, double sizeX, double sizeY, double alignX, double alignY) {
  double left;
  double width;
  if (minX == maxX) {
    width = sizeX;
    left = minX * w + posX - alignX * width;
  } else {
    left = minX * w + posX;
    width = (maxX * w - sizeX - left).clamp(0.0, double.infinity);
  }
  double top;
  double height;
  if (minY == maxY) {
    height = sizeY;
    top = minY * h + posY - alignY * height;
  } else {
    top = minY * h + posY;
    height = (maxY * h - sizeY - top).clamp(0.0, double.infinity);
  }
  return Rect.fromLTWH(left, top, width, height);
}

/// Places a resolved canvas slot; size-to-content slots only pin their origin.
Widget _umgCanvasSlot(Rect r, bool sizeToContent, Widget child) {
  return Positioned(left: r.left, top: r.top, width: sizeToContent ? null : r.width, height: sizeToContent ? null : r.height, child: child);
}
