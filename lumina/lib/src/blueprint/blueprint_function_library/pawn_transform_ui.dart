part of '../blueprint_function_library.dart';

// --- Authoring ↔ runtime --------------------------------------------------

Vector3 _toRuntime(Vector3 a) => Vector3(a.x, a.z, -a.y);

Vector3 _toAuthoring(Vector3 r) => Vector3(r.x, -r.z, r.y);

Vector3 _toControlRotation(LuminaRotator r) => Vector3(r.x, r.z, -r.y);

LuminaRotator _fromControlRotation(Vector3 e) =>
    LuminaRotator(e.x, -e.z, e.y);

void _log(LuminaActor self, String text) =>
    developer.log(text, name: 'Blueprint');

void _printString(LuminaActor self, String inString,
    [bool printToScreen = true, bool printToLog = true, List<double>? textColor, double duration = 2.0, String key = '']) {
  if (printToLog) LuminaBlueprintFunctionLibrary.onPrintString(self, inString);
  if (printToScreen) {
    self.world?.addScreenMessage(key.isEmpty ? null : key, inString, color: LuminaBlueprintFunctionLibrary._c(textColor ?? const [0.0, 0.66, 1.0, 1.0]), duration: duration);
  }
}

// --- Pawn / character ------------------------------------------------------

LuminaCharacterMovementComponent? _movement(LuminaActor self) =>
    self is LuminaCharacter
    ? self.characterMovement
    : self.getComponent<LuminaCharacterMovementComponent>();

void _addMovementInput(
  LuminaActor self,
  Vector3 worldDirection,
  double scaleValue, [
  bool force = false,
]) {
  final direction = LuminaBlueprintFunctionLibrary.toRuntime(worldDirection);
  final movement = _movement(self);
  if (movement != null) {
    movement.addInputVector(direction, scaleValue);
  } else if (self is LuminaPawn) {
    self.addMovementInput(direction, scaleValue);
  }
}

void _addControllerYawInput(LuminaActor self, double val) {
  if (self is LuminaPawn) self.addControllerYawInput(val);
}

void _addControllerPitchInput(LuminaActor self, double val) {
  if (self is LuminaPawn) self.addControllerPitchInput(val);
}

LuminaRotator _getControlRotation(LuminaActor self) {
  final controller = self is LuminaPawn ? self.controller : null;
  return controller == null
      ? const LuminaRotator.zero()
      : LuminaBlueprintFunctionLibrary.fromControlRotation(controller.controlRotation);
}

void _setFreeLook(LuminaActor self, [bool enabled = true]) {
  if (self is LuminaPawn) self.freeLook = enabled;
}

bool _isFreeLooking(LuminaActor self) => self is LuminaPawn && self.freeLook;

void _jump(LuminaActor self) {
  if (self is LuminaCharacter) self.jump();
}

void _stopJumping(LuminaActor self) => _movement(self)?.stopJumping();

Vector3 _getVelocity(LuminaActor self) {
  final movement = _movement(self);
  return movement == null ? Vector3.zero() : LuminaBlueprintFunctionLibrary.toAuthoring(movement.velocity);
}

bool _isFalling(LuminaActor self) =>
    _movement(self)?.isFalling ?? false;

// --- Transformation --------------------------------------------------------

Vector3 _getActorLocation(LuminaActor self) =>
    LuminaBlueprintFunctionLibrary.toAuthoring(self.actorLocation);

bool _setActorLocation(
  LuminaActor self,
  Vector3 newLocation, [
  bool sweep = false,
]) {
  self.actorLocation = LuminaBlueprintFunctionLibrary.toRuntime(newLocation);
  return true;
}

LuminaRotator _getActorRotation(LuminaActor self) =>
    LuminaBlueprintFunctionLibrary.fromControlRotation(luminaPawnQuaternionToEuler(self.actorRotation));

// --- UI / Widget -----------------------------------------------------------

Object? _createWidget(
  LuminaActor self,
  String className, [
  Object? owningPlayer,
]) {
  final widget = <String, Object?>{
    'class': className,
    'owner': owningPlayer,
    'inViewport': false,
    'zOrder': 0,
    'visibility': 'Visible',
    'elements': LuminaWidgetClassRegistry.elementsFor(className),
  };
  // A widget class with a graph gets its script.
  LuminaUserWidgets.attach(self.world, widget);
  return widget;
}

void _addToViewport(
  LuminaActor self,
  Object? target, [
  int zOrder = 0,
]) {
  target = _widgetTarget(self, target);
  if (target is Map<String, Object?>) {
    target['inViewport'] = true;
    target['zOrder'] = zOrder;
    self.world?.getSubsystem<LuminaWidgetSubsystem>()?.addWidget(target);
    LuminaUserWidgets.addedToViewport(target);
  }
}

void _removeFromParent(LuminaActor self, Object? target) {
  target = _widgetTarget(self, target);
  if (target is Map<String, Object?>) {
    target['inViewport'] = false;
    self.world?.getSubsystem<LuminaWidgetSubsystem>()?.removeWidget(target);
    LuminaUserWidgets.removedFromParent(target);
  }
}

void _setWidgetVisibility(
  LuminaActor self,
  Object? target, [
  String inVisibility = 'Visible',
]) {
  target = _widgetTarget(self, target);
  if (target is Map<String, Object?>) {
    target['visibility'] = inVisibility;
    self.world?.getSubsystem<LuminaWidgetSubsystem>()?.notifyChanged();
  }
}

bool _isInViewport(Object? target) {
  if (target is Map<String, Object?>) {
    return target['inViewport'] == true;
  }
  return false;
}

Object? _getOwningPlayer(Object? target) {
  if (target is Map<String, Object?>) {
    return target['owner'];
  }
  return null;
}

void _setWidgetText(
  LuminaActor self,
  Object? target, [
  String inText = '',
]) {
  if (target is Map<String, Object?>) {
    target['text'] = inText;
    for (final e in _elementsOf(target, 'text')) {
      e['text'] = inText;
    }
    self.world?.getSubsystem<LuminaWidgetSubsystem>()?.notifyChanged();
  }
}

void _setWidgetPercent(
  LuminaActor self,
  Object? target, [
  double inPercent = 1.0,
]) {
  if (target is Map<String, Object?>) {
    target['percent'] = inPercent;
    for (final e in _elementsOf(target, 'progressBar')) {
      e['percent'] = inPercent;
    }
    self.world?.getSubsystem<LuminaWidgetSubsystem>()?.notifyChanged();
  }
}

Iterable<Map<String, Object?>> _elementsOf(Map<String, Object?> widget, String type) {
  final elements = widget['elements'];
  if (elements is! Map) return const [];
  return [
    for (final e in elements.values)
      if (e is Map<String, Object?> && e['type'] == type) e,
  ];
}
