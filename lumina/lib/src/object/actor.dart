import 'package:vector_math/vector_math_64.dart';
import '../declarative/lumina_object.dart';
import '../declarative/build_context.dart';
import '../components/base/actor_component.dart';
import '../components/base/scene_component.dart';
import '../components/collision/collision_component.dart';
import '../collision/collision_subsystem.dart';
import '../controller/controller.dart';
import '../world/world.dart';
import '../world/level.dart';

/// Mixin defining serialization hooks for persistent actors and components.
mixin LuminaSaveable {
  /// Captures custom save game variables into a JSON-encodable map.
  Map<String, dynamic> captureSaveData() => {};

  /// Restores custom save game variables from the supplied map.
  void restoreSaveData(Map<String, dynamic> data) {}
}

/// Why an actor's play ended, for
/// [LuminaActor.onEndPlay] and the Blueprint End Play event.
enum LuminaEndPlayReason {
  /// The actor was destroyed.
  destroyed,

  /// The world is changing level.
  levelTransition,

  /// Play-In-Editor stopped.
  endPlayInEditor,

  /// The actor's level was unloaded or the world cleaned up.
  removedFromWorld,

  /// The game is quitting.
  quit;

  /// The display name: `Destroyed`, `LevelTransition`, …
  String get displayName => name[0].toUpperCase() + name.substring(1);
}

/// Base class for all entities/objects that can be spawned or placed in a [LuminaWorld].
class LuminaActor extends LuminaObject with LuminaSaveable {
  late final LuminaSceneComponent rootComponent;
  final List<LuminaActorComponent> _components = [];
  final List<LuminaObject> _declarativeComponents;

  LuminaWorld? _world;
  LuminaLevel? owningLevel;
  bool _isInitialized = false;
  bool _hasBegunPlay = false;

  /// Whether this actor should be persisted when saving the world state.
  bool bSaveGame;

  final String? _explicitSaveId;

  /// Stable unique identifier for this actor across save/load sessions.
  String get saveId => _explicitSaveId ?? '${owningLevel?.runtimeType.toString() ?? "DefaultLevel"}/${runtimeType.toString()}_${key?.toString() ?? hashCode}';

  LuminaActor({
    super.key,
    LuminaSceneComponent? root,
    List<LuminaObject> components = const [],
    Vector3? location,
    Quaternion? rotation,
    String? saveId,
    this.bSaveGame = false,
    bool hiddenInGame = false,
  }) : _explicitSaveId = saveId,
       _hiddenInGame = hiddenInGame, // ignore: prefer_initializing_formals
       _declarativeComponents = components {
    if (root != null) {
      rootComponent = root;
      if (location != null) rootComponent.relativeLocation = location;
      if (rotation != null) rootComponent.relativeRotation = rotation;
    } else {
      rootComponent = LuminaSceneComponent(location: location, rotation: rotation);
    }
    addComponent(rootComponent);
  }

  /// The world instance this actor is active in.
  LuminaWorld? get world => _world ?? owningLevel?.owningWorld;

  /// Whether this actor has been explicitly registered with a world.
  bool get isRegistered => _world != null;

  bool get isInitialized => _isInitialized;
  bool get hasBegunPlay => _hasBegunPlay;
  List<LuminaActorComponent> get components => List.unmodifiable(_components);

  Vector3 get actorLocation => rootComponent.relativeLocation;
  set actorLocation(Vector3 v) => rootComponent.relativeLocation = v;

  Quaternion get actorRotation => rootComponent.relativeRotation;
  set actorRotation(Quaternion q) => rootComponent.relativeRotation = q;

  Vector3 get actorScale => rootComponent.relativeScale;
  set actorScale(Vector3 v) => rootComponent.relativeScale = v;

  /// Whether this actor is receptive to receiving damage events.
  bool bCanBeDamaged = true;

  /// Delegate invoked whenever this actor receives any damage.
  void Function(double damage, LuminaController? instigator, LuminaActor? damageCauser)? onTakeAnyDamage;

  /// Applies damage to this actor and invokes [onTakeAnyDamage] and
  /// [onAnyDamage]. Subclasses may override to apply health deductions.
  double takeDamage(double amount, {LuminaController? instigator, LuminaActor? damageCauser, String damageType = ''}) {
    if (!bCanBeDamaged || amount <= 0.0) return 0.0;
    onTakeAnyDamage?.call(amount, instigator, damageCauser);
    onAnyDamage(amount, damageType, instigator, damageCauser);
    return amount;
  }

