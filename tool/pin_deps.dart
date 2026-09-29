// Pins every cross-repo git dependency of this workspace's pubspecs to a
// commit SHA (`ref: <sha>`), or checks that they are pinned.
//
//   dart run tool/pin_deps.dart               # HEAD of each GitHub repo (git ls-remote)
//   dart run tool/pin_deps.dart --from-local  # HEAD of the sibling checkouts (../tools, …)
//   dart run tool/pin_deps.dart --check       # exit 1 when a dependency has no ref: SHA
//
// Options: --root <dir> (default: this script's repo), --remote-base <url>
// (default https://github.com/LuminaGame), --dry-run.
//
// A cross-repo dependency is a `git:` dependency whose url is
// `<remote-base>/<repo>.git` (or any github.com/LuminaGame/<repo>) for a
// repo other than this one (`lumina`). Only `ref:` lines are written: an
// existing one gets the new SHA, a missing one is added as the last key of
// the `git:` block; every other byte of the pubspec stays as it was. Run
// `flutter pub get` afterwards so pubspec.lock records the same commits.
import 'dart:io';

/// The GitHub organisation the repos live in.
const String defaultRemoteBase = 'https://github.com/LuminaGame';

/// This repo's own name: dependencies on it are not cross-repo.
const String selfRepo = 'lumina';

final RegExp _sha = RegExp(r'^[0-9a-f]{40}$');

/// A `git:` dependency found in a pubspec.
class GitDependency {
  /// The package name (the key above `git:`).
  final String name;

  /// The repo name taken from the url (`tools`), or null when the url is not
  /// a LuminaGame repo.
  final String? repo;

  final String url;

  /// The current `ref:` value, or null.
  final String? ref;

  /// Line indexes: the `git:` line, the url line, the ref line (or -1) and
  /// the last line of the block.
  final int gitLine, urlLine, refLine, lastLine;

  /// Whether the dependency uses the one-line form `git: <url>`, which has no
  /// room for a ref.
  final bool shortForm;

  const GitDependency({
    required this.name,
    required this.repo,
    required this.url,
    required this.ref,
    required this.gitLine,
    required this.urlLine,
    required this.refLine,
    required this.lastLine,
    this.shortForm = false,
  });

  bool get pinned => ref != null && _sha.hasMatch(ref!);
}

/// The repo name of a LuminaGame git [url] (also matching [remoteBase]).
String? repoOf(String url, {String remoteBase = defaultRemoteBase}) {
  final u = url.trim().replaceAll(RegExp(r'''^['"]|['"]$'''), '');
  final base = remoteBase.endsWith('/') ? remoteBase : '$remoteBase/';
  String? name;
  if (u.startsWith(base)) {
    name = u.substring(base.length);
  } else {
    final m = RegExp(r'github\.com[/:]LuminaGame/(.+)$').firstMatch(u);
    name = m?.group(1);
  }
  if (name == null) return null;
  name = name.replaceAll(RegExp(r'/+$'), '');
  if (name.endsWith('.git')) name = name.substring(0, name.length - 4);
  return name.isEmpty || name.contains('/') ? null : name;
}

String _value(String line) {
  var v = line.substring(line.indexOf(':') + 1);
  final hash = v.indexOf(' #');
  if (hash >= 0) v = v.substring(0, hash);
  return v.trim().replaceAll(RegExp(r'''^['"]|['"]$'''), '');
}

int _indent(String line) => line.length - line.trimLeft().length;

bool _blank(String line) => line.trim().isEmpty || line.trimLeft().startsWith('#');

