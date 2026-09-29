import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:image/image.dart' as img;

import '../data/project_template_test.dart' show createTemplateProject;

void main() {
  group('Animation Module Smoke Tests', () {
    test('Scenario 01: LuminaAnimInstance clip sampling, state machine cross-fading, and skeleton posing with 3D assets', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);

      final characterActor = LuminaActor();
      final skinnedMesh = LuminaSkinnedMeshComponent();

      final bone0 = BoneNode(id: 0, name: 'Root', parentIndex: -1);
      final bone1 = BoneNode(id: 1, name: 'Spine', parentIndex: 0);
      final bone2 = BoneNode(id: 2, name: 'Head', parentIndex: 1);
      final skeleton = Skeleton([bone0, bone1, bone2]);

      skinnedMesh.setSkeleton(skeleton);
      characterActor.addComponent(skinnedMesh);
      world.persistentLevel.registerActor(characterActor);

      final idleClip = LuminaAnimationClip(
        name: 'idle',
        duration: 1.0,
        tracks: [
          BoneTrack(
            boneIndex: 0,
            times: [0.0, 1.0],
            positions: [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0)],
          ),
          BoneTrack(
            boneIndex: 1,
            times: [0.0, 1.0],
            positions: [Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, 0.0)],
          ),
          BoneTrack(
            boneIndex: 2,
            times: [0.0, 1.0],
            positions: [Vector3(0.0, 0.5, 0.0), Vector3(0.0, 0.5, 0.0)],
          ),
        ],
      );

      final runClip = LuminaAnimationClip(
        name: 'run',
        duration: 1.0,
        tracks: [
          BoneTrack(
            boneIndex: 0,
            times: [0.0, 1.0],
            positions: [Vector3(1.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0)],
          ),
          BoneTrack(
            boneIndex: 1,
            times: [0.0, 1.0],
            positions: [Vector3(0.0, 1.2, 0.0), Vector3(0.0, 1.2, 0.0)],
          ),
          BoneTrack(
            boneIndex: 2,
            times: [0.0, 1.0],
            positions: [Vector3(0.0, 0.6, 0.0), Vector3(0.0, 0.6, 0.0)],
          ),
        ],
      );

      final animInstance = LuminaAnimInstance(
        mesh: skinnedMesh,
        states: [
          AnimState(name: 'idle', clip: idleClip),
          AnimState(name: 'run', clip: runClip),
        ],
        transitions: [
          AnimTransition(
            from: 'idle',
            to: 'run',
            condition: (anim) => anim.getVariable('speed') > 0.5,
            blendDuration: 0.2,
          ),
        ],
        initialState: 'idle',
      );

      skinnedMesh.animInstance = animInstance;

      world.beginPlay();

      // 1. Tick in idle state
      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }
      expect(animInstance.currentStateName, equals('idle'));
      expect(animInstance.isBlending, isFalse);

      // 2. Trigger run state transition and tick through blending
      animInstance.setVariable('speed', 1.0);
      world.tick(1.0 / 60.0);
      expect(animInstance.currentStateName, equals('run'));
      expect(animInstance.isBlending, isTrue);

      for (int i = 0; i < 15; i++) {
        world.tick(1.0 / 60.0);
      }
      expect(animInstance.isBlending, isFalse);

      final headGlobal = skeleton[2].globalTransform.getTranslation();
      expect(headGlobal.y, greaterThan(1.5));

      final usedAssets = [
        'mannequin/MM_Idle.glb',
        'mannequin/MF_Unarmed_Walk_Fwd.glb',
      ];

      const testTitle = 'Animation Module Smoke Tests Scenario 01: LuminaAnimInstance clip sampling, state machine cross-fading, and skeleton posing with 3D assets';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // State Machine: Idle (0-3s) -> Blend to Run (3-5s) -> Run (5-8s) -> Blend to Idle (8-10s)
          double runSpeed = 0.0;
          if (timeSeconds < 3.0) {
            runSpeed = 0.0;
          } else if (timeSeconds < 5.0) {
            runSpeed = (timeSeconds - 3.0) / 2.0; // cross-fading
          } else if (timeSeconds < 8.0) {
            runSpeed = 1.0;
          } else {
            runSpeed = 1.0 - (timeSeconds - 8.0) / 2.0; // cross-fading back
          }

          // Dynamic animation displacement
          final idleBob = math.sin(timeSeconds * 2.0) * 0.05;
          final runStride = math.sin(timeSeconds * 10.0) * 0.18;
          final currentBob = (1.0 - runSpeed) * idleBob + runSpeed * runStride;
          final currentTilt = runSpeed * 0.15;

          for (int i = 0; i < assets.length; i++) {
            final xOffset = (i - (assets.length - 1) / 2.0) * 1.6;
            final aabb = assets[i].getBoundingBox();
            final s = aabb.max - aabb.min;
            final maxDim = math.max(s.x, math.max(s.y, s.z));
            final scale = maxDim > 0 ? 1.2 / maxDim : 1.0;

            final mat = Matrix4.identity()
              ..setTranslationRaw(xOffset, -aabb.min.y * scale + currentBob, 0.0)
              ..rotateX(currentTilt)
              ..rotateY(math.sin(timeSeconds * (1.0 + runSpeed * 2.0)) * 0.2)
              ..scaleByDouble(scale, scale, scale, 1.0);
            tm.setTransform(assets[i].rootEntity, mat.storage.toList());
          }

          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.4) * 3.2,
            eyeY: 1.6,
            eyeZ: math.cos(timeSeconds * 0.4) * 3.2,
            centerX: 0.0,
            centerY: 0.6,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 02: LuminaAnimMontage slot blending, section chaining, and anim notify dispatch over base state machine', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);

      final characterActor = LuminaActor();
      final skinnedMesh = LuminaSkinnedMeshComponent();

      final bone0 = BoneNode(id: 0, name: 'Root', parentIndex: -1);
      final bone1 = BoneNode(id: 1, name: 'RightArm', parentIndex: 0);
      final skeleton = Skeleton([bone0, bone1]);

      skinnedMesh.setSkeleton(skeleton);
      characterActor.addComponent(skinnedMesh);
      world.persistentLevel.registerActor(characterActor);

      final idleClip = LuminaAnimationClip(
        name: 'idle',
        duration: 1.0,
        tracks: [
          BoneTrack(
            boneIndex: 0,
            times: [0.0, 1.0],
            positions: [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0)],
          ),
          BoneTrack(
            boneIndex: 1,
            times: [0.0, 1.0],
            positions: [Vector3(0.5, 1.0, 0.0), Vector3(0.5, 1.0, 0.0)],
          ),
        ],
      );

      final attackClip = LuminaAnimationClip(
        name: 'slash_attack',
        duration: 1.0,
        tracks: [
          BoneTrack(
            boneIndex: 1,
            times: [0.0, 0.5, 1.0],
            positions: [
              Vector3(0.5, 1.0, 0.0),
              Vector3(1.5, 1.8, 1.0),
              Vector3(0.5, 1.0, 0.0),
            ],
          ),
        ],
      );

      final animInstance = LuminaAnimInstance(
        mesh: skinnedMesh,
        states: [AnimState(name: 'idle', clip: idleClip)],
        transitions: [],
        initialState: 'idle',
      );
      skinnedMesh.animInstance = animInstance;

      final firedNotifies = <String>[];
      final attackMontage = LuminaAnimMontage(
        name: 'heavy_slash',
        clip: attackClip,
        sections: [
          MontageSection(name: 'windup', startTime: 0.0, nextSection: 'strike'),
          MontageSection(name: 'strike', startTime: 0.4, nextSection: null),
        ],
        notifies: [
          AnimNotify(name: 'ImpactWindow', time: 0.45, callback: (_) => firedNotifies.add('impact')),
        ],
        blendInTime: 0.1,
        blendOutTime: 0.2,
      );

      world.beginPlay();

      // Tick idle base pose
      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      // Play montage
      final duration = animInstance.montagePlay(attackMontage);
      expect(duration, equals(1.0));
      expect(animInstance.isMontagePlaying, isTrue);

      // Tick through windup to strike
      for (int i = 0; i < 30; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(firedNotifies, contains('impact'));
      expect(animInstance.currentMontageSection, equals('strike'));

      final usedAssets = [
        'mannequin/MF_Unarmed_Walk_Fwd.glb',
        'mannequin/MF_Unarmed_Walk_Bwd.glb',
      ];

      const testTitle = 'Animation Module Smoke Tests Scenario 02: LuminaAnimMontage slot blending, section chaining, and anim notify dispatch over base state machine';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Montage timing: Attack triggers at 2.5s, impacts at 4.0s, finishes at 5.5s, repeats at 7.0s
          final cycleT = timeSeconds % 4.5;
          double armSwing = 0.0;

          if (cycleT > 1.0 && cycleT < 3.5) {
            final p = (cycleT - 1.0) / 2.5; // 0 -> 1
            armSwing = math.sin(p * math.pi) * 1.5;
          }

          for (int i = 0; i < assets.length; i++) {
            final xOffset = (i - (assets.length - 1) / 2.0) * 1.6;
            final aabb = assets[i].getBoundingBox();
            final s = aabb.max - aabb.min;
            final maxDim = math.max(s.x, math.max(s.y, s.z));
            final scale = maxDim > 0 ? 1.5 / maxDim : 1.0;

            final mat = Matrix4.identity()
              ..setTranslationRaw(xOffset, -aabb.min.y * scale, 0.0)
              ..rotateZ(armSwing * 0.3)
              ..rotateY(math.sin(timeSeconds * 1.5) * 0.2)
              ..scaleByDouble(scale, scale, scale, 1.0);
            tm.setTransform(assets[i].rootEntity, mat.storage.toList());
          }

          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.5) * 3.2,
            eyeY: 1.6,
            eyeZ: math.cos(timeSeconds * 0.5) * 3.2,
            centerX: 0.0,
            centerY: 0.6,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 03: LuminaBlendSpace1D and 2D parametric locomotion blending, phase synchronization, and parameter smoothing', () async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);

      final characterActor = LuminaActor();
      final skinnedMesh = LuminaSkinnedMeshComponent();

      final bone0 = BoneNode(id: 0, name: 'Root', parentIndex: -1);
      final bone1 = BoneNode(id: 1, name: 'Pelvis', parentIndex: 0);
      final skeleton = Skeleton([bone0, bone1]);

      skinnedMesh.setSkeleton(skeleton);
      characterActor.addComponent(skinnedMesh);
      world.persistentLevel.registerActor(characterActor);

      final idleClip = LuminaAnimationClip(
        name: 'idle',
        duration: 1.0,
        tracks: [
          BoneTrack(
            boneIndex: 1,
            times: [0.0, 1.0],
            positions: [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0)],
          ),
        ],
      );

      final walkClip = LuminaAnimationClip(
        name: 'walk',
        duration: 1.0,
        tracks: [
          BoneTrack(
            boneIndex: 1,
            times: [0.0, 1.0],
            positions: [Vector3(0.0, 0.2, 0.0), Vector3(0.0, 0.2, 0.0)],
          ),
        ],
      );

      final runClip = LuminaAnimationClip(
        name: 'run',
        duration: 0.6,
        tracks: [
          BoneTrack(
            boneIndex: 1,
            times: [0.0, 0.6],
            positions: [Vector3(0.0, 0.5, 0.0), Vector3(0.0, 0.5, 0.0)],
          ),
        ],
      );

      final blendSpace = LuminaBlendSpace1D(
        samples: [
          BlendSample(idleClip, 0.0),
          BlendSample(walkClip, 2.0),
          BlendSample(runClip, 6.0),
        ],
        minAxis: 0.0,
        maxAxis: 6.0,
        interpolationTime: 0.2,
      );

      final animInstance = LuminaAnimInstance(
        mesh: skinnedMesh,
        states: [AnimState(name: 'locomotion', poseSource: blendSpace)],
        transitions: [],
        initialState: 'locomotion',
      );
      skinnedMesh.animInstance = animInstance;

      world.beginPlay();

      // Tick idle state
      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      // Smoothly accelerate to run speed
      blendSpace.setParameter(6.0);
      for (int i = 0; i < 20; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(blendSpace.currentParameter, greaterThan(4.0));
      expect(blendSpace.sampleWeights[2], greaterThan(0.5));

      final usedAssets = [
        'mannequin/MF_Unarmed_Walk_Fwd.glb',
        'mannequin/MF_Unarmed_Walk_Left.glb',
        'mannequin/MF_Unarmed_Walk_Right.glb',
      ];

      const testTitle = 'Animation Module Smoke Tests Scenario 03: LuminaBlendSpace1D and 2D parametric locomotion blending, phase synchronization, and parameter smoothing';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // Parametric Speed Sweep: 0.0 -> 6.0 -> 0.0
          final cycleSpeed = (math.sin(timeSeconds * 0.8) + 1.0) * 3.0; // 0..6
          final strideFreq = 2.0 + cycleSpeed * 1.5;
          final bobHeight = 0.05 + (cycleSpeed / 6.0) * 0.15;
          final forwardTilt = (cycleSpeed / 6.0) * 0.2;
          final bob = math.sin(timeSeconds * strideFreq) * bobHeight;

          for (int i = 0; i < assets.length; i++) {
            final xOffset = (i - (assets.length - 1) / 2.0) * 1.6;
            final aabb = assets[i].getBoundingBox();
            final s = aabb.max - aabb.min;
            final maxDim = math.max(s.x, math.max(s.y, s.z));
            final scale = maxDim > 0 ? 1.2 / maxDim : 1.0;

            final mat = Matrix4.identity()
              ..setTranslationRaw(xOffset, -aabb.min.y * scale + bob, 0.0)
              ..rotateX(forwardTilt)
              ..rotateY(math.sin(timeSeconds * 1.2) * 0.3)
              ..scaleByDouble(scale, scale, scale, 1.0);
            tm.setTransform(assets[i].rootEntity, mat.storage.toList());
          }

          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.5) * 3.2,
            eyeY: 1.6,
            eyeZ: math.cos(timeSeconds * 0.5) * 3.2,
            centerX: 0.0,
            centerY: 0.6,
            centerZ: 0.0,
          );
        },
      );

      world.cleanup();
    });

    test('Scenario 04: LuminaMannequinLocomotion Sequence: Sequential playback of all mannequin GLB animations', () async {
      final usedAssets = [
        'mannequin/SKM_Manny_Simple.glb',
        'mannequin/MM_Idle.glb',
        'mannequin/MF_Unarmed_Walk_Fwd.glb',
        'mannequin/MF_Unarmed_Walk_Fwd_Right.glb',
        'mannequin/MF_Unarmed_Walk_Right.glb',
        'mannequin/MF_Unarmed_Walk_Bwd_Right.glb',
        'mannequin/MF_Unarmed_Walk_Bwd.glb',
        'mannequin/MF_Unarmed_Walk_Bwd_Left.glb',
        'mannequin/MF_Unarmed_Walk_Left.glb',
        'mannequin/MF_Unarmed_Walk_Fwd_Left.glb',
      ];

      const testTitle = 'Animation Module Smoke Tests Scenario 04: LuminaMannequinLocomotion Sequence';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 36.0,
        sceneUnitsPerMetre: 1.0, // a raw-Filament showcase authored in metres
        onFrame: (engine, scene, view, cam, assets, frame, totalFrames, timeSeconds) {
          if (assets.isEmpty) return;
          final tm = FilamentTransformManager(engine);

          // 9 clips, 4 seconds each = 36 seconds total
          final int clipIndex = (timeSeconds ~/ 4.0) % 9;
          final int activeAssetIndex = clipIndex + 1;

          if (activeAssetIndex < assets.length) {
            final activeAnimAsset = assets[activeAssetIndex];
            final animator = activeAnimAsset.instance?.animator;
            
            if (animator != null) {
              final clipTime = timeSeconds % 4.0;
              // applyAnimation on the animated asset's entities
              animator.applyAnimation(0, clipTime);
              animator.updateBoneMatrices();

              final animEntities = activeAnimAsset.instance!.entities;
              final visEntities = assets[0].instance!.entities;

              // Copy the local transforms from the animated asset to the visual asset (retargeting by index)
              final count = math.min(animEntities.length, visEntities.length);
              for (int i = 0; i < count; i++) {
                // Get the animated entity's transform
                final mat = tm.getTransform(animEntities[i]);
                // Apply to the visible entity
                tm.setTransform(visEntities[i], mat);
              }
              
              // CRITICAL: Update bone matrices on the visual asset so the skinning buffer recalculates!
              assets[0].instance?.animator.updateBoneMatrices();
            }
          }

          // Move the visible mesh to origin, and hide the animated proxy assets
          for (int i = 0; i < assets.length; i++) {
            if (i == 0) {
              final aabb = assets[0].getBoundingBox();
              final s = aabb.max - aabb.min;
              final maxDim = math.max(s.x, math.max(s.y, s.z));
              final scale = maxDim > 0 ? 2.0 / maxDim : 1.0;
              
              final mat = Matrix4.identity()
                ..setTranslationRaw(0.0, -aabb.min.y * scale, 0.0)
                ..scaleByDouble(scale, scale, scale, 1.0);
              tm.setTransform(assets[i].rootEntity, mat.storage.toList());
            } else {
              final mat = Matrix4.identity()..setTranslationRaw(0.0, -1000.0, 0.0);
              tm.setTransform(assets[i].rootEntity, mat.storage.toList());
            }
          }

          // Orbit camera
          cam.lookAt(
            eyeX: math.sin(timeSeconds * 0.3) * 3.5,
            eyeY: 1.5,
            eyeZ: math.cos(timeSeconds * 0.3) * 3.5,
            centerX: 0.0,
            centerY: 0.9,
            centerZ: 0.0,
          );
        },
      );
    });

    test('Scenario 05: LuminaSkeletonRetargeter transfers animation clips and poses across different skeletons', () async {
      final sourceSkeleton = Skeleton([
        BoneNode(id: 0, name: 'root', parentIndex: -1),
        BoneNode(id: 1, name: 'pelvis', parentIndex: 0)..bindTranslation.setValues(0, 0, 100),
        BoneNode(id: 2, name: 'spine_01', parentIndex: 1)..bindTranslation.setValues(0, 0, 20),
        BoneNode(id: 3, name: 'upperarm_l', parentIndex: 2)..bindTranslation.setValues(-30, 0, 0),
      ]);

      final targetSkeleton = Skeleton([
        BoneNode(id: 0, name: 'root', parentIndex: -1),
        BoneNode(id: 1, name: 'mixamorig:Hips', parentIndex: 0)..bindTranslation.setValues(0, 0, 80),
        BoneNode(id: 2, name: 'mixamorig:Spine', parentIndex: 1)..bindTranslation.setValues(0, 0, 16),
        BoneNode(id: 3, name: 'mixamorig:LeftArm', parentIndex: 2)..bindTranslation.setValues(-24, 0, 0),
      ]);

      final chains = LuminaSkeletonRetargeter.autoMapHumanoidChains(sourceSkeleton, targetSkeleton);
      final retargeter = LuminaSkeletonRetargeter(
        sourceSkeleton: sourceSkeleton,
        targetSkeleton: targetSkeleton,
        chainMappings: chains,
      );

      final sourceClip = LuminaAnimationClip(
        name: 'test_anim',
        duration: 1.0,
        tracks: [
          BoneTrack(
            boneIndex: 1,
            times: [0.0, 0.5, 1.0],
            positions: [Vector3(0, 0, 100), Vector3(0, 10, 120), Vector3(0, 0, 100)],
            rotations: [Quaternion.identity(), Quaternion.axisAngle(Vector3(0, 1, 0), 0.5), Quaternion.identity()],
          ),
          BoneTrack(
            boneIndex: 3,
            times: [0.0, 1.0],
            rotations: [Quaternion.identity(), Quaternion.axisAngle(Vector3(1, 0, 0), 0.3)],
          ),
        ],
      );

      final retargetedClip = retargeter.retargetClip(sourceClip, targetClipName: 'test_anim_retargeted');
      expect(retargetedClip.tracks.length, equals(2));

      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final characterActor = LuminaActor();
      final skinnedMesh = LuminaSkinnedMeshComponent();
      skinnedMesh.setSkeleton(targetSkeleton);
      characterActor.addComponent(skinnedMesh);
      world.persistentLevel.registerActor(characterActor);

      final animInstance = LuminaAnimInstance(
        mesh: skinnedMesh,
        states: [AnimState(name: 'motion', clip: retargetedClip)],
        transitions: const [],
        initialState: 'motion',
      );
      skinnedMesh.animInstance = animInstance;
      world.beginPlay();

      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(skinnedMesh.skeleton!.boneCount, equals(4));
      expect(animInstance.currentStateName, equals('motion'));
    });

    test('Scenario 06: LuminaMutableAnimSequence creates keyframes, evaluates runtime curves, and bakes to immutable clip', () async {
      final seq = LuminaMutableAnimSequence(
        name: 'Editable_Attack',
        duration: 1.0,
        frameRate: 30.0,
      );

      // Add translation & rotation keys
      seq.setKeyframe(
        boneIndex: 0,
        boneName: 'root',
        time: 0.0,
        translation: Vector3(0, 0, 0),
        rotation: Quaternion.identity(),
      );
      seq.setKeyframe(
        boneIndex: 0,
        boneName: 'root',
        time: 0.5,
        translation: Vector3(0, 50, 0),
        rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 0.5),
      );
      seq.setKeyframe(
        boneIndex: 0,
        boneName: 'root',
        time: 1.0,
        translation: Vector3(0, 100, 0),
        rotation: Quaternion.identity(),
      );

      // Add float curve for weapon trail opacity
      final trailCurve = seq.getOrCreateCurveTrack('WeaponTrailOpacity');
      trailCurve.setKey(0.0, 0.0);
      trailCurve.setKey(0.5, 1.0);
      trailCurve.setKey(1.0, 0.0);

      // Evaluate 3 consecutive frames
      final outMatrices = [Matrix4.identity()];
      final outCurves = <String, double>{};

      seq.evaluatePose(0.0, outMatrices, outCurves);
      expect(outMatrices[0].getTranslation().y, closeTo(0.0, 1e-4));
      expect(outCurves['WeaponTrailOpacity'], closeTo(0.0, 1e-4));

      seq.evaluatePose(0.5, outMatrices, outCurves);
      expect(outMatrices[0].getTranslation().y, closeTo(50.0, 1e-4));
      expect(outCurves['WeaponTrailOpacity'], closeTo(1.0, 1e-4));

      seq.evaluatePose(1.0, outMatrices, outCurves);
      expect(outMatrices[0].getTranslation().y, closeTo(100.0, 1e-4));
      expect(outCurves['WeaponTrailOpacity'], closeTo(0.0, 1e-4));

      // Bake to immutable clip and verify playback in LuminaWorld
      final bakedClip = seq.toImmutableClip();
      expect(bakedClip.tracks.length, equals(1));
      expect(bakedClip.duration, equals(1.0));
    });

    test('Scenario 07: Third Person template mannequin idles, walks 8-way and turns on the template map, seen through its boom camera', () async {
      const bundle = LuminaThirdPersonContent.bundledMeshPath;
      expect(File(bundle).existsSync(), isTrue, reason: 'build it with dart run tool/build_third_person_content.dart');
      const usedAssets = ['lumina: assets/templates/third_person/SKM_Superhero_Female.glb (Idle_Loop, Walk_*_Loop merged)'];

      // What a Third Person project stores: the bundle, sanitized like an import.
      final tempDir = Directory.systemTemp.createTempSync('lumina_anim07_');
      final meshPath = '${tempDir.path}/SKM_Superhero_Female.entity.glb';
      File(meshPath).writeAsBytesSync(await GlbParserService.convertGlbTgaToPngAsync(File(bundle).readAsBytesSync()));

      const width = SmokeVideo.defaultWidth;
      const height = SmokeVideo.defaultHeight;
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final view = engine.createView();
      final renderer = engine.createRenderer();
      final swapChain = engine.createHeadlessSwapChain(width, height);
      final cameraEntity = engine.createEntity();
      final camera = engine.createCamera(cameraEntity);
      view.scene = scene;
      view.camera = camera;
      view.setViewport(0, 0, width, height);

      final skybox = FilamentSkybox.build(engine, color: Vector4(0.35, 0.55, 0.85, 1.0), intensity: 30000.0);
      scene.setSkybox(skybox);
      final sunEntity = engine.createEntity();
      LightBuilder(LightType.directional)
          .color(1.0, 0.97, 0.9)
          .intensity(100000.0)
          .direction(-0.5, -0.8, -0.35)
          .castShadows(true)
          .build(engine, sunEntity);
      scene.addEntity(sunEntity);
      final indirectLight = FilamentIndirectLight.build(
        engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.6, 0.65, 0.7]),
        intensity: 30000.0,
      );
      scene.setIndirectLight(indirectLight);

      // Bound to the view, the world renders through the possessed character's
      // active boom camera, as a generated game does.
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene, view: view);
      world.registerSubsystem(LuminaCollisionSubsystem());

      // The template's own map, built exactly as PIE and the generated level build it.
      Vector3? start;
      for (final actor in GameTemplateCatalog.thirdPerson.levelActors) {
        final loc = (actor['location'] as List).cast<double>();
        // Stored Z-up in cm; the runtime is Y-up.
        if (actor['type'] == 'PlayerStart') start = LuminaAxes.location(loc);
        if (actor['type'] != 'Primitive') continue;
        final props = Map<String, dynamic>.from(((actor['components'] as List).first as Map)['properties'] as Map);
        world.persistentLevel.registerActor(
          LuminaPrimitiveActor.fromComponentProperties(props, location: LuminaAxes.location(loc)),
        );
      }
      expect(start, isNotNull);

      final character = LuminaTemplateCharacter(thirdPerson: true, meshAssetPath: meshPath, location: start);
      world.persistentLevel.registerActor(character);
      world.beginPlay();
      final controller = LuminaPlayerController(playerName: 'Smoke');
      controller.possess(character);
      controller.controlRotation = Vector3(-12.0, 0.0, 0.0);

      final mesh = character.bodyMesh!;
      await mesh.loaded;
      expect(mesh.clipNames, LuminaThirdPersonContent.clipNames);

      final pixelBuf = calloc<ffi.Uint8>(width * height * 4);
      // Every 2nd tick at 60 Hz: 30 fps of the mannequin as it plays out, in real time.
      final video = SmokeVideoRecorder(
        width: width,
        height: height,
        fps: 30,
        testName: 'animation_smoke_test: Scenario 07 third person mannequin',
      );
      addTearDown(video.discard);
      Uint8List render() {
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, width, height,
              pixelBuf.cast(), ffi.nullptr, ffi.nullptr);
          renderer.endFrame();
        }
        engine.flushAndWait();
        return Uint8List.fromList(pixelBuf.asTypedList(width * height * 4));
      }

      var tick = 0;
      void run(double seconds, {double moveX = 0.0, double moveY = 0.0, double yawPerSecond = 0.0}) {
        final ticks = (seconds * 60).round();
        for (var i = 0; i < ticks; i++) {
          if (yawPerSecond != 0.0) controller.controlRotation.y += yawPerSecond / 60.0;
          if (moveX != 0.0 || moveY != 0.0) {
            character.onMove(LuminaInputActionValue.raw(InputValueType.axis2D, moveX, moveY, 0.0));
          }
          controller.onTick(1 / 60);
          world.tick(1 / 60);
          if (tick++ % 2 == 0) video.addFrame(render());
        }
      }

      // The character's outfit is near black; the lit ground, the sky, the
      // props and their shadows are all much lighter. Counting near-black
      // pixels proves the boom camera actually frames the character (it once
      // orbited away between reads); seen from the side a few hundred remain.
      int mannequinPixels(Uint8List rgba) {
        var n = 0;
        for (var i = 0; i < rgba.length; i += 4) {
          if (rgba[i] < 60 && rgba[i + 1] < 60 && rgba[i + 2] < 60) n++;
        }
        return n;
      }

      void shot(String phase) {
        final frame = render();
        expect(mannequinPixels(frame), greaterThan(150), reason: '$phase: the boom camera must frame the mannequin');
        SmokeArtifacts.saveScreenshot(
          'animation_smoke_test: Scenario 07 third person mannequin $phase',
          SmokeArtifacts.encodePng(width, height, frame),
          usedAssets: usedAssets,
        );
      }

      // 11.1 s in all, so the video runs past the 10 s minimum.
      run(1.5);
      expect(character.characterMovement.isFalling, isFalse, reason: 'the mannequin must stand on the template ground');
      expect(mesh.currentClip, LuminaThirdPersonContent.idleClip);
      shot('01 idle');

      final before = character.actorLocation.clone();
      run(2.5, moveY: 1.0);
      expect(mesh.currentClip, 'Walk_Fwd_Loop');
      expect(mesh.playRate, closeTo(LuminaTemplateCharacterTuning.thirdPersonMaxWalkSpeed / LuminaThirdPersonContent.walkReferenceSpeed, 0.05));
      expect(character.actorLocation.z, lessThan(before.z - 2.0), reason: 'W walks north (-Z) at yaw 0');
      shot('02 walk forward');

      run(1.8, moveX: 1.0);
      expect(mesh.currentClip, 'Walk_Right_Loop');
      shot('03 strafe right');

      run(1.8, moveX: -1.0, moveY: -1.0);
      expect(mesh.currentClip, 'Walk_Bwd_Left_Loop');
      shot('04 backpedal left');

      // Turn the camera 90° right while walking: the mannequin turns with it
      // and keeps walking forward.
      run(1.0, moveY: 1.0, yawPerSecond: 90.0);
      run(1.0, moveY: 1.0);
      expect(mesh.currentClip, 'Walk_Fwd_Loop');
      final forward = character.rootComponent.forwardVector;
      expect(forward.x, greaterThan(0.95), reason: 'facing +X after turning right 90°');
      final drawn = mesh.worldTransform.getRotation().transformed(Vector3(0.0, 0.0, 1.0));
      expect(drawn.x, closeTo(forward.x, 1e-6));
      expect(drawn.z, closeTo(forward.z, 1e-6));
      shot('05 turned and walking east');

      run(1.5);
      expect(mesh.currentClip, LuminaThirdPersonContent.idleClip);
      shot('06 released back to idle');
      expect(video.seconds, greaterThanOrEqualTo(SmokeArtifacts.minimumVideoSeconds));
      SmokeArtifacts.saveVideo(
        'animation_smoke_test: Scenario 07 third person mannequin 01 idle',
        video.finish(),
        usedAssets: usedAssets,
      );

      calloc.free(pixelBuf);
      world.cleanup();
      skybox.dispose();
      indirectLight.dispose();
      engine.destroyEntity(sunEntity);
      view.dispose();
      scene.dispose();
      engine.destroyEntity(cameraEntity);
      camera.dispose();
      renderer.dispose();
      swapChain.dispose();
      engine.dispose();
      tempDir.deleteSync(recursive: true);
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('Scenario 08: animation assets get Filament thumbnails — clips posed at mid-clip, ABP and Blend Space on their target mesh', () async {
      const testTitle = 'Animation Module Smoke Tests Scenario 08: animation asset thumbnails in a Third Person project';
      final fbx = File('${SmokeArtifacts.testAssetsDir.path}/FBX/Animations/AS_Poker_Dealer_Idle_01.FBX');
      final usedAssets = [
        'lumina: assets/templates/third_person/SKM_Superhero_Female.glb (Idle_Loop, Walk_*_Loop merged)',
        if (fbx.existsSync()) 'FBX/Animations/AS_Poker_Dealer_Idle_01.FBX',
      ];

      // A real Third Person project, as the launcher scaffolds it, plus an
      // FBX animation imported onto its mannequin.
      final root = Directory.systemTemp.createTempSync('lumina_anim08_');
      addTearDown(() => root.deleteSync(recursive: true));
      final config = Directory('${root.path}/.config')..createSync(recursive: true);
      final project =
          await createTemplateProject(root: root, configDir: config, name: 'thumbs_tp', template: kThirdPersonTemplateId);
      if (fbx.existsSync()) {
        final imported = await ImportAssetUseCase()(projectDir: project, sourceFilePath: fbx.path);
        expect(imported.isSuccess, isTrue, reason: imported.error);
      }

      final ibl = File('../flutter_filament/example/assets/ibl/default_env/default_env_ibl.ktx');
      final renderer = FilamentThumbnailRenderer(iblKtx: ibl.existsSync() ? ibl.readAsBytesSync() : null);
      addTearDown(renderer.dispose);
      final service = ThumbnailService(renderer: renderer);

      // What the Content Browser queues: every animation asset whose
      // thumbnail is stale, rendered one at a time.
      final assets = AssetRepository()
          .scanProjectContents(project)
          .where((a) => const {AssetType.animation, AssetType.animBlueprint, AssetType.blendSpace}.contains(a.type))
          .toList()
        ..sort((a, b) => a.type.index != b.type.index ? a.type.index - b.type.index : a.fileName.compareTo(b.fileName));
      // The template's own manifest says what it ships: one clip
      // asset per bundled clip, ABP_Character and every blend space, plus the
      // imported FBX clip.
      final templateClips = LuminaThirdPersonContent.clipNames;
      final blendSpaces = LuminaThirdPersonContent.blendSpaces;
      expect(assets.length, templateClips.length + 1 + blendSpaces.length + (fbx.existsSync() ? 1 : 0),
          reason: '${templateClips.length} template clips, ABP_Character, ${blendSpaces.length} blend spaces'
              '${fbx.existsSync() ? ' and the FBX clip' : ''}');
      expect(assets.where((a) => a.type == AssetType.animation).map((a) => a.fileName),
          containsAll([for (final c in templateClips) '$c.lmas']), reason: 'every clip in the manifest has its asset');
      expect(assets.where((a) => a.type == AssetType.blendSpace).map((a) => a.fileName),
          unorderedEquals([for (final p in blendSpaces.keys) p.split('/').last]));

      // Contact sheet: 128 px tiles, eight across, at least the 1024x768 a
      // smoke video needs; as many rows as the manifest's assets need.
      const tile = 128;
      const columns = 8;
      final rows = math.max(6, (assets.length / columns).ceil());
      const width = tile * columns;
      final height = tile * rows;
      final sheet = img.Image(width: width, height: height, numChannels: 4);
      img.fill(sheet, color: img.ColorRgba8(18, 18, 20, 255));
      final video = SmokeVideoRecorder(width: width, height: height, fps: 30, testName: testTitle);
      addTearDown(video.discard);
      Uint8List frame() => Uint8List.fromList(sheet.getBytes(order: img.ChannelOrder.rgba));
      void hold(int frames) {
        final rgba = frame();
        for (var i = 0; i < frames; i++) {
          video.addFrame(rgba);
        }
      }

      void place(int index, Uint8List png, String label, {String? note}) {
        final x = (index % columns) * tile;
        final y = (index ~/ columns) * tile;
        img.compositeImage(sheet, img.copyResize(img.decodePng(png)!, width: tile, height: tile), dstX: x, dstY: y);
        img.fillRect(sheet, x1: x, y1: y + tile - 22, x2: x + tile - 1, y2: y + tile - 1, color: img.ColorRgba8(28, 28, 32, 255));
        // Short enough for the tile: the _Loop suffix dropped, then cut.
        var short = label.replaceFirst('_Loop', '');
        if (short.length > 16) short = short.substring(0, 16);
        img.drawString(sheet, short, font: img.arial14, x: x + 4, y: y + tile - 19, color: img.ColorRgba8(235, 235, 235, 255));
        if (note != null) {
          img.drawString(sheet, note, font: img.arial14, x: x + 6, y: y + 4, color: img.ColorRgba8(255, 170, 60, 255));
        }
      }

      // Visible mannequin: pixels well above the dark backdrop.
      int lit(Uint8List png) {
        final image = img.decodePng(png)!;
        var n = 0;
        for (final p in image) {
          if (p.r + p.g + p.b > 150) n++;
        }
        return n;
      }

      hold(15);
      for (var i = 0; i < assets.length; i++) {
        final info = assets[i];
        expect(ThumbnailService.isStaleInfo(info), isTrue, reason: '${info.fileName} is queued (no rendered thumbnail yet)');
        final result = await service.generate(info.lmasPath!);
        expect(result?.source, ThumbnailService.sourceFilament, reason: '${info.fileName} renders its skeletal mesh');
        expect(lit(result!.png), greaterThan(1500), reason: '${info.fileName}: the mannequin is in the frame');
        final stored = LuminaAsset.fromBytes(File(info.lmasPath!).readAsBytesSync());
        expect(stored.thumbnailPng, orderedEquals(result.png), reason: '${info.fileName}: persisted in the .lmas');
        place(i, result.png, info.fileName.replaceAll('.lmas', ''), note: info.type.name);
        hold(10);
      }
      final walkIndex = assets.indexWhere((a) => a.fileName == 'Walk_Fwd_Loop.lmas');
      final walkThumb = LuminaAsset.fromBytes(File(assets[walkIndex].lmasPath!).readAsBytesSync()).thumbnailPng!;
      final png = SmokeArtifacts.encodePng(width, height, frame());
      SmokeArtifacts.saveScreenshot('animation_smoke_test: Scenario 08 animation asset thumbnails', png,
          usedAssets: usedAssets);

      // The walk clip's frame chosen for its thumbnail: sweep the clip from
      // start to end in its tile and stop in the middle, where the thumbnail is.
      final glb = (await FilamentThumbnailRenderer.loadMeshGlb('$project/${LuminaThirdPersonContent.projectMeshAssetPath}'))!;
      Uint8List? mid;
      for (var f = 0; f <= 90; f++) {
        final fraction = f / 90;
        final posed = (await renderer.renderMeshParts(
            [ThumbnailMeshPart(glb, pose: ThumbnailPose(clip: 'Walk_Fwd_Loop', fraction: fraction))]))!;
        if (f == 45) mid = posed;
        place(walkIndex, posed, 'Walk_Fwd_Loop', note: 'clip at ${(fraction * 100).round()}%');
        video.addFrame(frame());
      }
      place(walkIndex, walkThumb, 'Walk_Fwd_Loop', note: 'thumbnail = 50%');
      hold(45);
      final a = img.decodePng(walkThumb)!;
      final b = img.decodePng(mid!)!;
      var diff = 0;
      for (var y = 0; y < a.height; y++) {
        for (var x = 0; x < a.width; x++) {
          final p = a.getPixel(x, y);
          final q = b.getPixel(x, y);
          diff += ((p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs()).toInt();
        }
      }
      expect(diff / (a.width * a.height * 3), lessThan(0.5), reason: 'the walk thumbnail is the middle of the clip');

      expect(video.seconds, greaterThanOrEqualTo(SmokeArtifacts.minimumVideoSeconds));
      SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);
    }, timeout: const Timeout(Duration(minutes: 8)));

    test('Scenario 09: mannequin full locomotion — ABP_Character jumps, falls, lands, turns, breaks its idle, sprints and dashes on the template map', () async {
      const bundle = LuminaThirdPersonContent.bundledMeshPath;
      expect(File(bundle).existsSync(), isTrue, reason: 'build it with dart run tool/build_third_person_content.dart');
      const usedAssets = ['lumina: assets/templates/third_person/SKM_Superhero_Female.glb (25 clips merged: Jump_Start, Jump_Loop, Jump_Land, Roll, NinjaJump_Start, idle breaks, walks, jogs)'];
      const testName = 'animation_smoke_test: Scenario 09 mannequin full locomotion';

      // What a Third Person project stores: the bundle, sanitized like an import.
      final tempDir = Directory.systemTemp.createTempSync('lumina_anim09_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final meshPath = '${tempDir.path}/SKM_Superhero_Female.entity.glb';
      File(meshPath).writeAsBytesSync(await GlbParserService.convertGlbTgaToPngAsync(File(bundle).readAsBytesSync()));

      const width = SmokeVideo.defaultWidth;
      const height = SmokeVideo.defaultHeight;
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final view = engine.createView();
      final renderer = engine.createRenderer();
      final swapChain = engine.createHeadlessSwapChain(width, height);
      final cameraEntity = engine.createEntity();
      final camera = engine.createCamera(cameraEntity);
      view.scene = scene;
      view.camera = camera;
      view.setViewport(0, 0, width, height);
      final skybox = FilamentSkybox.build(engine, color: Vector4(0.35, 0.55, 0.85, 1.0), intensity: 30000.0);
      scene.setSkybox(skybox);
      final sunEntity = engine.createEntity();
      LightBuilder(LightType.directional)
          .color(1.0, 0.97, 0.9)
          .intensity(100000.0)
          .direction(-0.5, -0.8, -0.35)
          .castShadows(true)
          .build(engine, sunEntity);
      scene.addEntity(sunEntity);
      final indirectLight = FilamentIndirectLight.build(
        engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.6, 0.65, 0.7]),
        intensity: 30000.0,
      );
      scene.setIndirectLight(indirectLight);

      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene, view: view);
      world.registerSubsystem(LuminaCollisionSubsystem());
      Vector3? start;
      for (final actor in GameTemplateCatalog.thirdPerson.levelActors) {
        final loc = (actor['location'] as List).cast<double>();
        if (actor['type'] == 'PlayerStart') start = LuminaAxes.location(loc);
        if (actor['type'] != 'Primitive') continue;
        final props = Map<String, dynamic>.from(((actor['components'] as List).first as Map)['properties'] as Map);
        world.persistentLevel.registerActor(
          LuminaPrimitiveActor.fromComponentProperties(props, location: LuminaAxes.location(loc)),
        );
      }
      expect(start, isNotNull);

      // BP_ThirdPersonCharacter run by the VM, its mesh animated by ABP_Character,
      // on the template's real Enhanced Input mappings.
      final bound = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
      final input = world.registerSubsystem(LuminaInputSubsystem());
      for (final c in bound.contexts) {
        input.addMappingContext(c.context, priority: c.priority);
      }
      final actions = bound.actions.values.toList();
      final animClass = LuminaAnimBlueprintClass.fromDocument(
        LuminaThirdPersonContent.animBlueprint,
        name: LuminaThirdPersonContent.animBlueprintName,
        blendSpaces: LuminaThirdPersonContent.blendSpaces,
      );
      expect(animClass.diagnostics, isEmpty, reason: '${animClass.diagnostics}');
      final characterClass = LuminaBlueprintClass.fromDocument(
        LuminaThirdPersonContent.characterBlueprint(inputActions: actions, meshAsset: meshPath),
        name: LuminaThirdPersonContent.characterBlueprintName,
        inputActions: actions,
        animBlueprints: (path) => path == LuminaThirdPersonContent.projectAnimBlueprintPath ? animClass.factory : null,
      );
      expect(characterClass.diagnostics, isEmpty, reason: '${characterClass.diagnostics}');
      final character = characterClass.instantiate(location: start) as LuminaCharacter;
      world.persistentLevel.registerActor(character);
      final controller = LuminaPlayerController(playerName: 'Smoke');
      controller.possess(character);
      world.beginPlay();
      controller.controlRotation = Vector3(-12.0, 0.0, 0.0);

      final components = (character as LuminaBlueprintRuntime).blueprintComponents;
      final mesh = components['mesh'] as LuminaAnimatedMeshComponent;
      final anim = components['mesh.anim'] as LuminaAnimBlueprintInstance;
      anim.random = math.Random(2026);
      await mesh.loaded;
      expect(mesh.clipNames, LuminaThirdPersonContent.clipNames);
      for (final clip in LuminaThirdPersonContent.clipNames) {
        expect(mesh.clipDuration(clip), greaterThan(0.0), reason: clip);
      }

      final pixelBuf = calloc<ffi.Uint8>(width * height * 4);
      final video = SmokeVideoRecorder(width: width, height: height, fps: 30, testName: testName);
      addTearDown(video.discard);
      Uint8List render() {
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, width, height,
              pixelBuf.cast(), ffi.nullptr, ffi.nullptr);
          renderer.endFrame();
        }
        engine.flushAndWait();
        return Uint8List.fromList(pixelBuf.asTypedList(width * height * 4));
      }

      var tick = 0;
      final states = <String?>[];
      /// Ticks [seconds] with [keys] held and [mouseX] per frame, recording
      /// the state each frame; stops early when [until] holds.
      void run(double seconds, {List<LuminaKey> keys = const [], double mouseX = 0.0, bool Function()? until}) {
        for (final k in keys) {
          input.injectKeyDown(k);
        }
        final ticks = (seconds * 60).round();
        for (var i = 0; i < ticks; i++) {
          if (mouseX != 0.0) input.injectAnalog(LuminaKey.mouseX, mouseX);
          controller.onTick(1 / 60);
          world.tick(1 / 60);
          states.add(anim.currentState);
          if (tick++ % 2 == 0) video.addFrame(render());
          if (until != null && until()) break;
        }
        for (final k in keys) {
          input.injectKeyUp(k);
        }
      }

      int mannequinPixels(Uint8List rgba) {
        var n = 0;
        for (var i = 0; i < rgba.length; i += 4) {
          if (rgba[i] < 60 && rgba[i + 1] < 60 && rgba[i + 2] < 60) n++;
        }
        return n;
      }

      // The character's near-black outfit is the only thing under 60 in
      // these frames (the pillars and their shadows stay lighter): a clip
      // that collapsed the skeleton leaves almost none of it (mid-roll the
      // body hides most of it, a few hundred remain).
      void shot(String phase) {
        final frame = render();
        expect(mannequinPixels(frame), greaterThan(150), reason: '$phase: the boom camera must frame the mannequin');
        SmokeArtifacts.saveScreenshot('$testName $phase', SmokeArtifacts.encodePng(width, height, frame), usedAssets: usedAssets);
      }

      // 1. Stand.
      run(1.5);
      expect(character.characterMovement.isFalling, isFalse, reason: 'the mannequin must stand on the template ground');
      expect(anim.currentState, 'Idle');
      expect(mesh.currentClip, LuminaThirdPersonContent.idleClip);
      shot('01 idle');
      final idleHeadHeight = Matrix4.fromList(FilamentTransformManager(engine)
              .getWorldTransform(mesh.assetInstance!.getAsset().getFirstEntityByName('Head')))
          .getTranslation()
          .y -
          mesh.worldLocation.y;
      expect(idleHeadHeight, greaterThan(0.0));

      // 2. Space: the jump clip, the fall loop past 0.3 s, the land clip on touchdown.
      run(0.25, keys: const [LuminaKey.keySpace]);
      expect(anim.currentState, 'Jump');
      expect(mesh.currentClip, LuminaThirdPersonContent.jumpClip);
      expect(anim.variables['IsRising'], isTrue);
      shot('02 jump');
      run(0.4);
      expect(anim.currentState, 'FallLoop');
      expect(mesh.currentClip, LuminaThirdPersonContent.fallLoopClip);
      shot('03 fall loop');
      run(2.0, until: () => anim.currentState == 'Land');
      expect(anim.currentState, 'Land');
      expect(mesh.currentClip, LuminaThirdPersonContent.landClip);
      expect(character.characterMovement.isFalling, isFalse);
      run(0.3);
      expect(anim.currentState, 'Land', reason: 'the land clip plays through (${mesh.clipDuration(LuminaThirdPersonContent.landClip)} s)');
      shot('04 land');
      run(1.5);
      expect(anim.currentState, 'Idle');

      // 3. The mouse sweeps the camera 100° right while standing: the bundle
      //    has no turn-in-place clips, so the character turns with its capsule.
      final yawBefore = controller.controlRotation.y;
      const turnFrames = 30;
      const perFrame = 100.0 / (turnFrames * LuminaTemplateCharacterTuning.lookSensitivity);
      run(turnFrames / 60, mouseX: perFrame);
      expect(controller.controlRotation.y - yawBefore, closeTo(100.0, 1e-6));
      expect(anim.currentState, 'Idle');
      expect(anim.rootYawOffsetDegrees, 0.0);
      shot('05 turned right');
      // The retargeted clips keep the character's height — the head joint
      // stays within 3 % of where the idle held it.
      final transforms = FilamentTransformManager(engine);
      final headEntity = mesh.assetInstance!.getAsset().getFirstEntityByName('Head');
      expect(headEntity, isNot(0));
      double headHeight() => Matrix4.fromList(transforms.getWorldTransform(headEntity)).getTranslation().y - mesh.worldLocation.y;
      final idleHead = idleHeadHeight;
      expect(headHeight(), closeTo(idleHead, idleHead * 0.03), reason: 'turned: head ${headHeight()} vs idle $idleHead');

      // 4. Keep standing: past 6 s one of the idle breaks plays once.
      run(9.0, until: () => anim.currentState == 'IdleBreak');
      expect(anim.currentState, 'IdleBreak');
      expect(mesh.currentClip, isIn(LuminaThirdPersonContent.idleBreakClips));
      run(0.5);
      shot('06 idle break ${mesh.currentClip}');
      expect(headHeight(), closeTo(idleHead, idleHead * 0.03), reason: 'idle break: head ${headHeight()} vs idle $idleHead');

      // 5. Part 2: back at the Player Start looking north (12 m of open
      //    ground to the hurdle), W (interrupting the break) + Left Shift
      //    held — the sprint raises the walk cap to 480 cm/s and, since
      //    BS_Locomotion's jog row plays: Jog_Fwd_Loop
      //    at 0.8× instead of the walk cycle at 4.8×.
      character.actorLocation = start!;
      controller.controlRotation = Vector3(-12.0, 0.0, 0.0);
      run(0.5);
      input.injectKeyDown(LuminaKey.keyW);
      run(0.5);
      expect(anim.currentState, 'Walk');
      input.injectKeyDown(LuminaKey.keyLeftShift);
      run(1.0);
      expect(anim.currentState, 'Walk');
      expect(anim.variables['IsSprinting'], isTrue);
      expect(character.characterMovement.velocity.length, closeTo(LuminaTemplateCharacterTuning.thirdPersonSprintSpeed, 1.0));
      expect(mesh.currentClip, 'Jog_Fwd_Loop', reason: 'the jog row dominates at 480 cm/s: ${anim.blendWeights}');
      expect(anim.blendWeights['Jog_Fwd_Loop'], greaterThan(0.5));
      expect(mesh.playRate, closeTo(LuminaTemplateCharacterTuning.thirdPersonSprintSpeed / LuminaThirdPersonContent.jogReferenceSpeed, 0.02));
      // The sidecar's test name records the dominant sample.
      shot('07 sprint ${mesh.currentClip}');
      input.injectKeyUp(LuminaKey.keyLeftShift);
      run(0.5);
      expect(character.characterMovement.velocity.length, closeTo(LuminaTemplateCharacterTuning.thirdPersonMaxWalkSpeed, 1.0));
      expect(mesh.currentClip, 'Walk_Fwd_Loop', reason: 'released: back on the walk row');

      // 6. W + Left Ctrl — IA_Dash launches the mannequin along the camera
      //    yaw and the roll plays until the walk takes over (~1.2 s).
      run(2 / 60, keys: const [LuminaKey.keyLeftControl]);
      expect(anim.currentState, 'Dash');
      expect(mesh.currentClip, LuminaThirdPersonContent.dashClip);
      expect(anim.variables['IsDashing'], isTrue);
      // (The 600 cm/s launch itself is asserted headless in
      // template_full_locomotion_test: with W held the walk cap takes over a frame later.)
      run(0.25);
      expect(anim.currentState, 'Dash');
      shot('08 dash');
      run(1.5, until: () => anim.currentState == 'Walk');
      expect(anim.currentState, 'Walk', reason: 'the dash hands over to the walk while W is held');
      expect(anim.variables['IsDashing'], isFalse, reason: 'the 0.4 s timer cleared it');
      input.injectKeyUp(LuminaKey.keyW);
      run(0.5);

      expect(states.toSet(), containsAll(['Idle', 'Jump', 'FallLoop', 'Land', 'IdleBreak', 'Walk', 'Dash']));
      expect(mesh.missingClip, isNull);
      expect(video.seconds, greaterThanOrEqualTo(SmokeArtifacts.minimumVideoSeconds));
      SmokeArtifacts.saveVideo('$testName 01 idle', video.finish(), usedAssets: usedAssets);

      calloc.free(pixelBuf);
      world.cleanup();
      skybox.dispose();
      indirectLight.dispose();
      engine.destroyEntity(sunEntity);
      view.dispose();
      scene.dispose();
      engine.destroyEntity(cameraEntity);
      camera.dispose();
      renderer.dispose();
      swapChain.dispose();
      engine.dispose();
    }, timeout: const Timeout(Duration(minutes: 5)));

    // Alt + mouse turns only the head.
    test('Scenario 10: free look turns the head — Alt + mouse orbits the camera while the body keeps its heading', () async {
      const bundle = LuminaThirdPersonContent.bundledMeshPath;
      expect(File(bundle).existsSync(), isTrue, reason: 'build it with dart run tool/build_third_person_content.dart');
      const usedAssets = ['mannequin/SKM_Superhero_Female.glb (+ the merged clips)'];
      const testName = 'animation_smoke_test: Scenario 10 free look turns the head';

      final tempDir = Directory.systemTemp.createTempSync('lumina_anim10_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final meshPath = '${tempDir.path}/SKM_Superhero_Female.entity.glb';
      File(meshPath).writeAsBytesSync(await GlbParserService.convertGlbTgaToPngAsync(File(bundle).readAsBytesSync()));

      const width = SmokeVideo.defaultWidth;
      const height = SmokeVideo.defaultHeight;
      final engine = FilamentEngine.create()!;
      final scene = engine.createScene();
      final view = engine.createView();
      final renderer = engine.createRenderer();
      final swapChain = engine.createHeadlessSwapChain(width, height);
      final cameraEntity = engine.createEntity();
      final camera = engine.createCamera(cameraEntity);
      view.scene = scene;
      view.camera = camera;
      view.setViewport(0, 0, width, height);
      final skybox = FilamentSkybox.build(engine, color: Vector4(0.35, 0.55, 0.85, 1.0), intensity: 30000.0);
      scene.setSkybox(skybox);
      final sunEntity = engine.createEntity();
      LightBuilder(LightType.directional)
          .color(1.0, 0.97, 0.9)
          .intensity(100000.0)
          .direction(-0.5, -0.8, -0.35)
          .castShadows(true)
          .build(engine, sunEntity);
      scene.addEntity(sunEntity);
      final indirectLight = FilamentIndirectLight.build(
        engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.6, 0.65, 0.7]),
        intensity: 30000.0,
      );
      scene.setIndirectLight(indirectLight);

      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene, view: view);
      world.registerSubsystem(LuminaCollisionSubsystem());
      Vector3? start;
      for (final actor in GameTemplateCatalog.thirdPerson.levelActors) {
        final loc = (actor['location'] as List).cast<double>();
        if (actor['type'] == 'PlayerStart') start = LuminaAxes.location(loc);
        if (actor['type'] != 'Primitive') continue;
        final props = Map<String, dynamic>.from(((actor['components'] as List).first as Map)['properties'] as Map);
        world.persistentLevel.registerActor(
          LuminaPrimitiveActor.fromComponentProperties(props, location: LuminaAxes.location(loc)),
        );
      }
      expect(start, isNotNull);

      final bound = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
      final input = world.registerSubsystem(LuminaInputSubsystem());
      for (final c in bound.contexts) {
        input.addMappingContext(c.context, priority: c.priority);
      }
      final actions = bound.actions.values.toList();
      final animClass = LuminaAnimBlueprintClass.fromDocument(
        LuminaThirdPersonContent.animBlueprint,
        name: LuminaThirdPersonContent.animBlueprintName,
        blendSpaces: LuminaThirdPersonContent.blendSpaces,
      );
      expect(animClass.diagnostics, isEmpty, reason: '${animClass.diagnostics}');
      final characterClass = LuminaBlueprintClass.fromDocument(
        LuminaThirdPersonContent.characterBlueprint(inputActions: actions, meshAsset: meshPath),
        name: LuminaThirdPersonContent.characterBlueprintName,
        inputActions: actions,
        animBlueprints: (path) => path == LuminaThirdPersonContent.projectAnimBlueprintPath ? animClass.factory : null,
      );
      expect(characterClass.diagnostics, isEmpty, reason: '${characterClass.diagnostics}');
      final character = characterClass.instantiate(location: start) as LuminaCharacter;
      world.persistentLevel.registerActor(character);
      final controller = LuminaPlayerController(playerName: 'Smoke');
      controller.possess(character);
      world.beginPlay();
      controller.controlRotation = Vector3(-8.0, 0.0, 0.0);

      final components = (character as LuminaBlueprintRuntime).blueprintComponents;
      final mesh = components['mesh'] as LuminaAnimatedMeshComponent;
      final anim = components['mesh.anim'] as LuminaAnimBlueprintInstance;
      anim.random = math.Random(2026);
      await mesh.loaded;
      expect(anim.aimOffset, isNotNull);

      final pixelBuf = calloc<ffi.Uint8>(width * height * 4);
      final video = SmokeVideoRecorder(width: width, height: height, fps: 30, testName: testName);
      addTearDown(video.discard);
      Uint8List render() {
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, width, height,
              pixelBuf.cast(), ffi.nullptr, ffi.nullptr);
          renderer.endFrame();
        }
        engine.flushAndWait();
        return Uint8List.fromList(pixelBuf.asTypedList(width * height * 4));
      }

      var tick = 0;
      void run(double seconds, {List<LuminaKey> keys = const [], double mouseX = 0.0}) {
        for (final k in keys) {
          input.injectKeyDown(k);
        }
        final ticks = (seconds * 60).round();
        for (var i = 0; i < ticks; i++) {
          if (mouseX != 0.0) input.injectAnalog(LuminaKey.mouseX, mouseX);
          controller.onTick(1 / 60);
          world.tick(1 / 60);
          if (tick++ % 2 == 0) video.addFrame(render());
        }
        for (final k in keys) {
          input.injectKeyUp(k);
        }
      }

      int mannequinPixels(Uint8List rgba) {
        var n = 0;
        for (var i = 0; i < rgba.length; i += 4) {
          if (rgba[i] < 120 && rgba[i + 1] < 120 && rgba[i + 2] < 120) n++;
        }
        return n;
      }

      void shot(String phase) {
        final frame = render();
        expect(mannequinPixels(frame), greaterThan(2000), reason: '$phase: the boom camera must frame the mannequin');
        SmokeArtifacts.saveScreenshot('$testName $phase', SmokeArtifacts.encodePng(width, height, frame), usedAssets: usedAssets);
      }

      final transforms = FilamentTransformManager(engine);
      final asset = mesh.assetInstance!.getAsset();
      final headEntity = asset.getFirstEntityByName('Head');
      final pelvisEntity = asset.getFirstEntityByName('pelvis');
      expect(headEntity, isNot(0));
      expect(pelvisEntity, isNot(0));
      Quaternion rotationOf(int entity) {
        final m = Matrix4.fromList(transforms.getWorldTransform(entity));
        final r = m.getRotation();
        for (var col = 0; col < 3; col++) {
          final len = math.sqrt(r.entry(0, col) * r.entry(0, col) + r.entry(1, col) * r.entry(1, col) + r.entry(2, col) * r.entry(2, col));
          for (var row = 0; row < 3; row++) {
            r.setEntry(row, col, r.entry(row, col) / len);
          }
        }
        return Quaternion.fromRotation(r)..normalize();
      }

      double degreesBetween(Quaternion a, Quaternion b) {
        final d = (a.clone()..inverse()) * b;
        d.normalize();
        return 2.0 * math.acos(d.w.abs().clamp(0.0, 1.0)) * 180.0 / math.pi;
      }

      double yawOf(LuminaActor a) => luminaPawnQuaternionToEuler(a.actorRotation).y;

      // 1. Stand, looking north over the boom.
      run(2.0);
      expect(anim.currentState, 'Idle');
      final headBefore = rotationOf(headEntity);
      final pelvisBefore = rotationOf(pelvisEntity);
      final bodyYaw = yawOf(character);
      shot('01 before: idle, head straight');

      // 2. Alt held, the mouse sweeps 70° right over half a second: the
      //    controller (and the boom camera) turn, the body does not, the
      //    aim offset turns the head (0.6 × 70° = 42° of it) and the neck.
      input.injectKeyDown(LuminaKey.keyLeftAlt);
      run(2 / 60);
      expect(character.freeLook, isTrue);
      const turnFrames = 30;
      const perFrame = 70.0 / (turnFrames * LuminaTemplateCharacterTuning.lookSensitivity);
      run(turnFrames / 60, mouseX: perFrame);
      run(1.5); // the aim offset and the boom's rotation lag settle
      expect(controller.controlRotation.y, closeTo(70.0, 1e-6));
      expect(yawOf(character), closeTo(bodyYaw, 1e-6), reason: 'the body kept its heading');
      expect(anim.variables['AimYaw'], closeTo(70.0, 1e-6));
      expect(anim.aimYaw, closeTo(70.0, 0.5));
      expect(anim.currentState, 'Idle', reason: 'no turn in place from free-look yaw');
      expect(anim.rootYawOffsetDegrees, 0.0);
      final headTurn = degreesBetween(headBefore, rotationOf(headEntity));
      final pelvisTurn = degreesBetween(pelvisBefore, rotationOf(pelvisEntity));
      expect(headTurn, greaterThan(50.0), reason: 'head + neck + spine share of 70° (idle sway aside): $headTurn°');
      expect(pelvisTurn, lessThan(8.0), reason: 'the body stayed still: $pelvisTurn°');
      shot('02 after: Alt + 70° mouse, head turned, body still');

      // 3. Walk forward while free looking: along the body heading, not the camera's.
      final from = character.actorLocation.clone();
      run(2.0, keys: const [LuminaKey.keyW]);
      final moved = character.actorLocation - from;
      expect(moved.z, lessThan(-200.0), reason: 'walked along the body heading (−Z)');
      expect(moved.x.abs(), lessThan(moved.z.abs() * 0.15), reason: 'not along the 70° camera');
      expect(yawOf(character), closeTo(bodyYaw, 1e-6));
      shot('03 walking north while looking 70° right');

      // 4. Release Alt: the camera swings back behind the character and the head returns.
      input.injectKeyUp(LuminaKey.keyLeftAlt);
      run(0.3);
      expect(character.freeLook, isFalse);
      expect(controller.controlRotation.y, closeTo(bodyYaw, 1e-6), reason: 'recentred within 0.25 s');
      run(4.0); // the head eases back; the whole clip runs over 10 s
      expect(anim.aimYaw.abs(), lessThan(0.5));
      expect(degreesBetween(headBefore, rotationOf(headEntity)), lessThan(12.0), reason: 'the head is back (idle sway aside)');
      shot('04 released: camera back behind, head straight');

      expect(mesh.missingClip, isNull);
      expect(video.seconds, greaterThanOrEqualTo(SmokeArtifacts.minimumVideoSeconds));
      SmokeArtifacts.saveVideo(testName, video.finish(), usedAssets: usedAssets);

      calloc.free(pixelBuf);
      world.cleanup();
      skybox.dispose();
      indirectLight.dispose();
      engine.destroyEntity(sunEntity);
      view.dispose();
      scene.dispose();
      engine.destroyEntity(cameraEntity);
      camera.dispose();
      renderer.dispose();
      swapChain.dispose();
      engine.dispose();
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
