import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:lumina/data/services/blueprint_class_registry.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina_ui/ui/features/sub_editors/models/sub_editor_line_set.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/viewport_ray.dart';

/// The Blueprint editor's 3D Viewport: the Blueprint's actor built
/// the way Play builds it, in the viewport's preview world.
///
/// - The components come from lumina's `LuminaBlueprintComponents.construct`
///   on a `LuminaCharacter` / `LuminaPawn` / `LuminaActor` (the Blueprint
///   VM's own parents), with the project class registry's asset resolver (a
///   mesh `.lmas` loads through its `.entity.glb`) and Anim Class factory, so
///   transforms convert from authoring space (cm, Z up) through `LuminaAxes`
///   exactly as in Play and the generated game.
/// - A Skeletal Mesh with an Animation Blueprint runs it: editor worlds do not
///   tick gameplay, so the scene ticks the Anim Blueprint instances, then the
///   meshes, then the world's render prep. The pawn stands still, so the
///   Third Person character plays its Idle state.
/// - Collision shapes (capsule, box, sphere, cylinder, cone, convex hull),
///   spring arms, cameras and arrows are drawn as line
///   overlays
///   ([overlays]); the selected component is highlighted (a mesh by its
///   bounds). Nothing looks through the Blueprint's cameras: they stay
///   inactive, and the viewport keeps its orbit camera.
///
/// Every world the viewport hands over gets a fresh actor (switching tabs
/// remounts the viewport); a document edit that changes a component rebuilds
/// it, and so does a texture its materials draw being saved again (checked
/// about once a second). Without a world the actor is still built (unregistered) so the
/// overlays and [framing] are known before the viewport opens.
class BlueprintPreviewScene extends ChangeNotifier {
  LuminaWorld? _world;
  bool _ownsWorld = false;
  Timer? _timer;
  final List<LuminaActor> _environment = [];

  LuminaBlueprintDocument? _document;
  String? _signature;
  String? _projectDir;
  LuminaBlueprintClassRegistry? _registry;

  LuminaActor? _actor;
  Map<String, LuminaActorComponent> _built = const {};
  int _revision = 0;
  String? _selected;
  List<SubEditorLineSet>? _overlays;
  String? _lastState;
  bool _disposed = false;
  bool _notifyScheduled = false;

  /// Frames since the textures were last checked, and what each texture
  /// file was then (modified time and size), by path.
  int _framesSinceTextureCheck = 0;
  Map<String, String> _textureStamps = const {};

