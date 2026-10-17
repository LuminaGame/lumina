/// Serves a packaged web game, opens it in headless Chrome and drives it like
/// a player: click the game, hold W, move the mouse. Writes the console
/// output and before/after screenshots to [outDir], and prints how much of
/// the picture changed. For diagnosing input in web builds.
///
/// ```
/// dart run tool/web_game_input_probe.dart <package web dir> <out dir>
/// ```
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' show Point;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart' as pptr;

const _types = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.wasm': 'application/wasm',
  '.json': 'application/json',
  '.css': 'text/css',
  '.png': 'image/png',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.bin': 'application/octet-stream',
};

Future<void> main(List<String> args) async {
  final root = args[0];
  final out = Directory(args[1])..createSync(recursive: true);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    var path = Uri.decodeComponent(req.uri.path);
    if (path.endsWith('/')) path = '${path}index.html';
    final file = File(p.join(root, path.substring(1)));
    if (!await file.exists()) {
      req.response.statusCode = 404;
      await req.response.close();
      return;
    }
    req.response.headers.contentType = ContentType.parse(_types[p.extension(file.path)] ?? 'application/octet-stream');
    await req.response.addStream(file.openRead());
    await req.response.close();
  });
  final url = 'http://127.0.0.1:${server.port}/';
  final chrome = Platform.isWindows
      ? r'C:\Program Files\Google\Chrome\Application\chrome.exe'
      : '/usr/bin/google-chrome';
  final browser = await pptr.puppeteer.launch(
    executablePath: chrome,
    headless: true,
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--no-sandbox'],
  );
  final log = StringBuffer();
  try {
    final page = await browser.newPage();
    page.onError.listen((e) => log.writeln('pageerror: ${e.message}'));
    page.onConsole.listen((m) => log.writeln('console.${m.type}: ${m.text}'));
    await page.setViewport(pptr.DeviceViewport(width: 1280, height: 720));
    await page.goto(url, wait: pptr.Until.load);

    bool levelDrawn(Uint8List png) {
      final shot = img.decodePng(png)!;
      final sky = shot.getPixel(shot.width ~/ 2, 8);
      final ground = shot.getPixel(shot.width ~/ 2, shot.height * 4 ~/ 5);
      return (ground.r - sky.r).abs() + (ground.g - sky.g).abs() + (ground.b - sky.b).abs() > 30;
    }

    final deadline = DateTime.now().add(const Duration(minutes: 4));
    while (!levelDrawn(Uint8List.fromList(await page.screenshot()))) {
      if (DateTime.now().isAfter(deadline)) break;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    await Future<void>.delayed(const Duration(seconds: 8));
    final before = Uint8List.fromList(await page.screenshot());
    File(p.join(out.path, 'before.png')).writeAsBytesSync(before);

    // Click into the game, hold W for two seconds.
    await page.mouse.click(const Point(640, 400));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    log.writeln('--- W down');
    await page.keyboard.down(pptr.Key.keyW);
    await Future<void>.delayed(const Duration(seconds: 2));
    await page.keyboard.up(pptr.Key.keyW);
    log.writeln('--- W up');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final afterW = Uint8List.fromList(await page.screenshot());
    File(p.join(out.path, 'after_w.png')).writeAsBytesSync(afterW);

    // Turn with the mouse.
    log.writeln('--- mouse move');
    for (var i = 0; i < 30; i++) {
      await page.mouse.move(Point(640 + i * 10, 400));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final afterMouse = Uint8List.fromList(await page.screenshot());
    File(p.join(out.path, 'after_mouse.png')).writeAsBytesSync(afterMouse);

    double diff(Uint8List a, Uint8List b) {
      final x = img.decodePng(a)!, y = img.decodePng(b)!;
      var sum = 0.0, n = 0;
      for (var j = 0; j < x.height; j += 4) {
        for (var i = 0; i < x.width; i += 4) {
          final p1 = x.getPixel(i, j), p2 = y.getPixel(i, j);
          sum += ((p1.r - p2.r).abs() + (p1.g - p2.g).abs() + (p1.b - p2.b).abs()) / 3;
          n++;
        }
      }
      return sum / n;
    }

    stdout.writeln('diff before -> after W: ${diff(before, afterW).toStringAsFixed(2)}');
    stdout.writeln('diff after W -> after mouse: ${diff(afterW, afterMouse).toStringAsFixed(2)}');
  } finally {
    File(p.join(out.path, 'console.log')).writeAsStringSync(log.toString());
    await browser.close();
    await server.close(force: true);
  }
}
