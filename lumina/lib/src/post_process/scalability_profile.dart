import 'package:flutter_filament/filament.dart';
import 'package:lumina/src/post_process/shadow_settings.dart';

/// Bundled engine scalability profile governing shadows, quality buffers, and anti-aliasing.
class LuminaScalabilityProfile {
  final LuminaShadowSettings shadows;
  final RenderQuality renderQuality;
  final DynamicResolutionOptions dynamicResolution;
  final TemporalAntiAliasingOptions taa;
  final MultiSampleAntiAliasingOptions msaa;
  final AntiAliasing antiAliasing;

  const LuminaScalabilityProfile({
    this.shadows = const LuminaShadowSettings.defaults(),
    this.renderQuality = const RenderQuality(),
    this.dynamicResolution = const DynamicResolutionOptions(),
    this.taa = const TemporalAntiAliasingOptions(),
    this.msaa = const MultiSampleAntiAliasingOptions(),
    this.antiAliasing = AntiAliasing.fxaa,
  });

  /// Low quality profile: PCF shadows (512, 1 cascade), dynamic resolution enabled, FXAA.
  static final LuminaScalabilityProfile low = LuminaScalabilityProfile(
    shadows: LuminaShadowSettings(
      shadowType: ShadowType.pcf,
      mapSize: 512,
      cascades: 1,
      screenSpaceContactShadows: false,
      stable: false,
    ),
    renderQuality: const RenderQuality(hdrColorBuffer: QualityLevel.low),
    dynamicResolution: const DynamicResolutionOptions(
      enabled: true,
      minScaleX: 0.5,
      minScaleY: 0.5,
    ),
    taa: const TemporalAntiAliasingOptions(enabled: false),
    msaa: const MultiSampleAntiAliasingOptions(enabled: false),
    antiAliasing: AntiAliasing.fxaa,
  );

  /// Medium quality profile: PCF shadows (1024, 2 cascades), dynamic resolution enabled, FXAA.
  static final LuminaScalabilityProfile medium = LuminaScalabilityProfile(
    shadows: LuminaShadowSettings(
      shadowType: ShadowType.pcf,
      mapSize: 1024,
      cascades: 2,
      splitMode: CsmSplitMode.practical,
      practicalLambda: 0.5,
      screenSpaceContactShadows: false,
      stable: false,
    ),
    renderQuality: const RenderQuality(hdrColorBuffer: QualityLevel.medium),
    dynamicResolution: const DynamicResolutionOptions(
      enabled: true,
      minScaleX: 0.75,
      minScaleY: 0.75,
    ),
    taa: const TemporalAntiAliasingOptions(enabled: false),
    msaa: const MultiSampleAntiAliasingOptions(enabled: false),
    antiAliasing: AntiAliasing.fxaa,
  );

  /// High quality profile: VSM shadows (2048, 3 cascades), full HDR buffer, TAA enabled.
  static final LuminaScalabilityProfile high = LuminaScalabilityProfile(
    shadows: LuminaShadowSettings(
      shadowType: ShadowType.vsm,
      vsm: const VsmShadowOptions(anisotropy: 2, mipmapping: true),
      mapSize: 2048,
      cascades: 3,
      splitMode: CsmSplitMode.practical,
      practicalLambda: 0.5,
      stable: true,
    ),
    renderQuality: const RenderQuality(hdrColorBuffer: QualityLevel.high),
    dynamicResolution: const DynamicResolutionOptions(enabled: false),
    taa: const TemporalAntiAliasingOptions(enabled: true),
    msaa: const MultiSampleAntiAliasingOptions(enabled: false),
    antiAliasing: AntiAliasing.none,
  );

  /// Epic quality profile: PCSS shadows (4096, 4 cascades, contact shadows), ultra HDR buffer, TAA enabled.
  static final LuminaScalabilityProfile epic = LuminaScalabilityProfile(
    shadows: LuminaShadowSettings(
      shadowType: ShadowType.pcss,
      mapSize: 4096,
      cascades: 4,
      splitMode: CsmSplitMode.practical,
      practicalLambda: 0.5,
      screenSpaceContactShadows: true,
      contactShadowsStepCount: 8,
      stable: true,
    ),
    renderQuality: const RenderQuality(hdrColorBuffer: QualityLevel.ultra),
    dynamicResolution: const DynamicResolutionOptions(enabled: false),
    taa: const TemporalAntiAliasingOptions(enabled: true),
    msaa: const MultiSampleAntiAliasingOptions(enabled: false),
    antiAliasing: AntiAliasing.none,
  );

