import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/anim_blueprint/anim_blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/widgets/anim_blueprint_retarget_modal.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Uint8List _makeTestGlb({List<String> animations = const []}) {
  return GlbDocument({
    'asset': {'version': '2.0'},
    'animations': [
      for (final a in animations)
        {'name': a, 'channels': <Map<String, dynamic>>[], 'samplers': <Map<String, dynamic>>[]}
    ],
    'skins': [
      {'joints': [0]}
    ],
    'nodes': [
      {'name': 'root'}
    ],
  }, Uint8List(0)).encode();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Animation Blueprint Retargeting Tests', () {
    late Directory tempDir;
    late Directory projDir;
    late Directory animDir;
    late Directory quinnAnimDir;
    late Directory meshDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('abp_retarget_test_');
      projDir = Directory('${tempDir.path}/TestProj')..createSync(recursive: true);
      animDir = Directory('${projDir.path}/contents/animations')..createSync(recursive: true);
      quinnAnimDir = Directory('${animDir.path}/SKM_Superhero_Female')..createSync(recursive: true);
      meshDir = Directory('${projDir.path}/contents/meshes/skeletal')..createSync(recursive: true);

      // 1. Create Quinn and Manny skeletal mesh lmas files and companion entity GLBs
      final quinnGlb = _makeTestGlb(animations: ['Idle_Loop', 'Walk_Fwd_Loop', 'Walk_Bwd_Loop']);
      final mannyGlb = _makeTestGlb();

      final quinnAsset = LuminaAsset(
        assetId: 'quinn-mesh',
        name: 'SKM_Superhero_Female',
        type: AssetType.filameshSk,
        rawPayload: quinnGlb,
      );
      File('${meshDir.path}/SKM_Superhero_Female.lmas').writeAsBytesSync(quinnAsset.toProtoBufferBytes());
      File('${meshDir.path}/SKM_Superhero_Female.entity.glb').writeAsBytesSync(quinnGlb);

      final mannyAsset = LuminaAsset(
        assetId: 'manny-mesh',
        name: 'SKM_Manny_Simple',
        type: AssetType.filameshSk,
        rawPayload: mannyGlb,
      );
      File('${meshDir.path}/SKM_Manny_Simple.lmas').writeAsBytesSync(mannyAsset.toProtoBufferBytes());
      File('${meshDir.path}/SKM_Manny_Simple.entity.glb').writeAsBytesSync(mannyGlb);

      // 2. Create Blend Space referencing Quinn mesh and walk clips
      final bsDoc = const LuminaBlendSpaceDocument(
        axes: [LuminaBlendSpaceAxis('Speed', -100, 100)],
        samples: [
          LuminaBlendSpaceSample('Walk_Fwd_Loop', 0, 1),
          LuminaBlendSpaceSample('Walk_Bwd_Loop', 0, -1),
        ],
      );
      final bsAsset = LuminaAsset(
        assetId: 'quinn-bs-01',
        name: 'BS_Walk',
        type: AssetType.blendSpace,
        metadata: {
          AnimGraphAssetService.targetMeshKey: 'contents/meshes/skeletal/SKM_Superhero_Female.lmas',
        },
        rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(bsDoc.toJson()))),
      );
      File('${quinnAnimDir.path}/BS_Walk.lmas').writeAsBytesSync(bsAsset.toProtoBufferBytes());

      // 3. Create Animation Blueprint document
      final abpDoc = LuminaAnimBlueprintDocument(
        targetMesh: 'contents/meshes/skeletal/SKM_Superhero_Female.lmas',
        stateMachines: [
          LuminaAnimStateMachine(
            name: 'Locomotion',
            entryState: 'Idle',
            transitions: const [],
            states: [
              const LuminaAnimState(
                'Idle',
                LuminaAnimPose.clip('Idle_Loop'),
              ),
              const LuminaAnimState(
                'Walk',
                LuminaAnimPose.blendSpace(
                  'contents/animations/SKM_Superhero_Female/BS_Walk.lmas',
                  xVariable: 'Speed',
                ),
              ),
            ],
          ),
        ],
      );
      final abpAsset = LuminaAsset(
        assetId: 'quinn-abp-01',
        name: 'ABP_Quinn',
        type: AssetType.animBlueprint,
        metadata: {
          AnimGraphAssetService.targetMeshKey: 'contents/meshes/skeletal/SKM_Superhero_Female.lmas',
        },
        rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(abpDoc.toJson()))),
      );
      File('${quinnAnimDir.path}/ABP_Quinn.lmas').writeAsBytesSync(abpAsset.toProtoBufferBytes());
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('linkedClips and linkedBlendSpacePaths extract all referenced animations', () async {
      final abpPath = '${quinnAnimDir.path}/ABP_Quinn.lmas';
      final vm = AnimBlueprintEditorViewModel(assetPath: abpPath);
      await vm.load();

      expect(vm.linkedClips, contains('Idle_Loop'));
      expect(vm.linkedClips, contains('Walk_Fwd_Loop'));
      expect(vm.linkedClips, contains('Walk_Bwd_Loop'));
      expect(vm.linkedClips.length, equals(3));

      expect(vm.linkedBlendSpacePaths, contains('contents/animations/SKM_Superhero_Female/BS_Walk.lmas'));
      expect(vm.linkedBlendSpacePaths.length, equals(1));
    });

    test('availableSkeletalMeshes exposes skeletal meshes from project', () async {
      final abpPath = '${quinnAnimDir.path}/ABP_Quinn.lmas';
      final vm = AnimBlueprintEditorViewModel(assetPath: abpPath);
      await vm.load();

      expect(vm.availableSkeletalMeshes.length, greaterThanOrEqualTo(2));
      final meshNames = vm.availableSkeletalMeshes.map((m) => m.fileName).toList();
      expect(meshNames, contains('SKM_Superhero_Female.lmas'));
      expect(meshNames, contains('SKM_Manny_Simple.lmas'));
    });

    test('executeRetarget with saveAsNew creates a new valid ABP under target mesh directory', () async {
      final abpPath = '${quinnAnimDir.path}/ABP_Quinn.lmas';
      final vm = AnimBlueprintEditorViewModel(assetPath: abpPath);
      await vm.load();

      final mannyMesh = vm.availableSkeletalMeshes.firstWhere((m) => m.fileName.contains('Manny'));
      final outputPath = await vm.executeRetarget(
        targetMeshAsset: mannyMesh,
        outputName: 'ABP_Character',
        saveAsNew: true,
      );

      expect(outputPath, isNotNull);
      final outputFile = File(outputPath!);
      expect(outputFile.existsSync(), isTrue);
      expect(outputFile.path, contains('SKM_Manny_Simple'));
      expect(outputFile.path, endsWith('ABP_Character.lmas'));

      // Verify the new ABP points to the target mesh and remapped blend space
      final newAsset = LuminaAsset.fromBytes(outputFile.readAsBytesSync());
      final newDoc = LuminaAnimBlueprintDocument.fromJson(jsonDecode(utf8.decode(newAsset.rawPayload!)) as Map<String, dynamic>);
      expect(newDoc.targetMesh, equals('contents/meshes/skeletal/SKM_Manny_Simple.lmas'));

      final walkState = newDoc.stateMachines.first.states.firstWhere((s) => s.name == 'Walk');
      expect(walkState.pose.blendSpace, contains('SKM_Manny_Simple/BS_Walk.lmas'));

      // Verify retargeted blend space file exists
      final newBsFile = File('${projDir.path}/${walkState.pose.blendSpace}');
      expect(newBsFile.existsSync(), isTrue);
      final newBsAsset = LuminaAsset.fromBytes(newBsFile.readAsBytesSync());
      expect(newBsAsset.metadata[AnimGraphAssetService.targetMeshKey], equals('contents/meshes/skeletal/SKM_Manny_Simple.lmas'));
    });

    test('executeRetarget in-place updates current ABP to target mesh and saves', () async {
      final abpPath = '${quinnAnimDir.path}/ABP_Quinn.lmas';
      final vm = AnimBlueprintEditorViewModel(assetPath: abpPath);
      await vm.load();

      final mannyMesh = vm.availableSkeletalMeshes.firstWhere((m) => m.fileName.contains('Manny'));
      final outputPath = await vm.executeRetarget(
        targetMeshAsset: mannyMesh,
        saveAsNew: false,
      );

      expect(outputPath, equals(abpPath));
      final abpFile = File(abpPath);
      final updatedAsset = LuminaAsset.fromBytes(abpFile.readAsBytesSync());
      final updatedDoc = LuminaAnimBlueprintDocument.fromJson(jsonDecode(utf8.decode(updatedAsset.rawPayload!)) as Map<String, dynamic>);
      expect(updatedDoc.targetMesh, equals('contents/meshes/skeletal/SKM_Manny_Simple.lmas'));
      expect(vm.document.targetMesh, equals('contents/meshes/skeletal/SKM_Manny_Simple.lmas'));
    });

    testWidgets('AnimBlueprintRetargetModal displays source, target, clips and blend spaces', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final abpPath = '${quinnAnimDir.path}/ABP_Quinn.lmas';
      final vm = AnimBlueprintEditorViewModel(assetPath: abpPath);
      await tester.runAsync(() => vm.load());

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: AnimBlueprintRetargetModal(
              viewModel: vm,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Retarget Animation Blueprint'), findsOneWidget);
      expect(find.text('Source Skeletal Mesh'), findsOneWidget);
      expect(find.text('Target Skeletal Mesh'), findsOneWidget);
      expect(find.text('SKM_Superhero_Female'), findsWidgets);
      expect(find.textContaining('Linked Animations'), findsOneWidget);
      expect(find.text('Idle_Loop'), findsOneWidget);
      expect(find.text('Walk_Fwd_Loop'), findsOneWidget);
      expect(find.text('Walk_Bwd_Loop'), findsOneWidget);
      expect(find.text('BS_Walk'), findsOneWidget);
      expect(find.text('Humanoid IK Rig Auto-Mapping Active'), findsOneWidget);
      expect(find.text('Retarget All & Apply'), findsOneWidget);
      expect(find.byKey(const ValueKey('abp_confirm_retarget_button')), findsOneWidget);
    });

    testWidgets('AnimBlueprintSubEditor displays Retarget Blueprint button in toolbar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final abpPath = '${quinnAnimDir.path}/ABP_Quinn.lmas';
      final vm = AnimBlueprintEditorViewModel(assetPath: abpPath);
      await tester.runAsync(() => vm.load());

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: AnimBlueprintSubEditor(
              assetName: 'ABP_Quinn',
              assetPath: abpPath,
              viewModel: vm,
              showPreviewViewport: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Retarget Blueprint'), findsOneWidget);
      expect(find.byKey(const ValueKey('abp_retarget_button')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      vm.dispose();
    });

    test('executeRetarget fires AssetRepository.onAssetsChanged and auto-refreshes EditorViewModel', () async {
      final project = LuminaProject(
        projectName: 'TestProj',
        engineVersion: '0.0.1',
        activeLevel: 'contents/levels/main.lmas',
      );
      final editorVm = EditorViewModel(
        initialProject: project,
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      );
      editorVm.refreshAssets();
      final initialAssetCount = editorVm.realAssets.length;
      expect(initialAssetCount, 4);

      final abpPath = '${quinnAnimDir.path}/ABP_Quinn.lmas';
      final abpVm = AnimBlueprintEditorViewModel(assetPath: abpPath);
      await abpVm.load();

      final mannyAssetInfo = abpVm.availableSkeletalMeshes.firstWhere((m) => m.fileName.contains('Manny'));

      // Execute retarget with saveAsNew
      final outputPath = await abpVm.executeRetarget(
        targetMeshAsset: mannyAssetInfo,
        outputName: 'ABP_Character_AutoRefreshed',
        saveAsNew: true,
      );
      expect(outputPath, isNotNull);

      // Wait for broadcast stream event to deliver to EditorViewModel
      await pumpEventQueue();

      // Verify that EditorViewModel immediately reflected the new assets on disk
      expect(editorVm.realAssets.length, greaterThan(initialAssetCount));
      expect(
        editorVm.realAssets.any((a) => a.fileName.contains('ABP_Character_AutoRefreshed')),
        isTrue,
      );

      editorVm.dispose();
      abpVm.dispose();
    });

    testWidgets('ContentBrowserWidget displays Refresh button and clicking it refreshes assets', (tester) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final project = LuminaProject(
        projectName: 'TestProj',
        engineVersion: '0.0.1',
        activeLevel: 'contents/levels/main.lmas',
      );
      final editorVm = EditorViewModel(
        initialProject: project,
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      );
      editorVm.refreshAssets();

      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: ContentBrowserWidget(
              viewModel: editorVm,
            ),
          ),
        ),
      );
      await tester.pump();

      // Check Refresh button presence
      final refreshBtn = find.text('Refresh');
      expect(refreshBtn, findsOneWidget);

      // Tap refresh
      await tester.tap(refreshBtn);
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      editorVm.dispose();
    });
  });
}

