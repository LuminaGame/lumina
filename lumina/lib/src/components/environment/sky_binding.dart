import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';

/// Immutable description of a scene's sky background and image-based lighting.
///
/// This is the value type the editor's `Environment` actor speaks: it is
/// parsed straight out of a `LuminaSkyComponent` property map (the map the
/// Environment Lighting sub-editor writes onto the actor and the `.lmas`
/// level file), so the editor viewports, the runtime and the code generator
/// all agree on what a level's sky is.
class LuminaSkyDescription {
  /// Whether the sky comes from an HDRI environment cubemap instead of a
  /// solid colour.
  final bool useEnvironmentMap;

  /// Project-relative path of the `.ktx` environment map, when
  /// [useEnvironmentMap] is set.
  final String? environmentAssetPath;

  /// Solid sky colour (linear RGBA) used when [useEnvironmentMap] is false.
  final Vector4 color;

  /// Skybox intensity in lux.
  final double skyIntensity;

  /// Indirect (ambient / IBL) intensity in lux.
  final double iblIntensity;

  /// Yaw rotation of the environment, in degrees.
  final double rotationDegrees;

  /// Whether the skybox renders the sun disc of the brightest sun light.
  final bool showSun;

  /// Whether the skybox is drawn at all (the IBL still applies when false).
  final bool skyVisible;

  const LuminaSkyDescription({
    this.useEnvironmentMap = false,
    this.environmentAssetPath,
    required this.color,
    this.skyIntensity = 30000.0,
    this.iblIntensity = 30000.0,
    this.rotationDegrees = 0.0,
    this.showSun = false,
    this.skyVisible = true,
  });

  /// The editor's default sky colour (`#5C7FB8`, a daylight zenith blue).
  static Vector4 get defaultColor => colorFromHex('#5C7FB8');

  /// A neutral daylight default used when a level carries no Environment actor.
  static LuminaSkyDescription get defaults =>
      LuminaSkyDescription(color: defaultColor);

  /// A neutral white studio ambient default used for asset previews and sub-editors.
  static LuminaSkyDescription get studioDefaults =>
      LuminaSkyDescription(
        color: Vector4(0.95, 0.95, 0.95, 1.0),
        skyIntensity: 25000.0,
        iblIntensity: 25000.0,
      );

  /// Parses `#RRGGBB` / `#AARRGGBB` into a linear-ish RGBA vector.
  ///
  /// The editor stores sky colours as sRGB hex, and Filament's `Skybox` takes
  /// linear colour, so the channels are converted with the sRGB EOTF.
  static Vector4 colorFromHex(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 8) h = h.substring(2);
    if (h.length != 6) return Vector4(0.36, 0.5, 0.72, 1.0);
    final v = int.tryParse(h, radix: 16);
    if (v == null) return Vector4(0.36, 0.5, 0.72, 1.0);
    double ch(int shift) {
      final s = ((v >> shift) & 0xFF) / 255.0;
      return s <= 0.04045 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    return Vector4(ch(16), ch(8), ch(0), 1.0);
  }

  /// Builds a description from a `LuminaSkyComponent` property map, falling
  /// back to [defaults] for every missing or malformed entry.
  factory LuminaSkyDescription.fromProperties(Map<String, dynamic>? props) {
    final d = LuminaSkyDescription.defaults;
    if (props == null || props.isEmpty) return d;

    double num_(String key, double fallback) {
      final v = props[key];
      return v is num ? v.toDouble() : fallback;
    }

    bool bool_(String key, bool fallback) {
      final v = props[key];
      return v is bool ? v : fallback;
    }

    final mode = props['mode'];
    var useEnv = mode is String && mode == 'environment';

    String? envPath;
    final ref = props['sky_environment'];
    if (ref is Map && ref['asset_path'] is String && (ref['asset_path'] as String).isNotEmpty) {
      envPath = ref['asset_path'] as String;
    } else if (props['environmentAssetPath'] is String &&
        (props['environmentAssetPath'] as String).isNotEmpty) {
      envPath = props['environmentAssetPath'] as String;
    }
    if (envPath == null) useEnv = false;

    final hex = props['colorHex'];
    return LuminaSkyDescription(
      useEnvironmentMap: useEnv,
      environmentAssetPath: envPath,
      color: hex is String && hex.isNotEmpty ? colorFromHex(hex) : d.color,
      skyIntensity: num_('skyIntensity', d.skyIntensity),
      iblIntensity: num_('iblIntensity', d.iblIntensity),
      rotationDegrees: num_('rotationDegrees', d.rotationDegrees),
      showSun: bool_('showSun', d.showSun),
      skyVisible: bool_('visible', d.skyVisible),
    );
  }

