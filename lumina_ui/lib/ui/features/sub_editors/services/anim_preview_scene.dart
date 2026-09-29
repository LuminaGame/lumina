import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueKey, debugPrint;
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// The Anim Preview's stand-in pawn movement: Get Velocity and Is Falling
/// answer what the Anim Preview Editor's owner controls say; nothing is
/// simulated.
class AnimPreviewOwnerMovement extends LuminaCharacterMovementComponent {
  /// Velocity in runtime space (Y up), cm/s.
  final Vector3 standInVelocity = Vector3.zero();
  bool standInFalling = false;

  AnimPreviewOwnerMovement() : super(key: const ValueKey('anim_preview_owner_movement'));

  @override
  Vector3 get velocity => standInVelocity;

  @override
  bool get isFalling => standInFalling;

  @override
  void onTick(double deltaTime) {}
}

/// A skeletal mesh on a stand-in owner, played either by an Animation
/// Blueprint instance or by clip requests, in a lumina world: the editor
/// world a sub-editor viewport hands over (the mesh renders through
/// flutter_filament), or a headless world of its own (no native context:
/// clips are requested but nothing draws — widget tests, and the editor
/// before its viewport is up).
///
/// Editor worlds do not tick gameplay, so the scene drives the owner itself:
/// the Animation Blueprint instance first (it picks the pose), then the mesh
/// (it applies it), then a zero-length world tick for render prep.
class AnimPreviewScene {
  LuminaWorld? _world;
  bool _ownsWorld = false;
  LuminaActor? _owner;
  final AnimPreviewOwnerMovement movement = AnimPreviewOwnerMovement();
  LuminaAnimatedMeshComponent? _mesh;
  LuminaAnimBlueprintInstance? _anim;
  String? _meshPath;
  LuminaAssetProvider? _meshProvider;
  Timer? _timer;
  final List<LuminaActor> _environment = [];

  /// Called before each tick (write overrides into the instance).
  void Function(double dt)? beforeTick;

  /// Called after each tick (repaint the highlighted state).
  void Function()? afterTick;

  static const double tickSeconds = 1.0 / 60.0;

  LuminaWorld? get world => _world;
  bool get isAttached => _world != null && !_world!.isCleanedUp;
  bool get hasNativeWorld => isAttached && _world!.hasNativeContext;
  LuminaAnimatedMeshComponent? get mesh => _mesh;
  LuminaAnimBlueprintInstance? get animInstance => _anim;
  LuminaActor? get owner => _owner;

  /// The clip the mesh plays now (the fade target while cross-fading).
  String? get currentClip => _mesh?.currentClip;

  /// Binds the viewport's editor world and starts ticking at 60 Hz.
  void attach(LuminaWorld world, {bool startTicker = true}) {
    detach();
    _world = world;
    _ownsWorld = false;
    _mountEnvironment();
    _mountOwner();
    if (startTicker) _startTicker();
  }

  /// A world of its own with no native context.
  void attachHeadless({bool startTicker = true}) {
    detach();
    _world = LuminaWorld(worldType: LuminaWorldType.editor);
    _ownsWorld = true;
    _mountOwner();
    if (startTicker) _startTicker();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(microseconds: 16667), (_) => advance(tickSeconds));
  }

  void stopTicker() {
    _timer?.cancel();
    _timer = null;
  }

  void _mountEnvironment() {
    final w = _world!;
    if (!w.hasNativeContext) return;
    LuminaActor add(LuminaActor a) {
      w.persistentLevel.registerActor(a);
      _environment.add(a);
      return a;
    }

    try {
      add(LuminaActor(
        key: const ValueKey('anim_preview_sun'),
        root: LuminaDirectionalLightComponent(
          rotation: Quaternion.euler(35 * math.pi / 180, -50 * math.pi / 180, 0),
          color: Vector3(1.0, 0.97, 0.92),
          intensity: 90000.0,
          castShadows: true,
          isSun: true,
        ),
      ));
      add(LuminaActor(
        key: const ValueKey('anim_preview_sky'),
        root: LuminaSkyComponent.color(
          color: Vector4(0.10, 0.11, 0.14, 1.0),
          skyIntensity: 14000.0,
          iblIntensity: 22000.0,
        ),
      ));
    } catch (e, st) {
      debugPrint('[AnimPreviewScene] environment failed: $e\n$st');
    }
  }

  void _mountOwner() {
    final w = _world!;
    final owner = LuminaActor(key: const ValueKey('anim_preview_owner'));
    owner.addComponent(movement);
    _owner = owner;
    w.persistentLevel.registerActor(owner);
    owner.onInitialize();
    owner.onBeginPlay();
    if (_meshPath != null) _mountMesh();
  }

  /// Shows the mesh at [path] (a GLB file, or an `.lmas` read through
  /// [provider]); the same path again keeps the loaded mesh.
  void setMesh(String? path, {LuminaAssetProvider? provider}) {
    if (path == _meshPath) return;
    _meshPath = path;
    _meshProvider = provider;
    if (_owner == null) return;
    _unmountMesh();
    if (path != null) _mountMesh();
  }

  void _mountMesh() {
    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: _meshPath!, assetProvider: _meshProvider);
    _mesh = mesh;
    _owner!.addComponent(mesh);
  }

  void _unmountMesh() {
    final anim = _anim;
    if (anim != null) {
      _owner?.removeComponent(anim);
      _anim = null;
    }
    final mesh = _mesh;
    if (mesh != null) _owner?.removeComponent(mesh);
    _mesh = null;
  }

  /// Plays [instance] on the mesh from now on (null: none). The previous
  /// instance is removed; [carryVariables] seeds the new one's variables.
  void setAnimInstance(LuminaAnimBlueprintInstance? instance, {Map<String, Object?> carryVariables = const {}}) {
    final old = _anim;
    if (old != null) _owner?.removeComponent(old);
    _anim = instance;
    if (instance != null) {
      instance.variables.addAll(carryVariables);
      _owner?.addComponent(instance);
    }
  }

  /// Blends the mesh to [clip] (a Blend Space preview's nearest sample).
  void crossFadeTo(String clip, {double duration = 0.2}) {
    final mesh = _mesh;
    if (mesh == null || mesh.currentClip == clip) return;
    try {
      if (mesh.currentClip == null) {
        mesh.play(clip);
      } else {
        mesh.crossFadeTo(clip, duration: duration);
      }
    } catch (e) {
      debugPrint('[AnimPreviewScene] $clip: $e');
    }
  }

  /// One preview frame of [dt] seconds.
  void advance(double dt) {
    final w = _world;
    if (w == null || w.isCleanedUp) return;
    try {
      beforeTick?.call(dt);
      _anim?.onTick(dt);
      _mesh?.onTick(dt);
      w.tick(0.0);
      afterTick?.call();
    } catch (e, st) {
      debugPrint('[AnimPreviewScene] tick failed: $e\n$st');
    }
  }

  /// Releases the world: unregisters what the scene added, or cleans up its
  /// own headless world.
  void detach() {
    _timer?.cancel();
    _timer = null;
    final w = _world;
    if (w != null && !w.isCleanedUp) {
      try {
        _anim = null;
        _mesh = null;
        if (_owner != null) w.persistentLevel.unregisterActor(_owner!);
        for (final a in _environment) {
          w.persistentLevel.unregisterActor(a);
        }
        if (_ownsWorld) w.cleanup();
      } catch (e) {
        debugPrint('[AnimPreviewScene] detach: $e');
      }
    }
    _environment.clear();
    _owner = null;
    _world = null;
  }
}
