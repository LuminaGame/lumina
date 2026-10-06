import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'workspace_paths.dart';

/// Everything a project editor build depends on.
class EditorHostInputs {
  /// `<project>/.lumina/editor`: its `pubspec.yaml` and `pubspec.lock`.
  final String hostDir;

  /// The workspace root holding the engine repos.
  final String engineRoot;

  /// Each code plugin's package directory, by plugin name.
  final Map<String, String> pluginDirs;

  /// `flutter --version --machine`: `frameworkVersion` (shown in reasons) and
  /// `frameworkRevision` (hashed).
  final String flutterVersion;
  final String flutterRevision;

  /// `windows-x64`, `linux-x64`, ….
  final String platform;

  /// `release` or `debug`.
  final String mode;

  /// The repos (relative dirs under [engineRoot]) hashed as `engine:<repo>`:
  /// the engine repos, or the packages of a project's source copy.
  final List<String> repos;

  const EditorHostInputs({
    required this.hostDir,
    required this.engineRoot,
    required this.pluginDirs,
    required this.flutterVersion,
    required this.flutterRevision,
    required this.platform,
    required this.mode,
    this.repos = kEditorEngineRepos,
  });

  /// The running host: `<os>-<arch>`.
  static String currentPlatform() {
    final v = Platform.version.toLowerCase();
    final arch = v.contains('arm64') ? 'arm64' : (v.contains('ia32') ? 'ia32' : 'x64');
    return '${Platform.operatingSystem}-$arch';
  }
}

/// The engine packages a project editor is compiled from (the ones of other
/// repos are found through the workspace's package config).
const List<String> kEditorEngineRepos = [
  'lumina_ui',
  'lumina',
  'lumina_editor_api',
  'flutter_filament',
  'flutter_assimp',
  'flutter_riglogic',
  'flutter_gstreamer',
  'lumina_smoke',
  'lumina_mouse_capture',
];

/// Per-input hashes: `host.pubspec`, `host.lock`, `engine:<repo>`,
/// `plugin:<name>`, and the plain values `flutter`, `platform`, `mode` (kept
/// readable, so a reason can say "Flutter 3.41 → 3.44").
///
/// Hashing the host `pubspec.yaml` alone is not enough: editing a path
/// plugin's code or pulling the engine leaves every yaml unchanged, so each
/// plugin's sources and each engine repo's revision are hashed too.
Future<Map<String, String>> fingerprintComponents(EditorHostInputs inputs) async {
  final c = <String, String>{
    'host.pubspec': _hostPubspecHash(p.join(inputs.hostDir, 'pubspec.yaml')),
    'host.lock': _fileHash(p.join(inputs.hostDir, 'pubspec.lock')),
    'flutter': '${inputs.flutterVersion} (${inputs.flutterRevision})',
    'platform': inputs.platform,
    'mode': inputs.mode,
  };
  for (final repo in inputs.repos) {
    // A repo beside the others, else (flutter_assimp, flutter_riglogic,
    // flutter_gstreamer, lumina_smoke: the tools repo) where the engine
    // workspace resolved the package.
    final local = p.join(inputs.engineRoot, repo);
    final dir = Directory(local).existsSync() ? local : LuminaWorkspace.resolvedPackageDir(inputs.engineRoot, repo);
    if (dir == null || !Directory(dir).existsSync()) continue;
    c['engine:$repo'] = await engineRepoState(dir);
  }
  for (final name in inputs.pluginDirs.keys) {
    c['plugin:$name'] = _pluginHash(inputs.pluginDirs[name]!);
  }
  final pubspecFile = File(p.join(inputs.hostDir, 'pubspec.yaml'));
  if (pubspecFile.existsSync()) {
    try {
      final yaml = loadYaml(pubspecFile.readAsStringSync());
      final overrides = yaml is YamlMap ? yaml['dependency_overrides'] : null;
      if (overrides is YamlMap) {
        for (final entry in overrides.entries) {
          final name = '${entry.key}';
          if (inputs.repos.contains(name) || inputs.pluginDirs.containsKey(name)) continue;
          final v = entry.value;
          String? dir;
          if (v is YamlMap && v['path'] != null) {
            final raw = v['path'].toString();
            dir = p.isAbsolute(raw) ? raw : p.normalize(p.join(inputs.hostDir, raw));
          }
          if (dir != null && Directory(dir).existsSync()) {
            final manifest = _findPrebuiltManifest(dir);
            if (manifest != null) {
              c['override:$name'] = '$name:${_fileHash(manifest.path)}';
            } else {
              c['override:$name'] = await engineRepoState(dir);
            }
          }
        }
      }
    } on YamlException {
      // Ignore malformed yaml.
    }
  }
  return c;
}

