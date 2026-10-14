import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'support/garment_tutorial.dart';

/// The Garment tutorial as a recorded walkthrough with captions and a
/// virtual cursor: the T-shirt from `test-assets/` made a Garment on the
/// mannequin, landmarked by clicks, aligned, saved and put into a character
/// Blueprint's Torso slot, where it is fitted and masks the body.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const title = 'Garment Tutorial Smoke: a T-shirt made a Garment on the mannequin, step by step with captions';
  const usedAssets = ['Props/Clothes Line/tshirt.glb', 'mannequin/SKM_Manny_Simple.glb'];

  testWidgets(title, (tester) async {
    final temp = Directory.systemTemp.createTempSync('lgt_');
    const project = LuminaProject(projectName: 'GarmentTut', activeLevel: 'contents/levels/L_Main.lmas');
    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: temp.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      for (final rel in usedAssets) {
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$rel'));
      }
      final shirt = vm.realAssets.firstWhere((a) => a.fileName.startsWith('tshirt'));
      final body = vm.realAssets.firstWhere((a) => a.fileName.startsWith('SKM_Manny_Simple'));
      // A character Blueprint: the body in slot Body, an empty Torso slot
      // following it.
      final bpPath = 'contents/blueprints/BP_Mannequin_Outfit.lmas';
      final components = [
        {'id': 'root_scene', 'name': 'Root', 'type': 'LuminaSceneComponent', 'isSceneComponent': true, 'properties': <String, dynamic>{}},
        {
          'id': 'comp_body',
          'name': 'Body',
          'type': 'LuminaSkeletalMeshComponent',
          'parentId': 'root_scene',
          'isSceneComponent': true,
          'properties': {'skeletalMeshAsset': body.relativePath, 'slot': 'Body', 'animMode': 'Disabled'},
        },
        {
          'id': 'comp_torso',
          'name': 'Torso',
          'type': 'LuminaSkeletalMeshComponent',
          'parentId': 'comp_body',
          'isSceneComponent': true,
          'properties': {'skeletalMeshAsset': '', 'slot': 'Torso', 'poseFrom': 'comp_body', 'masksBody': true, 'animMode': 'Disabled'},
        },
      ];
      final doc = LuminaBlueprintDocument.fromJson({'parentClass': 'LuminaActor', 'components': components});
      File('${temp.path}/GarmentTut/$bpPath')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(LuminaAsset(
          assetId: 'BP_Mannequin_Outfit',
          name: 'BP_Mannequin_Outfit',
          type: AssetType.actor,
          rawPayload: utf8.encode(jsonEncode(doc.toJson())),
          metadata: const {'parent_class': 'LuminaActor'},
        ).toProtoBufferBytes());
      vm.refreshAssets();
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final boundaryKey = GlobalKey();
      final overlay = SmokeTutorialController();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: SmokeTutorialOverlay(
          controller: overlay,
          child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
        ),
      ));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      final tutor = SmokeTutor(tester, rec, overlay, total: garmentTutorialSteps);
      await runGarmentTutorial(
        tester,
        vm,
        tutor,
        GarmentTutorialSetup(
          sourceFile: shirt.fileName,
          sourceSearch: 'tshirt',
          bodyFile: body.fileName,
          bodySearch: 'Manny',
          blueprintPath: bpPath,
          slotComponentId: 'comp_torso',
          garmentName: 'tişörtün',
        ),
        shot: (label) async => SmokeArtifacts.saveScreenshot(
          '$title $label',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
          usedAssets: usedAssets,
        ),
      );
      rec.save(title, usedAssets: usedAssets);
      vm.dispose();
    } finally {
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
