import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina_smoke/lumina_smoke.dart';
import 'package:vector_math/vector_math_64.dart';

import '../math/units.dart';

/// Called for every frame [SmokeRender.renderRealAssetMedia] films, before it
/// is rendered.
typedef SmokeRenderFrame = void Function(
  FilamentEngine engine,
  FilamentScene scene,
  FilamentView view,
  FilamentCamera camera,
  List<FilamentAsset> assets,
  int frame,
  int totalFrames,
  double timeSeconds,
);

/// Called once the scene of [SmokeRender.renderRealAssetMedia] and its assets
/// are ready, before the first frame.
typedef SmokeRenderSetup = Future<void> Function(
  FilamentEngine engine,
  FilamentScene scene,
  FilamentView view,
  FilamentCamera camera,
  List<FilamentAsset> assets,
);

/// Smoke evidence rendered by Filament itself: a headless scene of real test
/// assets filmed frame by frame into a screenshot and a smoke video.
abstract final class SmokeRender {
  /// Renders real 3D assets from [usedAssets] (paths under [SmokeArtifacts.testAssetsDir]; a missing or unloadable one throws a
  /// [StateError], never a blank scene) via Filament C++/Vulkan engine over a headless simulation of
  /// [durationSeconds] (at least [SmokeVideo.minimumSeconds]) at [fps] (at least [SmokeVideo.minimumFps]), capturing a
  /// real rendered screenshot PNG and a WebM video of every simulated frame, [width] × [height] (at least
  /// [SmokeVideo.minimumWidth] × [SmokeVideo.minimumHeight]).
  ///
  /// The scene is set up in centimetres, like the world: clip planes [near] 10 / [far] 100000, and
  /// the default asset placement and orbit camera sized in centimetres. A scene authored in another scale
  /// passes [sceneUnitsPerMetre] (1.0 for a raw-Filament showcase authored in metres), which scales the
  /// default placement, orbit and clip planes together; [near] and [far] override the clip planes alone.
  ///
  /// [onFrame] runs synchronously inside the frame loop, which never yields, so nothing asynchronous (a
  /// world's mesh loads) progresses while it films. A scenario that needs such work done first does it in
  /// [onSetup], awaited once the scene and the assets are ready and before the first frame; [onTeardown] runs
  /// after the last frame, while the scene still exists (clean a world up there, before the scene is
  /// disposed). With an [onFrame] the scenario aims the camera itself; the default orbit only runs without one.
  static Future<void> renderRealAssetMedia({
    required String testTitle,
    required List<String> usedAssets,
    double durationSeconds = 10.0,
    int width = SmokeVideo.defaultWidth,
    int height = SmokeVideo.defaultHeight,
    int fps = SmokeVideo.minimumFps,
    SmokeRenderFrame? onFrame,
    SmokeRenderSetup? onSetup,
    FutureOr<void> Function()? onTeardown,
    FilamentEngine? engine,
    bool autoDisposeEngine = true,
    double sceneUnitsPerMetre = LuminaUnits.unitsPerMetre,
    double? near,
    double? far,
  }) async {
    if (SmokeVideo.isTooShort(durationSeconds)) {
      throw StateError(
        'Smoke video "$testTitle" would run ${durationSeconds.toStringAsFixed(2)} s; smoke videos must run at '
        'least ${SmokeVideo.minimumSeconds.toStringAsFixed(0)} s.',
      );
    }
    // A missing asset would leave a blank scene on video: refuse it up front.
    final missing = [
      for (final a in usedAssets)
        if (!File('${SmokeArtifacts.testAssetsDir.path}/$a').existsSync()) a,
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Smoke "$testTitle" uses test assets that do not exist under ${SmokeArtifacts.testAssetsDir.path}: '
        '${missing.join(', ')}.',
      );
    }
    final s = sceneUnitsPerMetre;
    final bool ownsEngine = (engine == null);
    final FilamentEngine effectiveEngine = engine ?? FilamentEngine.create()!;
    final scene = effectiveEngine.createScene();
    final view = effectiveEngine.createView();
    final cameraEntity = effectiveEngine.createEntity();
    final camera = effectiveEngine.createCamera(cameraEntity);
    final renderer = effectiveEngine.createRenderer();
    final swapChain = effectiveEngine.createHeadlessSwapChain(width, height);

    view.scene = scene;
    view.camera = camera;
    view.setViewport(0, 0, width, height);

    camera.setProjection(
      fovDegrees: 45.0,
      aspect: width / height,
      near: near ?? 0.1 * s,
      far: far ?? 1000.0 * s,
      direction: FovDirection.vertical,
    );

    // Skybox & Studio Lighting
    final skybox = FilamentSkybox.build(
      effectiveEngine,
      color: Vector4(0.12, 0.14, 0.18, 1.0),
      intensity: 30000.0,
    );
    scene.setSkybox(skybox);

    final sunEntity = effectiveEngine.createEntity();
    LightBuilder(LightType.directional)
        .color(1.0, 0.98, 0.95)
        .intensity(100000.0)
        .direction(-0.4, -0.8, -0.6)
        .castShadows(true)
        .build(effectiveEngine, sunEntity);
    scene.addEntity(sunEntity);

