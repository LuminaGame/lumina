part of '../blueprint_function_library.dart';

// --- Actor --------------------------------------------------------

/// The actor a node acts on: its Target pin, or Self when unwired.
LuminaActor _target(LuminaActor self, Object? target) => target is LuminaActor ? target : self;

Vector3 _scaleToRuntime(Vector3 a) => Vector3(a.x, a.z, a.y);

Vector3 _scaleToAuthoring(Vector3 r) => Vector3(r.x, r.z, r.y);

Object? _spawnActorFromClass(LuminaActor self, String cls, [Object? spawnTransform, String collisionHandling = 'Default']) {
  final actor = LuminaBlueprintActorClasses.create(cls);
  if (actor == null) {
    developer.log("Spawn Actor from Class: '$cls' is not a registered actor class.", name: 'Blueprint', level: 900);
    return null;
  }
  final t = LuminaBlueprintFunctionLibrary.breakTransform(spawnTransform ?? luminaBlueprintZero(LuminaPinType.transform));
  actor.actorLocation = LuminaBlueprintFunctionLibrary.toRuntime(t.location);
  actor.actorRotation = _quat(t.rotation);
  actor.actorScale = _scaleToRuntime(t.scale);
  actor.owner = self;
  actor.instigator = self is LuminaPawn ? self : self.instigator;
  self.world?.spawnActorImmediately(actor, level: self.owningLevel);
  return actor;
}

void _destroyActor(LuminaActor self, [Object? target]) => _target(self, target).destroy();

void _setLifeSpan(LuminaActor self, Object? target, [double inLifeSpan = 0.0]) => _target(self, target).lifeSpan = inLifeSpan;

Map<String, Object?> _getActorTransform(LuminaActor self, [Object? target]) {
  final a = _target(self, target);
  return LuminaBlueprintFunctionLibrary.makeTransform(LuminaBlueprintFunctionLibrary.getActorLocation(a), LuminaBlueprintFunctionLibrary.getActorRotation(a), _scaleToAuthoring(a.actorScale));
}

void _setActorTransform(LuminaActor self, Object? target, Object? newTransform) {
  final a = _target(self, target);
  final t = LuminaBlueprintFunctionLibrary.breakTransform(newTransform);
  a.actorLocation = LuminaBlueprintFunctionLibrary.toRuntime(t.location);
  a.actorRotation = _quat(t.rotation);
  a.actorScale = _scaleToRuntime(t.scale);
}

void _setActorRotation(LuminaActor self, Object? target, LuminaRotator newRotation) =>
    _target(self, target).actorRotation = _quat(newRotation);

void _setActorScale3D(LuminaActor self, Object? target, Vector3 newScale3D) =>
    _target(self, target).actorScale = _scaleToRuntime(newScale3D);

Vector3 _getActorScale3D(LuminaActor self, [Object? target]) => _scaleToAuthoring(_target(self, target).actorScale);

void _setActorHiddenInGame(LuminaActor self, Object? target, [bool newHidden = true]) =>
    _target(self, target).hiddenInGame = newHidden;

bool _isHidden(LuminaActor self, [Object? target]) => _target(self, target).hiddenInGame;

void _setActorEnableCollision(LuminaActor self, Object? target, [bool newActorEnableCollision = true]) =>
    _target(self, target).setActorEnableCollision(newActorEnableCollision);

bool _getActorEnableCollision(LuminaActor self, [Object? target]) => _target(self, target).actorEnableCollision;

bool _teleport(LuminaActor self, Object? target, Vector3 destLocation, LuminaRotator destRotation) {
  final a = _target(self, target);
  a.actorLocation = LuminaBlueprintFunctionLibrary.toRuntime(destLocation);
  a.actorRotation = _quat(destRotation);
  _movement(a)?.stopMovementImmediately();
  return true;
}

({Vector3 origin, Vector3 boxExtent}) _getActorBounds(LuminaActor self, [Object? target]) {
  final b = _target(self, target).actorBounds;
  final e = b.extent;
  return (origin: LuminaBlueprintFunctionLibrary.toAuthoring(b.origin), boxExtent: Vector3(e.x, e.z, e.y));
}

Vector3 _getActorForwardVector(LuminaActor self, [Object? target]) => LuminaBlueprintFunctionLibrary.getForwardVector(LuminaBlueprintFunctionLibrary.getActorRotation(_target(self, target)));

Vector3 _getActorRightVector(LuminaActor self, [Object? target]) => LuminaBlueprintFunctionLibrary.getRightVector(LuminaBlueprintFunctionLibrary.getActorRotation(_target(self, target)));

