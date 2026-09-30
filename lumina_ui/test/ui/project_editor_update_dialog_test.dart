import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/services/project_editor_resolver.dart';
import 'package:lumina_ui/ui/features/launcher/services/project_editor_update.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/editor_build_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/editor_build_splash.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/launcher/views/project_editor_update_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/editor_host_fixture.dart';
import '../helpers/temp_project.dart';

/// "Update this project's editor?": a project whose copy of the engine
/// source comes from another engine than the running Studio's is offered an
/// update before it opens. Real temp projects, hosts (the copy as links) and
/// config folders on disk.
void main() {
  const older = EngineIdentity(version: '0.0.1-dev.3', commit: '1111111111111111111111111111111111111111', release: true);

  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  group('the dialog', () {
    Future<ProjectEditorUpdateAnswer?> ask(WidgetTester tester, Future<void> Function() answer) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      ProjectEditorUpdateAnswer? result;
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Builder(
          builder: (context) => PrimaryButton(
            onPressed: () async => result = await ProjectEditorUpdateDialog.show(context,
                projectName: 'HostGame', fromLabel: '0.0.1-dev.3', toLabel: '0.0.1-dev.7'),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(find.text("Update this project's editor?"), findsOneWidget);
      await answer();
      await settle(tester);
      expect(find.text("Update this project's editor?"), findsNothing);
      return result;
    }

    testWidgets('names both versions and the loss of edits; each button answers', (tester) async {
      final update = await ask(tester, () async {
        expect(
            find.text('HostGame was set up with Lumina 0.0.1-dev.3; this Studio is Lumina 0.0.1-dev.7. '
                "Update the project's editor to Lumina 0.0.1-dev.7?"),
            findsOneWidget);
        expect(
            find.text('Its copy of the engine source is replaced and the editor is rebuilt; edits made inside '
                '.lumina/editor are lost.'),
            findsOneWidget);
        expect(find.widgetWithText(PrimaryButton, 'Update'), findsOneWidget);
        expect(find.widgetWithText(OutlineButton, 'Open with the old editor'), findsOneWidget);
        expect(find.widgetWithText(GhostButton, 'Cancel'), findsOneWidget);
        expect(find.text("Don't ask again for this version"), findsOneWidget);
        await tester.tap(find.text('Update'));
      });
      expect(update!.choice, ProjectEditorUpdateChoice.update);

      final old = await ask(tester, () => tester.tap(find.text('Open with the old editor')));
      expect(old!.choice, ProjectEditorUpdateChoice.openWithOldEditor);
      expect(old.dontAskAgain, isFalse);

      final dismissed = await ask(tester, () async {
        await tester.tap(find.text("Don't ask again for this version"));
        await settle(tester);
        await tester.tap(find.text('Open with the old editor'));
      });
      expect(dismissed!.choice, ProjectEditorUpdateChoice.openWithOldEditor);
      expect(dismissed.dontAskAgain, isTrue);

      final cancel = await ask(tester, () => tester.tap(find.text('Cancel')));
      expect(cancel!.choice, ProjectEditorUpdateChoice.cancel);
    });

    testWidgets('an unknown older engine reads "an older engine"', (tester) async {
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: const ProjectEditorUpdateDialog(projectName: 'HostGame', fromLabel: 'an older engine', toLabel: '0.0.1-dev.7'),
      ));
      expect(find.textContaining('HostGame was set up with an older engine; this Studio is Lumina 0.0.1-dev.7.'), findsOneWidget);
    });

    test('uses no Material widgets', () {
      final src = File(p.join(LuminaWorkspace.package('lumina_ui'), 'lib', 'ui', 'features', 'launcher', 'views',
              'project_editor_update_dialog.dart'))
          .readAsStringSync();
      expect(src, isNot(contains('package:flutter/material.dart')));
    });
  });

  group('per-machine records', () {
    late Directory temp;
    setUp(() => temp = Directory.systemTemp.createTempSync('pe_update_'));
    tearDown(() => deleteTempProject(temp));

    test("Don't ask again: per project and engine, in the config folder", () {
      final config = Directory(p.join(temp.path, 'config'));
      final project = p.join(temp.path, 'Game');
      final prompts = ProjectEditorUpdatePrompts(configDir: config);
      expect(prompts.isDismissed(project, older), isFalse);
      prompts.dismiss(project, older);
      expect(prompts.isDismissed(project, older), isTrue);
      expect(prompts.isDismissed('$project/', older), isTrue, reason: 'the same folder, spelled differently');
      expect(prompts.isDismissed(project, const EngineIdentity(version: '0.0.1-dev.4', commit: '2222', release: true)), isFalse,
          reason: 'a newer engine asks again');
      expect(prompts.isDismissed(p.join(temp.path, 'Other'), older), isFalse);
      expect(File(p.join(config.path, ProjectEditorUpdatePrompts.fileName)).existsSync(), isTrue);
      expect(ProjectEditorUpdatePrompts(configDir: config).isDismissed(project, older), isTrue, reason: 'stored on disk');
    });

    test('the Studio record round trip; none under a test run', () async {
      final config = Directory(p.join(temp.path, 'config'));
      expect(LuminaStudioRecord.read(configDir: config), isNull);
      LuminaStudioRecord(executable: p.join(temp.path, 'lumina_ui.exe'), engineRoot: LuminaWorkspace.root, engine: older)
          .write(configDir: config);
      final read = LuminaStudioRecord.read(configDir: config)!;
      expect(read.executable, p.join(temp.path, 'lumina_ui.exe'));
      expect(read.engineRoot, LuminaWorkspace.root);
      expect(read.engine, older);
      expect(await LuminaStudioRecord.recordThisStudio(configDir: Directory(p.join(temp.path, 'other'))), isNull);
    });

    test('--update-editor on the command line', () {
      expect(EditorLaunchArgs.parse(['--project', 'x', '--update-editor']).updateEditor, isTrue);
      expect(EditorLaunchArgs.parse(['--project', 'x']).updateEditor, isFalse);
    });
  });

  group('the launcher', () {
    late EditorHostFixture fx;
    late Directory config;
    final starts = <List<String>>[];
    final originalHandOff = EditorHandOff.instance;

    setUp(() {
      fx = EditorHostFixture.create(enabledPlugins: const []);
      config = Directory(p.join(fx.temp.path, 'config'))..createSync();
      UserPluginDir.override = Directory(p.join(fx.temp.path, 'user_plugins'))..createSync();
      starts.clear();
      EditorHandOff.instance = EditorHandOff(startDetached: (exe, args) async => starts.add([exe, ...args]), exitApp: (_) {});
    });
    tearDown(() async {
      EditorHandOff.instance = originalHandOff;
      LuminaEditorHost.info = null;
      LuminaEditorHost.args = const EditorLaunchArgs();
      UserPluginDir.override = null;
      await deleteTempProject(fx.temp);
    });

    // The running engine, read once on the real clock (`git` does not run
    // inside the widget test's fake-async zone).
    late EngineIdentity current;
    setUpAll(() async => current = await EngineIdentity.of(LuminaWorkspace.root));

    ProjectEditorResolver resolver({bool everyProject = true}) => ProjectEditorResolver(
          engineRoot: LuminaWorkspace.root,
          cache: EditorBuildCache(root: Directory(p.join(fx.temp.path, 'cache'))),
          flutterInfo: fixedFlutterInfo,
          everyProject: everyProject,
          currentEngine: () async => current,
        );

    /// The project's host with a copy (links) stamped as taken from [older].
    Future<void> olderCopy(WidgetTester tester) async {
      await tester.runAsync(() async {
        await resolver().generator.generate(fx.projectDir.path, const []);
        await fx.vendorHost();
      });
      final stamp = File(p.join(fx.hostDir, EditorSourceVendorService.stampFileName));
      final json = jsonDecode(stamp.readAsStringSync()) as Map<String, dynamic>;
      json['engine'] = older.toJson();
      stamp.writeAsStringSync(jsonEncode(json));
    }

    String engineVersionOnDisk() =>
        (jsonDecode(File(p.join(fx.projectDir.path, 'HostGame.lmproject')).readAsStringSync()) as Map)['engine_version'] as String;

    Future<LauncherViewModel> launcherFor(WidgetTester tester, ProjectEditorResolver r) async {
      late LauncherViewModel launcher;
      await tester.runAsync(() async => launcher = LauncherViewModel(
            configDir: config,
            editorResolver: r,
            // The copy as links; the build ends at its first tool call (the
            // real build is the smoke run's).
            buildServiceFactory: (r) => _RootZoneBuildService(
              engineRoot: r.engineRoot,
              cache: r.cache,
              generator: r.generator,
              vendor: EditorSourceVendorService(engineRoot: r.engineRoot, linkPackages: true),
              flutterInfo: r.flutterInfo,
              hostAliasRoot: Directory(p.join(fx.temp.path, 'hosts')),
              killTree: (_) async {},
              processStarter: (exe, args, {workingDirectory, environment}) async =>
                  throw ProcessException(exe, args, 'no build in this test'),
            ),
          ));
      return launcher;
    }

    Future<void> pumpLauncher(WidgetTester tester, LauncherViewModel launcher, {Key? key}) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ShadcnApp(
        key: key,
        theme: luminaEditorTheme(),
        home: LauncherView(
          viewModel: launcher,
          initialProjectDir: fx.projectDir.path,
          editorBuilder: (project, location, warning) => Text('opened ${project.projectName} ${project.engineVersion}'),
        ),
      ));
    }

    /// Real IO (resolving, hashing the copy, git) runs on the real clock.
    Future<void> until(WidgetTester tester, bool Function() done) async {
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (!done() && DateTime.now().isBefore(deadline)) {
        await drainRealIo(tester, rounds: 2);
      }
      expect(done(), isTrue);
    }

    bool dialogUp() => find.byType(ProjectEditorUpdateDialog).evaluate().isNotEmpty;
    bool splashUp() => find.byType(EditorBuildSplash).evaluate().isNotEmpty;

    testWidgets('Open with the old editor builds from the old copy; "Don\'t ask again" is kept for this engine', (tester) async {
      await olderCopy(tester);
      final launcher = await launcherFor(tester, resolver());
      await pumpLauncher(tester, launcher);
      await until(tester, dialogUp);
      expect(find.byKey(const Key('project_editor_update_text')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('project_editor_update_text'))).data,
          startsWith('HostGame was set up with Lumina 0.0.1-dev.3; this Studio is Lumina ${current.label}'));

      await tester.tap(find.text("Don't ask again for this version"));
      await settle(tester);
      await tester.tap(find.text('Open with the old editor'));
      await settle(tester);
      await until(tester, () => splashUp() && tester.widget<EditorBuildSplash>(find.byType(EditorBuildSplash)).viewModel.state != EditorBuildSplashState.running);
      final build = tester.widget<EditorBuildSplash>(find.byType(EditorBuildSplash)).viewModel;
      expect((build.outcome as EditorBuildFailed).lastLines.any((l) => l.contains('Updating the editor source')), isFalse);
      expect(EditorSourceVendorService.copiedEngine(fx.hostDir), older, reason: 'the old copy is kept');
      expect(engineVersionOnDisk(), kLuminaEngineVersion);
      expect(launcher.updatePrompts.isDismissed(fx.projectDir.path, current), isTrue);
      expect(File(p.join(config.path, ProjectEditorUpdatePrompts.fileName)).existsSync(), isTrue);

      // Reopened: no question for this engine.
      await pumpLauncher(tester, launcher, key: const ValueKey('again'));
      await until(tester, splashUp);
      expect(dialogUp(), isFalse);
      await tester.runAsync(() async => launcher.dispose());
    });

    testWidgets('Cancel stays in the launcher and changes nothing', (tester) async {
      await olderCopy(tester);
      final launcher = await launcherFor(tester, resolver());
      await pumpLauncher(tester, launcher);
      await until(tester, dialogUp);
      await tester.tap(find.text('Cancel'));
      await settle(tester, frames: 30);
      expect(dialogUp(), isFalse);
      expect(splashUp(), isFalse);
      expect(find.byType(LauncherView), findsOneWidget);
      expect(EditorSourceVendorService.copiedEngine(fx.hostDir), older);
      expect(engineVersionOnDisk(), kLuminaEngineVersion);
      expect(File(p.join(config.path, ProjectEditorUpdatePrompts.fileName)).existsSync(), isFalse);
      await tester.runAsync(() async => launcher.dispose());
    });

    testWidgets('Update replaces the copy on the splash and records the engine_version', (tester) async {
      await olderCopy(tester);
      final launcher = await launcherFor(tester, resolver());
      await pumpLauncher(tester, launcher);
      await until(tester, dialogUp);
      await tester.tap(find.text('Update'));
      await settle(tester);
      await until(tester, () => splashUp() && tester.widget<EditorBuildSplash>(find.byType(EditorBuildSplash)).viewModel.state != EditorBuildSplashState.running);
      final build = tester.widget<EditorBuildSplash>(find.byType(EditorBuildSplash)).viewModel;
      expect((build.outcome as EditorBuildFailed).lastLines.any((l) => l.contains('Updating the editor source')), isTrue);
      // The engine as the sync read it (the checkout may move on meanwhile).
      expect(EditorSourceVendorService.copiedEngine(fx.hostDir)!.version, current.version);
      expect(EditorSourceVendorService.copiedEngine(fx.hostDir), isNot(older));
      expect(engineVersionOnDisk(), current.version);
      final logs = EngineLoggerService().logs.map((e) => e.message).toList();
      expect(logs.any((m) => m.contains('Updated the project editor source of HostGame from Lumina 0.0.1-dev.3 to Lumina ${current.label}')), isTrue);
      await tester.runAsync(() async => launcher.dispose());
    });

    testWidgets('--update-editor updates without asking', (tester) async {
      await olderCopy(tester);
      LuminaEditorHost.args = EditorLaunchArgs(project: fx.projectDir.path, updateEditor: true);
      final launcher = await launcherFor(tester, resolver());
      await pumpLauncher(tester, launcher);
      await until(tester, () => splashUp() && tester.widget<EditorBuildSplash>(find.byType(EditorBuildSplash)).viewModel.state != EditorBuildSplashState.running);
      expect(dialogUp(), isFalse);
      // The engine as the sync read it (the checkout may move on meanwhile).
      expect(EditorSourceVendorService.copiedEngine(fx.hostDir)!.version, current.version);
      expect(EditorSourceVendorService.copiedEngine(fx.hostDir), isNot(older));
      await tester.runAsync(() async => launcher.dispose());
    });

    testWidgets('open in place records engine_version and logs one line, without a dialog', (tester) async {
      final launcher = await launcherFor(tester, resolver(everyProject: false));
      await pumpLauncher(tester, launcher);
      await until(tester, () => find.textContaining('opened HostGame').evaluate().isNotEmpty);
      expect(dialogUp(), isFalse);
      expect(find.text('opened HostGame ${LuminaRelease.displayVersion}'), findsOneWidget);
      expect(engineVersionOnDisk(), LuminaRelease.displayVersion);
      final lines = EngineLoggerService()
          .logs
          .where((e) => e.message == 'HostGame: engine_version $kLuminaEngineVersion → ${LuminaRelease.displayVersion} '
              '(opened in Lumina ${LuminaRelease.displayVersion})')
          .toList();
      expect(lines, hasLength(1));
      await tester.runAsync(() async => launcher.dispose());
    });

    testWidgets('a project editor started on its own offers the update through the recorded Studio', (tester) async {
      await olderCopy(tester);
      final studioExe = File(p.join(fx.temp.path, 'studio', 'lumina_ui.exe'))..createSync(recursive: true);
      LuminaStudioRecord(executable: studioExe.path, engineRoot: LuminaWorkspace.root, engine: current).write(configDir: config);
      LuminaEditorHost.info = EditorHostInfo(packageName: 'hostgame_editor', engineRoot: LuminaWorkspace.root);
      final launcher = await launcherFor(tester, resolver());
      await pumpLauncher(tester, launcher);
      await until(tester, dialogUp);
      await tester.tap(find.text('Update'));
      await settle(tester, frames: 30);
      await drainRealIo(tester);
      expect(starts, [
        [studioExe.path, '--project', fx.projectDir.path, '--update-editor'],
      ]);
      await tester.runAsync(() async => launcher.dispose());
    });

    testWidgets('a project editor the launcher started does not ask again', (tester) async {
      await olderCopy(tester);
      final studioExe = File(p.join(fx.temp.path, 'studio', 'lumina_ui.exe'))..createSync(recursive: true);
      LuminaStudioRecord(executable: studioExe.path, engineRoot: LuminaWorkspace.root, engine: current).write(configDir: config);
      LuminaEditorHost.info = EditorHostInfo(packageName: 'hostgame_editor', engineRoot: LuminaWorkspace.root);
      LuminaEditorHost.args = EditorLaunchArgs(project: fx.projectDir.path, launcherExe: studioExe.path);
      final launcher = await launcherFor(tester, resolver());
      await pumpLauncher(tester, launcher);
      await until(tester, () => find.textContaining('opened HostGame').evaluate().isNotEmpty);
      expect(dialogUp(), isFalse);
      expect(starts, isEmpty);
      await tester.runAsync(() async => launcher.dispose());
    });
  });
}

/// Runs each build on the real event loop (its file IO and `git` do not run
/// inside the widget test's fake-async zone); the splash sees its events on
/// pump.
class _RootZoneBuildService extends EditorBuildService {
  _RootZoneBuildService({
    required super.engineRoot,
    super.cache,
    super.generator,
    super.vendor,
    super.flutterInfo,
    super.hostAliasRoot,
    super.killTree,
    super.processStarter,
  });

  @override
  EditorBuildJob start(String projectDir, List<LuminaPluginDescriptor> plugins,
          {String? projectName, bool syncSource = false, FutureOr<void> Function()? onSourceSynced}) =>
      Zone.root.run(() => super.start(projectDir, plugins,
          projectName: projectName, syncSource: syncSource, onSourceSynced: onSourceSynced));
}
