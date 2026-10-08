import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

final String _assets =
    Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';
final File _manny = File('$_assets/mannequin/SKM_Manny_Simple.glb');

void main() {
  group('physics asset data', () {
    test('round-trips the editor keys and keeps unknown keys', () {
      final json = {
        'v': 2,
        'world_units': 'cm',
        'bodies': [
          {
            'bone': 'pelvis',
            'shape': 'capsule',
            'radius': 12.0,
            'half_height': 20.0,
            'half_extents': [10.0, 10.0, 10.0],
            'offset_t': [1.0, 2.0, 3.0],
            'offset_r': [10.0, 20.0, 30.0],
            'mass_kg': 11.5,
            'linear_damping': 0.05,
            'angular_damping': 0.6,
            'physics_material': 'Flesh',
            'custom_note': 'kept',
          },
        ],
        'constraints': [
          {
            'body_a': 'pelvis',
            'body_b': 'calf_l',
            'angular_mode': 'limited',
            'swing1_deg': 0.0,
            'swing2_deg': 0.0,
            'twist_deg': 140.0,
            'type': 'hinge',
            'twist_min_deg': -2.0,
            'twist_max_deg': 140.0,
            'frame_r': [0.0, 90.0, 0.0],
          },
        ],
        'disabled_collision_pairs': [
          ['pelvis', 'thigh_l'],
        ],
        'author_tool': 'x',
      };
      final data = LuminaPhysicsAssetData.fromJson(json);
      expect(data.bodies.single.massKg, 11.5);
      expect(data.constraints.single.type, LuminaPhysicsJointType.hinge);
      expect(data.constraints.single.effectiveTwistMin, -2.0);
      expect(data.isPairDisabled('thigh_l', 'pelvis'), isTrue);
      final back = jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>;
      expect(back['bodies'][0]['custom_note'], 'kept');
      expect(back['author_tool'], 'x');
      expect(back['constraints'][0]['frame_r'], [0.0, 90.0, 0.0]);
      expect(LuminaPhysicsAssetData.fromJson(back).toJson(), data.toJson());
    });

    test('a schema 1 document in metres reads as centimetres', () {
      final data = LuminaPhysicsAssetData.fromJson({
        'v': 1,
        'bodies': [
          {'bone': 'head', 'shape': 'sphere', 'radius': 0.1, 'half_height': 0.2, 'offset_t': [0.0, 0.05, 0.0]},
        ],
      });
      expect(data.bodies.single.radius, closeTo(10.0, 1e-9));
      expect(data.bodies.single.offsetLocation[1], closeTo(5.0, 1e-9));
    });

    test('Euler conversion round-trips', () {
      final r = math.Random(3);
      for (var i = 0; i < 200; i++) {
        final e = [r.nextDouble() * 170 - 85, r.nextDouble() * 340 - 170, r.nextDouble() * 340 - 170];
        final q = LuminaPhysicsAssetData.eulerToQuaternion(e);
        final back = LuminaPhysicsAssetData.eulerToQuaternion(LuminaPhysicsAssetData.quaternionToEuler(q));
        final dot = (q.x * back.x + q.y * back.y + q.z * back.z + q.w * back.w).abs();
        expect(dot, closeTo(1.0, 1e-9));
      }
    });
  });

  group('generator', () {
    test('builds a humanoid physics asset on the mannequin\'s main bones', () {
      final sampler = LuminaGlbAnimationSampler.fromGlb(_manny.readAsBytesSync());
      final data = LuminaPhysicsAssetGenerator.fromSampler(sampler);
      final bones = data.bodies.map((b) => b.bone).toList();
      expect(bones.length, inInclusiveRange(15, 19));
      for (final b in bones) {
        expect(b, isNot(anyOf(contains('twist'), contains('ik_'), contains('index'), contains('thumb'))));
      }
      expect(bones, containsAll(['pelvis', 'head', 'thigh_l', 'calf_r', 'hand_l', 'foot_r', 'upperarm_r']));
      expect(data.totalMassKg, closeTo(80.0, 1e-6));
      expect(data.constraints.length, bones.length - 1);
      for (final b in bones.where((b) => b != 'pelvis')) {
        expect(data.constraints.where((c) => c.bodyB == b), hasLength(1), reason: b);
      }
      final hinges = data.constraints.where((c) => c.type == LuminaPhysicsJointType.hinge).map((c) => c.bodyB).toSet();
      expect(hinges, {'calf_l', 'calf_r', 'lowerarm_l', 'lowerarm_r'});
      expect(data.constraints.firstWhere((c) => c.bodyB == 'thigh_l').bodyA, 'pelvis');
      expect(data.constraints.firstWhere((c) => c.bodyB == 'head').bodyA, 'spine_04');
      // Thighs touch the pelvis at rest: that pair never collides.
      expect(data.isPairDisabled('pelvis', 'thigh_l'), isTrue);
      expect(data.isPairDisabled('hand_l', 'thigh_r'), isFalse);
    });

    test('knee hinges bend the shin backward, elbows bend the forearm forward', () {
      final sampler = LuminaGlbAnimationSampler.fromGlb(_manny.readAsBytesSync());
      final skeleton = LuminaSkeletonRest.fromSampler(sampler);
      final data = LuminaPhysicsAssetGenerator.fromSkeleton(skeleton);
      final p = skeleton.positions;
      Vector3 at(String n) => p[skeleton.indexOf(n)];
      final up = (at('head') - at('pelvis'))..normalize();
      final forward = (at('ball_l') - at('foot_l'))..sub(up * (at('ball_l') - at('foot_l')).dot(up));
      forward.normalize();
      Vector3 bend(String child, String grandChild) {
        final c = data.constraints.firstWhere((c) => c.bodyB == child);
        final frame = skeleton.rotations[skeleton.indexOf(child)] * c.frameQuaternion;
        final axis = Vector3(1, 0, 0)..applyQuaternion(frame);
        final d = (at(grandChild) - at(child))..normalize();
        // A small positive turn about the hinge axis moves the segment toward:
        return axis.cross(d);
      }

      expect(bend('calf_l', 'foot_l').dot(forward), lessThan(-0.5));
      expect(bend('calf_r', 'foot_r').dot(forward), lessThan(-0.5));
      expect(bend('lowerarm_l', 'hand_l').dot(forward), greaterThan(0.5));
      expect(bend('lowerarm_r', 'hand_r').dot(forward), greaterThan(0.5));
    });

    test('a skeleton without a pelvis cannot be generated', () {
      final s = LuminaSkeletonRest(['a'], Int32List.fromList([-1]), [Quaternion.identity()], [Vector3.zero()]);
      expect(() => LuminaPhysicsAssetGenerator.fromSkeleton(s), throwsStateError);
    });
  }, skip: _manny.existsSync() ? false : 'test-assets/mannequin/SKM_Manny_Simple.glb is missing');
}
