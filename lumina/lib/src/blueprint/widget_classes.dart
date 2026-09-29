import 'blueprint_model.dart';

/// One named element of a widget class: what `Get <Name>`
/// returns on a `Widget:<class>` pin. [typeName] is the UmgWidgetType name
/// (`text`, `progressBar`, `button`, …); [props] are the designer's stored
/// properties, which seed the element's runtime state.
class LuminaBlueprintWidgetElement {
  final String name;

  /// The Dart field the generated widget class exposes it as.
  final String fieldName;
  final String typeName;
  final Map<String, dynamic> props;

  const LuminaBlueprintWidgetElement({
    required this.name,
    String? fieldName,
    required this.typeName,
    this.props = const {},
  }) : fieldName = fieldName ?? name;

  /// The pin class of this element: `WidgetElement:text`.
  String get objectClass => LuminaBlueprintObjectClass.widgetElement(typeName);

  Map<String, dynamic> toJson() => {
        'name': name,
        'fieldName': fieldName,
        'type': typeName,
        'props': props,
      };

  factory LuminaBlueprintWidgetElement.fromJson(Map<String, dynamic> map) => LuminaBlueprintWidgetElement(
        name: map['name'] as String? ?? '',
        fieldName: map['fieldName'] as String?,
        typeName: map['type'] as String? ?? 'text',
        props: Map<String, dynamic>.from(map['props'] as Map? ?? const {}),
      );
}

/// The engine's plain description of a widget class (a UMG `.lmas`
/// document as the Blueprint side sees it): its name and its named elements.
/// The editor converts its `UmgDocument`; the generated game fills
/// [LuminaWidgetClassRegistry] from its compiled widget classes.
class LuminaBlueprintWidgetClass {
  final String name;
  final List<LuminaBlueprintWidgetElement> elements;

  const LuminaBlueprintWidgetClass({required this.name, this.elements = const []});

  /// The pin class of this widget: `Widget:WBP_HUD`.
  String get objectClass => LuminaBlueprintObjectClass.widget(name);

  LuminaBlueprintWidgetElement? element(String? name) {
    for (final e in elements) {
      if (e.name == name || e.fieldName == name) return e;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'elements': elements.map((e) => e.toJson()).toList(),
      };

  factory LuminaBlueprintWidgetClass.fromJson(Map<String, dynamic> map) => LuminaBlueprintWidgetClass(
        name: map['name'] as String? ?? '',
        elements: (map['elements'] as List? ?? const [])
            .map((e) => LuminaBlueprintWidgetElement.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// The widget classes a running game or the editor knows:
/// `Create Widget` builds a widget instance's per-element state from the
/// class found here. Unknown classes still create a widget with no elements.
abstract final class LuminaWidgetClassRegistry {
  static final Map<String, LuminaBlueprintWidgetClass> _classes = {};

  /// Adds or replaces [cls] under its name.
  static void register(LuminaBlueprintWidgetClass cls) => _classes[cls.name] = cls;

  static void registerAll(Iterable<LuminaBlueprintWidgetClass> classes) => classes.forEach(register);

  static LuminaBlueprintWidgetClass? lookup(String? name) => name == null ? null : _classes[name];

  static void unregister(String name) => _classes.remove(name);

  static void clear() => _classes.clear();

  static bool get isEmpty => _classes.isEmpty;

  /// Every registered class, in registration order.
  static List<LuminaBlueprintWidgetClass> get classes => List.unmodifiable(_classes.values);

  /// A fresh widget instance's `elements` map for [className]: one JSON-plain
  /// map per element, seeded from the designer's properties.
  static Map<String, Object?> elementsFor(String className) {
    final cls = lookup(className);
    if (cls == null) return <String, Object?>{};
    return {for (final e in cls.elements) e.name: newElementState(e)};
  }

  /// The runtime state of one element: its type, the common properties every
  /// element has, then the designer's stored properties.
  static Map<String, Object?> newElementState(LuminaBlueprintWidgetElement e) => <String, Object?>{
        'type': e.typeName,
        'name': e.name,
        'visibility': 'Visible',
        'isEnabled': true,
        'renderOpacity': 1.0,
        ...Map<String, Object?>.from(e.props),
      };
}

/// One component of a Blueprint's component tree as the type context sees
/// it: `Get <name>` yields a `Component:<componentClass>`.
class LuminaBlueprintComponentRef {
  final String name;
  final String componentClass;

  /// The component's id in the document, where the runtime finds it.
  final String? id;

  const LuminaBlueprintComponentRef({required this.name, required this.componentClass, this.id});

  /// The pin class: `Component:LuminaSpringArmComponent`.
  String get objectClass => LuminaBlueprintObjectClass.component(componentClass);

  /// The refs of a document's components (editor-only components too: they
  /// are typed, and null at run time).
  static List<LuminaBlueprintComponentRef> fromComponents(List<LuminaBlueprintComponent> components) => [
        for (final c in components) LuminaBlueprintComponentRef(name: c.name, componentClass: c.type, id: c.id),
      ];
}
