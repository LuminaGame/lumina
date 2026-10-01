import 'dart:convert';
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart' hide GizmoMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_preferences.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_view_layers.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/camera_preview_panel.dart';
import 'package:lumina_ui/ui/features/main_editor/views/level_scene_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// Selecting a camera in the level editor opens a picture-in-picture preview
/// at the bottom-left of the level viewport: a second view of the level's
/// own scene through the camera (pose, field of view, projection), without
/// the editor's helpers, resizable from its top-right corner with the size
/// kept per user. A real temp project and a real mesh.
void main() {
  final acUnitGlb = '${Directory.current.parent.path}/test-assets/Props/AC_units/ac_unit_a_300x300.glb';
  final hasAsset = File(acUnitGlb).existsSync();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('lvl_cam_preview_'));
  tearDown(() => deleteTempProject(root));

  // The editor viewport's tickers never let pumpAndSettle settle.
  Future<void> settle(WidgetTester tester, bool Function() done, {int frames = 400}) async {
    await tester.pump();
    for (var i = 0; i < frames && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
  }

  /// A project with the AC unit mesh at the origin and Camera_1 six metres in
  /// front of it, looking at it; the editor pumped until the mesh is drawn.
  Future<(EditorViewModel, EditorActorNode, EditorActorNode)> openLevel(WidgetTester tester, {String projectName = 'CamPreview'}) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pDir = Directory('${root.path}/$projectName')..createSync(recursive: true);
    await tester.runAsync(() async {
      await AssetRepository().createAsset(projectPath: pDir.path, subFolder: 'meshes', fileName: 'AC_Unit.lmas', type: AssetType.filamesh);
    });
    File(acUnitGlb).copySync('${pDir.path}/contents/meshes/AC_Unit.glb');
    final project = LuminaProject(projectName: projectName, activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/$projectName.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    final evm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
    await tester.runAsync(evm.ensureDefaultLevelAssets);
    await tester.runAsync(() => evm.spawnActorFromAsset(evm.realAssets.firstWhere((a) => a.fileName == 'AC_Unit.lmas'), location: [0, 0, 0]));
    final mesh = evm.actors.last;
    evm.spawnNewActor('Camera');
    final camera = evm.actors.last;
    expect(camera.type, 'Camera');
    camera.location = [0, -600, 150];
    camera.rotation = [0, 0, 0];
    evm.selectActor(null);

    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: evm)));
    dynamic level() => tester.state(find.byType(ViewportWidget));
    await settle(tester, () => level().actorInstanceInSceneForTest(mesh.id) != null);
    expect(level().actorInstanceInSceneForTest(mesh.id), isNotNull, reason: 'the level viewport draws the mesh');
    return (evm, mesh, camera);
  }

  const panelKey = ValueKey('camera_preview_panel');
  LevelSceneViewState previewView(WidgetTester tester) =>
      tester.state<LevelSceneViewState>(find.byKey(const ValueKey('camera_preview_view')));

  testWidgets('selecting a camera shows its preview bottom-left; a mesh, × and Play hide it; clicks stay on the panel',
      (tester) async {
    final (evm, mesh, camera) = await openLevel(tester);
    dynamic level() => tester.state(find.byType(ViewportWidget));
    expect(find.byKey(panelKey), findsNothing, reason: 'nothing selected, no preview');
    expect(find.byType(LevelSceneView), findsNothing, reason: 'no second view while hidden');

    // Select the camera: the panel opens at the bottom-left, titled with its name.
    evm.selectActor(camera);
    await settle(tester, () => find.byKey(panelKey).evaluate().isNotEmpty && previewView(tester).drawsLevelScene);
    expect(find.byKey(panelKey), findsOneWidget);
    expect(find.descendant(of: find.byKey(panelKey), matching: find.text(camera.name)), findsOneWidget);
    final viewport = tester.getRect(find.byType(ViewportWidget));
    final panel = tester.getRect(find.byKey(panelKey));
    expect(panel.left, closeTo(viewport.left + CameraPreviewOverlay.margin, 0.5));
    expect(panel.bottom,
        closeTo(viewport.bottom - CameraPreviewOverlay.statsStripHeight - CameraPreviewOverlay.margin, 0.5));
    expect(panel.width, EditorPreferences.defaultCameraPreviewWidth);

    // The preview draws the level's own scene, without the editor's helpers;
    // the level view keeps its helpers.
    final view = previewView(tester);
    final levelScene = level().nativeSceneForTest as FilamentScene;
    expect(view.view!.scene!.nativePointer.address, levelScene.nativePointer.address);
    expect(view.view!.visibleLayers & EditorViewLayers.all, EditorViewLayers.cameraView);
    expect(view.view!.visibleLayers & EditorViewLayers.helpers, 0, reason: 'no grid, gizmo or wires in the preview');
    expect(level().viewLayersForTest & EditorViewLayers.all, EditorViewLayers.levelViewport);

    // A click on the panel does not reach the level view (which would select
    // or deselect behind it).
    await tester.tapAt(panel.center);
    await settle(tester, () => false, frames: 3);
    expect(evm.selectedActor, same(camera), reason: 'the click stayed on the panel');
    expect(find.byKey(panelKey), findsOneWidget);

    // Wireframe in the level view: its solids layer is hidden there, the
    // preview still draws the solids (they stay in the scene).
    evm.setViewMode('Wireframe');
    await settle(tester, () => false, frames: 3);
    expect(level().viewLayersForTest & EditorViewLayers.solids, 0, reason: 'the level view draws edges only');
    expect(level().editorActorSolidsInSceneForTest, 1, reason: 'the mesh solid stays in the shared scene');
    expect(previewView(tester).view!.visibleLayers & EditorViewLayers.solids, EditorViewLayers.solids);
    evm.setViewMode('Lit');
    await settle(tester, () => false, frames: 3);
    expect(level().viewLayersForTest & EditorViewLayers.all, EditorViewLayers.levelViewport);

    // A mesh selected: the panel and its view are gone.
    evm.selectActor(mesh);
    await settle(tester, () => find.byKey(panelKey).evaluate().isEmpty, frames: 10);
    expect(find.byKey(panelKey), findsNothing);
    expect(find.byKey(const ValueKey('camera_preview_filament')), findsNothing);

    // Back to the camera: shown again; × closes it while it stays selected.
    evm.selectActor(camera);
    await settle(tester, () => find.byKey(panelKey).evaluate().isNotEmpty, frames: 10);
    expect(find.byKey(panelKey), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('camera_preview_close')));
    await settle(tester, () => false, frames: 3);
    expect(find.byKey(panelKey), findsNothing);
    expect(evm.selectedActor, same(camera), reason: 'closing the preview keeps the selection');
    evm.selectActor(camera);
    await settle(tester, () => false, frames: 3);
    expect(find.byKey(panelKey), findsNothing, reason: 'closed until another selection');

    // Away and back: it opens again.
    evm.selectActor(mesh);
    await settle(tester, () => false, frames: 3);
    evm.selectActor(camera);
    await settle(tester, () => find.byKey(panelKey).evaluate().isNotEmpty, frames: 10);
    expect(find.byKey(panelKey), findsOneWidget);

    // Two actors selected: no preview.
    evm.toggleActorSelection(mesh.id);
    await settle(tester, () => false, frames: 3);
    expect(find.byKey(panelKey), findsNothing, reason: 'only a single selected camera previews');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    evm.dispose();
  }, skip: !hasAsset);

  testWidgets('the preview camera follows the actor\'s transform and its Details field of view and projection',
      (tester) async {
    final (evm, _, camera) = await openLevel(tester);
    evm.selectActor(camera);
    await settle(tester, () => find.byKey(panelKey).evaluate().isNotEmpty && previewView(tester).drawsLevelScene);

    FilamentCamera cam() => previewView(tester).camera!;
    void expectAt(List<double> location) {
      final eye = LuminaAxes.location(location);
      expect(cam().position.x, closeTo(eye.x, 1e-2));
      expect(cam().position.y, closeTo(eye.y, 1e-2));
      expect(cam().position.z, closeTo(eye.z, 1e-2));
    }

    await settle(tester, () => false, frames: 3);
    expectAt([0, -600, 150]);
    // Rotation 0 looks along +Y stored, which is −Z at runtime.
    expect(cam().forwardVector.z, closeTo(-1.0, 1e-4));
    expect(cam().getFieldOfViewInDegrees(FovDirection.vertical), closeTo(60.0, 0.05));
    expect(cam().near, closeTo(10.0, 1e-3), reason: 'the camera\'s own near clip plane (cm)');

    // A move, as the gizmo or the Details transform does it.
    evm.updateActorLocation([200, -500, 180]);
    await settle(tester, () => false, frames: 3);
    expectAt([200, -500, 180]);

    // Details commits FOV 30: one undo step, the preview zooms in.
    final component = camera.components.firstWhere((c) => c.type == 'LuminaCameraComponent');
    evm.updateComponentPropertyWithTransaction(camera.id, component.id, 'fieldOfView', 30.0);
    await settle(tester, () => false, frames: 3);
    expect(cam().getFieldOfViewInDegrees(FovDirection.vertical), closeTo(30.0, 0.05));
    evm.transactions.undo();
    await settle(tester, () => false, frames: 3);
    expect(cam().getFieldOfViewInDegrees(FovDirection.vertical), closeTo(60.0, 0.05));
    evm.transactions.redo();

    // Orthographic: a parallel projection of the camera's ortho width.
    evm.updateComponentPropertyWithTransaction(camera.id, component.id, 'projectionMode', 'Orthographic');
    await settle(tester, () => false, frames: 3);
    final p = cam().projectionMatrix;
    expect(p.entry(3, 3), closeTo(1.0, 1e-6), reason: 'an orthographic projection');
    expect(2 / p.entry(0, 0), closeTo(1000.0, 1e-2), reason: 'the default ortho width, 1000 cm');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    evm.dispose();
  }, skip: !hasAsset);

  testWidgets('dragging the top-right corner resizes the preview within limits, keeping 16:9, and the size persists',
      (tester) async {
    final (evm, _, camera) = await openLevel(tester);
    evm.selectActor(camera);
    await settle(tester, () => find.byKey(panelKey).evaluate().isNotEmpty);
    final before = tester.getRect(find.byKey(panelKey));
    final grip = find.byKey(const ValueKey('camera_preview_resize'));
    expect((tester.getRect(grip).topRight - before.topRight).distance, lessThan(1.5), reason: 'the grip sits in the free corner (inside the border)');

    double viewAspect() {
      final r = tester.getRect(find.byKey(const ValueKey('camera_preview_view')));
      return r.width / r.height;
    }

    // Right and up: bigger, anchored bottom-left, still 16:9.
    await tester.drag(grip, const Offset(160, -40));
    await settle(tester, () => false, frames: 3);
    var after = tester.getRect(find.byKey(panelKey));
    expect(after.width, closeTo(before.width + 160, 1.0));
    expect(after.left, closeTo(before.left, 0.5));
    expect(after.bottom, closeTo(before.bottom, 0.5));
    expect(viewAspect(), closeTo(CameraPreviewPanel.aspect, 0.01));
    expect(evm.editorPreferences.cameraPreviewWidth, closeTo(after.width, 1.0), reason: 'saved when the drag ends');

    // Far beyond the limits: clamped to the maximum, then the minimum.
    await tester.drag(grip, const Offset(3000, -3000));
    await settle(tester, () => false, frames: 3);
    final overlay = tester.state<CameraPreviewOverlayState>(find.byType(CameraPreviewOverlay));
    after = tester.getRect(find.byKey(panelKey));
    expect(after.width, closeTo(overlay.maxWidth, 0.5));
    expect(after.width, lessThanOrEqualTo(EditorPreferences.maxCameraPreviewWidth));
    expect(after.top, greaterThanOrEqualTo(tester.getRect(find.byType(ViewportWidget)).top + CameraPreviewOverlay.topReserve - 0.5),
        reason: 'never over the viewport\'s header');
    expect(viewAspect(), closeTo(CameraPreviewPanel.aspect, 0.01));
    await tester.drag(find.byKey(const ValueKey('camera_preview_resize')), const Offset(-3000, 3000));
    await settle(tester, () => false, frames: 3);
    after = tester.getRect(find.byKey(panelKey));
    expect(after.width, closeTo(EditorPreferences.minCameraPreviewWidth, 0.5));

    // A size in between persists per user: a fresh load reads it back, and
    // a new editor opens the panel at that size.
    await tester.drag(find.byKey(const ValueKey('camera_preview_resize')), const Offset(100, 0));
    await settle(tester, () => false, frames: 3);
    final saved = tester.getRect(find.byKey(panelKey)).width;
    expect(saved, closeTo(EditorPreferences.minCameraPreviewWidth + 100, 1.0));
    final file = evm.editorPreferences.file;
    expect((jsonDecode(file.readAsStringSync()) as Map)['cameraPreviewWidth'], closeTo(saved, 1.0));
    expect(EditorPreferences.load(configDir: file.parent).cameraPreviewWidth, closeTo(saved, 1.0));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    evm.dispose();

    final (evm2, _, camera2) = await openLevel(tester, projectName: 'CamPreviewAgain');
    evm2.selectActor(camera2);
    await settle(tester, () => find.byKey(panelKey).evaluate().isNotEmpty);
    expect(tester.getRect(find.byKey(panelKey)).width, closeTo(saved, 1.0), reason: 'remembered across sessions');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    evm2.dispose();
  }, skip: !hasAsset);
}
