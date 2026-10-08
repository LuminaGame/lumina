import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/animation/motion_matching/pose_search_database_runtime.dart';
import 'package:lumina/src/collision/collision_subsystem.dart';
import 'package:lumina/src/components/base/actor_component.dart';
import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/components/mesh/mesh_pose_modifier.dart';
import 'package:lumina/src/components/movement/character_movement_component.dart';
import 'package:lumina/src/physics/physics_subsystem.dart';
import 'package:lumina/src/physics/ragdoll/fall_monitor.dart';
import 'package:lumina/src/physics/ragdoll/ragdoll.dart';
import 'package:lumina/src/physics/ragdoll/ragdoll_get_up.dart';
import 'package:lumina/src/physics/ragdoll/ragdoll_poser.dart';
import 'package:lumina/src/physics/ragdoll/ragdoll_skeleton.dart';
import 'package:lumina/src/utility/lumina_assets.dart';

part 'ragdoll_component_states.dart';

/// What a [LuminaRagdollComponent] is doing.
enum LuminaRagdollState {
  /// The animation shows (a heavy landing may play over it).
  animated,

  /// The bodies drive the bones.
  ragdoll,

  /// A get-up clip blends in from the ragdoll's last pose.
  gettingUp,

  /// No get-up clip: the animation blends back in.
  blendingOut,
}

/// Makes its owner's animated mesh a ragdoll on demand and on hard falls.
///
/// The bodies and joints come from a physics asset ([physicsAssetPath], a
/// `physicsAsset` `.lmas`; or [physicsAsset]; or, with neither, one
/// generated from the mesh's skeleton by [LuminaPhysicsAssetGenerator]).
/// The mesh's skeleton and clips are read on the CPU from its GLB.
///
/// - [startRagdoll] goes limp at the animated pose, carrying the animation's
///   velocity; the bodies drive the bones through a pose modifier, faded in
///   over [blendInTime] up to [blendWeight] (1 fully physical). The
///   movement component is parked in a custom mode
///   ([ragdollMovementMode]) and the capsule follows the pelvis on the
///   ground, so the camera follows.
/// - [powered]: joint motors pull toward the animated pose with
///   [motorStrength] (kg·cm²/s² per kg of the child body). While falling,
///   [flailClip] drives the motors instead ([flailStrength]).
/// - Falls ([autoRagdollOnFall]): a [LuminaFallMonitor] on the movement
///   component; falling faster than its ragdoll speed goes limp in the air,
///   a hard touchdown plays [hardLandingClip] over the animation.
/// - Getting up ([autoGetUp]): once every body moves slower than
///   [settleSpeed] for [settleTime] (or after [maxRagdollTime]), the clip of
///   [getUpClips] that lies like the ragdoll (face down or up) blends in from
///   the ragdoll's pose, the character is placed under it, its root motion
///   carries the character, and the animation takes over again
///   ([getUpBlendOut]); without a clip the animation blends back in over
///   [blendOutTime].
class LuminaRagdollComponent extends LuminaActorComponent implements LuminaMeshPoseModifier {
  LuminaRagdollComponent({
    super.key,
    this.physicsAssetPath = '',
    this.physicsAsset,
    this.mesh,
    this.sampler,
    this.blendWeight = 1.0,
    this.blendInTime = 0.08,
    this.blendOutTime = 0.4,
    this.powered = false,
    this.motorStrength = 2e6,
    this.motorRate = 20.0,
    this.autoRagdollOnFall = true,
    double hardLandingSpeed = 750.0,
    double ragdollLandingSpeed = 1200.0,
    double ragdollFallSpeed = 1300.0,
    this.autoGetUp = true,
    this.settleSpeed = 8.0,
    this.settleTime = 0.6,
    this.maxRagdollTime = 8.0,
    this.getUpClips = const [],
    this.getUpBlendIn = 0.3,
    this.getUpBlendOut = 0.35,
    this.flailClip = '',
    this.flailStrength = 6e5,
    this.hardLandingClip = '',
    this.hardLandingBlend = 0.15,
    this.meshYawOffsetDegrees = 0.0,
  }) : fallMonitor = LuminaFallMonitor(
            hardLandingSpeed: hardLandingSpeed, ragdollLandingSpeed: ragdollLandingSpeed, ragdollFallSpeed: ragdollFallSpeed) {
    // A load failure is reported through [loadError] (and to whoever awaits
    // [ready]), never as an unhandled error.
    _ready.future.ignore();
  }

  /// The custom movement mode index the movement component waits in while
  /// the character is a ragdoll or gets up.
  static const int ragdollMovementMode = 71;

