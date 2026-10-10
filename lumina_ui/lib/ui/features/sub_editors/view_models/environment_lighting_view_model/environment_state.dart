part of '../environment_lighting_view_model.dart';

/// Sky background mode of the level's `LuminaSkyComponent`.
enum EnvironmentSkyMode { color, environment }

/// Immutable snapshot of everything the Environment Lighting mixer edits.
///
/// Persisted twice, on purpose: the sun/sky halves live on the level's
/// `Sun` / `SkyAmbience` actors (component properties, so they serialize like
/// any other actor and PIE picks them up) and the whole state is mirrored
/// under the level payload's `environment` section (`sun` / `sky` /
/// `postProcess`) so the fog and post-process values have a home too.
@immutable
class EnvironmentState {
  // Sun & time of day
  final double timeOfDay;
  final double sunElevationDeg;
  final double sunAzimuthDeg;
  final double sunIntensityLux;
  final double sunKelvin;
  final bool sunColorOverride;
  final String sunColorHex;
  final bool castShadows;
  final bool sunDiscVisible;

  // Sky & ambient
  final EnvironmentSkyMode skyMode;
  final String skyColorHex;
  final String? skyEnvironmentAssetPath;
  final double skyIntensity;
  final double iblIntensity;
  final double skyRotationDeg;
  final bool followTimeOfDay;

  // Height fog (Filament FogOptions)
  final bool fogEnabled;
  final double fogDensity;
  final double fogHeightFalloff;
  final String fogColorHex;

  // Post process
  final double exposure;
  final double bloomIntensity;
  final double bloomThreshold;
  final double vignette;
  final double saturation;
  final double contrast;
  final double gamma;

  const EnvironmentState({
    required this.timeOfDay,
    required this.sunElevationDeg,
    required this.sunAzimuthDeg,
    required this.sunIntensityLux,
    required this.sunKelvin,
    required this.sunColorOverride,
    required this.sunColorHex,
    required this.castShadows,
    required this.sunDiscVisible,
    required this.skyMode,
    required this.skyColorHex,
    required this.skyEnvironmentAssetPath,
    required this.skyIntensity,
    required this.iblIntensity,
    required this.skyRotationDeg,
    required this.followTimeOfDay,
    required this.fogEnabled,
    required this.fogDensity,
    required this.fogHeightFalloff,
    required this.fogColorHex,
    required this.exposure,
    required this.bloomIntensity,
    required this.bloomThreshold,
    required this.vignette,
    required this.saturation,
    required this.contrast,
    required this.gamma,
  });

  static const double defaultTimeOfDay = 14.5;
  static const double defaultSunIntensityLux = 100000.0;
  static const double defaultSunKelvin = 6500.0;
  static const double defaultSkyIntensity = 30000.0;
  static const double defaultIblIntensity = 30000.0;
  static const String defaultSkyColorHex = '#5C7FB8';
  static const String defaultFogColorHex = '#B8C4D6';

  /// A 0–8 bloom scale; Filament's strength is 0–1.
  static const double bloomIntensityMax = 8.0;

  /// The world is in centimetres; the fog sliders are per metre,
  /// so Filament's per-unit density / height falloff are divided by this.
  static const double worldUnitsPerMetre = LuminaUnits.unitsPerMetre;

  /// Documented defaults: 100 000 lux, 6500 K, no fog, Filament's bloom.
  factory EnvironmentState.defaults() {
    final angles = SolarMath.anglesForTime(defaultTimeOfDay);
    return EnvironmentState(
      timeOfDay: defaultTimeOfDay,
      sunElevationDeg: angles.elevation,
      sunAzimuthDeg: angles.azimuth,
      sunIntensityLux: defaultSunIntensityLux,
      sunKelvin: defaultSunKelvin,
      sunColorOverride: false,
      sunColorHex: SolarMath.rgbToHex(SolarMath.kelvinToRgb(defaultSunKelvin)),
      castShadows: true,
      sunDiscVisible: true,
      skyMode: EnvironmentSkyMode.color,
      skyColorHex: defaultSkyColorHex,
      skyEnvironmentAssetPath: null,
      skyIntensity: defaultSkyIntensity,
      iblIntensity: defaultIblIntensity,
      skyRotationDeg: 0.0,
      followTimeOfDay: false,
      fogEnabled: false,
      fogDensity: 0.0,
      fogHeightFalloff: 1.0,
      fogColorHex: defaultFogColorHex,
      exposure: 0.0,
      bloomIntensity: LuminaPostProcessSettings.standard().bloom.strength * bloomIntensityMax,
      bloomThreshold: LuminaPostProcessSettings.standard().bloom.highlight,
      vignette: 0.0,
      saturation: 1.0,
      contrast: 1.0,
      gamma: 1.0,
    );
  }

