import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/source_control/services/git_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The editor side of the project's
/// `DerivedDataCache/`: Tools → Clear Derived Data Cache, the Initialize Git
/// Repository template, and the Cook & Package guard.
void main() {
  final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';
  final barrel = File('$assets/Props/Barrels/dented_barrel.glb');
  final banana = File('$assets/Props/Banana Bunch/banana_bunch_long.glb');
  final skip = barrel.existsSync() && banana.existsSync() ? null : 'test-assets missing';

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('lumina_ui_ddc_'));
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// A real project folder with a `.lmproject`, the way the launcher opens one.
  Directory writeProject(String name) {
    final dir = Directory('${temp.path}/$name')..createSync(recursive: true);
    Directory('${dir.path}/contents/levels').createSync(recursive: true);
    File('${dir.path}/$name.lmproject').writeAsStringSync(
      '{"project_name": "$name", "active_level": "contents/levels/L_Main.lmas"}',
    );
    return dir;
  }

  // The editor viewport's tickers never let pumpAndSettle settle.
  Future<void> settle(WidgetTester tester, {int frames = 20}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  test('tools.clearDerivedDataCache is registered and empties the open project\'s cache', () async {
    final project = writeProject('DdcGame');
    final cache = DerivedDataCache(project.path);
    await cache.put(DerivedDataCache.sanitizedGlbBucket, 'barrel', barrel.readAsBytesSync(), label: 'dented_barrel.glb');
    await cache.put(DerivedDataCache.sanitizedGlbBucket, 'banana', banana.readAsBytesSync(), label: 'banana_bunch_long.glb');
    final bytes = cache.usage().bytes;

    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'DdcGame'),
      projectLocation: temp.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    final command = vm.commands.byId('tools.clearDerivedDataCache');
    expect(command, isNotNull);
    expect(command!.label, 'Clear Derived Data Cache');
    expect(command.canExecute(), isTrue);

    final logs = <EngineLogEntry>[];
    final sub = EngineLoggerService().logStream.listen(logs.add);
    addTearDown(sub.cancel);
    final freed = await vm.clearDerivedDataCache();

    expect(freed.entries, 2);
    expect(freed.bytes, bytes);
    expect(cache.entries(), isEmpty);
    expect(
      logs.where((e) => e.source == 'DerivedDataCache' && e.message.contains('Cleared') && e.message.contains('2 entries')),
      hasLength(1),
    );
  }, skip: skip);

  testWidgets('Tools → Clear Derived Data Cache clears the project\'s cache from the menu', (tester) async {
    final project = writeProject('DdcMenuGame');
    final cache = DerivedDataCache(project.path);
    await tester.runAsync(() => cache.put(DerivedDataCache.sanitizedGlbBucket, 'barrel', barrel.readAsBytesSync()));
    expect(cache.entries(), hasLength(1));

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'DdcMenuGame'),
      projectLocation: temp.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await settle(tester);

    await tester.tap(find.text('Tools'));
    await settle(tester);
    expect(find.text('Clear Derived Data Cache'), findsOneWidget);
    await tester.tap(find.text('Clear Derived Data Cache'));
    await settle(tester);

    expect(cache.entries(), isEmpty);
    expect(find.text('Clear Derived Data Cache'), findsNothing, reason: 'the menu closed');
  }, skip: skip != null);

  test('Initialize Git Repository keeps DerivedDataCache/ out of the repository', () async {
    final git = await Process.run('git', ['--version']);
    if (git.exitCode != 0) return markTestSkipped('git is not installed');
    expect(GitService.defaultGitignore.split('\n').map((l) => l.trim()), contains('DerivedDataCache/'));

    final project = writeProject('DdcGitGame');
    final cache = DerivedDataCache(project.path);
    await cache.put(DerivedDataCache.sanitizedGlbBucket, 'barrel', barrel.readAsBytesSync());
    final svc = GitService(projectRoot: project.path, configOverrides: const ['-c', 'user.name=Lumina Test', '-c', 'user.email=test@lumina.invalid']);
    await svc.init(gitignoreContent: GitService.defaultGitignore, initialCommitMessage: 'Initial Lumina project');

    final tree = await Process.run('git', ['ls-tree', '-r', '--name-only', 'HEAD'], workingDirectory: project.path);
    expect(tree.stdout as String, contains('DdcGitGame.lmproject'));
    expect(tree.stdout as String, isNot(contains('DerivedDataCache')));
    expect((await svc.status()).map((s) => s.path).where((p) => p.contains('DerivedDataCache')), isEmpty);
  }, skip: skip);

  test('Cook & Package refuses a pubspec that would bundle DerivedDataCache/, before anything runs', () async {
    final project = writeProject('DdcCookGame');
    File('${project.path}/pubspec.yaml').writeAsStringSync('''
name: ddc_cook_game
flutter:
  assets:
    - contents/
    - DerivedDataCache/SanitizedGlb/
''');
    var spawned = 0;
    var generated = 0;
    final step = CookAndPackageStep(
      target: 'linux',
      configuration: BuildConfiguration.shipping,
      processStarter: (exe, args, {workingDirectory}) {
        spawned++;
        throw StateError('flutter build must not start');
      },
      codeGenerator: (ctx) async {
        generated++;
        return const CookCodeGenOutcome(true, 'generated');
      },
    );
    final events = <BuildEvent>[];
    final result = await step.execute(BuildStepContext(
      projectDir: project.path,
      project: const LuminaProject(projectName: 'DdcCookGame'),
      token: BuildCancellationToken(),
      kind: BuildStepKind.cookAndPackage,
      emit: events.add,
    ));

    expect(result.status, BuildStepStatus.failed);
    expect(result.message, allOf(contains('DerivedDataCache/SanitizedGlb/'), contains('pubspec.yaml')));
    expect(spawned, 0);
    expect(generated, 0);

    // The default asset list a new project gets passes the guard.
    File('${project.path}/pubspec.yaml').writeAsStringSync('''
name: ddc_cook_game
flutter:
  assets:
    - contents/
    - contents/meshes/static/
''');
    expect(CookAndPackageStep.derivedDataCacheLeak(project.path), isNull);
  });
}
