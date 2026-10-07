import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Camera moves made outside the viewport (Outliner "Focus",
/// View → Reset Camera, the Navigation editor, the end of a Play session)
/// changed the view model's camera but not the Filament one, so the render
/// kept the old view until the next orbit, dolly or WASD gesture.
void main() {
  testWidgets('a camera move made in the view model reaches the Filament view without a viewport gesture', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('lumina_viewport_camera_sync_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'CameraSync'),
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    vm.spawnNewActor('PlayerStart');
    final target = vm.actors.last..location = [400.0, 300.0, 60.0];

    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: ViewportWidget(viewModel: vm)));
    dynamic viewport() => tester.state(find.byType(ViewportWidget));
    final size = tester.getSize(find.byType(ViewportWidget));
    final centre = Offset(size.width / 2, size.height / 2);

    Offset? drawnAt(List<double> p) => viewport().nativeProjectForTest(p[0], p[1], p[2], size) as Offset?;

    for (var i = 0; i < 30 && drawnAt(target.location) == null; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final before = drawnAt(target.location);
    expect(before, isNotNull, reason: 'the viewport needs its native Filament camera for this test');
    expect((before! - centre).distance, greaterThan(50), reason: 'the opening camera looks at the origin, not at the actor');

    // Outliner → Focus: no pointer or key event reaches the viewport.
    vm.focusCameraOnActor(target);
    await tester.pump(const Duration(milliseconds: 16));
    final focused = drawnAt(target.location)!;
    expect((focused - centre).distance, lessThan(1.0),
        reason: 'Focus centres the actor in the rendered frame, not only in the view model (drawn at $focused, centre $centre)');

    // View → Reset Camera: the origin is back in the middle of the frame.
    vm.resetCamera();
    await tester.pump(const Duration(milliseconds: 16));
    final reset = drawnAt([0.0, 0.0, 0.0])!;
    expect((reset - centre).distance, lessThan(1.0), reason: 'Reset Camera re-aims the rendered view at the origin (drawn at $reset)');
    expect((drawnAt(target.location)! - before).distance, lessThan(1.0), reason: 'and it is the same view the viewport opened with');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 16));
    vm.dispose();
  });

  testWidgets('stopping Play gives the Filament view back to the editor camera', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('lumina_viewport_camera_sync_pie_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final template = GameTemplateCatalog.byId(kFirstPersonTemplateId);
    final vm = EditorViewModel(
      initialProject: LuminaProject(projectName: 'CameraSyncPie', template: kFirstPersonTemplateId, input: template.input),
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    // The template's gameplay actors: a player start for the character to
    // spawn at. (Its primitives only add mesh uploads this test does not need.)
    vm.restoreSnapshot(template.levelActors.map(EditorActorNode.fromMap).where((a) => a.type != 'Primitive').toList());

    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: ViewportWidget(viewModel: vm)));
    dynamic viewport() => tester.state(find.byType(ViewportWidget));
    final size = tester.getSize(find.byType(ViewportWidget));
    final centre = Offset(size.width / 2, size.height / 2);
    Offset? drawnAt(List<double> p) => viewport().nativeProjectForTest(p[0], p[1], p[2], size) as Offset?;

    for (var i = 0; i < 30 && drawnAt([0.0, 0.0, 0.0]) == null; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final pivot = [vm.cameraPanX, vm.cameraPanY, vm.cameraPanZ];
    expect((drawnAt(pivot)! - centre).distance, lessThan(1.0), reason: 'the editor camera looks at its pivot before Play');

    vm.onStartSimulationRequest!();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(vm.pieController.lastError, isNull, reason: 'PIE error: ${vm.pieController.lastError}');
    expect(viewport().pieCameraDrivesViewForTest as bool, isTrue, reason: 'the possessed character must own the view');
    final playing = drawnAt(pivot);
    expect(playing == null || (playing - centre).distance > 1.0, isTrue,
        reason: 'the character looks from its own eye, not along the editor camera');

    vm.onStopSimulationRequest!();
    await tester.pump(const Duration(milliseconds: 16));
    expect(vm.pieController.isPlaying, isFalse);
    final after = drawnAt(pivot);
    expect(after, isNotNull, reason: 'the editor pivot must be in front of the camera again after Stop');
    expect((after! - centre).distance, lessThan(1.0),
        reason: 'Stop restores the editor camera in the rendered frame too, not only in the view model (drawn at $after)');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 16));
    vm.dispose();
  });
}