  EnvironmentState copyWith({
    double? timeOfDay,
    double? sunElevationDeg,
    double? sunAzimuthDeg,
    double? sunIntensityLux,
    double? sunKelvin,
    bool? sunColorOverride,
    String? sunColorHex,
    bool? castShadows,
    bool? sunDiscVisible,
    EnvironmentSkyMode? skyMode,
    String? skyColorHex,
    Object? skyEnvironmentAssetPath = _unset,
    double? skyIntensity,
    double? iblIntensity,
    double? skyRotationDeg,
    bool? followTimeOfDay,
    bool? fogEnabled,
    double? fogDensity,
    double? fogHeightFalloff,
    String? fogColorHex,
    double? exposure,
    double? bloomIntensity,
    double? bloomThreshold,
    double? vignette,
    double? saturation,
    double? contrast,
    double? gamma,
  }) {
    return EnvironmentState(
      timeOfDay: timeOfDay ?? this.timeOfDay,
      sunElevationDeg: sunElevationDeg ?? this.sunElevationDeg,
      sunAzimuthDeg: sunAzimuthDeg ?? this.sunAzimuthDeg,
      sunIntensityLux: sunIntensityLux ?? this.sunIntensityLux,
      sunKelvin: sunKelvin ?? this.sunKelvin,
      sunColorOverride: sunColorOverride ?? this.sunColorOverride,
      sunColorHex: sunColorHex ?? this.sunColorHex,
      castShadows: castShadows ?? this.castShadows,
      sunDiscVisible: sunDiscVisible ?? this.sunDiscVisible,
      skyMode: skyMode ?? this.skyMode,
      skyColorHex: skyColorHex ?? this.skyColorHex,
      skyEnvironmentAssetPath: identical(skyEnvironmentAssetPath, _unset)
          ? this.skyEnvironmentAssetPath
          : skyEnvironmentAssetPath as String?,
      skyIntensity: skyIntensity ?? this.skyIntensity,
      iblIntensity: iblIntensity ?? this.iblIntensity,
      skyRotationDeg: skyRotationDeg ?? this.skyRotationDeg,
      followTimeOfDay: followTimeOfDay ?? this.followTimeOfDay,
      fogEnabled: fogEnabled ?? this.fogEnabled,
      fogDensity: fogDensity ?? this.fogDensity,
      fogHeightFalloff: fogHeightFalloff ?? this.fogHeightFalloff,
      fogColorHex: fogColorHex ?? this.fogColorHex,
      exposure: exposure ?? this.exposure,
      bloomIntensity: bloomIntensity ?? this.bloomIntensity,
      bloomThreshold: bloomThreshold ?? this.bloomThreshold,
      vignette: vignette ?? this.vignette,
      saturation: saturation ?? this.saturation,
      contrast: contrast ?? this.contrast,
      gamma: gamma ?? this.gamma,
    );
  }

  static const Object _unset = Object();

  /// The light colour actually sent to the engine: the Kelvin ramp unless a
  /// manual override is active.
  Vector3 get effectiveSunColor => sunColorOverride ? SolarMath.hexToRgb(sunColorHex) : SolarMath.kelvinToRgb(sunKelvin);

  String get effectiveSunColorHex => SolarMath.rgbToHex(effectiveSunColor);

  /// Unit light direction (Y-up), the final value the runtime consumes.
  Vector3 get sunDirection => SolarMath.lightDirection(sunElevationDeg, sunAzimuthDeg);

  /// Editor Euler rotation stored on the Sun actor.
  List<double> get sunEuler => SolarMath.eulerForAngles(sunElevationDeg, sunAzimuthDeg);

