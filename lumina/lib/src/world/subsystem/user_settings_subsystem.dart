import 'dart:convert';
import 'dart:io';

import 'package:flutter_filament/filament.dart';
import 'package:lumina_core/lumina_core.dart' show EngineLoggerService;

import 'package:lumina/src/components/camera/camera_component.dart';
import 'package:lumina/src/post_process/rendering_features.dart';
import 'package:lumina/src/post_process/scalability_profile.dart';
import 'package:lumina/src/post_process/shadow_settings.dart';
import 'package:lumina/src/save/save_game_subsystem.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/world/subsystem/world_subsystem.dart';

export 'package:lumina/src/world/subsystem/user_settings_rendering.dart';

/// World subsystem managing engine scalability settings, quality presets,
/// view distance, resolution scale, frame pacing, and graphics configuration,
/// plus ray tracing and upscaling ([LuminaUserSettingsRenderingFeatures]).
///
/// The scalability presets leave the ray tracing and upscaler choice alone:
/// those depend on the GPU and are opted into by the player, so picking
/// `Cinematic` never turns ray tracing on and picking `Low` never turns an
/// upscaler off.
class LuminaUserSettingsSubsystem extends LuminaWorldSubsystem with LuminaUserSettingsRenderingFeatures {
  /// Where [saveSettings] and [loadSettings] keep the settings by default:
  /// `GameUserSettings.json` in the save game directory.
  static String get defaultSettingsFilePath =>
      '${LuminaSaveGameSubsystem.defaultSaveDirectoryPath}/GameUserSettings.json';

  static const double viewDistanceLow = 25000.0; // 250 m
  static const double viewDistanceMedium = 50000.0; // 500 m
  static const double viewDistanceHigh = 100000.0; // 1,000 m (1 km)
  static const double viewDistanceEpic = 200000.0; // 2,000 m (2 km)
  static const double viewDistanceCinematic = 400000.0; // 4,000 m (4 km)

  static double viewDistanceForPreset(String preset) {
    switch (preset.toLowerCase()) {
      case 'low':
        return viewDistanceLow;
      case 'medium':
        return viewDistanceMedium;
      case 'high':
        return viewDistanceHigh;
      case 'cinematic':
        return viewDistanceCinematic;
      case 'epic':
      default:
        return viewDistanceEpic;
    }
  }

  String _overallScalabilityLevel = 'Epic';
  String _viewDistanceQuality = 'Epic';
  double _viewDistance = viewDistanceEpic;
  String _shadowQuality = 'High';
  String _antiAliasingQuality = 'FXAA';
  String _postProcessingQuality = 'Epic';
  String _textureQuality = 'High';
  String _shadingQuality = 'Epic';
  double _resolutionScale = 100.0;
  int _targetFps = 0;
  bool _vsyncEnabled = false;

  /// Current overall scalability preset name ('Low', 'Medium', 'High', 'Epic', 'Cinematic', or 'Custom').
  String get overallScalabilityLevel => _overallScalabilityLevel;

  /// Current view distance quality tier ('Low', 'Medium', 'High', 'Epic', 'Cinematic').
  String get viewDistanceQuality => _viewDistanceQuality;

  /// Current view distance in centimeters (governing camera far clip planes and cull distances).
  double get viewDistance => _viewDistance;

  /// Current shadow quality tier ('Low', 'Medium', 'High', 'Epic', 'Cinematic').
  String get shadowQuality => _shadowQuality;

  /// Current anti-aliasing mode ('None', 'FXAA', 'MSAA', 'TAA').
  String get antiAliasingQuality => _antiAliasingQuality;

  /// Current post-processing quality tier ('Low', 'Medium', 'High', 'Epic', 'Cinematic').
  String get postProcessingQuality => _postProcessingQuality;

  /// Current texture quality tier ('Low', 'Medium', 'High', 'Epic', 'Cinematic').
  String get textureQuality => _textureQuality;

  /// Current shading quality tier ('Low', 'Medium', 'High', 'Epic', 'Cinematic').
  String get shadingQuality => _shadingQuality;

  /// Internal render resolution percentage (25.0 % to 200.0 %, 100.0 % = native).
  double get resolutionScale => _resolutionScale;

  /// Target frame rate in FPS (0 = unlimited).
  int get targetFps => _targetFps;

  /// Whether vertical synchronization is enabled.
  bool get vsyncEnabled => _vsyncEnabled;

