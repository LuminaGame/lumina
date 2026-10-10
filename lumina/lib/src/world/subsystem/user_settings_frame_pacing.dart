import 'package:lumina/src/game/game_frame_pacing.dart';
import 'package:lumina/src/world/subsystem/world_subsystem.dart';

/// The frame rate half of the game user settings: the target frame rate and
/// VSync the game paces its frames by ([LuminaGameFramePacing]).
///
/// [setTargetFps] and [setVsyncEnabled] only stage the choice; Apply
/// Scalability Settings ([applyFramePacing]) puts it in force, and Save Game
/// User Settings keeps it in `GameUserSettings.json`. [targetFps] and
/// [vsyncEnabled] return the staged choice, else what is in force (the
/// player's applied choice, else the project's Target FPS and VSync).
mixin LuminaUserSettingsFramePacing on LuminaWorldSubsystem {
  int? _stagedTargetFps;
  bool? _stagedVsync;

  /// Target frame rate in FPS (0 = unlimited): staged, else in force.
  int get targetFps => _stagedTargetFps ?? LuminaGameFramePacing.targetFps;

  /// Whether VSync is on: staged, else in force.
  bool get vsyncEnabled => _stagedVsync ?? LuminaGameFramePacing.vsyncEnabled;

  /// Stages the target frame rate in frames per second (0 or less =
  /// unlimited).
  void setTargetFps(int fps) => _stagedTargetFps = fps < 0 ? 0 : fps;

  /// Stages VSync on or off.
  void setVsyncEnabled(bool enabled) => _stagedVsync = enabled;

  /// Whether a frame rate choice waits for [applyFramePacing].
  bool get hasStagedFramePacing => _stagedTargetFps != null || _stagedVsync != null;

  /// Puts the staged target frame rate and VSync, if any, in force; the
  /// game widget follows at once.
  void applyFramePacing() {
    if (!hasStagedFramePacing) return;
    final fps = _stagedTargetFps;
    final vsync = _stagedVsync;
    _stagedTargetFps = null;
    _stagedVsync = null;
    LuminaGameFramePacing.apply(targetFps: fps, vsyncEnabled: vsync);
  }

  /// The frame rate settings as settings-file keys (what `toMap` adds): the
  /// player's choice, staged over applied; null (no key) where the player
  /// chose nothing, so the project's settings stay the default.
  Map<String, Object?> framePacingSettingsMap() {
    final applied = LuminaGameFramePacing.settingsPatch();
    return {
      LuminaGameFramePacing.targetFpsKey: _stagedTargetFps ?? applied[LuminaGameFramePacing.targetFpsKey],
      LuminaGameFramePacing.vsyncKey: _stagedVsync ?? applied[LuminaGameFramePacing.vsyncKey],
    };
  }

  /// Stages the frame rate settings in [map] (a loaded settings file).
  void stageFramePacingFrom(Map<String, dynamic> map) {
    final fps = map[LuminaGameFramePacing.targetFpsKey];
    if (fps is num) setTargetFps(fps.round());
    final vsync = map[LuminaGameFramePacing.vsyncKey];
    if (vsync is bool) setVsyncEnabled(vsync);
  }
}
