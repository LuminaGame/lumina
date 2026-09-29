import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/src/animation/skeleton_retargeter.dart';

void main() {
  group('LuminaSkeletonRetargeter Tests', () {
    late Skeleton mannySkeleton;
    late Skeleton quinnSkeleton;

    setUp(() {
      // Build source (Manny) skeleton
      mannySkeleton = Skeleton([
        BoneNode(id: 0, name: 'root', parentIndex: -1),
        BoneNode(id: 1, name: 'pelvis', parentIndex: 0)
          ..bindTranslation.setValues(0, 0, 100),
        BoneNode(id: 2, name: 'spine_01', parentIndex: 1)
          ..bindTranslation.setValues(0, 0, 20),
        BoneNode(id: 3, name: 'clavicle_l', parentIndex: 2)
          ..bindTranslation.setValues(-15, 0, 30),
        BoneNode(id: 4, name: 'upperarm_l', parentIndex: 3)
          ..bindTranslation.setValues(-30, 0, 0),
        BoneNode(id: 5, name: 'thigh_l', parentIndex: 1)
          ..bindTranslation.setValues(-10, 0, -10),
        BoneNode(id: 6, name: 'calf_l', parentIndex: 5)
          ..bindTranslation.setValues(0, 0, -45),
      ]);

      // Build target (Quinn / Mixamo style) skeleton with different naming / proportions (0.8x scaled limbs)
      quinnSkeleton = Skeleton([
        BoneNode(id: 0, name: 'Root', parentIndex: -1),
        BoneNode(id: 1, name: 'mixamorig:Hips', parentIndex: 0)
          ..bindTranslation.setValues(0, 0, 80),
        BoneNode(id: 2, name: 'mixamorig:Spine', parentIndex: 1)
          ..bindTranslation.setValues(0, 0, 16),
        BoneNode(id: 3, name: 'mixamorig:LeftShoulder', parentIndex: 2)
          ..bindTranslation.setValues(-12, 0, 24),
        BoneNode(id: 4, name: 'mixamorig:LeftArm', parentIndex: 3)
          ..bindTranslation.setValues(-24, 0, 0),
        BoneNode(id: 5, name: 'mixamorig:LeftUpLeg', parentIndex: 1)
          ..bindTranslation.setValues(-8, 0, -8),
        BoneNode(id: 6, name: 'mixamorig:LeftLeg', parentIndex: 5)
          ..bindTranslation.setValues(0, 0, -36),
      ]);
    });

    test('Auto-map heuristic correctly associates standard UE humanoid bones with target skeleton', () {
      final chains = LuminaSkeletonRetargeter.autoMapHumanoidChains(mannySkeleton, quinnSkeleton);
      expect(chains.isNotEmpty, isTrue);

      final pelvisChain = chains.firstWhere((c) => c.chainName == 'Pelvis');
      expect(pelvisChain.sourceStartBone, equals('pelvis'));
      expect(pelvisChain.targetStartBone, equals('mixamorig:Hips'));

      final leftArmChain = chains.firstWhere((c) => c.chainName == 'LeftArm');
      expect(leftArmChain.sourceStartBone, equals('upperarm_l'));
      expect(leftArmChain.targetStartBone, equals('mixamorig:LeftArm'));

      final leftLegChain = chains.firstWhere((c) => c.chainName == 'LeftLeg');
      expect(leftLegChain.sourceStartBone, equals('thigh_l'));
      expect(leftLegChain.targetStartBone, equals('mixamorig:LeftUpLeg'));
    });

    test('T-pose to A-pose compensation neutralizes rest rotation delta during retargeting', () {
      final chains = LuminaSkeletonRetargeter.autoMapHumanoidChains(mannySkeleton, quinnSkeleton);
      
      // Source rest offset: Clavicle down 45 degrees in A-pose
      final sourceOffset = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 4); // 45 deg pitch
      final targetOffset = Quaternion.identity(); // Target is T-pose

      final retargeter = LuminaSkeletonRetargeter(
        sourceSkeleton: mannySkeleton,
        targetSkeleton: quinnSkeleton,
        chainMappings: chains,
        sourceRestPoseOffsets: {'clavicle_l': sourceOffset},
        targetRestPoseOffsets: {'mixamorig:LeftShoulder': targetOffset},
      );

      // Create a test clip rotating clavicle_l by 45 degrees
      final sourceClip = LuminaAnimationClip(
        name: 'ClavicleRotate',
        duration: 1.0,
        tracks: [
          BoneTrack(
            boneIndex: 3, // clavicle_l
            times: [0.0, 1.0],
            rotations: [
              Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 4),
              Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2),
            ],
          ),
        ],
      );

      final retargetedClip = retargeter.retargetClip(sourceClip);
      expect(retargetedClip.tracks.isNotEmpty, isTrue);

      final shoulderTrack = retargetedClip.tracks.firstWhere((t) => t.boneIndex == 3);
      expect(shoulderTrack.rotations.isNotEmpty, isTrue);
      // The 45 degree delta is compensated (neutralized at t=0)
      final rotAt0 = shoulderTrack.rotations.first;
      expect(rotAt0.w, closeTo(1.0, 0.05)); // close to identity
    });

    test('Limb length scaling scales root translation trajectory accurately', () {
      final chains = LuminaSkeletonRetargeter.autoMapHumanoidChains(mannySkeleton, quinnSkeleton);
      final retargeter = LuminaSkeletonRetargeter(
        sourceSkeleton: mannySkeleton,
        targetSkeleton: quinnSkeleton,
        chainMappings: chains,
      );

      // Source clip has pelvis moving up and down by 20 units
      final sourceClip = LuminaAnimationClip(
        name: 'PelvisBounce',
        duration: 1.0,
        tracks: [
          BoneTrack(
            boneIndex: 1, // pelvis
            times: [0.0, 0.5, 1.0],
            positions: [
              Vector3(0, 0, 100),
              Vector3(0, 0, 120),
              Vector3(0, 0, 100),
            ],
          ),
        ],
      );

      final retargetedClip = retargeter.retargetClip(sourceClip);
      final hipsTrack = retargetedClip.tracks.firstWhere((t) => t.boneIndex == 1);
      expect(hipsTrack.positions.length, equals(3));
      
      // Height scale is 80 / 100 = 0.8
      expect(hipsTrack.positions[0].z, closeTo(80.0, 0.1));
      expect(hipsTrack.positions[1].z, closeTo(96.0, 0.1)); // 80 + 20 * 0.8 = 96
    });

    test('retargetClip maps all valid channels from source to target tracks', () {
      final chains = LuminaSkeletonRetargeter.autoMapHumanoidChains(mannySkeleton, quinnSkeleton);
      final retargeter = LuminaSkeletonRetargeter(
        sourceSkeleton: mannySkeleton,
        targetSkeleton: quinnSkeleton,
        chainMappings: chains,
      );

      final sourceClip = LuminaAnimationClip(
        name: 'Walk_Forward',
        duration: 2.0,
        tracks: [
          BoneTrack(
            boneIndex: 1, // pelvis
            times: [0.0, 1.0, 2.0],
            positions: [Vector3(0, 0, 100), Vector3(0, 50, 100), Vector3(0, 100, 100)],
            rotations: [Quaternion.identity(), Quaternion.identity(), Quaternion.identity()],
          ),
          BoneTrack(
            boneIndex: 5, // thigh_l
            times: [0.0, 1.0, 2.0],
            rotations: [
              Quaternion.axisAngle(Vector3(1, 0, 0), -0.2),
              Quaternion.axisAngle(Vector3(1, 0, 0), 0.3),
              Quaternion.axisAngle(Vector3(1, 0, 0), -0.2),
            ],
          ),
        ],
      );

      final targetClip = retargeter.retargetClip(sourceClip, targetClipName: 'Quinn_Walk_Forward');
      expect(targetClip.name, equals('Quinn_Walk_Forward'));
      expect(targetClip.duration, equals(2.0));
      expect(targetClip.tracks.length, equals(2));
      expect(targetClip.tracks.any((t) => t.boneIndex == 1), isTrue); // mixamorig:Hips
      expect(targetClip.tracks.any((t) => t.boneIndex == 5), isTrue); // mixamorig:LeftUpLeg
    });

    test('retargetPose writes live evaluated pose to target pose buffer', () {
      final chains = LuminaSkeletonRetargeter.autoMapHumanoidChains(mannySkeleton, quinnSkeleton);
      final retargeter = LuminaSkeletonRetargeter(
        sourceSkeleton: mannySkeleton,
        targetSkeleton: quinnSkeleton,
        chainMappings: chains,
      );

      final sourcePose = List.generate(mannySkeleton.boneCount, (_) => Matrix4.identity());
      sourcePose[1].setTranslationRaw(0, 0, 100);

      final targetPose = List.generate(quinnSkeleton.boneCount, (_) => Matrix4.identity());
      retargeter.retargetPose(sourcePose, targetPose);

      expect(targetPose[1].getTranslation().z, closeTo(80.0, 0.1));
    });
  });
}
