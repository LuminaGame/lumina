import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina_ui/ui/core/host/editor_host.dart' show EditorAssets;
import 'package:flutter_filament/flutter_filament.dart' show FilamentEngine, FilamentScene;
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart' show EditorActorNode;

/// Owns the sky background and the image-based lighting of one Lumina Studio
/// Filament viewport (the level viewport and every sub-editor preview).
///
/// The editor viewports render a bare Filament scene rather than a
/// [LuminaWorld], so they cannot register a [LuminaSkyComponent]. This service
/// is the bridge: it resolves the level's `Environment` actor (or a sensible
/// default), reads any HDRI off disk, and hands the result to lumina's
/// [LuminaSkyBinding], which creates the real `Skybox` and `IndirectLight`.
///
/// ### Why every viewport gets image-based lighting, always
///
/// Before this existed the viewports had directional lights only. Filament's
/// PBR shading takes its *ambient* diffuse and **all** of its ambient specular
/// from an `IndirectLight`; with none bound, every surface the sun does not
/// directly face resolves to near-black, which is why imported meshes showed
/// up as black silhouettes. Measured on
/// `Props/AC_units/roof_aircon_unit_150x150_a.glb`, the mean luminance of the
/// mesh pixels went from 45.8 to 117.3 (/255) once an IBL was bound.
///
/// A solid-colour sky carries no reflection information and spherical
/// harmonics alone give no specular ambient at all, so the service always
/// falls back to a bundled neutral studio cubemap
/// (`assets/ibl/default_env/default_env_ibl.ktx`, Filament's `default_env`)
/// for lighting when the level has no HDRI of its own. It lights and reflects;
/// it never replaces the level's own sky background.
class EditorSceneEnvironment {
  /// Bundled neutral IBL cubemap used when the level has no HDRI.
  static const String defaultIblAsset = 'assets/ibl/default_env/default_env_ibl.ktx';

  /// Actor type the editor spawns for `Sky & Atmosphere` / `Environment`.
  static const String environmentActorType = 'Environment';

  /// Actor types recognized as environment/sky actors.
  static const Set<String> environmentActorTypes = {
    'Environment',
    'SkyAtmosphere',
    'SkyLight',
    'Sky',
  };

  static bool isEnvironmentActor(String actorType) => environmentActorTypes.contains(actorType);

  /// Component type the Environment Lighting sub-editor writes the sky onto.
  static const String skyComponentType = 'LuminaSkyComponent';

  /// Default properties for an environment actor's sky & lighting component.
  static Map<String, dynamic> defaultSkyProperties() => <String, dynamic>{
        'mode': 'color',
        'colorHex': '#5C7FB8',
        'skyIntensity': 30000.0,
        'iblIntensity': 30000.0,
        'rotationDegrees': 0.0,
        'showSun': false,
      };

  /// Creates a freshly initialized [EditorComponentNode] for sky & lighting.
  static EditorComponentNode seedSkyComponent(String actorId, {Map<String, dynamic>? initialProperties}) =>
      EditorComponentNode(
        id: '${actorId}_sky',
        type: skyComponentType,
        name: 'Sky & Lighting',
        properties: initialProperties ?? defaultSkyProperties(),
      );

  /// Returns the [LuminaSkyComponent] of [actor], if present.
  static EditorComponentNode? componentOf(EditorActorNode actor) {
    if (!isEnvironmentActor(actor.type)) return null;
    for (final c in actor.components) {
      if (c.type == skyComponentType) return c;
    }
    return null;
  }

  /// Actor type of the Procedural Sky & Ocean, which draws its own background.
  static const String proceduralSkyActorType = 'ProceduralSky';

  static Uint8List? _cachedDefaultIbl;
  static Future<Uint8List?>? _defaultIblLoad;

  /// Absolute path of the open project, used to resolve relative HDRI paths.
  String? projectDirPath;

  /// Whether this viewport draws the level's sky background. Sub-editor
  /// previews leave it off: they keep the neutral editor backdrop (so the
  /// grid, gizmos and HUD stay readable) but still take the ambient light.
  final bool showSkyBackground;

  LuminaSkyBinding? _binding;
  LuminaSkyDescription _description = LuminaSkyDescription.defaults;
  Uint8List? _environmentKtx;

  EditorSceneEnvironment({this.projectDirPath, this.showSkyBackground = true});

  bool get isAttached => _binding != null;

  /// The description currently pushed to the scene.
  LuminaSkyDescription get description => _description;

  /// The bundled fallback IBL, once [ensureAssetsLoaded] has completed.
  static Uint8List? get cachedDefaultIbl => _cachedDefaultIbl;

  /// Reads the bundled fallback IBL cubemap (once per process).
  static Future<Uint8List?> ensureAssetsLoaded() {
    if (_cachedDefaultIbl != null) return Future.value(_cachedDefaultIbl);
    return _defaultIblLoad ??= () async {
      try {
        final data = await EditorAssets.load(defaultIblAsset);
        _cachedDefaultIbl = data.buffer.asUint8List();
      } catch (e) {
        debugPrint('[Lumina Studio] default IBL unavailable ($defaultIblAsset): $e');
        _cachedDefaultIbl = null;
      }
      return _cachedDefaultIbl;
    }();
  }