  /// Maps the mixer's controls onto the real lumina post-process settings.
  ///
  /// Honest mapping notes: fog density / height falloff are per metre and
  /// converted to the level's centimetre units ([worldUnitsPerMetre]); bloom
  /// "intensity" 0–8 scales Filament's 0–1 `strength`; "threshold" is
  /// Filament's `highlight` (lux); vignette 0–1 pulls `midPoint` inward;
  /// gamma is applied as the shadow gamma of the colour-grading curves.
  LuminaPostProcessSettings toPostProcessSettings({LuminaPostProcessSettings? base}) {
    final b = base ?? LuminaPostProcessSettings.standard();
    final fogColor = SolarMath.hexToRgb(fogColorHex);
    final v = vignette.clamp(0.0, 1.0);
    final grade = b.colorGrade.copyWith(
      exposure: exposure,
      saturation: saturation,
      contrast: contrast,
      curves: (Vector3.all(gamma), Vector3.all(1.0), Vector3.all(1.0)),
    );
    return b.copyWith(
      fog: b.fog.copyWith(
        enabled: fogEnabled,
        density: fogDensity / worldUnitsPerMetre,
        heightFalloff: fogHeightFalloff / worldUnitsPerMetre,
        colorR: fogColor.x,
        colorG: fogColor.y,
        colorB: fogColor.z,
      ),
      bloom: b.bloom.copyWith(
        enabled: bloomIntensity > 0.0,
        strength: (bloomIntensity / bloomIntensityMax).clamp(0.0, 1.0),
        highlight: bloomThreshold,
      ),
      vignette: b.vignette.copyWith(
        enabled: v > 0.0,
        midPoint: (1.0 - v * 0.9).clamp(0.05, 1.0),
      ),
      colorGrade: grade,
    );
  }

  // --- Serialization -----------------------------------------------------

  Map<String, dynamic> get sunProperties => {
        'timeOfDay': timeOfDay,
        'elevationDeg': sunElevationDeg,
        'azimuthDeg': sunAzimuthDeg,
        'direction': [sunDirection.x, sunDirection.y, sunDirection.z],
        'intensity': sunIntensityLux,
        'kelvin': sunKelvin,
        'colorOverride': sunColorOverride,
        'colorHex': sunColorHex,
        'effectiveColorHex': effectiveSunColorHex,
        'castShadows': castShadows,
        'isSun': true,
      };

  Map<String, dynamic> get skyProperties => {
        'mode': skyMode.name,
        'colorHex': skyColorHex,
        'sky_environment': skyMode == EnvironmentSkyMode.environment && skyEnvironmentAssetPath != null
            ? {'slot_name': 'sky_environment', 'asset_id': '', 'asset_path': skyEnvironmentAssetPath}
            : null,
        'skyIntensity': skyIntensity,
        'iblIntensity': iblIntensity,
        'rotationDegrees': skyRotationDeg,
        'showSun': sunDiscVisible,
        'followTimeOfDay': followTimeOfDay,
      };

  Map<String, dynamic> get postProcessProperties => {
        'fogEnabled': fogEnabled,
        'fogDensity': fogDensity,
        'fogHeightFalloff': fogHeightFalloff,
        'fogColorHex': fogColorHex,
        'exposure': exposure,
        'bloomIntensity': bloomIntensity,
        'bloomThreshold': bloomThreshold,
        'vignette': vignette,
        'saturation': saturation,
        'contrast': contrast,
        'gamma': gamma,
      };

  /// The level payload's `environment` section.
  Map<String, dynamic> toSection() => {
        'version': 1,
        'sun': sunProperties,
        'sky': skyProperties,
        'postProcess': postProcessProperties,
      };

  static double _d(Map<String, dynamic>? m, String key, double fallback) {
    final v = m?[key];
    return v is num ? v.toDouble() : fallback;
  }

  static bool _b(Map<String, dynamic>? m, String key, bool fallback) {
    final v = m?[key];
    return v is bool ? v : fallback;
  }

  static String _s(Map<String, dynamic>? m, String key, String fallback) {
    final v = m?[key];
    return v is String && v.isNotEmpty ? v : fallback;
  }

