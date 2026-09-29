import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/source_control/services/git_service.dart';
import 'package:lumina_ui/ui/features/source_control/view_models/source_control_view_model.dart';
import 'package:lumina_ui/ui/features/source_control/views/commit_dialog.dart';
import 'package:lumina_ui/ui/features/source_control/views/source_control_badge.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// View model + widget scenarios
/// over real git repositories in `Directory.systemTemp`.
const _identity = <String>[
  '-c', 'user.name=Lumina Test',
  '-c', 'user.email=test@lumina.local',
];

Future<bool> _hostHasGit() async {
  try {
    return (await Process.run('git', ['--version'])).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

Uint8List _binaryLmas(String name, int seed) => LuminaAsset(
      assetId: 'asset_$name',
      name: name,
      type: AssetType.filamesh,
      rawPayload: Uint8List.fromList(List<int>.generate(256, (i) => (i * seed) & 0xFF)),
    ).toProtoBufferBytes();

void main() {
  late bool hasGit;
  late Directory tempDir;
  late Directory projectDir;

  setUpAll(() async {
    hasGit = await _hostHasGit();
    if (!hasGit) {
      // ignore: avoid_print
      print('SKIPPED: git is not installed on this host; source control tests need the real CLI.');
    }
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_source_control_');
    projectDir = Directory('${tempDir.path}/ScProj')..createSync(recursive: true);
    File('${projectDir.path}/ScProj.lmproject').writeAsStringSync(
      jsonEncode(const LuminaProject(projectName: 'ScProj', activeLevel: 'contents/levels/L_Main.lmas').toMap()),
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void seed(Map<String, List<int>> files) {
    for (final e in files.entries) {
      final f = File('${projectDir.path}/${e.key}');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(e.value);
    }
  }

  Future<SourceControlViewModel> seededVm({
    required Map<String, List<int>> files,
    List<List<String>>? calls,
    void Function(String path)? onFileRestored,
  }) async {
    seed(files);
    final vm = SourceControlViewModel(
      projectRoot: projectDir.path,
      configOverrides: _identity,
      onFileRestored: onFileRestored,
      runner: calls == null
          ? null
          : (exe, args, {workingDirectory}) {
              calls.add(args);
              return Process.run(exe, args, workingDirectory: workingDirectory);
            },
    );
    await vm.service.init(gitignoreContent: GitService.defaultGitignore, initialCommitMessage: 'Initial Lumina project');
    await vm.refresh();
    return vm;
  }

  group('SourceControlViewModel', () {
    test('badge map: 1 modified + 1 untracked → exactly those states; empty after commit + refresh; rapid refresh is single-flight', () async {
      if (!hasGit) return;
      final calls = <List<String>>[];
      final vm = await seededVm(
        files: {'contents/meshes/SM_A.lmas': _binaryLmas('SM_A', 3)},
        calls: calls,
      );
      expect(vm.isAvailable, isTrue);
      expect(vm.isRepo, isTrue);
      expect(vm.changes, isEmpty);

      File('${projectDir.path}/contents/meshes/SM_A.lmas').writeAsBytesSync(_binaryLmas('SM_A', 5));
      File('${projectDir.path}/contents/meshes/SM_New.lmas').writeAsBytesSync(_binaryLmas('SM_New', 7));
      await vm.refresh();

      expect(vm.stateFor('contents/meshes/SM_A.lmas'), GitFileState.modified);
      expect(vm.stateFor('contents/meshes/SM_New.lmas'), GitFileState.untracked);
      expect(vm.stateFor('ScProj.lmproject'), isNull);
      expect(vm.changes.length, 2);
      expect(vm.folderState('contents/meshes'), isNotNull, reason: 'folder badges aggregate children');
      expect(vm.folderState('contents/levels'), isNull);

      final hash = await vm.commit(paths: ['contents/meshes/SM_A.lmas', 'contents/meshes/SM_New.lmas'], message: 'assets');
      expect(hash, isNotNull);
      expect(vm.lastError, isNull);
      await vm.refresh();
      expect(vm.changes, isEmpty);
      expect(vm.stateFor('contents/meshes/SM_A.lmas'), isNull);

      calls.clear();
      final f1 = vm.refresh();
      final f2 = vm.refresh();
      expect(identical(f1, f2), isTrue, reason: 'second call joins the in-flight refresh');
      await Future.wait([f1, f2]);
      final statusCalls = calls.where((a) => a.contains('status')).length;
      expect(statusCalls, 1, reason: 'two rapid refresh() calls run git status once');
    });

    test('changelists group Assets / Levels / Generated code / Project and the active level dirty marker tracks .lmas + L_*.dart', () async {
      if (!hasGit) return;
      final vm = await seededVm(files: {
        'contents/meshes/SM_A.lmas': _binaryLmas('SM_A', 3),
        'contents/levels/L_Main.lmas': utf8.encode('{"actors":[]}'),
        'lib/levels/l_main.dart': utf8.encode('// level\n'),
        'README.md': utf8.encode('# proj\n'),
      });
      expect(vm.isLevelDirty('L_Main'), isFalse);

      File('${projectDir.path}/contents/meshes/SM_A.lmas').writeAsBytesSync(_binaryLmas('SM_A', 5));
      File('${projectDir.path}/contents/levels/L_Main.lmas').writeAsStringSync('{"actors":[1]}');
      File('${projectDir.path}/lib/levels/l_main.dart').writeAsStringSync('// level 2\n');
      File('${projectDir.path}/README.md').writeAsStringSync('# proj 2\n');
      await vm.refresh();

      final groups = vm.groupedChanges;
      expect(groups.map((g) => g.title).toList(), ['Assets (.lmas)', 'Levels', 'Generated code (lib/)', 'Project']);
      expect(groups[0].entries.map((e) => e.path), ['contents/meshes/SM_A.lmas']);
      expect(groups[1].entries.map((e) => e.path), ['contents/levels/L_Main.lmas']);
      expect(groups[2].entries.map((e) => e.path), ['lib/levels/l_main.dart']);
      expect(groups[3].entries.map((e) => e.path), ['README.md']);
      expect(vm.isLevelDirty('L_Main'), isTrue);
      expect(vm.isLevelDirty('L_Other'), isFalse);

      await vm.commit(paths: ['contents/levels/L_Main.lmas'], message: 'level');
      await vm.refresh();
      expect(vm.isLevelDirty('L_Main'), isTrue, reason: 'generated l_main.dart still differs from HEAD');
      await vm.commit(paths: ['lib/levels/l_main.dart'], message: 'code');
      await vm.refresh();
      expect(vm.isLevelDirty('L_Main'), isFalse);
    });

    test('revert restores a modified file, fires the reload hook, and offers delete for untracked files', () async {
      if (!hasGit) return;
      final restored = <String>[];
      final vm = await seededVm(
        files: {'contents/meshes/SM_R.lmas': _binaryLmas('SM_R', 3)},
        onFileRestored: restored.add,
      );
      final original = File('${projectDir.path}/contents/meshes/SM_R.lmas').readAsBytesSync();
      File('${projectDir.path}/contents/meshes/SM_R.lmas').writeAsBytesSync(_binaryLmas('SM_R', 9));
      File('${projectDir.path}/contents/meshes/SM_U.lmas').writeAsBytesSync(_binaryLmas('SM_U', 9));
      await vm.refresh();
      expect(vm.stateFor('contents/meshes/SM_R.lmas'), GitFileState.modified);
      expect(vm.stateFor('contents/meshes/SM_U.lmas'), GitFileState.untracked);

      await vm.revert('contents/meshes/SM_R.lmas');
      expect(File('${projectDir.path}/contents/meshes/SM_R.lmas').readAsBytesSync(), original);
      expect(restored, ['contents/meshes/SM_R.lmas']);
      expect(vm.stateFor('contents/meshes/SM_R.lmas'), isNull, reason: 'revert refreshes the map');

      await vm.revert('contents/meshes/SM_U.lmas', deleteUntracked: true);
      expect(File('${projectDir.path}/contents/meshes/SM_U.lmas').existsSync(), isFalse);
      expect(restored, ['contents/meshes/SM_R.lmas', 'contents/meshes/SM_U.lmas']);
      expect(vm.changes, isEmpty);
    });

    test('a failing commit surfaces as lastError (GitException) instead of a crash', () async {
      if (!hasGit) return;
      final vm = await seededVm(files: {'contents/same.txt': utf8.encode('same\n')});
      final hash = await vm.commit(paths: ['contents/same.txt'], message: 'nothing');
      expect(hash, isNull);
      expect(vm.lastError, isNotNull);
      expect(vm.lastError, contains('commit'));
      expect(vm.lastCommitHash, isNull);
    });

    test('init prompt: shown for a project without .git, dismissal persists on disk, initRepository makes the initial commit', () async {
      if (!hasGit) return;
      seed({'contents/meshes/SM_A.lmas': _binaryLmas('SM_A', 3)});
      final vm = SourceControlViewModel(projectRoot: projectDir.path, configOverrides: _identity);
      await vm.refresh();
      expect(vm.isAvailable, isTrue);
      expect(vm.isRepo, isFalse);
      expect(vm.shouldPromptInit, isTrue);

      await vm.dismissInitPrompt();
      expect(vm.shouldPromptInit, isFalse);
      final again = SourceControlViewModel(projectRoot: projectDir.path, configOverrides: _identity);
      await again.refresh();
      expect(again.shouldPromptInit, isFalse, reason: 'dismissal persisted to disk');

      expect(await again.initRepository(), isTrue);
      expect(again.isRepo, isTrue);
      expect(again.changes, isEmpty, reason: 'initial commit captured every file');
      expect(File('${projectDir.path}/.gitignore').readAsStringSync(), contains('saved/'));
      expect(await again.service.headHashOf('ScProj.lmproject'), isNotNull);
      expect(again.shouldPromptInit, isFalse);
    });

    test('git absent: isAvailable false, no states, menu entries disabled with the install hint, no exception', () async {
      final vm = SourceControlViewModel(
        projectRoot: projectDir.path,
        runner: (exe, args, {workingDirectory}) => throw ProcessException(exe, args, 'No such file or directory', 2),
      );
      await vm.refresh();
      expect(vm.isAvailable, isFalse);
      expect(vm.isRepo, isFalse);
      expect(vm.shouldPromptInit, isFalse);
      expect(vm.stateFor('ScProj.lmproject'), isNull);
      expect(vm.changes, isEmpty);
      final entries = vm.menuEntries;
      expect(entries.map((e) => e.id), containsAll(['sourceControl.commit', 'sourceControl.history', 'sourceControl.refresh', 'sourceControl.initRepository']));
      for (final e in entries) {
        expect(e.enabled, isFalse, reason: '${e.id} must be disabled without git');
        expect(e.tooltip, SourceControlViewModel.installHint);
      }
      expect(await vm.commit(paths: ['x'], message: 'm'), isNull);
      expect(await vm.initRepository(), isFalse);
    });

    test('menu entries reflect repo state when git is present', () async {
      if (!hasGit) return;
      final vm = await seededVm(files: {'contents/a.txt': utf8.encode('a\n')});
      final byId = {for (final e in vm.menuEntries) e.id: e};
      expect(byId['sourceControl.commit']!.enabled, isTrue);
      expect(byId['sourceControl.refresh']!.enabled, isTrue);
      expect(byId['sourceControl.history']!.enabled, isTrue);
      expect(byId['sourceControl.initRepository']!.enabled, isFalse, reason: 'already a repository');
      expect(byId['sourceControl.initRepository']!.tooltip, isNot(SourceControlViewModel.installHint));
    });
  });

  group('EditorViewModel integration', () {
    test('registers the source control commands and refreshes badges after Save Level', () async {
      if (!hasGit) return;
      seed({'contents/levels/L_Main.lmas': utf8.encode('{"actors":[]}')});
      final vm = EditorViewModel(
        initialProject: const LuminaProject(projectName: 'ScProj', activeLevel: 'contents/levels/L_Main.lmas'),
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      );
      addTearDown(vm.dispose);
      for (final id in ['sourceControl.commit', 'sourceControl.history', 'sourceControl.refresh', 'sourceControl.initRepository']) {
        expect(vm.commands.byId(id), isNotNull, reason: '$id registered');
      }
      expect(vm.sourceControl.projectRoot, projectDir.path);

      await vm.sourceControl.service.init(gitignoreContent: GitService.defaultGitignore, initialCommitMessage: 'init');
      await vm.sourceControl.refresh();
      expect(vm.sourceControl.changes, isEmpty);

      vm.spawnNewActor('Mesh');
      await vm.saveLevelAndGenerateCode();
      // Save Level rewrites the level .lmas + generated lib/ code and triggers a badge refresh.
      await vm.sourceControl.whenIdle;
      expect(vm.sourceControl.stateFor('contents/levels/L_Main.lmas'), GitFileState.modified);
      expect(vm.sourceControl.stateFor('lib/levels/l_main.dart'), GitFileState.untracked);
      expect(vm.sourceControl.isLevelDirty('L_Main'), isTrue);
    });
  });

  group('Widgets', () {
    testWidgets('SourceControlBadge renders letter + colour per state and nothing for null (git absent)', (tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          theme: luminaEditorTheme(),
          home: const Column(
            children: [
              SourceControlBadge(state: GitFileState.modified, path: 'a'),
              SourceControlBadge(state: GitFileState.untracked, path: 'b'),
              SourceControlBadge(state: GitFileState.deleted, path: 'c'),
              SourceControlBadge(state: GitFileState.conflicted, path: 'd'),
              SourceControlBadge(state: null, path: 'e'),
            ],
          ),
        ),
      );
      expect(find.text('M'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.byKey(const ValueKey('sc_badge_a')), findsOneWidget);
      expect(find.byKey(const ValueKey('sc_badge_e')), findsNothing);
    });

    testWidgets('CommitDialog on a real temp repo: grouped headers, unchecking a row excludes it from the git argv, success shows the short hash', (tester) async {
      if (!hasGit) return;
      final calls = <List<String>>[];
      final vm = (await tester.runAsync(() => seededVm(
            files: {
              'contents/meshes/SM_A.lmas': _binaryLmas('SM_A', 3),
              'contents/levels/L_Main.lmas': utf8.encode('{"actors":[]}'),
              'lib/levels/l_main.dart': utf8.encode('// level\n'),
              'README.md': utf8.encode('# proj\n'),
            },
            calls: calls,
          )))!;
      File('${projectDir.path}/contents/meshes/SM_A.lmas').writeAsBytesSync(_binaryLmas('SM_A', 5));
      File('${projectDir.path}/contents/levels/L_Main.lmas').writeAsStringSync('{"actors":[1]}');
      File('${projectDir.path}/lib/levels/l_main.dart').writeAsStringSync('// level\n// more\n');
      File('${projectDir.path}/README.md').writeAsStringSync('# proj\nchanged\nagain\n');
      await tester.runAsync(() => vm.refresh());

      // Git work started from initState/tap must be born in the real zone
      // (runAsync); fake-zone futures cannot progress while runAsync waits.
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ShadcnApp(
            theme: luminaEditorTheme(),
            home: CommitDialog(viewModel: vm),
          ),
        );
        await vm.whenIdle;
      });
      await tester.pump();
      await tester.pump();

      for (final header in ['Assets (.lmas)', 'Levels', 'Generated code (lib/)', 'Project']) {
        expect(find.text(header), findsOneWidget, reason: 'group header $header');
      }
      expect(find.byKey(const ValueKey('sc_row_check_README.md')), findsOneWidget);
      // Binary summary for the .lmas, +n −m for the generated code.
      expect(find.textContaining('binary'), findsWidgets);
      expect(find.textContaining('+1 −0'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('sc_row_check_README.md')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('sc_commit_message')), 'Commit from dialog');
      await tester.pump();

      // Drop focus from the message box first so no cursor-blink timer is
      // (re)started in the real zone during the commit continuation.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      calls.clear();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('sc_commit_button')));
        await vm.whenIdle;
      });
      await tester.pump();

      final addCall = calls.firstWhere((a) => a.contains('add'));
      expect(addCall, isNot(contains('README.md')));
      expect(addCall, contains('contents/meshes/SM_A.lmas'));
      final commitCall = calls.firstWhere((a) => a.contains('commit'));
      expect(commitCall, isNot(contains('README.md')));
      expect(commitCall, contains('Commit from dialog'));
      expect(commitCall, isNot(contains('-A')));

      final hash = vm.lastCommitHash;
      expect(hash, isNotNull);
      expect(find.text('Committed ${hash!.substring(0, 7)}'), findsOneWidget, reason: 'inline result row');
      expect(find.textContaining(hash.substring(0, 7)), findsWidgets, reason: 'toast + result row');
      await tester.runAsync(() => vm.refresh());
      expect(vm.changes.map((c) => c.path), ['README.md']);
      // Let the success toast (5 s show duration) expire, then unmount the
      // tree so the focused TextArea's cursor timer is cancelled in dispose.
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