  /// Called by [takeDamage] after the delegate: the hook a Blueprint's
  /// Event AnyDamage runs from.
  void onAnyDamage(double damage, String damageType, LuminaController? instigator, LuminaActor? damageCauser) {}

  /// Apply Point Damage: [onPointDamage] (the Blueprint Event
  /// TakePointDamage) with where it hit (runtime space), then [takeDamage].
  double takePointDamage(double amount,
      {required Vector3 hitLocation,
      required Vector3 hitFromDirection,
      LuminaController? instigator,
      LuminaActor? damageCauser,
      String damageType = ''}) {
    if (!bCanBeDamaged || amount <= 0.0) return 0.0;
    onPointDamage(amount, hitLocation, hitFromDirection, damageType, instigator, damageCauser);
    return takeDamage(amount, instigator: instigator, damageCauser: damageCauser, damageType: damageType);
  }

  /// Called by [takePointDamage] before the general damage hooks.
  void onPointDamage(double damage, Vector3 hitLocation, Vector3 hitFromDirection, String damageType,
      LuminaController? instigator, LuminaActor? damageCauser) {}

  // --- Actor state Blueprints read and write ------------------

  /// Gameplay tags (`Actor Has Tag`, `Add Tag`, `Remove Tag`).
  final List<String> tags = [];

  /// Whether the actor is hidden in game: every scene component of the actor
  /// is made invisible (`Set Actor Hidden In Game`), the ones added later
  /// too. A level's actor hidden in the editor's outliner (itself or through
  /// a folder) is spawned with it set.
  bool get hiddenInGame => _hiddenInGame;
  bool _hiddenInGame;
  set hiddenInGame(bool hidden) {
    _hiddenInGame = hidden;
    for (final c in _components) {
      if (c is LuminaSceneComponent) c.isVisible = !hidden;
    }
  }

  /// The actor responsible for this one (its `Owner`), if any.
  LuminaActor? owner;

  /// The pawn responsible for damage this actor causes (its `Instigator`).
  LuminaActor? instigator;

  double _lifeSpan = 0.0;

  /// Seconds until the actor destroys itself; 0 disables it (`Set Life Span`).
  double get lifeSpan => _lifeSpan;
  set lifeSpan(double seconds) => _lifeSpan = seconds < 0.0 ? 0.0 : seconds;

  /// Enables or disables collision on every collision component
  /// (`Set Actor Enable Collision`).
  void setActorEnableCollision(bool enabled) {
    for (final c in _components) {
      if (c is LuminaCollisionComponent) c.collisionEnabled = enabled;
    }
  }

  /// Whether any collision component of the actor has collision enabled.
  bool get actorEnableCollision => _components.any((c) => c is LuminaCollisionComponent && c.collisionEnabled);

  /// Attaches this actor's root to [parent]'s root (or [parentComponent]),
  /// keeping the relative transform as is (`Attach Actor To Component`).
  void attachToActor(LuminaActor parent, {LuminaSceneComponent? parentComponent}) {
    if (identical(parent, this)) return;
    rootComponent.attachToComponent(parentComponent ?? parent.rootComponent);
  }

  /// Detaches the root from its parent, keeping the world transform
  /// (`Detach From Actor`).
  void detachFromActor() {
    final parent = rootComponent.parentComponent;
    if (parent == null) return;
    final location = rootComponent.worldLocation;
    final rotation = rootComponent.worldRotation;
    rootComponent.detachFromParent();
    rootComponent.relativeLocation = location;
    rootComponent.relativeRotation = rotation;
  }

  /// The actor this one's root is attached to, or null.
  LuminaActor? get attachParentActor => rootComponent.parentComponent?.owner;

  /// The actor's collision bounds in runtime space: the union of its
  /// collision components' boxes, else its location with no extent.
  ({Vector3 origin, Vector3 extent}) get actorBounds {
    Vector3? min, max;
    for (final c in _components) {
      if (c is! LuminaCollisionComponent) continue;
      final box = c.getAABB();
      if (min == null || max == null) {
        min = box.min.clone();
        max = box.max.clone();
      } else {
        Vector3.min(min, box.min, min);
        Vector3.max(max, box.max, max);
      }
    }
    if (min == null || max == null) {
      final root = rootComponent;
      return (origin: root.worldLocation.clone(), extent: Vector3.zero());
    }
    return (origin: (min + max) * 0.5, extent: (max - min) * 0.5);
  }

