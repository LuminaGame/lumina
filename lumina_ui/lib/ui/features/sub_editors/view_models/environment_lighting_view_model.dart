import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/commands/editor_transaction.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/solar_math.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/environment_preview_scene.dart';

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

/// View model of the Environment Lighting mixer.
///
/// Owns the [EnvironmentState], finds-or-creates the level's environment
/// actors on [open], writes every committed edit through to those actors and
/// the level's `environment` section (marking the level dirty so auto-save
/// picks it up), records one undo transaction per gesture on the editor's
/// [TransactionManager], and pushes live values into the attached
/// [EnvironmentPreviewScene] (a real lumina world on the sub-editor viewport).
class EnvironmentLightingViewModel extends ChangeNotifier {
  final EditorViewModel editor;
  final EnvironmentPreviewScene preview;

  EnvironmentState _state = EnvironmentState.defaults();
  EnvironmentState? _gestureStart;
  EditorActorNode? _sunActor;
  EditorActorNode? _skyActor;
  bool _dirty = false;
  bool _opened = false;
  bool _disposed = false;

  /// The level the tab shows (it follows a level switch).
  String? _level;

  static const String sunActorName = 'Sun';
  static const String skyActorName = 'SkyAmbience';
  static const String sunComponentType = 'LuminaDirectionalLightComponent';
  static const String skyComponentType = 'LuminaSkyComponent';
  static const Set<String> sunActorTypes = {'Light', 'DirectionalLight'};
  static const String skyActorType = 'Environment';

  EnvironmentLightingViewModel({required this.editor, EnvironmentPreviewScene? preview})
      : preview = preview ?? EnvironmentPreviewScene();

  EnvironmentState get state => _state;
  bool get isDirty => _dirty;
  bool get isOpened => _opened;
  EditorActorNode? get sunActor => _sunActor;
  EditorActorNode? get skyActor => _skyActor;
  bool get isPreviewAttached => preview.isAttached;

  Vector3 get effectiveSunColor => _state.effectiveSunColor;
  Vector3 get sunDirection => _state.sunDirection;
  String get timeLabel => '${SolarMath.formatTime(_state.timeOfDay)} — ${SolarMath.dayPhase(_state.timeOfDay)}';

