import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/animation/motion_matching/motion_matching_component.dart';
import 'package:lumina/src/animation/motion_matching/motion_matching_player.dart';
import 'package:lumina/src/animation/motion_matching/pose_search_database_runtime.dart';
import 'package:lumina/src/animation/root_motion/motion_warping.dart';
import 'package:lumina/src/animation/root_motion/root_motion_montage_player.dart';
import 'package:lumina/src/blueprint/anim/anim_blueprint_instance.dart';
import 'package:lumina/src/collision/collision_subsystem.dart';
import 'package:lumina/src/components/base/actor_component.dart';
import 'package:lumina/src/components/collision/capsule_component.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/components/movement/character_movement_component.dart';
import 'package:lumina/src/components/movement/traversal/traversal_check.dart';
import 'package:lumina/src/components/movement/traversal/traversal_chooser.dart';
import 'package:lumina/src/world/debug_shapes.dart';

/// Hurdles, vaults and mantles for a character: [tryTraversalAction] checks
/// the obstacle ahead ([LuminaTraversalCheck]), picks one of [animations]
/// ([LuminaTraversalChooser]) and plays it with root motion warped onto the
/// measured ledges and floor ([LuminaRootMotionMontagePlayer]) — in the
/// Animation Blueprint's default slot when the mesh has one, else driving
/// the mesh itself. While it plays the movement component is parked in
/// [MovementMode.custom] ([customMovementMode]); afterwards it walks (or
/// falls) on with the clip's exit velocity.
///
/// The clips are sampled from the mesh's own GLB (shared with its motion
/// matching databases), so every row's clip must be in the mesh.
class LuminaTraversalComponent extends LuminaActorComponent {
  /// The chooser rows.
  List<LuminaTraversalAnimation> animations;
  bool enabled;

  /// The custom movement mode index set while an action plays.
  int customMovementMode;

  /// The root bone of the mesh ('' finds it) and the yaw from the mesh's
  /// authored forward to glTF +Z, when there is no motion matching database
  /// to take them from.
  String rootBone;
  double? meshYawOffsetDegrees;

  /// Draws the measured ledges and floor for a second after each check.
  bool debugDraw;

  /// The traces' tunables (the capsule is filled in from the owner's).
  double minLedgeHeight;
  double maxLedgeHeight;
  double minTraceDistance;
  double maxTraceDistance;

  /// The mesh to animate (the Animation Blueprint's or the owner's first
  /// animated mesh when null).
  LuminaAnimatedMeshComponent? mesh;

  /// Called when an action ends: its type, and whether it was interrupted.
  void Function(LuminaTraversalActionType action, bool interrupted)? onTraversalFinished;

  LuminaTraversalComponent({
    super.key,
    this.animations = const [],
    this.enabled = true,
    this.customMovementMode = 1,
    this.rootBone = '',
    this.meshYawOffsetDegrees,
    this.debugDraw = false,
    this.minLedgeHeight = 50.0,
    this.maxLedgeHeight = 275.0,
    this.minTraceDistance = 75.0,
    this.maxTraceDistance = 350.0,
  });

  /// From a Blueprint component's properties: `animations` (rows as JSON),
  /// `enabled`, `rootBone`, `meshYawOffsetDegrees`, `debugDraw`,
  /// `minLedgeHeight`, `maxLedgeHeight`, `minTraceDistance`,
  /// `maxTraceDistance`, `customMovementMode`.
  factory LuminaTraversalComponent.fromProperties(Map<String, dynamic> p) {
    double? n(String k) => p[k] is num ? (p[k] as num).toDouble() : null;
    return LuminaTraversalComponent(
      animations: [
        for (final a in (p['animations'] as List?) ?? const [])
          if (a is Map) LuminaTraversalAnimation.fromJson(Map<String, dynamic>.from(a)),
      ],
      enabled: p['enabled'] as bool? ?? true,
      customMovementMode: (p['customMovementMode'] as num?)?.toInt() ?? 1,
      rootBone: p['rootBone'] as String? ?? '',
      meshYawOffsetDegrees: n('meshYawOffsetDegrees'),
      debugDraw: p['debugDraw'] as bool? ?? false,
      minLedgeHeight: n('minLedgeHeight') ?? 50.0,
      maxLedgeHeight: n('maxLedgeHeight') ?? 275.0,
      minTraceDistance: n('minTraceDistance') ?? 75.0,
      maxTraceDistance: n('maxTraceDistance') ?? 350.0,
    );
  }

  LuminaTraversalCheckResult? _lastCheck;
  LuminaTraversalChoice? _lastChoice;
  LuminaRootMotionMontagePlayer? _player;
  LuminaPoseSearchRig? _rig;
  Future<LuminaPoseSearchRig?>? _loading;
  int _actions = 0;

  /// The last check, and the clip the last action played.
  LuminaTraversalCheckResult? get lastCheck => _lastCheck;
  LuminaTraversalChoice? get lastChoice => _lastChoice;

  /// The action playing now, if any.
  LuminaRootMotionMontagePlayer? get player => _player;
  bool get isTraversing => _player != null;