  // --- Lifecycle hooks Blueprints bind ------------------------

  LuminaEndPlayReason? _pendingEndPlayReason;
  bool _endPlayNotified = false;

  /// Called once when play ends for this actor: it was destroyed, its level
  /// unloaded, the world cleaned up. The Blueprint End Play event runs here.
  void onEndPlay(LuminaEndPlayReason reason) {}

  /// Called when the actor is destroyed, before [onEndPlay] (the Blueprint
  /// Destroyed event).
  void onDestroyed() {}

  // --- Actor event dispatchers --------------------------------

  /// The `OnActorBeginOverlap` / `OnActorEndOverlap` dispatchers: the
  /// collision subsystem broadcasts them with `OverlappedActor` and
  /// `OtherActor` after [notifyActorBeginOverlap] / [notifyActorEndOverlap],
  /// on every actor — a Level Blueprint binds its custom events to a placed
  /// trigger's with Bind Event.
  static const String actorBeginOverlapEvent = 'OnActorBeginOverlap';
  static const String actorEndOverlapEvent = 'OnActorEndOverlap';

  /// The actor events [bindActorEvent] accepts.
  static const Set<String> actorEvents = {actorBeginOverlapEvent, actorEndOverlapEvent};

  final Map<String, List<(Object, void Function(Map<String, Object?> args))>> _actorEventListeners = {};

  /// Calls [listener] on every [event] broadcast; [handle] identifies the
  /// binding (binding the same handle twice keeps one).
  void bindActorEvent(String event, Object handle, void Function(Map<String, Object?> args) listener) {
    final list = _actorEventListeners.putIfAbsent(event, () => []);
    if (list.any((l) => l.$1 == handle)) return;
    list.add((handle, listener));
  }

  /// Removes the binding [handle] of [event].
  void unbindActorEvent(String event, Object handle) => _actorEventListeners[event]?.removeWhere((l) => l.$1 == handle);

  /// Removes every binding of [event] whose handle passes [test] (all when null).
  void unbindActorEvents(String event, [bool Function(Object handle)? test]) =>
      _actorEventListeners[event]?.removeWhere((l) => test == null || test(l.$1));

  /// Whether [event] has a binding.
  bool isActorEventBound(String event) => _actorEventListeners[event]?.isNotEmpty ?? false;

  /// Calls every listener of [event] with [args], in binding order.
  void broadcastActorEvent(String event, Map<String, Object?> args) {
    final list = _actorEventListeners[event];
    if (list == null || list.isEmpty) return;
    for (final l in List.of(list)) {
      l.$2(args);
    }
  }

  /// Called when a component of this actor starts overlapping a component of
  /// [other] (actor-level overlap, dispatched by the collision subsystem).
  void notifyActorBeginOverlap(LuminaActor other, LuminaCollisionComponent selfComponent, LuminaCollisionComponent otherComponent) {}

  /// Called when an overlap with [other] ends.
  void notifyActorEndOverlap(LuminaActor other, LuminaCollisionComponent selfComponent, LuminaCollisionComponent otherComponent) {}

  /// Called when a component of this actor is blocked by [other].
  void notifyActorHit(LuminaActor other, LuminaCollisionComponent selfComponent, LuminaCollisionComponent otherComponent, HitResult hit) {}

  /// The world calls this when it takes the actor out of play; [reason] says
  /// why. [onDestroyed] runs first for a destroyed actor, then [onEndPlay].
  void notifyEndPlay(LuminaEndPlayReason reason) {
    if (_endPlayNotified || !_hasBegunPlay) return;
    _endPlayNotified = true;
    if (reason == LuminaEndPlayReason.destroyed) onDestroyed();
    onEndPlay(reason);
  }

  /// Adds a component to this actor.
  void addComponent(LuminaActorComponent component) {
    if (_components.contains(component)) return;
    _components.add(component);
    if (component is LuminaSceneComponent && component != rootComponent && component.parentComponent == null) {
      component.attachToComponent(rootComponent);
    }
    if (_hiddenInGame && component is LuminaSceneComponent) component.isVisible = false;
    component.onRegister(this);
    final colSys = world?.subsystems.getSubsystem<LuminaCollisionSubsystem>();
    if (colSys != null && component is LuminaCollisionComponent) {
      colSys.register(component);
    }
    if (_isInitialized) {
      component.onInitialize();
    }
    if (_hasBegunPlay) {
      component.onBeginPlay();
    }
  }

