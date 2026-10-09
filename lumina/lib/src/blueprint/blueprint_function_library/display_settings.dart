part of '../blueprint_function_library.dart';

/// [LuminaBlueprintFunctionLibrary.callShapes]: the screen resolution and
/// monitor nodes.
const Map<String, LuminaBlueprintCallShape> _displaySettingsCallShapes = <String, LuminaBlueprintCallShape>{
  'get_screen_resolution': LuminaBlueprintCallShape('getScreenResolution', [], self: true, outputs: ['width', 'height']),
  'get_desktop_resolution':
      LuminaBlueprintCallShape('getDesktopResolution', [], self: true, outputs: ['width', 'height', 'refresh_rate']),
  'get_supported_resolutions':
      LuminaBlueprintCallShape('getSupportedResolutions', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'get_supported_refresh_rates': LuminaBlueprintCallShape('getSupportedRefreshRates', ['width', 'height'],
      self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'get_monitor_count': LuminaBlueprintCallShape('getMonitorCount', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'get_current_monitor': LuminaBlueprintCallShape('getCurrentMonitor', [], self: true, outputs: ['index', 'name']),
  'set_screen_resolution': LuminaBlueprintCallShape('setScreenResolution', ['width', 'height'], self: true),
  'set_fullscreen_monitor': LuminaBlueprintCallShape('setFullscreenMonitor', ['index'], self: true),
};

/// [LuminaBlueprintFunctionLibrary.builtInFunctions]: the screen resolution
/// and monitor nodes.
final Map<String, LuminaBlueprintFunction> _displaySettingsFunctions = <String, LuminaBlueprintFunction>{
  'get_screen_resolution': (c, i) {
    final r = _getScreenResolution(c.self);
    return {'width': r.width, 'height': r.height};
  },
  'get_desktop_resolution': (c, i) {
    final r = _getDesktopResolution(c.self);
    return {'width': r.width, 'height': r.height, 'refresh_rate': r.refreshRate};
  },
  'get_supported_resolutions': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getSupportedResolutions(c.self)),
  'get_supported_refresh_rates': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getSupportedRefreshRates(
      c.self, LuminaBlueprintFunctionLibrary._n(i['width'], 1920), LuminaBlueprintFunctionLibrary._n(i['height'], 1080))),
  'get_monitor_count': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getMonitorCount(c.self)),
  'get_current_monitor': (c, i) {
    final r = _getCurrentMonitor(c.self);
    return {'index': r.index, 'name': r.name};
  },
  'set_screen_resolution': (c, i) => _settingsEffect(() => _setScreenResolution(
      c.self, LuminaBlueprintFunctionLibrary._n(i['width'], 1920), LuminaBlueprintFunctionLibrary._n(i['height'], 1080))),
  'set_fullscreen_monitor': (c, i) =>
      _settingsEffect(() => _setFullscreenMonitor(c.self, LuminaBlueprintFunctionLibrary._n(i['index'], 0))),
};

(int, int) _renderSizeOf(LuminaActor self) => self.world?.viewportSize ?? (1280, 720);

/// What the game renders at, in physical pixels: the window's client area
/// (windowed) or the chosen resolution scaled to the monitor (borderless
/// fullscreen). A change applied this frame shows from the next one.
({int width, int height}) _getScreenResolution(LuminaActor self) {
  final world = self.world;
  final (w, h) = LuminaGameDisplay.currentResolution(_renderSizeOf(self), viewBound: world?.filamentViewOrNull != null);
  return (width: w, height: h);
}

/// The resolution and refresh rate the desktop of the game's monitor runs at.
({int width, int height, int refreshRate}) _getDesktopResolution(LuminaActor self) {
  final mode = LuminaGameDisplay.desktopMode(_renderSizeOf(self));
  return (width: mode.width, height: mode.height, refreshRate: mode.refreshRate);
}

/// The distinct resolutions the game's monitor offers (X = width, Y =
/// height), ascending by width then height.
List<Object?> _getSupportedResolutions(LuminaActor self) => [
      for (final (w, h) in LuminaGameDisplay.supportedResolutions(_renderSizeOf(self))) Vector2(w.toDouble(), h.toDouble()),
    ];

/// The refresh rates (Hz) the game's monitor offers at [width]×[height],
/// ascending; empty for a resolution it does not have.
List<Object?> _getSupportedRefreshRates(LuminaActor self, [int width = 1920, int height = 1080]) =>
    List<Object?>.of(LuminaGameDisplay.refreshRatesFor(width, height));

int _getMonitorCount(LuminaActor self) => LuminaGameDisplay.monitorCount;

/// The monitor the game is on: its index (for Set Fullscreen Monitor) and
/// name.
({int index, String name}) _getCurrentMonitor(LuminaActor self) {
  final (index, name) = LuminaGameDisplay.currentMonitor;
  return (index: index, name: name);
}

/// Stages [width]×[height] (0 × 0: native); Apply Scalability Settings
/// applies and keeps it.
void _setScreenResolution(LuminaActor self, [int width = 1920, int height = 1080]) =>
    _userSettings(self).setScreenResolution(width, height);

/// Stages the monitor at [index]; Apply Scalability Settings moves the game.
void _setFullscreenMonitor(LuminaActor self, [int index = 0]) => _userSettings(self).setFullscreenMonitor(index);
