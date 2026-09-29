// Shared helpers for `test/smoke/<module>_smoke_test.dart` scenarios.
//
// Every smoke scenario boots a *real* FilamentEngine on the backend selected by
// `FILAMENT_SMOKE_BACKEND` (opengl|vulkan|noop, default opengl), renders through
// a headless swap chain, reads pixels back and publishes PNG / WebM evidence
// through `SmokeArtifacts` so it lands in `build/smoke_report.html`.

import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:flutter_filament/testing.dart';

/// Root of the shared real 3D assets (the workspace's `test-assets/`, or
/// `LUMINA_TEST_ASSETS`).
final Directory testAssets = SmokeArtifacts.testAssetsDir;

/// Backend selected by `FILAMENT_SMOKE_BACKEND` (default opengl).
String get smokeBackendName => Platform.environment['FILAMENT_SMOKE_BACKEND'] ?? 'opengl';

FilamentBackend get smokeBackend => switch (smokeBackendName) {
      'vulkan' => FilamentBackend.vulkan,
      'noop' => FilamentBackend.noop,
      'default' => FilamentBackend.defaultBackend,
      _ => FilamentBackend.opengl,
    };

/// Frame rate of every smoke video recorded through [SmokeRig.video]: the
/// lowest `SmokeArtifacts` accepts (`minimumVideoFps`).
const double smokeVideoFps = SmokeArtifacts.minimumVideoFps;

/// Render size of every rig that records a smoke video: the smallest frame
/// `SmokeArtifacts` accepts (`minimumVideoWidth`×`minimumVideoHeight`,
/// 1024×768, the 4:3 aspect the 320×240 / 400×300 scenes were framed for).
/// Square scenes use [smokeVideoWidth] for both sides.
const int smokeVideoWidth = SmokeArtifacts.minimumVideoWidth;

/// See [smokeVideoWidth].
const int smokeVideoHeight = SmokeArtifacts.minimumVideoHeight;

/// Frames a smoke video records at [fps]: exactly the minimum length
/// `SmokeArtifacts` accepts (`minimumVideoSeconds`, 10 s → 300 frames at 30 fps).
int smokeVideoFrames({double fps = smokeVideoFps}) => SmokeArtifacts.framesForSeconds(fps);

/// How long [SmokeRig.renderFrame] keeps retrying `beginFrame` before giving up.
const Duration renderFrameTimeout = Duration(seconds: 60);

/// Reads a real asset from `test-assets/` and records it for the report badge.
Uint8List loadTestAsset(String relativePath) {
  final file = File('${testAssets.path}/$relativePath');
  if (!file.existsSync()) {
    throw StateError('missing test asset: ${file.path}');
  }
  SmokeArtifacts.recordAsset(file.absolute.path);
  return file.readAsBytesSync();
}

/// A minimal headless render rig: engine, swap chain, renderer, scene, view,
/// camera. Disposal order mirrors what Filament expects.
class SmokeRig {
  SmokeRig._(this.engine, this.swapChain, this.renderer, this.scene, this.view,
      this.cameraEntity, this.camera, this.width, this.height);

  final FilamentEngine engine;
  final FilamentSwapChain swapChain;
  final FilamentRenderer renderer;
  final FilamentScene scene;
  final FilamentView view;
  final int cameraEntity;
  final FilamentCamera camera;
  final int width;
  final int height;
  final List<int> entities = [];

  factory SmokeRig.create({int width = 320, int height = 240, FilamentBackend? backend}) {
    final engine = FilamentEngine.create(backend: backend ?? smokeBackend);
    if (engine == null) {
      throw StateError('engine creation failed for $smokeBackendName');
    }
    return SmokeRig.adopt(engine, width: width, height: height);
  }

