import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/web_module_download.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Project Settings ▸ Packaging on a machine without flutter_filament's web
/// module: the Web target offers a download, the real
/// `flutter-filament-web-v0.0.1-dev.16.zip` comes from the GitHub release
/// (sha256-checked, unpacked into a temp data folder) and the Web target
/// becomes buildable. Skips without network.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const name = 'Web module download: Packaging offers the download, then the Web target is buildable';

  testWidgets(name, (tester) async {
    try {
      await tester.runAsync(() => InternetAddress.lookup('github.com').timeout(const Duration(seconds: 5)));
    } catch (e) {
      return markTestSkipped('no network: $e');
    }
    final temp = Directory.systemTemp.createTempSync('lumina_smoke_web_module_');
    final projDir = Directory('${temp.path}/WebGame')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/WebGame.lmproject')
        .writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'WebGame', activeLevel: 'contents/levels/L_Main.lmas').toMap()));
    final download = WebModuleDownload(root: Directory('${temp.path}/flutter_filament_web'), requestedTag: 'v0.0.1-dev.16', packageRoots: const []);
    // The host can build Linux, Windows and Web; only the engine's module is missing.
    const host = HostBuildTargets(
        flutterAvailable: true, flutterVersion: '3.47.0', targets: ['linux', 'windows', 'web'], operatingSystem: 'windows');
    final vm = ProjectSettingsViewModel(projectDirPath: projDir.path, hostTargets: host, webModulePackageRoots: const [], webModuleDownload: download);
    try {
      await tester.runAsync(vm.load);
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(child: ProjectSettingsSubEditor(assetName: 'Project Settings', viewModel: vm)),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(milliseconds: 800));

      await tester.tap(find.byKey(const ValueKey('project_settings_nav_${ProjectSettingsCategory.packaging}')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 900));
      // Tick Web: its row offers the download instead of a dead end.
      await tester.tap(find.byKey(const ValueKey('project_settings_target_web')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 900));
      expect(vm.webModule, isNull);
      expect(find.byKey(const ValueKey('project_settings_web_module_download')), findsOneWidget);
      expect(find.byKey(const ValueKey('project_settings_web_module_hint')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('project_settings_target_windows')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 900));
      final button = find.byKey(const ValueKey('project_settings_web_module_download'));
      final mouse = TestPointer(41, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(tester.getCenter(button)));
      await rec.hold(const Duration(milliseconds: 900));
      SmokeArtifacts.saveScreenshot('$name 01 before the download',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));

      await tester.tap(button);
      await tester.pump();
      final sw = Stopwatch()..start();
      while (download.phase != WebModuleDownloadPhase.ready &&
          download.phase != WebModuleDownloadPhase.failed &&
          sw.elapsed < const Duration(minutes: 3)) {
        await rec.hold(const Duration(milliseconds: 100));
      }
      expect(download.phase, WebModuleDownloadPhase.ready, reason: download.error);
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 900));
      expect(download.install!.tag, 'v0.0.1-dev.16');
      expect(download.install!.sha256, '5545758085cfd5388028776fe830d75a37b3a049b24753ed7ab82dd9c5ca62ef');
      expect(vm.webModule, isNotNull);
      expect(vm.reasonsFor('web'), isEmpty, reason: 'the Web target is buildable');
      expect(find.byKey(const ValueKey('project_settings_web_module_found')), findsOneWidget);
      expect(find.textContaining('downloaded v0.0.1-dev.16'), findsOneWidget);
      await tester.sendEventToBinding(mouse.hover(tester.getCenter(find.byKey(const ValueKey('project_settings_package')))));
      await rec.hold(const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('project_settings_target_windows')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('project_settings_target_linux')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('project_settings_target_linux')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 900));
      await tester.sendEventToBinding(mouse.hover(tester.getCenter(find.byKey(const ValueKey('project_settings_target_web')))));
      await rec.hold(const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('project_settings_target_windows')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 900));
      SmokeArtifacts.saveScreenshot(name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
      rec.save(name);
    } finally {
      vm.dispose();
      download.dispose();
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // A scanner holding a file: the OS temp cleanup takes it.
      }
    }
  });
}
