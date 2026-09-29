import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:image/image.dart' as img;
import 'package:vector_math/vector_math_64.dart';

import '../../src/math/axes.dart';
import '../../src/math/units.dart';
import '../models/lumina_asset.dart';
import 'derived_data_cache.dart';
import 'engine_logger_service.dart';
import 'primitive_glb_factory.dart';

part 'filament_thumbnail_renderer/state.dart';
part 'filament_thumbnail_renderer/material_preview.dart';

/// One glTF binary placed in a thumbnail scene.
///
/// [transform] is the placement in world space (Y up, centimetres).
/// [unitScale] converts the glTF's own units into world units: imported glTF
/// is metres and is drawn ×[LuminaUnits.unitsPerMetre], exactly as
/// `LuminaStaticMeshComponent.assetUnitScale` draws it in a level; geometry
/// generated in world units (primitives) uses 1.
class ThumbnailMeshPart {
  final Uint8List glb;
  final Matrix4 transform;
  final double unitScale;

  /// The animation pose to draw a skinned mesh in; its rest pose when null.
  final ThumbnailPose? pose;

  ThumbnailMeshPart(this.glb, {Matrix4? transform, this.unitScale = LuminaUnits.unitsPerMetre, this.pose})
      : transform = transform ?? Matrix4.identity();
}

/// A frame of an animation clip stored in a mesh's GLB: the clip named
/// [clip] (else the one at [clipIndex]), at [fraction] of its length — an
/// animation sequence's thumbnail is its mesh at the middle of the clip.
class ThumbnailPose {
  final String? clip;
  final int? clipIndex;
  final double fraction;

  const ThumbnailPose({this.clip, this.clipIndex, this.fraction = 0.5});

  /// The gltfio animation index this pose names in [names], or null.
  int? indexIn(List<String> names) {
    final byName = clip == null ? -1 : names.indexOf(clip!);
    if (byName >= 0) return byName;
    final i = clipIndex;
    return i != null && i >= 0 && i < names.length ? i : null;
  }

  @override
  String toString() => 'ThumbnailPose(${clip ?? '#$clipIndex'} @ $fraction)';
}

