import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/base/actor_component.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/components/movement/character_movement_component.dart';
import 'package:lumina/src/animation/locomotion_clip_set.dart';

/// Drives an animated character mesh from its owner's movement: idle when
/// still, one of eight walk cycles by the direction it moves relative to the
/// way it faces, played at a rate matched to its ground speed, and a held pose
/// while falling.
///
/// Add it to the character **before** [mesh], so each frame the clip is chosen
/// from this frame's velocity before the mesh applies it.
///
/// The component also turns [mesh] from its authored forward (glTF +Z, see
/// [meshYawOffsetDegrees]) to the actor's forward, −Z, with a constant
/// relative yaw; the mesh otherwise inherits the owner's rotation. The owner's
/// `forwardVector` is the drawn −Z, so the character
/// looks where it walks.
class LuminaDirectionalLocomotionComponent extends LuminaActorComponent {
  final LuminaAnimatedMeshComponent mesh;
  final LuminaLocomotionClipSet clips;

  /// Seconds a clip change blends over.
  double crossFadeDuration;

  /// Yaw, in degrees, from the mesh's authored forward to +Z. glTF assets face
  /// +Z, so 0 for them.
  double meshYawOffsetDegrees;

  /// What was selected on the last tick.
  LuminaLocomotionPose? lastPose;

  LuminaDirectionalLocomotionComponent({
    super.key,
    required this.mesh,
    required this.clips,
    this.crossFadeDuration = 0.2,
    this.meshYawOffsetDegrees = 0.0,
  });

  static final Vector3 _up = Vector3(0.0, 1.0, 0.0);

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    if (mesh.currentClip == null) {
      mesh.play(clips.idle);
    }
    _faceOwnerForward();
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    final actor = owner;
    if (actor == null) return;

    _faceOwnerForward();

    final movement = actor.getComponent<LuminaCharacterMovementComponent>();
    final pose = selectLocomotionPose(
      clips: clips,
      velocity: movement?.velocity ?? Vector3.zero(),
      facing: actor.rootComponent.forwardVector,
      isFalling: movement?.isFalling ?? false,
    );
    lastPose = pose;

    if (!pose.holdCurrent) {
      final target = pose.clip!;
      if (mesh.currentClip != target) {
        final bothWalks = clips.isCycleClip(mesh.currentClip) && clips.isCycleClip(target);
        mesh.crossFadeTo(target, duration: crossFadeDuration, syncPhase: bothWalks);
      }
    }
    mesh.playRate = pose.playRate;
  }

  /// Turns [mesh] from its authored forward to the owner's −Z. Its world
  /// rotation is then the owner's rotation times this constant turn.
  void _faceOwnerForward() {
    mesh.relativeRotation = Quaternion.axisAngle(_up, math.pi + meshYawOffsetDegrees * math.pi / 180.0);
  }
}
