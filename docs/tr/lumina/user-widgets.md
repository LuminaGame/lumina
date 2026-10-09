[English](../../en/lumina/user-widgets.md)

# User widget'lar (Widget Blueprint script'i)

UMG'nin motor tarafı: bir Widget Blueprint graph'ının üzerinde çalıştığı nesne. Hiçbir Flutter widget'ı tutmaz; script'lediği widget'ları `lumina_widgets` çizer ([UMG sayfası](../lumina_widgets/umg.md)). Dosya yolları `lumina/` paket dizinine görelidir.

## `lib/src/umg/user_widget.dart`

### `abstract class LuminaUserWidget`

A widget's own script: the object a Widget Blueprint graph runs on, bound to one widget instance map (the one `Create Widget` built). It is a hidden actor with no components so every Blueprint node that reaches `self.world` (the widget subsystem, the player, timers) keeps working.

The VM (`LuminaBlueprintUserWidget`) and each generated `WBP<Name>Graph` override the hooks: Pre Construct and Construct when the widget is added to the viewport, Destruct when it is removed, Tick every world tick while it is on screen, and [onWidgetEvent] when one of its elements is pressed, hovered or changed.

**Yapıcı Metotlar (Constructors):**

- `LuminaUserWidget({super.key})`

**Üyeler:**

| Üye | İmza | Açıklama |
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

**Üyeler:**

| Üye | İmza | Açıklama |
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
| `instanceOfElement` | `static Map<String, Object?>? instanceOfElement(Object? element)` | [element] durum map'inin ait olduğu widget instance'ı (instance bir graph çalıştırıyorsa; [attach] hatırlar); Combo Box setter'ları On Selection Changed'i (`Direct`) bununla çalıştırır. |

## `lib/src/umg/combo_box_options.dart`

Bir Combo Box seçeneği oyuncunun gördüğü **etiketi** herhangi bir Blueprint tipindeki bir **değerle** eşler (`Vector2` çözünürlük, bir enum adı, bir aktör, …). Element durumu bunları `options` altında tutar; her saklama biçimi aynı okunur:

| Saklanan biçim | Nereden gelir | Okunuşu |
| :--- | :--- | :--- |
| `'Low,High'` | seçeneklerin değeri olmadan önce kaydedilmiş widget belgeleri (designer açınca liste biçimine taşınır) | etiketler, her biri kendi değeri |
| `['Easy', 'Hard']` | değersiz Add Option | etiketler, her biri kendi değeri |
| `[{'label': '720p', 'value': Vector2(1280, 720)}]` | değerli Add Option | etiket + değerin kendisi |
| `[{'label': '4K', 'value': [3840.0, 2160.0], 'type': 'vector2D'}]` | designer'ın tipli literal'i | etiket + `luminaBlueprintLiteral(type, value)` (`Vector2(3840, 2160)`) |

Seçim `selectedOption` (etiket; designer bunu `selected` olarak tohumlar) ile tekrarlanan etiketleri ayıran `selectedIndex`'tir.

### `class LuminaComboBoxOption`

`LuminaComboBoxOption(label, value)`; `LuminaComboBoxOption.text(label)` kendi etiketini temsil eder. Eşitlik etiketi ve değeri içerikle karşılaştırır.

### `class LuminaComboBoxSelection`

On Selection Changed'in verdiği: `label` (Selected Item), `value`, `index` (seçim yoksa -1), `selectType` (`ESelectInfo`). `eventArgs` olayın çıktılarıdır, pin id'sine göre (`selected_item`, `value`, `index`, `select_type`); `none` seçimsizliktir.

### `abstract final class LuminaComboBoxOptions`

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `optionsKey`, `selectedKey`, `designerSelectedKey`, `selectedIndexKey` | `static const String` | `options`, `selectedOption`, `selected`, `selectedIndex`. |
| `selectInfoEnum`, `selectInfos` | `static const` | `ESelectInfo`: `Direct`, `OnKeyPress`, `OnNavigation`, `OnMouseClick` (sabitler `direct`, `onKeyPress`, `onNavigation`, `onMouseClick`). |
| `parse` | `static List<LuminaComboBoxOption> parse(Object? stored)` | Saklanan bir değerin bütün seçenekleri (yukarıdaki tablo). |
| `labels` | `static List<String> labels(Object? stored)` | Saklanan değerin etiketleri. |
| `entry` | `static Object entry(LuminaComboBoxOption option)` | Element durumundaki kayıt: değer etiketin kendisiyse yalnız etiket, değilse `{label, value}`. |
| `designerEntry` | `static Map<String, Object?> designerEntry(String label, {Object? value, String? type})` | Designer belgesi kaydı (`{label}` ya da `{label, value, type}`). |
| `migrateDesignerOptions` | `static List<Map<String, Object?>> migrateDesignerOptions(Object? stored)` | Eski virgülle ayrılmış metni (ya da string listesini) `{label}` kayıtlarına çevirir; kayıt listesi olduğu gibi kalır. |
| `of` | `static List<LuminaComboBoxOption> of(Object? element)` | Bir element durum map'inin seçenekleri. |
| `selectedLabel` / `selectedIndex` / `selected` | `static …(Object? element, …)` | Seçili etiket; hâlâ o etiketi gösteriyorsa saklanan indeks, değilse o etiketli ilk seçenek, yoksa -1; seçimin tamamı. |
| `writeSelection` | `static bool writeSelection(Map<String, Object?> element, List<LuminaComboBoxOption> options, int index)` | [index] numaralı seçeneğin seçimini yazar (-1: seçim yok); değişip değişmediğini döner. |
| `indexOfLabel` / `indexOfValue` | `static int …(List<LuminaComboBoxOption> options, …)` | Etiketi / eşit değeri olan ilk seçenek, yoksa -1. |
| `valueEquals` | `static bool valueEquals(Object? a, Object? b)` | Liste ve map içerikle, sayılar sayı olarak, diğerleri `==` ile (vektör ve rotator bileşenleriyle) karşılaştırılır. |

Bu model üzerindeki Blueprint düğümleri (joker Value'lu Add Option, Set Selected Value / Index, Get Selected Option → Label, Value, Index, …) [fonksiyon kütüphanesinde](blueprint/function-library.md); On Selection Changed [`LuminaWidgetEvents`](blueprint/runtime.md) içindedir.

---

[Önceki: Oyun çatısı (game framework)](game.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Kayıt (save game)](save.md)
