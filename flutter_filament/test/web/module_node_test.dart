import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runs the Node checks of the WebAssembly module
/// (test/web/module_test.mjs: every filament_* export, the heap, ABI parity
/// with the desktop library) as part of `flutter test`, so the smoke report
/// and CI see them. Skips when the module or Node is missing.
void main() {
  test('web module: exports, heap and ABI parity (node --test)', () async {
    final node = Process.runSync('which', ['node']);
    if (!File('web/flutter_filament.wasm').existsSync() || node.exitCode != 0) {
      markTestSkipped('needs web/flutter_filament.wasm (tool/web/build_module.sh) and node');
      return;
    }
    final result = await Process.run('node', ['--test', 'test/web/module_test.mjs']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('# fail 0').or(contains('ℹ fail 0')));
  }, timeout: const Timeout(Duration(minutes: 2)));
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
