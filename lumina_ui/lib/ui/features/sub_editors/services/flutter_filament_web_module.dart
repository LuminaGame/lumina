import 'dart:convert';
import 'dart:io';

import 'package:lumina_core/lumina_core.dart' show FlutterFilamentWebPrebuilt;
import 'package:lumina_editor_data/lumina_editor.dart' show ProjectRepository;
import 'package:lumina_ui/ui/core/host/editor_host.dart' show LuminaEditorHost;

/// Where a [FlutterFilamentWebModule] was found.
enum FlutterFilamentWebModuleSource {
  /// flutter_filament's own `web/` folder, built by `tool/web/build_module.sh`
  /// (the developer override).
  packageBuild,

  /// The copy the editor downloaded from a Lumina release
  /// ([FlutterFilamentWebPrebuilt]).
  download,
}

/// flutter_filament's WebAssembly module — `flutter_filament.{js,wasm}`:
/// built into the package's `web/` folder by its `tool/web/build_module.sh`,
/// or downloaded by the editor from a Lumina release
/// (`flutter-filament-web-<tag>.zip`, [FlutterFilamentWebPrebuilt]).
/// A Lumina game can only be built for the web when it exists:
/// the cook serves both files next to the game's
/// `index.html`, where `FilamentWeb.ensureInitialized` loads them.
///
/// Jolt Physics' module (`flutter_jolt.{js,wasm}`, [joltFileNames]) is staged
/// beside them when found — in the same folder (a downloaded release holds
/// both modules) or built into flutter_jolt's own `web/` folder
/// (`tool/web/build_jolt_wasm.sh`); the game then simulates on Jolt, else on
/// the engine's Dart solver.
class FlutterFilamentWebModule {
  FlutterFilamentWebModule._(this.directory, [this.source = FlutterFilamentWebModuleSource.packageBuild, this.joltDirectory]);

  /// The folder holding both files: the package's `web/` folder or the
  /// downloaded module.
  final Directory directory;

  /// Whether this is a local package build or the downloaded copy.
  final FlutterFilamentWebModuleSource source;

  static const List<String> fileNames = ['flutter_filament.js', 'flutter_filament.wasm'];

  /// Jolt Physics' WebAssembly module, staged when present.
  static const List<String> joltFileNames = ['flutter_jolt.js', 'flutter_jolt.wasm'];

  /// Where Jolt's module was found when not in [directory] (flutter_jolt's
  /// package build), or null.
  final Directory? joltDirectory;

  /// Jolt's module files, or empty when it was not found.
  List<File> get joltFiles {
    for (final dir in [directory, ?joltDirectory]) {
      final found = [for (final name in joltFileNames) File('${dir.path}/$name')];
      if (found.every((f) => f.existsSync())) return found;
    }
    return const [];
  }

  /// Why web builds are unavailable while the module is missing.
  static const String missingReason = "Not available yet: flutter_filament's WebAssembly module (flutter_filament.wasm) "
      'is not downloaded. Download it in Project Settings > Packaging, or build it with flutter_filament/tool/web/build_module.sh.';

  /// The secondary hint next to the download button.
  static const String buildHint = 'Or build it locally with flutter_filament/tool/web/build_module.sh '
      '(a local build always wins over the download).';

  List<File> get files => [for (final name in fileNames) File('${directory.path}/$name')];

  int get sizeBytes => files.fold(0, (sum, f) => sum + f.lengthSync());

  /// The module in [webDir], or null when either file is missing.
  static FlutterFilamentWebModule? at(Directory webDir, [FlutterFilamentWebModuleSource source = FlutterFilamentWebModuleSource.packageBuild]) {
    final module = FlutterFilamentWebModule._(webDir, source);
    return module.files.every((f) => f.existsSync()) ? module : null;
  }

  /// The module a web build stages: first a local build in the
  /// flutter_filament package ([locatePackageBuild] over [packageRoots], the
  /// developer override), then the copy the editor downloaded under
  /// [downloadRoot] (default [FlutterFilamentWebPrebuilt.defaultRoot], the
  /// per-user data folder). Null when neither exists.
  static FlutterFilamentWebModule? locate({List<String>? packageRoots, Directory? downloadRoot}) =>
      locatePackageBuild(packageRoots: packageRoots) ?? locateDownload(downloadRoot);

