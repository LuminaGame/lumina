import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/source_control/services/git_service.dart';

/// GitService scenarios.
///
/// Every scenario spawns the **real `git` CLI** against a repository created
/// in `Directory.systemTemp`. Identity is injected through
/// `-c user.name/-c user.email` overrides so fresh machines behave the same.
/// The whole file skips with a clear message when git is absent on the host.
const _identity = <String>[
  '-c', 'user.name=Lumina Test',
  '-c', 'user.email=test@lumina.local',
];

Future<ProcessResult> _git(String cwd, List<String> args) async {
  final r = await Process.run('git', [..._identity, ...args], workingDirectory: cwd);
  if (r.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed (${r.exitCode}): ${r.stderr}\n${r.stdout}');
  }
  return r;
}

Future<bool> _hostHasGit() async {
  try {
    final r = await Process.run('git', ['--version']);
    return r.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Binary `.lmas`-style payload: a real protobuf envelope with a NUL-bearing
/// raw payload so git's heuristic (and the generated `.gitattributes`) treat it
/// as binary.
Uint8List _binaryLmas(String name, int seed) {
  final asset = LuminaAsset(
    assetId: 'asset_$name',
    name: name,
    type: AssetType.filamesh,
    rawPayload: Uint8List.fromList(List<int>.generate(512, (i) => (i * seed) & 0xFF)),
  );
  return asset.toProtoBufferBytes();
}

void main() {
  late bool hasGit;
  late Directory tempDir;
  late Directory projectDir;

  setUpAll(() async {
    hasGit = await _hostHasGit();
    if (!hasGit) {
      // ignore: avoid_print
      print('SKIPPED: git is not installed on this host; GitService tests need the real CLI.');
    }
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_git_service_');
    projectDir = Directory('${tempDir.path}/GitProj')..createSync(recursive: true);
    File('${projectDir.path}/GitProj.lmproject').writeAsStringSync(
      jsonEncode(const LuminaProject(projectName: 'GitProj', activeLevel: 'contents/levels/L_Main.lmas').toMap()),
    );
    Directory('${projectDir.path}/contents/meshes').createSync(recursive: true);
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  GitService makeService({GitProcessRunner? runner}) =>
      GitService(projectRoot: projectDir.path, runner: runner, configOverrides: _identity);

  /// Seeds a repository through the service itself so the generated
  /// `.gitignore`/`.gitattributes` are part of the initial commit.
  Future<GitService> seededRepo(Map<String, List<int>> files) async {
    for (final e in files.entries) {
      final f = File('${projectDir.path}/${e.key}');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(e.value);
    }
    final svc = makeService();
    await svc.init(gitignoreContent: GitService.defaultGitignore, initialCommitMessage: 'Initial Lumina project');
    return svc;
  }

  group('GitService (real git CLI in temp repos)', () {
    test('init creates .git, the documented .gitignore and exactly one commit containing the .lmproject', () async {
      if (!hasGit) return;
      final svc = makeService();
      expect(await svc.isGitAvailable(), isTrue);
      expect(await svc.isRepository(), isFalse);

      await svc.init(gitignoreContent: GitService.defaultGitignore, initialCommitMessage: 'Initial Lumina project');

      expect(Directory('${projectDir.path}/.git').existsSync(), isTrue);
      final ignore = File('${projectDir.path}/.gitignore').readAsStringSync();
      for (final entry in ['build/', '.dart_tool/', 'saved/', '*.iml', '.flutter-plugins']) {
        expect(ignore, contains(entry), reason: '.gitignore must list $entry');
      }
      final count = await _git(projectDir.path, ['rev-list', '--count', 'HEAD']);
      expect((count.stdout as String).trim(), '1');
      final tree = await _git(projectDir.path, ['ls-tree', '-r', '--name-only', 'HEAD']);
      expect((tree.stdout as String).split('\n'), contains('GitProj.lmproject'));
      final subject = await _git(projectDir.path, ['log', '-1', '--format=%s']);
      expect((subject.stdout as String).trim(), 'Initial Lumina project');
      expect(await svc.isRepository(), isTrue);
    });

    test('status parses untracked, modified, deleted and renamed entries (NUL-split, space + ü intact)', () async {
      if (!hasGit) return;
      final svc = await seededRepo({
        'contents/meshes/SM_A.lmas': _binaryLmas('SM_A', 3),
        'contents/keep.txt': utf8.encode('keep\n'),
        'contents/old name ü.txt': utf8.encode('rename me\n'),
      });
      expect(await svc.status(), isEmpty, reason: 'clean right after the initial commit');

      File('${projectDir.path}/contents/new ü file.txt').writeAsStringSync('new\n');
      File('${projectDir.path}/contents/meshes/SM_A.lmas').writeAsBytesSync(_binaryLmas('SM_A', 7));
      File('${projectDir.path}/contents/keep.txt').deleteSync();
      await _git(projectDir.path, ['mv', 'contents/old name ü.txt', 'contents/renamed ü.txt']);

      final statuses = await svc.status();
      final byPath = {for (final s in statuses) s.path: s};
      expect(statuses.length, 4, reason: 'entries: ${statuses.map((s) => '${s.state.name}:${s.path}').join(', ')}');
      expect(byPath['contents/new ü file.txt']?.state, GitFileState.untracked);
      expect(byPath['contents/meshes/SM_A.lmas']?.state, GitFileState.modified);
      expect(byPath['contents/keep.txt']?.state, GitFileState.deleted);
      final renamed = byPath['contents/renamed ü.txt'];
      expect(renamed?.state, GitFileState.renamed);
      expect(renamed?.origPath, 'contents/old name ü.txt');
    });

    test('diffSummary reports +3 −1 for text and binary sizes for a modified .lmas', () async {
      if (!hasGit) return;
      final svc = await seededRepo({
        'contents/notes.txt': utf8.encode('A\nB\nC\nD\n'),
        'contents/meshes/SM_B.lmas': _binaryLmas('SM_B', 5),
      });
      File('${projectDir.path}/contents/notes.txt').writeAsStringSync('A\nB\nC\nE\nF\nG\n');
      final bigger = _binaryLmas('SM_B_longer_name_for_more_bytes', 9);
      File('${projectDir.path}/contents/meshes/SM_B.lmas').writeAsBytesSync(bigger);

      final text = await svc.diffSummary('contents/notes.txt');
      expect(text.isBinary, isFalse);
      expect(text.added, 3);
      expect(text.removed, 1);
      expect(text.label, '+3 −1');

      final bin = await svc.diffSummary('contents/meshes/SM_B.lmas');
      expect(bin.isBinary, isTrue);
      expect(bin.oldSize, greaterThan(0));
      expect(bin.newSize, greaterThan(0));
      expect(bin.newSize, bigger.length);
      expect(bin.label, startsWith('binary'));
    });

    test('commit stages exactly the given paths and returns the HEAD hash; empty message never touches git', () async {
      if (!hasGit) return;
      final svc = await seededRepo({
        'contents/a.txt': utf8.encode('a\n'),
        'contents/b.txt': utf8.encode('b\n'),
      });
      File('${projectDir.path}/contents/a.txt').writeAsStringSync('a2\n');
      File('${projectDir.path}/contents/b.txt').writeAsStringSync('b2\n');

      final hash = await svc.commit(paths: ['contents/a.txt'], message: 'only a');
      final head = await _git(projectDir.path, ['rev-parse', 'HEAD']);
      expect(hash, (head.stdout as String).trim());
      final shown = await _git(projectDir.path, ['show', '--name-only', '--format=', 'HEAD']);
      final committed = (shown.stdout as String).trim().split('\n');
      expect(committed, ['contents/a.txt']);

      final after = await svc.status();
      expect(after.map((s) => s.path), ['contents/b.txt']);
      expect(after.single.state, GitFileState.modified);

      final calls = <List<String>>[];
      final recording = GitService(
        projectRoot: projectDir.path,
        configOverrides: _identity,
        runner: (exe, args, {workingDirectory}) {
          calls.add(args);
          return Process.run(exe, args, workingDirectory: workingDirectory);
        },
      );
      await expectLater(
        () => recording.commit(paths: ['contents/b.txt'], message: '   '),
        throwsA(isA<ArgumentError>()),
      );
      expect(calls, isEmpty, reason: 'validation happens before any git call');
    });

    test('fileHistory follows renames newest-first and respects limit', () async {
      if (!hasGit) return;
      final svc = await seededRepo({'contents/h.txt': utf8.encode('v1\n')});
      File('${projectDir.path}/contents/h.txt').writeAsStringSync('v2\n');
      await svc.commit(paths: ['contents/h.txt'], message: 'edit h');
      await _git(projectDir.path, ['mv', 'contents/h.txt', 'contents/h2.txt']);
      await _git(projectDir.path, ['commit', '-m', 'rename h']);

      final history = await svc.fileHistory('contents/h2.txt');
      expect(history.map((e) => e.subject).toList(), ['rename h', 'edit h', 'Initial Lumina project']);
      expect(history.first.author, 'Lumina Test');
      expect(history.first.abbrevHash.length, 7);
      expect(history.first.date.isAfter(DateTime(2020)), isTrue);

      final limited = await svc.fileHistory('contents/h2.txt', limit: 2);
      expect(limited.length, 2);
    });

    test('restoreFile brings a modified committed file back to HEAD bytes (verified through git)', () async {
      if (!hasGit) return;
      final svc = await seededRepo({'contents/meshes/SM_R.lmas': _binaryLmas('SM_R', 11)});
      final path = '${projectDir.path}/contents/meshes/SM_R.lmas';
      File(path).writeAsBytesSync(_binaryLmas('SM_R', 13));
      expect((await svc.status()).single.state, GitFileState.modified);

      await svc.restoreFile('contents/meshes/SM_R.lmas');

      expect(await svc.status(), isEmpty);
      final headBytes = await Process.run(
        'git', [..._identity, 'show', 'HEAD:contents/meshes/SM_R.lmas'],
        workingDirectory: projectDir.path, stdoutEncoding: null,
      );
      expect(headBytes.exitCode, 0);
      expect(File(path).readAsBytesSync(), headBytes.stdout as List<int>);
      expect(await svc.headHashOf('contents/meshes/SM_R.lmas'), isNotNull);
      expect(await svc.headHashOf('contents/does_not_exist.txt'), isNull);
    });

    test('GitException carries command, exit code and stderr for a failing commit', () async {
      if (!hasGit) return;
      final svc = await seededRepo({'contents/same.txt': utf8.encode('same\n')});
      try {
        await svc.commit(paths: ['contents/same.txt'], message: 'nothing changed');
        fail('expected GitException');
      } on GitException catch (e) {
        expect(e.command, contains('commit'));
        expect(e.exitCode, isNot(0));
        expect(e.stderr, isNotEmpty);
        expect(e.toString(), contains('git'));
      }
    });

    test('git absent (runner seam throws ENOENT): isGitAvailable false, isRepository false, status empty, no throw', () async {
      final svc = makeService(
        runner: (exe, args, {workingDirectory}) =>
            throw ProcessException(exe, args, 'No such file or directory', 2),
      );
      expect(await svc.isGitAvailable(), isFalse);
      expect(await svc.isRepository(), isFalse);
      expect(await svc.status(), isEmpty);
    });
  });
}
