import 'dart:async';
import 'dart:developer' as developer;

import 'package:lumina_core/lumina_core.dart' show ObservableValue;

import 'package:lumina/src/game/display_info.dart';
import 'package:lumina/src/game/game_user_settings_file.dart';
import 'package:lumina/src/game/game_window.dart';

/// What reports the monitors and moves or resizes the real window: the
/// generated runner's `lumina/game_window` channel on Windows and Linux,
/// the browser on the web (lumina_widgets installs them).
abstract interface class LuminaDisplayBackend {
  /// The monitors and the window's client area; null when the runner cannot
  /// report them (a runner generated before it).
  Future<LuminaDisplayInfo?> queryDisplays();

  /// Gives the window a client area of [width]×[height] physical pixels,
  /// clamped to its monitor's work area and centred on it. Returns the
  /// client size it got; null when the window cannot be resized (the web, an
  /// older runner).
  Future<(int, int)?> setClientSize(int width, int height);

  /// Moves the window to monitor [index] (borderless fullscreen covers it,
  /// a window is centred on it); whether it moved.
  Future<bool> moveToMonitor(int index);

  /// Called when a monitor is added, removed or changes mode, or the window
  /// moves to another monitor.
  set onDisplayChanged(void Function(LuminaDisplayInfo info)? listener);
}

/// The game's screen resolution and monitor, what the Blueprint display
/// nodes read and `Set Screen Resolution` / `Set Fullscreen Monitor` (through
/// `LuminaUserSettingsSubsystem`) change.
///
/// The chosen resolution means, by window mode:
/// - **Windowed**: the window's client area, in physical pixels, clamped to
///   the monitor's work area and centred on it. The game renders at the
///   client size.
/// - **Borderless fullscreen**: the window keeps covering the monitor and
///   the game's render target is the chosen resolution ([renderResolution]),
///   scaled to the monitor with its aspect ratio kept. A resolution at least
///   as large as the monitor renders native. The display mode itself never
///   changes (no exclusive fullscreen).
///
/// A platform whose window cannot be resized (the web, Play-In-Editor)
/// renders the chosen resolution scaled into the window, as in fullscreen.
/// Resolution Scale and the upscalers' render scale apply inside that render
/// target. No choice ([screenResolution] null) is native: the client area
/// or the whole monitor.
///
/// The choice is kept in `GameUserSettings.json` ([LuminaGameUserSettingsFile])
/// under `screen_resolution` and `fullscreen_monitor`;
/// `LuminaGameWindow.restore` puts it back before the first frame.
abstract final class LuminaGameDisplay {
  /// The runner's displays, set by lumina_widgets.
  static LuminaDisplayBackend? backend;

  /// The last display report; null until one arrived (or without a backend).
  static final ObservableValue<LuminaDisplayInfo?> info = ObservableValue(null);

  /// The fixed size, in physical pixels, the game view renders at; null
  /// renders at the widget's own size. The game widget follows it.
  static final ObservableValue<(int, int)?> renderResolution = ObservableValue(null);

  /// The key of the chosen resolution in the settings file.
  static const String resolutionKey = 'screen_resolution';

  /// The key of the chosen monitor in the settings file.
  static const String monitorKey = 'fullscreen_monitor';

  static (int, int)? _screenResolution;
  static int? _fullscreenMonitor;
  static (int, int)? _clientSize;
  static Future<void> _pending = Future<void>.value();

  /// The applied resolution choice; null is native.
  static (int, int)? get screenResolution => _screenResolution;

  /// The applied monitor choice; null leaves the window where it is.
  static int? get fullscreenMonitor => _fullscreenMonitor;

  /// Completes when the last apply (window changes and settings write) is
  /// done.
  static Future<void> get pendingApply => _pending;

  /// [resolution] with a non-positive side as native (null).
  static (int, int)? normalize((int, int)? resolution) =>
      resolution == null || resolution.$1 <= 0 || resolution.$2 <= 0 ? null : resolution;

