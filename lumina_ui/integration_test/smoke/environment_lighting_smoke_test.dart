import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/services/light_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/solar_math.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/environment_lighting_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/environment_lighting_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Environment Lighting smoke: boot the real editor
/// on a temp project seeded with real props from test-assets/, open Tools →
/// Environment Lighting, move time-of-day 08:00 → 16:00 (slider + sun gizmo),
/// raise the fog density, capture Filament frames as PNG + WebM, Save, and
/// assert the level `.lmas` on disk carries the edits.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const usedAssets = [
    'Props/AC_units/ac_unit_a_300x300.glb',
    'Props/Barrels/fuel_barrel_red.glb',
    'structures/Concrete_slabs/concrete_slabs_9x9.glb',
  ];

  testWidgets('Environment Lighting Smoke: time-of-day + fog drive the live sun and persist into the level', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_environment_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeEnvironment')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeEnvironment', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeEnvironment.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    final levelFile = File('${pDir.path}/contents/levels/L_Main.lmas');

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      // Real props from test-assets/ through the real import pipeline, then
      // placed as level actors so the mixer's viewport shows the open level.
      final assetsDir = SmokeArtifacts.testAssetsDir;
      final placements = <String, List<double>>{
        usedAssets[2]: [0.0, 0.0, 0.0],
        usedAssets[0]: [-180.0, 0.0, -40.0],
        usedAssets[1]: [160.0, 0.0, 60.0],
      };
      for (final entry in placements.entries) {
        final src = File('${assetsDir.path}/${entry.key}');
        expect(src.existsSync(), isTrue, reason: 'seed asset ${entry.key} must exist');
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: src.path));
        final base = entry.key.split('/').last.split('.').first;
        final imported = vm.realAssets.firstWhere((a) => a.fileName.startsWith(base));
        await tester.runAsync(() => vm.spawnActorFromAsset(imported, location: entry.value));
      }
      expect(vm.actors.where((a) => a.meshAssetPath != null).length, greaterThanOrEqualTo(3));

      final boundaryKey = GlobalKey();
      _pinView(tester);
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

      // Tools → Environment Lighting opens the mixer workspace tab.
      vm.commands.execute('tools.environmentLighting');
      await tester.pump(const Duration(milliseconds: 300));
      expect(vm.openTabs.any((t) => t.category == 'lighting'), isTrue);
      final editorFinder = find.byType(EnvironmentLightingSubEditor);
      expect(editorFinder, findsOneWidget);
      expect(find.text('Build Lighting'), findsNothing, reason: 'the fake baker is gone');
      final envVm = _findVm(tester);
      expect(envVm.sunActor, isNotNull);
      expect(envVm.skyActor, isNotNull);

      Future<void> settle([int frames = 30]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await settle(40);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));
      final live = envVm.isPreviewAttached;
      if (!live) {
        // skip-degrade (manny_load_test pattern): no GPU renderer in this run.
        debugPrint('[environment_lighting_smoke] lumina preview world not attached; pixel checks skipped');
      }

      // Morning: 08:00 through the real time slider.
      final slider = find.byKey(const ValueKey('env_time_slider'));
      expect(slider, findsOneWidget);
      envVm.setTimeOfDay(8.0);
      await settle(20);
      expect(envVm.state.timeOfDay, 8.0);
      expect(find.text('08:00 — Morning'), findsOneWidget);
      final morningPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('environment_lighting_morning_0800', morningPng, usedAssets: usedAssets);
      await rec.hold(const Duration(milliseconds: 800));

      // Sweep 08:00 → 16:00 in quarter hours: the sun crosses the sky on video.
      final viewportRect = tester.getRect(find.byType(SubEditor3DViewport));
      for (var h = 8.25; h <= 16.0; h += 0.25) {
        envVm.setTimeOfDay(h);
        await settle(2);
        await rec.hold(const Duration(milliseconds: 170));
      }

      // Sun gizmo drag (real pointer gesture) → slider follows.
      final gizmo = find.byKey(const ValueKey('env_sun_gizmo'));
      expect(gizmo, findsOneWidget);
      final gizmoCenter = tester.getCenter(gizmo);
      final gesture = await tester.startGesture(gizmoCenter);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(-4, 2));
        await tester.pump();
        await rec.hold(const Duration(milliseconds: 66));
      }
      await gesture.up();
      await settle(4);
      await rec.hold(const Duration(seconds: 1));
      final gizmoAngles = SolarMath.anglesForTime(envVm.state.timeOfDay);
      expect(envVm.state.sunAzimuthDeg, closeTo(gizmoAngles.azimuth, 1e-6), reason: 'slider ↔ gizmo in sync');
      expect(envVm.state.sunAzimuthDeg, closeTo(243.4, 2.0), reason: 'down-left on the compass (atan2(-40, -20)) is west-south-west');

      // Afternoon 16:00 with height fog.
      envVm.setTimeOfDay(16.0);
      envVm.setFogEnabled(true);
      envVm.setFogDensity(0.03);
      envVm.setSunKelvin(4000.0);
      await settle(20);
      expect(find.text('16:00 — Afternoon'), findsOneWidget);
      final afternoonPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('environment_lighting_afternoon_1600_fog', afternoonPng, usedAssets: usedAssets);
      await rec.hold(const Duration(seconds: 1));

      if (live) {
        expect(envVm.preview.sun, isNotNull, reason: 'real LuminaDirectionalLightComponent in the preview world');
        expect(envVm.preview.sky, isNotNull, reason: 'real LuminaSkyComponent in the preview world');
        expect(envVm.preview.meshActorCount, greaterThanOrEqualTo(3), reason: 'level meshes mounted through lumina');
        final applied = envVm.preview.world!.postProcess.applied;
        expect(applied.fog.enabled, isTrue);
        expect(applied.fog.density, closeTo(0.03 / EnvironmentState.worldUnitsPerMetre, 1e-12));
        // The two viewport frames must differ: sun moved + fog + warmer light.
        final diff = _viewportDifference(morningPng, afternoonPng, viewportRect);
        expect(diff, greaterThan(0.5), reason: 'live viewport reacts to the sun/fog edits (mean abs diff $diff)');
      }

      // Save through the toolbar and verify the level file on disk.
      await tester.tap(find.byKey(const ValueKey('env_save')));
      await settle(10);
      expect(envVm.isDirty, isFalse);
      await rec.hold(const Duration(seconds: 1));
      rec.save('Environment Lighting Smoke: time-of-day + fog drive the live sun and persist into the level', usedAssets: usedAssets);
      final raw = jsonDecode(levelFile.readAsStringSync()) as Map<String, dynamic>;
      final env = (raw['metadata'] as Map)['environment'] as Map;
      expect((env['postProcess'] as Map)['fogDensity'], 0.03);
      expect((env['postProcess'] as Map)['fogEnabled'], isTrue);
      expect((env['sun'] as Map)['timeOfDay'], 16.0);
      expect((env['sun'] as Map)['kelvin'], 4000.0);
      final actors = ((raw['metadata'] as Map)['actors'] as List).cast<Map>();
      final sun = actors.firstWhere((a) => a['id'] == envVm.sunActor!.id);
      final comps = (sun['components'] as List).cast<Map>();
      expect(comps.any((c) => c['type'] == 'LuminaDirectionalLightComponent'), isTrue);
      expect((sun['lightIntensity'] as num).toDouble(), envVm.state.sunIntensityLux);
      final sky = actors.firstWhere((a) => a['id'] == envVm.skyActor!.id);
      expect(((sky['components'] as List).cast<Map>()).any((c) => c['type'] == 'LuminaSkyComponent'), isTrue);

      // Reload the level from disk: the state round-trips.
      final reloaded = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path, enableTimers: false);
      await tester.runAsync(() => reloaded.ensureDefaultLevelAssets());
      final reopened = EnvironmentLightingViewModel(editor: reloaded)..open();
      expect(reopened.state, envVm.state);
      reopened.dispose();
      reloaded.dispose();
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });

  // The Procedural Sky & Ocean as placeable content.
  testWidgets('Procedural Sky Smoke: placing the actor renders an atmospheric sky that darkens as the day runs', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_procsky_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeProceduralSky')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeProceduralSky', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeProceduralSky.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    final levelFile = File('${pDir.path}/contents/levels/L_Main.lmas');

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      // Real props from test-assets/ so the sky is seen over a real level.
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final entry in <String, List<double>>{
        usedAssets[2]: [0.0, 0.0, 0.0],
        usedAssets[1]: [140.0, 0.0, 40.0],
      }.entries) {
        final src = File('${assetsDir.path}/${entry.key}');
        expect(src.existsSync(), isTrue, reason: 'seed asset ${entry.key} must exist');
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: src.path));
        final base = entry.key.split('/').last.split('.').first;
        final imported = vm.realAssets.firstWhere((a) => a.fileName.startsWith(base));
        await tester.runAsync(() => vm.spawnActorFromAsset(imported, location: entry.value));
      }

      // Place the sky through the real Place Actors path.
      vm.spawnNewActor('ProceduralSky');
      final skyActor = vm.actors.singleWhere((a) => a.type == 'ProceduralSky');
      final skyComponent = skyActor.components.singleWhere((c) => c.type == 'LuminaProceduralSkyComponent');

      final key = GlobalKey();
      _pinView(tester);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
        ),
      );
      await _settle(tester);

      // The Details panel edits the *selected* actor — `applyPropertyToSelection`
      // is a no-op on an empty selection — so select the sky exactly as clicking
      // it in the outliner would.
      final rec = SmokeRecorder(tester, boundary: find.byKey(key));
      await rec.hold(const Duration(seconds: 1));
      vm.clearSelection();
      vm.selectActors([skyActor.id]);
      await _settle(tester, frames: 12);
      await rec.hold(const Duration(milliseconds: 1500));

      // Sweep noon -> night through the Details-panel edit path and keep a
      // frame from each hour.
      final frames = <Uint8List>[];
      final skyLuma = <double>[];
      final viewportLuma = <double>[];
      for (var hour = 12; hour <= 23; hour++) {
        vm.updateComponentPropertyWithTransaction(
            skyActor.id, skyComponent.id, 'timeOfDay', hour.toDouble());
        await _settle(tester, frames: 30);
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(key));
        frames.add(png);
        skyLuma.add(_skyLuminance(png));
        viewportLuma.add(_viewportLuminance(png));
        await rec.hold(const Duration(milliseconds: 700));
        expect(skyComponent.properties['timeOfDay'], hour.toDouble(),
            reason: 'the Details edit must reach the actor');
      }

      // ignore: avoid_print
      print('MEASURE procedural_sky sky 12:00..23:00 = ${skyLuma.map((v) => v.toStringAsFixed(1)).join(', ')}');
      // ignore: avoid_print
      print('MEASURE procedural_sky viewport 12:00..23:00 = ${viewportLuma.map((v) => v.toStringAsFixed(1)).join(', ')}');

      SmokeArtifacts.saveScreenshot('procedural_sky_ocean_noon', frames.first, usedAssets: usedAssets);
      SmokeArtifacts.saveScreenshot('procedural_sky_ocean_night', frames.last, usedAssets: usedAssets);

      // A real atmosphere: bright at noon, black after sunset. Measured on
      // GPU 1, sky median 169.0 at 12:00 and 4.2 at 23:00; viewport median
      // 63.4 -> 15.1. Without the procedural sky — or with the Environment
      // actor's static skybox painted over it — this curve is flat.
      expect(skyLuma.first, greaterThan(120.0), reason: 'the midday sky must be bright');
      expect(skyLuma.last, lessThan(40.0), reason: 'the night sky must be dark');
      expect(viewportLuma.last, lessThan(viewportLuma.first * 0.5),
          reason: 'the whole scene must darken as the sun sets, not just the sky');

      // It persists: the authored hour, not the animated one, is what saves.
      vm.updateComponentPropertyWithTransaction(
          skyActor.id, skyComponent.id, 'cloudCoverage', 0.85);
      await tester.runAsync(() => vm.saveLevelAndGenerateCode());
      expect(levelFile.existsSync(), isTrue);
      final raw = jsonDecode(levelFile.readAsStringSync()) as Map<String, dynamic>;
      final savedActors = ((raw['metadata'] as Map)['actors'] as List).cast<Map>();
      final savedSky = savedActors.singleWhere((a) => a['type'] == 'ProceduralSky');
      final savedProps = ((savedSky['components'] as List).cast<Map>())
          .singleWhere((c) => c['type'] == 'LuminaProceduralSkyComponent')['properties'] as Map;
      expect(savedProps['timeOfDay'], 23.0);
      expect(savedProps['cloudCoverage'], 0.85);
      await rec.hold(const Duration(milliseconds: 1500));
      rec.save('Procedural Sky Smoke: placing the actor renders an atmospheric sky that darkens as the day runs', usedAssets: usedAssets);
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 8)));

  // The Exponential Height Fog as a placeable actor.
  testWidgets('Height Fog Smoke: scrubbing the placed fog actor\'s density fogs the level viewport and persists', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_heightfog_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeHeightFog')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeHeightFog', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeHeightFog.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    final levelFile = File('${pDir.path}/contents/levels/L_Main.lmas');

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      // Real props: a slab underfoot, a barrel near the camera, an AC unit far
      // down the level — the fog has distance to work with.
      final assetsDir = SmokeArtifacts.testAssetsDir;
      for (final entry in <String, List<double>>{
        usedAssets[2]: [0.0, 0.0, 0.0],
        usedAssets[1]: [0.0, -300.0, 0.0],
        usedAssets[0]: [0.0, 2500.0, 0.0],
      }.entries) {
        final src = File('${assetsDir.path}/${entry.key}');
        expect(src.existsSync(), isTrue, reason: 'seed asset ${entry.key} must exist');
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: src.path));
        final base = entry.key.split('/').last.split('.').first;
        final imported = vm.realAssets.firstWhere((a) => a.fileName.startsWith(base));
        await tester.runAsync(() => vm.spawnActorFromAsset(imported, location: entry.value));
      }

      // Place Actors → Visual Effects → Exponential Height Fog, then select it:
      // the Details panel edits the selection.
      vm.spawnNewActor('ExponentialHeightFog');
      final fogActor = vm.actors.singleWhere((a) => a.type == 'ExponentialHeightFog');
      final fogComponent = fogActor.components.singleWhere((c) => c.type == 'LuminaExponentialHeightFogComponent');
      vm.clearSelection();
      vm.selectActors([fogActor.id]);
      vm.updateActorLocation([0.0, 0.0, 0.0]);
      vm.updateComponentPropertyWithTransaction(fogActor.id, fogComponent.id, 'fogDensity', 0.0);
      vm.frameLevelBounds();

      final key = GlobalKey();
      _pinView(tester);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
        ),
      );
      await _settle(tester);
      expect(find.text('Fog Density'), findsWidgets, reason: 'the fog actor\'s Details rows are on screen');

      final rec = SmokeRecorder(tester, boundary: find.byKey(key));
      await rec.hold(const Duration(seconds: 1));
      Rect viewportRect() => tester.getRect(find.byType(ViewportWidget));
      final boundarySize = tester.getSize(find.byKey(key));
      final clearPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(key));
      SmokeArtifacts.saveScreenshot('height_fog_density_0', clearPng, usedAssets: usedAssets);

      // Scrub 0 → 0.08 /m on camera, the way the Details slider drags
      // (uncommitted steps, one commit at the end).
      const steps = 40;
      for (var i = 1; i <= steps; i++) {
        final d = 0.08 * i / steps;
        vm.updateComponentPropertyWithTransaction(fogActor.id, fogComponent.id, 'fogDensity', d, isCommit: i == steps);
        await _settle(tester, frames: 4);
        await rec.hold(const Duration(milliseconds: 260));
      }
      await _settle(tester, frames: 20);
      final foggedPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(key));
      SmokeArtifacts.saveScreenshot('height_fog_density_0_08', foggedPng, usedAssets: usedAssets);
      await rec.hold(const Duration(milliseconds: 1500));

      // The view the level renders got the actor's fog (per cm).
      final viewportState = tester.state(find.byType(ViewportWidget));
      final applied = (viewportState as dynamic).levelPostProcessForTest.appliedForTest as LuminaPostProcessSettings?;
      expect(applied, isNotNull, reason: 'the level viewport runs the environment post-process service');
      expect(applied!.fog.enabled, isTrue);
      expect(applied.fog.density, closeTo(0.0008, 1e-9));

      // The far half of the viewport (the level recedes towards the top)
      // moves toward the inscattering colour. The component hands Filament
      // #72A3FF as *linear* RGB (0.447, 0.638, 1.0), and the swap chain
      // encodes linear to sRGB, so on screen the fog is sRGB(0.447, 0.638,
      // 1.0) = (176, 208, 255). Measured on GPU 1: (100, 141, 192) at
      // density 0 → (184, 198, 213) at 0.08.
      final fogRgb = [for (final c in [0x72, 0xA3, 0xFF]) _linearToSrgb8(c / 255.0)];
      final crop = _relativeCrop(viewportRect(), boundarySize, top: 0.15, bottom: 0.55);
      final before = _medianRgb(clearPng, crop);
      final after = _medianRgb(foggedPng, crop);
      double distance(List<double> c) =>
          [for (var k = 0; k < 3; k++) (c[k] - fogRgb[k]) * (c[k] - fogRgb[k])].reduce((a, b) => a + b);
      // ignore: avoid_print
      print('MEASURE height_fog far-region median RGB density 0 = $before, density 0.08 = $after; '
          'distance² to the on-screen fog colour $fogRgb ${distance(before).toStringAsFixed(0)} -> ${distance(after).toStringAsFixed(0)}');
      expect(distance(after), lessThan(distance(before) * 0.8), reason: 'the fog pulls the far level toward its inscattering colour');

      // It persists.
      await tester.runAsync(() => vm.saveLevelAndGenerateCode());
      final raw = jsonDecode(levelFile.readAsStringSync()) as Map<String, dynamic>;
      final saved = ((raw['metadata'] as Map)['actors'] as List).cast<Map>().singleWhere((a) => a['type'] == 'ExponentialHeightFog');
      final savedProps = ((saved['components'] as List).cast<Map>())
          .singleWhere((c) => c['type'] == 'LuminaExponentialHeightFogComponent')['properties'] as Map;
      expect(savedProps['fogDensity'], closeTo(0.08, 1e-9));
      await rec.hold(const Duration(milliseconds: 1200));
      rec.save('Height Fog Smoke: scrubbing the placed fog actor\'s density fogs the level viewport and persists', usedAssets: usedAssets);
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 8)));

  // The Post Process Volume blends by the editor camera.
  testWidgets('Post Process Volume Smoke: flying the editor camera into a bloom volume blooms the view, out restores it', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_ppvolume_');
    final pDir = Directory('${tempProjectsDir.path}/SmokePpVolume')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokePpVolume', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokePpVolume.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    const ppAssets = [
      'Props/Barrels/fuel_barrel_yellow.glb',
      'Props/AC_units/ac_unit_a_300x300.glb',
      'structures/Concrete_slabs/concrete_slabs_9x9.glb',
    ];

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      final assetsDir = SmokeArtifacts.testAssetsDir;
      final placed = <String, EditorActorNode>{};
      for (final entry in <String, List<double>>{
        ppAssets[2]: [0.0, 0.0, 0.0],
        ppAssets[0]: [0.0, 0.0, 0.0],
        ppAssets[1]: [-250.0, 150.0, 0.0],
      }.entries) {
        final src = File('${assetsDir.path}/${entry.key}');
        expect(src.existsSync(), isTrue, reason: 'seed asset ${entry.key} must exist');
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: src.path));
        final base = entry.key.split('/').last.split('.').first;
        final imported = vm.realAssets.firstWhere((a) => a.fileName.startsWith(base));
        await tester.runAsync(() => vm.spawnActorFromAsset(imported, location: entry.value));
        placed[entry.key] = vm.actors.last;
      }
      final barrel = placed[ppAssets[0]]!;

      // Make the barrel bright: a hot point light beside it over-exposes its
      // side, and only highlights above 1.0 bloom (Filament's threshold).
      vm.spawnNewActor('PointLight');
      final lamp = vm.actors.last;
      vm.clearSelection();
      vm.selectActors([lamp.id]);
      vm.updateActorLocation([60.0, -70.0, 90.0]);
      final lampComponent = LightActorProperties.componentOf(lamp)!;
      vm.updateComponentPropertyWithTransaction(lamp.id, lampComponent.id, 'intensity', 4000000.0);
      vm.updateComponentPropertyWithTransaction(lamp.id, lampComponent.id, 'attenuationRadius', 600.0);

      // A bloom-6 volume around the barrel (Place Actors → Visual Effects).
      vm.spawnNewActor('PostProcessVolume');
      final volume = vm.actors.singleWhere((a) => a.type == 'PostProcessVolume');
      final component = volume.components.singleWhere((c) => c.type == 'LuminaPostProcessVolumeComponent');
      vm.clearSelection();
      vm.selectActors([volume.id]);
      vm.updateActorLocation([0.0, 0.0, 0.0]);
      vm.updateComponentPropertyWithTransaction(volume.id, component.id, 'overrideBloomIntensity', true);
      vm.updateComponentPropertyWithTransaction(volume.id, component.id, 'bloomIntensity', 6.0);

      final key = GlobalKey();
      _pinView(tester);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
        ),
      );
      // Look at the barrel from outside the volume (a 400 cm box, 100 cm blend).
      vm.focusCameraOnActor(barrel);
      vm.selectActors([volume.id]);
      final viewportState = tester.state(find.byType(ViewportWidget)) as dynamic;
      double eyeDistance() => vm.cameraDistance;
      Future<void> dollyTo(double target, SmokeRecorder rec, {int steps = 30}) async {
        final start = eyeDistance();
        for (var i = 1; i <= steps; i++) {
          final want = start + (target - start) * i / steps;
          vm.dollyCamera((want - eyeDistance()) / (0.8 * vm.cameraSpeedMultiplier));
          await _settle(tester, frames: 3);
          await rec.hold(const Duration(milliseconds: 100));
        }
      }

      final rec = SmokeRecorder(tester, boundary: find.byKey(key));
      await _settle(tester, frames: 60);
      await rec.hold(const Duration(seconds: 1));
      final boundarySize = tester.getSize(find.byKey(key));
      final crop = _relativeCrop(tester.getRect(find.byType(ViewportWidget)), boundarySize, top: 0.05, bottom: 0.95);
      double bloomOf() {
        final applied = viewportState.levelPostProcessForTest.appliedForTest as LuminaPostProcessSettings;
        return applied.bloom.enabled ? applied.bloom.strength : 0.0;
      }

      // What the volume adds at the camera's current position: the frame with
      // the volume against the same frame with the volume switched off (its
      // Enabled row, uncommitted). Comparing the camera inside with the camera
      // outside directly would mostly measure the composition (the barrel
      // fills the frame up close), not the bloom.
      Future<({double on, double off, double bloom, Uint8List png})> measure(String label) async {
        await _settle(tester, frames: 20);
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(key));
        final bloom = bloomOf();
        vm.updateComponentPropertyWithTransaction(volume.id, component.id, 'enabled', false, isCommit: false);
        await _settle(tester, frames: 20);
        final offPng = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(key));
        vm.updateComponentPropertyWithTransaction(volume.id, component.id, 'enabled', true, isCommit: false);
        await _settle(tester, frames: 10);
        final on = _meanLuminance(png, crop);
        final off = _meanLuminance(offPng, crop);
        // ignore: avoid_print
        print('MEASURE post_process_volume $label: camera distance ${eyeDistance().toStringAsFixed(0)} cm, '
            'bloom strength ${bloom.toStringAsFixed(3)}, viewport mean luminance ${on.toStringAsFixed(2)} '
            '(volume off: ${off.toStringAsFixed(2)}, added ${(on - off).toStringAsFixed(2)})');
        return (on: on, off: off, bloom: bloom, png: png);
      }

      const insideDistance = 250.0;
      const outsideDistance = 900.0;
      await dollyTo(outsideDistance, rec, steps: 10);
      final outStart = await measure('outside (start)');
      await rec.hold(const Duration(milliseconds: 800));

      await dollyTo(insideDistance, rec);
      final in1 = await measure('inside (pass 1)');
      SmokeArtifacts.saveScreenshot('post_process_volume_inside', in1.png, usedAssets: ppAssets);
      await rec.hold(const Duration(milliseconds: 1200));

      await dollyTo(outsideDistance, rec);
      final out1 = await measure('outside (pass 1)');
      SmokeArtifacts.saveScreenshot('post_process_volume_outside', out1.png, usedAssets: ppAssets);
      await rec.hold(const Duration(milliseconds: 1200));

      await dollyTo(insideDistance, rec);
      final in2 = await measure('inside (pass 2)');
      await rec.hold(const Duration(milliseconds: 1200));

      // The blender follows the editor camera: 6 of 8 inside, the baseline out.
      expect(in1.bloom, closeTo(0.75, 1e-9));
      expect(in2.bloom, closeTo(0.75, 1e-9));
      expect(out1.bloom, lessThan(0.75));
      expect(outStart.bloom, closeTo(out1.bloom, 1e-9), reason: 'leaving restores the baseline');
      // …and the picture shows it: inside, the volume brightens the view on
      // both passes; outside it adds nothing. Measured on GPU 1: +0.61 inside
      // on both passes (the glow around the lit barrel), ±0.01 outside —
      // capture noise. The glow is local, so the whole-viewport mean moves
      // less than a pixel value, but sixty times more than the noise.
      expect(in1.on - in1.off, greaterThan(0.3), reason: 'pass 1: the bloom volume brightens the view inside');
      expect(in2.on - in2.off, greaterThan(0.3), reason: 'pass 2: again inside');
      expect((out1.on - out1.off).abs(), lessThan(0.1), reason: 'outside the volume adds nothing');
      expect((outStart.on - outStart.off).abs(), lessThan(0.1));
      rec.save('Post Process Volume Smoke: flying the editor camera into a bloom volume blooms the view, out restores it', usedAssets: ppAssets);
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 8)));

  // The Local Fog Volume (a fog-shell approximation).
  testWidgets('Local Fog Volume Smoke: the fog shell tints its sphere from outside, and inside it thickens the global fog', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_localfog_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeLocalFog')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeLocalFog', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeLocalFog.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    const fogAssets = [
      'Props/Banana Bunch/banana_bunch_long.glb',
      'Props/Access_cards/access_card_blue.glb',
      'structures/Concrete_slabs/concrete_slabs_9x9.glb',
      'Props/AC_units/ac_unit_a_300x300.glb',
    ];

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      final assetsDir = SmokeArtifacts.testAssetsDir;
      final placed = <String, EditorActorNode>{};
      for (final entry in <String, List<double>>{
        fogAssets[2]: [0.0, 0.0, 0.0],
        fogAssets[0]: [0.0, 0.0, 20.0],
        fogAssets[1]: [120.0, -80.0, 20.0],
        fogAssets[3]: [0.0, 2400.0, 0.0],
      }.entries) {
        final src = File('${assetsDir.path}/${entry.key}');
        expect(src.existsSync(), isTrue, reason: 'seed asset ${entry.key} must exist');
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: src.path));
        final base = entry.key.split('/').last.split('.').first;
        final imported = vm.realAssets.firstWhere((a) => a.fileName.startsWith(base));
        await tester.runAsync(() => vm.spawnActorFromAsset(imported, location: entry.value));
        placed[entry.key] = vm.actors.last;
      }

      // A thin global fog for the volume to thicken (an Exponential Height Fog).
      vm.spawnNewActor('ExponentialHeightFog');
      final heightFog = vm.actors.singleWhere((a) => a.type == 'ExponentialHeightFog');
      vm.clearSelection();
      vm.selectActors([heightFog.id]);
      vm.updateActorLocation([0.0, 0.0, 0.0]);
      vm.updateComponentPropertyWithTransaction(heightFog.id, '${heightFog.id}_heightfog', 'fogDensity', 0.01);

      // The Local Fog Volume: a 300 cm sphere over the bananas, tinted pink so
      // the tint is measurable.
      vm.spawnNewActor('LocalFogVolume');
      final volume = vm.actors.singleWhere((a) => a.type == 'LocalFogVolume');
      final component = volume.components.singleWhere((c) => c.type == 'LuminaLocalFogVolumeComponent');
      vm.clearSelection();
      vm.selectActors([volume.id]);
      vm.updateActorLocation([0.0, 0.0, 100.0]);
      vm.updateComponentPropertyWithTransaction(volume.id, component.id, 'radius', 300.0);
      vm.updateComponentPropertyWithTransaction(volume.id, component.id, 'fogAlbedoHex', '#FF4DA6');
      vm.updateComponentPropertyWithTransaction(volume.id, component.id, 'fogDensity', 0.6);

      final key = GlobalKey();
      _pinView(tester);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
        ),
      );
      vm.focusCameraOnActor(volume);
      vm.clearSelection();
      final viewportState = tester.state(find.byType(ViewportWidget)) as dynamic;
      Future<void> dollyTo(double target, SmokeRecorder rec, {int steps = 30}) async {
        final start = vm.cameraDistance;
        for (var i = 1; i <= steps; i++) {
          final want = start + (target - start) * i / steps;
          vm.dollyCamera((want - vm.cameraDistance) / (0.8 * vm.cameraSpeedMultiplier));
          await _settle(tester, frames: 3);
          await rec.hold(const Duration(milliseconds: 100));
        }
      }

      final rec = SmokeRecorder(tester, boundary: find.byKey(key));
      await _settle(tester, frames: 60);
      await rec.hold(const Duration(seconds: 1));
      final boundarySize = tester.getSize(find.byKey(key));
      final viewportRect = tester.getRect(find.byType(ViewportWidget));
      final wholeCrop = _relativeCrop(viewportRect, boundarySize, top: 0.05, bottom: 0.95);
      double fogDensity() => (viewportState.levelPostProcessForTest.appliedForTest as LuminaPostProcessSettings).fog.density;

      // The frame with the volume against the same frame with it switched off
      // (its Enabled row, uncommitted): what the volume itself changes.
      Future<({Uint8List on, Uint8List off, double density, double offDensity})> abFrames(String label) async {
        await _settle(tester, frames: 20);
        final on = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(key));
        final density = fogDensity();
        vm.updateComponentPropertyWithTransaction(volume.id, component.id, 'enabled', false, isCommit: false);
        await _settle(tester, frames: 20);
        final off = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(key));
        final offDensity = fogDensity();
        vm.updateComponentPropertyWithTransaction(volume.id, component.id, 'enabled', true, isCommit: false);
        await _settle(tester, frames: 10);
        return (on: on, off: off, density: density, offDensity: offDensity);
      }

      // Pink pixels (red and blue above green: the albedo #FF4DA6's hue; the
      // level itself is grey-blue) in the viewport, volume on against off.
      // A median over a crop is the wrong tool here: the ball sits above the
      // orbit pivot and the pivot is covered by the actor labels.

      // Outside: the shell reads as a tinted ball.
      await dollyTo(1400.0, rec, steps: 10);
      final outside = await abFrames('outside');
      SmokeArtifacts.saveScreenshot('local_fog_volume_outside', outside.on, usedAssets: fogAssets);
      final pinkOutsideOn = _tintedFraction(outside.on, wholeCrop);
      final pinkOutsideOff = _tintedFraction(outside.off, wholeCrop);
      // ignore: avoid_print
      print('MEASURE local_fog outside: albedo-tinted share of the viewport ${(pinkOutsideOff * 100).toStringAsFixed(2)}% (volume off) -> '
          '${(pinkOutsideOn * 100).toStringAsFixed(2)}% (on); global fog density ${outside.density} (off ${outside.offDensity})');
      await rec.hold(const Duration(milliseconds: 1200));

      // Fly inside: the global fog thickens, the far AC unit washes out.
      await dollyTo(120.0, rec);
      final inside = await abFrames('inside');
      SmokeArtifacts.saveScreenshot('local_fog_volume_inside', inside.on, usedAssets: fogAssets);
      final contrastOn = _luminanceSpread(inside.on, wholeCrop);
      final contrastOff = _luminanceSpread(inside.off, wholeCrop);
      final pinkInsideOn = _tintedFraction(inside.on, wholeCrop);
      final pinkInsideOff = _tintedFraction(inside.off, wholeCrop);
      // ignore: avoid_print
      print('MEASURE local_fog inside: global fog density ${inside.density} (off ${inside.offDensity}); '
          'albedo-tinted share ${(pinkInsideOff * 100).toStringAsFixed(2)}% (off) -> ${(pinkInsideOn * 100).toStringAsFixed(2)}% (on); '
          'viewport luminance spread ${contrastOff.toStringAsFixed(2)} (off) -> ${contrastOn.toStringAsFixed(2)} (on)');
      await rec.hold(const Duration(milliseconds: 1200));

      // Fly out: restored.
      await dollyTo(1400.0, rec);
      await _settle(tester, frames: 20);
      final restored = fogDensity();
      // ignore: avoid_print
      print('MEASURE local_fog out again: global fog density $restored');
      await rec.hold(const Duration(milliseconds: 1500));

      // Measured on GPU 1: 0.00% → 1.98% outside (the ball is a few percent
      // of a 1400 cm view), 0.00% → 75.79% inside.
      expect(pinkOutsideOff, lessThan(0.002), reason: 'nothing in the level is pink by itself');
      expect(pinkOutsideOn, greaterThan(0.01), reason: 'from outside the shell reads as a tinted ball');
      expect(pinkInsideOn, greaterThan(0.5), reason: 'inside, the shell surrounds the camera');
      expect(inside.density, closeTo(inside.offDensity * (1 + 10 * 0.6), inside.offDensity * 1e-6),
          reason: 'inside, the global fog is scaled by 1 + 10·density');
      expect(outside.density, closeTo(outside.offDensity, outside.offDensity * 1e-6), reason: 'outside it is the baseline');
      expect(restored, closeTo(outside.offDensity, outside.offDensity * 1e-6), reason: 'leaving restores the fog');
      expect(contrastOn, lessThanOrEqualTo(contrastOff), reason: 'inside, the view does not gain contrast');

      // Persisted.
      await tester.runAsync(() => vm.saveLevelAndGenerateCode());
      final raw = jsonDecode(File('${pDir.path}/contents/levels/L_Main.lmas').readAsStringSync()) as Map<String, dynamic>;
      final saved = ((raw['metadata'] as Map)['actors'] as List).cast<Map>().singleWhere((a) => a['type'] == 'LocalFogVolume');
      final savedProps = ((saved['components'] as List).cast<Map>())
          .singleWhere((c) => c['type'] == 'LuminaLocalFogVolumeComponent')['properties'] as Map;
      expect(savedProps['fogAlbedoHex'], '#FF4DA6');
      expect(savedProps['enabled'], isTrue);
      rec.save('Local Fog Volume Smoke: the fog shell tints its sphere from outside, and inside it thickens the global fog', usedAssets: fogAssets);
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}

