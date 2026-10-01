import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart' hide GizmoMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_transform.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/sequencer_viewport_camera.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/level_viewport.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/sequencer_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' as vm64;

/// The Sequencer's viewport draws the level the sequence drives: the level
/// viewport's own Filament scene, through a camera of its own or through a
/// camera actor bound in the sequence.
void main() {
  final acUnitGlb = '${Directory.current.parent.path}/test-assets/Props/AC_units/ac_unit_a_300x300.glb';
  final hasAsset = File(acUnitGlb).existsSync();

  group('SequencerViewportCamera', () {
    test('starts at the level camera pose and points Filament through the same eye', () {
      final cam = SequencerViewportCamera(yaw: 30, pitch: 20, distance: 500, target: [10, 20, 30]);
      final pose = cam.editorPose();
      final yaw = 30 * math.pi / 180, pitch = 20 * math.pi / 180;
      // The level viewport's orbit: eye = target + (d·cosP·sinY, −d·cosP·cosY, d·sinP), Z up → Y up.
      final eyeAuthoring = [10 + 500 * math.cos(pitch) * math.sin(yaw), 20 - 500 * math.cos(pitch) * math.cos(yaw), 30 + 500 * math.sin(pitch)];
      final eye = LuminaAxes.location(eyeAuthoring);
      expect(pose.eye.x, closeTo(eye.x, 1e-6));
      expect(pose.eye.y, closeTo(eye.y, 1e-6));
      expect(pose.eye.z, closeTo(eye.z, 1e-6));
      final target = LuminaAxes.location([10, 20, 30]);
      final toTarget = (target - pose.eye).normalized();
      expect(pose.forward.dot(toTarget), closeTo(1.0, 1e-9));
    });

    test('orbit, pan, dolly, fly and focus move the editor camera', () {
      final cam = SequencerViewportCamera(yaw: 0, pitch: 0, distance: 400, target: [0, 0, 0]);
      cam.orbit(100, 0);
      expect(cam.yaw, isNot(0.0));
      final beforePan = List<double>.of(cam.target);
      cam.pan(50, 0);
      expect(cam.target, isNot(equals(beforePan)));
      cam.dolly(-120);
      expect(cam.distance, lessThan(400));
      final eyeBefore = cam.editorPose().eye;
      cam.fly(forward: 1, right: 0, up: 0, dt: 0.5);
      final eyeAfter = cam.editorPose().eye;
      expect((eyeAfter - eyeBefore).dot(cam.editorPose().forward), greaterThan(0), reason: 'W flies forward');
      cam.focus(center: [300, 0, 50], radius: 80);
      expect(cam.target, [300.0, 0.0, 50.0]);
      expect(cam.distance, greaterThan(80));
    });

    test('a camera actor is looked through from its own location along its forward (+Y authoring)', () {
      final camera = EditorActorNode(id: 'cam', name: 'Camera_1', type: 'Camera', location: [100, -300, 150], rotation: [0, 0, 90]);
      final pose = SequencerViewportCamera.lockedPose(camera);
      final eye = LuminaAxes.location(camera.location);
      expect(pose.eye.x, closeTo(eye.x, 1e-6));
      expect(pose.eye.y, closeTo(eye.y, 1e-6));
      expect(pose.eye.z, closeTo(eye.z, 1e-6));
      // Yaw 90 faces +X (authoring and runtime).
      expect(pose.forward.x, closeTo(1.0, 1e-9));
      expect(pose.up.y, closeTo(1.0, 1e-9));
      expect(pose.fovDegrees, 60.0, reason: 'a camera without a camera component uses the runtime default');
    });
  });

  group('Sequencer viewport on the live level', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('seq_level_vp_'));
    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    // The editor viewport's tickers never let pumpAndSettle settle.
    Future<void> settle(WidgetTester tester, bool Function() done, {int frames = 400}) async {
      await tester.pump();
      for (var i = 0; i < frames && !done(); i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
    }

    testWidgets('renders the level viewport\'s scene, scrubbing moves the bound mesh in it, camera lock follows the bound camera',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const projectName = 'SeqLevelViewport';
      final pDir = Directory('${root.path}/$projectName')..createSync(recursive: true);
      await tester.runAsync(() async {
        await AssetRepository().createAsset(projectPath: pDir.path, subFolder: 'meshes', fileName: 'AC_Unit.lmas', type: AssetType.filamesh);
      });
      File(acUnitGlb).copySync('${pDir.path}/contents/meshes/AC_Unit.glb');
      File('${pDir.path}/$projectName.lmproject').writeAsStringSync('{}');
      final evm = EditorViewModel(
        initialProject: LuminaProject(projectName: projectName, activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60)),
        projectLocation: root.path,
        enableTimers: false,
      );
      await tester.runAsync(evm.ensureDefaultLevelAssets);
      await tester.runAsync(() => evm.spawnActorFromAsset(evm.realAssets.firstWhere((a) => a.fileName == 'AC_Unit.lmas'), location: [0, 0, 0]));
      final mesh = evm.actors.last;
      evm.spawnNewActor('Camera');
      final camera = evm.actors.last;
      expect(camera.type, 'Camera');
      camera.location = [0, -600, 150];
      camera.rotation = [0, 0, 0];

      final seq = SequencerData(fps: 30, lengthFrames: 120, tracks: [
        SequencerTrack(id: 'mesh', actorId: mesh.id, actorName: mesh.name, kind: SequencerTrackKind.transform, channels: [
          SequencerChannel(name: 'Location.X', keys: [SequencerKey(frame: 0, value: 0), SequencerKey(frame: 60, value: 200)]),
        ]),
        SequencerTrack(id: 'cam', actorId: camera.id, actorName: camera.name, kind: SequencerTrackKind.transform, channels: [
          SequencerChannel(name: 'Location.X', keys: [SequencerKey(frame: 0, value: 0), SequencerKey(frame: 60, value: 300)]),
          SequencerChannel(name: 'Rotation.Z', keys: [SequencerKey(frame: 0, value: 0), SequencerKey(frame: 60, value: 90)]),
        ]),
      ]);
      Directory('${pDir.path}/contents/cinematics').createSync(recursive: true);
      File('${pDir.path}/contents/cinematics/SEQ_Shot.lmas').writeAsBytesSync(
          LuminaAsset(assetId: 'seq-shot', name: 'SEQ_Shot', type: AssetType.sequencer, rawPayload: seq.toBytes()).toProtoBufferBytes());
      evm.refreshAssets();

      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: evm)));
      dynamic level() => tester.state(find.byType(ViewportWidget, skipOffstage: false));
      ({int root, List<int> entities})? meshInstance() =>
          level().actorInstanceInSceneForTest(mesh.id) as ({int root, List<int> entities})?;
      await settle(tester, () => meshInstance() != null);
      expect(meshInstance(), isNotNull, reason: 'the level viewport draws the mesh');

      evm.openSubEditorTab('SEQUENCER', asset: evm.realAssets.firstWhere((a) => a.fileName == 'SEQ_Shot.lmas'));
      await settle(tester, () => find.text('Curves & Tangents').evaluate().isNotEmpty, frames: 100);

      // Not the generic preview: no sample sphere, no shape buttons.
      expect(find.byType(SubEditor3DViewport), findsNothing);
      expect(find.text('SPHERE'), findsNothing);
      expect(find.byType(SequencerLevelViewport), findsOneWidget);

      final seqView = tester.state<SequencerLevelViewportState>(find.byType(SequencerLevelViewport));
      await settle(tester, () => seqView.drawsLevelScene);
      final levelScene = level().nativeSceneForTest as FilamentScene;
      expect(seqView.viewForTest!.scene!.nativePointer.address, levelScene.nativePointer.address,
          reason: 'the Sequencer view renders the level viewport\'s scene');

      // Scrubbing moves the bound mesh in the scene this view draws.
      final seqVm = tester.widget<SequencerSubEditor>(find.byType(SequencerSubEditor));
      expect(seqVm.editorViewModel, same(evm));
      final tm = FilamentTransformManager(level().nativeEngineForTest as FilamentEngine);
      double rootX() => tm.getTransform(meshInstance()!.root)[12];
      final x0 = rootX();
      seqView.sequencer.scrubToFrame(60);
      await settle(tester, () => (rootX() - x0).abs() > 1e-3, frames: 30);
      expect(mesh.location[0], closeTo(200.0, 1e-6));
      expect(rootX(), closeTo(EditorTransforms.meshMatrix(mesh).getTranslation().x, 1e-3));
      expect(levelScene.hasEntity(meshInstance()!.entities.first), isTrue);

      // The bound camera is offered for the lock; locking looks through it, and scrubbing moves the view with it.
      expect(seqView.cameraCandidates.map((a) => a.id), [camera.id]);
      seqView.lockToCamera(camera.id);
      seqView.sequencer.scrubToFrame(30);
      await settle(tester, () => false, frames: 3);
      var cam = seqView.cameraForTest!;
      var expectedEye = LuminaAxes.location(camera.location);
      expect(camera.location[0], closeTo(150.0, 1e-6));
      expect(cam.position.x, closeTo(expectedEye.x, 1e-2));
      expect(cam.position.y, closeTo(expectedEye.y, 1e-2));
      expect(cam.position.z, closeTo(expectedEye.z, 1e-2));
      final halfway = SequencerViewportCamera.lockedPose(camera).forward;
      expect(vm64.Vector3(cam.forwardVector.x, cam.forwardVector.y, cam.forwardVector.z).dot(halfway), closeTo(1.0, 1e-4));

      seqView.sequencer.scrubToFrame(60);
      await settle(tester, () => false, frames: 3);
      cam = seqView.cameraForTest!;
      expectedEye = LuminaAxes.location(camera.location);
      expect(cam.position.x, closeTo(expectedEye.x, 1e-2), reason: 'the locked view follows the keyed camera');
      expect(cam.forwardVector.x, closeTo(1.0, 1e-4), reason: 'yaw 90 at frame 60 looks along +X');
      expect(find.text('PILOTING ${camera.name}'), findsOneWidget);

      // Unlock: back to the editor camera.
      seqView.lockToCamera(null);
      await settle(tester, () => false, frames: 3);
      expect(find.text('PILOTING ${camera.name}'), findsNothing);
      expect(seqView.cameraForTest!.position.x, isNot(closeTo(expectedEye.x, 1e-2)));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      evm.dispose();
    }, skip: !hasAsset);
  });
}