Vector3 _getActorUpVector(LuminaActor self, [Object? target]) => LuminaBlueprintFunctionLibrary.getUpVector(LuminaBlueprintFunctionLibrary.getActorRotation(_target(self, target)));

void _attachActorToComponent(LuminaActor self, Object? target, Object? parent, [String socketName = '']) {
  final a = _target(self, target);
  if (parent is LuminaSceneComponent) {
    final owner = parent.owner;
    if (owner != null) a.attachToActor(owner, parentComponent: parent);
  } else if (parent is LuminaActor) {
    a.attachToActor(parent);
  }
}

void _detachFromActor(LuminaActor self, [Object? target]) => _target(self, target).detachFromActor();

Object? _getAttachParentActor(LuminaActor self, [Object? target]) => _target(self, target).attachParentActor;

Object? _getOwner(LuminaActor self, [Object? target]) => _target(self, target).owner;

void _setOwner(LuminaActor self, Object? target, Object? newOwner) =>
    _target(self, target).owner = newOwner is LuminaActor ? newOwner : null;

Object? _getInstigator(LuminaActor self, [Object? target]) => _target(self, target).instigator;

bool _actorHasTag(LuminaActor self, Object? target, [String tag = '']) => _target(self, target).tags.contains(tag);

void _addTag(LuminaActor self, Object? target, [String tag = '']) {
  final tags = _target(self, target).tags;
  if (tag.isNotEmpty && !tags.contains(tag)) tags.add(tag);
}

void _removeTag(LuminaActor self, Object? target, [String tag = '']) => _target(self, target).tags.remove(tag);

double _getDistanceTo(LuminaActor self, Object? target, Object? otherActor) =>
    otherActor is LuminaActor ? (_target(self, target).actorLocation - otherActor.actorLocation).length : 0.0;

double _getHorizontalDistanceTo(LuminaActor self, Object? target, Object? otherActor) {
  if (otherActor is! LuminaActor) return 0.0;
  final d = _target(self, target).actorLocation - otherActor.actorLocation;
  return math.sqrt(d.x * d.x + d.z * d.z);
}

bool _isActorBeingDestroyed(LuminaActor self, [Object? target]) {
  final a = _target(self, target);
  return a.isPendingDestroy || a.isDestroyed;
}

double _applyDamage(LuminaActor self, Object? damagedActor, [double baseDamage = 0.0, Object? eventInstigator, Object? damageCauser, String damageTypeClass = '']) {
  return LuminaGameplayStatics.applyDamage(_target(self, damagedActor), baseDamage,
      instigator: eventInstigator is LuminaController ? eventInstigator : (self is LuminaPawn ? self.controller : null),
      damageCauser: damageCauser is LuminaActor ? damageCauser : self,
      damageType: damageTypeClass);
}

double _applyPointDamage(LuminaActor self, Object? damagedActor, [double baseDamage = 0.0, Vector3? hitFromDirection, Object? hitInfo,
    Object? eventInstigator, Object? damageCauser, String damageTypeClass = '']) {
  final hit = LuminaBlueprintFunctionLibrary.breakHitResult(hitInfo);
  return _target(self, damagedActor).takePointDamage(baseDamage,
      hitLocation: LuminaBlueprintFunctionLibrary.toRuntime(hit.impactPoint),
      hitFromDirection: LuminaBlueprintFunctionLibrary.toRuntime(hitFromDirection ?? Vector3.zero()),
      instigator: eventInstigator is LuminaController ? eventInstigator : (self is LuminaPawn ? self.controller : null),
      damageCauser: damageCauser is LuminaActor ? damageCauser : self,
      damageType: damageTypeClass);
}

bool _applyRadialDamage(LuminaActor self, [double baseDamage = 0.0, Vector3? origin, double damageRadius = 0.0, String damageTypeClass = '',
    Object? ignoreActors, Object? damageCauser, Object? instigatedBy, bool doFullDamage = false]) {
  final world = self.world;
  if (world == null || damageRadius <= 0.0) return false;
  final ignored = _actorList(ignoreActors);
  LuminaGameplayStatics.applyRadialDamage(world, baseDamage, LuminaBlueprintFunctionLibrary.toRuntime(origin ?? LuminaBlueprintFunctionLibrary.getActorLocation(self)), damageRadius,
      damageFalloff: doFullDamage ? 0.0 : 1.0,
      instigator: instigatedBy is LuminaController ? instigatedBy : (self is LuminaPawn ? self.controller : null),
      damageCauser: damageCauser is LuminaActor ? damageCauser : self,
      ignoreActors: ignored,
      damageType: damageTypeClass);
  return true;
}

