import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'pose_fixture.dart';

void main() {
  /// A run posed with a raised hand, a turned head and a bent spine.
  PoseRun posed() {
    final r = PoseRun(LuminaPoseRig.detect(metahumanSkeleton()), mesh: meshAt(Vector3(5, 0, 5)));
    r.component.setHandleTarget('hand_r', r.at('upperarm_r') + Vector3(-15, 35, 20));
    r.component.setHandleTarget('chest', r.component.handleWorldLocation('chest')! + Vector3(0, -3, 10));
    r.component.setHandleTarget('head', r.component.handleWorldLocation('head')! + Vector3(8, 0, 0));
    r.tick();
    return r;
  }

  void expectSameRotations(PoseRun r, AuthoredPose pose, double tolerance) {
    for (final e in pose.bones.entries) {
      final q = r.localRotation(e.key);
      // q and −q are the same rotation.
      final d = (q.x * e.value.r.x + q.y * e.value.r.y + q.z * e.value.r.z + q.w * e.value.r.w).abs();
      expect(1 - d, lessThan(tolerance), reason: e.key);
    }
  }

  test('toAuthoredPose → reset → applyAuthoredPose reproduces every local rotation', () {
    final r = posed();
    final pose = r.component.toAuthoredPose('Wave');
    expect(pose.name, 'Wave');
    expect(pose.bones.keys, containsAll(['upperarm_r', 'lowerarm_r', 'hand_r', 'spine_03', 'neck_02']));
    r.component.resetToReference();
    r.tick();
    expect(r.component.handles.values.where((h) => h.hasTarget), isEmpty);
    // Back at the reference pose.
    final rest = r.rig.restPoseCopy();
    for (var i = 0; i < r.rig.length * 10; i++) {
      expect(r.pose[i], closeTo(rest[i], 1e-9));
    }
    r.component.applyAuthoredPose(pose);
    r.tick();
    expectSameRotations(r, pose, 1e-10);
    // Every component of every rotation within 1e-5.
    for (final e in pose.bones.entries) {
      final q = r.localRotation(e.key);
      final sign = q.w * e.value.r.w + q.x * e.value.r.x + q.y * e.value.r.y + q.z * e.value.r.z < 0 ? -1.0 : 1.0;
      expect((q.x * sign - e.value.r.x).abs(), lessThan(1e-5));
      expect((q.w * sign - e.value.r.w).abs(), lessThan(1e-5));
    }
  });

  test('applyAuthoredPose blends in over its blend time', () {
    final r = posed();
    final pose = r.component.toAuthoredPose('Wave');
    r.component.resetToReference();
    r.tick();
    r.component.applyAuthoredPose(pose, blendSeconds: 0.5);
    r.tick(15); // a quarter of a second at 60 Hz
    final half = r.localRotation('lowerarm_r');
    final rest = r.rig.restPoseCopy();
    final o = r.rig.slotNamed('lowerarm_r') * 10;
    final restQ = Quaternion(rest[o + 3], rest[o + 4], rest[o + 5], rest[o + 6]);
    final full = pose.bones['lowerarm_r']!.r;
    final total = angleBetween(restQ, full);
    expect(angleBetween(restQ, half), closeTo(total / 2, total * 0.05));
    r.tick(30);
    expectSameRotations(r, pose, 1e-10);
  });

  test('a save game slot round-trip in a temp directory returns the same pose', () async {
    final dir = Directory.systemTemp.createTempSync('pose_slot_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final saves = LuminaSaveGameSubsystem(saveDirectoryPath: dir.path);
    final pose = posed().component.toAuthoredPose('Wave');
    expect(await LuminaPoseLibrary.saveToSlot(saves, 'Poses', 'Wave', pose), isTrue);
    // A second pose in the same slot keeps the first.
    expect(await LuminaPoseLibrary.saveToSlot(saves, 'Poses', 'Rest', AuthoredPose('Rest', const {})), isTrue);
    final back = await LuminaPoseLibrary.loadFromSlot(saves, 'Poses', 'Wave');
    expect(back, isNotNull);
    expect(back!.toJson(), pose.toJson());
    expect(await LuminaPoseLibrary.loadFromSlot(saves, 'Poses', 'Missing'), isNull);
    final r = PoseRun(LuminaPoseRig.detect(metahumanSkeleton()));
    r.component.applyAuthoredPose(back);
    r.tick();
    expectSameRotations(r, pose, 1e-10);
  });

  test("a project's PoseLibrary.lmas loads through the asset provider", () async {
    final dir = Directory.systemTemp.createTempSync('pose_lib_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pose = posed().component.toAuthoredPose('Wave');
    final rel = await LuminaPoseLibrary.saveToProject(dir.path, '${dir.path}/contents/meshes/SKM_MH.lmas', 'Wave', pose);
    expect(rel, 'contents/animations/SKM_MH/PoseLibrary.lmas');
    final library = await LuminaPoseLibrary.load(rel, provider: (path) => File('${dir.path}/$path').readAsBytes());
    expect(library.meshRelPath, 'contents/meshes/SKM_MH.lmas');
    expect(library.pose('Wave')!.toJson(), pose.toJson());
    // An empty container reads as an empty library.
    final empty = LuminaPoseLibrary.parse(Uint8List.fromList(
        LuminaAsset(assetId: 'x', name: 'PoseLibrary', type: AssetType.unknown, metadata: const {'source_mesh': 'm.glb'})
            .toProtoBufferBytes()));
    expect(empty.poses, isEmpty);
    expect(empty.meshRelPath, 'm.glb');
  });
}
