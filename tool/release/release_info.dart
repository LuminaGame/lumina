// Release and CI helper for the GitHub workflows (.github/workflows/).
//
// Pure `dart:io`: it runs with `dart tool/release/release_info.dart …` before
// the workspace is resolved, so it reads the pubspecs with a small
// line-based reader instead of package:yaml.
//
//   version --tag v1.2.3            Check the tag against lumina_ui's pubspec
//                                   version; print tag, version, msix_version
//                                   (msixVersion: Store-valid, increasing),
//                                   prerelease.
//   pins                            Print the commit SHA every sibling repo
//                                   (tools, plugins, marketplace) is pinned to
//                                   by the workspace pubspecs' git `ref:`s.
//   overrides [--out <file>]        Write the pubspec_overrides.yaml that
//                                   points every git dependency on a sibling
//                                   repo at its checkout next to this one
//                                   (../tools/…, ../plugins/…, ../marketplace/…).
//   filament-dir                    Print where the hooks look for Filament:
//                                   flutter_filament's `filament_dir`
//                                   user-define in the root pubspec (relative
//                                   to the repo root), else `filament`.
//
// Options: `--root <dir>` (default: the repo root above this script) and
// `--github-output` (also append `key=value` lines to $GITHUB_OUTPUT).
import 'dart:io';

const String _thisRepo = 'lumina';
const String _org = 'LuminaGame';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first == '-h' || args.first == '--help') {
    stdout.write(_usage);
    exit(args.isEmpty ? 64 : 0);
  }
  final command = args.first;
  final rest = args.skip(1).toList();
  String? option(String name) {
    final i = rest.indexOf(name);
    if (i == -1) return null;
    if (i + 1 >= rest.length) _fail('$name needs a value.', 64);
    return rest[i + 1];
  }

  final root = option('--root') ?? File.fromUri(Platform.script).parent.parent.parent.path;
  final githubOutput = rest.contains('--github-output');
  final Map<String, String> outputs;
  switch (command) {
    case 'version':
      final tag = option('--tag') ?? _fail('version needs --tag <tag>.', 64);
      outputs = checkVersion(tag, File('$root/lumina_ui/pubspec.yaml').readAsStringSync());
    case 'pins':
      outputs = pinnedRepos(root);
    case 'filament-dir':
      stdout.writeln(filamentDir(root));
      outputs = const {};
    case 'overrides':
      final out = option('--out') ?? '$root/pubspec_overrides.yaml';
      final text = siblingOverrides(root);
      File(out).writeAsStringSync(text);
      stdout.write(text);
      outputs = const {};
    case 'changelog':
      final tag = option('--tag') ?? _fail('changelog needs --tag <tag>.', 64);
      final fromTag = option('--from');
      final text = generateChangelog(root, tag, fromTag: fromTag);
      stdout.write(text);
      final out = option('--out');
      if (out != null) File(out).writeAsStringSync(text);
      outputs = const {};
    default:
      _fail('Unknown command "$command".\n\n$_usage', 64);
  }
  for (final e in outputs.entries) {
    stdout.writeln('${e.key}=${e.value}');
  }
  final path = Platform.environment['GITHUB_OUTPUT'];
  if (githubOutput && path != null && path.isNotEmpty && outputs.isNotEmpty) {
    File(path).writeAsStringSync(
      outputs.entries.map((e) => '${e.key}=${e.value}\n').join(),
      mode: FileMode.append,
    );
  }
}

const String _usage = '''
Usage: dart tool/release/release_info.dart <command> [options]

  version --tag <tag>      Check a release tag against lumina_ui/pubspec.yaml.
  pins                     Print the SHA each sibling repo is pinned to.
  overrides [--out <file>] Write pubspec_overrides.yaml for sibling checkouts.
  filament-dir             Print flutter_filament's filament_dir (repo-relative).
  changelog --tag <tag>    Generate categorized markdown release notes between tags.

Options: --root <dir>, --from <tag>, --out <file>, --github-output
''';

Never _fail(String message, [int code = 1]) {
  stderr.writeln(message);
  exit(code);
}

// ---------------------------------------------------------------- version

final RegExp _semver = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?$');