  /// Builds the rig around an engine the caller already created.
  factory SmokeRig.adopt(FilamentEngine engine, {int width = 320, int height = 240, dynamic swapChainFlags = 0}) {
    final swapChain = engine.createHeadlessSwapChain(width, height, flags: swapChainFlags);
    final renderer = engine.createRenderer();
    final scene = engine.createScene();
    final view = engine.createView();
    final cameraEntity = engine.createEntity();
    final camera = engine.createCamera(cameraEntity);
    view.scene = scene;
    view.camera = camera;
    view.setViewport(0, 0, width, height);
    camera.setProjection(fovDegrees: 45, aspect: width / height, near: 0.1, far: 1000);
    camera.lookAt(eyeX: 0, eyeY: 1, eyeZ: 5, centerX: 0, centerY: 0, centerZ: 0);
    renderer.setClearOptions(r: 0.05, g: 0.08, b: 0.15, a: 1);
    return SmokeRig._(engine, swapChain, renderer, scene, view, cameraEntity,
        camera, width, height);
  }

  /// Adds a white directional light so lit materials are visible.
  int addSun({double intensity = 100000}) {
    final e = engine.createEntity();
    LightBuilder(LightType.directional)
      ..color(1.0, 0.98, 0.95)
      ..intensity(intensity)
      ..direction(0.4, -1.0, -0.6)
      ..castShadows(true)
      ..build(engine, e);
    scene.addEntity(e);
    entities.add(e);
    return e;
  }

  /// Adds the bundled lightroom IBL (real KTX) so PBR assets are shaded.
  FilamentIndirectLight addIbl({double intensity = 30000}) {
    final ibl = FilamentIndirectLight.fromKtx(
      engine,
      File('example/assets/ibl/lightroom_14b/lightroom_14b_ibl.ktx').readAsBytesSync(),
      intensity: intensity,
    );
    scene.setIndirectLight(ibl);
    return ibl;
  }

  /// Renders [warmup] frames then reads back one RGBA8 frame (top-down rows).
  ///
  /// `beginFrame` skips frames while the GPU is behind, which happens when
  /// many smokes record 1024×768 videos on one GPU at once; retry for up to
  /// [renderFrameTimeout] instead of a fixed number of attempts.
  Uint8List renderFrame({int warmup = 3, void Function(int frame)? onFrame}) {
    final total = warmup + 1;
    final nativeBuf = calloc<ffi.Uint8>(width * height * 4);
    try {
      var rendered = 0;
      var attempts = 0;
      final clock = Stopwatch()..start();
      for (; rendered < total && (attempts < 200 || clock.elapsed < renderFrameTimeout); attempts++) {
        sleep(const Duration(milliseconds: 8));
        if (renderer.beginFrame(swapChain)) {
          rendered++;
          onFrame?.call(rendered - 1);
          renderer.render(view);
          if (rendered == total) {
            c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer,
                0, 0, width, height, nativeBuf.cast(), ffi.nullptr, ffi.nullptr);
          }
          renderer.endFrame();
        }
      }
      if (rendered < total) {
        throw StateError('could not render $total frames in $attempts attempts (${clock.elapsed.inMilliseconds} ms)');
      }
      engine.flushAndWait();
      // The C wrapper already delivers rows top-down on both GL and Vulkan
      // (verified with the renderable triangle apex at +Y).
      return Uint8List.fromList(nativeBuf.asTypedList(width * height * 4));
    } finally {
      calloc.free(nativeBuf);
    }
  }

  /// Renders one frame and publishes it as the PNG for [artifactName].
  Uint8List screenshot(String artifactName, {int warmup = 3}) {
    final pixels = renderFrame(warmup: warmup);
    SmokeArtifacts.saveScreenshot(artifactName, SmokeArtifacts.encodePng(width, height, pixels));
    return pixels;
  }

  /// Records [frames] frames, calling [onFrame] before each so the scene can
  /// animate, and publishes a WebM for [artifactName]. Returns the RGBA of
  /// the last frame. The PNG screenshot is taken from the middle frame.
  ///
  /// [frames] defaults to [smokeVideoFrames] for [fps]: the shortest video
  /// `SmokeArtifacts.saveVideoFromPngFrames` accepts (10 s). `t` in
  /// [onFrame] runs 0 → 1 over the whole recording; `frame / fps` is the
  /// playback time of the frame for real-time animation.
  Uint8List video(
    String artifactName, {
    int? frames,
    required void Function(int frame, double t) onFrame,
    double fps = smokeVideoFps,
    bool alsoScreenshot = true,
  }) {
    final count = frames ?? smokeVideoFrames(fps: fps);
    // Fail before rendering anything when the recording would be too short
    // or too small.
    SmokeArtifacts.checkVideoDuration(artifactName, count, fps);
    SmokeArtifacts.checkVideoSize(artifactName, width, height);
    final pngs = <Uint8List>[];
    Uint8List? last;
    for (var f = 0; f < count; f++) {
      onFrame(f, f / (count - 1).clamp(1, 1 << 30));
      last = renderFrame(warmup: f == 0 ? 3 : 0);
      pngs.add(SmokeArtifacts.encodePng(width, height, last));
    }
    SmokeArtifacts.saveVideoFromPngFrames(artifactName, pngs, fps: fps);
    if (alsoScreenshot) {
      SmokeArtifacts.saveScreenshot(artifactName, pngs[pngs.length ~/ 2]);
    }
    return last!;
  }

  /// Destroys this rig's entities (renderables, lights) now. Call it before
  /// disposing the material instances and buffers they use: Filament refuses
  /// (a precondition panic that aborts the test process) to destroy a
  /// MaterialInstance a renderable still uses.
  void releaseEntities() {
    for (final e in entities) {
      scene.removeEntity(e);
      engine.destroyEntity(e);
    }
    entities.clear();
  }

  void dispose() {
    for (final e in entities) {
      engine.destroyEntity(e);
    }
    engine.destroyEntity(cameraEntity);
    renderer.dispose();
    engine.dispose();
  }

  /// Destroys this rig's own viewport objects (view, scene, camera, renderer,
  /// swap chain, lights) and leaves the engine alive: for a rig adopted on a
  /// shared engine that other viewports still use.
  void disposeViewport() {
    engine.flushAndWait();
    view.dispose();
    scene.dispose();
    for (final e in entities) {
      engine.destroyEntityComponents(e);
      engine.destroyEntity(e);
    }
    entities.clear();
    camera.dispose();
    engine.destroyEntity(cameraEntity);
    renderer.dispose();
    swapChain.dispose();
  }
}

