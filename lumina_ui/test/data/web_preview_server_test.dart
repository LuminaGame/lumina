import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/web_preview_server.dart';

/// The local server behind "Launch in Browser". Pages
/// opened as `file://` cannot fetch `.wasm`, so the preview is served.
void main() {
  late Directory root;
  late WebPreviewServer server;

  // The smallest valid WebAssembly module: magic + version.
  final wasm = Uint8List.fromList([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]);

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_web_preview_');
    File('${root.path}/index.html').writeAsStringSync('<!DOCTYPE html><title>game</title>');
    File('${root.path}/flutter_filament.wasm').writeAsBytesSync(wasm);
    File('${root.path}/flutter_filament.js').writeAsStringSync('var FlutterFilament = 1;');
    Directory('${root.path}/assets/contents/meshes').createSync(recursive: true);
    File('${root.path}/assets/contents/meshes/SM Crate.glb').writeAsBytesSync([1, 2, 3]);
    server = WebPreviewServer();
  });

  tearDown(() async {
    await server.stop();
    root.deleteSync(recursive: true);
  });

  Future<HttpClientResponse> get(Uri url) async {
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    return (await client.getUrl(url)).close();
  }

  Future<List<int>> body(HttpClientResponse r) => r.fold<List<int>>(<int>[], (a, b) => a..addAll(b));

  test('GET / serves index.html; .wasm is application/wasm with the same bytes; stop closes the port', () async {
    final url = await server.start(root.path);
    expect(url.host, '127.0.0.1');
    expect(server.isRunning, isTrue);
    expect(server.url, url);

    final index = await get(url);
    expect(index.statusCode, 200);
    expect(index.headers.contentType?.mimeType, 'text/html');
    expect(utf8.decode(await body(index)), contains('<title>game</title>'));

    final module = await get(url.resolve('flutter_filament.wasm'));
    expect(module.statusCode, 200);
    expect(module.headers.contentType?.mimeType, 'application/wasm');
    expect(await body(module), wasm);

    final js = await get(url.resolve('flutter_filament.js'));
    expect(js.headers.contentType?.mimeType, 'text/javascript');
    await body(js);

    final spaced = await get(url.resolve('assets/contents/meshes/SM%20Crate.glb'));
    expect(spaced.statusCode, 200, reason: 'percent-encoded asset paths resolve');
    expect(await body(spaced), [1, 2, 3]);

    final missing = await get(url.resolve('nope.js'));
    expect(missing.statusCode, 404);
    await body(missing);

    await server.stop();
    expect(server.isRunning, isFalse);
    await expectLater(get(url), throwsA(isA<SocketException>()));
  });

  test('never serves files outside the build directory', () async {
    final outside = File('${root.parent.path}/lumina_preview_outside_${DateTime.now().microsecondsSinceEpoch}.txt')
      ..writeAsStringSync('secret');
    addTearDown(outside.deleteSync);
    final url = await server.start(root.path);
    final socket = await Socket.connect(url.host, url.port);
    socket.write('GET /../${outside.uri.pathSegments.last} HTTP/1.1\r\nHost: ${url.host}\r\nConnection: close\r\n\r\n');
    final response = utf8.decode(await socket.fold<List<int>>(<int>[], (a, b) => a..addAll(b)));
    expect(response, startsWith('HTTP/1.1 404'));
    expect(response, isNot(contains('secret')));
    final encoded = await get(url.replace(path: '/%2E%2E/${outside.uri.pathSegments.last}'));
    expect(encoded.statusCode, 404);
    expect(utf8.decode(await body(encoded)), isNot(contains('secret')));
  });

  test('starting again on another build directory serves the new one', () async {
    await server.start(root.path);
    final other = Directory.systemTemp.createTempSync('lumina_web_preview_other_');
    addTearDown(() => other.deleteSync(recursive: true));
    File('${other.path}/index.html').writeAsStringSync('<title>other</title>');
    final url = await server.start(other.path);
    expect(utf8.decode(await body(await get(url))), contains('other'));
  });
}
