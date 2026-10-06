[English](../../en/lumina_ui/core-continued-2.md)

# Uygulama kabuğu ve ortak UI (devamı, bölüm 2)

Uygulama kabuğu ve ortak UI sayfasının devamı: `lib/ui/core/window/` altındaki diğer public dosyalar. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/core/window/lumina_window.dart`](#libuicorewindowlumina_windowdart)
- [`lib/ui/core/window/window_controls.dart`](#libuicorewindowwindow_controlsdart)
- [`lib/ui/core/window/window_state_store.dart`](#libuicorewindowwindow_state_storedart)
- [`lib/ui/core/widgets/media/editor_media_widgets.dart`](#libuicorewidgetsmediaeditor_media_widgetsdart)

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

---

[Önceki: Uygulama kabuğu ve ortak UI (devamı, bölüm 1)](core-continued.md) | [Üst: lumina_ui (Lumina Studio)](index.md) | [Sonraki: Ana editör: view'ler](main-editor-views.md)
