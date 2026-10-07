import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/source_control/services/git_service.dart';
import 'package:lumina_ui/ui/features/source_control/view_models/source_control_view_model.dart';
import 'package:lumina_ui/ui/features/source_control/views/commit_dialog.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The commit dialog on a real temp git repository with
/// 2 000 changed and untracked files: it opens at once, grouped by folder
/// (big folders collapsed) and counted from the status the view model
/// already has; summaries arrive in a couple of batched git processes and
/// one Output Log line; closing mid-load cancels the rest; committing
/// everything is one `git add --pathspec-from-file` and one `git commit`.
const _identity = <String>['-c', 'user.name=Lumina Test', '-c', 'user.email=test@lumina.local'];

Uint8List _binary(int seed) => Uint8List.fromList([0, 1, 2, 0, ...List<int>.generate(96, (i) => (i * seed + 7) & 0xFF)]);

/// A refreshed view model on a fresh one-file repository under [temp]: the
/// warm-up for the first-frame timing.
Future<SourceControlViewModel> _oneChangeViewModel(Directory temp) async {
  final root = Directory('${temp.path}/WarmUp')..createSync(recursive: true);
  File('${root.path}/WarmUp.lmproject').writeAsStringSync('{}');
  await GitService(projectRoot: root.path, configOverrides: _identity)
      .init(gitignoreContent: GitService.defaultGitignore, initialCommitMessage: 'Warm-up');
  File('${root.path}/notes.txt').writeAsStringSync('one change\n');
  final vm = SourceControlViewModel(projectRoot: root.path, configOverrides: _identity);
  await vm.refresh();
  expect(vm.changes, hasLength(1));
  return vm;
}

