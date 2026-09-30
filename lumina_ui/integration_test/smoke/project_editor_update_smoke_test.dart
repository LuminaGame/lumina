import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/services/project_editor_resolver.dart';
import 'package:lumina_ui/ui/features/launcher/services/project_editor_update.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/create_project_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/editor_build_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/editor_build_splash.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/launcher/views/project_editor_update_dialog.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/scaffold_game_project.dart' show offlineScaffoldRunner;

/// A project whose editor was set up with an older Lumina opens in this
/// Studio: the launcher asks "Update this project's editor?" first. Open
/// with the old editor builds from the copy the project has; Update replaces
/// the copy on the build splash and records this Studio's version in the
/// `.lmproject`. A real project made through the launcher's create flow with
/// a barrel in its level; the project's copy of the engine source is linked
/// (the ~650 MB copy is the plugins smoke's to prove) and stamped as taken
/// from an older release. Each build is cancelled once it is past the copy:
/// the multi-minute editor build is not this scenario's.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("Project Editor Update Smoke Scenario: an older project's editor is updated to this Studio", (tester) async {
    const name = "Project Editor Update Smoke Scenario: an older project's editor is updated to this Studio";
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/dented_barrel.glb');
    expect(barrel.existsSync(), isTrue, reason: 'test-assets must hold the barrel');
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A short temp root: Windows paths under the host stay short.
    final temp = Directory.systemTemp.createTempSync('peu_');
    final originalHandOff = EditorHandOff.instance;
    const older = EngineIdentity(version: '0.0.1-dev.3', commit: '5d1c0f2e9a7b4c3d2e1f0a9b8c7d6e5f4a3b2c1d', release: true);
    try {
      final cacheBase = Directory('${temp.path}/cache')..createSync();
      final pubCache = Platform.environment['PUB_CACHE'] ??
          (Platform.isWindows ? '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache' : '${Platform.environment['HOME']}/.pub-cache');
      final buildEnv = Platform.isWindows ? {'LOCALAPPDATA': cacheBase.path, 'PUB_CACHE': pubCache} : {'HOME': cacheBase.path, 'PUB_CACHE': pubCache};
      final starts = <List<String>>[];
      EditorHandOff.instance = EditorHandOff(startDetached: (exe, args) async => starts.add([exe, ...args]), exitApp: (_) {});
      EditorBuildSplash.manageNativeWindow = false;

      // 1. A real project through the launcher's create flow, a barrel in its
      //    level (the stock editor, saved to disk).
      final config = Directory('${temp.path}/config')..createSync();
      final resolver = ProjectEditorResolver(cache: EditorBuildCache(root: Directory('${cacheBase.path}/editor-builds')));
      final repo = ProjectRepository(configDir: config, processRunner: offlineScaffoldRunner());
      late LauncherViewModel launcher;
      await tester.runAsync(() async => launcher = LauncherViewModel(
            configDir: config,
            projectRepo: repo,
            editorResolver: resolver,
            buildServiceFactory: (r) => EditorBuildService(
              engineRoot: r.engineRoot,
              cache: r.cache,
              generator: r.generator,
              // The project's copy as links to the engine.
              vendor: EditorSourceVendorService(engineRoot: r.engineRoot, linkPackages: true),
              mode: r.mode,
              flutterInfo: r.flutterInfo,
              environment: buildEnv,
              hostAliasRoot: Directory('${temp.path}/hosts'),
            ),
          ));
      final create = CreateProjectViewModel(launcherVM: launcher, projectRepo: repo)
        ..updateName('update_game')
        ..updateLocation(temp.path);
      await tester.runAsync(create.createProject);
      expect(create.creationError, isNull);
      final pDir = '${temp.path}/update_game';
      final project = (await tester.runAsync(() => repo.loadProject('$pDir/update_game.lmproject')))!;
      final editor = EditorViewModel(initialProject: project, projectLocation: temp.path, enableTimers: false);
      await tester.runAsync(() async {
        await editor.ensureDefaultLevelAssets();
        await editor.processImportPipeline(sourceFilePath: barrel.path);
        editor.refreshAssets();
        final mesh = editor.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('dented_barrel'));
        await editor.spawnActorFromAsset(mesh, location: [0.0, 0.0, 0.0]);
        await editor.saveLevelAndGenerateCode();
      });
      editor.dispose();

      // 2. The project's editor as an older Studio left it: a copy of the
      //    engine source stamped with release 0.0.1-dev.3.
      final host = EditorHostGeneratorService.hostDirOf(pDir);
      await tester.runAsync(() async {
        await resolver.generator.generate(pDir, const []);
        await EditorSourceVendorService(engineRoot: resolver.engineRoot, linkPackages: true).vendor(host);
      });
      final stampFile = File('$host/${EditorSourceVendorService.stampFileName}');
      final stamp = jsonDecode(stampFile.readAsStringSync()) as Map<String, dynamic>;
      stampFile.writeAsStringSync(jsonEncode({...stamp, 'engine': older.toJson()}));
      String engineVersionOnDisk() => (jsonDecode(File('$pDir/update_game.lmproject').readAsStringSync()) as Map)['engine_version'] as String;
      expect(engineVersionOnDisk(), kLuminaEngineVersion);
      final current = (await tester.runAsync(() => EngineIdentity.of(LuminaWorkspace.root)))!;

      final boundaryKey = GlobalKey();
      Future<void> pumpLauncher(Key key) => tester.pumpWidget(RepaintBoundary(
            key: boundaryKey,
            child: ShadcnApp(key: key, theme: luminaEditorTheme(), home: LauncherView(viewModel: launcher, initialProjectDir: pDir)),
          ));
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String label) async => SmokeArtifacts.saveScreenshot('$name: $label',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
          usedAssets: [barrel.path]);
      EditorBuildViewModel? splash() {
        final f = find.byType(EditorBuildSplash);
        return f.evaluate().isEmpty ? null : tester.widget<EditorBuildSplash>(f).viewModel;
      }

      Future<void> until(bool Function() done, {Duration timeout = const Duration(minutes: 3)}) async {
        final sw = Stopwatch()..start();
        while (!done() && sw.elapsed < timeout) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 33)));
          await tester.pump();
          await rec.captureIfChanged();
        }
        expect(done(), isTrue);
      }

      bool dialogUp() => find.byType(ProjectEditorUpdateDialog).evaluate().isNotEmpty;

      // 3. Open: the question names both versions.
      await pumpLauncher(const ValueKey('first'));
      await until(dialogUp);
      await rec.hold(const Duration(milliseconds: 1200));
      final text = tester.widget<Text>(find.byKey(const Key('project_editor_update_text'))).data!;
      expect(text, 'update_game was set up with Lumina 0.0.1-dev.3; this Studio is Lumina ${current.label}. '
          "Update the project's editor to Lumina ${current.label}?");
      await shot('the update question');

      // 4. Open with the old editor: the splash builds from the old copy.
      await tester.tap(find.text('Open with the old editor'));
      // Past the copy and `pub get`: the build log exists.
      await until(() => splash()?.logPath != null);
      expect(splash()!.logLines.where((l) => l.contains('Updating the editor source')), isEmpty);
      // Show log: the build runs on the copy the project has.
      splash()!.toggleLog();
      await rec.hold(const Duration(milliseconds: 1200));
      expect(EditorSourceVendorService.copiedEngine(host), older, reason: 'the old copy is kept');
      await shot('splash, building from the old copy');
      final oldBuild = splash()!;
      oldBuild.cancel();
      await until(() => splash() == null);
      final oldLog = File(oldBuild.logPath!).readAsStringSync();
      expect(oldLog, isNot(contains('Updating the editor source')));
      expect(engineVersionOnDisk(), kLuminaEngineVersion);
      expect(File('${config.path}/${ProjectEditorUpdatePrompts.fileName}').existsSync(), isFalse);
      await rec.hold(const Duration(milliseconds: 800));

      // 5. Open again: asked again (no "Don't ask again"); Update replaces the
      //    copy on the splash and records this Studio's version.
      await pumpLauncher(const ValueKey('second'));
      await until(dialogUp);
      await rec.hold(const Duration(milliseconds: 1200));
      await tester.tap(find.text('Update'));
      // Show log as soon as the splash reports the update: the copy is
      // replaced before anything else runs.
      await until(() => splash()?.logLines.any((l) => l.startsWith('Updating the editor source in')) ?? false);
      splash()!.toggleLog();
      await tester.pump();
      await shot('splash, the copy updated to this Studio');
      await until(() => splash()?.logPath != null);
      await rec.hold(const Duration(milliseconds: 1200));
      // The engine as the sync saw it (other work may commit to the engine
      // checkout while this runs).
      final synced = EditorSourceVendorService.copiedEngine(host)!;
      expect(synced.version, current.version);
      expect(synced.release, current.release);
      expect(synced.commit, matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(engineVersionOnDisk(), current.version);
      final update = splash()!;
      update.cancel();
      await until(() => splash() == null);
      expect(File(update.logPath!).readAsStringSync(), contains('Updating the editor source in'));

      // 6. The copy is current: the next open asks nothing (unless the
      //    engine checkout moved on meanwhile).
      await pumpLauncher(const ValueKey('third'));
      await until(() => splash() != null || dialogUp());
      if (dialogUp()) {
        final now = (await tester.runAsync(() => EngineIdentity.of(LuminaWorkspace.root)))!;
        expect(now.key, isNot(synced.key), reason: 'asked again although the engine did not change');
        await tester.tap(find.text('Cancel'));
        await rec.hold(const Duration(milliseconds: 800));
      } else {
        await rec.hold(const Duration(milliseconds: 1500));
        splash()!.cancel();
        await until(() => splash() == null);
      }
      final minimum = Duration(milliseconds: (SmokeArtifacts.minimumVideoSeconds * 1000).ceil() + 500);
      while (rec.recorded < minimum) {
        await rec.hold(const Duration(milliseconds: 1000));
      }
      rec.save(name, usedAssets: [barrel.path]);
      expect(starts, isEmpty, reason: 'no project editor was started');
      await tester.runAsync(() async => launcher.dispose());
    } finally {
      EditorHandOff.instance = originalHandOff;
      EditorBuildSplash.manageNativeWindow = true;
      await tester.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          try {
            if (temp.existsSync()) temp.deleteSync(recursive: true);
            break;
          } on FileSystemException {
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
        }
      });
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