  /// Listeners hear about a change after the current frame: the viewport
  /// hands its world over from inside a build, where a rebuild request is
  /// not allowed.
  void _notify() {
    if (_disposed || _notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  /// What went wrong building the actor (unknown component types, an Anim
  /// Class that does not compile), newest last.
  final List<LuminaBlueprintDiagnostic> diagnostics = [];

  static const double tickSeconds = 1.0 / 60.0;

  /// The shape collision components drawn through lumina's
  /// `LuminaCollisionComponent.buildWireframe`; the
  /// capsule keeps its own `buildCapsuleWireframe`.
  static const Set<String> shapeTypes = {
    'LuminaBoxComponent',
    'LuminaSphereComponent',
    'LuminaCylinderComponent',
    'LuminaConeComponent',
    'LuminaConvexComponent',
  };

  /// Component-visualizer hues, saturated enough to read on the grey
  /// backdrop: a pink capsule, a red spring arm, a blue camera, and the orange
  /// selection.
  static const (double, double, double) capsuleColor = (0.95, 0.42, 0.55);
  static const (double, double, double) springArmColor = (1.0, 0.18, 0.15);
  static const (double, double, double) cameraColor = (0.3, 0.65, 1.0);
  static const (double, double, double) spotLightColor = (1.0, 0.85, 0.3);
  static const (double, double, double) pointLightColor = (1.0, 0.9, 0.4);
  static const (double, double, double) selectionColor = (1.0, 0.6, 0.1);

  LuminaWorld? get world => _world;
  bool get isAttached => _world != null && !_world!.isCleanedUp;
  bool get hasNativeWorld => isAttached && _world!.hasNativeContext;

  /// The preview actor (registered in [world] while attached).
  LuminaActor? get actor => _actor;

  /// Bumped whenever the actor is rebuilt or a mesh of it finishes loading.
  int get revision => _revision;

  /// The component built for Blueprint component [id], or null.
  LuminaActorComponent? componentFor(String id) => _built[id];

  /// The Animation Blueprint instance playing on mesh component [id].
  LuminaAnimBlueprintInstance? animInstanceFor(String id) {
    final c = _built['$id.anim'];
    return c is LuminaAnimBlueprintInstance ? c : null;
  }

  /// The highlighted component.
  String? get selected => _selected;

  /// Shows [document]'s components (a copy is built; the signature of its
  /// components decides whether anything changed). [projectDir] resolves mesh
  /// assets and Anim Classes. If [components] is provided, those components
  /// are used instead of [document.components] (e.g. to preview inherited components).
  void setDocument(LuminaBlueprintDocument document, {String? projectDir, List<LuminaBlueprintComponent>? components}) {
    final effectiveComponents = components ?? document.components;
    final json = jsonEncode({
      'parentClass': document.parentClass,
      'components': [for (final c in effectiveComponents) c.toJson()],
    });
    final signature = '$projectDir\n$json';
    if (signature == _signature) return;
    _signature = signature;
    _document = LuminaBlueprintDocument.fromJson({
      'parentClass': document.parentClass,
      'components': jsonDecode(json)['components'],
    });
    if (projectDir != _projectDir) {
      _projectDir = projectDir;
      _registry = null;
    }
    _rebuild();
  }

  /// Highlights component [id] (null: none).
  void select(String? id) {
    if (id == _selected) return;
    _selected = id;
    _overlays = null;
    _notify();
  }

  // ---------------------------------------------------------------------------
  // World
  // ---------------------------------------------------------------------------

  /// Builds the actor in the viewport's [world] and starts ticking it.
  void attach(LuminaWorld world, {bool startTicker = true}) {
    detach();
    _world = world;
    _ownsWorld = false;
    _mountEnvironment();
    _rebuild();
    if (startTicker) {
      _timer = Timer.periodic(const Duration(microseconds: 16667), (_) => advance(tickSeconds));
    }
  }

  /// A world of its own with no native context (widget tests): the actor and
  /// its Anim Blueprint run, nothing draws. Ticked by [advance].
  void attachHeadless() {
    detach();
    _world = LuminaWorld(worldType: LuminaWorldType.editor);
    _ownsWorld = true;
    _rebuild();
  }

  /// Releases the world. The actor is built again, unregistered.
  void detach() {
    _timer?.cancel();
    _timer = null;
    final w = _world;
    _retire(_actor, immediately: true);
    _actor = null;
    _built = const {};
    if (w != null && !w.isCleanedUp) {
      for (final a in _environment) {
        try {
          w.persistentLevel.unregisterActor(a);
        } catch (_) {}
      }
      if (_ownsWorld) w.cleanup();
    }
    _environment.clear();
    _world = null;
    _ownsWorld = false;
    if (w != null && !_disposed) _rebuild();
  }

  bool _renderSceneLights = false;

  /// Whether the preview is rendered primarily using lights authored in the scene,
  /// with the preview sun turned off and environment IBL dimmed to dark ambient.
  bool get renderSceneLights => _renderSceneLights;

  /// Whether the blueprint currently contains at least one authored light component.
  bool get hasSceneLights {
    final doc = _document;
    if (doc != null && doc.components.any((c) => _isLightType(c.type))) return true;
    final a = _actor;
    if (a != null && a.components.any((c) => c is LuminaLightComponent)) return true;
    return false;
  }

  static bool _isLightType(String type) =>
      type == 'LuminaSpotLightComponent' ||
      type == 'LuminaPointLightComponent' ||
      type == 'LuminaDirectionalLightComponent' ||
      type == 'SpotLightComponent' ||
      type == 'PointLightComponent' ||
      type == 'DirectionalLightComponent' ||
      type.contains('LightComponent') ||
      type.endsWith('Light');

  void setRenderSceneLights(bool value) {
    if (_renderSceneLights == value) return;
    _renderSceneLights = value;
    _updateEnvironmentLighting();
    _notify();
  }

  void toggleRenderSceneLights() => setRenderSceneLights(!_renderSceneLights);

  void _updateEnvironmentLighting() {
    final w = _world;
    if (w == null) return;
    for (final a in _environment) {
      final root = a.rootComponent;
      if (root is LuminaDirectionalLightComponent) {
        root.intensity = _renderSceneLights ? 0.0 : 90000.0;
        root.visible = !_renderSceneLights;
      } else if (root is LuminaSkyComponent) {
        root.visible = !_renderSceneLights;
        root.color = _renderSceneLights ? Vector4(0.002, 0.002, 0.003, 1.0) : Vector4(0.10, 0.11, 0.14, 1.0);
        root.iblIntensity = _renderSceneLights ? 0.0 : 22000.0;
      }
    }
  }

  void _mountEnvironment() {
    final w = _world!;
    if (!w.hasNativeContext) return;
    // The viewport lights nothing in a preview world. The sun
    // comes from in front of the actor (it faces −Z), where the viewport
    // looks from, and from the camera's left.
    try {
      for (final a in [
        LuminaActor(
          key: const LuminaObjectKey('blueprint_preview_sun'),
          root: LuminaDirectionalLightComponent(
            rotation: Quaternion.euler(215 * math.pi / 180, -50 * math.pi / 180, 0),
            color: Vector3(1.0, 0.97, 0.92),
            intensity: 90000.0,
            castShadows: true,
            isSun: true,
          ),
        ),
        LuminaActor(
          key: const LuminaObjectKey('blueprint_preview_sky'),
          root: LuminaSkyComponent.color(color: Vector4(0.10, 0.11, 0.14, 1.0), skyIntensity: 14000.0, iblIntensity: 22000.0),
        ),
      ]) {
        w.persistentLevel.registerActor(a);
        _environment.add(a);
      }
      _updateEnvironmentLighting();
    } catch (e, st) {
      debugPrint('[BlueprintPreviewScene] environment failed: $e\n$st');
    }
  }

  // ---------------------------------------------------------------------------
  // The actor
  // ---------------------------------------------------------------------------

  void _rebuild() {
    _retire(_actor);
    _actor = null;
    _built = const {};
    _revision++;
    _overlays = null;
    final doc = _document;
    if (doc == null || _disposed) {
      _notify();
      return;
    }
    diagnostics.clear();
    final dir = _projectDir;
    final registry = dir == null ? null : (_registry ??= LuminaBlueprintClassRegistry(dir, inputActions: const []));
    final registryIssues = registry?.diagnostics.length ?? 0;
    const key = LuminaObjectKey('blueprint_preview_actor');
    final LuminaActor actor = switch (doc.parentClass) {
      'LuminaCharacter' => LuminaCharacter(key: key),
      'LuminaPawn' => LuminaPawn(key: key),
      _ => LuminaActor(key: key),
    };
    // A convex component names a mesh whose simple collision hulls it wraps;
    // lumina resolves that name through the editor's mesh collision service
    // (an older document has no `hullPoints`).
    if (dir != null) {
      LuminaBlueprintComponents.hullResolver = (hullAsset) {
        final hulls = MeshCollisionService.hullsForMeshAsset(hullAsset, projectDir: dir);
        final points = [for (final h in hulls) ...h.runtimePoints];
        return points.length >= 4 ? points : null;
      };
      // A static mesh's `metadata.physics` (the Static
      // Mesh editor's mass and centre of mass) through lumina's service.
      LuminaBlueprintComponents.meshPhysicsResolver = (stored) => MeshPhysicsService.forMeshAsset(stored, projectDir: dir);
    }
    try {
      _built = LuminaBlueprintComponents.construct(
        actor,
        doc.components,
        resolveAsset: registry?.resolveAsset,
        // Components name project files `contents/…` (a Material Override,
        // its textures): read them from this project, as Play does.
        assetProvider: dir == null
            ? null
            : (path) => File(path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path) ? path : '$dir/$path').readAsBytes(),
        animBlueprints: registry == null ? null : (animClass) => registry.animClassFor(animClass)?.factory,
        diagnostics: diagnostics,
      );
    } catch (e) {
      diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, 'The preview could not be built: $e'));
    }
    if (registry != null) diagnostics.addAll(registry.diagnostics.skip(registryIssues));
    // An editor preview: the viewport's orbit camera stays in charge.
    for (final c in actor.components) {
      if (c is LuminaCameraComponent) c.isActive = false;
    }
    _actor = actor;