  /// Asks the [backend] for the displays and keeps the answer in [info].
  static Future<LuminaDisplayInfo?> refresh() async {
    final b = backend;
    if (b == null) return info.value;
    try {
      final next = await b.queryDisplays();
      if (next != null) {
        info.value = next;
        if (next.clientSize != null) _clientSize = next.clientSize;
      }
    } on Object catch (e) {
      developer.log('Displays could not be queried: $e', name: 'LuminaGameDisplay');
    }
    return info.value;
  }

  /// Applies [resolution] (null or a non-positive side: native) and, when
  /// given, moves the game to [monitor]; [persist] keeps both in the
  /// settings file.
  ///
  /// The choice ([screenResolution], [fullscreenMonitor]) is taken at once;
  /// the window changes and the settings write follow in order
  /// ([pendingApply]). Without a [backend] the render target changes at once.
  static Future<void> apply({(int, int)? resolution, int? monitor, bool persist = true}) {
    _screenResolution = normalize(resolution);
    _fullscreenMonitor = monitor;
    if (backend == null) _renderTargetLayout();
    final done = Completer<void>();
    _pending = _pending.then((_) async {
      try {
        await _apply(monitor, persist);
      } on Object catch (e) {
        developer.log('Display settings not applied: $e', name: 'LuminaGameDisplay');
      }
      done.complete();
    });
    return done.future;
  }

  static Future<void> _apply(int? monitor, bool persist) async {
    final b = backend;
    if (b != null) {
      final current = info.value ?? await refresh();
      if (monitor != null && current != null && monitor >= 0 && monitor < current.monitors.length &&
          monitor != current.currentMonitor) {
        await b.moveToMonitor(monitor);
      }
      await refresh();
    }
    await _layout(resizeWindow: true);
    if (persist) await _save();
  }

  /// Re-applies the choice after the window mode changed (the runner's
  /// toggle, Set Fullscreen Mode).
  static Future<void> onWindowModeChanged() {
    _pending = _pending.then((_) async {
      try {
        await refresh();
        await _layout(resizeWindow: true);
      } on Object catch (e) {
        developer.log('Display settings not re-applied: $e', name: 'LuminaGameDisplay');
      }
    });
    return _pending;
  }

  static Future<void> _layout({required bool resizeWindow}) async {
    final res = _screenResolution;
    if (res == null) {
      renderResolution.value = null;
      return;
    }
    final b = backend;
    if (LuminaGameWindow.mode.value == LuminaWindowMode.windowed && b != null) {
      if (!resizeWindow) {
        if (_clientSize != null) return;
      } else {
        final got = await b.setClientSize(res.$1, res.$2);
        if (got != null) {
          _clientSize = got;
          renderResolution.value = null;
          return;
        }
      }
    }
    _renderTargetLayout();
  }

  /// Borderless fullscreen, or a window that cannot be resized: the chosen
  /// resolution is the render target, scaled to the window; native when it
  /// is at least the monitor's size.
  static void _renderTargetLayout() {
    final res = _screenResolution;
    final monitor = info.value?.current;
    final native = res == null || (monitor != null && res.$1 >= monitor.width && res.$2 >= monitor.height);
    renderResolution.value = native ? null : res;
  }

  static Future<void> _save() async {
    final path = LuminaGameWindow.settingsFilePath;
    if (path == null) return;
    await LuminaGameUserSettingsFile.update(path, settingsPatch());
  }

  /// The keys this class keeps in the settings file (null values remove
  /// them).
  static Map<String, Object?> settingsPatch() {
    final res = _screenResolution;
    final monitorIndex = _fullscreenMonitor;
    final monitors = info.value?.monitors ?? const <LuminaMonitor>[];
    final monitor = monitorIndex != null && monitorIndex >= 0 && monitorIndex < monitors.length ? monitors[monitorIndex] : null;
    return {
      resolutionKey: res == null ? null : {'width': res.$1, 'height': res.$2},
      monitorKey: monitorIndex == null
          ? null
          : {'index': monitorIndex, if (monitor != null) 'device': monitor.device, if (monitor != null) 'name': monitor.name},
    };
  }