  /// Effective RGBA color for the solid-color skybox, scaled by [skyIntensity].
  ///
  /// Filament's solid-color Skybox treats color as clear-color and does not
  /// apply builder intensity to it, so the color channels are scaled by
  /// `skyIntensity / 30000.0` (where 30000 lux is standard daylight intensity).
  Vector4 get effectiveSkyColor {
    final scale = (skyIntensity / 30000.0).clamp(0.0, 10.0);
    return Vector4(
      color.x * scale,
      color.y * scale,
      color.z * scale,
      color.w,
    );
  }

  /// Effective ambient indirect light intensity in lux.
  ///
  /// In color mode, if [skyIntensity] is dimmed, the ambient light
  /// dims proportionally.
  double get effectiveIblIntensity {
    if (useEnvironmentMap) return iblIntensity;
    final factor = (skyIntensity / 30000.0).clamp(0.0, 10.0);
    return iblIntensity * factor;
  }

  LuminaSkyDescription copyWith({
    bool? useEnvironmentMap,
    String? environmentAssetPath,
    Vector4? color,
    double? skyIntensity,
    double? iblIntensity,
    double? rotationDegrees,
    bool? showSun,
    bool? skyVisible,
  }) {
    return LuminaSkyDescription(
      useEnvironmentMap: useEnvironmentMap ?? this.useEnvironmentMap,
      environmentAssetPath: environmentAssetPath ?? this.environmentAssetPath,
      color: color ?? this.color,
      skyIntensity: skyIntensity ?? this.skyIntensity,
      iblIntensity: iblIntensity ?? this.iblIntensity,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      showSun: showSun ?? this.showSun,
      skyVisible: skyVisible ?? this.skyVisible,
    );
  }

  /// Whether [other] needs the native skybox / IBL objects rebuilt rather than
  /// just re-parameterised.
  bool needsRebuildFrom(LuminaSkyDescription other) =>
      useEnvironmentMap != other.useEnvironmentMap ||
      environmentAssetPath != other.environmentAssetPath ||
      showSun != other.showSun ||
      skyIntensity != other.skyIntensity;

  @override
  bool operator ==(Object other) =>
      other is LuminaSkyDescription &&
      other.useEnvironmentMap == useEnvironmentMap &&
      other.environmentAssetPath == environmentAssetPath &&
      other.color == color &&
      other.skyIntensity == skyIntensity &&
      other.iblIntensity == iblIntensity &&
      other.rotationDegrees == rotationDegrees &&
      other.showSun == showSun &&
      other.skyVisible == skyVisible;

  @override
  int get hashCode => Object.hash(useEnvironmentMap, environmentAssetPath, color,
      skyIntensity, iblIntensity, rotationDegrees, showSun, skyVisible);

  @override
  String toString() => 'LuminaSkyDescription(env=$useEnvironmentMap path=$environmentAssetPath '
      'color=$color sky=$skyIntensity ibl=$iblIntensity rot=$rotationDegrees '
      'showSun=$showSun visible=$skyVisible)';
}

