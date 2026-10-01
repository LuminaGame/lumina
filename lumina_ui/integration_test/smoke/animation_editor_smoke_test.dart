import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;
import 'package:lumina_ui/ui/features/main_editor/services/transform_gizmo.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/anim_blueprint/create_anim_asset_dialog.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/animation_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/anim_notify_and_curves.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Animation Editor Smoke Test: Preview mesh swapping and retargeting modal', (WidgetTester tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_anim_');
    final animDir = Directory('${tempProjectsDir.path}/contents/animations')..createSync(recursive: true);
    final meshDir = Directory('${tempProjectsDir.path}/contents/meshes/skeletal')..createSync(recursive: true);

    // Import real GLB Manny, Quinn and Walk animation if available
    final mannyGlb = File('${Directory.current.parent.path}/test-assets/mannequin/SKM_Manny_Simple.glb');
    if (mannyGlb.existsSync()) {
      File('${meshDir.path}/SKM_Manny_Simple.glb').writeAsBytesSync(mannyGlb.readAsBytesSync());
      final mannyAsset = LuminaAsset(
        assetId: 'manny-smoke',
        name: 'SKM_Manny_Simple',
        type: AssetType.filamesh,
        rawPayload: mannyGlb.readAsBytesSync(),
      );
      File('${meshDir.path}/SKM_Manny_Simple.lmas').writeAsBytesSync(mannyAsset.toProtoBufferBytes());
    }

    final walkGlb = File('${Directory.current.parent.path}/test-assets/mannequin/MF_Unarmed_Walk_Bwd.glb');
    final animFile = File('${animDir.path}/MF_Unarmed_Walk_Bwd.lmas');
    if (walkGlb.existsSync()) {
      final walkAsset = LuminaAsset(
        assetId: 'walk-smoke',
        name: 'MF_Unarmed_Walk_Bwd',
        type: AssetType.animation,
        rawPayload: walkGlb.readAsBytesSync(),
      );
      animFile.writeAsBytesSync(walkAsset.toProtoBufferBytes());
    } else {
      final walkAsset = LuminaAsset(
        assetId: 'walk-smoke',
        name: 'MF_Unarmed_Walk_Bwd',
        type: AssetType.animation,
      );
      animFile.writeAsBytesSync(walkAsset.toProtoBufferBytes());
    }

    final vm = AnimationEditorViewModel(assetPath: animFile.path);
    await tester.runAsync(() => vm.load());

    // The boundary wraps the whole app so the retarget dialog, an overlay
    // above the page, is on video too.
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: SizedBox(
              width: 1400,
              height: 900,
              child: AnimationSubEditor(
                assetName: 'MF_Unarmed_Walk_Bwd',
                assetPath: animFile.path,
                viewModel: vm,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(seconds: 1));

    expect(find.text('Preview Mesh'), findsOneWidget);
    expect(find.text('Retarget Animation'), findsOneWidget);
    expect(find.text('DOPE SHEET'), findsOneWidget);
    expect(find.text('+ Key'), findsOneWidget);
    expect(find.text('+ Notify'), findsOneWidget);

    // Add key and notify via view model
    vm.addKeyAtCurrentFrame(curveName: 'SmokeCurve', value: 0.5);
    await rec.hold(const Duration(seconds: 1));
    vm.addNotify('Smoke_Footstep', 0.25, type: AnimNotifyType.footstep);
    await tester.pump(const Duration(milliseconds: 100));
    await rec.hold(const Duration(seconds: 1));

    expect(find.text('Smoke_Footstep'), findsOneWidget);

    SmokeArtifacts.saveScreenshot('animation_editor_dope_sheet', await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));

    // The clip plays: the playhead sweeps the dope sheet.
    vm.play();
    await rec.hold(const Duration(milliseconds: 2500));

    // Orbit the preview around the walking mannequin while it plays.
    final preview = tester.getCenter(find.byType(SubEditor3DViewport));
    await rec.drag(preview - const Offset(120, 0), preview + const Offset(120, 0), steps: 40);
    vm.pause();
    await rec.hold(const Duration(milliseconds: 500));

    // The retargeting modal opens over the editor and closes again.
    await tester.tap(find.text('Retarget Animation'));
    await tester.pump(const Duration(milliseconds: 300));
    await rec.hold(const Duration(milliseconds: 1500));
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
    await rec.hold(const Duration(seconds: 1));
    rec.save('Animation Editor Smoke Test: Preview mesh swapping and retargeting modal');

    if (tempProjectsDir.existsSync()) {
      tempProjectsDir.deleteSync(recursive: true);
    }
  });


  testWidgets(
      'Animation Editor Smoke Test: A new Animation Sequence for SKM_Manny_Simple, the right upper arm raised 0 to 30 and the head turned at 15 with the gizmo, played and reopened',
      (WidgetTester tester) async {
    const scenario =
        'Animation Editor Smoke Test: A new Animation Sequence for SKM_Manny_Simple, the right upper arm raised 0 to 30 and the head turned at 15 with the gizmo, played and reopened';
    const usedAssets = ['mannequin/SKM_Manny_Simple.glb', 'contents/animations/SKM_Manny_Simple/ArmRaise.lmas'];
    final mannyGlb = File('${Directory.current.parent.path}/test-assets/mannequin/SKM_Manny_Simple.glb');
    if (!mannyGlb.existsSync()) {
      markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
      return;
    }
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Future<void> settle({int frames = 12}) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    final project = Directory.systemTemp.createTempSync('lumina_smoke_anim_author_');
    const meshRel = 'contents/meshes/skeletal/SKM_Manny_Simple.lmas';
    Directory('${project.path}/contents/meshes/skeletal').createSync(recursive: true);
    File('${project.path}/$meshRel').writeAsBytesSync(LuminaAsset(
      assetId: 'manny-author-smoke',
      name: 'SKM_Manny_Simple',
      type: AssetType.filameshSk,
      rawPayload: mannyGlb.readAsBytesSync(),
      metadata: const {'payload_format': 'glb'},
    ).toProtoBufferBytes());

    final boundaryKey = GlobalKey();
    Widget frame(Widget child) => RepaintBoundary(
          key: boundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: Scaffold(child: SizedBox(width: 1400, height: 900, child: child)),
          ),
        );
    Future<Uint8List> png() => SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));

    try {
      // 1. New Animation Sequence: Manny, "ArmRaise", 30 frames at 30 FPS.
      String? created;
      await tester.pumpWidget(frame(Center(
        child: CreateAnimAssetDialog(
          projectDir: project.path,
          kind: AnimAssetKind.animationSequence,
          onCreated: (path) => created = path,
          onCancel: () {},
        ),
      )));
      await settle();
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(milliseconds: 600));
      await rec.typeText(find.byKey(const ValueKey('anim_asset_name')), 'ArmRaise');
      await rec.typeText(find.byKey(const ValueKey('anim_sequence_length')), '30');
      await rec.hold(const Duration(milliseconds: 500));
      expect(find.textContaining('30 frames at 30 FPS'), findsOneWidget);
      SmokeArtifacts.saveScreenshot('Animation Editor Smoke Test: New Animation Sequence dialog for SKM_Manny_Simple', await png(),
          usedAssets: usedAssets);
      await tester.tap(find.byKey(const ValueKey('anim_asset_create')));
      await settle();
      expect(created, 'contents/animations/SKM_Manny_Simple/ArmRaise.lmas');

      // 2. Open it in the Animation editor.
      final assetPath = '${project.path}/$created';
      final vm = AnimationEditorViewModel(assetPath: assetPath);
      await tester.runAsync(() => vm.load());
      expect(vm.isAuthored, isTrue);
      expect(vm.totalFrames, 30);
      await tester.pumpWidget(frame(AnimationSubEditor(assetName: 'ArmRaise', assetPath: assetPath, viewModel: vm)));
      await settle(frames: 30);
      await rec.hold(const Duration(milliseconds: 1500));

      dynamic viewport() => tester.state(find.byType(SubEditor3DViewport));
      Rect viewRect() => tester.getRect(find.byType(SubEditor3DViewport));

      Future<void> selectBone(String bone) async {
        final filter = find.descendant(of: find.byKey(const ValueKey('anim_bone_filter')), matching: find.byType(EditableText));
        await tester.tap(filter);
        await settle(frames: 2);
        await rec.typeText(filter, bone, perCharacter: const Duration(milliseconds: 40));
        await settle(frames: 4);
        expect(vm.boneSearchQuery, bone);
        await tester.tap(find.byKey(ValueKey('anim_bone_tree_$bone')));
        await settle(frames: 4);
        expect(vm.selectedBone, bone);
        await rec.hold(const Duration(milliseconds: 300));
      }

      Future<void> key() async {
        await tester.tap(find.byKey(const ValueKey('anim_key_button')));
        await settle(frames: 4);
        await rec.hold(const Duration(milliseconds: 300));
      }

      double handHeight() => vm.boneWorldPosition('hand_r')!.y;

      double turnDegrees(Quaternion a, Quaternion b) =>
          2 * math.acos((a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w).abs().clamp(0.0, 1.0)) * 180 / math.pi;

      /// Turns [axis]'s ring of the bone gizmo by [steps] eighths of a turn
      /// (negative: the other way), grabbing it where only that ring is hit
      /// and dragging along it, recorded.
      Future<void> dragRing(String axis, int steps) async {
        // A modifier left down by the desktop (Alt orbits instead of dragging).
        HardwareKeyboard.instance.clearState();
        final model = viewport().transformGizmoModelForTest(viewRect().size) as TransformGizmoModel;
        final ring = model.ringPoints(axis, segments: 8);
        final origin = viewRect().topLeft;
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: viewRect().center);
        // Grab the ring where the viewport hovers that ring (not a crossing).
        int? from;
        for (var i = 0; i < 8 && from == null; i++) {
          if (ring[i] == null || ring[(i + steps) % 8] == null) continue;
          await mouse.moveTo(origin + ring[i]!);
          await rec.hold(const Duration(milliseconds: 60));
          if (viewport().hoveredGizmoHandleForTest == axis) from = i;
        }
        expect(from, isNotNull, reason: 'a point of the $axis ring the viewport hovers as $axis');
        final grab = origin + ring[from!]!;
        await mouse.down(grab);
        await rec.hold(const Duration(milliseconds: 100));
        for (var i = 1; i <= 24; i++) {
          final a = from + steps * i / 24;
          final lo = a.floor();
          final p0 = ring[lo % 8]!;
          final p1 = ring[(lo + 1) % 8]!;
          await mouse.moveTo(origin + Offset.lerp(p0, p1, a - lo)!);
          await rec.hold(const Duration(milliseconds: 50));
        }
        await mouse.up();
        await mouse.removePointer();
        await settle(frames: 4);
        await rec.hold(const Duration(milliseconds: 300));
      }

      /// The world ring (authoring axis) that lifts [tip] the most when
      /// [bone] turns: its runtime axis crossed with the bone's direction.
      String upRing(String bone, String tip) {
        final r = vm.boneWorldPosition(tip)! - vm.boneWorldPosition(bone)!;
        var best = 'X';
        var bestUp = 0.0;
        for (final (name, axis) in [('X', Vector3(1, 0, 0)), ('Y', Vector3(0, 1, 0)), ('Z', Vector3(0, 0, 1))]) {
          final up = AuthoringRotation.toRuntime(axis).cross(r).y.abs();
          if (up > bestUp) {
            bestUp = up;
            best = name;
          }
        }
        return best;
      }

      // World-space rings, so "up" and "turn" read the same on every bone.
      await tester.tap(find.byKey(const ValueKey('sub_gizmo_space')));
      await settle(frames: 4);

      // 3. Frame 0: key the arm and the head where they rest.
      expect(vm.playheadFrame, 0);
      await selectBone('upperarm_r');
      await key();
      final restHand = handHeight();
      await selectBone('head');
      await key();
      final restHead = vm.boneLocal('head')!.r;

      // 4. Frame 30: raise the arm a quarter turn with the gizmo (Auto Key).
      vm.seek(1.0);
      await settle(frames: 6);
      expect(vm.playheadFrame, 30);
      await selectBone('upperarm_r');
      final armRing = upRing('upperarm_r', 'hand_r');
      await dragRing(armRing, 2);
      // Raised, the hand is above the shoulder; across the body it is not.
      if (handHeight() < vm.boneWorldPosition('upperarm_r')!.y) {
        // That way swung it down across the body: undo and turn the other way.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await settle(frames: 4);
        await rec.hold(const Duration(milliseconds: 300));
        await dragRing(armRing, -2);
      }
      expect(vm.authoredClip!.keyFrames('upperarm_r'), [0, 30]);
      final raisedHand = handHeight();
      expect(raisedHand - restHand, greaterThan(0.2), reason: 'the hand is raised by the arm key at 30');

      // 5. Frame 15: turn the head (yaw ring) by an eighth of a turn.
      vm.seek(0.5);
      await settle(frames: 6);
      await selectBone('head');
      await dragRing('Z', 1);
      expect(vm.authoredClip!.keyFrames('head'), [0, 15]);
      expect(turnDegrees(restHead, vm.boneLocal('head')!.r), closeTo(45, 2));

      // 6. Frames 0, 15, 30: the pose changes.
      Future<void> showFrame(int f, String label) async {
        vm.seek(f / 30);
        await settle(frames: 10);
        await rec.hold(const Duration(milliseconds: 700));
        SmokeArtifacts.saveScreenshot('Animation Editor Smoke Test: ArmRaise at frame $f ($label)', await png(), usedAssets: usedAssets);
      }

      await showFrame(0, 'rest pose');
      expect(handHeight(), closeTo(restHand, 1e-6));
      await showFrame(15, 'arm half way up, head turned');
      expect(handHeight(), inExclusiveRange(restHand, raisedHand));
      expect(turnDegrees(restHead, vm.boneLocal('head')!.r), closeTo(45, 2));
      await showFrame(30, 'arm raised');
      expect(handHeight(), closeTo(raisedHand, 1e-6));

      // 7. Play it, then save.
      vm.seek(0);
      vm.play();
      await rec.hold(const Duration(seconds: 3));
      vm.pause();
      await settle(frames: 4);
      await tester.tap(find.text('Save'));
      await settle(frames: 10);
      expect(vm.isDirty, isFalse);
      final saved = vm.authoredClip!.copy();
      await rec.hold(const Duration(milliseconds: 500));

      // 8. Reopen: the same keys, the arm key at 30 in the Key panel.
      await tester.pumpWidget(frame(const SizedBox()));
      await settle(frames: 4);
      vm.dispose();
      final reopened = AnimationEditorViewModel(assetPath: assetPath);
      await tester.runAsync(() => reopened.load());
      expect(reopened.authoredClip, saved, reason: 'the keys come back exactly');
      await tester.pumpWidget(frame(AnimationSubEditor(assetName: 'ArmRaise', assetPath: assetPath, viewModel: reopened)));
      await settle(frames: 30);
      await rec.hold(const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('dope_bone_key_upperarm_r_30')));
      await settle(frames: 10);
      expect(find.byKey(const ValueKey('anim_bone_key_panel')), findsOneWidget);
      await rec.hold(const Duration(milliseconds: 800));
      SmokeArtifacts.saveScreenshot('Animation Editor Smoke Test: ArmRaise reopened, the arm key at frame 30 in the Key panel', await png(),
          usedAssets: usedAssets);
      reopened.seek(0);
      reopened.play();
      await rec.hold(const Duration(milliseconds: 2500));
      reopened.pause();
      await rec.hold(const Duration(milliseconds: 300));
      rec.save(scenario, usedAssets: usedAssets);
      await tester.pumpWidget(frame(const SizedBox()));
      await settle(frames: 4);
      reopened.dispose();
    } finally {
      try {
        project.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
