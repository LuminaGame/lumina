part of 'viewport_runtime.dart';

/// The preview's stage: the sky (environment), the default shadowed key
/// light and the floor grid.
mixin _ViewportStage {
  FilamentEngine get engine;
  FilamentScene get scene;
  FilamentView get view;
  LuminaWorld get world;
  LuminaAssetProvider? get assetProvider;
  String get _viewMode;

  /// The key light's intensity in Lit (lux).
  static const double keyLightIntensity = 90000.0;

  LuminaActor? _sky;
  LuminaActor? _keyLight;
  FilamentEditorGrid? _grid;
  bool _gridShown = false;

  // --- Environment and grid --------------------------------------------------

  void _applyEnvironment(Map<String, Object?> env) {
    final old = _sky;
    if (old != null) world.persistentLevel.unregisterActor(old);
    _sky = null;
    final mode = env['mode'];
    final intensity = env['intensity'] is num ? (env['intensity']! as num).toDouble() : 1.0;
    final ibl = '${env['ibl'] ?? ''}';
    view.blendMode = mode == LuminaViewportEnvironmentMode.transparent ? BlendMode.translucent : BlendMode.opaque;
    final LuminaSkyComponent sky;
    if (ibl.isNotEmpty && mode != LuminaViewportEnvironmentMode.color) {
      sky = LuminaSkyComponent.environment(
        environmentAssetPath: ibl,
        assetProvider: assetProvider,
        iblIntensity: 30000.0 * intensity,
        visible: mode == LuminaViewportEnvironmentMode.sky,
      );
    } else {
      final c = env['color'] is List ? env['color']! as List : const [0.10, 0.11, 0.14, 1.0];
      sky = LuminaSkyComponent.color(
        color: Vector4(LuminaViewportSceneRuntime._n(c, 0, 0.1), LuminaViewportSceneRuntime._n(c, 1, 0.11), LuminaViewportSceneRuntime._n(c, 2, 0.14), 1.0),
        skyIntensity: 14000.0,
        iblIntensity: 22000.0 * intensity,
        visible: mode != LuminaViewportEnvironmentMode.transparent,
      );
    }
    final actor = LuminaActor(key: const LuminaObjectKey('viewport_sky'), root: sky);
    world.persistentLevel.registerActor(actor);
    _sky = actor;
    // The preview's one shadowed directional light (a key light from the
    // front left, above); description lights add to it unshadowed.
    if (_keyLight == null) {
      final key = _keyLight = LuminaActor(
      key: const LuminaObjectKey('viewport_key_light'),
      root: LuminaDirectionalLightComponent(
        rotation: LuminaAxes.rotation(const [-40, 0, 30]),
        color: Vector3(1.0, 0.97, 0.92),
        intensity: _viewMode == LuminaViewportViewMode.unlit ? 0.0 : keyLightIntensity,
        castShadows: true,
        isSun: false,
      ),
      );
      world.persistentLevel.registerActor(key);
    }
  }

  void _applyGrid(bool visible) {
    if (visible == _gridShown) return;
    _gridShown = visible;
    if (visible) {
      _grid ??= FilamentEditorGrid.create(engine: engine, extent: 500.0, step: 50.0)..setColor(0.35, 0.37, 0.42, 0.6);
      _grid!.addToScene(scene);
    } else {
      _grid?.removeFromScene(scene);
    }
  }

}
