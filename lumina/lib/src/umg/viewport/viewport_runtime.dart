import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/filament.dart';
import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/components/environment/sky_component.dart';
import 'package:lumina/src/components/light/directional_light_component.dart';
import 'package:lumina/src/components/light/light_component.dart';
import 'package:lumina/src/components/light/point_light_component.dart';
import 'package:lumina/src/components/light/spot_light_component.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/components/mesh/mesh_asset_cache.dart';
import 'package:lumina/src/components/mesh/static_mesh_component.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/object/lumina_object_key.dart';
import 'package:lumina/src/umg/viewport/viewport_camera.dart';
import 'package:lumina/src/umg/viewport/viewport_scene.dart';
import 'package:lumina/src/umg/viewport/viewport_scene_diff.dart';
import 'package:lumina/src/umg/viewport/viewport_transforms.dart';
import 'package:lumina/src/utility/lumina_assets.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/world/world_type.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

part 'viewport_runtime_queries.dart';

/// A node of the description, drawn: the actor and its root component.
class _RuntimeNode {
  _RuntimeNode(this.id, this.json, this.actor, this.root);
  final String id;
  Map<String, Object?> json;
  final LuminaActor actor;
  LuminaSceneComponent root;
  bool loaded = false;
  bool failed = false;

  /// The gizmo drag's local transform (description authoring), until commit.
  Map<String, Object?>? localTransform;

  /// A time a bound timeline sets, overriding the description's.
  double? localTime;
  /// The skeletal mesh's sockets (name → bone), from its `.lmas`.
  Map<String, String> sockets = const {};

  /// The joint names of the mesh's first skin, in the skin's order.
  List<String> jointNames = const [];

  String get kind => '${json['kind']}';
  String get asset => '${json['asset'] ?? ''}';
  LuminaStaticMeshComponent? get mesh => root is LuminaStaticMeshComponent ? root as LuminaStaticMeshComponent : null;
  LuminaAnimatedMeshComponent? get skeletal => root is LuminaAnimatedMeshComponent ? root as LuminaAnimatedMeshComponent : null;
}

/// A Viewport's preview scene on the shared engine: one [FilamentScene],
/// [FilamentView] and camera, the description's nodes as actors of a
/// preview [LuminaWorld] (so meshes come from the engine's mesh cache
/// through [LuminaAssets], skeletal meshes animate with gltfio's animator
/// on the GPU, lights and the sky are the engine's components).
///
/// [apply] takes the next description and applies only its difference
/// ([LuminaViewportSceneDiff]); [advance] runs one frame of animation,
/// socket following and auto-rotation; the orbit, picking and joint
/// positions serve the widget's gestures and overlays. Preview views use a
/// fixed light feature set (MSAA 4×, one shadowed directional light, IBL;
/// none of the game's ray tracing, ReSTIR, SSR, upscalers or frame
/// generation).
class LuminaViewportSceneRuntime with _ViewportQueries {
  LuminaViewportSceneRuntime({
    required this.engine,
    FilamentScene? scene,
    FilamentView? view,
    FilamentCamera? camera,
    this.assetProvider,
    this.allowFiles = false,
    this.onEvent,
  })  : _ownsScene = scene == null,
        _ownsView = view == null,
        _ownsCamera = camera == null {
    this.scene = scene ?? engine.createScene();
    this.view = view ?? engine.createView();
    if (camera == null) {
      _cameraEntity = engine.createEntity();
      this.camera = engine.createCamera(_cameraEntity!);
    } else {
      this.camera = camera;
    }
    if (_ownsView) {
      this.view
        ..scene = this.scene
        ..camera = this.camera;
    }
    _configureView();
    this.camera.setExposure(aperture: 16.0, shutterSpeed: 1.0 / 125.0, sensitivity: 100.0);
    world.initializeNativeContext(engine, this.scene);
  }

  @override
  final FilamentEngine engine;
  late final FilamentScene scene;
  late final FilamentView view;
  late final FilamentCamera camera;
  int? _cameraEntity;
  final bool _ownsScene;
  final bool _ownsView;
  final bool _ownsCamera;

  /// Where meshes and animation assets are read (null: [LuminaAssets]).
  final LuminaAssetProvider? assetProvider;

