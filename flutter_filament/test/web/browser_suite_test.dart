import 'dart:convert';
import 'dart:io';

import 'package:flutter_filament/testing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the browser suite (test/web_browser/, dart2js in Chrome
/// against the WebAssembly module) as part of `flutter test`, and publishes
/// the frames it prints (`SMOKE_PNG <name> <base64>`) to the smoke report.
/// Skips without the module or Chrome.
const _chromeCandidates = ['/usr/bin/google-chrome', '/usr/bin/chromium', '/snap/bin/chromium'];

void main() {
  test('web browser suite: dart:ffi layer and the Dart API in Chrome', () async {
    final chrome = _chromeCandidates.where((p) => File(p).existsSync()).firstOrNull;
    if (!File('web/flutter_filament.wasm').existsSync() || chrome == null) {
      markTestSkipped('needs web/flutter_filament.wasm (tool/web/build_module.sh) and Chrome');
      return;
    }
    final result = await Process.run(
      'flutter',
      ['test', '--platform', 'chrome', 'test/web_browser/'],
      environment: {'CHROME_EXECUTABLE': chrome},
    );
    final out = '${result.stdout}';
    var published = 0;
    for (final line in const LineSplitter().convert(out)) {
      if (!line.startsWith('SMOKE_PNG ')) continue;
      final space = line.lastIndexOf(' ');
      SmokeArtifacts.saveScreenshot(line.substring('SMOKE_PNG '.length, space), base64Decode(line.substring(space + 1)));
      published++;
    }
    final log = const LineSplitter().convert(out).where((l) => !l.startsWith('SMOKE_PNG ')).join('\n');
    expect(result.exitCode, 0, reason: '$log\n${result.stderr}');
    expect(published, greaterThan(0), reason: 'the API smoke prints its frame');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
