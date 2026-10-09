import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A real `flutter-filament-web-<tag>.zip` in the layout the release workflow
/// writes, served with its sidecar and a GitHub-style releases listing by a
/// loopback HTTP server.
void main() {
  late Directory temp;
  late HttpServer server;
  late Map<String, List<int>> assets;
  late List<Map<String, Object?>> releases;
  late List<String> requests;
  late String origin;

  List<int> buildZip(String tag, {bool withWasm = true}) {
    final folder = FlutterFilamentWebPrebuilt.baseName(tag);
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('$folder/flutter_filament.js', utf8.encode('// module $tag')))
      ..addFile(ArchiveFile.bytes('$folder/README.md', utf8.encode('# web module $tag')));
    if (withWasm) archive.addFile(ArchiveFile.bytes('$folder/flutter_filament.wasm', [0, 0x61, 0x73, 0x6d, 1, 0, 0, 0]));
    return ZipEncoder().encode(archive);
  }

  /// Attaches the archive of [tag] and its sidecar to the [tag] release and
  /// lists that release (newest first by [published]).
  void publish(String tag, {String? sha, bool withWasm = true, String published = '2026-10-01T00:00:00Z', bool listed = true}) {
    final name = FlutterFilamentWebPrebuilt.archiveName(tag);
    final bytes = buildZip(tag, withWasm: withWasm);
    assets['/download/$tag/$name'] = bytes;
    assets['/download/$tag/$name.sha256'] = utf8.encode('${sha ?? sha256.convert(bytes)}  $name\n');
    if (listed) {
      releases.add({
        'tag_name': tag,
        'draft': false,
        'published_at': published,
        'assets': [
          {'name': name},
          {'name': '$name.sha256'},
        ],
      });
    }
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('web_module_prebuilt_test');
    assets = {};
    releases = [];
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    origin = 'http://${server.address.address}:${server.port}';
    server.listen((request) async {
      requests.add(request.uri.path);
      final body = request.uri.path == '/releases' ? utf8.encode(jsonEncode(releases)) : assets[request.uri.path];
      if (body == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.contentLength = body.length;
        request.response.add(body);
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await temp.delete(recursive: true);
  });

  String baseUrl() => '$origin/download';
  String apiUrl() => '$origin/releases';
  Directory root() => Directory(p.join(temp.path, 'flutter_filament_web'));

  Future<FlutterFilamentWebInstall> ensure(String tag, {bool force = false}) =>
      FlutterFilamentWebPrebuilt.ensure(requestedTag: tag, root: root(), baseUrl: baseUrl(), apiUrl: apiUrl(), force: force);

  test('the asset names follow the release workflow', () {
    expect(FlutterFilamentWebPrebuilt.archiveName('v0.0.1-dev.16'), 'flutter-filament-web-v0.0.1-dev.16.zip');
    expect(FlutterFilamentWebPrebuilt.baseName('v0.0.1-dev.16'), 'flutter-filament-web-v0.0.1-dev.16');
    expect(LuminaDataDir.webModuleRoot(environment: {'LUMINA_DATA_DIR': temp.path}).path, p.join(temp.path, 'flutter_filament_web'));
  });

  test("downloads, verifies and unpacks the editor's own release and records it", () async {
    publish('v9.9.9');
    final progress = <double>[];
    final install = await FlutterFilamentWebPrebuilt.ensure(
        requestedTag: 'v9.9.9', root: root(), baseUrl: baseUrl(), apiUrl: apiUrl(), onProgress: (f, _) => progress.add(f));
    expect(install.directory.path, p.join(root().path, 'module'));
    expect(File(p.join(install.directory.path, 'flutter_filament.js')).readAsStringSync(), '// module v9.9.9');
    expect(File(p.join(install.directory.path, 'flutter_filament.wasm')).lengthSync(), 8);
    expect(install.tag, 'v9.9.9');
    final name = FlutterFilamentWebPrebuilt.archiveName('v9.9.9');
    expect(install.sha256, sha256.convert(assets['/download/v9.9.9/$name']!).toString());
    final marker = jsonDecode(File(p.join(install.directory.path, FlutterFilamentWebPrebuilt.markerFileName)).readAsStringSync()) as Map;
    expect(marker['tag'], 'v9.9.9');
    expect(marker['requestedTag'], 'v9.9.9');
    expect(requests, ['/download/v9.9.9/$name.sha256', '/download/v9.9.9/$name'], reason: 'the own tag needs no releases listing');
    expect(progress.last, 1);
    expect(FlutterFilamentWebPrebuilt.installed(root())!.tag, 'v9.9.9');
  });

  test('without the asset in its own release, falls back to the newest release that has it', () async {
    publish('v1.0.0', published: '2026-09-01T00:00:00Z');
    publish('v1.1.0', published: '2026-09-20T00:00:00Z');
    // A newer release without the web module.
    releases.add({'tag_name': 'v1.2.0', 'draft': false, 'published_at': '2026-10-01T00:00:00Z', 'assets': <Object>[]});
    // A draft is never used.
    publish('v1.3.0', published: '2026-10-05T00:00:00Z');
    releases.last['draft'] = true;
    final install = await ensure('v2.0.0');
    expect(install.tag, 'v1.1.0');
    expect(install.requestedTag, 'v2.0.0');
    expect(requests.first, '/download/v2.0.0/${FlutterFilamentWebPrebuilt.archiveName('v2.0.0')}.sha256');
    expect(requests, contains('/releases'));
  });

  test('a development build (no tag) takes the newest release with the asset', () async {
    publish('v1.1.0', published: '2026-09-20T00:00:00Z');
    final install = await ensure('');
    expect(install.tag, 'v1.1.0');
    expect(install.requestedTag, '');
    expect(requests.first, '/releases');
  });

  test('a sha256 mismatch is rejected and leaves no module behind', () async {
    publish('v9.9.9', sha: 'a' * 64);
    await expectLater(
      ensure('v9.9.9'),
      throwsA(isA<FlutterFilamentWebPrebuiltException>().having((e) => e.message, 'message', contains('Checksum mismatch'))),
    );
    expect(FlutterFilamentWebPrebuilt.moduleDir(root()).existsSync(), isFalse);
    expect(root().listSync(), isEmpty, reason: 'the staging folder is cleaned up');
  });

  test('an archive without the wasm file is rejected', () async {
    publish('v9.9.9', withWasm: false);
    await expectLater(ensure('v9.9.9'), throwsA(isA<FlutterFilamentWebPrebuiltException>()));
    expect(FlutterFilamentWebPrebuilt.installed(root()), isNull);
  });

  test('the same editor version reuses the install offline; a new version downloads again', () async {
    publish('v1.0.0');
    await ensure('v1.0.0');
    requests.clear();
    await server.close(force: true);
    final again = await ensure('v1.0.0');
    expect(again.tag, 'v1.0.0');
    expect(requests, isEmpty);
    // Back online with a newer release: the new editor version replaces it.
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    origin = 'http://${server.address.address}:${server.port}';
    server.listen((request) async {
      requests.add(request.uri.path);
      final body = assets[request.uri.path];
      request.response.statusCode = body == null ? HttpStatus.notFound : HttpStatus.ok;
      if (body != null) request.response.add(body);
      await request.response.close();
    });
    publish('v1.1.0', listed: false);
    final upgraded = await ensure('v1.1.0');
    expect(upgraded.tag, 'v1.1.0');
    expect(File(p.join(upgraded.directory.path, 'flutter_filament.js')).readAsStringSync(), '// module v1.1.0');
  });

  test('offline: a clear error, nothing installed, the previous install kept', () async {
    publish('v1.0.0');
    await ensure('v1.0.0');
    await server.close(force: true);
    await expectLater(ensure('v2.0.0'), throwsA(isA<FlutterFilamentWebPrebuiltException>()));
    expect(FlutterFilamentWebPrebuilt.installed(root())!.tag, 'v1.0.0');
  });

  test('no release carries the asset: says so', () async {
    await expectLater(
      ensure('v9.9.9'),
      throwsA(isA<FlutterFilamentWebPrebuiltException>().having((e) => e.message, 'message', contains('No release'))),
    );
  });

  test('downloads the real v0.0.1-dev.16 web module from GitHub (skips offline)', () async {
    if ((Platform.environment['LUMINA_SKIP_NETWORK_TESTS'] ?? '').isNotEmpty) return markTestSkipped('LUMINA_SKIP_NETWORK_TESTS is set');
    try {
      await InternetAddress.lookup('github.com').timeout(const Duration(seconds: 5));
    } catch (e) {
      return markTestSkipped('no network: $e');
    }
    final install = await FlutterFilamentWebPrebuilt.ensure(requestedTag: 'v0.0.1-dev.16', root: root());
    expect(install.tag, 'v0.0.1-dev.16');
    expect(install.sha256, '5545758085cfd5388028776fe830d75a37b3a049b24753ed7ab82dd9c5ca62ef');
    final wasm = File(p.join(install.directory.path, 'flutter_filament.wasm'));
    expect(wasm.readAsBytesSync().take(4), [0, 0x61, 0x73, 0x6d], reason: 'a WebAssembly binary');
  }, tags: ['network'], timeout: const Timeout(Duration(minutes: 3)));
}
