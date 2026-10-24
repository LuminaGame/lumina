import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/viewport_pills.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/static_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A sub-editor viewport's Aurora chrome: the pill row top-left (view mode,
/// projection, preview shape, Show), Reset View top-right, and the Static
/// Mesh editor's Show menu that toggles its collision view and a bounds box
/// drawn from the mesh's own bounds.
void main() {
  Future<void> settle(WidgetTester tester, {int frames = 20}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('the pill row: view mode with Wireframe, projection, shape and Show; Reset View at the right', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var collision = true;
    var bounds = false;
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: StatefulBuilder(
          builder: (context, setState) => SubEditor3DViewport(
            title: 'Static Mesh 3D Preview Viewport',
            showShapeSelector: true,
            showItems: [
              ViewportShowItem(label: 'Collision', value: collision, onChanged: (v) => setState(() => collision = v)),
              ViewportShowItem(label: 'Bounds', value: bounds, onChanged: (v) => setState(() => bounds = v)),
            ],
          ),
        ),
      ),
    ));
    await settle(tester);

    final viewport = tester.getRect(find.byType(SubEditor3DViewport));
    final shading = tester.getRect(find.byKey(const ValueKey('sub_viewport_shading')));
    expect(shading.left - viewport.left, closeTo(ViewportPillStyle.inset, 1));
    expect(shading.height, ViewportPillStyle.height);
    expect(find.byKey(const ValueKey('sub_viewport_projection')), findsOneWidget);
    expect(find.byKey(const ValueKey('sub_viewport_shape')), findsOneWidget);
    final reset = tester.getRect(find.byKey(const ValueKey('sub_viewport_reset_view')));
    expect(viewport.right - reset.right, closeTo(ViewportPillStyle.inset, 1));

    // The view mode pill offers Wireframe.
    await tester.tap(find.byKey(const ValueKey('sub_viewport_shading')));
    await settle(tester);
    expect(find.text('Wireframe'), findsOneWidget);
    await tester.tap(find.text('Wireframe'));
    await settle(tester, frames: 40);
    expect(find.descendant(of: find.byKey(const ValueKey('sub_viewport_shading')), matching: find.text('Wireframe')), findsOneWidget);

    // Show lists Collision and Bounds and toggles them.
    expect(find.text('Show · 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sub_viewport_show')));
    await settle(tester);
    expect(find.byKey(const ValueKey('sub_viewport_show_collision')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sub_viewport_show_bounds')));
    await settle(tester, frames: 40);
    expect(bounds, isTrue);
    expect(find.text('Show · 2'), findsOneWidget);
  });

  test('Show · Bounds draws the mesh bounds as 12 edges in the viewport frame', () async {
    final barrel = File('${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb');
    if (!barrel.existsSync()) return markTestSkipped('test-assets/Props/Barrels missing');
    final root = Directory.systemTemp.createTempSync('lumina_bounds_pill_');
    addTearDown(() => root.deleteSync(recursive: true));
    final result = await ImportAssetUseCase()(projectDir: root.path, sourceFilePath: barrel.path);
    expect(result.isSuccess, isTrue, reason: result.error);
    final vm = StaticMeshEditorViewModel(assetPath: '${root.path}/${result.asset!.relativePath}');
    await vm.load();
    expect(vm.boundsLineSet, isNull, reason: 'off by default');
    vm.setShowBounds(true);
    final set = vm.boundsLineSet!;
    expect(set.segmentCount, 12);
    expect(set.positions.length, 8 * 3);
    // The box spans the mesh's bounds, read back in the authoring frame.
    final xs = [for (var i = 0; i < 24; i += 3) set.positions[i]];
    final ys = [for (var i = 1; i < 24; i += 3) set.positions[i]];
    final width = (xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b)) * 100;
    final height = (ys.reduce((a, b) => a > b ? a : b) - ys.reduce((a, b) => a < b ? a : b)) * 100;
    expect(width, closeTo(vm.boundsWidth, 1), reason: 'glTF X (m) is the authoring width (cm)');
    expect(height, closeTo(vm.boundsHeight, 1), reason: 'glTF Y up (m) is the authoring height along Z (cm)');
    vm.setShowCollisionWireframe(false);
    expect(vm.showCollisionWireframe, isFalse);
    vm.dispose();
  });
}
