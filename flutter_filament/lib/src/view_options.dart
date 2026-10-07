import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/filament_bindings.dart' as ffi_gen;

enum QualityLevel {
  low,
  medium,
  high,
  ultra;

  int toNative() => index;

  static QualityLevel fromNative(int val) => QualityLevel.values[val];
}

/// Which upscaler turns a dynamically scaled frame into the output.
enum Upscaler {
  /// Filament's own: bilinear, SGSR1 or FSR1 by [DynamicResolutionOptions.quality].
  builtin,

  /// An upscaler registered on the view from outside Filament ([Dlss]); falls
  /// back to FSR1 when none is registered or it declines the resolution.
  external;

  int toNative() => index;

  static Upscaler fromNative(int val) => Upscaler.values[val];
}

enum BlendMode {
  opaque,
  translucent;

  int toNative() => index;

  static BlendMode fromNative(int val) => BlendMode.values[val];
}

class DynamicResolutionOptions {
  final double minScaleX;
  final double minScaleY;
  final double maxScaleX;
  final double maxScaleY;
  final double sharpness;
  final bool enabled;
  final bool homogeneousScaling;
  final QualityLevel quality;

  /// Which upscaler reconstructs the output; [Upscaler.external] hands the
  /// frame to the view's external upscaler (DLSS). Default [Upscaler.builtin].
  final Upscaler upscaler;

  const DynamicResolutionOptions({
    this.minScaleX = 0.5,
    this.minScaleY = 0.5,
    this.maxScaleX = 1.0,
    this.maxScaleY = 1.0,
    this.sharpness = 0.9,
    this.enabled = false,
    this.homogeneousScaling = false,
    this.quality = QualityLevel.low,
    this.upscaler = Upscaler.builtin,
  });

