[English](../../en/lumina_ui/core-continued-2.md)

# Uygulama kabuğu ve ortak UI (devamı, bölüm 2)

Uygulama kabuğu ve ortak UI sayfasının devamı: `lib/ui/core/window/` ve `lib/ui/core/widgets/` (medya oynatıcıları, bildirimsel eklenti panelleri) altındaki diğer public dosyalar. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/core/window/lumina_window.dart`](#libuicorewindowlumina_windowdart)
- [`lib/ui/core/window/window_controls.dart`](#libuicorewindowwindow_controlsdart)
- [`lib/ui/core/window/window_state_store.dart`](#libuicorewindowwindow_state_storedart)
- [`lib/ui/core/widgets/media/editor_media_widgets.dart`](#libuicorewidgetsmediaeditor_media_widgetsdart)
- [`lib/ui/core/widgets/plugin_view/`](#libuicorewidgetsplugin_view)

## `lib/ui/core/window/lumina_window.dart`

### `typedef WindowCloseGuard`

Asked before the window closes; false keeps it open. The editor's guard shows the unsaved-changes prompt.

### `class LuminaWindow`

Lumina Studio's own window chrome: the native title bar is hidden, and the editor's menu row, [LuminaWindowControls] and the resize border drive the window through this controller.

It wraps `package:window_manager` and never assumes a state change: the maximize / fullscreen flags follow the plugin's events, so a window manager that ignores a request (a tiling WM refusing to maximize) or changes the window on its own is reflected as it really is.

Closing — from [LuminaWindowControls], or from the window manager (Alt+F4, the taskbar), which `setPreventClose(true)` turns into a `close` event — runs every registered [WindowCloseGuard] first, saves the window's placement through [store] and only then destroys the window.

**Yapıcı Metotlar (Constructors):**

- `LuminaWindow({WindowManager? manager, WindowStateStore? store})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `instance` | `static final LuminaWindow instance` | The app's window. Widgets reach it through [LuminaWindowScope.of]. |
| `store` | `WindowStateStore get store` | Where the placement is saved; the editor preferences by default. |
| `isMaximized` | `bool get isMaximized` |  |
| `isFullScreen` | `bool get isFullScreen` |  |
| `normalBounds` | `Rect? get normalBounds` | The restored (un-maximized, windowed) bounds last seen. |
| `os` | `static String get os` | The desktop OS the chrome is drawn for (`linux`, `windows`, `macos`); a test can pretend to be another one. |
| `debugOsOverride` | `static String? debugOsOverride` |  |
| `drawsOwnControls` | `static bool get drawsOwnControls` | Whether this platform shows Lumina's own minimize / maximize / close buttons. macOS keeps its traffic lights (drawn by the system at the left of the hidden title bar, `windowButtonVisibility: true`). |
| `needsResizeBorder` | `static bool get needsResizeBorder` | Whether the app needs its own resize border: an undecorated GTK window has no WM handles. Windows keeps its native frame border and macOS its window edges with a hidden title bar. |
| `leadingInset` | `static double get leadingInset` | The room macOS's traffic lights take at the left of the menu row. |
| `startup` | `Future<void> startup(WindowOptions options) async` | Prepares the window before the first frame: restores the saved placement over [options] (whose `titleBarStyle` is the app's), turns the window manager's close into a request, and shows the window. |
| `minimize` | `Future<void> minimize()` |  |
| `toggleMaximize` | `Future<void> toggleMaximize()` | Maximizes or restores, from the window's real state. |
| `toggleFullScreen` | `Future<void> toggleFullScreen()` | Enters or leaves fullscreen, from the window's real state. |
| `startDragging` | `Future<void> startDragging()` |  |
| `startResizing` | `Future<void> startResizing(ResizeEdge edge)` |  |
| `addCloseGuard` | `void addCloseGuard(WindowCloseGuard guard)` |  |
| `removeCloseGuard` | `void removeCloseGuard(WindowCloseGuard guard)` |  |
| `requestClose` | `Future<bool> requestClose() async` | Asks every close guard (most recent first); when all agree, saves the placement and destroys the window. Returns whether the window closed. |

### `class LuminaWindowScope`

Puts a [LuminaWindow] in the tree (the app's [LuminaWindow.instance] when there is none), so window chrome rebuilds when the window changes state.

**Yapıcı Metotlar (Constructors):**

- `const LuminaWindowScope({super.key, required LuminaWindow window, required super.child})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `of` | `static LuminaWindow of(BuildContext context)` |  |
| `read` | `static LuminaWindow read(BuildContext context)` | The window without subscribing to its changes (for callbacks). |

## `lib/ui/core/window/window_controls.dart`

### `class LuminaWindowControls`

Lumina's own window buttons at the right end of the menu bar row (and of the launcher header): minimize, maximize ⇄ restore (the icon follows the window's real state), fullscreen and close (red on hover; it goes through [LuminaWindow.requestClose], so the editor's unsaved-changes prompt runs first).

macOS keeps its system traffic lights at the left, so there this draws nothing ([LuminaWindow.drawsOwnControls]).

**Yapıcı Metotlar (Constructors):**

- `const LuminaWindowControls({super.key, this.height = 30, this.showFullScreen = true})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `height` | `final double height` |  |
| `showFullScreen` | `final bool showFullScreen` |  |

### `class WindowDragArea`

The part of a title bar that moves the window: drag to move it, double-click to maximize / restore.

**Yapıcı Metotlar (Constructors):**

- `const WindowDragArea({super.key, this.child = const SizedBox.expand()})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `child` | `final Widget child` |  |

### `class LuminaWindowFrame`

The app's window frame, above every route: puts [window] in scope, gives F11 (fullscreen) to screens that have no shortcut layer of their own (the editor maps it to View ▸ Full Screen), and — where the native border is gone (Linux) — lays a thin resize border along every edge and corner, which drives `gtk_window_begin_resize_drag` through the plugin. The border steps aside while the window is maximized or fullscreen.

**Yapıcı Metotlar (Constructors):**

- `const LuminaWindowFrame({super.key, required this.window, required this.child})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `window` | `final LuminaWindow window` |  |
| `child` | `final Widget child` |  |
| `edge` | `static const double edge` | The border's thickness; corners take twice that along each side. |

## `lib/ui/core/window/window_state_store.dart`

### `class WindowStateData`

The editor window's placement as the user left it: the restored (un-maximized) bounds in logical pixels, plus whether it was maximized or fullscreen on top of them.

**Yapıcı Metotlar (Constructors):**

- `const WindowStateData({required this.bounds, this.maximized = false, this.fullScreen = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `bounds` | `final Rect bounds` |  |
| `maximized` | `final bool maximized` |  |
| `fullScreen` | `final bool fullScreen` |  |
| `minWidth` | `static const double minWidth` | Smaller than this is not a window anyone left on purpose (a corrupt or hand-edited file); it is ignored. |
| `minHeight` | `static const double minHeight` |  |
| `toJson` | `Map<String, Object> toJson()` |  |
| `fromJson` | `static WindowStateData? fromJson(Object? json)` | The state in [json], or null when it is missing, malformed or too small. |

### `class WindowStateStore`

Keeps [WindowStateData] in the editor preferences — the `window` block of `editor_preferences.json` in [LuminaConfigDir] (a temp directory in every test), beside the other Editor Preferences, which it never touches.

**Yapıcı Metotlar (Constructors):**

- `WindowStateStore({Directory? configDir})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `fileName` | `static const String fileName` | The same file as `EditorPreferences.fileName`. |
| `key` | `static const String key` |  |
| `file` | `final File file` |  |
| `load` | `WindowStateData? load()` | The saved state, or null when there is none (first start) or it is unreadable. |
| `save` | `void save(WindowStateData state)` |  |

## `lib/ui/core/widgets/media/editor_media_widgets.dart`

### `class LuminaVideoPlayerWidget`

`shadcn_flutter` kullanılarak geliştirilmiş, tam özellikli masaüstü/editör video oynatıcı bileşeni. Donanım hızlandırmalı video oynatmayı şunlarla birleştirir:
- Oynat / Duraklat / Durdur denetimleri.
- Geçerli konum ve toplam süre zaman kodları (`MM:SS` / `HH:MM:SS`).
- Hassas konum arama için etkileşimli ilerleme çubuğu (slider).
- Sessize alma geçişi ve ses ayar slider'ı içeren ses popover menüsü.
- Döngü (loop) geçiş butonu.
- Oynatma hızı açılır menü seçicisi (`0.5x`, `1.0x`, `1.25x`, `1.5x`, `2.0x`).

**Yapıcı Metotlar (Constructors):**

- `const LuminaVideoPlayerWidget({super.key, required this.controller, this.fit = BoxFit.contain, this.showControls = true, this.autoPlay = false})`

### `class LuminaAudioPlayerWidget`

Oynatma kontrolleri, ilerleme çubuğu, zaman kodu göstergeleri, ses seviyesi ayarları ve döngü denetimlerine sahip hafif editör ses oynatıcı bileşeni.

**Yapıcı Metotlar (Constructors):**

- `const LuminaAudioPlayerWidget({super.key, required this.controller, this.showControls = true, this.autoPlay = false})`

## `lib/ui/core/widgets/plugin_view/`

Bildirimsel (declarative) eklenti panelleri. Kendi sürecinde çalışan bir eklenti widget gönderemez; paneli bir
`PluginViewSpec` olarak tarif eder (`package:lumina_plugin_protocol`, `lumina_editor_api` yeniden dışa aktarır):
her biri bir `kind`, görünümde benzersiz bir `id`, `props` ve kapsayıcılarda `children` taşıyan `PluginControl`
ağacı. Editör bu tarifi kendi shadcn widget'larıyla (Details panelinin özellik editörleri) çizer, kullanıcı
eylemlerini `PluginViewEvent` olarak iletir; eklenti yeni bir tarif ya da bir `PluginViewPatch` ile yanıt verir.

### `class PluginViewRenderer`

`const PluginViewRenderer({super.key, required PluginViewSpec spec, required void Function(PluginViewEvent) onEvent, String? projectDir})`

[spec]'i yukarıdan aşağı çizer, her kontrol için bir widget, her biri `ValueKey('<viewId>/<controlId>')`
anahtarıyla. [projectDir] göreli görsel yollarını çözer ve ana editör dışında asset-ref alanlarının asset listesini
sağlar. Panel kendisi kaymaz; onu barındıran dock paneli kaydırır.

**Güncelleme.** Yeni bir tarif verin, genellikle `spec.apply(patch)`. Öncekiyle aynı çizilen bir kontrol (aynı
kind, id, props ve children, derinlemesine karşılaştırılır) widget örneğini korur ve Flutter onu atlar: bir yama
yalnızca değiştirdiği kontrolleri yeniden kurar, değişmeyen bir metin alanı odağını, imlecini ve gönderilmemiş
yazısını korur. Aynı tarifin tamamen yeniden gönderilmesi ekranda hiçbir şeyi değiştirmez. Girdiler eklenti farklı
bir `value` gönderene kadar kullanıcının son seçimini gösterir; odaktaki bir metin alanı o durumda bile yazılanı
korur ve alandan çıkılınca eklentinin değerini gösterir. Yeni bir görünüm kimliği ya da proje dizini her şeyi
sıfırdan başlatır.

**Kontroller.** `label` (Details panelindeki gibi 100 px soluk etiket sütunu) ve `tooltip` her türde çalışır;
`enabled: false` bir girdiyi ya da butonu soluklaştırır ve hiçbir olay göndermez.

| Tür | Props | Çizim | Olay |
|---|---|---|---|
| `section` | `title`, `collapsed` | Details kategori başlığı; tıklamak çocukları daraltır (yerel durum; eklentiden gelen yeni `collapsed` kazanır) | yok |
| `row` | `gap` (varsayılan 8) | çocuklar yan yana: butonlar kendi genişliğini korur, metin küçülür, diğerleri kalanı paylaşır | yok |
| `text` | `value`, `style` (`body`, `muted`, `heading`, `code`, `error`) | bir metin satırı (`code` JetBrains Mono ile) | yok |
| `textField` | `value`, `placeholder`, `multiline` | shadcn `TextField` | Enter'da ya da kullanıcı değiştirdiği alandan çıkınca metinle `changed` (çok satırlı alan çıkışta gönderir) |
| `numberField` | `value`, `min`, `max`, `step`, `unit` | `min` ve `max` varsa `SliderField`, yoksa `ScrubNumericField` | onaylanan sayıyla `changed`, `step`'e yuvarlanır, `step` ve `value` tam sayıysa `int`; sürükleme sırasında her adımda değil |
| `boolField` | `value` | shadcn `Checkbox` | bool ile `changed` |
| `enumField` | `value`, `options` (`[{"value","label"}]`) | etiketleri gösteren `EnumField` | seçeneğin değeriyle `changed` |
| `assetRefField` | `value` (projeye göreli yol), `assetTypes` (`AssetType` adları) | türe göre süzülmüş `AssetPickerSelect`, temizleme butonu ve Content Browser kutucukları için bırakma hedefi | projeye göreli yolla, temizlenince null ile `changed` |
| `colorField` | `value` (`#RRGGBB` ya da `#AARRGGBB`) | `ColorField` (renk kutusu, seçici, hex metni); 8 haneli değer alfayı da düzenler | değerin kendi biçimindeki renkle `changed` |
| `button` | `text`, `tone` (`EditorTone` adı), `icon` (`PluginIconSpec` json) | shadcn `Button`: primary, destructive, outline (success ve warning metni renklendirir) | `pressed` |
| `progress` | `value` (0..1, null = belirsiz), `text` | shadcn `LinearProgressIndicator`, metin ve yüzde | yok |
| `log` | `lines` (en yenisi sonda), `maxLines` (varsayılan 200), `height` (varsayılan 160) | en yeni `maxLines` satırı tutan, seçilebilir, eş aralıklı kutu; en alttayken yeni satırları izler | yok |
| `image` | `path` (mutlak ya da projeye göreli) veya `base64`, `height` (varsayılan 160) | sığdırılmış `Image.memory`; dosya asenkron okunur, 64 KB üstü base64 arka plan isolate'inde çözülür | yok |
| `preview3d` | `scene` (`PluginSceneSpec` json), `height` (varsayılan 240) | düğümün mesh'i, `jointLocalPose`'u ve sahnenin `cameraDistance`'ı ile `Plugin3DViewportContainer`, altında sahne düğümlerinin listesi | listedeki bir düğüm tıklanınca `{"node": <ad>}` ile `picked` |
| `divider` | yok | ince bir çizgi | yok |

Editörün tanımadığı bir tür tek bir soluk satır çizer, `unsupported control <kind>`, ve asla hata fırlatmaz.

**Yamalar.** `PluginViewPatchOp.set(id, props)` bir kontrolün props'una birleştirir;
`PluginViewPatchOp.replace(id, control)` onu tümden değiştirir. Uzun bir iş ilerlemesini bir `progress` ve bir `log`
kontrolünü yamalayarak bildirir:

```dart
spec = spec.apply(const PluginViewPatch([
  PluginViewPatchOp.set('job', {'value': 0.6, 'text': 'Placing instances'}),
  PluginViewPatchOp.set('log', {'lines': ['started', 'placed 72 / 120']}),
]));
```

**Sınırlamalar.** 3B önizleme bir seferde tek sahne düğümü gösterir (ilkini ya da altındaki listede seçileni);
düğümün `location`/`rotation`/`scale` değerleri ve sahnenin `cameraTarget`'ı uygulanmaz, viewport gösterilen mesh'i
kendisi çerçeveler. Seçim viewport'a tıklayarak değil, düğüm listesinden yapılır. Buton ikonu adı verilen fonttaki
glif olarak çizilir (çalışma zamanında `IconData` yok, böylece release derlemesi ikon fontlarını budamaya devam
edebilir); editörün kendisinin hiç kullanmadığı bir glif budanmış bir release derlemesinde eksik olabilir.

### Dosyalar

Her tür için kendi dosyasında bir widget: `plugin_section_control.dart` (`PluginControlColumn` da burada),
`plugin_row_control.dart`, `plugin_text_control.dart`, `plugin_text_field_control.dart`,
`plugin_number_field_control.dart`, `plugin_bool_field_control.dart`, `plugin_enum_field_control.dart`,
`plugin_asset_ref_field_control.dart` (arka plan isolate'inde proje taraması `PluginProjectAssets.scan` da burada),
`plugin_color_field_control.dart`, `plugin_button_control.dart`, `plugin_progress_control.dart`,
`plugin_log_control.dart`, `plugin_image_control.dart`, `plugin_preview3d_control.dart`,
`plugin_divider_control.dart`, `plugin_unsupported_control.dart`. `plugin_control_cache.dart` (`PluginControlCache`)
türleri widget'lara eşler ve değişmeyenleri yeniden kullanır; `plugin_view_scope.dart` `PluginViewHost` (görünüm
kimliği, proje dizini, `emit`), `PluginViewScope`, tipli prop okuyucuları, `pluginControlEquals` ve
`PluginFieldRow`'u içerir.

---

[Önceki: Uygulama kabuğu ve ortak UI (devamı, bölüm 1)](core-continued.md) | [Üst: lumina_ui (Lumina Studio)](index.md) | [Sonraki: Ana editör: view'ler](main-editor-views.md)