/// Binds a [LuminaSkyDescription] onto a live Filament engine + scene as a real
/// `Skybox` and a real `IndirectLight`.
///
/// [LuminaSkyComponent] does the same thing for a full [LuminaWorld]; this
/// binding exists for surfaces that render a Filament scene *without* a world
/// — the Lumina Studio level viewport and the sub-editor preview viewports —
/// so those viewports never have to talk to `FilamentSkybox` /
/// `FilamentIndirectLight` themselves.
///
/// ### Why a fallback cubemap and not just spherical harmonics
///
/// A solid-colour sky carries no reflection information, and an `IndirectLight`
/// built from spherical harmonics alone gives diffuse ambient but **no specular
/// ambient** — so a metallic or smooth PBR surface lit only by directional
/// lights renders as a black silhouette. Callers therefore always hand this
/// binding a neutral fallback IBL cubemap ([fallbackIblKtx]) which is used
/// whenever the description has no HDRI of its own. This is the editor-preview
/// environment: it lights and reflects, it never replaces the level's sky.
class LuminaSkyBinding {
  final FilamentEngine engine;
  final FilamentScene scene;

  /// Neutral KTX1 IBL cubemap used when the description has no HDRI.
  final Uint8List? fallbackIblKtx;

  FilamentSkybox? _skybox;
  FilamentIndirectLight? _indirectLight;
  FilamentTexture? _envTexture;
  FilamentTexture? _fallbackReflectionsTexture;
  Float32List? _fallbackShCoefficients;
  bool _fallbackParsed = false;
  LuminaSkyDescription? _applied;
  Uint8List? _appliedEnvBytes;
  bool _disposed = false;

  LuminaSkyBinding({
    required this.engine,
    required this.scene,
    this.fallbackIblKtx,
  });

  /// The description currently bound to the scene, if any.
  LuminaSkyDescription? get applied => _applied;

  /// The live skybox, or null when the description hides it.
  FilamentSkybox? get skybox => _skybox;

  /// The live indirect light.
  FilamentIndirectLight? get indirectLight => _indirectLight;

  /// Applies [description] to the scene.
  ///
  /// [environmentKtx] are the bytes of `description.environmentAssetPath`
  /// (KTX1 cubemap); the caller resolves and reads it, because asset
  /// resolution is a host concern. When it is null the binding falls back to
  /// [fallbackIblKtx] for lighting and to the description's solid colour for
  /// the background.
  ///
  /// Calling this repeatedly is cheap: only the pieces that actually changed
  /// are rebuilt, so it is safe to call on every editor property edit.
  void apply(LuminaSkyDescription description, {Uint8List? environmentKtx}) {
    if (_disposed) return;

    final prev = _applied;
    final bytesChanged = !identical(_appliedEnvBytes, environmentKtx) &&
        (_appliedEnvBytes?.length ?? -1) != (environmentKtx?.length ?? -1);
    final rebuild = prev == null || description.needsRebuildFrom(prev) || bytesChanged;

    if (rebuild) {
      _destroyNative();
      _build(description, environmentKtx);
    } else {
      if (!description.useEnvironmentMap) {
        if (description.effectiveSkyColor != prev.effectiveSkyColor) {
          _skybox?.color = description.effectiveSkyColor;
        }
        if (description.color != prev.color) {
          _rebuildColorIndirectLight(description);
        } else if (description.effectiveIblIntensity != prev.effectiveIblIntensity) {
          _indirectLight?.setIntensity(description.effectiveIblIntensity);
        }
      } else {
        if (description.effectiveIblIntensity != prev.effectiveIblIntensity) {
          _indirectLight?.setIntensity(description.effectiveIblIntensity);
        }
      }
      if (description.rotationDegrees != prev.rotationDegrees) {
        _applyRotation(description.rotationDegrees);
      }
      if (description.skyVisible != prev.skyVisible) {
        scene.setSkybox(description.skyVisible ? _skybox : null);
      }
    }

    _applied = description;
    _appliedEnvBytes = environmentKtx;
  }

