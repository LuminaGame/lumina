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
class FlutterFilamentWebModule {
  FlutterFilamentWebModule._(this.directory, [this.source = FlutterFilamentWebModuleSource.packageBuild]);

  /// The folder holding both files: the package's `web/` folder or the
  /// downloaded module.
  final Directory directory;

  /// Whether this is a local package build or the downloaded copy.
  final FlutterFilamentWebModuleSource source;

  static const List<String> fileNames = ['flutter_filament.js', 'flutter_filament.wasm'];

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
      final package = _flutterFilamentRoot(root);
      if (package == null) continue;
      final module = at(Directory.fromUri(package.resolve('web/')));
      if (module != null) return module;
    }
    return null;
  }

  static Uri? _flutterFilamentRoot(String packageRoot) {
    final config = File('$packageRoot/.dart_tool/package_config.json');
    if (!config.existsSync()) return null;
    try {
      final packages = (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
      for (final p in packages.whereType<Map>()) {
        if (p['name'] != 'flutter_filament') continue;
        final rootUri = p['rootUri'] as String;
        return config.parent.uri.resolve(rootUri.endsWith('/') ? rootUri : '$rootUri/');
      }
    } catch (_) {
      // An unreadable config is the same as none.
    }
    return null;
  }

  /// Copies both files into [webBuild] (a `flutter build web` output) and
  /// returns the copies.
  List<File> stageInto(Directory webBuild) => [for (final f in files) f.copySync('${webBuild.path}/${f.uri.pathSegments.last}')];
}
