import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/testing.dart';
import 'package:puppeteer/puppeteer.dart';

import '../../../lumina/test/support/viewport_project.dart';

/// The UMG Viewport on the web: lumina's example web app
/// (lumina/example/lib/viewport_web_smoke.dart) is built with `flutter build
/// web`, served with real `.lmas` props, and driven in headless Chrome (no
/// window). Two Viewports render their framed, orbiting prop on their own
/// WebGL2 canvases; the third shows the "Viewport limit reached"
/// placeholder (the web's limit is 2).
const _name = 'umg viewport web: two viewports render, the third shows the limit placeholder';
const _chromeCandidates = [
  r'C:\Program Files\Google\Chrome\Application\chrome.exe',
  r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
  '/snap/bin/chromium',
];

ContentType _contentType(String path) => switch (path.split('.').last) {
      'wasm' => ContentType('application', 'wasm'),
      'js' || 'mjs' => ContentType('text', 'javascript', charset: 'utf-8'),
      'html' => ContentType.html,
      'json' => ContentType.json,
      _ => ContentType.binary,
    };

void main() {
  test(_name, () async {
    final chrome = _chromeCandidates.where((p) => File(p).existsSync()).firstOrNull;
    final module = Directory('../flutter_filament/web');
    if (!File('${module.path}/flutter_filament.wasm').existsSync() || chrome == null) {
      markTestSkipped('needs flutter_filament/web/flutter_filament.wasm (tool/web/build_module.sh) and Chrome');
      return;
    }
    if (!ViewportTestProject.available) {
      markTestSkipped('test-assets models missing');
      return;
    }
    final project = ViewportTestProject.create();
    addTearDown(project.delete);

    // The app serves the module next to its index.html.
    const app = '../lumina/example';
    for (final f in ['flutter_filament.js', 'flutter_filament.wasm']) {
      File('${module.path}/$f').copySync('$app/web/$f');
    }
    final build = await Process.run(
      'flutter',
      ['build', 'web', '-t', 'lib/viewport_web_smoke.dart', '--release', '--no-web-resources-cdn'],
      workingDirectory: app,
      runInShell: Platform.isWindows,
    );
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');

    // The page, and the props under viewport_assets/ (their project paths).
    final root = Directory('$app/build/web');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      var path = request.uri.path == '/' ? '/index.html' : Uri.decodeComponent(request.uri.path);
      File file;
      if (path.startsWith('/viewport_assets/')) {
        path = path.substring('/viewport_assets'.length);
        file = File('${project.dir.path}$path');
      } else {
        file = File('${root.path}$path');
      }
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
    const width = 1280;
    const height = 800;
    await page.setViewport(DeviceViewport(width: width, height: height));
    await page.goto('http://127.0.0.1:${server.port}/', wait: Until.load);

    // Two previews loaded and rendering, the third refused.
    await page.waitForFunction(
      '() => { const s = window.luminaViewportSmoke; return s && (s.failed !== "" || (s.ready >= 2 && s.controllers === 2 && s.refused === 1 && s.frames >= 20)); }',
      timeout: const Duration(seconds: 240),
    );
    final state = await page.evaluate<Map>('() => window.luminaViewportSmoke');
    expect(state['failed'], '', reason: 'every prop loads');
    expect(state['controllers'], 2, reason: 'the web renders two Viewports');
    expect(state['refused'], 1, reason: 'the third shows the limit placeholder');

    // Each rendering Viewport shows its prop at the centre, over the sky.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final png = Uint8List.fromList(await page.screenshot());
    final frame = img.decodePng(png)!;
    final metrics = {'controllers': state['controllers'], 'refused': state['refused'], 'ready': state['ready'], 'frames': state['frames'], 'cameras': state['cameras']};
    SmokeArtifacts.saveScreenshot(_name, png, usedAssets: ViewportTestProject.sources.values.toList(), metrics: metrics);
    const pad = 16;
    final column = (width - pad * 4) / 3;
    for (var i = 0; i < 2; i++) {
      final left = pad + i * (column + pad);
      final sky = frame.getPixel((left + 6).round(), pad + 6);
      var differs = 0;
      var total = 0;
      for (var y = height * 0.35; y < height * 0.65; y += 4) {
        for (var x = left + column * 0.35; x < left + column * 0.65; x += 4) {
          final p = frame.getPixel(x.round(), y.round());
          if ((p.r - sky.r).abs() + (p.g - sky.g).abs() + (p.b - sky.b).abs() > 60) differs++;
          total++;
        }
      }
      expect(differs / total, greaterThan(0.2), reason: 'Viewport $i draws its framed prop at the centre');
    }

    // The video: 11 s of real page frames (the props orbit).
    final video = SmokeVideoRecorder(width: width, height: height, fps: 30, testName: _name);
    addTearDown(video.discard);
    Uint8List? last;
    while (video.frameCount < 330) {
      final shot = img.decodePng(Uint8List.fromList(await page.screenshot()))!;
      final rgba = shot.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
      if (last != null && SmokeVideoRecorder.sameBytes(last, rgba)) continue;
      last = rgba;
      video.addFrame(rgba);
    }
    SmokeArtifacts.saveVideo(_name, video.finish(), usedAssets: ViewportTestProject.sources.values.toList());
    expect(errors, isEmpty, reason: errors.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
