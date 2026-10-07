import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/static_mesh_collision.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/static_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/static_mesh_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Static Mesh editor smoke: boots
/// the real Lumina Studio shell on a real temp project, imports the real
/// Unreal FBX `SM_Counter_1` (812 × 272 × 110 cm, no UCX_ hull) through the
/// editor's import pipeline, opens it in the Static Mesh editor, reads its
/// stats in cm, generates Box, Capsule and Convex collision through the real
/// toolbar menu with the collision view drawn over the live Filament viewport,
/// saves, and checks the saved document is cm, Z up — the box lumina
/// turns into the prop's simple collision.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Static Mesh Editor Smoke: stats in cm, collision generated, drawn over the mesh and saved cm Z-up', (tester) async {
    final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';
    final fbx = '$assets/FBX/StaticMeshes/SM_Counter_1.FBX';
    expect(File(fbx).existsSync(), isTrue, reason: 'real FBX asset must exist');

    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_static_mesh_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeStaticMesh')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeStaticMesh', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeStaticMesh.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: fbx));
      vm.refreshAssets();
      final meshAsset = vm.realAssets.firstWhere(
        (a) => a.type == AssetType.filamesh && a.fileName.startsWith('SM_Counter_1'),
        orElse: () => throw StateError('the FBX import produced no static mesh asset'),
      );

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
        ),
      );

      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));

      // Orbits the live viewport a little, on video: the shapes stay on the
      // mesh from every side (and no stretch of the video stands still).
      var orbitSign = 1.0;
      Future<void> orbit() async {
        final c = tester.getCenter(find.byType(SubEditor3DViewport));
        await rec.drag(c, c + Offset(160 * orbitSign, 0), steps: 45);
        orbitSign = -orbitSign;
        await rec.hold(const Duration(milliseconds: 500));
      }

      vm.openSubEditorTab('Mesh', asset: meshAsset);
      await settle(40);
      expect(find.byType(StaticMeshSubEditor), findsOneWidget);
      final mesh = (tester.state(find.byType(StaticMeshSubEditor)) as dynamic).viewModelForTest as StaticMeshEditorViewModel;
      for (var i = 0; i < 100 && mesh.isLoading; i++) {
        await settle(5);
      }
      expect(mesh.glbMesh, isNotNull, reason: 'the imported GLB loads');
      await orbit();

      // The Stats card in cm, height along Z.
      expect(mesh.boundsWidth, closeTo(812, 1));
      expect(mesh.boundsHeight, closeTo(110, 1));
      expect(find.textContaining(' cm'), findsWidgets);

      Future<void> generate(String label) async {
        await tester.tap(find.text('Collision').first);
        await settle(10);
        await tester.tap(find.text(label).last);
        await settle(12);
        await orbit();
      }

      // Convex is the mesh's hull, drawn over it.
      await generate('Convex (hull)');
      expect(mesh.collisionShapes.single.type, StaticMeshCollisionShapeType.convex);
      expect(mesh.collisionShapes.single.points!.length, greaterThan(8));
      expect(tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport)).collisionLines, isNotNull);

      await generate('Capsule Collision');
      expect(mesh.collisionShapes.single.axis, 'X', reason: 'the counter\'s long axis');

      await generate('Box Collision');
      final box = mesh.collisionShapes.single;
      expect(box.extents![2], closeTo(55, 0.5), reason: 'half the 110 cm height, along Z');
      final lines = tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport)).collisionLines!;
      expect(lines.indices.length, 24, reason: 'the box\'s 12 edges drawn over the mesh');
      final boxPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('static_mesh_editor_box_collision_over_the_counter', boxPng, usedAssets: [fbx]);

      // The collision view hides and shows the shapes.
      mesh.toggleCollisionWireframe();
      await settle(10);
      expect(tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport)).collisionLines, isNull);
      await rec.hold(const Duration(seconds: 1));
      mesh.toggleCollisionWireframe();
      await settle(10);
      await orbit();

      // Save through the real toolbar button; the document is cm, Z up.
      await tester.tap(find.text('Save').first);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await settle(12);
      expect(mesh.isDirty, isFalse);
      final saved = LuminaAsset.fromBytes(File(meshAsset.lmasPath!).readAsBytesSync());
      final doc = jsonDecode(saved.metadata['collision']!) as Map;
      expect(doc['world_units'], 'cm');
      expect(doc['up_axis'], 'z');
      final simple = MeshCollisionService.simpleCollisionForMeshAsset(meshAsset.lmasPath!);
      expect(simple.primitives.single.kind, LuminaCollisionPrimitiveKind.box, reason: 'what the runtime collides with');
      await rec.hold(const Duration(seconds: 1));

      final finalPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('Static Mesh Editor Smoke: stats in cm, collision generated, drawn over the mesh and saved cm Z-up', finalPng,
          usedAssets: [fbx]);
      rec.save('Static Mesh Editor Smoke: stats in cm, collision generated, drawn over the mesh and saved cm Z-up', usedAssets: [fbx]);
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });
}
