import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/views/status_bar_web_module_segment.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/web_module_download.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/web_module_release_server.dart';

/// Project Settings ▸ Packaging while flutter_filament's web module is
/// missing: the download button, its progress, a failure with a retry, and
/// the Web target becoming buildable once the module is downloaded — all
/// against a real temp project and a real local release server.
void main() {
  const host = HostBuildTargets(flutterAvailable: true, flutterVersion: '3.47.0', targets: ['linux', 'web'], operatingSystem: 'linux');
  late Directory tempDir;
  late Directory projDir;
  late WebModuleReleaseServer server;
  HttpOverrides? testOverrides;

  setUp(() async {
    // flutter_test answers every HttpClient request with HTTP 400; the
    // download talks to the real loopback release server instead.
    testOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    tempDir = Directory.systemTemp.createTempSync('wmd_project_settings_');
    LuminaDataDir.override = Directory('${tempDir.path}/lumina_data');
    projDir = Directory('${tempDir.path}/wmd_game')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/wmd_game.lmproject')
        .writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'wmd_game', activeLevel: 'contents/levels/L_Main.lmas').toMap()));
    server = await WebModuleReleaseServer.start();
  });

  tearDown(() async {
    HttpOverrides.global = testOverrides;
    LuminaDataDir.override = null;
    await server.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<(ProjectSettingsViewModel, WebModuleDownload)> pumpPackaging(WidgetTester tester) async {
    final download = WebModuleDownload(
      root: Directory('${tempDir.path}/downloads'),
      requestedTag: 'v9.9.9',
      baseUrl: server.baseUrl,
      apiUrl: server.apiUrl,
      packageRoots: const [],
    );
    final vm = ProjectSettingsViewModel(
      projectDirPath: projDir.path,
      hostTargets: host,
      webModulePackageRoots: const [],
      webModuleDownload: download,
    );
    addTearDown(vm.dispose);
    addTearDown(download.dispose);
    await tester.runAsync(vm.load);
    vm.setTargetSelected('web', true);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SizedBox(width: 1200, height: 1400, child: ProjectSettingsSubEditor(assetName: 'Project Settings', viewModel: vm))),
    ));
    await tester.tap(find.byKey(const ValueKey('project_settings_nav_${ProjectSettingsCategory.packaging}')));
    await tester.pump();
    return (vm, download);
  }

  Future<void> waitFor(WidgetTester tester, bool Function() done) => tester.runAsync(() async {
        for (var i = 0; i < 500 && !done(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

  testWidgets('missing module: a download button with progress instead of the build hint; then the Web target is buildable',
      (tester) async {
    server.publish('v9.9.9');
    final (vm, download) = await pumpPackaging(tester);
    expect(vm.webModule, isNull);
    expect(vm.reasonsFor('web'), [contains('not downloaded')]);
    expect(find.byKey(const ValueKey('project_settings_web_module_download')), findsOneWidget);
    expect(find.byKey(const ValueKey('project_settings_web_module_hint')), findsOneWidget);
    expect(find.textContaining('build_module.sh'), findsOneWidget, reason: 'the build hint stays, as secondary text');
    expect(find.byKey(const ValueKey('project_settings_target_reason_web_0')), findsNothing,
        reason: 'the download line replaces the "not available" reason');

    // Hold the release server so the running download can be seen.
    // Made outside the fake-async zone, so completing it reaches the server.
    late Completer<void> gate;
    await tester.runAsync(() async {
      gate = Completer<void>();
      server.gate = gate.future;
    });
    await tester.runAsync(() async {
      tester.widget<OutlineButton>(find.byKey(const ValueKey('project_settings_web_module_download'))).onPressed!();
    });
    await waitFor(tester, () => download.isDownloading);
    await tester.pump();
    expect(find.byKey(const ValueKey('project_settings_web_module_progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('project_settings_web_module_download')), findsNothing);

    await tester.runAsync(() async => gate.complete());
    await waitFor(tester, () => download.phase == WebModuleDownloadPhase.ready);
    await tester.pump();
    expect(vm.webModule, isNotNull);
    expect(vm.reasonsFor('web'), isEmpty);
    expect(find.byKey(const ValueKey('project_settings_web_module_found')), findsOneWidget);
    expect(find.textContaining('downloaded v9.9.9'), findsOneWidget);
    expect(find.byKey(const ValueKey('project_settings_web_module_progress')), findsNothing);
  });

  testWidgets('a failed download shows the error and a retry that succeeds', (tester) async {
    server.publish('v9.9.9', sha: 'c' * 64);
    final (vm, download) = await pumpPackaging(tester);
    await tester.runAsync(() async {
      tester.widget<OutlineButton>(find.byKey(const ValueKey('project_settings_web_module_download'))).onPressed!();
    });
    await waitFor(tester, () => download.phase == WebModuleDownloadPhase.failed);
    await tester.pump();
    expect(find.byKey(const ValueKey('project_settings_web_module_error')), findsOneWidget);
    expect(find.textContaining('Checksum mismatch'), findsOneWidget);
    expect(find.byKey(const ValueKey('project_settings_web_module_retry')), findsOneWidget);
    expect(vm.webModule, isNull);

    // The release is fixed upstream: Retry installs it.
    server.publish('v9.9.9');
    await tester.runAsync(() async {
      tester.widget<OutlineButton>(find.byKey(const ValueKey('project_settings_web_module_retry'))).onPressed!();
    });
    await waitFor(tester, () => download.phase == WebModuleDownloadPhase.ready);
    await tester.pump();
    expect(vm.webModule, isNotNull);
    expect(find.byKey(const ValueKey('project_settings_web_module_error')), findsNothing);
    expect(find.byKey(const ValueKey('project_settings_web_module_found')), findsOneWidget);
  });

  testWidgets('the status bar segment shows a running or failed download, and nothing once it is installed', (tester) async {
    server.publish('v9.9.9', sha: 'd' * 64);
    final download = WebModuleDownload(
        root: Directory('${tempDir.path}/downloads'), requestedTag: 'v9.9.9', baseUrl: server.baseUrl, apiUrl: server.apiUrl, packageRoots: const []);
    addTearDown(download.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: Row(children: [WebModuleStatusSegment(download: download)]))));
    expect(find.byKey(const ValueKey('status_web_module')), findsNothing, reason: 'idle: nothing to show');
    await tester.runAsync(download.start);
    await tester.pump();
    expect(find.text('Web module download failed'), findsOneWidget);
    server.publish('v9.9.9');
    await tester.runAsync(download.retry);
    await tester.pump();
    expect(download.phase, WebModuleDownloadPhase.ready);
    expect(find.byKey(const ValueKey('status_web_module')), findsNothing);
  });
}
