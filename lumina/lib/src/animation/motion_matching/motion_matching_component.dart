import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/animation/motion_matching/motion_matching_player.dart';
import 'package:lumina/src/animation/motion_matching/pose_search_database_runtime.dart';
import 'package:lumina/src/animation/motion_matching/trajectory_predictor.dart';
import 'package:lumina/src/components/base/actor_component.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/components/movement/character_movement_component.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/world/debug_shapes.dart';

/// How a character feeds a motion matching player: the input from its
/// movement component, optionally turning the character toward its movement,
/// and debug lines of the desired and matched trajectories.
abstract final class LuminaMotionMatchingCharacter {
  static final Vector3 _up = Vector3(0.0, 1.0, 0.0);

  /// World yaw of [actor]'s facing: its forward vector (the drawn −Z).
  static double facingYaw(LuminaActor actor) {
    final f = actor.actorRotation.asRotationMatrix().transformed(Vector3(0.0, 0.0, -1.0));
    return luminaWorldYaw(f);
  }

  /// Turns [actor] to face world [yaw] (its −Z turned to the yaw's
  /// direction).
  static void setFacingYaw(LuminaActor actor, double yaw) =>
      actor.actorRotation = Quaternion.axisAngle(_up, yaw - math.pi);

  /// The movement component of [actor], if any.
  static LuminaCharacterMovementComponent? movementOf(LuminaActor actor) =>
      actor.components.whereType<LuminaCharacterMovementComponent>().firstOrNull;

  /// The input for [actor] this frame: its position and facing, its
  /// movement's velocity and last input (clamped to length 1) × its walk
  /// speed as the desired velocity; [desiredYaw] as given.
  static LuminaMotionMatchingInput inputFor(LuminaActor actor, LuminaAnimatedMeshComponent mesh, {double? desiredYaw}) {
    final movement = movementOf(actor);
    final velocity = movement == null ? Vector3.zero() : Vector3(movement.velocity.x, 0.0, movement.velocity.z);
    final desired = Vector3.zero();
    if (movement != null) {
      final input = Vector3(movement.lastInputVector.x, 0.0, movement.lastInputVector.z);
      if (input.length > 1.0) input.normalize();
      desired.setFrom(input * movement.effectiveMaxWalkSpeed);
    }
    final scale = mesh.assetUnitScale * mesh.relativeScale.x.abs();
    return LuminaMotionMatchingInput(
      position: actor.actorLocation.clone(),
      facingYaw: facingYaw(actor),
      velocity: velocity,
      desiredVelocity: desired,
      desiredYaw: desiredYaw,
      modelUnitsPerWorldUnit: scale > 1e-9 ? 1.0 / scale : 1.0,
    );
  }

  /// Turns [actor] toward its movement with the predictor's facing spring
  /// (what the prediction assumed), which keeps its own velocity from frame
  /// to frame (see [LuminaTrajectoryPredictor.turnFacing]).
  static void orientToMovement(LuminaActor actor, LuminaMotionMatchingPlayer player, LuminaMotionMatchingInput input, double dt) {
    final d = input.desiredVelocity;
    if (Vector3(d.x, 0, d.z).length < 1e-3) return;
    setFacingYaw(actor, player.predictor.turnFacing(input.facingYaw, luminaWorldYaw(d), dt));
  }

  /// Draws the desired (green) and matched (orange) trajectories for one
  /// frame.
  static void drawDebug(LuminaActor actor, LuminaMotionMatchingPlayer player) {
    final world = actor.world;
    if (world == null) return;
    final now = world.realTimeSeconds;
    void path(List<Vector3> points, List<double> color, double lift) {
      for (var i = 0; i + 1 < points.length; i++) {
        world.addDebugShape(LuminaDebugShape(
          kind: LuminaDebugShapeKind.line,
          points: [points[i] + Vector3(0, lift, 0), points[i + 1] + Vector3(0, lift, 0)],
          color: color,
          thickness: 2.0,
          expiresAt: now,
        ));
      }
      for (final p in points) {
        world.addDebugShape(LuminaDebugShape(
            kind: LuminaDebugShapeKind.point, points: [p + Vector3(0, lift, 0)], radius: 6.0, color: color, expiresAt: now));
      }
    }

    path(player.desiredTrajectory, const [0.2, 1.0, 0.3, 1.0], 2.0);
    path(player.matchedTrajectory, const [1.0, 0.6, 0.1, 1.0], 4.0);
  }
}