/// `v1.2.3[-pre]` against the pubspec's `version: 1.2.3[-pre][+build]`: the
/// build number is ignored, everything before it must match.
Map<String, String> checkVersion(String tag, String pubspecYaml) {
  if (!tag.startsWith('v')) _fail('The tag "$tag" does not start with "v" (expected v<major>.<minor>.<patch>).');
  final tagVersion = tag.substring(1);
  final t = _semver.firstMatch(tagVersion);
  if (t == null || t.group(5) != null) {
    _fail('The tag "$tag" is not v<major>.<minor>.<patch>[-<prerelease>].');
  }
  final m = RegExp(r'''^version:\s*['"]?([^\s'"#]+)''', multiLine: true).firstMatch(pubspecYaml);
  if (m == null) _fail('lumina_ui/pubspec.yaml has no version.');
  final pubspecVersion = m.group(1)!;
  final p = _semver.firstMatch(pubspecVersion);
  if (p == null) _fail('lumina_ui/pubspec.yaml version "$pubspecVersion" is not semantic.');
  final withoutBuild = pubspecVersion.split('+').first;
  if (withoutBuild != tagVersion) {
    _fail('Version mismatch: tag $tag, but lumina_ui/pubspec.yaml has version $pubspecVersion. '
        'Set "version: $tagVersion+<build>" in lumina_ui/pubspec.yaml, or tag v$withoutBuild.');
  }
  return {
    'tag': tag,
    'version': tagVersion,
    'msix_version': msixVersion(tagVersion),
    'prerelease': t.group(4) != null ? 'true' : 'false',
  };
}

/// The MSIX package version of [version] (`M.m.p[-dev.N|-rc.N]`), valid for
/// the Microsoft Store and strictly increasing with semver order — the same
/// scheme as lumina_ui's `storeMsixVersion` (lib/tooling/windows_packaging):
/// `(M+1).m.(p*1000 + s).0` with `s` = `N` for `dev.N` (1–499), `500+N` for
/// `rc.N` (1–498), `999` for a final release. The Store keeps the fourth
/// section for itself (0) and refuses a first section of 0, hence `M+1`.
String msixVersion(String version) {
  final m = _semver.firstMatch(version);
  if (m == null) _fail('"$version" is not a semantic version.');
  final major = int.parse(m.group(1)!), minor = int.parse(m.group(2)!), patch = int.parse(m.group(3)!);
  final pre = m.group(4);
  var stage = 999;
  if (pre != null) {
    final p = RegExp(r'^(dev|rc)\.(\d+)$').firstMatch(pre);
    if (p == null) _fail('"$version": only dev.N and rc.N pre-releases map to an MSIX version, got "-$pre".');
    final n = int.parse(p.group(2)!);
    final dev = p.group(1) == 'dev';
    if (n < 1 || n > (dev ? 499 : 498)) _fail('"$version": ${p.group(1)}.N must be 1–${dev ? 499 : 498} to map to an MSIX version.');
    stage = (dev ? 0 : 500) + n;
  }
  if (patch > 64) _fail('"$version": the patch number must be at most 64 to map to an MSIX version; raise the minor instead.');
  if (major + 1 > 65535 || minor > 65535) _fail('"$version": a version section exceeds 65535.');
  return '${major + 1}.$minor.${patch * 1000 + stage}.0';
}

// ---------------------------------------------------------------- pubspecs

/// A git dependency read from a pubspec.
class GitDependency {
  final String name;
  final String url;
  final String? path;
  final String? ref;
  final String pubspec;

  GitDependency(this.name, this.url, this.path, this.ref, this.pubspec);

  /// `tools` for `https://github.com/LuminaGame/tools.git`.
  String get repo {
    var u = url.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (u.endsWith('.git')) u = u.substring(0, u.length - 4);
    return u.split(RegExp(r'[/:]')).last;
  }

  bool get isLuminaRepo => url.contains('/$_org/') || url.contains(':$_org/');
}

String _scalar(String raw) {
  var v = raw.trim();
  if (v.startsWith('"') || v.startsWith("'")) {
    final q = v[0];
    final end = v.indexOf(q, 1);
    return end == -1 ? v.substring(1) : v.substring(1, end);
  }
  final hash = v.indexOf(' #');
  if (hash != -1) v = v.substring(0, hash);
  return v.trim();
}