    final indirectLight = FilamentIndirectLight.build(
      effectiveEngine,
      irradiance: SphericalHarmonics(bands: 1, coefficients: [0.6, 0.65, 0.7]),
      intensity: 35000.0,
    );
    scene.setIndirectLight(indirectLight);

    final matProvider = FilamentMaterialProvider.ubershader(effectiveEngine);
    final assetLoader = FilamentAssetLoader.create(
      engine: effectiveEngine,
      materialProvider: matProvider,
    );

    final loadedAssets = <FilamentAsset>[];
    final assetsDir = SmokeArtifacts.testAssetsDir;

    for (int i = 0; i < usedAssets.length; i++) {
      final path = '${assetsDir.path}/${usedAssets[i]}';
      final bytes = File(path).readAsBytesSync();
      final asset = assetLoader.createAsset(bytes);
      if (asset == null) {
        throw StateError(
          'Smoke "$testTitle": Filament could not load test asset ${usedAssets[i]}.',
        );
      }

      final rLoader = FilamentResourceLoader.create(
        engine: effectiveEngine,
        normalizeSkinningWeights: true,
      );
      rLoader.registerDefaultProviders(effectiveEngine);
      rLoader.loadResources(asset);
      rLoader.dispose();

      asset.addToScene(scene);
      loadedAssets.add(asset);

      final aabb = asset.getBoundingBox();
      final size = aabb.max - aabb.min;
      final maxDim = math.max(size.x, math.max(size.y, size.z));
      final targetSize = 1.2 * s;
      final scale = maxDim > 0 ? targetSize / maxDim : 1.0;

      final xOffset = (i - (usedAssets.length - 1) / 2.0) * 1.6 * s;
      final yOffset = -aabb.min.y * scale;

      final root = asset.rootEntity;
      final mat = Matrix4.identity()
        ..setTranslationRaw(xOffset, yOffset, 0.0)
        ..scaleByDouble(scale, scale, scale, 1.0);
      FilamentTransformManager(
        effectiveEngine,
      ).setTransform(root, mat.storage.toList());
    }

    final totalFrames = (durationSeconds * fps).round();
    final nativeBuf = calloc<ffi.Uint8>(width * height * 4);
    // Every simulated frame goes into the video at the render resolution, streamed rather than held.
    final recorder = SmokeVideoRecorder(
      width: width,
      height: height,
      fps: fps,
      testName: testTitle,
    );
    Uint8List? firstFrameRgba;
    Uint8List? middleScreenshotRgba;

    try {
      if (onSetup != null) {
        await onSetup(effectiveEngine, scene, view, camera, loadedAssets);
      }
      for (int frame = 0; frame < totalFrames; frame++) {
        final t = frame / totalFrames;
        final timeSeconds = t * durationSeconds;

        if (onFrame != null) {
          onFrame(
            effectiveEngine,
            scene,
            view,
            camera,
            loadedAssets,
            frame,
            totalFrames,
            timeSeconds,
          );
        } else {
          final angle = t * math.pi * 2.0;
          final camDist = 3.5 * s;
          final camX = math.sin(angle) * camDist;
          final camZ = math.cos(angle) * camDist;
          final camY = (1.8 + math.sin(t * math.pi * 4.0) * 0.3) * s;

          camera.lookAt(
            eyeX: camX,
            eyeY: camY,
            eyeZ: camZ,
            centerX: 0.0,
            centerY: 0.6 * s,
            centerZ: 0.0,
          );
        }

        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          renderer.readPixelsInto(nativeBuf, x: 0, y: 0, width: width, height: height);
          renderer.endFrame();
        }

        effectiveEngine.flushAndWait();
        final framePixels = nativeBuf.asTypedList(width * height * 4);
        recorder.addFrame(framePixels);

        if (frame == 0) {
          firstFrameRgba = Uint8List.fromList(framePixels);
        }
        if (frame == (totalFrames ~/ 2)) {
          middleScreenshotRgba = Uint8List.fromList(framePixels);
        }
      }

      calloc.free(nativeBuf);

      // Save screenshot
      final screenshotBytes = SmokeArtifacts.encodePng(
        width,
        height,
        middleScreenshotRgba ?? firstFrameRgba!,
        flipY: false,
      );
      SmokeArtifacts.saveScreenshot(testTitle, screenshotBytes, usedAssets: usedAssets);

      // Save the WebM video of every simulated frame.
      final videoBytes = recorder.finish();
      SmokeArtifacts.saveVideo(
        testTitle,
        videoBytes,
        extension: 'webm',
        usedAssets: usedAssets,
      );
    } finally {
      recorder.discard();
      if (onTeardown != null) await onTeardown();
    }

    // Cleanup resources
    for (final asset in loadedAssets) {
      asset.removeFromScene(scene);
      asset.dispose();
    }
    assetLoader.dispose();
    matProvider.dispose();
    skybox.dispose();
    indirectLight.dispose();
    view.dispose();
    scene.dispose();
    effectiveEngine.destroyEntity(sunEntity);
    effectiveEngine.destroyEntity(cameraEntity);
    camera.dispose();
    renderer.dispose();
    swapChain.dispose();
    if (ownsEngine && autoDisposeEngine) {
      effectiveEngine.dispose();
    }
  }
}