  /// The module [FlutterFilamentWebPrebuilt] unpacked under [downloadRoot],
  /// or null.
  static FlutterFilamentWebModule? locateDownload([Directory? downloadRoot]) {
    final install = FlutterFilamentWebPrebuilt.installed(downloadRoot);
    return install == null ? null : at(install.directory, FlutterFilamentWebModuleSource.download);
  }

  /// Finds the flutter_filament package through the resolved dependencies
  /// (`.dart_tool/package_config.json`) of each of [packageRoots], in order,
  /// and returns the module built into its `web/` folder.
  /// By default: the engine package the editor scaffolds projects against,
  /// then the editor's own working directory. Pass the project first to use
  /// exactly the flutter_filament its game links.
  static FlutterFilamentWebModule? locatePackageBuild({List<String>? packageRoots}) {
    final roots = packageRoots ?? [ProjectRepository.luminaPackagePath, LuminaEditorHost.uiRoot];
    for (final root in roots) {
      final package = _packageRootUri(root, 'flutter_filament');
      if (package == null) continue;
      final module = at(Directory.fromUri(package.resolve('web/')));
      if (module == null) continue;
      final jolt = _packageRootUri(root, 'flutter_jolt');
      return FlutterFilamentWebModule._(module.directory, module.source, jolt == null ? null : Directory.fromUri(jolt.resolve('web/')));
    }
    return null;
  }

  static Uri? _packageRootUri(String packageRoot, String name) {
    final config = File('$packageRoot/.dart_tool/package_config.json');
    if (!config.existsSync()) return null;
    try {
      final packages = (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
      for (final p in packages.whereType<Map>()) {
        if (p['name'] != name) continue;
        final rootUri = p['rootUri'] as String;
        return config.parent.uri.resolve(rootUri.endsWith('/') ? rootUri : '$rootUri/');
      }
    } catch (_) {
      // An unreadable config is the same as none.
    }
    return null;
  }

  /// Why this module cannot run a game built by this editor, or null. A
  /// module built for another Filament release refuses the materials the
  /// editor compiles (another material version); a module built before a
  /// function was added to flutter_filament's web bindings throws every time
  /// the game calls it (a MetaHuman's pose following stopped every tick, so
  /// input never reached the player). [filamentVersion] is the Filament the
  /// editor links (`FilamentInfo.version`): the module stamps its own into
  /// the wasm. A package build is also checked against the package's web
  /// bindings, function for function.
  String? staleReason({required String filamentVersion}) {
    final wasm = files.last.readAsBytesSync();
    if (!_contains(wasm, utf8.encode(filamentVersion))) {
      return "flutter_filament's WebAssembly module in ${directory.path} was built for another Filament release "
          'than the editor\'s ($filamentVersion): rebuild it with '
          'flutter_filament/tool/web/build_module.sh${source == FlutterFilamentWebModuleSource.download ? ', or download it again in Project Settings > Packaging' : ''}.';
    }
    final missing = missingExports();
    if (missing.isNotEmpty) {
      return "flutter_filament's WebAssembly module in ${directory.path} is older than its web bindings: it lacks "
          '${missing.length} function${missing.length == 1 ? '' : 's'} the game calls (${missing.take(5).join(', ')}'
          '${missing.length > 5 ? ', …' : ''}). Rebuild it with flutter_filament/tool/web/build_module.sh.';
    }
    return null;
  }

  /// The functions flutter_filament's web bindings call that this module does
  /// not export (a package build only: the bindings sit beside its `web/`).
  List<String> missingExports() {
    if (source != FlutterFilamentWebModuleSource.packageBuild) return const [];
    final bindings = File('${directory.parent.path}/lib/src/third_party/filament_c.web.g.dart');
    if (!bindings.existsSync()) return const [];
    final wanted = {for (final m in RegExp(r"@JS\('(_filament_\w+)'\)").allMatches(bindings.readAsStringSync())) m.group(1)!};
    final exported = {for (final m in RegExp(r'_filament_\w+').allMatches(files.first.readAsStringSync())) m.group(0)!};
    return (wanted.difference(exported).toList()..sort()).map((n) => n.substring(1)).toList();
  }

  static bool _contains(List<int> haystack, List<int> needle) {
    outer:
    for (var i = 0; i + needle.length <= haystack.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  /// Copies both files into [webBuild] (a `flutter build web` output) and
  /// returns the copies.
  List<File> stageInto(Directory webBuild) =>
      [for (final f in [...files, ...joltFiles]) f.copySync('${webBuild.path}/${f.uri.pathSegments.last}')];
}
