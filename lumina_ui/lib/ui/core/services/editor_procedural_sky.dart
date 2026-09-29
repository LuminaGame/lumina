import 'package:flutter/foundation.dart';
import '../host/editor_host.dart' show EditorAssets;
import 'package:flutter_filament/flutter_filament.dart' show FilamentEngine, FilamentScene;
import 'package:lumina/lumina.dart';

import '../../features/details/models/editor_component_node.dart';
import '../../features/main_editor/view_models/editor_view_model.dart' show EditorActorNode;

/// Owns the Procedural Sky & Ocean of one Lumina Studio viewport.
///
/// The editor viewports render a bare Filament scene rather than a
/// [LuminaWorld], so they cannot register a [LuminaProceduralSkyComponent].
/// This service is the bridge: it finds the level's `ProceduralSky` actor,
/// turns its component properties into a [LuminaProceduralSkyDescription] and
/// hands it to lumina's [LuminaProceduralSkyBinding] — the same binding the
/// component itself drives at runtime, so the editor and the shipped game
/// cannot render different skies.
///
/// It is the sibling of [EditorSceneEnvironment], which does the same for the
/// `Environment` actor's skybox and image-based lighting. The two coexist on
/// purpose: the procedural sky is a renderable with `depthWrite: false` and
/// lights nothing, so a level wanting both a moving sky and lit meshes needs
/// both actors.
class EditorProceduralSky {
  /// Actor type the editor spawns for the Procedural Sky & Ocean.
  static const String actorType = 'ProceduralSky';

  /// Component type carrying the sky's properties.
  static const String componentType = 'LuminaProceduralSkyComponent';

  LuminaProceduralSkyBinding? _binding;
  LuminaProceduralSkyDescription? _description;

  /// The `timeOfDay` the *actor* carries, as distinct from the hour the
  /// viewport is currently showing. A running day cycle animates the rendered
  /// sky without rewriting the level — otherwise every frame would dirty the
  /// document and fight auto-save — so [apply] must not snap the animation back
  /// to the authored hour on every view-model notification. It only does so
  /// when the authored hour itself changed, i.e. when the user edited it.
  double? _authoredTimeOfDay;

  /// Set while a level actually has a `ProceduralSky` actor.
  bool get isActive => _binding != null;

  /// The description currently pushed to the scene, if any.
  LuminaProceduralSkyDescription? get description => _description;

  FilamentEngine? _engine;
  FilamentScene? _scene;

  /// Remembers the engine and scene. Nothing is created until a level actually
  /// carries a `ProceduralSky` actor — an ordinary level pays nothing.
  void attach(FilamentEngine engine, FilamentScene scene) {
    detach();
    _engine = engine;
    _scene = scene;
  }

  /// Finds the level's `ProceduralSky` actor, if it has one.
  static EditorActorNode? actorIn(Iterable<EditorActorNode> actors) {
    for (final a in actors) {
      if (a.type == actorType) return a;
    }
    return null;
  }

  /// Builds the sky description for a level from its `ProceduralSky` actor.
  ///
  /// Returns null when the level has no such actor — the common case, and the
  /// signal to tear the sky down. The outliner's eye toggle drives
  /// [EditorActorNode.isVisible], so hiding the actor hides the sky.
  static LuminaProceduralSkyDescription? describeLevel(Iterable<EditorActorNode> actors) {
    final actor = actorIn(actors);
    if (actor == null) return null;
    EditorComponentNode? component;
    for (final c in actor.components) {
      if (c.type == componentType) {
        component = c;
        break;
      }
    }
    final d = LuminaProceduralSkyDescription.fromProperties(component?.properties);
    return actor.isVisible ? d : d.copyWith(visible: false);
  }

  /// Pushes [description] onto the scene, creating or destroying the binding as
  /// the level gains or loses its `ProceduralSky` actor.
  ///
  /// Cheap and idempotent: an unchanged description does nothing, and a changed
  /// one is a uniform upload rather than a rebuild, so this is safe on every
  /// Details-panel keystroke.
  void apply(LuminaProceduralSkyDescription? description) {
    if (description == null) {
      if (_binding != null) detach(keepEngine: true);
      _description = null;
      _authoredTimeOfDay = null;
      return;
    }

    final engine = _engine;
    final scene = _scene;
    if (engine == null || scene == null) {
      _description = description;
      return;
    }

    // Preserve a running day cycle's live hour unless the user edited it.
    var effective = description;
    final live = _description;
    if (live != null &&
        live.dayCycleSpeed != 0.0 &&
        description.dayCycleSpeed != 0.0 &&
        description.timeOfDay == _authoredTimeOfDay) {
      effective = description.copyWith(timeOfDay: live.timeOfDay);
    }
    _authoredTimeOfDay = description.timeOfDay;

    var binding = _binding;
    if (binding == null) {
      binding = LuminaProceduralSkyBinding(
        engine: engine,
        scene: scene,
        assetProvider: _bundleAsset,
      );
      _binding = binding;
      // The shader is ~180 KB and is read off the bundle asynchronously; the
      // sky appears on the first frame after it lands.
      binding.load(effective).catchError((Object e) {
        debugPrint('[Lumina Studio] procedural sky failed to load: $e');
      });
    } else if (effective != _description) {
      binding.apply(effective);
    }
    _description = effective;
  }

  /// Advances the day cycle by [deltaSeconds] and returns the new time of day,
  /// or null when there is nothing to advance.
  ///
  /// The hour is deliberately *not* written back onto the actor: the level
  /// saves the authored `timeOfDay`, and the viewport just previews the cycle
  /// running from it. Writing every frame would mark the document dirty sixty
  /// times a second and fight auto-save.
  double? advance(double deltaSeconds) {
    final binding = _binding;
    final d = _description;
    if (binding == null || d == null || d.dayCycleSpeed == 0.0 || !binding.isLoaded) {
      return null;
    }
    final next = binding.advance(deltaSeconds);
    _description = binding.description;
    return next;
  }

  static Future<Uint8List> _bundleAsset(String key) async {
    final data = await EditorAssets.load(key);
    return data.buffer.asUint8List();
  }

  /// Removes the sky from the scene and destroys it.
  void detach({bool keepEngine = false}) {
    _binding?.dispose();
    _binding = null;
    _description = null;
    _authoredTimeOfDay = null;
    if (!keepEngine) {
      _engine = null;
      _scene = null;
    }
  }
}