  /// Whether `Play Animation File` may read a file (editor panels only).
  final bool allowFiles;

  /// The Viewport's runtime events (`OnSceneReady`, `OnAssetLoadFailed`)
  /// with their outputs.
  void Function(String event, Map<String, Object?> args)? onEvent;

  /// The preview world the nodes live in.
  final LuminaWorld world = LuminaWorld(worldType: LuminaWorldType.preview);

  /// The orbit the camera shows (the player's drag moves it every frame).
  @override
  final LuminaViewportCamera orbit = LuminaViewportCamera();

  LuminaViewportScene? _shown;
  @override
  final Map<String, _RuntimeNode> _nodes = {};
  LuminaActor? _sky;
  FilamentEditorGrid? _grid;
  bool _gridShown = false;
  int _frameSerial = 0;
  int _pending = 0;
  bool _disposed = false;

  /// Diff ops applied so far (every [apply]), for tests and diagnostics.
  int opsApplied = 0;

  /// Asset loads that failed, by asset (the last message).
  final Map<String, String> failures = {};

  bool get isDisposed => _disposed;

  /// The description shown now.
  LuminaViewportScene? get shown => _shown;

  /// The node ids drawn now.
  Iterable<String> get nodeIds => _nodes.keys;

  /// The root component of node [id] (a mesh or a light), or null.
  LuminaSceneComponent? componentOf(String id) => _nodes[id]?.root;

  /// Whether every mesh of the description has loaded (or failed).
  bool get isReady => _pending == 0;

  Completer<void>? _ready;

  /// Completes when every mesh shown has loaded or failed.
  Future<void> get whenReady {
    if (_pending == 0) return Future<void>.value();
    return (_ready ??= Completer<void>()).future;
  }

  void _configureView() {
    view
      ..postProcessingEnabled = true
      ..shadowingEnabled = true
      ..multiSampleAntiAliasingOptions = const MultiSampleAntiAliasingOptions(enabled: true, sampleCount: 4)
      ..screenSpaceReflectionsOptions = const ScreenSpaceReflectionsOptions(enabled: false)
      ..antiAliasing = 0;
    view.setDynamicLightingOptions(LuminaUnits.dynamicLightingNear, LuminaUnits.dynamicLightingFar);
  }

  // --- Applying a description ------------------------------------------------

  /// Shows [next]: applies the ops between what is shown and [next] and
  /// returns them (empty when nothing changed).
  List<LuminaViewportSceneOp> apply(LuminaViewportScene next) {
    if (_disposed) return const [];
    final ops = LuminaViewportSceneDiff.diff(_shown, next);
    if (ops.isEmpty) return ops;
    for (final op in ops) {
      switch (op.kind) {
        case LuminaViewportSceneOpKind.removeNode:
          _removeNode(op.id!);
        case LuminaViewportSceneOpKind.addNode:
          _addNode(op.id!, _plainCopy(op.value!));
        case LuminaViewportSceneOpKind.updateNode:
          _updateNode(op.id!, _plainCopy(op.value!), op.fields);
        case LuminaViewportSceneOpKind.environment:
          _applyEnvironment(next.environment);
        case LuminaViewportSceneOpKind.grid:
          _applyGrid(next.gridVisible);
        case LuminaViewportSceneOpKind.camera:
          _applyCamera(next);
        case LuminaViewportSceneOpKind.interaction:
        case LuminaViewportSceneOpKind.addOverlay:
        case LuminaViewportSceneOpKind.removeOverlay:
        case LuminaViewportSceneOpKind.updateOverlay:
        case LuminaViewportSceneOpKind.gizmo:
        case LuminaViewportSceneOpKind.addMarker:
        case LuminaViewportSceneOpKind.removeMarker:
        case LuminaViewportSceneOpKind.updateMarker:
          // Drawn by the widget's overlays from the description.
          break;
      }
    }
    opsApplied += ops.length;
    _shown = next.copy();
    _syncAttachments();
    world.tick(0.0);
    return ops;
  }

  static Map<String, Object?> _plainCopy(Map<String, Object?> m) => LuminaViewportScene.plain(m)! as Map<String, Object?>;

