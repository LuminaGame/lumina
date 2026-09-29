import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_filament/flutter_filament.dart' show GizmoMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Selecting an actor must give the transform manipulator: coloured axis
/// arrows for Move, rings for Rotate, handles for Scale, and the handle under
/// the pointer must light up. The gizmo's mode used to be stuck on translate
/// because nothing ever told it the active tool, and hover hit-testing used a
/// fixed world offset that only lined up at one zoom level.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Gizmo Smoke: Move arrows, Rotate rings, Scale handles, and hover highlight', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_gizmo_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeGizmo')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeGizmo', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeGizmo.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      // A primitive gives the gizmo something solid to sit on.
      vm.spawnNewActor('Primitive');
      final target = vm.actors.last;
      // Off the origin on every axis: a gizmo that ignores the editor's
      // coordinate mapping only looks right at (0, 0, 0).
      target.location = [40.0, 25.0, -30.0];
      await tester.runAsync(() => vm.ensureActorMeshDataForTest(target));

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

      await settle(40);

      dynamic viewportState() => tester.state(find.byType(ViewportWidget));

      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));
      vm.selectActor(target);
      vm.setActiveTool('translate');
      await settle(20);
      await rec.hold(const Duration(milliseconds: 500));

      final gizmo = viewportState().nativeGizmoForTest;
      final hasGizmo = gizmo != null;
      if (!hasGizmo) {
        debugPrint('[gizmo_smoke] no native gizmo in this run; mode assertions skipped');
      }

      // Each step's screenshot is followed by the running editor on video.
      Future<void> shot(String name) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png);
        await rec.hold(const Duration(milliseconds: 1200));
      }

      // --- Move: three coloured axes with arrow heads ----------------------
      if (hasGizmo) {
        expect(gizmo.mode, GizmoMode.translate);
        expect(gizmo.handleIds, containsAll(<String>['X', 'Y', 'Z']),
            reason: 'one handle per axis: ${gizmo.handleIds}');
      }
      await shot('gizmo_move_axes');

      // --- The axes must be coloured, not white ----------------------------
      // The arrows are drawn by Filament, so the only honest check is the
      // pixels. The editor grid is white and crosses the same region, so
      // sampling along an axis would measure the grid; instead capture the
      // viewport with the gizmo hidden and again with it shown, and look only
      // at the pixels the gizmo itself added.
      {
        final rect = tester.getRect(find.byType(ViewportWidget));

        Future<img.Image> shoot() async {
          final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
          return img.decodePng(png)!;
        }

        vm.toggleShowFlag('Transform Gizmo');
        await settle(20);
        expect(vm.showFlags['Transform Gizmo'], isFalse);
        final without = await shoot();

        vm.toggleShowFlag('Transform Gizmo');
        await settle(20);
        expect(vm.showFlags['Transform Gizmo'], isTrue);

        // A manipulator whose handles have no material instance is drawn by
        // Filament's default material and comes out white whatever colour is
        // set on it. Nothing else about the frame looks wrong, so assert it.
        final live = viewportState().nativeGizmoForTest;
        if (live != null) {
          expect(live.handlesAreColourable, isTrue,
              reason: 'the wireframe material did not compile, so the manipulator cannot be coloured');
        }
        final with_ = await shoot();

        // Pixels the gizmo drew, inside a window around where the editor says
        // the manipulator is. The window matters: the viewport's own HUD
        // ("Tris / FPS / CPU", in amber) changes every frame, so a whole-
        // viewport diff reports those as red gizmo pixels.
        final hs = viewportState().gizmoHandleScreenPositionsForTest(rect.size) as Map<String, Offset>;
        final centreOffset = hs['CENTER']!;
        final expectedSpan = (hs['X']! - centreOffset).distance;
        final window = math.max(60.0, expectedSpan * 2.0);
        debugPrint('[gizmo_smoke] centre=$centreOffset axis=${expectedSpan.toStringAsFixed(0)}px '
            'window=${window.toStringAsFixed(0)}px');

        final x0 = rect.left.round(), y0 = rect.top.round();
        var minGx = 1 << 30, minGy = 1 << 30, maxGx = -1, maxGy = -1;
        final byHue = <String, int>{'red': 0, 'green': 0, 'blue': 0, 'grey': 0};

        for (var ly = (centreOffset.dy - window).round(); ly <= (centreOffset.dy + window).round(); ly++) {
          for (var lx = (centreOffset.dx - window).round(); lx <= (centreOffset.dx + window).round(); lx++) {
            final x = x0 + lx, y = y0 + ly;
            if (x < 0 || y < 0 || x >= with_.width || y >= with_.height) continue;
            if (lx < 0 || ly < 0 || lx >= rect.width || ly >= rect.height) continue;
            final a = without.getPixel(x, y);
            final b = with_.getPixel(x, y);
            final gain = [b.r - a.r, b.g - a.g, b.b - a.b].reduce(math.max);
            if (gain <= 60) continue;

            if (lx < minGx) minGx = lx;
            if (ly < minGy) minGy = ly;
            if (lx > maxGx) maxGx = lx;
            if (ly > maxGy) maxGy = ly;

            final hue = (b.r > b.g && b.r > b.b)
                ? 'red'
                : (b.g > b.r && b.g > b.b)
                    ? 'green'
                    : (b.b > b.r && b.b > b.g)
                        ? 'blue'
                        : 'grey';
            byHue[hue] = byHue[hue]! + 1;
          }
        }

        debugPrint('[gizmo_smoke] manipulator pixels $byHue bbox=$minGx,$minGy..$maxGx,$maxGy');
        expect(maxGx, greaterThanOrEqualTo(0), reason: 'hiding the gizmo changed nothing, so it was never drawn');

        // The manipulator must be painted around the point the editor
        // hit-tests against, at roughly the size the editor thinks it is.
        // Asserting the editor's projection against its own helper proved
        // nothing; these are the real pixels.
        expect(centreOffset.dx, greaterThanOrEqualTo(minGx - 12.0));
        expect(centreOffset.dx, lessThanOrEqualTo(maxGx + 12.0));
        expect(centreOffset.dy, greaterThanOrEqualTo(minGy - 12.0));
        expect(centreOffset.dy, lessThanOrEqualTo(maxGy + 12.0));

        // The manipulator is red/green/blue per axis. Mostly grey is the
        // bug the user reported.
        final coloured = byHue['red']! + byHue['green']! + byHue['blue']!;
        expect(coloured, greaterThan(byHue['grey']!),
            reason: 'the manipulator is mostly grey/white: $byHue');
        for (final hue in ['red', 'green', 'blue']) {
          expect(byHue[hue]!, greaterThan(0), reason: 'no $hue axis is drawn: $byHue');
        }
      }

      // --- Hover: the handle under the pointer lights up -------------------
      final viewportRect = tester.getRect(find.byType(ViewportWidget));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: viewportRect.center);
      addTearDown(mouse.removePointer);
      await settle(6);

      // Point at the X handle where it is actually drawn, the way a user does.
      final handles = viewportState().gizmoHandleScreenPositionsForTest(viewportRect.size) as Map<String, Offset>?;
      expect(handles, isNotNull, reason: 'a selected actor has gizmo handles');
      debugPrint('[gizmo_smoke] handles: ${handles!.map((k, v) => MapEntry(k, '${v.dx.toStringAsFixed(0)},${v.dy.toStringAsFixed(0)}'))}');
      await mouse.moveTo(viewportRect.topLeft + handles['X']!);
      await settle(6);
      await rec.capture();
      var hoveredAxis = viewportState().hoveredGizmoAxisForTest as String?;
      if (hoveredAxis == null) {
        await mouse.moveTo(viewportRect.topLeft + handles['Y']!);
        await settle(6);
        await rec.capture();
        hoveredAxis = viewportState().hoveredGizmoAxisForTest as String?;
      }
      final overlayCentre = handles['CENTER']!;
      final nativeCentre = viewportState().nativeProjectForTest(
        target.location[0], target.location[1], target.location[2], viewportRect.size) as Offset?;
      debugPrint('[gizmo_smoke] overlay=$overlayCentre native=$nativeCentre '
          'delta=${nativeCentre == null ? 'n/a' : (nativeCentre - overlayCentre).distance.toStringAsFixed(1)}px');
      debugPrint('[gizmo_smoke] hovered handle: $hoveredAxis');
      expect(hoveredAxis, isNotNull, reason: 'moving over a handle must highlight it');
      await shot('gizmo_move_hover');

      // The overlay and the renderer must agree on where the actor is, or the
      // user points at an arrow and the editor thinks they pointed elsewhere.
      // (A pixel diff cannot check this: temporal anti-aliasing changes every
      // frame, so toggling the gizmo repaints the whole viewport.)
      expect(nativeCentre, isNotNull);
      expect((nativeCentre! - overlayCentre).distance, lessThan(1.0),
          reason: 'overlay projection must match the Filament camera exactly');

      // --- Drag the hovered handle: the actor follows the pointer ----------
      final grabAt = viewportRect.topLeft + handles[hoveredAxis]!;
      final along = (handles[hoveredAxis]! - overlayCentre);
      final dir = along / along.distance;
      final before = List<double>.from(target.location);
      await mouse.down(grabAt);
      await rec.hold(const Duration(milliseconds: 100));
      for (var i = 1; i <= 30; i++) {
        await mouse.moveTo(grabAt + dir * (5.0 * i));
        await rec.hold(const Duration(milliseconds: 33));
      }
      await mouse.up();
      await settle(6);
      final moved = [for (var i = 0; i < 3; i++) (target.location[i] - before[i]).abs()].reduce(math.max);
      debugPrint('[gizmo_smoke] dragged $hoveredAxis: ${before.map((v) => v.toStringAsFixed(1))} -> ${target.location.map((v) => v.toStringAsFixed(1))}');
      expect(moved, greaterThan(1.0), reason: 'dragging the $hoveredAxis handle must move the actor');
      await rec.hold(const Duration(seconds: 1));

      // Edit -> Undo puts it back where it was.
      await tester.tap(find.text('Edit').first);
      await settle(6);
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('Undo')).last);
      await settle(6);
      expect(target.location, before, reason: 'one undo reverts the whole drag');
      await rec.hold(const Duration(seconds: 1));

      // --- Rotate: rings, not arrows ---------------------------------------
      vm.setActiveTool('rotate');
      await settle(20);
      if (hasGizmo) {
        expect(viewportState().nativeGizmoForTest.mode, GizmoMode.rotate,
            reason: 'the Rotate tool must show the rotation rings');
      }
      await shot('gizmo_rotate_rings');

      // --- Scale ------------------------------------------------------------
      vm.setActiveTool('scale');
      await settle(20);
      if (hasGizmo) {
        expect(viewportState().nativeGizmoForTest.mode, GizmoMode.scale);
      }
      await shot('gizmo_scale_handles');

      // Back to Move, so the recording ends where it started.
      vm.setActiveTool('translate');
      await settle(20);
      await shot('gizmo_move_again');

      rec.save('Gizmo Smoke: Move arrows, Rotate rings, Scale handles, and hover highlight');
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });
}
