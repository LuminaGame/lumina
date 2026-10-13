import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Draw distances in the level viewport: three props in a row, the left
/// one with a Max Draw Distance of 25 m and the right one with a Min Draw
/// Distance of 14 m (Mesh Component Details), the middle one free. The
/// camera dollies out and back: the right prop appears once the camera is
/// far enough and the left one leaves past 25 m.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const usedAssets = [
    'Props/AC_units/ac_unit_a_300x300.glb',
    'Props/Fuel Engines/fuel_engine_basic.glb',
    'Props/Barrels/fuel_barrel_red.glb',
  ];

  testWidgets('Draw Distance Smoke: meshes hide nearer than Min and farther than Max Draw Distance as the camera dollies',
      (tester) async {
    const name = 'Draw Distance Smoke: meshes hide nearer than Min and farther than Max Draw Distance as the camera dollies';
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_dd_smoke_');
    const project = LuminaProject(projectName: 'DrawDistSmoke', activeLevel: 'contents/levels/L_Main.lmas');
    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      final ids = <String>[];
      for (final (i, rel) in usedAssets.indexed) {
        final src = File('${SmokeArtifacts.testAssetsDir.path}/$rel');
        expect(src.existsSync(), isTrue, reason: '$rel must exist');
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: src.path));
        final stem = rel.split('/').last.replaceAll('.glb', '');
        final asset = vm.realAssets.firstWhere((a) => a.fileName.startsWith(stem));
        final before = vm.actors.map((a) => a.id).toSet();
        await tester.runAsync(() => vm.spawnActorFromAsset(asset, location: [i * 600.0, 0.0, 0.0]));
        ids.add(vm.actors.firstWhere((a) => !before.contains(a.id)).id);
      }
      final (left, middle, right) = (ids[0], ids[1], ids[2]);
      // The Details' Mesh Component (a dropped mesh gets one through Add
      // Component), its Render Distance & Culling fields.
      String meshComponent(String id) =>
          vm.actors.firstWhere((a) => a.id == id).components.where((c) => c.type == 'LuminaMeshComponent').firstOrNull?.id ??
          vm.addComponentWithTransaction(id, 'LuminaMeshComponent')!.id;
      vm.updateComponentProperty(left, meshComponent(left), 'maxDrawDistance', 25.0);
      vm.updateComponentProperty(right, meshComponent(right), 'minDrawDistance', 14.0);

      // Looking along +Y at the middle prop: the eye is as far from the
      // left and right props as sqrt(600² + distance²).
      void camera(double distance) => vm.restoreCameraSnapshot([0, 15, distance, 600, 0, 60]);
      camera(900);

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: boundaryKey, child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm))),
      );
      Future<void> frame() async {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }

      final loading = vm.loadLevelMeshes();
      for (var i = 0; i < 400 && (vm.meshesLoading || i < 60); i++) {
        await frame();
      }
      await tester.runAsync(() => loading);
      for (var i = 0; i < 30; i++) {
        await frame();
      }

      final dynamic viewport = tester.state(find.byType(ViewportWidget));
      List<bool> shown() => [for (final id in ids) viewport.editorActorInSceneForTest(id) as bool];
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String label, List<bool> state) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($label)', png,
            usedAssets: usedAssets, metrics: {'camera_distance_cm': vm.cameraDistance, 'left_middle_right_in_scene': state});
      }

      final near = shown();
      await shot('near 9 m, right prop under its 14 m minimum', near);
      await rec.hold(const Duration(seconds: 2));
      // Out to 32 m and back, a frame at a time.
      final seen = <List<bool>>[];
      for (var i = 0; i <= 360; i++) {
        final t = i <= 180 ? i / 180 : (360 - i) / 180;
        camera(900 + t * 2300);
        await frame();
        await rec.captureIfChanged();
        final s = shown();
        if (seen.isEmpty || seen.last.toString() != s.toString()) seen.add(s);
        if (i == 70) await shot('middle, all three drawn', s);
        if (i == 180) await shot('far 32 m, left prop past its 25 m maximum', s);
      }
      await rec.hold(const Duration(seconds: 1));
      rec.save(name, usedAssets: usedAssets);
      debugPrint('[draw_distance_smoke] states over the dolly: $seen');

      expect(near, [true, true, false], reason: 'at 9 m the right prop is nearer than 14 m');
      final states = [for (final s in seen) s.toString()];
      expect(states, contains('[true, true, true]'), reason: 'between the limits all three are drawn');
      expect(states, contains('[false, true, true]'), reason: 'past 25 m the left prop leaves');
      expect(shown(), [true, true, false], reason: 'back at 9 m');
      expect(middle, isNotEmpty);
      vm.dispose();
    } finally {
      try {
        tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {
        // a cache writer may still hold a file; the OS temp folder is cleaned later
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
