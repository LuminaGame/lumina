import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';

/// Immutable configuration for the Filament color grading pipeline and tone mapping.
class LuminaColorGradeSettings {
  final ToneMapperType toneMapper;
  final AgxLook agxLook;
  final double genericContrast;
  final double genericMidGrayIn;
  final double genericMidGrayOut;
  final double genericHdrMax;
  final ColorGradingQuality quality;
  final LutFormat format;
  final int lutDimensions;
  final double exposure;
  final double nightAdaptation;
  final (double temperature, double tint) whiteBalance;
  final (Vector3 outRed, Vector3 outGreen, Vector3 outBlue)? channelMixer;
  final (Vector4 shadows, Vector4 midtones, Vector4 highlights, Vector4 ranges)? shadowsMidtonesHighlights;
  final (Vector3 slope, Vector3 offset, Vector3 power)? slopeOffsetPower;
  final double contrast;
  final double vibrance;
  final double saturation;
  final (Vector3 shadowGamma, Vector3 midPoint, Vector3 highlightScale)? curves;
  final bool luminanceScaling;
  final bool gamutMapping;

  const LuminaColorGradeSettings._({
    this.toneMapper = ToneMapperType.acesLegacy,
    this.agxLook = AgxLook.none,
    this.genericContrast = 1.55,
    this.genericMidGrayIn = 0.18,
    this.genericMidGrayOut = 0.215,
    this.genericHdrMax = 10.0,
    this.quality = ColorGradingQuality.medium,
    this.format = LutFormat.integer,
    this.lutDimensions = 32,
    this.exposure = 0.0,
    this.nightAdaptation = 0.0,
    this.whiteBalance = (0.0, 0.0),
    this.channelMixer,
    this.shadowsMidtonesHighlights,
    this.slopeOffsetPower,
    this.contrast = 1.0,
    this.vibrance = 1.0,
    this.saturation = 1.0,
    this.curves,
    this.luminanceScaling = false,
    this.gamutMapping = false,
  });

  const LuminaColorGradeSettings.defaults() : this._();

  factory LuminaColorGradeSettings({
    ToneMapperType toneMapper = ToneMapperType.acesLegacy,
    AgxLook agxLook = AgxLook.none,
    double genericContrast = 1.55,
    double genericMidGrayIn = 0.18,
    double genericMidGrayOut = 0.215,
    double genericHdrMax = 10.0,
    ColorGradingQuality quality = ColorGradingQuality.medium,
    LutFormat format = LutFormat.integer,
    int lutDimensions = 32,
    double exposure = 0.0,
    double nightAdaptation = 0.0,
    (double, double) whiteBalance = (0.0, 0.0),
    (Vector3, Vector3, Vector3)? channelMixer,
    (Vector4, Vector4, Vector4, Vector4)? shadowsMidtonesHighlights,
    (Vector3, Vector3, Vector3)? slopeOffsetPower,
    double contrast = 1.0,
    double vibrance = 1.0,
    double saturation = 1.0,
    (Vector3, Vector3, Vector3)? curves,
    bool luminanceScaling = false,
    bool gamutMapping = false,
  }) {
    if (lutDimensions < 16 || lutDimensions > 64) {
      throw ArgumentError.value(
        lutDimensions,
        'lutDimensions',
        'LUT dimensions must be between 16 and 64',
      );
    }
    if (whiteBalance.$1 < -1.0 ||
        whiteBalance.$1 > 1.0 ||
        whiteBalance.$2 < -1.0 ||
        whiteBalance.$2 > 1.0) {
      throw ArgumentError.value(
        whiteBalance,
        'whiteBalance',
        'White balance temperature and tint must be in [-1.0, 1.0]',
      );
    }

    return LuminaColorGradeSettings._(
      toneMapper: toneMapper,
      agxLook: agxLook,
      genericContrast: genericContrast,
      genericMidGrayIn: genericMidGrayIn,
      genericMidGrayOut: genericMidGrayOut,
      genericHdrMax: genericHdrMax,
      quality: quality,
      format: format,
      lutDimensions: lutDimensions,
      exposure: exposure,
      nightAdaptation: nightAdaptation,
      whiteBalance: whiteBalance,
      channelMixer: channelMixer,
      shadowsMidtonesHighlights: shadowsMidtonesHighlights,
      slopeOffsetPower: slopeOffsetPower,
      contrast: contrast,
      vibrance: vibrance,
      saturation: saturation,
      curves: curves,
      luminanceScaling: luminanceScaling,
      gamutMapping: gamutMapping,
    );
  }

