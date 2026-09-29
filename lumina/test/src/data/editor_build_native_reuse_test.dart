@Tags(['slow'])
library;

import 'dart:io';

import 'package:lumina/data/services/editor_build_cache.dart';
import 'package:lumina/data/services/editor_build_service.dart';
import 'package:lumina/data/services/editor_source_vendor_service.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'editor_build_test_support.dart';

/// Editor builds × flutter_filament's native library cache: two project
/// editors built one after the other against one temp native library cache —
/// the second relinks nothing for flutter_filament.
void main() {
  final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';

  test('the second host build reuses flutter_filament from the native cache', () async {
    try {
      Process.runSync(flutter, ['--version'], runInShell: Platform.isWindows);
    } on ProcessException {
      markTestSkipped('flutter is not on PATH');
      return;
    }
    final engineRoot = LuminaWorkspace.root;
    final one = await EditorBuildFixture.create(projectName: 'HostOne', engineRoot: engineRoot);
    final two = await EditorBuildFixture.create(projectName: 'HostTwo', engineRoot: engineRoot);
    addTearDown(one.dispose);
    addTearDown(two.dispose);
    // Distinct plugin sources, so the second host is a different editor and
    // really builds (the same plugin set would be a cache hit, no build).
    File(p.join(two.pluginDir.path, 'lib', 'a.dart')).writeAsStringSync('${File(p.join(two.pluginDir.path, 'lib', 'a.dart')).readAsStringSync()}// two\n');

    // The hooks runner passes a hook only allow-listed variables, so the
    // native cache follows LOCALAPPDATA (Windows) / HOME; PUB_CACHE keeps
    // resolution on the real pub cache.
    final base = Directory(p.join(one.temp.path, 'base'))..createSync();
    final pubCache = Platform.environment['PUB_CACHE'] ??
        (Platform.isWindows ? '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache' : '${Platform.environment['HOME']}/.pub-cache');
    final env = Platform.isWindows ? {'LOCALAPPDATA': base.path, 'PUB_CACHE': pubCache} : {'HOME': base.path, 'PUB_CACHE': pubCache};
    final cache = EditorBuildCache(
      root: EditorBuildCache.defaultRoot(environment: env),
      nativeRoot: Directory(p.join(EditorBuildCache.cacheBase(environment: env), 'native')),
    );
    final service = EditorBuildService(
      engineRoot: engineRoot,
      cache: cache,
      flutterExecutable: flutter,
      environment: env,
      // Each host reaches the engine through its own links, as a
      // copy does (the cache key ignores the route).
      vendor: EditorSourceVendorService(engineRoot: engineRoot, linkPackages: true),
      hostAliasRoot: Directory(p.join(one.temp.path, 'hosts')),
    );

    final first = await service.start(one.projectDir.path, [await one.plugin()]).result;
    expect(first, isA<EditorBuildSucceeded>(), reason: first is EditorBuildFailed ? first.lastLines.join('\n') : '');
    final firstLog = File((first as EditorBuildSucceeded).logPath!).readAsStringSync();
    expect(RegExp(r'--- hook output: flutter_filament ---[\s\S]*?native cache store [0-9a-f]{64}').hasMatch(firstLog), isTrue,
        reason: 'the cold build stores flutter_filament');

    final second = await service.start(two.projectDir.path, [await two.plugin()]).result;
    expect(second, isA<EditorBuildSucceeded>(), reason: second is EditorBuildFailed ? second.lastLines.join('\n') : '');
    final secondLog = File((second as EditorBuildSucceeded).logPath!).readAsStringSync();
    expect(RegExp(r'--- hook output: flutter_filament ---[\s\S]*?native cache hit [0-9a-f]{64}').hasMatch(secondLog), isTrue,
        reason: 'the second host reuses flutter_filament');
    expect(cache.hashes(), hasLength(2));
    // ignore: avoid_print
    print('PLUGINS07_NATIVE_REUSE first=${first.elapsed.inSeconds}s second=${second.elapsed.inSeconds}s');
  }, timeout: const Timeout(Duration(minutes: 60)));
}
