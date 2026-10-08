part of 'ragdoll_component.dart';

/// A clip shown over the live animation: a get-up (with its placement and
/// root motion) or a heavy landing.
class _Overlay {
  final String clip;
  final int clipIndex;
  final double duration;
  final LuminaGetUpPlan? plan;
  final Float64List clipPose;
  LuminaGroundFrame start = (x: 0.0, z: 0.0, yaw: 0.0);
  double time = 0.0;

  _Overlay(this.clip, this.clipIndex, this.duration, this.plan, int length) : clipPose = Float64List(length * 10);

  bool get isGetUp => plan != null;
}

final Vector3 _up = Vector3(0, 1, 0);

bool _start(LuminaRagdollComponent c, Vector3? impulse, String? bone, Vector3? location) {
  final skeleton = c._skeleton, w = c.world, o = c.owner, m = c.mesh;
  if (skeleton == null || w == null || o == null || m == null || c._state != LuminaRagdollState.animated) return false;
  // Another system owns the capsule (a traversal action plays its root
  // motion in a custom mode): no ragdoll until it hands it back.
  final owned = c._movement;
  if (owned != null && owned.isCustom && owned.customMovementModeIndex != LuminaRagdollComponent.ragdollMovementMode) {
    return false;
  }
  final physics = LuminaPhysicsSubsystem.ensure(w);
  if (physics == null) return false;
  final affine = LuminaRagdollSkeleton.affineOf(m.renderTransform);
  final rest = c._poser!.frames(skeleton.restPose, affine);
  final start = c._animated ?? rest;
  final velocities = <String, (Vector3, Vector3)>{};
  final before = c._animatedBefore, dt = c._animatedDt;
  if (c._animated != null && before != null && dt > 1e-4) {
    for (final e in start.entries) {
      final b = before[e.key];
      if (b == null) continue;
      final v = (e.value.position - b.position)..scale(1 / dt);
      final dq = (e.value.rotation * b.rotation.conjugated())..normalize();
      if (dq.w < 0) dq.setValues(-dq.x, -dq.y, -dq.z, -dq.w);
      final s = math.sqrt(dq.x * dq.x + dq.y * dq.y + dq.z * dq.z);
      final angle = 2 * math.atan2(s, dq.w);
      final omega = s < 1e-9 ? Vector3.zero() : (Vector3(dq.x, dq.y, dq.z)..scale(angle / s / dt));
      // A teleport is not a velocity.
      if (v.length > 5000 || omega.length > 60) continue;
      velocities[e.key] = (v, omega);
    }
  }
  c._ragdoll = LuminaRagdoll.create(
      physics: physics, owner: o, asset: c.physicsAsset!, skeleton: skeleton, rest: rest, start: start, velocities: velocities);
  if (impulse != null) c._ragdoll!.addImpulse(impulse, bone: bone, location: location);
  final movement = c._movement;
  if (movement != null) {
    movement.setMovementMode(MovementMode.custom, customModeIndex: LuminaRagdollComponent.ragdollMovementMode);
    movement.velocity.setZero();
  }
  c._overlay = null;
  c._state = LuminaRagdollState.ragdoll;
  c.stateTime = 0.0;
  c._weight = c.blendInTime <= 0 ? c.blendWeight : 0.0;
  c._settledFor = 0.0;
  c.fallMonitor.reset();
  c.onRagdollStarted?.call();
  return true;
}

void _stop(LuminaRagdollComponent c, bool getUp) {
  final ragdoll = c._ragdoll;
  if (ragdoll == null) return;
  final frames = ragdoll.boneFrames();
  c._snapshot = frames;
  final pelvis = ragdoll.root.boneFrame();
  ragdoll.destroy();
  c._ragdoll = null;
  final ground = c.groundBelow(pelvis.position) ?? pelvis.position.y - 15.0;
  final helper = getUp && c.getUpClips.isNotEmpty ? c._getUpHelper() : null;
  final plan = helper?.plan(frames, c.getUpClips, ground);
  if (helper != null && plan != null) {
    final overlay = _Overlay(plan.clip, plan.clipIndex, helper.duration(plan.clipIndex), plan, helper.skeleton.length);
    overlay.start = helper.sample(plan.clipIndex, 0.0, overlay.clipPose);
    c._overlay = overlay;
    c.placeMesh(plan.origin, Quaternion.axisAngle(_up, plan.yaw));
    c._state = LuminaRagdollState.gettingUp;
    c.stateTime = 0.0;
    c.onGetUpStarted?.call(plan.clip);
    return;
  }
  c.placeMesh(Vector3(pelvis.position.x, ground, pelvis.position.z), Quaternion.axisAngle(_up, c.meshYaw));
  c._movement?.setMovementMode(MovementMode.walking);
  c._state = LuminaRagdollState.blendingOut;
  c.stateTime = 0.0;
}

