import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

import '../../test/helpers/blueprint_test_project.dart';

/// Project Settings smoke: real editor on a real temp project, Edit → Project
/// Settings, add IA_Move (axis2D) with W/S bindings, pick the Game Default Map
/// and a GameMode Blueprint saved into a subfolder after the tab opened,
/// Apply; the `.lmproject` on disk must contain the new input block.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Project Settings Smoke: Enhanced Input + Maps & Modes round-trip through the real manifest', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_project_settings_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeSettings')..createSync(recursive: true);
    final repo = AssetRepository();
    await repo.createAsset(projectPath: pDir.path, subFolder: 'levels', fileName: 'L_Main.lmas', type: AssetType.level);
    await repo.createAsset(projectPath: pDir.path, subFolder: 'levels', fileName: 'L_Hub.lmas', type: AssetType.level);
    const project = LuminaProject(projectName: 'SmokeSettings', activeLevel: 'contents/levels/L_Main.lmas');
    final manifest = File('${pDir.path}/SmokeSettings.lmproject')..writeAsStringSync(jsonEncode(project.toMap()));

    final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: MainEditorView(viewModel: vm),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(seconds: 1));

    // Edit → Project Settings, from the menu bar, opens the workspace tab
    // against the live project.
    await tester.tap(find.text('Edit').first);
    await tester.pump(const Duration(milliseconds: 300));
    await rec.hold(const Duration(milliseconds: 700));
    await tester.tap(find.text('Project Settings...').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(vm.openTabs.any((t) => t.category == 'projectSettings'), isTrue);
    final editorFinder = find.byType(ProjectSettingsSubEditor);
    expect(editorFinder, findsOneWidget);
    // Let the async manifest load settle.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await rec.hold(const Duration(seconds: 1));

    // Enhanced Input: IA_Move axis2D with W (+1 Y) and S (-1 Y).
    await tester.tap(find.byKey(const ValueKey('project_settings_nav_${ProjectSettingsCategory.input}')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('project_settings_action_add')));
    await tester.pump();
    await rec.hold(const Duration(milliseconds: 500));
    await rec.typeText(find.byKey(const ValueKey('project_settings_action_name_0')), 'IA_Move');
    await tester.pump();
    await rec.hold(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const ValueKey('project_settings_context_add')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('project_settings_mapping_add_0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('project_settings_mapping_add_0')));
    await tester.pump();
    await rec.hold(const Duration(seconds: 1));
    // Key capture: click "Set key" then press the real key.
    final settingsVm = _findVm(tester);
    await tester.tap(find.byKey(const ValueKey('project_settings_key_capture_0_0')));
    await tester.pump();
    await tester.pump();
    await rec.hold(const Duration(milliseconds: 500));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    expect(settingsVm.project.input.mappingContexts[0].mappings[0].keyLabel, 'W', reason: 'real key capture');
    await rec.hold(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('project_settings_key_capture_0_1')));
    await tester.pump();
    await tester.pump();
    await rec.hold(const Duration(milliseconds: 500));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pump();
    expect(settingsVm.project.input.mappingContexts[0].mappings[1].keyLabel, 'S');
    await rec.hold(const Duration(milliseconds: 600));

    settingsVm.updateAction(0, valueType: ProjectInputValueType.axis2D);
    settingsVm.updateMapping(0, 0, scale: 1.0, axis: 'Y');
    settingsVm.updateMapping(0, 1, scale: -1.0, axis: 'Y');
    settingsVm.updateMappingContext(0, name: 'Gameplay');
    await tester.pump();
    await rec.hold(const Duration(seconds: 1));

    // A GameMode Blueprint saved into contents/blueprints/runner/ while the
    // tab is open: Maps & Modes lists it when the category is opened.
    final gameMode = File(writeBlueprint(pDir.path, 'BP_RunnerGameMode',
        BlueprintEditorViewModel.createDefaultDocument('BP_RunnerGameMode', parentClass: 'LuminaGameMode')));
    Directory('${pDir.path}/contents/blueprints/runner').createSync(recursive: true);
    gameMode.renameSync('${pDir.path}/contents/blueprints/runner/BP_RunnerGameMode.lmas');
    const runnerMode = 'contents/blueprints/runner/BP_RunnerGameMode.lmas';

    // Maps & Modes: pick L_Hub as the Game Default Map.
    await tester.tap(find.byKey(const ValueKey('project_settings_nav_${ProjectSettingsCategory.mapsAndModes}')));
    await tester.pump();
    expect(settingsVm.gameModeClasses, contains(runnerMode));
    final hub = settingsVm.levels.firstWhere((l) => l.displayName == 'L_Hub');
    await rec.hold(const Duration(milliseconds: 700));
    settingsVm.setGameDefaultMap(hub.relativePath);
    await tester.pump();
    await rec.hold(const Duration(milliseconds: 800));
    // Default Game Mode: the dropdown offers the new Blueprint.
    await tester.tap(find.text('LuminaGameMode').last);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await rec.hold(const Duration(milliseconds: 800));
    await tester.tap(find.text('BP_RunnerGameMode (Blueprint)').last);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(settingsVm.project.mapsAndModes.defaultGameMode, runnerMode);
    await rec.hold(const Duration(milliseconds: 800));

    final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot('project_settings_modal', png);

    expect(settingsVm.validationErrors.values.expand((e) => e), isEmpty, reason: 'nothing blocks Apply');
    expect(settingsVm.isDirty, isTrue);
    await tester.tap(find.byKey(const ValueKey('project_settings_apply')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await rec.hold(const Duration(milliseconds: 1200));
    rec.save('Project Settings Smoke: Enhanced Input + Maps & Modes round-trip through the real manifest');

    final raw = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
    final input = raw['input'] as Map<String, dynamic>;
    expect(input['actions'], [
      {'name': 'IA_Move', 'value_type': 'axis2D'},
    ]);
    final ctx = (input['mapping_contexts'] as List).single as Map;
    expect(ctx['name'], 'Gameplay');
    final mappings = (ctx['mappings'] as List).cast<Map>();
    expect(mappings.length, 2);
    expect(mappings[0]['key'], 'W');
    expect(mappings[0]['key_id'], LogicalKeyboardKey.keyW.keyId);
    expect(mappings[0]['scale'], 1.0);
    expect(mappings[0]['axis'], 'Y');
    expect(mappings[1]['key'], 'S');
    expect(mappings[1]['scale'], -1.0);
    expect((raw['maps_and_modes'] as Map)['game_default_map'], 'contents/levels/L_Hub.lmas');
    expect(vm.project.mapsAndModes.gameDefaultMap, 'contents/levels/L_Hub.lmas', reason: 'apply propagated to the editor');
    expect((raw['maps_and_modes'] as Map)['default_game_mode'], runnerMode);

    tempProjectsDir.deleteSync(recursive: true);
  });

  testWidgets('Project Settings Smoke: several packaging targets in one Package Project run', (tester) async {
    const name = 'project_settings: several packaging targets';
    final usedAssets = ['${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb'];
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_package_targets_');
    const projectName = 'pkg_targets_game';
    EditorViewModel? vm;
    try {
      // The real launcher pipeline: flutter create, the lumina path dependency, pub get, manifest.
      final repo = ProjectRepository();
      await tester.runAsync(() async {
        await for (final p in repo.createProjectStream(projectName: projectName, projectLocation: tempProjectsDir.path)) {
          // ignore: avoid_print
          print('[create] ${p.message}');
        }
      });
      final project = await tester.runAsync(() => repo.loadProject('${tempProjectsDir.path}/$projectName/$projectName.lmproject'));
      expect(project!.packaging.targets, ['linux']);
      vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path, enableTimers: false, autoInitAssets: false);
      final editor = vm;
      await tester.runAsync(() async {
        await editor.ensureDefaultLevelAssets();
        await editor.processImportPipeline(sourceFilePath: usedAssets.single);
      });
      editor.refreshAssets();
      final projDir = editor.projectDirPath;

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // Edit → Project Settings → Packaging & Target.
      await tester.tap(find.text('Edit').first);
      await tester.pump(const Duration(milliseconds: 300));
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(find.text('Project Settings...').last);
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      final settings = _findVm(tester);
      await tester.tap(find.byKey(const ValueKey('project_settings_nav_${ProjectSettingsCategory.packaging}')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 800));
      // The real `flutter doctor -v` probe gives every row its reasons.
      expect(await _recordUntil(tester, rec, () => settings.hostTargets != null, progress: () => 0, budget: const Duration(seconds: 120)), isTrue);
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 800));
      expect(settings.reasonsFor('linux'), isEmpty);
      expect(settings.reasonsFor('web'), isEmpty, reason: 'the flutter_filament web module is built');
      expect(settings.reasonsFor('android').join(' '), contains('no Android build of the Filament libraries'));
      expect(settings.reasonsFor('windows').first, contains('Windows host'));

      // Tick Android and Web: both stay tickable, Android with its reasons on screen.
      for (final t in ['android', 'web']) {
        await tester.ensureVisible(find.byKey(ValueKey('project_settings_target_$t')));
        await tester.pump();
        await rec.hold(const Duration(milliseconds: 400));
        await tester.tap(find.byKey(ValueKey('project_settings_target_$t')));
        await tester.pump();
        await rec.hold(const Duration(milliseconds: 900));
      }
      expect(settings.project.packaging.targets, ['linux', 'android', 'web']);
      expect(find.byKey(const ValueKey('project_settings_target_reason_android_0')), findsOneWidget);
      expect(find.textContaining('need a Mac with Xcode'), findsNWidgets(2), reason: 'macOS and iOS');
      SmokeArtifacts.saveScreenshot('$name 01 targets and reasons',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)), usedAssets: usedAssets);

      await tester.tap(find.byKey(const ValueKey('project_settings_apply')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 800));
      final raw = jsonDecode(File('$projDir/$projectName.lmproject').readAsStringSync()) as Map<String, dynamic>;
      expect((raw['packaging'] as Map)['targets'], ['linux', 'android', 'web']);
      expect(editor.buildManagerViewModel.selectedTargets, ['linux', 'android', 'web'], reason: 'the Build Manager reads the same list');

      // Package Project: real flutter builds for Linux and Web, Android reported.
      await tester.ensureVisible(find.byKey(const ValueKey('project_settings_package')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('project_settings_package')));
      await tester.pump();
      expect(await _recordUntil(tester, rec, () => settings.packaging.result != null,
              progress: () => settings.packagingLog.length, budget: const Duration(minutes: 15)),
          isTrue,
          reason: settings.packagingLog.map((l) => '[${l.source}] ${l.message}').join('\n'));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 700));
      final log = settings.packagingLog.map((l) => '[${l.source}] ${l.message}').join('\n');
      expect(settings.packaging.statuses,
          {'linux': PackageTargetStatus.ok, 'android': PackageTargetStatus.unbuildable, 'web': PackageTargetStatus.ok},
          reason: log);
      expect(File('$projDir/build/package/linux/$projectName').existsSync(), isTrue, reason: 'the Linux bundle is packaged');
      expect(File('$projDir/build/package/web/index.html').existsSync(), isTrue, reason: 'the web build is packaged');
      expect(File('$projDir/build/package/web/flutter_filament.wasm').existsSync(), isTrue);
      expect(settings.packagingLog.any((l) => l.target == 'android' && l.message.contains('not buildable')), isTrue, reason: log);
      expect(find.text('NOT BUILDABLE'), findsOneWidget);
      expect(find.text('OK'), findsNWidgets(2));
      await tester.ensureVisible(find.byKey(const ValueKey('project_settings_package_log')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 500));
      // Read back through the run's log with the wheel: every target's tagged lines.
      final logCenter = tester.getCenter(find.byKey(const ValueKey('project_settings_package_log')));
      final wheel = TestPointer(31, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(wheel.hover(logCenter));
      for (final dy in [-60.0, 60.0]) {
        for (var i = 0; i < 24; i++) {
          await tester.sendEventToBinding(wheel.scroll(Offset(0, dy)));
          await rec.hold(const Duration(milliseconds: 66));
        }
      }
      await rec.hold(const Duration(milliseconds: 800));
      SmokeArtifacts.saveScreenshot(name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
          usedAssets: usedAssets);
      rec.save(name, usedAssets: usedAssets);
    } finally {
      vm?.dispose();
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 25)));

  testWidgets('Project Settings Smoke: the packaged Linux game uses the project icon', (tester) async {
    const name = 'project_settings: packaged Linux game uses the project icon';
    final usedAssets = [_iconGlb];
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_project_icon_');
    const projectName = 'icon_game';
    EditorViewModel? vm;
    Process? game;
    try {
      final repo = ProjectRepository(configDir: Directory('${tempProjectsDir.path}/config')..createSync());
      await tester.runAsync(() async {
        await for (final p in repo.createProjectStream(projectName: projectName, projectLocation: tempProjectsDir.path)) {
          // ignore: avoid_print
          print('[create] ${p.message}');
        }
      });
      final project = await tester.runAsync(() => repo.loadProject('${tempProjectsDir.path}/$projectName/$projectName.lmproject'));
      vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path, enableTimers: false, autoInitAssets: false);
      final editor = vm;
      await tester.runAsync(editor.ensureDefaultLevelAssets);
      final projDir = editor.projectDirPath;
      // The custom icon: the real texture inside a test-assets model, as its own WebP file.
      final iconSource = File('${tempProjectsDir.path}/big_button_texture.webp')..writeAsBytesSync(_glbImageBytes(_iconGlb));

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Edit').first);
      await tester.pump(const Duration(milliseconds: 300));
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(find.text('Project Settings...').last);
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      final settings = _findVm(tester);
      await rec.hold(const Duration(milliseconds: 800));
      expect(find.text('Lumina logo (default)'), findsOneWidget);

      // Choose… the texture (the native file dialog is the one step driven through the view model).
      final refused = await tester.runAsync(() => settings.chooseIcon(iconSource.path));
      expect(refused, isNull);
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 1200));
      expect(find.text('branding/app_icon.webp'), findsOneWidget);
      await rec.typeText(find.byKey(const ValueKey('project_settings_icon_background')), '#1E3A5F', perCharacter: const Duration(milliseconds: 60));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('project_settings_apply')));
      await _recordUntil(tester, rec, () => settings.iconStatus?.startsWith('Wrote') ?? false, progress: () => 0, budget: const Duration(seconds: 60));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 1000));
      expect(settings.iconStatus, contains('Linux'), reason: '${settings.iconError}');
      expect(File('$projDir/linux/runner/resources/app_icon.png').existsSync(), isTrue);

      // Package Project for Linux: a real flutter build.
      await tester.tap(find.byKey(const ValueKey('project_settings_nav_${ProjectSettingsCategory.packaging}')));
      await tester.pump();
      expect(await _recordUntil(tester, rec, () => settings.hostTargets != null, progress: () => 0, budget: const Duration(seconds: 120)), isTrue);
      expect(settings.project.packaging.targets, ['linux']);
      expect(settings.packageDisabledReason, isNull, reason: 'Package Project is enabled (doctor: ${settings.hostTargets?.error})');
      // The tap used to go to the button wherever it was laid out,
      // with no check that it started anything; when it did not, the scenario
      // waited out its 12-minute budget with an empty packaging log.
      await tester.ensureVisible(find.byKey(const ValueKey('project_settings_package')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('project_settings_package')));
      await tester.pump();
      expect(await _recordUntil(tester, rec, () => settings.packaging.isRunning || settings.packaging.result != null,
              progress: () => 0, budget: const Duration(seconds: 10)),
          isTrue,
          reason: 'the tap started Package Project');
      expect(await _recordUntil(tester, rec, () => settings.packaging.result != null,
              progress: () => settings.packagingLog.length, budget: const Duration(minutes: 12)),
          isTrue);
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 600));
      final log = settings.packagingLog.map((l) => '[${l.source}] ${l.message}').join('\n');
      expect(settings.packaging.statuses['linux'], PackageTargetStatus.ok, reason: log);

      // The bundle carries the icon, the runner sets it, the file manager shows it.
      final package = '$projDir/build/package/linux';
      final bundleIcon = img.decodePng(File('$package/data/app_icon.png').readAsBytesSync())!;
      expect((bundleIcon.width, bundleIcon.height), (512, 512));
      final texture = img.decodeImage(iconSource.readAsBytesSync())!;
      final a = bundleIcon.getPixel(256, 256), b = texture.getPixel(texture.width ~/ 2, texture.height ~/ 2);
      expect((a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs(), lessThan(60), reason: 'the custom icon\'s pixels');
      expect(File('$projDir/linux/runner/my_application.cc').readAsStringSync(), contains('gtk_window_set_icon_list'));
      final desktop = File('$package/com.example.$projectName.desktop').readAsStringSync();
      expect(desktop, contains('Icon=$package/data/app_icon.png'));
      final gio = await tester.runAsync(() => Process.run('gio', ['info', '-a', 'metadata::custom-icon', '$package/$projectName']));
      expect(gio!.stdout as String, contains('metadata::custom-icon: ${Uri.file('$package/data/app_icon.png')}'));
      expect(log, contains('App icon from branding/app_icon.webp'));

      // Launch the packaged game briefly under XWayland and read the window
      // icon back from the X server (_NET_WM_ICON, what the WM shows).
      final windowIcon = await tester.runAsync(() async {
        game = await Process.start('$package/$projectName', const [], workingDirectory: package, environment: {'GDK_BACKEND': 'x11'});
        String? window;
        for (var i = 0; i < 120 && window == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          window = await _windowOf(game!.pid);
        }
        expect(window, isNotNull, reason: 'the packaged game opened no X11 window');
        return _windowIcon(window!);
      });
      expect(windowIcon, isNotNull, reason: 'the window has a _NET_WM_ICON');
      final c = windowIcon!.getPixel(windowIcon.width ~/ 2, windowIcon.height ~/ 2);
      final d = bundleIcon.getPixel(256, 256);
      expect((c.r - d.r).abs() + (c.g - d.g).abs() + (c.b - d.b).abs(), lessThan(60), reason: 'the window icon is the project icon');
      // Evidence: the window icon as read from the X server, next to the bundle's file.
      final sheet = img.Image(width: 1100, height: 600, numChannels: 4);
      img.fill(sheet, color: img.ColorRgba8(16, 16, 20, 255));
      img.drawString(sheet, 'Packaged $projectName: window icon read back from the X server (_NET_WM_ICON)', font: img.arial24, x: 24, y: 20);
      img.compositeImage(sheet, img.copyResize(windowIcon, width: 480, height: 480), dstX: 24, dstY: 80);
      img.compositeImage(sheet, img.copyResize(bundleIcon, width: 480, height: 480), dstX: 596, dstY: 80);
      img.drawString(sheet, '_NET_WM_ICON ${windowIcon.width}x${windowIcon.height}', font: img.arial14, x: 24, y: 570);
      img.drawString(sheet, 'bundle data/app_icon.png 512x512 (gio metadata::custom-icon set)', font: img.arial14, x: 596, y: 570);
      SmokeArtifacts.saveScreenshot('$name (window icon)', Uint8List.fromList(img.encodePng(sheet)), usedAssets: usedAssets);

      await tester.ensureVisible(find.byKey(const ValueKey('project_settings_package_log')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 500));
      // Back through the Linux target's log: the icon lines, the build, the .desktop and gio lines.
      final logCenter = tester.getCenter(find.byKey(const ValueKey('project_settings_package_log')));
      final wheel = TestPointer(32, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(wheel.hover(logCenter));
      for (final dy in [-60.0, 60.0]) {
        for (var i = 0; i < 24; i++) {
          await tester.sendEventToBinding(wheel.scroll(Offset(0, dy)));
          await rec.hold(const Duration(milliseconds: 66));
        }
      }
      await rec.hold(const Duration(milliseconds: 800));
      SmokeArtifacts.saveScreenshot(name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
          usedAssets: usedAssets);
      rec.save(name, usedAssets: usedAssets);
    } finally {
      game?.kill();
      await tester.runAsync(() async => game?.exitCode.timeout(const Duration(seconds: 10), onTimeout: () => -1));
      vm?.dispose();
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 25)));

  testWidgets('Project Settings Smoke: the web loading screen style, previewed and saved', (tester) async {
    const name = 'project_settings: web loading screen style';
    final usedAssets = [_iconGlb];
    final tempProjectsDir = Directory.systemTemp.createTempSync('wls_smoke_web_loading_');
    EditorViewModel? vm;
    try {
      final pDir = Directory('${tempProjectsDir.path}/WlsSmoke')..createSync(recursive: true);
      await AssetRepository().createAsset(projectPath: pDir.path, subFolder: 'levels', fileName: 'L_Main.lmas', type: AssetType.level);
      // The web platform folder `flutter create` leaves: Apply regenerates its loading screen.
      Directory('${pDir.path}/web/icons').createSync(recursive: true);
      File('${pDir.path}/web/index.html').writeAsStringSync('<!DOCTYPE html><html><head><base href="\$FLUTTER_BASE_HREF"></head>'
          '<body><script src="flutter_bootstrap.js" async></script></body></html>');
      const project = LuminaProject(projectName: 'WlsSmoke', activeLevel: 'contents/levels/L_Main.lmas');
      final manifest = File('${pDir.path}/WlsSmoke.lmproject')..writeAsStringSync(jsonEncode(project.toMap()));
      // A real test asset's embedded texture becomes the custom logo.
      final logoSource = File('${tempProjectsDir.path}/big_button.webp')..writeAsBytesSync(_glbImageBytes(_iconGlb));

      vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path, enableTimers: false, autoInitAssets: false);
      final editor = vm;
      await tester.runAsync(() => editor.ensureDefaultLevelAssets());
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // Edit → Project Settings → Packaging & Target.
      await tester.tap(find.text('Edit').first);
      await tester.pump(const Duration(milliseconds: 300));
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(find.text('Project Settings...').last);
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      final settings = _findVm(tester);
      await tester.tap(find.byKey(const ValueKey('project_settings_nav_${ProjectSettingsCategory.packaging}')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('project_settings_web_loading')), findsNothing, reason: 'no web target yet');

      // Tick Web: the Web Loading Style section appears.
      await tester.ensureVisible(find.byKey(const ValueKey('project_settings_target_web')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('project_settings_target_web')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('project_settings_web_loading')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('project_settings_web_loading_title')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 600));
      await rec.typeText(find.byKey(const ValueKey('project_settings_web_loading_title')), 'Big Button Panic');
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 500));
      await rec.typeText(find.byKey(const ValueKey('project_settings_web_loading_subtitle')), 'Press to start');
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 500));
      settings.setWebLoadingBackground('#0F172A');
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('project_settings_web_loading_gradient_toggle')));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 700));
      await tester.runAsync(() => settings.chooseWebLoadingLogo(logoSource.path));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 800));
      await tester.ensureVisible(find.byKey(const ValueKey('project_settings_web_loading_preview')));
      await tester.pump();
      // The preview in each progress style, scrubbed through the phases.
      for (final style in ProjectWebLoadingStyle.progressStyles) {
        settings.setWebLoadingProgressStyle(style);
        await tester.pump();
        await rec.hold(const Duration(milliseconds: 1500));
      }
      settings.setWebLoadingProgressStyle('bar');
      await tester.pump();
      final slider = find.descendant(
          of: find.byKey(const ValueKey('project_settings_web_loading_preview_progress')), matching: find.byType(Slider));
      for (final dx in [-120.0, 90.0, 90.0]) {
        await tester.drag(slider, Offset(dx, 0));
        await tester.pump();
        await rec.hold(const Duration(milliseconds: 800));
      }
      expect(find.descendant(of: find.byKey(const ValueKey('project_settings_web_loading_preview')), matching: find.text('Big Button Panic')),
          findsOneWidget);
      SmokeArtifacts.saveScreenshot('$name 01 section and preview',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)), usedAssets: usedAssets);

      // Apply & Save: the manifest holds the style, web/ holds the page.
      expect(settings.validationErrors.values.expand((e) => e), isEmpty);
      await tester.ensureVisible(find.byKey(const ValueKey('project_settings_apply')));
      await tester.tap(find.byKey(const ValueKey('project_settings_apply')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await tester.pump();
      await rec.hold(const Duration(milliseconds: 1200));
      final saved = LuminaProject.fromMap(jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>);
      expect(saved.packaging.targets, contains('web'));
      expect(saved.packaging.webLoadingStyle.title, 'Big Button Panic');
      expect(saved.packaging.webLoadingStyle.logo, 'branding/web_loading_logo.webp');
      final index = File('${pDir.path}/web/index.html').readAsStringSync();
      expect(index, contains('<title>Big Button Panic</title>'));
      expect(File('${pDir.path}/web/loading_logo.webp').existsSync(), isTrue);
      expect(File('${pDir.path}/web/loading.js').existsSync(), isTrue);
      SmokeArtifacts.saveScreenshot(name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
          usedAssets: usedAssets);
      rec.save(name, usedAssets: usedAssets);
    } finally {
      vm?.dispose();
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/// Pumps while [condition] is false, recording a time-lapse frame whenever
/// [progress] moves (a build log gaining lines) or at least every 0.6 s.
Future<bool> _recordUntil(WidgetTester tester, SmokeRecorder rec, bool Function() condition,
    {required int Function() progress, Duration budget = const Duration(minutes: 5)}) async {
  final sw = Stopwatch()..start();
  var last = -1;
  var quiet = 0;
  while (sw.elapsed < budget && !condition()) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    final now = progress();
    if (now != last || ++quiet >= 3) {
      last = now;
      quiet = 0;
      await rec.captureIfChanged();
    }
  }
  return condition();
}

/// The test-assets GLB whose embedded texture becomes the custom icon.
final String _iconGlb = '${Directory.current.parent.path}/test-assets/Props/Big_button/big_button.glb';

/// The first image embedded in [glb], as its own file bytes (WebP here).
Uint8List _glbImageBytes(String glb) {
  final bytes = File(glb).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  final jsonLength = data.getUint32(12, Endian.little);
  final json = jsonDecode(utf8.decode(bytes.sublist(20, 20 + jsonLength))) as Map<String, dynamic>;
  final view = (json['bufferViews'] as List)[((json['images'] as List).first as Map)['bufferView'] as int] as Map;
  final start = 20 + jsonLength + 8 + ((view['byteOffset'] as num?)?.toInt() ?? 0);
  return Uint8List.sublistView(bytes, start, start + (view['byteLength'] as num).toInt());
}

/// The X11 window of process [pid], from the window manager's client list.
Future<String?> _windowOf(int pid) async {
  final list = await Process.run('xprop', ['-root', '_NET_CLIENT_LIST']);
  for (final id in RegExp(r'0x[0-9a-f]+').allMatches(list.stdout as String).map((m) => m.group(0)!)) {
    final p = await Process.run('xprop', ['-id', id, '_NET_WM_PID']);
    if ((p.stdout as String).trim().endsWith('= $pid')) return id;
  }
  return null;
}

/// `_NET_WM_ICON` of [window] as the window manager reads it: the largest
/// image in the property.
Future<img.Image?> _windowIcon(String window) async {
  // xprop reads at most 500000 bytes of a property by default; a 512 px
  // icon is 1 MB of 32-bit values.
  final r = await Process.run('xprop', ['-len', '67108864', '-id', window, '-notype', '-f', '_NET_WM_ICON', '32c', r'=$0+', '_NET_WM_ICON']);
  final numbers = RegExp(r'\d+').allMatches((r.stdout as String).split('=').skip(1).join('=')).map((m) => int.parse(m.group(0)!)).toList();
  img.Image? best;
  var i = 0;
  while (i + 2 <= numbers.length) {
    final w = numbers[i], h = numbers[i + 1];
    if (w <= 0 || h <= 0 || i + 2 + w * h > numbers.length) break;
    final icon = img.Image(width: w, height: h, numChannels: 4);
    for (var k = 0; k < w * h; k++) {
      final argb = numbers[i + 2 + k];
      icon.setPixelRgba(k % w, k ~/ w, (argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF, (argb >> 24) & 0xFF);
    }
    if (best == null || w > best.width) best = icon;
    i += 2 + w * h;
  }
  return best;
}

ProjectSettingsViewModel _findVm(WidgetTester tester) {
  final state = tester.state(find.byType(ProjectSettingsSubEditor));
  // ignore: invalid_use_of_protected_member
  final dynamic s = state;
  return s.viewModelForTest as ProjectSettingsViewModel;
}