  /// Builds the sky description for a level from its `Environment` actor.
  ///
  /// [environmentSection] is the level's `metadata.environment` payload (what
  /// the Environment Lighting sub-editor persists); it wins over the actor's
  /// component properties because the sub-editor writes it last. When neither
  /// exists the level has no sky and no image-based light — null — as in
  /// the built game; a level is lit by what it holds.
  ///
  /// A visible `ProceduralSky` actor suppresses this skybox (the ambient light
  /// is untouched). Filament draws a `Skybox` into every pixel nothing wrote
  /// depth to, and the Procedural Sky & Ocean is a `depthWrite: false`
  /// renderable, so the static skybox would paint straight over it. When a
  /// level carries both, the procedural sky *is* the background and the
  /// `Environment` actor is there for the image-based lighting a procedural
  /// sky cannot provide.
  static LuminaSkyDescription? describeLevel(
    Iterable<EditorActorNode> actors, {
    Map<String, dynamic>? environmentSection,
  }) {
    final d = _skyOf(actors, environmentSection);
    if (d == null) return null;
    return _hasVisibleProceduralSky(actors) ? d.copyWith(skyVisible: false) : d;
  }

  static bool _hasVisibleProceduralSky(Iterable<EditorActorNode> actors) {
    for (final a in actors) {
      if (a.type == proceduralSkyActorType && a.isVisible) return true;
    }
    return false;
  }

  static LuminaSkyDescription? _skyOf(
    Iterable<EditorActorNode> actors,
    Map<String, dynamic>? environmentSection,
  ) {
    final sky = environmentSection?['sky'];
    if (sky is Map) {
      return LuminaSkyDescription.fromProperties(Map<String, dynamic>.from(sky));
    }
    for (final actor in actors) {
      if (!environmentActorTypes.contains(actor.type)) continue;
      EditorComponentNode? skyComponent;
      for (final c in actor.components) {
        if (c.type == skyComponentType) {
          skyComponent = c;
          break;
        }
      }
      final d = LuminaSkyDescription.fromProperties(skyComponent?.properties);
      return actor.isVisible ? d : d.copyWith(skyVisible: false);
    }
    return null;
  }

  /// Attaches to a live engine + scene and immediately binds the current
  /// description, so the very first rendered frame is already lit.
  void attach(FilamentEngine engine, FilamentScene scene) {
    detach();
    _engine = engine;
    _scene = scene;
    _cleared = false;
    _binding = LuminaSkyBinding(
      engine: engine,
      scene: scene,
      fallbackIblKtx: _cachedDefaultIbl,
    );
    _push();
    if (_cachedDefaultIbl == null) {
      // The bundle read is async; rebuild once it lands so the scene is not
      // left with colour-only ambient.
      ensureAssetsLoaded().then((bytes) {
        if (bytes == null || _binding == null || _cleared) return;
        final scene0 = scene;
        _binding!.dispose();
        _binding = LuminaSkyBinding(engine: engine, scene: scene0, fallbackIblKtx: bytes);
        _push();
      });
    }
  }

  /// Pushes [description] onto the scene. Cheap and idempotent: only the parts
  /// that actually changed are rebuilt, so the Details panel can call it on
  /// every keystroke.
  void apply(LuminaSkyDescription description) {
    final effective = showSkyBackground ? description : description.copyWith(skyVisible: false);
    if (effective == _description && _binding?.applied != null) return;
    _description = effective;
    _environmentKtx = _readEnvironmentKtx(effective.environmentAssetPath);
    _push();
  }

  void _push() {
    final b = _binding;
    if (b == null) return;
    try {
      b.apply(_description, environmentKtx: _environmentKtx);
    } catch (e) {
      debugPrint('[Lumina Studio] sky binding failed: $e');
    }
  }

  Uint8List? _readEnvironmentKtx(String? relativeOrAbsolutePath) {
    final p = relativeOrAbsolutePath;
    if (p == null || p.isEmpty) return null;
    // KTX2 environments still go through LuminaSkyComponent's Ktx2Reader path;
    // the viewport binding handles KTX1, which is what the editor imports.
    if (!p.toLowerCase().endsWith('.ktx')) return null;
    final candidates = <String>[
      if (p.startsWith('/')) p,
      if (!p.startsWith('/') && projectDirPath != null) '$projectDirPath/$p',
    ];
    for (final c in candidates) {
      final f = File(c);
      if (f.existsSync()) {
        try {
          return f.readAsBytesSync();
        } catch (e) {
          debugPrint('[Lumina Studio] could not read HDRI $c: $e');
        }
      }
    }
    return null;
  }

  /// A level's environment: [description], or none at all — no skybox and
  /// no image-based light — for a level without an Environment actor
  /// Rebinds on the next non-null description.
  void applyLevel(LuminaSkyDescription? description) {
    if (description == null) {
      _cleared = true;
      _binding?.dispose();
      _binding = null;
      return;
    }
    if (_cleared && _engine != null && _scene != null) {
      _cleared = false;
      _binding = LuminaSkyBinding(engine: _engine!, scene: _scene!, fallbackIblKtx: _cachedDefaultIbl);
      _description = LuminaSkyDescription.defaults;
      _environmentKtx = null;
    }
    apply(description);
  }

  FilamentEngine? _engine;
  FilamentScene? _scene;
  bool _cleared = false;

  /// Removes the sky and ambient light from the scene.
  void detach() {
    _binding?.dispose();
    _binding = null;
    _engine = null;
    _scene = null;
    _cleared = false;
  }
}
