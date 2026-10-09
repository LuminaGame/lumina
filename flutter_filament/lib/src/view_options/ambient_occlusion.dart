part of '../view_options.dart';

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