void main() {
  late bool hasGit;
  late Directory temp;
  late String root;

  /// Folder → (tracked-then-modified count, untracked count).
  const layout = <String, (int, int)>{
    'contents/animations': (600, 600), // 1 200 → collapsed
    'contents/audio': (0, 40),
    'contents/meshes': (300, 0),
    'contents/levels': (60, 0),
    'lib/gen': (300, 0),
    'notes': (0, 100),
  };

  String fileName(String folder, int i, {required bool tracked}) {
    final text = folder.startsWith('lib/') || folder.startsWith('notes') || folder.endsWith('levels');
    final ext = folder.startsWith('lib/') ? 'dart' : (text ? 'txt' : 'lmas');
    return '$folder/${tracked ? 'T' : 'N'}_$i.$ext';
  }

  setUpAll(() async {
    try {
      hasGit = (await Process.run('git', ['--version'])).exitCode == 0;
    } on ProcessException {
      hasGit = false;
    }
  });

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('lumina_sc_large_');
    root = '${temp.path}/BigChange';
    Directory(root).createSync(recursive: true);
    File('$root/BigChange.lmproject').writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'BigChange').toMap()));
    if (!hasGit) return;
    // Tracked files, committed once.
    layout.forEach((folder, counts) {
      Directory('$root/$folder').createSync(recursive: true);
      for (var i = 0; i < counts.$1; i++) {
        final f = File('$root/${fileName(folder, i, tracked: true)}');
        f.path.endsWith('.lmas') ? f.writeAsBytesSync(_binary(i)) : f.writeAsStringSync('line a $i\nline b\n');
      }
    });
    final svc = GitService(projectRoot: root, configOverrides: _identity);
    await svc.init(gitignoreContent: GitService.defaultGitignore, initialCommitMessage: 'Initial Lumina project');
    // Then 1 260 modified and 740 untracked: 2 000 changes.
    layout.forEach((folder, counts) {
      for (var i = 0; i < counts.$1; i++) {
        final f = File('$root/${fileName(folder, i, tracked: true)}');
        f.path.endsWith('.lmas') ? f.writeAsBytesSync(_binary(i + 1000)) : f.writeAsStringSync('line a $i\nline b\nline c\n');
      }
      for (var i = 0; i < counts.$2; i++) {
        final f = File('$root/${fileName(folder, i, tracked: false)}');
        f.path.endsWith('.lmas') ? f.writeAsBytesSync(_binary(i + 5000)) : f.writeAsStringSync('new $i\n');
      }
    });
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// A view model whose git runner records every argv and holds `git diff`
  /// until [gate] completes (when given).
  ({SourceControlViewModel vm, List<List<String>> calls}) viewModel({Completer<void>? gate}) {
    final calls = <List<String>>[];
    final vm = SourceControlViewModel(
      projectRoot: root,
      configOverrides: _identity,
      runner: (exe, args, {workingDirectory}) async {
        calls.add(args);
        if (gate != null && args.contains('diff')) await gate.future;
        return Process.run(exe, args, workingDirectory: workingDirectory);
      },
    );
    return (vm: vm, calls: calls);
  }

  Widget dialog(SourceControlViewModel vm) => ShadcnApp(
        theme: luminaEditorTheme(),
        home: Center(child: SizedBox(width: 780, height: 520, child: CommitDialog(viewModel: vm))),
      );

  /// Lets real async work run (inside runAsync) until [done] holds.
  Future<void> waitFor(WidgetTester tester, bool Function() done) => tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (!done() && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }).then((_) => expect(done(), isTrue, reason: 'timed out waiting'));

  testWidgets('2 000 changes: the dialog opens at once with a progress bar, grouped and counted before any summary; '
      'summaries arrive in ≤ 5 git processes and one log line', (tester) async {
    if (!hasGit) return markTestSkipped('git is not installed');
    final gate = Completer<void>();
    final (:vm, :calls) = viewModel(gate: gate);
    await tester.runAsync(vm.refresh);
    expect(vm.changes, hasLength(2000));
    final logsBefore = EngineLoggerService().logs.length;
    calls.clear();

    // The app shell first (theme, fonts): its first frame is not the dialog's.
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: const SizedBox.shrink()));
    // Then the dialog once on a one-file repository: the first build
    // of CommitDialog JIT-compiles its code, ~200 ms of one-time cost that
    // does not depend on the change set and that a loaded machine (the full
    // suite runs files in parallel) stretched past the budget. What the
    // budget guards is the 2 000-change work itself — grouping, counting,
    // the first list frame — which a warmed open measures on its own.
    final warmUp = (await tester.runAsync(() => _oneChangeViewModel(temp)))!;
    await tester.runAsync(() => tester.pumpWidget(dialog(warmUp)));
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: const SizedBox.shrink()));
    final watch = Stopwatch()..start();
    await tester.runAsync(() => tester.pumpWidget(dialog(vm)));
    watch.stop();
    // ignore: avoid_print
    print('[source_control] dialog open with 2 000 changes: ${watch.elapsedMilliseconds} ms (first frame)');
    expect(watch.elapsedMilliseconds, lessThan(500), reason: 'opens without waiting for git');

    // The first frame: the progress bar (indeterminate while git status
    // runs) and the list, grouped and counted from the status already known.
    expect(find.byKey(const ValueKey('sc_commit_progress')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('sc_commit_progress_label'))).data, 'Reading git status…');
    expect(tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('sc_commit_progress'))).value, isNull);
    expect(find.text('2000 changed · 2000 selected'), findsOneWidget);
    expect(find.text('Assets (.lmas)'), findsOneWidget);
    expect(find.text('contents/animations/'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('sc_folder_count_Assets (.lmas)|contents/animations'))).data, '1200 / 1200');
    expect(find.byKey(ValueKey('sc_row_check_${fileName('contents/animations', 0, tracked: true)}')), findsNothing,
        reason: 'a folder with > 50 changes starts collapsed');
    final audioRow = fileName('contents/audio', 0, tracked: false);
    expect(find.byKey(ValueKey('sc_row_check_$audioRow')), findsOneWidget, reason: 'a small folder is open');

    // Status done, untracked sizes (stat) in, git diff still held back: the
    // bar turns determinate — "Loading changes 740 / 2000".
    // Also wait until the loader has reached the gated `git diff`:
    // its next step is a real-zone timer, and if it has not run when this
    // returns it would first run inside the final runAsync, where on Windows
    // the git process's result was intermittently never delivered.
    await waitFor(tester, () => vm.summariesDone >= 740 && calls.any((a) => a.contains('diff')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const ValueKey('sc_commit_progress_label'))).data, 'Loading changes 740 / 2000');
    expect(tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('sc_commit_progress'))).value, closeTo(0.37, 0.001));
    expect(tester.widget<Text>(find.byKey(ValueKey('sc_row_summary_$audioRow'))).data, startsWith('new file'));
    expect(vm.summaryFor(fileName('contents/meshes', 0, tracked: true)), isNull, reason: 'git diff is still gated');

    // Select-all per folder: unchecking the folder header unchecks its 40 rows.
    await tester.tap(find.byKey(const ValueKey('sc_folder_check_Assets (.lmas)|contents/audio')));
    await tester.pump();
    expect(find.text('2000 changed · 1960 selected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sc_folder_check_Assets (.lmas)|contents/audio')));
    await tester.pump();
    expect(find.text('2000 changed · 2000 selected'), findsOneWidget);

    // Release git: the summaries arrive.
    await tester.runAsync(() async {
      gate.complete();
      await vm.whenIdle;
    });
    await tester.pump();
    final gitDuringLoad = calls.where((a) => !a.contains('--version')).toList();
    expect(gitDuringLoad.length, lessThanOrEqualTo(5), reason: gitDuringLoad.map((a) => a.join(' ')).join('\n'));
    expect(gitDuringLoad.where((a) => a.contains('rev-list') || a.contains('--no-index') || a.contains('cat-file')), isEmpty);
    for (final c in vm.changes) {
      expect(vm.summaryFor(c.path), isNotNull, reason: c.path);
    }
    expect(vm.summaryFor(fileName('contents/meshes', 3, tracked: true))!.isBinary, isTrue);
    expect(vm.summaryFor(fileName('contents/meshes', 3, tracked: true))!.oldSize, 100, reason: 'HEAD size from one ls-tree');
    expect(vm.summaryFor(fileName('lib/gen', 3, tracked: true))!.label, '+1 −0');
    expect(vm.summaryFor(fileName('notes', 3, tracked: false))!.label, startsWith('new file'));
    expect(find.byKey(const ValueKey('sc_commit_progress')), findsNothing, reason: 'the bar goes when everything is in');

    final newLogs = EngineLoggerService().logs.skip(logsBefore).toList();
    expect(newLogs.length, lessThanOrEqualTo(3), reason: newLogs.map((l) => l.message).join('\n'));
    expect(newLogs.where((l) => l.message.startsWith('SourceControl: diff summaries for 2000 files')), hasLength(1));

    // The filter narrows the list to matching paths (open, whatever the folder size).
    await tester.enterText(find.byKey(const ValueKey('sc_commit_filter')).last, 'T_599.lmas');
    await tester.pump();
    expect(find.byKey(ValueKey('sc_row_check_${fileName('contents/animations', 599, tracked: true)}')), findsOneWidget);
    expect(find.byKey(ValueKey('sc_row_check_$audioRow')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    vm.dispose();
  });

  testWidgets('frames keep coming while a 2 000-file status + summary load runs: the UI isolate never blocks', (tester) async {
    if (!hasGit) return markTestSkipped('git is not installed');
    final (:vm, :calls) = viewModel();
    var maxGapMs = 0;
    var ticks = 0;
    var barInFirstFrame = false;
    await tester.runAsync(() async {
      // Opened before any status is known: the progress bar is in the first frame.
      await tester.pumpWidget(dialog(vm));
      barInFirstFrame = find.byKey(const ValueKey('sc_commit_progress')).evaluate().isNotEmpty;
      // A frame-rate timer on the UI isolate: any long synchronous stretch
      // (a blocking process, a big parse, a per-file loop) shows as a gap.
      var last = DateTime.now();
      final timer = Timer.periodic(const Duration(milliseconds: 8), (_) {
        final now = DateTime.now();
        final gap = now.difference(last).inMilliseconds;
        if (gap > maxGapMs) maxGapMs = gap;
        last = now;
        ticks++;
      });
      await vm.whenIdle;
      timer.cancel();
    });
    expect(barInFirstFrame, isTrue, reason: 'progress bar in the first frame');
    await tester.pump();
    // ignore: avoid_print
    print('[source_control] status + summaries for ${vm.changes.length} files: $ticks timer ticks, longest UI-isolate gap $maxGapMs ms');
    expect(vm.changes, hasLength(2000));
    expect(vm.summariesDone, 2000);
    expect(maxGapMs, lessThan(100), reason: 'the event loop kept turning');
    await tester.pumpWidget(const SizedBox.shrink());
    vm.dispose();
  });

  testWidgets('closing the dialog mid-load cancels the outstanding summary work', (tester) async {
    if (!hasGit) return markTestSkipped('git is not installed');
    final gate = Completer<void>();
    final (:vm, :calls) = viewModel(gate: gate);
    await tester.runAsync(vm.refresh);
    calls.clear();
    final logsBefore = EngineLoggerService().logs.length;
    await tester.runAsync(() => tester.pumpWidget(dialog(vm)));
    await waitFor(tester, () => vm.summariesDone >= 740 && calls.any((a) => a.contains('diff'))); // git diff is running (gated)
    expect(vm.summariesLoading, isTrue);

    // Close while `git diff` is running.
    await tester.pumpWidget(const SizedBox.shrink());
    expect(vm.summariesLoading, isFalse);
    await tester.runAsync(() async {
      gate.complete();
      await vm.whenIdle;
    });
    expect(calls.where((a) => a.contains('ls-tree')), isEmpty, reason: 'no git process started after the close');
    expect(vm.summaryFor(fileName('contents/meshes', 0, tracked: true)), isNull, reason: 'no row filled in after the close');
    expect(EngineLoggerService().logs.skip(logsBefore).where((l) => l.message.startsWith('SourceControl: diff summaries')), isEmpty);
    vm.dispose();
  });

  test('committing all 2 000 files is one git add --pathspec-from-file and one git commit, and it succeeds', () async {
    if (!hasGit) return markTestSkipped('git is not installed');
    final (:vm, :calls) = viewModel();
    await vm.refresh();
    final paths = [for (final c in vm.changes) c.path]..sort();
    expect(paths, hasLength(2000));
    calls.clear();
    final steps = <String>[];
    void listener() {
      if (vm.commitStep != null && (steps.isEmpty || steps.last != vm.commitStep)) steps.add(vm.commitStep!);
    }
    vm.addListener(listener);
    final hash = await vm.commit(paths: paths, message: 'Commit 2000 files');
    vm.removeListener(listener);
    expect(hash, isNotNull, reason: vm.lastError);
    expect(steps, containsAllInOrder(['Staging', 'Committing', 'Refreshing status']), reason: 'the dialog\'s "Committing 2000 files…" bar');
    final adds = calls.where((a) => a.contains('add')).toList();
    final commits = calls.where((a) => a.contains('commit')).toList();
    expect(adds, hasLength(1));
    expect(commits, hasLength(1));
    expect(adds.single.any((a) => a.startsWith('--pathspec-from-file=')), isTrue);
    expect(commits.single.any((a) => a.startsWith('--pathspec-from-file=')), isTrue);
    expect(adds.single.length, lessThan(20), reason: 'no path on the command line');
    expect(calls.where((a) => a.contains('rm')), isEmpty, reason: 'every path exists');
    expect(vm.changes, isEmpty, reason: 'working tree clean after the commit');
    final count = await Process.run('git', ['show', '--name-only', '--format=', 'HEAD'], workingDirectory: root);
    expect(LineSplitter.split(count.stdout as String).where((l) => l.isNotEmpty), hasLength(2000));
    vm.dispose();
  });
}
