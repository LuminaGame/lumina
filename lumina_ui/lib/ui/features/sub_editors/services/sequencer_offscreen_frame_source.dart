// ignore_for_file: implementation_imports
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart' show EditorActorNode;
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_evaluator.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_movie_render_service.dart';

/// One actor the movie render queue draws: its mesh on disk plus the pose the
/// level gave it, which the sampled channels then override per frame.
class SequencerRenderActor {
  final String actorId;
  final String name;

  /// Absolute path of a `.glb` to load; null renders nothing for this actor
  /// (a light or camera binding, for example).
  final String? meshPath;
  final List<double> location;
  final List<double> rotation;
  final List<double> scale;

  SequencerRenderActor({
    required this.actorId,
    required this.name,
    this.meshPath,
    List<double>? location,
    List<double>? rotation,
    List<double>? scale,
  }) : location = List<double>.from(location ?? const [0.0, 0.0, 0.0]),
       rotation = List<double>.from(rotation ?? const [0.0, 0.0, 0.0]),
       scale = List<double>.from(scale ?? const [1.0, 1.0, 1.0]);
}

/// Real Filament frame source: an offscreen View bound to its own
/// RenderTarget, drawn with `renderStandaloneView` *outside* any
/// beginFrame/endFrame block (so the editor viewport is never disturbed) and
/// read back with `readPixelsFromRenderTarget`.
///
/// One RenderTarget is allocated per job and torn down in the service's
/// `finally`; the readback buffer is reused, never copied into progress events.
class SequencerOffscreenFrameSource implements MovieFrameSource {
  final List<SequencerRenderActor> actors;
  final FilamentBackend backend;

  FilamentEngine? _engine;
  FilamentEngineLease? _lease;
  FilamentScene? _scene;
  FilamentView? _view;
  FilamentCamera? _camera;
  FilamentRenderer? _renderer;
  FilamentRenderTarget? _rt;
  FilamentTexture? _color;
  FilamentTexture? _depth;
  FilamentSkybox? _skybox;
  FilamentIndirectLight? _ibl;
  FilamentMaterialProvider? _materials;
  FilamentAssetLoader? _loader;
  FilamentSwapChain? _swapChain;
  int _sunEntity = 0;
  int _cameraEntity = 0;
  final Map<String, FilamentAsset> _assets = {};
  final Map<String, Aabb> _bounds = {};
  bool _disposed = false;

  SequencerOffscreenFrameSource({
    required this.actors,
    this.backend = FilamentBackend.defaultBackend,
  });

  /// GL/Vulkan readback origin is the bottom-left corner.
  @override
  bool get rowsAreBottomUp => true;

