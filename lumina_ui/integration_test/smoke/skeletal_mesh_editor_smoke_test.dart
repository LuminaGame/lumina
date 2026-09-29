import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/skeletal_mesh/skeletal_mesh_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Skeletal Mesh editor smoke: boots the real Lumina
/// Studio shell on a real temp project, imports the real skinned mannequin
/// (`test-assets/mannequin/SKM_Manny_Simple.glb`) through the real import
/// pipeline, creates a real FILAMAT `.lmas` and a real texture `.lmas`, opens
/// the mesh in the Skeletal Mesh sub-editor, binds the material to `element_0`
/// and a texture to the sampler that material declares, isolates the slot, and
/// saves — asserting the bindings landed in the `.lmas` on disk and capturing
/// PNG + WebM evidence of the live viewport with the panel mounted.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Skeletal Mesh Smoke: material slot and texture binding round-trip', (tester) async {
    final mannequin = '${Directory.current.parent.path}/test-assets/mannequin/SKM_Manny_Simple.glb';
    expect(File(mannequin).existsSync(), isTrue, reason: 'real skeletal asset must exist');

    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_skelmat_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeSkelMat')..createSync(recursive: true);
    const project = LuminaProject(
      projectName: 'SmokeSkelMat',
      activeLevel: 'contents/levels/L_Main.lmas',
    );
    File('${pDir.path}/SmokeSkelMat.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: mannequin));

      // A real FILAMAT `.lmas` declaring one sampler, and a real texture `.lmas`.
      final matPath = '${pDir.path}/contents/materials/M_Smoke.lmas';
      Directory('${pDir.path}/contents/materials').createSync(recursive: true);
      File(matPath).writeAsBytesSync(
        LuminaAsset(
          assetId: 'M_Smoke',
          name: 'M_Smoke',
          type: AssetType.filamat,
          rawMatSource: '''
material {
    name : M_Smoke,
    parameters : [
        { type : sampler2d, name : baseColorMap }
    ],
    shadingModel : lit
}
''',
        ).toProtoBufferBytes(),
      );

      final texPath = '${pDir.path}/contents/textures/T_Smoke.lmas';
      Directory('${pDir.path}/contents/textures').createSync(recursive: true);
      File(texPath).writeAsBytesSync(
        LuminaAsset(
          assetId: 'T_Smoke',
          name: 'T_Smoke',
          type: AssetType.texture,
          rawPayload: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
        ).toProtoBufferBytes(),
      );

      vm.refreshAssets();
      // The import pipeline emits a whole asset family (mesh + textures), and the
      // textures sort first — pick by asset *type*, not by name, or this smoke
      // silently exercises a texture `.lmas` with no geometry.
      final meshAsset = vm.realAssets.firstWhere(
        (a) =>
            (a.type == AssetType.filamesh || a.type == AssetType.filameshSk) &&
            a.fileName.toLowerCase().contains('manny'),
        orElse: () => throw StateError('mannequin import produced no mesh asset'),
      );

      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: MainEditorView(viewModel: vm),
          ),
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
      await rec.hold(const Duration(seconds: 1));

      vm.openSubEditorTab('SKELETAL', asset: meshAsset);
      await settle(50);
      expect(find.byType(SkeletalMeshSubEditor), findsOneWidget);

      final skel = (tester.state(find.byType(SkeletalMeshSubEditor)) as dynamic).viewModelForTest
          as SkeletalMeshEditorViewModel;

      expect(skel.boneCount, greaterThan(0),
          reason: 'the opened asset must be the real skinned mesh, not a texture from the same family');
      expect(skel.materialSlots, isNotEmpty, reason: 'the imported mannequin has geometry sections');
      expect(
        skel.availableMaterials.map((m) => m.fileName),
        contains('M_Smoke.lmas'),
        reason: 'the picker sees the real project material',
      );
      expect(find.textContaining('MATERIAL SLOTS ('), findsOneWidget);

      // Each binding step is followed by the running editor on video.
      Future<void> grabFrame() => rec.hold(const Duration(milliseconds: 1500));

      await grabFrame();

      // Bind through the real view model the panel drives, then let the panel
      // rebuild so the sampler rows the material declares appear on screen.
      skel.assignMaterial(0, materialAssetPath: matPath, materialAssetId: 'M_Smoke');
      await tester.runAsync(() => skel.refreshSlotSamplers());
      await settle(12);

      expect(skel.samplerNamesForSlot(0), equals(['baseColorMap']));
      expect(find.text('TEXTURES'), findsWidgets);
      expect(find.text('baseColorMap'), findsWidgets);
      await grabFrame();

      skel.assignTexture(0, 'baseColorMap', textureAssetPath: texPath, textureAssetId: 'T_Smoke');
      await settle(10);
      await grabFrame();

      // Isolate the bound slot: every other section is reported hidden.
      skel.isolateMaterial(0, true);
      await settle(10);
      expect(skel.hiddenSectionIndices.contains(0), isFalse);
      await grabFrame();

      final boundPng = await SmokeArtifacts.captureIntegrationPng(
        binding,
        tester,
        boundary: find.byKey(boundaryKey),
      );
      SmokeArtifacts.saveScreenshot(
        'skeletal_mesh_editor_material_slots',
        boundPng,
        usedAssets: [mannequin],
      );
      await rec.hold(const Duration(seconds: 1));

      // Isolation off again: every section is back.
      skel.isolateMaterial(0, false);
      await settle(10);
      expect(skel.hiddenSectionIndices, isEmpty);
      await grabFrame();

      expect(skel.isDirty, isTrue);
      expect(await tester.runAsync(() => skel.save()), isTrue);
      await settle(10);
      expect(skel.isDirty, isFalse);
      await grabFrame();
      rec.save('Skeletal Mesh Smoke: material slot and texture binding round-trip', usedAssets: [mannequin]);

      // The bindings are on disk, in the shared slot vocabulary.
      final onDisk = LuminaAsset.fromBytes(File(meshAsset.lmasPath!).readAsBytesSync());
      final ref = onDisk.references.where((r) => r.slotName == 'element_0').toList();
      expect(ref, hasLength(1));
      expect(ref.single.assetId, equals('M_Smoke'));

      final overrides = jsonDecode(onDisk.metadata['materialTextures']!) as Map<String, dynamic>;
      expect((overrides['element_0/baseColorMap'] as Map)['assetId'], equals('T_Smoke'));
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });

  testWidgets('Skeletal Mesh Smoke: bones and sockets overlays on a 256-bone rig draw without an exception',
      (tester) async {
    // The bone/socket overlay threw "Offset argument contained a NaN
    // value" every frame for a rig with an identity-rotation bone (the
    // MetaHuman body: `root` is [8e-08, 0, 0, -1]). The real skinned mannequin
    // goes through the real import pipeline; when the MetaHuman body the report
    // was about is on this machine it is imported too, so the overlay is
    // exercised on the exact rig. Bones and sockets on, sockets added and
    // selected, on video — no exception may reach the framework.
    final mannequin = '${Directory.current.parent.path}/test-assets/mannequin/SKM_Manny_Simple.glb';
    final metahuman = Platform.environment['LUMINA_METAHUMAN_BODY_GLB'] ?? '';
    expect(File(mannequin).existsSync(), isTrue, reason: 'real skeletal asset must exist');
    final rigs = [mannequin, if (metahuman.isNotEmpty && File(metahuman).existsSync()) metahuman];

    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_skelbones_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeSkelBones')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeSkelBones', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeSkelBones.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      for (final rig in rigs) {
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: rig));
      }
      vm.refreshAssets();

      tester.view.physicalSize = const Size(1920, 1200);
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
          final e = tester.takeException();
          expect(e, isNull, reason: 'the overlay must never throw (was: $e)');
        }
      }

      await settle(30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      for (final rig in rigs) {
        final stem = rig.split('/').last.split('.').first.toLowerCase();
        final meshAsset = vm.realAssets.firstWhere(
          (a) =>
              (a.type == AssetType.filamesh || a.type == AssetType.filameshSk) &&
              a.fileName.toLowerCase().contains(stem.contains('manny') ? 'manny' : 'metahuman'),
          orElse: () => throw StateError('$rig import produced no mesh asset'),
        );
        vm.openSubEditorTab('SKELETAL', asset: meshAsset);
        await settle(50);
        expect(find.byType(SkeletalMeshSubEditor), findsWidgets);
        final skel = (tester.state(find.byType(SkeletalMeshSubEditor).last) as dynamic).viewModelForTest
            as SkeletalMeshEditorViewModel;
        expect(skel.boneCount, greaterThan(0));
        expect(skel.showBones, isTrue, reason: 'Show Bones is on when the editor opens');
        expect(skel.displaySockets, isTrue);

        // Bones on; then a socket on the selected bone, selected: the socket
        // crosshair and label draw too. Each state is held on video.
        await rec.hold(const Duration(seconds: 2));
        await settle(10);
        await tester.tap(find.text('Add Socket').last);
        await settle(10);
        expect(skel.sockets, isNotEmpty);
        skel.selectSocket(skel.sockets.first);
        await settle(10);
        await rec.hold(const Duration(seconds: 2));
        await settle(10);

        // Bones off and on again, the orbit moved: fresh paints of the overlay.
        skel.toggleShowBones();
        await settle(10);
        await rec.hold(const Duration(milliseconds: 800));
        skel.toggleShowBones();
        await settle(10);
        await rec.hold(const Duration(seconds: 1));
        await settle(10);

        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('skeletal_mesh_editor_bone_overlay_$stem', png, usedAssets: [rig]);
      }
      await rec.hold(const Duration(seconds: 1));
      rec.save('Skeletal Mesh Smoke: bones and sockets overlays on a 256-bone rig draw without an exception',
          usedAssets: rigs);
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });
}
