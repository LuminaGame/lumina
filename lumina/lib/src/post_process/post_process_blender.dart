import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/environment/exponential_height_fog_component.dart';
import 'package:lumina/src/post_process/post_process_settings.dart';

/// Post-process volume blending on top of Filament's single
/// per-`View` post-processing state.
///
/// Filament has no notion of volumes: one `View` carries one set of options.
/// The blender is the missing layer, in Dart and pure: it starts from the
/// **baseline** (whatever the game or the editor last applied directly),
/// overlays the level's height fog ([LuminaHeightFogSettings]),
/// then walks every registered [LuminaPostProcessVolume] that contains the
/// camera — unbound volumes always — in **priority** order, lerping towards
/// each volume's [LuminaPostProcessOverrides] by its **blend weight** times a
/// **blend-radius** falloff (1 inside, 0 at `blendRadius` outside the shape).
/// The honest limit is that Filament blends the whole view by camera position, never per pixel.
class LuminaPostProcessBlender {
  /// The settings volumes blend from. Set by every direct
  /// `LuminaPostProcessController.apply` (game code, scalability, the editor).
  LuminaPostProcessSettings baseline = LuminaPostProcessSettings.standard();

  /// The level's Exponential Height Fog, or null when the
  /// level has no fog actor: then the baseline's fog stays.
  LuminaHeightFogSettings? heightFog;

  /// Who published [heightFog] (for the "one per level" rule).
  Object? heightFogOwner;

  final List<LuminaPostProcessVolume> _volumes = [];

  /// Registered volumes, in registration order.
  List<LuminaPostProcessVolume> get volumes => List.unmodifiable(_volumes);

  /// Where the camera is when the world has no active camera component
  /// (the editor viewport's eye; runtime axes).
  Vector3? cameraPositionOverride;

  void addVolume(LuminaPostProcessVolume volume) {
    if (!_volumes.contains(volume)) _volumes.add(volume);
  }

  void removeVolume(LuminaPostProcessVolume volume) => _volumes.remove(volume);

  void clearVolumes() => _volumes.clear();

  /// Publishes the height fog from [owner]; a different live owner is
  /// replaced (last one wins — Filament has one fog per view).
  void setHeightFog(LuminaHeightFogSettings? fog, {required Object owner}) {
    heightFog = fog;
    heightFogOwner = fog == null ? null : owner;
  }

  /// Clears the height fog if [owner] published it.
  void clearHeightFogOf(Object owner) {
    if (identical(heightFogOwner, owner)) {
      heightFog = null;
      heightFogOwner = null;
    }
  }

  /// The settings for a camera at [cameraWorld] (runtime axes). With no
  /// camera position only unbound volumes apply.
  LuminaPostProcessResult resolve(Vector3? cameraWorld) {
    var settings = baseline;
    final fog = heightFog;
    if (fog != null) settings = settings.copyWith(fog: fog.toFogOptions(settings.fog));
    if (_volumes.isEmpty) return LuminaPostProcessResult(settings, null);

    final resolved = LuminaPostProcessResolved.fromSettings(settings);
    double? focusDistance;
    // Stable sort by priority ascending: the highest priority is applied last
    // and therefore wins.
    final ordered = List<LuminaPostProcessVolume>.from(_volumes)
      ..sort((a, b) => a.priority.compareTo(b.priority));
    var touched = false;
    for (final v in ordered) {
      if (!v.enabled) continue;
      final w = (v.weightFor(cameraWorld) * v.blendWeight).clamp(0.0, 1.0);
      if (w <= 0) continue;
      v.overrides.lerpOnto(resolved, w);
      if (v.overrides.dofFocusDistance != null) {
        focusDistance = _lerp(focusDistance ?? v.overrides.dofFocusDistance!, v.overrides.dofFocusDistance!, w);
      }
      touched = true;
    }
    if (!touched) return LuminaPostProcessResult(settings, null);
    return LuminaPostProcessResult(resolved.applyTo(settings), focusDistance);
  }
}