/// Pixel statistics used by assertions: how many pixels differ from the clear
/// colour / black, and how many distinct RGB values appear.
class FrameStats {
  FrameStats(this.nonBlack, this.distinct, this.total);
  final int nonBlack;
  final int distinct;
  final int total;
  double get nonBlackRatio => nonBlack / total;

  @override
  String toString() => 'FrameStats(nonBlack=$nonBlack/$total, distinct=$distinct)';
}

FrameStats frameStats(Uint8List rgba) {
  var nonBlack = 0;
  final distinct = <int>{};
  for (var i = 0; i < rgba.length; i += 4) {
    final rgb = (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2];
    if (rgba[i] > 8 || rgba[i + 1] > 8 || rgba[i + 2] > 8) nonBlack++;
    distinct.add(rgb);
  }
  return FrameStats(nonBlack, distinct.length, rgba.length ~/ 4);
}

/// Counts pixels that differ from the clear colour by more than [tolerance].
int countPixelsDifferingFrom(Uint8List rgba, int r, int g, int b, {int tolerance = 12}) {
  var n = 0;
  for (var i = 0; i < rgba.length; i += 4) {
    if ((rgba[i] - r).abs() > tolerance ||
        (rgba[i + 1] - g).abs() > tolerance ||
        (rgba[i + 2] - b).abs() > tolerance) {
      n++;
    }
  }
  return n;
}

/// Counts "foreground" pixels: those differing from the background colour,
/// sampled at the top-left corner (post-processing tone-maps the clear colour,
/// so the raw clear RGB cannot be used as the reference).
int countForegroundPixels(Uint8List rgba, int width, {int tolerance = 12}) {
  final i = (2 * width + 2) * 4;
  return countPixelsDifferingFrom(rgba, rgba[i], rgba[i + 1], rgba[i + 2], tolerance: tolerance);
}

/// Number of pixels that differ between two same-size RGBA frames.
int countChangedPixels(Uint8List a, Uint8List b, {int tolerance = 12}) {
  var n = 0;
  for (var i = 0; i < a.length; i += 4) {
    if ((a[i] - b[i]).abs() > tolerance ||
        (a[i + 1] - b[i + 1]).abs() > tolerance ||
        (a[i + 2] - b[i + 2]).abs() > tolerance) {
      n++;
    }
  }
  return n;
}

