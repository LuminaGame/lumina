import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/testing.dart';
import 'package:puppeteer/puppeteer.dart';

const _name = 'physics web: Jolt runs the rigid body tests and a barrel tower collapses in the browser';
const _chromeCandidates = [
  r'C:\Program Files\Google\Chrome\Application\chrome.exe',
  r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
  '/snap/bin/chromium',
];
const _props = [
  'Props/Barrels/fuel_barrel_red.glb',
  'Props/Barrels/fuel_barrel_yellow.glb',
  'Props/AC_units/roof_aircon_unit_150x150_a.glb',
];

ContentType _contentType(String path) => switch (path.split('.').last) {
      'wasm' => ContentType('application', 'wasm'),
      'js' || 'mjs' => ContentType('text', 'javascript', charset: 'utf-8'),
      'html' => ContentType.html,
      'json' => ContentType.json,
      _ => ContentType.binary,
    };

/// Jolt Physics on the web: the lumina example's physics web smoke app
/// (example/web_smoke/physics_web_smoke.dart) built with both WebAssembly
/// modules (flutter_filament's renderer and flutter_jolt's physics), served
/// with real props from test-assets and driven in headless Chrome. The page
/// runs the engine's rigid body test file on the Jolt backend, then draws a
/// tower of barrels that a thrown barrel knocks down beside stacked
/// air-conditioning units. PNG + 11 s video.
void main() {
  test(_name, () async {
    final chrome = _chromeCandidates.where((p) => File(p).existsSync()).firstOrNull;
    final filament = Directory('../flutter_filament/web');
    final jolt = Directory('../../tools/flutter_jolt/web');
    if (!File('${filament.path}/flutter_filament.wasm').existsSync() ||
        !File('${jolt.path}/flutter_jolt.wasm').existsSync() ||
        chrome == null) {
      markTestSkipped('needs flutter_filament/web/flutter_filament.wasm, tools/flutter_jolt/web/flutter_jolt.wasm '
          '(tool/web/build_module.sh, tool/web/build_jolt_wasm.sh) and Chrome');
      return;
    }
    final assets = SmokeArtifacts.testAssetsDir;
    final used = [for (final a in _props) '${assets.path}/$a'];
    if (used.any((a) => !File(a).existsSync())) {
      markTestSkipped('test-assets props missing');
      return;
    }

    const app = '../lumina/example';
    for (final (dir, files) in [
      (filament, ['flutter_filament.js', 'flutter_filament.wasm']),
      (jolt, ['flutter_jolt.js', 'flutter_jolt.wasm']),
    ]) {
      for (final f in files) {
        File('${dir.path}/$f').copySync('$app/web/$f');
      }
    }
    final build = await Process.run(
      'flutter',
      ['build', 'web', '-t', 'web_smoke/physics_web_smoke.dart', '--release', '--no-web-resources-cdn'],
      workingDirectory: app,
      runInShell: Platform.isWindows,
    );
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');

    final root = Directory('$app/build/web');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      var path = request.uri.path == '/' ? '/index.html' : Uri.decodeComponent(request.uri.path);
      File file;
      if (path.startsWith('/physics_assets/')) {
        path = path.substring('/physics_assets'.length);
        file = File('${assets.path}$path');
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

    // The rigid body tests ran on Jolt, and the scene renders.
    await page.waitForFunction(
      '() => { const s = window.luminaPhysicsSmoke; return s && s.tests !== undefined && s.ready === true && s.frames >= 30; }',
      timeout: const Duration(seconds: 300),
    );
    var state = await page.evaluate<Map>('() => window.luminaPhysicsSmoke');
    expect(state['jolt'], isTrue, reason: 'the flutter_jolt module loaded');
    expect(state['backend'], 'jolt');
    expect(state['sceneBackend'], 'jolt');
    expect(state['failed'], 0, reason: '${state['failures']}');
    expect(state['tests'], 8, reason: 'every rigid body test ran');
    expect(state['failedAssets'], '', reason: 'every prop loads');

    final standing = Uint8List.fromList(await page.screenshot());
    SmokeArtifacts.saveScreenshot('$_name 01 the tower stands', standing, usedAssets: used, metrics: {
      'rigidBodyTests': state['tests'],
      'rigidBodyTestsPassed': state['passed'],
    });

    // The video: 11 s of real page frames — the throw at 2.5 s and the fall.
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
    state = await page.evaluate<Map>('() => window.luminaPhysicsSmoke');
    expect(state['thrown'], isTrue, reason: 'the barrel was thrown');
    expect(state['impulse'], isTrue, reason: 'the throw reached its body');
    expect(state['towerMovedCm'] as num, greaterThan(20), reason: 'the thrown barrel knocks the tower');
    final fallen = Uint8List.fromList(await page.screenshot());
    final metrics = {
      'jolt': state['jolt'],
      'rigidBodyTests': state['tests'],
      'stepMs': state['stepMs'],
      'frames': state['frames'],
      'lowestBarrelCm': state['lowestBarrel'],
      'towerMovedCm': state['towerMovedCm'],
      'thrownXCm': state['thrownX'],
      'settled': state['settled'],
    };
    // ignore: avoid_print
    print('physics web smoke: $metrics');
    SmokeArtifacts.saveScreenshot('$_name 02 after the throw', fallen, usedAssets: used, metrics: metrics);
    SmokeArtifacts.saveVideo(_name, video.finish(), usedAssets: used);
    expect(errors, isEmpty, reason: errors.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 25)));
}
