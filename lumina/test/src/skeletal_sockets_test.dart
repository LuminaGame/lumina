import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaSocket and SkeletalMeshComponent Sockets', () {
    late LuminaSkinnedMeshComponent meshComponent;
    late Skeleton skeleton;

    setUp(() {
      meshComponent = LuminaSkinnedMeshComponent();
      // Setup skeleton with a few bones
      // root -> spine -> hand (translate(0, 1, 0)) -> finger
      final bones = [
        BoneNode(name: 'root', id: -1)..translation.setValues(0, 0, 0)..composeLocal(),
        BoneNode(name: 'spine', id: 0)..translation.setValues(0, 0, 0)..composeLocal(),
        BoneNode(name: 'hand', id: 1)..translation.setValues(0, 1, 0)..composeLocal(),
        BoneNode(name: 'finger', id: 2)..translation.setValues(0, 0.5, 0)..composeLocal(),
        BoneNode(name: 'toe_r', id: 0)..translation.setValues(1, -1, 0)..composeLocal(),
      ];
      skeleton = Skeleton(bones);
      skeleton.updateGlobalTransforms();
      meshComponent.setSkeleton(skeleton);
      // Put component at (5, 0, 0)
      meshComponent.location = Vector3(5, 0, 0);
    });

    test('getSocketLocation computes entity + bone + local correctly', () {
      final socket = LuminaSocket.at('hand_r', 'hand');
      meshComponent.addSocket(socket);

      // Bone "hand" is at (0, 1, 0) relative to root. Component is at (5, 0, 0).
      // So world socket should be (5, 1, 0).
      final loc = meshComponent.getSocketLocation('hand_r');
      expect(loc.x, closeTo(5.0, 1e-6));
      expect(loc.y, closeTo(1.0, 1e-6));
      expect(loc.z, closeTo(0.0, 1e-6));
    });

    test('Offset chain order: rotated entity and offset', () {
      // Offset translate (1, 0, 0)
      final socket = LuminaSocket.at(
        'hand_offset',
        'hand',
        translation: Vector3(1, 0, 0),
      );
      meshComponent.addSocket(socket);

      // Rotate bone 'hand' 90 degrees yaw
      skeleton[2].rotation.setFrom(Quaternion.axisAngle(Vector3(0, 1, 0), 1.57079632679)); // 90 deg
      skeleton[2].composeLocal();
      skeleton.updateGlobalTransforms();

      // The entity is at (5,0,0). Bone is translated (0,1,0), rotated 90 yaw.
      // Socket local offset is (1,0,0).
      // 90 deg yaw rotates (1,0,0) to (0,0,-1).
      // World should be (5,0,0) + (0,1,0) + (0,0,-1) = (5, 1, -1).
      final loc = meshComponent.getSocketLocation('hand_offset');
      expect(loc.x, closeTo(5.0, 1e-5));
      expect(loc.y, closeTo(1.0, 1e-5));
      expect(loc.z, closeTo(-1.0, 1e-5));
      
      // Now rotate entity 90 yaw as well
      meshComponent.rotation = Quaternion.axisAngle(Vector3(0, 1, 0), 1.57079632679);
      // Entity rotates everything by 90 yaw.
      // (0,1,0) -> (0,1,0). (0,0,-1) -> (-1,0,0).
      // World loc should be (5,0,0) + (-1, 1, 0) = (4, 1, 0).
      final loc2 = meshComponent.getSocketLocation('hand_offset');
      expect(loc2.x, closeTo(4.0, 1e-5));
      expect(loc2.y, closeTo(1.0, 1e-5));
      expect(loc2.z, closeTo(0.0, 1e-5));
    });

    test('Compound rotations', () {
      final socket = LuminaSocket.at('rot_socket', 'hand', rotation: Quaternion.axisAngle(Vector3(1, 0, 0), 0.5));
      meshComponent.addSocket(socket);
      
      meshComponent.rotation = Quaternion.axisAngle(Vector3(0, 1, 0), 0.3);
      skeleton[2].rotation.setFrom(Quaternion.axisAngle(Vector3(0, 0, 1), 0.4));
      skeleton[2].composeLocal();
      skeleton.updateGlobalTransforms();
      
      final expectedRot = Quaternion.axisAngle(Vector3(0, 1, 0), 0.3) *
          Quaternion.axisAngle(Vector3(0, 0, 1), 0.4) *
          Quaternion.axisAngle(Vector3(1, 0, 0), 0.5);
          
      final rot = meshComponent.getSocketRotation('rot_socket');
      
      expect(rot.x, closeTo(expectedRot.x, 1e-5));
      expect(rot.y, closeTo(expectedRot.y, 1e-5));
      expect(rot.z, closeTo(expectedRot.z, 1e-5));
      expect(rot.w, closeTo(expectedRot.w, 1e-5));
    });

    test('Registry validations (bad bone, duplicates, removal)', () {
      expect(
        () => meshComponent.addSocket(LuminaSocket.at('s1', 'toe_l')),
        throwsA(isA<ArgumentError>()),
        reason: 'Unknown bone should throw',
      );

      meshComponent.addSocket(LuminaSocket.at('s1', 'hand'));
      
      expect(
        () => meshComponent.addSocket(LuminaSocket.at('s1', 'spine')),
        throwsA(isA<ArgumentError>()),
        reason: 'Duplicate name should throw',
      );

      expect(meshComponent.removeSocket('s1'), isTrue);
      expect(meshComponent.findSocket('s1'), isNull);
    });

    test('getSocketWorldTransform bounds check throws RangeError', () {
      expect(
        () => meshComponent.getSocketWorldTransform(99, Matrix4.identity()),
        throwsRangeError,
      );
    });

    test('Follower updates per tick', () {
      final socket = LuminaSocket.at('hand_r', 'hand');
      meshComponent.addSocket(socket);
      
      final follower = LuminaSceneComponent();
      // Should reparent to meshComponent
      meshComponent.attachToSocket(follower, 'hand_r');
      
      // Tick 1
      skeleton[2].translation.setValues(0, 2, 0);
      skeleton[2].composeLocal();
      meshComponent.onTick(0.016);
      
      // mesh is at 5,0,0; bone is at 0,2,0 -> socket is 5,2,0
      expect(follower.worldLocation.x, closeTo(5.0, 1e-5));
      expect(follower.worldLocation.y, closeTo(2.0, 1e-5));
      expect(follower.worldLocation.z, closeTo(0.0, 1e-5));
      
      // Tick 2
      skeleton[2].translation.setValues(0, 3, 0);
      skeleton[2].composeLocal();
      meshComponent.onTick(0.016);
      expect(follower.worldLocation.y, closeTo(3.0, 1e-5));
    });

    test('Follower offset (relativeOffset)', () {
      final socket = LuminaSocket.at('hand_r', 'hand');
      meshComponent.addSocket(socket);
      
      final follower = LuminaSceneComponent();
      final offset = Matrix4.translationValues(0, 0.1, 0);
      meshComponent.attachToSocket(follower, 'hand_r', relativeOffset: offset);
      
      meshComponent.onTick(0.016);
      
      // mesh 5,0,0; hand 0,1,0; offset 0,0.1,0 -> follower 5, 1.1, 0
      expect(follower.worldLocation.y, closeTo(1.1, 1e-5));
    });

    test('detachFromSocket', () {
      final socket = LuminaSocket.at('hand_r', 'hand');
      meshComponent.addSocket(socket);
      final follower = LuminaSceneComponent();
      meshComponent.attachToSocket(follower, 'hand_r');
      
      meshComponent.onTick(0.016);
      expect(follower.worldLocation.y, closeTo(1.0, 1e-5));
      
      meshComponent.detachFromSocket(follower);
      
      skeleton[2].translation.setValues(0, 3, 0);
      skeleton[2].composeLocal();
      meshComponent.onTick(0.016);
      // Follower no longer moves
      expect(follower.worldLocation.y, closeTo(1.0, 1e-5));
    });

    test('Zero steady-state allocation check', () {
      meshComponent.addSocket(LuminaSocket.at('hand_r', 'hand'));
      final out = Matrix4.identity();
      final result = meshComponent.getSocketTransformByName('hand_r', out: out);
      
      expect(identical(result, out), isTrue);
    });

    test('Missing skeleton behavior', () {
      final comp = LuminaSkinnedMeshComponent();
      // Since attach checks socket, attach before removal
      comp.setSkeleton(skeleton);
      comp.addSocket(LuminaSocket.at('s1', 'hand'));
      
      comp.setSkeleton(null);
      
      expect(() => comp.getSocketLocation('s1'), throwsStateError);
      
      final follower = LuminaSceneComponent();
      // Since attach checks socket, attach before removal
      comp.setSkeleton(skeleton);
      comp.attachToSocket(follower, 's1');
      comp.setSkeleton(null);
      
      // Ticking should not throw
      expect(() => comp.onTick(0.016), returnsNormally);
    });
  });
}