/// The git dependencies under `dependencies:`, `dev_dependencies:` and
/// `dependency_overrides:` of the pubspec [lines].
List<GitDependency> findGitDependencies(List<String> lines, {String remoteBase = defaultRemoteBase}) {
  final out = <GitDependency>[];
  String? section;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_blank(line)) continue;
    if (_indent(line) == 0) {
      section = line.split(':').first.trim();
      continue;
    }
    if (section != 'dependencies' && section != 'dev_dependencies' && section != 'dependency_overrides') continue;
    final m = RegExp(r'^(\s+)git:\s*(.*)$').firstMatch(line);
    if (m == null) continue;
    final gitIndent = m.group(1)!.length;
    // The package key: the nearest line above with a smaller indent.
    var name = '';
    for (var k = i - 1; k >= 0; k--) {
      if (_blank(lines[k])) continue;
      if (_indent(lines[k]) < gitIndent) {
        name = lines[k].trim().split(':').first;
        break;
      }
    }
    final inline = m.group(2)!.split(' #').first.trim();
    if (inline.isNotEmpty) {
      final url = inline.replaceAll(RegExp(r'''^['"]|['"]$'''), '');
      out.add(GitDependency(
          name: name, repo: repoOf(url, remoteBase: remoteBase), url: url, ref: null,
          gitLine: i, urlLine: i, refLine: -1, lastLine: i, shortForm: true));
      continue;
    }
    var url = '', urlLine = -1, refLine = -1, last = i;
    String? ref;
    for (var k = i + 1; k < lines.length; k++) {
      if (_blank(lines[k])) continue;
      if (_indent(lines[k]) <= gitIndent) break;
      last = k;
      final key = lines[k].trim().split(':').first;
      if (key == 'url') {
        url = _value(lines[k]);
        urlLine = k;
      } else if (key == 'ref') {
        ref = _value(lines[k]);
        refLine = k;
      }
    }
    if (urlLine < 0) continue;
    out.add(GitDependency(
        name: name, repo: repoOf(url, remoteBase: remoteBase), url: url, ref: ref,
        gitLine: i, urlLine: urlLine, refLine: refLine, lastLine: last));
  }
  return out;
}

/// The cross-repo dependencies among [deps].
Iterable<GitDependency> crossRepo(Iterable<GitDependency> deps) => deps.where((d) => d.repo != null && d.repo != selfRepo);

/// [text] (a pubspec) with every cross-repo git dependency's `ref:` set to
/// `shaFor(repo)`; only ref lines change. Throws [FormatException] for a
/// one-line `git: <url>` dependency.
String pinPubspec(String text, String Function(String repo) shaFor, {String remoteBase = defaultRemoteBase}) {
  final nl = text.contains('\r\n') ? '\r\n' : '\n';
  final lines = text.split(nl);
  final deps = crossRepo(findGitDependencies(lines, remoteBase: remoteBase)).toList();
  // Bottom-up, so inserted lines do not shift the ones still to edit.
  for (final d in deps.reversed) {
    if (d.shortForm) {
      throw FormatException('${d.name}: the one-line form `git: <url>` cannot carry a ref; use the url:/path: form');
    }
    final sha = shaFor(d.repo!);
    if (d.refLine >= 0) {
      final old = lines[d.refLine];
      final m = RegExp(r'^(\s*ref:\s*)(\S+)(.*)$').firstMatch(old)!;
      final quote = RegExp(r'''^['"]''').hasMatch(m.group(2)!) ? m.group(2)![0] : '';
      lines[d.refLine] = '${m.group(1)}$quote$sha$quote${m.group(3)}';
    } else {
      lines.insert(d.lastLine + 1, '${' ' * _indent(lines[d.urlLine])}ref: $sha');
    }
  }
  return lines.join(nl);
}