  /// The resolution stored under [resolutionKey] in [settings]; null for
  /// none (native).
  static (int, int)? resolutionFrom(Map<String, dynamic> settings) {
    final v = settings[resolutionKey];
    if (v is Map && v['width'] is num && v['height'] is num) {
      return normalize(((v['width'] as num).round(), (v['height'] as num).round()));
    }
    if (v is List && v.length >= 2 && v[0] is num && v[1] is num) {
      return normalize(((v[0] as num).round(), (v[1] as num).round()));
    }
    return null;
  }

  /// The monitor stored under [monitorKey] in [settings]: the monitor with
  /// the same device id when it is still connected, else the stored index;
  /// null for none.
  static int? monitorFrom(Map<String, dynamic> settings) {
    final v = settings[monitorKey];
    if (v is num) return v.round();
    if (v is! Map) return null;
    final device = v['device'];
    final monitors = info.value?.monitors ?? const <LuminaMonitor>[];
    if (device is String && device.isNotEmpty) {
      for (final m in monitors) {
        if (m.device == device) return m.index;
      }
    }
    final index = v['index'];
    if (index is! num) return null;
    final i = index.round();
    return monitors.isEmpty || (i >= 0 && i < monitors.length) ? i : null;
  }

  /// Start-up: listens for display changes, reads the displays and applies
  /// the choice stored in [settings] (the settings file's content) without
  /// writing it back.
  static Future<void> restore(Map<String, dynamic> settings) async {
    backend?.onDisplayChanged = (next) {
      info.value = next;
      if (next.clientSize != null) _clientSize = next.clientSize;
      // The monitor may have a new size: the render target follows; the
      // window is left as the player sized it.
      unawaited(_layout(resizeWindow: false));
    };
    await refresh();
    final resolution = resolutionFrom(settings);
    final monitor = monitorFrom(settings);
    if (resolution == null && monitor == null) return;
    await apply(resolution: resolution, monitor: monitor, persist: false);
  }

  // --- What the Blueprint nodes read ----------------------------------------

  /// What the game renders at: [renderResolution] when set, else the bound
  /// view's size ([viewportSize] when [viewBound]), else the window's client
  /// area, else the chosen resolution or [viewportSize].
  static (int, int) currentResolution((int, int) viewportSize, {required bool viewBound}) {
    final render = renderResolution.value;
    if (render != null) return render;
    if (viewBound) return viewportSize;
    return _clientSize ?? _screenResolution ?? viewportSize;
  }

  /// The mode the desktop of the game's monitor runs at; [fallback] (the
  /// render size) without a display report.
  static LuminaDisplayMode desktopMode((int, int) fallback) =>
      info.value?.current?.current ?? LuminaDisplayMode(fallback.$1, fallback.$2);

  /// The distinct resolutions the game's monitor offers, ascending; the
  /// [fallback] alone without a display report.
  static List<(int, int)> supportedResolutions((int, int) fallback) =>
      info.value?.current?.resolutions ?? [fallback];

  /// The refresh rates the game's monitor offers at [width]×[height],
  /// ascending.
  static List<int> refreshRatesFor(int width, int height) {
    final monitor = info.value?.current;
    if (monitor == null) return const [];
    return monitor.refreshRatesFor(width, height);
  }

  /// How many monitors there are (1 without a display report).
  static int get monitorCount => info.value?.monitors.length ?? 1;

  /// The index and name of the monitor the game is on.
  static (int, String) get currentMonitor {
    final monitor = info.value?.current;
    return monitor == null ? (0, 'Display') : (monitor.index, monitor.name);
  }

  /// Back to a fresh process's state (tests).
  static void resetForTesting() {
    backend?.onDisplayChanged = null;
    backend = null;
    info.value = null;
    renderResolution.value = null;
    _screenResolution = null;
    _fullscreenMonitor = null;
    _clientSize = null;
    _pending = Future<void>.value();
  }
}
