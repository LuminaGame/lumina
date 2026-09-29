import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/skeletal_mesh_socket.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/static_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/static_mesh_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Double clicking skeletal mesh routes to Skeleton sub-editor, not StaticMeshSubEditor', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('mesh_route_test_');
    final projDir = Directory('${tempDir.path}/MeshProj')..createSync(recursive: true);
    final skelDir = Directory('${projDir.path}/contents/meshes/skeletal')..createSync(recursive: true);

    final skmAsset = LuminaAsset(
      assetId: 'skm-01',
      name: 'SKM_Manny_Simple',
      type: AssetType.filamesh,
      rawPayload: Uint8List.fromList([0, 1, 2, 3]),
    );

    final lmasFile = File('${skelDir.path}/SKM_Manny_Simple.lmas');
    lmasFile.writeAsBytesSync(skmAsset.toProtoBufferBytes());

    final project = LuminaProject(
      projectName: 'MeshProj',
      activeLevel: 'contents/levels/L_Main.lmas',
    );

    final vm = EditorViewModel(
      initialProject: project,
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    )..showAllAssets = true; // The root lists its own folder only; Show All lists the project as this test expects.
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: ContentBrowserWidget(viewModel: vm),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Double click SKM_Manny_Simple
    final assetFinder = find.text('SKM_Manny_Simple');
    expect(assetFinder, findsOneWidget);
    await tester.tap(assetFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(assetFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify open tabs
    expect(vm.openTabs.length, equals(2));
    final openedTab = vm.openTabs.last;
    expect(openedTab.category.toLowerCase(), equals('skeleton'), reason: 'Skeletal mesh should open Skeleton sub-editor');

    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('StaticMeshSubEditor passes glbMesh and PreviewShape.mesh to SubEditor3DViewport', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('static_mesh_test_');
    final assetFile = File('${tempDir.path}/SM_Rock_Basalt.lmas');

    final glbMesh = GlbMeshData(
      positions: [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
      indices: [0, 1, 2],
      minBounds: [0.0, 0.0, 0.0],
      maxBounds: [1.0, 1.0, 0.0],
    );

    final asset = LuminaAsset(
      assetId: 'mesh-01',
      name: 'SM_Rock_Basalt',
      type: AssetType.filamesh,
    );
    assetFile.writeAsBytesSync(asset.toProtoBufferBytes());

    final vm = StaticMeshEditorViewModel(
      assetPath: assetFile.path,
      initialAsset: asset,
      initialGlbMesh: glbMesh,
    );

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: StaticMeshSubEditor(
            assetName: 'SM_Rock_Basalt',
            viewModel: vm,
          ),
        ),
      ),
    );
    await tester.pump();

    final viewportFinder = find.byType(SubEditor3DViewport);
    expect(viewportFinder, findsOneWidget);
    final viewportWidget = tester.widget<SubEditor3DViewport>(viewportFinder);
    expect(viewportWidget.initialShape, equals(PreviewShape.mesh), reason: 'Static mesh viewport should use PreviewShape.mesh');

    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('SubEditor3DViewport uses PreviewShape.mesh when glbMesh is supplied without explicit shape', (tester) async {
    final glbMesh = GlbMeshData(
      positions: [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
      indices: [0, 1, 2],
      minBounds: [0.0, 0.0, 0.0],
      maxBounds: [1.0, 1.0, 0.0],
    );

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SubEditor3DViewport(
            title: 'Test Rig Viewport',
            glbMesh: glbMesh,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final viewportFinder = find.byType(SubEditor3DViewport);
    expect(viewportFinder, findsOneWidget);
    final viewportWidget = tester.widget<SubEditor3DViewport>(viewportFinder);
    expect(viewportWidget.initialShape, equals(PreviewShape.mesh));
  });

  testWidgets('EditorViewModel strips .lmas from tab title in openSubEditorTab', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('tab_title_test_');
    final project = LuminaProject(
      projectName: 'TabTitleProj',
      activeLevel: 'contents/levels/L_Main.lmas',
    );

    final vm = EditorViewModel(
      initialProject: project,
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);

    final realAsset = RealAssetInfo(
      fileName: 'T_Character_Texture.lmas',
      relativePath: 'contents/textures/T_Character_Texture.lmas',
      lmasPath: '${tempDir.path}/contents/textures/T_Character_Texture.lmas',
      type: AssetType.texture,
      bytes: 1024,
      lastModified: DateTime.now(),
    );

    vm.openSubEditorTab('Texture', asset: realAsset);
    expect(vm.openTabs.length, equals(2));
    expect(vm.openTabs.last.title, equals('T_Character_Texture'), reason: '.lmas extension should be stripped from tab title');

    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('SubEditor3DViewport renders bone wireframes and socket gizmos when enabled', (tester) async {
    final rootBone = GlbNode(
      index: 0,
      name: 'root',
      type: GlbNodeType.bone,
      translation: [0.0, 0.0, 0.0],
      children: [
        GlbNode(
          index: 1,
          name: 'pelvis',
          type: GlbNodeType.bone,
          translation: [0.0, 0.0, 50.0],
        ),
      ],
    );

    final glbMesh = GlbMeshData(
      positions: [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
      indices: [0, 1, 2],
      minBounds: [0.0, 0.0, 0.0],
      maxBounds: [1.0, 1.0, 100.0],
      rootNodes: [rootBone],
      allNodes: [rootBone, rootBone.children.first],
    );

    final testSocket = SkeletalMeshSocket(
      name: 'hand_r_socket',
      parentBone: 'pelvis',
      relativeLocation: [5.0, 0.0, 0.0],
    );

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SizedBox(
            width: 800,
            height: 600,
            child: SubEditor3DViewport(
              title: 'Rig & Sockets Test',
              glbMesh: glbMesh,
              showBones: true,
              showSockets: true,
              sockets: [testSocket],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final viewportFinder = find.byType(SubEditor3DViewport);
    expect(viewportFinder, findsOneWidget);
    final viewportWidget = tester.widget<SubEditor3DViewport>(viewportFinder);
    expect(viewportWidget.showBones, isTrue);
    expect(viewportWidget.showSockets, isTrue);
    expect(viewportWidget.sockets.length, equals(1));
    expect(viewportWidget.sockets.first.name, equals('hand_r_socket'));
  });

  testWidgets('Double clicking animation GLB/lmas routes to Animation sub-editor', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('anim_route_test_');
    final projDir = Directory('${tempDir.path}/AnimProj')..createSync(recursive: true);
    final animDir = Directory('${projDir.path}/contents/animations')..createSync(recursive: true);

    final animAsset = LuminaAsset(
      assetId: 'anim-01',
      name: 'Walk_Bwd_Loop',
      type: AssetType.filamesh,
      rawPayload: Uint8List.fromList([0, 1, 2, 3]),
    );

    final lmasFile = File('${animDir.path}/Walk_Bwd_Loop.lmas');
    lmasFile.writeAsBytesSync(animAsset.toProtoBufferBytes());

    final project = LuminaProject(
      projectName: 'AnimProj',
      activeLevel: 'contents/levels/L_Main.lmas',
    );

    final vm = EditorViewModel(
      initialProject: project,
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    )..showAllAssets = true; // The root lists its own folder only; Show All lists the project as this test expects.
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: ContentBrowserWidget(viewModel: vm),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Double click Walk_Bwd_Loop
    final assetFinder = find.text('Walk_Bwd_Loop');
    expect(assetFinder, findsOneWidget);
    await tester.tap(assetFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(assetFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify open tabs
    expect(vm.openTabs.length, equals(2));
    final openedTab = vm.openTabs.last;
    expect(openedTab.category.toLowerCase(), equals('animation'), reason: 'Animation sequence should open Animation sub-editor');

    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('Double clicking SKM_Manny with AssetType.actor routes to Skeleton sub-editor', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('skm_actor_route_test_');
    final projDir = Directory('${tempDir.path}/SKMProj')..createSync(recursive: true);
    final meshDir = Directory('${projDir.path}/contents/meshes/skeletal')..createSync(recursive: true);

    final skmAsset = LuminaAsset(
      assetId: 'skm-01',
      name: 'SKM_Manny_Simple',
      type: AssetType.actor, // Even if legacy or protobuf says actor
      rawPayload: Uint8List.fromList([0, 1, 2, 3]),
    );

    final lmasFile = File('${meshDir.path}/SKM_Manny_Simple.lmas');
    lmasFile.writeAsBytesSync(skmAsset.toProtoBufferBytes());

    final project = LuminaProject(
      projectName: 'SKMProj',
      activeLevel: 'contents/levels/L_Main.lmas',
    );

    final vm = EditorViewModel(
      initialProject: project,
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    )..showAllAssets = true; // The root lists its own folder only; Show All lists the project as this test expects.
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: ContentBrowserWidget(viewModel: vm),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Double click SKM_Manny_Simple
    final assetFinder = find.text('SKM_Manny_Simple');
    expect(assetFinder, findsOneWidget);
    await tester.tap(assetFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(assetFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify open tabs
    expect(vm.openTabs.length, equals(2));
    final openedTab = vm.openTabs.last;
    expect(openedTab.category.toLowerCase(), equals('skeleton'), reason: 'Skeletal mesh should open Skeleton sub-editor');

    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });
}
