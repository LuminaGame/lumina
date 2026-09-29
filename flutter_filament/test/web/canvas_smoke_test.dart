import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puppeteer/puppeteer.dart';

/// The WebAssembly module (tool/web/build_module.sh) draws in a real
/// browser: headless Chrome, a WebGL2 canvas, and only the filament_* C
/// functions the Dart bindings call (test/web/canvas_smoke.html).
///
/// Skips when the module or Chrome is missing, like the FFI tests do without
/// native assets.
const _chromeCandidates = ['/usr/bin/google-chrome', '/usr/bin/chromium', '/snap/bin/chromium'];
const _matc = '../filament/out/prebuilt-tools-release/tools/matc/matc';
const _testName = 'web module: clear + triangle on a WebGL2 canvas';

ContentType _contentType(String path) {
  if (path.endsWith('.wasm')) return ContentType('application', 'wasm');
  if (path.endsWith('.js')) return ContentType('text', 'javascript', charset: 'utf-8');
  if (path.endsWith('.html')) return ContentType.html;
  return ContentType.binary;
}

void _expectColor(List<Object?> rgba, List<int> expected, String what) {
  for (var i = 0; i < 3; i++) {
    expect(((rgba[i] as num).toInt() - expected[i]).abs(), lessThanOrEqualTo(2), reason: '$what: got $rgba, want $expected');
  }
}

void main() {
  test(_testName, () async {
    final chrome = _chromeCandidates.where((p) => File(p).existsSync()).firstOrNull;
    if (!File('web/flutter_filament.wasm').existsSync() || chrome == null || !File(_matc).existsSync()) {
      markTestSkipped('needs web/flutter_filament.wasm (tool/web/build_module.sh), Chrome and matc');
      return;
    }

    // The triangle's material, compiled for WebGL (OpenGL ES 3.0).
    Directory('build/web_smoke').createSync(recursive: true);
    final matc = await Process.run(_matc, ['-a', 'opengl', '-p', 'mobile', '-o', 'build/web_smoke/red_unlit.filamat', 'test/web/red_unlit.mat']);
    expect(matc.exitCode, 0, reason: '${matc.stdout}${matc.stderr}');

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final file = File('.${request.uri.path}');
      if (request.uri.path.contains('..') || !file.existsSync()) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.headers.contentType = _contentType(request.uri.path);
        await request.response.addStream(file.openRead());
      }
      await request.response.close();
    });

    // SwiftShader: a deterministic, CPU-only WebGL2 implementation.
    final browser = await puppeteer.launch(
      executablePath: chrome,
      headless: true,
      args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--no-sandbox'],
    );
    addTearDown(browser.close);
    final page = await browser.newPage();
    await page.setViewport(DeviceViewport(width: 512, height: 512));
    final console = <String>[];
    page.onConsole.listen((m) => console.add(m.text ?? ''));
    page.onError.listen((e) => console.add('pageerror: ${e.message}'));

    await page.goto('http://127.0.0.1:${server.port}/test/web/canvas_smoke.html');
    await page.waitForFunction('() => window.__smoke !== undefined', timeout: const Duration(seconds: 90));
    final result = Map<String, Object?>.from(await page.evaluate<Map>('() => window.__smoke'));

    final canvas = await page.$('#c');
    SmokeArtifacts.saveScreenshot(_testName, Uint8List.fromList(await canvas.screenshot()));

    expect(result['ok'], isTrue, reason: '$result\n${console.join('\n')}');
    expect(result['glError'], 0, reason: 'WebGL error after the frames');
    expect((result['rendered'] as num).toInt(), greaterThan(0), reason: 'beginFrame never let a frame through');
    expect((result['contextHandle'] as num).toInt(), greaterThan(0));
    _expectColor(result['corner'] as List<Object?>, [51, 102, 204], 'corner (clear colour 0.2, 0.4, 0.8)');
    _expectColor(result['center'] as List<Object?>, [255, 0, 0], 'centre (the red triangle)');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
