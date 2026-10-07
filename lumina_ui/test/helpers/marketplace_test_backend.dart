import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';

import 'temp_project.dart';
import 'package:lumina_core/lumina_core.dart';

/// A real Lumina Marketplace server (lumina_marketplace/server) for the
/// marketplace tests: started as its own `dart run bin/server.dart --seed`
/// process on 127.0.0.1 with an ephemeral port, a temp SQLite database and a
/// temp storage directory, seeded with the sample CC0 listings built from the
/// workspace's `test-assets/` (Barrel, …) and the "Lumina Ember" theme.
///
/// A process rather than an in-process dev dependency: the server's sqlite3
/// needs `hooks` 2.x, which flutter_riglogic's `hooks` 1.x constraint rules
/// out of lumina_ui's dependency graph.
class MarketplaceTestBackend {
  MarketplaceTestBackend._(this._process, this.url, this.root);

  final Process _process;
  final Uri url;
  final Directory root;

  static const String adminPassword = 'seed-admin-password-for-tests';
  static const String moderatorPassword = 'seed-moderator-password-for-tests';

  /// The marketplace repo's `server/` (or `LUMINA_MARKETPLACE_SERVER_DIR`):
  /// beside the `shared` package the workspace resolved, else a
  /// `marketplace/server` (or `lumina_marketplace/server`) up the tree.
  static Directory? serverDir() {
    final env = Platform.environment['LUMINA_MARKETPLACE_SERVER_DIR'];
    if (env != null && env.isNotEmpty) return Directory(env);
    final shared = LuminaWorkspace.resolvedPackageDir(LuminaWorkspace.root, 'lumina_marketplace_shared');
    if (shared != null) {
      final candidate = Directory('${Directory(shared).parent.path}/server');
      if (File('${candidate.path}/bin/server.dart').existsSync()) return candidate;
    }
    var dir = Directory.current.absolute;
    for (var i = 0; i < 6; i++) {
      for (final rel in ['marketplace/server', 'lumina_marketplace/server']) {
        final candidate = Directory('${dir.path}/$rel');
        if (File('${candidate.path}/bin/server.dart').existsSync()) return candidate;
      }
      dir = dir.parent;
    }
    return null;
  }

  /// The workspace's `test-assets/` (read only: the seed zips are built in
  /// memory).
  static String get testAssetsDir {
    var dir = Directory.current.absolute;
    for (var i = 0; i < 6; i++) {
      final candidate = Directory('${dir.path}/test-assets');
      if (candidate.existsSync()) return candidate.path;
      dir = dir.parent;
    }
    return '${Directory.current.absolute.parent.path}/test-assets';
  }

  /// Why the backend cannot run here, or null.
  static String? get unavailableReason {
    final dir = serverDir();
    if (dir == null) return 'the marketplace server (marketplace/server) was not found';
    // A pub workspace member resolves at the workspace root (marketplace/).
    if (!File('${dir.path}/.dart_tool/package_config.json').existsSync() &&
        !File('${dir.parent.path}/.dart_tool/package_config.json').existsSync()) {
      return 'run `dart pub get` in ${dir.parent.path} first';
    }
    if (!File('$testAssetsDir/Props/Barrels/bent_barrel.glb').existsSync()) return 'test-assets missing';
    return null;
  }