  void _addNode(String id, Map<String, Object?> json) {
    final actor = LuminaActor(key: LuminaObjectKey('viewport_$id'));
    final node = _RuntimeNode(id, json, actor, _componentFor(json));
    actor.addComponent(node.root);
    _nodes[id] = node;
    _place(node);
    world.persistentLevel.registerActor(actor);
    _watchLoad(node);
    _applyLook(node, const {'materialParams', 'morphs', 'animation', 'visible'});
  }

  LuminaSceneComponent _componentFor(Map<String, Object?> json) {
    final kind = json['kind'];
    final asset = '${json['asset'] ?? ''}';
    switch (kind) {
      case LuminaViewportNodeKind.staticMesh:
        if (asset.isEmpty) return LuminaSceneComponent();
        return LuminaStaticMeshComponent(meshAssetPath: asset, assetProvider: assetProvider);
      case LuminaViewportNodeKind.skeletalMesh:
        if (asset.isEmpty) return LuminaSceneComponent();
        return LuminaAnimatedMeshComponent(meshAssetPath: asset, assetProvider: assetProvider);
      case LuminaViewportNodeKind.light:
        return _lightFor(json['light'] is Map ? json['light']! as Map : const {});
      default:
        return LuminaSceneComponent();
    }
  }

  LuminaLightComponent _lightFor(Map light) {
    final c = light['color'] is List ? light['color']! as List : const [1.0, 1.0, 1.0];
    final color = Vector3(_n(c, 0, 1), _n(c, 1, 1), _n(c, 2, 1));
    final intensity = light['intensity'] is num ? (light['intensity']! as num).toDouble() : 100000.0;
    return switch (light['type']) {
      LuminaViewportLightType.point => LuminaPointLightComponent(color: color, intensity: intensity),
      LuminaViewportLightType.spot => LuminaSpotLightComponent(color: color, intensity: intensity),
      _ => LuminaDirectionalLightComponent(color: color, intensity: intensity, castShadows: true, isSun: false),
    };
  }

  static double _n(List l, int i, double d) => i < l.length && l[i] is num ? (l[i] as num).toDouble() : d;

  void _watchLoad(_RuntimeNode node) {
    final mesh = node.mesh;
    if (mesh == null) {
      node.loaded = true;
      return;
    }
    _pending++;
    unawaited(_load(node, mesh));
  }

  Future<void> _load(_RuntimeNode node, LuminaStaticMeshComponent mesh) async {
    final asset = node.asset;
    try {
      await mesh.loaded;
      if (!_disposed && identical(_nodes[node.id]?.root, mesh)) {
        if (node.skeletal != null) await _readSkeleton(node, mesh);
        node.loaded = true;
        await _applyLookLoaded(node);
      }
    } catch (e) {
      if (!_disposed && identical(_nodes[node.id]?.root, mesh)) {
        node.failed = true;
        _fail(asset, '$e');
      }
    }
    if (_disposed) return;
    _pending = math.max(0, _pending - 1);
    if (_pending == 0) {
      final ready = _ready;
      _ready = null;
      ready?.complete();
      onEvent?.call('OnSceneReady', const {});
    }
  }

  Future<void> _applyLookLoaded(_RuntimeNode node) async {
    _applyLook(node, const {'materialParams', 'morphs'});
    final skeletal = node.skeletal;
    if (skeletal != null) await _applyAnimation(node, skeletal);
  }

  Future<void> _readSkeleton(_RuntimeNode node, LuminaStaticMeshComponent mesh) async {
    final provider = LuminaAssets.resolve(assetProvider);
    try {
      final names = _ViewportQueries._jointNameCache[node.asset] ??= _ViewportQueries.skinJointNames(await LuminaMeshAssetCache.meshBytes(provider, node.asset));
      if (identical(node.root, mesh)) node.jointNames = names;
    } catch (_) {
      // Unnamed joints.
    }
    if (!node.asset.toLowerCase().endsWith('.lmas')) return;
    try {
      final meta = LuminaAsset.fromBytes(await LuminaAssets.resolve(assetProvider)(node.asset)).metadata;
      final sockets = meta['sockets'];
      if (sockets != null && identical(node.root, mesh)) node.sockets = _ViewportQueries.socketsOf(sockets);
    } catch (_) {
      // No sockets: socket names are bone names.
    }
  }

