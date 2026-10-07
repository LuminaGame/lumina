import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/level_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A placed Camera's Details show its Camera section; its field of view,
/// changed there from 90° to 30°, is what looking through the camera (the
/// Sequencer camera lock) renders: the barrel and the AC unit in front of it
/// fill a much larger part of the frame at 30°.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Camera Details Smoke Scenario: the Camera section\'s field of view drives the view through the camera', (tester) async {
    final barrelGlb = '${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb';
    final acUnitGlb = '${Directory.current.parent.path}/test-assets/Props/AC_units/ac_unit_a_300x300.glb';
    if (!File(barrelGlb).existsSync() || !File(acUnitGlb).existsSync()) {
      markTestSkipped('test assets missing: $barrelGlb, $acUnitGlb');
      return;
    }
    tester.view.physicalSize = const Size(1680, 1120);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Future<void> settle({int frames = 20}) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    const scenario = 'Camera Details Smoke Scenario: the Camera section\'s field of view drives the view through the camera';
    const usedAssets = ['Props/Barrels/fuel_barrel_red.glb', 'Props/AC_units/ac_unit_a_300x300.glb'];
    final tempProjectsDir = Directory.systemTemp.createTempSync('cam_details_smoke_');
    const projectName = 'SmokeCameraDetails';
    final pDir = Directory('${tempProjectsDir.path}/$projectName')..createSync(recursive: true);
    final repo = AssetRepository();
    await repo.createAsset(projectPath: pDir.path, subFolder: 'meshes', fileName: 'Barrel.lmas', type: AssetType.filamesh);
    File(barrelGlb).copySync('${pDir.path}/contents/meshes/Barrel.glb');
    await repo.createAsset(projectPath: pDir.path, subFolder: 'meshes', fileName: 'AC_Unit.lmas', type: AssetType.filamesh);
    File(acUnitGlb).copySync('${pDir.path}/contents/meshes/AC_Unit.glb');

    try {
      File('${pDir.path}/$projectName.lmproject').writeAsStringSync('{}');
      final vm = EditorViewModel(
        initialProject: LuminaProject(projectName: projectName, activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60)),
        projectLocation: tempProjectsDir.path,
        enableTimers: false,
      );
      addTearDown(vm.dispose);
      await vm.ensureDefaultLevelAssets();
      // A barrel 6 m in front of the camera, an AC unit behind it, lit.
      await vm.spawnActorFromAsset(vm.realAssets.firstWhere((a) => a.fileName == 'Barrel.lmas'), location: [0, 0, 0]);
      await vm.spawnActorFromAsset(vm.realAssets.firstWhere((a) => a.fileName == 'AC_Unit.lmas'), location: [250, 400, 0]);
      vm.spawnNewActor('Environment');
      vm.spawnNewActor('DirectionalLight');
      vm.actors.last.location = [900, 900, 600];
      vm.spawnNewActor('Camera');
      final camera = vm.actors.last;
      camera.name = 'Camera_1';
      camera.location = [0, -600, 50];
      camera.rotation = [0, 0, 0];
      final cameraComponent = camera.components.firstWhere((c) => c.type == 'LuminaCameraComponent');

      // A sequence bound to the camera, so the Sequencer can look through it.
      final seqData = SequencerData(fps: 30, lengthFrames: 60, tracks: [
        SequencerTrack(id: 'track-camera', actorId: camera.id, actorName: camera.name, kind: SequencerTrackKind.transform, channels: [
          SequencerChannel(name: 'Location.X', keys: [SequencerKey(frame: 0, value: 0), SequencerKey(frame: 60, value: 0)]),
        ]),
      ]);
      Directory('${pDir.path}/contents/cinematics').createSync(recursive: true);
      File('${pDir.path}/contents/cinematics/SEQ_Camera.lmas').writeAsBytesSync(
          LuminaAsset(assetId: 'seq-camera', name: 'SEQ_Camera', type: AssetType.sequencer, rawPayload: seqData.toBytes()).toProtoBufferBytes());
      vm.refreshAssets();

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(frames: 60);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(milliseconds: 1000));

      Future<img.Image> shot(String name) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
        return img.decodePng(png)!;
      }

      // 1. Select Camera_1: Details shows its Camera section; set FOV 90 there.
      vm.selectActorById(camera.id);
      await settle(frames: 20);
      expect(find.text('CAMERA'), findsOneWidget);
      final fovField = find.byKey(const ValueKey('details_camera_fieldOfView'));
      // The section's heading at the top of the Details list.
      await tester.ensureVisible(find.text('CAMERA'));
      await settle(frames: 10);
      tester.widget<ScrubNumericField>(fovField).onCommit(90.0);
      await settle(frames: 20);
      expect(cameraComponent.properties['fieldOfView'], 90.0);
      expect(tester.widget<ScrubNumericField>(fovField).value, 90.0);
      await rec.hold(const Duration(milliseconds: 1500));
      await shot('Camera Details Smoke Scenario: Camera_1 Details with the Camera section (FOV 90)');

      // 2. Look through Camera_1 (Sequencer camera lock) at 90°.
      vm.openSubEditorTab('SEQUENCER', asset: vm.realAssets.firstWhere((a) => a.fileName == 'SEQ_Camera.lmas'));
      for (var i = 0; i < 100 && find.byType(SequencerLevelViewport).evaluate().isEmpty; i++) {
        await settle(frames: 1);
      }
      final seqView = tester.state<SequencerLevelViewportState>(find.byType(SequencerLevelViewport));
      for (var i = 0; i < 200 && !seqView.drawsLevelScene; i++) {
        await settle(frames: 1);
      }
      expect(seqView.drawsLevelScene, isTrue);
      seqView.lockToCamera(camera.id);
      seqView.sequencer.scrubToFrame(0);
      await settle(frames: 40);
      expect(find.text('PILOTING Camera_1'), findsOneWidget);
      await rec.hold(const Duration(milliseconds: 3000));

      // What the camera sees above the horizon (its eye is level, so the
      // horizon is the film gate's middle row): the barrel and the AC unit,
      // neutral white / grey against the blue sky. Pixels counted inside the
      // 16:9 gate; dark masking, the green / red gizmo lines and the sky are not.
      int objectPixelsAboveHorizon(img.Image image) {
        final scale = image.width / tester.getSize(find.byKey(boundaryKey)).width;
        final r = tester.getRect(find.byType(SequencerLevelViewport));
        const aspect = SequencerLevelViewport.filmAspect;
        final gate = r.width / r.height >= aspect
            ? Rect.fromCenter(center: r.center, width: r.height * aspect, height: r.height)
            : Rect.fromCenter(center: r.center, width: r.width, height: r.width / aspect);
        var count = 0;
        for (var y = (gate.top * scale + 4).round(); y < (gate.center.dy * scale - 4).round(); y++) {
          for (var x = (gate.left * scale + 4).round(); x < (gate.right * scale - 4).round(); x++) {
            final p = image.getPixel(x, y);
            final neutral = (p.r - p.b).abs() < 40 && (p.g - p.r).abs() < 30 && (p.g - p.b).abs() < 40;
            if (neutral && p.r + p.g + p.b > 150) count++;
          }
        }
        return count;
      }

      final wide = objectPixelsAboveHorizon(await shot('Camera Details Smoke Scenario: looking through Camera_1 at FOV 90'));

      // 3. FOV 30, committed the way the Details field commits it: one undo step.
      vm.selectActorById(camera.id);
      vm.updateComponentPropertyWithTransaction(camera.id, cameraComponent.id, 'fieldOfView', 30.0);
      await settle(frames: 40);
      await rec.hold(const Duration(milliseconds: 3000));
      final narrow = objectPixelsAboveHorizon(await shot('Camera Details Smoke Scenario: looking through Camera_1 at FOV 30'));
      debugPrint('[camera_details_smoke] object pixels above the horizon: FOV 90 = $wide, FOV 30 = $narrow');
      expect(wide, greaterThan(200), reason: 'the barrel and the AC unit are in view at 90°');
      // tan(45°) / tan(15°) = 3.7× the size, about 14× the area.
      expect(narrow, greaterThan(wide * 5), reason: 'the meshes fill far more of the frame at 30°');

      // Undo goes back to the wide view.
      vm.transactions.undo();
      await settle(frames: 30);
      await rec.hold(const Duration(milliseconds: 2500));
      expect(cameraComponent.properties['fieldOfView'], 90.0);
      rec.save(scenario, usedAssets: usedAssets);
    } finally {
      if (tempProjectsDir.existsSync()) {
        try {
          tempProjectsDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
