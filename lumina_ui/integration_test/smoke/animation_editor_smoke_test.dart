import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
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
}
