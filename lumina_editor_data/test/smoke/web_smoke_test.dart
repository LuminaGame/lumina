import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaProject, ProjectWebLoadingStyle, WebLoadingScreenService;
import 'package:lumina/testing.dart';
import 'package:puppeteer/puppeteer.dart';

import '../web/web_game_build.dart';

/// The scaffolded Third Person game, built with `flutter build web`,
/// served and played in headless Chrome (SwiftShader WebGL2): the mannequin
/// loads from the asset bundle and walks.
const _chromeCandidates = ['/usr/bin/google-chrome', '/usr/bin/chromium', '/snap/bin/chromium'];
const _name = 'web: Third Person game in Chrome';
const _spawned = 'LUMINA_SMOKE mannequin spawned';
const _loadingName = 'web: styled loading screen in Chrome';

/// How fast the loading-screen smoke serves the heavy files, so the load
/// lasts long enough to film (>= 10 s).
const _throttleBytesPerSecond = 2 * 1024 * 1024;

/// Runs before the page's scripts: notes Flutter's first-frame event and
/// whether the loading screen was still up when it came.
const _firstFrameProbe = '''() => {
  window.addEventListener('flutter-first-frame', () => {
    window.__wlsFirstFrame = {
      at: performance.now(),
      overlayPresent: !!document.getElementById('lumina-loading'),
      hiddenBefore: !!(window.luminaLoading && window.luminaLoading.hidden),
    };
  });
}''';

/// The loading screen's state, as `window.luminaLoading` reports it.
const _loadingState = '''() => window.luminaLoading ? {
  fraction: window.luminaLoading.fraction,
  label: window.luminaLoading.label,
  hidden: window.luminaLoading.hidden,
} : null''';

ContentType _contentType(String path) => switch (path.split('.').last) {
      'wasm' => ContentType('application', 'wasm'),
      'js' || 'mjs' => ContentType('text', 'javascript', charset: 'utf-8'),
      'html' => ContentType.html,
      'json' => ContentType.json,
      'css' => ContentType('text', 'css', charset: 'utf-8'),
      'png' => ContentType('image', 'png'),
      'svg' => ContentType('image', 'svg+xml'),
      _ => ContentType.binary,
    };

/// The console marker, written into the character's user-code region the way
/// a developer would add a log line. The Third Person
/// character is `BP_ThirdPersonCharacter`, compiled into `lib/actors/`; its
/// `class_body` region survives recompiles.
void _addSpawnMarker(String project) {
  final character = File('$project/lib/actors/bp_third_person_character.dart');
  final source = character.readAsStringSync();
  const region = '  // BEGIN USER CODE: class_body\n';
  expect(source, contains(region));
  character.writeAsStringSync(source.replaceFirst(
    region,
    '$region'
    '  @override\n'
    '  void onRegister(LuminaWorld world) {\n'
    '    super.onRegister(world);\n'
    "    (blueprintComponents['mesh'] as LuminaStaticMeshComponent).loaded.then((_) => print('$_spawned'));\n"
    '  }\n',
  ));
}

