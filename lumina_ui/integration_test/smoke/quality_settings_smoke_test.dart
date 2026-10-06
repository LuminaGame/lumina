import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart' show FilamentScene, FilamentView, QualityLevel;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/widgets/quality_settings_popover.dart';
import 'package:lumina_ui/ui/core/widgets/rtx_settings_popover.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The editor quality popover used to change nothing. This boots the
/// real editor on a real project with a real prop in it, drives the real
/// popover, and asserts the settings reached the live Filament view *and*
/// changed the pixels it produces.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const usedAssets = ['Props/Barrels/fuel_barrel_red.glb'];

  testWidgets('Quality Smoke: Low and Cinematic reach the Filament view and render differently', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_quality_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeQuality')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeQuality', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeQuality.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    try {
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      // A real prop, so the frame has edges that anti-aliasing and resolution
      // scaling visibly act on.
      final src = File('${SmokeArtifacts.testAssetsDir.path}/${usedAssets.first}');
      expect(src.existsSync(), isTrue, reason: 'seed asset must exist');
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: src.path));
      final imported = vm.realAssets.firstWhere((a) => a.fileName.startsWith('fuel_barrel_red'));
      await tester.runAsync(() => vm.spawnActorFromAsset(imported, location: [0.0, 0.0, 0.0]));

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
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      FilamentView? liveView() {
        final finder = find.byType(ViewportWidget);
        if (finder.evaluate().isEmpty) return null;
        final dynamic state = tester.state(finder);
        return state.nativeViewForTest as FilamentView?;
      }

      final view = liveView();
      final hasRenderer = view != null;
      if (!hasRenderer) {
        debugPrint('[quality_smoke] no live Filament view in this run; view assertions skipped');
      }

      Future<Uint8List> shot(String name) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
        return png;
      }

      /// Opens the toolbar's Quality popover.
      Future<void> openQuality() async {
        // The toolbar button (the status bar also reads "… Quality: EPIC …").
        await tester.tap(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('Quality: ')));
        await settle(10);
        await rec.hold(const Duration(milliseconds: 800));
      }

      Future<void> applyAndClose() async {
        await tester.tap(find.text('Apply & Close'));
        await settle(25);
      }

      // --- Low, at half resolution -----------------------------------------
      await openQuality();
      await tester.tap(find.byKey(const ValueKey('quality_preset_Low')));
      await settle(10);
      await rec.hold(const Duration(milliseconds: 800));
      // The Resolution Scale slider dragged all the way left: 50%.
      final slider = find.descendant(of: find.byType(QualitySettingsPopover), matching: find.byType(Slider));
      final sr = tester.getRect(slider);
      await rec.drag(sr.center, Offset(sr.left - 20, sr.center.dy), steps: 24);
      expect(vm.resolutionScale, 50);
      await rec.hold(const Duration(milliseconds: 600));
      await applyAndClose();
      expect(vm.qualityPreset, 'low');
      if (hasRenderer) {
        expect(view.dynamicResolutionOptions.enabled, isTrue, reason: 'half resolution is pinned on the view');
        expect(view.dynamicResolutionOptions.maxScaleX, closeTo(0.5, 1e-5));
        expect(view.renderQuality.hdrColorBuffer, QualityLevel.low);
      }
      await rec.hold(const Duration(seconds: 1));
      final lowPng = await shot('quality_settings_low_half_resolution');

      // --- Cinematic, at full resolution -----------------------------------
      await openQuality();
      await tester.tap(find.byKey(const ValueKey('quality_preset_Cin')));
      await settle(10);
      vm.updateResolutionScale(100);
      await settle(10);
      await rec.hold(const Duration(milliseconds: 800));
      await applyAndClose();
      if (hasRenderer) {
        expect(view.dynamicResolutionOptions.enabled, isFalse);
        expect(view.renderQuality.hdrColorBuffer, QualityLevel.ultra);
      }
      await rec.hold(const Duration(seconds: 1));
      final cinePng = await shot('quality_settings_cinematic');

      // The two frames must differ: this is the whole point of the bug.
      final a = img.decodePng(lowPng);
      final b = img.decodePng(cinePng);
      expect(a, isNotNull);
      expect(b, isNotNull);
      if (hasRenderer && a!.width == b!.width && a.height == b.height) {
        var changed = 0;
        for (var y = 0; y < a.height; y += 2) {
          for (var x = 0; x < a.width; x += 2) {
            if (a.getPixel(x, y) != b.getPixel(x, y)) changed++;
          }
        }
        debugPrint('[quality_smoke] $changed sampled pixels differ between Low@50% and Cinematic@100%');
        expect(changed, greaterThan(0), reason: 'the quality change must be visible, not just recorded');
      }

      // --- Feature toggles reach the view ----------------------------------
      expect(vm.ssaoEnabled, isTrue);
      await openQuality();
      await tester.tap(find.byKey(const ValueKey('quality_feature_ssao')));
      await settle(10);
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('quality_feature_bloom')));
      await settle(10);
      await rec.hold(const Duration(milliseconds: 600));
      await applyAndClose();
      if (hasRenderer) {
        expect(view.ambientOcclusionOptions.enabled, isFalse);
        expect(view.bloomOptions.enabled, isFalse);
      }
      await rec.hold(const Duration(seconds: 1));
      await shot('quality_settings_features_off');

      // --- It survives a reopen of the same project ------------------------
      await vm.flushQualitySettings();
      final reopened = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path, autoInitAssets: false);
      await tester.runAsync(reopened.loadQualitySettings);
      expect(reopened.qualityPreset, 'cinematic');
      expect(reopened.ssaoEnabled, isFalse);
      reopened.dispose();
      rec.save('Quality Smoke: Low and Cinematic reach the Filament view and render differently', usedAssets: usedAssets);
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });

  testWidgets('RTX Smoke: the viewport HUD toggles ray tracing and DLSS and their settings reach the view', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_rtx_hud_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeRtx')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeRtx', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeRtx.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    const name = 'RTX Smoke: the viewport HUD toggles ray tracing and DLSS and their settings reach the view';

    try {
      // As the editor does at startup: before the viewport creates the shared engine.
      final sourceRoot = LuminaWorkspace.findSourceRoot();
      final sdk = sourceRoot == null ? null : Directory('$sourceRoot/lumina/flutter_filament/build/dlss-sdk');
      LuminaRtxController.requestExtensions(dlssRuntimeDir: sdk != null && sdk.existsSync() ? sdk.path : null);
      final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      final src = File('${SmokeArtifacts.testAssetsDir.path}/${usedAssets.first}');
      expect(src.existsSync(), isTrue, reason: 'seed asset must exist');
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: src.path));
      final imported = vm.realAssets.firstWhere((a) => a.fileName.startsWith('fuel_barrel_red'));
      await tester.runAsync(() => vm.spawnActorFromAsset(imported, location: [0.0, 0.0, 0.0]));

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
          child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
        ),
      );

      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(40);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 2));

      final viewportFinder = find.byType(ViewportWidget);
      final dynamic viewportState = viewportFinder.evaluate().isEmpty ? null : tester.state(viewportFinder);
      final view = viewportState?.nativeViewForTest as FilamentView?;
      final scene = viewportState?.nativeSceneForTest as FilamentScene?;
      final rayTracingSupported = (viewportState?.rayTracingSupportedForTest as bool?) ?? false;
      debugPrint('[rtx_hud_smoke] live view: ${view != null}, ray tracing supported: $rayTracingSupported');

      Future<void> shot(String label) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($label)', png, usedAssets: usedAssets);
      }

      // Both HUD buttons sit next to the camera speed.
      expect(find.byKey(const ValueKey('hud_rtx_toggle')), findsOneWidget);
      expect(find.byKey(const ValueKey('hud_dlss_toggle')), findsOneWidget);
      await shot('hud off');

      // The arrow opens the ray tracing settings; ReSTIR is switched on there.
      await tester.tap(find.byKey(const ValueKey('hud_rtx_settings')));
      await settle(10);
      await rec.hold(const Duration(milliseconds: 800));
      expect(find.byType(RtxSettingsPopover), findsOneWidget);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('rtx_restir')), matching: find.byType(Switch)));
      await settle(5);
      await shot('rtx settings');
      await tester.tap(find.byKey(const ValueKey('rtx_popover_close')));
      await settle(10);
      expect(vm.rayTracingSettings.restir, isTrue);
      expect(vm.rayTracingSettings.enabled, isFalse, reason: 'the sub-choice does not switch ray tracing on');

      // The label toggles ray tracing itself.
      await tester.tap(find.byKey(const ValueKey('hud_rtx_toggle')));
      await settle(30);
      expect(vm.rayTracingSettings.enabled, isTrue);
      await rec.hold(const Duration(seconds: 3));
      await shot('rtx on');
      if (view != null && scene != null && rayTracingSupported) {
        expect(scene.rayTracingEnabled, isTrue, reason: 'the live scene keeps its acceleration structures');
        expect(view.restirOptions.enabled, isTrue, reason: 'ReSTIR reaches the live view');
      } else {
        debugPrint('[rtx_hud_smoke] no ray query on this engine: the choice is stored, the view keeps the froxel path');
        if (view != null) expect(view.restirOptions.enabled, isFalse);
      }

      // DLSS: the quality mode from its popover, then the toggle.
      await tester.tap(find.byKey(const ValueKey('hud_dlss_settings')));
      await settle(10);
      await tester.tap(find.byKey(const ValueKey('dlss_quality_maxQuality')));
      await settle(5);
      await shot('dlss settings');
      await tester.tap(find.byKey(const ValueKey('rtx_popover_close')));
      await settle(10);
      await tester.tap(find.byKey(const ValueKey('hud_dlss_toggle')));
      await settle(30);
      expect(vm.dlssSettings.enabled, isTrue);
      expect(vm.dlssSettings.quality.name, 'maxQuality');
      await rec.hold(const Duration(seconds: 3));
      await shot('dlss on');
      if (view != null && LuminaRtxController.dlssAvailable) {
        expect(view.dynamicResolutionOptions.enabled, isTrue, reason: 'DLSS pins the render resolution on the live view');
        expect(view.temporalAntiAliasingOptions.motionVectors, isTrue);
      }

      // Off again: the view returns to the profile's own options.
      await tester.tap(find.byKey(const ValueKey('hud_dlss_toggle')));
      await tester.tap(find.byKey(const ValueKey('hud_rtx_toggle')));
      await settle(30);
      expect(vm.dlssSettings.enabled, isFalse);
      expect(vm.rayTracingSettings.enabled, isFalse);
      if (view != null) {
        expect(view.restirOptions.enabled, isFalse);
        expect(view.dynamicResolutionOptions.enabled, vm.quality.profile.dynamicResolution.enabled);
      }
      await rec.hold(const Duration(seconds: 2));

      await vm.flushQualitySettings();
      final reopened = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path, autoInitAssets: false);
      await tester.runAsync(reopened.loadQualitySettings);
      expect(reopened.rayTracingSettings.restir, isTrue, reason: 'the per-user choice survives a reopen');
      expect(reopened.dlssSettings.quality.name, 'maxQuality');
      reopened.dispose();
      rec.save(name, usedAssets: usedAssets);
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });
}