// --- Custom events, functions, dispatchers, interfaces ---------

LuminaBlueprintCallable? _callable(Object? o) => o is LuminaBlueprintCallable ? o : null;

Map<String, Object?> _callBlueprint(LuminaActor self, String name, [Map<String, Object?> args = const {}]) =>
    _callable(self)?.callBlueprint(name, args) ?? const {};

void _callCustomEvent(LuminaActor self, String event, [Map<String, Object?> args = const {}, Object? target]) {
  _callable(target ?? self)?.callBlueprint(event, args);
}

Map<String, Object?> _callFunction(LuminaActor self, String function, [Map<String, Object?> args = const {}]) =>
    LuminaBlueprintFunctionLibrary.callBlueprint(self, function, args);

void _callDispatcher(LuminaActor self, String dispatcher, [Map<String, Object?> args = const {}]) =>
    _runtime(self)?.blueprintDispatcher(dispatcher).broadcast(args);

/// The Blueprint a dispatcher / interface node acts on: its Target pin, or Self when unwired.
/// A widget instance (what `Create Widget` returned) stands for its graph's script.
LuminaBlueprintRuntime? _runtimeTarget(LuminaActor self, Object? target) =>
    _scriptOf(target) ?? (target == null ? _runtime(self) : null);

/// [target] as a Blueprint: itself, or the graph script of a widget instance.
LuminaBlueprintRuntime? _scriptOf(Object? target) {
  if (target is LuminaBlueprintRuntime) return target;
  final script = LuminaUserWidgets.of(target);
  return script is LuminaBlueprintRuntime ? script as LuminaBlueprintRuntime : null;
}

/// The actor an actor event dispatcher (`OnActorBeginOverlap`)
/// is bound on: [target], or Self when unwired.
LuminaActor? _eventActor(LuminaActor self, Object? target) =>
    target is LuminaActor ? target : (target == null ? self : null);

void _bindEventToDispatcher(LuminaActor self, Object? target, String dispatcher, Object? event) {
  if (event is! LuminaBlueprintDelegate) return;
  if (LuminaActor.actorEvents.contains(dispatcher)) {
    _eventActor(self, target)?.bindActorEvent(dispatcher, event, event.call);
    return;
  }
  _runtimeTarget(self, target)?.blueprintDispatcher(dispatcher).add(event);
}

void _unbindEventFromDispatcher(LuminaActor self, Object? target, String dispatcher, Object? event) {
  if (event is! LuminaBlueprintDelegate) return;
  if (LuminaActor.actorEvents.contains(dispatcher)) {
    _eventActor(self, target)?.unbindActorEvent(dispatcher, event);
    return;
  }
  _runtimeTarget(self, target)?.blueprintDispatcher(dispatcher).remove(event);
}

void _unbindAllEvents(LuminaActor self, Object? target, String dispatcher) {
  if (LuminaActor.actorEvents.contains(dispatcher)) {
    _eventActor(self, target)?.unbindActorEvents(dispatcher, (h) => h is LuminaBlueprintDelegate && identical(h.owner, self));
    return;
  }
  _runtimeTarget(self, target)?.blueprintDispatcher(dispatcher).removeAll(self);
}

// --- Level Blueprints ----------------------------------------

Object? _getLevelActor(LuminaActor self, String name) =>
    self is LuminaBlueprintLevelActors ? self.levelActor(name) : null;

List<Object?> _getLevelActorsOfClass(LuminaActor self, [String cls = LuminaBlueprintObjectClass.anyActor]) =>
    self is LuminaBlueprintLevelActors ? self.levelActorsOfClass(cls) : <Object?>[];

bool _implementsInterface(Object? target, String interface) =>
    _scriptOf(target)?.implementsInterface(interface) ?? false;

bool _doesImplementInterface(LuminaActor self, Object? target, String interface) =>
    LuminaBlueprintFunctionLibrary.implementsInterface(target ?? self, interface);

Map<String, Object?> _interfaceMessage(LuminaActor self, Object? target, String interface, String function,
    [Map<String, Object?> args = const {}]) {
  final t = _runtimeTarget(self, target);
  return t != null && t.implementsInterface(interface) ? t.callBlueprint(function, args) : const {};
}

// --- Enums -----------------------------------------------------

String _enumLiteral(String enumName, String value) => value;

