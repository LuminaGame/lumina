part of '../blueprint_function_library.dart';

// --- Objects, validity, casting -----------------------------

bool _isWidgetInstance(Object? o) => o is Map<String, Object?> && o.containsKey('elements') && o['class'] is String;

bool _isWidgetElement(Object? o) =>
    o is Map<String, Object?> && o['type'] is String && o.containsKey('visibility') && !o.containsKey('elements');

String _classOf(Object? o) {
  if (o == null) return '';
  if (o is Map<String, Object?> && LuminaBlueprintFunctionLibrary.isWidgetInstance(o)) return LuminaBlueprintObjectClass.widget(o['class'] as String);
  if (o is Map<String, Object?> && LuminaBlueprintFunctionLibrary.isWidgetElement(o)) return LuminaBlueprintObjectClass.widgetElement(o['type'] as String);
  if (o is LuminaActorComponent) return LuminaBlueprintObjectClass.component(LuminaBlueprintComponents.classNameOf(o));
  if (o is LuminaActor) return LuminaBlueprintObjectClass.actor(_actorClassName(o));
  if (o is LuminaBlueprintSaveGame) return LuminaBlueprintObjectClass.saveGame(o.className);
  if (o is LuminaSaveGame) return LuminaBlueprintObjectClass.saveGameKind;
  return LuminaBlueprintObjectClass.any;
}

String _actorClassName(LuminaActor a) {
  if (a is LuminaBlueprintRuntime) return a.blueprintClassName;
  if (a is LuminaCharacter) return 'LuminaCharacter';
  if (a is LuminaPawn) return 'LuminaPawn';
  return 'LuminaActor';
}

List<String> _actorClassChain(LuminaActor a) => [
      _actorClassName(a),
      if (a is LuminaCharacter) 'LuminaCharacter',
      if (a is LuminaPawn) 'LuminaPawn',
      // The placed-actor classes a Level Blueprint types.
      if (a is LuminaPlayerStart) 'LuminaPlayerStart',
      if (a is LuminaTriggerVolume) 'LuminaTriggerVolume',
      if (a is LuminaBlockingVolume) 'LuminaBlockingVolume',
      if (a is LuminaVolume) 'LuminaVolume',
      if (a is LuminaLevelScriptActor) 'LuminaLevelScriptActor',
      'LuminaActor',
    ];

bool _isA(Object? o, String cls) {
  if (o == null) return false;
  if (cls.isEmpty || cls == LuminaBlueprintObjectClass.any) return true;
  final kind = LuminaBlueprintObjectClass.kind(cls);
  final name = LuminaBlueprintObjectClass.name(cls);
  final own = LuminaBlueprintFunctionLibrary.classOf(o);
  if (LuminaBlueprintObjectClass.kind(own) != kind) return false;
  if (name.isEmpty) return true;
  switch (kind) {
    case LuminaBlueprintObjectClass.actorKind:
      return LuminaBlueprintFunctionLibrary.actorClassChain(o as LuminaActor).contains(name);
    case LuminaBlueprintObjectClass.componentKind:
      return LuminaBlueprintComponents.isA(o as LuminaActorComponent, name);
    default:
      return LuminaBlueprintObjectClass.name(own) == name;
  }
}

bool _isValid(Object? inputObject) {
  if (inputObject == null) return false;
  if (inputObject is LuminaActor) return !inputObject.isDestroyed;
  return true;
}

Object? _castTo(Object? object, String cls) => LuminaBlueprintFunctionLibrary.isValid(object) && LuminaBlueprintFunctionLibrary.isA(object, cls) ? object : null;

String _getClassName(Object? object) {
  if (object == null) return 'None';
  final cls = LuminaBlueprintFunctionLibrary.classOf(object);
  return cls == LuminaBlueprintObjectClass.any ? object.runtimeType.toString() : LuminaBlueprintObjectClass.name(cls);
}

String _getDisplayName(Object? object) {
  if (object == null) return 'None';
  if (object is Map<String, Object?> && LuminaBlueprintFunctionLibrary.isWidgetInstance(object)) return object['class'] as String;
  if (object is Map<String, Object?> && LuminaBlueprintFunctionLibrary.isWidgetElement(object)) {
    return object['name'] as String? ?? object['type'] as String;
  }
  if (object is LuminaActorComponent) {
    final owner = object.owner;
    if (owner is LuminaBlueprintRuntime) {
      for (final c in owner.blueprintComponentTree) {
        if (identical(owner.blueprintComponents[c.id], object)) return c.name;
      }
    }
    return object.componentName ?? LuminaBlueprintComponents.classNameOf(object);
  }
  if (object is LuminaActor) {
    final key = object.key;
    return key == null ? _actorClassName(object) : '${_actorClassName(object)} ($key)';
  }
  return object.toString();
}

// --- Widget elements ----------------------------------------

Object? _getWidgetElement(Object? target, String element) {
  if (target is! Map<String, Object?>) return null;
  final elements = target['elements'];
  if (elements is! Map) return null;
  final e = elements[element];
  return e is Map<String, Object?> ? e : null;
}

void _setElement(LuminaActor self, Object? target, String key, Object? value) {
  if (target is Map<String, Object?>) {
    target[key] = value;
    self.world?.getSubsystem<LuminaWidgetSubsystem>()?.notifyChanged();
  }
}

T _getElement<T>(Object? target, String key, T fallback) {
  if (target is Map<String, Object?>) {
    final v = target[key];
    if (v is T) return v;
    if (T == double && v is num) return v.toDouble() as T;
    if (T == int && v is num) return v.toInt() as T;
  }
  return fallback;
}

void _setElementVisibility(LuminaActor self, Object? target, [String inVisibility = 'Visible']) =>
    _setElement(self, target, 'visibility', inVisibility);

