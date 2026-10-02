import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/transform_gizmo.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/sub_editor_transform_gizmo.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/animation_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Quaternion, Vector3;

import '../helpers/temp_project.dart';

/// The posing and cycle tools of an authored Animation Sequence: onion
/// skins, pose copy / paste / mirror, loop helpers, the pose library,
/// two-bone IK baked to rotation keys and root motion authoring, each edit
/// one undo step.
void main() {
  final assets = Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');
  final mannyGlb = File('${assets.path}/mannequin/SKM_Manny_Simple.glb');
  const meshRel = 'contents/meshes/skeletal/SKM_Manny_Simple.lmas';

  late Directory project;
  var counter = 0;

  setUpAll(() {
    project = Directory.systemTemp.createTempSync('lumina_anim_pose_tools_');
    Directory('${project.path}/contents/meshes/skeletal').createSync(recursive: true);
    if (!mannyGlb.existsSync()) return;
    File('${project.path}/$meshRel').writeAsBytesSync(LuminaAsset(
      assetId: 'manny-mesh',
      name: 'SKM_Manny_Simple',
      type: AssetType.filameshSk,
      rawPayload: mannyGlb.readAsBytesSync(),
      metadata: const {'payload_format': 'glb'},
    ).toProtoBufferBytes());
  });
  tearDownAll(() => deleteTempProject(project));

  Future<AnimationEditorViewModel> newSequence({int lengthFrames = 30}) async {
    final rel = AnimGraphAssetService.createAnimationSequence(project.path,
        name: 'Tools_${++counter}', meshRelPath: meshRel, lengthFrames: lengthFrames, frameRate: 30);
    final vm = AnimationEditorViewModel(assetPath: '${project.path}/$rel');
    await vm.load();
    return vm;
  }

  Quaternion rotOf(Matrix4 m) {
    final t = Vector3.zero();
    final r = Quaternion.identity();
    final s = Vector3.zero();
    m.decompose(t, r, s);
    return r..normalize();
  }

  /// Degrees between two rotations (GLB rest rotations are float32 and not
  /// quite unit length).
  double angle(Quaternion a, Quaternion b) =>
      2 * math.acos(((a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w) / (a.length * b.length)).abs().clamp(0.0, 1.0)) * 180 / math.pi;

  Matrix4 world(AnimationEditorViewModel vm, String bone) => vm.skeleton!.worldMatrices(vm.currentNodePose)[vm.skeleton!.indexOf(bone)];

  /// Turns [bone] by [degrees] about the runtime-frame world [axis] through
  /// the gizmo path (Auto Key on keys it at the playhead).
  void turn(AnimationEditorViewModel vm, String bone, Vector3 axis, double degrees) {
    vm.selectBone(bone);
    vm.beginBonePose(bone);
    vm.previewGizmoDelta(SubEditorGizmoDelta.rotate(AuthoringRotation.toAuthoring(axis), degrees));
    vm.endBonePose();
  }

  Vector3 forwardOf(AnimationEditorViewModel vm) => Vector3(0, 1, 0).cross(vm.mirrorTable!.lateralAxis).normalized();

  test('onion skin: keys at 0, 15, 30 with the playhead at 20 ghost 15 before and 30 after, in their poses', () async {
    if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
    final vm = await newSequence();
    final fwd = forwardOf(vm);
    for (final (f, deg) in [(0, 0.0), (15, 30.0), (30, 60.0)]) {
      vm.seek(f / 30);
      turn(vm, 'upperarm_r', fwd, deg == 0 ? 1 : deg);
    }
    expect(vm.authoredClip!.keyFrames('upperarm_r'), [0, 15, 30]);
    vm.seek(20 / 30);
    expect(vm.ghostPoses, isEmpty, reason: 'off by default');
    vm.setOnionSkin(enabled: true);
    final ghosts = vm.ghostPoses;
    expect([for (final g in ghosts) (g.frame, g.before)], [(15, true), (30, false)]);
    for (final g in ghosts) {
      final sampled = vm.authoredClip!.sample('upperarm_r', AuthoredChannel.rotation, g.frame / 30)!;
      expect(g.jointLocalPose['upperarm_r']!.sublist(3, 7), sampled);
      expect(g.opacity, closeTo(vm.onionSkin.opacity, 1e-9));
    }
    vm.setOnionSkin(before: 2, after: 2);
    expect([for (final g in vm.ghostPoses) g.frame], [15, 0, 30]);
    vm.setOnionSkin(enabled: false);
    expect(vm.ghostPoses, isEmpty);
    vm.dispose();
  });

  test('copy the pose at 0 and paste it at 30: frame 30 equals frame 0 on the copied bones, one undo step', () async {
    if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
    final vm = await newSequence();
    final fwd = forwardOf(vm);
    turn(vm, 'upperarm_r', fwd, 50);
    turn(vm, 'head', Vector3(0, 1, 0), 25);
    vm.seek(1.0);
    turn(vm, 'upperarm_r', fwd, -20);
    vm.seek(0);
    final at0 = Map.of(vm.currentNodePose);
    vm.copyPose();
    expect(vm.hasPoseClipboard, isTrue);
    vm.seek(1.0);
    final steps = vm.transactions.history().length;
    vm.pastePose();
    expect(vm.transactions.history().length, steps + 1);
    final at30 = vm.authoredClip!.samplePose(vm.skeleton!, 1.0);
    for (final bone in ['upperarm_r', 'head', 'lowerarm_r', 'pelvis']) {
      final n = vm.skeleton!.indexOf(bone);
      expect(angle(at30[n]!.r, at0[n]!.r), lessThan(0.01), reason: bone);
      expect((at30[n]!.t - at0[n]!.t).length, lessThan(1e-6), reason: bone);
    }
    vm.undo();
    expect(angle(vm.authoredClip!.samplePose(vm.skeleton!, 1.0)[vm.skeleton!.indexOf('upperarm_r')]!.r,
            at0[vm.skeleton!.indexOf('upperarm_r')]!.r),
        greaterThan(10));
    vm.dispose();
  });

  test('Paste Mirrored puts the raised right arm on the left arm and flips the head yaw', () async {
    if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
    final vm = await newSequence();
    final fwd = forwardOf(vm);
    turn(vm, 'upperarm_r', fwd, 60);
    final headRest = rotOf(world(vm, 'head'));
    turn(vm, 'head', Vector3(0, 1, 0), 30);
    final handR = world(vm, 'hand_r').getTranslation();
    final mirror = vm.mirrorTable!;
    vm.copyPose();
    vm.pastePose(mirrored: true);
    expect(vm.authoredClip!.hasKey('upperarm_l', 0, AuthoredChannel.rotation), isTrue);
    expect((world(vm, 'hand_l').getTranslation() - mirror.mirrorPoint(handR)).length, lessThan(0.005),
        reason: 'the left hand is where the right one was, mirrored');
    final yaw = rotOf(world(vm, 'head')) * headRest.conjugated();
    expect(angle(yaw, Quaternion.axisAngle(Vector3(0, 1, 0), -30 * math.pi / 180)), lessThan(0.1));
    // Translations stay rotations-only here.
    expect(vm.authoredClip!.channel('upperarm_l', AuthoredChannel.translation), isNull);

    // Mirror Selected copies the selected arm onto the other side.
    vm.undo();
    vm.selectBone('upperarm_r');
    vm.mirrorSelected();
    expect((world(vm, 'hand_l').getTranslation() - mirror.mirrorPoint(handR)).length, lessThan(0.005));
    expect(vm.authoredClip!.hasKey('lowerarm_l', 0, AuthoredChannel.rotation), isTrue,
        reason: 'a mirrored selection keys every rotation, so a later key cannot move this frame');
    expect(angle(rotOf(world(vm, 'head')) * headRest.conjugated(), Quaternion.axisAngle(Vector3(0, 1, 0), 30 * math.pi / 180)),
        lessThan(0.1), reason: 'the head is not part of the selection');
    vm.dispose();
  });

  test('Copy First → Last makes the last frame equal frame 0; Match Selected to First does it for the selection', () async {
    if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
    final vm = await newSequence();
    final fwd = forwardOf(vm);
    turn(vm, 'upperarm_r', fwd, 40);
    turn(vm, 'head', Vector3(0, 1, 0), 20);
    vm.seek(0.5);
    turn(vm, 'upperarm_r', fwd, 30);
    turn(vm, 'head', Vector3(0, 1, 0), -40);
    vm.seek(1.0);
    turn(vm, 'head', Vector3(0, 1, 0), 15);
    expect(vm.loopSeamDegrees, greaterThan(1));

    vm.selectBone('upperarm_r');
    vm.matchSelectedToFirst();
    final clip = vm.authoredClip!;
    expect(clip.sample('upperarm_r', AuthoredChannel.rotation, 1.0), clip.sample('upperarm_r', AuthoredChannel.rotation, 0));
    expect(clip.sample('head', AuthoredChannel.rotation, 1.0), isNot(clip.sample('head', AuthoredChannel.rotation, 0)));

    final steps = vm.transactions.history().length;
    vm.copyFirstToLast();
    expect(vm.transactions.history().length, steps + 1);
    for (final bone in vm.authoredClip!.bones) {
      for (final ch in vm.authoredClip!.tracks[bone]!.values) {
        final first = ch.sample(0);
        final last = ch.sample(30);
        for (var i = 0; i < first.length; i++) {
          expect(last[i], closeTo(first[i], 1e-12), reason: '$bone ${ch.path}');
        }
      }
    }
    final skel = vm.skeleton!;
    final p0 = vm.authoredClip!.samplePose(skel, 0);
    final pEnd = vm.authoredClip!.samplePose(skel, vm.authoredClip!.duration);
    for (final n in skel.joints) {
      expect(angle(p0[n]!.r, pEnd[n]!.r), lessThan(1e-4));
    }
    expect(vm.loopSeamDegrees, lessThan(1e-4));
    vm.setShowLoopSeam(true);
    vm.seek(1.0);
    expect(vm.ghostPoses.where((g) => g.seam).map((g) => g.frame), [0], reason: 'the seam ghost shows frame 0');
    vm.dispose();
  });

  test('two-bone IK: a hand target 10 cm forward is reached, elbow towards the pole, keyed as rotations only', () async {
    if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
    final vm = await newSequence();
    expect(vm.ikChains.map((c) => c.name), containsAll(['LeftArm', 'RightArm', 'LeftLeg', 'RightLeg']));
    vm.seek(0.5);
    vm.setIkMode(true);
    vm.selectIkChain('RightArm');
    final fwd = forwardOf(vm);
    final shoulder = world(vm, 'upperarm_r').getTranslation();
    final hand = vm.ikTargetPosition!;
    expect((hand - world(vm, 'hand_r').getTranslation()).length, lessThan(1e-9), reason: 'the target starts on the hand');
    final pole = world(vm, 'lowerarm_r').getTranslation() - fwd * 0.5;
    vm.setIkPole(pole);
    final target = hand + fwd * 0.10;
    expect(vm.ikGizmoTarget!.id, 'ik:RightArm');
    final steps = vm.transactions.history().length;
    vm.beginIkDrag();
    vm.previewIkDelta(SubEditorGizmoDelta.translate(AuthoringRotation.toAuthoring(fwd * 0.05)));
    vm.previewIkDelta(SubEditorGizmoDelta.translate(AuthoringRotation.toAuthoring(fwd * 0.10)));
    vm.endIkDrag();
    expect(vm.transactions.history().length, steps + 1, reason: 'one undo step');
    expect((world(vm, 'hand_r').getTranslation() - target).length, lessThan(0.005));
    final elbow = world(vm, 'lowerarm_r').getTranslation();
    final line = (target - shoulder).normalized();
    Vector3 across(Vector3 v) => v - line * v.dot(line);
    expect(across(elbow - shoulder).dot(across(pole - shoulder)), greaterThan(0));
    final clip = vm.authoredClip!;
    for (final bone in ['upperarm_r', 'lowerarm_r', 'hand_r']) {
      expect(clip.tracks[bone]!.keys, [AuthoredChannel.rotation], reason: '$bone is keyed as a rotation only');
      expect(clip.keyFrames(bone), [15]);
    }
    vm.undo();
    expect(vm.authoredClip!.tracks.containsKey('upperarm_r'), isFalse);
    vm.dispose();
  });

  test('pinning a foot over a range keeps it where it was while the pelvis drops, baked to rotation keys', () async {
    if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
    final vm = await newSequence();
    final skel = vm.skeleton!;
    final foot0 = world(vm, 'foot_l').getTranslation();
    // The pelvis drops 15 cm at frame 15 and is back at 30.
    vm.selectBone('pelvis');
    vm.keyPendingOrSelected();
    vm.seek(1.0);
    vm.keyPendingOrSelected();
    vm.seek(0.5);
    vm.beginBonePose('pelvis');
    vm.previewGizmoDelta(SubEditorGizmoDelta.translate(AuthoringRotation.toAuthoring(Vector3(0, -0.15, 0))));
    vm.endBonePose();
    expect(vm.authoredClip!.keyFrames('pelvis'), [0, 15, 30]);
    vm.seek(0.5);
    expect((world(vm, 'foot_l').getTranslation() - foot0).length, greaterThan(0.1));

    vm.pinIkChain('LeftLeg', from: 0, to: 30);
    for (final f in [0, 15, 30]) {
      final pose = vm.authoredClip!.samplePose(skel, f / 30);
      final foot = skel.worldMatrices(pose)[skel.indexOf('foot_l')].getTranslation();
      expect((foot - foot0).length, lessThan(0.005), reason: 'frame $f');
    }
    expect(vm.authoredClip!.tracks['calf_l']!.keys, [AuthoredChannel.rotation]);
    vm.dispose();
  });

  test('Extract from Pelvis moves the horizontal travel to the root; the world pelvis path is unchanged', () async {
    if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
    final vm = await newSequence();
    final skel = vm.skeleton!;
    final fwd = forwardOf(vm);
    vm.selectBone('pelvis');
    vm.keyPendingOrSelected();
    vm.seek(1.0);
    vm.beginBonePose('pelvis');
    vm.previewGizmoDelta(SubEditorGizmoDelta.translate(AuthoringRotation.toAuthoring(fwd * 1.0 + Vector3(0, -0.05, 0))));
    vm.endBonePose();
    Vector3 pelvisAt(int f) => skel.worldMatrices(vm.authoredClip!.samplePose(skel, f / 30))[skel.indexOf('pelvis')].getTranslation();
    Vector3 rootAt(int f) => skel.worldMatrices(vm.authoredClip!.samplePose(skel, f / 30))[skel.root!].getTranslation();
    final before = [for (final f in [0, 10, 20, 30]) pelvisAt(f)];
    expect(vm.enableRootMotion, isFalse);
    final steps = vm.transactions.history().length;

    vm.extractRootMotion();
    expect(vm.transactions.history().length, steps + 1);
    expect(vm.enableRootMotion, isTrue, reason: 'the clip now carries root motion');
    for (final (i, f) in [0, 10, 20, 30].indexed) {
      expect((pelvisAt(f) - before[i]).length, lessThan(1e-5));
    }
    final travel = rootAt(30) - rootAt(0);
    expect((travel - fwd).length, lessThan(1e-4));
    final offset0 = pelvisAt(0) - rootAt(0);
    final offset30 = pelvisAt(30) - rootAt(30);
    expect(offset30.x, closeTo(offset0.x, 1e-5));
    expect(offset30.z, closeTo(offset0.z, 1e-5));
    expect(offset30.y, closeTo(offset0.y - 0.05, 1e-5), reason: 'the pelvis keeps only its vertical offset');

    vm.undo();
    expect(vm.enableRootMotion, isFalse);
    expect((rootAt(30) - rootAt(0)).length, lessThan(1e-9));
    vm.redo();
    vm.zeroRootMotion();
    expect(vm.enableRootMotion, isFalse);
    expect((rootAt(30) - rootAt(0)).length, lessThan(1e-9));
    for (final (i, f) in [0, 10, 20, 30].indexed) {
      expect((pelvisAt(f) - before[i]).length, lessThan(1e-5));
    }

    // A drawn path: root keys through the clicked floor points.
    vm.clearRootPath();
    final start = rootAt(0);
    vm.addRootPathPoint(start);
    vm.addRootPathPoint(start + fwd * 0.5);
    vm.addRootPathPoint(start + fwd * 1.0 + vm.mirrorTable!.lateralAxis * 0.3);
    vm.keyRootPath();
    expect(vm.authoredClip!.keyFrames(skel.names[skel.root!]!), containsAll([0, 15, 30]));
    expect((rootAt(15) - (start + fwd * 0.5)).length, lessThan(1e-5));
    expect((rootAt(30) - (start + fwd * 1.0 + vm.mirrorTable!.lateralAxis * 0.3)).length, lessThan(1e-5));
    vm.dispose();
  });

  test('pose library: save, apply at 50 % weight half way, rename, delete, kept across reopening', () async {
    if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
    final vm = await newSequence();
    final fwd = forwardOf(vm);
    turn(vm, 'upperarm_r', fwd, 80);
    final raised = vm.boneLocal('upperarm_r')!.r;
    vm.savePoseToLibrary('Wave');
    expect(vm.libraryPoses.map((p) => p.name), contains('Wave'));
    vm.seek(1.0);
    vm.selectBone('upperarm_r');
    vm.keyPendingOrSelected();
    vm.seek(0.5);
    turn(vm, 'upperarm_r', fwd, -80);
    vm.seek(1.0);
    turn(vm, 'upperarm_r', fwd, -80);
    final current = vm.boneLocal('upperarm_r')!.r;
    final steps = vm.transactions.history().length;
    vm.applyLibraryPose('Wave', weight: 0.5);
    expect(vm.transactions.history().length, steps + 1);
    final half = BoneTrs.blend(BoneTrs(Vector3.zero(), current, Vector3.all(1)), BoneTrs(Vector3.zero(), raised, Vector3.all(1)), 0.5).r;
    expect(angle(vm.boneLocal('upperarm_r')!.r, half), lessThan(0.01));
    expect(angle(vm.boneLocal('upperarm_r')!.r, current), closeTo(angle(raised, current) / 2, 0.05));

    vm.renameLibraryPose('Wave', 'Hello');
    vm.savePoseToLibrary('Spare');
    vm.deleteLibraryPose('Spare');
    final reopened = AnimationEditorViewModel(assetPath: vm.assetPath);
    await reopened.load();
    expect(reopened.libraryPoses.map((p) => p.name).toList(), ['Hello']);
    expect(angle(reopened.libraryPoses.single.bones['upperarm_r']!.r, raised), lessThan(1e-4));
    // The library itself opens in the Animation editor on its mesh.
    final library = AnimationEditorViewModel(
        assetPath: '${project.path}/${AuthoredPoseLibraryStore.pathFor(meshRel)}');
    await library.load();
    expect(library.hasError, isFalse);
    expect(library.isPoseLibrary, isTrue);
    expect(library.glbMesh, isNotNull);
    expect(library.libraryPoses.map((p) => p.name), ['Hello']);
    expect(await library.save(), isTrue, reason: 'saving leaves the library as it is');
    expect(AuthoredPoseLibraryStore.load(project.path, meshRel).poses.map((p) => p.name), ['Hello']);
    library.dispose();
    vm.dispose();
    reopened.dispose();
  });

  testWidgets('the Pose tab drives onion skin, copy / paste mirrored, loop and IK in the editor', (tester) async {
    if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rel = AnimGraphAssetService.createAnimationSequence(project.path,
        name: 'Tools_widget', meshRelPath: meshRel, lengthFrames: 30, frameRate: 30);
    final vm = AnimationEditorViewModel(assetPath: '${project.path}/$rel');
    await tester.runAsync(() => vm.load());
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: AnimationSubEditor(assetName: 'Tools_widget', assetPath: vm.assetPath, viewModel: vm)),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey('anim_right_tab_pose')));
    await tester.pump();
    final fwd = forwardOf(vm);
    turn(vm, 'upperarm_r', fwd, 60);
    await tester.pump();

    // Copy / Paste Mirrored.
    await tester.tap(find.byKey(const ValueKey('anim_pose_copy')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('anim_pose_paste_mirrored')));
    await tester.tap(find.byKey(const ValueKey('anim_pose_paste_mirrored')));
    await tester.pump();
    expect(vm.authoredClip!.hasKey('upperarm_l', 0, AuthoredChannel.rotation), isTrue);

    // Onion skin from the viewport HUD toggle; ghosts reach the viewport.
    vm.seek(1.0);
    turn(vm, 'upperarm_r', fwd, -30);
    vm.seek(0.5);
    await tester.tap(find.byKey(const ValueKey('anim_onion_skin_toggle')));
    await tester.pump();
    expect(vm.onionSkin.enabled, isTrue);
    final viewport = tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport));
    expect(viewport.ghostSkeletons, hasLength(2));

    // Loop.
    await tester.ensureVisible(find.byKey(const ValueKey('anim_loop_copy_first_to_last')));
    await tester.tap(find.byKey(const ValueKey('anim_loop_copy_first_to_last')));
    await tester.pump();
    expect(vm.loopSeamDegrees, lessThan(1e-4));

    // IK mode (I) puts the gizmo on the chain's target.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pump();
    expect(vm.ikMode, isTrue);
    await tester.ensureVisible(find.byKey(const ValueKey('anim_ik_chain_LeftLeg')));
    await tester.tap(find.byKey(const ValueKey('anim_ik_chain_LeftLeg')));
    await tester.pump();
    final shown = tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport));
    expect(shown.transformGizmo!.target!.id, 'ik:LeftLeg');
    expect(shown.transformGizmo!.mode, GizmoMode.translate);
    expect(shown.overlayMarkers.map((m) => m.label), containsAll(['LeftLeg target', 'LeftLeg pole']));
    await tester.pumpWidget(const SizedBox());
  });
}
