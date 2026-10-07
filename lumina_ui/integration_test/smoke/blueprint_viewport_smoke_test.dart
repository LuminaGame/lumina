import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/services/gizmo_controller.dart' show GizmoMode;
import 'package:lumina_ui/ui/features/main_editor/services/transform_gizmo.dart' show TransformGizmoModel;
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/component_tree.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/scaffold_game_project.dart';

/// Smoke — the Blueprint editor's 3D Viewport shows the Blueprint.
///
/// A launcher Third Person project opened in Lumina Studio; BP_ThirdPersonCharacter
/// opened from its asset; the 3D Viewport tab draws the actor Play would
/// spawn: the Quinn mannequin (its Mesh component, playing ABP_Character's Idle),
/// the capsule, the camera boom and the follow camera. Each component picked
/// in the Components panel is highlighted; the view orbits; Event Graph and
/// back to 3D Viewport shows the same Blueprint again.
///
/// Runs on GPU 1 (NVIDIA RTX PRO 2000) — `tool/smoke_report.dart` injects the
/// GPU environment.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const testName = 'Blueprint Viewport Smoke: BP_ThirdPersonCharacter shows its mannequin, capsule, boom and camera';
  const usedAssets = ['mannequin/SKM_Superhero_Female.glb (the Third Person template mannequin)'];

  testWidgets(testName, (tester) async {
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bp_viewport_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir =
        (await tester.runAsync(() => scaffoldGameProject(root, name: 'bp_viewport_smoke', widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(Map<String, dynamic>.from(
        jsonDecode(File('$projectDir/bp_viewport_smoke.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.ensureDefaultLevelAssets);

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> settle([int frames = 12]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
    ));
    await settle(40);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(milliseconds: 800));
    Future<Uint8List> capture() => SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));

    // The mannequin is a mid-grey figure on the preview's dark backdrop.
    int mannequinPixels(Uint8List png) {
      final image = img.decodePng(png)!;
      final r = tester.getRect(find.byType(SubEditor3DViewport));
      var n = 0;
      for (var y = r.top.toInt(); y < r.bottom.toInt(); y += 2) {
        for (var x = r.left.toInt(); x < r.right.toInt(); x += 2) {
          final p = image.getPixel(x, y);
          final grey = (p.r - p.g).abs() < 18 && (p.g - p.b).abs() < 18;
          if (grey && p.r > 95 && p.r < 235) n++;
        }
      }
      return n;
    }

    // --- Open BP_ThirdPersonCharacter, as a double-click in the browser does ---
    final asset = vm.realAssets.firstWhere((a) => a.relativePath == LuminaThirdPersonContent.characterBlueprintPath);
    vm.openSubEditorTab('Blueprint', asset: asset);
    await settle(20);
    final bp = tester.state<BlueprintSubEditorState>(find.byType(BlueprintSubEditor)).viewModel;
    for (var i = 0; i < 200 && bp.document.components.length < 5; i++) {
      await settle(2);
    }
    await rec.hold(const Duration(milliseconds: 800));

    Future<void> openViewportTab() async {
      await tester.tap(find.text('3D Viewport'));
      await settle(6);
      LuminaStaticMeshComponent? mesh() => bp.preview.componentFor('mesh') as LuminaStaticMeshComponent?;
      for (var i = 0; i < 400 && !(bp.preview.hasNativeWorld && (mesh()?.isLoaded ?? false)); i++) {
        await rec.hold(const Duration(milliseconds: 100));
      }
      expect(bp.preview.hasNativeWorld, isTrue, reason: 'the viewport hands its Filament world to the preview');
      expect(mesh()?.isLoaded, isTrue, reason: 'the Mesh component loads SKM_Superhero_Female (${bp.preview.diagnostics})');
    }

    await openViewportTab();
    final viewport = tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport));
    expect(viewport.showShapeSelector, isFalse);
    expect(find.text('SPHERE'), findsNothing, reason: 'no primitive shape selector for a Blueprint');
    await rec.hold(const Duration(milliseconds: 1500));
    expect(bp.preview.animInstanceFor('mesh')?.currentState, 'Idle', reason: 'ABP_Character idles the standing pawn');
    expect(bp.preview.animInstanceFor('mesh')?.mesh.currentClip, LuminaThirdPersonContent.idleClip);
    final opened = await capture();
    expect(mannequinPixels(opened), greaterThan(1500), reason: 'the mannequin is drawn in the viewport');
    SmokeArtifacts.saveScreenshot('blueprint_viewport_third_person_character', opened, usedAssets: usedAssets);

    // --- Pick components: each one is highlighted in the viewport ------------
    for (final (name, id) in [('CapsuleComponent', 'capsule'), ('CameraBoom', 'boom'), ('FollowCamera', 'camera'), ('Mesh', 'mesh')]) {
      await tester.tap(find.descendant(of: find.byType(BlueprintComponentTree), matching: find.text(name)).first);
      await settle(4);
      expect({for (final s in bp.preview.overlays) if (s.selected) s.id}, {id}, reason: '$name is highlighted');
      await rec.hold(const Duration(milliseconds: 1100));
    }
    SmokeArtifacts.saveScreenshot('blueprint_viewport_mesh_selected', await capture(), usedAssets: usedAssets);

    // --- Orbit around the actor ------------------------------------------------
    final rect = tester.getRect(find.byType(SubEditor3DViewport));
    await rec.drag(rect.center + const Offset(-120, 20), rect.center + const Offset(180, 50), steps: 75);
    await rec.hold(const Duration(milliseconds: 700));

    // --- Event Graph and back: the same Blueprint again ------------------------
    await tester.tap(find.text('Event Graph'));
    await settle(6);
    await rec.hold(const Duration(milliseconds: 1000));
    await openViewportTab();
    await rec.hold(const Duration(milliseconds: 1500));
    final back = await capture();
    expect(mannequinPixels(back), greaterThan(1500), reason: 'back on the 3D Viewport the mannequin is drawn again');
    SmokeArtifacts.saveScreenshot('blueprint_viewport_after_tab_switch', back, usedAssets: usedAssets);

    expect(rec.recorded, greaterThanOrEqualTo(const Duration(seconds: 10)));
    rec.save(testName, usedAssets: usedAssets);
  });

  // ---------------------------------------------------------------------------
  // component transform gizmos.
  // ---------------------------------------------------------------------------
  const gizmoTestName = 'Blueprint Viewport Smoke: component gizmo rotate — CameraBoom turned by its yaw ring';

  testWidgets(gizmoTestName, (tester) async {
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bp_gizmo_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir =
        (await tester.runAsync(() => scaffoldGameProject(root, name: 'bp_gizmo_smoke', widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(Map<String, dynamic>.from(
        jsonDecode(File('$projectDir/bp_gizmo_smoke.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.ensureDefaultLevelAssets);

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> settle([int frames = 12]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
    ));
    await settle(40);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(milliseconds: 800));
    Future<Uint8List> capture() => SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));

    // Open the character and its 3D Viewport.
    final asset = vm.realAssets.firstWhere((a) => a.relativePath == LuminaThirdPersonContent.characterBlueprintPath);
    vm.openSubEditorTab('Blueprint', asset: asset);
    await settle(20);
    final editor = tester.state<BlueprintSubEditorState>(find.byType(BlueprintSubEditor));
    final bp = editor.viewModel;
    for (var i = 0; i < 200 && bp.document.components.length < 5; i++) {
      await settle(2);
    }
    await tester.tap(find.text('3D Viewport'));
    await settle(6);
    LuminaStaticMeshComponent? mesh() => bp.preview.componentFor('mesh') as LuminaStaticMeshComponent?;
    for (var i = 0; i < 400 && !(bp.preview.hasNativeWorld && (mesh()?.isLoaded ?? false)); i++) {
      await rec.hold(const Duration(milliseconds: 100));
    }
    expect(bp.preview.hasNativeWorld, isTrue);
    await rec.hold(const Duration(milliseconds: 1000));

    // Select CameraBoom: the translate gizmo sits on the boom.
    await tester.tap(find.descendant(of: find.byType(BlueprintComponentTree), matching: find.text('CameraBoom')).first);
    await settle(4);
    final boom = bp.document.components.firstWhere((c) => c.name == 'CameraBoom').id;
    expect(bp.selectedComponentId, boom);
    expect(find.byKey(const ValueKey('sub_editor_transform_gizmo')), findsOneWidget, reason: 'the gizmo is drawn');
    await rec.hold(const Duration(milliseconds: 1200));
    SmokeArtifacts.saveScreenshot('blueprint_viewport_gizmo_translate_boom', await capture(), usedAssets: usedAssets);

    // Rotate tool (E): the rings. Grab the yaw ring at 45° and sweep a quarter turn.
    await tester.tap(find.byKey(const ValueKey('sub_gizmo_tool_rotate')));
    await settle(4);
    expect(editor.transformGizmo.mode, GizmoMode.rotate);
    await rec.hold(const Duration(milliseconds: 1000));
    final before = await capture();
    SmokeArtifacts.saveScreenshot('blueprint_viewport_gizmo_rotate_before', before, usedAssets: usedAssets);

    final rect = tester.getRect(find.byType(SubEditor3DViewport));
    final dynamic viewport = tester.state(find.byType(SubEditor3DViewport));
    final model = viewport.transformGizmoModelForTest(rect.size) as TransformGizmoModel?;
    expect(model, isNotNull, reason: 'a selected component has a gizmo');
    final ring = model!.ringPoints('Z', segments: 8);
    final grab = rect.topLeft + ring[1]!;
    final to = rect.topLeft + ring[3]!;
    final rotationBefore = List<double>.from(
        ((bp.getComponent(boom)!.properties['rotation'] as List?) ?? const [0.0, 0.0, 0.0]).map((e) => (e as num).toDouble()));
    await rec.drag(grab, to, steps: 60);
    await settle(4);
    final rotation = (bp.getComponent(boom)!.properties['rotation'] as List).map((e) => (e as num).toDouble()).toList();
    debugPrint('[bp_gizmo_smoke] boom rotation $rotationBefore -> $rotation');
    expect(rotation[2].abs(), greaterThan(30.0), reason: 'the yaw ring turned the boom');
    expect(rotation[0], closeTo(0.0, 1e-6));
    expect(rotation[1], closeTo(0.0, 1e-6));
    expect(bp.transactions.canUndo, isTrue, reason: 'one undo step per drag');
    await rec.hold(const Duration(milliseconds: 1500));
    SmokeArtifacts.saveScreenshot('blueprint_viewport_gizmo_rotate_after', await capture(), usedAssets: usedAssets);

    // Undo puts the boom back; the scale tool shows its cubes.
    await tester.tap(find.byKey(const ValueKey('bp_undo')));
    await settle(6);
    expect((bp.getComponent(boom)!.properties['rotation'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [0.0, 0.0, 0.0],
        rotationBefore);
    await rec.hold(const Duration(milliseconds: 1000));
    await tester.tap(find.byKey(const ValueKey('sub_gizmo_tool_scale')));
    await settle(4);
    await rec.hold(const Duration(milliseconds: 1200));
    SmokeArtifacts.saveScreenshot('blueprint_viewport_gizmo_scale', await capture(), usedAssets: usedAssets);
    await tester.tap(find.byKey(const ValueKey('sub_gizmo_tool_translate')));
    await settle(4);
    await rec.hold(const Duration(milliseconds: 1500));

    expect(rec.recorded, greaterThanOrEqualTo(const Duration(seconds: 10)));
    rec.save(gizmoTestName, usedAssets: usedAssets);
  });
}
