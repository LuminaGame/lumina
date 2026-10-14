import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/component_tree.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../helpers/scaffold_game_project.dart';

/// F in the Blueprint 3D Viewport frames the selected component (a mesh by
/// its drawn bounds) or, with nothing selected, the whole Blueprint,
/// keeping the camera's angle.
void main() {
  late Directory root;
  late String dir;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_bp_frame_');
    dir = await scaffoldGameProject(root, name: 'bp_frame', widgetLibrary: 'flutter');
  });
  tearDownAll(() => root.deleteSync(recursive: true));

  Future<void> frames(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
    }
  }

  testWidgets('F frames the selected mesh, then the whole Blueprint with nothing selected', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: BlueprintSubEditor(
          assetName: LuminaThirdPersonContent.characterBlueprintName,
          assetPath: '$dir/${LuminaThirdPersonContent.characterBlueprintPath}',
        ),
      ),
    ));
    final state = tester.state<BlueprintSubEditorState>(find.byType(BlueprintSubEditor));
    final vm = state.viewModel;
    for (var i = 0; i < 300 && !vm.document.components.any((c) => c.name == 'Mesh'); i++) {
      await frames(tester, 1);
    }
    await tester.tap(find.descendant(of: find.byType(BlueprintComponentTree), matching: find.text('Mesh')).first);
    await frames(tester, 2);
    await tester.tap(find.text('3D Viewport'));
    await frames(tester, 10);
    final meshId = vm.document.components.firstWhere((c) => c.name == 'Mesh').id;
    for (var i = 0; i < 400 && !((vm.preview.componentFor(meshId) as LuminaStaticMeshComponent?)?.isLoaded ?? false); i++) {
      await frames(tester, 1);
    }
    expect((vm.preview.componentFor(meshId) as LuminaStaticMeshComponent).localBounds, isNotNull, reason: 'the mesh is drawn');
    dynamic viewport() => tester.state(find.byType(SubEditor3DViewport));
    final centre = tester.getCenter(find.byType(SubEditor3DViewport));

    // Orbit away first, so F has something to do; the viewport takes keys
    // once pressed.
    await tester.dragFrom(centre, const Offset(160, 40), buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
    await frames(tester, 2);
    vm.selectComponent(meshId);
    await frames(tester, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await frames(tester, 2);
    final onMesh = viewport().cameraForTest as ({Vector3 target, double distance});
    final meshFrame = vm.preview.frameOf(meshId);
    expect((onMesh.target - meshFrame.target).length, lessThan(1e-6), reason: 'centred on the mesh bounds');
    expect(onMesh.distance, closeTo(meshFrame.distance, 1e-6));
    // The character's mesh spans its capsule (about 180 cm round the actor's
    // origin): the frame fits that, not the 60 cm of a bare component.
    expect(meshFrame.distance, greaterThan(200));

    vm.selectComponent(null);
    await frames(tester, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await frames(tester, 2);
    final onAll = viewport().cameraForTest as ({Vector3 target, double distance});
    final whole = vm.preview.frameOf(null);
    expect((onAll.target - whole.target).length, lessThan(1e-6), reason: 'the whole Blueprint');
    expect(onAll.distance, closeTo(whole.distance, 1e-6));
    await tester.pumpWidget(const SizedBox());
  });
}
