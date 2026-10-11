import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/build_manager_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/build_manager_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Records [condition]'s wait as a time-lapse: a frame whenever [progress]
/// moves, else one every 0.6 s.
Future<bool> _recordUntil(WidgetTester tester, SmokeRecorder rec, bool Function() condition,
    {required int Function() progress, required Duration budget}) async {
  final sw = Stopwatch()..start();
  var last = -1;
  var quiet = 0;
  while (sw.elapsed < budget && !condition()) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    final now = progress();
    if (now != last || ++quiet >= 3) {
      last = now;
      quiet = 0;
      await rec.captureIfChanged();
    }
  }
  return condition();
}

/// Android (Meta Quest) packaging smoke: a real project made by the
/// launcher pipeline with the OpenXR and MetaXR plugins enabled (their
/// checkouts linked as project plugins), Project Settings → Packaging →
/// Android with the Meta Quest profile and the composed manifest preview,
/// then the Build Manager cooks it into a finished APK. Skipped without an
/// Android SDK or the plugins' checkouts.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android Quest Packaging Smoke: Quest profile, manifest preview and a cooked APK', (tester) async {
    const name = 'android_quest_packaging: quest profile to a cooked apk';
    final workspace = Directory.current.parent.parent.path;
    final pluginDirs = ['$workspace/openxr', '$workspace/metaxr'];
    if (pluginDirs.any((d) => !File('$d/${d.endsWith('openxr') ? 'lumina_plugin_openxr' : 'lumina_plugin_metaxr'}.lmplugin').existsSync())) {
      markTestSkipped('the OpenXR / MetaXR plugin checkouts are not next to the engine');
      return;
    }
    final tempProjectsDir = Directory.systemTemp.createTempSync('lq_smoke_');
    const projectName = 'quest_smoke';
    final projDir = '${tempProjectsDir.path}/$projectName'.replaceAll('\\', '/');
    LuminaConfigDir.override = Directory('${tempProjectsDir.path}/config')..createSync();
    ProjectSettingsViewModel? settings;
    BuildManagerViewModel? bm;
    try {
      final repo = ProjectRepository();
      await tester.runAsync(() async {
        await for (final p in repo.createProjectStream(projectName: projectName, projectLocation: tempProjectsDir.path)) {
          // ignore: avoid_print
          print('[create] ${p.message}');
        }
      });
      // The plugins as project plugins: links to their checkouts.
      Directory('$projDir/plugins').createSync(recursive: true);
      for (final dir in pluginDirs) {
        final plugin = dir.endsWith('openxr') ? 'lumina_plugin_openxr' : 'lumina_plugin_metaxr';
        DirectoryLink.createSync('$projDir/plugins/$plugin', dir);
      }
      var project = (await tester.runAsync(() => repo.loadProject('$projDir/$projectName.lmproject')))!;
      project = project.copyWith(enabledPlugins: const ['lumina_plugin_metaxr', 'lumina_plugin_openxr']);
      await tester.runAsync(() => repo.saveProject(project, projDir));

      // Project Settings → Packaging & Target.
      settings = ProjectSettingsViewModel(projectDirPath: projDir, initialProject: project);
      final s = settings;
      await tester.runAsync(() => s.load());
      final boundaryKey = GlobalKey();
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: ProjectSettingsSubEditor(assetName: 'Project Settings', projectDirPath: projDir, viewModel: s),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('project_settings_nav_${ProjectSettingsCategory.packaging}')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 800));
      expect(await _recordUntil(tester, rec, () => s.hostTargets != null, progress: () => 0, budget: const Duration(seconds: 120)), isTrue);
      await tester.pump();
      final engine = HostBuildTargets.androidArchivesReason();
      final toolchain = s.hostTargets!.toolchainReason('android');
      if (engine != null || toolchain != null) {
        markTestSkipped('Android cannot be built here: ${engine ?? toolchain}');
        return;
      }

      // Android on, Linux off: the Android section appears.
      for (final t in ['android', 'linux']) {
        await tester.ensureVisible(find.byKey(ValueKey('project_settings_target_$t')));
        await tester.pump();
        await rec.hold(const Duration(milliseconds: 400));
        await tester.tap(find.byKey(ValueKey('project_settings_target_$t')));
        await tester.pump();
        await rec.hold(const Duration(milliseconds: 700));
      }
      expect(s.project.packaging.targets, ['android']);
      expect(find.text('Android'), findsWidgets);

      // XR Profile → Meta Quest, from its select.
      final profileRow = find.byKey(const ValueKey('project_settings_row_XR Profile'));
      await tester.ensureVisible(profileRow);
      await tester.pump();
      await tester.tap(find.descendant(of: profileRow, matching: find.byType(Select<String>)));
      await tester.pump(const Duration(milliseconds: 300));
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(find.text('Meta Quest').last);
      await tester.pump(const Duration(milliseconds: 300));
      await rec.hold(const Duration(milliseconds: 800));
      expect(s.androidSettings.isQuest, isTrue);
      expect(s.androidSettings.minSdk, kQuestMinSdk);
      expect(s.androidApplicationId, 'com.lumina.quest_smoke');

      // The manifest preview, composed from the template, the project and both plugins.
      await tester.tap(find.byKey(const ValueKey('project_settings_android_preview_refresh')));
      await tester.pump();
      expect(await _recordUntil(tester, rec, () => !s.androidPreviewLoading && s.androidManifestPreview != null,
          progress: () => 0, budget: const Duration(seconds: 60)), isTrue, reason: s.androidPreviewError);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('project_settings_android_manifest_preview')));
      await tester.pump();
      await rec.hold(const Duration(seconds: 1));
      final preview = s.androidManifestPreview!;
      final sources = preview.lines.map((l) => l.source).toSet();
      expect(sources, containsAll(['template', 'project', 'lumina_plugin_openxr', 'lumina_plugin_metaxr']));
      expect(preview.xml, contains('org.khronos.openxr.intent.category.IMMERSIVE_HMD'));
      expect(preview.xml, contains('com.oculus.supportedDevices'));
      // Scroll the preview down to the plugins' launcher categories.
      final previewList = find.descendant(
          of: find.byKey(const ValueKey('project_settings_android_manifest_preview')), matching: find.byType(Scrollable));
      final position = tester.state<ScrollableState>(previewList.first).position;
      for (var i = 0; i < 80 && find.textContaining('IMMERSIVE_HMD').evaluate().isEmpty; i++) {
        position.jumpTo(math.min(position.pixels + 12, position.maxScrollExtent));
        await tester.pump();
        await rec.hold(const Duration(milliseconds: 66));
      }
      expect(find.textContaining('IMMERSIVE_HMD'), findsWidgets);
      await rec.hold(const Duration(seconds: 1));
      SmokeArtifacts.saveScreenshot('$name 01 quest profile and manifest preview',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));

      await tester.tap(find.byKey(const ValueKey('project_settings_apply')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 700));
      final saved = (await tester.runAsync(() => repo.loadProject('$projDir/$projectName.lmproject')))!;
      expect(saved.packaging.android.isQuest, isTrue);

      // Build Manager: cook the Android target into a finished APK.
      bm = BuildManagerViewModel(projectDirPath: projDir, project: saved);
      final b = bm;
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: BuildManagerSubEditor(assetName: 'Build Manager', projectDirPath: projDir, viewModel: b),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() => b.init());
      await tester.pump();
      await rec.hold(const Duration(seconds: 1));
      expect(b.selectedTargets, ['android']);
      expect(b.reasonsFor('android'), isEmpty);
      expect(b.cookArgumentsFor('android'), containsAllInOrder(['build', 'apk', '--release', '--target-platform', 'android-arm64']));
      await tester.tap(find.byKey(const ValueKey('build_manager_cook')));
      await tester.pump();
      expect(await _recordUntil(tester, rec, () => !b.isRunning && b.lastPipelineStatus != null,
              progress: () => b.logLines.length, budget: const Duration(minutes: 30)),
          isTrue);
      await tester.pump();
      await rec.hold(const Duration(seconds: 1));
      final log = b.logText;
      expect(b.lastPipelineStatus, BuildStepStatus.ok, reason: log);
      expect(log, contains('AndroidManifest.xml composed'));
      expect(log, contains('Plugin runtime modules: lumina_plugin_metaxr, lumina_plugin_openxr'));
      final apk = File('$projDir/build/package/android/quest_smoke-1.0.0.apk');
      expect(apk.existsSync(), isTrue, reason: log);
      expect(File('${apk.path}.sha256').readAsStringSync(), contains('quest_smoke-1.0.0.apk'));
      expect(File('$projDir/lib/main.dart').readAsStringSync(), contains('registerPluginRuntimeModules();'));
      SmokeArtifacts.saveScreenshot('$name 02 cooked apk',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
      rec.save(name);
    } finally {
      settings?.dispose();
      bm?.dispose();
      LuminaConfigDir.override = null;
      // The plugin links first, so nothing behind them is deleted.
      final plugins = Directory('$projDir/plugins');
      if (plugins.existsSync()) {
        for (final e in plugins.listSync(followLinks: false)) {
          if (e is Link) e.deleteSync();
        }
      }
      final engineLinks = Directory('$projDir/.lumina/engine');
      if (engineLinks.existsSync()) {
        for (final e in engineLinks.listSync(followLinks: false)) {
          if (e is Link) e.deleteSync();
        }
      }
      try {
        tempProjectsDir.deleteSync(recursive: true);
      } on FileSystemException catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 45)));
}
