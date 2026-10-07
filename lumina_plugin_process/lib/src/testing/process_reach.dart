import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// What a plugin's process part reaches: the libraries its process class's
/// library imports or exports, transitively, through every package of the
/// plugin's `.dart_tool/package_config.json`.
///
/// A plugin's architecture test lists the packages its process part may
/// import ([directPackages]) and checks [flutterPackages]: a process part
/// that reaches none can later run as a plain `dart` program; one that does
/// records why.
///
/// ```dart
/// final reach = PluginProcessReach.ofPlugin(Directory.current);
/// expect(reach.directPackages, {'lumina_core', 'lumina_plugin_process', 'path'});
/// expect(reach.flutterPackages, isEmpty, reason: reach.describeFlutter());
/// ```
///
/// Directives are read from each library's header (the `library`, `import`,
/// `export` and `part` directives before the first declaration), so `import`
/// lines inside string templates do not count. Conditional imports count
/// every variant. Libraries of the Flutter SDK are recorded, not entered.
class PluginProcessReach {
  PluginProcessReach._(this.package, this.roots, this._packages);

  /// Walks from [roots] (`package:` URIs of the plugin's own package).
  factory PluginProcessReach.walk(List<Uri> roots, {PluginPackageRoots? packages}) {
    if (roots.isEmpty) throw ArgumentError.value(roots, 'roots', 'no process library to walk from');
    final config = packages ?? PluginPackageRoots.read();
    final own = roots.first.pathSegments.first;
    final reach = PluginProcessReach._(own, roots, config);
    reach._walk();
    return reach;
  }

  /// Reads the `.lmplugin` in [pluginDir], finds the library under `lib/`
  /// that declares each module's `process_class` and walks from them.
  /// Throws a [StateError] when the plugin has no process part.
  factory PluginProcessReach.ofPlugin(Directory pluginDir, {PluginPackageRoots? packages}) {
    final roots = processLibrariesOf(pluginDir);
    if (roots.isEmpty) throw StateError('${pluginDir.path} declares no process_class');
    return PluginProcessReach.walk(roots, packages: packages);
  }