/// Looks for a prebuilt provenance manifest (such as `lumina-kimodo.json`) in
/// `<dir>/prebuilt` or `<dir>/third_party/**/prebuilt`.
File? _findPrebuiltManifest(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return null;
  for (final sub in ['prebuilt', p.join('third_party', 'kimodo', 'prebuilt')]) {
    final subDir = Directory(p.join(dir, sub));
    if (!subDir.existsSync()) continue;
    try {
      for (final f in subDir.listSync(recursive: true).whereType<File>()) {
        if (p.basename(f.path).startsWith('lumina-') && f.path.endsWith('.json')) {
          return f;
        }
      }
    } on FileSystemException {
      // Ignore unreadable dirs.
    }
  }
  return null;
}

/// SHA-256 (hex) over [components] (or over [fingerprintComponents] of
/// [inputs]).
Future<String> fingerprint(EditorHostInputs inputs) async => fingerprintOf(await fingerprintComponents(inputs));

String fingerprintOf(Map<String, String> components) {
  final keys = components.keys.toList()..sort();
  return sha256.convert(utf8.encode(jsonEncode([for (final k in keys) '$k=${components[k]}']))).toString();
}

/// Human-readable reasons [newer] differs from [older], one per change:
/// "plugin a_plugin changed", "editor source changed (lumina_ui)",
/// "Flutter 3.41.0 → 3.44.0", "build mode release → debug".
List<String> diffInputs(Map<String, String> older, Map<String, String> newer) {
  final reasons = <String>[];
  final engine = <String>[];
  var hostChanged = false;
  final keys = {...older.keys, ...newer.keys}.toList()..sort();
  for (final k in keys) {
    final a = older[k], b = newer[k];
    if (a == b) continue;
    if (k.startsWith('engine:')) {
      engine.add(k.substring(7));
    } else if (k.startsWith('plugin:')) {
      final name = k.substring(7);
      reasons.add(a == null ? 'plugin $name added' : (b == null ? 'plugin $name removed' : 'plugin $name changed'));
    } else if (k.startsWith('override:')) {
      final name = k.substring(9);
      reasons.add(a == null ? 'dependency $name added' : (b == null ? 'dependency $name removed' : 'dependency $name changed'));
    } else if (k == 'flutter') {
      String short(String? v) => (v ?? '?').split(' ').first;
      final sa = short(a), sb = short(b);
      reasons.add(sa == sb ? 'Flutter revision changed ($sa)' : 'Flutter $sa → $sb');
    } else if (k == 'mode') {
      reasons.add('build mode $a → $b');
    } else if (k == 'platform') {
      reasons.add('platform $a → $b');
    } else {
      hostChanged = true;
    }
  }
  if (engine.isNotEmpty) reasons.insert(0, 'editor source changed (${engine.join(', ')})');
  if (hostChanged && reasons.isEmpty) reasons.add('editor host packages changed');
  return reasons;
}

/// The host pubspec without what names the project (`name:`, `description:`,
/// comments): two projects with the same plugins on the same engine are the
/// same editor and share one cache entry.
String _hostPubspecHash(String path) {
  final f = File(path);
  if (!f.existsSync()) return 'absent';
  final lines = f.readAsLinesSync().where((l) => !l.startsWith('name:') && !l.startsWith('description:') && !l.trimLeft().startsWith('#'));
  return sha256.convert(utf8.encode(lines.join('\n'))).toString();
}

String _fileHash(String path) {
  final f = File(path);
  return f.existsSync() ? sha256.convert(f.readAsBytesSync()).toString() : 'absent';
}

/// A path plugin's `lib/`, `hook/`, `pubspec.yaml` and `.lmplugin`, by path +
/// content. The manifest decides what the registrar compiles in (its
/// `registration_class`, `isolation` and `process_class`).
String _pluginHash(String dir) {
  final lines = <String>[];
  final root = Directory(dir);
  if (root.existsSync()) {
    for (final f in root.listSync(followLinks: true).whereType<File>()) {
      if (f.path.endsWith('.lmplugin')) lines.add('${p.basename(f.path)}:${sha256.convert(f.readAsBytesSync())}');
    }
  }
  for (final sub in ['lib', 'hook']) {
    final d = Directory(p.join(dir, sub));
    if (!d.existsSync()) continue;
    for (final f in d.listSync(recursive: true, followLinks: true).whereType<File>()) {
      lines.add('${p.relative(f.path, from: dir).replaceAll(r'\', '/')}:${sha256.convert(f.readAsBytesSync())}');
    }
  }
  lines.add('pubspec.yaml:${_fileHash(p.join(dir, 'pubspec.yaml'))}');
  lines.sort();
  return sha256.convert(utf8.encode(lines.join('\n'))).toString();
}