  /// Cinematic quality: everything Epic pays for, plus MSAA on top of TAA and
  /// the largest stable shadow cascade set. Meant for capture, not for play.
  static final LuminaScalabilityProfile cinematic = LuminaScalabilityProfile(
    shadows: LuminaShadowSettings(
      shadowType: ShadowType.pcss,
      mapSize: 4096,
      cascades: 4,
      splitMode: CsmSplitMode.practical,
      practicalLambda: 0.4,
      screenSpaceContactShadows: true,
      contactShadowsStepCount: 16,
      stable: true,
    ),
    renderQuality: const RenderQuality(hdrColorBuffer: QualityLevel.ultra),
    dynamicResolution: const DynamicResolutionOptions(enabled: false),
    taa: const TemporalAntiAliasingOptions(enabled: true),
    msaa: const MultiSampleAntiAliasingOptions(enabled: true, sampleCount: 4),
    antiAliasing: AntiAliasing.none,
  );

  /// The profile behind a preset name as the editor and the project manifest
  /// spell it (`Low`, `Medium`, `High`, `Epic`, `Cinematic`); anything
  /// unrecognised falls back to [epic], which is the manifest default.
  static LuminaScalabilityProfile forPreset(String preset) {
    switch (preset.toLowerCase()) {
      case 'low':
        return low;
      case 'medium':
        return medium;
      case 'high':
        return high;
      case 'cinematic':
        return cinematic;
      case 'epic':
      default:
        return epic;
    }
  }

  /// This profile rendered at [percent] of the view's resolution.
  ///
  /// 100 % returns the profile unchanged. Anything else pins Filament's
  /// dynamic-resolution scaler to that fixed factor — it is the only knob that
  /// changes the internal render resolution without resizing the surface. The
  /// value is clamped to 25–200 %.
  LuminaScalabilityProfile withResolutionScale(double percent) {
    if (percent == 100) return this;
    final scale = (percent / 100.0).clamp(0.25, 2.0);
    return copyWith(
      dynamicResolution: DynamicResolutionOptions(
        enabled: true,
        homogeneousScaling: dynamicResolution.homogeneousScaling,
        minScaleX: scale,
        minScaleY: scale,
        maxScaleX: scale,
        maxScaleY: scale,
        quality: dynamicResolution.quality,
        sharpness: dynamicResolution.sharpness,
      ),
    );
  }

  /// Writes the view-level half of this profile into [view].
  ///
  /// Shadows are deliberately not written here: they live on the scene's
  /// directional light, so they go through `LuminaWorld.applyScalability` /
  /// `LuminaPostProcessController.applyShadowSettings`, which have the light
  /// and the camera clip planes to work with.
  void applyToView(FilamentView view) {
    view.antiAliasing = antiAliasing.toNative();
    view.multiSampleAntiAliasingOptions = msaa;
    view.temporalAntiAliasingOptions = taa;
    view.dynamicResolutionOptions = dynamicResolution;
    view.renderQuality = renderQuality;
  }

  LuminaScalabilityProfile copyWith({
    LuminaShadowSettings? shadows,
    RenderQuality? renderQuality,
    DynamicResolutionOptions? dynamicResolution,
    TemporalAntiAliasingOptions? taa,
    MultiSampleAntiAliasingOptions? msaa,
    AntiAliasing? antiAliasing,
  }) {
    return LuminaScalabilityProfile(
      shadows: shadows ?? this.shadows,
      renderQuality: renderQuality ?? this.renderQuality,
      dynamicResolution: dynamicResolution ?? this.dynamicResolution,
      taa: taa ?? this.taa,
      msaa: msaa ?? this.msaa,
      antiAliasing: antiAliasing ?? this.antiAliasing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LuminaScalabilityProfile &&
          runtimeType == other.runtimeType &&
          shadows == other.shadows &&
          renderQuality == other.renderQuality &&
          dynamicResolution == other.dynamicResolution &&
          taa == other.taa &&
          msaa == other.msaa &&
          antiAliasing == other.antiAliasing;

  @override
  int get hashCode => Object.hash(
        shadows,
        renderQuality,
        dynamicResolution,
        taa,
        msaa,
        antiAliasing,
      );
}
