import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'window_state_store.dart';

export 'package:window_manager/window_manager.dart' show ResizeEdge, TitleBarStyle, WindowOptions;

/// Asked before the window closes; false keeps it open. The editor's guard
/// shows the unsaved-changes prompt.
typedef WindowCloseGuard = Future<bool> Function();

/// Lumina Studio's own window chrome: the native title bar
/// is hidden, and the editor's menu row, [LuminaWindowControls] and the resize
/// border drive the window through this controller.
///
/// It wraps `package:window_manager` and never assumes a state change: the
/// maximize / fullscreen flags follow the plugin's events, so a window
/// manager that ignores a request (a tiling WM refusing to maximize) or
/// changes the window on its own is reflected as it really is.
///
/// Closing — from [LuminaWindowControls], or from the window manager (Alt+F4,
/// the taskbar), which `setPreventClose(true)` turns into a `close` event —
/// runs every registered [WindowCloseGuard] first, saves the window's
/// placement through [store] and only then destroys the window.
class LuminaWindow extends ChangeNotifier with WindowListener {
  LuminaWindow({WindowManager? manager, WindowStateStore? store})
      : _wm = manager ?? windowManager,
        _explicitStore = store {
    _wm.addListener(this);
  }

  /// The app's window. Widgets reach it through [LuminaWindowScope.of].
  static final LuminaWindow instance = LuminaWindow();

  final WindowManager _wm;
  final WindowStateStore? _explicitStore;
  WindowStateStore? _defaultStore;

  /// Where the placement is saved; the editor preferences by default.
  WindowStateStore get store => _explicitStore ?? (_defaultStore ??= WindowStateStore());

  bool _maximized = false;
  bool _fullScreen = false;
  bool _closing = false;
  bool _disposed = false;
  Rect? _normalBounds;
  Timer? _boundsTimer;
  final List<WindowCloseGuard> _guards = <WindowCloseGuard>[];

  bool get isMaximized => _maximized;
  bool get isFullScreen => _fullScreen;

  /// The restored (un-maximized, windowed) bounds last seen.
  Rect? get normalBounds => _normalBounds;

  /// The desktop OS the chrome is drawn for (`linux`, `windows`, `macos`);
  /// a test can pretend to be another one.
  static String get os => debugOsOverride ?? (kIsWeb ? 'web' : Platform.operatingSystem);
  static String? debugOsOverride;

  /// Whether this platform shows Lumina's own minimize / maximize / close
  /// buttons. macOS keeps its traffic lights (drawn by the system at the left
  /// of the hidden title bar, `windowButtonVisibility: true`).
  static bool get drawsOwnControls => os == 'linux' || os == 'windows';

  /// Whether the app needs its own resize border: an undecorated GTK window
  /// has no WM handles. Windows keeps its native frame border and macOS its
  /// window edges with a hidden title bar.
  static bool get needsResizeBorder => os == 'linux';

  /// The room macOS's traffic lights take at the left of the menu row.
  static double get leadingInset => os == 'macos' ? 72 : 0;

  /// Prepares the window before the first frame: restores the saved
  /// placement over [options] (whose `titleBarStyle` is the app's), turns the
  /// window manager's close into a request, and shows the window.
  Future<void> startup(WindowOptions options) async {
    final saved = store.load();
    final restored = WindowOptions(
      size: saved?.bounds.size ?? options.size,
      center: saved == null ? options.center : false,
      minimumSize: options.minimumSize ?? const Size(960, 600),
      maximumSize: options.maximumSize,
      alwaysOnTop: options.alwaysOnTop,
      fullScreen: options.fullScreen,
      backgroundColor: options.backgroundColor,
      skipTaskbar: options.skipTaskbar,
      title: options.title,
      titleBarStyle: options.titleBarStyle,
      windowButtonVisibility: options.windowButtonVisibility ?? true,
    );
    // Its own guard: centring reads the bounds, which can fail;
    // the window must still be shown.
    await _guard(() => _wm.waitUntilReadyToShow(restored));
    await _guard(() async {
      if (saved != null) {
        await _wm.setBounds(saved.bounds);
        _normalBounds = saved.bounds;
      }
      if (saved?.maximized ?? false) await _wm.maximize();
      if (saved?.fullScreen ?? false) await _wm.setFullScreen(true);
      await _wm.setPreventClose(true);
      await _wm.show();
      await _wm.focus();
      _normalBounds ??= await _readBounds();
      await _sync();
    });
  }

  Future<void> minimize() => _guard(_wm.minimize);

  /// Maximizes or restores, from the window's real state.
  Future<void> toggleMaximize() => _guard(() async {
        if (await _wm.isMaximized()) {
          await _wm.unmaximize();
        } else {
          await _rememberBounds();
          await _wm.maximize();
        }
      });

