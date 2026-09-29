import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/animation_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/widgets/animation_retarget_modal.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Animation Preview Mesh & Retargeting Tests', () {
    late Directory tempDir;
    late Directory projDir;
    late Directory animDir;
    late Directory meshDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('anim_preview_test_');
      projDir = Directory('${tempDir.path}/TestProj')..createSync(recursive: true);
      animDir = Directory('${projDir.path}/contents/animations')..createSync(recursive: true);
      meshDir = Directory('${projDir.path}/contents/meshes/skeletal')..createSync(recursive: true);

      // Create dummy Manny and Quinn skeletal mesh lmas files
      final mannyAsset = LuminaAsset(
        assetId: 'manny-01',
        name: 'SKM_Manny_Simple',
        type: AssetType.filamesh,
        rawPayload: Uint8List.fromList([0x67, 0x6C, 0x54, 0x46, 2, 0, 0, 0, 0, 0, 0, 0]),
      );
      File('${meshDir.path}/SKM_Manny_Simple.lmas').writeAsBytesSync(mannyAsset.toProtoBufferBytes());

      final quinnAsset = LuminaAsset(
        assetId: 'quinn-01',
        name: 'SKM_Superhero_Female',
        type: AssetType.filamesh,
        rawPayload: Uint8List.fromList([0x67, 0x6C, 0x54, 0x46, 2, 0, 0, 0, 0, 0, 0, 0]),
      );
      File('${meshDir.path}/SKM_Superhero_Female.lmas').writeAsBytesSync(quinnAsset.toProtoBufferBytes());

      // Create test animation asset
      final animAsset = LuminaAsset(
        assetId: 'anim-01',
        name: 'Walk_Bwd_Loop',
        type: AssetType.animation,
        rawPayload: Uint8List.fromList([0x67, 0x6C, 0x54, 0x46, 2, 0, 0, 0, 0, 0, 0, 0]),
      );
      File('${animDir.path}/Walk_Bwd_Loop.lmas').writeAsBytesSync(animAsset.toProtoBufferBytes());
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('availableSkeletalMeshes scans and exposes skeletal meshes from project', () async {
      final animPath = '${animDir.path}/Walk_Bwd_Loop.lmas';
      final vm = AnimationEditorViewModel(assetPath: animPath);
      await vm.load();

      expect(vm.availableSkeletalMeshes.length, greaterThanOrEqualTo(2));
      final meshNames = vm.availableSkeletalMeshes.map((m) => m.fileName).toList();
      expect(meshNames, contains('SKM_Manny_Simple.lmas'));
      expect(meshNames, contains('SKM_Superhero_Female.lmas'));
    });

    test('setPreviewMesh updates previewMeshAsset and marks view model dirty', () async {
      final animPath = '${animDir.path}/Walk_Bwd_Loop.lmas';
      final vm = AnimationEditorViewModel(assetPath: animPath);
      await vm.load();

      final quinnMesh = vm.availableSkeletalMeshes.firstWhere((m) => m.fileName.contains('Superhero'));
      await vm.setPreviewMesh(quinnMesh);

      expect(vm.previewMeshAsset, equals(quinnMesh));
      expect(vm.previewMeshPath, equals(quinnMesh.relativePath));
      expect(vm.previewMeshSourcePath, contains('SKM_Superhero_Female.lmas'));
      expect(vm.isDirty, isTrue);
    });

    test('executeRetarget creates a new valid .lmas file in contents/animations', () async {
      final animPath = '${animDir.path}/Walk_Bwd_Loop.lmas';
      final vm = AnimationEditorViewModel(assetPath: animPath);
      await vm.load();

      final quinnMesh = vm.availableSkeletalMeshes.firstWhere((m) => m.fileName.contains('Superhero'));
      final outputPath = await vm.executeRetarget(
        targetMeshAsset: quinnMesh,
        outputName: 'Quinn_Walk_Bwd',
      );

      expect(outputPath, isNotNull);
      final outputFile = File(outputPath!);
      expect(outputFile.existsSync(), isTrue);
      expect(outputFile.path, contains('Quinn_Walk_Bwd.lmas'));
    });

    test('executeRetarget strips trailing .lmas to prevent double extension', () async {
      final animPath = '${animDir.path}/Walk_Bwd_Loop.lmas';
      final vm = AnimationEditorViewModel(assetPath: animPath);
      await vm.load();

      final quinnMesh = vm.availableSkeletalMeshes.firstWhere((m) => m.fileName.contains('Superhero'));
      final outputPath = await vm.executeRetarget(
        targetMeshAsset: quinnMesh,
        outputName: 'Quinn_Walk_Bwd.lmas',
      );

      expect(outputPath, isNotNull);
      final outputFile = File(outputPath!);
      expect(outputFile.existsSync(), isTrue);
      expect(outputFile.path, endsWith('Quinn_Walk_Bwd.lmas'));
      expect(outputFile.path, isNot(contains('.lmas.lmas')));
    });

    testWidgets('AnimationSubEditor displays preview mesh picker and retarget button in UI', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final animPath = '${animDir.path}/Walk_Bwd_Loop.lmas';
      final vm = AnimationEditorViewModel(assetPath: animPath);
      await tester.runAsync(() => vm.load());

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: AnimationSubEditor(
              assetName: 'Walk_Bwd_Loop',
              assetPath: animPath,
              viewModel: vm,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify Preview Mesh and Retarget buttons exist
      expect(find.text('Preview Mesh'), findsOneWidget);
      expect(find.text('Retarget Animation'), findsOneWidget);
    });

    testWidgets('AnimationRetargetModal displays source animation and target skeletal mesh pickers', (tester) async {
      final animPath = '${animDir.path}/Walk_Bwd_Loop.lmas';
      final vm = AnimationEditorViewModel(assetPath: animPath);
      await tester.runAsync(() => vm.load());

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: AnimationRetargetModal(
              viewModel: vm,
              sourceAssetName: 'Walk_Bwd_Loop',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Retarget Animation Asset'), findsOneWidget);
      expect(find.text('Source Animation'), findsOneWidget);
      expect(find.text('Target Skeletal Mesh'), findsOneWidget);
      expect(find.text('Export Retargeted Asset'), findsOneWidget);
    });
  });
}