/// What [LuminaPostProcessBlender.resolve] produces: the view settings and,
/// when a volume overrides depth-of-field focus, the camera focus distance
/// (a `FilamentCamera` property, not a view option).
class LuminaPostProcessResult {
  const LuminaPostProcessResult(this.settings, this.focusDistance);
  final LuminaPostProcessSettings settings;
  final double? focusDistance;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// A volume's overrides: every field `null` means "not overridden", so it
/// leaves the blended state alone (the per-setting override checkbox).
class LuminaPostProcessOverrides {
  const LuminaPostProcessOverrides({
    this.bloomIntensity,
    this.bloomThreshold,
    this.vignette,
    this.depthOfFieldEnabled,
    this.dofFocusDistance,
    this.dofAperture,
    this.ambientOcclusionEnabled,
    this.ambientOcclusionIntensity,
    this.exposure,
    this.contrast,
    this.saturation,
    this.temperature,
    this.taaEnabled,
    this.fogDensityScale,
    this.fogColor,
  });

  /// 0–8, the Environment editor's scale (Filament strength × 8).
  final double? bloomIntensity;

  /// Filament's bloom `highlight`, lux.
  final double? bloomThreshold;

  /// 0..1; pulls Filament's vignette `midPoint` inward.
  final double? vignette;
  final bool? depthOfFieldEnabled;

  /// Camera focus distance, cm.
  final double? dofFocusDistance;

  /// Filament's DoF `cocScale` (0..2).
  final double? dofAperture;
  final bool? ambientOcclusionEnabled;

  /// Filament's AO `intensity` (0..4).
  final double? ambientOcclusionIntensity;

  /// Exposure compensation, EV.
  final double? exposure;
  final double? contrast;
  final double? saturation;

  /// White-balance temperature, −1 (cool) .. 1 (warm).
  final double? temperature;
  final bool? taaEnabled;

  /// Multiplies the fog density (a Local Fog Volume's way in).
  final double? fogDensityScale;
  final Vector3? fogColor;

  /// The editor component's property keys, each guarded by an
  /// `override<Name>` boolean (the override checkbox).
  static const List<String> keys = [
    'bloomIntensity',
    'bloomThreshold',
    'vignette',
    'depthOfFieldEnabled',
    'dofFocusDistance',
    'dofAperture',
    'ambientOcclusionEnabled',
    'ambientOcclusionIntensity',
    'exposure',
    'contrast',
    'saturation',
    'temperature',
    'taaEnabled',
  ];

  static String overrideKey(String key) => 'override${key[0].toUpperCase()}${key.substring(1)}';

  /// Reads the editor properties: a value counts only when its
  /// `override<Name>` flag is true.
  factory LuminaPostProcessOverrides.fromProperties(Map<String, dynamic> p) {
    bool on(String key) => p[overrideKey(key)] == true;
    double? num_(String key) => on(key) && p[key] is num ? (p[key] as num).toDouble() : null;
    bool? bool_(String key) => on(key) && p[key] is bool ? p[key] as bool : null;
    return LuminaPostProcessOverrides(
      bloomIntensity: num_('bloomIntensity'),
      bloomThreshold: num_('bloomThreshold'),
      vignette: num_('vignette'),
      depthOfFieldEnabled: bool_('depthOfFieldEnabled'),
      dofFocusDistance: num_('dofFocusDistance'),
      dofAperture: num_('dofAperture'),
      ambientOcclusionEnabled: bool_('ambientOcclusionEnabled'),
      ambientOcclusionIntensity: num_('ambientOcclusionIntensity'),
      exposure: num_('exposure'),
      contrast: num_('contrast'),
      saturation: num_('saturation'),
      temperature: num_('temperature'),
      taaEnabled: bool_('taaEnabled'),
    );
  }

  /// The editor properties: values plus their `override<Name>` flags.
  Map<String, dynamic> toProperties() {
    final out = <String, dynamic>{};
    void put(String key, Object? v) {
      out[overrideKey(key)] = v != null;
      if (v != null) out[key] = v;
    }

    put('bloomIntensity', bloomIntensity);
    put('bloomThreshold', bloomThreshold);
    put('vignette', vignette);
    put('depthOfFieldEnabled', depthOfFieldEnabled);
    put('dofFocusDistance', dofFocusDistance);
    put('dofAperture', dofAperture);
    put('ambientOcclusionEnabled', ambientOcclusionEnabled);
    put('ambientOcclusionIntensity', ambientOcclusionIntensity);
    put('exposure', exposure);
    put('contrast', contrast);
    put('saturation', saturation);
    put('temperature', temperature);
    put('taaEnabled', taaEnabled);
    return out;
  }