  /// `.ktx` / `.ktx2` environment maps under the project's `contents/`
  /// (relative paths), scanned live from disk.
  List<String> get hdriAssets {
    final contents = Directory('${editor.projectDirPath}/contents');
    if (!contents.existsSync()) return const [];
    final root = editor.projectDirPath;
    final out = <String>[];
    try {
      for (final f in contents.listSync(recursive: true, followLinks: false).whereType<File>()) {
        final lower = f.path.toLowerCase();
        if (lower.endsWith('.ktx') || lower.endsWith('.ktx2')) {
          // Stored in the level, so '/' on every host.
          out.add(f.path.substring(root.length + 1).replaceAll(r'\', '/'));
        }
      }
    } catch (_) {}
    out.sort();
    return out;
  }

  // --- Lifecycle -----------------------------------------------------------

  /// Finds (or creates, as a real undoable level edit) the `Sun` and
  /// `SkyAmbience` actors and loads the persisted state.
  void open() {
    if (_opened) return;
    _opened = true;
    _loadLevel();
    editor.addListener(_onEditorChanged);

    final section = editor.levelEnvironment;
    final created = _ensureActors();
    if (created || section.isEmpty) {
      _syncToEditor();
    }
    preview.apply(_state);
    notifyListeners();
  }

  /// Reads the open level's environment actors and section.
  void _loadLevel() {
    _level = editor.project.activeLevel;
    _sunActor = _firstActor((a) => sunActorTypes.contains(a.type));
    _skyActor = _firstActor((a) => a.type == skyActorType);
    final section = editor.levelEnvironment;
    _state = section.isNotEmpty ? EnvironmentState.fromSection(section) : _stateFromActors(_sunActor, _skyActor);
    _gestureStart = null;
    _dirty = false;
  }

  /// Another level was opened while the tab is open; show that
  /// level. Missing actors are created by the first edit, not by the switch,
  /// so the freshly opened level stays clean.
  void _onEditorChanged() {
    if (_disposed || !_opened || editor.project.activeLevel == _level) return;
    _loadLevel();
    preview.apply(_state);
    notifyListeners();
  }

  /// Creates the `Sun` / `SkyAmbience` actors the level lacks, as undoable
  /// level edits; returns whether it created one.
  bool _ensureActors() {
    var created = false;
    if (_sunActor == null) {
      _sunActor = EditorActorNode(
        id: _uniqueId('act_env_sun'),
        name: sunActorName,
        type: 'DirectionalLight',
        // Stored Z-up: 5 m above the origin.
        location: [0.0, 0.0, 500.0],
        rotation: _state.sunEuler,
        lightIntensity: _state.sunIntensityLux,
        lightColorHex: _state.effectiveSunColorHex,
        castShadows: _state.castShadows,
        mobility: 'Stationary',
      );
      editor.addActorNode(_sunActor!, label: 'Create $sunActorName');
      created = true;
    }
    if (_skyActor == null) {
      _skyActor = EditorActorNode(
        id: _uniqueId('act_env_sky'),
        name: skyActorName,
        type: skyActorType,
        location: [0.0, 0.0, 0.0],
        mobility: 'Static',
      );
      editor.addActorNode(_skyActor!, label: 'Create $skyActorName');
      created = true;
    }
    return created;
  }

  EditorActorNode? _firstActor(bool Function(EditorActorNode) test) {
    for (final a in editor.actors) {
      if (test(a)) return a;
    }
    return null;
  }

  String _uniqueId(String base) {
    final ids = editor.actors.map((a) => a.id).toSet();
    if (!ids.contains(base)) return base;
    var i = 2;
    while (ids.contains('${base}_$i')) {
      i++;
    }
    return '${base}_$i';
  }

  /// Adopts an existing sun/sky pair's authored values when the level has no
  /// `environment` section yet (legacy levels, starter template).
  EnvironmentState _stateFromActors(EditorActorNode? sun, EditorActorNode? sky) {
    Map<String, dynamic>? props(EditorActorNode? actor, String type) {
      if (actor == null) return null;
      for (final c in actor.components) {
        if (c.type == type) return c.properties;
      }
      return null;
    }

    final sunProps = props(sun, sunComponentType);
    final skyProps = props(sky, skyComponentType);
    var s = EnvironmentState.fromMaps(sun: sunProps, sky: skyProps);
    if (sun != null && sunProps == null) {
      // Plain light actor: keep its authored intensity/colour/shadows.
      s = s.copyWith(
        sunIntensityLux: sun.lightIntensity,
        sunColorOverride: true,
        sunColorHex: sun.lightColorHex.toUpperCase(),
        castShadows: sun.castShadows,
      );
    }
    return s;
  }

  // --- Editing -------------------------------------------------------------

  /// Applies [next]. With `commit == false` (continuous slider drag) the
  /// change is previewed live only; the first uncommitted change remembers
  /// the pre-gesture state so the eventual commit becomes one undo step.
  void _update(EnvironmentState next, {required bool commit, required String label}) {
    if (!commit) {
      _gestureStart ??= _state;
      _state = next;
      preview.apply(_state);
      notifyListeners();
      return;
    }
    final before = _gestureStart ?? _state;
    _gestureStart = null;
    _state = next;
    _syncToEditor();
    preview.apply(_state);
    if (before != next) {
      _dirty = true;
      editor.transactions.record(
        EditorTransaction(
          label: label,
          undo: () => _restore(before),
          redo: () => _restore(next),
        ),
      );
    }
    notifyListeners();
  }

  void _restore(EnvironmentState s) {
    _state = s;
    _dirty = true;
    _syncToEditor();
    preview.apply(_state);
    notifyListeners();
  }

  EnvironmentState _withTime(EnvironmentState s, double hours) {
    final t = hours.clamp(0.0, 24.0);
    final arc = SolarMath.anglesForTime(t);
    var rotation = s.skyRotationDeg;
    if (s.followTimeOfDay) {
      rotation = _wrap360(rotation + (arc.azimuth - s.sunAzimuthDeg));
    }
    return s.copyWith(
      timeOfDay: t,
      sunElevationDeg: arc.elevation,
      sunAzimuthDeg: arc.azimuth,
      skyRotationDeg: rotation,
    );
  }

  void setTimeOfDay(double hours, {bool commit = true}) =>
      _update(_withTime(_state, hours), commit: commit, label: 'Sun Time of Day');

  /// Viewport sun gizmo: sets elevation/azimuth directly; the time slider
  /// follows via the azimuth so both stay in sync.
  void setSunFromGizmo(double azimuthDeg, double elevationDeg, {bool commit = true}) {
    final az = _wrap360(azimuthDeg);
    final el = elevationDeg.clamp(-90.0, 90.0);
    var rotation = _state.skyRotationDeg;
    if (_state.followTimeOfDay) {
      rotation = _wrap360(rotation + (az - _state.sunAzimuthDeg));
    }
    _update(
      _state.copyWith(
        timeOfDay: SolarMath.timeForAzimuth(az),
        sunAzimuthDeg: az,
        sunElevationDeg: el,
        skyRotationDeg: rotation,
      ),
      commit: commit,
      label: 'Sun Gizmo',
    );
  }

  void setSunIntensity(double lux, {bool commit = true}) =>
      _update(_state.copyWith(sunIntensityLux: lux.clamp(0.0, 200000.0)), commit: commit, label: 'Sun Intensity');

  void setSunKelvin(double kelvin, {bool commit = true}) =>
      _update(_state.copyWith(sunKelvin: kelvin.clamp(1500.0, 15000.0)), commit: commit, label: 'Sun Temperature');

  void setSunColorOverride(bool enabled) {
    // Seed the manual colour with the current ramp so toggling is seamless.
    final next = _state.copyWith(
      sunColorOverride: enabled,
      sunColorHex: enabled && !_state.sunColorOverride ? _state.effectiveSunColorHex : _state.sunColorHex,
    );
    _update(next, commit: true, label: enabled ? 'Sun Manual Color' : 'Sun Kelvin Ramp');
  }

  void setSunColorHex(String hex, {bool commit = true}) =>
      _update(_state.copyWith(sunColorHex: hex.toUpperCase()), commit: commit, label: 'Sun Color');

  void setCastShadows(bool value) => _update(_state.copyWith(castShadows: value), commit: true, label: 'Sun Cast Shadows');

  void setSunDiscVisible(bool value) => _update(_state.copyWith(sunDiscVisible: value), commit: true, label: 'Sun Disc');

  void setSkyMode(EnvironmentSkyMode mode) {
    _update(
      _state.copyWith(
        skyMode: mode,
        skyEnvironmentAssetPath: mode == EnvironmentSkyMode.environment ? _state.skyEnvironmentAssetPath : null,
      ),
      commit: true,
      label: 'Sky Mode',
    );
  }

  void setSkyColorHex(String hex, {bool commit = true}) =>
      _update(_state.copyWith(skyColorHex: hex.toUpperCase()), commit: commit, label: 'Sky Color');

  void setSkyEnvironmentAsset(String? relativePath) {
    _update(
      _state.copyWith(skyMode: EnvironmentSkyMode.environment, skyEnvironmentAssetPath: relativePath),
      commit: true,
      label: 'Sky Environment',
    );
  }

  void setSkyIntensity(double value, {bool commit = true}) =>
      _update(_state.copyWith(skyIntensity: value.clamp(0.0, 200000.0)), commit: commit, label: 'Sky Intensity');

  void setIblIntensity(double value, {bool commit = true}) =>
      _update(_state.copyWith(iblIntensity: value.clamp(0.0, 200000.0)), commit: commit, label: 'IBL Intensity');

  void setSkyRotation(double degrees, {bool commit = true}) =>
      _update(_state.copyWith(skyRotationDeg: _wrap360(degrees)), commit: commit, label: 'Sky Rotation');

  void setFollowTimeOfDay(bool value) =>
      _update(_state.copyWith(followTimeOfDay: value), commit: true, label: 'Sky Follow Time of Day');

  void setFogEnabled(bool value) => _update(_state.copyWith(fogEnabled: value), commit: true, label: 'Height Fog');

  void setFogDensity(double value, {bool commit = true}) =>
      _update(_state.copyWith(fogDensity: value.clamp(0.0, 0.05)), commit: commit, label: 'Fog Density');

  void setFogHeightFalloff(double value, {bool commit = true}) =>
      _update(_state.copyWith(fogHeightFalloff: value.clamp(0.0, 10.0)), commit: commit, label: 'Fog Height Falloff');

  void setFogColorHex(String hex, {bool commit = true}) =>
      _update(_state.copyWith(fogColorHex: hex.toUpperCase()), commit: commit, label: 'Fog Inscattering Color');

  void setExposure(double value, {bool commit = true}) =>
      _update(_state.copyWith(exposure: value.clamp(-6.0, 6.0)), commit: commit, label: 'Exposure');

  void setBloomIntensity(double value, {bool commit = true}) => _update(
      _state.copyWith(bloomIntensity: value.clamp(0.0, EnvironmentState.bloomIntensityMax)),
      commit: commit,
      label: 'Bloom Intensity');

  void setBloomThreshold(double value, {bool commit = true}) =>
      _update(_state.copyWith(bloomThreshold: value.clamp(1.0, 100000.0)), commit: commit, label: 'Bloom Threshold');

  void setVignette(double value, {bool commit = true}) =>
      _update(_state.copyWith(vignette: value.clamp(0.0, 1.0)), commit: commit, label: 'Vignette');

  void setSaturation(double value, {bool commit = true}) =>
      _update(_state.copyWith(saturation: value.clamp(0.0, 2.0)), commit: commit, label: 'Saturation');

  void setContrast(double value, {bool commit = true}) =>
      _update(_state.copyWith(contrast: value.clamp(0.5, 2.0)), commit: commit, label: 'Contrast');

  void setGamma(double value, {bool commit = true}) =>
      _update(_state.copyWith(gamma: value.clamp(0.2, 3.0)), commit: commit, label: 'Gamma');

  /// Restores the documented defaults as a single undo step.
  void resetToDefaults() {
    _gestureStart = null;
    _update(EnvironmentState.defaults(), commit: true, label: 'Reset Environment');
  }

  // --- Persistence ---------------------------------------------------------

  /// Writes the state onto the level's environment actors and `environment`
  /// section (marks the level dirty; auto-save and Save Level persist it).
  void _syncToEditor() {
    _ensureActors();
    final sun = _sunActor;
    if (sun != null) {
      sun.lightIntensity = _state.sunIntensityLux;
      sun.lightColorHex = _state.effectiveSunColorHex;
      sun.castShadows = _state.castShadows;
      final euler = _state.sunEuler;
      sun.rotation
        ..clear()
        ..addAll(euler);
      _upsertComponent(sun, sunComponentType, 'Directional Light', _state.sunProperties);
    }
    final sky = _skyActor;
    if (sky != null) {
      _upsertComponent(sky, skyComponentType, 'Sky', _state.skyProperties);
    }
    editor.setLevelEnvironment(_state.toSection());
  }

  void _upsertComponent(EditorActorNode actor, String type, String name, Map<String, dynamic> properties) {
    EditorComponentNode? existing;
    for (final c in actor.components) {
      if (c.type == type) {
        existing = c;
        break;
      }
    }
    if (existing == null) {
      existing = EditorComponentNode(id: '${actor.id}_${type.toLowerCase()}', type: type, name: name);
      actor.components.add(existing);
    }
    existing.properties
      ..clear()
      ..addAll(properties);
  }

  /// Saves the level (`.lmas` + generated Dart) through the editor.
  Future<bool> save() async {
    _gestureStart = null;
    _syncToEditor();
    try {
      await editor.saveLevelAndGenerateCode();
    } catch (e) {
      editor.logger.log('Environment save failed: $e', level: 'error', source: 'EnvironmentLighting');
      return false;
    }
    _dirty = false;
    notifyListeners();
    return true;
  }

  // --- Live preview --------------------------------------------------------

  /// Called by the viewport once its lumina world exists on the live engine.
  void attachPreview(LuminaWorld world) {
    preview.attach(
      world,
      levelActors: editor.actors,
      projectDirPath: editor.projectDirPath,
      state: _state,
    );
    notifyListeners();
  }

  /// Called by the viewport right before it cleans the world up.
  void detachPreview(LuminaWorld world) {
    preview.detach();
    notifyListeners();
  }

  static double _wrap360(double degrees) {
    final d = degrees % 360.0;
    return d < 0 ? d + 360.0 : d;
  }

  @override
  void dispose() {
    _disposed = true;
    if (_opened) editor.removeListener(_onEditorChanged);
    preview.detach();
    super.dispose();
  }
}
