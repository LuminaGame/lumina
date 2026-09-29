import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:lumina/lumina.dart' show EngineBootstrap, EngineBootstrapStep;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/engine_bootstrap/view_models/engine_bootstrap_view_model.dart';
import 'package:lumina_ui/ui/features/engine_bootstrap/views/engine_bootstrap_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/about_dialog.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/engine_source_preferences_page.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The first-launch screen of an installed Lumina Studio, the Engine Source
/// preferences and the release line in About.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('engine_bootstrap_view_'));
  tearDown(() {
    LuminaWorkspace.clearCheckout();
    if (Platform.isWindows) Process.runSync('attrib', ['-R', '${temp.path}\\*', '/S', '/D'], runInShell: true);
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  Map<String, String> gitEnv() => {
        ...Platform.environment,
        'GIT_AUTHOR_NAME': 'Lumina Test',
        'GIT_COMMITTER_NAME': 'Lumina Test',
        'GIT_AUTHOR_EMAIL': 'test@lumina.invalid',
        'GIT_COMMITTER_EMAIL': 'test@lumina.invalid',
      };

  /// A bare git "remote" holding a tiny engine workspace; returns its file
  /// URL and commit.
  Future<(String, String)> fixtureRemote() async {
    final src = Directory(p.join(temp.path, 'src'))..createSync();
    File(p.join(src.path, 'pubspec.yaml')).writeAsStringSync('name: fixture_engine\npublish_to: none\nenvironment:\n  sdk: ^3.0.0\n');
    File(p.join(src.path, 'tool', 'filament', 'VERSION'))
      ..createSync(recursive: true)
      ..writeAsStringSync('1.77.0-test.1\n');
    File(p.join(src.path, '.gitignore')).writeAsStringSync('/filament\n.dart_tool/\npubspec.lock\n');
    Future<String> git(List<String> args, String cwd) async {
      final r = await Process.run('git', args, workingDirectory: cwd, environment: gitEnv());
      expect(r.exitCode, 0, reason: '${r.stderr}');
      return '${r.stdout}'.trim();
    }

    await git(['init', '-q', '-b', 'main'], src.path);
    await git(['add', '.'], src.path);
    await git(['commit', '-q', '-m', 'engine'], src.path);
    final sha = await git(['rev-parse', 'HEAD'], src.path);
    final remote = p.join(temp.path, 'remote.git');
    await git(['clone', '-q', '--bare', src.path, remote], temp.path);
    return (Uri.file(remote).toString(), sha);
  }

  Map<String, String> withFlutterOnPath() {
    final env = Map.of(Platform.environment);
    final flutterBin = p.join(p.dirname(p.dirname(p.dirname(p.dirname(p.dirname(Platform.resolvedExecutable))))), 'bin');
    final key = env.keys.firstWhere((k) => k.toLowerCase() == 'path', orElse: () => 'PATH');
    env[key] = '$flutterBin${Platform.isWindows ? ';' : ':'}${env[key] ?? ''}';
    return env;
  }

  EngineBootstrap bootstrapFor({required String repo, required String commit, Map<String, String>? environment}) => EngineBootstrap(
        version: 'v0.0.0-test',
        commit: commit,
        repo: repo,
        engineRoot: Directory(p.join(temp.path, 'data', 'engine')),
        filamentRoot: Directory(p.join(temp.path, 'data', 'filament')),
        environment: environment ?? withFlutterOnPath(),
        checkToolchain: false,
        filament: ({required version, required releaseTag, required cacheRoot, onProgress}) async =>
            Directory(p.join(cacheRoot.path, version))..createSync(recursive: true),
        openriglogicRoot: Directory(p.join(temp.path, 'data', 'openriglogic')),
        openriglogic: ({required releaseTag, required cacheRoot, onProgress}) async =>
            (Directory(p.join(cacheRoot.path, releaseTag, 'lib'))..createSync(recursive: true)).parent,
      );

  Future<void> pumpScreen(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: child)));
  }

  testWidgets('missing git and Flutter: a clear error with install hints, the installer hint and Retry', (tester) async {
    final noTools = {
      for (final e in Platform.environment.entries)
        if (e.key.toLowerCase() != 'path') e.key: e.value,
      'PATH': '',
    };
    final vm = EngineBootstrapViewModel(bootstrapFor(repo: 'file:///nowhere.git', commit: 'a' * 40, environment: noTools));
    addTearDown(vm.dispose);
    var quit = 0;
    await pumpScreen(tester, EngineBootstrapView(viewModel: vm, onReady: (_) => fail('not ready'), onQuit: () => quit++));
    await tester.pump();
    await tester.pump();

    expect(find.text('Setting up Lumina Studio'), findsOneWidget);
    expect(find.textContaining('prebuilt Filament and OpenRigLogic libraries'), findsOneWidget);
    for (final s in EngineBootstrapStep.values) {
      expect(find.text(s.label), findsOneWidget);
    }
    expect(vm.failed, isTrue);
    expect(find.byKey(const Key('engine_bootstrap_error')), findsOneWidget);
    expect(find.text('Missing prerequisites'), findsOneWidget);
    expect(find.byKey(const Key('engine_bootstrap_missing_Git')), findsOneWidget);
    expect(find.byKey(const Key('engine_bootstrap_missing_Flutter SDK')), findsOneWidget);
    expect(find.textContaining('Install the Flutter SDK'), findsOneWidget);
    expect(find.textContaining('Lumina installer'), findsOneWidget);
    expect(find.byKey(const Key('engine_bootstrap_checkout_path')), findsOneWidget);

    // The log is there on demand.
    await tester.tap(find.byKey(const Key('engine_bootstrap_toggle_log')));
    await tester.pump();
    expect(find.byKey(const Key('engine_bootstrap_log')), findsOneWidget);
    expect(find.textContaining('Git: not found'), findsOneWidget);

    // Retry runs the check again (still missing here).
    final before = vm.log.length;
    await tester.tap(find.byKey(const Key('engine_bootstrap_retry')));
    await tester.pump();
    await tester.pump();
    expect(vm.log.length, greaterThan(before));
    expect(vm.failed, isTrue);

    await tester.tap(find.byKey(const Key('engine_bootstrap_quit')));
    expect(quit, 1);
  });

  testWidgets('a completed bootstrap shows every step done and activates the checkout', (tester) async {
    final (repo, sha) = (await tester.runAsync(fixtureRemote))!;
    final vm = EngineBootstrapViewModel(bootstrapFor(repo: repo, commit: sha));
    addTearDown(vm.dispose);
    final checkout = await tester.runAsync(() => vm.start());
    expect(checkout, isNotNull, reason: vm.log.join('\n'));

    await pumpScreen(tester, EngineBootstrapView(viewModel: vm, autoStart: false, onReady: (_) {}));
    await tester.pump();
    for (final s in EngineBootstrapStep.values) {
      expect(vm.step(s).status, BootstrapStepStatus.done, reason: s.name);
    }
    expect(find.byKey(const Key('engine_bootstrap_error')), findsNothing);
    expect(find.byKey(const Key('engine_bootstrap_retry')), findsNothing);
    expect(LuminaWorkspace.root, p.normalize(vm.bootstrap.checkoutDir.path));
    expect(LuminaWorkspace.engineCommit, sha);

    // Editor Preferences → Engine Source names the release, commit, checkout and Filament.
    await pumpScreen(tester, EngineSourcePreferencesPage(bootstrap: vm.bootstrap, releaseVersion: 'v0.0.0-test', releaseCommit: sha));
    await tester.pump();
    expect(find.text('v0.0.0-test'), findsOneWidget);
    expect(find.text(sha), findsOneWidget);
    expect(find.text(p.normalize(vm.bootstrap.checkoutDir.path)), findsOneWidget);
    expect(find.textContaining('1.77.0-test.1'), findsOneWidget);
    expect(tester.widget<OutlineButton>(find.byKey(const ValueKey('engine_source_redownload'))).onPressed, isNotNull);
  });

  testWidgets('a dev build: Engine Source shows the source checkout and cannot re-download', (tester) async {
    await pumpScreen(tester, const EngineSourcePreferencesPage(releaseVersion: '', releaseCommit: ''));
    await tester.pump();
    expect(find.text('Development build'), findsOneWidget);
    expect(find.text(LuminaWorkspace.root), findsOneWidget);
    expect(tester.widget<OutlineButton>(find.byKey(const ValueKey('engine_source_redownload'))).onPressed, isNull);
  });

  testWidgets('About shows the release tag and commit when set, nothing extra in a dev build', (tester) async {
    await pumpScreen(
      tester,
      Column(children: [
        AboutLuminaDialog(engineVersion: '0.0.1', onClose: () {}, releaseVersion: 'v0.1.0', releaseCommit: 'c0ffee' * 6 + 'c0ff'),
      ]),
    );
    await tester.pump();
    expect(find.text('Release v0.1.0 · commit ${'c0ffee' * 6}c0ff'), findsOneWidget);
    final dialog = AboutLuminaDialog(engineVersion: '0.0.1', onClose: () {}, releaseVersion: 'v0.1.0', releaseCommit: 'abc');
    expect(dialog.versionInfo(), contains('Release v0.1.0 · commit abc'));
    expect(AboutLuminaDialog(engineVersion: '0.0.1', onClose: () {}, releaseVersion: '', releaseCommit: '').releaseLine, isNull);
  });
}