  bool get isEmpty =>
      bloomIntensity == null &&
      bloomThreshold == null &&
      vignette == null &&
      depthOfFieldEnabled == null &&
      dofFocusDistance == null &&
      dofAperture == null &&
      ambientOcclusionEnabled == null &&
      ambientOcclusionIntensity == null &&
      exposure == null &&
      contrast == null &&
      saturation == null &&
      temperature == null &&
      taaEnabled == null &&
      fogDensityScale == null &&
      fogColor == null;

  /// Lerps [current] towards these overrides by [weight]; booleans switch
  /// once the weight reaches one half.
  void lerpOnto(LuminaPostProcessResolved current, double weight) {
    final t = weight.clamp(0.0, 1.0);
    if (bloomIntensity != null) current.bloomIntensity = _lerp(current.bloomIntensity, bloomIntensity!, t);
    if (bloomThreshold != null) current.bloomThreshold = _lerp(current.bloomThreshold, bloomThreshold!, t);
    if (vignette != null) current.vignette = _lerp(current.vignette, vignette!, t);
    if (depthOfFieldEnabled != null && t >= 0.5) current.depthOfFieldEnabled = depthOfFieldEnabled!;
    if (dofAperture != null) current.dofAperture = _lerp(current.dofAperture, dofAperture!, t);
    if (ambientOcclusionEnabled != null && t >= 0.5) current.ambientOcclusionEnabled = ambientOcclusionEnabled!;
    if (ambientOcclusionIntensity != null) {
      current.ambientOcclusionIntensity = _lerp(current.ambientOcclusionIntensity, ambientOcclusionIntensity!, t);
    }
    if (exposure != null) current.exposure = _lerp(current.exposure, exposure!, t);
    if (contrast != null) current.contrast = _lerp(current.contrast, contrast!, t);
    if (saturation != null) current.saturation = _lerp(current.saturation, saturation!, t);
    if (temperature != null) current.temperature = _lerp(current.temperature, temperature!, t);
    if (taaEnabled != null && t >= 0.5) current.taaEnabled = taaEnabled!;
    if (fogDensityScale != null) current.fogDensityScale = _lerp(current.fogDensityScale, fogDensityScale!, t);
    if (fogColor != null) current.fogColor = current.fogColor + (fogColor! - current.fogColor) * t;
  }
}

/// The mutable numeric state the blender lerps, in the editor's units, built
/// from a [LuminaPostProcessSettings] and written back with the exact
/// mappings the Environment editor and the code generator already use.
class LuminaPostProcessResolved {
  LuminaPostProcessResolved({
    required this.bloomIntensity,
    required this.bloomThreshold,
    required this.vignette,
    required this.depthOfFieldEnabled,
    required this.dofAperture,
    required this.ambientOcclusionEnabled,
    required this.ambientOcclusionIntensity,
    required this.exposure,
    required this.contrast,
    required this.saturation,
    required this.temperature,
    required this.taaEnabled,
    required this.fogDensityScale,
    required this.fogColor,
  });

  /// A 0–8 bloom scale over Filament's 0–1 `strength`.
  static const double bloomIntensityMax = 8.0;

  double bloomIntensity;
  double bloomThreshold;
  double vignette;
  bool depthOfFieldEnabled;
  double dofAperture;
  bool ambientOcclusionEnabled;
  double ambientOcclusionIntensity;
  double exposure;
  double contrast;
  double saturation;
  double temperature;
  bool taaEnabled;
  double fogDensityScale;
  Vector3 fogColor;

  factory LuminaPostProcessResolved.fromSettings(LuminaPostProcessSettings s) => LuminaPostProcessResolved(
        bloomIntensity: s.bloom.enabled ? s.bloom.strength * bloomIntensityMax : 0.0,
        bloomThreshold: s.bloom.highlight,
        vignette: s.vignette.enabled ? ((1.0 - s.vignette.midPoint) / 0.9).clamp(0.0, 1.0) : 0.0,
        depthOfFieldEnabled: s.depthOfField.enabled,
        dofAperture: s.depthOfField.cocScale,
        ambientOcclusionEnabled: s.ambientOcclusion.enabled,
        ambientOcclusionIntensity: s.ambientOcclusion.intensity,
        exposure: s.colorGrade.exposure,
        contrast: s.colorGrade.contrast,
        saturation: s.colorGrade.saturation,
        temperature: s.colorGrade.whiteBalance.$1,
        taaEnabled: s.taa.enabled,
        fogDensityScale: 1.0,
        fogColor: Vector3(s.fog.colorR, s.fog.colorG, s.fog.colorB),
      );