  void _fail(String asset, String message) {
    failures[asset] = message;
    developer.log('Viewport: cannot load $asset: $message', name: 'UMG', level: 900);
    onEvent?.call('OnAssetLoadFailed', {'asset': asset, 'message': message});
  }

  void _removeNode(String id) {
    final node = _nodes.remove(id);
    if (node == null) return;
    world.persistentLevel.unregisterActor(node.actor);
  }

  void _updateNode(String id, Map<String, Object?> json, Set<String> fields) {
    final node = _nodes[id];
    if (node == null) return _addNode(id, json);
    final assetChanged = fields.contains('asset') || (fields.contains('light') && node.kind == LuminaViewportNodeKind.light);
    node.json = json;
    if (assetChanged) {
      // A part swap: a new component on the same actor, the same transform.
      node.actor.removeComponent(node.root);
      node.root = _componentFor(json);
      node.loaded = false;
      node.failed = false;
      node.actor.addComponent(node.root);
      _watchLoad(node);
    }
    if (fields.contains('transform') || assetChanged) {
      node.localTransform = null;
      _place(node);
    }
    _applyLook(node, assetChanged ? const {'materialParams', 'morphs', 'animation', 'visible'} : fields);
  }

  void _place(_RuntimeNode node) {
    if (node.json['parent'] != null) return; // Placed by its socket each frame.
    final t = LuminaViewportTransforms.toRuntime(node.localTransform ?? node.json['transform']);
    node.root
      ..relativeLocation = t.location
      ..relativeRotation = t.rotation
      ..relativeScale = t.scale;
  }

  /// Visibility, material parameters, morphs and animation of [node].
  void _applyLook(_RuntimeNode node, Set<String> fields) {
    if (fields.contains('visible')) {
      final visible = node.json['visible'] != false;
      final mesh = node.mesh;
      if (mesh != null) {
        mesh.visible = visible;
      } else {
        node.root.isVisible = visible;
      }
    }
    if (!node.loaded) return;
    if (fields.contains('materialParams')) _applyMaterialParams(node);
    final skeletal = node.skeletal;
    if (skeletal == null) return;
    if (fields.contains('morphs')) {
      final morphs = node.json['morphs'];
      if (morphs is Map) {
        for (final e in morphs.entries) {
          if (e.value is num && skeletal.hasMorphTarget('${e.key}')) skeletal.setMorphTarget('${e.key}', (e.value as num).toDouble());
        }
      }
    }
    if (fields.contains('animation')) unawaited(_applyAnimation(node, skeletal));
  }

  /// Plays the node's animation: an animation asset (`.lmas`, whose
  /// `clip_name` the mesh carries), or a clip name of the mesh.
  Future<void> _applyAnimation(_RuntimeNode node, LuminaAnimatedMeshComponent mesh) async {
    final a = node.json['animation'];
    if (a is! Map) {
      mesh.stop();
      return;
    }
    if (a['file'] != null) {
      if (!allowFiles) {
        _fail('${a['file']}', 'Play Animation File plays files in editor panels only');
        return;
      }
      _fail('${a['file']}', 'this Viewport has no animation file reader');
      return;
    }
    final asset = '${a['asset'] ?? ''}';
    if (asset.isEmpty) return;
    String clip = asset;
    if (asset.toLowerCase().endsWith('.lmas')) {
      try {
        final bytes = await LuminaAssets.resolve(assetProvider)(asset);
        final meta = LuminaAsset.fromBytes(bytes).metadata;
        clip = meta['clip_name'] ?? '';
        if (clip.isEmpty) throw StateError('$asset names no clip (clip_name)');
      } catch (e) {
        if (!_disposed) _fail(asset, '$e');
        return;
      }
    }
    if (_disposed || !identical(node.root, mesh)) return;
    if (!mesh.hasClip(clip)) {
      _fail(asset, mesh.clipNames.isEmpty ? '${node.asset} has no animation clips' : "${node.asset} has no clip '$clip'");
      return;
    }
    final playing = a['playing'] != false;
    final time = node.localTime ?? (a['time'] is num ? (a['time']! as num).toDouble() : 0.0);
    mesh.play(clip, startTime: time, loop: a['loop'] != false);
    mesh.playRate = playing ? (a['rate'] is num ? (a['rate']! as num).toDouble() : 1.0) : 0.0;
    mesh.onTick(0.0);
  }

