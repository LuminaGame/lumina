import 'dart:convert';
import 'dart:io';

import 'package:flutter_filament/filament.dart' show FilamentInfo;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';

import '../helpers/flutter_build_stand_in.dart';
import '../helpers/temp_project.dart';

/// The project icon in Project Settings, against a real temp project with a
/// real `.lmproject` on disk.
void main() {
  late Directory tempDir;
  late Directory projDir;
  late File manifest;

  Future<LuminaProject> readManifest() async =>
      LuminaProject.fromMap(jsonDecode(await manifest.readAsString()) as Map<String, dynamic>);

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('lumina_project_settings_');
    // No Filament Android archives in these runs.
    HostBuildTargets.filamentDirOverride = '${tempDir.path}/no_filament';
    projDir = Directory('${tempDir.path}/settings_game')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    Directory('${projDir.path}/contents/meshes').createSync(recursive: true);
    const project = LuminaProject(
      projectName: 'settings_game',
      activeLevel: 'contents/levels/L_Main.lmas',
      settings: EngineScalabilitySettings(targetFps: 60, vsyncEnabled: true, qualityPreset: 'epic'),
    );
    manifest = File('${projDir.path}/settings_game.lmproject');
    manifest.writeAsStringSync(jsonEncode(project.toMap()));
    // Seed real assets: two levels + one mesh (must be excluded from map pickers).
    final repo = AssetRepository();
    await repo.createAsset(projectPath: projDir.path, subFolder: 'levels', fileName: 'L_Main.lmas', type: AssetType.level);
    await repo.createAsset(projectPath: projDir.path, subFolder: 'levels', fileName: 'L_Arena.lmas', type: AssetType.level);
    await repo.createAsset(projectPath: projDir.path, subFolder: 'meshes', fileName: 'SM_Rock.lmas', type: AssetType.filamesh);
  });

  // Retries: Windows refuses to delete a folder the editor's git probe
  // still works in.
  tearDown(() {
    HostBuildTargets.filamentDirOverride = null;
    return deleteTempProject(tempDir);
  });

  group('the project icon is the packaged app icon', () {
    const host = HostBuildTargets(flutterAvailable: true, flutterVersion: '3.47.0', targets: ['linux', 'web'], operatingSystem: 'linux');
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><circle cx="32" cy="32" r="30" fill="#E11D48"/></svg>';

    /// The platform folders `flutter create` gives a project, trimmed to the
    /// files the icon step patches: the Linux runner and CMakeLists, and the web manifest.
    void writeLinuxAndWebPlatforms() {
      Directory('${projDir.path}/linux/runner').createSync(recursive: true);
      File('${projDir.path}/linux/runner/my_application.cc').writeAsStringSync(
          'static void my_application_activate(GApplication* application) {\n'
          '  GtkWindow* window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));\n'
          '  gtk_window_set_default_size(window, 1280, 720);\n'
          '  g_autoptr(FlDartProject) project = fl_dart_project_new();\n}\n');
      File('${projDir.path}/linux/CMakeLists.txt').writeAsStringSync(
          'set(BINARY_NAME "settings_game")\nset(APPLICATION_ID "com.example.settings_game")\n'
          'set(INSTALL_BUNDLE_DATA_DIR "\${CMAKE_INSTALL_PREFIX}/data")\nset(INSTALL_BUNDLE_LIB_DIR "\${CMAKE_INSTALL_PREFIX}/lib")\n');
      writeFlutterWebPlatform(projDir.path);
      File('${projDir.path}/web/manifest.json').writeAsStringSync('{"name": "settings_game", "start_url": "."}');
    }

    test('Choose copies the icon into the project; Apply writes it into every platform folder; the Lumina logo is the default', () async {
      writeLinuxAndWebPlatforms();
      final source = File('${tempDir.path}/my_icon.svg')..writeAsStringSync(svg);
      final vm = ProjectSettingsViewModel(projectDirPath: projDir.path, hostTargets: host);
      await vm.load();
      expect(vm.project.branding.usesDefaultIcon, isTrue);
      expect(await vm.chooseIcon(source.path), isNull);
      expect(vm.project.branding.icon, 'branding/app_icon.svg');
      expect(File('${projDir.path}/branding/app_icon.svg').readAsStringSync(), svg, reason: 'same bytes, copied into the project');
      expect(await vm.apply(), isTrue);
      expect((await readManifest()).branding.icon, 'branding/app_icon.svg');
      final runnerIcon = img.decodePng(File('${projDir.path}/linux/runner/resources/app_icon.png').readAsBytesSync())!;
      expect((runnerIcon.width, runnerIcon.height), (512, 512));
      final centre = runnerIcon.getPixel(256, 256);
      expect([centre.r, centre.g, centre.b], [0xE1, 0x1D, 0x48], reason: 'the chosen SVG, rendered');
      expect(File('${projDir.path}/linux/runner/my_application.cc').readAsStringSync(), contains('gtk_window_set_icon_list'));
      expect(File('${projDir.path}/web/icons/Icon-512.png').existsSync(), isTrue);
      expect(vm.iconStatus, contains('Linux'));

      vm.useDefaultIcon();
      expect(vm.project.branding.icon, '');
      expect(await vm.apply(), isTrue);
      final logo = img.decodePng(File('${projDir.path}/linux/runner/resources/app_icon.png').readAsBytesSync())!;
      expect(logo.getPixel(256, 256), isNot(equals(centre)), reason: 'the Lumina logo replaced the red circle');

      vm.setIconBackground('zz');
      expect(vm.validationErrors[ProjectSettingsCategory.description], [contains('#RRGGBB')]);
      vm.setIconBackground('#1e90ff');
      expect(vm.validationErrors[ProjectSettingsCategory.description], isEmpty);

      final notAnImage = File('${tempDir.path}/notes.png')..writeAsStringSync('not a png');
      expect(await vm.chooseIcon(notAnImage.path), contains('cannot be used as an icon'));
      expect(vm.project.branding.icon, '', reason: 'a refused file changes nothing');
    });

    test('packaging writes each target\'s icons before its build and finishes the Linux bundle', () async {
      writeLinuxAndWebPlatforms();
      File('${projDir.path}/contents/levels/L_Main.lmas').writeAsStringSync(jsonEncode({
        'assetId': 'level_L_Main',
        'name': 'L_Main',
        'type': 'level',
        'relativePath': 'contents/levels/L_Main.lmas',
        'metadata': {'actors': <Map<String, dynamic>>[]},
      }));
      final module = FlutterFilamentWebModule.locate();
      if (module == null) return markTestSkipped('flutter_filament web module not built');
      if (module.staleReason(filamentVersion: FilamentInfo.version) case final stale?) return markTestSkipped(stale);
      final source = File('${tempDir.path}/my_icon.svg')..writeAsStringSync(svg);
      final recordDir = Directory('${tempDir.path}/record')..createSync();
      final vm = ProjectSettingsViewModel(projectDirPath: projDir.path, hostTargets: host, processStarter: flutterBuildStandIn(recordDir));
      await vm.load();
      await vm.chooseIcon(source.path);
      vm.setTargetSelected('web', true);
      expect(await vm.packageProject(), BuildStepStatus.ok, reason: vm.packagingLog.map((l) => '[${l.source}] ${l.message}').join('\n'));
      final package = '${projDir.path}/build/package/linux';
      final icon = img.decodePng(File('$package/data/app_icon.png').readAsBytesSync())!;
      expect((icon.width, icon.height), (512, 512), reason: 'the runner icon was written before the build, and installed into the bundle');
      final desktop = File('$package/com.example.settings_game.desktop').readAsStringSync();
      expect(desktop, contains('Icon=${Directory(package).absolute.path}/data/app_icon.png'));
      // The desktop entry spec quotes a path with spaces or backslashes (a
      // Windows temp dir) and escapes those characters.
      final exePath = '${Directory(package).absolute.path}/settings_game';
      final exec = exePath.contains(RegExp(r'[\s"`$\\]'))
          ? '"${exePath.replaceAllMapped(RegExp(r'["`$\\]'), (m) => '\\${m[0]}')}"'
          : exePath;
      expect(desktop, contains('Exec=$exec'));
      final webIcon = img.decodePng(File('${projDir.path}/build/package/web/icons/Icon-512.png').existsSync()
          ? File('${projDir.path}/build/package/web/icons/Icon-512.png').readAsBytesSync()
          : File('${projDir.path}/web/icons/Icon-512.png').readAsBytesSync())!;
      expect(webIcon.width, 512);
      expect(vm.packagingLog.where((l) => l.target == 'linux').any((l) => l.message.startsWith('App icon from branding/app_icon.svg')), isTrue);
      expect(vm.packagingLog.where((l) => l.target == 'web').any((l) => l.message.startsWith('App icon from')), isTrue);
      expect(vm.packagingLog.where((l) => l.target == 'linux').any((l) => l.message.contains('.desktop')), isTrue);
    });

    testWidgets('the Project Icon row shows the chosen file with working buttons', (tester) async {
      final source = File('${tempDir.path}/my_icon.svg')..writeAsStringSync(svg);
      final vm = ProjectSettingsViewModel(projectDirPath: projDir.path, hostTargets: host);
      await tester.runAsync(vm.load);
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: SizedBox(width: 1200, height: 900, child: ProjectSettingsSubEditor(assetName: 'Project Settings', viewModel: vm))),
      ));
      await tester.pump();
      expect(find.text('Lumina logo (default)'), findsOneWidget);
      expect(tester.widget<OutlineButton>(find.byKey(const ValueKey('project_settings_icon_choose'))).onPressed, isNotNull);
      expect(tester.widget<GhostButton>(find.byKey(const ValueKey('project_settings_icon_default'))).onPressed, isNull,
          reason: 'already the default');
      await tester.runAsync(() => vm.chooseIcon(source.path));
      await tester.pump();
      expect(find.text('branding/app_icon.svg'), findsOneWidget);
      expect(find.byKey(const ValueKey('project_settings_icon_preview')), findsOneWidget);
      final reset = tester.widget<GhostButton>(find.byKey(const ValueKey('project_settings_icon_default')));
      expect(reset.onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('project_settings_icon_default')));
      await tester.pump();
      expect(vm.project.branding.usesDefaultIcon, isTrue);
      // Typed character by character into the same field element: the
      // validation error a half-typed colour raises must not rebuild the
      // field out from under the user.
      final field = find.byKey(const ValueKey('project_settings_icon_background')).evaluate().single;
      final pinned = find.byElementPredicate((e) => identical(e, field));
      const colour = '#1E90FF';
      for (var i = 1; i <= colour.length; i++) {
        await tester.enterText(pinned, colour.substring(0, i));
        await tester.pump();
        if (i == 3) expect(find.textContaining('must be a #RRGGBB colour'), findsOneWidget);
      }
      expect(vm.project.branding.iconBackground, '#1E90FF');
      expect(find.textContaining('must be a #RRGGBB colour'), findsNothing);
    });
  });
}