/// Renders asset thumbnails offscreen with Filament.
///
/// It draws on the process's shared engine (flutter_filament
/// `FilamentEngineHost`), leased on first use and released by
/// [dispose], with its own headless swap chain, renderer, view and scene: the
/// editor's viewports and the thumbnail queue are one Vulkan device, not one
/// each. The engine is on the GPU every engine in the process uses
/// (`FilamentEngine.defaultGpuPreference`, which the editor sets from its
/// Graphics Device setting, then `FILAMENT_GPU`).
///
/// Every render is lit by the same studio rig (a sun, image-based lighting and
/// a neutral backdrop) and framed from a three-quarter view onto the bounds of
/// what was drawn, with the near and far planes taken from those bounds, so a
/// 3 cm bolt and a 30 m level both fill the frame. The frame is rendered at
/// [supersample]× and averaged down to [size]² before it is encoded.
///
/// Renders are serialized: callers may overlap, the engine never does.
class FilamentThumbnailRenderer extends _FilamentThumbnailRendererState
    with
        _ThumbnailMaterialPreview {
  FilamentThumbnailRenderer({
    super.size,
    super.supersample,
    super.sunIntensity,
    super.iblIntensity,
    super.backdrop,
    super.iblKtx,
  });

  static FilamentThumbnailRenderer? _shared;

  /// The process-wide renderer the editor's thumbnail queue uses.
  static FilamentThumbnailRenderer get shared => _shared ??= FilamentThumbnailRenderer();

  int get _px => size * supersample;

  /// False once the engine could not be created (no GPU, no driver); every
  /// render then returns null and callers keep their fallback.
  bool get isAvailable => !_failed && !_disposed;

  /// Sets the image-based light (a KTX1 cubemap, e.g. Filament's
  /// `default_env_ibl.ktx`). Without one the rig uses a neutral
  /// spherical-harmonics ambient.
  set environmentIbl(Uint8List? ktx) {
    if (identical(ktx, _iblKtx)) return;
    _iblKtx = ktx;
    if (_engine != null) {
      _tail = _tail.then((_) => _buildLighting());
    }
  }

  Uint8List? get environmentIbl => _iblKtx;

  // ---------------------------------------------------------------------------
  // Public renders
  // ---------------------------------------------------------------------------

  /// A static or skeletal mesh (GLB / glTF bytes, metres), drawn ×100 like a
  /// level draws it. Null when nothing could be loaded or rendered.
  Future<Uint8List?> renderMesh(Uint8List glb) => renderMeshParts([ThumbnailMeshPart(glb)]);

  /// Several meshes in one frame (a Blueprint's mesh components, a level).
  Future<Uint8List?> renderMeshParts(List<ThumbnailMeshPart> parts, {double pitchDegrees = 22}) {
    if (parts.isEmpty) return Future.value(null);
    return _serialized(() => _renderParts(parts, pitchDegrees: pitchDegrees));
  }

  /// A material on a preview sphere: its compiled package when it has one,
  /// else compiled from its `.mat` source; when neither yields a package the
  /// sphere gets a default lit material in the material's base colour (the
  /// Material Editor's fallback). Texture references resolve against
  /// [projectRoot].
  Future<Uint8List?> renderMaterial(LuminaAsset material, {String? projectRoot}) =>
      _serialized(() => _renderMaterial(material, projectRoot: projectRoot));

  /// A level from its stored actors (`metadata.actors`: centimetres, Z up):
  /// its primitives and meshes, framed from above on the bounds of the level.
  /// Mesh paths resolve against [projectRoot].
  Future<Uint8List?> renderLevel(List<Map<String, dynamic>> actors, {String? projectRoot}) async {
    final parts = await levelParts(actors, projectRoot: projectRoot);
    if (parts.isEmpty) return null;
    return renderMeshParts(parts, pitchDegrees: 35);
  }

  /// The drawable pieces of a level: primitives (built in world units) and
  /// mesh actors (glTF metres), each placed by its stored transform converted
  /// from Z up to the runtime's Y up.
  static Future<List<ThumbnailMeshPart>> levelParts(List<Map<String, dynamic>> actors, {String? projectRoot}) async {
    final parts = <ThumbnailMeshPart>[];
    for (final a in actors) {
      if (a['isVisible'] == false) continue;
      final type = (a['type'] ?? '').toString();
      final transform = authoringTransform(a['location'], a['rotation'], a['scale']);
      if (type == 'Primitive') {
        final props = _componentProperties(a, 'LuminaProceduralMeshComponent');
        double dim(String key) => props[key] is num ? (props[key] as num).toDouble() : 100.0;
        final glb = PrimitiveGlbFactory.build(
          shape: (props['shape'] ?? 'box').toString(),
          sizeX: dim('sizeX'),
          sizeY: props['sizeY'] is num ? (props['sizeY'] as num).toDouble() : 100.0,
          sizeZ: dim('sizeZ'),
          colorHex: (props['colorHex'] ?? '#9AA3AE').toString(),
        );
        parts.add(ThumbnailMeshPart(glb, transform: transform, unitScale: 1.0));
        continue;
      }
      if (type == 'Mesh' || type == 'StaticMesh' || type == 'SkeletalMesh') {
        final path = a['meshAssetPath'];
        if (path is! String || path.isEmpty) continue;
        final resolved = resolveProjectPath(path, projectRoot);
        final glb = resolved == null ? null : await loadMeshGlb(resolved);
        if (glb != null) parts.add(ThumbnailMeshPart(glb, transform: transform));
      }
    }
    return parts;
  }

  /// A stored (Z up, cm, degrees) transform as a runtime (Y up) matrix, the
  /// conversion the level code generator emits ([LuminaAxes]).
  static Matrix4 authoringTransform(dynamic location, dynamic rotation, dynamic scale) {
    List<num> v(dynamic x, num fallback) =>
        x is List && x.length >= 3 && x.every((e) => e is num) ? x.cast<num>() : [fallback, fallback, fallback];
    return Matrix4.compose(
      LuminaAxes.location(v(location, 0)),
      LuminaAxes.rotation(v(rotation, 0)),
      LuminaAxes.scale(v(scale, 1)),
    );
  }

  /// [path] as an openable file: absolute and existing paths as they are,
  /// project-relative ones (`contents/…`) under [projectRoot].
  static String? resolveProjectPath(String path, String? projectRoot) {
    if (File(path).existsSync()) return path;
    if (projectRoot == null) return null;
    final p = path.replaceAll('\\', '/');
    final i = p.indexOf('contents/');
    final candidate = '$projectRoot/${i < 0 ? p : p.substring(i)}';
    return File(candidate).existsSync() ? candidate : null;
  }

  /// The GLB a mesh file draws: a `.glb`/`.gltf` as it is, a `.lmas`'s
  /// embedded payload or its `.entity.glb` companion. Run through the import
  /// sanitizer (TGA → PNG, texture budget, four skin influences) so gltfio can
  /// load it; already-sanitized files pass straight through.
  static Future<Uint8List?> loadMeshGlb(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    Uint8List? glb;
    if (path.endsWith('.lmas')) {
      final companion = File(path.replaceAll(RegExp(r'\.lmas$'), '.entity.glb'));
      try {
        final payload = LuminaAsset.fromBytes(file.readAsBytesSync()).rawPayload;
        if (_isGltf(payload)) glb = payload;
      } catch (_) {}
      if (glb == null && companion.existsSync()) glb = companion.readAsBytesSync();
    } else {
      final bytes = file.readAsBytesSync();
      if (_isGltf(bytes)) glb = bytes;
    }
    if (glb == null) return null;
    try {
      final parent = file.parent.path;
      // Oversized source art is budgeted once per project, not per session.
      return await DerivedDataCache.sanitizeGlbForAsset(path, glb, searchDirs: [parent, '$parent/../../textures']);
    } catch (_) {
      return glb;
    }
  }

  static bool _isGltf(Uint8List? b) =>
      b != null && b.length > 20 && ((b[0] == 0x67 && b[1] == 0x6C && b[2] == 0x54 && b[3] == 0x46) || b[0] == 0x7B);

  static Map<String, dynamic> _componentProperties(Map<String, dynamic> actor, String type) {
    final components = actor['components'];
    if (components is! List) return const {};
    for (final c in components) {
      if (c is Map && c['type'] == type && c['properties'] is Map) {
        return Map<String, dynamic>.from(c['properties'] as Map);
      }
    }
    return const {};
  }

  /// Releases the engine and everything on it.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (identical(_shared, this)) _shared = null;
    _teardownEngine();
  }

  // ---------------------------------------------------------------------------
  // Engine
  // ---------------------------------------------------------------------------

  Future<T?> _serialized<T>(Future<T?> Function() body) {
    final result = Completer<T?>();
    _tail = _tail.then((_) async {
      if (_disposed) return result.complete(null);
      try {
        result.complete(await body());
      } catch (e, st) {
        _logger.log('Thumbnail render failed: $e\n$st', level: 'warning', source: 'ThumbnailRenderer');
        result.complete(null);
      }
    });
    return result.future;
  }

  @override
  bool _ensureEngine() {
    if (_engine != null) return true;
    if (_failed || _disposed) return false;
    try {
      final lease = FilamentEngineHost.acquire(owner: 'FilamentThumbnailRenderer');
      if (lease == null) {
        _failed = true;
        _logger.log('Thumbnail renderer: no Filament engine on this host', level: 'warning', source: 'ThumbnailRenderer');
        return false;
      }
      _lease = lease;
      final engine = lease.engine;
      _engine = engine;
      _scene = engine.createScene();
      _view = engine.createView();
      _renderer = engine.createRenderer();
      _swapChain = engine.createHeadlessSwapChain(_px, _px);
      _cameraEntity = engine.createEntity();
      _camera = engine.createCamera(_cameraEntity);
      _view!
        ..scene = _scene!
        ..camera = _camera!
        ..setViewport(0, 0, _px, _px)
        ..postProcessingEnabled = true
        ..shadowingEnabled = true
        ..antiAliasing = 1; // FXAA, on top of the supersampling.
      // Khronos PBR Neutral: base colours come out as authored (hue and
      // saturation kept), which is what a thumbnail is for.
      final toneMapper = ToneMapper.pbrNeutral();
      try {
        _colorGrading = (ColorGradingBuilder()..toneMapper(toneMapper)).build(engine);
        _view!.colorGrading = _colorGrading;
      } finally {
        toneMapper.destroy();
      }

      // Studio key light: a warm sun from high on the camera's left, so the
      // highlight sits off-centre and the far side falls into shade.
      _sunEntity = engine.createEntity();
      LightBuilder(LightType.directional)
          .color(1.0, 0.97, 0.92)
          .intensity(sunIntensity)
          .direction(0.55, -0.75, -0.35)
          .castShadows(true)
          .build(engine, _sunEntity);
      _scene!.addEntity(_sunEntity);
      _buildLighting();

      _provider = FilamentMaterialProvider.ubershader(engine);
      _loader = FilamentAssetLoader.create(engine: engine, materialProvider: _provider!);
      _resources = FilamentResourceLoader.create(engine: engine, normalizeSkinningWeights: true)
        ..registerDefaultProviders(engine);
      _logger.log(
        'Thumbnail renderer: headless ${_px}px engine on ${engine.gpuName.isEmpty ? engine.backend.name : engine.gpuName}',
        level: 'info',
        source: 'ThumbnailRenderer',
      );
      return true;
    } catch (e) {
      _failed = true;
      _logger.log('Thumbnail renderer: engine creation failed: $e', level: 'warning', source: 'ThumbnailRenderer');
      _teardownEngine();
      return false;
    }
  }

  /// Neutral backdrop + image-based light (the IBL when one was given).
  void _buildLighting() {
    final engine = _engine;
    final scene = _scene;
    if (engine == null || scene == null) return;
    scene.setSkybox(null);
    scene.setIndirectLight(null);
    _skybox?.dispose();
    _indirectLight?.dispose();
    _skybox = FilamentSkybox.build(engine, color: Vector4(backdrop, backdrop, backdrop, 1.0), intensity: 30000);
    final ibl = _iblKtx;
    FilamentIndirectLight? light;
    if (ibl != null && ibl.isNotEmpty) {
      try {
        light = FilamentIndirectLight.fromKtx(engine, ibl, intensity: iblIntensity);
      } catch (e) {
        _logger.log('Thumbnail renderer: IBL rejected ($e); using ambient', level: 'warning', source: 'ThumbnailRenderer');
      }
    }
    light ??= FilamentIndirectLight.build(
      engine,
      irradiance: SphericalHarmonics(bands: 1, coefficients: [0.65, 0.66, 0.7]),
      intensity: iblIntensity,
    );
    _indirectLight = light;
    scene.setSkybox(_skybox);
    scene.setIndirectLight(_indirectLight);
  }

  void _teardownEngine() {
    final engine = _engine;
    if (engine == null) return;
    try {
      _sphereIb?.dispose();
      _sphereVb?.dispose();
      _resources?.dispose();
      _loader?.dispose();
      _provider?.dispose();
      _scene?.setSkybox(null);
      _scene?.setIndirectLight(null);
      _skybox?.dispose();
      _indirectLight?.dispose();
      if (_sunEntity != 0) {
        engine.destroyEntityComponents(_sunEntity);
        engine.destroyEntity(_sunEntity);
      }
      // Only this renderer's objects: the engine is shared.
      _view?.colorGrading = null;
      _colorGrading?.destroy();
      _view?.dispose();
      _scene?.dispose();
      _camera?.dispose();
      if (_cameraEntity != 0) engine.destroyEntity(_cameraEntity);
      _renderer?.dispose();
      _swapChain?.dispose();
    } catch (e) {
      _logger.log('Thumbnail renderer teardown: $e', level: 'warning', source: 'ThumbnailRenderer');
    }
    _lease?.release();
    _lease = null;
    _cameraEntity = 0;
    _engine = null;
    _scene = null;
    _view = null;
    _renderer = null;
    _swapChain = null;
    _camera = null;
    _skybox = null;
    _indirectLight = null;
    _colorGrading = null;
    _provider = null;
    _loader = null;
    _resources = null;
    _sphereVb = null;
    _sphereIb = null;
    _sunEntity = 0;
  }

  // ---------------------------------------------------------------------------
  // Meshes
  // ---------------------------------------------------------------------------

  Future<Uint8List?> _renderParts(List<ThumbnailMeshPart> parts, {required double pitchDegrees}) async {
    if (!_ensureEngine()) return null;
    final engine = _engine!;
    final scene = _scene!;
    final loader = _loader!;
    final tm = FilamentTransformManager(engine);
    final loaded = <FilamentAsset>[];
    final entities = <int>[];
    Aabb3? bounds;
    try {
      for (final part in parts) {
        final (asset, instances) = loader.createInstancedAsset(part.glb, 1);
        if (asset == null) continue;
        loaded.add(asset);
        if (instances.isEmpty) continue;
        try {
          await _resources!.loadAsync(asset).timeout(const Duration(seconds: 60));
        } on TimeoutException {
          _resources!.asyncCancelLoad();
          continue;
        }
        final instance = instances.first;
        final pose = part.pose;
        if (pose != null) _applyPose(instance.animator, pose);
        if (instance.skinCount > 0) {
          // The pose (or the rest pose): without it the skinning buffer
          // holds no bones.
          instance.animator.updateBoneMatrices();
        }
        final matrix = part.unitScale == 1.0
            ? part.transform
            : (Matrix4.copy(part.transform)..multiply(Matrix4.diagonal3Values(part.unitScale, part.unitScale, part.unitScale)));
        tm.setTransform(instance.root, matrix.storage.toList());
        final box = instance.boundingBox;
        if (box.min.x <= box.max.x && box.min.y <= box.max.y && box.min.z <= box.max.z) {
          final world = _transformBox(box.min, box.max, matrix);
          bounds = bounds == null ? world : (bounds..hull(world));
        }
        final list = instance.entities;
        scene.addEntities(list);
        entities.addAll(list);
      }
      if (bounds == null) return null;
      _frame(bounds, pitchDegrees: pitchDegrees);
      return await _captureAndEncode();
    } finally {
      if (entities.isNotEmpty) scene.removeEntities(entities);
      for (final asset in loaded) {
        try {
          loader.destroyAsset(asset);
        } catch (_) {}
      }
      engine.flushAndWait();
    }
  }

  /// Poses the asset's nodes at [pose]'s frame; a clip the asset does not
  /// have leaves the rest pose (and says so).
  void _applyPose(FilamentAnimator animator, ThumbnailPose pose) {
    final names = [for (var i = 0; i < animator.animationCount; i++) animator.getAnimationName(i)];
    final index = pose.indexIn(names);
    if (index == null) {
      _logger.log('Thumbnail: $pose is not in the mesh (${names.join(', ')}); drawing the rest pose',
          level: 'warning', source: 'ThumbnailRenderer');
      return;
    }
    final duration = animator.getAnimationDuration(index);
    animator.applyAnimation(index, duration * pose.fraction.clamp(0.0, 1.0));
  }

  static Aabb3 _transformBox(Vector3 min, Vector3 max, Matrix4 m) {
    final out = Aabb3.minMax(Vector3.all(double.infinity), Vector3.all(-double.infinity));
    for (var i = 0; i < 8; i++) {
      final corner = Vector3(i & 1 == 0 ? min.x : max.x, i & 2 == 0 ? min.y : max.y, i & 4 == 0 ? min.z : max.z);
      out.hullPoint(m.transformed3(corner));
    }
    return out;
  }

  /// Places the camera on a three-quarter view (yaw 35°, [pitchDegrees] up)
  /// so every corner of [bounds] is inside the frustum, with near and far
  /// planes hugging the bounds.
  @override
  void _frame(Aabb3 bounds, {required double pitchDegrees}) {
    const fovDegrees = 30.0;
    const margin = 1.08;
    final center = bounds.center;
    final yaw = 35.0 * math.pi / 180.0;
    final pitch = pitchDegrees * math.pi / 180.0;
    // Direction from the target towards the eye; glTF faces +Z, so this is
    // front-right-above.
    final dir = Vector3(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))..normalize();
    final right = Vector3(0, 1, 0).cross(dir)..normalize();
    final up = dir.cross(right)..normalize();
    final tanHalf = math.tan(fovDegrees * math.pi / 360.0);

    var distance = 0.0;
    var radius = 0.0;
    for (var i = 0; i < 8; i++) {
      final corner = Vector3(
        i & 1 == 0 ? bounds.min.x : bounds.max.x,
        i & 2 == 0 ? bounds.min.y : bounds.max.y,
        i & 4 == 0 ? bounds.min.z : bounds.max.z,
      );
      final p = corner - center;
      radius = math.max(radius, p.length);
      final along = p.dot(dir);
      distance = math.max(distance, along + p.dot(right).abs() / tanHalf);
      distance = math.max(distance, along + p.dot(up).abs() / tanHalf);
    }
    radius = math.max(radius, 1e-3);
    distance = math.max(distance * margin, radius * 1.05);

    final near = math.max(distance - radius * 1.5, radius * 0.02);
    final far = distance + radius * 1.5;
    final eye = center + dir * distance;
    _camera!
      ..setProjection(fovDegrees: fovDegrees, aspect: 1.0, near: near, far: far, direction: FovDirection.vertical)
      ..lookAt(eyeX: eye.x, eyeY: eye.y, eyeZ: eye.z, centerX: center.x, centerY: center.y, centerZ: center.z);
  }

  /// Renders a few frames (shadows and uploads settle), reads the last one
  /// back and encodes it as a [size]² PNG off the calling isolate.
  @override
  Future<Uint8List?> _captureAndEncode() async {
    final renderer = _renderer!;
    final engine = _engine!;
    final px = _px;
    final pixels = Uint8List(px * px * 4);
    var rendered = 0;
    for (var attempt = 0; attempt < 20 && rendered < 3; attempt++) {
      if (renderer.beginFrame(_swapChain!)) {
        renderer.render(_view!);
        rendered++;
        if (rendered == 3) {
          renderer.readPixels(x: 0, y: 0, width: px, height: px, outPixels: pixels);
        }
        renderer.endFrame();
      }
      engine.flushAndWait();
    }
    if (rendered < 3) return null;
    final out = size;
    final flip = engine.backend == FilamentBackend.opengl;
    return Isolate.run(() => _encodeFrame(pixels, px, out, flip));
  }

  /// RGBA → opaque PNG, box-filtered from [px]² to [out]².
  static Uint8List _encodeFrame(Uint8List rgba, int px, int out, bool flip) {
    var image = img.Image.fromBytes(width: px, height: px, bytes: rgba.buffer, numChannels: 4);
    // A GL swap chain reads back bottom row first; Vulkan top row first.
    if (flip) image = img.flipVertical(image);
    if (px != out) {
      image = img.copyResize(image, width: out, height: out, interpolation: img.Interpolation.average);
    }
    return img.encodePng(image.convert(numChannels: 3));
  }

  // ---------------------------------------------------------------------------
  // Materials
  // ---------------------------------------------------------------------------

  static const String _fallbackSource = '''material {
    name : "LuminaThumbnailFallback",
    shadingModel : lit,
    parameters : [
        { type : float4, name : baseColor },
        { type : float, name : roughness },
        { type : float, name : metallic }
    ],
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = materialParams.baseColor;
        material.roughness = materialParams.roughness;
        material.metallic = materialParams.metallic;
    }
}
''';

  /// Whether [bytes] is a compiled `.filamat` package: a `MAT_VERS` chunk of
  /// size 4. Filament aborts the process on anything else.
  static bool isFilamatPackage(Uint8List? bytes) {
    const magic = [0x53, 0x52, 0x45, 0x56, 0x5F, 0x54, 0x41, 0x4D];
    if (bytes == null || bytes.length < 16) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return ByteData.view(bytes.buffer, bytes.offsetInBytes + 8, 4).getUint32(0, Endian.little) == 4;
  }

  /// The values a material instance starts with: the `.mat` header's
  /// `default :` entries, overridden by what the Material Editor saved in
  /// `metadata.parameter_defaults`.
  static Map<String, Object?> materialParameterValues(LuminaAsset material) {
    final values = <String, Object?>{};
    for (final p in _headerParameters(material.rawMatSource)) {
      if (p.defaultValue != null) values[p.name] = p.defaultValue;
    }
    final saved = material.metadata['parameter_defaults'];
    if (saved != null && saved.isNotEmpty) {
      try {
        final decoded = jsonDecode(saved);
        if (decoded is Map) {
          decoded.forEach((k, v) => values[k.toString()] = v);
        }
      } catch (_) {}
    }
    return values;
  }

  // --- the preview sphere ------------------------------------------------------

  /// 50 cm: the size of the Material Editor's preview sphere in a level.
  static const double _sphereRadius = 50.0;
  static const int _stride = 12 + 8 + 8;
}
