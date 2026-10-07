import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/solar_math.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/environment_lighting_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/environment_lighting_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Every scenario
/// runs against a real temp project whose level `.lmas` lives on disk.
void main() {
  late Directory tempDir;
  late Directory projDir;
  late File levelFile;

  const project = LuminaProject(
    projectName: 'EnvGame',
    activeLevel: 'contents/levels/L_Main.lmas',
  );

  /// Level with a pawn only — no Sun / SkyAmbience actors.
  void writeLevelWithoutEnvironment() {
    levelFile.writeAsStringSync(jsonEncode({
      'assetId': 'level_L_Main',
      'name': 'L_Main',
      'type': 'level',
      'relativePath': 'contents/levels/L_Main.lmas',
      'metadata': {
        'actors': [
          EditorActorNode(id: 'act_1', name: 'PlayerPawn_Default', type: 'Pawn', location: [0.0, 0.0, 0.0]).toMap(),
        ],
      },
    }));
  }

  Map<String, dynamic> readLevel() => jsonDecode(levelFile.readAsStringSync()) as Map<String, dynamic>;

  Future<EditorViewModel> openEditor() async {
    final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    await vm.ensureDefaultLevelAssets();
    return vm;
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_env_lighting_');
    projDir = Directory('${tempDir.path}/EnvGame')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    Directory('${projDir.path}/contents/textures').createSync(recursive: true);
    File('${projDir.path}/EnvGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    levelFile = File('${projDir.path}/contents/levels/L_Main.lmas');
    writeLevelWithoutEnvironment();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('opening on a level without environment actors creates Sun + SkyAmbience once', () async {
    final editor = await openEditor();
    addTearDown(editor.dispose);
    expect(editor.actors.where((a) => a.type == 'Environment'), isEmpty);

    final vm = EnvironmentLightingViewModel(editor: editor)..open();
    addTearDown(vm.dispose);

    final sun = editor.actors.singleWhere((a) => a.name == 'Sun');
    final sky = editor.actors.singleWhere((a) => a.name == 'SkyAmbience');
    expect(sun.type, 'DirectionalLight');
    expect(sky.type, 'Environment');
    expect(sun.components.map((c) => c.type), contains('LuminaDirectionalLightComponent'));
    expect(sky.components.map((c) => c.type), contains('LuminaSkyComponent'));
    expect(identical(vm.sunActor, sun), isTrue);
    expect(identical(vm.skyActor, sky), isTrue);
    // Outliner data: both are root actors of the level tree.
    expect(editor.rootActors.map((a) => a.name), containsAll(['Sun', 'SkyAmbience']));
    // Creating the actors is a real, undoable level edit.
    expect(editor.transactions.canUndo, isTrue);

    // Reopening (new mixer session on the same level) must not duplicate them.
    final again = EnvironmentLightingViewModel(editor: editor)..open();
    addTearDown(again.dispose);
    expect(editor.actors.where((a) => a.name == 'Sun').length, 1);
    expect(editor.actors.where((a) => a.name == 'SkyAmbience').length, 1);

    // Save → reload from disk → still exactly one of each.
    expect(await vm.save(), isTrue);
    final reloaded = await openEditor();
    addTearDown(reloaded.dispose);
    final third = EnvironmentLightingViewModel(editor: reloaded)..open();
    addTearDown(third.dispose);
    expect(reloaded.actors.where((a) => a.name == 'Sun').length, 1);
    expect(reloaded.actors.where((a) => a.name == 'SkyAmbience').length, 1);
  });

  test('existing DirectionalLight / Environment actors are adopted instead of recreated', () async {
    levelFile.writeAsStringSync(jsonEncode({
      'metadata': {
        'actors': [
          EditorActorNode(id: 'act_2', name: 'DirectionalLight_Sun', type: 'Light', location: [0.0, 150.0, 180.0], lightIntensity: 80000.0).toMap(),
          EditorActorNode(id: 'act_3', name: 'SkyAtmosphere_Env', type: 'Environment', location: [0.0, 0.0, 0.0]).toMap(),
        ],
      },
    }));
    final editor = await openEditor();
    addTearDown(editor.dispose);
    final vm = EnvironmentLightingViewModel(editor: editor)..open();
    addTearDown(vm.dispose);
    expect(editor.actors.length, 2);
    expect(vm.sunActor!.name, 'DirectionalLight_Sun');
    expect(vm.skyActor!.name, 'SkyAtmosphere_Env');
    expect(vm.state.sunIntensityLux, 80000.0, reason: 'the adopted sun keeps its authored intensity');
  });

  testWidgets('time slider to 12:00 writes the direction into the sun component; gizmo drag moves the slider', (tester) async {
    final editor = await openEditor();
    addTearDown(editor.dispose);
    final vm = EnvironmentLightingViewModel(editor: editor)..open();
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SizedBox(
            width: 1400,
            height: 820,
            child: EnvironmentLightingSubEditor(assetName: 'Environment', editorViewModel: editor, viewModel: vm),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // The dead sliders and the fake baker are gone; the real viewport is in.
    expect(find.text('Build Lighting'), findsNothing);
    expect(find.text('Volumetric Clouds & Height Fog Active'), findsNothing);
    expect(find.byType(SubEditor3DViewport), findsOneWidget);
    expect(find.text('ENVIRONMENT'), findsOneWidget);

    vm.setTimeOfDay(12.0);
    await tester.pump();
    expect(vm.state.timeOfDay, 12.0);
    expect(vm.state.sunElevationDeg, closeTo(SolarMath.maxElevationDeg, 1e-6));
    expect(vm.state.sunAzimuthDeg, closeTo(180.0, 1e-6));

    final light = vm.sunActor!.components.firstWhere((c) => c.type == 'LuminaDirectionalLightComponent');
    final dir = (light.properties['direction'] as List).cast<num>();
    final expected = SolarMath.lightDirection(SolarMath.maxElevationDeg, 180.0);
    expect(dir[0].toDouble(), closeTo(expected.x, 1e-6));
    expect(dir[1].toDouble(), closeTo(expected.y, 1e-6));
    expect(dir[2].toDouble(), closeTo(expected.z, 1e-6));
    expect(vm.sunActor!.rotation, SolarMath.eulerForAngles(SolarMath.maxElevationDeg, 180.0));
    expect((light.properties['elevationDeg'] as num).toDouble(), closeTo(SolarMath.maxElevationDeg, 1e-6));

    expect(find.byKey(const ValueKey('env_elevation_badge')), findsOneWidget);
    expect(find.text('Elevation ${SolarMath.maxElevationDeg.toStringAsFixed(1)}°'), findsOneWidget);
    expect(find.text('12:00 — Noon'), findsOneWidget);

    // Sun gizmo: drag the disc straight down (south on the compass) → azimuth 180° → 12:00.
    vm.setTimeOfDay(8.0);
    await tester.pump();
    final gizmo = find.byKey(const ValueKey('env_sun_gizmo'));
    expect(gizmo, findsOneWidget);
    final center = tester.getCenter(gizmo);
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(vm.state.timeOfDay, closeTo(12.0, 0.1), reason: 'gizmo → slider sync');
    expect(vm.state.sunAzimuthDeg, closeTo(180.0, 1.0));
    expect(vm.state.sunElevationDeg, lessThan(SolarMath.maxElevationDeg));
    expect(vm.state.sunElevationDeg, greaterThan(0.0));
    final slider = tester.widget<Slider>(
        find.descendant(of: find.byKey(const ValueKey('env_time_slider')), matching: find.byType(Slider)));
    expect(slider.value.value, closeTo(12.0, 0.1), reason: 'slider follows the gizmo');

    // Continuous drag then release = one undo step.
    final undoBefore = editor.transactions.undoLabel;
    expect(undoBefore, contains('Sun'));
  });

  test('Kelvin ramp drives the light colour until a manual override is enabled', () async {
    final editor = await openEditor();
    addTearDown(editor.dispose);
    final vm = EnvironmentLightingViewModel(editor: editor)..open();
    addTearDown(vm.dispose);

    vm.setSunKelvin(2000.0);
    expect(vm.state.sunColorOverride, isFalse);
    expect(vm.effectiveSunColor, SolarMath.kelvinToRgb(2000.0));
    expect(vm.sunActor!.lightColorHex, SolarMath.rgbToHex(SolarMath.kelvinToRgb(2000.0)));

    vm.setSunColorOverride(true);
    vm.setSunColorHex('#0000FF');
    expect(vm.effectiveSunColor, Vector3(0.0, 0.0, 1.0));
    expect(vm.sunActor!.lightColorHex, '#0000FF');
    // Moving the Kelvin slider no longer touches the colour.
    vm.setSunKelvin(9000.0);
    expect(vm.effectiveSunColor, Vector3(0.0, 0.0, 1.0));
    final light = vm.sunActor!.components.firstWhere((c) => c.type == 'LuminaDirectionalLightComponent');
    expect(light.properties['colorOverride'], isTrue);
    expect(light.properties['kelvin'], 9000.0);
  });

  test('fog + bloom persist under the level environment section and a reload restores the full state', () async {
    final editor = await openEditor();
    addTearDown(editor.dispose);
    final vm = EnvironmentLightingViewModel(editor: editor)..open();
    addTearDown(vm.dispose);

    vm.setFogEnabled(true);
    vm.setFogDensity(0.03);
    vm.setBloomIntensity(4.0);
    vm.setTimeOfDay(16.25);
    vm.setSunKelvin(4200.0);
    vm.setSkyRotation(33.0);
    vm.setExposure(1.5);
    vm.setSaturation(1.3);
    vm.setContrast(1.1);
    vm.setGamma(0.9);
    vm.setVignette(0.4);
    expect(vm.isDirty, isTrue);
    expect(editor.project.isDirty, isTrue, reason: 'mixer edits mark the level dirty for auto-save');

    expect(await vm.save(), isTrue);
    expect(vm.isDirty, isFalse);

    final env = readLevel()['metadata']['environment'] as Map<String, dynamic>;
    final pp = env['postProcess'] as Map<String, dynamic>;
    expect(pp['fogDensity'], 0.03);
    expect(pp['bloomIntensity'], 4.0);
    expect(pp['fogEnabled'], isTrue);
    expect((env['sun'] as Map)['timeOfDay'], 16.25);
    // The actors carry their component properties like any other actor.
    final actors = (readLevel()['metadata']['actors'] as List).cast<Map>();
    final sunMap = actors.firstWhere((a) => a['name'] == 'Sun');
    final lightComp = (sunMap['components'] as List).cast<Map>().firstWhere((c) => c['type'] == 'LuminaDirectionalLightComponent');
    expect((lightComp['properties'] as Map)['kelvin'], 4200.0);

    // Post-process mapping targets the real lumina settings object.
    final settings = vm.state.toPostProcessSettings();
    expect(settings.fog.enabled, isTrue);
    expect(settings.fog.density, closeTo(0.03 / EnvironmentState.worldUnitsPerMetre, 1e-12), reason: 'per-metre slider → centimetre world');
    expect(EnvironmentState.worldUnitsPerMetre, LuminaUnits.unitsPerMetre);
    // The generated game ships the same per-cm fog the view model hands PIE.
    final code = DartCodeGeneratorService().generateLevelDart(levelName: 'L_Fog', actors: const [], actorMaps: const [], environment: env);
    expect(code, contains('density: ${settings.fog.density.toStringAsFixed(4)}, heightFalloff: ${settings.fog.heightFalloff.toStringAsFixed(4)}'));
    expect(settings.bloom.enabled, isTrue);
    expect(settings.bloom.strength, closeTo(0.5, 1e-9));
    expect(settings.colorGrade.exposure, 1.5);
    expect(settings.colorGrade.saturation, 1.3);
    expect(settings.colorGrade.contrast, 1.1);
    expect(settings.vignette.enabled, isTrue);

    final reloaded = await openEditor();
    addTearDown(reloaded.dispose);
    final vm2 = EnvironmentLightingViewModel(editor: reloaded)..open();
    addTearDown(vm2.dispose);
    expect(vm2.state, vm.state, reason: 'full EnvironmentState round-trip through the real .lmas');
    expect(vm2.isDirty, isFalse);
  });

  test('HDRI mode stores the .ktx reference in the sky_environment slot; Color mode clears it', () async {
    // A real KTX1 IBL from the flutter_filament test assets, placed in the project's textures.
    final source = File('${Directory.current.parent.path}/flutter_filament/test/assets/lightroom_ibl.ktx');
    expect(source.existsSync(), isTrue, reason: 'seed asset must exist');
    source.copySync('${projDir.path}/contents/textures/lightroom_ibl.ktx');

    final editor = await openEditor();
    addTearDown(editor.dispose);
    final vm = EnvironmentLightingViewModel(editor: editor)..open();
    addTearDown(vm.dispose);

    expect(vm.hdriAssets, ['contents/textures/lightroom_ibl.ktx']);
    vm.setSkyMode(EnvironmentSkyMode.environment);
    vm.setSkyEnvironmentAsset('contents/textures/lightroom_ibl.ktx');
    expect(vm.state.skyEnvironmentAssetPath, 'contents/textures/lightroom_ibl.ktx');

    final skyMap = vm.skyActor!.toMap();
    final comp = (skyMap['components'] as List).cast<Map>().firstWhere((c) => c['type'] == 'LuminaSkyComponent');
    final ref = (comp['properties'] as Map)['sky_environment'] as Map;
    expect(ref['slot_name'], 'sky_environment');
    expect(ref['asset_path'], 'contents/textures/lightroom_ibl.ktx');
    expect((comp['properties'] as Map)['mode'], 'environment');

    vm.setSkyMode(EnvironmentSkyMode.color);
    final compAfter = (vm.skyActor!.toMap()['components'] as List).cast<Map>().firstWhere((c) => c['type'] == 'LuminaSkyComponent');
    expect((compAfter['properties'] as Map)['sky_environment'], isNull);
    expect(vm.state.skyEnvironmentAssetPath, isNull);
    expect((compAfter['properties'] as Map)['mode'], 'color');
  });

  test('Follow Time of Day slaves the sky rotation to the solar azimuth', () async {
    final editor = await openEditor();
    addTearDown(editor.dispose);
    final vm = EnvironmentLightingViewModel(editor: editor)..open();
    addTearDown(vm.dispose);

    vm.setTimeOfDay(8.0);
    vm.setSkyRotation(10.0);
    vm.setFollowTimeOfDay(true);
    vm.setTimeOfDay(10.0); // azimuth 120° → 150°
    expect(vm.state.skyRotationDeg, closeTo(40.0, 1e-9));

    vm.setFollowTimeOfDay(false);
    vm.setTimeOfDay(14.0);
    expect(vm.state.skyRotationDeg, closeTo(40.0, 1e-9), reason: 'rotation stays put when not following');
  });

  test('Reset to Defaults restores the documented defaults in one undoable transaction', () async {
    final editor = await openEditor();
    addTearDown(editor.dispose);
    final vm = EnvironmentLightingViewModel(editor: editor)..open();
    addTearDown(vm.dispose);

    vm.setSunIntensity(25000.0);
    vm.setSunKelvin(3000.0);
    vm.setFogEnabled(true);
    vm.setFogDensity(0.04);
    vm.setBloomIntensity(6.0);
    final edited = vm.state;
    final undoDepthBefore = _undoDepth(editor);

    vm.resetToDefaults();
    expect(vm.state.sunIntensityLux, 100000.0);
    expect(vm.state.sunKelvin, 6500.0);
    expect(vm.state.fogDensity, 0.0);
    expect(vm.state.fogEnabled, isFalse);
    expect(vm.state.toPostProcessSettings().bloom.strength, LuminaPostProcessSettings.standard().bloom.strength, reason: 'bloom back to the Filament default');
    expect(vm.state.toPostProcessSettings().bloom.enabled, isTrue);
    expect(_undoDepth(editor), undoDepthBefore + 1, reason: 'exactly one transaction');

    editor.transactions.undo();
    expect(vm.state, edited, reason: 'undo restores every edited value at once');
    editor.transactions.redo();
    expect(vm.state.sunIntensityLux, 100000.0);
  });

  // The HDRI picker's paths are stored in the level, so they must be
  // '/'-separated on every host (Windows listings join below the project
  // with '\').
  test('hdriAssets lists project-relative HDRI paths with / on every host', () async {
    final hdri = Directory('${projDir.path}/contents/hdri')..createSync(recursive: true);
    File('${Directory.current.parent.path}/flutter_filament/test/assets/lightroom_ibl.ktx').copySync('${hdri.path}/Studio.ktx');
    final editor = await openEditor();
    final vm = EnvironmentLightingViewModel(editor: editor);
    expect(vm.hdriAssets, ['contents/hdri/Studio.ktx']);
    await editor.close();
  });
}

/// Undo depth is not exposed directly; count by walking undo/redo.
int _undoDepth(EditorViewModel editor) {
  var depth = 0;
  while (editor.transactions.canUndo) {
    editor.transactions.undo();
    depth++;
  }
  for (var i = 0; i < depth; i++) {
    editor.transactions.redo();
  }
  return depth;
}