    final w = _world;
    if (w != null && !w.isCleanedUp) {
      try {
        w.persistentLevel.registerActor(actor);
        actor.onInitialize();
        // Begins the Anim Blueprints (entry state, its clip) and turns the
        // mesh to face the actor's forward, as in Play.
        actor.onBeginPlay();
      } catch (e, st) {
        debugPrint('[BlueprintPreviewScene] mount failed: $e\n$st');
      }
      for (final mesh in _built.values.whereType<LuminaStaticMeshComponent>()) {
        mesh.loaded.then((_) {
          if (!identical(_actor, actor) || _disposed) return;
          _revision++;
          _overlays = null;
          _notify();
        }).catchError((Object e) {
          diagnostics.add(LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, '${mesh.meshAssetPath}: $e'));
        });
      }
    }
    _placeSpringArms();
    _lastState = null;
    _notify();
  }

  /// Puts every spring arm's children at its socket, as its tick does in
  /// Play once the lag has settled (no collision probe: there is no level).
  void _placeSpringArms() {
    for (final arm in _built.values.whereType<LuminaSpringArmComponent>()) {
      final lag = arm.bEnableCameraLag;
      final rotationLag = arm.bEnableCameraRotationLag;
      final collision = arm.bDoCollisionTest;
      arm
        ..bEnableCameraLag = false
        ..bEnableCameraRotationLag = false
        ..bDoCollisionTest = false;
      try {
        arm.onTick(0.0);
      } catch (e) {
        debugPrint('[BlueprintPreviewScene] spring arm: $e');
      } finally {
        arm
          ..bEnableCameraLag = lag
          ..bEnableCameraRotationLag = rotationLag
          ..bDoCollisionTest = collision;
      }
    }
  }

  /// Takes [actor] out of the world. A mesh still loading is hidden and the
  /// actor unregistered once the load settles, so the late load cannot add
  /// its entities to the scene after the actor is gone.
  void _retire(LuminaActor? actor, {bool immediately = false}) {
    final w = _world;
    if (actor == null || w == null || w.isCleanedUp || actor.owningLevel == null) return;
    final loading = [
      for (final c in actor.components)
        if (c is LuminaStaticMeshComponent && !c.isLoaded && w.hasNativeContext) c,
    ];
    void unregister() {
      if (w.isCleanedUp || actor.owningLevel == null) return;
      try {
        w.persistentLevel.unregisterActor(actor);
      } catch (e) {
        debugPrint('[BlueprintPreviewScene] unregister: $e');
      }
    }

    if (loading.isEmpty || immediately) {
      unregister();
      return;
    }
    for (final mesh in loading) {
      mesh.visible = false;
    }
    Future.wait([for (final m in loading) m.loaded.catchError((_) {})]).whenComplete(unregister);
  }

  /// One preview frame of [dt] seconds: Anim Blueprints choose the pose,
  /// meshes apply it, the world syncs transforms to Filament.
  void advance(double dt) {
    final w = _world;
    if (w == null || w.isCleanedUp || _actor == null) return;
    try {
      for (final c in _built.values) {
        if (c is LuminaAnimBlueprintInstance) c.onTick(dt);
      }
      for (final c in _built.values) {
        if (c is LuminaAnimatedMeshComponent) c.onTick(dt);
      }
      w.tick(0.0);
    } catch (e, st) {
      debugPrint('[BlueprintPreviewScene] tick failed: $e\n$st');
    }
    if (++_framesSinceTextureCheck >= 60) {
      _framesSinceTextureCheck = 0;
      if (_texturesChanged()) {
        _rebuild();
        return;
      }
    }
    final state = _animSummary();
    if (state != _lastState) {
      _lastState = state;
      _notify();
    }
  }

  /// Whether a texture the built meshes' materials draw was saved again
  /// (Texture editor Save / Reimport, an import over it) since it was first
  /// seen: their materials are then built anew with it.
  bool _texturesChanged() {
    final dir = _projectDir;
    final stamps = <String, String>{};
    for (final c in _built.values) {
      if (c is! LuminaStaticMeshComponent) continue;
      for (var i = 0; i < 8; i++) {
        final material = c.materialOverride(i)?.material;
        if (material == null || material.isDisposed) continue;
        for (final t in material.textures.bound.values) {
          final p = t.path;
          final absolute = p.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(p);
          try {
            final stat = File(absolute || dir == null ? p : '$dir/$p').statSync();
            stamps[p] = '${stat.modified.microsecondsSinceEpoch}:${stat.size}';
          } catch (_) {}
        }
      }
    }
    final changed = stamps.entries.any((e) => _textureStamps.containsKey(e.key) && _textureStamps[e.key] != e.value);
    _textureStamps = changed ? const {} : stamps;
    return changed;
  }

  String? _animSummary() {
    final parts = <String>[];
    for (final e in _built.entries) {
      final anim = e.value;
      if (anim is LuminaAnimBlueprintInstance) parts.add('${anim.currentState}:${anim.mesh.currentClip}');
    }
    return parts.isEmpty ? null : parts.join(',');
  }

  /// One line for the viewport's stats strip: the mesh, and what it plays.
  String get summary {
    final doc = _document;
    if (doc == null) return 'No Blueprint';
    final parts = <String>['${doc.components.length} components'];
    for (final c in doc.components) {
      final built = _built[c.id];
      if (built is! LuminaStaticMeshComponent) continue;
      final name = built.meshAssetPath.split('/').last.replaceAll('.entity.glb', '').replaceAll('.lmas', '');
      final anim = animInstanceFor(c.id);
      final animClass = (c.properties['animClass'] as String? ?? '').split('/').last.replaceAll('.lmas', '');
      if (anim != null) {
        parts.add('${c.name}: $name · $animClass ${anim.currentState ?? ''} (${anim.mesh.currentClip ?? 'no clip'})');
      } else if (built is LuminaAnimatedMeshComponent) {
        parts.add('${c.name}: $name · reference pose (no Animation Blueprint)');
      } else {
        parts.add('${c.name}: $name');
      }
    }
    if (diagnostics.any((d) => d.isError)) parts.add(diagnostics.firstWhere((d) => d.isError).message);
    return parts.join('  ·  ');
  }

  // ---------------------------------------------------------------------------
  // Component transforms
  // ---------------------------------------------------------------------------

  /// The built scene component of [id] as the viewport's gizmo needs it:
  /// its world location and rotation, and its parent's world rotation (the
  /// frame its relative transform is written in), all runtime frame (Y up).
  ({Vector3 worldLocation, Quaternion worldRotation, Quaternion parentRotation})? sceneTransformFor(String id) {
    final built = _built[id];
    if (built is! LuminaSceneComponent) return null;
    return (
      worldLocation: built.worldLocation,
      worldRotation: built.worldRotation.clone(),
      parentRotation: built.parentComponent?.worldRotation.clone() ?? Quaternion.identity(),
    );
  }

  /// Moves the built component of [id] live, as a gizmo drag writes the
  /// relative [location] / [rotation] / [scale] (authoring values), without
  /// rebuilding the actor: spring arms re-place their children, the overlays
  /// follow, and the attached world's next tick syncs Filament.
  void setComponentTransform(String id, {List<double>? location, List<double>? rotation, List<double>? scale}) {
    final built = _built[id];
    final doc = _document;
    if (built is! LuminaSceneComponent || doc == null) return;
    final c = doc.components.where((c) => c.id == id).firstOrNull;
    if (c != null) {
      if (location != null) c.properties['location'] = List<double>.from(location);
      if (rotation != null) c.properties['rotation'] = List<double>.from(rotation);
      if (scale != null) c.properties['scale'] = List<double>.from(scale);
    }
    if (location != null) built.relativeLocation = LuminaAxes.location(location);
    if (rotation != null) built.relativeRotation = LuminaAxes.rotation(rotation);
    if (scale != null) built.relativeScale = LuminaAxes.scale(scale);
    _placeSpringArms();
    _revision++;
    _overlays = null;
    _lastState = null;
    _notify();
  }

  /// The scene component under [ray] (runtime frame): the nearest hit among
  /// the components' bounding boxes — a capsule's, boom's, camera's or
  /// arrow's drawn lines, a mesh's bounds — or null. Boxes thinner than
  /// [pickPadding] (a boom is a line) are padded so they can be hit.
  String? pick(ViewportRay ray) {
    final doc = _document;
    if (doc == null) return null;
    String? best;
    var bestT = double.infinity;
    var bestVolume = double.infinity;
    for (final c in doc.components) {
      final built = _built[c.id];
      if (built is! LuminaSceneComponent) continue;
      final box = _pickBox(c, built);
      if (box == null) continue;
      final t = _rayBox(ray, box.$1, box.$2);
      if (t == null) continue;
      final volume = (box.$2 - box.$1).x * (box.$2 - box.$1).y * (box.$2 - box.$1).z;
      // A smaller box wins a near tie: the mesh sits inside the capsule.
      final better = t < bestT - pickPadding || ((t - bestT).abs() <= pickPadding && volume < bestVolume);
      if (better) {
        best = c.id;
        bestT = t;
        bestVolume = volume;
      }
    }
    return best;
  }

  static const double pickPadding = 6.0;

  (Vector3, Vector3)? _pickBox(LuminaBlueprintComponent c, LuminaSceneComponent built) {
    final points = <Vector3>[];
    switch (c.type) {
      case 'LuminaCapsuleComponent':
        if (built is LuminaCapsuleComponent) points.addAll(built.buildCapsuleWireframe(segments: 12));
      case 'LuminaSpringArmComponent':
        if (built is LuminaSpringArmComponent) points.addAll(_springArm(built));
      case 'LuminaCameraComponent':
        if (built is LuminaCameraComponent) points.addAll(_cameraFrustum(built));
      case 'LuminaArrowComponent':
        final size = (c.properties['arrowSize'] as num?)?.toDouble() ?? 1.0;
        points.addAll(_arrow(built, 80.0 * size));
      case 'LuminaSpotLightComponent':
        if (built is LuminaSpotLightComponent) points.addAll(built.buildConeWireframe(segments: 12));
      case 'LuminaPointLightComponent':
        if (built is LuminaPointLightComponent) points.addAll(built.buildSphereWireframe(segments: 12));
      case 'LuminaDirectionalLightComponent':
        if (built is LuminaDirectionalLightComponent) points.addAll(built.buildArrowWireframe());
      case 'LuminaStaticMeshComponent':
      case 'LuminaSkeletalMeshComponent':
      case 'LuminaAnimatedMeshComponent':
        if (built is LuminaStaticMeshComponent) points.addAll(_bounds(built));
        if (points.isEmpty) points.addAll(_tripod(built, 40.0));
      default:
        if (shapeTypes.contains(c.type) && built is LuminaCollisionComponent) {
          points.addAll(built.buildWireframe(segments: 12));
        } else {
          points.addAll(_tripod(built, 30.0));
        }
    }
    if (points.isEmpty) return null;
    final lo = Vector3.copy(points.first);
    final hi = Vector3.copy(points.first);
    for (final p in points) {
      Vector3.min(lo, p, lo);
      Vector3.max(hi, p, hi);
    }
    for (var i = 0; i < 3; i++) {
      if (hi[i] - lo[i] < pickPadding * 2) {
        lo[i] -= pickPadding;
        hi[i] += pickPadding;
      }
    }
    return (lo, hi);
  }

  /// Slab test: the ray parameter where it enters the box, or null.
  static double? _rayBox(ViewportRay ray, Vector3 lo, Vector3 hi) {
    var tMin = 0.0;
    var tMax = double.infinity;
    for (var i = 0; i < 3; i++) {
      final o = ray.origin[i];
      final d = ray.direction[i];
      if (d.abs() < 1e-9) {
        if (o < lo[i] || o > hi[i]) return null;
        continue;
      }
      var t1 = (lo[i] - o) / d;
      var t2 = (hi[i] - o) / d;
      if (t1 > t2) {
        final tmp = t1;
        t1 = t2;
        t2 = tmp;
      }
      if (t1 > tMin) tMin = t1;
      if (t2 < tMax) tMax = t2;
      if (tMin > tMax) return null;
    }
    return tMin;
  }

  // ---------------------------------------------------------------------------
  // Overlays
  // ---------------------------------------------------------------------------

  /// The centre-of-mass marker's colour.
  static const (double, double, double) centerOfMassColor = (1.0, 0.25, 0.85);

  /// Where [component]'s body turns about, world space (runtime, cm): its
  /// shapes' centroid moved by its (or its mesh's) centre-of-mass offset.
  static Vector3 centerOfMassOf(LuminaPrimitivePhysics component) {
    final props = LuminaPhysicsSubsystem.resolveMassProperties(component);
    final scene = component as LuminaSceneComponent;
    return scene.worldLocation + scene.worldRotation.rotateVector(props.centerOfMass);
  }

  /// The line overlays, in runtime space (Y up, cm).
  List<SubEditorLineSet> get overlays => _overlays ??= _buildOverlays();

  List<SubEditorLineSet> _buildOverlays() {
    final doc = _document;
    if (doc == null) return const [];
    final out = <SubEditorLineSet>[];
    for (final c in doc.components) {
      final built = _built[c.id];
      if (built is! LuminaSceneComponent) continue;
      final selected = c.id == _selected;
      final points = <Vector3>[];
      var color = selectionColor;
      switch (c.type) {
        case 'LuminaCapsuleComponent':
          if (built is LuminaCapsuleComponent) points.addAll(built.buildCapsuleWireframe(segments: 24));
          color = capsuleColor;
        case 'LuminaSpringArmComponent':
          if (built is LuminaSpringArmComponent) points.addAll(_springArm(built));
          color = springArmColor;
        case 'LuminaCameraComponent':
          if (built is LuminaCameraComponent) points.addAll(_cameraFrustum(built));
          color = cameraColor;
        case 'LuminaArrowComponent':
          final size = (c.properties['arrowSize'] as num?)?.toDouble() ?? 1.0;
          points.addAll(_arrow(built, 80.0 * size));
          color = _hexColor(c.properties['arrowColor']) ?? (0.0, 0.53, 1.0);
        case 'LuminaSpotLightComponent':
          if (built is LuminaSpotLightComponent) points.addAll(built.buildConeWireframe(segments: 24));
          color = spotLightColor;
        case 'LuminaPointLightComponent':
          if (built is LuminaPointLightComponent) points.addAll(built.buildSphereWireframe(segments: 24));
          color = pointLightColor;
        case 'LuminaDirectionalLightComponent':
          if (built is LuminaDirectionalLightComponent) points.addAll(built.buildArrowWireframe());
          color = spotLightColor;
        case 'LuminaStaticMeshComponent':
        case 'LuminaSkeletalMeshComponent':
        case 'LuminaAnimatedMeshComponent':
          // Selection only: the mesh itself is what is drawn.
          if (selected && built is LuminaStaticMeshComponent) points.addAll(_bounds(built));
        default:
          if (shapeTypes.contains(c.type) && built is LuminaCollisionComponent) {
            // Box, sphere, cylinder, cone and convex hull
            // wireframes from lumina's shapes (scaled by the transform).
            points.addAll(built.buildWireframe(segments: 24));
            color = capsuleColor;
          } else if (selected) {
            points.addAll(_tripod(built, 30.0));
          }
      }
      // The selected simulating component's centre of mass.
      if (selected && built is LuminaPrimitivePhysics && built.simulatePhysics) {
        final com = centerOfMassOf(built);
        final (r, g, b) = centerOfMassColor;
        out.add(SubEditorLineSet(
          id: '${c.id}.com',
          positions: [for (final p in _cross(com, 12.0)) ...[p.x, p.y, p.z]],
          indices: List<int>.generate(6, (i) => i),
          r: r,
          g: g,
          b: b,
          selected: false,
          xray: true,
          signature: '${c.id}.com|$_revision|${com.x},${com.y},${com.z}',
        ));
      }
      if (points.isEmpty) continue;
      final (r, g, b) = selected ? selectionColor : color;
      out.add(SubEditorLineSet(
        id: c.id,
        positions: [for (final p in points) ...[p.x, p.y, p.z]],
        indices: List<int>.generate(points.length - points.length % 2, (i) => i),
        r: r,
        g: g,
        b: b,
        selected: selected,
        xray: selected,
        signature: '${c.id}|$selected|$_revision',
      ));
    }
    return out;
  }

  /// The boom from its origin to the socket its children sit at, and a small
  /// cross at each end.
  static List<Vector3> _springArm(LuminaSpringArmComponent arm) {
    final origin = arm.worldLocation;
    final socket = arm.socketWorldLocation;
    return [origin, socket, ..._cross(origin, 6.0), ..._cross(socket, 6.0)];
  }

  static List<Vector3> _cross(Vector3 at, double size) => [
        at + Vector3(size, 0, 0), at - Vector3(size, 0, 0),
        at + Vector3(0, size, 0), at - Vector3(0, size, 0),
        at + Vector3(0, 0, size), at - Vector3(0, 0, size),
      ];

  /// A camera: its frustum 50 cm deep (its vertical field of view, 16:9) and
  /// a triangle on the top edge marking up.
  static List<Vector3> _cameraFrustum(LuminaCameraComponent camera) {
    const depth = 50.0;
    final eye = camera.worldLocation;
    final forward = camera.forwardVector;
    final up = camera.upVector;
    final right = camera.rightVector;
    final halfH = math.tan(camera.fieldOfViewInDegrees * math.pi / 360.0) * depth;
    final halfW = halfH * 16.0 / 9.0;
    final centre = eye + forward * depth;
    final corners = [
      centre + right * halfW + up * halfH,
      centre - right * halfW + up * halfH,
      centre - right * halfW - up * halfH,
      centre + right * halfW - up * halfH,
    ];
    return [
      for (final c in corners) ...[eye, c],
      for (var i = 0; i < 4; i++) ...[corners[i], corners[(i + 1) % 4]],
      corners[0] + up * (halfH * 0.15), centre + up * (halfH * 1.5),
      centre + up * (halfH * 1.5), corners[1] + up * (halfH * 0.15),
      corners[1] + up * (halfH * 0.15), corners[0] + up * (halfH * 0.15),
    ];
  }

  static List<Vector3> _arrow(LuminaSceneComponent c, double length) {
    final from = c.worldLocation;
    final forward = c.forwardVector;
    final to = from + forward * length;
    final side = c.rightVector * (length * 0.12);
    final back = forward * (length * 0.2);
    return [from, to, to, to - back + side, to, to - back - side];
  }

  static List<Vector3> _tripod(LuminaSceneComponent c, double length) {
    final at = c.worldLocation;
    return [at, at + c.rightVector * length, at, at + c.upVector * length, at, at - c.forwardVector * length];
  }

  /// A loaded mesh's bounds as a box, in the world.
  static List<Vector3> _bounds(LuminaStaticMeshComponent mesh) {
    final box = mesh.localBounds;
    if (box == null) return const [];
    final m = mesh.worldTransform;
    final c = [
      for (var i = 0; i < 8; i++)
        m.transformed3(Vector3(i & 1 == 0 ? box.min.x : box.max.x, i & 2 == 0 ? box.min.y : box.max.y,
            i & 4 == 0 ? box.min.z : box.max.z)),
    ];
    const edges = [0, 1, 2, 3, 4, 5, 6, 7, 0, 2, 1, 3, 4, 6, 5, 7, 0, 4, 1, 5, 2, 6, 3, 7];
    return [for (final e in edges) c[e]];
  }

  static (double, double, double)? _hexColor(Object? hex) {
    if (hex is! String) return null;
    final h = hex.replaceFirst('#', '');
    if (h.length < 6) return null;
    final v = int.tryParse(h.substring(0, 6), radix: 16);
    if (v == null) return null;
    return (((v >> 16) & 0xFF) / 255.0, ((v >> 8) & 0xFF) / 255.0, (v & 0xFF) / 255.0);
  }

  /// Where the viewport's orbit camera starts (runtime space, cm): centred
  /// on the actor's body — its capsule and meshes, framing a Blueprint by
  /// its primitives — from twice the distance that fits them in
  /// the 45° view, which leaves the boom and the camera behind it in frame.
  ({Vector3 target, double distance}) get framing {
    List<Vector3> pointsOf(Iterable<SubEditorLineSet> sets) => [
          for (final set in sets)
            for (var i = 0; i + 2 < set.positions.length; i += 3)
              Vector3(set.positions[i], set.positions[i + 1], set.positions[i + 2]),
        ];
    final capsules = {
      for (final c in _document?.components ?? const <LuminaBlueprintComponent>[])
        if (c.type == 'LuminaCapsuleComponent' || shapeTypes.contains(c.type)) c.id,
    };
    final points = [
      ...pointsOf(overlays.where((s) => capsules.contains(s.id))),
      for (final mesh in _built.values.whereType<LuminaStaticMeshComponent>()) ..._bounds(mesh),
    ];
    if (points.isEmpty) points.addAll(pointsOf(overlays));
    if (points.isEmpty) return (target: Vector3.zero(), distance: 400.0);
    final lo = Vector3.copy(points.first);
    final hi = Vector3.copy(points.first);
    for (final p in points) {
      Vector3.min(lo, p, lo);
      Vector3.max(hi, p, hi);
    }
    final radius = math.max((hi - lo).length / 2, 60.0);
    return (target: (lo + hi) * 0.5, distance: radius / math.sin(22.5 * math.pi / 180.0) * 2.0);
  }

  @override
  void dispose() {
    _disposed = true;
    detach();
    super.dispose();
  }
}
