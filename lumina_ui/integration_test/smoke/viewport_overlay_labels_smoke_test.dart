import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Smoke — actor labels and icons sit on their actors in a large
/// level.
///
/// Opens the Third Person template's 60 m level from disk, with two real
/// props from `test-assets/` placed near its far corners, and lets the editor
/// frame it (from ~120 m). Before the fix the Filament camera stopped at
/// 50 m while the overlay projected from the framed distance, so every label
/// sat on a shrunken copy of the level around the view centre. Each check
/// compares where the overlay paints a label with where Filament draws the
/// actor (the native camera's own matrices), before and after an Alt+LMB
/// orbit, and the whole run is on video.
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
    'Props/Barrels/fuel_barrel_red.glb': [2400.0, 2400.0, 0.0],
    'Props/AC_units/aircon_small.glb': [-2400.0, -2600.0, 0.0],
  };
  const labelled = ['Pillar_01', 'Pillar_03', 'Pillar_06', 'Wall_North', 'Wall_East', 'Marker_Sphere', 'Platform'];
  const testName = 'Viewport Overlay Labels Smoke: labels sit on their actors in the 60 m Third Person level';

  testWidgets(testName, (tester) async {
    for (final rel in props.keys) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    final root = Directory.systemTemp.createTempSync('lumina_smoke_overlay_labels_');
    final pDir = Directory('${root.path}/OverlayLabels')..createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);
    final template = GameTemplateCatalog.byId(kThirdPersonTemplateId);
    final project = LuminaProject(
      projectName: 'OverlayLabels',
      activeLevel: 'contents/levels/L_DefaultLevel.lmas',
      template: kThirdPersonTemplateId,
      input: template.input,
    );
    File('${pDir.path}/OverlayLabels.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    // The level exactly as the launcher scaffolds it; the editor reads it back.
    File('${pDir.path}/contents/levels/L_DefaultLevel.lmas').writeAsStringSync(jsonEncode(<String, dynamic>{
      'assetId': 'level_L_DefaultLevel',
      'name': 'L_DefaultLevel',
      'type': 'level',
      'relativePath': 'contents/levels/L_DefaultLevel.lmas',
      'rawPayload': null,
      'metadata': <String, dynamic>{'actors': template.levelActors},
    }));

    EditorViewModel? vm;
    try {
      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
      final editor = vm;
      await tester.runAsync(() => editor.ensureDefaultLevelAssets());
      expect(editor.actors.where((a) => a.name.startsWith('Pillar_')), hasLength(6), reason: 'the template level is loaded');

      // Real props through the real import pipeline, near the far corners.
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
      editor.frameLevelBounds();
      expect(editor.cameraDistance, greaterThan(5000.0), reason: 'the 60 m level is framed from further than 50 m');

      tester.view.physicalSize = const Size(1600, 1000);
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
      await _settle(tester, 60);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(milliseconds: 1500));

      dynamic viewport() => tester.state(find.byType(ViewportWidget));
      final size = tester.getSize(find.byType(ViewportWidget));
      final names = [...labelled, for (final a in placed.values) a.name];

      void expectLabelsOnActors(String when) {
        for (final name in names) {
          final actor = editor.actors.firstWhere((a) => a.name == name);
          final p = actor.location;
          final rendered = viewport().nativeProjectForTest(p[0], p[1], p[2], size) as Offset?;
          final label = viewport().overlayProjectForTest(p[0], p[1], p[2], size) as Offset?;
          expect(rendered, isNotNull, reason: '$when: $name is in front of the Filament camera');
          expect(label, isNotNull, reason: '$when: $name is in front of the overlay camera');
          expect((label! - rendered!).distance, lessThan(2.0),
              reason: "$when: $name's label is painted at $label, Filament draws it at $rendered");
        }
      }

      expectLabelsOnActors('framed');
      SmokeArtifacts.saveScreenshot('viewport_overlay_labels_framed',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
          usedAssets: props.keys.toList());

      // Alt + LMB orbit, the way a user tumbles the view: labels ride along.
      final viewportRect = tester.getRect(find.byType(ViewportWidget));
      final from = viewportRect.center + const Offset(-260, 40);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await rec.drag(from, from + const Offset(520, 40), steps: 150);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await rec.hold(const Duration(milliseconds: 1200));
      expectLabelsOnActors('after an Alt+LMB orbit');

      // Select a far pillar from the level: its label and gizmo are on it.
      final pillar = editor.actors.firstWhere((a) => a.name == 'Pillar_06');
      editor.selectActors([pillar.id]);
      await rec.hold(const Duration(milliseconds: 1500));
      expectLabelsOnActors('with Pillar_06 selected');
      SmokeArtifacts.saveScreenshot('viewport_overlay_labels_orbited',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
          usedAssets: props.keys.toList());

      // Tilt the view down over the level (Alt + LMB, vertical): the labels
      // follow the pitch as well as the yaw.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await rec.drag(from + const Offset(300, -40), from + const Offset(240, 40), steps: 90);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await rec.hold(const Duration(milliseconds: 1200));
      expectLabelsOnActors('after tilting the view');
      await rec.hold(const Duration(milliseconds: 800));
      expect(rec.recorded, greaterThanOrEqualTo(const Duration(seconds: 10)));
      rec.save(testName, usedAssets: props.keys.toList());
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  });
}
