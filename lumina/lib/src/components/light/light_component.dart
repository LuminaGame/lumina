import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/post_process/shadow_settings.dart';

export 'auto_exposure.dart';

/// Abstract base scene component representing an illumination source bound to FilamentLightManager.
abstract class LuminaLightComponent extends LuminaSceneComponent {
  /// The direction the light travels in world space: what Filament gets.
  ///
  /// It is the light's [forwardVector], the −Z of its drawn rotation (the
  /// matrix `Matrix4.compose` renders and the editor shows). Previously
  /// `forwardVector` was the mirror of the drawn rotation, which turned a sun
  /// authored 50° down into one shining up from below.
  Vector3 get lightDirection => forwardVector..normalize();

  final Vector3 _color;
  double _intensity;
  bool _castShadows;
  ShadowOptions? _shadowOptions;
  bool _visible;

  int? _lightEntity;
  Matrix4? _lastSyncedTransform;

  LuminaLightComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    Vector3? color,
    required this._intensity,
    this._castShadows = false,
    this._shadowOptions,
    this._visible = true,
  }) : _color = color ?? Vector3(1.0, 1.0, 1.0);

  /// Native entity handle for this light component, or null if unbound.
  int? get lightEntity => _lightEntity;

  /// Linear RGB color (0.0 to 1.0).
  Vector3 get color => _color;
  set color(Vector3 value) {
    _color.setFrom(value);
    final w = owner?.world;
    if (_lightEntity != null && w != null && w.hasNativeContext) {
      FilamentLightManager(w.filamentEngine).setColor(_lightEntity!, _color.x, _color.y, _color.z);
    }
  }

  /// Light intensity (unit depends on subclass: lux for directional, lumens for point/spot).
  double get intensity => _intensity;
  set intensity(double value) {
    _intensity = value;
    final w = owner?.world;
    if (_lightEntity != null && w != null && w.hasNativeContext) {
      applyIntensity(FilamentLightManager(w.filamentEngine), _lightEntity!, _intensity);
    }
  }

  /// Whether this light casts dynamic shadows.
  bool get castShadows => _castShadows;
  set castShadows(bool value) {
    _castShadows = value;
    final w = owner?.world;
    if (_lightEntity != null && w != null && w.hasNativeContext) {
      FilamentLightManager(w.filamentEngine).setShadowCaster(_lightEntity!, _castShadows);
    }
  }

  /// Shadow map and cascaded shadow map configuration options.
  ShadowOptions? get shadowOptions => _shadowOptions;
  set shadowOptions(ShadowOptions? value) {
    _shadowOptions = value;
    final w = owner?.world;
    if (_lightEntity != null && w != null && w.hasNativeContext && _shadowOptions != null) {
      FilamentLightManager(w.filamentEngine).setShadowOptions(_lightEntity!, _shadowOptions!);
    }
  }

  /// Whether the light is currently illuminating the scene.
  bool get visible => _visible;
  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    _updateVisibility();
  }

  void _updateVisibility() {
    final w = owner?.world;
    if (_lightEntity == null || w == null || !w.hasNativeContext) return;
    final scene = w.filamentScene;
    if (_visible) {
      if (!scene.hasEntity(_lightEntity!)) {
        scene.addEntity(_lightEntity!);
      }
    } else {
      if (scene.hasEntity(_lightEntity!)) {
        scene.removeEntity(_lightEntity!);
      }
    }
  }

  /// Subclass hook to build the native [LightBuilder] with type-specific properties.
  LightBuilder createLightBuilder();

  /// Subclass hook to apply intensity to native light (e.g. lumens vs candela vs lux).
  void applyIntensity(FilamentLightManager lm, int entity, double intensity) {
    lm.setIntensity(entity, intensity);
  }

  /// Subclass hook to sync transform (position, direction, or both) to [FilamentLightManager].
  void syncNativeTransform(FilamentLightManager lm, int entity);

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    _buildNativeLight();
  }

  void _buildNativeLight() {
    final w = owner?.world;
    if (w == null || !w.hasNativeContext) return;
    if (_lightEntity != null) return;

    final engine = w.filamentEngine;
    final scene = w.filamentScene;

    _lightEntity = engine.createEntity();
    final builder = createLightBuilder();
    builder.build(engine, _lightEntity!);

    final lm = FilamentLightManager(engine);
    if (_castShadows) {
      lm.setShadowCaster(_lightEntity!, true);
    }
    if (_shadowOptions == null && _castShadows && w.stagedSunShadowOptions != null) {
      _shadowOptions = w.stagedSunShadowOptions;
    }
    // Filament's own ShadowOptions defaults are metres; a caster left without
    // options gets the centimetre defaults.
    if (_shadowOptions == null && _castShadows) {
      _shadowOptions = LuminaShadowSettings().toShadowOptions(cameraNear: 10.0, cameraFar: 10000.0);
    }
    if (_shadowOptions != null) {
      lm.setShadowOptions(_lightEntity!, _shadowOptions!);
    }

    if (_visible) {
      scene.addEntity(_lightEntity!);
    }

    syncNativeTransform(lm, _lightEntity!);
    _lastSyncedTransform = Matrix4.copy(worldTransform);
  }

  @override
  void onRenderPrep(LuminaWorld world) {
    super.onRenderPrep(world);
    if (_lightEntity == null || !world.hasNativeContext) return;

    final currentMtx = worldTransform;
    if (_lastSyncedTransform != null && _isMatrixEqual(_lastSyncedTransform!, currentMtx)) {
      return;
    }

    syncNativeTransform(FilamentLightManager(world.filamentEngine), _lightEntity!);
    _lastSyncedTransform = Matrix4.copy(currentMtx);
  }

  bool _isMatrixEqual(Matrix4 a, Matrix4 b) {
    for (int i = 0; i < 16; i++) {
      if ((a.storage[i] - b.storage[i]).abs() > 1e-6) return false;
    }
    return true;
  }

  @override
  void onUnregister() {
    final w = owner?.world;
    if (_lightEntity != null && w != null && w.hasNativeContext) {
      final engine = w.filamentEngine;
      final scene = w.filamentScene;
      if (scene.hasEntity(_lightEntity!)) {
        scene.removeEntity(_lightEntity!);
      }
      final lm = FilamentLightManager(engine);
      if (lm.hasComponent(_lightEntity!)) {
        lm.destroy(_lightEntity!);
      }
      engine.destroyEntity(_lightEntity!);
      _lightEntity = null;
    }
    super.onUnregister();
  }
}
