import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_transform.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../test/helpers/blueprint_test_project.dart';

/// Smoke — Ctrl+D on a placed multi-mesh Blueprint draws the copy.
///
/// A real project with `BP_Tunnel` (a scene root, an AC unit and two barrels
/// chained under it, real `test-assets/Props` meshes) placed in the level.
/// The user's steps: click the viewport, select the Blueprint, Ctrl+D, W,
/// drag the copy's gizmo away. Before the fix the copy had no class and no
/// mesh, so only its label and a default selection box showed. The copy's
/// screen region (its mesh bounds projected through the Filament camera) is
/// compared with the same frame with the copy hidden: mesh pixels, not
/// background. Runs on GPU 1 (`tool/smoke_report.dart` injects it).
const _testName = 'Actor Duplicate Smoke: Ctrl+D on a multi-mesh Blueprint draws the copy where it is moved';
const _assets = ['Props/AC_units/ac_unit_b_600x600.glb', 'Props/Barrels/fuel_barrel_red.glb'];
const _unitMesh = 'contents/meshes/static/SM_AcUnit.glb';
const _barrelMesh = 'contents/meshes/static/SM_Barrel.glb';
const _tunnelPath = 'contents/blueprints/BP_Tunnel.lmas';

Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(_testName, (tester) async {
    final assetsDir = SmokeArtifacts.testAssetsDir.path;
    for (final rel in _assets) {
      if (!File('$assetsDir/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    final root = Directory.systemTemp.createTempSync('lumina_smoke_dup81_');
    final dir = '${root.path}/DupSmoke';
    Directory('$dir/contents/levels').createSync(recursive: true);
    const project = LuminaProject(projectName: 'DupSmoke', activeLevel: 'contents/levels/L_Main.lmas');
    File('$dir/DupSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    for (final (from, to) in [(_assets[0], _unitMesh), (_assets[1], _barrelMesh)]) {
      File('$dir/$to')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(File('$assetsDir/$from').readAsBytesSync());
    }
    writeBlueprint(
      dir,
      'BP_Tunnel',
      LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
        LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
        LuminaBlueprintComponent(id: 'unit', name: 'Unit', type: 'LuminaStaticMeshComponent', parentId: 'root', properties: {
          'staticMeshAsset': _unitMesh,
        }),
        LuminaBlueprintComponent(id: 'barrel_l', name: 'BarrelL', type: 'LuminaStaticMeshComponent', parentId: 'unit', properties: {
          'staticMeshAsset': _barrelMesh,
          'location': [-120.0, 0.0, 0.0],
        }),
        LuminaBlueprintComponent(id: 'barrel_r', name: 'BarrelR', type: 'LuminaStaticMeshComponent', parentId: 'barrel_l', properties: {
          'staticMeshAsset': _barrelMesh,
          'location': [240.0, 0.0, 0.0],
        }),
      ]),
    );

    EditorViewModel? vm;
    try {
      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
      final editor = vm;
      await tester.runAsync(editor.ensureDefaultLevelAssets);
      // A sun and a sky, so the props are lit.
      for (final type in ['DirectionalLight', 'Environment']) {
        if (!editor.actors.any((a) => a.type == type)) editor.spawnNewActor(type);
      }
      editor.refreshAssets();
      final asset = editor.realAssets.firstWhere((a) => a.relativePath == _tunnelPath);
      await tester.runAsync(() => editor.spawnActorFromAsset(asset, location: [0.0, 0.0, 0.0]));
      final original = editor.actors.lastWhere((a) => a.blueprintClass == _tunnelPath);
      expect(original.meshData, isNotNull, reason: 'the placed Blueprint draws its AC unit');
      // An orbit view onto the Blueprint, far enough back that the copy
      // stays in view once it is dragged away.
      editor.restoreCameraSnapshot([editor.cameraYaw, editor.cameraPitch, 2400.0, 0.0, 0.0, 40.0]);

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
      ));
      await _settle(tester, 60);

      dynamic viewport() => tester.state(find.byType(ViewportWidget));
      ({int root, List<int> entities})? drawn(String id) =>
          viewport().actorInstanceInSceneForTest(id) as ({int root, List<int> entities})?;
      for (var i = 0; i < 300 && drawn(original.id) == null; i++) {
        await _settle(tester, 1);
      }
      expect(drawn(original.id), isNotNull, reason: 'the original is in the Filament scene');

      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(milliseconds: 1500));

      // Click the viewport (it takes the keyboard), select the Blueprint, Ctrl+D.
      final viewportRect = tester.getRect(find.byType(ViewportWidget));
      // One mouse for the whole session (a second one on the same device trips
      // the mouse tracker).
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: viewportRect.center);
      addTearDown(mouse.removePointer);
      await mouse.down(viewportRect.topLeft + const Offset(40, 60));
      await mouse.up();
      await _settle(tester, 3);
      editor.selectActor(original);
      await rec.hold(const Duration(milliseconds: 1200));
      final before = editor.actors.map((a) => a.id).toSet();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await rec.hold(const Duration(milliseconds: 600));
      final copy = editor.actors.singleWhere((a) => !before.contains(a.id));
      debugPrint('[dup_smoke] copy ${copy.name} class=${copy.blueprintClass} mesh=${copy.meshData != null}');
      expect(copy.blueprintClass, _tunnelPath, reason: 'the copy is a BP_Tunnel');
      for (var i = 0; i < 300 && drawn(copy.id) == null; i++) {
        await _settle(tester, 1);
      }
      expect(drawn(copy.id), isNotNull, reason: 'the copy is in the Filament scene');
      expect(drawn(copy.id)!.entities.length, drawn(original.id)!.entities.length);

      // W, then drag the copy's gizmo away along its X or Y handle.
      editor.selectActor(copy);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await rec.hold(const Duration(milliseconds: 800));
      final handles = viewport().gizmoHandleScreenPositionsForTest(viewportRect.size) as Map<String, Offset>;
      String? axis;
      for (final candidate in ['X', 'Y']) {
        await mouse.moveTo(viewportRect.topLeft + handles[candidate]!);
        await rec.hold(const Duration(milliseconds: 300));
        axis = viewport().hoveredGizmoAxisForTest as String?;
        if (axis != null) break;
      }
      expect(axis, isNotNull, reason: 'the pointer is over a gizmo handle');
      final grab = viewportRect.topLeft + handles[axis]!;
      final along = handles[axis]! - handles['CENTER']!;
      // Back along the handle: the original sits right of the view centre.
      final step = -along / along.distance;
      final startLocation = List<double>.from(copy.location);
      await mouse.down(grab);
      await rec.hold(const Duration(milliseconds: 100));
      for (var i = 1; i <= 50; i++) {
        await mouse.moveTo(grab + step * (5.0 * i));
        await rec.hold(const Duration(milliseconds: 33));
      }
      await mouse.up();
      await rec.hold(const Duration(milliseconds: 1200));
      final moved = [for (var i = 0; i < 3; i++) (copy.location[i] - startLocation[i]).abs()].reduce(math.max);
      debugPrint('[dup_smoke] dragged $axis: $startLocation -> ${copy.location}');
      expect(moved, greaterThan(100.0), reason: 'the gizmo drag moved the copy');
      expect(original.location, [0.0, 0.0, 0.0], reason: 'the original stayed');

      // The copy's mesh bounds on screen, through the Filament camera.
      final size = viewportRect.size;
      Rect screenBounds(EditorActorNode a) {
        final m = EditorTransforms.meshMatrix(a);
        final lo = a.meshData!.minBounds, hi = a.meshData!.maxBounds;
        final points = <Offset>[];
        for (final x in [lo[0], hi[0]]) {
          for (final y in [lo[1], hi[1]]) {
            for (final z in [lo[2], hi[2]]) {
              final s = m.transform3(Vector3(x, y, z)); // runtime, Y up
              final p = viewport().nativeProjectForTest(s.x, -s.z, s.y, size) as Offset?;
              if (p != null) points.add(p);
            }
          }
        }
        expect(points, hasLength(8), reason: '${a.name} is in front of the camera');
        final xs = points.map((p) => p.dx), ys = points.map((p) => p.dy);
        return Rect.fromLTRB(xs.reduce(math.min), ys.reduce(math.min), xs.reduce(math.max), ys.reduce(math.max))
            .shift(viewportRect.topLeft);
      }

      final copyRect = screenBounds(copy);
      final originalRect = screenBounds(original);
      debugPrint('[dup_smoke] copy on screen $copyRect, original $originalRect');
      expect(viewportRect.contains(copyRect.center), isTrue, reason: 'the moved copy is in view');
      final core = Rect.fromCenter(center: copyRect.center, width: copyRect.width * 0.5, height: copyRect.height * 0.5);
      expect(core.overlaps(originalRect), isFalse, reason: 'the copy moved clear of the original');

      editor.clearSelection();
      await rec.hold(const Duration(milliseconds: 1500));
      final withCopy = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      editor.setActorVisibilityWithTransaction(copy.id, false);
      await rec.hold(const Duration(milliseconds: 1500));
      final withoutCopy = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      editor.setActorVisibilityWithTransaction(copy.id, true);
      await rec.hold(const Duration(milliseconds: 1500));

      // Fraction of pixels in [r] that change when the copy is hidden.
      final a = img.decodePng(withCopy)!, b = img.decodePng(withoutCopy)!;
      double changed(Rect r) {
        var n = 0, hit = 0;
        for (var y = r.top.floor(); y < r.bottom.ceil(); y++) {
          for (var x = r.left.floor(); x < r.right.ceil(); x++) {
            if (x < 0 || y < 0 || x >= a.width || y >= a.height) continue;
            final p = a.getPixel(x, y), q = b.getPixel(x, y);
            final d = (p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs();
            n++;
            if (d > 30) hit++;
          }
        }
        return n == 0 ? 0 : hit / n;
      }

      final copyChanged = changed(core);
      final control = changed(Rect.fromLTWH(viewportRect.left + 20, viewportRect.top + 40, core.width, core.height));
      debugPrint('[dup_smoke] copy region changed ${(copyChanged * 100).toStringAsFixed(1)}%, control ${(control * 100).toStringAsFixed(1)}%');
      expect(copyChanged, greaterThan(0.3), reason: 'the copy\'s region shows mesh pixels, not background');
      expect(control, lessThan(0.05), reason: 'away from the copy the frame is the same');

      SmokeArtifacts.saveScreenshot(_testName, withCopy, usedAssets: _assets, metrics: {
        'copyRegionChangedPct': double.parse((copyChanged * 100).toStringAsFixed(1)),
        'controlRegionChangedPct': double.parse((control * 100).toStringAsFixed(1)),
        'copyRenderables': drawn(copy.id)!.entities.length,
      });
      await rec.hold(const Duration(milliseconds: 1500));
      expect(rec.recorded, greaterThanOrEqualTo(const Duration(seconds: 10)));
      rec.save(_testName, usedAssets: _assets);
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  });
}
