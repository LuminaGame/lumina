import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_preferences.dart';
import 'package:lumina_ui/ui/features/main_editor/services/transform_gizmo.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/selected_keyframe_details.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/sub_editor_transform_gizmo.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/animation_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import '../helpers/scaffold_game_project.dart';
import '../helpers/temp_project.dart';

/// Authoring an Animation Sequence from scratch: New Animation Sequence for a
/// skeletal mesh, posing bones with the viewport gizmo, Auto Key at the
/// playhead, editing / moving / deleting bone keys with undo, and saving the
/// clip into the mesh's GLB where every player finds it.
void main() {
  final assets = Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');
  final mannyGlb = File('${assets.path}/mannequin/SKM_Manny_Simple.glb');
  const meshRel = 'contents/meshes/skeletal/SKM_Manny_Simple.lmas';

  late Directory project;
  var counter = 0;

  setUpAll(() {
    project = Directory.systemTemp.createTempSync('lumina_anim_author_');
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

  /// A new 60-frame, 30 fps sequence on Manny, loaded in a view model.
  Future<AnimationEditorViewModel> newSequence({int lengthFrames = 60, double fps = 30}) async {
    final rel = AnimGraphAssetService.createAnimationSequence(project.path,
        name: 'Authored_${++counter}', meshRelPath: meshRel, lengthFrames: lengthFrames, frameRate: fps);
    final vm = AnimationEditorViewModel(assetPath: '${project.path}/$rel');
    await vm.load();
    return vm;
  }

  double angleBetween(Quaternion a, Quaternion b) {
    final d = (a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w).abs().clamp(0.0, 1.0);
    return 2 * math.acos(d) * 180 / math.pi;
  }

  /// [bone]'s world rotation as the editor shows it now.
  Quaternion worldRotation(AnimationEditorViewModel vm, String bone) {
    final skel = vm.skeleton!;
    final pose = {for (final e in vm.currentNodePose.entries) e.key: e.value};
    final m = skel.worldMatrices(pose)[skel.indexOf(bone)];
    final t = Vector3.zero();
    final r = Quaternion.identity();
    final s = Vector3.zero();
    m.decompose(t, r, s);
    return r..normalize();
  }

  /// Rotates [bone] by [degrees] about the authoring-frame [axis] through the
  /// gizmo path, in [steps] pointer moves and one release.
  void rotateBone(AnimationEditorViewModel vm, String bone, Vector3 axis, double degrees, {int steps = 4}) {
    vm.selectBone(bone);
    vm.beginBonePose(bone);
    for (var i = 1; i <= steps; i++) {
      vm.previewGizmoDelta(SubEditorGizmoDelta.rotate(axis, degrees * i / steps));
    }
    vm.endBonePose();
  }

  group('view model', () {
    test('a new sequence is an authored clip of the chosen length and frame rate on the mesh', () async {
      if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final vm = await newSequence(lengthFrames: 45, fps: 30);
      expect(vm.isAuthored, isTrue);
      expect(vm.hasError, isFalse);
      expect(vm.duration, closeTo(1.5, 1e-9));
      expect(vm.totalFrames, 45);
      expect(vm.frameRate, 30);
      expect(vm.activeClip!.name, vm.authoredClip!.name);
      expect(vm.authoredClip!.bones, ['root'], reason: 'the rest pose of the skeleton root at frame 0');
      expect(vm.jointLocalPose, contains('upperarm_r'));
      expect(vm.jointLocalPose!['upperarm_r'], hasLength(10));
      final asset = LuminaAsset.fromBytes(File(vm.assetPath).readAsBytesSync());
      expect(asset.metadata['source_mesh'], meshRel);
      expect(AnimGraphAssetService.clipNames(project.path, meshRel), contains(vm.authoredClip!.name));
      vm.dispose();
    });

    test('posing with Auto Key keys exactly that bone\'s rotation at the playhead, as one undo step', () async {
      if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final vm = await newSequence();
      expect(vm.autoKey, isTrue);
      vm.seek(1.0); // frame 30
      expect(vm.playheadFrame, 30);
      final before = worldRotation(vm, 'upperarm_r');
      final steps = vm.transactions.history().length;

      rotateBone(vm, 'upperarm_r', Vector3(0, 1, 0), 40);

      final clip = vm.authoredClip!;
      expect(clip.keyFrames('upperarm_r'), [30]);
      expect(clip.tracks['upperarm_r']!.keys, ['rotation'], reason: 'only the changed channel is keyed');
      expect(clip.bones.toSet(), {'root', 'upperarm_r'}, reason: 'no other bone gets a key');
      expect(vm.transactions.history().length, steps + 1);
      expect(vm.hasPendingPreview, isFalse);
      expect(vm.isDirty, isTrue);
      // The bone turned 40° about the world axis the gizmo ring stands for.
      final after = worldRotation(vm, 'upperarm_r');
      final expected = Quaternion.axisAngle(AuthoringRotation.toRuntime(Vector3(0, 1, 0)), 40 * math.pi / 180) * before;
      expect(angleBetween(after, expected), lessThan(0.01));
      expect(angleBetween(after, before), closeTo(40, 0.01));

      vm.undo();
      expect(vm.authoredClip!.tracks.containsKey('upperarm_r'), isFalse);
      expect(angleBetween(worldRotation(vm, 'upperarm_r'), before), lessThan(0.01));
      vm.redo();
      expect(vm.authoredClip!.keyFrames('upperarm_r'), [30]);
      vm.dispose();
    });

    test('a key already at the frame is updated; Auto Key off previews until a seek, Key keys it', () async {
      if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final vm = await newSequence();
      vm.seek(0.5); // frame 15
      rotateBone(vm, 'head', Vector3(0, 0, 1), 20);
      rotateBone(vm, 'head', Vector3(0, 0, 1), 15);
      final head = vm.authoredClip!.channel('head', 'rotation')!;
      expect(head.keys.keys, [15], reason: 'updated, not duplicated');
      final keyed = worldRotation(vm, 'head');

      vm.setAutoKey(false);
      final steps = vm.transactions.history().length;
      rotateBone(vm, 'head', Vector3(1, 0, 0), 30);
      expect(vm.hasPendingPreview, isTrue);
      expect(vm.transactions.history().length, steps, reason: 'a preview is no undo step');
      expect(angleBetween(worldRotation(vm, 'head'), keyed), closeTo(30, 0.05));
      vm.seek(0.5);
      expect(vm.hasPendingPreview, isFalse, reason: 'the scrub reverts it');
      expect(angleBetween(worldRotation(vm, 'head'), keyed), lessThan(0.01));

      rotateBone(vm, 'head', Vector3(1, 0, 0), 30);
      vm.keyPendingOrSelected();
      expect(vm.transactions.history().length, steps + 1);
      expect(vm.hasPendingPreview, isFalse);
      expect(angleBetween(worldRotation(vm, 'head'), keyed), closeTo(30, 0.05));
      expect(vm.authoredClip!.channel('head', 'rotation')!.keys.keys, [15]);

      // Key with nothing pending keys the selected bone's whole transform.
      vm.seek(40 / 30);
      vm.selectBone('lowerarm_l');
      vm.keyPendingOrSelected();
      expect(vm.authoredClip!.tracks['lowerarm_l']!.keys.toSet(), {'translation', 'rotation', 'scale'});
      expect(vm.authoredClip!.keyFrames('lowerarm_l'), [40]);
      vm.dispose();
    });

    test('bone keys move, delete and edit in the Key panel, each one undo step', () async {
      if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final vm = await newSequence();
      vm.seek(1.0);
      rotateBone(vm, 'upperarm_r', Vector3(0, 1, 0), 30);
      vm.seek(20 / 30);
      rotateBone(vm, 'upperarm_r', Vector3(0, 1, 0), 10);
      expect(vm.authoredClip!.keyFrames('upperarm_r'), [20, 30]);
      var steps = vm.transactions.history().length;

      // Move 30 → 20, replacing the key there.
      vm.selectKeyframe(vm.boneKeyId('upperarm_r', 30));
      expect(vm.selectedBoneKeys.single.frame, 30);
      vm.moveSelectedBoneKeysToFrame(20);
      expect(vm.authoredClip!.keyFrames('upperarm_r'), [20]);
      expect(vm.selectedBoneKeys.single.frame, 20);
      expect(vm.transactions.history().length, ++steps);

      // The Key panel: the values at the key, editable.
      final details = vm.selectedKeyframeDetails!;
      expect(details.type, 'Bone Keyframe');
      expect(details.targetName, 'upperarm_r');
      expect(details.frame, 20);
      final euler = details.rotationEuler!;
      final back = SelectedKeyframeDetails.eulerXyzToQuaternion(euler[0], euler[1], euler[2]);
      final q = details.rotationQuat!;
      expect((back[0] * q[0] + back[1] * q[1] + back[2] * q[2] + back[3] * q[3]).abs(), closeTo(1.0, 1e-9),
          reason: 'Euler degrees round-trip to the key\'s quaternion');
      vm.setBoneKey('upperarm_r', 20, rotation: SelectedKeyframeDetails.eulerXyzToQuaternion(euler[0] + 15, euler[1], euler[2]));
      expect(vm.transactions.history().length, ++steps);
      expect(vm.selectedKeyframeDetails!.rotationEuler![0], closeTo(euler[0] + 15, 1e-6));
      vm.setBoneKey('upperarm_r', 20, translation: [0.1, 0.2, 0.3]);
      expect(vm.authoredClip!.channel('upperarm_r', 'translation')!.keys[20], [0.1, 0.2, 0.3]);
      expect(vm.transactions.history().length, ++steps);
      vm.setBoneInterpolation('upperarm_r', AuthoredInterpolation.step);
      expect(vm.authoredClip!.channel('upperarm_r', 'rotation')!.interpolation, AuthoredInterpolation.step);
      expect(vm.selectedKeyframeDetails!.interpolation, 'Step');
      expect(vm.transactions.history().length, ++steps);

      vm.deleteSelectedKeys();
      expect(vm.authoredClip!.tracks.containsKey('upperarm_r'), isFalse);
      expect(vm.transactions.history().length, ++steps);
      vm.undo();
      expect(vm.authoredClip!.keyFrames('upperarm_r'), [20]);
      vm.dispose();
    });

    test('save → reload gives the same keys; the clip in the mesh GLB samples to the authored pose', () async {
      if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      final vm = await newSequence();
      // Frame 0: the arm's rest pose, keyed with Key (its whole transform).
      vm.selectBone('upperarm_r');
      vm.keyPendingOrSelected();
      vm.seek(1.0);
      rotateBone(vm, 'upperarm_r', Vector3(0, 1, 0), 60);
      vm.seek(0.5);
      rotateBone(vm, 'head', Vector3(0, 0, 1), 30);
      vm.setBoneInterpolation('head', AuthoredInterpolation.cubic);
      final authored = vm.authoredClip!.copy();
      expect(await vm.save(), isTrue);
      expect(vm.isDirty, isFalse);

      final again = AnimationEditorViewModel(assetPath: vm.assetPath);
      await again.load();
      expect(again.isAuthored, isTrue);
      expect(again.authoredClip, authored, reason: 'frames, values and interpolation restored exactly');

      // The animation every player uses: the clip in the mesh's GLB.
      final glb = File('${project.path}/contents/meshes/skeletal/SKM_Manny_Simple.entity.glb').readAsBytesSync();
      final clip = (await GlbParserService.parseGlb(glb))!.animations.firstWhere((a) => a.name == authored.name);
      final arm = clip.channels.firstWhere((c) => c.nodeName == 'upperarm_r' && c.path == 'rotation');
      final fromGlb = AuthoredChannel('rotation', keys: {
        for (var i = 0; i < arm.keyframeTimes.length; i++) (arm.keyframeTimes[i] * 30).round(): arm.values.sublist(i * 4, i * 4 + 4),
      });
      for (final frame in [0.0, 7.5, 15.0, 22.5, 30.0]) {
        final a = authored.sample('upperarm_r', 'rotation', frame / 30)!;
        final b = fromGlb.sample(frame);
        final dot = (a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]).abs();
        expect(dot, closeTo(1.0, 1e-6), reason: 'frame $frame');
      }
      // Between the keys it is in between: half way is half of 60°.
      final rest = authored.sample('upperarm_r', 'rotation', 0)!;
      final mid = fromGlb.sample(15);
      final half = 2 * math.acos((rest[0] * mid[0] + rest[1] * mid[1] + rest[2] * mid[2] + rest[3] * mid[3]).abs().clamp(0.0, 1.0));
      expect(half * 180 / math.pi, closeTo(30, 0.05));
      vm.dispose();
      again.dispose();
    });

    test('EditorPreferences.animationAutoKey defaults to true and persists', () {
      final config = Directory.systemTemp.createTempSync('lumina_anim_prefs_');
      addTearDown(() => config.deleteSync(recursive: true));
      final prefs = EditorPreferences.load(configDir: config);
      expect(prefs.animationAutoKey, isTrue);
      prefs.setAnimationAutoKey(false);
      expect(EditorPreferences.load(configDir: config).animationAutoKey, isFalse);
      final raw = jsonDecode(File('${config.path}/${EditorPreferences.fileName}').readAsStringSync()) as Map;
      expect(raw['animationAutoKey'], false);
    });
  });

  group('editor', () {
    Future<void> frames(WidgetTester tester, [int n = 6]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    testWidgets('a gizmo ring drag keys the selected bone at the playhead; the Key panel shows it; Ctrl+Z removes it',
        (tester) async {
      if (!mannyGlb.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final config = Directory.systemTemp.createTempSync('lumina_anim_prefs_');
      addTearDown(() => config.deleteSync(recursive: true));
      final prefs = EditorPreferences.load(configDir: config);

      final vm = (await tester.runAsync(() => newSequence()))!;
      addTearDown(vm.dispose);
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: AnimationSubEditor(assetName: vm.authoredClip!.name, assetPath: vm.assetPath, viewModel: vm, preferences: prefs),
        ),
      ));
      await frames(tester);
      expect(find.byKey(const ValueKey('anim_auto_key')), findsOneWidget);
      expect(find.byKey(const ValueKey('anim_bone_filter')), findsOneWidget, reason: 'the skeleton tree is shown');
      await tester.enterText(find.byKey(const ValueKey('anim_bone_filter')), 'upperarm_r');
      await frames(tester, 2);
      expect(find.byKey(const ValueKey('anim_bone_tree_upperarm_r')), findsOneWidget);

      // Auto Key is remembered.
      await tester.tap(find.byKey(const ValueKey('anim_auto_key')));
      await frames(tester, 2);
      expect(vm.autoKey, isFalse);
      expect(prefs.animationAutoKey, isFalse);
      await tester.tap(find.byKey(const ValueKey('anim_auto_key')));
      await frames(tester, 2);
      expect(prefs.animationAutoKey, isTrue);

      vm.seek(1.0);
      await tester.tap(find.byKey(const ValueKey('anim_bone_tree_upperarm_r')));
      await frames(tester, 2);
      expect(vm.selectedBone, 'upperarm_r');
      expect(find.byKey(const ValueKey('anim_selected_bone')), findsOneWidget);

      dynamic viewport() => tester.state(find.byType(SubEditor3DViewport));
      final rect = tester.getRect(find.byType(SubEditor3DViewport));
      final model = viewport().transformGizmoModelForTest(rect.size) as TransformGizmoModel?;
      expect(model, isNotNull, reason: 'the rotate gizmo sits on the bone');
      expect(model!.mode, GizmoMode.rotate);
      String? axis;
      List<Offset?> ring = const [];
      for (final a in ['X', 'Y', 'Z']) {
        final points = model.ringPoints(a, segments: 8);
        if (points[1] != null && points[3] != null && model.hitTest(points[1]!) == a) {
          axis = a;
          ring = points;
          break;
        }
      }
      expect(axis, isNotNull, reason: 'a ring point that hits only its ring');
      final grab = rect.topLeft + ring[1]!;
      final to = rect.topLeft + ring[3]!;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: grab);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(grab);
      await frames(tester, 2);
      await mouse.down(grab);
      await frames(tester, 1);
      for (var i = 1; i <= 8; i++) {
        await mouse.moveTo(Offset.lerp(grab, to, i / 8)!);
        await frames(tester, 1);
      }
      await mouse.up();
      await frames(tester, 2);
      expect(vm.authoredClip!.keyFrames('upperarm_r'), [30], reason: 'keyed at the playhead on release');
      expect(vm.authoredClip!.tracks['upperarm_r']!.keys, ['rotation']);

      await tester.tap(find.byKey(const ValueKey('dope_bone_key_upperarm_r_30')));
      await frames(tester, 2);
      expect(find.byKey(const ValueKey('anim_bone_key_panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('anim_key_frame')), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await frames(tester, 2);
      expect(vm.authoredClip!.tracks.containsKey('upperarm_r'), isFalse, reason: 'Ctrl+Z undid the key');

      await tester.pumpWidget(const SizedBox());
      await drainRealIo(tester);
    });

    testWidgets('Content Browser New Asset → Animation Sequence asks for mesh, length and FPS and opens the sequence',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = Directory.systemTemp.createTempSync('lumina_anim_seq_cb_');
      addTearDown(() => deleteTempProject(root));
      final dir = (await tester.runAsync(() => scaffoldGameProject(root, name: 'seq_cb', widgetLibrary: 'flutter')))!;
      final project = LuminaProject.fromMap(
          Map<String, dynamic>.from(jsonDecode(File('$dir/seq_cb.lmproject').readAsStringSync()) as Map));
      final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
      addTearDown(vm.dispose);
      vm.refreshAssets();
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: ContentBrowserWidget(viewModel: vm))));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Asset').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Animation → Animation Sequence (.lmas)'));
      await tester.pumpAndSettle();
      expect(find.text('New Animation Sequence'), findsOneWidget);
      expect(find.text('Target Skeletal Mesh'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('anim_asset_name')), 'Wave');
      await tester.tap(find.byKey(const ValueKey('anim_sequence_unit_seconds')));
      await tester.enterText(find.byKey(const ValueKey('anim_sequence_length')), '1.5');
      await tester.enterText(find.byKey(const ValueKey('anim_sequence_fps')), '24');
      await tester.pumpAndSettle();
      expect(find.textContaining('36 frames at 24 FPS'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('anim_asset_create')));
      await tester.pumpAndSettle();

      final tab = vm.openTabs.last;
      expect(tab.category, 'Animation');
      final asset = tab.asset!;
      expect(asset.type, AssetType.animation);
      expect(asset.relativePath, 'contents/animations/SKM_Superhero_Female/Wave.lmas');
      final clip = AuthoredAnimationStore.load(dir, asset.relativePath)!;
      expect(clip.lengthFrames, 36);
      expect(clip.frameRate, 24);
      expect(AnimGraphAssetService.clipNames(dir, LuminaThirdPersonContent.projectMeshAssetPath), contains('Wave'));
      await drainRealIo(tester);
    });
  });
}
