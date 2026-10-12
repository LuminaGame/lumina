import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/dlss_sdk_download.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings/dlss_bundle_panel.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Project Settings ▸ Packaging ▸ NVIDIA DLSS Runtime against a real temp
/// project: the opt-in checkbox (off by default, saved into the .lmproject),
/// the licence notice and the licence text, and the SDK line: found, or
/// missing with the fetch command and a Fetch button that downloads the real
/// SDK files from a loopback server. Skips when the SDK is not fetched on
/// this machine.
void main() {
  const host = HostBuildTargets(flutterAvailable: true, flutterVersion: '3.47.0', targets: ['windows', 'linux'], operatingSystem: 'windows');
  final filamentRoot = LuminaWorkspace.packageIn(LuminaWorkspace.findSourceRoot() ?? LuminaWorkspace.root, 'flutter_filament');
  final realSdk = DlssSdk.readSync(filamentRoot);
  final skip = realSdk == null || !realSdk.isFetched
      ? 'the DLSS SDK is not fetched: run `dart run tool/dlss/fetch_sdk.dart` in $filamentRoot'
      : null;
  late Directory temp;
  late Directory projDir;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('dlss_settings_');
    projDir = Directory(p.join(temp.path, 'dlss_game'))..createSync(recursive: true);
    Directory(p.join(projDir.path, 'contents', 'levels')).createSync(recursive: true);
    File(p.join(projDir.path, 'dlss_game.lmproject'))
        .writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'dlss_game', activeLevel: 'contents/levels/L_Main.lmas').toMap()));
  });
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<void> waitFor(WidgetTester tester, bool Function() done) => tester.runAsync(() async {
        for (var i = 0; i < 1000 && !done(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

  Future<ProjectSettingsViewModel> pumpPackaging(WidgetTester tester, {required List<String> roots, DlssSdkDownload? download}) async {
    final vm = ProjectSettingsViewModel(
      projectDirPath: projDir.path,
      hostTargets: host,
      webModulePackageRoots: const [],
      dlssFallbackPackageRoots: roots,
      dlssSdkDownload: download,
    );
    addTearDown(vm.dispose);
    await tester.runAsync(vm.load);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SizedBox(width: 1200, height: 1600, child: ProjectSettingsSubEditor(assetName: 'Project Settings', viewModel: vm))),
    ));
    await tester.tap(find.byKey(const ValueKey('project_settings_nav_${ProjectSettingsCategory.packaging}')));
    await tester.pump();
    await waitFor(tester, () => vm.dlssSdkLooked);
    await tester.pump();
    return vm;
  }

  testWidgets('off by default; ticking it and Apply writes bundle_dlss_runtime; the notice and the licence are shown', (tester) async {
    if (skip != null) return markTestSkipped(skip);
    final vm = await pumpPackaging(tester, roots: [realSdk!.packageRoot]);
    expect(find.text('Bundle NVIDIA DLSS runtime (Windows/Linux)'), findsOneWidget);
    final box = find.byKey(const ValueKey('project_settings_bundle_dlss_runtime'));
    expect(tester.widget<Checkbox>(box).state, CheckboxState.unchecked);
    expect(find.byKey(const ValueKey('project_settings_dlss_license_notice')), findsOneWidget);
    expect(find.text(kDlssBundleLicenseNotice), findsOneWidget);
    expect(kDlssBundleLicenseNotice, allOf(contains('NVIDIA RTX SDKs licence'), contains('open-source licence (§4e)'), contains('§2')));
    expect(find.byKey(const ValueKey('project_settings_dlss_sdk_found')), findsOneWidget);
    expect(find.textContaining('DLSS SDK ${realSdk.version}'), findsOneWidget);

    await tester.ensureVisible(box);
    await tester.tap(box);
    await tester.pump();
    expect(vm.project.packaging.bundleDlssRuntime, isTrue);
    expect(vm.isDirty, isTrue);
    expect(await tester.runAsync(vm.apply), isTrue);
    final saved = jsonDecode(File(p.join(projDir.path, 'dlss_game.lmproject')).readAsStringSync()) as Map<String, dynamic>;
    expect((saved['packaging'] as Map)['bundle_dlss_runtime'], isTrue);

    final view = find.byKey(const ValueKey('project_settings_dlss_view_license'));
    await tester.ensureVisible(view);
    await tester.runAsync(() async {
      tester.widget<OutlineButton>(view).onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('project_settings_dlss_license_dialog')), findsOneWidget);
    expect(find.textContaining('NVIDIA RTX SDKs LICENSE'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('project_settings_dlss_license_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('project_settings_dlss_license_dialog')), findsNothing);
  });

  testWidgets('a missing SDK shows the fetch command and a Fetch button that downloads it with progress', (tester) async {
    if (skip != null) return markTestSkipped(skip);
    // flutter_test answers every HttpClient request with HTTP 400.
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = overrides);
    // Server and gate live outside the fake-async zone, so the requests are served.
    late HttpServer server;
    late Completer<void> gate;
    await tester.runAsync(() async {
      gate = Completer<void>();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        await gate.future;
        final path = req.uri.pathSegments.skip(1).join('/');
        final file = File(p.join(realSdk!.sdkDir, path));
        if (file.existsSync()) {
          await req.response.addStream(file.openRead());
        } else {
          req.response.statusCode = 404;
        }
        await req.response.close();
      });
    });
    addTearDown(() => server.close(force: true));
    // A flutter_filament folder with the real VERSION and two manifest lines, nothing fetched.
    final root = p.join(temp.path, 'flutter_filament');
    Directory(p.join(root, 'tool', 'dlss')).createSync(recursive: true);
    File(p.join(root, 'tool', 'dlss', 'VERSION')).writeAsStringSync(realSdk!.version);
    File(p.join(root, 'tool', 'dlss', 'manifest.txt')).writeAsStringSync([
      for (final e in realSdk.manifest.where((e) => e.path == 'LICENSE.txt' || e.path == 'include/nvsdk_ngx.h'))
        '${e.sha256}  ${e.size}  ${e.path}',
    ].join('\n'));
    final download = DlssSdkDownload(fetcher: DlssSdkFetcher(baseUrl: 'http://${server.address.host}:${server.port}'));
    final vm = await pumpPackaging(tester, roots: [root], download: download);

    expect(find.byKey(const ValueKey('project_settings_dlss_sdk_missing')), findsOneWidget);
    expect(find.textContaining(DlssSdk.fetchCommand), findsOneWidget);
    final fetch = find.byKey(const ValueKey('project_settings_dlss_fetch'));
    expect(fetch, findsOneWidget);
    await tester.runAsync(() async => tester.widget<OutlineButton>(fetch).onPressed!());
    await waitFor(tester, () => download.isRunning);
    await tester.pump();
    expect(find.byKey(const ValueKey('project_settings_dlss_fetch_progress')), findsOneWidget);

    await tester.runAsync(() async => gate.complete());
    await waitFor(tester, () => vm.dlssSdk?.isFetched ?? false);
    await tester.pump();
    expect(download.phase, DlssSdkDownloadPhase.done);
    expect(find.byKey(const ValueKey('project_settings_dlss_sdk_found')), findsOneWidget);
    expect(File(p.join(root, 'build', 'dlss-sdk', 'LICENSE.txt')).readAsStringSync(), startsWith('NVIDIA RTX SDKs LICENSE'));
  });
}
