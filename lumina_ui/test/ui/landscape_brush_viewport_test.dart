// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/landscape_brush.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/landscape_terrain_sink.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/viewport_ray.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/landscape_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'landscape_editor_test.dart' show RecordingTerrainSink;

/// The brush in the 3D viewport: the camera ray under
/// the mouse, the heightmap raycast, the cursor pushed to the engine, strokes
/// and scatter drags as single undo entries, and the viewport's control split.

/// A sink that also records the brush cursor the view model asks for.
class CursorRecordingSink extends RecordingTerrainSink {
  final List<LandscapeBrushCursorState?> cursors = [];

  @override
  void setBrushCursor(LandscapeBrushCursorState? cursor) => cursors.add(cursor);
}

void main() {
  test('viewportRay passes through the point projectWorldToViewport put at that pixel', () {
    const size = Size(1280, 720);
    final target = Vector3(3.0, 1.0, -2.0);
    for (final p in [Vector3(0, 0, 0), Vector3(40, 5, -30), Vector3(-60, 12, 25)]) {
      final px = projectWorldToViewport(worldPos: p, size: size, yawDeg: -35, pitchDeg: 25, distance: 150, target: target)!;
      final ray = viewportRay(local: px, size: size, yawDeg: -35, pitchDeg: 25, distance: 150, target: target)!;
      final toPoint = p - ray.origin;
      final along = toPoint.dot(ray.direction);
      final closest = ray.origin + ray.direction * along;
      expect((closest - p).length, lessThan(1e-6), reason: 'the ray through $px misses $p');
    }
  });

  group('LandscapeEditorViewModel brush input', () {
    late Directory tempDir;
    late CursorRecordingSink sink;
    late LandscapeEditorViewModel vm;
    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('lumina_landscape_brush_vp_');
      sink = CursorRecordingSink();
      vm = LandscapeEditorViewModel(assetPath: '${tempDir.path}/contents/landscapes/T.lmas', sink: sink)..open();
      // A sculpted bump so the raycast has relief to hit.
      for (var r = 0; r < 129; r++) {
        for (var c = 0; c < 129; c++) {
          final dx = (c - 64) / 20.0, dz = (r - 64) / 20.0;
          vm.data.setHeight(c, r, 10.0 + 30.0 * math.exp(-(dx * dx + dz * dz)));
        }
      }
    });
    tearDown(() {
      vm.dispose();
      tempDir.deleteSync(recursive: true);
    });

    test('the raycast hits the heightmap where a ray from above meets it, and a miss costs nothing', () {
      final hit = vm.raycast(Vector3(20.0, 300.0, -10.0), Vector3(0, -1, 0))!;
      expect(hit.x, closeTo(20.0, 1e-6));
      expect(hit.z, closeTo(-10.0, 1e-6));
      expect(hit.y, closeTo(vm.data.sampleHeight(20.0, -10.0), vm.data.cellSize));
      // Slanted: the hit lies on the ray and on the terrain.
      final origin = Vector3(-200.0, 150.0, -200.0);
      final dir = Vector3(1.0, -0.6, 1.0)..normalize();
      final slanted = vm.raycast(origin, dir)!;
      expect(slanted.y, closeTo(vm.data.sampleHeight(slanted.x, slanted.z), 0.05));

      final sw = Stopwatch()..start();
      expect(vm.raycast(Vector3(0, 300, 0), Vector3(0, 1, 0)), isNull, reason: 'pointing at the sky');
      expect(vm.raycast(Vector3(500, 50, 500), Vector3(1, 0, 0)), isNull, reason: 'beside the terrain');
      sw.stop();
      expect(sw.elapsedMicroseconds, lessThan(1000), reason: 'a miss must not march 100 000 steps');
    });

    test('hovering pushes the active brush as a cursor on the terrain; off the terrain and in Manage it is cleared', () {
      vm.setTab(LandscapeEditorTab.sculpt);
      vm.setBrushRadius(15.0);
      vm.setBrushFalloff(0.4);
      vm.hoverRay(Vector3(5.0, 300.0, 5.0), Vector3(0, -1, 0));
      expect(vm.cursorWorldX, closeTo(5.0, 1e-6));
      final c = sink.cursors.last!;
      expect(c.x, closeTo(5.0, 1e-6));
      expect(c.z, closeTo(5.0, 1e-6));
      expect(c.radius, 15.0);
      expect(c.falloff, 0.4);
      expect(c.kind, LandscapeCursorKind.sculpt);

      vm.setTab(LandscapeEditorTab.foliage);
      vm.setFoliageBrushRadius(7.0);
      vm.hoverRay(Vector3(5.0, 300.0, 5.0), Vector3(0, -1, 0));
      expect(sink.cursors.last!.radius, 7.0, reason: 'the Foliage tab shows the foliage brush');
      expect(sink.cursors.last!.kind, LandscapeCursorKind.scatter);
      vm.setPaintMode(FoliagePaintMode.erase);
      expect(sink.cursors.last!.kind, LandscapeCursorKind.erase);

      vm.hoverRay(Vector3(0, 300, 0), Vector3(0, 1, 0));
      expect(sink.cursors.last, isNull, reason: 'off the terrain there is no cursor');

      vm.hoverRay(Vector3(5.0, 300.0, 5.0), Vector3(0, -1, 0));
      expect(sink.cursors.last, isNotNull);
      vm.setTab(LandscapeEditorTab.manage);
      expect(sink.cursors.last, isNull, reason: 'Manage shows no brush');
    });

    test('a sculpt drag in the viewport raises the terrain along its path as one undo entry; Shift lowers', () {
      vm.setTab(LandscapeEditorTab.sculpt);
      vm.setTool(LandscapeTool.sculpt);
      vm.setBrushRadius(8.0);
      vm.setBrushStrength(1.0);
      final before = vm.data.sampleHeight(-40.0, 30.0);
      final beforeEnd = vm.data.sampleHeight(-10.0, 30.0);
      expect(vm.brushDown(Vector3(-40, 300, 30), Vector3(0, -1, 0)), isTrue);
      vm.brushDrag(Vector3(-25, 300, 30), Vector3(0, -1, 0));
      vm.brushDrag(Vector3(-10, 300, 30), Vector3(0, -1, 0));
      vm.brushUp();
      expect(vm.data.sampleHeight(-40.0, 30.0), greaterThan(before));
      expect(vm.data.sampleHeight(-10.0, 30.0), greaterThan(beforeEnd));
      expect(vm.undoDepth, 1, reason: 'one drag, one undo entry');

      final raised = vm.data.sampleHeight(-25.0, 30.0);
      vm.brushDown(Vector3(-25, 300, 30), Vector3(0, -1, 0), invert: true);
      vm.brushUp();
      expect(vm.data.sampleHeight(-25.0, 30.0), lessThan(raised), reason: 'Shift+LMB lowers');
      expect(vm.undoDepth, 2);
    });

    test('a scatter drag places instances along its path as one undo entry; Shift+drag erases', () {
      vm.setTab(LandscapeEditorTab.foliage);
      vm.addFoliageLayer(meshAssetId: 'b', meshAssetPath: '${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb', name: 'B');
      vm.setLayerRules(0, const FoliageRules(density: 30.0, minSpacing: 0.5, slopeMaxDegrees: 90.0));
      vm.setFoliageBrushRadius(6.0);
      vm.setFoliageBrushFalloff(0.0);
      vm.setPaintDensity(1.0);
      final undoBefore = vm.undoDepth;
      expect(vm.brushDown(Vector3(-50, 300, -40), Vector3(0, -1, 0)), isTrue);
      vm.brushDrag(Vector3(-30, 300, -40), Vector3(0, -1, 0));
      vm.brushDrag(Vector3(-10, 300, -40), Vector3(0, -1, 0));
      vm.brushUp();
      final layer = vm.data.layers[0];
      expect(layer.instanceCount, greaterThan(0));
      expect(vm.undoDepth, undoBefore + 1, reason: 'one scatter drag, one undo entry');
      var nearStart = 0, nearEnd = 0;
      for (var i = 0; i < layer.instanceCount; i++) {
        final inst = layer.instanceAt(i);
        if ((inst.x + 50).abs() < 6 && (inst.z + 40).abs() < 6) nearStart++;
        if ((inst.x + 10).abs() < 6 && (inst.z + 40).abs() < 6) nearEnd++;
      }
      expect(nearStart, greaterThan(0));
      expect(nearEnd, greaterThan(0), reason: 'the drag scattered along its whole path');

      final count = layer.instanceCount;
      vm.setEraseDensity(0.0);
      vm.brushDown(Vector3(-30, 300, -40), Vector3(0, -1, 0), invert: true);
      vm.brushUp();
      expect(layer.instanceCount, lessThan(count), reason: 'Shift+LMB with Scatter erases');
      expect(vm.undoDepth, undoBefore + 2);
    });

    test('Manage takes no brush input', () {
      vm.setTab(LandscapeEditorTab.manage);
      expect(vm.brushDown(Vector3(0, 300, 0), Vector3(0, -1, 0)), isFalse);
      expect(vm.undoDepth, 0);
    });
  });

  group('SubEditor3DViewport brushInput', () {
    Future<(List<String>, State)> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final calls = <String>[];
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SubEditor3DViewport(
            title: 'Brush Test',
            yUpCamera: true,
            showShapeSelector: false,
            initialCameraDistance: 300,
            brushInput: ViewportBrushInput(
              onHover: (ray) => calls.add('hover ${ray.direction.y < 0 ? 'down' : 'up'}'),
              onStrokeStart: (ray, {required bool invert}) {
                calls.add('start${invert ? ' invert' : ''}');
                return true;
              },
              onStrokeUpdate: (ray) => calls.add('update'),
              onStrokeEnd: () => calls.add('end'),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      return (calls, tester.state(find.byType(SubEditor3DViewport)));
    }

    testWidgets('hover reports camera rays; a plain LMB drag paints and leaves the camera alone', (tester) async {
      final (calls, state) = await pump(tester);
      final centre = tester.getCenter(find.byType(SubEditor3DViewport));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: centre);
      await mouse.moveTo(centre + const Offset(10, 10));
      await tester.pump();
      expect(calls, contains('hover down'), reason: 'a ray from the orbit camera points down at the scene');

      final pitch = (state as dynamic).cameraPitchForTest as double;
      final drag = await tester.startGesture(centre, kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
      await drag.moveBy(const Offset(0, 40));
      await drag.moveBy(const Offset(0, 40));
      await drag.up();
      await tester.pump();
      expect(calls.where((c) => c.startsWith('start')), hasLength(1));
      expect(calls.where((c) => c == 'update').length, greaterThanOrEqualTo(2));
      expect(calls.last, 'end');
      expect((state as dynamic).cameraPitchForTest, pitch, reason: 'painting must not orbit the camera');

      calls.clear();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final shifted = await tester.startGesture(centre, kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
      await shifted.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(calls.first, 'start invert', reason: 'Shift+LMB inverts the brush');
    });

    testWidgets('Alt+LMB orbits and never paints', (tester) async {
      final (calls, state) = await pump(tester);
      final centre = tester.getCenter(find.byType(SubEditor3DViewport));
      final pitch = (state as dynamic).cameraPitchForTest as double;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      final drag = await tester.startGesture(centre, kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
      await drag.moveBy(const Offset(0, 40));
      await drag.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();
      expect(calls.where((c) => c.startsWith('start') || c == 'update' || c == 'end'), isEmpty);
      expect((state as dynamic).cameraPitchForTest, isNot(pitch), reason: 'Alt+LMB orbits');
    });
  });
}
