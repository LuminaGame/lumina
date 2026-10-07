import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_filament/flutter_filament.dart' show FilamentEngine, FilamentScene, FilamentView;
import 'package:lumina/lumina.dart';

import 'package:lumina_ui/ui/features/sub_editors/models/solar_math.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/services/environment_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';

/// The level's environment actors in the edit-mode viewport, the way [EditorLevelLights] runs the level's
/// lights: every `ExponentialHeightFog`, `PostProcessVolume` and
/// `LocalFogVolume` actor becomes the runtime component PIE and the generated
/// game build for it ([EditorPieGame.mapEditorActor] — one conversion), in an
/// editor world bound to the viewport's scene and, for post-processing only,
/// to the viewport's [FilamentView] (`LuminaWorld.attachPostProcessView`: the
/// world never takes the editor camera). lumina's `LuminaPostProcessBlender`
/// then resolves the **baseline** (the editor quality's post-process, with the
/// Environment editor's global Height Fog as the fallback when no fog actor
/// exists), the fog actor and the volumes for the *editor camera*, and applies
/// the result to the very view the level renders — so a fog scrub, a volume
/// edit or flying the camera into a box changes the picture live, and leaving
/// every volume returns the view to the baseline.
///
/// Filament's limits apply: one fog per view, one post-process state per view
/// (volumes blend by camera position), no volumetric scattering (a Local Fog
/// Volume is a fog-shell approximation).
class EditorLevelPostProcess {
  LuminaWorld? _world;
  FilamentView? _view;
  final Map<String, _RealisedActor> _actors = {};
  LuminaPostProcessSettings _baseline = LuminaPostProcessSettings.standard();
  bool _lastEnabled = true;

  bool get isAttached => _world != null;

  /// The editor world running the environment components (null when detached).
  LuminaWorld? get world => _world;

  /// The blender the editor viewport blends through.
  LuminaPostProcessBlender? get blender => _world?.postProcessBlender;

  /// The settings volumes blend from (the editor quality's post-process plus
  /// the fallback fog), as last synced.
  LuminaPostProcessSettings get baseline => _baseline;

  /// Test seam: what the view was last given.
  LuminaPostProcessSettings? get appliedForTest => _world?.postProcess.applied;

  /// Test seam: the realised runtime components by actor id.
  Map<String, LuminaActor> get realisedForTest => {for (final e in _actors.entries) e.key: e.value.actor};

  /// Binds to the viewport's engine, scene and view.
  void attach(FilamentEngine engine, FilamentScene scene, FilamentView view) {
    detach();
    _view = view;
    _world = LuminaWorld(worldType: LuminaWorldType.editor)
      ..initializeNativeContext(engine, scene)
      ..attachPostProcessView(view);
  }

  /// Makes the world match [actors] and applies the blend for the editor
  /// camera at [cameraAuthoring] (cm, Z-up). [quality] supplies the baseline
  /// (bloom/AO/SSR as the quality popover applies them); [environmentSection]
  /// is the level's `metadata.environment` whose `postProcess.fog*` values
  /// are the fallback fog when the level has no fog actor. With [enabled]
  /// false (a Play session owns the view) nothing is applied and every
  /// realised actor leaves the scene.
  void sync(
    Iterable<EditorActorNode> actors, {
    required LuminaPostProcessSettings quality,
    Map<String, dynamic>? environmentSection,
    List<double>? cameraAuthoring,
    bool Function(String id)? isVisible,
    bool enabled = true,
  }) {
    final world = _world;
    if (world == null) return;
    if (!enabled) {
      for (final id in _actors.keys.toList()) {
        _remove(world, id);
      }
      _lastEnabled = false;
      return;
    }
    if (!_lastEnabled) {
      // A Play session drove the view meanwhile: forget what this controller
      // believes it applied so the next apply pushes everything again.
      _reattachView();
      _lastEnabled = true;
    }
    final w = _world!;

    final visibleFog = EnvironmentActorProperties.heightFogActorOf(actors, isVisible: isVisible);
    _baseline = visibleFog == null ? withFallbackFog(quality, environmentSection) : quality;
    if (w.postProcess.baseline != _baseline) w.postProcess.apply(_baseline);

    final wanted = <String, EditorActorNode>{
      for (final a in actors)
        if (EnvironmentActorProperties.isEnvironmentActor(a) && (isVisible?.call(a.id) ?? a.isVisible)) a.id: a,
    };
    for (final id in _actors.keys.where((id) => !wanted.containsKey(id)).toList()) {
      _remove(w, id);
    }
    for (final node in wanted.values) {
      final signature = EnvironmentActorProperties.signature(node);
      final existing = _actors[node.id];
      if (existing != null && existing.signature == signature) continue;
      if (existing != null) _remove(w, node.id);
      final built = EditorPieGame.mapEditorActor(node);
      if (built is! LuminaActor) continue;
      try {
        w.persistentLevel.registerActor(built);
      } catch (e) {
        debugPrint('[EditorLevelPostProcess] could not realise ${node.type} ${node.id}: $e');
        continue;
      }
      _actors[node.id] = _RealisedActor(built, signature);
    }

    w.postProcessBlender.cameraPositionOverride =
        cameraAuthoring == null ? null : LuminaAxes.location(cameraAuthoring);
    // Render prep: the components publish to the blender and the world
    // applies the resolved settings to the view.
    w.tick(0.0);
  }

  /// [quality] with the Environment editor's Height Fog section
  /// (`environment.postProcess.fogEnabled/fogDensity/fogHeightFalloff/fogColorHex`,
  /// per metre → per cm) as its fog — the fallback for a level without a fog
  /// actor. Without a section the quality's fog stays.
  static LuminaPostProcessSettings withFallbackFog(LuminaPostProcessSettings quality, Map<String, dynamic>? environmentSection) {
    final pp = environmentSection?['postProcess'];
    if (pp is! Map) return quality;
    double num_(String k, double d) => pp[k] is num ? (pp[k] as num).toDouble() : d;
    final colour = SolarMath.hexToRgb(pp['fogColorHex'] is String ? pp['fogColorHex'] as String : '#B8C4D6');
    return quality.copyWith(
      fog: quality.fog.copyWith(
        enabled: pp['fogEnabled'] == true,
        density: num_('fogDensity', 0.0) / LuminaUnits.unitsPerMetre,
        heightFalloff: num_('fogHeightFalloff', 1.0) / LuminaUnits.unitsPerMetre,
        colorR: colour.x,
        colorG: colour.y,
        colorB: colour.z,
      ),
    );
  }

  void _reattachView() {
    final world = _world;
    final view = _view;
    if (world == null || view == null) return;
    world.postProcess.dispose();
    world.attachPostProcessView(view);
  }

  void _remove(LuminaWorld world, String id) {
    final r = _actors.remove(id);
    if (r == null) return;
    world.persistentLevel.unregisterActor(r.actor);
  }

  /// Removes every realised actor and drops the world.
  void detach() {
    final world = _world;
    if (world == null) return;
    for (final id in _actors.keys.toList()) {
      _remove(world, id);
    }
    world.cleanup();
    _world = null;
    _view = null;
    _lastEnabled = true;
  }
}

class _RealisedActor {
  _RealisedActor(this.actor, this.signature);
  final LuminaActor actor;
  final String signature;
}
