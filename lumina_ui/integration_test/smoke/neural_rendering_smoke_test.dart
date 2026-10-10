import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart' show OpenDlssNr;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_neural_rendering.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart' show ProjectSettingsCategory;
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/blueprint_test_project.dart';
import '../../test/helpers/pie_pointer_fixture.dart';

/// Neural rendering opt-in on the real editor and GPU 1: Project Settings ▸
/// Engine & Graphics ▸ Neural rendering, tick "Use OpenDLSS-NR", read and
/// accept the warning, point the weights at a model folder, Apply; the level
/// viewport (real props: fuel barrels, an AC unit) then runs the pass, and so
/// does Play-In-Editor. The weights are a synthetic model of the network's
/// layout written by the test (small random values, no trained weights), so
/// the image shows the pipeline running, not a trained network's look.
const _testName = 'Neural Rendering Smoke: OpenDLSS-NR opt-in with the warning, weights and the viewport running it';
const _barrel = 'Props/Barrels/fuel_barrel_red.glb';
const _acUnit = 'Props/AC_units/ac_unit_b_600x600.glb';
const _barrelMesh = 'contents/meshes/static/SM_FuelBarrel.glb';
const _acUnitMesh = 'contents/meshes/static/SM_AcUnit.glb';

LuminaBlueprintDocument _prop(String mesh) => LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
      LuminaBlueprintComponent(
          id: 'mesh', name: 'Mesh', type: 'LuminaStaticMeshComponent', parentId: 'root', properties: {'staticMeshAsset': mesh}),
    ]);

Map<String, dynamic> _placed(String id, String cls, List<double> at) => {
      'id': id,
      'name': id,
      'type': 'Blueprint',
      'blueprintClass': 'contents/blueprints/$cls.lmas',
      'location': at,
      'rotation': [0.0, 0.0, 0.0],
      'scale': [1.0, 1.0, 1.0],
    };

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(_testName, (tester) async {
    final assets = SmokeArtifacts.testAssetsDir.path;
    for (final rel in [_barrel, _acUnit]) {
      if (!File('$assets/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    // As the editor's entry point does: the device features before the engine.
    LuminaRtxController.requestExtensions(neuralRendering: true);
    final project = PiePointerProject.create(name: 'NeuralSmoke', extraActors: [
      _placed('BarrelLeft', 'BP_Barrel', [-180.0, -250.0, 0.0]),
      _placed('BarrelRight', 'BP_Barrel', [160.0, -150.0, 0.0]),
      _placed('AcUnit', 'BP_AcUnit', [0.0, 300.0, 0.0]),
    ]);
    addTearDown(project.dispose);
    for (final (from, to) in [(_barrel, _barrelMesh), (_acUnit, _acUnitMesh)]) {
      File('${project.dir}/$to')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(File('$assets/$from').readAsBytesSync());
    }
    writeBlueprint(project.dir, 'BP_Barrel', _prop(_barrelMesh));
    writeBlueprint(project.dir, 'BP_AcUnit', _prop(_acUnitMesh));
    final weights = '${project.root.path}/synthetic_weights';
    await tester.runAsync(() async => OpenDlssNr.writeSyntheticModel(weights, seed: 5, random: true));

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final vm = EditorViewModel(initialProject: project.manifest(), projectLocation: project.root.path, enableTimers: false);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
    ));
    Future<void> settle([int frames = 10]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    await settle(60);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<void> shot(String name) async => SmokeArtifacts.saveScreenshot(
        name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
    Future<void> film(int frames, {double orbit = 0}) async {
      for (var i = 0; i < frames; i++) {
        if (orbit != 0) vm.orbitCamera(orbit, 0);
        await settle(1);
        await rec.capture();
      }
    }

    expect(EditorNeuralRendering.capability.value?.supported, isTrue,
        reason: 'GPU 1 runs OpenDLSS-NR: ${EditorNeuralRendering.capability.value}');
    await film(45, orbit: 1.5);
    await shot('neural_rendering_viewport_off');

    // --- Project Settings > Engine & Graphics > Neural rendering --------------
    await tester.tap(find.text('Edit').first);
    await settle(10);
    await tester.tap(find.text('Project Settings...').last);
    await settle(20);
    expect(find.byType(ProjectSettingsSubEditor), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('project_settings_nav_${ProjectSettingsCategory.graphics}')));
    await settle(10);
    final checkbox = find.byKey(const ValueKey('project_settings_neural_rendering_enabled'));
    await tester.ensureVisible(checkbox);
    await settle(10);
    await film(30);
    await tester.tap(checkbox);
    await settle(10);
    expect(find.byKey(const ValueKey('neural_rendering_warning_dialog')), findsOneWidget);
    await film(90);
    await shot('neural_rendering_warning_dialog');
    await tester.tap(find.byKey(const ValueKey('neural_rendering_warning_accept')));
    await settle(10);
    await film(30);
    expect(find.textContaining('No weights set'), findsOneWidget, reason: 'weights missing is said plainly');
    await shot('neural_rendering_weights_missing');

    // The weights: the synthetic model's manifest.json.
    await rec.typeText(find.byKey(const ValueKey('project_settings_neural_rendering_weights')), '$weights/manifest.json');
    for (var i = 0; i < 200 && !find.textContaining('Valid:').evaluate().isNotEmpty; i++) {
      await settle(2);
    }
    expect(find.textContaining('Valid:'), findsOneWidget);
    await film(30);
    await tester.tap(find.byKey(const ValueKey('project_settings_apply')));
    await settle(20);
    await film(20);
    await shot('neural_rendering_settings_applied');

    // --- The level viewport runs it ------------------------------------------
    vm.selectTab(0);
    for (var i = 0; i < 300 && !EditorNeuralRendering.status.value.running; i++) {
      await settle(2);
    }
    expect(EditorNeuralRendering.status.value.running, isTrue, reason: '${EditorNeuralRendering.status.value}');
    await film(120, orbit: 1.5);
    await shot('neural_rendering_viewport_running');

    // --- Play-In-Editor renders through the same view -------------------------
    await tester.tap(find.byKey(const ValueKey('toolbar_play')));
    for (var i = 0; i < 100 && !vm.pieController.isPlaying; i++) {
      await settle(2);
    }
    expect(vm.pieController.isPlaying, isTrue, reason: 'blocked: ${vm.playBlockers} error: ${vm.pieController.lastError}');
    await film(90);
    expect(EditorNeuralRendering.status.value.running, isTrue, reason: 'still running in PIE');
    await shot('neural_rendering_pie_running');
    vm.stopSimulation();
    await settle(20);

    final video = rec.save(_testName);
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
    await tester.pumpWidget(const SizedBox());
    await settle(30);
  });
}
