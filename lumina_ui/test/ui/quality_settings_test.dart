import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/widgets/quality_settings_popover.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_quality_settings.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The quality popover used to change nothing and named two features
/// Filament does not have. These tests pin what it now drives.
void main() {
  late Directory tempDir;
  late Directory projectsDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_quality_test_');
    projectsDir = Directory('${tempDir.path}/projects')..createSync(recursive: true);
    Directory('${projectsDir.path}/QualityGame').createSync(recursive: true);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  EditorViewModel makeEditor() {
    const project = LuminaProject(
      projectName: 'QualityGame',
      activeLevel: 'contents/levels/L_Main.lmas',
    );
    return EditorViewModel(
      initialProject: project,
      projectLocation: projectsDir.path,
      enableTimers: false,
      autoInitAssets: false,
      qualityStore: EditorQualityStore(configDir: Directory('${tempDir.path}/config')),
    );
  }

  group('EditorQualitySettings', () {
    test('the preset and resolution scale resolve to a real engine profile', () {
      const epic = EditorQualitySettings(preset: 'epic');
      expect(epic.profile.shadows.mapSize, LuminaScalabilityProfile.epic.shadows.mapSize);

      const low = EditorQualitySettings(preset: 'low');
      expect(low.profile.shadows.mapSize, lessThan(epic.profile.shadows.mapSize));

      const half = EditorQualitySettings(preset: 'epic', resolutionScale: 50);
      expect(half.profile.dynamicResolution.enabled, isTrue);
      expect(half.profile.dynamicResolution.minScaleX, closeTo(0.5, 1e-9));
    });

    test('feature toggles turn real Filament post-process options on and off', () {
      const all = EditorQualitySettings();
      final on = all.applyFeatures(LuminaPostProcessSettings.standard());
      expect(on.ambientOcclusion.enabled, isTrue);
      expect(on.bloom.enabled, isTrue);

      const none = EditorQualitySettings(ssao: false, bloom: false, screenSpaceReflections: false);
      final off = none.applyFeatures(LuminaPostProcessSettings.standard());
      expect(off.ambientOcclusion.enabled, isFalse);
      expect(off.bloom.enabled, isFalse);
      expect(off.screenSpaceReflections.enabled, isFalse);
    });

    test('round-trips through the per-user store, keyed by project directory', () async {
      final store = EditorQualityStore(configDir: Directory('${tempDir.path}/config'));
      const settings = EditorQualitySettings(
        preset: 'cinematic',
        resolutionScale: 75,
        ssao: false,
        bloom: true,
        screenSpaceReflections: false,
      );
      await store.save('/some/project/Alpha', settings);
      // Presets are stored the way the manifest spells them, lower case, so
      // the editor and Project Settings cannot disagree about 'Epic' vs 'epic'.
      await store.save('/some/project/Beta', const EditorQualitySettings(preset: 'Low'));

      expect(await store.load('/some/project/Alpha'), settings);
      expect((await store.load('/some/project/Beta')).preset, 'low');
      expect(await store.load('/never/saved'), const EditorQualitySettings(),
          reason: 'an unknown project gets the defaults, not an exception');

      // Real file on disk, readable as JSON.
      final file = File('${tempDir.path}/config/editor_quality.json');
      expect(file.existsSync(), isTrue);
      expect((jsonDecode(file.readAsStringSync()) as Map).keys, containsAll(['/some/project/Alpha', '/some/project/Beta']));
    });
  });

  group('EditorViewModel quality state', () {
    test('changing the preset moves the live profile, bumps the revision and persists', () async {
      final vm = makeEditor();
      addTearDown(vm.dispose);
      final before = vm.qualityRevision;
      expect(vm.quality.profile.shadows.mapSize, LuminaScalabilityProfile.epic.shadows.mapSize);

      vm.updateQualityPreset('low');
      expect(vm.qualityPreset, 'low');
      expect(vm.quality.profile.shadows.mapSize, LuminaScalabilityProfile.low.shadows.mapSize);
      expect(vm.qualityRevision, greaterThan(before), reason: 'the viewport reapplies on a revision change');
      expect(vm.project.settings.qualityPreset, 'low', reason: 'the project preset is still manifest-backed');

      await vm.flushQualitySettings();
      final reloaded = await EditorQualityStore(configDir: Directory('${tempDir.path}/config')).load(vm.projectDirPath);
      expect(reloaded.preset, 'low');
    });

    test('resolution scale and the feature toggles change the applied settings', () async {
      final vm = makeEditor();
      addTearDown(vm.dispose);

      vm.updateResolutionScale(50);
      expect(vm.resolutionScale, 50);
      expect(vm.quality.profile.dynamicResolution.enabled, isTrue);
      expect(vm.quality.profile.dynamicResolution.maxScaleX, closeTo(0.5, 1e-9));

      expect(vm.ssaoEnabled, isTrue);
      vm.toggleSsao();
      expect(vm.ssaoEnabled, isFalse);
      expect(vm.quality.applyFeatures(LuminaPostProcessSettings.standard()).ambientOcclusion.enabled, isFalse);

      vm.toggleBloom();
      expect(vm.bloomEnabled, isFalse);
      vm.toggleScreenSpaceReflections();
      expect(vm.screenSpaceReflectionsEnabled, isFalse);

      await vm.flushQualitySettings();
      final reloaded = await EditorQualityStore(configDir: Directory('${tempDir.path}/config')).load(vm.projectDirPath);
      expect(reloaded.resolutionScale, 50);
      expect(reloaded.ssao, isFalse);
    });

    test('quality settings load back when the editor reopens the same project', () async {
      final vm = makeEditor();
      addTearDown(vm.dispose);
      vm.updateQualityPreset('Cinematic');
      vm.updateResolutionScale(75);
      await vm.flushQualitySettings();

      final second = makeEditor();
      addTearDown(second.dispose);
      await second.loadQualitySettings();
      expect(second.qualityPreset, 'cinematic');
      expect(second.resolutionScale, 75);
    });
  });

  group('Quality popover', () {
    testWidgets('offers the five presets and only features this renderer has', (tester) async {
      final vm = makeEditor();
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: SizedBox(
              width: 420,
              height: 520,
              child: QualitySettingsPopover(viewModel: vm, onClose: () {}),
            ),
          ),
        ),
      );
      await tester.pump();

      for (final preset in ['Low', 'Med', 'Hig', 'Epi', 'Cin']) {
        expect(find.text(preset), findsOneWidget);
      }
      expect(find.text('Ray Tracing'), findsNothing, reason: 'Filament has no ray tracing');
      expect(find.text('Lumen'), findsNothing, reason: 'Filament has no Lumen');
      expect(find.text('SSAO'), findsOneWidget);
      expect(find.text('Bloom'), findsOneWidget);
      expect(find.text('SSR'), findsOneWidget);
      expect(find.text('VSync'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('quality_preset_Low')));
      await tester.pump();
      expect(vm.qualityPreset.toLowerCase(), 'low');

      await tester.tap(find.byKey(const ValueKey('quality_feature_ssao')));
      await tester.pump();
      expect(vm.ssaoEnabled, isFalse);
    });
  });
}
