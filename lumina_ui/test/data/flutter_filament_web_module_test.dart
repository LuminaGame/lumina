import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/flutter_filament_web_module.dart';

/// The WebAssembly modules a web build stages next to the game's
/// `index.html`: flutter_filament's always, Jolt Physics' when it is found —
/// beside it (a downloaded release holds both) or in flutter_jolt's own
/// `web/` folder (a package build).
void main() {
  late Directory temp;

  setUp(() async => temp = await Directory.systemTemp.createTemp('web_module_'));
  tearDown(() => temp.delete(recursive: true));

  Future<Directory> write(String dir, List<String> names) async {
    final d = await Directory('${temp.path}/$dir').create(recursive: true);
    for (final n in names) {
      await File('${d.path}/$n').writeAsString(n);
    }
    return d;
  }

  test('a downloaded module with Jolt beside it stages all four files', () async {
    final dir = await write('download', [...FlutterFilamentWebModule.fileNames, ...FlutterFilamentWebModule.joltFileNames]);
    final module = FlutterFilamentWebModule.at(dir, FlutterFilamentWebModuleSource.download)!;
    final out = await write('build_web', ['index.html']);
    final staged = module.stageInto(out).map((f) => f.uri.pathSegments.last).toSet();
    expect(staged, {'flutter_filament.js', 'flutter_filament.wasm', 'flutter_jolt.js', 'flutter_jolt.wasm'});
    expect(await File('${out.path}/flutter_jolt.wasm').readAsString(), 'flutter_jolt.wasm');
  });

  test('without Jolt only the renderer is staged (the game keeps the Dart solver)', () async {
    final dir = await write('download', FlutterFilamentWebModule.fileNames);
    final module = FlutterFilamentWebModule.at(dir)!;
    expect(module.joltFiles, isEmpty);
    final out = await write('build_web', ['index.html']);
    expect(module.stageInto(out).map((f) => f.uri.pathSegments.last).toSet(), {'flutter_filament.js', 'flutter_filament.wasm'});
  });

  test("package builds: flutter_jolt's web folder is found through the package config", () async {
    final filament = await write('packages/flutter_filament/web', FlutterFilamentWebModule.fileNames);
    final jolt = await write('packages/flutter_jolt/web', FlutterFilamentWebModule.joltFileNames);
    final project = await Directory('${temp.path}/project/.dart_tool').create(recursive: true);
    await File('${project.path}/package_config.json').writeAsString(jsonEncode({
      'configVersion': 2,
      'packages': [
        {'name': 'flutter_filament', 'rootUri': filament.parent.uri.toString()},
        {'name': 'flutter_jolt', 'rootUri': jolt.parent.uri.toString()},
      ],
    }));
    final module = FlutterFilamentWebModule.locatePackageBuild(packageRoots: [project.parent.path])!;
    expect(module.joltFiles.map((f) => f.uri.pathSegments.last), FlutterFilamentWebModule.joltFileNames);
    final out = await write('build_web', ['index.html']);
    expect(module.stageInto(out), hasLength(4));
  });
}