/// Animates its owner's [LuminaAnimatedMeshComponent] by motion matching
/// over the pose search database at [databasePath] (or a ready [runtime]),
/// steered by the owner's [LuminaCharacterMovementComponent]: the capsule
/// moves the character, the matched frames follow it.
class LuminaMotionMatchingComponent extends LuminaActorComponent {
  final String databasePath;
  LuminaPoseSearchDatabaseRuntime? runtime;

  /// The mesh to drive (the owner's first animated mesh when null).
  LuminaAnimatedMeshComponent? mesh;

  double? blendTime;
  double poseWeight;
  double trajectoryWeight;
  Set<String> requiredTags;

  /// Turn the owner toward its movement (for pawns that do not turn with
  /// the controller).
  bool orientToMovement;

  /// The facing to turn to when not orienting to movement (null: keep).
  double? Function()? desiredYaw;

  bool debugDraw;

  /// Yaw from the mesh's authored forward to glTF +Z, as an Animation
  /// Blueprint's (the mesh is turned to face the owner's −Z).
  double meshYawOffsetDegrees;

  LuminaMotionMatchingPlayer? _player;
  final Completer<LuminaMotionMatchingPlayer> _ready = Completer();

  LuminaMotionMatchingComponent({
    super.key,
    this.databasePath = '',
    this.runtime,
    this.mesh,
    this.blendTime,
    this.poseWeight = 1.0,
    this.trajectoryWeight = 1.0,
    this.requiredTags = const {},
    this.orientToMovement = false,
    this.desiredYaw,
    this.debugDraw = false,
    this.meshYawOffsetDegrees = 0.0,
  });

  /// The player, once the database is loaded.
  LuminaMotionMatchingPlayer? get player => _player;

  /// Completes when the database is loaded and the player drives the mesh.
  Future<LuminaMotionMatchingPlayer> get ready => _ready.future;

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    mesh ??= owner?.components.whereType<LuminaAnimatedMeshComponent>().firstOrNull;
    final ready = runtime;
    if (ready != null) {
      _start(ready);
    } else if (databasePath.isNotEmpty) {
      LuminaPoseSearchDatabaseRuntime.load(databasePath).then(_start, onError: (Object e, StackTrace st) {
        developer.log('Motion matching: cannot load $databasePath: $e', name: 'LuminaMotionMatching', level: 900);
        if (!_ready.isCompleted) _ready.completeError(e, st);
      });
    }
  }

  void _start(LuminaPoseSearchDatabaseRuntime db) {
    runtime = db;
    final player = LuminaMotionMatchingPlayer(db, blendTime: blendTime, poseWeight: poseWeight, trajectoryWeight: trajectoryWeight)
      ..requiredTags = requiredTags;
    _player = player;
    mesh?.poseDriver = player;
    if (!_ready.isCompleted) _ready.complete(player);
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    final player = _player;
    final actor = owner;
    final target = mesh;
    if (player == null || actor == null || target == null) return;
    target.relativeRotation = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi + meshYawOffsetDegrees * math.pi / 180.0);
    final input = LuminaMotionMatchingCharacter.inputFor(actor, target, desiredYaw: desiredYaw?.call());
    player.requiredTags = requiredTags;
    player.input = input;
    if (orientToMovement) LuminaMotionMatchingCharacter.orientToMovement(actor, player, input, deltaTime);
    if (debugDraw) LuminaMotionMatchingCharacter.drawDebug(actor, player);
  }

  @override
  void onUnregister() {
    if (mesh?.poseDriver == _player) mesh?.poseDriver = null;
    super.onUnregister();
  }
}