  final String physicsAssetPath;
  LuminaPhysicsAssetData? physicsAsset;
  LuminaAnimatedMeshComponent? mesh;

  /// The mesh's skeleton and clips (read from its GLB when null).
  LuminaGlbAnimationSampler? sampler;

  double blendWeight;
  double blendInTime;
  double blendOutTime;
  bool powered;
  double motorStrength;
  double motorRate;
  bool autoRagdollOnFall;
  final LuminaFallMonitor fallMonitor;
  bool autoGetUp;
  double settleSpeed;
  double settleTime;
  double maxRagdollTime;
  List<String> getUpClips;
  double getUpBlendIn;
  double getUpBlendOut;
  String flailClip;
  double flailStrength;
  String hardLandingClip;
  double hardLandingBlend;

  /// The mesh's authored forward turned to glTF +Z (as its Animation
  /// Blueprint and pose search schema say).
  double meshYawOffsetDegrees;

  void Function()? onRagdollStarted;
  void Function()? onRagdollEnded;
  void Function(String clip)? onGetUpStarted;
  void Function(double impactSpeed)? onHardLanding;

  /// Builds the component from its Blueprint / level JSON properties
  /// (authoring units: cm, cm/s; angles in degrees).
  factory LuminaRagdollComponent.fromProperties(Map<String, dynamic> p) {
    double number(String k, double fallback) => p[k] is num ? (p[k] as num).toDouble() : fallback;
    bool flag(String k, bool fallback) => p[k] is bool ? p[k] as bool : fallback;
    String text(String k) => p[k] is String ? p[k] as String : '';
    List<String> list(String k) => p[k] is List
        ? [for (final v in p[k] as List) '$v']
        : text(k).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return LuminaRagdollComponent(
      physicsAssetPath: text('physicsAsset'),
      blendWeight: number('blendWeight', 1.0),
      blendInTime: number('blendInTime', 0.08),
      blendOutTime: number('blendOutTime', 0.4),
      powered: flag('powered', false),
      motorStrength: number('motorStrength', 2e6),
      autoRagdollOnFall: flag('autoRagdollOnFall', true),
      hardLandingSpeed: number('hardLandingSpeed', 750.0),
      ragdollLandingSpeed: number('ragdollLandingSpeed', 1200.0),
      ragdollFallSpeed: number('ragdollFallSpeed', 1300.0),
      autoGetUp: flag('autoGetUp', true),
      settleSpeed: number('settleSpeed', 8.0),
      settleTime: number('settleTime', 0.6),
      maxRagdollTime: number('maxRagdollTime', 8.0),
      getUpClips: list('getUpClips'),
      getUpBlendIn: number('getUpBlendIn', 0.3),
      getUpBlendOut: number('getUpBlendOut', 0.35),
      flailClip: text('flailClip'),
      flailStrength: number('flailStrength', 6e5),
      hardLandingClip: text('hardLandingClip'),
      meshYawOffsetDegrees: number('meshYawOffsetDegrees', 0.0),
    );
  }

  // --- State -------------------------------------------------------------------------

  LuminaRagdollState _state = LuminaRagdollState.animated;
  LuminaRagdollState get state => _state;
  bool get isRagdoll => _state == LuminaRagdollState.ragdoll;

  LuminaRagdoll? _ragdoll;

  /// The ragdoll while one simulates.
  LuminaRagdoll? get ragdoll => _ragdoll;

  final Completer<void> _ready = Completer();

  /// Completes when the skeleton and the physics asset are loaded.
  Future<void> get ready => _ready.future;
  bool get isReady => _skeleton != null;

  /// Why loading failed, if it did.
  String? loadError;

  LuminaRagdollSkeleton? _skeleton;
  LuminaRagdollPoser? _poser;
  LuminaRagdollGetUp? _getUp;
  LuminaRagdollPoser? _fullPoser;

  /// Seconds in the current state.
  double stateTime = 0.0;
  double _weight = 0.0;
  double _settledFor = 0.0;

  /// The current blend weight of the physics pose (0 animation … 1 physics).
  double get currentWeight => _weight;

  // The animated frames of the body bones in the last two frames.
  Map<String, LuminaBoneFrame>? _animated, _animatedBefore;
  double _animatedDt = 0.0;
  Map<String, LuminaBoneFrame> _snapshot = const {};
  final Float64List _meshAffine = Float64List(12);

  // A clip overlay: a get-up or a heavy landing over the live animation.
  _Overlay? _overlay;

