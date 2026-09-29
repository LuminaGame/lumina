import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/navigation_editor_state.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/navigation_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/navigation_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Navigation editor smoke: boot the real editor on a
/// temp project seeded with real props from test-assets/ (a concrete slab
/// floor plus two obstacles), open Build → Build Navigation, add a bounds
/// volume through the real button, build the walkable grid with the real
/// `LuminaNavigationSystem`, enable the overlay, run an A* path test around
/// the obstacle (real viewport clicks + an explicit query), capture Filament
/// frames as PNG + WebM, Save, and assert the level `.lmas` on disk carries
/// the config, the volume actor and that the path really detours.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const usedAssets = [
    'structures/Concrete_slabs/concrete_slabs_9x9.glb',
    'Props/Barrels/fuel_barrel_red.glb',
    'Props/AC_units/ac_unit_a_300x300.glb',
  ];

  testWidgets('Navigation Smoke: bounds volume + real grid bake + A* path detours around a real prop', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_navigation_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeNavigation')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeNavigation', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeNavigation.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    final levelFile = File('${pDir.path}/contents/levels/L_Main.lmas');

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      // Real props through the real import pipeline, placed as level actors:
      // the slab is the floor, the barrel sits in the middle of the path, the
      // AC unit off to the side. Locations are stored like every level actor:
      // cm, Z up.
      final assetsDir = SmokeArtifacts.testAssetsDir;
      final placed = <String, EditorActorNode>{};
      final placements = <String, List<double>>{
        usedAssets[0]: [0.0, 0.0, 0.0],
        usedAssets[1]: [0.0, 0.0, 0.0],
        usedAssets[2]: [-250.0, -220.0, 0.0],
      };
      for (final entry in placements.entries) {
        final src = File('${assetsDir.path}/${entry.key}');
        expect(src.existsSync(), isTrue, reason: 'seed asset ${entry.key} must exist');
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: src.path));
        final base = entry.key.split('/').last.split('.').first;
        final imported = vm.realAssets.firstWhere((a) => a.fileName.startsWith(base));
        await tester.runAsync(() => vm.spawnActorFromAsset(imported, location: entry.value));
        placed[entry.key] = vm.actors.last;
      }
      expect(vm.actors.where((a) => a.meshData != null).length, greaterThanOrEqualTo(3));

      // The slab's top face is the walking surface: rest the obstacles on it
      // so the level reads like a real scene (floor + props on the floor).
      // The slab's collision box is in runtime axes (Y up), cm — its top is
      // the stored Z of the surface.
      final slab = placed[usedAssets[0]]!;
      final slabTopCm = NavigationWorldBuilder.obstaclesFrom([slab]).single.top;
      debugPrint('[navigation_editor_smoke] slab top: ${slabTopCm.toStringAsFixed(1)} cm');
      final barrel = placed[usedAssets[1]]!;
      final acUnit = placed[usedAssets[2]]!;
      barrel.location = [0.0, 0.0, slabTopCm];
      acUnit.location = [-250.0, -220.0, slabTopCm];
      final barrelBox = NavigationWorldBuilder.obstaclesFrom([barrel]).single;
      expect(barrelBox.top, greaterThan(slabTopCm + 30.0), reason: 'the barrel rises above the slab (runtime Y up, cm)');

      // A real editor-sized surface: the right panel's accordions must fit, or
      // the Build button lands outside the scroll viewport and stops hit-testing.
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
      await tester.pump(const Duration(milliseconds: 300));

      // Build → Build Navigation opens the Navigation workspace tab (nothing
      // to bake yet: no volume) — the real shell command.
      vm.commands.execute('build.buildNavigation');
      await tester.pump(const Duration(milliseconds: 300));
      expect(vm.openTabs.any((t) => t.category == 'navmesh'), isTrue);
      expect(find.byType(NavigationSubEditor), findsOneWidget);
      expect(find.text('Rebuild NavMesh'), findsNothing, reason: 'the mockup is gone');
      expect(find.text('NAV BOUNDS VOLUMES'), findsOneWidget);
      final navVm = _findVm(tester);
      expect(navVm.volumes, isEmpty);
      expect(navVm.canBuild, isFalse);
      expect(navVm.lastBuild, isNull, reason: 'no fabricated stats before a build');

      // Live binding: animations run on the real clock, so a pump loop alone
      // advances nothing. Each frame waits for real time to pass.
      Future<void> settle([int frames = 30]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      /// The right panel's `Accordion` sections render collapsed until they are
      /// opened; a collapsed section clips its content to zero height, so its
      /// controls exist but cannot be hit. Opens [title] when that is the case.
      Future<void> expandSection(String title, String probeKey) async {
        final probe = find.byKey(ValueKey(probeKey));
        if (probe.evaluate().isEmpty) return;
        final clip = find.ancestor(of: probe, matching: find.byType(ClipRect));
        if (clip.evaluate().isEmpty || tester.getRect(clip.first).height >= 2) return;
        await tester.tap(find.descendant(of: find.byType(AccordionTrigger), matching: find.text(title)).first);
        await settle(20);
      }

      await settle(40);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(milliseconds: 1500));
      final live = navVm.isPreviewAttached;
      if (!live) {
        // skip-degrade (manny_load_test pattern): no GPU renderer in this run.
        debugPrint('[navigation_editor_smoke] lumina preview world not attached; overlay checks skipped');
      }

      // Add a bounds volume through the real button; it lands centred on the
      // viewport pivot, so lift it onto the slab surface and cover the props.
      await tester.ensureVisible(find.byKey(const ValueKey('nav_add_volume')));
      await settle(10);
      await tester.tap(find.byKey(const ValueKey('nav_add_volume')));
      await settle(20);
      await rec.hold(const Duration(seconds: 1));
      expect(navVm.volumes.length, 1);
      final volume = navVm.volumes.single;
      expect(vm.actors.any((a) => a.id == volume.id && a.type == NavMeshBoundsVolume.actorType), isTrue, reason: 'real level actor');
      navVm.selectVolume(volume.id);
      // 12 × 12 m footprint along the stored X / Y (cm in, scale in metres),
      // bottom face on the slab top (stored Z up).
      navVm.setVolumeExtent(volume.id, 0, 1200.0);
      navVm.setVolumeExtent(volume.id, 1, 1200.0);
      navVm.setVolumeCenter(volume.id, 2, slabTopCm + NavMeshBoundsVolume.extentCmOf(volume)[2] / 2);
      await settle(20);
      expect(NavMeshBoundsVolume.aabb(volume).min.y, closeTo(slabTopCm, 1e-6), reason: 'grid floor = slab top');
      final beforeBuildPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('navigation_editor_volume_before_build', beforeBuildPng, usedAssets: usedAssets);
      await rec.hold(const Duration(milliseconds: 1500));

      // Cell size 25 cm for a readable grid, then the real bake.
      navVm.setCellSize(25.0);
      await expandSection('Build', 'nav_build');
      await tester.ensureVisible(find.byKey(const ValueKey('nav_build')));
      await settle(10);
      await tester.tap(find.byKey(const ValueKey('nav_build')));
      await settle(20);
      await rec.hold(const Duration(milliseconds: 1500));
      final build = navVm.lastBuild;
      expect(build, isNotNull);
      expect(build!.walkableCells, greaterThan(0));
      expect(build.obstacleCount, greaterThanOrEqualTo(2), reason: 'barrel + AC unit block; the slab is floor');
      expect(build.walkableCells, lessThan(build.cellCount), reason: 'the props carve blocked cells');
      expect(navVm.navigation!.isWalkable(Vector3(barrelBox.center.x, 0.0, barrelBox.center.z)), isFalse, reason: 'barrel footprint blocked');
      expect(find.textContaining('Walkable Cells: ${build.walkableCells}'), findsOneWidget);
      expect(find.textContaining('Grid: ${build.cols}×${build.rows}'), findsOneWidget);

      // Overlay on (it defaults on; toggle off/on through the real switch).
      await expandSection('Build', 'nav_overlay_switch');
      await tester.ensureVisible(find.byKey(const ValueKey('nav_overlay_switch')));
      await settle(10);
      await tester.tap(find.byKey(const ValueKey('nav_overlay_switch')));
      await settle(3);
      await rec.hold(const Duration(seconds: 1));
      expect(navVm.overlayVisible, isFalse);
      await expandSection('Build', 'nav_overlay_switch');
      await tester.ensureVisible(find.byKey(const ValueKey('nav_overlay_switch')));
      await settle(10);
      await tester.tap(find.byKey(const ValueKey('nav_overlay_switch')));
      await settle(3);
      await rec.hold(const Duration(seconds: 1));
      expect(navVm.overlayVisible, isTrue);

      // Path tester: real viewport clicks drop the start and goal flags.
      await expandSection('Build', 'nav_path_mode');
      await tester.ensureVisible(find.byKey(const ValueKey('nav_path_mode')));
      await settle(10);
      await tester.tap(find.byKey(const ValueKey('nav_path_mode')));
      await settle(2);
      expect(navVm.pathTesterMode, isTrue);
      final viewportRect = tester.getRect(find.byType(SubEditor3DViewport));
      final centre = viewportRect.center;
      await tester.tapAt(centre + const Offset(-160, 40));
      await settle(3);
      await rec.hold(const Duration(seconds: 1));
      expect(navVm.pathStart, isNotNull, reason: 'first click → Start flag');
      await tester.tapAt(centre + const Offset(160, 40));
      await settle(3);
      await rec.hold(const Duration(seconds: 1));
      expect(navVm.pathGoal, isNotNull, reason: 'second click → Goal flag');
      expect(navVm.pathResult, isNotNull);
      debugPrint('[navigation_editor_smoke] click path: ${navVm.pathDebugLine}');

      // Explicit query straight through the barrel: the real A* must detour.
      // Runtime axes, cm: 4 m either side of the barrel along X.
      final around = navVm.testPath(
        Vector3(-400.0, barrelBox.center.y, barrelBox.center.z),
        Vector3(400.0, barrelBox.center.y, barrelBox.center.z),
      );
      expect(around.state, NavPathState.found, reason: navVm.pathDebugLine);
      expect(around.path!.isPartial, isFalse);
      expect(around.path!.points.length, greaterThan(2), reason: 'a straight line would cross the barrel');
      final inflatedX = barrelBox.halfExtent.x + navVm.config.agentRadius;
      final inflatedZ = barrelBox.halfExtent.z + navVm.config.agentRadius;
      for (final p in around.path!.points) {
        final inside = (p.x - barrelBox.center.x).abs() < inflatedX && (p.z - barrelBox.center.z).abs() < inflatedZ;
        expect(inside, isFalse, reason: 'path point $p lies inside the inflated barrel footprint');
      }
      expect(around.queryTimeMs, greaterThan(0.0));
      await settle(10);
      expect(find.textContaining('Path: ${around.pointCount} points'), findsOneWidget);

      final overlayPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('navigation_editor_overlay_and_path', overlayPng, usedAssets: usedAssets);
      await rec.hold(const Duration(milliseconds: 1500));

      if (live) {
        expect(navVm.preview.meshActorCount, greaterThanOrEqualTo(3), reason: 'level meshes mounted through lumina');
        expect(navVm.preview.hasWalkableSection, isTrue, reason: 'walkable cells batched into one procedural-mesh section');
        expect(navVm.preview.walkableQuadCount, build.walkableCells);
        expect(navVm.preview.blockedQuadCount, build.cellCount - build.walkableCells);
        expect(navVm.preview.hasPathSection, isTrue, reason: 'blue path strip section');
        expect(navVm.preview.overlaySectionCount, greaterThanOrEqualTo(4), reason: 'cells + path + flags');
      }

      // Orbit the viewport with the right mouse button, on video.
      final gesture = await tester.startGesture(centre, buttons: kSecondaryMouseButton);
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(Offset(18, i.isEven ? 4 : -4));
        await rec.hold(const Duration(milliseconds: 400));
      }
      await gesture.up();

      // Save through the toolbar and verify the level file on disk.
      navVm.setAgentRadius(40.0);
      await tester.ensureVisible(find.byKey(const ValueKey('nav_save')));
      await settle(10);
      await tester.tap(find.byKey(const ValueKey('nav_save')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await settle(20);
      expect(navVm.isDirty, isFalse);
      await rec.hold(const Duration(milliseconds: 1500));
      rec.save('Navigation Smoke: bounds volume + real grid bake + A* path detours around a real prop', usedAssets: usedAssets);
      final raw = jsonDecode(levelFile.readAsStringSync()) as Map<String, dynamic>;
      final nav = (raw['metadata'] as Map)['navigation'] as Map;
      // Persisted in cm.
      expect((nav['config'] as Map)['cellSize'], 25.0);
      expect((nav['config'] as Map)['agentRadius'], 40.0);
      expect(((nav['volumes'] as List).cast<Map>()).single['id'], volume.id);
      final actors = ((raw['metadata'] as Map)['actors'] as List).cast<Map>();
      final volMap = actors.firstWhere((a) => a['id'] == volume.id);
      expect(volMap['type'], NavMeshBoundsVolume.actorType);
      expect((volMap['scale'] as List).first, 12.0, reason: '1200 cm → scale 12 (metres)');
      expect((volMap['scale'] as List)[1], 12.0);

      // Reload the level from disk: config + volume round-trip, a fresh build
      // yields the same grid.
      final reloaded = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path, enableTimers: false);
      await tester.runAsync(() => reloaded.ensureDefaultLevelAssets());
      final reopened = NavigationEditorViewModel(editor: reloaded)..open();
      expect(reopened.config, navVm.config);
      expect(reopened.volumes.single.id, volume.id);
      expect(reopened.lastBuild, isNotNull, reason: 'opening on a level with volumes rebuilds');
      expect(reopened.lastBuild!.cellCount, build.cellCount);
      expect(reopened.lastBuild!.cols, build.cols);
      reopened.dispose();
      reloaded.dispose();
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });
}

NavigationEditorViewModel _findVm(WidgetTester tester) {
  final state = tester.state(find.byType(NavigationSubEditor));
  // ignore: invalid_use_of_protected_member
  final dynamic s = state;
  return s.viewModelForTest as NavigationEditorViewModel;
}
