import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';

import '../helpers/flutter_build_stand_in.dart';

/// Every scenario runs against a real
/// temp project with a real `.lmproject` on disk.
void main() {
  late Directory tempDir;
  late Directory projDir;
  late File manifest;

  Future<LuminaProject> readManifest() async =>
      LuminaProject.fromMap(jsonDecode(await manifest.readAsString()) as Map<String, dynamic>);

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('lumina_project_settings_');
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

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  ProjectSettingsViewModel makeVm({ProcessStarter? starter}) =>
      ProjectSettingsViewModel(projectDirPath: projDir.path, processStarter: starter);

  test('load mirrors disk; apply persists vsync/preset + timestamp; revert restores', () async {
    final vm = makeVm();
    await vm.load();
    expect(vm.loadError, isNull);
    expect(vm.project.projectName, 'settings_game');
    expect(vm.project.settings.vsyncEnabled, isTrue);
    expect(vm.project.settings.qualityPreset, 'epic');
    expect(vm.isDirty, isFalse);

    final before = await readManifest();
    vm.setVSync(false);
    vm.setQualityPreset('Low');
    expect(vm.isDirty, isTrue);
    expect(await vm.apply(), isTrue);
    expect(vm.isDirty, isFalse);

    final after = await readManifest();
    expect(after.settings.vsyncEnabled, isFalse);
    expect(after.settings.qualityPreset, 'low');
    expect(after.settings.scalability.shadowQuality, 'low');
    expect(after.lastModifiedTimestamp, isNot(before.lastModifiedTimestamp));

    vm.setTargetFps(120);
    expect(vm.isDirty, isTrue);
    await vm.revert();
    expect(vm.isDirty, isFalse);
    expect(vm.project.settings.targetFps, 60);
    expect(vm.project.settings.vsyncEnabled, isFalse, reason: 'revert reloads the applied disk state');
  });

  test('legacy manifest without the new sections loads with defaults and round-trips them', () async {
    manifest.writeAsStringSync(jsonEncode({
      'project_name': 'settings_game',
      'engine_version': '0.0.1',
      'active_level': 'contents/levels/L_Main.lmas',
      'settings': {'target_fps': 30, 'vsync_enabled': true, 'quality_preset': 'high'},
    }));
    final vm = makeVm();
    await vm.load();
    expect(vm.project.input.actions, isEmpty);
    expect(vm.project.mapsAndModes.defaultGameMode, 'LuminaGameMode');
    expect(vm.project.packaging.targets, ['linux']);
    expect(vm.project.settings.targetFps, 30);
    vm.setDescription('legacy upgraded');
    expect(await vm.apply(), isTrue);
    final raw = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    expect(raw['input'], isA<Map>());
    expect(raw['maps_and_modes'], isA<Map>());
    expect(raw['packaging'], isA<Map>());
    expect((raw['settings'] as Map)['target_fps'], 30, reason: 'existing settings survive');
    expect((raw['settings'] as Map)['quality_preset'], 'high');
  });

  test('Enhanced Input: IA_Jump + Gameplay/Space persists exactly; duplicate names block apply', () async {
    final vm = makeVm();
    await vm.load();
    vm.addAction('IA_Jump');
    vm.addMappingContext('Gameplay');
    vm.updateMappingContext(0, priority: 0);
    vm.addMapping(0, ProjectInputMapping(action: 'IA_Jump', keyId: LogicalKeyboardKey.space.keyId, keyLabel: 'Space', scale: 1.0));
    expect(vm.validationErrors[ProjectSettingsCategory.input], isEmpty);
    expect(await vm.apply(), isTrue);

    final raw = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    expect(raw['input'], {
      'actions': [
        {'name': 'IA_Jump', 'value_type': 'digital'},
      ],
      'mapping_contexts': [
        {
          'name': 'Gameplay',
          'priority': 0,
          'mappings': [
            {'action': 'IA_Jump', 'key_id': LogicalKeyboardKey.space.keyId, 'key': 'Space', 'scale': 1.0, 'axis': ''},
          ],
        },
      ],
    });

    vm.addAction('IA_Jump'); // second action gets a unique suggested name
    expect(vm.project.input.actions.last.name, 'IA_Jump_1');
    vm.updateAction(1, name: 'IA_Jump'); // force the duplicate
    final errors = vm.validationErrors[ProjectSettingsCategory.input]!;
    expect(errors.any((e) => e.contains('Duplicate action name "IA_Jump"')), isTrue);
    expect(vm.errorCount(ProjectSettingsCategory.input), greaterThan(0), reason: 'badge count for the Input category');
    expect(await vm.apply(), isFalse, reason: 'apply refuses to save with errors');
    final unchanged = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    expect((unchanged['input'] as Map)['actions'], hasLength(1));
  });

  test('Maps & Modes picker lists only LEVEL assets; missing map is a warning, not an error', () async {
    final vm = makeVm();
    await vm.load();
    expect(vm.levels.map((l) => l.displayName), containsAll(['L_Main', 'L_Arena']));
    expect(vm.levels.any((l) => l.displayName == 'SM_Rock'), isFalse);
    final arena = vm.levels.firstWhere((l) => l.displayName == 'L_Arena');
    expect(arena.relativePath, 'contents/levels/L_Arena.lmas');
    vm.setGameDefaultMap(arena.relativePath);
    expect(await vm.apply(), isTrue);
    expect((await readManifest()).mapsAndModes.gameDefaultMap, 'contents/levels/L_Arena.lmas');

    File('${projDir.path}/contents/levels/L_Arena.lmas').deleteSync();
    expect(vm.validationWarnings[ProjectSettingsCategory.mapsAndModes], isNotEmpty);
    expect(vm.validationErrors[ProjectSettingsCategory.mapsAndModes], isEmpty);
    vm.setDescription('still saveable');
    expect(await vm.apply(), isTrue, reason: 'a warning does not block');
  });

  testWidgets('preset click instantly updates every category select before Apply; disk untouched', (tester) async {
    final vm = makeVm();
    await tester.runAsync(() => vm.load());
    final bytesBefore = manifest.readAsBytesSync();
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: SizedBox(width: 1200, height: 800, child: ProjectSettingsSubEditor(assetName: 'Project Settings', viewModel: vm)),
      ),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('project_settings_nav_${ProjectSettingsCategory.graphics}')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('project_settings_preset_Low')));
    await tester.pump();

    final s = vm.project.settings;
    expect(s.qualityPreset, 'low');
    expect(s.scalability.viewDistance, 'low');
    expect(s.scalability.shadowQuality, 'low');
    expect(s.scalability.antiAliasing, 'none');
    expect(s.scalability.textureQuality, 'low');
    expect(s.scalability.shadingQuality, 'low');
    expect(find.text('low'), findsWidgets, reason: 'per-category selects show the Low tier');
    expect(manifest.readAsBytesSync(), bytesBefore, reason: 'nothing written until Apply');
    expect(find.text('Unsaved changes'), findsOneWidget);

    await tester.runAsync(() => vm.apply());
    await tester.pump();
    final saved = await tester.runAsync(readManifest);
    expect(saved!.settings.qualityPreset, 'low');
  });

  testWidgets('Target FPS 0 renders Unlimited; 300 is rejected; fresh manifest defaults VSync off', (tester) async {
    final vm = makeVm();
    await tester.runAsync(() => vm.load());
    vm.setTargetFps(0);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: SizedBox(width: 1200, height: 800, child: ProjectSettingsSubEditor(assetName: 'Project Settings', viewModel: vm)),
      ),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('project_settings_nav_${ProjectSettingsCategory.graphics}')));
    await tester.pump();
    expect(find.text('Unlimited (0 FPS)'), findsOneWidget);

    vm.setTargetFps(300);
    await tester.pump();
    expect(vm.validationErrors[ProjectSettingsCategory.graphics], isNotEmpty);
    expect(await tester.runAsync(() => vm.apply()), isFalse);

    const fresh = LuminaProject(projectName: 'fresh');
    expect(fresh.settings.vsyncEnabled, isFalse);
    expect(fresh.settings.targetFps, 0);
  });

  testWidgets('settings search filters categories and highlights the matching row', (tester) async {
    final vm = makeVm();
    await tester.runAsync(() => vm.load());
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: SizedBox(width: 1200, height: 800, child: ProjectSettingsSubEditor(assetName: 'Project Settings', viewModel: vm)),
      ),
    ));
    await tester.pump();
    expect(vm.visibleCategories, ProjectSettingsCategory.all);

    await tester.enterText(find.byKey(const ValueKey('project_settings_search')), 'vsync');
    await tester.pump();
    expect(vm.visibleCategories, [ProjectSettingsCategory.graphics]);
    expect(find.byKey(const ValueKey('project_settings_nav_${ProjectSettingsCategory.input}')), findsNothing);
    expect(vm.rowMatches('VSync'), isTrue);
    expect(vm.rowMatches('Target FPS'), isFalse);
    // The VSync row is highlighted (opacity 1) while the FPS row is dimmed.
    final vsyncRow = tester.widget<Opacity>(find.ancestor(
      of: find.byKey(const ValueKey('project_settings_row_VSync')),
      matching: find.byType(Opacity),
    ).first);
    final fpsRow = tester.widget<Opacity>(find.ancestor(
      of: find.byKey(const ValueKey('project_settings_row_Target FPS')),
      matching: find.byType(Opacity),
    ).first);
    expect(vsyncRow.opacity, 1.0);
    expect(fpsRow.opacity, lessThan(1.0));

    await tester.enterText(find.byKey(const ValueKey('project_settings_search')), '');
    await tester.pump();
    expect(vm.visibleCategories, ProjectSettingsCategory.all);
  });

  test('apply propagates to the editor: shared scalability state, not a copy', () async {
    final editor = EditorViewModel(
      initialProject: LuminaProject.fromMap(jsonDecode(await manifest.readAsString()) as Map<String, dynamic>),
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(editor.dispose);
    expect(editor.qualityPreset, 'epic');
    final vm = makeVm()..onApplied = editor.applyProjectSettings;
    await vm.load();
    vm.setQualityPreset('High');
    vm.setVSync(false);
    expect(await vm.apply(), isTrue);
    expect(editor.qualityPreset, 'high');
    expect(editor.vsyncEnabled, isFalse);
    expect(editor.project.settings.scalability.shadowQuality, 'high');
    expect(editor.project.isDirty, isFalse);
  });

  group('several packaging targets', () {
    const host = HostBuildTargets(flutterAvailable: true, flutterVersion: '3.47.0', targets: ['linux', 'web'], operatingSystem: 'linux');

    void writeLevel() => File('${projDir.path}/contents/levels/L_Main.lmas').writeAsStringSync(jsonEncode({
          'assetId': 'level_L_Main',
          'name': 'L_Main',
          'type': 'level',
          'relativePath': 'contents/levels/L_Main.lmas',
          'metadata': {'actors': <Map<String, dynamic>>[]},
        }));

    test('a legacy target_os manifest ticks its platform; ticking writes the list; unknown ids are errors, none is a warning', () async {
      manifest.writeAsStringSync(jsonEncode({
        'project_name': 'settings_game',
        'active_level': 'contents/levels/L_Main.lmas',
        'packaging': {'target_os': 'Linux x64', 'output_dir': 'build'},
      }));
      final vm = ProjectSettingsViewModel(projectDirPath: projDir.path, hostTargets: host);
      await vm.load();
      expect(vm.project.packaging.targets, ['linux']);
      vm.setTargetSelected('web', true);
      vm.setTargetSelected('android', true);
      expect(await vm.apply(), isTrue);
      final raw = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      expect((raw['packaging'] as Map)['targets'], ['linux', 'android', 'web']);
      expect((raw['packaging'] as Map).containsKey('target_os'), isFalse);

      for (final t in ['linux', 'android', 'web']) {
        vm.setTargetSelected(t, false);
      }
      expect(vm.validationWarnings[ProjectSettingsCategory.packaging], [contains('No target platform is ticked')]);
      expect(vm.packageDisabledReason, 'Tick at least one target platform');
      vm.setTargetSelected('ps5', true);
      expect(vm.validationErrors[ProjectSettingsCategory.packaging], [contains('Unknown packaging target "ps5"')]);
    });

    test('Package Project builds every ticked target in turn into its own folder; android is reported, never spawned', () async {
      writeLevel();
      final recordDir = Directory('${tempDir.path}/record')..createSync();
      final logger = EngineLoggerService();
      final vm = ProjectSettingsViewModel(
        projectDirPath: projDir.path,
        logger: logger,
        hostTargets: host,
        processStarter: flutterBuildStandIn(recordDir),
        webModulePackageRoots: const [],
      );
      await vm.load();
      vm.setTargetSelected('android', true);
      expect(vm.reasonsFor('android'), hasLength(2));
      expect(vm.reasonsFor('linux'), isEmpty);
      final result = await vm.packageProject();
      expect(result, BuildStepStatus.failed, reason: 'android could not be built');
      final run = vm.packaging;
      expect(run.isRunning, isFalse);
      expect(run.statuses, {'linux': PackageTargetStatus.ok, 'android': PackageTargetStatus.unbuildable});
      expect(run.packageDirs['linux'], '${projDir.path}/build/package/linux');
      expect(File('${projDir.path}/build/package/linux/settings_game').existsSync(), isTrue);
      expect(run.messages['android'], contains('flutter doctor reports no ready Android toolchain'));
      expect(run.stage, 'Packaged 1 of 2 target(s)');
      expect(File('${recordDir.path}/argv.log').readAsLinesSync(), ['flutter build linux --release']);
      expect(vm.packagingLog.where((l) => l.target == 'linux').any((l) => l.message.contains('Built build/linux')), isTrue);
      expect(vm.packagingLog.where((l) => l.target == 'android').first.level, 'error');
      expect(File('${projDir.path}/lib/levels/l_main.dart').existsSync(), isTrue, reason: 'the game code was generated first');
      expect(logger.logs.any((e) => e.source == 'Packaging' && e.message.contains('Android is not buildable')), isTrue);
    });

    test('a failing flutter build surfaces its exit code for that target; no fake success', () async {
      writeLevel();
      final recordDir = Directory('${tempDir.path}/record')..createSync();
      final vm = ProjectSettingsViewModel(
        projectDirPath: projDir.path,
        hostTargets: host,
        processStarter: flutterBuildStandIn(recordDir, exitCode: 42),
      );
      await vm.load();
      expect(await vm.packageProject(), BuildStepStatus.failed);
      expect(vm.packaging.statuses['linux'], PackageTargetStatus.failed);
      expect(vm.packaging.messages['linux'], contains('exited with code 42'));
      expect(vm.packaging.packageDirs, isEmpty);
      expect(Directory('${projDir.path}/build/package/linux').existsSync(), isFalse);
      expect(vm.packagingLog.any((l) => l.message.contains('stand-in failing on purpose')), isTrue);
    });

    testWidgets('the Packaging category: six checkboxes, reasons, a package run with per-target badges and a tagged log', (tester) async {
      writeLevel();
      final recordDir = Directory('${tempDir.path}/record')..createSync();
      final vm = ProjectSettingsViewModel(
        projectDirPath: projDir.path,
        hostTargets: host,
        processStarter: flutterBuildStandIn(recordDir),
        webModulePackageRoots: const [],
      );
      await tester.runAsync(vm.load);
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: SizedBox(width: 1200, height: 900, child: ProjectSettingsSubEditor(assetName: 'Project Settings', viewModel: vm))),
      ));
      await tester.tap(find.byKey(const ValueKey('project_settings_nav_${ProjectSettingsCategory.packaging}')));
      await tester.pump();
      for (final t in kPackagingPlatforms) {
        expect(find.byKey(ValueKey('project_settings_target_$t')), findsOneWidget);
      }
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('project_settings_target_linux'))).state, CheckboxState.checked);
      await tester.ensureVisible(find.byKey(const ValueKey('project_settings_target_android')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('project_settings_target_android')));
      await tester.pump();
      expect(vm.project.packaging.targets, ['linux', 'android']);
      expect(find.byKey(const ValueKey('project_settings_target_reason_android_0')), findsOneWidget);
      expect(find.textContaining('no Android build of the Filament libraries'), findsOneWidget);
      expect(find.textContaining('need a Windows host'), findsOneWidget);
      expect(find.textContaining('${projDir.path}/build/package/<target>'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('project_settings_apply')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect((await tester.runAsync(readManifest))!.packaging.targets, ['linux', 'android']);

      final button = tester.widget<PrimaryButton>(find.byKey(const ValueKey('project_settings_package')));
      expect(button.onPressed, isNotNull);
      await tester.runAsync(() async {
        button.onPressed!();
        for (var i = 0; i < 400 && (vm.packaging.result == null); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.pump();
      expect(vm.packaging.statuses['linux'], PackageTargetStatus.ok);
      expect(find.byKey(const ValueKey('project_settings_target_status_linux')), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('NOT BUILDABLE'), findsOneWidget);
      expect(find.byKey(const ValueKey('project_settings_target_package_linux')), findsOneWidget);
      expect(find.byKey(const ValueKey('project_settings_package_log')), findsOneWidget);
      // The console is a lazy list pinned to its end: the last lines are on screen, every line is in the log.
      expect(find.textContaining(RegExp(r'^\[(linux|android|package)\] ')), findsWidgets);
      expect(vm.packagingLog.map((l) => l.target).toSet(), containsAll(<String?>['linux', 'android', null]));
      expect(find.text('Packaged 1 of 2 target(s)'), findsOneWidget);
    });
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
      expect(desktop, contains('Exec=${Directory(package).absolute.path}/settings_game'));
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

  group('the UI widget library in Project Settings', () {
    late File pubspec;
    late File widgetDart;

    Future<void> seedWidgetProject() async {
      pubspec = File('${projDir.path}/pubspec.yaml')
        ..writeAsStringSync('name: settings_game\nenvironment:\n  sdk: ^3.12.0\ndependencies:\n  flutter:\n    sdk: flutter\nflutter:\n  uses-material-design: true\n');
      UmgWidgetLibraryService.apply(projDir.path, kUmgWidgetLibraryShadcn);
      await AssetRepository().createAsset(projectPath: projDir.path, subFolder: 'widgets', fileName: 'WBP_Menu.lmas', type: AssetType.widget);
      final umg = UmgEditorViewModel(assetPath: '${projDir.path}/contents/widgets/WBP_Menu.lmas');
      await umg.load();
      umg.addWidget(UmgWidgetType.button, parentId: umg.document.root.id, canvasPosition: const Offset(10, 10));
      await umg.compile();
      widgetDart = File('${projDir.path}/lib/widgets/wbp_menu.dart');
      expect(widgetDart.readAsStringSync(), contains('shadcn_flutter'), reason: 'seeded as a shadcn widget');
    }

    test('switching library rewrites the pubspec, runs flutter pub get once, regenerates every widget; switching back restores', () async {
      await seedWidgetProject();
      final calls = <String>[];
      final vm = makeVm(starter: (exe, args, {workingDirectory}) {
        calls.add('$exe ${args.join(' ')} @ $workingDirectory');
        return Process.start('true', const []);
      });
      await vm.load();
      expect(vm.project.ui.widgetLibrary, kUmgWidgetLibraryShadcn);

      vm.setWidgetLibrary(kUmgWidgetLibraryFlutter);
      expect(vm.isDirty, isTrue);
      expect(await vm.apply(), isTrue);
      expect(pubspec.readAsStringSync(), isNot(contains('shadcn_flutter')));
      expect(calls, ['flutter pub get @ ${projDir.path}']);
      final plain = widgetDart.readAsStringSync();
      expect(plain, isNot(contains('shadcn_flutter')));
      expect(plain, contains('LuminaUmgButton('));
      expect((await readManifest()).ui.widgetLibrary, kUmgWidgetLibraryFlutter);

      vm.setWidgetLibrary(kUmgWidgetLibraryShadcn);
      expect(await vm.apply(), isTrue);
      expect(pubspec.readAsStringSync(), contains('shadcn_flutter: $kGameShadcnFlutterVersion'));
      expect(calls, hasLength(2));
      expect(widgetDart.readAsStringSync(), contains("import 'package:shadcn_flutter/shadcn_flutter.dart';"));
    });

    test('a failing flutter pub get keeps the manifest and the pubspec as they were', () async {
      await seedWidgetProject();
      final vm = makeVm(starter: (exe, args, {workingDirectory}) => Process.start('sh', ['-c', 'echo "network down" 1>&2; exit 3']));
      await vm.load();
      // Snapshot after load: loading a project heals its pubspec's
      // `flutter: assets:` list (lumina's ProjectRepository.ensurePubspecAssets);
      // what a failed switch must leave untouched is the pubspec it started from.
      final before = pubspec.readAsStringSync();
      expect(before, contains('shadcn_flutter: $kGameShadcnFlutterVersion'));
      vm.setWidgetLibrary(kUmgWidgetLibraryFlutter);
      expect(await vm.apply(), isFalse);
      expect(pubspec.readAsStringSync(), before);
      expect((await readManifest()).ui.widgetLibrary, kUmgWidgetLibraryShadcn);
      expect(widgetDart.readAsStringSync(), contains('shadcn_flutter'));
      expect(vm.widgetLibraryError, contains('exit 3'));
    });

    testWidgets('the User Interface category offers both libraries', (tester) async {
      final vm = makeVm();
      await tester.runAsync(vm.load);
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: ProjectSettingsSubEditor(assetName: 'Project Settings', viewModel: vm)),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('User Interface'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('project_settings_widget_library')), findsOneWidget);
      expect(find.textContaining('shadcn_flutter'), findsWidgets);
    });
  });
}