  /// A bound timeline's time for node [id]'s animation (null: the
  /// description's), applied without a description diff.
  void setLocalAnimationTime(String id, double? seconds) {
    final node = _nodes[id];
    final mesh = node?.skeletal;
    if (node == null || mesh == null) return;
    node.localTime = seconds;
    final clip = mesh.currentClip;
    if (seconds == null || clip == null) return;
    final loop = (node.json['animation'] is Map) ? (node.json['animation']! as Map)['loop'] != false : true;
    final rate = mesh.playRate;
    mesh.play(clip, startTime: seconds, loop: loop);
    mesh.playRate = rate;
    mesh.onTick(0.0);
  }

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
        color: Vector4(_n(c, 0, 0.1), _n(c, 1, 0.11), _n(c, 2, 0.14), 1.0),
        skyIntensity: 14000.0,
        iblIntensity: 22000.0 * intensity,
        visible: mode != LuminaViewportEnvironmentMode.transparent,
      );
    }
    final actor = LuminaActor(key: const LuminaObjectKey('viewport_sky'), root: sky);
    world.persistentLevel.registerActor(actor);
    _sky = actor;
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

  // --- Camera ----------------------------------------------------------------

  void _applyCamera(LuminaViewportScene next) {
    orbit.readFrom(next);
    final c = next.camera;
    final serial = c['frameSerial'] is int ? c['frameSerial']! as int : 0;
    if (serial != _frameSerial) {
      _frameSerial = serial;
      final target = c['frame'];
      if (target is String) frameNode(target);
    }
  }

  /// Frames node [id] ('*': every mesh); waits for the meshes to load.
  void frameNode(String id) {
    final box = boundsOf(id);
    if (box != null) {
      orbit.frame(box);
      return;
    }
    if (_pending > 0) {
      _deferredFrame = id;
    }
  }

  String? _deferredFrame;

  /// The world bounds (runtime frame) of node [id] or ('*') every mesh.
  Aabb3? boundsOf(String id) {
    Aabb3? out;
    for (final node in _nodes.values) {
      if (id != '*' && node.id != id) continue;
      final b = _worldBounds(node);
      if (b == null) continue;
      if (out == null) {
        out = b;
      } else {
        out.hull(b);
      }
    }
    return out;
  }

  @override
  Aabb3? _worldBounds(_RuntimeNode node) {
    final mesh = node.mesh;
    final local = mesh?.localBounds;
    if (mesh == null || local == null || !mesh.isLoaded) return null;
    if (node.skeletal != null) {
      // A skinned mesh's glTF bounds ignore its skeleton's scale (a
      // centimetre export under a 0.01 root): its joints bound it instead.
      final joints = jointsOf(node.id);
      if (joints.length > 1) {
        final box = Aabb3.minMax(joints.first.position.clone(), joints.first.position.clone());
        for (final j in joints) {
          box.hullPoint(j.position);
        }
        final pad = (box.max - box.min).length * 0.08 + 5.0;
        return Aabb3.minMax(box.min - Vector3.all(pad), box.max + Vector3.all(pad));
      }
    }
    return Aabb3.copy(local)..transform(mesh.renderTransform);
  }

  /// Sets the viewport size (pixels) the camera projects to.
  void setViewportSize(int width, int height) {
    orbit
      ..width = math.max(1, width).toDouble()
      ..height = math.max(1, height).toDouble();
    if (_ownsView) view.setViewport(0, 0, math.max(1, width), math.max(1, height));
    _updateCamera();
  }

  void _updateCamera() {
    final eye = orbit.eye;
    final centre = orbit.centre;
    camera.lookAt(eyeX: eye.x, eyeY: eye.y, eyeZ: eye.z, centerX: centre.x, centerY: centre.y, centerZ: centre.z);
    final aspect = orbit.width / math.max(1.0, orbit.height);
    if (orbit.orthographic) {
      final h = orbit.orthoHalfHeight;
      camera.setProjectionOrtho(left: -h * aspect, right: h * aspect, bottom: -h, top: h, near: -orbit.far, far: orbit.far);
    } else {
      camera.setProjectionFov(fovDegrees: orbit.fov, aspect: aspect, near: orbit.near, far: orbit.far);
    }
  }

  // --- Frames ----------------------------------------------------------------

  /// Whether something moves on its own (an animation plays, the camera
  /// auto-rotates): the Viewport renders every frame while it does.
  bool get animating {
    if ((_shown?.autoRotate ?? 0.0) != 0.0) return true;
    for (final node in _nodes.values) {
      final a = node.json['animation'];
      if (a is Map && a['playing'] != false && node.skeletal?.currentClip != null) return true;
    }
    return false;
  }

  /// One frame of [dt] seconds: animation, sockets, auto-rotation, camera.
  void advance(double dt) {
    if (_disposed) return;
    final spin = _shown?.autoRotate ?? 0.0;
    if (spin != 0.0) orbit.orbit(spin * dt, 0.0);
    final deferred = _deferredFrame;
    if (deferred != null && _pending == 0) {
      _deferredFrame = null;
      frameNode(deferred);
    }
    for (final node in _nodes.values) {
      node.skeletal?.onTick(dt);
    }
    _syncAttachments();
    world.tick(0.0);
    _updateCamera();
  }

  /// Puts every node attached to a socket at its parent's bone.
  void _syncAttachments() {
    for (final node in _nodes.values) {
      final parentId = node.json['parent'];
      if (parentId is! String) continue;
      final parent = _nodes[parentId];
      if (parent == null) continue;
      final local = LuminaViewportTransforms.toRuntime(node.localTransform ?? node.json['transform']);
      final socket = node.json['socket'];
      final skeletal = parent.skeletal;
      final Matrix4 world;
      final joint = socket is String && skeletal != null ? skeletal.jointWorldTransform(parent.sockets[socket] ?? socket) : null;
      if (joint != null) {
        // jointWorld maps the bone's frame (asset metres) to the world;
        // the child's centimetre offset and its own ×100 asset scale are
        // undone into that frame.
        const toAsset = 1.0 / LuminaUnits.unitsPerMetre;
        final offset = Matrix4.compose(local.location * toAsset, local.rotation, local.scale);
        world = joint * offset * Matrix4.diagonal3Values(toAsset, toAsset, toAsset);
      } else {
        world = parent.root.worldTransform * local.matrix;
      }
      final t = Vector3.zero();
      final r = Quaternion.identity();
      final s = Vector3.zero();
      world.decompose(t, r, s);
      node.root
        ..relativeLocation = t
        ..relativeRotation = r
        ..relativeScale = s;
    }
  }

  // --- Gizmo -----------------------------------------------------------------

  /// Moves node [id] to [transform] (authoring) at once, without touching
  /// the description (a gizmo drag; the description changes on commit).
  /// Null puts it back where the description has it.
  void setLocalTransform(String id, Map<String, Object?>? transform) {
    final node = _nodes[id];
    if (node == null) return;
    node.localTransform = transform == null ? null : _plainCopy(transform);
    _place(node);
    _syncAttachments();
    world.tick(0.0);
  }

  /// Node [id]'s transform (authoring) as drawn now.
  Map<String, Object?>? transformOf(String id) {
    final node = _nodes[id];
    if (node == null) return null;
    return _plainCopy(node.localTransform ?? (node.json['transform'] as Map<String, Object?>? ?? const {}));
  }

  // --- Lifetime --------------------------------------------------------------

  /// Destroys the preview: every node, the sky, the grid, and the scene,
  /// view and camera this runtime created.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final id in _nodes.keys.toList()) {
      _removeNode(id);
    }
    final sky = _sky;
    if (sky != null) world.persistentLevel.unregisterActor(sky);
    _sky = null;
    final grid = _grid;
    if (grid != null) {
      if (_gridShown) grid.removeFromScene(scene);
      grid.dispose();
    }
    _grid = null;
    world.cleanup();
    if (_ownsView) view.dispose();
    if (_ownsCamera) {
      camera.dispose();
      final e = _cameraEntity;
      if (e != null) engine.destroyEntity(e);
    }
    if (_ownsScene) scene.dispose();
  }
}