/// Standard deviation of luminance (0..255) over a relative crop of [png]: a
/// contrast measure.
double _luminanceSpread(Uint8List png, ({double x0, double x1, double y0, double y1}) crop) {
  final im = img.decodePng(png)!;
  final values = <double>[];
  for (var y = (im.height * crop.y0).round(); y < (im.height * crop.y1).round(); y += 2) {
    for (var x = (im.width * crop.x0).round(); x < (im.width * crop.x1).round(); x += 2) {
      final p = im.getPixel(x, y);
      values.add(0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b);
    }
  }
  if (values.isEmpty) return 0.0;
  final mean = values.reduce((a, b) => a + b) / values.length;
  final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
  return math.sqrt(variance);
}

/// Share of a relative crop of [png] tinted toward a pink albedo: red and
/// blue both clearly above green.
double _tintedFraction(Uint8List png, ({double x0, double x1, double y0, double y1}) crop) {
  final im = img.decodePng(png)!;
  var tinted = 0;
  var n = 0;
  for (var y = (im.height * crop.y0).round(); y < (im.height * crop.y1).round(); y += 2) {
    for (var x = (im.width * crop.x0).round(); x < (im.width * crop.x1).round(); x += 2) {
      final p = im.getPixel(x, y);
      if (p.r > p.g + 25 && p.b > p.g + 10) tinted++;
      n++;
    }
  }
  return n == 0 ? 0.0 : tinted / n;
}