  /// The get-up in progress (null otherwise).
  LuminaGetUpPlan? get getUpPlan => _overlay?.plan;

  /// The heavy-landing clip playing over the animation, if any.
  String? get overlayClip => _overlay?.clip;

  // --- Lifecycle -------------------------------------------------------------------

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    final target = mesh ??= owner?.components.whereType<LuminaAnimatedMeshComponent>().firstOrNull;
    if (target == null) {
      loadError = 'the actor has no animated mesh';
      return;
    }
    if (!target.poseModifiers.contains(this)) target.poseModifiers.add(this);
    unawaited(load());
  }

  @override
  void onUnregister() {
    mesh?.poseModifiers.remove(this);
    _ragdoll?.destroy();
    _ragdoll = null;
    super.onUnregister();
  }

  /// Loads the skeleton and the physics asset (once).
  Future<void> load() async {
    if (_skeleton != null || loadError != null) return;
    try {
      final target = mesh;
      final s = sampler ??
          await LuminaPoseSearchDatabaseRuntime.meshSampler(target!.meshAssetPath, provider: target.assetProvider);
      sampler = s;
      physicsAsset ??= await _readAsset(s);
      _setUp(s, physicsAsset!);
      if (!_ready.isCompleted) _ready.complete();
    } catch (e, st) {
      loadError = '$e';
      developer.log('Ragdoll: cannot load: $e', name: 'LuminaRagdoll', level: 900);
      if (!_ready.isCompleted) _ready.completeError(e, st);
    }
  }

  Future<LuminaPhysicsAssetData> _readAsset(LuminaGlbAnimationSampler s) async {
    if (physicsAssetPath.isEmpty) return LuminaPhysicsAssetGenerator.fromSampler(s);
    final path = physicsAssetPath;
    final bytes = await LuminaAssets.resolve(mesh?.assetProvider)(path);
    Map<String, dynamic> json;
    try {
      json = await Isolate.run(() => _parseAsset(bytes, path), debugName: 'physics asset');
    } on UnsupportedError {
      json = _parseAsset(bytes, path);
    }
    return LuminaPhysicsAssetData.fromJson(json);
  }

  /// The physics asset document of the `.lmas` [bytes] (on a worker isolate:
  /// it captures nothing of the component).
  static Map<String, dynamic> _parseAsset(Uint8List bytes, String path) {
    final raw = LuminaAsset.fromBytes(bytes).metadata[LuminaPhysicsAssetData.metadataKey] ?? '';
    if (raw.isEmpty) throw FormatException('$path has no physics asset document');
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  /// Uses [s] and [asset] right away (what [load] ends with).
  void setUp(LuminaGlbAnimationSampler s, LuminaPhysicsAssetData asset) {
    sampler = s;
    physicsAsset = asset;
    _setUp(s, asset);
    if (!_ready.isCompleted) _ready.complete();
  }

  void _setUp(LuminaGlbAnimationSampler s, LuminaPhysicsAssetData asset) {
    final bones = [for (final b in asset.bodies) s.indexOfNode(b.bone)].where((i) => i >= 0).toList();
    if (bones.isEmpty) throw StateError('the physics asset has no body on a bone of this mesh');
    final skeleton = LuminaRagdollSkeleton(s, bones: bones);
    _skeleton = skeleton;
    _poser = LuminaRagdollPoser(skeleton, [for (final b in asset.bodies) b.bone]);
  }

  LuminaRagdollGetUp? _getUpHelper() {
    final s = sampler;
    if (s == null) return null;
    try {
      _getUp ??= LuminaRagdollGetUp(s, meshYawOffsetDegrees: meshYawOffsetDegrees, unitScale: mesh?.assetUnitScale ?? 100.0);
      _fullPoser ??= LuminaRagdollPoser(_getUp!.skeleton, [for (final b in physicsAsset!.bodies) b.bone]);
    } on StateError {
      return null;
    }
    return _getUp;
  }

  LuminaCharacterMovementComponent? get _movement =>
      owner?.components.whereType<LuminaCharacterMovementComponent>().firstOrNull;

  // --- Pose modifier ------------------------------------------------------------------

  @override
  List<String> get poseModifierNodes {
    final overlay = _overlay;
    if (overlay != null) return _getUp!.skeleton.nodeNames;
    return _skeleton?.nodeNames ?? const [];
  }

  @override
  bool modifyPose(Float64List pose, Matrix4 meshTransform, double deltaTime) {
    final skeleton = _skeleton;
    if (skeleton == null) return false;
    _meshAffine.setAll(0, LuminaRagdollSkeleton.affineOf(meshTransform));
    final overlay = _overlay;
    if (overlay != null && pose.length == _getUp!.skeleton.length * 10) {
      return _applyOverlay(this, overlay, pose, deltaTime);
    }
    if (pose.length != skeleton.length * 10) return false;
    for (var i = 0; i < skeleton.length; i++) {
      // Nodes the mesh cannot address (above the skin) keep their rest pose.
      if (pose[i * 10 + 6] == 0 && pose[i * 10 + 3] == 0 && pose[i * 10 + 4] == 0 && pose[i * 10 + 5] == 0) {
        pose.setRange(i * 10, i * 10 + 10, skeleton.restPose, i * 10);
      }
    }
    final frames = _poser!.frames(pose, _meshAffine);
    if (_state == LuminaRagdollState.animated) {
      _animatedBefore = _animated;
      _animated = frames;
      _animatedDt = deltaTime;
      return false;
    }
    return _applyPhysicsPose(this, pose, deltaTime);
  }

  // --- Control ------------------------------------------------------------------------

  /// Goes limp at the animated pose; [impulse] (kg·cm/s) pushes [bone]'s body
  /// (the pelvis by default) at [location]. False while loading or already a
  /// ragdoll.
  bool startRagdoll({Vector3? impulse, String? bone, Vector3? location}) => _start(this, impulse, bone, location);

  /// Stops the ragdoll: gets up with a get-up clip when [getUp] and one
  /// fits, else blends back to the animation.
  void stopRagdoll({bool getUp = true}) => _stop(this, getUp);

  /// Starts the ragdoll, or gets up from it.
  void toggleRagdoll() {
    if (_state == LuminaRagdollState.ragdoll) {
      stopRagdoll();
    } else if (_state == LuminaRagdollState.animated) {
      startRagdoll();
    }
  }

  /// Pushes [bone]'s body (a hit); starts the ragdoll first when
  /// [startIfAnimated].
  void addImpulse(Vector3 impulse, {String? bone, Vector3? location, bool startIfAnimated = true}) {
    if (_ragdoll == null) {
      if (startIfAnimated) startRagdoll(impulse: impulse, bone: bone, location: location);
      return;
    }
    _ragdoll!.addImpulse(impulse, bone: bone, location: location);
  }

  /// Plays [clip] over the animation as a heavy landing.
  bool playHardLanding([String? clip]) => _playLanding(this, clip ?? hardLandingClip);

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    _tick(this, deltaTime);
  }

  // --- Helpers for the states ----------------------------------------------------

  /// The ground height under [at] (a downward trace ignoring the owner), or
  /// null.
  double? groundBelow(Vector3 at, {double up = 30.0, double down = 2000.0}) {
    final collision = world?.getSubsystem<LuminaCollisionSubsystem>();
    final o = owner;
    if (collision == null || o == null) return null;
    final hit = HitResult();
    final ok = collision.lineTraceSingle(
        start: at + Vector3(0, up, 0), end: at - Vector3(0, down, 0), out: hit, ignoreActors: [o]);
    return ok ? hit.impactPoint.y : null;
  }

  /// Moves the owner so its mesh's origin lands at [meshOrigin] turned by
  /// [meshRotation] (a yaw), through the mesh's transform under the root.
  void placeMesh(Vector3 meshOrigin, Quaternion meshRotation) {
    final o = owner, m = mesh;
    if (o == null || m == null) return;
    // The mesh's transform relative to the root component.
    var rel = Quaternion.identity();
    var relPos = Vector3.zero();
    for (LuminaSceneComponent? c = m; c != null && !identical(c, o.rootComponent); c = c.parentComponent) {
      rel = c.relativeRotation * rel;
      relPos = c.relativeLocation + (relPos.clone()..applyQuaternion(c.relativeRotation));
    }
    final rootRotation = (meshRotation * rel.conjugated())..normalize();
    o.actorRotation = rootRotation;
    o.actorLocation = meshOrigin - (relPos.clone()..applyQuaternion(rootRotation));
  }

  /// The mesh's render-transform yaw (radians about +Y) now.
  double get meshYaw {
    final m = mesh;
    if (m == null) return 0.0;
    final f = Vector3(0, 0, 1)..applyQuaternion(m.worldRotation);
    return math.atan2(f.x, f.z);
  }

  /// Every body's collision component of the running ragdoll.
  List<LuminaCollisionComponent> get bodyComponents => [for (final b in _ragdoll?.bodies ?? const <LuminaRagdollBody>[]) b.component];
}
