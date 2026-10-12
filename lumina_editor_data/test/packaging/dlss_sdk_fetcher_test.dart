import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/lumina_editor_data.dart';
import 'package:path/path.dart' as p;

/// Fetching the DLSS SDK from the editor: the real SDK files are served by a
/// loopback server laid out like github.com/NVIDIA/DLSS's raw files
/// (`/<tag>/<path>`), fetched into a temp flutter_filament folder, verified
/// against the manifest with byte progress. Skips when the SDK is not fetched
/// on this machine (the server needs real files to serve).
void main() {
  final filamentRoot = LuminaWorkspace.packageIn(LuminaWorkspace.findSourceRoot() ?? LuminaWorkspace.root, 'flutter_filament');
  final realSdk = DlssSdk.readSync(filamentRoot);
  final skip = realSdk == null || !realSdk.isFetched
      ? 'the DLSS SDK is not fetched: run `dart run tool/dlss/fetch_sdk.dart` in $filamentRoot'
      : null;
  const files = ['LICENSE.txt', 'include/nvsdk_ngx.h', 'lib/Windows_x86_64/rel/nvngx_dlssg.dll'];
  late Directory temp;
  late HttpServer server;
  HttpOverrides? testOverrides;
  final corrupt = <String>{};

  setUp(() async {
    // flutter_test answers every HttpClient request with HTTP 400.
    testOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    temp = Directory.systemTemp.createTempSync('dlss_fetch_');
    corrupt.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final segments = req.uri.pathSegments;
      final path = segments.skip(1).join('/');
      final file = File(p.join(realSdk!.sdkDir, path));
      if (segments.isEmpty || segments.first != realSdk.version || !file.existsSync()) {
        req.response.statusCode = 404;
      } else if (corrupt.contains(path)) {
        final bytes = file.readAsBytesSync();
        bytes[bytes.length ~/ 2] ^= 0xFF;
        req.response.add(bytes);
      } else {
        await req.response.addStream(file.openRead());
      }
      await req.response.close();
    });
  });

  tearDown(() async {
    HttpOverrides.global = testOverrides;
    await server.close(force: true);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  DlssSdk emptySdk() {
    final root = p.join(temp.path, 'flutter_filament');
    Directory(p.join(root, 'tool', 'dlss')).createSync(recursive: true);
    File(p.join(root, 'tool', 'dlss', 'VERSION')).writeAsStringSync('${realSdk!.version}\n');
    File(p.join(root, 'tool', 'dlss', 'manifest.txt')).writeAsStringSync([
      for (final f in files)
        () {
          final e = realSdk.manifest.firstWhere((m) => m.path == f);
          return '${e.sha256}  ${e.size}  ${e.path}';
        }(),
    ].join('\n'));
    return DlssSdk.readSync(root)!;
  }

  String base() => 'http://${server.address.host}:${server.port}';

  test('fetches every manifest file, verified, with progress up to the total', () async {
    if (skip != null) return markTestSkipped(skip);
    final sdk = emptySdk();
    expect(sdk.isFetched, isFalse);
    final progress = <DlssSdkFetchProgress>[];
    final result = await DlssSdkFetcher(baseUrl: base()).fetch(sdk, onProgress: progress.add);
    expect(result.downloaded, files.length);
    final fetched = await sdk.refresh();
    expect(fetched.isFetched, isTrue);
    expect(await fetched.verify(fetched.manifest), isEmpty);
    expect(progress.last.bytesDone, progress.last.bytesTotal);
    expect(progress.last.filesDone, files.length);
    expect(progress.map((e) => e.bytesDone).toList(), orderedEquals([...progress.map((e) => e.bytesDone)]..sort()));

    // Again: everything is there, nothing is downloaded.
    final again = await DlssSdkFetcher(baseUrl: base()).fetch(fetched);
    expect(again.downloaded, 0);
    expect(again.alreadyPresent, files.length);
  });

  test('a download that does not match the manifest is refused and leaves no partial file', () async {
    if (skip != null) return markTestSkipped(skip);
    final sdk = emptySdk();
    corrupt.add('lib/Windows_x86_64/rel/nvngx_dlssg.dll');
    await expectLater(DlssSdkFetcher(baseUrl: base()).fetch(sdk), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('SHA-256'))));
    final rel = Directory(p.join(sdk.sdkDir, 'lib', 'Windows_x86_64', 'rel'));
    expect(rel.existsSync() ? rel.listSync() : const <FileSystemEntity>[], isEmpty);
    expect((await sdk.refresh()).missing, ['lib/Windows_x86_64/rel/nvngx_dlssg.dll']);
  });
}