void main() {
  test(_name, () async {
    final module = flutterFilamentWebModule();
    final chrome = _chromeCandidates.where((p) => File(p).existsSync()).firstOrNull;
    if (module == null || chrome == null) {
      markTestSkipped('needs flutter_filament/web/flutter_filament.wasm (tool/web/build_module.sh) and Chrome');
      return;
    }
    final root = Directory.systemTemp.createTempSync('lumina_web_smoke_');
    addTearDown(() => root.deleteSync(recursive: true));
    final project = await buildThirdPersonGameForWeb(root, module, customize: _addSpawnMarker);

    final web = '$project/build/web';
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final path = request.uri.path == '/' ? '/index.html' : Uri.decodeComponent(request.uri.path);
      final file = File('$web$path');
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
    final spawned = Completer<void>();
    page.onError.listen((e) => errors.add('pageerror: ${e.message}'));
    page.onConsole.listen((m) {
      if (m.text == _spawned && !spawned.isCompleted) spawned.complete();
      if (m.type == ConsoleMessageType.error) errors.add('console: ${m.text}');
    });
    // Smoke videos are at least 1024×768.
    await page.setViewport(DeviceViewport(width: SmokeVideo.defaultWidth, height: SmokeVideo.defaultHeight));
    await page.goto('http://127.0.0.1:${server.port}/', wait: Until.load);

    await spawned.future.timeout(const Duration(minutes: 3),
        onTimeout: () => fail('the mannequin never loaded; page errors:\n${errors.join('\n')}'));
    await Future<void>.delayed(const Duration(seconds: 2));

    final png = Uint8List.fromList(await page.screenshot());
    SmokeArtifacts.saveScreenshot(_name, png,
        usedAssets: const ['contents/meshes/skeletal/SKM_Superhero_Female.entity.glb']);
    final frame = img.decodePng(png)!;
    final sky = frame.getPixel(frame.width ~/ 2, 8);
    final body = frame.getPixel(frame.width ~/ 2, frame.height * 3 ~/ 5);
    final diff = (body.r - sky.r).abs() + (body.g - sky.g).abs() + (body.b - sky.b).abs();
    expect(diff, greaterThan(60),
        reason: 'the level is drawn below the sky (${body.r},${body.g},${body.b}) vs (${sky.r},${sky.g},${sky.b})');

    // Walk a square — W, D, S, A, 3 s each — while Chrome streams every frame
    // it paints. The video lays those frames on a real-time 30 fps timeline:
    // each video frame is the newest one Chrome had painted by then
    // (>= 10 s of the game actually running).
    final painted = <(int, Uint8List)>[];
    final clock = Stopwatch()..start();
    final screencast = page.devTools.page.onScreencastFrame.listen((e) {
      painted.add((clock.elapsedMilliseconds, base64Decode(e.data)));
      page.devTools.page.screencastFrameAck(e.sessionId);
    });
    await page.devTools.page.startScreencast(format: 'png', everyNthFrame: 1);
    await page.mouse.click(Point(SmokeVideo.defaultWidth / 2, SmokeVideo.defaultHeight / 2));
    final walkStart = clock.elapsedMilliseconds;
    for (final key in [Key.keyW, Key.keyD, Key.keyS, Key.keyA]) {
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
    print('web smoke: Chrome painted ${painted.length} frames in ${(walkEnd - walkStart) / 1000} s of walking');
    SmokeArtifacts.saveVideo(
      _name,
      video.finish(),
      usedAssets: const ['contents/meshes/skeletal/SKM_Superhero_Female.entity.glb'],
    );

    expect(errors, isEmpty, reason: errors.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 15)));
  // The project-styled HTML loading
  // screen: shown from the first byte, filled by the real downloads (served
  // throttled so the load takes long enough to watch), gone on the first frame.
  test(_loadingName, () async {
    final module = flutterFilamentWebModule();
    final chrome = _chromeCandidates.where((p) => File(p).existsSync()).firstOrNull;
    if (module == null || chrome == null) {
      markTestSkipped('needs flutter_filament/web/flutter_filament.wasm (tool/web/build_module.sh) and Chrome');
      return;
    }
    final root = Directory.systemTemp.createTempSync('wls_web_smoke_');
    addTearDown(() => root.deleteSync(recursive: true));
    final project = await buildThirdPersonGameForWeb(root, module, name: 'wls_game', customize: (project) {
      _addSpawnMarker(project);
      // Project Settings > Web Loading Style, then what packaging does before
      // `flutter build web` (the editor passes its rasterized project icon).
      final manifest = File('$project/wls_game.lmproject');
      final saved = LuminaProject.fromMap(jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>);
      final styled = saved.copyWith(
        packaging: saved.packaging.copyWith(
          targets: ['linux', 'web'],
          webLoadingStyle: const ProjectWebLoadingStyle(
            background: '#101418',
            gradient: '#2A1A0C',
            accent: '#FB7C01',
            title: 'Barrel Run',
            subtitle: 'A Lumina web build',
            fadeMs: 800,
          ),
        ),
      );
      manifest.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(styled.toMap()));
      final report = WebLoadingScreenService.write(
        projectDir: project,
        project: styled,
        iconPng: File('../lumina_ui/assets/logo_color.png').readAsBytesSync(),
      );
      expect(report.written, isTrue, reason: report.skippedReason);
    });
    final web = '$project/build/web';
    expect(File('$web/loading.js').existsSync(), isTrue, reason: 'flutter build web copies the loading screen');
    expect(File('$web/loading_logo.png').existsSync(), isTrue);
    expect(File('$web/flutter_bootstrap.js').readAsStringSync(), contains('window.luminaLoading.attach(_flutter.loader)'));

    // The heavy files are served throttled to _throttleBytesPerSecond.
    final heavy = RegExp(r'\.(wasm|js|mjs|glb|lmas|filamat|ktx|png|bin)$');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final path = request.uri.path == '/' ? '/index.html' : Uri.decodeComponent(request.uri.path);
      final file = File('$web$path');
      final response = request.response;
      if (path.contains('..') || !file.existsSync()) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      response.headers.contentType = _contentType(path);
      final bytes = file.readAsBytesSync();
      response.contentLength = bytes.length;
      try {
        if (!heavy.hasMatch(path)) {
          response.add(bytes);
        } else {
          const chunk = 32 * 1024;
          for (var i = 0; i < bytes.length; i += chunk) {
            response.add(bytes.sublist(i, (i + chunk).clamp(0, bytes.length)));
            await response.flush();
            await Future<void>.delayed(Duration(microseconds: chunk * 1000000 ~/ _throttleBytesPerSecond));
          }
        }
        await response.close();
      } catch (_) {/* the browser closed the page */}
    });

    final browser = await puppeteer.launch(
      executablePath: chrome,
      headless: true,
      args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--no-sandbox'],
    );
    addTearDown(browser.close);
    final page = await browser.newPage();
    final errors = <String>[];
    final spawned = Completer<void>();
    page.onError.listen((e) => errors.add('pageerror: ${e.message}'));
    page.onConsole.listen((m) {
      if (m.text == _spawned && !spawned.isCompleted) spawned.complete();
      if (m.type == ConsoleMessageType.error) errors.add('console: ${m.text}');
    });
    // Records Flutter's first-frame event as it arrives, before loading.js reacts.
    await page.evaluateOnNewDocument(_firstFrameProbe);
    await page.setViewport(DeviceViewport(width: SmokeVideo.defaultWidth, height: SmokeVideo.defaultHeight));

    final painted = <(int, Uint8List)>[];
    final clock = Stopwatch()..start();
    final screencast = page.devTools.page.onScreencastFrame.listen((e) {
      painted.add((clock.elapsedMilliseconds, base64Decode(e.data)));
      page.devTools.page.screencastFrameAck(e.sessionId);
    });
    await page.devTools.page.startScreencast(format: 'png', everyNthFrame: 1);
    final loadStart = clock.elapsedMilliseconds;
    await page.goto('http://127.0.0.1:${server.port}/', wait: Until.domContentLoaded);

    // Poll the screen while it loads: its fraction only grows, through the
    // engine, the renderer and the asset preload.
    final samples = <(double, String)>[];
    Uint8List? midLoad;
    while (true) {
      final state = await page.evaluate<Map<dynamic, dynamic>?>(_loadingState);
      expect(state, isNotNull, reason: 'loading.js defines window.luminaLoading before anything loads');
      final fraction = (state!['fraction'] as num).toDouble();
      samples.add((fraction, state['label'] as String));
      if (state['hidden'] == true) break;
      if (midLoad == null && fraction > 0.3 && fraction < 0.8) {
        midLoad = Uint8List.fromList(await page.screenshot());
        SmokeArtifacts.saveScreenshot('$_loadingName: mid-load', midLoad);
      }
      if (clock.elapsedMilliseconds - loadStart > 240000) fail('the loading screen never hid; samples: $samples\n${errors.join('\n')}');
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final firstFrame = await page.evaluate<Map<dynamic, dynamic>?>('() => window.__wlsFirstFrame || null');
    expect(firstFrame, isNotNull, reason: 'the screen hid only after flutter-first-frame');
    expect(firstFrame!['overlayPresent'], isTrue, reason: 'the screen covered the page until the first frame');
    expect(firstFrame['hiddenBefore'], isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 1200)); // fadeMs 800, then removal
    expect(await page.evaluate<bool>("() => document.getElementById('lumina-loading') === null"), isTrue,
        reason: 'the faded screen is removed from the page');
    await spawned.future.timeout(const Duration(minutes: 3),
        onTimeout: () => fail('the mannequin never loaded; page errors:\n${errors.join('\n')}'));
    await Future<void>.delayed(const Duration(seconds: 3));
    final loadEnd = clock.elapsedMilliseconds;
    await page.devTools.page.stopScreencast();
    await screencast.cancel();
    final game = Uint8List.fromList(await page.screenshot());
    SmokeArtifacts.saveScreenshot('$_loadingName: game after the fade', game,
        usedAssets: const ['contents/meshes/skeletal/SKM_Superhero_Female.entity.glb']);

    for (var i = 1; i < samples.length; i++) {
      expect(samples[i].$1, greaterThanOrEqualTo(samples[i - 1].$1), reason: 'progress never goes backwards: $samples');
    }
    final labels = samples.map((s) => s.$2).toSet();
    expect(labels.any((l) => l.startsWith('Downloading the engine')), isTrue, reason: '$labels');
    expect(labels.any((l) => l.startsWith('Downloading the renderer') || l == 'Loading the renderer'), isTrue, reason: '$labels');
    expect(labels.any((l) => l.startsWith('Loading game assets')), isTrue, reason: '$labels');
    expect(midLoad, isNotNull, reason: 'a partially filled bar was on screen: $samples');

    // The mid-load frame is the styled screen: the accent fill and the dark
    // project background; after the fade the game is on screen instead.
    final shot = img.decodePng(midLoad!)!;
    var accent = 0;
    for (var y = 0; y < shot.height; y += 2) {
      for (var x = 0; x < shot.width; x += 2) {
        final p = shot.getPixel(x, y);
        if ((p.r - 0xFB).abs() < 24 && (p.g - 0x7C).abs() < 24 && (p.b - 0x01).abs() < 24) accent++;
      }
    }
    expect(accent, greaterThan(50), reason: 'the accent-coloured progress fill is visible');
    final corner = shot.getPixel(4, 4);
    expect(corner.r + corner.g + corner.b, lessThan(120), reason: 'the dark project background');
    final after = img.decodePng(game)!;
    final centre = after.getPixel(after.width ~/ 2, after.height * 3 ~/ 5);
    expect((centre.r - corner.r).abs() + (centre.g - corner.g).abs() + (centre.b - corner.b).abs(), greaterThan(30),
        reason: 'the game, not the loading screen, is on screen after the fade');

    const fps = 30;
    final video = SmokeVideoRecorder(width: shot.width, height: shot.height, fps: fps, testName: _loadingName);
    addTearDown(video.discard);
    var next = 0;
    Uint8List? rgba;
    for (var t = loadStart.toDouble(); t < loadEnd; t += 1000 / fps) {
      Uint8List? newest;
      while (next < painted.length && painted[next].$1 <= t) {
        newest = painted[next++].$2;
      }
      if (newest != null) {
        var frame = img.decodePng(newest)!;
        if (frame.width != shot.width || frame.height != shot.height) {
          frame = img.copyResize(frame, width: shot.width, height: shot.height);
        }
        rgba = frame.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
      }
      if (rgba != null) video.addFrame(rgba);
    }
    // ignore: avoid_print
    print('web loading smoke: ${(loadEnd - loadStart) / 1000} s from navigation to 3 s after the mannequin; '
        '${samples.length} samples, labels $labels');
    SmokeArtifacts.saveVideo(_loadingName, video.finish(),
        usedAssets: const ['contents/meshes/skeletal/SKM_Superhero_Female.entity.glb']);
    expect(errors, isEmpty, reason: errors.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