  /// Enters or leaves fullscreen, from the window's real state.
  Future<void> toggleFullScreen() => _guard(() async {
        final full = await _wm.isFullScreen();
        if (!full) await _rememberBounds();
        await _wm.setFullScreen(!full);
      });

  Future<void> startDragging() => _guard(_wm.startDragging);

  Future<void> startResizing(ResizeEdge edge) => _guard(() => _wm.startResizing(edge));

  void addCloseGuard(WindowCloseGuard guard) => _guards.add(guard);

  void removeCloseGuard(WindowCloseGuard guard) => _guards.remove(guard);

  /// Asks every close guard (most recent first); when all agree, saves the
  /// placement and destroys the window. Returns whether the window closed.
  Future<bool> requestClose() async {
    if (_closing) return false;
    _closing = true;
    try {
      for (final guard in _guards.reversed.toList()) {
        if (!await guard()) return false;
      }
      await _saveState();
      await _guard(_wm.destroy);
      return true;
    } finally {
      _closing = false;
    }
  }

  Future<void> _saveState() async {
    await _guard(() async {
      final maximized = await _wm.isMaximized();
      final full = await _wm.isFullScreen();
      if (!maximized && !full) _normalBounds = await _readBounds() ?? _normalBounds;
      final bounds = _normalBounds;
      if (bounds == null) return;
      store.save(WindowStateData(bounds: bounds, maximized: maximized, fullScreen: full));
    });
  }

  Future<void> _rememberBounds() async {
    if (await _wm.isMaximized() || await _wm.isFullScreen()) return;
    _normalBounds = await _readBounds() ?? _normalBounds;
  }

  /// The window's bounds, or null when the plugin cannot tell (on
  /// Windows it answers with null fields for a window that is not realised,
  /// e.g. an integration test's, and `window_manager` then throws a
  /// [TypeError] building the [Rect]).
  Future<Rect?> _readBounds() async {
    try {
      return await _wm.getBounds();
    } on TypeError {
      return null;
    }
  }

  Future<void> _sync() async {
    final maximized = await _wm.isMaximized();
    final full = await _wm.isFullScreen();
    _set(maximized: maximized, fullScreen: full);
  }

  void _set({bool? maximized, bool? fullScreen}) {
    final m = maximized ?? _maximized, f = fullScreen ?? _fullScreen;
    if (m == _maximized && f == _fullScreen) return;
    _maximized = m;
    _fullScreen = f;
    if (!_disposed) notifyListeners();
  }

  /// Runs a plugin call; where there is no native window (a widget test
  /// without one, a platform without the plugin) the call is skipped, and so
  /// is one the native side cannot answer: on Windows `getBounds` returns
  /// null fields for a window that is not realised (an integration test's),
  /// which `window_manager` turns into a [TypeError] — also inside its own
  /// `center` / `getSize`.
  Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } on MissingPluginException {
      // No native window underneath.
    } on TypeError {
      // The native window could not answer (no bounds yet).
    }
  }

  // --- WindowListener --------------------------------------------------------

  @override
  void onWindowMaximize() => _set(maximized: true);

  @override
  void onWindowUnmaximize() => _set(maximized: false);

  @override
  void onWindowEnterFullScreen() => _set(fullScreen: true);

  @override
  void onWindowLeaveFullScreen() => _set(fullScreen: false);

  @override
  void onWindowResize() => _scheduleBoundsRead();

  @override
  void onWindowMove() => _scheduleBoundsRead();

  @override
  void onWindowResized() => _scheduleBoundsRead();

  @override
  void onWindowMoved() => _scheduleBoundsRead();

  @override
  void onWindowClose() => unawaited(requestClose());

  /// GTK reports every step of a drag; the bounds are read once it settles.
  void _scheduleBoundsRead() {
    _boundsTimer?.cancel();
    _boundsTimer = Timer(const Duration(milliseconds: 200), () => unawaited(_guard(_rememberBounds)));
  }

  @override
  void dispose() {
    _disposed = true;
    _boundsTimer?.cancel();
    _wm.removeListener(this);
    super.dispose();
  }
}

/// Puts a [LuminaWindow] in the tree (the app's [LuminaWindow.instance] when
/// there is none), so window chrome rebuilds when the window changes state.
class LuminaWindowScope extends InheritedNotifier<LuminaWindow> {
  const LuminaWindowScope({super.key, required LuminaWindow window, required super.child}) : super(notifier: window);

  static LuminaWindow of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LuminaWindowScope>()?.notifier ?? LuminaWindow.instance;

  /// The window without subscribing to its changes (for callbacks).
  static LuminaWindow read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LuminaWindowScope>()?.notifier ?? LuminaWindow.instance;
}
