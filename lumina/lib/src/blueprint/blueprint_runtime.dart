import '../components/base/actor_component.dart';
import '../components/mesh/animated_mesh_component.dart';
import 'anim/anim_blueprint_instance.dart';
import 'blueprint_assets.dart';
import '../controller/player_controller.dart';
import '../input/input_component.dart';
import '../object/actor.dart';
import '../object/character.dart';
import '../object/pawn.dart';
import '../utility/timer_manager.dart';
import '../world/debug_shapes.dart';
import 'timeline_curve.dart';
import 'blueprint_model.dart';

/// One step of a Blueprint run, for tests, the editor's live highlighting
/// and VM ↔ generated-code parity.
class LuminaBlueprintTraceEvent {
  /// The event node the run started from.
  final String eventNodeId;
  final String nodeId;
  final String registryId;

  /// Input and output pin values of the node, by pin id.
  final Map<String, Object?> values;

  /// Print String's text, when the node printed.
  final String? printed;

  const LuminaBlueprintTraceEvent({
    required this.eventNodeId,
    required this.nodeId,
    required this.registryId,
    this.values = const {},
    this.printed,
  });

  @override
  String toString() => '$registryId($nodeId)${printed == null ? '' : ' "$printed"'} $values';
}

/// An Enhanced Input binding a Blueprint makes: when [action] reaches
/// [state], [handler] runs the graph from that trigger pin.
class LuminaBlueprintInputBinding {
  final LuminaInputAction action;
  final TriggerState state;
  final void Function(LuminaInputActionValue value) handler;
  const LuminaBlueprintInputBinding(this.action, this.state, this.handler);
}

class _Latent {
  final String nodeId;
  void Function() resume;
  double remaining;
  _Latent(this.nodeId, this.remaining, this.resume);
}

/// What a Blueprint answers by name: its custom events, its
/// functions and the interface events it implements. The VM runs the graph;
/// generated classes switch to their methods. Unknown names return an
/// empty map.
abstract interface class LuminaBlueprintCallable {
  Map<String, Object?> callBlueprint(String name, Map<String, Object?> args);
}

/// A bound custom event: the red delegate pin's value, what a
/// timer or a dispatcher calls.
class LuminaBlueprintDelegate {
  final LuminaBlueprintCallable owner;
  final String eventName;
  const LuminaBlueprintDelegate(this.owner, this.eventName);

  Map<String, Object?> call([Map<String, Object?> args = const {}]) => owner.callBlueprint(eventName, args);

  @override
  bool operator ==(Object other) =>
      other is LuminaBlueprintDelegate && identical(other.owner, owner) && other.eventName == eventName;

  @override
  int get hashCode => Object.hash(identityHashCode(owner), eventName);

  @override
  String toString() => 'LuminaBlueprintDelegate($eventName)';
}

/// An event dispatcher's bound delegates: `Bind Event` adds,
/// `Unbind` removes, `Call` broadcasts the parameters to each in binding order.
class LuminaMulticastDelegate {
  final String name;
  final List<LuminaBlueprintDelegate> _bound = [];

  LuminaMulticastDelegate(this.name);

  List<LuminaBlueprintDelegate> get bound => List.unmodifiable(_bound);
  bool get isBound => _bound.isNotEmpty;

  void add(LuminaBlueprintDelegate delegate) {
    if (!_bound.contains(delegate)) _bound.add(delegate);
  }

  void remove(LuminaBlueprintDelegate delegate) => _bound.remove(delegate);

  /// Removes every delegate of [owner] (Unbind All Events).
  void removeAll([Object? owner]) {
    if (owner == null) {
      _bound.clear();
    } else {
      _bound.removeWhere((d) => identical(d.owner, owner));
    }
  }

  void broadcast([Map<String, Object?> args = const {}]) {
    for (final d in List.of(_bound)) {
      d.call(args);
    }
  }
}