  /// Removes a component from this actor.
  void removeComponent(LuminaActorComponent component) {
    if (_components.remove(component)) {
      if (component is LuminaCollisionComponent) {
        world?.subsystems.getSubsystem<LuminaCollisionSubsystem>()?.unregister(component);
      }
      component.onUnregister();
    }
  }

  /// Finds the first component of type [T] attached to this actor.
  T? getComponent<T extends LuminaActorComponent>() {
    for (final comp in _components) {
      if (comp is T) return comp;
    }
    return null;
  }

  /// Called when spawned or registered in a world.
  void onRegister(LuminaWorld world) {
    _world = world;
    for (final comp in _components) {
      comp.onRegister(this);
    }
    final colSys = world.subsystems.getSubsystem<LuminaCollisionSubsystem>();
    if (colSys != null) {
      for (final comp in _components) {
        if (comp is LuminaCollisionComponent) {
          colSys.register(comp);
        }
      }
    }
  }

  /// Called after registration to initialize components.
  void onInitialize() {
    _isInitialized = true;
    for (final comp in _components) {
      comp.onInitialize();
    }
  }

  /// Called when play begins.
  void onBeginPlay() {
    _hasBegunPlay = true;
    for (final comp in _components) {
      comp.onBeginPlay();
    }
  }

  /// Called on every frame tick update.
  void onTick(double deltaTime) {
    for (final comp in _components) {
      comp.onTick(deltaTime);
    }
    if (_lifeSpan > 0.0) {
      _lifeSpan -= deltaTime;
      if (_lifeSpan <= 1e-9) {
        _lifeSpan = 0.0;
        destroy();
      }
    }
  }

  /// Called during post-physics render prep phase.
  void onRenderPrep(LuminaWorld world) {
    for (final comp in _components) {
      comp.onRenderPrep(world);
    }
  }

  /// Called when actor is destroyed or level unloads.
  void onUnregister() {
    final reason = _pendingEndPlayReason ?? LuminaEndPlayReason.removedFromWorld;
    if (reason == LuminaEndPlayReason.destroyed) _wasDestroyed = true;
    notifyEndPlay(reason);
    _pendingEndPlayReason = null;
    final colSys = world?.subsystems.getSubsystem<LuminaCollisionSubsystem>();
    if (colSys != null) {
      for (final comp in _components) {
        if (comp is LuminaCollisionComponent) {
          colSys.unregister(comp);
        }
      }
    }
    // A component may remove a sibling it owns while unregistering (a Local
    // Fog Volume drops its shell mesh): walk a snapshot and skip the ones
    // already removed — removeComponent unregistered them.
    for (final comp in List<LuminaActorComponent>.of(_components)) {
      if (_components.contains(comp)) comp.onUnregister();
    }
    _components.clear();
    owningLevel = null;
    _world = null;
    _isInitialized = false;
    _hasBegunPlay = false;
    _endPlayNotified = false;
    _pendingDestroy = false;
  }

  /// Whether [destroy] was called and the world has not removed the actor yet.
  bool get isPendingDestroy => _pendingDestroy;
  bool _pendingDestroy = false;

  /// The world marks the actor it was asked to destroy, so its End Play
  /// reason is Destroyed and `Is Actor Being Destroyed` reads true.
  void markPendingDestroy() {
    _pendingDestroy = true;
    _pendingEndPlayReason = LuminaEndPlayReason.destroyed;
  }

  bool _forceDestroyed = false;
  bool _wasDestroyed = false;

  /// True if this actor has been removed from the world or is pending kill.
  bool get isDestroyed => _forceDestroyed || _wasDestroyed || (_world == null && _isInitialized);

  /// Requests the world to destroy this actor.
  void destroy() {
    _pendingEndPlayReason = LuminaEndPlayReason.destroyed;
    if (world != null) {
      if (_pendingDestroy) return;
      _pendingDestroy = true;
      world!.destroyActor(this);
    } else {
      _forceDestroyed = true;
      notifyEndPlay(LuminaEndPlayReason.destroyed);
    }
  }

  @override
  LuminaObject? build(LuminaBuildContext context) {
    if (_declarativeComponents.isEmpty) return null;
    return LuminaNodeGroup(children: _declarativeComponents);
  }
}