  DynamicResolutionOptions copyWith({
    double? minScaleX,
    double? minScaleY,
    double? maxScaleX,
    double? maxScaleY,
    double? sharpness,
    bool? enabled,
    bool? homogeneousScaling,
    QualityLevel? quality,
    Upscaler? upscaler,
  }) {
    return DynamicResolutionOptions(
      minScaleX: minScaleX ?? this.minScaleX,
      minScaleY: minScaleY ?? this.minScaleY,
      maxScaleX: maxScaleX ?? this.maxScaleX,
      maxScaleY: maxScaleY ?? this.maxScaleY,
      sharpness: sharpness ?? this.sharpness,
      enabled: enabled ?? this.enabled,
      homogeneousScaling: homogeneousScaling ?? this.homogeneousScaling,
      quality: quality ?? this.quality,
      upscaler: upscaler ?? this.upscaler,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DynamicResolutionOptions &&
          runtimeType == other.runtimeType &&
          minScaleX == other.minScaleX &&
          minScaleY == other.minScaleY &&
          maxScaleX == other.maxScaleX &&
          maxScaleY == other.maxScaleY &&
          sharpness == other.sharpness &&
          enabled == other.enabled &&
          homogeneousScaling == other.homogeneousScaling &&
          quality == other.quality &&
          upscaler == other.upscaler;

  @override
  int get hashCode => Object.hash(
        minScaleX,
        minScaleY,
        maxScaleX,
        maxScaleY,
        sharpness,
        enabled,
        homogeneousScaling,
        quality,
        upscaler,
      );

  void copyToNative(ffi_gen.filament_dynamic_resolution_options out) {
    out.minScale[0] = minScaleX;
    out.minScale[1] = minScaleY;
    out.maxScale[0] = maxScaleX;
    out.maxScale[1] = maxScaleY;
    out.sharpness = sharpness;
    out.enabled = enabled;
    out.homogeneousScaling = homogeneousScaling;
    out.quality = quality.toNative();
    out.upscaler = upscaler.toNative();
  }

  factory DynamicResolutionOptions.fromNative(ffi_gen.filament_dynamic_resolution_options out) {
    return DynamicResolutionOptions(
      minScaleX: out.minScale[0],
      minScaleY: out.minScale[1],
      maxScaleX: out.maxScale[0],
      maxScaleY: out.maxScale[1],
      sharpness: out.sharpness,
      enabled: out.enabled,
      homogeneousScaling: out.homogeneousScaling,
      quality: QualityLevel.fromNative(out.quality),
      upscaler: Upscaler.fromNative(out.upscaler),
    );
  }
}

enum BloomBlendMode {
  add,
  interpolate;

  int toNative() => index;

  static BloomBlendMode fromNative(int val) => BloomBlendMode.values[val];
}

class BloomOptions {
  final ffi.Pointer<ffi.Void>? dirt;
  final double dirtStrength;
  final double strength;
  final int resolution;
  final int levels;
  final BloomBlendMode blendMode;
  final bool threshold;
  final bool enabled;
  final double highlight;
  final QualityLevel quality;
  final bool lensFlare;
  final bool starburst;
  final double chromaticAberration;
  final int ghostCount;
  final double ghostSpacing;
  final double ghostThreshold;
  final double haloThickness;
  final double haloRadius;
  final double haloThreshold;

  const BloomOptions({
    this.dirt,
    this.dirtStrength = 0.2,
    this.strength = 0.10,
    this.resolution = 384,
    this.levels = 6,
    this.blendMode = BloomBlendMode.add,
    this.threshold = true,
    this.enabled = false,
    this.highlight = 1000.0,
    this.quality = QualityLevel.low,
    this.lensFlare = false,
    this.starburst = true,
    this.chromaticAberration = 0.005,
    this.ghostCount = 4,
    this.ghostSpacing = 0.6,
    this.ghostThreshold = 10.0,
    this.haloThickness = 0.1,
    this.haloRadius = 0.4,
    this.haloThreshold = 10.0,
  });

  BloomOptions copyWith({
    ffi.Pointer<ffi.Void>? dirt,
    double? dirtStrength,
    double? strength,
    int? resolution,
    int? levels,
    BloomBlendMode? blendMode,
    bool? threshold,
    bool? enabled,
    double? highlight,
    QualityLevel? quality,
    bool? lensFlare,
    bool? starburst,
    double? chromaticAberration,
    int? ghostCount,
    double? ghostSpacing,
    double? ghostThreshold,
    double? haloThickness,
    double? haloRadius,
    double? haloThreshold,
  }) {
    return BloomOptions(
      dirt: dirt ?? this.dirt,
      dirtStrength: dirtStrength ?? this.dirtStrength,
      strength: strength ?? this.strength,
      resolution: resolution ?? this.resolution,
      levels: levels ?? this.levels,
      blendMode: blendMode ?? this.blendMode,
      threshold: threshold ?? this.threshold,
      enabled: enabled ?? this.enabled,
      highlight: highlight ?? this.highlight,
      quality: quality ?? this.quality,
      lensFlare: lensFlare ?? this.lensFlare,
      starburst: starburst ?? this.starburst,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      ghostCount: ghostCount ?? this.ghostCount,
      ghostSpacing: ghostSpacing ?? this.ghostSpacing,
      ghostThreshold: ghostThreshold ?? this.ghostThreshold,
      haloThickness: haloThickness ?? this.haloThickness,
      haloRadius: haloRadius ?? this.haloRadius,
      haloThreshold: haloThreshold ?? this.haloThreshold,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomOptions &&
          runtimeType == other.runtimeType &&
          dirt == other.dirt &&
          dirtStrength == other.dirtStrength &&
          strength == other.strength &&
          resolution == other.resolution &&
          levels == other.levels &&
          blendMode == other.blendMode &&
          threshold == other.threshold &&
          enabled == other.enabled &&
          highlight == other.highlight &&
          quality == other.quality &&
          lensFlare == other.lensFlare &&
          starburst == other.starburst &&
          chromaticAberration == other.chromaticAberration &&
          ghostCount == other.ghostCount &&
          ghostSpacing == other.ghostSpacing &&
          ghostThreshold == other.ghostThreshold &&
          haloThickness == other.haloThickness &&
          haloRadius == other.haloRadius &&
          haloThreshold == other.haloThreshold;

  @override
  int get hashCode => Object.hashAll([
        dirt,
        dirtStrength,
        strength,
        resolution,
        levels,
        blendMode,
        threshold,
        enabled,
        highlight,
        quality,
        lensFlare,
        starburst,
        chromaticAberration,
        ghostCount,
        ghostSpacing,
        ghostThreshold,
        haloThickness,
        haloRadius,
        haloThreshold,
      ]);

  void copyToNative(ffi_gen.filament_bloom_options out) {
    out.dirt = dirt?.cast() ?? ffi.Pointer.fromAddress(0);
    out.dirtStrength = dirtStrength;
    out.strength = strength;
    out.resolution = resolution;
    out.levels = levels;
    out.blendMode = blendMode.toNative();
    out.threshold = threshold;
    out.enabled = enabled;
    out.highlight = highlight;
    out.quality = quality.toNative();
    out.lensFlare = lensFlare;
    out.starburst = starburst;
    out.chromaticAberration = chromaticAberration;
    out.ghostCount = ghostCount;
    out.ghostSpacing = ghostSpacing;
    out.ghostThreshold = ghostThreshold;
    out.haloThickness = haloThickness;
    out.haloRadius = haloRadius;
    out.haloThreshold = haloThreshold;
  }

  factory BloomOptions.fromNative(ffi_gen.filament_bloom_options out) {
    return BloomOptions(
      dirt: out.dirt.address == 0 ? null : out.dirt,
      dirtStrength: out.dirtStrength,
      strength: out.strength,
      resolution: out.resolution,
      levels: out.levels,
      blendMode: BloomBlendMode.fromNative(out.blendMode),
      threshold: out.threshold,
      enabled: out.enabled,
      highlight: out.highlight,
      quality: QualityLevel.fromNative(out.quality),
      lensFlare: out.lensFlare,
      starburst: out.starburst,
      chromaticAberration: out.chromaticAberration,
      ghostCount: out.ghostCount,
      ghostSpacing: out.ghostSpacing,
      ghostThreshold: out.ghostThreshold,
      haloThickness: out.haloThickness,
      haloRadius: out.haloRadius,
      haloThreshold: out.haloThreshold,
    );
  }
}

class FogOptions {
  final double distance;
  final double cutOffDistance;
  final double maximumOpacity;
  final double height;
  final double heightFalloff;
  final double colorR;
  final double colorG;
  final double colorB;
  final double density;
  final double inScatteringStart;
  final double inScatteringSize;
  final bool fogColorFromIbl;
  final ffi.Pointer<ffi.Void>? skyColor;
  final bool enabled;

  const FogOptions({
    this.distance = 0.0,
    this.cutOffDistance = double.infinity,
    this.maximumOpacity = 1.0,
    this.height = 0.0,
    this.heightFalloff = 1.0,
    this.colorR = 1.0,
    this.colorG = 1.0,
    this.colorB = 1.0,
    this.density = 0.1,
    this.inScatteringStart = 0.0,
    this.inScatteringSize = -1.0,
    this.fogColorFromIbl = false,
    this.skyColor,
    this.enabled = false,
  });

  FogOptions copyWith({
    double? distance,
    double? cutOffDistance,
    double? maximumOpacity,
    double? height,
    double? heightFalloff,
    double? colorR,
    double? colorG,
    double? colorB,
    double? density,
    double? inScatteringStart,
    double? inScatteringSize,
    bool? fogColorFromIbl,
    ffi.Pointer<ffi.Void>? skyColor,
    bool? enabled,
  }) {
    return FogOptions(
      distance: distance ?? this.distance,
      cutOffDistance: cutOffDistance ?? this.cutOffDistance,
      maximumOpacity: maximumOpacity ?? this.maximumOpacity,
      height: height ?? this.height,
      heightFalloff: heightFalloff ?? this.heightFalloff,
      colorR: colorR ?? this.colorR,
      colorG: colorG ?? this.colorG,
      colorB: colorB ?? this.colorB,
      density: density ?? this.density,
      inScatteringStart: inScatteringStart ?? this.inScatteringStart,
      inScatteringSize: inScatteringSize ?? this.inScatteringSize,
      fogColorFromIbl: fogColorFromIbl ?? this.fogColorFromIbl,
      skyColor: skyColor ?? this.skyColor,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FogOptions &&
          runtimeType == other.runtimeType &&
          distance == other.distance &&
          cutOffDistance == other.cutOffDistance &&
          maximumOpacity == other.maximumOpacity &&
          height == other.height &&
          heightFalloff == other.heightFalloff &&
          colorR == other.colorR &&
          colorG == other.colorG &&
          colorB == other.colorB &&
          density == other.density &&
          inScatteringStart == other.inScatteringStart &&
          inScatteringSize == other.inScatteringSize &&
          fogColorFromIbl == other.fogColorFromIbl &&
          skyColor == other.skyColor &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
        distance,
        cutOffDistance,
        maximumOpacity,
        height,
        heightFalloff,
        colorR,
        colorG,
        colorB,
        density,
        inScatteringStart,
        inScatteringSize,
        fogColorFromIbl,
        skyColor,
        enabled,
      );

  void copyToNative(ffi_gen.filament_fog_options out) {
    out.distance = distance;
    out.cutOffDistance = cutOffDistance;
    out.maximumOpacity = maximumOpacity;
    out.height = height;
    out.heightFalloff = heightFalloff;
    out.color[0] = colorR;
    out.color[1] = colorG;
    out.color[2] = colorB;
    out.density = density;
    out.inScatteringStart = inScatteringStart;
    out.inScatteringSize = inScatteringSize;
    out.fogColorFromIbl = fogColorFromIbl;
    out.skyColor = skyColor?.cast() ?? ffi.Pointer.fromAddress(0);
    out.enabled = enabled;
  }

  factory FogOptions.fromNative(ffi_gen.filament_fog_options out) {
    return FogOptions(
      distance: out.distance,
      cutOffDistance: out.cutOffDistance,
      maximumOpacity: out.maximumOpacity,
      height: out.height,
      heightFalloff: out.heightFalloff,
      colorR: out.color[0],
      colorG: out.color[1],
      colorB: out.color[2],
      density: out.density,
      inScatteringStart: out.inScatteringStart,
      inScatteringSize: out.inScatteringSize,
      fogColorFromIbl: out.fogColorFromIbl,
      skyColor: out.skyColor.address == 0 ? null : out.skyColor,
      enabled: out.enabled,
    );
  }
}

enum DofFilter {
  none,
  unused,
  median;

  int toNative() => index;

  static DofFilter fromNative(int val) => DofFilter.values[val];
}

class DepthOfFieldOptions {
  final double cocScale;
  final double cocAspectRatio;
  final double maxApertureDiameter;
  final bool enabled;
  final DofFilter filter;
  final bool nativeResolution;
  final int foregroundRingCount;
  final int backgroundRingCount;
  final int fastGatherRingCount;
  final int maxForegroundCOC;
  final int maxBackgroundCOC;

  const DepthOfFieldOptions({
    this.cocScale = 1.0,
    this.cocAspectRatio = 1.0,
    this.maxApertureDiameter = 0.01,
    this.enabled = false,
    this.filter = DofFilter.median,
    this.nativeResolution = false,
    this.foregroundRingCount = 0,
    this.backgroundRingCount = 0,
    this.fastGatherRingCount = 0,
    this.maxForegroundCOC = 0,
    this.maxBackgroundCOC = 0,
  });

  DepthOfFieldOptions copyWith({
    double? cocScale,
    double? cocAspectRatio,
    double? maxApertureDiameter,
    bool? enabled,
    DofFilter? filter,
    bool? nativeResolution,
    int? foregroundRingCount,
    int? backgroundRingCount,
    int? fastGatherRingCount,
    int? maxForegroundCOC,
    int? maxBackgroundCOC,
  }) {
    return DepthOfFieldOptions(
      cocScale: cocScale ?? this.cocScale,
      cocAspectRatio: cocAspectRatio ?? this.cocAspectRatio,
      maxApertureDiameter: maxApertureDiameter ?? this.maxApertureDiameter,
      enabled: enabled ?? this.enabled,
      filter: filter ?? this.filter,
      nativeResolution: nativeResolution ?? this.nativeResolution,
      foregroundRingCount: foregroundRingCount ?? this.foregroundRingCount,
      backgroundRingCount: backgroundRingCount ?? this.backgroundRingCount,
      fastGatherRingCount: fastGatherRingCount ?? this.fastGatherRingCount,
      maxForegroundCOC: maxForegroundCOC ?? this.maxForegroundCOC,
      maxBackgroundCOC: maxBackgroundCOC ?? this.maxBackgroundCOC,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepthOfFieldOptions &&
          runtimeType == other.runtimeType &&
          cocScale == other.cocScale &&
          cocAspectRatio == other.cocAspectRatio &&
          maxApertureDiameter == other.maxApertureDiameter &&
          enabled == other.enabled &&
          filter == other.filter &&
          nativeResolution == other.nativeResolution &&
          foregroundRingCount == other.foregroundRingCount &&
          backgroundRingCount == other.backgroundRingCount &&
          fastGatherRingCount == other.fastGatherRingCount &&
          maxForegroundCOC == other.maxForegroundCOC &&
          maxBackgroundCOC == other.maxBackgroundCOC;

  @override
  int get hashCode => Object.hash(
        cocScale,
        cocAspectRatio,
        maxApertureDiameter,
        enabled,
        filter,
        nativeResolution,
        foregroundRingCount,
        backgroundRingCount,
        fastGatherRingCount,
        maxForegroundCOC,
        maxBackgroundCOC,
      );

  void copyToNative(ffi_gen.filament_depth_of_field_options out) {
    out.cocScale = cocScale;
    out.cocAspectRatio = cocAspectRatio;
    out.maxApertureDiameter = maxApertureDiameter;
    out.enabled = enabled;
    out.filter = filter.toNative();
    out.nativeResolution = nativeResolution;
    out.foregroundRingCount = foregroundRingCount;
    out.backgroundRingCount = backgroundRingCount;
    out.fastGatherRingCount = fastGatherRingCount;
    out.maxForegroundCOC = maxForegroundCOC;
    out.maxBackgroundCOC = maxBackgroundCOC;
  }

  factory DepthOfFieldOptions.fromNative(ffi_gen.filament_depth_of_field_options out) {
    return DepthOfFieldOptions(
      cocScale: out.cocScale,
      cocAspectRatio: out.cocAspectRatio,
      maxApertureDiameter: out.maxApertureDiameter,
      enabled: out.enabled,
      filter: DofFilter.fromNative(out.filter),
      nativeResolution: out.nativeResolution,
      foregroundRingCount: out.foregroundRingCount,
      backgroundRingCount: out.backgroundRingCount,
      fastGatherRingCount: out.fastGatherRingCount,
      maxForegroundCOC: out.maxForegroundCOC,
      maxBackgroundCOC: out.maxBackgroundCOC,
    );
  }
}

class VignetteOptions {
  final double midPoint;
  final double roundness;
  final double feather;
  final double colorR;
  final double colorG;
  final double colorB;
  final double colorA;
  final bool enabled;

  const VignetteOptions({
    this.midPoint = 0.5,
    this.roundness = 0.5,
    this.feather = 0.5,
    this.colorR = 0.0,
    this.colorG = 0.0,
    this.colorB = 0.0,
    this.colorA = 1.0,
    this.enabled = false,
  });

  VignetteOptions copyWith({
    double? midPoint,
    double? roundness,
    double? feather,
    double? colorR,
    double? colorG,
    double? colorB,
    double? colorA,
    bool? enabled,
  }) {
    return VignetteOptions(
      midPoint: midPoint ?? this.midPoint,
      roundness: roundness ?? this.roundness,
      feather: feather ?? this.feather,
      colorR: colorR ?? this.colorR,
      colorG: colorG ?? this.colorG,
      colorB: colorB ?? this.colorB,
      colorA: colorA ?? this.colorA,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VignetteOptions &&
          runtimeType == other.runtimeType &&
          midPoint == other.midPoint &&
          roundness == other.roundness &&
          feather == other.feather &&
          colorR == other.colorR &&
          colorG == other.colorG &&
          colorB == other.colorB &&
          colorA == other.colorA &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
        midPoint,
        roundness,
        feather,
        colorR,
        colorG,
        colorB,
        colorA,
        enabled,
      );

  void copyToNative(ffi_gen.filament_vignette_options out) {
    out.midPoint = midPoint;
    out.roundness = roundness;
    out.feather = feather;
    out.color[0] = colorR;
    out.color[1] = colorG;
    out.color[2] = colorB;
    out.color[3] = colorA;
    out.enabled = enabled;
  }

  factory VignetteOptions.fromNative(ffi_gen.filament_vignette_options out) {
    return VignetteOptions(
      midPoint: out.midPoint,
      roundness: out.roundness,
      feather: out.feather,
      colorR: out.color[0],
      colorG: out.color[1],
      colorB: out.color[2],
      colorA: out.color[3],
      enabled: out.enabled,
    );
  }
}

class RenderQuality {
  final QualityLevel hdrColorBuffer;

  const RenderQuality({
    this.hdrColorBuffer = QualityLevel.high,
  });

  RenderQuality copyWith({
    QualityLevel? hdrColorBuffer,
  }) {
    return RenderQuality(
      hdrColorBuffer: hdrColorBuffer ?? this.hdrColorBuffer,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenderQuality &&
          runtimeType == other.runtimeType &&
          hdrColorBuffer == other.hdrColorBuffer;

  @override
  int get hashCode => hdrColorBuffer.hashCode;

  void copyToNative(ffi_gen.filament_render_quality out) {
    out.hdrColorBuffer = hdrColorBuffer.toNative();
  }

  factory RenderQuality.fromNative(ffi_gen.filament_render_quality out) {
    return RenderQuality(
      hdrColorBuffer: QualityLevel.fromNative(out.hdrColorBuffer),
    );
  }
}

enum AmbientOcclusionType {
  sao,
  gtao;

  int toNative() => index;

  static AmbientOcclusionType fromNative(int val) => AmbientOcclusionType.values[val];
}

class AmbientOcclusionOptions {
  final AmbientOcclusionType aoType;
  final double radius;
  final double power;
  final double bias;
  final double resolution;
  final double intensity;
  final double bilateralThreshold;
  final QualityLevel quality;
  final QualityLevel lowPassFilter;
  final QualityLevel upsampling;
  final bool enabled;
  final bool bentNormals;
  final double minHorizonAngleRad;

  // Ssct
  final double ssctLightConeRad;
  final double ssctShadowDistance;
  final double ssctContactDistanceMax;
  final double ssctIntensity;
  final double ssctLightDirectionX;
  final double ssctLightDirectionY;
  final double ssctLightDirectionZ;
  final double ssctDepthBias;
  final double ssctDepthSlopeBias;
  final int ssctSampleCount;
  final int ssctRayCount;
  final bool ssctEnabled;

  // Gtao
  final int gtaoSampleSliceCount;
  final int gtaoSampleStepsPerSlice;
  final double gtaoThicknessHeuristic;
  final bool gtaoUseVisibilityBitmasks;
  final double gtaoConstThickness;
  final bool gtaoLinearThickness;

  const AmbientOcclusionOptions({
    this.aoType = AmbientOcclusionType.sao,
    this.radius = 0.3,
    this.power = 1.0,
    this.bias = 0.0005,
    this.resolution = 0.5,
    this.intensity = 1.0,
    this.bilateralThreshold = 0.05,
    this.quality = QualityLevel.low,
    this.lowPassFilter = QualityLevel.medium,
    this.upsampling = QualityLevel.low,
    this.enabled = false,
    this.bentNormals = false,
    this.minHorizonAngleRad = 0.0,

    this.ssctLightConeRad = 1.0,
    this.ssctShadowDistance = 0.3,
    this.ssctContactDistanceMax = 1.0,
    this.ssctIntensity = 0.8,
    this.ssctLightDirectionX = 0.0,
    this.ssctLightDirectionY = -1.0,
    this.ssctLightDirectionZ = 0.0,
    this.ssctDepthBias = 0.01,
    this.ssctDepthSlopeBias = 0.01,
    this.ssctSampleCount = 4,
    this.ssctRayCount = 1,
    this.ssctEnabled = false,

    this.gtaoSampleSliceCount = 4,
    this.gtaoSampleStepsPerSlice = 3,
    this.gtaoThicknessHeuristic = 0.004,
    this.gtaoUseVisibilityBitmasks = false,
    this.gtaoConstThickness = 0.5,
    this.gtaoLinearThickness = false,
  });

  AmbientOcclusionOptions copyWith({
    AmbientOcclusionType? aoType,
    double? radius,
    double? power,
    double? bias,
    double? resolution,
    double? intensity,
    double? bilateralThreshold,
    QualityLevel? quality,
    QualityLevel? lowPassFilter,
    QualityLevel? upsampling,
    bool? enabled,
    bool? bentNormals,
    double? minHorizonAngleRad,
    double? ssctLightConeRad,
    double? ssctShadowDistance,
    double? ssctContactDistanceMax,
    double? ssctIntensity,
    double? ssctLightDirectionX,
    double? ssctLightDirectionY,
    double? ssctLightDirectionZ,
    double? ssctDepthBias,
    double? ssctDepthSlopeBias,
    int? ssctSampleCount,
    int? ssctRayCount,
    bool? ssctEnabled,
    int? gtaoSampleSliceCount,
    int? gtaoSampleStepsPerSlice,
    double? gtaoThicknessHeuristic,
    bool? gtaoUseVisibilityBitmasks,
    double? gtaoConstThickness,
    bool? gtaoLinearThickness,
  }) {
    return AmbientOcclusionOptions(
      aoType: aoType ?? this.aoType,
      radius: radius ?? this.radius,
      power: power ?? this.power,
      bias: bias ?? this.bias,
      resolution: resolution ?? this.resolution,
      intensity: intensity ?? this.intensity,
      bilateralThreshold: bilateralThreshold ?? this.bilateralThreshold,
      quality: quality ?? this.quality,
      lowPassFilter: lowPassFilter ?? this.lowPassFilter,
      upsampling: upsampling ?? this.upsampling,
      enabled: enabled ?? this.enabled,
      bentNormals: bentNormals ?? this.bentNormals,
      minHorizonAngleRad: minHorizonAngleRad ?? this.minHorizonAngleRad,
      ssctLightConeRad: ssctLightConeRad ?? this.ssctLightConeRad,
      ssctShadowDistance: ssctShadowDistance ?? this.ssctShadowDistance,
      ssctContactDistanceMax: ssctContactDistanceMax ?? this.ssctContactDistanceMax,
      ssctIntensity: ssctIntensity ?? this.ssctIntensity,
      ssctLightDirectionX: ssctLightDirectionX ?? this.ssctLightDirectionX,
      ssctLightDirectionY: ssctLightDirectionY ?? this.ssctLightDirectionY,
      ssctLightDirectionZ: ssctLightDirectionZ ?? this.ssctLightDirectionZ,
      ssctDepthBias: ssctDepthBias ?? this.ssctDepthBias,
      ssctDepthSlopeBias: ssctDepthSlopeBias ?? this.ssctDepthSlopeBias,
      ssctSampleCount: ssctSampleCount ?? this.ssctSampleCount,
      ssctRayCount: ssctRayCount ?? this.ssctRayCount,
      ssctEnabled: ssctEnabled ?? this.ssctEnabled,
      gtaoSampleSliceCount: gtaoSampleSliceCount ?? this.gtaoSampleSliceCount,
      gtaoSampleStepsPerSlice: gtaoSampleStepsPerSlice ?? this.gtaoSampleStepsPerSlice,
      gtaoThicknessHeuristic: gtaoThicknessHeuristic ?? this.gtaoThicknessHeuristic,
      gtaoUseVisibilityBitmasks: gtaoUseVisibilityBitmasks ?? this.gtaoUseVisibilityBitmasks,
      gtaoConstThickness: gtaoConstThickness ?? this.gtaoConstThickness,
      gtaoLinearThickness: gtaoLinearThickness ?? this.gtaoLinearThickness,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmbientOcclusionOptions &&
          runtimeType == other.runtimeType &&
          aoType == other.aoType &&
          radius == other.radius &&
          power == other.power &&
          bias == other.bias &&
          resolution == other.resolution &&
          intensity == other.intensity &&
          bilateralThreshold == other.bilateralThreshold &&
          quality == other.quality &&
          lowPassFilter == other.lowPassFilter &&
          upsampling == other.upsampling &&
          enabled == other.enabled &&
          bentNormals == other.bentNormals &&
          minHorizonAngleRad == other.minHorizonAngleRad &&
          ssctLightConeRad == other.ssctLightConeRad &&
          ssctShadowDistance == other.ssctShadowDistance &&
          ssctContactDistanceMax == other.ssctContactDistanceMax &&
          ssctIntensity == other.ssctIntensity &&
          ssctLightDirectionX == other.ssctLightDirectionX &&
          ssctLightDirectionY == other.ssctLightDirectionY &&
          ssctLightDirectionZ == other.ssctLightDirectionZ &&
          ssctDepthBias == other.ssctDepthBias &&
          ssctDepthSlopeBias == other.ssctDepthSlopeBias &&
          ssctSampleCount == other.ssctSampleCount &&
          ssctRayCount == other.ssctRayCount &&
          ssctEnabled == other.ssctEnabled &&
          gtaoSampleSliceCount == other.gtaoSampleSliceCount &&
          gtaoSampleStepsPerSlice == other.gtaoSampleStepsPerSlice &&
          gtaoThicknessHeuristic == other.gtaoThicknessHeuristic &&
          gtaoUseVisibilityBitmasks == other.gtaoUseVisibilityBitmasks &&
          gtaoConstThickness == other.gtaoConstThickness &&
          gtaoLinearThickness == other.gtaoLinearThickness;

  @override
  int get hashCode => Object.hashAll([
        aoType,
        radius,
        power,
        bias,
        resolution,
        intensity,
        bilateralThreshold,
        quality,
        lowPassFilter,
        upsampling,
        enabled,
        bentNormals,
        minHorizonAngleRad,
        ssctLightConeRad,
        ssctShadowDistance,
        ssctContactDistanceMax,
        ssctIntensity,
        ssctLightDirectionX,
        ssctLightDirectionY,
        ssctLightDirectionZ,
      ]);

  void copyToNative(ffi_gen.filament_ambient_occlusion_options out) {
    out.aoType = aoType.toNative();
    out.radius = radius;
    out.power = power;
    out.bias = bias;
    out.resolution = resolution;
    out.intensity = intensity;
    out.bilateralThreshold = bilateralThreshold;
    out.quality = quality.toNative();
    out.lowPassFilter = lowPassFilter.toNative();
    out.upsampling = upsampling.toNative();
    out.enabled = enabled;
    out.bentNormals = bentNormals;
    out.minHorizonAngleRad = minHorizonAngleRad;

    out.ssct.lightConeRad = ssctLightConeRad;
    out.ssct.shadowDistance = ssctShadowDistance;
    out.ssct.contactDistanceMax = ssctContactDistanceMax;
    out.ssct.intensity = ssctIntensity;
    out.ssct.lightDirection[0] = ssctLightDirectionX;
    out.ssct.lightDirection[1] = ssctLightDirectionY;
    out.ssct.lightDirection[2] = ssctLightDirectionZ;
    out.ssct.depthBias = ssctDepthBias;
    out.ssct.depthSlopeBias = ssctDepthSlopeBias;
    out.ssct.sampleCount = ssctSampleCount;
    out.ssct.rayCount = ssctRayCount;
    out.ssct.enabled = ssctEnabled;

    out.gtao.sampleSliceCount = gtaoSampleSliceCount;
    out.gtao.sampleStepsPerSlice = gtaoSampleStepsPerSlice;
    out.gtao.thicknessHeuristic = gtaoThicknessHeuristic;
    out.gtao.useVisibilityBitmasks = gtaoUseVisibilityBitmasks;
    out.gtao.constThickness = gtaoConstThickness;
    out.gtao.linearThickness = gtaoLinearThickness;
  }

  factory AmbientOcclusionOptions.fromNative(ffi_gen.filament_ambient_occlusion_options out) {
    return AmbientOcclusionOptions(
      aoType: AmbientOcclusionType.fromNative(out.aoType),
      radius: out.radius,
      power: out.power,
      bias: out.bias,
      resolution: out.resolution,
      intensity: out.intensity,
      bilateralThreshold: out.bilateralThreshold,
      quality: QualityLevel.fromNative(out.quality),
      lowPassFilter: QualityLevel.fromNative(out.lowPassFilter),
      upsampling: QualityLevel.fromNative(out.upsampling),
      enabled: out.enabled,
      bentNormals: out.bentNormals,
      minHorizonAngleRad: out.minHorizonAngleRad,
      ssctLightConeRad: out.ssct.lightConeRad,
      ssctShadowDistance: out.ssct.shadowDistance,
      ssctContactDistanceMax: out.ssct.contactDistanceMax,
      ssctIntensity: out.ssct.intensity,
      ssctLightDirectionX: out.ssct.lightDirection[0],
      ssctLightDirectionY: out.ssct.lightDirection[1],
      ssctLightDirectionZ: out.ssct.lightDirection[2],
      ssctDepthBias: out.ssct.depthBias,
      ssctDepthSlopeBias: out.ssct.depthSlopeBias,
      ssctSampleCount: out.ssct.sampleCount,
      ssctRayCount: out.ssct.rayCount,
      ssctEnabled: out.ssct.enabled,
      gtaoSampleSliceCount: out.gtao.sampleSliceCount,
      gtaoSampleStepsPerSlice: out.gtao.sampleStepsPerSlice,
      gtaoThicknessHeuristic: out.gtao.thicknessHeuristic,
      gtaoUseVisibilityBitmasks: out.gtao.useVisibilityBitmasks,
      gtaoConstThickness: out.gtao.constThickness,
      gtaoLinearThickness: out.gtao.linearThickness,
    );
  }
}

class MultiSampleAntiAliasingOptions {
  final bool enabled;
  final int sampleCount;
  final bool customResolve;

  const MultiSampleAntiAliasingOptions({
    this.enabled = false,
    this.sampleCount = 4,
    this.customResolve = false,
  });

  MultiSampleAntiAliasingOptions copyWith({
    bool? enabled,
    int? sampleCount,
    bool? customResolve,
  }) {
    return MultiSampleAntiAliasingOptions(
      enabled: enabled ?? this.enabled,
      sampleCount: sampleCount ?? this.sampleCount,
      customResolve: customResolve ?? this.customResolve,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultiSampleAntiAliasingOptions &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          sampleCount == other.sampleCount &&
          customResolve == other.customResolve;

  @override
  int get hashCode => Object.hash(enabled, sampleCount, customResolve);

  void copyToNative(ffi_gen.filament_multi_sample_anti_aliasing_options out) {
    out.enabled = enabled;
    out.sampleCount = sampleCount;
    out.customResolve = customResolve;
  }

  factory MultiSampleAntiAliasingOptions.fromNative(ffi_gen.filament_multi_sample_anti_aliasing_options out) {
    return MultiSampleAntiAliasingOptions(
      enabled: out.enabled,
      sampleCount: out.sampleCount,
      customResolve: out.customResolve,
    );
  }
}

enum TaaBoxType {
  aabb,
  aabbVariance;

  int toNative() => index;

  static TaaBoxType fromNative(int val) => TaaBoxType.values[val];
}

enum TaaBoxClipping {
  accurate,
  clamp,
  none;

  int toNative() => index;

  static TaaBoxClipping fromNative(int val) => TaaBoxClipping.values[val];
}

/// Which temporal anti-aliasing and upscaling algorithm a view runs.
enum TaaAlgorithm {
  /// Filament's temporal anti-aliasing.
  filament,

  /// The FidelityFX Super Resolution 3 upscaler as fragment passes: uses the
  /// structure pass motion vectors (implied), honours `upscaling`, `sharpness`,
  /// `lodBias` and `jitterPattern`; feature level 1 and no stereo. An external
  /// upscaler (DLSS) takes precedence.
  fsr3;

  int toNative() => index;

  static TaaAlgorithm fromNative(int value) =>
      value >= 0 && value < TaaAlgorithm.values.length ? TaaAlgorithm.values[value] : TaaAlgorithm.filament;
}

enum TaaJitterPattern {
  rgssX4,
  uniformHelixX4,
  halton23X8,
  halton23X16,
  halton23X32;

  int toNative() => index;

  static TaaJitterPattern fromNative(int val) => TaaJitterPattern.values[val];
}

class TemporalAntiAliasingOptions {
  final double filterWidth;
  final double feedback;
  final double lodBias;
  final double sharpness;
  final bool enabled;
  final double upscaling;
  final bool filterHistory;
  final bool filterInput;
  final bool useYCoCg;
  final bool hdr;
  final TaaBoxType boxType;
  final TaaBoxClipping boxClipping;
  final TaaJitterPattern jitterPattern;
  final double varianceGamma;
  final bool preventFlickering;
  final bool historyReprojection;

  /// Renders per-pixel motion vectors in the structure pass (which then runs
  /// at full resolution) and reprojects the TAA history with them instead of
  /// with the camera matrices alone, so moving, transform-animated, skinned
  /// and morphed objects stop ghosting (a shared skinning buffer keeps no
  /// previous palette). The buffer can be exported with
  /// [FilamentView.motionVectorTexture]; needs
  /// [FilamentView.motionVectorsSupported].
  final bool motionVectors;

  /// Filament's TAA or the FSR3 upscaler. Default [TaaAlgorithm.filament].
  final TaaAlgorithm algorithm;

  /// FSR3 frame generation: an interpolated frame is presented before each
  /// rendered frame, doubling the presented rate at half a frame of latency.
  /// Needs [TaaAlgorithm.fsr3] and a view rendering into the swap chain
  /// without guard band. Default false.
  final bool frameGeneration;

  const TemporalAntiAliasingOptions({
    this.filterWidth = 1.0,
    this.feedback = 0.12,
    this.lodBias = -1.0,
    this.sharpness = 0.0,
    this.enabled = false,
    this.upscaling = 1.0,
    this.filterHistory = true,
    this.filterInput = true,
    this.useYCoCg = false,
    this.hdr = true,
    this.boxType = TaaBoxType.aabb,
    this.boxClipping = TaaBoxClipping.accurate,
    this.jitterPattern = TaaJitterPattern.halton23X16,
    this.varianceGamma = 1.0,
    this.preventFlickering = false,
    this.historyReprojection = true,
    this.motionVectors = false,
    this.algorithm = TaaAlgorithm.filament,
    this.frameGeneration = false,
  });

  TemporalAntiAliasingOptions copyWith({
    double? filterWidth,
    double? feedback,
    double? lodBias,
    double? sharpness,
    bool? enabled,
    double? upscaling,
    bool? filterHistory,
    bool? filterInput,
    bool? useYCoCg,
    bool? hdr,
    TaaBoxType? boxType,
    TaaBoxClipping? boxClipping,
    TaaJitterPattern? jitterPattern,
    double? varianceGamma,
    bool? preventFlickering,
    bool? historyReprojection,
    bool? motionVectors,
    TaaAlgorithm? algorithm,
    bool? frameGeneration,
  }) {
    return TemporalAntiAliasingOptions(
      filterWidth: filterWidth ?? this.filterWidth,
      feedback: feedback ?? this.feedback,
      lodBias: lodBias ?? this.lodBias,
      sharpness: sharpness ?? this.sharpness,
      enabled: enabled ?? this.enabled,
      upscaling: upscaling ?? this.upscaling,
      filterHistory: filterHistory ?? this.filterHistory,
      filterInput: filterInput ?? this.filterInput,
      useYCoCg: useYCoCg ?? this.useYCoCg,
      hdr: hdr ?? this.hdr,
      boxType: boxType ?? this.boxType,
      boxClipping: boxClipping ?? this.boxClipping,
      jitterPattern: jitterPattern ?? this.jitterPattern,
      varianceGamma: varianceGamma ?? this.varianceGamma,
      preventFlickering: preventFlickering ?? this.preventFlickering,
      historyReprojection: historyReprojection ?? this.historyReprojection,
      motionVectors: motionVectors ?? this.motionVectors,
      algorithm: algorithm ?? this.algorithm,
      frameGeneration: frameGeneration ?? this.frameGeneration,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemporalAntiAliasingOptions &&
          runtimeType == other.runtimeType &&
          filterWidth == other.filterWidth &&
          feedback == other.feedback &&
          lodBias == other.lodBias &&
          sharpness == other.sharpness &&
          enabled == other.enabled &&
          upscaling == other.upscaling &&
          filterHistory == other.filterHistory &&
          filterInput == other.filterInput &&
          useYCoCg == other.useYCoCg &&
          hdr == other.hdr &&
          boxType == other.boxType &&
          boxClipping == other.boxClipping &&
          jitterPattern == other.jitterPattern &&
          varianceGamma == other.varianceGamma &&
          preventFlickering == other.preventFlickering &&
          historyReprojection == other.historyReprojection &&
          motionVectors == other.motionVectors &&
          algorithm == other.algorithm &&
          frameGeneration == other.frameGeneration;

  @override
  int get hashCode => Object.hashAll([
        filterWidth,
        feedback,
        lodBias,
        sharpness,
        enabled,
        upscaling,
        filterHistory,
        filterInput,
        useYCoCg,
        hdr,
        boxType,
        boxClipping,
        jitterPattern,
        varianceGamma,
        preventFlickering,
        historyReprojection,
        motionVectors,
        algorithm,
        frameGeneration,
      ]);

  void copyToNative(ffi_gen.filament_temporal_anti_aliasing_options out) {
    out.filterWidth = filterWidth;
    out.feedback = feedback;
    out.lodBias = lodBias;
    out.sharpness = sharpness;
    out.enabled = enabled;
    out.upscaling = upscaling;
    out.filterHistory = filterHistory;
    out.filterInput = filterInput;
    out.useYCoCg = useYCoCg;
    out.hdr = hdr;
    out.boxType = boxType.toNative();
    out.boxClipping = boxClipping.toNative();
    out.jitterPattern = jitterPattern.toNative();
    out.varianceGamma = varianceGamma;
    out.preventFlickering = preventFlickering;
    out.historyReprojection = historyReprojection;
    out.motionVectors = motionVectors;
    out.algorithm = algorithm.toNative();
    out.frameGeneration = frameGeneration;
  }

  factory TemporalAntiAliasingOptions.fromNative(ffi_gen.filament_temporal_anti_aliasing_options out) {
    return TemporalAntiAliasingOptions(
      filterWidth: out.filterWidth,
      feedback: out.feedback,
      lodBias: out.lodBias,
      sharpness: out.sharpness,
      enabled: out.enabled,
      upscaling: out.upscaling,
      filterHistory: out.filterHistory,
      filterInput: out.filterInput,
      useYCoCg: out.useYCoCg,
      hdr: out.hdr,
      boxType: TaaBoxType.fromNative(out.boxType),
      boxClipping: TaaBoxClipping.fromNative(out.boxClipping),
      jitterPattern: TaaJitterPattern.fromNative(out.jitterPattern),
      varianceGamma: out.varianceGamma,
      preventFlickering: out.preventFlickering,
      historyReprojection: out.historyReprojection,
      motionVectors: out.motionVectors,
      algorithm: TaaAlgorithm.fromNative(out.algorithm),
      frameGeneration: out.frameGeneration,
    );
  }
}

class ScreenSpaceReflectionsOptions {
  final double thickness;
  final double bias;
  final double maxDistance;
  final double stride;
  final bool enabled;

  const ScreenSpaceReflectionsOptions({
    this.thickness = 0.1,
    this.bias = 0.01,
    this.maxDistance = 3.0,
    this.stride = 2.0,
    this.enabled = false,
  });

  ScreenSpaceReflectionsOptions copyWith({
    double? thickness,
    double? bias,
    double? maxDistance,
    double? stride,
    bool? enabled,
  }) {
    return ScreenSpaceReflectionsOptions(
      thickness: thickness ?? this.thickness,
      bias: bias ?? this.bias,
      maxDistance: maxDistance ?? this.maxDistance,
      stride: stride ?? this.stride,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenSpaceReflectionsOptions &&
          runtimeType == other.runtimeType &&
          thickness == other.thickness &&
          bias == other.bias &&
          maxDistance == other.maxDistance &&
          stride == other.stride &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(thickness, bias, maxDistance, stride, enabled);

  void copyToNative(ffi_gen.filament_screen_space_reflections_options out) {
    out.thickness = thickness;
    out.bias = bias;
    out.maxDistance = maxDistance;
    out.stride = stride;
    out.enabled = enabled;
  }

  factory ScreenSpaceReflectionsOptions.fromNative(ffi_gen.filament_screen_space_reflections_options out) {
    return ScreenSpaceReflectionsOptions(
      thickness: out.thickness,
      bias: out.bias,
      maxDistance: out.maxDistance,
      stride: out.stride,
      enabled: out.enabled,
    );
  }
}

class GuardBandOptions {
  final bool enabled;

  const GuardBandOptions({
    this.enabled = false,
  });

  GuardBandOptions copyWith({
    bool? enabled,
  }) {
    return GuardBandOptions(
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuardBandOptions &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled;

  @override
  int get hashCode => enabled.hashCode;

  void copyToNative(ffi_gen.filament_guard_band_options out) {
    out.enabled = enabled;
  }

  factory GuardBandOptions.fromNative(ffi_gen.filament_guard_band_options out) {
    return GuardBandOptions(
      enabled: out.enabled,
    );
  }
}

enum AntiAliasing {
  none,
  fxaa;

  int toNative() => index;

  static AntiAliasing fromNative(int val) => AntiAliasing.values[val];
}

enum Dithering {
  none,
  temporal;

  int toNative() => index;

  static Dithering fromNative(int val) => Dithering.values[val];
}

enum ShadowType {
  pcf,
  vsm,
  dpcf,
  pcss,
  pcfd;

  int toNative() => index;

  static ShadowType fromNative(int val) => ShadowType.values[val];
}

class VsmShadowOptions {
  final int anisotropy;
  final bool mipmapping;
  final int msaaSamples;
  final bool highPrecision;
  final double minVarianceScale;
  final double lightBleedReduction;

  const VsmShadowOptions({
    this.anisotropy = 0,
    this.mipmapping = false,
    this.msaaSamples = 1,
    this.highPrecision = false,
    this.minVarianceScale = 0.5,
    this.lightBleedReduction = 0.15,
  });

  VsmShadowOptions copyWith({
    int? anisotropy,
    bool? mipmapping,
    int? msaaSamples,
    bool? highPrecision,
    double? minVarianceScale,
    double? lightBleedReduction,
  }) {
    return VsmShadowOptions(
      anisotropy: anisotropy ?? this.anisotropy,
      mipmapping: mipmapping ?? this.mipmapping,
      msaaSamples: msaaSamples ?? this.msaaSamples,
      highPrecision: highPrecision ?? this.highPrecision,
      minVarianceScale: minVarianceScale ?? this.minVarianceScale,
      lightBleedReduction: lightBleedReduction ?? this.lightBleedReduction,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VsmShadowOptions &&
          runtimeType == other.runtimeType &&
          anisotropy == other.anisotropy &&
          mipmapping == other.mipmapping &&
          msaaSamples == other.msaaSamples &&
          highPrecision == other.highPrecision &&
          minVarianceScale == other.minVarianceScale &&
          lightBleedReduction == other.lightBleedReduction;

  @override
  int get hashCode => Object.hash(
        anisotropy,
        mipmapping,
        msaaSamples,
        highPrecision,
        minVarianceScale,
        lightBleedReduction,
      );

  void copyToNative(ffi_gen.filament_vsm_shadow_options out) {
    out.anisotropy = anisotropy;
    out.mipmapping = mipmapping;
    out.msaaSamples = msaaSamples;
    out.highPrecision = highPrecision;
    out.minVarianceScale = minVarianceScale;
    out.lightBleedReduction = lightBleedReduction;
  }

  factory VsmShadowOptions.fromNative(ffi_gen.filament_vsm_shadow_options out) {
    return VsmShadowOptions(
      anisotropy: out.anisotropy,
      mipmapping: out.mipmapping,
      msaaSamples: out.msaaSamples,
      highPrecision: out.highPrecision,
      minVarianceScale: out.minVarianceScale,
      lightBleedReduction: out.lightBleedReduction,
    );
  }
}

class SoftShadowOptions {
  final double penumbraScale;
  final double penumbraRatioScale;
  final double maxPenumbraRatio;
  final double maxSearchRadius;

  const SoftShadowOptions({
    this.penumbraScale = 1.0,
    this.penumbraRatioScale = 1.0,
    this.maxPenumbraRatio = 10.0,
    this.maxSearchRadius = 1.0,
  });

  SoftShadowOptions copyWith({
    double? penumbraScale,
    double? penumbraRatioScale,
    double? maxPenumbraRatio,
    double? maxSearchRadius,
  }) {
    return SoftShadowOptions(
      penumbraScale: penumbraScale ?? this.penumbraScale,
      penumbraRatioScale: penumbraRatioScale ?? this.penumbraRatioScale,
      maxPenumbraRatio: maxPenumbraRatio ?? this.maxPenumbraRatio,
      maxSearchRadius: maxSearchRadius ?? this.maxSearchRadius,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoftShadowOptions &&
          runtimeType == other.runtimeType &&
          penumbraScale == other.penumbraScale &&
          penumbraRatioScale == other.penumbraRatioScale &&
          maxPenumbraRatio == other.maxPenumbraRatio &&
          maxSearchRadius == other.maxSearchRadius;

  @override
  int get hashCode => Object.hash(
        penumbraScale,
        penumbraRatioScale,
        maxPenumbraRatio,
        maxSearchRadius,
      );

  void copyToNative(ffi_gen.filament_soft_shadow_options out) {
    out.penumbraScale = penumbraScale;
    out.penumbraRatioScale = penumbraRatioScale;
    out.maxPenumbraRatio = maxPenumbraRatio;
    out.maxSearchRadius = maxSearchRadius;
  }

  factory SoftShadowOptions.fromNative(ffi_gen.filament_soft_shadow_options out) {
    return SoftShadowOptions(
      penumbraScale: out.penumbraScale,
      penumbraRatioScale: out.penumbraRatioScale,
      maxPenumbraRatio: out.maxPenumbraRatio,
      maxSearchRadius: out.maxSearchRadius,
    );
  }
}

class StereoscopicOptions {
  final bool enabled;

  const StereoscopicOptions({
    this.enabled = false,
  });

  void copyToNative(ffi_gen.filament_stereoscopic_options out) {
    out.enabled = enabled;
  }

  factory StereoscopicOptions.fromNative(ffi_gen.filament_stereoscopic_options out) {
    return StereoscopicOptions(
      enabled: out.enabled,
    );
  }
}