/// The workspace pubspecs under [root]: the root one and each `workspace:`
/// member's.
List<File> workspacePubspecs(Directory root) {
  final rootPubspec = File('${root.path}/pubspec.yaml');
  final out = [rootPubspec];
  var inWorkspace = false;
  for (final line in rootPubspec.readAsLinesSync()) {
    if (_indent(line) == 0 && !_blank(line)) {
      inWorkspace = line.startsWith('workspace:');
      continue;
    }
    final m = RegExp(r'^\s*-\s*(.+?)\s*$').firstMatch(line);
    if (inWorkspace && m != null) {
      final f = File('${root.path}/${m.group(1)!.replaceAll(RegExp(r'''^['"]|['"]$'''), '')}/pubspec.yaml');
      if (f.existsSync()) out.add(f);
    }
  }
  return out;
}

Future<String> _gitOut(List<String> args, {String? cwd}) async {
  final r = await Process.run('git', args, workingDirectory: cwd, environment: const {'GIT_TERMINAL_PROMPT': '0'});
  if (r.exitCode != 0) throw StateError('git ${args.join(' ')} failed: ${'${r.stderr}'.trim()}');
  return '${r.stdout}'.trim();
}

/// The HEAD commit of the sibling checkout `<root>/../<repo>`.
Future<String> localHead(Directory root, String repo) =>
    _gitOut(['rev-parse', 'HEAD'], cwd: '${root.parent.path}${Platform.pathSeparator}$repo');

/// The HEAD commit of `<remoteBase>/<repo>.git`.
Future<String> remoteHead(String remoteBase, String repo) async {
  final base = remoteBase.endsWith('/') ? remoteBase.substring(0, remoteBase.length - 1) : remoteBase;
  final out = await _gitOut(['ls-remote', '$base/$repo.git', 'HEAD']);
  final sha = out.split(RegExp(r'\s+')).first;
  if (!_sha.hasMatch(sha)) throw StateError('$base/$repo.git has no HEAD');
  return sha;
}

/// The command line; returns the exit code.
Future<int> run(List<String> args, {StringSink? out, StringSink? err}) async {
  out ??= stdout;
  err ??= stderr;
  var fromLocal = false, check = false, dryRun = false;
  var remoteBase = defaultRemoteBase;
  Directory root = File.fromUri(Platform.script).parent.parent;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    String next() {
      if (i + 1 >= args.length) throw ArgumentError('$a needs a value');
      return args[++i];
    }

    switch (a) {
      case '--from-local':
        fromLocal = true;
      case '--check':
        check = true;
      case '--dry-run':
        dryRun = true;
      case '--root':
        root = Directory(next());
      case '--remote-base':
        remoteBase = next();
      case '-h' || '--help':
        out.writeln('usage: dart run tool/pin_deps.dart [--from-local | --check] [--root <dir>] [--remote-base <url>] [--dry-run]');
        return 0;
      default:
        err.writeln('Unknown option $a');
        return 64;
    }
  }
  if (!File('${root.path}/pubspec.yaml').existsSync()) {
    err.writeln('No pubspec.yaml in ${root.path}');
    return 66;
  }
  final pubspecs = workspacePubspecs(root);

  if (check) {
    var bad = 0;
    for (final f in pubspecs) {
      for (final d in crossRepo(findGitDependencies(f.readAsLinesSync(), remoteBase: remoteBase))) {
        if (d.pinned) continue;
        bad++;
        err.writeln('${f.path}: ${d.name} (${d.repo}) ${d.ref == null ? 'has no ref:' : 'ref ${d.ref} is not a commit SHA'}');
      }
    }
    if (bad > 0) {
      err.writeln('$bad cross-repo git dependenc${bad == 1 ? 'y is' : 'ies are'} not pinned; run tool/pin_deps.dart.');
      return 1;
    }
    out.writeln('Every cross-repo git dependency is pinned to a commit.');
    return 0;
  }

  final shas = <String, String>{};
  try {
    for (final f in pubspecs) {
      for (final d in crossRepo(findGitDependencies(f.readAsLinesSync(), remoteBase: remoteBase))) {
        final repo = d.repo!;
        if (shas.containsKey(repo)) continue;
        shas[repo] = fromLocal ? await localHead(root, repo) : await remoteHead(remoteBase, repo);
        out.writeln('$repo: ${shas[repo]}');
      }
    }
  } on StateError catch (e) {
    err.writeln(e.message);
    return 1;
  }

  var changed = 0;
  for (final f in pubspecs) {
    final before = f.readAsStringSync();
    final String after;
    try {
      after = pinPubspec(before, (repo) => shas[repo]!, remoteBase: remoteBase);
    } on FormatException catch (e) {
      err.writeln('${f.path}: ${e.message}');
      return 1;
    }
    if (after == before) continue;
    changed++;
    out.writeln('${dryRun ? 'would update' : 'updated'} ${f.path}');
    if (!dryRun) f.writeAsStringSync(after);
  }
  out.writeln(changed == 0 ? 'Already pinned.' : 'Run `flutter pub get` to update pubspec.lock.');
  return 0;
}

Future<void> main(List<String> args) async {
  exitCode = await run(args);
}