/// The actor classes `Spawn Actor from Class` can make: the
/// project's Blueprint classes by name (`BP_Door`), registered by the editor's
/// class registry for Play-In-Editor and by the generated `main()` from
/// `actors.g.dart`'s `luminaBlueprintFactories`, plus the engine's own
/// `LuminaActor`, `LuminaPawn` and `LuminaCharacter`.
abstract final class LuminaBlueprintActorClasses {
  static final Map<String, LuminaActor Function()> _factories = {};

  static void register(String className, LuminaActor Function() factory) => _factories[className] = factory;

  static void registerAll(Map<String, LuminaActor Function()> factories) => _factories.addAll(factories);

  static void unregister(String className) => _factories.remove(className);

  static void clear() => _factories.clear();

  /// The registered class names.
  static Iterable<String> get classNames => _factories.keys;

  /// Whether [cls] (`Actor:BP_Door` or `BP_Door`) can be spawned.
  static bool has(String cls) => _factories.containsKey(_name(cls)) || _engine.containsKey(_name(cls));

  /// A new actor of [cls], or null for an unknown class.
  static LuminaActor? create(String cls) {
    final name = _name(cls);
    final factory = _factories[name] ?? _engine[name];
    return factory?.call();
  }

  static String _name(String cls) {
    final i = cls.indexOf(':');
    return i < 0 ? cls : cls.substring(i + 1);
  }

  static final Map<String, LuminaActor Function()> _engine = {
    'LuminaActor': LuminaActor.new,
    'LuminaPawn': LuminaPawn.new,
    'LuminaCharacter': LuminaCharacter.new,
  };
}

