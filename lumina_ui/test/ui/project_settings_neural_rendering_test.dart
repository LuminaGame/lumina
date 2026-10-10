import 'dart:convert';
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_neural_rendering.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings/neural_rendering_warning_dialog.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Project Settings ▸ Engine & Graphics ▸ Neural rendering (experimental):
/// the OpenDLSS-NR opt-in behind its warning, the persisted acknowledgement,
/// the GPU gating and the weights check, on a real temporary `.lmproject`.
void main() {
  late Directory tempDir;
  late Directory projDir;
  late File manifest;
  FilamentEngine? vulkan;
  OpenDlssNrCapability? vulkanCapability;

  setUpAll(() {
    OpenDlssNr.requestDeviceFeatures();
    try {
      vulkan = FilamentEngine.create(backend: FilamentBackend.vulkan);
      if (vulkan != null) vulkanCapability = OpenDlssNr.capability(vulkan!);
    } catch (_) {
      vulkan = null;
    }
  });

  tearDownAll(() => vulkan?.dispose());

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_nr_settings_');
    projDir = Directory('${tempDir.path}/NrGame')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'NrGame', activeLevel: 'contents/levels/L_Main.lmas');
    manifest = File('${projDir.path}/NrGame.lmproject')..writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() {
    EditorNeuralRendering.capability.value = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<ProjectSettingsViewModel> open(WidgetTester tester) async {
    final vm = ProjectSettingsViewModel(projectDirPath: projDir.path);
    await tester.runAsync(vm.load);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: ProjectSettingsSubEditor(assetName: 'NrGame.lmproject', projectDirPath: projDir.path, viewModel: vm),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('project_settings_nav_${ProjectSettingsCategory.graphics}')));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('project_settings_neural_rendering_enabled'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    return vm;
  }

  Checkbox checkbox(WidgetTester tester) =>
      tester.widget<Checkbox>(find.byKey(const ValueKey('project_settings_neural_rendering_enabled')));

  bool requireCapable() {
    if (vulkanCapability?.supported != true) {
      markTestSkipped('needs a GPU that runs OpenDLSS-NR (${vulkanCapability?.reason ?? 'no Vulkan engine'})');
      return false;
    }
    EditorNeuralRendering.capability.value = vulkanCapability;
    return true;
  }

  testWidgets('an unsupported engine disables the checkbox and says why', (tester) async {
    final noop = FilamentEngine.create(backend: FilamentBackend.noop)!;
    addTearDown(noop.dispose);
    EditorNeuralRendering.capability.value = OpenDlssNr.capability(noop);
    await open(tester);
    expect(checkbox(tester).onChanged, isNull);
    expect(find.textContaining('Vulkan'), findsWidgets);
    expect(find.byKey(const ValueKey('project_settings_neural_rendering_unavailable')), findsOneWidget);
  });

  testWidgets('Cancel in the warning leaves it off and the manifest unchanged', (tester) async {
    if (!requireCapable()) return;
    final before = manifest.readAsStringSync();
    final vm = await open(tester);
    await tester.tap(find.byKey(const ValueKey('project_settings_neural_rendering_enabled')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('neural_rendering_warning_dialog')), findsOneWidget);
    for (final statement in kNeuralRenderingWarningStatements) {
      expect(find.text(statement), findsOneWidget);
    }
    expect(find.text(OpenDlssNr.upstreamUrl), findsOneWidget);
    expect(find.text('I understand, enable'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('neural_rendering_warning_cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('neural_rendering_warning_dialog')), findsNothing);
    expect(vm.neuralRendering.enabled, isFalse);
    expect(checkbox(tester).state, CheckboxState.unchecked);
    expect(vm.isDirty, isFalse);
    expect(manifest.readAsStringSync(), before);
  });

  testWidgets('accepting enables it, records the acknowledgement and Apply persists both', (tester) async {
    if (!requireCapable()) return;
    final vm = await open(tester);
    await tester.tap(find.byKey(const ValueKey('project_settings_neural_rendering_enabled')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('neural_rendering_warning_accept')));
    await tester.pumpAndSettle();
    expect(vm.neuralRendering.enabled, isTrue);
    expect(vm.neuralRendering.acknowledged, isTrue);
    expect(checkbox(tester).state, CheckboxState.checked);
    // no weights yet: the section says so plainly
    expect(find.textContaining('No weights set'), findsOneWidget);
    expect(await tester.runAsync(vm.apply), isTrue);
    final saved = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
    final nr = saved['neural_rendering'] as Map<String, dynamic>;
    expect(nr['enabled'], isTrue);
    expect(nr['acknowledged_at'], isNotEmpty);
    expect(nr['weights_path'], '');

    final reopened = ProjectSettingsViewModel(projectDirPath: projDir.path);
    await tester.runAsync(reopened.load);
    expect(reopened.neuralRendering.active, isTrue);
    reopened.dispose();
  });

  testWidgets('the weights path is checked: wrong size is invalid, the right layout is valid', (tester) async {
    final vm = ProjectSettingsViewModel(projectDirPath: projDir.path);
    await tester.runAsync(vm.load);
    expect(vm.neuralRenderingWeightsState, NeuralRenderingWeightsState.missing);

    final bad = '${tempDir.path}/bad_weights';
    final good = '${tempDir.path}/good_weights';
    await tester.runAsync(() async {
      OpenDlssNr.writeSyntheticModel(bad);
      OpenDlssNr.writeSyntheticModel(good);
      final stage = File('$bad/model/stage2.bin');
      final bytes = await stage.readAsBytes();
      await stage.writeAsBytes(bytes.sublist(0, bytes.length - 8));
    });

    await tester.runAsync(() async {
      vm.setNeuralRenderingWeightsPath('$bad/manifest.json');
      await vm.checkNeuralRenderingWeights();
    });
    expect(vm.neuralRenderingWeightsState, NeuralRenderingWeightsState.invalid);
    expect(vm.neuralRenderingWeightsMessage, contains('stage2'));

    await tester.runAsync(() async {
      vm.setNeuralRenderingWeightsPath(good);
      await vm.checkNeuralRenderingWeights();
    });
    expect(vm.neuralRenderingWeightsState, NeuralRenderingWeightsState.valid);
    expect(vm.neuralRenderingWeightsMessage, contains('71 blocks'));

    await tester.runAsync(() async {
      vm.setNeuralRenderingWeightsPath('');
      await vm.checkNeuralRenderingWeights();
    });
    expect(vm.neuralRenderingWeightsState, NeuralRenderingWeightsState.missing);
    vm.dispose();
  });
}
