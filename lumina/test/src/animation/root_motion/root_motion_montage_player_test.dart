import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_core/testing.dart';
import 'package:vector_math/vector_math_64.dart';

/// Root-motion montages on a synthetic rig: a clip whose root rises 1 m and
/// moves 2 m forward in 1 s.
void main() {
  late LuminaPoseSearchRig rig;

  setUpAll(() {
    final glb = LuminaSyntheticLocomotionRig.build([
      LuminaSyntheticLocomotionRig.idle('Idle'),
      LuminaSyntheticClip('Climb', 1.0, (t) => (x: 0.0, z: 2.0 * t, yaw: 0.0), height: (t) => 1.0 * t),
    ], fps: 60);
    rig = LuminaPoseSearchRig(LuminaGlbAnimationSampler.fromGlb(glb), const LuminaPoseSearchSchema());
  });

  int clip(String name) => rig.sampler.clipIndex(name)!;

  test('the track reports the root motion in the root frame, in world units', () {
    final track = LuminaRootMotionTrack(rig, clip('Climb'), worldUnitsPerModelUnit: 100);
    final d = track.delta(0.25, 0.75);
    expect(d.z, closeTo(100, 1e-6));
    expect(d.y, closeTo(50, 1e-6));
    expect(d.x, closeTo(0, 1e-9));
    expect(track.velocityAt(0.5).z, closeTo(200, 1e-3));
    final hand = track.boneOffset(rig.sampler.indexOfNode('hand_l'), 0.5)!;
    expect(hand.y, closeTo(140, 1e-6));
  });

  test('the owner follows the root motion along its facing while the pose keeps the root at the origin', () {
    final actor = LuminaActor(location: Vector3(0, 90, 0));
    final player = LuminaRootMotionMontagePlayer(
      rig: rig,
      clip: clip('Climb'),
      montage: const LuminaRootMotionMontage(clip: 'Climb'),
      owner: actor,
      feetOffset: 90,
    )..begin();
    var steps = 0;
    while (player.advance(1 / 60)) {
      steps++;
      final o = rig.root * LuminaPoseMath.trsStride;
      expect(player.pose[o].abs() + player.pose[o + 1].abs() + player.pose[o + 2].abs(), lessThan(1e-4),
          reason: 'root motion removed at step $steps');
    }
    expect(steps, inInclusiveRange(58, 60));
    // The actor faces −Z: forward is −Z.
    expect(actor.actorLocation.z, closeTo(-200, 1e-3));
    expect(actor.actorLocation.y, closeTo(190, 1e-3));
    expect(actor.actorLocation.x, closeTo(0, 1e-6));
    expect(player.rootVelocity.z, closeTo(-200, 0.5));
  });

  test('a warp window puts the root on the measured target at the window end', () {
    final actor = LuminaActor(location: Vector3(0, 90, 0));
    final player = LuminaRootMotionMontagePlayer(
      rig: rig,
      clip: clip('Climb'),
      montage: const LuminaRootMotionMontage(clip: 'Climb', windows: [LuminaWarpWindow(target: 'Ledge', start: 0.0, end: 0.5)]),
      owner: actor,
      feetOffset: 90,
      targets: {'Ledge': LuminaWarpTarget(Vector3(0, 70, -150), math.pi)},
    )..begin();
    for (var i = 0; i < 30; i++) {
      player.advance(1 / 60);
    }
    expect(player.time, closeTo(0.5, 1e-9));
    expect(player.rootLocation.distanceTo(Vector3(0, 70, -150)), lessThan(1e-6));
    expect(actor.actorLocation.y, closeTo(160, 1e-6));
  });

  test('a warp point bone resolves to its offset from the root at the window end', () {
    final player = LuminaRootMotionMontagePlayer(
      rig: rig,
      clip: clip('Climb'),
      montage: const LuminaRootMotionMontage(
          clip: 'Climb', windows: [LuminaWarpWindow(target: 'Ledge', start: 0.0, end: 0.5, warpPointBone: 'hand_l')]),
    );
    expect(player.windows.single.warpPointOffset!.y, closeTo(140, 1e-6));
  });

  test('it blends in from the pose shown before and ends early when asked at its blend-out time', () {
    final idle = Float64List(rig.sampler.nodeCount * LuminaPoseMath.trsStride);
    LuminaPoseSearchPoser(rig).pose(clip('Idle'), 0, false, idle);
    final pelvis = rig.sampler.indexOfNode('pelvis') * LuminaPoseMath.trsStride;
    // The pose before: pelvis turned 90° about Y.
    idle.setAll(pelvis + 3, [0, math.sin(math.pi / 4), 0, math.cos(math.pi / 4)]);
    var wants = false;
    final player = LuminaRootMotionMontagePlayer(
      rig: rig,
      clip: clip('Climb'),
      montage: const LuminaRootMotionMontage(clip: 'Climb', blendOutTime: 0.5, blendTime: 0.2),
      wantsBlendOut: () => wants,
    )..begin(fromPose: idle, fromVelocity: Float64List(rig.sampler.nodeCount * 6), fromNodes: rig.sampler.nodeNames);
    double pelvisAngle() => 2 * math.acos(player.pose[pelvis + 6].abs().clamp(0.0, 1.0));
    expect(pelvisAngle(), closeTo(math.pi / 2, 1e-6), reason: 'starts at the shown pose');
    for (var i = 0; i < 12; i++) {
      player.advance(1 / 60);
    }
    expect(pelvisAngle(), lessThan(0.05 * math.pi / 2), reason: 'blended by 0.2 s');
    for (var i = 0; i < 24; i++) {
      player.advance(1 / 60);
    }
    expect(player.finished, isFalse, reason: 'nobody asked to leave');
    wants = true;
    player.advance(1 / 60);
    expect(player.finished, isTrue);
    expect(player.time, lessThan(1.0));
  });
}