bool _playLanding(LuminaRagdollComponent c, String clip) {
  if (clip.isEmpty || c._state != LuminaRagdollState.animated || c._overlay != null) return false;
  final helper = c._getUpHelper();
  final index = c.sampler?.clipIndex(clip);
  if (helper == null || index == null) return false;
  c._overlay = _Overlay(clip, index, helper.duration(index), null, helper.skeleton.length);
  return true;
}

/// Blends a ragdoll (or its last pose, blending out) into [pose].
bool _applyPhysicsPose(LuminaRagdollComponent c, Float64List pose, double deltaTime) {
  switch (c._state) {
    case LuminaRagdollState.ragdoll:
      final targets = c._ragdoll!.boneFrames();
      c._snapshot = targets;
      c._poser!.apply(pose, c._meshAffine, targets, c._weight);
      return true;
    case LuminaRagdollState.blendingOut:
      final w = c.blendOutTime <= 0 ? 0.0 : (1.0 - c.stateTime / c.blendOutTime).clamp(0.0, 1.0);
      c._poser!.apply(pose, c._meshAffine, c._snapshot, w * c._weight);
      return w > 0;
    case LuminaRagdollState.animated:
    case LuminaRagdollState.gettingUp:
      return false;
  }
}

/// Shows an overlay clip: a get-up placed under the ragdoll and carried by
/// its root motion, blending in from the ragdoll's last pose; a heavy
/// landing blending in and out over the live animation.
bool _applyOverlay(LuminaRagdollComponent c, _Overlay o, Float64List pose, double deltaTime) {
  final helper = c._getUp!;
  o.time += deltaTime;
  final t = math.min(o.time, o.duration);
  final g = helper.sample(o.clipIndex, t, o.clipPose);
  double weight;
  if (o.isGetUp) {
    final w = helper.meshTransformAt(o.plan!, o.start, g);
    final forward = w.getRotation().transformed(Vector3(0, 0, 1));
    c.placeMesh(w.getTranslation(), Quaternion.axisAngle(_up, math.atan2(forward.x, forward.z)));
    final fromRagdoll = c.getUpBlendIn <= 0 ? 0.0 : 1.0 - t / c.getUpBlendIn;
    if (fromRagdoll > 0) c._fullPoser!.apply(o.clipPose, LuminaRagdollSkeleton.affineOf(w), c._snapshot, fromRagdoll * c._weight);
    weight = c.getUpBlendOut <= 0 ? 1.0 : ((o.duration - t) / c.getUpBlendOut).clamp(0.0, 1.0);
  } else {
    final b = c.hardLandingBlend;
    weight = b <= 0 ? 1.0 : math.min(1.0, math.min(t / b, (o.duration - t) / b)).clamp(0.0, 1.0);
  }
  _mix(pose, o.clipPose, weight);
  if (o.time >= o.duration) {
    c._overlay = null;
    if (o.isGetUp) {
      c._movement?.setMovementMode(MovementMode.walking);
      c._state = LuminaRagdollState.animated;
      c.stateTime = 0.0;
      c._animated = null;
      c._animatedBefore = null;
      c.onRagdollEnded?.call();
    }
  }
  return true;
}

final Float64List _qa = Float64List(4), _qb = Float64List(4);

