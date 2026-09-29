import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart' show RenderClipRect;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/physics_asset_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/physics_asset_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/physics_asset_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Physics Asset editor smoke: boots the real Lumina Studio
/// shell on a real temp project, imports the real skinned mannequin
/// (`test-assets/mannequin/SKM_Manny_Simple.glb`), opens a real PHYSICS_ASSET
/// `.lmas` bound to it through an `AssetReference{slot_name: 'skeletal_mesh'}`,
/// authors a capsule body on `pelvis` and a box body on `spine_01` through the
/// real tree UI, adds the constraint between them, runs `Validate Overlaps`
/// (lumina's real bind-pose narrow phase) and saves — capturing PNG + WebM
/// evidence of the live Filament viewport with the body overlays mounted.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Physics Asset Smoke: per-bone bodies, constraint and real bind-pose overlap validation', (tester) async {
    final mannequin = '${Directory.current.parent.path}/test-assets/mannequin/SKM_Manny_Simple.glb';
    expect(File(mannequin).existsSync(), isTrue, reason: 'real skeletal asset must exist');

    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_phat_');
    final pDir = Directory('${tempProjectsDir.path}/SmokePhysics')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokePhysics', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokePhysics.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      // The real import pipeline turns the real .glb into a real .lmas.
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: mannequin));
      vm.refreshAssets();
      // The import emits a whole family (textures, materials, mesh) and the
      // textures sort first: pick the skeletal mesh by type.
      final meshAsset = vm.realAssets.firstWhere(
        (a) => a.type == AssetType.filameshSk && a.fileName.toLowerCase().contains('manny'),
        orElse: () => throw StateError('mannequin import produced no skeletal mesh asset'),
      );

      // A real PHYSICS_ASSET `.lmas` that references that mesh.
      await tester.runAsync(() => AssetRepository().createAsset(
            projectPath: pDir.path,
            subFolder: 'physics',
            fileName: 'PHYS_Manny.lmas',
            type: AssetType.physicsAsset,
          ));
      final physPath = '${pDir.path}/contents/physics/PHYS_Manny.lmas';
      final created = LuminaAsset.fromBytes(File(physPath).readAsBytesSync());
      File(physPath).writeAsBytesSync(LuminaAsset(
        assetId: created.assetId,
        name: created.name,
        type: AssetType.physicsAsset,
        hasThumbnail: created.hasThumbnail,
        thumbnailPng: created.thumbnailPng,
        references: [
          AssetReference(
            slotName: 'skeletal_mesh',
            assetId: meshAsset.assetId ?? '',
            assetPath: meshAsset.lmasPath ?? meshAsset.relativePath,
          ),
        ],
      ).toProtoBufferBytes());
      vm.refreshAssets();
      final physAsset = vm.realAssets.firstWhere((a) => a.fileName == 'PHYS_Manny.lmas');

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

      // The live binding runs animations on the real clock: every frame waits.
      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // Open the physics asset through the real shell tab path.
      vm.openSubEditorTab('PhysicsAsset', asset: physAsset);
      await settle(40);
      expect(find.byType(PhysicsAssetSubEditor), findsOneWidget);
      expect(find.text('Simulate Ragdoll'), findsNothing, reason: 'the fake ragdoll button is gone');
      expect(find.textContaining('LIVE SIMULATION ACTIVE'), findsNothing);

      final phat = (tester.state(find.byType(PhysicsAssetSubEditor)) as dynamic).viewModelForTest
          as PhysicsAssetEditorViewModel;
      expect(phat.hasSkeletalMesh, isTrue, reason: phat.linkError ?? 'mesh must resolve');
      expect(phat.allBoneNames, containsAll(<String>['pelvis', 'spine_01']),
          reason: 'real mannequin bones, not stub strings');
      expect(phat.document.bodies, isEmpty);

      // Each authoring step is followed by a second of the running editor.
      Future<void> grabFrame() => rec.hold(const Duration(seconds: 1));

      await grabFrame();

      /// Taps [field] first so the live binding's text input really attaches,
      /// then types [text] into it.
      Future<void> typeInto(Finder field, String text) async {
        await tester.ensureVisible(field);
        await settle(4);
        await tester.tap(field);
        await settle(6);
        await rec.typeText(field, text, perCharacter: const Duration(milliseconds: 80));
        await settle(8);
      }

      /// Selects [bone] in the real skeleton tree and adds a body of [shape]
      /// through the real left-panel controls.
      Future<void> addBodyThroughUi(String bone, PhysicsShapeType shape) async {
        final row = find.byKey(ValueKey('physics_bone_row_$bone'));
        expect(row, findsOneWidget, reason: '$bone is a real row in the skeleton tree');
        await tester.ensureVisible(row);
        await settle(6);
        await tester.tap(row);
        await settle(8);
        expect(phat.selectedBoneName, bone);
        await tester.tap(find.byKey(ValueKey('physics_add_body_${shape.name}')));
        await settle(10);
        expect(phat.document.bodyForBone(bone), isNotNull, reason: '$bone got a ${shape.label} body');
      }

      await addBodyThroughUi('pelvis', PhysicsShapeType.capsule);
      final pelvisBody = phat.document.bodyForBone('pelvis')!;
      expect(pelvisBody.name, 'pelvis_Capsule');
      expect(pelvisBody.effectiveHalfHeight, greaterThanOrEqualTo(pelvisBody.radius));
      await grabFrame();

      await addBodyThroughUi('spine_01', PhysicsShapeType.box);
      expect(phat.document.bodyForBone('spine_01')!.name, 'spine_01_Box');
      await grabFrame();

      // The constraint to the nearest parent body (pelvis) through the real button.
      await tester.tap(find.byKey(const ValueKey('physics_add_constraint')));
      await settle(10);
      expect(phat.document.constraints.single.name, 'spine_01_Constraint');
      expect(phat.document.constraints.single.bodyA, 'pelvis');
      expect(find.text('spine_01_Constraint'), findsWidgets);
      await grabFrame();

      // Grow the pelvis capsule through the real inspector so the bind-pose
      // narrow phase has something to report. A shadcn Accordion section can
      // render clipped to zero height even when expanded: open it by its
      // trigger before typing.
      final pelvisRow = find.byKey(const ValueKey('physics_body_row_pelvis'));
      await tester.ensureVisible(pelvisRow);
      await settle(6);
      await tester.tap(pelvisRow);
      await settle(10);
      expect(phat.selectedBody?.boneName, 'pelvis');

      final radiusField = find.byKey(const ValueKey('physics_body_radius'));
      expect(radiusField, findsOneWidget);
      final clip = find.ancestor(of: radiusField, matching: find.byType(ClipRect));
      if (clip.evaluate().isNotEmpty) {
        final box = tester.renderObject(clip.first) as RenderClipRect;
        if (box.size.height < 4) {
          await tester.tap(find.byType(AccordionTrigger).first);
          await settle(12);
        }
      }
      final grownRadius = (phat.boneGlobal('spine_01')!.getTranslation() -
                  phat.boneGlobal('pelvis')!.getTranslation())
              .length *
          0.8;
      await typeInto(radiusField, grownRadius.toStringAsFixed(4));
      expect(phat.document.bodyForBone('pelvis')!.radius, closeTo(grownRadius, 1e-3),
          reason: 'the inspector wrote a real radius');
      await grabFrame();

      // Validate Overlaps: lumina's own narrow phase, in bind pose.
      await tester.tap(find.byKey(const ValueKey('physics_validate_overlaps')));
      await settle(14);
      expect(find.byKey(const ValueKey('physics_validation_results')), findsOneWidget);
      expect(find.textContaining('Bind Pose'), findsWidgets);
      expect(phat.hasValidated, isTrue);
      expect(phat.lastValidation.where((r) => r.isColliding).length, 1,
          reason: 'the grown pelvis capsule really interpenetrates the spine_01 box');
      final hit = phat.lastValidation.firstWhere((r) => r.isColliding);
      expect(hit.penetrationDepth, greaterThan(0.0));
      expect(find.textContaining('pelvis_Capsule'), findsWidgets);
      await grabFrame();

      final validatedPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('physics_editor_bodies_and_validation', validatedPng, usedAssets: [mannequin]);

      // Every view mode renders: wireframe, constraints only, solid.
      for (final mode in PhysicsViewMode.values) {
        phat.setViewMode(mode);
        await settle(10);
        await grabFrame();
      }
      expect(phat.buildOverlay().where((s) => !s.isConstraint), isEmpty,
          reason: 'Constraints Only was not the last mode' );
      phat.setViewMode(PhysicsViewMode.solidBodies);
      await settle(10);
      expect(phat.buildOverlay().where((s) => !s.isConstraint).length, 2);
      expect(phat.buildSolidBodies().length, 2);
      await grabFrame();

      final overlayPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('physics_editor_view_modes', overlayPng, usedAssets: [mannequin]);

      // Save through the real toolbar button and re-read the `.lmas`.
      expect(phat.isDirty, isTrue);
      await tester.tap(find.byKey(const ValueKey('physics_save')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await settle(12);
      expect(phat.isDirty, isFalse);

      // The left panel's filter Input is real: typing narrows the tree.
      await typeInto(find.byKey(const ValueKey('physics_bone_filter')), 'spine_01');
      expect(phat.boneFilter, 'spine_01');
      expect(find.byKey(const ValueKey('physics_bone_row_spine_01')), findsOneWidget);
      expect(find.byKey(const ValueKey('physics_bone_row_thigh_l')), findsNothing,
          reason: 'non-matching bones drop out of the filtered tree');
      await grabFrame();
      rec.save('Physics Asset Smoke: per-bone bodies, constraint and real bind-pose overlap validation', usedAssets: [mannequin]);

      final reopened = LuminaAsset.fromBytes(File(physPath).readAsBytesSync());
      final doc = PhysicsAssetDocument.fromJson(
          jsonDecode(reopened.metadata['physics_asset']!) as Map<String, dynamic>);
      expect(doc.bodies.map((b) => b.name), containsAll(<String>['pelvis_Capsule', 'spine_01_Box']));
      expect(doc.constraints.single.name, 'spine_01_Constraint');
      expect(doc.constraints.single.angularMode, PhysicsAngularMode.limited);
      expect(reopened.references.any((r) => r.slotName == 'skeletal_mesh'), isTrue,
          reason: 'the skeletal mesh link survives the save');
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });
}
