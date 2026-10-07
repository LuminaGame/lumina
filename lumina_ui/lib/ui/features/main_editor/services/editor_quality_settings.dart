import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_filament/flutter_filament.dart' show FilamentView;
import 'package:lumina_editor_data/lumina_editor.dart';

/// How the **editor viewport** renders — the editor's scalability, which is a
/// per-user preference rather than a project property.
///
/// The project's own shipped quality lives in the `.lmproject` manifest and is
/// edited in Project Settings; this only governs what the user looks at while
/// editing, so it is stored per user, keyed by project directory, and is never
/// written into the project.
///
/// Every field maps onto something Filament really does: the preset expands to
/// a [LuminaScalabilityProfile] (shadow type/size/cascades, HDR buffer quality,
/// TAA, MSAA, FXAA), the resolution scale pins Filament's dynamic-resolution
/// scaler, and the three feature flags switch real post-process passes.
class EditorQualitySettings {
  /// One of `kQualityPresets` (`Low`, `Medium`, `High`, `Epic`, `Cinematic`).
  /// Lower-case, matching `ProjectScalabilitySettings.qualityPreset` in the
  /// manifest. The UI capitalises for display; nothing compares display text.
  final String preset;

  /// Internal render resolution, as a percentage of the view. 100 means native.
  final double resolutionScale;

  /// Screen-space ambient occlusion.
  final bool ssao;

  /// Bloom.
  final bool bloom;

  /// Screen-space reflections.
  final bool screenSpaceReflections;

  /// Hardware ray tracing of the viewport: acceleration structures, ray-traced
  /// sun shadows and ReSTIR direct lighting (the RTX HUD button).
  final LuminaRayTracingSettings rayTracing;

  /// DLSS Super Resolution of the viewport (the DLSS HUD button).
  final LuminaDlssSettings dlss;

  /// FSR3 upscaling and frame generation of the viewport (the FSR3 HUD button).
  final LuminaFsr3Settings fsr3;

  const EditorQualitySettings({
    this.preset = 'epic',
    this.resolutionScale = 100,
    this.ssao = true,
    this.bloom = true,
    this.screenSpaceReflections = true,
    this.rayTracing = const LuminaRayTracingSettings(),
    this.dlss = const LuminaDlssSettings(),
    this.fsr3 = const LuminaFsr3Settings(),
  });

  /// The engine profile this preset and resolution scale describe.
  LuminaScalabilityProfile get profile =>
      LuminaScalabilityProfile.forPreset(preset).withResolutionScale(resolutionScale);

  /// [base] with this settings object's feature flags applied. Used for the
  /// post-process passes, which live on the settings rather than the profile.
  LuminaPostProcessSettings applyFeatures(LuminaPostProcessSettings base) {
    return base.copyWith(
      ambientOcclusion: base.ambientOcclusion.copyWith(enabled: ssao),
      bloom: base.bloom.copyWith(enabled: bloom),
      screenSpaceReflections: base.screenSpaceReflections.copyWith(enabled: screenSpaceReflections),
    );
  }

  /// Writes everything that lives on the view itself: the profile's
  /// anti-aliasing / render quality / dynamic resolution, plus the three
  /// feature passes. Shadows are not written here — they belong to the scene's
  /// directional light and go through the world.
  void applyToView(FilamentView view, {LuminaPostProcessSettings? base}) {
    try {
      profile.applyToView(view);
      final pp = applyFeatures(base ?? LuminaPostProcessSettings.standard());
      view.ambientOcclusionOptions = pp.ambientOcclusion;
      view.bloomOptions = pp.bloom;
      view.screenSpaceReflectionsOptions = pp.screenSpaceReflections;
    } catch (e) {
      debugPrint('[EditorQualitySettings] applyToView failed: $e');
    }
  }

  EditorQualitySettings copyWith({
    String? preset,
    double? resolutionScale,
    bool? ssao,
    bool? bloom,
    bool? screenSpaceReflections,
    LuminaRayTracingSettings? rayTracing,
    LuminaDlssSettings? dlss,
    LuminaFsr3Settings? fsr3,
  }) {
    return EditorQualitySettings(
      preset: (preset ?? this.preset).toLowerCase(),
      resolutionScale: resolutionScale ?? this.resolutionScale,
      ssao: ssao ?? this.ssao,
      bloom: bloom ?? this.bloom,
      screenSpaceReflections: screenSpaceReflections ?? this.screenSpaceReflections,
      rayTracing: rayTracing ?? this.rayTracing,
      dlss: dlss ?? this.dlss,
      fsr3: fsr3 ?? this.fsr3,
    );
  }