  /// The type of the action playing (none when idle).
  LuminaTraversalActionType get currentAction =>
      _player == null ? LuminaTraversalActionType.none : _lastChoice?.animation.action ?? LuminaTraversalActionType.none;

  /// Actions started so far.
  int get actionCount => _actions;

  LuminaCharacterMovementComponent? get _movement => owner?.getComponent<LuminaCharacterMovementComponent>();

  LuminaCapsuleComponent? get _capsule {
    final m = _movement?.updatedComponent;
    return m ?? owner?.getComponent<LuminaCapsuleComponent>();
  }

  LuminaAnimBlueprintInstance? get _anim {
    for (final c in owner?.components ?? const []) {
      if (c is LuminaAnimBlueprintInstance && (mesh == null || identical(c.mesh, mesh))) return c;
    }
    return null;
  }

  LuminaAnimatedMeshComponent? get _mesh => mesh ?? _anim?.mesh ?? owner?.getComponent<LuminaAnimatedMeshComponent>();

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    if (animations.isNotEmpty) unawaited(ensureLoaded());
  }

  /// The mesh's clips on the CPU, ready for actions: the motion matching
  /// database's when one plays, else loaded once from the mesh asset.
  Future<LuminaPoseSearchRig?> ensureLoaded() {
    final ready = _rigNow();
    if (ready != null) return Future.value(ready);
    final target = _mesh;
    if (target == null || target.meshAssetPath.isEmpty) return Future.value(null);
    return _loading ??= _load(target.meshAssetPath);
  }

  Future<LuminaPoseSearchRig?> _load(String meshAssetPath) async {
    try {
      final sampler = await LuminaPoseSearchDatabaseRuntime.meshSampler(meshAssetPath);
      final yaw = meshYawOffsetDegrees ?? _anim?.meshYawOffsetDegrees ?? 0.0;
      return _rig = LuminaPoseSearchRig(sampler, LuminaPoseSearchSchema(rootBone: rootBone, meshYawOffsetDegrees: yaw));
    } catch (e) {
      developer.log('Traversal: cannot read the clips of $meshAssetPath: $e', name: 'LuminaTraversal', level: 900);
      _loading = null;
      return null;
    }
  }

  /// Uses [rig]'s sampler for the clips instead of the mesh's (a rig built
  /// in code, or one shared with another system).
  void useRig(LuminaPoseSearchRig rig) => _explicitRig = rig;

  LuminaPoseSearchRig? _explicitRig;

  /// World units per model unit when there is no mesh to read the scale
  /// from (glTF metres to centimetres).
  double fallbackWorldUnitsPerModelUnit = 100.0;

  LuminaMotionMatchingPlayer? get _motionMatching {
    final anim = _anim;
    if (anim != null) return anim.motionMatching.player;
    for (final c in owner?.components ?? const []) {
      if (c is LuminaMotionMatchingComponent) return c.player;
    }
    return null;
  }

  LuminaPoseSearchRig? _rigNow() {
    final explicit = _explicitRig;
    if (explicit != null) return explicit;
    final mm = _motionMatching?.database.rig;
    if (mm == null) return _rig;
    // The motion matching database's clips, with this component's root bone
    // when it names one.
    if (rootBone.isEmpty || mm.schema.rootBone == rootBone) return mm;
    final cached = _sharedRig;
    if (cached != null && identical(cached.sampler, mm.sampler)) return cached;
    return _sharedRig = LuminaPoseSearchRig(mm.sampler, mm.schema.copyWith(rootBone: rootBone));
  }

  LuminaPoseSearchRig? _sharedRig;

  /// Measures the obstacle ahead of the owner (along its facing, at its
  /// horizontal speed) without acting.
  LuminaTraversalCheckResult checkTraversal() {
    final actor = owner;
    final capsule = _capsule;
    final collision = actor?.world?.subsystems.getSubsystem<LuminaCollisionSubsystem>();
    if (actor == null || capsule == null || collision == null) {
      return _lastCheck = LuminaTraversalCheckResult()..reason = 'no capsule or collision';
    }
    final yaw = LuminaMotionMatchingCharacter.facingYaw(actor);
    final v = _movement?.velocity ?? Vector3.zero();
    final check = LuminaTraversalCheck(capsuleRadius: capsule.radius, capsuleHalfHeight: capsule.halfHeight)
      ..minLedgeHeight = minLedgeHeight
      ..maxLedgeHeight = maxLedgeHeight
      ..minTraceDistance = minTraceDistance
      ..maxTraceDistance = maxTraceDistance;
    final result = check.run(
      collision,
      location: capsule.worldLocation.clone(),
      forward: Vector3(math.sin(yaw), 0.0, math.cos(yaw)),
      speed: math.sqrt(v.x * v.x + v.z * v.z),
      ignore: capsule,
    );
    if (debugDraw) _draw(result);
    return _lastCheck = result;
  }

  /// Checks the obstacle ahead and, when an action and a clip fit it, plays
  /// it; false (nothing changes) otherwise — a Blueprint then jumps.
  bool tryTraversalAction() {
    if (!enabled || isTraversing || animations.isEmpty) return false;
    final movement = _movement;
    final actor = owner;
    final capsule = _capsule;
    if (actor == null || capsule == null || movement == null || !movement.isWalking) return false;
    final rig = _rigNow();
    if (rig == null) {
      unawaited(ensureLoaded());
      return false;
    }
    final check = checkTraversal();
    if (check.actionType == LuminaTraversalActionType.none) return false;
    final mm = _motionMatching;
    final current = mm != null && identical(mm.database.sampler, rig.sampler) ? mm.pose : null;
    final bones = [for (final b in rig.schema.bones) if (b.position > 0) b.name];
    final choice = LuminaTraversalChooser.choose(animations, check, rig,
        currentPose: current, bones: bones.isEmpty ? const ['foot_l', 'foot_r'] : bones);
    if (choice == null) {
      check.reason = 'no clip for ${check.actionType.label}';
      return false;
    }
    final target = _mesh;
    final scale = target == null ? fallbackWorldUnitsPerModelUnit : target.assetUnitScale * target.relativeScale.x.abs();
    final yaw = check.facingYaw;
    final targets = <String, LuminaWarpTarget>{
      'FrontLedge': LuminaWarpTarget(check.frontLedge, yaw),
      if (check.hasBackLedge) 'BackLedge': LuminaWarpTarget(check.backLedge, yaw),
      if (check.hasBackFloor) 'BackFloor': LuminaWarpTarget(check.backFloor, yaw),
    };
    final player = LuminaRootMotionMontagePlayer(
      rig: rig,
      clip: choice.clip,
      montage: choice.animation.montage(startTime: choice.startTime),
      worldUnitsPerModelUnit: scale,
      targets: targets,
      owner: actor,
      feetOffset: capsule.halfHeight,
      wantsBlendOut: () => movement.lastInputVector.length2 > 1e-4,
      onEnded: _ended,
    );
    _lastChoice = choice;
    _player = player;
    _actions++;
    movement.stopMovementImmediately();
    movement.setMovementMode(MovementMode.custom, customModeIndex: customMovementMode);
    final anim = _anim;
    if (anim != null && target != null && identical(anim.mesh, target)) {
      anim.playSlot(player);
    } else {
      _selfDriven = target;
      _previousDriver = target?.poseDriver;
      player.begin(
          fromPose: current, fromVelocity: current == null ? null : mm!.poseVelocity, fromNodes: rig.sampler.nodeNames);
      target?.poseDriver = player;
    }
    return true;
  }

  LuminaAnimatedMeshComponent? _selfDriven;
  Object? _previousDriver;

  /// Stops the action playing now (interrupted).
  void stopTraversal() {
    final p = _player;
    if (p == null) return;
    final anim = _anim;
    if (_selfDriven == null && anim != null && identical(anim.slotPlayer, p)) {
      anim.stopSlot();
    } else {
      _finishSelfDriven(p, interrupted: true);
    }
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    final p = _player;
    if (p == null || _selfDriven == null && _anim != null) return;
    if (!p.advance(deltaTime)) _finishSelfDriven(p, interrupted: false);
  }

  void _finishSelfDriven(LuminaRootMotionMontagePlayer p, {required bool interrupted}) {
    final target = _selfDriven;
    _selfDriven = null;
    final mm = _motionMatching;
    if (target != null && target.poseDriver == p) {
      if (mm != null && identical(_previousDriver, mm)) {
        mm.blendFrom(p.pose, p.poseVelocity);
        target.poseDriver = mm;
      } else {
        target.poseDriver = null;
      }
    }
    _previousDriver = null;
    p.end(interrupted: interrupted);
  }

  void _ended(LuminaRootMotionMontagePlayer p, bool interrupted) {
    if (!identical(_player, p)) return;
    _player = null;
    final movement = _movement;
    if (movement != null) {
      movement.setMovementMode(MovementMode.walking);
      final v = p.rootVelocity;
      final horizontal = Vector3(v.x, 0.0, v.z);
      final cap = movement.effectiveMaxWalkSpeed;
      if (horizontal.length > cap && cap > 0) horizontal.scale(cap / horizontal.length);
      movement.velocity.setValues(horizontal.x, movement.isFalling ? math.min(0.0, v.y) : 0.0, horizontal.z);
    }
    onTraversalFinished?.call(_lastChoice?.animation.action ?? LuminaTraversalActionType.none, interrupted);
  }

  void _draw(LuminaTraversalCheckResult r) {
    final world = owner?.world;
    if (world == null) return;
    final until = world.realTimeSeconds + 1.0;
    void point(Vector3 p, List<double> color) => world.addDebugShape(
        LuminaDebugShape(kind: LuminaDebugShapeKind.point, points: [p.clone()], radius: 8.0, color: color, expiresAt: until));
    if (r.hasFrontLedge) point(r.frontLedge, const [0.2, 1.0, 0.3, 1.0]);
    if (r.hasBackLedge) point(r.backLedge, const [0.2, 0.6, 1.0, 1.0]);
    if (r.hasBackFloor) point(r.backFloor, const [1.0, 0.6, 0.1, 1.0]);
  }
}