/// A loaded glTF asset with the loaders it depends on.
class LoadedGltf {
  LoadedGltf(this.materialProvider, this.assetLoader, this.resourceLoader, this.asset);
  final FilamentMaterialProvider materialProvider;
  final FilamentAssetLoader assetLoader;
  final FilamentResourceLoader resourceLoader;
  final FilamentAsset asset;

  void dispose(FilamentScene scene) {
    asset.removeFromScene(scene);
    assetLoader.destroyAsset(asset);
    resourceLoader.dispose();
    assetLoader.dispose();
    materialProvider.dispose();
  }
}

/// Loads a real GLB from `test-assets/`, uploads its resources, adds it to the
/// scene and frames the camera on its bounding box.
LoadedGltf loadGltfIntoScene(SmokeRig rig, String relativePath, {bool frameCamera = true}) {
  final bytes = loadTestAsset(relativePath);
  final provider = FilamentMaterialProvider.createUbershader(engine: rig.engine);
  final loader = FilamentAssetLoader.create(engine: rig.engine, materialProvider: provider);
  final asset = loader.createAsset(bytes);
  if (asset == null) throw StateError('createAsset failed for $relativePath');
  final resources = FilamentResourceLoader.create(engine: rig.engine);
  resources.registerDefaultProviders(rig.engine);
  if (!resources.loadResources(asset)) {
    throw StateError('loadResources failed for $relativePath');
  }
  asset.addToScene(rig.scene);
  if (frameCamera) frameCameraOn(rig, asset.getBoundingBox());
  return LoadedGltf(provider, loader, resources, asset);
}

/// Points the rig camera at [box] from a distance that fits it in view.
void frameCameraOn(SmokeRig rig, Aabb box, {double azimuth = 0.6, double elevation = 0.35}) {
  final center = box.center;
  final extent = box.max - box.min;
  final radius = [extent.x, extent.y, extent.z].reduce((a, b) => a > b ? a : b) / 2;
  final dist = radius * 2.6 + 0.1;
  final eyeX = center.x + dist * azimuth.clamp(-1.0, 1.0);
  final eyeY = center.y + dist * elevation;
  final eyeZ = center.z + dist;
  rig.camera.setProjection(fovDegrees: 45, aspect: rig.width / rig.height, near: dist * 0.01, far: dist * 20);
  rig.camera.lookAt(eyeX: eyeX, eyeY: eyeY, eyeZ: eyeZ, centerX: center.x, centerY: center.y, centerZ: center.z);
}

/// Legacy helper kept for existing scenarios: renders 30 frames and saves a PNG.
Future<void> renderSmokeTest({
  required FilamentEngine engine,
  required FilamentRenderer renderer,
  required FilamentView view,
  required FilamentSwapChain swapChain,
  required int width,
  required int height,
  required String artifactName,
}) async {
  final pixels = Uint8List(width * height * 4);
  final nativeBuf = calloc<ffi.Uint8>(width * height * 4);
  try {
    var rendered = 0;
    for (var attempt = 0; attempt < 200 && rendered < 30; attempt++) {
      sleep(const Duration(milliseconds: 16));
      if (renderer.beginFrame(swapChain)) {
        rendered++;
        renderer.render(view);
        if (rendered == 30) {
          c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer,
              0, 0, width, height, nativeBuf.cast(), ffi.nullptr, ffi.nullptr);
        }
        renderer.endFrame();
      }
    }
    if (rendered < 30) {
      throw StateError('Could not render 30 frames in 200 attempts');
    }
    engine.flushAndWait();
    pixels.setAll(0, nativeBuf.asTypedList(width * height * 4));
  } finally {
    calloc.free(nativeBuf);
  }
  SmokeArtifacts.saveScreenshot(artifactName, SmokeArtifacts.encodePng(width, height, pixels, flipY: true));
}

// -----------------------------------------------------------------------------
// Materials and geometry shared by the buffer / material / renderable smokes.
// -----------------------------------------------------------------------------

