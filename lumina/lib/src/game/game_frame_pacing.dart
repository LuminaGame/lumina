import 'package:lumina_core/lumina_core.dart' show ObservableValue;

/// A target frame rate and VSync choice.
class LuminaFramePacingSettings {
  const LuminaFramePacingSettings({this.targetFps = 0, this.vsyncEnabled = false});

  /// Frames per second; 0 is unlimited (the display's refresh rate).
  final int targetFps;

  /// Whether every frame is held for the same whole number of display
  /// refreshes (`FilamentFrameLimiter.vsync`).
  final bool vsyncEnabled;

  @override
  bool operator ==(Object other) =>
      other is LuminaFramePacingSettings && other.targetFps == targetFps && other.vsyncEnabled == vsyncEnabled;

  @override
  int get hashCode => Object.hash(targetFps, vsyncEnabled);

  @override
  String toString() => 'LuminaFramePacingSettings(targetFps: $targetFps, vsync: $vsyncEnabled)';
}

/// The game's target frame rate and VSync, what the game widget paces its
/// world tick and its rendered frames by, and what `Set Target FPS` /
/// `Set VSync Enabled` (through `LuminaUserSettingsSubsystem` and Apply
/// Scalability Settings) change.
///
/// The project's Target FPS and VSync (Project Settings, passed to the game
/// host by the generated `main()`) are the defaults ([setProjectDefaults]);
/// the player's applied choice ([apply]) wins over them. The choice is kept
/// in `GameUserSettings.json` under `target_fps` and `vsync` when the player
/// saves the user settings, and `LuminaGameWindow.restore` puts it back
/// before the first frame ([restore]). Without a saved choice the project
/// defaults stay in force, also when the project changes them.
///
/// How a built game presents: Filament renders into an offscreen (headless)
/// swap chain and the frame is shown through Flutter, which presents on the
/// display's vsync. So no rate goes above the refresh rate and the picture
/// never tears whatever [vsyncEnabled] says; the target is met by rendering
/// on some refreshes and not others (`FilamentFrameLimiter`), and VSync
/// chooses the pacing: on holds every frame for the same number of
/// refreshes (even frame times, the largest refresh divisor not above the
/// target), off keeps the target as the average. On the web the browser's
/// requestAnimationFrame is the vsync. A swap chain that presents to a
/// window itself takes `SwapChain::CONFIG_DISABLE_VSYNC` for VSync off.
///
/// Play-In-Editor never changes the editor's own pacing: a session starts
/// from the project defaults ([beginPlayInEditor]) and records the choice
/// (Get returns it), but the editor viewport keeps rendering at its rate.
abstract final class LuminaGameFramePacing {
  /// The key of the target frame rate in the settings file.
  static const String targetFpsKey = 'target_fps';

  /// The key of VSync in the settings file.
  static const String vsyncKey = 'vsync';

  static int _projectTargetFps = 0;
  static bool _projectVsync = false;
  static int? _playerTargetFps;
  static bool? _playerVsync;

  /// What is in force; the game widget follows it.
  static final ObservableValue<LuminaFramePacingSettings> settings = ObservableValue(const LuminaFramePacingSettings());

  /// The target frame rate in force (0 is unlimited).
  static int get targetFps => settings.value.targetFps;

  /// Whether VSync is in force.
  static bool get vsyncEnabled => settings.value.vsyncEnabled;

  /// Whether the player chose a target frame rate or VSync (applied, or
  /// restored from the settings file).
  static bool get hasPlayerChoice => _playerTargetFps != null || _playerVsync != null;

  /// The project's Target FPS and VSync, in force where the player chose
  /// nothing.
  static void setProjectDefaults({required int targetFps, required bool vsyncEnabled}) {
    _projectTargetFps = _fps(targetFps);
    _projectVsync = vsyncEnabled;
    _publish();
  }

  /// Puts the player's choice in force (null keeps that half as it is).
  static void apply({int? targetFps, bool? vsyncEnabled}) {
    if (targetFps != null) _playerTargetFps = _fps(targetFps);
    if (vsyncEnabled != null) _playerVsync = vsyncEnabled;
    _publish();
  }

  /// Start-up: the choice stored in [saved] (the settings file's content),
  /// if any, before the first frame.
  static void restore(Map<String, dynamic> saved) {
    final fps = saved[targetFpsKey];
    final vsync = saved[vsyncKey];
    apply(targetFps: fps is num ? fps.round() : null, vsyncEnabled: vsync is bool ? vsync : null);
  }

  /// A Play-In-Editor session: the project's settings, no earlier session's
  /// choice.
  static void beginPlayInEditor({required int targetFps, required bool vsyncEnabled}) {
    _playerTargetFps = null;
    _playerVsync = null;
    setProjectDefaults(targetFps: targetFps, vsyncEnabled: vsyncEnabled);
  }

  /// The keys this class keeps in the settings file: the player's choice,
  /// null (removed) where there is none.
  static Map<String, Object?> settingsPatch() => {targetFpsKey: _playerTargetFps, vsyncKey: _playerVsync};

  static int _fps(int fps) => fps < 0 ? 0 : fps;

  static void _publish() {
    settings.value = LuminaFramePacingSettings(
      targetFps: _playerTargetFps ?? _projectTargetFps,
      vsyncEnabled: _playerVsync ?? _projectVsync,
    );
  }

  /// Back to a fresh process's state (tests).
  static void resetForTesting() {
    _projectTargetFps = 0;
    _projectVsync = false;
    _playerTargetFps = null;
    _playerVsync = null;
    _publish();
  }
}
