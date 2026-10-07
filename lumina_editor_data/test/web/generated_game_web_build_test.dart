import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'web_game_build.dart';

/// A scaffolded Third Person game compiles for the browser: its
/// import graph reaches no `dart:ffi` package and its assets come from the
/// bundle.
void main() {
  test('flutter build web of a scaffolded Third Person project succeeds', () async {
    final module = flutterFilamentWebModule();
    if (module == null) {
      markTestSkipped('needs flutter_filament/web/flutter_filament.wasm (tool/web/build_module.sh)');
      return;
    }
    final root = Directory.systemTemp.createTempSync('lumina_web_build_');
    addTearDown(() => root.deleteSync(recursive: true));

    final project = await buildThirdPersonGameForWeb(root, module);

    final web = Directory('$project/build/web');
    for (final f in ['index.html', 'main.dart.js', 'flutter_filament.js', 'flutter_filament.wasm']) {
      expect(File('${web.path}/$f').existsSync(), isTrue, reason: '$f in build/web');
    }
    final manifest = File('${web.path}/assets/AssetManifest.bin.json');
    expect(manifest.existsSync(), isTrue);
    expect(manifest.readAsStringSync().isNotEmpty, isTrue);
    expect(File('${web.path}/assets/contents/meshes/skeletal/SKM_Superhero_Female.entity.glb').existsSync(), isTrue,
        reason: 'the mannequin ships in the bundle');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
