import 'filament_bindings.dart' as c;

/// ReSTIR direct lighting for the punctual lights of a view.
///
/// With [enabled] on a Vulkan engine that supports ray queries
/// (`FilamentEngine.supportsRayQuery`) and a scene that keeps its acceleration
/// structures (`FilamentScene.rayTracingEnabled`), every pixel resamples the
/// scene's point and spot lights ([initialCandidates] per frame), reuses the
/// previous frame ([temporal], bounded by [maxHistory]) and its neighbours
/// ([spatialSamples] within [spatialRadiusPx]), traces one visibility ray to
/// the chosen light ([visibilityRays]) and shades that light alone. The cost is
/// nearly independent of the light count; without support the froxel light
/// loop renders as before.
class RestirOptions {
  const RestirOptions({
    this.enabled = false,
    this.initialCandidates = 8,
    this.spatialSamples = 2,
    this.spatialRadiusPx = 32.0,
    this.temporal = true,
    this.maxHistory = 20,
    this.visibilityRays = true,
    this.shadeEmissive = false,
  });

  final bool enabled;

  /// Lights sampled per pixel and frame before any reuse.
  final int initialCandidates;

  /// Neighbouring reservoirs merged into each pixel's (0 disables spatial reuse).
  final int spatialSamples;

  /// Radius of the neighbourhood, in pixels.
  final double spatialRadiusPx;

  /// Reuse the previous frame's reservoir at the reprojected position.
  final bool temporal;

  /// How many frames of history one reservoir may weigh.
  final int maxHistory;

  /// Trace a visibility ray to the chosen light (hard ray-traced shadows).
  final bool visibilityRays;

  /// Reserved: emissive triangles as lights are not implemented yet.
  final bool shadeEmissive;

  RestirOptions copyWith({
    bool? enabled,
    int? initialCandidates,
    int? spatialSamples,
    double? spatialRadiusPx,
    bool? temporal,
    int? maxHistory,
    bool? visibilityRays,
    bool? shadeEmissive,
  }) {
    return RestirOptions(
      enabled: enabled ?? this.enabled,
      initialCandidates: initialCandidates ?? this.initialCandidates,
      spatialSamples: spatialSamples ?? this.spatialSamples,
      spatialRadiusPx: spatialRadiusPx ?? this.spatialRadiusPx,
      temporal: temporal ?? this.temporal,
      maxHistory: maxHistory ?? this.maxHistory,
      visibilityRays: visibilityRays ?? this.visibilityRays,
      shadeEmissive: shadeEmissive ?? this.shadeEmissive,
    );
  }

  void copyToNative(c.filament_restir_options ref) {
    ref.enabled = enabled;
    ref.initialCandidates = initialCandidates;
    ref.spatialSamples = spatialSamples;
    ref.spatialRadiusPx = spatialRadiusPx;
    ref.temporal = temporal;
    ref.maxHistory = maxHistory;
    ref.visibilityRays = visibilityRays;
    ref.shadeEmissive = shadeEmissive;
  }

  static RestirOptions fromNative(c.filament_restir_options ref) {
    return RestirOptions(
      enabled: ref.enabled,
      initialCandidates: ref.initialCandidates,
      spatialSamples: ref.spatialSamples,
      spatialRadiusPx: ref.spatialRadiusPx,
      temporal: ref.temporal,
      maxHistory: ref.maxHistory,
      visibilityRays: ref.visibilityRays,
      shadeEmissive: ref.shadeEmissive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestirOptions &&
          enabled == other.enabled &&
          initialCandidates == other.initialCandidates &&
          spatialSamples == other.spatialSamples &&
          spatialRadiusPx == other.spatialRadiusPx &&
          temporal == other.temporal &&
          maxHistory == other.maxHistory &&
          visibilityRays == other.visibilityRays &&
          shadeEmissive == other.shadeEmissive;

  @override
  int get hashCode => Object.hash(enabled, initialCandidates, spatialSamples, spatialRadiusPx, temporal, maxHistory, visibilityRays, shadeEmissive);

  @override
  String toString() =>
      'RestirOptions(enabled: $enabled, initialCandidates: $initialCandidates, spatialSamples: $spatialSamples, '
      'spatialRadiusPx: $spatialRadiusPx, temporal: $temporal, maxHistory: $maxHistory, visibilityRays: $visibilityRays)';
}

/// Counters of the last frame a view rendered with ReSTIR direct lighting.
class RestirStats {
  const RestirStats({required this.lightCount, required this.emissiveTriangleCount, required this.raysPerFrame, required this.gpuTime});

  /// Punctual lights in the light buffer.
  final int lightCount;

  /// Always 0: emissive lights are not implemented.
  final int emissiveTriangleCount;

  /// Visibility rays traced last frame (the pixel count, or 0 without rays).
  final int raysPerFrame;

  /// GPU time of the ReSTIR passes last measured ([Duration.zero] until a timer resolved).
  final Duration gpuTime;

  @override
  String toString() => 'RestirStats(lights: $lightCount, rays: $raysPerFrame, gpu: $gpuTime)';
}