String _getElementVisibility(Object? target) => _getElement(target, 'visibility', 'Visible');

bool _isElementVisible(Object? target) {
  final v = LuminaBlueprintFunctionLibrary.getElementVisibility(target);
  return target != null && v != 'Hidden' && v != 'Collapsed';
}

void _setElementIsEnabled(LuminaActor self, Object? target, [bool inIsEnabled = true]) =>
    _setElement(self, target, 'isEnabled', inIsEnabled);

bool _getElementIsEnabled(Object? target) => _getElement(target, 'isEnabled', true);

void _setElementRenderOpacity(LuminaActor self, Object? target, [double inOpacity = 1.0]) =>
    _setElement(self, target, 'renderOpacity', inOpacity.clamp(0.0, 1.0));

void _setElementText(LuminaActor self, Object? target, [String inText = '']) =>
    _setElement(self, target, 'text', inText);

String _getElementText(Object? target) => _getElement(target, 'text', '');

void _setElementColor(LuminaActor self, Object? target, List<double> inColor) =>
    _setElement(self, target, 'color', List<double>.from(inColor));

void _setElementFontSize(LuminaActor self, Object? target, [double inSize = 24.0]) =>
    _setElement(self, target, 'fontSize', inSize);

// Text shadow and outline, under the designer's own keys.
void _setElementShadowEnabled(LuminaActor self, Object? target, [bool inEnabled = true]) =>
    _setElement(self, target, 'shadowEnabled', inEnabled);

void _setElementShadowColor(LuminaActor self, Object? target, List<double> inColor) =>
    _setElement(self, target, 'shadowColor', List<double>.from(inColor));

void _setElementShadowOffset(LuminaActor self, Object? target, Vector2 inOffset) {
  if (target is Map<String, Object?>) target['shadowOffsetX'] = inOffset.x;
  _setElement(self, target, 'shadowOffsetY', inOffset.y);
}

void _setElementOutline(LuminaActor self, Object? target, double inSize, List<double> inColor) {
  if (target is Map<String, Object?>) target['outlineSize'] = inSize < 0 ? 0.0 : inSize;
  _setElement(self, target, 'outlineColor', List<double>.from(inColor));
}

void _setElementPercent(LuminaActor self, Object? target, [double inPercent = 1.0]) =>
    _setElement(self, target, 'percent', inPercent.clamp(0.0, 1.0));

double _getElementPercent(Object? target) => _getElement(target, 'percent', 0.0);

void _setElementFillColor(LuminaActor self, Object? target, List<double> inColor) =>
    _setElement(self, target, 'fillColor', List<double>.from(inColor));

void _setElementBrushFromTexture(LuminaActor self, Object? target, [String texture = '']) =>
    _setElement(self, target, 'texture', texture);

void _setElementImageColor(LuminaActor self, Object? target, List<double> inColor) =>
    _setElement(self, target, 'color', List<double>.from(inColor));

void _setElementLabel(LuminaActor self, Object? target, [String inLabel = '']) =>
    _setElement(self, target, 'label', inLabel);

void _setElementSliderValue(LuminaActor self, Object? target, [double inValue = 0.0]) =>
    _setElement(self, target, 'value', inValue);

double _getElementSliderValue(Object? target) => _getElement(target, 'value', 0.0);

void _setElementIsChecked(LuminaActor self, Object? target, [bool inIsChecked = false]) =>
    _setElement(self, target, 'isChecked', inIsChecked);

bool _getElementIsChecked(Object? target) => _getElement(target, 'isChecked', false);

void _setElementEditableText(LuminaActor self, Object? target, [String inText = '']) =>
    _setElement(self, target, 'text', inText);

String _getElementEditableText(Object? target) => _getElement(target, 'text', '');

void _setElementHintText(LuminaActor self, Object? target, [String inHintText = '']) =>
    _setElement(self, target, 'hintText', inHintText);

void _setElementSelectedOption(LuminaActor self, Object? target, [String option = '']) =>
    _setElement(self, target, 'selectedOption', option);

String _getElementSelectedOption(Object? target) => _getElement(target, 'selectedOption', '');

void _addElementOption(LuminaActor self, Object? target, [String option = '']) {
  if (target is Map<String, Object?>) {
    final options = target['options'];
    final list = options is List ? List<Object?>.from(options) : <Object?>[];
    list.add(option);
    _setElement(self, target, 'options', list);
  }
}

void _clearElementOptions(LuminaActor self, Object? target) {
  if (target is Map<String, Object?>) {
    target['selectedOption'] = '';
    _setElement(self, target, 'options', <Object?>[]);
  }
}

void _setElementActiveIndex(LuminaActor self, Object? target, [int index = 0]) =>
    _setElement(self, target, 'activeIndex', index);

int _getElementActiveIndex(Object? target) => _getElement(target, 'activeIndex', 0);

// Container styling, under the designer's own keys.
void _setElementBackgroundColor(LuminaActor self, Object? target, List<double> inColor) =>
    _setElement(self, target, 'backgroundColor', List<double>.from(inColor));

void _setElementBorderColor(LuminaActor self, Object? target, List<double> inColor) =>
    _setElement(self, target, 'borderColor', List<double>.from(inColor));

void _setElementCornerRadius(LuminaActor self, Object? target, [double inRadius = 8.0]) =>
    _setElement(self, target, 'cornerRadius', inRadius < 0 ? 0.0 : inRadius);

void _setElementPadding(LuminaActor self, Object? target, [double left = 0.0, double top = 0.0, double right = 0.0, double bottom = 0.0]) =>
    _setElement(self, target, 'padding', <double>[left, top, right, bottom]);
