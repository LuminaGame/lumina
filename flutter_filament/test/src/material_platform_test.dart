import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone or a standalone headset runs Filament at a mobile feature level:
/// the engine picks the material's MOBILE shaders and refuses a package that
/// carries only DESKTOP ones. Every material the packages ship (the `.filamat`
/// files and the packages embedded as C++ byte arrays) must therefore carry
/// both shader models.
void main() {
  String posix(String path) => path.replaceAll('\\', '/');

  /// The compiled packages of flutter_filament and of the lumina package next
  /// to it, outside build output.
  List<File> shippedPackages() {
    final roots = [Directory.current, Directory('../lumina')];
    return [
      for (final root in roots)
        if (root.existsSync())
          ...root
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()
              .where((f) => f.path.endsWith('.filamat') || f.path.endsWith('_filamat.h'))
              .where((f) => !posix(f.path).contains('/build/') && !posix(f.path).contains('/.dart_tool/')),
    ]..sort((a, b) => a.path.compareTo(b.path));
  }

  /// The package bytes: the file itself, or the byte array `embed_material.py`
  /// writes into a header.
  Uint8List packageBytes(File file) {
    if (file.path.endsWith('.filamat')) return file.readAsBytesSync();
    final text = file.readAsStringSync();
    final body = text.substring(text.indexOf('{') + 1, text.lastIndexOf('}'));
    return Uint8List.fromList([
      for (final m in RegExp(r'0x([0-9a-fA-F]{2})').allMatches(body)) int.parse(m.group(1)!, radix: 16),
    ]);
  }

  Set<String> shaderModels(Uint8List bytes) {
    final json = FilamentTools.inspectMaterialJson(bytes);
    expect(json, isNotNull, reason: 'matdbg could not read the package');
    return {for (final m in RegExp(r'"shaderModel":\s*"(\w+)"').allMatches(json!)) m.group(1)!.toLowerCase()};
  }

  test('the walk finds the packages both packages ship', () {
    final names = shippedPackages().map((f) => posix(f.path).split('/').last).toSet();
    expect(names, containsAll(['simulated_skybox.filamat', 'wireframe_filamat.h', 'ui_overlay_filamat.h']));
  });

  for (final file in shippedPackages()) {
    test('${posix(file.path)} carries desktop and mobile shaders', () {
      final models = shaderModels(packageBytes(file));
      expect(models, containsAll(['desktop', 'mobile']),
          reason: '${file.path} has shader models $models; compile it with `-p all` in tool/materials.txt');
    });
  }
}
