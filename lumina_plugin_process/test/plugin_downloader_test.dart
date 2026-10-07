import 'dart:io';
import 'package:lumina_plugin_process/lumina_plugin_process.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('plugin_downloader_test_');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('PluginDownloader throws StateError when free disk space is insufficient', () async {
    final downloader = PluginDownloader(
      freeSpaceChecker: (_) => 100, // Only 100 bytes available
    );

    final files = [
      const PluginFileDef(
        path: 'test.bin',
        bytes: 1000,
        sha256: 'abc',
        downloadUrl: 'http://127.0.0.1/test.bin',
      ),
    ];

    expect(
      () => downloader.download(files: files, targetDir: tempDir.path).drain<void>(),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Insufficient disk space'))),
    );
  });

  test('PluginDownloader skips already downloaded and verified files', () async {
    final existingFile = File('${tempDir.path}/model.bin');
    existingFile.writeAsStringSync('sample content');
    final bytes = existingFile.lengthSync();

    final downloader = PluginDownloader();
    final files = [
      PluginFileDef(
        path: 'model.bin',
        bytes: bytes,
        sha256: 'sample',
        downloadUrl: 'http://127.0.0.1/model.bin',
      ),
    ];

    final progressUpdates = <PluginDownloadProgress>[];
    await for (final p in downloader.download(files: files, targetDir: tempDir.path)) {
      progressUpdates.add(p);
    }

    expect(progressUpdates.length, 1);
    expect(progressUpdates.first.fileProgress, 1.0);
    expect(progressUpdates.first.overallProgress, 1.0);
  });

  test('PluginDownloader cancel aborts active download', () {
    final downloader = PluginDownloader();
    expect(downloader.isCancelled, isFalse);
    downloader.cancel();
    expect(downloader.isCancelled, isTrue);
  });

  test('PluginDownloader downloads file and adopts remote server contentLength over estimated size', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    const bodyText = 'hello world dynamic size test';
    server.listen((req) {
      req.response.headers.contentType = ContentType.binary;
      req.response.headers.contentLength = bodyText.length;
      req.response.write(bodyText);
      req.response.close();
    });

    try {
      final downloader = PluginDownloader();
      final files = [
        PluginFileDef(
          path: 'downloaded.bin',
          bytes: 10, // estimated size was 10, but server serves bodyText.length (29)
          sha256: '', // optional checksum
          downloadUrl: 'http://${server.address.host}:${server.port}/downloaded.bin',
        ),
      ];

      final updates = <PluginDownloadProgress>[];
      await for (final p in downloader.download(files: files, targetDir: tempDir.path)) {
        updates.add(p);
      }

      final downloaded = File('${tempDir.path}/downloaded.bin');
      expect(downloaded.existsSync(), isTrue);
      expect(downloaded.readAsStringSync(), bodyText);
      expect(updates.last.fileProgress, 1.0);
    } finally {
      await server.close(force: true);
    }
  });
}

