import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

/// Drives the Particle sub-editor's live viewport through lumina.
///
/// The viewport hands over a [LuminaWorld] bound to its Filament engine; this
/// scene mounts a sun, a plain sky, and one [LuminaActor] per *enabled*
/// emitter carrying the view model's **real**
/// [LuminaParticleSystemComponent] — the same instance whose
/// `liveParticleCount` the stats overlay reads. There is no editor-side
/// particle simulator.
///
/// Simulation stepping stays with the view model (play / pause / sim speed /
/// step frame), so this scene ticks the world with `dt = 0`: that runs the
/// render-prep phase (the component pushes each live particle's transform
/// into Filament) without advancing the sim twice.
///
/// **Sprite renderer.** The particles are drawn by the engine component itself
/// (`LuminaParticleSystemComponent`): it batches a pair of
/// crossed quads per live particle with that particle's own over-life colour
/// and size. The editor only mounts the components, lights the scene and
/// drives the clock — it does not draw particles of its own.
class ParticlePreviewScene {
  LuminaWorld? _world;
  final List<LuminaActor> _emitterActors = [];
  List<LuminaParticleSystemComponent> _components = const [];
  Timer? _ticker;

  /// Hard cap on preview sprites, so a large `maxParticles` cannot stall the
  /// editor's render thread.
  static const int maxPreviewSprites = 2048;

  static const double _tickHz = 60.0;

  /// Sprite half-extent in world units at scale 1.0.
  static const double spriteHalfSize = 0.06;

  void Function(double dt)? _onAdvance;

  bool get isAttached => _world != null && !_world!.isCleanedUp;
  LuminaWorld? get world => _world;

  /// Binds [world] (already carrying a native context) and starts the render
  /// ticker; each tick calls [onAdvance] with the real elapsed time.
  void attach(LuminaWorld world, {required void Function(double dt) onAdvance}) {
    detach();
    if (world.isCleanedUp || !world.hasNativeContext) return;
    _world = world;
    _onAdvance = onAdvance;

    try {
      _register(LuminaActor(
        key: const LuminaObjectKey('particle_preview_sun'),
        root: LuminaDirectionalLightComponent(
          rotation: _eulerDegrees(-55.0, 30.0),
          color: Vector3(1.0, 0.98, 0.94),
          intensity: 90000.0,
          castShadows: false,
          isSun: true,
        ),
      ));
      _register(LuminaActor(
        key: const LuminaObjectKey('particle_preview_sky'),
        root: LuminaSkyComponent.color(
          color: Vector4(0.06, 0.07, 0.11, 1.0),
          skyIntensity: 12000.0,
          iblIntensity: 12000.0,
        ),
      ));
      _mountComponents();
      world.tick(0.0);
    } catch (e, st) {
      debugPrint('[ParticlePreviewScene] attach failed: $e\n$st');
    }

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 1000 ~/ _tickHz), (_) => _tick());
  }

  /// Hands over the live engine components (one per enabled emitter). Called
  /// again whenever the view model rebuilds them after a config edit.
  void setComponents(List<LuminaParticleSystemComponent> components) {
    _components = components;
    if (!isAttached) return;
    _unmountComponents();
    _mountComponents();
  }

  /// Drops the scene's references to the components before the view model
  /// replaces them (the viewport still owns the engine — see the ordering
  /// trap in the task notes: unregister before the engine goes away).
  void releaseComponents() {
    _unmountComponents();
    _components = const [];
  }

  void _mountComponents() {
    final w = _world;
    if (w == null || w.isCleanedUp) return;
    for (var i = 0; i < _components.length; i++) {
      final actor = LuminaActor(
        key: LuminaObjectKey('particle_preview_emitter_$i'),
        root: _components[i],
      );
      _emitterActors.add(actor);
      _register(actor);
    }
  }

  void _unmountComponents() {
    final w = _world;
    for (final actor in _emitterActors) {
      try {
        if (w != null && !w.isCleanedUp) w.persistentLevel.unregisterActor(actor);
      } catch (e) {
        debugPrint('[ParticlePreviewScene] unregister failed: $e');
      }
    }
    _emitterActors.clear();
  }

  void detach() {
    _ticker?.cancel();
    _ticker = null;
    _onAdvance = null;
    try {
      _unmountComponents();
    } catch (e) {
      debugPrint('[ParticlePreviewScene] detach cleanup: $e');
    }
    _components = const [];
    _world = null;
  }

  void _tick() {
    final w = _world;
    if (w == null || w.isCleanedUp) return;
    try {
      _onAdvance?.call(1.0 / _tickHz);
      // dt = 0: render-prep only, the sim was advanced by the view model.
      w.tick(0.0);
    } catch (e) {
      debugPrint('[ParticlePreviewScene] tick failed: $e');
    }
  }

  // --- what the engine draws ------------------------------------------------

  /// Pool budget across the live components, capped for the preview.
  int get spriteCapacity {
    var n = 0;
    for (final c in _components) {
      n += c.config.maxParticles;
    }
    return n > maxPreviewSprites ? maxPreviewSprites : n;
  }

  /// Particles the engine components drew on their last render prep.
  int get liveSpriteCount {
    var n = 0;
    for (final c in _components) {
      n += c.renderedParticleCount;
    }
    return n;
  }

  /// Kept for callers that used to force a sprite rebuild; the component now
  /// rebuilds its own geometry on every render prep, so this only pumps one.
  void syncParticles() {
    final w = _world;
    if (w == null || w.isCleanedUp) return;
    try {
      w.tick(0.0);
    } catch (e) {
      debugPrint('[ParticlePreviewScene] syncParticles: $e');
    }
  }

  void _register(LuminaActor actor) {
    _world!.persistentLevel.registerActor(actor);
  }

  static Quaternion _eulerDegrees(double pitch, double yaw) {
    return Quaternion.euler(
      yaw * 3.141592653589793 / 180.0,
      pitch * 3.141592653589793 / 180.0,
      0.0,
    );
  }
}