/// Compiles an unlit material with a `baseColor` float3 parameter (and an
/// optional `tex` sampler multiplied in when [textured]).
FilamentMaterial buildUnlitMaterial(FilamentEngine engine, {bool textured = false, bool vertexColor = false}) {
  FilamentMaterialBuilder.initEngine();
  final b = FilamentMaterialBuilder.create();
  b.setName(textured ? 'SmokeUnlitTextured' : 'SmokeUnlit');
  b.setShading(FilamatShading.unlit);
  b.setDoubleSided(true);
  b.requireAttribute(VertexAttribute.position.value);
  if (textured) {
    b.requireAttribute(VertexAttribute.uv0.value);
    b.addSamplerParameter('tex');
  }
  if (vertexColor) b.requireAttribute(VertexAttribute.color.value);
  b.addParameter('baseColor', UniformType.float3);
  b.setCode('''
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor.rgb = materialParams.baseColor;
        ${textured ? 'material.baseColor.rgb *= texture(materialParams_tex, getUV0()).rgb;' : ''}
        ${vertexColor ? 'material.baseColor.rgb *= getColor().rgb;' : ''}
    }
  ''');
  final bytes = b.build();
  b.dispose();
  if (bytes == null) throw StateError('filamat build failed');
  return FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: bytes);
}

/// A quad in the XY plane (side [size]) with positions (float3) in buffer 0
/// and uv0 (float2) in buffer 1; 6 ushort indices.
class SmokeQuad {
  SmokeQuad(this.vb, this.ib);
  final FilamentVertexBuffer vb;
  final FilamentIndexBuffer ib;

  static SmokeQuad create(FilamentEngine engine, {double size = 1.0, double z = 0.0}) {
    final vb = FilamentVertexBuffer.create(
      engine: engine,
      vertexCount: 4,
      bufferCount: 2,
      attributes: const [
        VertexAttributeDesc(attribute: VertexAttribute.position, bufferIndex: 0, type: AttributeType.float3, byteOffset: 0, byteStride: 12),
        VertexAttributeDesc(attribute: VertexAttribute.uv0, bufferIndex: 1, type: AttributeType.float2, byteOffset: 0, byteStride: 8),
      ],
    );
    final s = size / 2;
    vb.setData(Float32List.fromList([-s, -s, z, s, -s, z, s, s, z, -s, s, z]), bufferIndex: 0);
    vb.setData(Float32List.fromList([0, 1, 1, 1, 1, 0, 0, 0]), bufferIndex: 1);
    final ib = FilamentIndexBuffer.create(engine: engine, indexCount: 6, type: IndexType.ushort);
    ib.setUint16Data(Uint16List.fromList([0, 1, 2, 0, 2, 3]));
    return SmokeQuad(vb, ib);
  }

  void dispose() {
    ib.dispose();
    vb.dispose();
  }
}

/// Builds a renderable entity for [quad] with [mi] and adds it to the scene.
int addQuadRenderable(SmokeRig rig, SmokeQuad quad, FilamentMaterialInstance mi, {double extent = 1}) {
  final e = rig.engine.createEntity();
  RenderableBuilder(1)
    ..boundingBox(-extent, -extent, -extent, extent, extent, extent)
    ..culling(false)
    ..material(0, mi)
    ..geometry(0, PrimitiveType.triangles, quad.vb, ib: quad.ib)
    ..build(rig.engine, e);
  rig.scene.addEntity(e);
  rig.entities.add(e);
  return e;
}

/// Average RGB over a rectangle of [rgba] (top-down rows).
(double, double, double) averageColor(Uint8List rgba, int width, int x0, int y0, int w, int h) {
  double r = 0, g = 0, b = 0;
  for (var y = y0; y < y0 + h; y++) {
    for (var x = x0; x < x0 + w; x++) {
      final i = (y * width + x) * 4;
      r += rgba[i];
      g += rgba[i + 1];
      b += rgba[i + 2];
    }
  }
  final n = (w * h).toDouble();
  return (r / n, g / n, b / n);
}

/// RGB of one pixel (top-down rows).
(int, int, int) pixelAt(Uint8List rgba, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return (rgba[i], rgba[i + 1], rgba[i + 2]);
}

extension Uint8ListExt on Uint8List {
  static Uint8List zeros(int n) => Uint8List(n);
}