  /// The `package:` URIs of the libraries that declare the process classes
  /// named by the `.lmplugin` in [pluginDir] (empty when it names none).
  static List<Uri> processLibrariesOf(Directory pluginDir) {
    final manifests = pluginDir.listSync().whereType<File>().where((f) => f.path.endsWith('.lmplugin')).toList();
    if (manifests.isEmpty) throw StateError('no .lmplugin in ${pluginDir.path}');
    final json = jsonDecode(manifests.first.readAsStringSync()) as Map<String, dynamic>;
    final classes = <String>[
      for (final m in (json['modules'] as List? ?? const []).cast<Map<String, dynamic>>())
        if (m['process_class'] is String) m['process_class'] as String,
    ];
    if (classes.isEmpty) return const [];
    final package = _packageName(pluginDir);
    final lib = Directory(p.join(pluginDir.path, 'lib'));
    final found = <Uri>[];
    for (final name in classes) {
      final declaration = RegExp(
        r'^\s*(?:abstract\s+|final\s+|base\s+)*class\s+' + RegExp.escape(name) + r'\b',
        multiLine: true,
      );
      final file = lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .firstWhere(
            (f) => declaration.hasMatch(f.readAsStringSync()),
            orElse: () => throw StateError('no library under ${lib.path} declares class $name'),
          );
      final rel = p.relative(file.path, from: lib.path).replaceAll(r'\', '/');
      found.add(Uri.parse('package:$package/$rel'));
    }
    return found;
  }

  /// The plugin's own package (the roots' package).
  final String package;

  /// The libraries the walk started from.
  final List<Uri> roots;

  final PluginPackageRoots _packages;

  /// Every reached URI → the URI that first reached it (null for a root).
  final reached = <String, String?>{};

  /// Packages imported by the plugin's own reached libraries (the process
  /// part's direct dependencies), without the plugin itself.
  final directPackages = <String>{};

  /// Every package reached, without the plugin itself.
  final allPackages = <String>{};

  /// Every `dart:` library reached.
  final dartLibraries = <String>{};

  /// `dart:` libraries imported by the plugin's own reached libraries.
  final directDartLibraries = <String>{};

  /// Every library of the plugin's own package that was reached.
  Iterable<String> get ownLibraries => reached.keys.where((u) => u.startsWith('package:$package/'));

  /// Packages that tie the process part to Flutter: the Flutter SDK's
  /// packages and every reached package whose pubspec depends on the
  /// Flutter SDK. `dart:ui` counts as `flutter`.
  Set<String> get flutterPackages => {
    for (final name in allPackages)
      if (_sdkPackages.contains(name) || _packages.dependsOnFlutter(name)) name,
    if (dartLibraries.contains('dart:ui') || dartLibraries.contains('dart:ui_web')) 'flutter',
  };

  /// The [directPackages] that tie the process part to Flutter (see
  /// [flutterPackages]); `flutter` also when an own library imports
  /// `dart:ui`. A plugin's architecture test records each with the reason.
  Set<String> get directFlutterPackages => {
    for (final name in directPackages)
      if (_sdkPackages.contains(name) || _packages.dependsOnFlutter(name)) name,
    if (directDartLibraries.contains('dart:ui') || directDartLibraries.contains('dart:ui_web')) 'flutter',
  };

  /// `node <- the library that reached it <- … <- root`.
  String chain(String node) => [for (String? f = node; f != null; f = reached[f]) f].join(' <- ');

  /// For each package of [flutterPackages], the import chain that reached it
  /// first, one per line.
  String describeFlutter() {
    final lines = <String>[];
    for (final name in flutterPackages.toList()..sort()) {
      final first = reached.keys.firstWhere(
        (u) => u.startsWith('package:$name/') || (name == 'flutter' && u.startsWith('dart:ui')),
        orElse: () => name,
      );
      lines.add('$name: ${chain(first)}');
    }
    return lines.join('\n');
  }

  static const _sdkPackages = {
    'flutter',
    'flutter_test',
    'flutter_web_plugins',
    'flutter_driver',
    'sky_engine',
    'integration_test',
  };

  void _walk() {
    final todo = <Uri>[];
    for (final r in roots) {
      reached[r.toString()] = null;
      todo.add(r);
    }
    while (todo.isNotEmpty) {
      final uri = todo.removeLast();
      final file = _packages.resolve(uri);
      if (file == null || !file.existsSync()) continue;
      final fromOwn = uri.scheme == 'package' && uri.pathSegments.first == package;
      for (final written in headerUris(file.readAsStringSync())) {
        final dep = uri.resolve(written);
        final key = dep.toString();
        if (dep.scheme == 'dart') {
          dartLibraries.add(key);
          if (fromOwn) directDartLibraries.add(key);
        } else if (dep.scheme == 'package') {
          final name = dep.pathSegments.first;
          if (name != package) {
            allPackages.add(name);
            if (fromOwn) directPackages.add(name);
          }
        }
        if (reached.containsKey(key)) continue;
        reached[key] = uri.toString();
        if (dep.scheme == 'dart') continue;
        if (dep.scheme == 'package' && _sdkPackages.contains(dep.pathSegments.first)) continue;
        todo.add(dep);
      }
    }
  }

  /// The URIs named by the `import`, `export` and `part` directives at the
  /// head of a Dart library [source] (conditional variants included).
  static List<String> headerUris(String source) => _HeaderScanner(source).scan();

  static String _packageName(Directory dir) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    final match = RegExp(r'^name:\s*([A-Za-z0-9_]+)', multiLine: true).firstMatch(pubspec.readAsStringSync());
    if (match == null) throw StateError('no name in ${pubspec.path}');
    return match.group(1)!;
  }
}

/// The plugin's `.dart_tool/package_config.json` (found from the current
/// directory upwards, so a pub workspace member finds its root's):
/// package name → its root and `lib/` folder.
class PluginPackageRoots {
  PluginPackageRoots(this.libs, this.roots);

  /// Package name → its `lib/` folder.
  final Map<String, Directory> libs;

  /// Package name → its root folder (where its pubspec is).
  final Map<String, Directory> roots;

  final _flutter = <String, bool>{};

  factory PluginPackageRoots.read([Directory? from]) {
    var dir = (from ?? Directory.current).absolute;
    while (!File(p.join(dir.path, '.dart_tool', 'package_config.json')).existsSync()) {
      if (dir.parent.path == dir.path) {
        throw StateError('no .dart_tool/package_config.json above ${(from ?? Directory.current).path}; run pub get');
      }
      dir = dir.parent;
    }
    final configFile = File(p.join(dir.path, '.dart_tool', 'package_config.json'));
    final json = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final libs = <String, Directory>{};
    final roots = <String, Directory>{};
    for (final pkg in (json['packages'] as List).cast<Map<String, dynamic>>()) {
      final rootUri = configFile.uri.resolve(_withSlash(pkg['rootUri'] as String));
      roots[pkg['name'] as String] = Directory.fromUri(rootUri);
      libs[pkg['name'] as String] = Directory.fromUri(
        rootUri.resolve(_withSlash((pkg['packageUri'] as String?) ?? 'lib/')),
      );
    }
    return PluginPackageRoots(libs, roots);
  }