String _enumToString(String value) => value;

int _enumToInt(String enumName, String value) {
  if (enumName.isNotEmpty) return LuminaBlueprintEnums.valuesOf(enumName).indexOf(value);
  for (final e in LuminaBlueprintEnums.all) {
    final i = e.values.indexOf(value);
    if (i >= 0) return i;
  }
  return -1;
}

final Set<String> _enumClampLogged = {};

String _intToEnum(String enumName, int index) {
  final values = LuminaBlueprintEnums.valuesOf(enumName);
  if (values.isEmpty) return '';
  final i = index.clamp(0, values.length - 1);
  if (i != index && _enumClampLogged.add('$enumName/$index')) {
    developer.log('Int to Enum: $index is out of range for $enumName (${values.length} values); ${values[i]} used.',
        name: 'Blueprint', level: 900);
  }
  return values[i];
}

bool _enumEqual(String a, String b) => a == b;

int _getEnumValueCount(String enumName) => LuminaBlueprintEnums.valuesOf(enumName).length;

// --- Timers ----------------------------------------------------

LuminaTimerHandle? _timer(LuminaActor self, LuminaBlueprintDelegate? delegate, double time, bool looping, double initialStartDelay) {
  final runtime = _runtime(self);
  final manager = runtime?.blueprintTimerManager;
  if (runtime == null || manager == null || delegate == null) return null;
  if (time <= 0.0) {
    developer.log('Set Timer: a time of $time s never fires; the timer was not set.', name: 'Blueprint', level: 900);
    return null;
  }
  final handle = manager.setTimer(() => delegate.call(), rate: time, looping: looping, firstDelay: initialStartDelay);
  runtime.blueprintTimerHandles.add(handle);
  return handle;
}

LuminaTimerHandle? _setTimerByEvent(LuminaActor self, Object? event, [double time = 0.0, bool looping = false, double initialStartDelay = -1.0]) =>
    _timer(self, event is LuminaBlueprintDelegate ? event : null, time, looping, initialStartDelay);

LuminaTimerHandle? _setTimerByFunctionName(LuminaActor self, String functionName,
        [double time = 0.0, bool looping = false, double initialStartDelay = -1.0]) =>
    _timer(self, _callable(self) == null ? null : LuminaBlueprintDelegate(_callable(self)!, functionName), time, looping, initialStartDelay);

LuminaTimerHandle? _setTimerForNextTick(LuminaActor self, Object? event) {
  final runtime = _runtime(self);
  final manager = runtime?.blueprintTimerManager;
  if (runtime == null || manager == null || event is! LuminaBlueprintDelegate) return null;
  final handle = manager.setTimerForNextTick(() => event.call());
  runtime.blueprintTimerHandles.add(handle);
  return handle;
}

LuminaTimerManager? _timers(LuminaActor self) => self.world?.getSubsystem<LuminaTimerManager>();

void _clearTimerByHandle(LuminaActor self, Object? handle) {
  if (handle is LuminaTimerHandle) {
    _timers(self)?.clearTimer(handle);
    _runtime(self)?.blueprintTimerHandles.remove(handle);
  }
}

void _clearAndInvalidateTimer(LuminaActor self, Object? handle) => LuminaBlueprintFunctionLibrary.clearTimerByHandle(self, handle);

void _pauseTimer(LuminaActor self, Object? handle) {
  if (handle is LuminaTimerHandle) _timers(self)?.pauseTimer(handle);
}

void _unpauseTimer(LuminaActor self, Object? handle) {
  if (handle is LuminaTimerHandle) _timers(self)?.unpauseTimer(handle);
}

bool _isTimerActive(LuminaActor self, Object? handle) => handle is LuminaTimerHandle && (_timers(self)?.isTimerActive(handle) ?? false);

bool _isTimerPaused(LuminaActor self, Object? handle) => handle is LuminaTimerHandle && (_timers(self)?.isTimerPaused(handle) ?? false);

double _getTimerRemainingTime(LuminaActor self, Object? handle) =>
    handle is LuminaTimerHandle ? (_timers(self)?.getTimerRemaining(handle) ?? -1.0) : -1.0;

double _getTimerElapsedTime(LuminaActor self, Object? handle) =>
    handle is LuminaTimerHandle ? (_timers(self)?.getTimerElapsed(handle) ?? -1.0) : -1.0;

Map<String, Object?> _signatureArgs(Map<String, Object?> inputs, Set<String> settings) =>
    {for (final e in inputs.entries) if (!settings.contains(e.key)) e.key: e.value};
