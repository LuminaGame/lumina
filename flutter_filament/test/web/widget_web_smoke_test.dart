import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:puppeteer/puppeteer.dart';

/// FilamentWidget on the web: the example's web smoke app
/// (example/lib/web_smoke.dart) is built with `flutter build web`, served,
/// and driven in headless Chrome. The widget must present Suzanne straight
/// into its WebGL2 canvas, follow the layout size, and clean up on unmount.
const _chromeCandidates = ['/usr/bin/google-chrome', '/usr/bin/chromium', '/snap/bin/chromium'];
const _name = 'web widget: example app in Chrome';

ContentType _contentType(String path) => switch (path.split('.').last) {
      'wasm' => ContentType('application', 'wasm'),
      'js' || 'mjs' => ContentType('text', 'javascript', charset: 'utf-8'),
      'html' => ContentType.html,
      'json' => ContentType.json,
      _ => ContentType.binary,
    };

/// Finds the widget's canvas even inside shadow roots and reports its size.
const _canvasSize = '''() => {
  const find = (root) => {
    const c = root.querySelector('canvas[id^="flutter-filament-"]');
    if (c) return c;
    for (const el of root.querySelectorAll('*')) if (el.shadowRoot) { const r = find(el.shadowRoot); if (r) return r; }
    return null;
  };
  const c = find(document);
  return c ? [c.width, c.height] : null;
}''';

void main() {
  test(_name, () async {
    final chrome = _chromeCandidates.where((p) => File(p).existsSync()).firstOrNull;
    if (!File('web/flutter_filament.wasm').existsSync() || chrome == null) {
      markTestSkipped('needs web/flutter_filament.wasm (tool/web/build_module.sh) and Chrome');
      return;
    }

    // The app serves the module next to its index.html.
    for (final f in ['flutter_filament.js', 'flutter_filament.wasm']) {
      File('web/$f').copySync('example/web/$f');
    }
    final build = await Process.run(
      'flutter',
      ['build', 'web', '-t', 'lib/web_smoke.dart', '--release', '--no-web-resources-cdn'],
      workingDirectory: 'example',
    );
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');

    final root = Directory('example/build/web');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final path = request.uri.path == '/' ? '/index.html' : request.uri.path;
      final file = File('${root.path}$path');
      if (path.contains('..') || !file.existsSync()) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.headers.contentType = _contentType(path);
        await request.response.addStream(file.openRead());
      }
      await request.response.close();
    });

    final browser = await puppeteer.launch(
      executablePath: chrome,
      headless: true,
      args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--no-sandbox'],
    );
    addTearDown(browser.close);
    final page = await browser.newPage();
    final errors = <String>[];
    page.onError.listen((e) => errors.add('pageerror: ${e.message}'));
    page.onConsole.listen((m) {
      if (m.type == ConsoleMessageType.error) errors.add('console: ${m.text}');
    });
    await page.setViewport(DeviceViewport(width: 640, height: 400));
    await page.goto('http://127.0.0.1:${server.port}/', wait: Until.load);

    // Scene created once, frames flowing.
    await page.waitForFunction(
        '() => window.flutterFilamentSmoke && window.flutterFilamentSmoke.created === 1 && window.flutterFilamentSmoke.frames >= 30',
        timeout: const Duration(seconds: 120));
    expect(await page.evaluate<List>(_canvasSize), [640, 400], reason: 'the drawing buffer follows the layout');

    final png = Uint8List.fromList(await page.screenshot());
    SmokeArtifacts.saveScreenshot(_name, png);
    final frame = img.decodePng(png)!;
    final corner = frame.getPixel(4, 4);
    final centre = frame.getPixel(frame.width ~/ 2, frame.height ~/ 2);
    final diff = (centre.r - corner.r).abs() + (centre.g - corner.g).abs() + (centre.b - corner.b).abs();
    expect(diff, greaterThan(60), reason: 'Suzanne at the centre (${centre.r},${centre.g},${centre.b}) vs clear colour (${corner.r},${corner.g},${corner.b})');

    // A bigger window: the canvas and the view's viewport follow.
    await page.setViewport(DeviceViewport(width: 800, height: 500));
    await page.waitForFunction('() => window.flutterFilamentSmoke.frames >= 60', timeout: const Duration(seconds: 60));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(await page.evaluate<List>(_canvasSize), [800, 500]);

    // Unmount: the engine is disposed and the canvas leaves the page.
    await page.evaluate<void>('() => { window.flutterFilamentUnmount = true; }');
    await page.waitForFunction('() => window.flutterFilamentSmoke.disposed === true', timeout: const Duration(seconds: 30));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(await page.evaluate<Object?>(_canvasSize), isNull, reason: 'the canvas is removed on dispose');

    expect(errors, isEmpty, reason: errors.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
