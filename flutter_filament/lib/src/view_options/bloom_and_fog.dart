part of '../view_options.dart';

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
