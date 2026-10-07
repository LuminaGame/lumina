import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/filament_prebuilt.dart';
import 'package:lumina/data/services/release_asset.dart';
import 'package:path/path.dart' as p;

/// A real archive, in the layout build_prebuilt.{sh,ps1} writes, served by a
/// loopback HTTP server laid out like GitHub release downloads.
void main() {
  const version = '1.77.0-lumina.test';
  const tag = 'v9.9.9';
  late Directory temp;
  late HttpServer server;
  late Map<String, List<int>> assets;
  late List<String> requests;

  String os() => FilamentPrebuilt.osName();

  Future<List<int>> buildArchive({String? infoVersion}) async {
    final stage = Directory(p.join(temp.path, 'stage-${DateTime.now().microsecondsSinceEpoch}'));
    final top = Directory(p.join(stage.path, FilamentPrebuilt.baseName(version)))..createSync(recursive: true);
    File(p.join(top.path, 'lumina-filament.json'))
        .writeAsStringSync(jsonEncode({'version': infoVersion ?? version, 'platform': '${os()}-x64'}));
    File(p.join(top.path, 'filament', 'include', 'filament', 'Engine.h'))
      ..createSync(recursive: true)
      ..writeAsStringSync('// header');
    final archive = File(p.join(temp.path, FilamentPrebuilt.archiveName(version)));
    if (archive.existsSync()) archive.deleteSync();
    final result = Platform.isWindows
        ? await Process.run(p.join(Platform.environment['SystemRoot']!, 'System32', 'tar.exe'),
            ['-a', '-c', '-f', archive.path, FilamentPrebuilt.baseName(version)],
            workingDirectory: stage.path)
        : await Process.run('tar', ['-czf', archive.path, FilamentPrebuilt.baseName(version)], workingDirectory: stage.path);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return archive.readAsBytesSync();
  }

  /// The Filament release every new binary downloads from.
  final filamentTag = FilamentPrebuilt.releaseTagFor(version);

  /// Attaches the archive and its sidecar to the release [under] (default:
  /// the Filament release).
  void publish(List<int> bytes, {String? sha, String? under}) {
    final name = FilamentPrebuilt.archiveName(version);
    final release = under ?? filamentTag;
    assets['/$release/$name'] = bytes;
    assets['/$release/$name.sha256'] = utf8.encode('${sha ?? sha256.convert(bytes)}  $name\n');
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('filament_prebuilt_test');
    assets = {};
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri.path);
      final body = assets[request.uri.path];
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

  String baseUrl() => 'http://${server.address.address}:${server.port}';
  Directory cache() => Directory(p.join(temp.path, 'cache'));

  test('asset names follow build_prebuilt', () {
    expect(FilamentPrebuilt.archiveName('1.77.0-lumina.1', 'windows'), 'filament-1.77.0-lumina.1-windows-x64.zip');
    expect(FilamentPrebuilt.archiveName('1.77.0-lumina.1', 'linux', 'x64'), 'filament-1.77.0-lumina.1-linux-x64.tar.gz');
    expect(FilamentPrebuilt.archiveName('1.77.0-lumina.1', 'linux', 'arm64'), 'filament-1.77.0-lumina.1-linux-arm64.tar.gz');
    expect(FilamentPrebuilt.archiveName('1.77.0-lumina.1', 'windows', 'arm64'), 'filament-1.77.0-lumina.1-windows-x64.zip',
        reason: 'Windows builds are x64 only');
    expect(FilamentPrebuilt.archiveName('1.77.0-lumina.1', 'linux'),
        'filament-1.77.0-lumina.1-linux-${ReleaseAssets.hostArchitecture()}.tar.gz');
    expect(FilamentPrebuilt.archiveUri('1.77.0-lumina.1', 'v0.2.0', operatingSystem: 'linux').toString(),
        'https://github.com/LuminaGame/lumina/releases/download/v0.2.0/filament-1.77.0-lumina.1-linux-x64.tar.gz');
    expect(() => FilamentPrebuilt.osName('android'), throwsA(isA<FilamentPrebuiltException>()));
  });

  test('the Filament release of a version is filament-<version>', () {
    expect(FilamentPrebuilt.releaseTagFor('1.77.0-lumina.2'), 'filament-1.77.0-lumina.2');
    expect(
        FilamentPrebuilt.archiveUri('1.77.0-lumina.2', FilamentPrebuilt.releaseTagFor('1.77.0-lumina.2'), operatingSystem: 'windows')
            .toString(),
        'https://github.com/LuminaGame/lumina/releases/download/filament-1.77.0-lumina.2/filament-1.77.0-lumina.2-windows-x64.zip');
  });

  test('downloads from the filament-<version> release first', () async {
    publish(await buildArchive());
    publish(await buildArchive(), under: tag);
    final dir = await FilamentPrebuilt.ensure(version: version, releaseTag: tag, cacheRoot: cache(), baseUrl: baseUrl());
    expect(FilamentPrebuilt.readInfo(dir)!['version'], version);
    final name = FilamentPrebuilt.archiveName(version);
    expect(requests, ['/$filamentTag/$name.sha256', '/$filamentTag/$name']);
  });

  test('falls back to the Lumina release tag when the Filament release has no assets', () async {
    publish(await buildArchive(), under: tag);
    final messages = <String>[];
    final dir = await FilamentPrebuilt.ensure(
      version: version,
      releaseTag: tag,
      cacheRoot: cache(),
      baseUrl: baseUrl(),
      onProgress: (_, m) => messages.add(m),
    );
    expect(File(p.join(dir.path, 'filament', 'include', 'filament', 'Engine.h')).existsSync(), isTrue);
    final name = FilamentPrebuilt.archiveName(version);
    expect(requests, ['/$filamentTag/$name.sha256', '/$tag/$name.sha256', '/$tag/$name']);
    expect(messages, contains(contains(tag)));
  });

  test('falls back when the Filament release has the sidecar but not the archive', () async {
    publish(await buildArchive(), under: tag);
    final name = FilamentPrebuilt.archiveName(version);
    assets['/$filamentTag/$name.sha256'] = assets['/$tag/$name.sha256']!;
    await FilamentPrebuilt.ensure(version: version, releaseTag: tag, cacheRoot: cache(), baseUrl: baseUrl());
    expect(requests, ['/$filamentTag/$name.sha256', '/$filamentTag/$name', '/$tag/$name.sha256', '/$tag/$name']);
  });

  test('a version in no release names every URL tried and leaves nothing behind', () async {
    await expectLater(
      FilamentPrebuilt.ensure(version: version, releaseTag: tag, cacheRoot: cache(), baseUrl: baseUrl()),
      throwsA(isA<FilamentPrebuiltException>().having(
          (e) => e.message, 'message', allOf(contains('HTTP 404'), contains('/$filamentTag/'), contains('/$tag/')))),
    );
    expect(cache().existsSync() ? cache().listSync() : const <FileSystemEntity>[], isEmpty);
  });

  test('without a release tag only the Filament release is tried', () async {
    publish(await buildArchive(), under: tag);
    await expectLater(
      FilamentPrebuilt.ensure(version: version, cacheRoot: cache(), baseUrl: baseUrl()),
      throwsA(isA<FilamentPrebuiltException>().having((e) => e.message, 'message', contains('HTTP 404'))),
    );
    expect(requests, isNotEmpty);
    expect(requests.every((r) => r.startsWith('/$filamentTag/')), isTrue);
    publish(await buildArchive());
    final dir = await FilamentPrebuilt.ensure(version: version, cacheRoot: cache(), baseUrl: baseUrl());
    expect(FilamentPrebuilt.readInfo(dir)!['version'], version);
  });

  test('LUMINA_FILAMENT_BASE_URL redirects the download', () async {
    publish(await buildArchive());
    final dir = await FilamentPrebuilt.ensure(
      version: version,
      releaseTag: tag,
      cacheRoot: cache(),
      environment: {FilamentPrebuilt.baseUrlVariable: baseUrl()},
    );
    expect(FilamentPrebuilt.readInfo(dir)!['version'], version);
    expect(requests.first, '/$filamentTag/${FilamentPrebuilt.archiveName(version)}.sha256');
  });

  test('downloads, verifies and unpacks to <cacheRoot>/<version>, then reuses it offline', () async {
    publish(await buildArchive());
    final progress = <double>[];
    final dir = await FilamentPrebuilt.ensure(
      version: version,
      releaseTag: tag,
      cacheRoot: cache(),
      baseUrl: baseUrl(),
      onProgress: (f, _) => progress.add(f),
    );
    expect(p.equals(dir.path, p.join(cache().path, version)), isTrue);
    expect(File(p.join(dir.path, 'filament', 'include', 'filament', 'Engine.h')).readAsStringSync(), '// header');
    expect(FilamentPrebuilt.readInfo(dir)!['version'], version);
    expect(progress.last, 1);
    // Nothing but the unpacked folder is left.
    expect(cache().listSync().map((e) => p.basename(e.path)), [version]);

    requests.clear();
    final again = await FilamentPrebuilt.ensure(version: version, releaseTag: tag, cacheRoot: cache(), baseUrl: baseUrl());
    expect(again.path, dir.path);
    expect(requests, isEmpty);
  });

  test('a checksum mismatch unpacks nothing', () async {
    publish(await buildArchive(), sha: 'a' * 64);
    await expectLater(
      FilamentPrebuilt.ensure(version: version, releaseTag: tag, cacheRoot: cache(), baseUrl: baseUrl()),
      throwsA(isA<FilamentPrebuiltException>().having((e) => e.message, 'message', contains('Checksum mismatch'))),
    );
    expect(cache().listSync(), isEmpty);
  });

  test('a missing release asset is reported', () async {
    await expectLater(
      FilamentPrebuilt.ensure(version: version, releaseTag: tag, cacheRoot: cache(), baseUrl: baseUrl()),
      throwsA(isA<FilamentPrebuiltException>().having((e) => e.message, 'message', contains('HTTP 404'))),
    );
    expect(FilamentPrebuilt.installed(cache(), version), isNull);
  });

  test('an archive for another version is refused', () async {
    publish(await buildArchive(infoVersion: '0.0.0'));
    await expectLater(
      FilamentPrebuilt.ensure(version: version, releaseTag: tag, cacheRoot: cache(), baseUrl: baseUrl()),
      throwsA(isA<FilamentPrebuiltException>()),
    );
    expect(Directory(p.join(cache().path, version)).existsSync(), isFalse);
  });
}