  /// Rebuilds the state from the three sub-maps (each may be null/partial).
  factory EnvironmentState.fromMaps({
    Map<String, dynamic>? sun,
    Map<String, dynamic>? sky,
    Map<String, dynamic>? postProcess,
  }) {
    final d = EnvironmentState.defaults();
    final time = _d(sun, 'timeOfDay', d.timeOfDay);
    final arc = SolarMath.anglesForTime(time);
    final modeName = _s(sky, 'mode', d.skyMode.name);
    final mode = EnvironmentSkyMode.values.firstWhere((m) => m.name == modeName, orElse: () => d.skyMode);
    String? envPath;
    final ref = sky?['sky_environment'];
    if (ref is Map && ref['asset_path'] is String && (ref['asset_path'] as String).isNotEmpty) {
      envPath = ref['asset_path'] as String;
    }
    return EnvironmentState(
      timeOfDay: time,
      sunElevationDeg: _d(sun, 'elevationDeg', arc.elevation),
      sunAzimuthDeg: _d(sun, 'azimuthDeg', arc.azimuth),
      sunIntensityLux: _d(sun, 'intensity', d.sunIntensityLux),
      sunKelvin: _d(sun, 'kelvin', d.sunKelvin),
      sunColorOverride: _b(sun, 'colorOverride', d.sunColorOverride),
      sunColorHex: _s(sun, 'colorHex', d.sunColorHex),
      castShadows: _b(sun, 'castShadows', d.castShadows),
      sunDiscVisible: _b(sky, 'showSun', d.sunDiscVisible),
      skyMode: mode,
      skyColorHex: _s(sky, 'colorHex', d.skyColorHex),
      skyEnvironmentAssetPath: mode == EnvironmentSkyMode.environment ? envPath : null,
      skyIntensity: _d(sky, 'skyIntensity', d.skyIntensity),
      iblIntensity: _d(sky, 'iblIntensity', d.iblIntensity),
      skyRotationDeg: _d(sky, 'rotationDegrees', d.skyRotationDeg),
      followTimeOfDay: _b(sky, 'followTimeOfDay', d.followTimeOfDay),
      fogEnabled: _b(postProcess, 'fogEnabled', d.fogEnabled),
      fogDensity: _d(postProcess, 'fogDensity', d.fogDensity),
      fogHeightFalloff: _d(postProcess, 'fogHeightFalloff', d.fogHeightFalloff),
      fogColorHex: _s(postProcess, 'fogColorHex', d.fogColorHex),
      exposure: _d(postProcess, 'exposure', d.exposure),
      bloomIntensity: _d(postProcess, 'bloomIntensity', d.bloomIntensity),
      bloomThreshold: _d(postProcess, 'bloomThreshold', d.bloomThreshold),
      vignette: _d(postProcess, 'vignette', d.vignette),
      saturation: _d(postProcess, 'saturation', d.saturation),
      contrast: _d(postProcess, 'contrast', d.contrast),
      gamma: _d(postProcess, 'gamma', d.gamma),
    );
  }

  factory EnvironmentState.fromSection(Map<String, dynamic> section) {
    Map<String, dynamic>? sub(String key) {
      final v = section[key];
      return v is Map ? Map<String, dynamic>.from(v) : null;
    }

    return EnvironmentState.fromMaps(sun: sub('sun'), sky: sub('sky'), postProcess: sub('postProcess'));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnvironmentState &&
          timeOfDay == other.timeOfDay &&
          sunElevationDeg == other.sunElevationDeg &&
          sunAzimuthDeg == other.sunAzimuthDeg &&
          sunIntensityLux == other.sunIntensityLux &&
          sunKelvin == other.sunKelvin &&
          sunColorOverride == other.sunColorOverride &&
          sunColorHex == other.sunColorHex &&
          castShadows == other.castShadows &&
          sunDiscVisible == other.sunDiscVisible &&
          skyMode == other.skyMode &&
          skyColorHex == other.skyColorHex &&
          skyEnvironmentAssetPath == other.skyEnvironmentAssetPath &&
          skyIntensity == other.skyIntensity &&
          iblIntensity == other.iblIntensity &&
          skyRotationDeg == other.skyRotationDeg &&
          followTimeOfDay == other.followTimeOfDay &&
          fogEnabled == other.fogEnabled &&
          fogDensity == other.fogDensity &&
          fogHeightFalloff == other.fogHeightFalloff &&
          fogColorHex == other.fogColorHex &&
          exposure == other.exposure &&
          bloomIntensity == other.bloomIntensity &&
          bloomThreshold == other.bloomThreshold &&
          vignette == other.vignette &&
          saturation == other.saturation &&
          contrast == other.contrast &&
          gamma == other.gamma;

  @override
  int get hashCode => Object.hashAll([
        timeOfDay,
        sunElevationDeg,
        sunAzimuthDeg,
        sunIntensityLux,
        sunKelvin,
        sunColorOverride,
        sunColorHex,
        castShadows,
        sunDiscVisible,
        skyMode,
        skyColorHex,
        skyEnvironmentAssetPath,
        skyIntensity,
        iblIntensity,
        skyRotationDeg,
        followTimeOfDay,
        fogEnabled,
        fogDensity,
        fogHeightFalloff,
        fogColorHex,
        exposure,
        bloomIntensity,
        bloomThreshold,
        vignette,
        saturation,
        contrast,
        gamma,
      ]);

  @override
  String toString() => 'EnvironmentState(${toSection()})';
}