  LuminaColorGradeSettings copyWith({
    ToneMapperType? toneMapper,
    AgxLook? agxLook,
    double? genericContrast,
    double? genericMidGrayIn,
    double? genericMidGrayOut,
    double? genericHdrMax,
    ColorGradingQuality? quality,
    LutFormat? format,
    int? lutDimensions,
    double? exposure,
    double? nightAdaptation,
    (double, double)? whiteBalance,
    (Vector3, Vector3, Vector3)? channelMixer,
    (Vector4, Vector4, Vector4, Vector4)? shadowsMidtonesHighlights,
    (Vector3, Vector3, Vector3)? slopeOffsetPower,
    double? contrast,
    double? vibrance,
    double? saturation,
    (Vector3, Vector3, Vector3)? curves,
    bool? luminanceScaling,
    bool? gamutMapping,
  }) {
    final newLutDimensions = lutDimensions ?? this.lutDimensions;
    final newWhiteBalance = whiteBalance ?? this.whiteBalance;
    if (newLutDimensions < 16 || newLutDimensions > 64) {
      throw ArgumentError.value(
        newLutDimensions,
        'lutDimensions',
        'LUT dimensions must be between 16 and 64',
      );
    }
    if (newWhiteBalance.$1 < -1.0 ||
        newWhiteBalance.$1 > 1.0 ||
        newWhiteBalance.$2 < -1.0 ||
        newWhiteBalance.$2 > 1.0) {
      throw ArgumentError.value(
        newWhiteBalance,
        'whiteBalance',
        'White balance temperature and tint must be in [-1.0, 1.0]',
      );
    }

    return LuminaColorGradeSettings._(
      toneMapper: toneMapper ?? this.toneMapper,
      agxLook: agxLook ?? this.agxLook,
      genericContrast: genericContrast ?? this.genericContrast,
      genericMidGrayIn: genericMidGrayIn ?? this.genericMidGrayIn,
      genericMidGrayOut: genericMidGrayOut ?? this.genericMidGrayOut,
      genericHdrMax: genericHdrMax ?? this.genericHdrMax,
      quality: quality ?? this.quality,
      format: format ?? this.format,
      lutDimensions: newLutDimensions,
      exposure: exposure ?? this.exposure,
      nightAdaptation: nightAdaptation ?? this.nightAdaptation,
      whiteBalance: newWhiteBalance,
      channelMixer: channelMixer ?? this.channelMixer,
      shadowsMidtonesHighlights: shadowsMidtonesHighlights ?? this.shadowsMidtonesHighlights,
      slopeOffsetPower: slopeOffsetPower ?? this.slopeOffsetPower,
      contrast: contrast ?? this.contrast,
      vibrance: vibrance ?? this.vibrance,
      saturation: saturation ?? this.saturation,
      curves: curves ?? this.curves,
      luminanceScaling: luminanceScaling ?? this.luminanceScaling,
      gamutMapping: gamutMapping ?? this.gamutMapping,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LuminaColorGradeSettings &&
          runtimeType == other.runtimeType &&
          toneMapper == other.toneMapper &&
          agxLook == other.agxLook &&
          genericContrast == other.genericContrast &&
          genericMidGrayIn == other.genericMidGrayIn &&
          genericMidGrayOut == other.genericMidGrayOut &&
          genericHdrMax == other.genericHdrMax &&
          quality == other.quality &&
          format == other.format &&
          lutDimensions == other.lutDimensions &&
          exposure == other.exposure &&
          nightAdaptation == other.nightAdaptation &&
          whiteBalance == other.whiteBalance &&
          channelMixer == other.channelMixer &&
          shadowsMidtonesHighlights == other.shadowsMidtonesHighlights &&
          slopeOffsetPower == other.slopeOffsetPower &&
          contrast == other.contrast &&
          vibrance == other.vibrance &&
          saturation == other.saturation &&
          curves == other.curves &&
          luminanceScaling == other.luminanceScaling &&
          gamutMapping == other.gamutMapping;

  @override
  int get hashCode => Object.hashAll([
        toneMapper,
        agxLook,
        genericContrast,
        genericMidGrayIn,
        genericMidGrayOut,
        genericHdrMax,
        quality,
        format,
        lutDimensions,
        exposure,
        nightAdaptation,
        whiteBalance,
        channelMixer,
        shadowsMidtonesHighlights,
        slopeOffsetPower,
        contrast,
        vibrance,
        saturation,
        curves,
        luminanceScaling,
        gamutMapping,
      ]);
}

/// Immutable value object holding the entire per-view post-process pipeline configuration.
class LuminaPostProcessSettings {
  final BloomOptions bloom;
  final DepthOfFieldOptions depthOfField;
  final VignetteOptions vignette;
  final FogOptions fog;
  final AmbientOcclusionOptions ambientOcclusion;
  final TemporalAntiAliasingOptions taa;
  final MultiSampleAntiAliasingOptions msaa;
  final ScreenSpaceReflectionsOptions screenSpaceReflections;
  final GuardBandOptions guardBand;
  final DynamicResolutionOptions dynamicResolution;
  final RenderQuality renderQuality;
  final Dithering dithering;
  final AntiAliasing antiAliasing;
  final bool postProcessingEnabled;
  final LuminaColorGradeSettings colorGrade;

  const LuminaPostProcessSettings({
    this.bloom = const BloomOptions(),
    this.depthOfField = const DepthOfFieldOptions(),
    this.vignette = const VignetteOptions(),
    this.fog = defaultFog,
    this.ambientOcclusion = defaultAmbientOcclusion,
    this.taa = const TemporalAntiAliasingOptions(),
    this.msaa = const MultiSampleAntiAliasingOptions(),
    this.screenSpaceReflections = defaultScreenSpaceReflections,
    this.guardBand = const GuardBandOptions(),
    this.dynamicResolution = const DynamicResolutionOptions(),
    this.renderQuality = const RenderQuality(),
    this.dithering = Dithering.temporal,
    this.antiAliasing = AntiAliasing.fxaa,
    this.postProcessingEnabled = true,
    this.colorGrade = const LuminaColorGradeSettings.defaults(),
  });

  // Filament's defaults are metres; these are the same effects in a
  // centimetre world: distances ×100, per-distance rates ÷100.
  static const FogOptions defaultFog = FogOptions(heightFalloff: 0.01, density: 0.001);
  static const AmbientOcclusionOptions defaultAmbientOcclusion = AmbientOcclusionOptions(
    radius: 30.0,
    bias: 0.05,
    bilateralThreshold: 5.0,
    ssctShadowDistance: 30.0,
    ssctContactDistanceMax: 100.0,
    ssctDepthBias: 1.0,
    ssctDepthSlopeBias: 1.0,
    gtaoConstThickness: 50.0,
  );
  static const ScreenSpaceReflectionsOptions defaultScreenSpaceReflections =
      ScreenSpaceReflectionsOptions(thickness: 10.0, bias: 1.0, maxDistance: 300.0);

  /// Factory for standard default settings matching Filament baseline with ACES Legacy.
  factory LuminaPostProcessSettings.standard() {
    return const LuminaPostProcessSettings();
  }

  /// Factory for minimal settings with post processing disabled and linear tone mapper.
  factory LuminaPostProcessSettings.none() {
    return const LuminaPostProcessSettings(
      postProcessingEnabled: false,
      antiAliasing: AntiAliasing.none,
      dithering: Dithering.none,
      bloom: BloomOptions(enabled: false),
      fog: FogOptions(enabled: false),
      depthOfField: DepthOfFieldOptions(enabled: false),
      vignette: VignetteOptions(enabled: false),
      ambientOcclusion: AmbientOcclusionOptions(enabled: false),
      taa: TemporalAntiAliasingOptions(enabled: false),
      msaa: MultiSampleAntiAliasingOptions(enabled: false),
      screenSpaceReflections: ScreenSpaceReflectionsOptions(enabled: false),
      guardBand: GuardBandOptions(enabled: false),
      dynamicResolution: DynamicResolutionOptions(enabled: false),
      colorGrade: LuminaColorGradeSettings._(
        toneMapper: ToneMapperType.linear,
      ),
    );
  }

  LuminaPostProcessSettings copyWith({
    BloomOptions? bloom,
    DepthOfFieldOptions? depthOfField,
    VignetteOptions? vignette,
    FogOptions? fog,
    AmbientOcclusionOptions? ambientOcclusion,
    TemporalAntiAliasingOptions? taa,
    MultiSampleAntiAliasingOptions? msaa,
    ScreenSpaceReflectionsOptions? screenSpaceReflections,
    GuardBandOptions? guardBand,
    DynamicResolutionOptions? dynamicResolution,
    RenderQuality? renderQuality,
    Dithering? dithering,
    AntiAliasing? antiAliasing,
    bool? postProcessingEnabled,
    LuminaColorGradeSettings? colorGrade,
  }) {
    return LuminaPostProcessSettings(
      bloom: bloom ?? this.bloom,
      depthOfField: depthOfField ?? this.depthOfField,
      vignette: vignette ?? this.vignette,
      fog: fog ?? this.fog,
      ambientOcclusion: ambientOcclusion ?? this.ambientOcclusion,
      taa: taa ?? this.taa,
      msaa: msaa ?? this.msaa,
      screenSpaceReflections: screenSpaceReflections ?? this.screenSpaceReflections,
      guardBand: guardBand ?? this.guardBand,
      dynamicResolution: dynamicResolution ?? this.dynamicResolution,
      renderQuality: renderQuality ?? this.renderQuality,
      dithering: dithering ?? this.dithering,
      antiAliasing: antiAliasing ?? this.antiAliasing,
      postProcessingEnabled: postProcessingEnabled ?? this.postProcessingEnabled,
      colorGrade: colorGrade ?? this.colorGrade,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LuminaPostProcessSettings &&
          runtimeType == other.runtimeType &&
          bloom == other.bloom &&
          depthOfField == other.depthOfField &&
          vignette == other.vignette &&
          fog == other.fog &&
          ambientOcclusion == other.ambientOcclusion &&
          taa == other.taa &&
          msaa == other.msaa &&
          screenSpaceReflections == other.screenSpaceReflections &&
          guardBand == other.guardBand &&
          dynamicResolution == other.dynamicResolution &&
          renderQuality == other.renderQuality &&
          dithering == other.dithering &&
          antiAliasing == other.antiAliasing &&
          postProcessingEnabled == other.postProcessingEnabled &&
          colorGrade == other.colorGrade;

  @override
  int get hashCode => Object.hashAll([
        bloom,
        depthOfField,
        vignette,
        fog,
        ambientOcclusion,
        taa,
        msaa,
        screenSpaceReflections,
        guardBand,
        dynamicResolution,
        renderQuality,
        dithering,
        antiAliasing,
        postProcessingEnabled,
        colorGrade,
      ]);
}
