import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/flutter_filament_web_module.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/web_module_download.dart';

import '../helpers/flutter_build_stand_in.dart';
import '../helpers/web_module_release_server.dart';

/// The web module the editor downloads: where the web build looks for it,
/// the background download against a real local release server, and the
/// web cook staging the downloaded files.
void main() {
  late Directory tempDir;
  late WebModuleReleaseServer server;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('lumina_web_module_');
    LuminaDataDir.override = Directory('${tempDir.path}/lumina_data');
    server = await WebModuleReleaseServer.start();
  });

  tearDown(() async {
    LuminaDataDir.override = null;
    await server.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A package root whose resolved flutter_filament has a built `web/`
  /// module (what build_module.sh leaves behind).
  String packageWithBuiltModule() {
    final pkg = Directory('${tempDir.path}/flutter_filament')..createSync();
    final web = Directory('${pkg.path}/web')..createSync();
    File('${web.path}/flutter_filament.js').writeAsStringSync('// local build\n');
    File('${web.path}/flutter_filament.wasm').writeAsBytesSync([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0]);
    final root = Directory('${tempDir.path}/game')..createSync();
    File('${root.path}/.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({
        'configVersion': 2,
        'packages': [
          {'name': 'flutter_filament', 'rootUri': '../../flutter_filament', 'packageUri': 'lib/'},
        ],
      }));
    return root.path;
  }

  WebModuleDownload download({String tag = 'v9.9.9'}) => WebModuleDownload(
        root: Directory('${tempDir.path}/downloads'),
        requestedTag: tag,
        baseUrl: server.baseUrl,
        apiUrl: server.apiUrl,
        packageRoots: const [],
      );

  group('locate order', () {
    test('nothing built, nothing downloaded → null', () {
      expect(FlutterFilamentWebModule.locate(packageRoots: const [], downloadRoot: Directory('${tempDir.path}/downloads')), isNull);
    });

    test('the downloaded copy is used when the package has no build', () async {
      server.publish('v9.9.9');
      expect(await download().start(), isTrue);
      final module = FlutterFilamentWebModule.locate(packageRoots: [packageWithoutModule(tempDir)], downloadRoot: Directory('${tempDir.path}/downloads'));
      expect(module, isNotNull);
      expect(module!.source, FlutterFilamentWebModuleSource.download);
      expect(module.directory.path.replaceAll(r'\', '/'), '${tempDir.path}/downloads/module'.replaceAll(r'\', '/'));
      expect(module.files.map((f) => f.uri.pathSegments.last), FlutterFilamentWebModule.fileNames);
    });

    test('a local package build wins over the download', () async {
      server.publish('v9.9.9');
      expect(await download().start(), isTrue);
      final module = FlutterFilamentWebModule.locate(packageRoots: [packageWithBuiltModule()], downloadRoot: Directory('${tempDir.path}/downloads'));
      expect(module!.source, FlutterFilamentWebModuleSource.packageBuild);
      expect(module.files.first.readAsStringSync(), '// local build\n');
    });

    test('the default download root is the per-user data folder', () async {
      server.publish('v9.9.9');
      final d = WebModuleDownload(requestedTag: 'v9.9.9', baseUrl: server.baseUrl, apiUrl: server.apiUrl, packageRoots: const []);
      expect(await d.start(), isTrue);
      expect(d.root.path, LuminaDataDir.webModuleRoot().path);
      expect(FlutterFilamentWebModule.locate(packageRoots: const [])!.source, FlutterFilamentWebModuleSource.download);
      expect(HostBuildTargets.engineUnsupportedReason('web', packageRoots: const []), isNull);
    });
  });

  group('WebModuleDownload', () {
    test('downloads, verifies and unpacks a real zip from the release server, with progress', () async {
      server.publish('v9.9.9');
      final d = download();
      final phases = <WebModuleDownloadPhase>[];
      final fractions = <double>[];
      d.addListener(() {
        phases.add(d.phase);
        fractions.add(d.progress);
      });
      expect(await d.start(), isTrue);
      expect(d.phase, WebModuleDownloadPhase.ready);
      expect(d.install!.tag, 'v9.9.9');
      expect(phases.first, WebModuleDownloadPhase.downloading);
      expect(fractions.last, 1);
      final module = FlutterFilamentWebModule.locateDownload(d.root)!;
      expect(module.files.first.readAsStringSync(), contains('v9.9.9'));
      expect(server.requests, ['/download/v9.9.9/flutter-filament-web-v9.9.9.zip.sha256', '/download/v9.9.9/flutter-filament-web-v9.9.9.zip']);
    });

    test('a sha256 mismatch is rejected: failed, nothing installed, the error says why', () async {
      server.publish('v9.9.9', sha: 'b' * 64);
      final d = download();
      expect(await d.start(), isFalse);
      expect(d.phase, WebModuleDownloadPhase.failed);
      expect(d.error, contains('Checksum mismatch'));
      expect(FlutterFilamentWebModule.locateDownload(d.root), isNull);
    });

    test('offline: failed with the error, then retry succeeds once the release is there', () async {
      final d = download();
      expect(await d.start(), isFalse, reason: 'no release has the asset yet');
      expect(d.phase, WebModuleDownloadPhase.failed);
      server.publish('v9.9.9');
      expect(await d.retry(), isTrue);
      expect(d.phase, WebModuleDownloadPhase.ready);
    });

    test('a call while one runs joins it; startAtLaunch skips when a local build exists', () async {
      server.publish('v9.9.9');
      final d = download();
      final a = d.start();
      final b = d.start();
      expect(await a, isTrue);
      expect(await b, isTrue);
      expect(server.requests.where((r) => r.endsWith('.zip')), hasLength(1));
      server.requests.clear();
      final withBuild = WebModuleDownload(
          root: Directory('${tempDir.path}/other'), requestedTag: 'v9.9.9', baseUrl: server.baseUrl, packageRoots: [packageWithBuiltModule()]);
      expect(await withBuild.startAtLaunch(), isTrue);
      expect(server.requests, isEmpty, reason: 'the local build wins, nothing is downloaded');
    });

    test('a new editor version downloads again; the same one reuses the install', () async {
      server.publish('v1.0.0', published: '2026-09-01T00:00:00Z');
      expect(await download(tag: 'v1.0.0').start(), isTrue);
      server.requests.clear();
      expect(await download(tag: 'v1.0.0').start(), isTrue);
      expect(server.requests, isEmpty);
      server.publish('v1.1.0', published: '2026-10-01T00:00:00Z');
      final upgraded = download(tag: 'v1.1.0');
      expect(await upgraded.start(), isTrue);
      expect(upgraded.install!.tag, 'v1.1.0');
    });
  });

  test('the web cook stages the downloaded module into build/web', () async {
    server.publish('v9.9.9');
    final d = download();
    expect(await d.start(), isTrue);
    final module = FlutterFilamentWebModule.locate(packageRoots: const [], downloadRoot: d.root)!;
    final projDir = Directory('${tempDir.path}/web_game')..createSync();
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/contents/levels/L_Main.lmas').writeAsStringSync(jsonEncode({
      'assetId': 'level_L_Main',
      'name': 'L_Main',
      'type': 'level',
      'relativePath': 'contents/levels/L_Main.lmas',
      'metadata': {'actors': <Map<String, dynamic>>[]},
    }));
    const project = LuminaProject(projectName: 'web_game', activeLevel: 'contents/levels/L_Main.lmas');
    writeFlutterWebPlatform(projDir.path);
    final events = await BuildPipelineService()
        .run(
          BuildPlan(steps: [
            CookAndPackageStep(
              target: 'web',
              configuration: BuildConfiguration.shipping,
              processStarter: flutterBuildStandIn(tempDir),
              webModule: module,
            ),
          ]),
          projectDir: projDir.path,
          project: project,
        )
        .toList();
    final finished = events.whereType<BuildStepFinished>().single;
    expect(finished.status, BuildStepStatus.ok, reason: finished.message);
    for (final source in module.files) {
      final staged = File('${projDir.path}/build/web/${source.uri.pathSegments.last}');
      expect(staged.readAsBytesSync(), source.readAsBytesSync(), reason: '${staged.path} is the downloaded file');
    }
  });
}

/// A package root with a resolved flutter_filament that has no `web/`
/// build.
String packageWithoutModule(Directory tempDir) {
  final pkg = Directory('${tempDir.path}/flutter_filament_unbuilt')..createSync();
  final root = Directory('${tempDir.path}/game_unbuilt')..createSync();
  File('${root.path}/.dart_tool/package_config.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode({
      'configVersion': 2,
      'packages': [
        {'name': 'flutter_filament', 'rootUri': '../../${pkg.uri.pathSegments.where((s) => s.isNotEmpty).last}', 'packageUri': 'lib/'},
      ],
    }));
  return root.path;
}