/// `pose = mix(pose, clip, weight)` per node (lerp, slerp).
void _mix(Float64List pose, Float64List clip, double weight) {
  if (weight >= 1.0) {
    pose.setAll(0, clip);
    return;
  }
  if (weight <= 0.0) return;
  for (var o = 0; o < pose.length; o += 10) {
    for (final k in const [0, 1, 2, 7, 8, 9]) {
      pose[o + k] += (clip[o + k] - pose[o + k]) * weight;
    }
    _qa.setRange(0, 4, pose, o + 3);
    _qb.setRange(0, 4, clip, o + 3);
    LuminaPoseMath.slerp(_qa, 0, _qb, 0, weight, pose, o + 3);
  }
}

void _tick(LuminaRagdollComponent c, double dt) {
  c.stateTime += dt;
  final movement = c._movement;
  switch (c._state) {
    case LuminaRagdollState.animated:
      if (!c.autoRagdollOnFall || movement == null || !c.isReady || c._overlay != null) return;
      final outcome = c.fallMonitor.update(falling: movement.isFalling, verticalVelocity: movement.velocity.y);
      if (outcome == LuminaFallOutcome.ragdoll) {
        c.startRagdoll();
      } else if (outcome == LuminaFallOutcome.hardLanding) {
        c.onHardLanding?.call(c.fallMonitor.lastImpactSpeed);
        c.playHardLanding();
      }
    case LuminaRagdollState.ragdoll:
      final ragdoll = c._ragdoll!;
      c._weight = c.blendInTime <= 0 ? c.blendWeight : math.min(c.blendWeight, c._weight + dt / c.blendInTime * c.blendWeight);
      final pelvis = ragdoll.root.boneFrame();
      final ground = c.groundBelow(pelvis.position);
      // The capsule (and the camera) follow the pelvis on the ground.
      c.placeMesh(Vector3(pelvis.position.x, ground ?? pelvis.position.y - 20.0, pelvis.position.z),
          Quaternion.axisAngle(_up, c.meshYaw));
      _drive(c, ragdoll, inAir: ground == null || pelvis.position.y - ground > 60.0);
      // Coming to rest: once the whole body barely moves, damp the last
      // wobble of limbs held against their limits so it lies still.
      final comSpeed = ragdoll.centerOfMassSpeed;
      final resting = c.stateTime > 0.3 && comSpeed < c.settleSpeed * 3;
      if (resting) {
        ragdoll.setDamping(linear: 3.0, angular: 6.0);
      } else {
        ragdoll.setDamping();
      }
      if (resting && comSpeed < c.settleSpeed && ragdoll.maxSpeed < c.settleSpeed * 4) {
        c._settledFor += dt;
      } else {
        c._settledFor = 0.0;
      }
      if (c._settledFor >= c.settleTime) {
        for (final b in ragdoll.bodies) {
          b.body.sleep();
        }
        if (c.autoGetUp) c.stopRagdoll();
      } else if (c.autoGetUp && c.stateTime >= c.maxRagdollTime) {
        c.stopRagdoll();
      }
    case LuminaRagdollState.blendingOut:
      if (c.stateTime >= c.blendOutTime) {
        c._state = LuminaRagdollState.animated;
        c.stateTime = 0.0;
        c._animated = null;
        c._animatedBefore = null;
        c.onRagdollEnded?.call();
      }
    case LuminaRagdollState.gettingUp:
      break;
  }
}

/// Powers the joints: toward the flail clip while falling, toward the
/// animation when [LuminaRagdollComponent.powered], else limp.
void _drive(LuminaRagdollComponent c, LuminaRagdoll ragdoll, {required bool inAir}) {
  if (inAir && c.flailClip.isNotEmpty) {
    final helper = c._getUpHelper();
    final index = c.sampler?.clipIndex(c.flailClip);
    if (helper != null && index != null) {
      final d = helper.duration(index);
      final pose = Float64List(helper.skeleton.length * 10);
      helper.sample(index, d > 0 ? c.stateTime % d : 0.0, pose);
      final frames = c._fullPoser!.frames(pose, LuminaRagdollSkeleton.affineOf(Matrix4.identity()));
      ragdoll.driveToward(frames, maxTorque: c.flailStrength, rate: c.motorRate);
      return;
    }
  }
  final animated = c._animated;
  if (c.powered && animated != null) {
    ragdoll.driveToward(animated, maxTorque: c.motorStrength, rate: c.motorRate);
  } else {
    ragdoll.driveToward(const {}, maxTorque: 0);
  }
}