/// What a running Blueprint needs besides its graph, shared by the VM
/// and generated Dart so both behave the same:
/// the component map, tracing, latent Delay, and Enhanced Input binding.
mixin LuminaBlueprintRuntime on LuminaActor implements LuminaBlueprintCallable {
  /// Whether Blueprints run under the editor's Play-In-Editor (PIE sets it
  /// while playing; a built game leaves it false): `Is Editor` reads it, and
  /// `Quit Game` only logs then unless PIE hooks `LuminaGame.onQuitRequested`.
  static bool isEditor = false;

  /// Components built from the Blueprint, by component id.
  Map<String, LuminaActorComponent> blueprintComponents = const {};

  /// The debug shapes this actor's nodes drew this tick (a trace's Draw
  /// Debug segment, Draw Debug Line…), cleared at the start of every tick;
  /// the world keeps them with their durations in `LuminaWorld.debugShapes`.
  final List<LuminaDebugShape> debugShapes = [];

  /// The Blueprint's component tree as authored, so `Get <Component>` can
  /// find a component by its name.
  List<LuminaBlueprintComponent> blueprintComponentTree = const [];

  /// The Blueprint's class name (`BP_ThirdPersonCharacter`), what
  /// `Actor:<class>` pins, Cast To and Get Class Name see.
  String get blueprintClassName => runtimeType.toString();

  /// The parent Blueprint class names of this actor in inheritance order
  /// (immediate parent first, ancestor Blueprints next).
  List<String> get blueprintParentClasses => const [];

  /// Resolves a Skeletal Mesh's Anim Class to its Animation Blueprint, for
  /// Set Anim Instance Class.
  LuminaAnimBlueprintFactory? Function(String animClass)? blueprintAnimClasses;

  /// Per-node state of the flow-control macros (DoOnce, FlipFlop, Gate, DoN,
  /// MultiGate), by node id. Cleared at BeginPlay so a PIE
  /// restart starts over.
  final Map<String, Object?> blueprintFlowState = {};

  // --- Custom events, dispatchers, interfaces, timers, timelines --

  /// Answers a custom event, function or implemented interface function by
  /// name; the VM and generated classes override it.
  @override
  Map<String, Object?> callBlueprint(String name, Map<String, Object?> args) => const {};

  /// The event dispatchers of this instance, by name; created on first use.
  final Map<String, LuminaMulticastDelegate> blueprintDispatchers = {};

  LuminaMulticastDelegate blueprintDispatcher(String name) =>
      blueprintDispatchers.putIfAbsent(name, () => LuminaMulticastDelegate(name));

  /// The interface assets this Blueprint implements (the document's list;
  /// generated classes set it in their constructor).
  List<String> blueprintInterfaces = const [];

  bool implementsInterface(String name) => blueprintInterfaces.contains(name);

  /// Timer handles this actor set (cleared at End Play so a PIE restart
  /// leaks no callback).
  final List<LuminaTimerHandle> blueprintTimerHandles = [];

  /// The Timelines of this actor's graph, by node id.
  final Map<String, LuminaTimeline> blueprintTimelines = {};

  /// The timeline of node [nodeId], built from [literals] on first use.
  LuminaTimeline blueprintTimeline(String nodeId, [Map<String, dynamic> literals = const {}]) =>
      blueprintTimelines.putIfAbsent(nodeId, () => LuminaTimeline.fromLiterals(literals));

  /// Callbacks of latent nodes (Load Stream Level, Async Save Game) that
  /// resolved off the tick, run at the next latent advance.
  final List<void Function()> blueprintLatentCompletions = [];

  /// The world time this actor's BeginPlay ran, for `Get Game Time Since
  /// Creation`.
  double blueprintBeginPlayTime = 0.0;

  /// Enable / Disable Input: while false the bound input
  /// handlers do not run.
  bool blueprintInputEnabled = true;

  /// The montage this Blueprint is playing on its skeletal mesh.
  LuminaBlueprintMontagePlayback? blueprintMontage;

  /// The mesh the montage plays on.
  LuminaAnimatedMeshComponent? blueprintMontageMesh;

  /// Called when the playing montage ends: [interrupted] when stopped or
  /// replaced (the Blueprint Montage Ended event).
  void onMontageEnded(String montage, bool interrupted) {}

  /// Called when the playing montage passes a notify (the Anim Notify event).
  void onAnimNotify(String notifyName) {}

  /// Ends the running montage, [interrupted] or not, restoring the Anim Blueprint.
  void endBlueprintMontage({required bool interrupted}) {
    final playback = blueprintMontage;
    if (playback == null) return;
    blueprintMontage = null;
    final mesh = blueprintMontageMesh;
    blueprintMontageMesh = null;
    for (final c in components) {
      if (c is LuminaAnimBlueprintInstance && identical(c.mesh, mesh)) c.montagePlaying = false;
    }
    onMontageEnded(playback.montage.name, interrupted);
  }

  void _advanceMontage(double deltaTime) {
    final playback = blueprintMontage;
    if (playback == null) return;
    for (final notify in playback.advance(deltaTime)) {
      onAnimNotify(notify);
    }
    if (playback.finished) endBlueprintMontage(interrupted: false);
  }

  /// The world's timer manager, registered when the world has none yet.
  LuminaTimerManager? get blueprintTimerManager {
    final w = world;
    if (w == null) return null;
    return w.getSubsystem<LuminaTimerManager>() ?? w.registerSubsystem(LuminaTimerManager());
  }

  @override
  void onEndPlay(LuminaEndPlayReason reason) {
    super.onEndPlay(reason);
    final manager = world?.getSubsystem<LuminaTimerManager>();
    for (final h in blueprintTimerHandles) {
      manager?.clearTimer(h);
    }
    blueprintTimerHandles.clear();
    for (final t in blueprintTimelines.values) {
      t.stop();
    }
    if (blueprintMontage != null) endBlueprintMontage(interrupted: true);
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    blueprintFlowState.clear();
    blueprintBeginPlayTime = world?.timeSeconds ?? 0.0;
    // A timer set from an input event or a Tick (e.g. IA_Dash's Set
    // Timer by Event) runs while the subsystems iterate, when the manager can
    // no longer be registered lazily; make sure it exists up front. An actor
    // spawned mid-iteration keeps the lazy path.
    final w = world;
    if (w != null && w.getSubsystem<LuminaTimerManager>() == null) {
      try {
        w.registerSubsystem(LuminaTimerManager());
      } on StateError {
        // Registered lazily on the first timer instead.
      }
    }
  }

  @override
  void onTick(double deltaTime) {
    debugShapes.clear();
    super.onTick(deltaTime);
  }

  /// Retriggerable Delay: like [blueprintDelay], but a trigger
  /// while pending restarts the countdown.
  void blueprintRetriggerableDelay(String nodeId, double seconds, void Function() resume) {
    for (final l in _latent) {
      if (l.nodeId == nodeId) {
        l.remaining = seconds;
        l.resume = resume;
        return;
      }
    }
    _latent.add(_Latent(nodeId, seconds, resume));
  }

  /// The component named [name] in the Blueprint (by name or id), or null.
  LuminaActorComponent? blueprintComponentNamed(String name) {
    for (final c in blueprintComponentTree) {
      if (c.name == name || c.id == name) return blueprintComponents[c.id];
    }
    return blueprintComponents[name];
  }

  /// Called for every executed node and every evaluated pure node.
  void Function(LuminaBlueprintTraceEvent event)? trace;

  /// The last runtime error (an aborted run), for the editor to show.
  String? lastError;

  final List<_Latent> _latent = [];
  LuminaInputComponent? _inputComponent;

  void blueprintTrace(String eventNodeId, String nodeId, String registryId, Map<String, Object?> values,
      {String? printed}) {
    trace?.call(LuminaBlueprintTraceEvent(
      eventNodeId: eventNodeId,
      nodeId: nodeId,
      registryId: registryId,
      values: values,
      printed: printed,
    ));
  }

  /// Delay: [resume] runs [seconds] later. A Delay node already
  /// pending ignores the new trigger.
  void blueprintDelay(String nodeId, double seconds, void Function() resume) {
    if (_latent.any((l) => l.nodeId == nodeId)) return;
    _latent.add(_Latent(nodeId, seconds, resume));
  }

  /// Advances pending Delays and the Timelines; the owner calls it each tick
  /// before Event Tick.
  void advanceBlueprintLatent(double deltaTime) {
    for (final t in List.of(blueprintTimelines.values)) {
      t.advance(deltaTime);
    }
    _advanceMontage(deltaTime);
    if (blueprintLatentCompletions.isNotEmpty) {
      final completions = List.of(blueprintLatentCompletions);
      blueprintLatentCompletions.clear();
      for (final c in completions) {
        c();
      }
    }
    if (_latent.isEmpty) return;
    final due = <_Latent>[];
    for (final l in _latent) {
      l.remaining -= deltaTime;
      if (l.remaining <= 1e-9) due.add(l);
    }
    for (final l in due) {
      _latent.remove(l);
      l.resume();
    }
  }

  /// Whether input is bound (the pawn is player-controlled and in a world).
  bool get blueprintInputBound => _inputComponent != null;

  /// Binds [bindings] once the pawn is controlled by a player controller and
  /// in a world; a no-op before that or
  /// when already bound. The world's input subsystem is created if needed.
  void bindBlueprintInput(List<LuminaBlueprintInputBinding> bindings) {
    final self = this;
    if (_inputComponent != null || bindings.isEmpty || self is! LuminaPawn) return;
    if ((self as LuminaPawn).controller is! LuminaPlayerController || world == null) return;
    final subsystem = world!.getSubsystem<LuminaInputSubsystem>() ?? world!.registerSubsystem(LuminaInputSubsystem());
    final component = LuminaInputComponent(subsystem: subsystem);
    for (final b in bindings) {
      component.bindAction(b.action, b.state, (value) {
        if (blueprintInputEnabled) b.handler(value);
      });
    }
    _inputComponent = component;
    addComponent(component);
  }

  void unbindBlueprintInput() {
    final component = _inputComponent;
    if (component == null) return;
    world?.getSubsystem<LuminaInputSubsystem>()?.unregisterComponent(component);
    _inputComponent = null;
  }
}