/// Mean luminance (0..255) of a relative crop of [png].
double _meanLuminance(Uint8List png, ({double x0, double x1, double y0, double y1}) crop) {
  final im = img.decodePng(png)!;
  var sum = 0.0;
  var n = 0;
  for (var y = (im.height * crop.y0).round(); y < (im.height * crop.y1).round(); y += 2) {
    for (var x = (im.width * crop.x0).round(); x < (im.width * crop.x1).round(); x += 2) {
      final p = im.getPixel(x, y);
      sum += 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;
      n++;
    }
  }
  return n == 0 ? 0.0 : sum / n;
}

/// [viewport] (logical, inside a boundary of [boundary] size) as fractions of
/// the boundary, keeping its full width and the rows [top]..[bottom] of it.
({double x0, double x1, double y0, double y1}) _relativeCrop(Rect viewport, Size boundary, {double top = 0.0, double bottom = 1.0}) => (
      x0: (viewport.left + viewport.width * 0.1) / boundary.width,
      x1: (viewport.right - viewport.width * 0.1) / boundary.width,
      y0: (viewport.top + viewport.height * top) / boundary.height,
      y1: (viewport.top + viewport.height * bottom) / boundary.height,
    );

/// Per-channel median colour of a relative crop of [png] (medians ignore the
/// constant-brightness grid lines, labels and HUD drawn over the viewport).
List<double> _medianRgb(Uint8List png, ({double x0, double x1, double y0, double y1}) crop) {
  final im = img.decodePng(png)!;
  final r = <double>[], g = <double>[], b = <double>[];
  for (var y = (im.height * crop.y0).round(); y < (im.height * crop.y1).round(); y += 2) {
    for (var x = (im.width * crop.x0).round(); x < (im.width * crop.x1).round(); x += 2) {
      final p = im.getPixel(x, y);
      r.add(p.r.toDouble());
      g.add(p.g.toDouble());
      b.add(p.b.toDouble());
    }
  }
  double med(List<double> v) => v.isEmpty ? 0.0 : (v..sort())[v.length ~/ 2];
  return [med(r), med(g), med(b)];
}