/// The directories whose files make up a repo's build when it is not a git
/// checkout (a sorted path + content-hash manifest): the Dart and native
/// sources and the platform runners (a project editor's runner is generated
/// from its copy of lumina_ui's, and a plugin package's native code lives
/// there too).
const List<String> _manifestDirs = ['lib', 'src', 'hook', 'windows', 'linux', 'macos'];

bool _isInsideGit(String dir) {
  if (!Directory(dir).existsSync()) return false;
  var current = Directory(dir).absolute;
  while (true) {
    if (Directory(p.join(current.path, '.git')).existsSync() ||
        File(p.join(current.path, '.git')).existsSync()) {
      return true;
    }
    final parent = current.parent;
    if (parent.path == current.path) break;
    current = parent;
  }
  return false;
}

/// A repo's source state: its git state when it is a checkout, else a
/// content manifest (the project's copy of the engine).
Future<String> engineRepoState(String dir) async {
  if (_isInsideGit(dir)) {
    final git = await _gitState(dir);
    if (git != null) return git;
  }
  return Isolate.run(() => _manifestHash(dir, [for (final s in _manifestDirs) p.join(dir, s)], extraFiles: [p.join(dir, 'pubspec.yaml')]));
}

/// `HEAD` + a hash of `git diff HEAD` + the untracked source files (path,
/// size, mtime): a pull, a local edit and a new file each change it.
Future<String?> _gitState(String dir) async {
  try {
    final head = await Process.run('git', ['rev-parse', 'HEAD'], workingDirectory: dir, runInShell: Platform.isWindows);
    if (head.exitCode != 0) return null;
    final diff = await Process.run('git', ['diff', 'HEAD', '--no-ext-diff', '--no-color', '--', '.'],
        workingDirectory: dir, stdoutEncoding: null, runInShell: Platform.isWindows);
    if (diff.exitCode != 0) return null;
    final untracked = await Process.run('git', ['ls-files', '--others', '--exclude-standard', '--', ..._manifestDirs, 'pubspec.yaml'],
        workingDirectory: dir, runInShell: Platform.isWindows);
    final files = (untracked.stdout as String).split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList()..sort();
    final untrackedLines = [
      for (final rel in files)
        if (File(p.join(dir, rel)).existsSync()) '$rel|${File(p.join(dir, rel)).lengthSync()}|${File(p.join(dir, rel)).lastModifiedSync().microsecondsSinceEpoch}',
    ];
    final diffHash = sha256.convert(diff.stdout as List<int>).toString();
    return 'git:${(head.stdout as String).trim()}:$diffHash:${sha256.convert(utf8.encode(untrackedLines.join('\n')))}';
  } on ProcessException {
    return null;
  }
}

String _manifestHash(String root, List<String> dirs, {List<String> extraFiles = const []}) {
  final lines = <String>[];
  // By content, not mtime: two projects copied from the same engine at
  // different times are the same editor.
  void add(File f) {
    lines.add('${p.relative(f.path, from: root).replaceAll(r'\', '/')}|${sha256.convert(f.readAsBytesSync())}');
  }

  for (final d in dirs) {
    final dir = Directory(d);
    if (!dir.existsSync()) continue;
    // Links are not followed: a runner's flutter/ephemeral/.plugin_symlinks
    // leads into other packages (their build folders too); the ephemeral
    // folder is the Flutter tool's own output.
    for (final f in dir.listSync(recursive: true, followLinks: false).whereType<File>()) {
      if (p.split(p.relative(f.path, from: d)).contains('ephemeral')) continue;
      add(f);
    }
  }
  for (final e in extraFiles) {
    if (File(e).existsSync()) add(File(e));
  }
  lines.sort();
  return 'manifest:${sha256.convert(utf8.encode(lines.join('\n')))}';
}

/// `flutter --version --machine`, probed once per process.
class FlutterToolInfo {
  final String version;
  final String revision;
  const FlutterToolInfo(this.version, this.revision);

  static FlutterToolInfo? _cached;

  static Future<FlutterToolInfo> probe({String flutter = 'flutter'}) async {
    if (_cached != null) return _cached!;
    final r = await Process.run(flutter, ['--version', '--machine'], runInShell: Platform.isWindows);
    if (r.exitCode != 0) throw ProcessException(flutter, ['--version', '--machine'], '${r.stderr}', r.exitCode);
    final out = r.stdout as String;
    final json = jsonDecode(out.substring(out.indexOf('{'))) as Map<String, dynamic>;
    return _cached = FlutterToolInfo('${json['frameworkVersion']}', '${json['frameworkRevision']}');
  }
}