/// The git dependencies in the `dependencies`, `dev_dependencies` and
/// `dependency_overrides` sections of [file] (block-style YAML, as pubspecs
/// are written).
List<GitDependency> gitDependencies(File file) {
  final lines = file.readAsLinesSync();
  final stack = <(int, String)>[];
  final found = <String, Map<String, String>>{};
  for (final line in lines) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    final m = RegExp(r'^(\s*)([A-Za-z0-9_.\-]+):(?:\s+(.*))?$').firstMatch(line);
    if (m == null) continue;
    final indent = m.group(1)!.length;
    final key = m.group(2)!;
    final value = m.group(3) == null ? '' : _scalar(m.group(3)!);
    while (stack.isNotEmpty && stack.last.$1 >= indent) {
      stack.removeLast();
    }
    final path = [for (final s in stack) s.$2, key];
    const sections = {'dependencies', 'dev_dependencies', 'dependency_overrides'};
    if (path.length >= 3 && sections.contains(path[0]) && path[2] == 'git') {
      final id = '${path[0]}/${path[1]}';
      final entry = found.putIfAbsent(id, () => {'name': path[1]});
      if (path.length == 3 && value.isNotEmpty) entry['url'] = value;
      if (path.length == 4) entry[path[3]] = value;
    }
    stack.add((indent, key));
  }
  return [
    for (final e in found.values)
      if (e['url'] != null) GitDependency(e['name']!, e['url']!, e['path'], e['ref'], file.path),
  ];
}

/// The workspace root and its members' pubspecs.
List<File> workspacePubspecs(String root) {
  final rootPubspec = File('$root/pubspec.yaml');
  final members = <String>[];
  var inWorkspace = false;
  for (final line in rootPubspec.readAsLinesSync()) {
    if (RegExp(r'^workspace:\s*$').hasMatch(line)) {
      inWorkspace = true;
      continue;
    }
    if (inWorkspace) {
      final m = RegExp(r'^\s+-\s+(.+?)\s*$').firstMatch(line);
      if (m != null) {
        members.add(_scalar(m.group(1)!));
      } else if (line.trim().isNotEmpty && !line.trimLeft().startsWith('#')) {
        inWorkspace = false;
      }
    }
  }
  return [rootPubspec, for (final m in members) File('$root/$m/pubspec.yaml')].where((f) => f.existsSync()).toList();
}

// ---------------------------------------------------------------- pins

final RegExp _sha = RegExp(r'^[0-9a-f]{40}$');

/// `{tools: <sha>, plugins: <sha>, marketplace: <sha>}` from the workspace
/// pubspecs. Every git dependency on a sibling repo must carry a full commit
/// SHA as `ref:`, and one repo must be pinned to one SHA everywhere.
Map<String, String> pinnedRepos(String root) {
  final pins = <String, Set<String>>{};
  final problems = <String>[];
  for (final pubspec in workspacePubspecs(root)) {
    for (final dep in gitDependencies(pubspec)) {
      if (!dep.isLuminaRepo || dep.repo == _thisRepo) continue;
      final ref = dep.ref;
      if (ref == null || !_sha.hasMatch(ref)) {
        problems.add('${_relative(root, dep.pubspec)}: ${dep.name} (${dep.repo}) is not pinned to a commit SHA '
            '(ref: ${ref ?? 'missing'}).');
        continue;
      }
      pins.putIfAbsent(dep.repo, () => {}).add(ref);
    }
  }
  pins.forEach((repo, shas) {
    if (shas.length > 1) problems.add('$repo is pinned to more than one commit: ${shas.join(', ')}.');
  });
  if (problems.isNotEmpty) _fail('Unpinned or inconsistent sibling repos:\n  - ${problems.join('\n  - ')}');
  return {for (final e in pins.entries) e.key: e.value.single};
}

