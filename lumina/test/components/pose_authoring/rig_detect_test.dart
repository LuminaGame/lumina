import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'pose_fixture.dart';

void main() {
  test('the test-assets mannequin has both arms and legs, a neck of two bones and the head, and a five-bone spine', () {
    final rig = LuminaPoseRig.detect(mannequinSkeleton);
    expect(rig.limbs.keys, containsAll(['arm_l', 'arm_r', 'leg_l', 'leg_r']));
    final arm = rig.limbs['arm_l']!;
    expect([rig.nodeNames[arm.upper], rig.nodeNames[arm.lower], rig.nodeNames[arm.end]], ['upperarm_l', 'lowerarm_l', 'hand_l']);
    final leg = rig.limbs['leg_r']!;
    expect([rig.nodeNames[leg.upper], rig.nodeNames[leg.lower], rig.nodeNames[leg.end]], ['thigh_r', 'calf_r', 'foot_r']);
    expect([for (final s in rig.neck) rig.nodeNames[s]], ['neck_01', 'neck_02', 'head']);
    expect(rig.neckWeights, [0.25, 0.35, 0.4]);
    expect(rig.spine.length, greaterThanOrEqualTo(3));
    expect([for (final s in rig.spine) rig.nodeNames[s]], ['spine_01', 'spine_02', 'spine_03', 'spine_04', 'spine_05']);
    expect(rig.nodeNames[rig.spineTip], 'neck_01');
    expect(rig.nodeNames[rig.pelvis], 'pelvis');
    expect({for (final (s, _) in arm.lowerTwist) rig.nodeNames[s]}, {'lowerarm_twist_01_l', 'lowerarm_twist_02_l'});
    expect({for (final (s, _) in arm.upperTwist) rig.nodeNames[s]}, {'upperarm_twist_01_l', 'upperarm_twist_02_l'});
    expect(rig.handleNames.toSet(), {
      'hand_l', 'elbow_l', 'foot_l', 'knee_l', 'hand_r', 'elbow_r', 'foot_r', 'knee_r', 'head', 'chest', 'pelvis', //
    });
    // The mannequin faces glTF +Z with +Y up.
    expect(rig.restUp.y, greaterThan(0.95));
    expect(rig.restForward.z, greaterThan(0.95));
    // Fingers are not part of the rig.
    expect(rig.slotNamed('index_01_l'), -1);
  }, skip: mannequinSkip);

  test('a MetaHuman-named skeleton: limbs with their lengths, twist bones placed along the bone, the rig as a definition', () {
    final skeleton = metahumanSkeleton(upperArm: 0.30, lowerArm: 0.28);
    final rig = LuminaPoseRig.detect(skeleton);
    expect(rig.limbs.keys, containsAll(['arm_l', 'arm_r', 'leg_l', 'leg_r']));
    final rest = rig.restPoseCopy();
    final mesh = meshAt(Vector3.zero());
    final shoulder = rig.worldPositionOf(rest, mesh, 'upperarm_l');
    final elbow = rig.worldPositionOf(rest, mesh, 'lowerarm_l');
    final hand = rig.worldPositionOf(rest, mesh, 'hand_l');
    expect((elbow - shoulder).length, closeTo(30, 1e-9));
    expect((hand - elbow).length, closeTo(28, 1e-9));
    final twists = {for (final (s, at) in rig.limbs['arm_l']!.lowerTwist) rig.nodeNames[s]: at};
    expect(twists['lowerarm_twist_01_l'], closeTo(2 / 3, 1e-9));
    expect(twists['lowerarm_twist_02_l'], closeTo(1 / 3, 1e-9));
    expect(rig.limbs['leg_l']!.lowerTwist.length, 1);
    // Corrective roots are carried along, not driven.
    expect(rig.slotNamed('upperarm_correctiveRoot_l'), -1);
    expect([for (final s in rig.neck) rig.nodeNames[s]], ['neck_01', 'neck_02', 'head']);
    expect(rig.restLeft.x, greaterThan(0.99));

    // The definition round-trips through a pose rig asset.
    final bytes = rig.definition.toAssetBytes(assetId: 'rig-1', meshPath: 'contents/meshes/MH.lmas');
    final back = LuminaPoseRigDefinition.fromAssetBytes(bytes);
    expect(back.toJson(), rig.definition.toJson());
    final rebuilt = LuminaPoseRig.fromDefinition(skeleton, back);
    expect(rebuilt.nodeNames, rig.nodeNames);
  });

  test('Mixamo names: arms, legs, Neck + Head and Spine..Spine2 under Hips', () {
    final json = metahumanSkeletonJson();
    const names = {
      'pelvis': 'mixamorig:Hips',
      'spine_01': 'mixamorig:Spine',
      'spine_02': 'mixamorig:Spine1',
      'spine_03': 'mixamorig:Spine2',
      'neck_01': 'mixamorig:Neck',
      'head': 'mixamorig:Head',
      'upperarm_l': 'mixamorig:LeftArm',
      'lowerarm_l': 'mixamorig:LeftForeArm',
      'hand_l': 'mixamorig:LeftHand',
      'thigh_r': 'mixamorig:RightUpLeg',
      'calf_r': 'mixamorig:RightLeg',
      'foot_r': 'mixamorig:RightFoot',
    };
    for (final n in (json['nodes'] as List).cast<Map<String, dynamic>>()) {
      final name = n['name'] as String;
      n['name'] = names[name] ?? (name == 'spine_04' || name == 'spine_05' || name == 'neck_02' ? 'mixamorig:Chest_$name' : name);
    }
    final rig = LuminaPoseRig.detect(GlbSkeleton.fromJson(json));
    expect(rig.nodeNames[rig.limbs['arm_l']!.end], 'mixamorig:LeftHand');
    expect(rig.nodeNames[rig.limbs['leg_r']!.upper], 'mixamorig:RightUpLeg');
    expect(rig.nodeNames[rig.pelvis], 'mixamorig:Hips');
    expect(rig.neck.isNotEmpty, isTrue);
    expect(rig.nodeNames[rig.neck.last], 'mixamorig:Head');
    expect(rig.spine.length, greaterThanOrEqualTo(3));
  });

  test('a skeleton without legs has no leg handles and no error', () {
    final rig = LuminaPoseRig.detect(metahumanSkeleton(legs: false));
    expect(rig.limbs.keys.toSet(), {'arm_l', 'arm_r'});
    expect(rig.handleNames, isNot(contains('foot_l')));
    expect(rig.handleNames, isNot(contains('knee_r')));
    final run = PoseRun(rig);
    expect(run.component.setHandleTarget('foot_l', Vector3(0, 0, 0)), isFalse);
    expect(run.component.setHandleTarget('hand_l', Vector3(40, 140, 20)), isTrue);
    run.tick();
    expect(run.at('hand_l').distanceTo(Vector3(40, 140, 20)), lessThan(0.05));
  });
}
