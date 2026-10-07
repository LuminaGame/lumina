import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../hook/dlss_sdk_dependencies.dart';

/// The hooks runner dates a missing file dependency "now", after the build
/// started, so declaring one re-ran the native build on every run. The NGX
/// SDK dependencies must therefore always exist and still change when the
/// SDK is fetched or deleted.
void main() {
  late Directory temp;
  late String sdk;
  late List<String> markers;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('dlss_deps');
    sdk = '${temp.path}/build/dlss-sdk';
    markers = ['$sdk/include/nvsdk_ngx_vk.h', '$sdk/lib/Windows_x86_64/x64/nvsdk_ngx_s.lib'];
  });
  tearDown(() => temp.deleteSync(recursive: true));

  bool exists(Uri uri) =>
      uri.path.endsWith('/') ? Directory.fromUri(uri).existsSync() : File.fromUri(uri).existsSync();

  test('without the SDK the folder is created empty and declared as a directory', () {
    final deps = dlssSdkDependencies(sdk, markers);
    expect(Directory(sdk).existsSync(), isTrue);
    expect(Directory(sdk).listSync(), isEmpty);
    expect(deps, [Uri.directory(Directory(sdk).absolute.path)]);
    expect(deps.every(exists), isTrue);
  });

  test('a partly fetched SDK depends on the deepest existing folder of each missing marker', () {
    File(markers.first).createSync(recursive: true);
    Directory('$sdk/lib/Windows_x86_64').createSync(recursive: true);
    final deps = dlssSdkDependencies(sdk, markers);
    expect(deps, [
      File(markers.first).absolute.uri,
      Uri.directory(Directory('$sdk/lib/Windows_x86_64').absolute.path),
    ]);
    expect(deps.every(exists), isTrue);
  });

  test('a fetched SDK depends on the marker files themselves', () {
    for (final marker in markers) {
      File(marker).createSync(recursive: true);
    }
    final deps = dlssSdkDependencies(sdk, markers);
    expect(deps, [for (final marker in markers) File(marker).absolute.uri]);
    expect(deps.every(exists), isTrue);
  });

  test('targets without DLSS declare nothing and create nothing', () {
    expect(dlssSdkDependencies(sdk, const []), isEmpty);
    expect(Directory(sdk).existsSync(), isFalse);
  });
}