  static Future<MarketplaceTestBackend> start() async {
    final dir = serverDir()!;
    final root = Directory.systemTemp.createTempSync('lumina_ui_marketplace_');
    // The server runs in its own process group under a watchdog shell that
    // kills the whole group when its stdin closes: on [stop], and also when
    // the test process dies without reaching its teardown (a crash, a
    // timeout, a killed run), so no server outlives its test.
    //
    // Windows has neither `setsid` nor process groups; the server
    // runs as a direct child (`dart` is a .bat, hence the shell) and
    // [_terminate] ends its whole tree with `taskkill /T`.
    final process = await Process.start(
      Platform.isWindows ? 'dart' : 'setsid',
      Platform.isWindows
          ? const ['run', 'bin/server.dart', '--seed']
          : const ['bash', '-c', r'dart run bin/server.dart --seed </dev/null & read -r _; kill -TERM 0'],
      workingDirectory: dir.path,
      runInShell: Platform.isWindows,
      environment: {
        'MARKETPLACE_JWT_SECRET': 'lumina-ui-marketplace-test-secret-0123456789abcdef',
        'MARKETPLACE_HOST': '127.0.0.1',
        'MARKETPLACE_PORT': '0',
        'MARKETPLACE_DB': '${root.path}/marketplace.db',
        'MARKETPLACE_STORAGE': '${root.path}/storage',
        'MARKETPLACE_TEST_ASSETS': testAssetsDir,
        'MARKETPLACE_SEED_ADMIN_PASSWORD': adminPassword,
        'MARKETPLACE_SEED_MODERATOR_PASSWORD': moderatorPassword,
      },
    );
    final ready = Completer<Uri>();
    Uri? listening;
    final log = StringBuffer();
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      log.writeln(line);
      try {
        final j = jsonDecode(line) as Map<String, dynamic>;
        if (j['msg'] == 'listening') listening = Uri.parse(j['url'] as String);
        if (j['msg'] == 'seeded' && listening != null && !ready.isCompleted) ready.complete(listening);
      } catch (_) {}
    });
    process.stderr.transform(utf8.decoder).listen(log.write);
    unawaited(process.exitCode.then((code) {
      if (!ready.isCompleted) ready.completeError(StateError('marketplace server exited ($code):\n$log'));
    }));
    final Uri url;
    try {
      url = await ready.future.timeout(const Duration(minutes: 3));
    } catch (e) {
      await _terminate(process);
      if (root.existsSync()) root.deleteSync(recursive: true);
      throw StateError('marketplace server did not start ($e):\n$log');
    }
    return MarketplaceTestBackend._(process, url, root);
  }

  /// Closes the watchdog's stdin (it then kills the server's process group),
  /// falling back to killing the group outright.
  static Future<void> _terminate(Process process) async {
    if (Platform.isWindows) {
      // Cmd → dart → the server, killed as one tree.
      await Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
      await process.exitCode.timeout(const Duration(seconds: 10), onTimeout: () => -1);
      return;
    }
    try {
      await process.stdin.close();
    } catch (_) {}
    final exited = await process.exitCode.timeout(const Duration(seconds: 10), onTimeout: () => -1);
    if (exited == -1) {
      // setsid made the watchdog the group leader: its pid is the group id.
      await Process.run('kill', ['-KILL', '--', '-${process.pid}']);
    }
  }

  Future<void> stop() async {
    await _terminate(_process);
    // Windows releases the killed server's SQLite file a moment
    // after the process tree is gone.
    await deleteTempProject(root);
  }

  /// A client for tests to set up data through the API.
  MarketplaceClient client() => MarketplaceClient(baseUrl: url, httpClient: realHttpClient());

  var _counter = 0;

  /// Signs up a fresh account on [client].
  Future<AuthSession> signUpUser(MarketplaceClient client, {String? username}) {
    final name = username ?? 'studio${++_counter}_${DateTime.now().microsecondsSinceEpoch % 100000}';
    return client.signUp(email: '$name@example.test', username: name, password: 'correct horse battery', displayName: 'User $name');
  }

  /// Publishes a free plugin listing (a real Lumina plugin package: a
  /// `.lmplugin` manifest, a pubspec and a Dart library, under one top-level
  /// folder that names the package) as [publisher] and returns it.
  Future<Listing> publishPlugin(MarketplaceClient publisher, {required String package, required String title}) async {
    final zip = Archive()
      ..addFile(ArchiveFile.bytes('$package/$package.lmplugin', utf8.encode(const JsonEncoder.withIndent('  ').convert({
            'name': package,
            'friendly_name': title,
            'version': '1.0.0',
            'description': 'A Marketplace test plugin that registers one editor command.',
            'category': 'Marketplace',
            'authors': ['Lumina Tests'],
            'engine_version': '>=0.0.1 <1.0.0',
            'can_contain_content': false,
            'modules': [
              {'name': package, 'type': 'editor', 'entry_library': 'lib/$package.dart', 'registration_class': 'TestPlugin'},
            ],
          }))))
      ..addFile(ArchiveFile.bytes('$package/pubspec.yaml', utf8.encode('name: $package\nversion: 1.0.0\n')))
      ..addFile(ArchiveFile.bytes('$package/lib/$package.dart', utf8.encode('/// $title.\nclass TestPlugin {}\n')))
      ..addFile(ArchiveFile.bytes('$package/README.md', utf8.encode('# $title\n')));
    var listing = await publisher.createListing(NewListing(
      category: ListingCategory.plugin,
      title: title,
      description: '# $title\n\nPublished by the lumina_ui marketplace tests.',
      tags: const ['plugin', 'test'],
    ));
    final upload = await publisher.upload(ZipEncoder().encode(zip), fileName: '$package.zip');
    final terms = await publisher.terms();
    await publisher.publishVersion(
      listing.id,
      NewVersion(
        version: '1.0.0',
        uploadId: upload.id,
        licenses: const LicenseSelection(code: 'MIT'),
        attestation: true,
        termsVersion: terms.version,
      ),
    );
    listing = await publisher.listing(listing.id);
    return listing;
  }
}

/// A real `dart:io` HTTP client that bypasses flutter_test's HttpOverrides
/// (which answer every request with 400) and runs requests in the root zone,
/// so keep-alive timers are real timers rather than fake ones a widget test
/// would see pending at its end.
http.Client realHttpClient() =>
    _RootZoneClient(IOClient(HttpOverrides.runWithHttpOverrides(HttpClient.new, _RealHttpOverrides())));

class _RealHttpOverrides extends HttpOverrides {}

class _RootZoneClient extends http.BaseClient {
  _RootZoneClient(this._inner);
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => Zone.root.run(() => _inner.send(request));

  @override
  void close() => Zone.root.run(_inner.close);
}

/// A minimal Lumina project on disk (manifest + default level folder) in
/// [parent], for installing into.
Directory createMarketplaceTestProject(Directory parent, String name) {
  final dir = Directory('${parent.path}/$name')..createSync(recursive: true);
  Directory('${dir.path}/contents/levels').createSync(recursive: true);
  Directory('${dir.path}/contents/Props').createSync(recursive: true);
  File('${dir.path}/$name.lmproject')
      .writeAsStringSync('{"project_name": "$name", "active_level": "contents/levels/L_Main.lmas"}');
  return dir;
}
