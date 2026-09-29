part of '../filament_thumbnail_renderer.dart';

/// State shared by the [FilamentThumbnailRenderer] domain mixins: every
/// instance field (in the original order, so initialisers run in the same
/// order) and the members the mixins call on one another.
abstract class _FilamentThumbnailRendererState {
  _FilamentThumbnailRendererState({
    this.size = 256,
    this.supersample = 2,
    this.sunIntensity = 100000,
    this.iblIntensity = 20000,
    this.backdrop = 0.05,
    this._iblKtx,
  });

  /// Output edge length in pixels.
  final int size;

  /// Render-target scale over [size]; the frame is box-filtered down.
  final int supersample;

  /// Key light (lux) and image-based light intensity of the studio rig.
  final double sunIntensity;
  final double iblIntensity;

  /// Grey level of the backdrop (a solid skybox, before exposure).
  final double backdrop;

  final EngineLoggerService _logger = EngineLoggerService();

  Uint8List? _iblKtx;
  FilamentEngine? _engine;
  FilamentEngineLease? _lease;
  FilamentScene? _scene;
  FilamentView? _view;
  FilamentRenderer? _renderer;
  FilamentSwapChain? _swapChain;
  FilamentCamera? _camera;
  int _cameraEntity = 0;
  int _sunEntity = 0;
  FilamentSkybox? _skybox;
  FilamentIndirectLight? _indirectLight;
  ColorGrading? _colorGrading;
  FilamentMaterialProvider? _provider;
  FilamentAssetLoader? _loader;
  FilamentResourceLoader? _resources;
  FilamentVertexBuffer? _sphereVb;
  FilamentIndexBuffer? _sphereIb;
  bool _failed = false;
  bool _disposed = false;
  Future<void> _tail = Future<void>.value();

  /// Compiled packages keyed by source text, so a material is compiled once
  /// per session however often its thumbnail is refreshed.
  final Map<String, Uint8List?> _compiled = {};

  // --- Implemented by the domain mixins or [FilamentThumbnailRenderer]. ---

  void dispose();

  bool _ensureEngine();

  void _frame(Aabb3 bounds, {required double pitchDegrees});

  Future<Uint8List?> _captureAndEncode();
}