String _relative(String root, String path) {
  final r = root.replaceAll(r'\', '/');
  final p = path.replaceAll(r'\', '/');
  return p.startsWith('$r/') ? p.substring(r.length + 1) : p;
}

// ---------------------------------------------------------------- overrides

/// The `pubspec_overrides.yaml` for sibling checkouts: every git dependency
/// on a sibling repo, followed through the checked-out packages (a tools
/// package depending on another tools package, …), becomes a path override.
String siblingOverrides(String root) {
  final overrides = <String, String>{};
  final queue = <File>[...workspacePubspecs(root)];
  final seen = <String>{};
  while (queue.isNotEmpty) {
    final pubspec = queue.removeAt(0);
    if (!seen.add(pubspec.absolute.path)) continue;
    for (final dep in gitDependencies(pubspec)) {
      if (!dep.isLuminaRepo || dep.repo == _thisRepo) continue;
      final rel = '../${dep.repo}${dep.path == null || dep.path!.isEmpty ? '' : '/${dep.path}'}';
      overrides.putIfAbsent(dep.name, () => rel);
      final checkout = File('$root/$rel/pubspec.yaml');
      if (!checkout.existsSync()) {
        _fail('${dep.name}: no checkout at ${checkout.path}. Check out ${dep.url} next to this repository.');
      }
      queue.add(checkout);
    }
  }
  final names = overrides.keys.toList()..sort();
  final b = StringBuffer()
    ..writeln('# Generated by tool/release/release_info.dart overrides: the sibling')
    ..writeln('# repos checked out next to this one instead of their git versions.')
    ..writeln('dependency_overrides:');
  for (final n in names) {
    b
      ..writeln('  $n:')
      ..writeln('    path: ${overrides[n]}');
  }
  return b.toString();
}

// ---------------------------------------------------------------- filament

/// flutter_filament's `filament_dir` user-define from the root pubspec
/// (`hooks: user_defines: flutter_filament: filament_dir:`), as written there
/// (relative to the repo root unless absolute); `filament` when unset, the
/// hook's own default.
String filamentDir(String root) {
  final stack = <(int, String)>[];
  for (final line in File('$root/pubspec.yaml').readAsLinesSync()) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    final m = RegExp(r'^(\s*)([A-Za-z0-9_.\-]+):(?:\s+(.*))?$').firstMatch(line);
    if (m == null) continue;
    final indent = m.group(1)!.length;
    while (stack.isNotEmpty && stack.last.$1 >= indent) {
      stack.removeLast();
    }
    final path = [for (final s in stack) s.$2, m.group(2)!];
    if (path.join('/') == 'hooks/user_defines/flutter_filament/filament_dir' && m.group(3) != null) {
      final value = _scalar(m.group(3)!);
      if (value.isNotEmpty) return value.startsWith('file:') ? Uri.parse(value).toFilePath() : value;
    }
    stack.add((indent, m.group(2)!));
  }
  return 'filament';
}

// ---------------------------------------------------------------- changelog

/// Generates categorized markdown release notes from git commits between tags.
String generateChangelog(String root, String tag, {String? fromTag}) {
  var prev = fromTag;
  if (prev == null || prev.isEmpty) {
    final res = Process.runSync(
      'git',
      // Only release tags: the Filament prebuilt tags (filament-*) sit in
      // between and would cut the range short.
      ['describe', '--tags', '--abbrev=0', '--match', 'v*', '$tag~1'],
      workingDirectory: root,
      runInShell: Platform.isWindows,
    );
    if (res.exitCode == 0) {
      prev = (res.stdout as String).trim();
    }
  }

  final range = (prev != null && prev.isNotEmpty) ? '$prev..$tag' : tag;
  final res = Process.runSync(
    'git',
    ['log', range, '--no-merges', '--pretty=format:%s'],
    workingDirectory: root,
    runInShell: Platform.isWindows,
  );

  final lines = (res.exitCode == 0 ? (res.stdout as String) : '')
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final features = <String>[];
  final fixes = <String>[];
  final others = <String>[];

  final featReg = RegExp(r'^feat(?:\(([^)]+)\))?:\s*(.*)$');
  final fixReg = RegExp(r'^fix(?:\(([^)]+)\))?:\s*(.*)$');

  for (final line in lines) {
    if (line.startsWith('chore(release):') || line.startsWith('chore(deps):')) {
      continue;
    }
    final featMatch = featReg.firstMatch(line);
    if (featMatch != null) {
      final scope = featMatch.group(1);
      final msg = featMatch.group(2)!;
      features.add(scope != null ? '**$scope**: $msg' : msg);
      continue;
    }
    final fixMatch = fixReg.firstMatch(line);
    if (fixMatch != null) {
      final scope = fixMatch.group(1);
      final msg = fixMatch.group(2)!;
      fixes.add(scope != null ? '**$scope**: $msg' : msg);
      continue;
    }
    others.add(line);
  }

  final buf = StringBuffer();
  buf.writeln("## What's Changed");
  buf.writeln();

  if (features.isNotEmpty) {
    buf.writeln('### New Features & Improvements');
    buf.writeln();
    for (final f in features) {
      buf.writeln('- $f');
    }
    buf.writeln();
  }

  if (fixes.isNotEmpty) {
    buf.writeln('### Bug Fixes');
    buf.writeln();
    for (final f in fixes) {
      buf.writeln('- $f');
    }
    buf.writeln();
  }

  if (others.isNotEmpty) {
    buf.writeln('### Other Changes');
    buf.writeln();
    for (final o in others) {
      buf.writeln('- $o');
    }
    buf.writeln();
  }

  return buf.toString();
}
