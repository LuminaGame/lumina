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
| `instanceOfElement` | `static Map<String, Object?>? instanceOfElement(Object? element)` | The widget instance element state [element] belongs to, when that instance runs a graph (remembered by [attach]); a Combo Box setter uses it to run On Selection Changed (`Direct`). |

## `lib/src/umg/combo_box_options.dart`

A Combo Box option pairs the **label** the player sees with a **value** of any Blueprint type (a `Vector2` resolution, an enum name, an actor, …). The element state stores them under `options`; every stored form reads the same:

| Stored form | Where it comes from | Reads as |
| :--- | :--- | :--- |
| `'Low,High'` | widget documents saved before options had values (migrated to the list form when the designer opens them) | labels, each its own value |
| `['Easy', 'Hard']` | Add Option without a value | labels, each its own value |
| `[{'label': '720p', 'value': Vector2(1280, 720)}]` | Add Option with a value | label + the value as is |
| `[{'label': '4K', 'value': [3840.0, 2160.0], 'type': 'vector2D'}]` | the designer's typed literal | label + `luminaBlueprintLiteral(type, value)` (`Vector2(3840, 2160)`) |

The selection is `selectedOption` (the label; the designer seeds it as `selected`) plus `selectedIndex`, which tells duplicate labels apart.

### `class LuminaComboBoxOption`

`LuminaComboBoxOption(label, value)`; `LuminaComboBoxOption.text(label)` stands for its label. Equality compares the label and the value by content.

### `class LuminaComboBoxSelection`

What On Selection Changed delivers: `label` (Selected Item), `value`, `index` (-1 for none), `selectType` (`ESelectInfo`). `eventArgs` is the event's outputs by pin id (`selected_item`, `value`, `index`, `select_type`); `none` is no selection.

### `abstract final class LuminaComboBoxOptions`

| Member | Signature | Description |
| :--- | :--- | :--- |
| `optionsKey`, `selectedKey`, `designerSelectedKey`, `selectedIndexKey` | `static const String` | `options`, `selectedOption`, `selected`, `selectedIndex`. |
| `selectInfoEnum`, `selectInfos` | `static const` | `ESelectInfo`: `Direct`, `OnKeyPress`, `OnNavigation`, `OnMouseClick` (constants `direct`, `onKeyPress`, `onNavigation`, `onMouseClick`). |
| `parse` | `static List<LuminaComboBoxOption> parse(Object? stored)` | Every option of a stored value (table above). |
| `labels` | `static List<String> labels(Object? stored)` | The labels of a stored value. |
| `entry` | `static Object entry(LuminaComboBoxOption option)` | The element state's entry: the label alone when the value is the label, else `{label, value}`. |
| `designerEntry` | `static Map<String, Object?> designerEntry(String label, {Object? value, String? type})` | A designer document entry (`{label}` or `{label, value, type}`). |
| `migrateDesignerOptions` | `static List<Map<String, Object?>> migrateDesignerOptions(Object? stored)` | The legacy comma-separated string (or a list of strings) as `{label}` entries; a list of entries is kept. |
| `of` | `static List<LuminaComboBoxOption> of(Object? element)` | The options of an element state map. |
| `selectedLabel` / `selectedIndex` / `selected` | `static …(Object? element, …)` | The selected label; the stored index while it still points at that label, else the first option with it, else -1; the whole selection. |
| `writeSelection` | `static bool writeSelection(Map<String, Object?> element, List<LuminaComboBoxOption> options, int index)` | Writes the selection of option [index] (-1: none); whether it changed. |
| `indexOfLabel` / `indexOfValue` | `static int …(List<LuminaComboBoxOption> options, …)` | The first option with the label / an equal value, or -1. |
| `valueEquals` | `static bool valueEquals(Object? a, Object? b)` | Lists and maps by content, numbers as numbers, `==` otherwise (vectors and rotators compare their components). |

The Blueprint nodes over this model (Add Option with a wildcard Value, Set Selected Value / Index, Get Selected Option → Label, Value, Index, …) are in the [function library](blueprint/function-library.md); On Selection Changed is in [`LuminaWidgetEvents`](blueprint/runtime.md).

---

[Previous: Game framework](game.md) | [Up: lumina (engine core)](index.md) | [Next: Save games](save.md)