  Map<String, dynamic> toMap() => {
        'preset': preset.toLowerCase(),
        'resolution_scale': resolutionScale,
        'ssao': ssao,
        'bloom': bloom,
        'screen_space_reflections': screenSpaceReflections,
        'ray_tracing': rayTracing.toMap(),
        'dlss': dlss.toMap(),
        'fsr3': fsr3.toMap(),
      };

  factory EditorQualitySettings.fromMap(Map<String, dynamic> map) {
    final scale = map['resolution_scale'];
    final rayTracing = map['ray_tracing'];
    final dlss = map['dlss'];
    final fsr3 = map['fsr3'];
    return EditorQualitySettings(
      preset: (map['preset'] as String? ?? 'epic').toLowerCase(),
      resolutionScale: scale is num ? scale.toDouble() : 100,
      ssao: map['ssao'] as bool? ?? true,
      bloom: map['bloom'] as bool? ?? true,
      screenSpaceReflections: map['screen_space_reflections'] as bool? ?? true,
      rayTracing: rayTracing is Map ? LuminaRayTracingSettings.fromMap(Map<String, dynamic>.from(rayTracing)) : const LuminaRayTracingSettings(),
      dlss: dlss is Map ? LuminaDlssSettings.fromMap(Map<String, dynamic>.from(dlss)) : const LuminaDlssSettings(),
      fsr3: fsr3 is Map ? LuminaFsr3Settings.fromMap(Map<String, dynamic>.from(fsr3)) : const LuminaFsr3Settings(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EditorQualitySettings &&
      other.preset == preset &&
      other.resolutionScale == resolutionScale &&
      other.ssao == ssao &&
      other.bloom == bloom &&
      other.screenSpaceReflections == screenSpaceReflections &&
      other.rayTracing == rayTracing &&
      other.dlss == dlss &&
      other.fsr3 == fsr3;

  @override
  int get hashCode => Object.hash(preset, resolutionScale, ssao, bloom, screenSpaceReflections, rayTracing, dlss, fsr3);

  @override
  String toString() =>
      'EditorQualitySettings($preset, ${resolutionScale.toStringAsFixed(0)}%, ssao: $ssao, bloom: $bloom, ssr: $screenSpaceReflections, '
      'rtx: ${rayTracing.enabled}, dlss: ${dlss.enabled}, fsr3: ${fsr3.enabled})';
}

/// Per-user store for [EditorQualitySettings], one entry per project
/// directory, in `editor_quality.json` of the editor's config directory
/// ([LuminaConfigDir], `~/.config/lumina`) — the same place the launcher keeps
/// its recent-project list and the plugin wizard its defaults.
class EditorQualityStore {
  final Directory configDir;

  EditorQualityStore({Directory? configDir}) : configDir = LuminaConfigDir.resolve(explicit: configDir);

  File get file => File('${configDir.path}/editor_quality.json');

  /// Shared with every other editor process: atomic writes, locked updates.
  ConfigJsonFile get _json => ConfigJsonFile(file);

  Future<Map<String, dynamic>> _readAll() async {
    try {
      final decoded = _json.read();
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (e) {
      debugPrint('[EditorQualityStore] unreadable, using the defaults: $e');
      return {};
    }
  }

  /// The settings saved for [projectDirPath], or the defaults.
  Future<EditorQualitySettings> load(String projectDirPath) async {
    final all = await _readAll();
    final entry = all[projectDirPath];
    if (entry is Map) return EditorQualitySettings.fromMap(Map<String, dynamic>.from(entry));
    return const EditorQualitySettings();
  }

  Future<void> save(String projectDirPath, EditorQualitySettings settings) async {
    try {
      _json.update(
        (current) => {...?(current as Map<String, dynamic>?), projectDirPath: settings.toMap()},
        isValid: (value) => value is Map<String, dynamic>,
        pretty: true,
        onUnreadable: (keptAside, error) =>
            debugPrint('[EditorQualityStore] ${file.path} is not readable ($error); kept it as ${keptAside.path}'),
      );
    } catch (e) {
      debugPrint('[EditorQualityStore] save failed: $e');
    }
  }
}