  /// Whether the native offscreen render capability is present in this build.
  /// Probes a trivial `@ffi.Native` symbol: resolution throws when the native
  /// asset was not built, which is exactly the "capability missing" case.
  static bool get isSupported {
    try {
      c.filament_frame_info_invalid_sentinel();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> prepare(MovieRenderJob job) async {
    // The process's shared engine: a movie render next to open
    // viewports is one more renderer, not one more Vulkan device.
    final lease = FilamentEngineHost.acquire(owner: 'SequencerOffscreenFrameSource', backend: backend);
    if (lease == null) {
      throw StateError(
        'Filament engine could not be created for the movie render job',
      );
    }
    _lease = lease;
    final engine = lease.engine;
    _engine = engine;
    _scene = engine.createScene();
    _view = engine.createView();
    _renderer = engine.createRenderer();
    // Some backends only make a context current once a swap chain exists; the
    // chain is never presented to, all drawing goes to the RenderTarget.
    _swapChain = engine.createHeadlessSwapChain(job.width, job.height);
    _cameraEntity = engine.createEntity();
    _camera = engine.createCamera(_cameraEntity);

    _color = FilamentTexture.create2D(
      engine: engine,
      width: job.width,
      height: job.height,
      format: TextureFormat.rgba8,
      usage: TextureUsage.colorAttachment | TextureUsage.sampleable,
    );
    _depth = FilamentTexture.create2D(
      engine: engine,
      width: job.width,
      height: job.height,
      format: TextureFormat.depth24,
      usage: TextureUsage.depthAttachment,
    );
    _rt = FilamentRenderTarget.build(
      engine: engine,
      colors: [RenderTargetAttachment(texture: _color!)],
      depth: RenderTargetAttachment(texture: _depth!),
    );

    _view!
      ..scene = _scene!
      ..camera = _camera!
      ..renderTarget = _rt
      ..postProcessingEnabled = false;
    _view!.setViewport(0, 0, job.width, job.height);
    _renderer!.setClearOptions(r: 0.05, g: 0.06, b: 0.09, a: 1.0);

    _skybox = FilamentSkybox.build(
      engine,
      color: vm.Vector4(0.10, 0.12, 0.16, 1.0),
      intensity: 30000.0,
    );
    _scene!.setSkybox(_skybox!);

    _sunEntity = engine.createEntity();
    LightBuilder(LightType.directional)
        .color(1.0, 0.98, 0.95)
        .intensity(110000.0)
        .direction(-0.4, -0.8, -0.6)
        .castShadows(true)
        .build(engine, _sunEntity);
    _scene!.addEntity(_sunEntity);

    _ibl = FilamentIndirectLight.build(
      engine,
      irradiance: SphericalHarmonics(bands: 1, coefficients: [0.6, 0.65, 0.7]),
      intensity: 35000.0,
    );
    _scene!.setIndirectLight(_ibl!);

    _materials = FilamentMaterialProvider.ubershader(engine);
    _loader = FilamentAssetLoader.create(
      engine: engine,
      materialProvider: _materials!,
    );

    for (final actor in actors) {
      final path = actor.meshPath;
      if (path == null || !File(path).existsSync()) continue;
      final bytes = meshBytes(path);
      if (bytes == null) continue;
      final asset = _loader!.createAsset(bytes);
      if (asset == null) continue;
      final resources = FilamentResourceLoader.create(
        engine: engine,
        normalizeSkinningWeights: true,
      );
      resources.registerDefaultProviders(engine);
      resources.loadResources(asset);
      resources.dispose();
      asset.addToScene(_scene!);
      _assets[actor.actorId] = asset;
      _bounds[actor.actorId] = asset.getBoundingBox();
    }

    _placeCamera(job);
  }

  /// Frames the camera on the union of every bound actor's pose across the
  /// job's range, so nothing walks out of shot mid-render.
  void _placeCamera(MovieRenderJob job) {
    const evaluator = SequencerEvaluator();
    var min = vm.Vector3.all(double.infinity);
    var max = vm.Vector3.all(double.negativeInfinity);
    var any = false;

    final probes = <double>{
      job.sequenceFrameFor(job.startFrame),
      job.sequenceFrameFor(job.startFrame + job.totalFrames ~/ 2),
      job.sequenceFrameFor(job.endFrame),
    };

    for (final frame in probes) {
      final samples = evaluator.evaluate(job.sequence, frame);
      for (final actor in actors) {
        final bounds = _bounds[actor.actorId];
        if (bounds == null) continue;
        final pose = _poseFor(actor, samples);
        final centre = (bounds.min + bounds.max) * 0.5;
        final half = (bounds.max - bounds.min) * 0.5;
        // Stored poses are Z up; the preview scene is Y up.
        final s = LuminaAxes.scale(pose.scale);
        final at = LuminaAxes.location(pose.location)..scale(_unitScale);
        final worldCentre = vm.Vector3(
          at.x + centre.x * s.x,
          at.y + centre.y * s.y,
          at.z + centre.z * s.z,
        );
        final worldHalf = vm.Vector3(
          half.x * s.x.abs(),
          half.y * s.y.abs(),
          half.z * s.z.abs(),
        );
        min = vm.Vector3(
          math.min(min.x, worldCentre.x - worldHalf.x),
          math.min(min.y, worldCentre.y - worldHalf.y),
          math.min(min.z, worldCentre.z - worldHalf.z),
        );
        max = vm.Vector3(
          math.max(max.x, worldCentre.x + worldHalf.x),
          math.max(max.y, worldCentre.y + worldHalf.y),
          math.max(max.z, worldCentre.z + worldHalf.z),
        );
        any = true;
      }
    }

    if (!any) {
      min = vm.Vector3(-1, -1, -1);
      max = vm.Vector3(1, 1, 1);
    }

    final centre = (min + max) * 0.5;
    final extent = max - min;
    final radius = math.max(0.5, extent.length * 0.5);
    final distance = radius * 2.6 + 0.5;

    _camera!.setProjection(
      fovDegrees: 45.0,
      aspect: extent.x <= 0 ? 1.0 : 1.0,
      near: math.max(0.01, distance * 0.01),
      far: distance * 20.0 + 100.0,
      direction: FovDirection.vertical,
    );
    _camera!.lookAt(
      eyeX: centre.x + distance * 0.55,
      eyeY: centre.y + distance * 0.45,
      eyeZ: centre.z + distance * 0.85,
      centerX: centre.x,
      centerY: centre.y,
      centerZ: centre.z,
    );
  }

  /// This preview renders its glTF assets at their native metres, so the
  /// level's centimetre locations are scaled down to meet them.
  static const double _unitScale = 1 / LuminaUnits.unitsPerMetre;

  _Pose _poseFor(SequencerRenderActor actor, List<TrackSample> samples) {
    final pose = _Pose(
      location: List<double>.from(actor.location),
      rotation: List<double>.from(actor.rotation),
      scale: List<double>.from(actor.scale),
      visible: true,
    );
    for (final sample in samples) {
      if (sample.actorId != actor.actorId) continue;
      if (sample.kind == SequencerTrackKind.visibility) {
        final v = sample.values.values.isEmpty
            ? 1.0
            : sample.values.values.first;
        pose.visible = v >= 0.5;
        continue;
      }
      sample.values.forEach((channel, value) {
        switch (channel) {
          case 'Location.X':
            pose.location[0] = value;
          case 'Location.Y':
            pose.location[1] = value;
          case 'Location.Z':
            pose.location[2] = value;
          case 'Rotation.X':
            pose.rotation[0] = value;
          case 'Rotation.Y':
            pose.rotation[1] = value;
          case 'Rotation.Z':
            pose.rotation[2] = value;
          case 'Scale.X':
            pose.scale[0] = value;
          case 'Scale.Y':
            pose.scale[1] = value;
          case 'Scale.Z':
            pose.scale[2] = value;
        }
      });
    }
    return pose;
  }

  @override
  Future<Uint8List> renderFrame(MovieRenderFrameRequest request) async {
    final engine = _engine;
    final renderer = _renderer;
    final rt = _rt;
    if (engine == null || renderer == null || rt == null) {
      throw StateError('SequencerOffscreenFrameSource.prepare was not called');
    }

    final transforms = FilamentTransformManager(engine);
    for (final actor in actors) {
      final asset = _assets[actor.actorId];
      if (asset == null) continue;
      final pose = _poseFor(actor, request.samples);
      // Stored Z-up pose → the Y-up preview, by lumina's one axis rule.
      final m = vm.Matrix4.compose(
        LuminaAxes.location(pose.location)..scale(_unitScale),
        LuminaAxes.rotation(pose.rotation),
        LuminaAxes.scale(pose.scale),
      );
      transforms.setTransform(asset.rootEntity, m.storage.toList());

      if (pose.visible) {
        asset.addToScene(_scene!);
      } else {
        asset.removeFromScene(_scene!);
      }
    }

    // Standalone draw: deliberately outside any beginFrame/endFrame block.
    renderer.renderStandaloneView(_view!);
    engine.flushAndWait();

    return renderer.readPixelsFromRenderTarget(
      rt,
      x: 0,
      y: 0,
      width: request.width,
      height: request.height,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final engine = _engine;
    if (engine == null) return;
    try {
      _view?.renderTarget = null;
      for (final asset in _assets.values) {
        asset.removeFromScene(_scene!);
        asset.dispose();
      }
      _assets.clear();
      _loader?.dispose();
      _materials?.dispose();
      _rt?.dispose();
      _depth?.dispose();
      _color?.dispose();
      _skybox?.dispose();
      _ibl?.dispose();
      _view?.dispose();
      _scene?.dispose();
      if (_sunEntity != 0) {
        engine.destroyEntityComponents(_sunEntity);
        engine.destroyEntity(_sunEntity);
      }
      _camera?.dispose();
      if (_cameraEntity != 0) engine.destroyEntity(_cameraEntity);
      _renderer?.dispose();
      _swapChain?.dispose();
    } catch (e) {
      debugPrint('[SequencerOffscreenFrameSource] teardown: $e');
    } finally {
      // Only this job's objects were freed; the engine is shared.
      _lease?.release();
      _lease = null;
      _engine = null;
    }
  }
}

class _Pose {
  final List<double> location;
  final List<double> rotation;
  final List<double> scale;
  bool visible;
  _Pose({
    required this.location,
    required this.rotation,
    required this.scale,
    required this.visible,
  });
}

/// The actors the offscreen movie render draws — the same level bindings the
/// Sequencer preview uses, carrying their mesh file so the render queue shows
/// the real models, not stand-ins. Shared by the render dialog and the MCP
/// `render_sequence` tool, so both build the same
/// [SequencerOffscreenFrameSource].
/// The glTF bytes behind an actor's mesh path: a `.glb` / `.gltf`
/// as it is; an imported `.lmas` through its `.entity.glb` companion, else
/// the GLB payload inside it. Null when there is none.
Uint8List? meshBytes(String path) {
  final file = File(path);
  if (!path.toLowerCase().endsWith('.lmas')) return file.readAsBytesSync();
  final companion = File(path.replaceAll(RegExp(r'\.lmas$', caseSensitive: false), '.entity.glb'));
  if (companion.existsSync()) return companion.readAsBytesSync();
  try {
    final payload = LuminaAsset.fromBytes(file.readAsBytesSync()).rawPayload;
    return payload == null || payload.isEmpty ? null : Uint8List.fromList(payload);
  } on Object {
    return null;
  }
}

List<SequencerRenderActor> sequencerRenderActors(List<EditorActorNode> actors) => [
      for (final a in actors)
        SequencerRenderActor(
          actorId: a.id,
          name: a.name,
          meshPath: a.meshAssetPath,
          location: a.location,
          rotation: a.rotation,
          scale: a.scale,
        ),
    ];