/// A linear 0..1 channel as the 0..255 sRGB value the display shows.
double _linearToSrgb8(double c) =>
    255.0 * (c <= 0.0031308 ? 12.92 * c : 1.055 * math.pow(c, 1 / 2.4) - 0.055);

/// Settles the real clock in an integration test (animations run live).
Future<void> _settle(WidgetTester tester, {int frames = 90}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

/// Median luminance over a relative crop of [png].
///
/// Median, not mean: the editor grid's white lines, the actor name labels and
/// the amber Tris/FPS/CPU HUD are all drawn over the 3D viewport at a constant
/// brightness, and they put a floor under a mean that hides the very change
/// being measured (a mean bottoms out around 71/255 on a frame whose sky and
/// ocean are both black).
double _medianLuminance(Uint8List png, double x0, double x1, double y0, double y1) {
  final im = img.decodePng(png)!;
  final lum = <double>[];
  for (var y = (im.height * y0).round(); y < (im.height * y1).round(); y++) {
    for (var x = (im.width * x0).round(); x < (im.width * x1).round(); x++) {
      final p = im.getPixel(x, y);
      lum.add(0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b);
    }
  }
  if (lum.isEmpty) return 0.0;
  lum.sort();
  return lum[lum.length ~/ 2];
}

/// The sky itself: the band just above the horizon, between the viewport's two
/// HUD chips. The editor camera looks down 35 degrees, so this is thin.
double _skyLuminance(Uint8List png) => _medianLuminance(png, 0.36, 0.62, 0.212, 0.245);

/// The whole 3D viewport rectangle, which the procedural sky and its ocean fill
/// edge to edge — the scene darkens with the sky, not just the sky.
double _viewportLuminance(Uint8List png) => _medianLuminance(png, 0.20, 0.78, 0.23, 0.58);

EnvironmentLightingViewModel _findVm(WidgetTester tester) {
  final state = tester.state(find.byType(EnvironmentLightingSubEditor));
  // ignore: invalid_use_of_protected_member
  final dynamic s = state;
  return s.viewModelForTest as EnvironmentLightingViewModel;
}

/// Mean absolute per-channel difference (0–255) between two captures inside
/// the viewport rectangle (logical coordinates, scaled to the PNG size).
double _viewportDifference(Uint8List a, Uint8List b, Rect viewport) {
  final da = img.decodePng(a);
  final db = img.decodePng(b);
  if (da == null || db == null || da.width != db.width || da.height != db.height) return 0.0;
  final scaleX = da.width / (viewport.width == 0 ? 1 : viewport.right);
  final scaleY = da.height / (viewport.height == 0 ? 1 : viewport.bottom);
  final x0 = (viewport.left * scaleX).round().clamp(0, da.width - 1);
  final x1 = (viewport.right * scaleX).round().clamp(0, da.width);
  final y0 = (viewport.top * scaleY).round().clamp(0, da.height - 1);
  final y1 = (viewport.bottom * scaleY).round().clamp(0, da.height);
  var sum = 0.0;
  var n = 0;
  for (var y = y0; y < y1; y += 2) {
    for (var x = x0; x < x1; x += 2) {
      final pa = da.getPixel(x, y);
      final pb = db.getPixel(x, y);
      sum += (pa.r - pb.r).abs() + (pa.g - pb.g).abs() + (pa.b - pb.b).abs();
      n += 3;
    }
  }
  return n == 0 ? 0.0 : sum / n;
}

/// The thresholds above were measured with the editor at 1920×1080 (the Linux
/// runner's window). The Windows runner opens at 1280×720, where the viewport
/// is shorter and the sky band the measures read falls on the ocean: pin the
/// logical view like the content browser's asset type strip smoke does.
void _pinView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