  @override
  void onWorldInitialize(LuminaWorld world) {
    super.onWorldInitialize(world);
    applySettings();
  }

  @override
  void onWorldBeginPlay() {
    super.onWorldBeginPlay();
    applySettings();
  }

  @override
  void onWorldTick(double deltaTime) {
    super.onWorldTick(deltaTime);
    tickRenderingFeatures();
  }

  @override
  void onWorldShutdown() {
    disposeRenderingFeatures();
    super.onWorldShutdown();
  }

  /// Every user setting as JSON (what [saveSettings] writes).
  Map<String, dynamic> toMap() => {
        'version': 1,
        'overall_scalability_level': _overallScalabilityLevel,
        'view_distance_quality': _viewDistanceQuality,
        'view_distance': _viewDistance,
        'shadow_quality': _shadowQuality,
        'anti_aliasing_quality': _antiAliasingQuality,
        'post_processing_quality': _postProcessingQuality,
        'texture_quality': _textureQuality,
        'shading_quality': _shadingQuality,
        'resolution_scale': _resolutionScale,
        'target_fps': _targetFps,
        'vsync': _vsyncEnabled,
        'rendering_features': renderingFeatures.toMap(),
      };

  /// Takes the settings in [map] (what [toMap] wrote; missing or mistyped
  /// keys keep their value) and applies them.
  void applyMap(Map<String, dynamic> map) {
    String str(String key, String current) => map[key] is String ? map[key] as String : current;
    double dbl(String key, double current) => map[key] is num ? (map[key] as num).toDouble() : current;
    _overallScalabilityLevel = str('overall_scalability_level', _overallScalabilityLevel);
    _viewDistanceQuality = str('view_distance_quality', _viewDistanceQuality);
    _viewDistance = dbl('view_distance', _viewDistance).clamp(100.0, 10000000.0);
    _shadowQuality = str('shadow_quality', _shadowQuality);
    _antiAliasingQuality = str('anti_aliasing_quality', _antiAliasingQuality);
    _postProcessingQuality = str('post_processing_quality', _postProcessingQuality);
    _textureQuality = str('texture_quality', _textureQuality);
    _shadingQuality = str('shading_quality', _shadingQuality);
    _resolutionScale = dbl('resolution_scale', _resolutionScale).clamp(25.0, 200.0);
    final fps = map['target_fps'];
    if (fps is int) setTargetFps(fps);
    if (map['vsync'] is bool) _vsyncEnabled = map['vsync'] as bool;
    final features = map['rendering_features'];
    if (features is Map) setRenderingFeatures(LuminaRenderingFeatureSettings.fromMap(Map<String, dynamic>.from(features)));
    applySettings();
  }

