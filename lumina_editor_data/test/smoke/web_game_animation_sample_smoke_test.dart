import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/testing.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaWorkspace;
import 'package:puppeteer/puppeteer.dart';

import '../web/web_game_build.dart';

/// The Game Animation Sample example project built for the web with this
/// checkout's flutter_filament module and played in headless Chrome on the
/// GPU (on Windows through ANGLE's Direct3D 11 backend, Chrome's default
/// there): the level, its fog and the glTF ubershader props, and the
/// MetaHuman character draw, and no WebGL context is lost. The project is
/// built locally from the sample's export and a MetaHuman (neither can be
/// shipped): the scenario skips without it.
const _name = 'web: Game Animation Sample renders on the GPU in Chrome without losing the WebGL context';

const _chromeCandidates = [
  r'C:\Program Files\Google\Chrome\Application\chrome.exe',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
  '/snap/bin/chromium',
];

String get _projectDir =>
    Platform.environment['LUMINA_GASP_PROJECT_DIR'] ?? '${LuminaWorkspace.home}/Lumina Projects/game_animation_sample';

/// Console lines that mean the page lost its GPU: the GPU process crashed (or
/// the context was reset) and every program link after it fails.
final _gpuLoss = RegExp(r'CONTEXT_LOST_WEBGL|Link error in|arena is full');

/// The renderer the page's WebGL 2 context runs on.
const _rendererProbe = '''() => {
  const gl = document.createElement('canvas').getContext('webgl2');
  if (!gl) return 'no webgl2';
  const info = gl.getExtension('WEBGL_debug_renderer_info');
  return info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER);
}''';

ContentType _contentType(String path) => switch (path.split('.').last) {
      'wasm' => ContentType('application', 'wasm'),
      'js' || 'mjs' => ContentType('text', 'javascript', charset: 'utf-8'),
      'html' => ContentType.html,
      'json' => ContentType.json,
      'css' => ContentType('text', 'css', charset: 'utf-8'),
      'png' => ContentType('image', 'png'),
      _ => ContentType.binary,
    };

