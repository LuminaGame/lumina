import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'pose_fixture.dart';

void main() {
  test('holdTargets: the hand stays at the same component-space spot over 120 frames while the actor moves 100 cm', () {
    final actor = LuminaActor(root: LuminaSceneComponent(location: Vector3(0, 0, 0)));
    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: mannequinFile.path)..relativeLocation = Vector3(0, -90, 0);
    mesh.attachToComponent(actor.rootComponent);
    actor.addComponent(mesh);
    final component = LuminaPoseAuthoringComponent()..setUp(LuminaPoseRig.detect(mannequinSkeleton));
    actor.addComponent(component);
    component.attachTo(mesh);
    expect(mesh.poseModifiers, contains(component));

    final rig = component.rig!;
    final pose = rig.restPoseCopy();
    final shoulder = rig.worldPositionOf(pose, mesh.renderTransform, 'upperarm_r');
    final target = shoulder + Vector3(-10, 30, 25);
    component.setHandleTarget('hand_r', target);
    component.modifyPose(pose, mesh.renderTransform, 1 / 60);
    final local = Matrix4.inverted(mesh.renderTransform).transformed3(rig.worldPositionOf(pose, mesh.renderTransform, 'hand_r'));
    expect(rig.worldPositionOf(pose, mesh.renderTransform, 'hand_r').distanceTo(target), lessThan(0.05));
    for (var f = 1; f <= 120; f++) {
      actor.actorLocation = Vector3(100 * f / 120, 0, 0);
      component.modifyPose(pose, mesh.renderTransform, 1 / 60);
      final now = Matrix4.inverted(mesh.renderTransform).transformed3(rig.worldPositionOf(pose, mesh.renderTransform, 'hand_r'));
      expect(now.distanceTo(local), lessThan(1e-6), reason: 'frame $f');
    }
    final hand = rig.worldPositionOf(pose, mesh.renderTransform, 'hand_r');
    expect(hand.distanceTo(target + Vector3(100, 0, 0)), lessThan(0.05));
    expect(component.handleWorldLocation('hand_r')!.distanceTo(hand), lessThan(1e-6));
  }, skip: mannequinSkip);

  test('bakeToPose: clearing a handle leaves its limb where it was; holdTargets gives it back to the incoming pose', () {
    for (final mode in LuminaPoseCaptureMode.values) {
      final r = PoseRun(LuminaPoseRig.detect(metahumanSkeleton()));
      r.component.captureMode = mode;
      final rest = r.at('hand_l');
      final target = r.at('upperarm_l') + Vector3(10, 30, 25);
      r.component.setHandleTarget('hand_l', target);
      r.tick(3);
      r.component.clearHandle('hand_l');
      r.tick(3);
      if (mode == LuminaPoseCaptureMode.bakeToPose) {
        expect(r.at('hand_l').distanceTo(target), lessThan(0.05), reason: '$mode');
      } else {
        expect(r.at('hand_l').distanceTo(rest), lessThan(1e-6), reason: '$mode');
      }
    }
  });

  test('weight blends the solved pose over the incoming one; targets set before the rig loads are kept', () {
    final component = LuminaPoseAuthoringComponent(weight: 0.5);
    final changed = <String>[];
    component.onHandleChanged = changed.add;
    expect(component.setHandleTarget('hand_l', Vector3(40, 140, 20)), isTrue);
    final rig = LuminaPoseRig.detect(metahumanSkeleton());
    component.setUp(rig);
    expect(component.handles['hand_l']!.hasTarget, isTrue);
    expect(changed, ['hand_l']);
    final pose = rig.restPoseCopy();
    final mesh = meshAt(Vector3.zero());
    final rest = rig.worldPositionOf(pose, mesh, 'hand_l');
    component.modifyPose(pose, mesh, 1 / 60);
    final half = rig.worldPositionOf(pose, mesh, 'hand_l');
    expect(half.distanceTo(rest), greaterThan(1));
    expect(half.distanceTo(Vector3(40, 140, 20)), greaterThan(1));
    component.weight = 1;
    component.modifyPose(pose, mesh, 1 / 60);
    expect(rig.worldPositionOf(pose, mesh, 'hand_l').distanceTo(Vector3(40, 140, 20)), lessThan(0.05));
    expect(component.findNearestHandle(Vector3(41, 140, 20), maxDistance: 8)!.name, 'hand_l');
    expect(component.findNearestHandle(Vector3(41, 400, 20), maxDistance: 8), isNull);
  });
}