  /// Writes [toMap] to [path] (default [defaultSettingsFilePath]); false when
  /// the file cannot be written.
  Future<bool> saveSettings({String? path}) async {
    final file = File(path ?? defaultSettingsFilePath);
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(toMap()));
      return true;
    } catch (e) {
      EngineLoggerService().log('user settings not saved to ${file.path}: $e', level: 'warning', source: 'LuminaUserSettingsSubsystem');
      return false;
    }
  }

  /// Reads the settings [saveSettings] wrote and applies them; false, with
  /// nothing changed, when the file is missing or not a settings object.
  Future<bool> loadSettings({String? path}) async {
    final file = File(path ?? defaultSettingsFilePath);
    try {
      if (!await file.exists()) return false;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return false;
      applyMap(Map<String, dynamic>.from(decoded));
      return true;
    } catch (e) {
      EngineLoggerService().log('user settings not loaded from ${file.path}: $e', level: 'warning', source: 'LuminaUserSettingsSubsystem');
      return false;
    }
  }

  /// Sets overall scalability level and updates all constituent quality tiers.
  void setOverallScalabilityLevel(String preset) {
    _overallScalabilityLevel = preset;
    final p = preset.toLowerCase();
    switch (p) {
      case 'low':
        _viewDistanceQuality = 'Low';
        _viewDistance = viewDistanceLow;
        _shadowQuality = 'Low';
        _antiAliasingQuality = 'None';
        _postProcessingQuality = 'Low';
        _textureQuality = 'Low';
        _shadingQuality = 'Low';
        break;
      case 'medium':
        _viewDistanceQuality = 'Medium';
        _viewDistance = viewDistanceMedium;
        _shadowQuality = 'Medium';
        _antiAliasingQuality = 'FXAA';
        _postProcessingQuality = 'Medium';
        _textureQuality = 'Medium';
        _shadingQuality = 'Medium';
        break;
      case 'high':
        _viewDistanceQuality = 'High';
        _viewDistance = viewDistanceHigh;
        _shadowQuality = 'High';
        _antiAliasingQuality = 'FXAA';
        _postProcessingQuality = 'High';
        _textureQuality = 'High';
        _shadingQuality = 'High';
        break;
      case 'cinematic':
        _viewDistanceQuality = 'Cinematic';
        _viewDistance = viewDistanceCinematic;
        _shadowQuality = 'Cinematic';
        _antiAliasingQuality = 'TAA';
        _postProcessingQuality = 'Cinematic';
        _textureQuality = 'Cinematic';
        _shadingQuality = 'Cinematic';
        break;
      case 'epic':
      default:
        _viewDistanceQuality = 'Epic';
        _viewDistance = viewDistanceEpic;
        _shadowQuality = 'Epic';
        _antiAliasingQuality = 'TAA';
        _postProcessingQuality = 'Epic';
        _textureQuality = 'Epic';
        _shadingQuality = 'Epic';
        break;
    }
    applySettings();
  }

  /// Sets view distance quality tier and updates the view distance in cm accordingly.
  void setViewDistanceQuality(String quality) {
    _viewDistanceQuality = quality;
    _viewDistance = viewDistanceForPreset(quality);
    _syncCameras();
  }

  /// Directly sets the camera view distance in centimeters (clamped between 100 cm and 100,000,000 cm).
  void setViewDistance(double distanceCm) {
    _viewDistance = distanceCm.clamp(100.0, 10000000.0);
    _syncCameras();
  }

  /// Sets shadow quality tier ('Low', 'Medium', 'High', 'Epic', 'Cinematic').
  void setShadowQuality(String quality) {
    _shadowQuality = quality;
    _overallScalabilityLevel = 'Custom';
  }

  /// Sets anti-aliasing mode ('None', 'FXAA', 'MSAA', 'TAA').
  void setAntiAliasingQuality(String quality) {
    _antiAliasingQuality = quality;
    _overallScalabilityLevel = 'Custom';
  }

  /// Sets post-processing quality tier ('Low', 'Medium', 'High', 'Epic', 'Cinematic').
  void setPostProcessingQuality(String quality) {
    _postProcessingQuality = quality;
    _overallScalabilityLevel = 'Custom';
  }

  /// Sets texture quality tier ('Low', 'Medium', 'High', 'Epic', 'Cinematic').
  void setTextureQuality(String quality) {
    _textureQuality = quality;
    _overallScalabilityLevel = 'Custom';
  }

  /// Sets shading quality tier ('Low', 'Medium', 'High', 'Epic', 'Cinematic').
  void setShadingQuality(String quality) {
    _shadingQuality = quality;
    _overallScalabilityLevel = 'Custom';
  }

  /// Sets internal render resolution percentage (25.0 % to 200.0 %).
  void setResolutionScale(double percent) {
    _resolutionScale = percent.clamp(25.0, 200.0);
  }

  /// Sets target frame rate in frames per second (0 = unlimited).
  void setTargetFps(int fps) {
    _targetFps = fps < 0 ? 0 : fps;
  }

  /// Enables or disables vertical synchronization.
  void setVsyncEnabled(bool enabled) {
    _vsyncEnabled = enabled;
  }

  void _syncCameras() {
    final w = world;
    if (w == null) return;
    final active = w.activeCamera;
    if (active != null) {
      active.farClipPlane = _viewDistance;
      active.invalidateNativeSync();
    }
    for (final level in [w.persistentLevel, ...w.streamingLevels]) {
      for (final actor in level.actors) {
        for (final comp in actor.components) {
          if (comp is LuminaCameraComponent) {
            comp.farClipPlane = _viewDistance;
            comp.invalidateNativeSync();
          }
        }
      }
    }
  }

  /// Commits and applies all scalability and view distance settings to the active world.
  void applySettings() {
    _syncCameras();

    LuminaShadowSettings shadowSettings;
    switch (_shadowQuality.toLowerCase()) {
      case 'low':
        shadowSettings = LuminaShadowSettings(
          shadowType: ShadowType.pcf,
          mapSize: 512,
          cascades: 1,
          screenSpaceContactShadows: false,
          stable: false,
        );
        break;
      case 'medium':
        shadowSettings = LuminaShadowSettings(
          shadowType: ShadowType.pcf,
          mapSize: 1024,
          cascades: 2,
          splitMode: CsmSplitMode.practical,
          practicalLambda: 0.5,
          screenSpaceContactShadows: false,
          stable: false,
        );
        break;
      case 'high':
        shadowSettings = LuminaShadowSettings(
          shadowType: ShadowType.vsm,
          vsm: const VsmShadowOptions(anisotropy: 2, mipmapping: true),
          mapSize: 2048,
          cascades: 3,
          splitMode: CsmSplitMode.practical,
          practicalLambda: 0.5,
          stable: true,
        );
        break;
      case 'cinematic':
        shadowSettings = LuminaShadowSettings(
          shadowType: ShadowType.pcss,
          mapSize: 4096,
          cascades: 4,
          splitMode: CsmSplitMode.practical,
          practicalLambda: 0.4,
          screenSpaceContactShadows: true,
          contactShadowsStepCount: 16,
          stable: true,
        );
        break;
      case 'epic':
      default:
        shadowSettings = LuminaShadowSettings(
          shadowType: ShadowType.pcss,
          mapSize: 4096,
          cascades: 4,
          splitMode: CsmSplitMode.practical,
          practicalLambda: 0.5,
          screenSpaceContactShadows: true,
          contactShadowsStepCount: 8,
          stable: true,
        );
        break;
    }

    RenderQuality renderQuality;
    switch (_postProcessingQuality.toLowerCase()) {
      case 'low':
        renderQuality = const RenderQuality(hdrColorBuffer: QualityLevel.low);
        break;
      case 'medium':
        renderQuality = const RenderQuality(hdrColorBuffer: QualityLevel.medium);
        break;
      case 'high':
        renderQuality = const RenderQuality(hdrColorBuffer: QualityLevel.high);
        break;
      case 'cinematic':
      case 'epic':
      default:
        renderQuality = const RenderQuality(hdrColorBuffer: QualityLevel.ultra);
        break;
    }

    AntiAliasing antiAliasing = AntiAliasing.none;
    TemporalAntiAliasingOptions taa = const TemporalAntiAliasingOptions(enabled: false);
    MultiSampleAntiAliasingOptions msaa = const MultiSampleAntiAliasingOptions(enabled: false);

    switch (_antiAliasingQuality.toLowerCase()) {
      case 'fxaa':
        antiAliasing = AntiAliasing.fxaa;
        break;
      case 'msaa':
        msaa = const MultiSampleAntiAliasingOptions(enabled: true, sampleCount: 4);
        break;
      case 'taa':
        taa = const TemporalAntiAliasingOptions(enabled: true);
        break;
      case 'none':
      default:
        break;
    }

    DynamicResolutionOptions dynamicResolution;
    switch (_shadingQuality.toLowerCase()) {
      case 'low':
        dynamicResolution = const DynamicResolutionOptions(
          enabled: true,
          minScaleX: 0.5,
          minScaleY: 0.5,
        );
        break;
      case 'medium':
        dynamicResolution = const DynamicResolutionOptions(
          enabled: true,
          minScaleX: 0.75,
          minScaleY: 0.75,
        );
        break;
      default:
        dynamicResolution = const DynamicResolutionOptions(enabled: false);
        break;
    }

    // Ray-traced sun shadows ride on the shadow settings too, so a sun
    // component re-applying its options keeps them.
    if (rayTracedSunShadowsWanted) shadowSettings = shadowSettings.copyWith(rayTraced: true);

    var profile = LuminaScalabilityProfile(
      shadows: shadowSettings,
      renderQuality: renderQuality,
      dynamicResolution: dynamicResolution,
      taa: taa,
      msaa: msaa,
      antiAliasing: antiAliasing,
    );

    if (_resolutionScale != 100.0) {
      profile = profile.withResolutionScale(_resolutionScale);
    }

    final w = world;
    if (w != null) {
      try {
        w.applyScalability(profile);
      } catch (_) {
        // In headless tests without native assets, applyScalability is safely caught.
      }
    }
    // After the profile: the upscalers replace its TAA and dynamic resolution.
    applyRenderingFeatures(baseTaa: profile.taa, baseDynamicResolution: profile.dynamicResolution);
  }
}
