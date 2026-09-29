import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/menu_bar_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Smoke — camera moves made outside the viewport reach the render.
///
/// Opens a real project with three real props from `test-assets/` spread
/// several metres apart, then frames each one from the World Outliner's
/// right-click "Focus Camera on Actor" and finally runs View → Reset Camera
/// from the menu bar. None of these send a gesture to the viewport; before
/// the fix the view model's camera moved while the Filament frame stayed where
/// it was. Each step checks, through the native camera's own matrices, that
/// the focused point is in the middle of the rendered frame, and the whole
/// run is on video.
///
/// Runs on GPU 1 (NVIDIA RTX PRO 2000) — `tool/smoke_report.dart` injects the
/// GPU environment.
Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Test asset → where it is placed (editor space: cm, Z up).
  const props = {
    'Props/AC_units/aircon_small.glb': [-450.0, 250.0, 0.0],
    'Props/Barrels/fuel_barrel_red.glb': [50.0, -400.0, 0.0],
    'Props/Banana Bunch/banana_bunch_long.glb': [500.0, 300.0, 80.0],
  };
  const testName = 'Viewport Camera Sync Smoke: Outliner Focus and View → Reset Camera move the rendered view';

  testWidgets(testName, (tester) async {
    for (final rel in props.keys) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    final root = Directory.systemTemp.createTempSync('lumina_smoke_camera_sync_');
    final pDir = Directory('${root.path}/CameraSync')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'CameraSync', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/CameraSync.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    EditorViewModel? vm;
    try {
      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
      final editor = vm;
      await tester.runAsync(() => editor.ensureDefaultLevelAssets());

      // Real assets through the real import pipeline, placed apart.
      final placed = <String, EditorActorNode>{};
      for (final entry in props.entries) {
        await tester.runAsync(
            () => editor.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/${entry.key}'));
        editor.refreshAssets();
        final stem = entry.key.split('/').last.replaceAll('.glb', '');
        final asset = editor.realAssets.firstWhere((a) => a.fileName == '$stem.lmas' && a.type == AssetType.filamesh);
        await tester.runAsync(() => editor.spawnActorFromAsset(asset, location: entry.value));
        placed[entry.key] = editor.actors.last;
      }
      editor.clearSelection();

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
      ));
      await _settle(tester, 40);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      dynamic viewport() => tester.state(find.byType(ViewportWidget));
      final size = tester.getSize(find.byType(ViewportWidget));
      final centre = Offset(size.width / 2, size.height / 2);
      Offset? drawnAt(List<double> p) => viewport().nativeProjectForTest(p[0], p[1], p[2], size) as Offset?;

      // 1. Outliner → right-click → Focus Camera on Actor, for each prop.
      for (final entry in placed.entries) {
        final actor = entry.value;
        await tester.tap(find.byKey(ValueKey('row_gesture_${actor.id}')), buttons: kSecondaryButton);
        await _settle(tester);
        await rec.hold(const Duration(milliseconds: 700));
        await tester.tap(find.text('Focus Camera on Actor').last);
        await _settle(tester);
        await rec.hold(const Duration(milliseconds: 1500));

        expect(editor.cameraPanX, actor.location[0], reason: 'the view model framed ${actor.name}');
        final at = drawnAt(actor.location);
        expect(at, isNotNull, reason: '${actor.name} must be in front of the Filament camera');
        expect((at! - centre).distance, lessThan(2.0),
            reason: 'Focus must centre ${actor.name} in the rendered frame, not only in the view model '
                '(drawn at $at, viewport centre $centre)');
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('camera_sync_focus_${actor.name}', png, usedAssets: [entry.key]);
      }

      // 2. View → Reset Camera from the menu bar.
      await tester.tap(find.descendant(of: find.byType(MenuBarWidget), matching: find.text('View')).first);
      await _settle(tester);
      await rec.hold(const Duration(milliseconds: 700));
      await tester.tap(find.text('Reset Camera').last);
      await _settle(tester);
      await rec.hold(const Duration(milliseconds: 1500));
      expect([editor.cameraPanX, editor.cameraPanY, editor.cameraPanZ], [0.0, 0.0, 0.0]);
      final origin = drawnAt([0.0, 0.0, 0.0]);
      expect(origin, isNotNull);
      expect((origin! - centre).distance, lessThan(2.0),
          reason: 'Reset Camera must re-aim the rendered view at the origin (drawn at $origin)');
      final resetPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('camera_sync_reset_camera', resetPng, usedAssets: props.keys.toList());

      await rec.hold(const Duration(seconds: 1));
      expect(rec.recorded, greaterThanOrEqualTo(const Duration(seconds: 10)));
      rec.save(testName, usedAssets: props.keys.toList());
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  });
}
