import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/transform_gizmo.dart' show TransformGizmoModel;
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/sub_editor_transform_gizmo.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/viewport_ray.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/garment/garment.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// Garment Editor smoke: boot the real editor on a temp project holding the
/// mannequin and the T-shirt from `test-assets/`, create a Garment asset the
/// way Content Browser → New Asset does, open it, choose the T-shirt and the
/// mannequin, move, turn and resize the shirt with the gizmo's own drag
/// handlers, place neck / shoulder / waist landmarks with clicks on the
/// shirt and on the body (the viewport's click handler), Align, save, close
/// and reopen the tab. PNG + WebM evidence goes to SmokeArtifacts.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const title = 'Garment Editor Smoke: a T-shirt placed on the mannequin with the gizmo and landmarks, aligned, saved';

  testWidgets(title, (tester) async {
    final assets = SmokeArtifacts.testAssetsDir.path;
    final tshirt = File('$assets/Props/Clothes Line/tshirt.glb');
    final manny = File('$assets/mannequin/SKM_Manny_Simple.glb');
    expect(tshirt.existsSync() && manny.existsSync(), isTrue, reason: 'test-assets: the T-shirt and the mannequin');
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_garment_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeGarment')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeGarment', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeGarment.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${pDir.path}/contents/meshes/static').createSync(recursive: true);
    Directory('${pDir.path}/contents/meshes/skeletal').createSync(recursive: true);
    tshirt.copySync('${pDir.path}/contents/meshes/static/tshirt.glb');
    manny.copySync('${pDir.path}/contents/meshes/skeletal/SKM_Manny_Simple.glb');
    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      // Content Browser → New Asset → Character → Garment.
      await tester.runAsync(() => vm.createNewAsset(type: AssetType.garment, subFolder: 'characters'));
      final created = vm.realAssets.firstWhere((a) => a.type == AssetType.garment);

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(milliseconds: 800));

      vm.openSubEditorTab('Garment', asset: created);
      await settle(30);
      expect(find.byType(GarmentSubEditor), findsOneWidget);
      final editor = tester.state<GarmentSubEditorState>(find.byType(GarmentSubEditor));
      final garment = editor.vm;
      await tester.runAsync(() async {
        await garment.setSourceMesh('contents/meshes/static/tshirt.glb');
        await garment.setReferenceBody('contents/meshes/skeletal/SKM_Manny_Simple.glb');
        await garment.meshesReady;
      });
      expect(garment.sourceMesh, isNotNull, reason: garment.error);
      expect(garment.bodyMesh, isNotNull, reason: garment.error);
      await settle(60);
      await rec.hold(const Duration(milliseconds: 1200));

      // The gizmo's own drag handlers: move up to the chest, turn to face
      // the front, enlarge — in steps, as a drag streams them.
      final gizmo = editor.gizmo;
      Future<void> drag(SubEditorGizmoDelta Function(double t) at, {int steps = 24}) async {
        gizmo.onDragBegin!('garment');
        for (var i = 1; i <= steps; i++) {
          gizmo.onDragUpdate!('garment', at(i / steps));
          await settle(2);
          await rec.capture();
        }
        gizmo.onDragEnd!('garment');
      }

      await drag((t) => SubEditorGizmoDelta.translate(Vector3(0, -18 * t, 150 * t)));
      await tester.tap(find.byKey(const ValueKey('garment_rotate')));
      await settle(4);
      await drag((t) => SubEditorGizmoDelta.rotate(Vector3(0, 0, 1), 90 * t));
      await tester.tap(find.byKey(const ValueKey('garment_scale')));
      await settle(4);
      await drag((t) => SubEditorGizmoDelta.scale(TransformGizmoModel.uniform, 0.15 * t));
      expect(garment.doc.location[1], closeTo(150, 1));
      expect(garment.doc.rotation[1].abs(), closeTo(90, 1));
      expect(garment.doc.scale[0], closeTo(1.15, 0.01));
      final placedPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('garment_editor_placed', placedPng);

      // Landmarks by clicks: the viewport's click handler gets the camera's
      // ray; each landmark on the shirt, then on the body.
      final viewport = tester.widget<SubEditor3DViewport>(find.byKey(const ValueKey('garment_viewport')));
      ViewportRay front(double x, double y) => ViewportRay(Vector3(x, y, 250), Vector3(0, 0, -1));
      const marks = {'Neck': (0.0, 145.0), 'Shoulder L': (17.0, 141.0), 'Shoulder R': (-17.0, 141.0), 'Waist': (0.0, 104.0)};
      for (final e in marks.entries) {
        garment.addLandmark(e.key);
        await settle(3);
        await tester.tap(find.byKey(const ValueKey('garment_pick_garment')));
        await settle(3);
        viewport.onRayTap!(front(e.value.$1, e.value.$2));
        await settle(10);
        await rec.capture();
        await tester.tap(find.byKey(const ValueKey('garment_pick_body')));
        await settle(3);
        viewport.onRayTap!(front(e.value.$1, e.value.$2));
        await settle(10);
        await rec.hold(const Duration(milliseconds: 500));
      }
      expect(garment.doc.landmarks.where((l) => l.isComplete).length, 4);
      final landmarksPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('garment_editor_landmarks', landmarksPng);

      // Nudge it off, then Align.
      await tester.tap(find.byKey(const ValueKey('garment_move')));
      await settle(4);
      await drag((t) => SubEditorGizmoDelta.translate(Vector3(25 * t, 0, -15 * t)), steps: 16);
      final before = garment.landmarkErrors().values.fold(0.0, math.max);
      await tester.tap(find.byKey(const ValueKey('garment_align')));
      await settle(30);
      await rec.hold(const Duration(milliseconds: 1200));
      final after = garment.landmarkErrors().values.fold(0.0, math.max);
      debugPrint('[garment_smoke] largest landmark error before Align ${before.toStringAsFixed(1)} cm, after ${after.toStringAsFixed(1)} cm');
      expect(after, lessThan(before));
      final alignedPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('garment_editor_aligned', alignedPng);

      await tester.tap(find.byKey(const ValueKey('garment_save')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await settle(10);
      expect(garment.isDirty, isFalse);
      // Walk through the saved landmarks (each one highlighted in turn).
      for (final name in marks.keys) {
        await tester.tap(find.byKey(ValueKey('garment_landmark_$name')));
        await settle(4);
        await rec.hold(const Duration(milliseconds: 600));
      }
      rec.save(title);

      final saved = LuminaGarmentDocument.fromAsset(LuminaAsset.fromBytes(File('${pDir.path}/${created.relativePath}').readAsBytesSync()));
      debugPrint('[garment_smoke] saved ${saved.toJson()}');
      expect(saved.sourceMesh, 'contents/meshes/static/tshirt.glb');
      expect(saved.landmarks.map((l) => l.name), marks.keys);
      expect(saved.landmarks.every((l) => l.isComplete), isTrue);
      vm.dispose();
    } finally {
      if (tempProjectsDir.existsSync()) {
        try {
          tempProjectsDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  });
}
