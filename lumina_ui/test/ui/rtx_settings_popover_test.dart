import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/rtx_settings_popover.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_quality_settings.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/about_dialog.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// DLSS Ray Reconstruction and DLSS Frame Generation in the viewport's DLSS
/// popover, their per-user settings, and the NVIDIA attribution in About.
void main() {
  late Directory tempDir;
  late Directory projectsDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_rtx_popover_test_');
    projectsDir = Directory('${tempDir.path}/projects')..createSync(recursive: true);
    Directory('${projectsDir.path}/NeuralGame').createSync(recursive: true);
  });

  tearDown(() {
    LuminaRtxController.activeNvidiaFeatures.value = const <String>{};
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  EditorViewModel makeEditor() => EditorViewModel(
    initialProject: const LuminaProject(projectName: 'NeuralGame', activeLevel: 'contents/levels/L_Main.lmas'),
    projectLocation: projectsDir.path,
    enableTimers: false,
    autoInitAssets: false,
    qualityStore: EditorQualityStore(configDir: Directory('${tempDir.path}/config')),
  );

  Future<void> pumpPopover(WidgetTester tester, EditorViewModel vm, {required bool rr, required int maxFrames}) async {
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SizedBox(
            width: 420,
            height: 760,
            child: SingleChildScrollView(
              child: RtxSettingsPopover(
                viewModel: vm,
                kind: RtxSettingsKind.dlss,
                supported: true,
                rayReconstructionSupported: rr,
                maxDlssGeneratedFrames: maxFrames,
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Switch rrSwitch(WidgetTester tester) => tester.widget<Switch>(
    find.descendant(of: find.byKey(const ValueKey('dlss_ray_reconstruction')), matching: find.byType(Switch)),
  );

  test(
    'Ray Reconstruction and 3 generated frames round-trip through the per-user store; old entries load with both off',
    () async {
      final store = EditorQualityStore(configDir: Directory('${tempDir.path}/config'));
      const settings = EditorQualitySettings(
        rayTracing: LuminaRayTracingSettings(enabled: true, restir: true),
        dlss: LuminaDlssSettings(enabled: true, rayReconstruction: true),
        dlssFrameGeneration: LuminaDlssFrameGenerationSettings(generatedFrames: 3),
      );
      await store.save('/projects/NeuralGame', settings);
      final back = await store.load('/projects/NeuralGame');
      expect(back, settings);
      expect(back.dlss.rayReconstruction, isTrue);
      expect(back.dlssFrameGeneration.generatedFrames, 3);

      final old = EditorQualitySettings.fromMap({
        'preset': 'epic',
        'dlss': {'enabled': true, 'quality': 'balanced'},
      });
      expect(old.dlss.rayReconstruction, isFalse);
      expect(old.dlssFrameGeneration.enabled, isFalse);
    },
  );

  testWidgets('the Ray Reconstruction switch is disabled with a reason until ray tracing is on, then sets it', (
    tester,
  ) async {
    final vm = makeEditor();
    addTearDown(vm.dispose);
    await pumpPopover(tester, vm, rr: true, maxFrames: 1);
    expect(rrSwitch(tester).onChanged, isNull);
    expect(find.textContaining('Turn RTX ray tracing on first'), findsOneWidget);

    vm.toggleRayTracing();
    await tester.pump();
    expect(rrSwitch(tester).onChanged, isNotNull);
    expect(find.byKey(const ValueKey('dlss_ray_reconstruction_blocker')), findsNothing);
    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('dlss_ray_reconstruction')), matching: find.byType(Switch)),
    );
    await tester.pump();
    expect(vm.dlssSettings.rayReconstruction, isTrue);
    expect(vm.dlssSettings.enabled, isTrue, reason: 'Ray Reconstruction is a DLSS mode: it switches DLSS on');
    expect(find.text('DLSS RAY RECONSTRUCTION'), findsOneWidget);
  });

  testWidgets('without the NGX Ray Reconstruction runtime the switch says what is missing', (tester) async {
    final vm = makeEditor();
    addTearDown(vm.dispose);
    vm.toggleRayTracing();
    await pumpPopover(tester, vm, rr: false, maxFrames: 0);
    expect(rrSwitch(tester).onChanged, isNull);
    expect(find.textContaining('nvngx_dlssd'), findsOneWidget);
    expect(find.textContaining('nvngx_dlssg'), findsOneWidget);
    expect(find.byKey(const ValueKey('dlss_frame_generation_0')), findsOneWidget, reason: 'only Off is offered');
    expect(find.byKey(const ValueKey('dlss_frame_generation_1')), findsNothing);
  });

  testWidgets('frame generation offers Off and 2x to 6x when the GPU allows 5, and sets the view model', (
    tester,
  ) async {
    final vm = makeEditor();
    addTearDown(vm.dispose);
    await pumpPopover(tester, vm, rr: true, maxFrames: 5);
    for (final (n, label) in const [(0, 'Off'), (1, '2x'), (2, '3x'), (3, '4x'), (4, '5x'), (5, '6x')]) {
      expect(
        find.descendant(of: find.byKey(ValueKey('dlss_frame_generation_$n')), matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.byKey(const ValueKey('dlss_frame_generation_6')), findsNothing);
    expect(find.textContaining('composited by Flutter'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dlss_frame_generation_3')));
    await tester.pump();
    expect(vm.dlssFrameGenerationSettings.generatedFrames, 3);
    expect(vm.quality.dlssFrameGeneration.generatedFrames, 3);
    await tester.tap(find.byKey(const ValueKey('dlss_frame_generation_0')));
    await tester.pump();
    expect(vm.dlssFrameGenerationSettings.enabled, isFalse);
  });

  testWidgets('frame generation offers Off and 2x when the GPU allows 1', (tester) async {
    final vm = makeEditor();
    addTearDown(vm.dispose);
    await pumpPopover(tester, vm, rr: true, maxFrames: 1);
    expect(find.byKey(const ValueKey('dlss_frame_generation_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('dlss_frame_generation_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('dlss_frame_generation_2')), findsNothing);
  });

  testWidgets('About shows the NVIDIA attribution only while an NGX feature runs', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: AboutLuminaDialog(engineVersion: '0.0.1', onClose: () {}),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('about_nvidia_attribution')), findsNothing);

    LuminaRtxController.activeNvidiaFeatures.value = {
      LuminaRtxController.nvidiaDlssFrameGeneration,
      LuminaRtxController.nvidiaDlssRayReconstruction,
    };
    await tester.pump();
    expect(find.byKey(const ValueKey('about_nvidia_attribution')), findsOneWidget);
    expect(find.text('NVIDIA DLSS Ray Reconstruction, DLSS Frame Generation: powered by NVIDIA DLSS'), findsOneWidget);

    LuminaRtxController.activeNvidiaFeatures.value = const <String>{};
    await tester.pump();
    expect(find.byKey(const ValueKey('about_nvidia_attribution')), findsNothing);
  });
}
