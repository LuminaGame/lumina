import 'dart:convert';
import 'dart:io';

import 'package:lumina/lumina.dart' show ProjectRepository;
import 'package:lumina_ui/ui/core/host/editor_host.dart' show LuminaEditorHost;

/// flutter_filament's WebAssembly module — `web/flutter_filament.{js,wasm}`,
/// built by its `tool/web/build_module.sh`.
/// A Lumina game can only be built for the web when it exists:
/// the cook serves both files next to the game's
/// `index.html`, where `FilamentWeb.ensureInitialized` loads them.
class FlutterFilamentWebModule {
  FlutterFilamentWebModule._(this.directory);

  /// The package's `web/` folder.
  final Directory directory;

  static const List<String> fileNames = ['flutter_filament.js', 'flutter_filament.wasm'];

  /// Why web builds are unavailable while the module is missing.
  static const String missingReason = "Not available yet: flutter_filament's WebAssembly module (web/flutter_filament.wasm) "
      'is not built. Build it with flutter_filament/tool/web/build_module.sh.';

  List<File> get files => [for (final name in fileNames) File('${directory.path}/$name')];

  int get sizeBytes => files.fold(0, (sum, f) => sum + f.lengthSync());

  /// The module in [webDir], or null when either file is missing.
  static FlutterFilamentWebModule? at(Directory webDir) {
    final module = FlutterFilamentWebModule._(webDir);
    return module.files.every((f) => f.existsSync()) ? module : null;
  }

  /// Finds the flutter_filament package through the resolved dependencies
  /// (`.dart_tool/package_config.json`) of each of [packageRoots], in order.
  /// By default: the engine package the editor scaffolds projects against,
  /// then the editor's own working directory. Pass the project first to use
  /// exactly the flutter_filament its game links.
  static FlutterFilamentWebModule? locate({List<String>? packageRoots}) {
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
