import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The lumina repo: generated games and plugins depend on its packages
/// through git, and a release build fetches its engine source from it.
const String kLuminaGitUrl = 'https://github.com/LuminaGame/lumina.git';

/// Locates the Lumina workspace (the lumina repo: the folder holding
/// `lumina/`, `lumina_ui/`, `flutter_filament/`, `filament/`, …) without
/// assuming where it was checked out, so the same build runs from `~/lumina`
/// on Linux and `D:\lumina` on Windows.
///
/// Packages from the other repos (flutter_assimp, flutter_riglogic,
/// flutter_gstreamer and lumina_smoke from `tools`, the marketplace's shared
/// package, the plugins) are not under the
/// root: they are git dependencies, or local checkouts through the root's
/// `pubspec_overrides.yaml`. [package] finds them through the workspace's
/// resolved package config.
class LuminaWorkspace {
  LuminaWorkspace._();

  static String? _cachedRoot;
  static String? _override;
  static String? _engineCommit;
  static String? _engineRepo;

  /// The user's home directory (`HOME`, or `USERPROFILE` on Windows).
  static String get home =>
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.systemTemp.path;

  /// The workspace root: the checkout set by [useCheckout], else
  /// `LUMINA_WORKSPACE` when set, else the first ancestor
  /// of the working directory, the running executable or the script that
  /// contains `lumina/pubspec.yaml`, else `<home>/lumina`.
  static String get root => _override ?? (_cachedRoot ??= _resolveRoot());

  /// Points [root] at [checkout] for the rest of the process: the engine
  /// source a release build fetched for itself (see `EngineBootstrap`).
  /// [commit] and [repo] are the commit that checkout is at and the git URL
  /// it came from; generated projects pin their engine dependency to them
  /// ([engineCommit], [engineRepo]). Takes precedence over every other way
  /// of finding the workspace.
  static void useCheckout(String checkout, {String? commit, String? repo}) {
    _override = p.normalize(p.absolute(checkout));
    _engineCommit = commit == null || commit.isEmpty ? null : commit;
    _engineRepo = repo == null || repo.isEmpty ? null : repo;
  }

  /// Undoes [useCheckout] (tests; a re-download that failed).
  static void clearCheckout() {
    _override = null;
    _engineCommit = null;
    _engineRepo = null;
  }

  /// The checkout [useCheckout] set; null when the workspace is found the
  /// usual way.
  static String? get checkoutOverride => _override;

  /// The engine commit of the checkout set by [useCheckout]; null in a
  /// source workspace, where generated projects follow the default branch.
  static String? get engineCommit => _engineCommit;

  /// The git URL the checkout set by [useCheckout] was cloned from.
  static String? get engineRepo => _engineRepo;

  /// The source workspace this process runs from, without the
  /// `<home>/lumina` fallback: `LUMINA_WORKSPACE`, else an ancestor of the
  /// working directory, the executable or the script holding
  /// `lumina/pubspec.yaml`; null when there is none (an installed release
  /// build). [environment] defaults to the process environment.
  static String? findSourceRoot({Map<String, String>? environment}) {
    final env = (environment ?? Platform.environment)['LUMINA_WORKSPACE'];
    if (env != null && env.isNotEmpty) return env;
    for (final start in _starts()) {
      final found = findRootFrom(start);
      if (found != null) return found;
    }
    return null;
  }

  static List<String> _starts() => <String>[
        Directory.current.path,
        File(Platform.resolvedExecutable).parent.path,
        if (Platform.script.scheme == 'file') File.fromUri(Platform.script).parent.path,
      ];

  /// The directory of package [name], e.g. `package('lumina_editor_api')`:
  /// `<root>/<name>` when it holds that package, else where the workspace
  /// resolved it (see [packageIn]).
  static String package(String name) => packageIn(root, name);

  /// [name]'s directory as the workspace at [root] sees it: `<root>/<name>`
  /// when its pubspec is there, else the package's root in
  /// `<root>/.dart_tool/package_config.json` (a package from another repo: a
  /// git checkout in the pub cache or its local override), else
  /// `<root>/<name>`.
  static String packageIn(String root, String name) {
    final local = p.join(root, name);
    if (File(p.join(local, 'pubspec.yaml')).existsSync()) return local;
    return resolvedPackageDir(root, name) ?? local;
  }

  /// [name]'s root directory from `<root>/.dart_tool/package_config.json`
  /// (written by `pub get` at the workspace root); null when the config or
  /// the package is missing.
  static String? resolvedPackageDir(String root, String name) {
    final config = File(p.join(root, '.dart_tool', 'package_config.json'));
    if (!config.existsSync()) return null;
    try {
      final json = jsonDecode(config.readAsStringSync());
      final packages = json is Map ? json['packages'] : null;
      if (packages is! List) return null;
      for (final entry in packages) {
        if (entry is! Map || entry['name'] != name) continue;
        final rootUri = '${entry['rootUri']}';
        // Relative URIs are relative to the config file's folder.
        final uri = Uri.directory(p.dirname(config.absolute.path)).resolve(rootUri.endsWith('/') ? rootUri : '$rootUri/');
        return p.normalize(uri.toFilePath());
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  /// The shared 3D test assets (`<root>/test-assets`).
  static String get testAssets => p.join(root, 'test-assets');

  static String _resolveRoot() => findSourceRoot() ?? p.join(home, 'lumina');

  /// The first of [start] and its ancestors holding `lumina/pubspec.yaml`.
  static String? findRootFrom(String start) {
    var dir = p.normalize(p.absolute(start));
    while (true) {
      if (File(p.join(dir, 'lumina', 'pubspec.yaml')).existsSync()) return dir;
      final parent = p.dirname(dir);
      if (parent == dir) return null;
      dir = parent;
    }
  }
}
