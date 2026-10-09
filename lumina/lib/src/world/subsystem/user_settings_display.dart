import 'dart:async';

import 'package:lumina/src/game/game_display.dart';
import 'package:lumina/src/world/subsystem/world_subsystem.dart';

/// The display half of the game user settings: the screen resolution and
/// the monitor the game runs on ([LuminaGameDisplay]).
///
/// Like every user setting, [setScreenResolution] and [setFullscreenMonitor]
/// only stage the choice; Apply Scalability Settings ([applyDisplaySettings])
/// applies it, which resizes the window or the render target and keeps the
/// choice in `GameUserSettings.json`. An apply with nothing staged leaves the
/// window alone.
mixin LuminaUserSettingsDisplay on LuminaWorldSubsystem {
  (int, int)? _stagedResolution;
  bool _resolutionStaged = false;
  int? _stagedMonitor;
  bool _monitorStaged = false;

  /// The chosen resolution (staged, else applied); null is native.
  (int, int)? get screenResolutionSetting => _resolutionStaged ? _stagedResolution : LuminaGameDisplay.screenResolution;

  /// The chosen monitor (staged, else applied); null leaves the window
  /// where it is.
  int? get fullscreenMonitorSetting => _monitorStaged ? _stagedMonitor : LuminaGameDisplay.fullscreenMonitor;

  /// Stages [width]×[height] physical pixels as the screen resolution; a
  /// non-positive side stages native.
  void setScreenResolution(int width, int height) {
    _stagedResolution = LuminaGameDisplay.normalize((width, height));
    _resolutionStaged = true;
  }

  /// Stages monitor [index] (see `Get Monitor Count`); a negative index
  /// stages none.
  void setFullscreenMonitor(int index) {
    _stagedMonitor = index < 0 ? null : index;
    _monitorStaged = true;
  }

  /// Whether a display choice waits for [applyDisplaySettings].
  bool get hasStagedDisplaySettings => _resolutionStaged || _monitorStaged;

  /// Applies the staged resolution and monitor, if any; the window changes
  /// and the settings write finish in the background
  /// ([LuminaGameDisplay.pendingApply]).
  void applyDisplaySettings() {
    if (!hasStagedDisplaySettings) return;
    final resolution = screenResolutionSetting;
    final monitor = fullscreenMonitorSetting;
    _resolutionStaged = false;
    _monitorStaged = false;
    unawaited(LuminaGameDisplay.apply(resolution: resolution, monitor: monitor));
  }

  /// The display settings as settings-file keys (what `toMap` adds).
  Map<String, Object?> displaySettingsMap() {
    if (!hasStagedDisplaySettings) return LuminaGameDisplay.settingsPatch();
    final res = screenResolutionSetting;
    final monitor = fullscreenMonitorSetting;
    return {
      LuminaGameDisplay.resolutionKey: res == null ? null : {'width': res.$1, 'height': res.$2},
      LuminaGameDisplay.monitorKey: monitor == null ? null : {'index': monitor},
    };
  }

  /// Stages the display settings in [map] (a loaded settings file) that
  /// differ from the applied ones.
  void stageDisplaySettingsFrom(Map<String, dynamic> map) {
    if (map.containsKey(LuminaGameDisplay.resolutionKey)) {
      final res = LuminaGameDisplay.resolutionFrom(map);
      if (res != LuminaGameDisplay.screenResolution) setScreenResolution(res?.$1 ?? 0, res?.$2 ?? 0);
    }
    if (map.containsKey(LuminaGameDisplay.monitorKey)) {
      final monitor = LuminaGameDisplay.monitorFrom(map);
      if (monitor != LuminaGameDisplay.fullscreenMonitor) setFullscreenMonitor(monitor ?? -1);
    }
  }
}