  static String _withSlash(String s) => s.endsWith('/') ? s : '$s/';

  /// The file behind a `package:` or `file:` URI (null for `dart:` and
  /// unknown packages).
  File? resolve(Uri uri) {
    if (uri.scheme == 'file') return File.fromUri(uri);
    if (uri.scheme != 'package') return null;
    final lib = libs[uri.pathSegments.first];
    if (lib == null) return null;
    return File(p.joinAll([lib.path, ...uri.pathSegments.skip(1)]));
  }

  /// Whether [package]'s pubspec depends on the Flutter SDK
  /// (`sdk: flutter` under `dependencies`).
  bool dependsOnFlutter(String package) => _flutter.putIfAbsent(package, () {
    final root = roots[package];
    if (root == null) return false;
    final pubspec = File(p.join(root.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return false;
    final lines = pubspec.readAsLinesSync();
    var inDeps = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
      if (!line.startsWith(' ')) {
        inDeps = line.startsWith('dependencies:');
        continue;
      }
      if (inDeps && RegExp(r'^\s+sdk:\s*flutter\s*$').hasMatch(line)) return true;
    }
    return false;
  });
}

/// Reads the directive header of a Dart library: comments, annotations and
/// `library` / `import` / `export` / `part` directives, up to the first
/// declaration.
class _HeaderScanner {
  _HeaderScanner(this.s);

  final String s;
  var i = 0;

  List<String> scan() {
    final out = <String>[];
    while (true) {
      _skipTrivia();
      if (i >= s.length) break;
      if (s.startsWith('#!', i) && i == 0) {
        _skipLine();
        continue;
      }
      if (s[i] == '@') {
        i++;
        _skipWord();
        while (i < s.length && s[i] == '.') {
          i++;
          _skipWord();
        }
        _skipTrivia();
        if (i < s.length && s[i] == '(') _skipBalanced();
        continue;
      }
      final word = _peekWord();
      if (word == 'library' || word == 'import' || word == 'export' || word == 'part') {
        i += word.length;
        final strings = _readDirective();
        if (word == 'import' || word == 'export') out.addAll(strings);
        if (word == 'part' && strings.isNotEmpty && !_lastWasPartOf) out.add(strings.first);
        continue;
      }
      break;
    }
    return out;
  }

  var _lastWasPartOf = false;

  /// Reads up to `;`; returns the string literals at parenthesis depth 0
  /// (the URI and the conditional variants, not the conditions' values).
  List<String> _readDirective() {
    final strings = <String>[];
    var depth = 0;
    _skipTrivia();
    _lastWasPartOf = _peekWord() == 'of';
    while (i < s.length) {
      _skipTrivia();
      if (i >= s.length) break;
      final c = s[i];
      if (c == ';') {
        i++;
        break;
      }
      if (c == '(') {
        depth++;
        i++;
      } else if (c == ')') {
        depth--;
        i++;
      } else if (c == "'" || c == '"') {
        final value = _readString();
        if (depth == 0) strings.add(value);
      } else {
        i++;
      }
    }
    return strings;
  }

  String _readString() {
    final q = s[i];
    final triple = s.startsWith('$q$q$q', i);
    final end = triple ? '$q$q$q' : q;
    i += end.length;
    final b = StringBuffer();
    while (i < s.length && !s.startsWith(end, i)) {
      if (s[i] == r'\' && i + 1 < s.length) {
        b.write(s[i + 1]);
        i += 2;
        continue;
      }
      b.write(s[i]);
      i++;
    }
    i += end.length;
    return b.toString();
  }

  void _skipBalanced() {
    var depth = 0;
    while (i < s.length) {
      _skipTrivia();
      if (i >= s.length) return;
      final c = s[i];
      if (c == "'" || c == '"') {
        _readString();
        continue;
      }
      i++;
      if (c == '(') depth++;
      if (c == ')' && --depth == 0) return;
    }
  }

  String _peekWord() {
    final m = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*').matchAsPrefix(s, i);
    return m?.group(0) ?? '';
  }

  void _skipWord() => i += _peekWord().length;

  void _skipLine() {
    while (i < s.length && s[i] != '\n') {
      i++;
    }
  }

  void _skipTrivia() {
    while (i < s.length) {
      final c = s[i];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '﻿') {
        i++;
      } else if (s.startsWith('//', i)) {
        _skipLine();
      } else if (s.startsWith('/*', i)) {
        var depth = 0;
        while (i < s.length) {
          if (s.startsWith('/*', i)) {
            depth++;
            i += 2;
          } else if (s.startsWith('*/', i)) {
            depth--;
            i += 2;
            if (depth == 0) break;
          } else {
            i++;
          }
        }
      } else {
        return;
      }
    }
  }
}
