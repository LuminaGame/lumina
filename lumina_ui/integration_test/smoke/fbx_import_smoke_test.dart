import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/viewport_picker.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/animation_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Smoke — FBX import on real Unreal exports.
///
/// Boots the real Lumina Studio on a real Third Person project (real
/// `flutter create`, the Quinn mannequin and its clips), imports five FBX
/// props from `test-assets/FBX/` through the editor's import pipeline, places
/// them in the level next to the mannequin and shows them in the Filament
/// level viewport at their real size (a 97 cm casino chair, a 2.6 m slot
/// machine, a 79 cm table with a laptop on it), then imports
/// `AS_Poker_Dealer_Idle_01.FBX` — an animation-only Unreal FBX — which the
/// importer retargets onto the mannequin, opens it in the Animation editor and
/// plays it. PNGs of both states plus a WebM of the whole scenario.
///
/// Runs on GPU 1 (NVIDIA RTX PRO 2000) — `tool/smoke_report.dart` injects the
/// GPU environment.
Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

/// Mean absolute RGB difference of [rect] between two PNG frames.
Future<double> _regionDifference(WidgetTester tester, Uint8List a, Uint8List b, Rect rect) async {
  return (await tester.runAsync(() async {
    Future<(ByteData, int)> decode(Uint8List png) async {
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final width = frame.image.width;
      frame.image.dispose();
      return (data!, width);
    }

    final (da, w) = await decode(a);
    final (db, _) = await decode(b);
    var sum = 0.0;
    var n = 0;
    for (var y = rect.top.toInt(); y < rect.bottom.toInt(); y += 2) {
      for (var x = rect.left.toInt(); x < rect.right.toInt(); x += 2) {
        final o = (y * w + x) * 4;
        for (var c = 0; c < 3; c++) {
          sum += (da.getUint8(o + c) - db.getUint8(o + c)).abs();
        }
        n += 3;
      }
    }
    return n == 0 ? 0.0 : sum / n;
  }))!;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // FBX (test-assets/FBX/StaticMeshes) → editor location (cm, Z up). The row
  // stands in front of the template's hurdle (y ±25); the 8 m reception
  // counter (its pivot at one end, extending 271 cm towards −Y) closes the
  // scene behind it.
  const props = {
    'SM_Slot_Machine': [-200.0, -150.0, 0.0],
    'SM_Casino_Chair': [-60.0, -150.0, 0.0],
    'SM_Table': [100.0, -150.0, 0.0],
    'SM_Laptop': [100.0, -150.0, 79.4], // on the table top (79.4 cm)
    'SM_Counter_1': [-420.0, 650.0, 0.0],
  };
  const animation = 'AS_Poker_Dealer_Idle_01';
  final usedAssets = [
    for (final p in props.keys) 'FBX/StaticMeshes/$p.FBX',
    'FBX/Animations/$animation.FBX',
  ];
  const testName = 'FBX Import Smoke: Unreal FBX props at real size + AS_ clip retargeted onto the mannequin';

  testWidgets(testName, (tester) async {
    final assets = SmokeArtifacts.testAssetsDir.path;
    for (final rel in usedAssets) {
      if (!File('$assets/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    final root = Directory.systemTemp.createTempSync('fbx_import_smoke_');
    EditorViewModel? vm;
    try {
      // A launcher Third Person project: the real scaffold, real flutter create.
      final project = (await tester.runAsync(() => ProjectRepository(
            configDir: Directory('${root.path}/.config')..createSync(recursive: true),
          ).createProject(projectName: 'fbx_smoke', projectLocation: root.path, template: kThirdPersonTemplateId)))!;

      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
      final editor = vm;
      await tester.runAsync(() => editor.ensureDefaultLevelAssets());

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

      Future<void> importWhileRecording(String path, {String? targetSkeletonPath}) async {
        var done = false;
        final importing = editor
            .processImportPipeline(sourceFilePath: path, targetSkeletonPath: targetSkeletonPath)
            .whenComplete(() => done = true);
        while (!done) {
          await rec.hold(const Duration(milliseconds: 100));
        }
        await importing;
      }

      // 1. Import the Unreal FBX props through the editor's pipeline.
      for (final name in props.keys) {
        await importWhileRecording('$assets/FBX/StaticMeshes/$name.FBX');
      }
      editor.refreshAssets();
      await rec.hold(const Duration(milliseconds: 500));

      // 2. Place them in the level and check each at its real size, upright.
      final expectedHeights = {
        'SM_Slot_Machine': 259.9,
        'SM_Casino_Chair': 96.8,
        'SM_Table': 79.4,
        'SM_Laptop': 23.9,
        'SM_Counter_1': 110.2,
      };
      for (final entry in props.entries) {
        final asset = editor.realAssets.firstWhere(
          (a) => a.fileName == '${entry.key}.lmas' && a.type == AssetType.filamesh,
          orElse: () => throw StateError('${entry.key}.FBX produced no static mesh asset'),
        );
        await tester.runAsync(() => editor.spawnActorFromAsset(asset, location: entry.value));
        final actor = editor.actors.last;
        final box = ViewportPicker.editorSpaceBounds(actor)!;
        final size = box.max - box.min;
        expect(size.z, closeTo(expectedHeights[entry.key]!, 3.0), reason: '${entry.key} height in cm along Z (up)');
        expect(actor.scale, [1.0, 1.0, 1.0], reason: 'no scale guess: the FBX came in as metres');
        await rec.hold(const Duration(milliseconds: 400));
      }

      // The mannequin stands beside them for scale.
      final quinnAsset = editor.realAssets.firstWhere((a) => a.relativePath == LuminaThirdPersonContent.projectMeshAssetPath);
      await tester.runAsync(() => editor.spawnActorFromAsset(quinnAsset, location: [-340.0, -150.0, 0.0]));
      await rec.hold(const Duration(milliseconds: 400));

      // Frame the row with the viewport's own controls, as a user does: select
      // the chair, Focus Selection [F], zoom out, raise the pivot and orbit.
      // (A camera set through the view model reaches the render
      // too; the HUD and drags stay because they show the navigation on video.)
      Finder hud(IconData icon) =>
          find.descendant(of: find.byType(ViewportWidget), matching: find.byIcon(icon));
      final chair = editor.actors.firstWhere((a) => a.name.startsWith('SM_Casino_Chair'));
      editor.selectActor(chair);
      await rec.hold(const Duration(milliseconds: 300));
      await tester.tap(hud(LucideIcons.scan).first);
      await rec.hold(const Duration(milliseconds: 500));
      for (var i = 0; i < 9; i++) {
        await tester.tap(hud(LucideIcons.zoomOut).first);
        await rec.hold(const Duration(milliseconds: 150));
      }
      final viewport = tester.getRect(find.byType(ViewportWidget));
      final spot = Offset(viewport.center.dx, viewport.bottom - 60);
      await rec.drag(spot, spot - const Offset(0, 70), steps: 15, buttons: kPrimaryButton | kSecondaryButton);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await rec.drag(spot, spot + const Offset(240, 0), steps: 60);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      expect(editor.cameraDistance, inInclusiveRange(450.0, 800.0));
      await rec.hold(const Duration(milliseconds: 500));
      final propsPng = await SmokeArtifacts.captureWidgetPng(tester, find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('fbx_import_props_in_level', propsPng, usedAssets: usedAssets);

      // 3. Import the Unreal animation FBX: it is retargeted onto the
      // mannequin (matched by bone names) and bundled into its GLB.
      await importWhileRecording('$assets/FBX/Animations/$animation.FBX');
      editor.refreshAssets();
      final clipAsset = editor.realAssets.firstWhere((a) => a.fileName == '$animation.lmas');
      expect(clipAsset.type, AssetType.animation);
      final clipLmas = LuminaAsset.fromBytes(File(clipAsset.lmasPath!).readAsBytesSync());
      expect(clipLmas.metadata['source_mesh'], LuminaThirdPersonContent.projectMeshAssetPath);
      expect(clipLmas.metadata['retarget_status'], startsWith('bound'));
      final meshGlb = File('${editor.projectDirPath}/${LuminaThirdPersonContent.projectMeshGlbPath}').readAsBytesSync();
      expect(GlbAnimationMerger.animationNames(meshGlb), contains(animation));

      // 4. Open it in the Animation editor and play it on the mannequin.
      editor.openSubEditorTab('ANIMATION', asset: clipAsset);
      await _settle(tester, 30);
      expect(find.byType(AnimationSubEditor), findsOneWidget);
      for (var i = 0; i < 40 && find.textContaining('Clip: $animation').evaluate().isEmpty; i++) {
        await rec.hold(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Clip: $animation'), findsWidgets, reason: 'the editor selected the retargeted clip');
      await rec.hold(const Duration(seconds: 1));

      await tester.tap(find.byKey(const ValueKey('anim_play_pause')));
      await rec.hold(const Duration(milliseconds: 1500));
      final viewportRect = tester.getRect(find.byType(SubEditor3DViewport).first);
      final framesA = await SmokeArtifacts.captureWidgetPng(tester, find.byKey(boundaryKey));
      await rec.hold(const Duration(milliseconds: 2500));
      final framesB = await SmokeArtifacts.captureWidgetPng(tester, find.byKey(boundaryKey));
      final moved = await _regionDifference(tester, framesA, framesB, viewportRect.deflate(40));
      expect(moved, greaterThan(0.2), reason: 'the mannequin moves in the preview while the clip plays (mean Δ $moved)');
      SmokeArtifacts.saveScreenshot('fbx_import_animation_playing', framesB, usedAssets: usedAssets);

      // Orbit the preview while it plays.
      final preview = tester.getCenter(find.byType(SubEditor3DViewport).first);
      await rec.drag(preview - const Offset(140, 0), preview + const Offset(140, 0), steps: 45);
      await rec.hold(const Duration(milliseconds: 1500));
      expect(rec.recorded, greaterThanOrEqualTo(const Duration(seconds: 10)));
      rec.save(testName, usedAssets: usedAssets);
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  });
}
