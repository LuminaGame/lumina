import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../../tool/pin_deps.dart' as pin;

/// tool/pin_deps.dart on copies of this workspace's pubspecs, with real git
/// sibling repos (and bare "remotes") in the system temp folder.
void main() {
  // flutter test runs in the package root (lumina/); the repo root is its parent.
  final repoRoot = Directory.current.parent.path;
  late Directory temp;
  late Directory root;
  late Map<String, String> heads;
  final repos = ['tools', 'plugins', 'marketplace'];

  Future<String> git(List<String> args, String cwd) async {
    final r = await Process.run('git', args, workingDirectory: cwd, environment: {
      'GIT_AUTHOR_NAME': 'Lumina Test',
      'GIT_COMMITTER_NAME': 'Lumina Test',
      'GIT_AUTHOR_EMAIL': 'test@lumina.invalid',
      'GIT_COMMITTER_EMAIL': 'test@lumina.invalid',
    });
    if (r.exitCode != 0) fail('git ${args.join(' ')}: ${r.stderr}');
    return '${r.stdout}'.trim();
  }

  Map<String, String> snapshot() => {for (final f in pin.workspacePubspecs(root)) f.path: f.readAsStringSync()};

  String withoutRefs(String s) => s.split('\n').where((l) => !RegExp(r'^\s+ref: ').hasMatch(l)).join('\n');

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('pin_deps_');
    root = Directory(p.join(temp.path, 'lumina'))..createSync();
    File(p.join(repoRoot, 'pubspec.yaml')).copySync(p.join(root.path, 'pubspec.yaml'));
    for (final f in pin.workspacePubspecs(Directory(repoRoot)).skip(1)) {
      final rel = p.relative(f.path, from: repoRoot);
      File(p.join(root.path, rel)).parent.createSync(recursive: true);
      f.copySync(p.join(root.path, rel));
    }
    heads = {};
    for (final repo in repos) {
      final dir = Directory(p.join(temp.path, repo))..createSync();
      File(p.join(dir.path, 'README.md')).writeAsStringSync(repo);
      await git(['init', '-q', '-b', 'main'], dir.path);
      await git(['add', '.'], dir.path);
      await git(['commit', '-q', '-m', repo], dir.path);
      heads[repo] = await git(['rev-parse', 'HEAD'], dir.path);
      await git(['clone', '-q', '--bare', dir.path, p.join(temp.path, 'remotes', '$repo.git')], temp.path);
    }
  });

  tearDown(() {
    if (Platform.isWindows) Process.runSync('attrib', ['-R', '${temp.path}\\*', '/S', '/D'], runInShell: true);
    temp.deleteSync(recursive: true);
  });

  test('the workspace copies have cross-repo git dependencies and --check rejects them unpinned', () async {
    final deps = [
      for (final f in pin.workspacePubspecs(root)) ...pin.crossRepo(pin.findGitDependencies(f.readAsLinesSync())),
    ];
    expect(deps.map((d) => d.repo).toSet(), containsAll(repos));
    final err = StringBuffer();
    expect(await pin.run(['--check', '--root', root.path], out: StringBuffer(), err: err), 1);
    expect(err.toString(), contains('has no ref:'));
  });

  test('--from-local pins every dependency to the sibling HEAD, touching only ref lines', () async {
    final before = snapshot();
    final out = StringBuffer();
    expect(await pin.run(['--from-local', '--root', root.path], out: out, err: StringBuffer()), 0);
    final after = snapshot();
    for (final path in before.keys) {
      expect(withoutRefs(after[path]!), withoutRefs(before[path]!), reason: '$path: only ref lines differ');
      for (final d in pin.crossRepo(pin.findGitDependencies(after[path]!.split('\n')))) {
        expect(d.ref, heads[d.repo], reason: '${d.name} in $path');
        final lines = after[path]!.split('\n');
        expect(lines[d.refLine].indexOf('ref:'), lines[d.urlLine].indexOf('url:'), reason: 'same indent as url:');
      }
    }
    expect(await pin.run(['--check', '--root', root.path], out: StringBuffer(), err: StringBuffer()), 0);

    // Idempotent.
    expect(await pin.run(['--from-local', '--root', root.path], out: StringBuffer(), err: StringBuffer()), 0);
    expect(snapshot(), after);
  });

  test('the default mode asks the remotes (git ls-remote) and replaces existing refs', () async {
    await pin.run(['--from-local', '--root', root.path], out: StringBuffer(), err: StringBuffer());
    final pinned = snapshot();
    // New commits on the remotes.
    final newHeads = <String, String>{};
    for (final repo in repos) {
      final dir = p.join(temp.path, repo);
      File(p.join(dir, 'CHANGELOG.md')).writeAsStringSync('next');
      await git(['add', '.'], dir);
      await git(['commit', '-q', '-m', 'next'], dir);
      await git(['push', '-q', p.join(temp.path, 'remotes', '$repo.git'), 'main'], dir);
      newHeads[repo] = await git(['rev-parse', 'HEAD'], dir);
    }
    final base = Uri.directory(p.join(temp.path, 'remotes')).toString();
    // The copies name github.com/LuminaGame; the remote base is only where the SHAs come from.
    expect(await pin.run(['--root', root.path, '--remote-base', base], out: StringBuffer(), err: StringBuffer()), 0);
    final after = snapshot();
    for (final path in after.keys) {
      expect(after[path]!.split('\n').length, pinned[path]!.split('\n').length, reason: 'refs replaced, none added');
      for (final d in pin.crossRepo(pin.findGitDependencies(after[path]!.split('\n')))) {
        expect(d.ref, newHeads[d.repo]);
      }
    }
  });

  test('--dry-run writes nothing; a one-line git dependency is refused', () async {
    final before = snapshot();
    expect(await pin.run(['--from-local', '--dry-run', '--root', root.path], out: StringBuffer(), err: StringBuffer()), 0);
    expect(snapshot(), before);

    const oneLine = 'name: x\ndependencies:\n  flutter_assimp:\n    git: https://github.com/LuminaGame/tools.git\n';
    expect(() => pin.pinPubspec(oneLine, (_) => 'a' * 40), throwsFormatException);
  });

  test('keeps CRLF, comments, quotes and non-cross-repo git dependencies as they are', () {
    const text = 'name: x\r\n'
        'dependencies:\r\n'
        '  flutter_assimp:\r\n'
        '    git:\r\n'
        '      url: https://github.com/LuminaGame/tools.git # tools\r\n'
        '      path: flutter_assimp\r\n'
        "      ref: 'main' # moving\r\n"
        '  lumina:\r\n'
        '    git:\r\n'
        '      url: https://github.com/LuminaGame/lumina.git\r\n'
        '      path: lumina\r\n'
        '  other:\r\n'
        '    git:\r\n'
        '      url: https://example.com/other.git\r\n'
        'flutter:\r\n'
        '  uses-material-design: true\r\n';
    final sha = 'b' * 40;
    final out = pin.pinPubspec(text, (_) => sha);
    expect(out, text.replaceFirst("ref: 'main' # moving", "ref: '$sha' # moving"));
  });
}
