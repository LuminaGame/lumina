import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:path/path.dart' as p;

/// A real archive, in the layout `.github/scripts/package_openriglogic.sh`
/// writes, served by a loopback HTTP server laid out like GitHub release
/// downloads.
void main() {
  const tag = 'v9.9.9';
  late Directory temp;
  late HttpServer server;
  late Map<String, List<int>> assets;
  late List<String> requests;

  String os() => OpenRigLogicPrebuilt.osName();

  Future<List<int>> buildArchive({String? platform, bool withLibrary = true}) async {
    final stage = Directory(p.join(temp.path, 'stage-${DateTime.now().microsecondsSinceEpoch}'));
    final top = Directory(p.join(stage.path, OpenRigLogicPrebuilt.baseName()))..createSync(recursive: true);
    File(p.join(top.path, OpenRigLogicPrebuilt.infoFileName))
        .writeAsStringSync(jsonEncode({'platform': platform ?? '${os()}-x64', 'rigLogicVersion': '13.2.9'}));
    if (withLibrary) {
      File(p.join(top.path, 'lib', OpenRigLogicPrebuilt.libraryName()))
        ..createSync(recursive: true)
        ..writeAsStringSync('library');
    }
    File(p.join(top.path, 'LICENSE')).writeAsStringSync('license');
    final archive = File(p.join(temp.path, OpenRigLogicPrebuilt.archiveName()));
    if (archive.existsSync()) archive.deleteSync();
    final result = Platform.isWindows
        ? await Process.run(p.join(Platform.environment['SystemRoot']!, 'System32', 'tar.exe'),
            ['-a', '-c', '-f', archive.path, OpenRigLogicPrebuilt.baseName()],
            workingDirectory: stage.path)
        : await Process.run('tar', ['-czf', archive.path, OpenRigLogicPrebuilt.baseName()], workingDirectory: stage.path);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return archive.readAsBytesSync();
  }

  void publish(List<int> bytes, {String? sha}) {
    final name = OpenRigLogicPrebuilt.archiveName();
    assets['/$tag/$name'] = bytes;
    assets['/$tag/$name.sha256'] = utf8.encode('${sha ?? sha256.convert(bytes)}  $name\n');
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('openriglogic_prebuilt_test');
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

  test('asset names follow package_openriglogic.sh', () {
    expect(OpenRigLogicPrebuilt.archiveName('windows'), 'openriglogic-windows-x64.zip');
    expect(OpenRigLogicPrebuilt.archiveName('linux'), 'openriglogic-linux-${ReleaseAssets.hostArchitecture()}.tar.gz');
    expect(ReleaseAssets.platformName('linux', 'arm64'), 'linux-arm64');
    expect(ReleaseAssets.platformName('windows', 'arm64'), 'windows-x64');
    expect(OpenRigLogicPrebuilt.libraryName('windows'), 'riglogic.lib');
    expect(OpenRigLogicPrebuilt.libraryName('linux'), 'libriglogic.a');
    expect(OpenRigLogicPrebuilt.archiveUri('v0.2.0', operatingSystem: 'linux').toString(),
        'https://github.com/LuminaGame/lumina/releases/download/v0.2.0/openriglogic-linux-x64.tar.gz');
    expect(() => OpenRigLogicPrebuilt.osName('android'), throwsA(isA<OpenRigLogicPrebuiltException>()));
  });

  test('downloads, verifies and unpacks to <cacheRoot>/<tag>, then reuses it offline', () async {
    publish(await buildArchive());
    final progress = <double>[];
    final dir = await OpenRigLogicPrebuilt.ensure(
      releaseTag: tag,
      cacheRoot: cache(),
      baseUrl: baseUrl(),
      onProgress: (f, _) => progress.add(f),
    );
    expect(p.equals(dir.path, p.join(cache().path, tag)), isTrue);
    expect(File(p.join(dir.path, 'lib', OpenRigLogicPrebuilt.libraryName())).readAsStringSync(), 'library');
    expect(progress.last, 1);
    expect(cache().listSync().map((e) => p.basename(e.path)), [tag]);

    requests.clear();
    final again = await OpenRigLogicPrebuilt.ensure(releaseTag: tag, cacheRoot: cache(), baseUrl: baseUrl());
    expect(again.path, dir.path);
    expect(requests, isEmpty);
  });

  test('a checksum mismatch unpacks nothing', () async {
    publish(await buildArchive(), sha: 'a' * 64);
    await expectLater(
      OpenRigLogicPrebuilt.ensure(releaseTag: tag, cacheRoot: cache(), baseUrl: baseUrl()),
      throwsA(isA<OpenRigLogicPrebuiltException>().having((e) => e.message, 'message', contains('Checksum mismatch'))),
    );
    expect(cache().listSync(), isEmpty);
  });

  test('a missing release asset is reported', () async {
    await expectLater(
      OpenRigLogicPrebuilt.ensure(releaseTag: tag, cacheRoot: cache(), baseUrl: baseUrl()),
      throwsA(isA<OpenRigLogicPrebuiltException>().having((e) => e.message, 'message', contains('HTTP 404'))),
    );
    expect(OpenRigLogicPrebuilt.installed(cache(), tag), isNull);
  });

  test('an archive for another platform, or without the library, is refused', () async {
    publish(await buildArchive(platform: 'plan9-x64'));
    await expectLater(
      OpenRigLogicPrebuilt.ensure(releaseTag: tag, cacheRoot: cache(), baseUrl: baseUrl()),
      throwsA(isA<OpenRigLogicPrebuiltException>()),
    );
    expect(Directory(p.join(cache().path, tag)).existsSync(), isFalse);

    publish(await buildArchive(withLibrary: false));
    await expectLater(
      OpenRigLogicPrebuilt.ensure(releaseTag: tag, cacheRoot: cache(), baseUrl: baseUrl()),
      throwsA(isA<OpenRigLogicPrebuiltException>().having((e) => e.message, 'message', contains('no lib/'))),
    );
    expect(Directory(p.join(cache().path, tag)).existsSync(), isFalse);
  });
}