void main() {
  test(_name, () async {
    final module = flutterFilamentWebModule();
    final chrome = _chromeCandidates.where((p) => File(p).existsSync()).firstOrNull;
    final project = Directory(_projectDir);
    if (module == null || chrome == null || !File('${project.path}/pubspec.yaml').existsSync()) {
      markTestSkipped('needs flutter_filament/web/flutter_filament.wasm (tool/web/build_module.sh), Chrome and '
          'the Game Animation Sample project ($_projectDir)');
      return;
    }

    // Build into a temporary folder (the project's own build/web stays as
    // packaging left it), then put the module next to index.html as
    // packaging does.
    final out = Directory.systemTemp.createTempSync('gasp_web_');
    addTearDown(() => out.deleteSync(recursive: true));
    final build = await Process.run(
      'flutter',
      ['build', 'web', '--release', '--no-web-resources-cdn', '--output', out.path],
      workingDirectory: project.path,
      runInShell: Platform.isWindows,
    );
    expect(build.exitCode, 0, reason: 'flutter build web failed:\n${build.stdout}\n${build.stderr}');
    for (final f in ['flutter_filament.js', 'flutter_filament.wasm']) {
      File('${module.path}/$f').copySync('${out.path}/$f');
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final path = request.uri.path == '/' ? '/index.html' : Uri.decodeComponent(request.uri.path);
      final file = File('${out.path}$path');
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
      args: [
        '--enable-gpu',
        '--ignore-gpu-blocklist',
        if (Platform.isWindows) '--use-angle=d3d11' else '--use-angle=vulkan',
        if (!Platform.isWindows) '--no-sandbox',
      ],
    );
    addTearDown(browser.close);
    final page = await browser.newPage();
    final console = <String>[];
    final errors = <String>[];
    page.onError.listen((e) => errors.add('pageerror: ${e.message}'));
    page.onConsole.listen((m) {
      console.add(m.text ?? '');
      if (m.type == ConsoleMessageType.error) errors.add('console: ${m.text ?? ''}');
    });
    await page.setViewport(DeviceViewport(width: SmokeVideo.defaultWidth, height: SmokeVideo.defaultHeight));
    await page.goto('http://127.0.0.1:${server.port}/', wait: Until.load);
    final renderer = await page.evaluate<String>(_rendererProbe);
    // ignore: avoid_print
    print('web GASP smoke: WebGL renderer $renderer');

    // The loading screen goes once the level's assets (the 324 MB MetaHuman
    // among them) are in; then give the character a few frames to appear.
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    while (true) {
      final hidden = await page.evaluate<bool>('() => !!(window.luminaLoading && window.luminaLoading.hidden)');
      if (hidden) break;
      if (DateTime.now().isAfter(deadline)) fail('the game never finished loading; page errors:\n${errors.join('\n')}');
      if (console.any(_gpuLoss.hasMatch)) break;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    await Future<void>.delayed(const Duration(seconds: 8));
    expect(console.where(_gpuLoss.hasMatch).toList(), isEmpty, reason: 'the page lost its GPU:\n${console.join('\n')}');

    final png = Uint8List.fromList(await page.screenshot());
    const usedAssets = [
      'contents/levels/L_Sandbox.lmas',
      'contents/materials/M_Grid_Block.lmas',
      'contents/meshes/skeletal/SK_MH_Sandbox.entity.glb',
      'contents/meshes/static/ac_unit_a_300x300.entity.glb',
      'contents/meshes/static/hay_bale_2x1.entity.glb',
    ];
    SmokeArtifacts.saveScreenshot(_name, png, usedAssets: usedAssets);
    final frame = img.decodePng(png)!;
    final sky = frame.getPixel(frame.width ~/ 2, 8);
    final floor = frame.getPixel(frame.width ~/ 4, frame.height * 7 ~/ 8);
    final diff = (floor.r - sky.r).abs() + (floor.g - sky.g).abs() + (floor.b - sky.b).abs();
    expect(diff, greaterThan(40),
        reason: 'the level is drawn below the sky (${floor.r},${floor.g},${floor.b}) vs (${sky.r},${sky.g},${sky.b})');

    // The first walk and the first turn stall the single-threaded page for a
    // few seconds (locomotion data and shader variants seen for the first
    // time): play the same moves once before filming.
    await page.mouse.click(Point(SmokeVideo.defaultWidth / 2, SmokeVideo.defaultHeight / 2));
    for (final key in [Key.keyW, Key.keyD, Key.keyW, Key.keyA]) {
      await page.keyboard.down(key);
      await Future<void>.delayed(const Duration(seconds: 3));
      await page.keyboard.up(key);
    }
    await Future<void>.delayed(const Duration(seconds: 2));

    // Walk forward, then turn with D, 12 s in all, while Chrome streams every
    // frame it paints; the video lays them on a real-time 30 fps timeline.
    final painted = <(int, Uint8List)>[];
    final clock = Stopwatch()..start();
    final screencast = page.devTools.page.onScreencastFrame.listen((e) {
      painted.add((clock.elapsedMilliseconds, base64Decode(e.data)));
      page.devTools.page.screencastFrameAck(e.sessionId);
    });
    await page.devTools.page.startScreencast(format: 'png', everyNthFrame: 1);
    await page.mouse.click(Point(SmokeVideo.defaultWidth / 2, SmokeVideo.defaultHeight / 2));
    final walkStart = clock.elapsedMilliseconds;
    for (final key in [Key.keyW, Key.keyD, Key.keyW, Key.keyA]) {
      await page.keyboard.down(key);
      await Future<void>.delayed(const Duration(seconds: 3));
      await page.keyboard.up(key);
    }
    final walkEnd = clock.elapsedMilliseconds;
    await page.devTools.page.stopScreencast();
    await screencast.cancel();

    const fps = 30;
    final video = SmokeVideoRecorder(width: frame.width, height: frame.height, fps: fps, testName: _name);
    addTearDown(video.discard);
    var next = 0;
    Uint8List? rgba;
    for (var t = walkStart.toDouble(); t < walkEnd; t += 1000 / fps) {
      Uint8List? newest;
      while (next < painted.length && painted[next].$1 <= t) {
        newest = painted[next++].$2;
      }
      if (newest != null) {
        var shot = img.decodePng(newest)!;
        if (shot.width != frame.width || shot.height != frame.height) {
          shot = img.copyResize(shot, width: frame.width, height: frame.height);
        }
        rgba = shot.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
      }
      if (rgba != null) video.addFrame(rgba);
    }
    // ignore: avoid_print
    print('web GASP smoke: Chrome painted ${painted.length} frames in ${(walkEnd - walkStart) / 1000} s');
    for (var i = 1; i < painted.length; i++) {
      final gap = painted[i].$1 - painted[i - 1].$1;
      // ignore: avoid_print
      if (gap > 700) print('web GASP smoke: no new frame for $gap ms at ${painted[i - 1].$1 - walkStart} ms');
    }
    SmokeArtifacts.saveVideo(_name, video.finish(), usedAssets: usedAssets);

    expect(console.where(_gpuLoss.hasMatch).toList(), isEmpty, reason: 'the page lost its GPU:\n${console.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 30)));
}
