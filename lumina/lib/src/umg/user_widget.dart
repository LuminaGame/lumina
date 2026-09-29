import '../object/actor.dart';
import '../world/world.dart';

/// A widget's own script: the object a
/// Widget Blueprint graph runs on, bound to one widget instance map (the one
/// `Create Widget` built). It is
/// a hidden actor with no components so every Blueprint node that reaches
/// `self.world` (the widget subsystem, the player, timers) keeps working.
///
/// The VM (`LuminaBlueprintUserWidget`) and each generated `WBP<Name>Graph`
/// override the hooks: Pre Construct and Construct when the widget is added
/// to the viewport, Destruct when it is removed, Tick every world tick while
/// it is on screen, and [onWidgetEvent] when one of its elements is pressed,
/// hovered or changed.
abstract class LuminaUserWidget extends LuminaActor {
  LuminaUserWidget({super.key}) {
    hiddenInGame = true;
  }

  Map<String, Object?> _instance = <String, Object?>{};
  bool _constructed = false;

  /// The widget instance map this script scripts.
  Map<String, Object?> get widgetInstance => _instance;

  /// The widget class (`WBP_Clicker`).
  String get widgetClassName => '${_instance['class'] ?? ''}';

  /// Whether Construct ran since the widget last entered the viewport.
  bool get isWidgetConstructed => _constructed;

  /// Whether the widget is on screen now.
  bool get isWidgetInViewport => _instance['inViewport'] == true;

  /// The state map of the element named [name] (its designer name), or null.
  Map<String, Object?>? widgetElement(String name) {
    final elements = _instance['elements'];
    if (elements is! Map) return null;
    final e = elements[name];
    return e is Map<String, Object?> ? e : null;
  }

  /// Binds this script to [instance] (done once, by [LuminaUserWidgets.attach]).
  void bindWidgetInstance(Map<String, Object?> instance) => _instance = instance;

  // --- Hooks the graph overrides -------------------------------------------

  /// Event Pre Construct; [isDesignTime] is false at run time.
  void onWidgetPreConstruct(bool isDesignTime) {}

  /// Event Construct.
  void onWidgetConstruct() {}

  /// Event Destruct.
  void onWidgetDestruct() {}

  /// Event Tick (In Delta Time), while the widget is on screen.
  void onWidgetTick(double inDeltaTime) {}

  /// A bound element event: [event] (`OnClicked`, `OnValueChanged`, …) of the
  /// element named [element], with the event's outputs in [args] (`value`,
  /// `text`, `commit_method`).
  void onWidgetEvent(String element, String event, Map<String, Object?> args) {}

  // --- Lifecycle -------------------------------------------------------------

  void _construct() {
    if (_constructed) return;
    _constructed = true;
    onWidgetPreConstruct(false);
    onWidgetConstruct();
  }

  void _destruct() {
    if (!_constructed) return;
    _constructed = false;
    onWidgetDestruct();
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    if (_constructed && isWidgetInViewport) onWidgetTick(deltaTime);
  }
}

/// The widget classes whose instances run a graph: the factory of
/// each class's script, registered by the generated `widget_registry.g.dart`
/// (the compiled `WBP<Name>Graph`) or by Play-In-Editor (a VM script over the
/// editor's graph). The widget nodes call into here, so the VM and generated
/// code share one lifecycle.
abstract final class LuminaUserWidgets {
  static final Map<String, LuminaUserWidget Function()> _factories = {};

  /// Instance map → its script. An [Expando], so the instance map stays
  /// JSON-plain (debug views and copies never see the script).
  static final Expando<LuminaUserWidget> _scripts = Expando('LuminaUserWidget');

  static void register(String className, LuminaUserWidget Function() factory) => _factories[className] = factory;

  static void registerAll(Map<String, LuminaUserWidget Function()> factories) => _factories.addAll(factories);

  static void unregister(String className) => _factories.remove(className);

  static void clear() => _factories.clear();

  static bool has(String className) => _factories.containsKey(className);

  static Iterable<String> get classNames => _factories.keys;

  /// The script of widget instance [instance], or null (no graph, or not a widget).
  static LuminaUserWidget? of(Object? instance) => instance is Map<String, Object?> ? _scripts[instance] : null;

  /// Creates [instance]'s script when its class has a graph, binds it and
  /// spawns it into [world] (`Create Widget`). Returns the script, or null.
  static LuminaUserWidget? attach(LuminaWorld? world, Map<String, Object?> instance) {
    final existing = _scripts[instance];
    if (existing != null) return existing;
    final factory = _factories['${instance['class'] ?? ''}'];
    if (factory == null) return null;
    final script = factory()..bindWidgetInstance(instance);
    _scripts[instance] = script;
    world?.spawnActorImmediately(script);
    return script;
  }

  /// `Add to Viewport`: Pre Construct then Construct, once per stay on screen.
  static void addedToViewport(Object? instance) => of(instance)?._construct();

  /// `Remove from Parent`: Destruct.
  static void removedFromParent(Object? instance) => of(instance)?._destruct();

  /// A generated widget's (or Play-In-Editor's) element event: runs the
  /// graph's `On <Event> (<element>)` node, if the widget has one.
  static void fire(Map<String, Object?>? instance, String element, String event, [Map<String, Object?> args = const {}]) =>
      of(instance)?.onWidgetEvent(element, event, args);
}