  void _ensureFallbackParsed() {
    if (_fallbackParsed) return;
    _fallbackParsed = true;
    final fallback = fallbackIblKtx;
    if (fallback == null || fallback.isEmpty) return;
    try {
      final bundle = Ktx1Bundle(fallback);
      _fallbackShCoefficients = bundle.getSphericalHarmonics();
      _fallbackReflectionsTexture = Ktx1Reader.createTexture(engine, bundle, srgb: false);
    } catch (_) {
      // In tests or if fallback parsing fails
    }
  }

  void _buildColorIndirectLight(LuminaSkyDescription d) {
    _ensureFallbackParsed();
    final baseSh = _fallbackShCoefficients;
    final reflections = _fallbackReflectionsTexture;

    final maxC = math.max(d.color.x, math.max(d.color.y, d.color.z));
    final tr = maxC > 1e-4 ? d.color.x / maxC : 0.0;
    final tg = maxC > 1e-4 ? d.color.y / maxC : 0.0;
    final tb = maxC > 1e-4 ? d.color.z / maxC : 0.0;

    if (baseSh != null && baseSh.length == 27) {
      final tintedSh = Float32List(27);
      for (var i = 0; i < 9; i++) {
        tintedSh[i * 3 + 0] = baseSh[i * 3 + 0] * tr;
        tintedSh[i * 3 + 1] = baseSh[i * 3 + 1] * tg;
        tintedSh[i * 3 + 2] = baseSh[i * 3 + 2] * tb;
      }
      _indirectLight = FilamentIndirectLight.build(
        engine,
        reflections: reflections,
        irradiance: SphericalHarmonics(bands: 3, coefficients: tintedSh),
        intensity: d.effectiveIblIntensity,
      );
    } else {
      _indirectLight = FilamentIndirectLight.build(
        engine,
        reflections: reflections,
        irradiance: SphericalHarmonics(
          bands: 1,
          coefficients: [tr, tg, tb],
        ),
        intensity: d.effectiveIblIntensity,
      );
    }
  }

  void _rebuildColorIndirectLight(LuminaSkyDescription d) {
    if (_indirectLight != null) {
      scene.setIndirectLight(null);
      _indirectLight!.dispose();
      _indirectLight = null;
    }
    _buildColorIndirectLight(d);
    scene.setIndirectLight(_indirectLight);
    _applyRotation(d.rotationDegrees);
  }

  void _build(LuminaSkyDescription d, Uint8List? environmentKtx) {
    final useEnv = d.useEnvironmentMap && environmentKtx != null;

    if (useEnv) {
      _skybox = FilamentSkybox.fromKtx(engine, environmentKtx, showSun: d.showSun);
      _indirectLight = FilamentIndirectLight.fromKtx(
        engine,
        environmentKtx,
        intensity: d.effectiveIblIntensity,
      );
    } else {
      _skybox = FilamentSkybox.build(
        engine,
        color: d.effectiveSkyColor,
        showSun: d.showSun,
        intensity: d.skyIntensity,
      );
      _buildColorIndirectLight(d);
    }

    scene.setSkybox(d.skyVisible ? _skybox : null);
    scene.setIndirectLight(_indirectLight);
    _applyRotation(d.rotationDegrees);
  }

  void _applyRotation(double degrees) {
    final il = _indirectLight;
    if (il == null) return;
    il.rotation = Matrix3.rotationY(degrees * math.pi / 180.0);
  }

  void _destroyNative() {
    if (_skybox != null) {
      scene.setSkybox(null);
      _skybox!.dispose();
      _skybox = null;
    }
    if (_indirectLight != null) {
      scene.setIndirectLight(null);
      _indirectLight!.dispose();
      _indirectLight = null;
    }
    _envTexture?.dispose();
    _envTexture = null;
  }

  /// Removes the skybox and indirect light from the scene and destroys them.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _destroyNative();
    _fallbackReflectionsTexture?.dispose();
    _fallbackReflectionsTexture = null;
    _fallbackShCoefficients = null;
    _fallbackParsed = false;
    _applied = null;
    _appliedEnvBytes = null;
  }
}
