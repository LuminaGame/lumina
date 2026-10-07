import 'package:lumina/src/blueprint/blueprint_model.dart';
import 'package:lumina/src/blueprint/widget_classes.dart';

/// A widget asset's own Blueprint graph (the Widget Blueprint Graph): the
/// widget class it scripts, its `Is Variable` elements (typed
/// members `Get <Element>` reads with no target) and the graph document
/// itself — event graph, variables, functions, macros, dispatchers — whose
/// parent class is always [parentClass]. The editor stores [blueprint]'s
/// JSON inside the widget `.lmas` payload, beside the designer tree.
class LuminaWidgetBlueprintDocument {
  /// The `kind` discriminator of the stored payload.
  static const String kind = 'widget_blueprint';

  /// The payload key the designer document stores the graph under.
  static const String payloadKey = 'blueprint';

  /// The class every widget script is (`Self` is the widget instance).
  static const String parentClass = 'LuminaUserWidget';

  /// The widget class (`WBP_Clicker`).
  final String widgetClass;

  /// The elements marked `Is Variable`, by designer name.
  final List<LuminaBlueprintWidgetElement> variables;

  /// The graph (`parentClass` is always [parentClass]; no components).
  final LuminaBlueprintDocument blueprint;

  LuminaWidgetBlueprintDocument({
    required this.widgetClass,
    this.variables = const [],
    LuminaBlueprintDocument? blueprint,
  }) : blueprint = blueprint ?? LuminaBlueprintDocument(parentClass: parentClass) {
    this.blueprint.parentClass = parentClass;
  }

  /// The pin class of the widget itself (`Widget:WBP_Clicker`), what Self is.
  String get selfClass => LuminaBlueprintObjectClass.widget(widgetClass);

  /// The variable element [name], or null.
  LuminaBlueprintWidgetElement? variable(String? name) {
    for (final v in variables) {
      if (v.name == name) return v;
    }
    return null;
  }

  /// Whether the graph does nothing: no nodes, variables or functions.
  bool get isEmpty =>
      blueprint.eventGraph.nodes.isEmpty &&
      blueprint.variables.isEmpty &&
      blueprint.functions.isEmpty &&
      blueprint.macros.isEmpty &&
      blueprint.dispatchers.isEmpty;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'widgetClass': widgetClass,
        'widgetVariables': variables.map((v) => v.toJson()).toList(),
        ...blueprint.toJson(),
      };

  factory LuminaWidgetBlueprintDocument.fromJson(Map<String, dynamic> map, {String? widgetClass}) =>
      LuminaWidgetBlueprintDocument(
        widgetClass: widgetClass ?? map['widgetClass'] as String? ?? '',
        variables: [
          for (final v in map['widgetVariables'] as List? ?? const [])
            if (v is Map) LuminaBlueprintWidgetElement.fromJson(Map<String, dynamic>.from(v)),
        ],
        blueprint: LuminaBlueprintDocument.fromJson(map),
      );

  /// A fresh widget graph: parent [parentClass], nothing placed.
  static LuminaBlueprintDocument emptyGraph() => LuminaBlueprintDocument(parentClass: parentClass);
}

/// The events each widget element type can bind in a Widget Blueprint graph
/// (the green `+` buttons in the Details panel), by the
/// designer's element type name (`button`, `slider`, `shadcnTextField`, …).
abstract final class LuminaWidgetEvents {
  static const String onClicked = 'OnClicked';
  static const String onHovered = 'OnHovered';
  static const String onUnhovered = 'OnUnhovered';
  static const String onValueChanged = 'OnValueChanged';
  static const String onTextCommitted = 'OnTextCommitted';

  static const Set<String> _shadcnButtons = {
    'shadcnPrimaryButton',
    'shadcnSecondaryButton',
    'shadcnOutlineButton',
    'shadcnGhostButton',
    'shadcnDestructiveButton',
    'shadcnLinkButton',
  };

  static const Set<String> _valueTypes = {
    'slider',
    'checkBox',
    'comboBox',
    'shadcnSwitch',
    'shadcnToggle',
    'shadcnCheckbox',
    'shadcnSelect',
    'shadcnRadioGroup',
    'shadcnTabs',
    'shadcnSlider',
  };

  static const Set<String> _textTypes = {'editableText', 'shadcnTextField', 'shadcnTextArea'};

  /// The events an element of [typeName] offers, in the Details panel's order.
  static List<String> forType(String typeName) {
    if (typeName == 'button') return const [onClicked, onHovered, onUnhovered];
    if (_shadcnButtons.contains(typeName)) return const [onClicked];
    if (_textTypes.contains(typeName)) return const [onValueChanged, onTextCommitted];
    if (_valueTypes.contains(typeName)) return const [onValueChanged];
    return const [];
  }

  /// `OnClicked` → `On Clicked` (the bound event node's title prefix).
  static String displayName(String event) =>
      event.replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (m) => ' ');

  /// The pin type name of `On Value Changed`'s `Value` for [typeName]:
  /// `float` (sliders), `boolean` (check boxes, switches, toggles),
  /// `integer` (tabs), `string` (texts, combo boxes, selects).
  static String valueTypeOf(String typeName) => switch (typeName) {
        'slider' || 'shadcnSlider' => 'float',
        'checkBox' || 'shadcnSwitch' || 'shadcnToggle' || 'shadcnCheckbox' => 'boolean',
        'shadcnTabs' => 'integer',
        _ => 'string',
      };

  /// `ETextCommit` (On Text Committed's Commit Method).
  static const List<String> commitMethods = ['Default', 'OnEnter', 'OnUserMovedFocus', 'OnCleared'];
}