  /// Writes this state onto [base].
  LuminaPostProcessSettings applyTo(LuminaPostProcessSettings base) {
    final v = vignette.clamp(0.0, 1.0);
    return base.copyWith(
      bloom: base.bloom.copyWith(
        enabled: bloomIntensity > 0.0,
        strength: (bloomIntensity / bloomIntensityMax).clamp(0.0, 1.0),
        highlight: bloomThreshold,
      ),
      vignette: base.vignette.copyWith(enabled: v > 0.0, midPoint: (1.0 - v * 0.9).clamp(0.05, 1.0)),
      depthOfField: base.depthOfField.copyWith(enabled: depthOfFieldEnabled, cocScale: dofAperture),
      ambientOcclusion: base.ambientOcclusion.copyWith(
        enabled: ambientOcclusionEnabled,
        intensity: ambientOcclusionIntensity,
      ),
      taa: base.taa.copyWith(enabled: taaEnabled),
      colorGrade: base.colorGrade.copyWith(
        exposure: exposure,
        contrast: contrast,
        saturation: saturation,
        whiteBalance: (temperature.clamp(-1.0, 1.0), base.colorGrade.whiteBalance.$2),
      ),
      fog: base.fog.copyWith(
        density: base.fog.density * fogDensityScale,
        colorR: fogColor.x,
        colorG: fogColor.y,
        colorB: fogColor.z,
      ),
    );
  }
}

/// The shape the blender evaluates: an oriented box (or sphere) in runtime
/// axes, or unbound. [worldTransform] carries the actor's rotation and scale
/// (the half extent is scaled by it).
class LuminaPostProcessVolume {
  LuminaPostProcessVolume({
    this.enabled = true,
    this.unbound = false,
    this.priority = 0.0,
    this.blendRadius = 100.0,
    this.blendWeight = 1.0,
    this.overrides = const LuminaPostProcessOverrides(),
    Matrix4? worldTransform,
    Vector3? halfExtent,
    this.sphereRadius,
    this.owner,
  })  : worldTransform = worldTransform ?? Matrix4.identity(),
        halfExtent = halfExtent ?? Vector3.all(400.0);

  bool enabled;
  bool unbound;
  double priority;

  /// Falloff distance outside the shape, cm (Blend Radius).
  double blendRadius;

  /// 0..1 (Blend Weight).
  double blendWeight;
  LuminaPostProcessOverrides overrides;

  /// The actor's world matrix (rotation, position, scale).
  Matrix4 worldTransform;

  /// Half size, cm, before [worldTransform]'s scale.
  Vector3 halfExtent;

  /// When set the shape is a sphere of this radius (cm, unscaled).
  double? sphereRadius;

  /// Whatever registered this volume (a component, the editor).
  Object? owner;

  /// Signed distance from the shape surface (negative inside), cm, in
  /// world units; `null` for an unbound volume.
  double? surfaceDistance(Vector3 world) {
    if (unbound) return null;
    // Rotation and translation move the point into the volume's frame; the
    // matrix' scale grows the shape instead, so the
    // distance stays in centimetres.
    final translation = Vector3.zero();
    final rotation = Quaternion.identity();
    final scale = Vector3.zero();
    worldTransform.decompose(translation, rotation, scale);
    final local = rotation.inverted().rotate(world - translation);
    if (sphereRadius != null) {
      final r = sphereRadius! * math.max(scale.x, math.max(scale.y, scale.z));
      return local.length - r;
    }
    final dx = local.x.abs() - halfExtent.x * scale.x;
    final dy = local.y.abs() - halfExtent.y * scale.y;
    final dz = local.z.abs() - halfExtent.z * scale.z;
    final outside = Vector3(math.max(dx, 0), math.max(dy, 0), math.max(dz, 0));
    final inside = math.min(math.max(dx, math.max(dy, dz)), 0.0);
    return outside.length + inside;
  }

  bool containsPoint(Vector3 world) {
    final d = surfaceDistance(world);
    return d == null || d <= 0;
  }

  /// 1 inside, falling linearly to 0 over [blendRadius] outside; unbound → 1;
  /// no camera → only unbound volumes count.
  double weightFor(Vector3? cameraWorld) {
    if (unbound) return 1.0;
    if (cameraWorld == null) return 0.0;
    final d = surfaceDistance(cameraWorld)!;
    if (d <= 0) return 1.0;
    if (blendRadius <= 0) return 0.0;
    return (1.0 - d / blendRadius).clamp(0.0, 1.0);
  }
}
