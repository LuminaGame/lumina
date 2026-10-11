part of 'pose_authoring_component.dart';

/// One frame of [LuminaPoseAuthoringComponent]: picks the incoming pose,
/// resolves the handle targets into the model frame, runs the solvers in
/// order and writes the result back into [pose].
bool _solve(LuminaPoseAuthoringComponent c, Float64List pose, Matrix4 meshTransform, double deltaTime) {
  final rig = c._rig, state = c._state;
  if (rig == null || state == null || pose.length != rig.length * 10) return false;
  final watch = Stopwatch()..start();
  c._meshTransform.setFrom(meshTransform);
  final n = rig.length;

  // The incoming pose. A node the mesh cannot address reads as zeros (the
  // rest pose stands in); a node still holding what the last frame wrote
  // was not animated since, so the pose from before that write is its base.
  final base = c._base ??= Float64List.fromList(rig.restPose);
  final written = c._written;
  for (var i = 0; i < n; i++) {
    final o = i * 10;
    if (pose[o + 3] == 0 && pose[o + 4] == 0 && pose[o + 5] == 0 && pose[o + 6] == 0) {
      base.setRange(o, o + 10, rig.restPose, o);
      continue;
    }
    if (written != null && _sameSlot(pose, written, o)) continue;
    base.setRange(o, o + 10, pose, o);
  }

  final work = Float64List.fromList(c._held ?? base);
  final applied = c._applied, mask = c._appliedMask;
  if (applied != null && mask != null) {
    c._appliedAlpha = c._appliedRate <= 0 ? 1.0 : (c._appliedAlpha + deltaTime * c._appliedRate).clamp(0.0, 1.0);
    final from = c._blendFrom ?? base;
    for (var i = 0; i < n; i++) {
      if (mask[i] == 0) continue;
      _blendSlot(from, applied, c._appliedAlpha, work, i * 10);
    }
    if (c._appliedAlpha >= 1.0) c._blendFrom = null;
  }

  final handles = c._handles;
  final active = handles.values.any((h) => h.hasTarget);
  if (!active && applied == null && c._held == null && written == null) {
    state.load(work);
    c._solvedOnce = true;
    c.lastSolveMicros = watch.elapsedMicroseconds;
    return false;
  }

  // Targets set in world units enter the model frame of this frame.
  if (handles.values.any((h) => h.pendingWorldTarget != null)) {
    final inverse = Matrix4.inverted(meshTransform);
    final meshRotation = Quaternion.identity();
    meshTransform.decompose(Vector3.zero(), meshRotation, Vector3.zero());
    final toModel = LuminaPoseQuat.qConj(meshRotation..normalize());
    for (final h in handles.values) {
      final target = h.pendingWorldTarget;
      if (target == null) continue;
      h.modelTarget = inverse.transformed3(target.clone());
      final r = h.pendingWorldRotation;
      h.modelRotation = r == null ? null : (LuminaPoseQuat.qMul(toModel, r)..normalize());
      h.pendingWorldTarget = null;
      h.pendingWorldRotation = null;
    }
  }

  state.load(work);
  if (active) {
    Vector3? at(String name) => handles[name]?.modelTarget;
    Quaternion? turn(String name) => handles[name]?.modelRotation;
    LuminaPoseSolvers.pelvis(state, position: at('pelvis'), rotation: turn('pelvis'));
    final chest = at('chest');
    if (chest != null) LuminaPoseSolvers.spine(state, chest);
    LuminaPoseSolvers.head(state, target: at('head'), rotation: turn('head'));
    for (final (limb, end, pole) in const [
      ('arm_l', 'hand_l', 'elbow_l'),
      ('arm_r', 'hand_r', 'elbow_r'),
      ('leg_l', 'foot_l', 'knee_l'),
      ('leg_r', 'foot_r', 'knee_r'),
    ]) {
      final l = rig.limbs[limb];
      if (l == null) continue;
      LuminaPoseSolvers.limb(state, l, (end: at(end), endRotation: turn(end), pole: at(pole)));
    }
    state.store(work);
  }

  if (c._weight < 1.0) {
    final solved = Float64List.fromList(work);
    for (var i = 0; i < n; i++) {
      _blendSlot(base, solved, c._weight, work, i * 10);
    }
    state.load(work);
  }
  pose.setAll(0, work);
  c._written = Float64List.fromList(work);
  if (c.captureMode == LuminaPoseCaptureMode.bakeToPose && (active || c._held != null || applied != null)) {
    c._held = Float64List.fromList(work);
    // The baked pose carries the applied one from now on.
    if (applied != null && c._appliedAlpha >= 1.0) {
      c._applied = null;
      c._appliedMask = null;
    }
  }
  c._solvedOnce = true;
  c.lastSolveMicros = watch.elapsedMicroseconds;
  return true;
}

/// Whether slot [o] of [a] and [b] match within float precision (the
/// transform manager keeps single-precision matrices).
bool _sameSlot(Float64List a, Float64List b, int o) {
  for (final k in const [0, 1, 2, 7, 8, 9]) {
    if ((a[o + k] - b[o + k]).abs() > 2e-5) return false;
  }
  // q and −q are the same rotation (a decomposed matrix picks its own sign).
  final dot = a[o + 3] * b[o + 3] + a[o + 4] * b[o + 4] + a[o + 5] * b[o + 5] + a[o + 6] * b[o + 6];
  return dot.abs() > 1 - 1e-8;
}

/// Slot [o] of [out]: [a] towards [b] by [t] (translation and scale lerp,
/// rotation slerp).
void _blendSlot(Float64List a, Float64List b, double t, Float64List out, int o) {
  for (final k in const [0, 1, 2, 7, 8, 9]) {
    out[o + k] = a[o + k] + (b[o + k] - a[o + k]) * t;
  }
  LuminaPoseMath.slerp(a, o + 3, b, o + 3, t, out, o + 3);
}
