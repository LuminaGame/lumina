[Türkçe](../../tr/lumina/user-widgets.md)

# User widgets (the Widget Blueprint script)

The engine side of UMG: the object a Widget Blueprint graph runs on. It holds no Flutter widget; the widgets it scripts are drawn by `lumina_widgets` ([UMG page](../lumina_widgets/umg.md)). File paths are relative to the `lumina/` package directory.

## `lib/src/umg/user_widget.dart`

### `abstract class LuminaUserWidget`

A widget's own script: the object a Widget Blueprint graph runs on, bound to one widget instance map (the one `Create Widget` built). It is a hidden actor with no components so every Blueprint node that reaches `self.world` (the widget subsystem, the player, timers) keeps working.

The VM (`LuminaBlueprintUserWidget`) and each generated `WBP<Name>Graph` override the hooks: Pre Construct and Construct when the widget is added to the viewport, Destruct when it is removed, Tick every world tick while it is on screen, and [onWidgetEvent] when one of its elements is pressed, hovered or changed.

**Constructors:**

- `LuminaUserWidget({super.key})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `widgetInstance` | `Map<String, Object?> get widgetInstance` | The widget instance map this script scripts. |
| `widgetClassName` | `String get widgetClassName` | The widget class (`WBP_Clicker`). |
| `isWidgetConstructed` | `bool get isWidgetConstructed` | Whether Construct ran since the widget last entered the viewport. |
| `isWidgetInViewport` | `bool get isWidgetInViewport` | Whether the widget is on screen now. |
| `widgetElement` | `Map<String, Object?>? widgetElement(String name)` | The state map of the element named [name] (its designer name), or null. |
| `bindWidgetInstance` | `void bindWidgetInstance(Map<String, Object?> instance)` | Binds this script to [instance] (done once, by [LuminaUserWidgets.attach]). |
| `onWidgetPreConstruct` | `void onWidgetPreConstruct(bool isDesignTime)` | Event Pre Construct; [isDesignTime] is false at run time. |
| `onWidgetConstruct` | `void onWidgetConstruct()` | Event Construct. |
| `onWidgetDestruct` | `void onWidgetDestruct()` | Event Destruct. |
| `onWidgetTick` | `void onWidgetTick(double inDeltaTime)` | Event Tick (In Delta Time), while the widget is on screen. |
| `onWidgetEvent` | `void onWidgetEvent(String element, String event, Map<String, Object?> args)` | A bound element event: [event] (`OnClicked`, `OnValueChanged`, …) of the element named [element], with the event's outputs in [args] (`value`, `text`, `commit_method`). |

### `abstract final class LuminaUserWidgets`

The widget classes whose instances run a graph: the factory of each class's script, registered by the generated `widget_registry.g.dart` (the compiled `WBP<Name>Graph`) or by Play-In-Editor (a VM script over the editor's graph). The widget nodes call into here, so the VM and generated code share one lifecycle.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `register` | `static void register(String className, LuminaUserWidget Function() factory)` |  |
| `registerAll` | `static void registerAll(Map<String, LuminaUserWidget Function()> factories)` |  |
| `unregister` | `static void unregister(String className)` |  |
| `clear` | `static void clear()` |  |
| `has` | `static bool has(String className)` |  |
| `classNames` | `static Iterable<String> get classNames` |  |
| `of` | `static LuminaUserWidget? of(Object? instance)` | The script of widget instance [instance], or null (no graph, or not a widget). |
| `attach` | `static LuminaUserWidget? attach(LuminaWorld? world, Map<String, Object?> instance)` | Creates [instance]'s script when its class has a graph, binds it and spawns it into [world] (`Create Widget`). Returns the script, or null. |
| `addedToViewport` | `static void addedToViewport(Object? instance)` | `Add to Viewport`: Pre Construct then Construct, once per stay on screen. |
| `removedFromParent` | `static void removedFromParent(Object? instance)` | `Remove from Parent`: Destruct. |
| `fire` | `static void fire(Map<String, Object?>? instance, String element, String event, [Map<String, Object?> args = co...` | A generated widget's (or Play-In-Editor's) element event: runs the graph's `On <Event> (<element>)` node, if the widget has one. |

---

[Previous: Game framework](game.md) | [Up: lumina (engine core)](index.md) | [Next: Save games](save.md)
