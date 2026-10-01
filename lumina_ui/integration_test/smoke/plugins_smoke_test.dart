import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart' show ZipDecoder;
import 'package:flutter/material.dart' hide ThemeData, Colors, Icon, Icons, DropdownMenu, TextField, Switch, CircularProgressIndicator, Column, Row, Stack, Card, SelectableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart' show ProjectSettingsViewModel;
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart' show ProjectSettingsSubEditor;
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_plugin_pcg/lumina_plugin_pcg.dart';
import 'package:lumina_plugin_miniai/lumina_plugin_miniai.dart';
import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/features/launcher/services/project_editor_resolver.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/editor_build_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/editor_build_splash.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/create_project_view_model.dart';

import '../../test/helpers/desktop_window.dart';
import '../../test/helpers/mcp_test_client.dart';
import '../../test/helpers/scaffold_game_project.dart' show offlineScaffoldRunner;
import 'package:lumina/data/services/workspace_paths.dart';

/// The editor viewport runs tickers for as long as it is on screen (fly
/// camera, procedural sky), so `pumpAndSettle` never settles with it mounted.
/// Pumps a bounded run of frames on the live clock instead.
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

/// A top-level menu of the menu bar ("Plugins" is also the
/// Plugin Manager tab's title).
Finder barItem(String title) => find.descendant(of: find.byType(Menubar), matching: find.text(title));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Plugins Smoke Scenario: Open Plugin Manager via Plugins Menu', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('plugins_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeProject');
    pDir.createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);

    try {
      final p = LuminaProject(
        projectName: 'SmokeProject',
        activeLevel: 'contents/levels/L_Main.lmas',
        settings: EngineScalabilitySettings(targetFps: 60),
      );
      final manifestFile = File('${pDir.path}/SmokeProject.lmproject');
      manifestFile.writeAsStringSync('{}');

      // Seed some plugins
      final projectPluginsDir = Directory('${pDir.path}/plugins')..createSync(recursive: true);
      File('${projectPluginsDir.path}/ocean_tools/ocean_tools.lmplugin')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode({
          'name': 'ocean_tools',
          'friendly_name': 'Ocean Tools',
          'version': '1.0.0',
          'description': 'Advanced water system',
          'category': 'Rendering',
          'modules': [{'name': 'O', 'type': 'runtime', 'entry_library': 'o.dart', 'registration_class': 'O'}]
        }));
      File('${projectPluginsDir.path}/terrain_tools/terrain_tools.lmplugin')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode({
          'name': 'terrain_tools',
          'friendly_name': 'Terrain Tools',
          'version': '0.3.0',
          'description': 'Erosion brushes for landscapes',
          'category': 'World',
          'modules': [{'name': 'T', 'type': 'editor', 'entry_library': 't.dart', 'registration_class': 'T'}]
        }));

      // The view model takes the projects folder and opens <folder>/<name>:
      // pDir is the project itself, where the plugin was seeded.
      final vm = EditorViewModel(initialProject: p, projectDirPath: tempProjectsDir.path);
      expect(vm.projectDirPath, pDir.path);
      
      final repaintBoundaryKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintBoundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: MainEditorView(viewModel: vm),
          ),
        ),
      );
      await settle(tester);
      final rec = SmokeRecorder(tester, boundary: find.byKey(repaintBoundaryKey));
      
      // Wait for plugins to be discovered
      await Future.delayed(const Duration(seconds: 1));
      await rec.hold(const Duration(seconds: 1));

      // Ensure the editor loads
      // The editor chrome no longer prints the project name; its menu bar is
      // the sign the shell loaded.
      expect(find.byType(MainEditorView), findsOneWidget);
      expect(barItem('Plugins'), findsOneWidget);

      // Open Plugins -> Plugin Manager...
      await tester.tap(barItem('Plugins'));
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      expect(find.text('Plugin Manager...'), findsOneWidget, reason: 'the Plugins menu offers the Plugin Manager');
      await tester.tap(find.text('Plugin Manager...'));
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 1500));
      
      // Verify plugin manager is open
      expect(find.text('ALL PLUGINS'), findsOneWidget);
      expect(find.text('Ocean Tools'), findsOneWidget);
      expect(find.text('Terrain Tools'), findsOneWidget);
      // The Plugins tab is a document tab: the level viewport's toolbar
      // (transform, play, view modes) belongs to the level tab only.
      expect(find.byKey(const ValueKey('toolbar_play')), findsNothing);
      expect(find.byKey(const ValueKey('toolbar_blueprints')), findsNothing);

      // Select plugin
      await tester.tap(find.text('Ocean Tools').last);
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 1500));

      // The other plugin's details, then back.
      await tester.tap(find.text('Terrain Tools').last);
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Ocean Tools').first);
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 800));

      // Search narrows the list, clearing brings everything back.
      final search = find.byWidgetPredicate((w) =>
          w is TextField && w.placeholder is Text && (w.placeholder as Text).data == 'Search plugins...');
      await tester.tap(search);
      await rec.typeText(search, 'ocean', perCharacter: const Duration(milliseconds: 150));
      await settle(tester);
      expect(find.text('Ocean Tools'), findsWidgets);
      expect(find.text('Terrain Tools'), findsNothing, reason: 'the search filters the list');
      await rec.hold(const Duration(seconds: 1));
      await tester.enterText(search, '');
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));

      // Ocean Tools' category in the sidebar, then back to all plugins.
      await tester.tap(find.text('Rendering').first);
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('ALL PLUGINS').first);
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));

      // BUILT-IN: the plugins the engine workspace depends on (the plugins
      // repository's packages, resolved by pub), not an engine folder.
      final builtIns = [for (final d in LuminaWorkspace.pluginPackageDirs(LuminaEditorHost.engineRoot)) d.replaceAll(r'\', '/').split('/').last];
      expect(builtIns, containsAll(['lumina_plugin_pcg', 'lumina_plugin_miniai']), reason: 'pub get resolved the built-in plugins');
      await tester.tap(find.text('All Built-in'));
      await settle(tester);
      expect(find.text('Procedural Content Generation'), findsWidgets);
      expect(find.text('MiniAI'), findsWidgets);
      expect(find.text('Terrain Tools'), findsNothing, reason: 'a project plugin is not built-in');
      expect(
          vm.pluginRegistry.entries.where((e) => e.descriptor.origin == PluginOrigin.engine).map((e) => e.descriptor.name),
          containsAll(['lumina_plugin_pcg', 'lumina_plugin_miniai']));
      await rec.hold(const Duration(milliseconds: 1500));
      SmokeArtifacts.saveScreenshot(
        'Plugins Smoke Scenario: the built-in plugins',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(repaintBoundaryKey)),
      );
      await tester.tap(find.text('ALL PLUGINS').first);
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));

      // Capture screenshot
      final pngEditor = await SmokeArtifacts.captureIntegrationPng(
        binding,
        tester,
        boundary: find.byKey(repaintBoundaryKey),
      );
      SmokeArtifacts.saveScreenshot(
        'Plugins Smoke Scenario: Plugin Manager executed',
        pngEditor,
      );
      rec.save('Plugins Smoke Scenario: Open Plugin Manager via Plugins Menu');

      expect(pngEditor.length, greaterThan(0));
    } finally {
      if (tempProjectsDir.existsSync()) {
        tempProjectsDir.deleteSync(recursive: true);
      }
    }
  });

  testWidgets('Plugins Smoke Scenario: enable a built-in plugin', (tester) async {
    const name = 'Plugins Smoke Scenario: enable a built-in plugin';
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final temp = Directory.systemTemp.createTempSync('bi_');
    final pDir = Directory('${temp.path}/BuiltInGame')..createSync(recursive: true);
    try {
      const project = LuminaProject(projectName: 'BuiltInGame', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      final manifest = File('${pDir.path}/BuiltInGame.lmproject')..writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: temp.path, enableTimers: false);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String label) async =>
          SmokeArtifacts.saveScreenshot('$name: $label', await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
      await tester.runAsync(() => vm.pluginsScanned);
      await rec.hold(const Duration(seconds: 1));

      // Plugins ▸ Plugin Manager ▸ BUILT-IN ▸ All Built-in ▸ PCG.
      await tester.tap(barItem('Plugins'));
      await settle(tester);
      await tester.tap(find.text('Plugin Manager...'));
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('All Built-in'));
      await settle(tester);
      await rec.hold(const Duration(seconds: 2));
      final pcg = vm.pluginRegistry.entries.singleWhere((e) => e.descriptor.name == 'lumina_plugin_pcg');
      expect(pcg.descriptor.origin, PluginOrigin.engine);
      expect(pcg.enabled, isFalse);
      await tester.tap(find.text('Procedural Content Generation').first);
      await settle(tester);
      expect(find.byKey(const ValueKey('plugin_built_in_note')), findsOneWidget, reason: 'the details say how a built-in is managed');
      await rec.hold(const Duration(seconds: 2));
      await shot('PCG built-in, disabled');

      // Its switch enables it for this project.
      final pcgSwitch = find.descendant(
        of: find.ancestor(of: find.text('Procedural Content Generation').first, matching: find.byType(Card)),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(pcgSwitch).value, isFalse);
      await tester.tap(pcgSwitch);
      final hostPubspec = File('${pDir.path}/.lumina/editor/pubspec.yaml');
      for (var i = 0; i < 100 && find.text('Restart required').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await settle(tester);
      expect(find.text('Built-in Plugin'), findsNothing, reason: 'a built-in is not refused');
      expect(tester.widget<Switch>(pcgSwitch).value, isTrue);
      expect(find.text('Restart required'), findsOneWidget, reason: 'PCG waits for the project editor rebuild');
      expect(find.text("Plugin changes require rebuilding this project's editor"), findsOneWidget);
      expect((jsonDecode(manifest.readAsStringSync()) as Map)['enabled_plugins'], ['lumina_plugin_pcg']);
      expect(hostPubspec.readAsStringSync(), contains('lumina_plugin_pcg:'), reason: "the project's editor host depends on PCG");
      await rec.hold(const Duration(seconds: 4));
      await shot('PCG enabled, restart required');
      rec.save(name);
      vm.dispose();
    } finally {
      await tester.runAsync(() async {
        for (var i = 0; i < 20; i++) {
          try {
            if (temp.existsSync()) temp.deleteSync(recursive: true);
            break;
          } on FileSystemException {
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
        }
      });
    }
  });

  testWidgets('Plugins Smoke Scenario: PCG example plugin generates barrels on camera', (tester) async {
    const barrels = ['Props/Barrels/fuel_barrel_red.glb', 'Props/Barrels/dented_barrel.glb', 'Props/Barrels/empty_barrel.glb'];
    final tempProjectsDir = Directory.systemTemp.createTempSync('plugins_pcg_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/SmokePcg')..createSync(recursive: true);
    try {
      // The plugin installed into the project's plugins root (README:
      // symlink for development), discovered from its manifest.
      final pluginsRoot = Directory('${pDir.path}/plugins')..createSync(recursive: true);
      Link('${pluginsRoot.path}/lumina_plugin_pcg').createSync(Directory(LuminaWorkspace.package('lumina_plugin_pcg')).absolute.path);

      // A project is its .lmproject on disk: the plugin registry reads the
      // enabled plugins from it and lists nothing without one.
      const project = LuminaProject(projectName: 'SmokePcg', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/SmokePcg.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(
        initialProject: project,
        projectDirPath: tempProjectsDir.path,
        enableTimers: false,
      );
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      for (final b in barrels) {
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$b'));
      }
      vm.refreshAssets();
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      expect(vm.pluginRegistry.entries.any((e) => e.descriptor.name == 'lumina_plugin_pcg'), isTrue, reason: 'discovered from <project>/plugins');

      // What the generated registrar does at boot once the plugin is enabled —
      // unless this editor build already has it enabled, in which case the
      // view model registered that instance at construction.
      final booted = LuminaEditorHost.plugins.whereType<LuminaPluginPcgPlugin>().firstOrNull;
      final plugin = booted ?? LuminaPluginPcgPlugin();
      if (booted == null) {
        vm.extensionRegistry.beginRegistration(plugin.pluginName);
        plugin.register(vm.extensionRegistry);
        vm.extensionRegistry.endRegistration();
      }
      EditorCommand command(String id) => vm.extensionRegistry.allMenuCommands.map((e) => e.value).firstWhere((c) => c.id == id);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // Plugins → PCG → New PCG Graph (the plugin's `Plugins/PCG/...`
      // items), on video: the graph editor tab opens with the imported
      // barrels in its spawner.
      await tester.tap(barItem('Plugins'));
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 800));
      expect(find.text('PCG'), findsWidgets, reason: 'the plugin\'s PCG submenu is in the Plugins menu');
      await tester.tap(find.text('PCG').last);
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 800));
      expect(find.text('New PCG Graph'), findsWidgets, reason: 'the plugin\'s items are in its submenu');
      await tester.tap(find.text('New PCG Graph').last);
      await settle(tester, frames: 30);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await settle(tester);
      expect(vm.openTabs[vm.activeTabIndex].title, 'PCG_Graph_1');
      expect(find.byKey(const Key('pcg_graph_save_button')), findsOneWidget, reason: 'the plugin asset editor is the tab');
      // The spawner is the last card of the editor's node list (a ListView,
      // which builds only what is on screen): scroll down to it, on video.
      await tester.scrollUntilVisible(find.byKey(const Key('pcg_mesh_spawner_0')), 120,
          scrollable: find.descendant(of: find.byType(PcgGraphEditor), matching: find.byType(Scrollable)).first);
      await settle(tester);
      expect(find.byKey(const Key('pcg_mesh_spawner_0')), findsOneWidget);
      await rec.hold(const Duration(seconds: 2));

      // Back to the level; place a volume through the plugin command and
      // generate through the Details section's own button.
      vm.selectTab(0);
      await settle(tester);
      command('tools.lumina_plugin_pcg.placeVolume').execute(null);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await settle(tester);
      final volume = vm.actors.firstWhere((a) => a.type == PcgTypes.volumeActor);
      expect(vm.selectedActorIds, [volume.id]);
      expect(find.text('PCG'), findsWidgets, reason: 'the plugin Details section for PcgVolume');
      await rec.hold(const Duration(seconds: 1));

      // The Details panel sits under the Outliner and is a
      // lazy list: bring the plugin section's controls into view first.
      Future<void> reveal(String key) async {
        await tester.scrollUntilVisible(find.byKey(Key(key)), 60,
            scrollable: find.descendant(of: find.byType(DetailsWidget), matching: find.byType(Scrollable)).first);
        await settle(tester);
      }

      await reveal('pcg_generate_button');
      await tester.tap(find.byKey(const Key('pcg_generate_button')));
      await settle(tester, frames: 40);
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await settle(tester, frames: 20);
      final generated = vm.actors.where((a) => a.parentId == volume.id).toList();
      expect(generated, isNotEmpty);
      expect(generated.every((a) => a.meshData != null), isTrue);
      await reveal('pcg_instance_count');
      expect((tester.widget(find.byKey(const Key('pcg_instance_count'))) as Text).data, '${generated.length}');
      vm.frameLevelBounds();
      await settle(tester, frames: 20);
      await rec.hold(const Duration(seconds: 3));

      // A new seed moves everything; Plugins → PCG → Generate All keeps it in sync.
      await reveal('pcg_randomize_seed');
      await tester.tap(find.byKey(const Key('pcg_randomize_seed')));
      await settle(tester);
      final seedBefore = generated.map((a) => a.location.join(',')).toList();
      await tester.tap(barItem('Plugins'));
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(find.text('PCG').last);
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(find.text('Generate All').last);
      await settle(tester, frames: 40);
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await settle(tester, frames: 20);
      final regenerated = vm.actors.where((a) => a.parentId == volume.id).toList();
      expect(regenerated.map((a) => a.location.join(',')).toList(), isNot(seedBefore));
      await rec.hold(const Duration(seconds: 2));

      // Cleanup empties the volume, Generate fills it again for the still.
      await reveal('pcg_cleanup_button');
      await tester.tap(find.byKey(const Key('pcg_cleanup_button')));
      await settle(tester, frames: 20);
      expect(vm.actors.where((a) => a.parentId == volume.id), isEmpty);
      await rec.hold(const Duration(seconds: 1));
      await reveal('pcg_generate_button');
      await tester.tap(find.byKey(const Key('pcg_generate_button')));
      await settle(tester, frames: 40);
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await settle(tester, frames: 20);
      expect(vm.actors.where((a) => a.parentId == volume.id), isNotEmpty);
      await rec.hold(const Duration(seconds: 2));

      // The level on disk carries the instances as plain StaticMesh actors.
      await tester.runAsync(() => vm.saveLevelAndGenerateCode());
      final json = jsonDecode(File('${pDir.path}/contents/levels/L_Main.lmas').readAsStringSync()) as Map;
      final actors = ((json['metadata'] as Map)['actors'] as List).cast<Map>();
      expect(actors.where((a) => a['parentId'] == volume.id && a['type'] == 'StaticMesh'), isNotEmpty);

      final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('Plugins Smoke Scenario: PCG example plugin generates barrels on camera', png, usedAssets: barrels);
      rec.save('Plugins Smoke Scenario: PCG example plugin generates barrels on camera', usedAssets: barrels);
      expect(png.length, greaterThan(0));
    } finally {
      if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
    }
  });

  // A plugin's console commands and importers reach the user —
  // `pcg.generate` typed into the Output Log's command line fills a PCG
  // Volume with barrels, and a `.pcggraph` goes through the plugin importer
  // into a PCG Graph asset.
  testWidgets('Plugins Smoke Scenario: a plugin console command and importer (Output Log, Import)', (tester) async {
    const name = 'Plugins Smoke Scenario: a plugin console command and importer (Output Log, Import)';
    const barrels = ['Props/Barrels/fuel_barrel_red.glb', 'Props/Barrels/dented_barrel.glb'];
    final tempProjectsDir = Directory.systemTemp.createTempSync('plugins_bugs101_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeConsole')..createSync(recursive: true);
    try {
      const project = LuminaProject(projectName: 'SmokeConsole', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/SmokeConsole.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      for (final b in barrels) {
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$b'));
      }
      vm.refreshAssets();
      if (LuminaEditorHost.plugins.whereType<LuminaPluginPcgPlugin>().isEmpty) vm.extensionRegistry.registerPlugin(LuminaPluginPcgPlugin());
      EditorCommand command(String id) => vm.extensionRegistry.allMenuCommands.map((e) => e.value).firstWhere((c) => c.id == id);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String label) async {
        SmokeArtifacts.saveScreenshot('$name: $label',
            await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
            usedAssets: barrels);
        await rec.hold(const Duration(seconds: 1));
      }

      // A .pcggraph through the plugin importer, into the selected folder:
      // the Content Browser lists the new PCG Graph asset.
      final source = File('${tempProjectsDir.path}/Barrel_Field.pcggraph')
        ..writeAsStringSync(PcgGraph.starter(name: 'Barrel_Field', meshes: [
          for (final b in vm.realAssets.where((a) => a.type == AssetType.filamesh && a.fileName.contains('barrel')))
            PcgMeshEntry(path: b.relativePath, weight: 1),
        ]).toJsonString());
      expect(vm.importExtensions, contains('pcggraph'));
      vm.selectedFolder = 'contents';
      final results = await tester.runAsync(() => vm.importWithPluginImporters([source.path]));
      expect(results!.single.success, isTrue, reason: '${results.single.error}');
      await settle(tester, frames: 30);
      expect(File('${pDir.path}/contents/Barrel_Field.lmas').existsSync(), isTrue);
      expect(vm.realAssets.any((a) => a.fileName == 'Barrel_Field.lmas'), isTrue, reason: 'the Content Browser lists the imported graph');
      await rec.hold(const Duration(seconds: 2));
      await shot('a .pcggraph imported by the plugin');

      // A PCG Volume through the plugin's command: it takes the imported
      // graph, and stays empty until generated.
      command('tools.lumina_plugin_pcg.placeVolume').execute(null);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await settle(tester);
      final volume = vm.actors.firstWhere((a) => a.type == PcgTypes.volumeActor);
      expect(vm.actors.where((a) => a.parentId == volume.id), isEmpty);
      await rec.hold(const Duration(seconds: 1));

      // Output Log ▸ command line: help, then pcg.generate.
      await tester.tap(find.byKey(const ValueKey('bottom_tab_1')));
      await settle(tester);
      final line = find.byKey(const ValueKey('output_log_command'));
      await tester.tap(line);
      await rec.typeText(line, 'help', perCharacter: const Duration(milliseconds: 90));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester, frames: 20);
      expect(vm.logger.logs.last.message, contains('pcg.generate'));
      await rec.hold(const Duration(seconds: 2));
      await tester.tap(line);
      await rec.typeText(line, 'pcg.generate', perCharacter: const Duration(milliseconds: 90));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester, frames: 40);
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await settle(tester, frames: 20);
      final generated = vm.actors.where((a) => a.parentId == volume.id).toList();
      expect(generated, isNotEmpty, reason: 'pcg.generate from the Output Log filled the volume');
      expect(generated.every((a) => a.meshData != null), isTrue);
      vm.frameLevelBounds();
      await settle(tester, frames: 20);
      await rec.hold(const Duration(seconds: 3));
      await shot('pcg.generate from the Output Log');
      rec.save(name, usedAssets: barrels);
    } finally {
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  // Tools shows built-in tools only; the Plugins menu holds the
  // Plugin Manager, New Plugin… and the PCG submenu, whose command places a
  // real volume in the level.
  testWidgets('plugins menu', (tester) async {
    const barrel = 'Props/Barrels/fuel_barrel_red.glb';
    const name = 'plugins menu';
    final tempProjectsDir = Directory.systemTemp.createTempSync('plugins_menu_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/MenuSmoke')..createSync(recursive: true);
    try {
      const project = LuminaProject(projectName: 'MenuSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/MenuSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrel'));
      vm.refreshAssets();
      final barrelAsset = vm.realAssets.firstWhere((a) => a.fileName == 'fuel_barrel_red.lmas' && a.type == AssetType.filamesh);
      await tester.runAsync(() => vm.spawnActorFromAsset(barrelAsset, location: const [0.0, 0.0, 0.0]));

      // lumina_plugin_pcg is compiled into a project editor (its host's
      // registrar); register it when this build does not have it.
      final booted = LuminaEditorHost.plugins.whereType<LuminaPluginPcgPlugin>().firstOrNull;
      if (booted == null) vm.extensionRegistry.registerPlugin(LuminaPluginPcgPlugin());

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      vm.frameLevelBounds();
      await settle(tester);
      await rec.hold(const Duration(seconds: 2));

      // The menu bar order, and the title bar still has room to drag.
      final titles = [
        for (final item in tester.widget<Menubar>(find.byType(Menubar)).children) ((item as MenuButton).child as Text).data,
      ];
      expect(titles, ['File', 'Edit', 'View', 'Build', 'Debug', 'Tools', 'Plugins', 'Window', 'Help']);
      expect(tester.getSize(find.byKey(const ValueKey('window_title_drag_area'))).width, greaterThan(100),
          reason: 'the Plugins menu leaves the title bar a drag region');

      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png, usedAssets: const [barrel]);
      }

      // 1. Tools: built-in tools, no plugin entries.
      await tester.tap(barItem('Tools'));
      await settle(tester);
      expect(find.text('AI Agent Access (MCP)...'), findsOneWidget);
      expect(find.text('PCG'), findsNothing);
      expect(find.text('New Plugin...'), findsNothing);
      await rec.hold(const Duration(seconds: 2));
      await shot('tools');
      await tester.tap(barItem('Tools'));
      await settle(tester);

      // 2. Plugins ▸ PCG.
      await tester.tap(barItem('Plugins'));
      await settle(tester);
      expect(find.text('Plugin Manager...'), findsOneWidget);
      expect(find.text('New Plugin...'), findsOneWidget);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('PCG'));
      await settle(tester);
      for (final label in ['New PCG Graph', 'Place PCG Volume', 'Generate All', 'Cleanup All']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await rec.hold(const Duration(seconds: 2));
      await shot('plugins pcg');

      // 3. Plugins ▸ PCG ▸ Place PCG Volume → a volume actor in the Outliner.
      final before = vm.actors.where((a) => a.type == PcgTypes.volumeActor).length;
      await tester.tap(find.text('Place PCG Volume'));
      await settle(tester, frames: 30);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await settle(tester);
      final volumes = vm.actors.where((a) => a.type == PcgTypes.volumeActor).toList();
      expect(volumes.length, before + 1, reason: 'the menu command placed a PCG Volume');
      expect(find.text(volumes.last.name), findsWidgets, reason: 'the Outliner lists the volume');
      await rec.hold(const Duration(seconds: 3));
      await shot('volume placed');
      rec.save(name, usedAssets: const [barrel]);
    } finally {
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  // A plugin made with Plugins ▸ New Plugin… packs itself for the
  // marketplace with its generated tool/pack_plugin.dart (a real `dart`
  // process): the zip holds the plugin and a real mesh, never its build/.
  testWidgets('Plugins Smoke Scenario: pack a plugin for the marketplace', (tester) async {
    const name = 'Plugins Smoke Scenario: pack a plugin for the marketplace';
    const barrel = 'Props/Barrels/fuel_barrel_red.glb';
    final tempProjectsDir = Directory.systemTemp.createTempSync('plugins_pack_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/PackSmoke')..createSync(recursive: true);
    try {
      const project = LuminaProject(projectName: 'PackSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/PackSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrel'));
      vm.refreshAssets();
      final barrelAsset = vm.realAssets.firstWhere((a) => a.fileName == 'fuel_barrel_red.lmas' && a.type == AssetType.filamesh);
      await tester.runAsync(() => vm.spawnActorFromAsset(barrelAsset, location: const [0.0, 0.0, 0.0]));

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      vm.frameLevelBounds();
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      Future<void> shot(String label) async {
        SmokeArtifacts.saveScreenshot('$name: $label',
            await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
            usedAssets: const [barrel]);
        await rec.hold(const Duration(seconds: 1));
      }

      // Plugins ▸ New Plugin… ▸ Content-only "barrel_pack".
      await tester.tap(barItem('Plugins'));
      await settle(tester);
      await tester.tap(find.text('New Plugin...'));
      await settle(tester, frames: 30);
      expect(find.text('New Plugin Wizard'), findsOneWidget);
      await tester.tap(find.text('Content-only'));
      await settle(tester);
      await rec.typeText(find.byKey(const Key('plugin_name_field')), 'barrel_pack', perCharacter: const Duration(milliseconds: 150));
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await shot('the New Plugin wizard');
      await tester.tap(find.text('Create Plugin'));
      for (var i = 0; i < 20 && find.text('Plugin Created').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await settle(tester, frames: 5);
      }
      expect(find.text('Plugin Created'), findsOneWidget);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Later'));
      await settle(tester);
      final pluginDir = Directory('${pDir.path}/plugins/barrel_pack');
      expect(File('${pluginDir.path}/tool/pack_plugin.dart').existsSync(), isTrue, reason: 'the wizard emits the pack script');

      // A real mesh as the plugin's content, and build outputs to leave out.
      File('${SmokeArtifacts.testAssetsDir.path}/$barrel').copySync('${pluginDir.path}/content/meshes/fuel_barrel_red.glb');
      File('${pluginDir.path}/build/cache/fuel_barrel_red.filamesh')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(4096, 1));
      File('${pluginDir.path}/.dart_tool/flutter_build/app.dill')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(64, 2));

      // Run it (a dry run first, then the pack), its output in the Output Log.
      await tester.tap(find.byKey(const ValueKey('bottom_tab_1')));
      await settle(tester, frames: 30);
      Future<void> run(List<String> args) async {
        final res = await tester.runAsync(() => Process.run('dart', ['run', 'tool/pack_plugin.dart', ...args],
            workingDirectory: pluginDir.path, runInShell: Platform.isWindows));
        expect(res!.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');
        for (final line in const LineSplitter().convert('${res.stdout}')) {
          if (line.trim().isNotEmpty) vm.logger.log(line.trim(), source: 'pack_plugin');
        }
        await settle(tester, frames: 30);
        await rec.hold(const Duration(seconds: 2));
      }

      await run(['--dry-run']);
      expect(find.textContaining('nothing written'), findsWidgets);
      expect(Directory('${pluginDir.path}/build/pack').existsSync(), isFalse, reason: 'a dry run writes nothing');
      await run(const []);
      final zip = File('${pluginDir.path}/build/pack/barrel_pack-0.1.0.zip');
      expect(zip.existsSync(), isTrue);
      final entries = [for (final e in ZipDecoder().decodeBytes(zip.readAsBytesSync(), verify: true)) if (e.isFile) e.name];
      expect(entries, containsAll(['barrel_pack/barrel_pack.lmplugin', 'barrel_pack/content/meshes/fuel_barrel_red.glb', 'barrel_pack/tool/pack_plugin.dart']));
      expect(entries.where((e) => e.contains('/build/') || e.contains('.dart_tool')), isEmpty, reason: 'no build outputs in the pack');

      expect(find.textContaining('barrel_pack-0.1.0.zip'), findsWidgets, reason: 'the Output Log shows the summary');
      expect(find.textContaining('build/ (1 file)'), findsWidgets);
      expect(find.textContaining('.dart_tool/ (1 file)'), findsWidgets);
      await rec.hold(const Duration(seconds: 2));
      await shot('the pack summary in the Output Log');
      rec.save(name, usedAssets: const [barrel]);
    } finally {
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  // Plugins ▸ Plugin Manager ▸ Import from Zip, then Import from Folder of
  // the same plugin (Replace): the real PCG plugin, copied to a temp folder
  // and packed there with its own pack_plugin.dart; the checkout is never
  // touched and the user plugin directory is a temp folder.
  testWidgets('Plugins Smoke Scenario: import a plugin from a zip and from a folder', (tester) async {
    const name = 'Plugins Smoke Scenario: import a plugin from a zip and from a folder';
    const barrel = 'Props/Barrels/fuel_barrel_red.glb';
    final pcgSource = LuminaWorkspace.resolvedPackageDir(LuminaWorkspace.root, 'lumina_plugin_pcg');
    if (pcgSource == null || !File('$pcgSource/lumina_plugin_pcg.lmplugin').existsSync()) {
      markTestSkipped('lumina_plugin_pcg is not resolved in this workspace (run pub get)');
      return;
    }
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final temp = Directory.systemTemp.createTempSync('pm_import_');
    final previousUserDir = UserPluginDir.override;
    final userDir = Directory('${temp.path}/user_plugins')..createSync();
    UserPluginDir.override = userDir;
    final previousDataDir = PluginDataDir.override;
    final pluginDataDir = Directory('${temp.path}/plugin_data')..createSync();
    PluginDataDir.override = pluginDataDir;
    final previousConfigDir = LuminaConfigDir.override;
    LuminaConfigDir.override = Directory('${temp.path}/config')..createSync();
    try {
      // A copy of the real plugin package, without its build outputs.
      final source = Directory(pcgSource);
      bool generated(String rel) => rel.startsWith('build/') || rel.startsWith('.dart_tool/') || rel.contains('/.dart_tool/') || rel.startsWith('.git/');
      List<String> checkoutFiles() => [
            for (final f in source.listSync(recursive: true, followLinks: false).whereType<File>())
              if (!generated(f.path.substring(source.path.length + 1).replaceAll(r'\', '/'))) '${f.path}:${f.lengthSync()}',
          ]..sort();
      final checkoutBefore = checkoutFiles();
      final copy = Directory('${temp.path}/src/lumina_plugin_pcg')..createSync(recursive: true);
      for (final f in source.listSync(recursive: true, followLinks: false).whereType<File>()) {
        final rel = f.path.substring(source.path.length + 1).replaceAll(r'\', '/');
        if (generated(rel)) continue;
        final out = File('${copy.path}/$rel');
        out.parent.createSync(recursive: true);
        f.copySync(out.path);
      }
      // `dart tool/pack_plugin.dart` (without `run`): dart: libraries only,
      // no dependency resolution in the copy.
      final pack = await tester.runAsync(() => Process.run('dart', ['tool/pack_plugin.dart'], workingDirectory: copy.path, runInShell: Platform.isWindows));
      expect(pack!.exitCode, 0, reason: '${pack.stdout}\n${pack.stderr}');
      final zip = File('${copy.path}/build/pack/lumina_plugin_pcg-0.1.0.zip');
      expect(zip.existsSync(), isTrue, reason: '${pack.stdout}');

      final projectsDir = Directory('${temp.path}/projects')..createSync();
      final pDir = Directory('${projectsDir.path}/ImportSmoke')..createSync();
      const project = LuminaProject(projectName: 'ImportSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/ImportSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: projectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrel'));
      vm.refreshAssets();
      final barrelAsset = vm.realAssets.firstWhere((a) => a.fileName == 'fuel_barrel_red.lmas' && a.type == AssetType.filamesh);
      await tester.runAsync(() => vm.spawnActorFromAsset(barrelAsset, location: const [0.0, 0.0, 0.0]));
      await tester.runAsync(() => vm.pluginsScanned);
      vm.pluginZipPicker = () async => zip.path;
      vm.pluginFolderPicker = () async => copy.path;

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      vm.frameLevelBounds();
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      Future<void> shot(String label) async {
        SmokeArtifacts.saveScreenshot('$name: $label',
            await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
            usedAssets: const [barrel]);
        await rec.hold(const Duration(seconds: 1));
      }

      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
          await settle(tester, frames: 3);
        }
        expect(finder, findsOneWidget);
        await settle(tester, frames: 10);
      }

      // Plugins ▸ Plugin Manager...
      await tester.tap(barItem('Plugins'));
      await settle(tester);
      await tester.tap(find.text('Plugin Manager...'));
      await settle(tester, frames: 30);
      await rec.hold(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('plugin_import_zip')), findsOneWidget);
      await shot('the Plugin Manager with New Plugin, Import from Folder and Import from Zip');

      // Import from Zip: the packed plugin lands in the user plugin directory.
      await tester.tap(find.byKey(const ValueKey('plugin_import_zip')));
      await waitFor(find.byKey(const ValueKey('plugin_import_done_dialog')));
      await rec.hold(const Duration(milliseconds: 1500));
      await shot('the zip imported');
      await tester.tap(find.byKey(const ValueKey('plugin_import_ok')));
      await settle(tester, frames: 20);
      final installed = Directory('${userDir.path}/lumina_plugin_pcg');
      expect(File('${installed.path}/lumina_plugin_pcg.lmplugin').existsSync(), isTrue);
      expect(Directory('${installed.path}/lib').existsSync(), isTrue);
      expect(Directory('${installed.path}/lumina_plugin_pcg').existsSync(), isFalse, reason: 'the zip top folder is not nested');
      final entry = vm.pluginRegistry.entries.singleWhere((e) => e.descriptor.name == 'lumina_plugin_pcg');
      expect(entry.descriptor.origin, PluginOrigin.user);
      expect(entry.descriptor.pluginDir.absolute.path.replaceAll(r'\', '/'), installed.absolute.path.replaceAll(r'\', '/'));
      expect(find.text('Procedural Content Generation'), findsWidgets);
      await rec.hold(const Duration(milliseconds: 1500));
      await shot('the imported plugin listed as a user plugin');

      // Import from Folder of the same plugin: Replace / Cancel, then Replace.
      File('${copy.path}/lib/imported_from_folder.dart').writeAsStringSync('// Added in the folder copy.\n');
      await tester.tap(find.byKey(const ValueKey('plugin_import_folder')));
      await waitFor(find.byKey(const ValueKey('plugin_import_replace_dialog')));
      await rec.hold(const Duration(milliseconds: 1500));
      await shot('Replace or Cancel for an installed plugin');
      await tester.tap(find.byKey(const ValueKey('plugin_import_replace')));
      await waitFor(find.byKey(const ValueKey('plugin_import_done_dialog')));
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('plugin_import_ok')));
      await settle(tester, frames: 20);
      expect(File('${installed.path}/lib/imported_from_folder.dart').existsSync(), isTrue, reason: 'the folder copy replaced the zip install');
      expect(Directory('${installed.path}/build').existsSync(), isFalse, reason: 'a folder import leaves build/ out');
      expect([for (final e in userDir.listSync()) e.uri.pathSegments.where((s) => s.isNotEmpty).last], ['lumina_plugin_pcg'],
          reason: 'no set-aside copy is left');
      await rec.hold(const Duration(seconds: 2));
      await shot('the folder import replaced the installed plugin');

      // Remove: the details pane's Remove lists what goes before anything is
      // deleted (the folder, its size, the saved data, the built-in that
      // comes back); confirming deletes the user copy and the built-in
      // lumina_plugin_pcg is listed again.
      final savedData = Directory('${pluginDataDir.path}/lumina_plugin_pcg')..createSync(recursive: true);
      File('${savedData.path}/settings.json').writeAsStringSync('{"density": 0.5}');
      expect(vm.pluginRegistry.entries.singleWhere((e) => e.descriptor.name == 'lumina_plugin_pcg').descriptor.origin, PluginOrigin.user);
      await tester.tap(find.byKey(const ValueKey('plugin_remove')));
      await waitFor(find.byKey(const ValueKey('plugin_remove_dialog')));
      Finder inDialog(Finder f) => find.descendant(of: find.byKey(const ValueKey('plugin_remove_dialog')), matching: f);
      expect(inDialog(find.textContaining('lumina_plugin_pcg')), findsWidgets);
      expect(inDialog(find.textContaining('every project on this machine')), findsOneWidget);
      expect(inDialog(find.byKey(const ValueKey('plugin_remove_size'))), findsOneWidget);
      expect(inDialog(find.byKey(const ValueKey('plugin_remove_comes_back'))), findsOneWidget);
      expect(inDialog(find.textContaining('plugin_data${Platform.pathSeparator}lumina_plugin_pcg')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plugin_remove_data')));
      await settle(tester, frames: 10);
      await rec.hold(const Duration(milliseconds: 1500));
      await shot('Remove lists the folder, its size, the saved data and the built-in that comes back');
      await tester.tap(find.byKey(const ValueKey('plugin_remove_confirm')));
      for (var i = 0; i < 100 && find.byKey(const ValueKey('plugin_remove_dialog')).evaluate().isNotEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await settle(tester, frames: 3);
      }
      expect(find.byKey(const ValueKey('plugin_remove_dialog')), findsNothing);
      await settle(tester, frames: 20);
      expect(installed.existsSync(), isFalse);
      expect(savedData.existsSync(), isFalse);
      expect(userDir.listSync(), isEmpty, reason: 'no set-aside folder is left');
      final back = vm.pluginRegistry.entries.singleWhere((e) => e.descriptor.name == 'lumina_plugin_pcg');
      expect(back.descriptor.origin, PluginOrigin.engine, reason: 'the built-in takes its place again');
      expect(find.text('ENGINE'), findsWidgets);
      expect(find.byKey(const ValueKey('plugin_built_in_note')), findsOneWidget);
      expect(find.byKey(const ValueKey('plugin_remove')), findsNothing);
      await rec.hold(const Duration(seconds: 2));
      await shot('the user plugin removed and the built-in listed again');

      expect(checkoutFiles(), checkoutBefore, reason: 'the plugins checkout is untouched');
      await rec.hold(const Duration(seconds: 2));
      rec.save(name, usedAssets: const [barrel]);
    } finally {
      UserPluginDir.override = previousUserDir;
      PluginDataDir.override = previousDataDir;
      LuminaConfigDir.override = previousConfigDir;
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  // A plugin button in each named slot (right of Blueprints,
  // toolbar end, both sides of the status bar), following its live state;
  // the toolbar-end button's command places a real barrel.
  testWidgets('plugin slot buttons (toolbar and status bar)', (tester) async {
    const barrel = 'Props/Barrels/fuel_barrel_red.glb';
    const name = 'plugin slot buttons (toolbar and status bar)';
    // The full toolbar needs ~1500 px (below that its right block is
    // cut); a 1920 px editor, as on DISPLAY1.
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('plugins_slots_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/SlotSmoke')..createSync(recursive: true);
    try {
      const project = LuminaProject(projectName: 'SlotSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/SlotSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrel'));
      vm.refreshAssets();
      final barrelAsset = vm.realAssets.firstWhere((a) => a.fileName == 'fuel_barrel_red.lmas' && a.type == AssetType.filamesh);
      await tester.runAsync(() => vm.spawnActorFromAsset(barrelAsset, location: const [0.0, 0.0, 0.0]));

      var placed = 0;
      final plugin = _SlotSmokePlugin(onPlace: () async {
        placed++;
        await vm.spawnActorFromAsset(barrelAsset, location: [placed * 120.0, 0.0, 0.0]);
      });
      vm.extensionRegistry.registerPlugin(plugin);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      vm.frameLevelBounds();
      await settle(tester);
      await rec.hold(const Duration(seconds: 2));

      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png, usedAssets: const [barrel]);
      }

      // 1. One button per slot, where the slot is.
      for (final slot in EditorSlot.values) {
        expect(find.byKey(ValueKey('slot_button_slot_smoke.${slot.name}')), findsOneWidget, reason: slot.name);
      }
      final blueprints = tester.getRect(find.byKey(const ValueKey('toolbar_blueprints')));
      expect(tester.getRect(find.byKey(const ValueKey('slot_button_slot_smoke.levelToolbarAfterBlueprints'))).left, greaterThanOrEqualTo(blueprints.right));
      expect(tester.getRect(find.byKey(const ValueKey('slot_button_slot_smoke.statusBarRight'))).right,
          lessThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('status_bar_rhi'))).left));
      await shot('four slots');

      // 2. The AI-style button through busy → active + badge → warning.
      final ai = plugin.ai;
      ai.value = ai.value.copyWith(busy: true);
      await settle(tester);
      expect(find.descendant(of: find.byKey(const ValueKey('slot_button_slot_smoke.levelToolbarAfterBlueprints')), matching: find.byType(CircularProgressIndicator)),
          findsOneWidget);
      await rec.hold(const Duration(seconds: 2));
      await shot('busy');
      ai.value = ai.value.copyWith(busy: false, active: true, badge: '2', tone: EditorTone.primary);
      await settle(tester);
      expect(find.text('2'), findsWidgets);
      await rec.hold(const Duration(seconds: 2));
      await shot('active with a badge');
      ai.value = ai.value.copyWith(active: false, tone: EditorTone.warning).withoutBadge;
      plugin.status.value = plugin.status.value.copyWith(label: 'Synced', tone: EditorTone.success);
      await settle(tester);
      await rec.hold(const Duration(seconds: 2));
      await shot('warning tone');

      // 3. The toolbar-end button places a barrel: the Outliner gains it.
      final before = vm.actors.length;
      await tester.tap(find.byKey(const ValueKey('slot_button_slot_smoke.levelToolbarEnd')));
      await settle(tester, frames: 20);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
      await settle(tester, frames: 20);
      expect(placed, 1);
      expect(vm.actors.length, before + 1, reason: 'the slot button command placed a barrel');
      vm.frameLevelBounds();
      await settle(tester, frames: 20);
      await rec.hold(const Duration(seconds: 3));
      await shot('barrel placed');
      rec.save(name, usedAssets: const [barrel]);
    } finally {
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  // A right-docked plugin panel (the level's actors, read through
  // context.level) opened by a slot button that is active while it is open;
  // a second panel gives the dock tabs; a wider dock persists.
  testWidgets('plugin right dock', (tester) async {
    const barrel = 'Props/Barrels/empty_barrel.glb';
    const name = 'plugin right dock';
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('plugins_dock_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/DockSmoke')..createSync(recursive: true);
    try {
      const project = LuminaProject(projectName: 'DockSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/DockSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrel'));
      vm.refreshAssets();
      final barrelAsset = vm.realAssets.firstWhere((a) => a.fileName == 'empty_barrel.lmas' && a.type == AssetType.filamesh);
      await tester.runAsync(() => vm.spawnActorFromAsset(barrelAsset, location: const [0.0, 0.0, 0.0]));
      final plugin = _DockSmokePlugin();
      vm.extensionRegistry.registerPlugin(plugin);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      vm.frameLevelBounds();
      await settle(tester);
      await rec.hold(const Duration(seconds: 2));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png, usedAssets: const [barrel]);
      }

      final dock = find.byKey(const ValueKey('right_dock'));
      expect(dock, findsNothing, reason: 'closed by default');

      // 1. The slot button opens the actors panel; it is active while open.
      await tester.tap(find.byKey(const ValueKey('slot_button_dock_smoke.actors')));
      await settle(tester, frames: 20);
      expect(dock, findsOneWidget);
      expect(plugin.button.value.active, isTrue);
      expect(find.text(vm.actors.last.name), findsWidgets, reason: 'the panel lists the barrel');
      await rec.hold(const Duration(seconds: 2));
      await shot('actors panel open');

      // 2. A second right panel: the dock gets tabs.
      plugin.panels.show('dock_smoke.notes');
      await settle(tester, frames: 20);
      expect(find.byKey(const ValueKey('right_dock_tab_dock_smoke.actors')), findsOneWidget);
      expect(find.byKey(const ValueKey('right_dock_tab_dock_smoke.notes')), findsOneWidget);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('right_dock_tab_dock_smoke.actors')));
      await settle(tester);
      await rec.hold(const Duration(seconds: 2));
      await shot('two panels, tabs');

      // 3. A wider dock, saved with the layout.
      final before = tester.getRect(dock);
      await rec.drag(Offset(before.left - 2, before.center.dy), Offset(before.left - 160, before.center.dy));
      await settle(tester, frames: 20);
      expect(tester.getRect(dock).width, greaterThan(before.width + 100));
      final saved = jsonDecode(File('${pDir.path}/.lumina/editor_layout.json').readAsStringSync()) as Map<String, dynamic>;
      expect((saved['rightWidth'] as num).toDouble(), greaterThan(before.width + 100));
      expect(saved['pluginPanelVisible'], {'dock_smoke.actors': true, 'dock_smoke.notes': true});
      await rec.hold(const Duration(seconds: 2));
      await shot('wider dock');

      // 4. The button closes the actors panel; closing notes closes the dock.
      await tester.tap(find.byKey(const ValueKey('slot_button_dock_smoke.actors')));
      await settle(tester);
      expect(plugin.button.value.active, isFalse);
      await tester.tap(find.byKey(const ValueKey('right_dock_close_dock_smoke.notes')));
      await settle(tester, frames: 20);
      expect(dock, findsNothing);
      await rec.hold(const Duration(seconds: 2));
      await shot('dock closed');
      rec.save(name, usedAssets: const [barrel]);
    } finally {
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  // A plugin MCP tool that places a real barrel, called in process
  // from the plugin's own right-dock panel and over HTTP by an external
  // agent; Undo takes the last one back.
  testWidgets('plugin MCP tools, in process and over HTTP', (tester) async {
    const barrel = 'Props/Barrels/fuel_barrel_red.glb';
    const name = 'plugin MCP tools, in process and over HTTP';
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('plugins_mcp_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/McpSmoke')..createSync(recursive: true);
    McpTestClient? client;
    try {
      const project = LuminaProject(projectName: 'McpSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/McpSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrel'));
      vm.refreshAssets();
      final asset = vm.realAssets.firstWhere((a) => a.fileName == 'fuel_barrel_red.lmas' && a.type == AssetType.filamesh);
      // EditorActorSpec.meshAssetPath is absolute (lumina_editor_api docs).
      final plugin = _McpSmokePlugin(asset.lmasPath!);
      vm.extensionRegistry.registerPlugin(plugin);
      plugin.panels.show('mcp_smoke.panel');

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 2));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png, usedAssets: const [barrel]);
      }

      int barrels() => vm.actors.where((a) => a.name.startsWith('McpBarrel')).length;
      // The mesh loads from disk after the actor is added: wait for real IO.
      Future<void> meshesLoaded() async {
        for (var i = 0; i < 60 && vm.actors.where((a) => a.name.startsWith('McpBarrel')).any((a) => a.meshData == null); i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
          await tester.pump();
        }
        expect(vm.actors.where((a) => a.name.startsWith('McpBarrel')).every((a) => a.meshData != null), isTrue,
            reason: 'every placed barrel draws its mesh');
      }

      // 1. The panel's Run button calls the tool in process.
      await tester.tap(find.byKey(const ValueKey('mcp_smoke_run')));
      for (var i = 0; i < 40 && barrels() < 1; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      expect(barrels(), 1, reason: 'the in-process call placed a barrel');
      await meshesLoaded();
      vm.frameLevelBounds();
      await settle(tester, frames: 20);
      await rec.hold(const Duration(seconds: 2));
      await shot('placed in process');

      // 2. An external agent over HTTP sees and calls the same tool.
      expect(await tester.runAsync(() => vm.mcpServer.start(port: 0)), isTrue);
      client = McpTestClient(vm.mcpServer.url!, vm.mcpServer.token);
      await tester.runAsync(() => client!.handshake());
      final list = await tester.runAsync(() => client!.post({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'}));
      final names = [for (final t in (((list!.json as Map)['result'] as Map)['tools'] as List)) (t as Map)['name']];
      expect(names, contains('mcp_smoke.place_barrel'));
      final reply = await tester.runAsync(() => client!.callTool('mcp_smoke.place_barrel', {'x': -200}));
      expect(reply!.isError, isFalse, reason: reply.text);
      await settle(tester, frames: 20);
      expect(barrels(), 2);
      await meshesLoaded();
      vm.frameLevelBounds();
      await settle(tester, frames: 20);
      await rec.hold(const Duration(seconds: 2));
      await shot('placed over HTTP');

      // 3. Undo takes the last one back.
      expect(vm.transactions.undoLabel, startsWith('Undo MCP: '));
      vm.commands.execute('edit.undo');
      await settle(tester, frames: 20);
      expect(barrels(), 1);
      await rec.hold(const Duration(seconds: 3));
      await shot('undone');
      expect(plugin.calls, isNotEmpty, reason: 'the plugin saw the calls');
      // The undone level, long enough for the video's minimum.
      final minimum = Duration(milliseconds: (SmokeArtifacts.minimumVideoSeconds * 1000).ceil() + 500);
      if (rec.recorded < minimum) await rec.hold(minimum - rec.recorded);
      rec.save(name, usedAssets: const [barrel]);
    } finally {
      client?.close();
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  // lumina_plugin_miniai 01: the ✦ AI button right of Blueprints opens the AI
  // Assistant in the right dock, with the editor's real MCP tool count;
  // Plugins ▸ MiniAI ▸ AI Assistant is checked and closes it.
  testWidgets('MiniAI AI button and chat panel', (tester) async {
    const barrel = 'Props/Barrels/dented_barrel.glb';
    const name = 'MiniAI AI button and chat panel';
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('miniai_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/MiniAiSmoke')..createSync(recursive: true);
    try {
      const project = LuminaProject(projectName: 'MiniAiSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/MiniAiSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrel'));
      vm.refreshAssets();
      final barrelAsset = vm.realAssets.firstWhere((a) => a.fileName == 'dented_barrel.lmas' && a.type == AssetType.filamesh);
      await tester.runAsync(() => vm.spawnActorFromAsset(barrelAsset, location: const [0.0, 0.0, 0.0]));
      vm.extensionRegistry.registerPlugin(LuminaPluginMiniaiPlugin());

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      vm.frameLevelBounds();
      await settle(tester);
      await rec.hold(const Duration(seconds: 2));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png, usedAssets: const [barrel]);
      }

      // 1. The ✦ AI button, right of Blueprints, warning-toned (no provider).
      final button = find.byKey(const ValueKey('slot_button_lumina_plugin_miniai.ai'));
      expect(button, findsOneWidget);
      expect(tester.getRect(button).left, greaterThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('toolbar_blueprints'))).right));
      await shot('AI button');

      // 2. Click → the AI Assistant in the right dock, with the real tool count.
      await tester.tap(button);
      await settle(tester, frames: 20);
      expect(find.byKey(const ValueKey('right_dock')), findsOneWidget);
      expect(find.text('AI ASSISTANT'), findsOneWidget);
      final tools = vm.mcpServer.tools.tools.length;
      expect(tools, greaterThan(50));
      expect(find.textContaining('$tools editor tools available'), findsOneWidget);
      expect(tester.widget<PrimaryButton>(find.byKey(const ValueKey('miniai_send'))).onPressed, isNull);
      await rec.hold(const Duration(seconds: 3));
      await shot('chat panel open');

      // 3. Plugins ▸ MiniAI ▸ AI Assistant is checked; clicking it closes the panel.
      await tester.tap(barItem('Plugins'));
      await settle(tester);
      await tester.tap(find.text('MiniAI'));
      await settle(tester);
      expect(tester.widget<MenuCheckbox>(find.byKey(const ValueKey('menu_check_miniai.menu.togglePanel'))).value, isTrue);
      await rec.hold(const Duration(seconds: 2));
      await shot('Plugins MiniAI menu');
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('menu_check_miniai.menu.togglePanel')), matching: find.text('AI Assistant')));
      await settle(tester, frames: 20);
      expect(find.byKey(const ValueKey('right_dock')), findsNothing);
      await rec.hold(const Duration(seconds: 2));
      await shot('panel closed');
      final minimum = Duration(milliseconds: (SmokeArtifacts.minimumVideoSeconds * 1000).ceil() + 500);
      if (rec.recorded < minimum) await rec.hold(minimum - rec.recorded);
      rec.save(name, usedAssets: const [barrel]);
    } finally {
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  // The AI Assistant stays in the level editor until its dock pin
  // ("Show in every editor") is on; then the same panel, with the text the
  // user typed, sits beside the Navigation editor's own Agent & Grid panel.
  testWidgets('plugin panel shown in every editor', (tester) async {
    const barrel = 'Props/Barrels/fuel_barrel_red.glb';
    const name = 'plugin panel shown in every editor';
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('always_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/AlwaysSmoke')..createSync(recursive: true);
    try {
      const project = LuminaProject(projectName: 'AlwaysSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/AlwaysSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrel'));
      vm.refreshAssets();
      final barrelAsset = vm.realAssets.firstWhere((a) => a.fileName == 'fuel_barrel_red.lmas' && a.type == AssetType.filamesh);
      await tester.runAsync(() => vm.spawnActorFromAsset(barrelAsset, location: const [0.0, 0.0, 0.0]));
      vm.extensionRegistry.registerPlugin(LuminaPluginMiniaiPlugin());

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      vm.frameLevelBounds();
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png, usedAssets: const [barrel]);
      }

      const chat = LuminaPluginMiniaiPlugin.chatPanelId;
      final dock = find.byKey(const ValueKey('right_dock'));
      final message = find.byKey(const ValueKey('miniai_message'));

      // 1. The AI button opens the AI Assistant in the level editor; a draft
      // message goes into its input.
      await tester.tap(find.byKey(const ValueKey('slot_button_lumina_plugin_miniai.ai')));
      await settle(tester, frames: 20);
      expect(dock, findsOneWidget);
      await tester.enterText(message, 'Place three barrels along the path');
      await settle(tester);
      await rec.hold(const Duration(seconds: 2));
      await shot('AI Assistant in the level editor');

      // 2. "Always" off: the Navigation editor has no dock.
      vm.commands.execute('tools.navmeshGenerator');
      await settle(tester, frames: 30);
      expect(vm.currentTab.category, 'navmesh');
      expect(find.text('AGENT & GRID'), findsOneWidget);
      expect(dock, findsNothing);
      await rec.hold(const Duration(seconds: 2));
      await shot('Navigation without Always');

      // 3. Back on the level tab, the dock's pin turns "Always" on.
      vm.selectTab(0);
      await settle(tester, frames: 20);
      await tester.tap(find.byKey(const ValueKey('right_dock_always_$chat')));
      await settle(tester);
      expect(vm.panelsController.isAlwaysVisible(chat), isTrue);
      await rec.hold(const Duration(seconds: 1));

      // 4. The Navigation tab now shows the same panel, draft kept, right of
      // Agent & Grid; the level toolbar stays on the level tab.
      vm.selectTab(vm.openTabs.indexWhere((t) => t.category == 'navmesh'));
      await settle(tester, frames: 30);
      expect(dock, findsOneWidget);
      expect(find.text('AI ASSISTANT'), findsOneWidget);
      expect(find.text('Place three barrels along the path'), findsOneWidget, reason: 'the same panel, its input kept');
      expect(tester.getRect(dock).left, greaterThanOrEqualTo(tester.getRect(find.text('AGENT & GRID')).right));
      expect(find.byKey(const ValueKey('toolbar_play')), findsNothing);
      await rec.hold(const Duration(seconds: 3));
      await shot('AI Assistant beside the Navigation editor');

      // 5. The Window menu row is checked.
      await tester.tap(barItem('Window'));
      await settle(tester);
      expect(tester.widget<MenuCheckbox>(find.byKey(const ValueKey('menu_check_window.panelAlways.$chat'))).value, isTrue);
      await rec.hold(const Duration(seconds: 2));
      await shot('Window menu Show in Every Editor');
      await tester.tapAt(const Offset(960, 1150));
      await settle(tester);
      final saved = jsonDecode(File('${pDir.path}/.lumina/editor_layout.json').readAsStringSync()) as Map<String, dynamic>;
      expect(saved['pluginPanelAlways'], {chat: true});
      final minimum = Duration(milliseconds: (SmokeArtifacts.minimumVideoSeconds * 1000).ceil() + 500);
      if (rec.recorded < minimum) await rec.hold(minimum - rec.recorded);
      rec.save(name, usedAssets: const [barrel]);
    } finally {
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  // A plugin places three real barrels in one runTransaction (one
  // Undo takes all three), keeps JSON in its own store, hears the project
  // open, and its onEditorShutdown runs on exit.
  testWidgets('plugin storage, lifecycle and one-step undo', (tester) async {
    const barrel = 'Props/Barrels/empty_barrel.glb';
    const name = 'plugin storage, lifecycle and one-step undo';
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('plugins_lifecycle_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/LifeSmoke')..createSync(recursive: true);
    PluginDataDir.override = Directory('${tempProjectsDir.path}/plugin_data');
    try {
      const project = LuminaProject(projectName: 'LifeSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/LifeSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrel'));
      vm.refreshAssets();
      final asset = vm.realAssets.firstWhere((a) => a.fileName == 'empty_barrel.lmas' && a.type == AssetType.filamesh);
      final plugin = _LifecycleSmokePlugin(asset.lmasPath!);
      vm.extensionRegistry.registerPlugin(plugin);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 2));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png, usedAssets: const [barrel]);
      }

      int barrels() => vm.actors.where((a) => a.name.startsWith('LifeBarrel')).length;

      // 1. Three barrels in one runTransaction.
      final before = vm.actors.length;
      await tester.runAsync(plugin.placeThree);
      await settle(tester, frames: 20);
      for (var i = 0; i < 40 && vm.actors.where((a) => a.name.startsWith('LifeBarrel')).any((a) => a.meshData == null); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(barrels(), 3);
      expect(vm.transactions.undoLabel, 'Undo Place 3 barrels');
      vm.frameLevelBounds();
      await settle(tester, frames: 20);
      await rec.hold(const Duration(seconds: 3));
      await shot('three barrels, one step');

      // 2. One Edit ▸ Undo removes all three.
      vm.commands.execute('edit.undo');
      await settle(tester, frames: 20);
      expect(barrels(), 0);
      expect(vm.actors.length, before);
      await rec.hold(const Duration(seconds: 3));
      await shot('one undo');

      // 3. Its store and the project it was told about are on disk.
      final opened = File('${pDir.path}/.lumina/plugins/lifecycle_smoke/opened.json');
      expect(jsonDecode(opened.readAsStringSync()), {'project': 'LifeSmoke'});
      expect(File('${tempProjectsDir.path}/plugin_data/lifecycle_smoke/settings.json').existsSync(), isTrue);

      // 4. Exiting runs its onEditorShutdown.
      await tester.runAsync(() => vm.shutdownPlugins(exiting: true));
      expect(File('${pDir.path}/.lumina/plugins/lifecycle_smoke/shutdown.json').existsSync(), isTrue);
      final minimum = Duration(milliseconds: (SmokeArtifacts.minimumVideoSeconds * 1000).ceil() + 500);
      if (rec.recorded < minimum) await rec.hold(minimum - rec.recorded);
      rec.save(name, usedAssets: const [barrel]);
    } finally {
      PluginDataDir.override = null;
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  // lumina_plugin_miniai 02: a real local model (MiniCPM5-2B on llama-server,
  // GPU 1) set up in the Model provider dialog places three real barrels
  // through the editor's MCP tools after the user approves; one Undo takes
  // the whole turn back. Skipped when the model is not installed.
  testWidgets('MiniAI places barrels with a local model', (tester) async {
    const barrel = 'Props/Barrels/fuel_barrel_red.glb';
    const name = 'MiniAI places barrels with a local model';
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    final miniai = '$home/.local/share/lumina/miniai';
    final model = File('$miniai/models/MiniCPM5-2B-Q4_K_M.gguf');
    final serverExe = File('$miniai/bin/b11239/${Platform.isWindows ? 'llama-server.exe' : 'llama-server'}');
    if (!model.existsSync() || !serverExe.existsSync()) {
      markTestSkipped('MiniCPM5-2B / llama-server not installed in $miniai (the MiniAI setup installs them)');
      return;
    }
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('miniai_model_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/AiSmoke')..createSync(recursive: true);
    PluginDataDir.override = Directory('${tempProjectsDir.path}/plugin_data');
    Process? llama;
    try {
      // llama-server on GPU 1 (the RTX PRO 2000's Vulkan device, by name).
      final devices = await tester.runAsync(() => Process.run(serverExe.path, ['--list-devices']));
      final device = RegExp(r'(Vulkan\d+): [^\n]*RTX PRO 2000').firstMatch('${devices!.stdout}${devices.stderr}')?.group(1);
      final port = await tester.runAsync(() async {
        final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final p = s.port;
        await s.close();
        return p;
      });
      llama = await tester.runAsync(() => Process.start(serverExe.path, [
            '-m', model.path, if (device != null) ...['--device', device], '-ngl', '99', '-c', '8192', '--jinja', '--min-p', '0.0',
            '--host', '127.0.0.1', '--port', '$port', '--alias', 'MiniCPM5-2B-Q4_K_M',
          ]));
      llama!.stdout.drain<void>();
      llama.stderr.drain<void>();

      const project = LuminaProject(projectName: 'AiSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/AiSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrel'));
      vm.refreshAssets();
      final asset = vm.realAssets.firstWhere((a) => a.fileName == 'fuel_barrel_red.lmas' && a.type == AssetType.filamesh);
      final plugin = LuminaPluginMiniaiPlugin();
      vm.extensionRegistry.registerPlugin(plugin);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png, usedAssets: const [barrel]);
      }

      Future<void> waitFor(bool Function() done, {Duration max = const Duration(minutes: 3)}) async {
        final sw = Stopwatch()..start();
        while (!done() && sw.elapsed < max) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
          await tester.pump(const Duration(milliseconds: 20));
          if (sw.elapsed.inSeconds % 2 == 0) await rec.capture();
        }
        expect(done(), isTrue, reason: 'timed out after $max');
      }

      final health = HttpClient();
      for (var i = 0; i < 120; i++) {
        final ok = await tester.runAsync(() async {
          try {
            return (await (await health.getUrl(Uri.parse('http://127.0.0.1:$port/health'))).close()).statusCode == 200;
          } catch (_) {
            return false;
          }
        });
        if (ok == true) break;
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      }
      health.close();

      // 1. The AI button opens the panel; set up the local model.
      await tester.tap(find.byKey(const ValueKey('slot_button_lumina_plugin_miniai.ai')));
      await settle(tester, frames: 20);
      await tester.tap(find.byKey(const ValueKey('miniai_setup_provider')));
      await settle(tester, frames: 20);
      await tester.enterText(find.byKey(const ValueKey('miniai_provider_url')), 'http://127.0.0.1:$port/v1');
      await tester.tap(find.byKey(const ValueKey('miniai_provider_test')));
      await waitFor(() => find.byKey(const ValueKey('miniai_provider_pick_MiniCPM5-2B-Q4_K_M')).evaluate().isNotEmpty, max: const Duration(seconds: 30));
      await tester.tap(find.byKey(const ValueKey('miniai_provider_pick_MiniCPM5-2B-Q4_K_M')));
      await settle(tester);
      await rec.hold(const Duration(seconds: 2));
      await shot('model provider');
      await tester.tap(find.byKey(const ValueKey('miniai_provider_save')));
      await waitFor(() => plugin.controller!.settings.isConfigured && find.byKey(const ValueKey('miniai_provider_save')).evaluate().isEmpty,
          max: const Duration(seconds: 20));

      // 2. Ask for three barrels; approve the calls.
      final before = vm.actors.length;
      await tester.enterText(find.byKey(const ValueKey('miniai_message')),
          'Place the asset ${asset.relativePath} three times in the level, at [0, 0, 0], [250, 0, 0] and [500, 0, 0].');
      await tester.tap(find.byKey(const ValueKey('miniai_send')));
      await waitFor(() => plugin.controller!.chat.pendingApprovals.isNotEmpty);
      await rec.hold(const Duration(seconds: 2));
      await shot('approval card');
      await tester.tap(find.byKey(const ValueKey('miniai_always')));
      await waitFor(() => !plugin.controller!.running);
      for (var i = 0; i < 40 && vm.actors.skip(before).any((a) => a.meshData == null); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      final placed = vm.actors.length - before;
      debugPrint('[miniai02_smoke] placed $placed barrels; calls: ${plugin.controller!.chat.items.whereType<ToolCallItem>().map((c) => '${c.call.name}:${c.status.name}').join(', ')}');
      expect(placed, 3, reason: 'the model placed three barrels');
      expect(vm.actors.skip(before).every((a) => a.meshData != null), isTrue);
      expect(vm.transactions.undoLabel, startsWith('Undo AI: '));
      vm.frameLevelBounds();
      await settle(tester, frames: 20);
      await rec.hold(const Duration(seconds: 3));
      await shot('three barrels placed');

      // 3. One Undo takes the whole turn back.
      vm.commands.execute('edit.undo');
      await settle(tester, frames: 20);
      expect(vm.actors.length, before);
      await rec.hold(const Duration(seconds: 3));
      await shot('one undo');
      rec.save(name, usedAssets: const [barrel]);
    } finally {
      PluginDataDir.override = null;
      llama?.kill();
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 15)));

  // The Local model card starts the installed llama-server +
  // MiniCPM5 on GPU 1, makes it the provider, answers, and the server stops
  // with the editor.
  testWidgets('MiniAI local model manager', (tester) async {
    const name = 'MiniAI local model manager';
    final env = {...Platform.environment, 'FILAMENT_GPU': Platform.environment['FILAMENT_GPU'] ?? 'RTX PRO 2000'};
    final probe = LocalModelManager(root: LocalModelManager.defaultRoot(env), environment: env);
    final installed = probe.isInstalled();
    probe.dispose();
    if (!installed) {
      markTestSkipped('MiniCPM5 / llama-server not installed in ${LocalModelManager.defaultRoot(env)}; the card offers Download instead');
      return;
    }
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('miniai_local_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/LocalAi')..createSync(recursive: true);
    PluginDataDir.override = Directory('${tempProjectsDir.path}/plugin_data');
    LuminaPluginMiniaiPlugin? plugin;
    Future<int> gpu1MemoryMiB() async {
      final r = await Process.run('nvidia-smi', ['--query-gpu=name,memory.used', '--format=csv,noheader,nounits']);
      final line = '${r.stdout}'.split('\n').firstWhere((l) => l.contains('RTX PRO 2000'), orElse: () => '');
      return int.tryParse(line.split(',').last.trim()) ?? -1;
    }

    try {
      const project = LuminaProject(projectName: 'LocalAi', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/LocalAi.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      plugin = LuminaPluginMiniaiPlugin();
      vm.extensionRegistry.registerPlugin(plugin);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png);
      }

      Future<void> waitFor(bool Function() done, {Duration max = const Duration(minutes: 2)}) async {
        final sw = Stopwatch()..start();
        while (!done() && sw.elapsed < max) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
          await tester.pump(const Duration(milliseconds: 20));
          if (sw.elapsed.inSeconds % 2 == 0) await rec.capture();
        }
        expect(done(), isTrue, reason: 'timed out after $max');
      }

      final local = plugin.controller!.local;
      await waitFor(() => local.status == LocalModelStatus.installed, max: const Duration(seconds: 10));

      // 1. The AI button opens the panel: the Local model card, installed.
      await tester.tap(find.byKey(const ValueKey('slot_button_lumina_plugin_miniai.ai')));
      await settle(tester, frames: 20);
      await waitFor(() => local.devices != null, max: const Duration(seconds: 20));
      await settle(tester, frames: 10);
      expect(find.byKey(const ValueKey('miniai_local_model')), findsOneWidget);
      expect(find.text('Downloaded · not running'), findsOneWidget);
      await rec.hold(const Duration(seconds: 2));
      await shot('local model installed');

      // 2. Start → ready on GPU 1; it becomes the provider.
      final before = await tester.runAsync(gpu1MemoryMiB) ?? -1;
      await tester.tap(find.byKey(const ValueKey('miniai_local_start')));
      await waitFor(() => local.status == LocalModelStatus.ready || local.status == LocalModelStatus.failed);
      expect(local.status, LocalModelStatus.ready, reason: local.message);
      expect(local.device, 'Vulkan0', reason: 'the RTX PRO 2000 is Vulkan0');
      await waitFor(() => plugin!.controller!.settings.selected?.id == MiniAiController.localProviderId, max: const Duration(seconds: 10));
      final after = await tester.runAsync(gpu1MemoryMiB) ?? -1;
      debugPrint('[miniai03_smoke] RTX PRO 2000 memory $before → $after MiB on ${local.device}, port ${local.port}');
      expect(after - before, greaterThan(500), reason: 'the model loads into GPU 1');
      await settle(tester, frames: 10);
      await rec.hold(const Duration(seconds: 2));
      await shot('ready on GPU 1');

      // 3. A question → an answer from the local model.
      await tester.enterText(find.byKey(const ValueKey('miniai_message')), 'What is 2+2? Answer with the number only.');
      await tester.tap(find.byKey(const ValueKey('miniai_send')));
      await waitFor(() => plugin!.controller!.chat.items.whereType<AssistantItem>().isNotEmpty && !plugin.controller!.running);
      expect(plugin.controller!.chat.items.whereType<AssistantItem>().last.text.toString(), contains('4'));
      await settle(tester, frames: 10);
      await rec.hold(const Duration(seconds: 3));
      await shot('answer');

      // 4. The editor exits: the server stops with it.
      final pid = local.pid!;
      await tester.runAsync(() => vm.shutdownPlugins(exiting: true));
      final alive = await tester.runAsync(() => LocalModelManager.isLlamaServer(pid));
      expect(alive, isFalse, reason: 'onEditorShutdown stops llama-server');
      expect(local.pidFile.existsSync(), isFalse);
      expect(local.status, LocalModelStatus.stopped);
      // The card after the shutdown, long enough for the video's minimum.
      await settle(tester, frames: 10);
      final minimum = Duration(milliseconds: (SmokeArtifacts.minimumVideoSeconds * 1000).ceil() + 500);
      await rec.hold(rec.recorded < minimum ? minimum - rec.recorded : const Duration(seconds: 1));
      rec.save(name);
    } finally {
      PluginDataDir.override = null;
      final pid = plugin?.controller?.local.pid;
      if (pid != null) await tester.runAsync(() => Process.run(Platform.isWindows ? 'taskkill' : 'kill', Platform.isWindows ? ['/T', '/F', '/PID', '$pid'] : ['-9', '$pid']));
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  // Two chats with the local model, History (search, rename,
  // open), the project reopened in a new editor restores the last chat, and
  // a confirmed delete.
  testWidgets('MiniAI chat history', (tester) async {
    const name = 'MiniAI chat history';
    final env = {...Platform.environment, 'FILAMENT_GPU': Platform.environment['FILAMENT_GPU'] ?? 'RTX PRO 2000'};
    final probe = LocalModelManager(root: LocalModelManager.defaultRoot(env), environment: env);
    final installed = probe.isInstalled();
    probe.dispose();
    if (!installed) {
      markTestSkipped('MiniCPM5 / llama-server not installed in ${LocalModelManager.defaultRoot(env)}');
      return;
    }
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('miniai_history_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/History')..createSync(recursive: true);
    PluginDataDir.override = Directory('${tempProjectsDir.path}/plugin_data');
    final plugins = <LuminaPluginMiniaiPlugin>[];
    try {
      const project = LuminaProject(projectName: 'History', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/History.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final boundaryKey = GlobalKey();

      Future<(EditorViewModel, LuminaPluginMiniaiPlugin)> openEditor() async {
        final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
        addTearDown(vm.dispose);
        await tester.runAsync(() => vm.ensureDefaultLevelAssets());
        final plugin = LuminaPluginMiniaiPlugin();
        plugins.add(plugin);
        vm.extensionRegistry.registerPlugin(plugin);
        await tester.pumpWidget(RepaintBoundary(
          key: boundaryKey,
          child: ShadcnApp(key: ObjectKey(vm), theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
        ));
        await settle(tester, frames: 30);
        return (vm, plugin);
      }

      var (vm, plugin) = await openEditor();
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png);
      }

      Future<void> waitFor(bool Function() done, {Duration max = const Duration(minutes: 2), VoidCallback? onTimeout}) async {
        final sw = Stopwatch()..start();
        while (!done() && sw.elapsed < max) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
          await tester.pump(const Duration(milliseconds: 20));
          if (sw.elapsed.inMilliseconds % 1000 < 200) await rec.capture();
        }
        if (!done()) {
          onTimeout?.call();
          await shot('timeout');
        }
        expect(done(), isTrue, reason: 'timed out after $max');
      }

      List<String> rows() => [
            for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('miniai_history_open_')).evaluate())
              (e.widget.key! as ValueKey<String>).value.substring('miniai_history_open_'.length),
          ];
      String title() => (tester.widget(find.byKey(const ValueKey('miniai_chat_title'))) as Text).data!;

      Future<void> ask(String text) async {
        final c = plugin.controller!;
        final before = c.chat.items.whereType<AssistantItem>().length;
        // Focus the composer first: after a send the text input connection
        // stays with the old focus and enterText would type nowhere.
        await tester.tap(find.byKey(const ValueKey('miniai_message')));
        await tester.pump();
        await tester.enterText(find.byKey(const ValueKey('miniai_message')), text);
        await tester.pump();
        expect((tester.widget(find.byKey(const ValueKey('miniai_message'))) as TextField).controller?.text, text);
        await tester.tap(find.byKey(const ValueKey('miniai_send')));
        await waitFor(() => !c.running && c.chat.items.whereType<AssistantItem>().length > before && c.summaries.any((s) => s.id == c.chat.id), onTimeout: () {
          debugPrint('[miniai04_smoke] running=${c.running} store=${c.store?.dir.path} summaries=${c.summaries.map((s) => s.id)} chat=${c.chat.id} '
              'items=${c.chat.items.map((i) => i.runtimeType)} failed=${c.lastTurnFailed} notes=${c.chat.items.whereType<NoteItem>().map((n) => n.text)}');
        });
        await settle(tester, frames: 10);
      }

      // 1. The local model on GPU 1, and a first question.
      final local = plugin.controller!.local;
      await tester.tap(find.byKey(const ValueKey('slot_button_lumina_plugin_miniai.ai')));
      await settle(tester, frames: 20);
      await tester.tap(find.byKey(const ValueKey('miniai_local_start')));
      await waitFor(() => local.status == LocalModelStatus.ready || local.status == LocalModelStatus.failed);
      expect(local.status, LocalModelStatus.ready, reason: local.message);
      await waitFor(() => plugin.controller!.settings.selected?.id == MiniAiController.localProviderId, max: const Duration(seconds: 10));
      await settle(tester, frames: 10);
      await ask('What is 2+2? Answer with the number only.');
      final math = plugin.controller!.chat.id;

      // 2. + New, a second question.
      await tester.tap(find.byKey(const ValueKey('miniai_new_chat')));
      await settle(tester, frames: 10);
      expect(title(), 'New chat');
      await ask('Name one primary colour. Answer with one word.');
      final colour = plugin.controller!.chat.id;
      await rec.hold(const Duration(seconds: 1));

      // 3. History shows both, the latest first.
      await tester.tap(find.byKey(const ValueKey('miniai_history')));
      await waitFor(() => rows().length == 2, max: const Duration(seconds: 10));
      expect(rows(), [colour, math]);
      await rec.hold(const Duration(seconds: 2));
      await shot('history');

      // 4. Search, 5. rename, 6. open.
      await tester.enterText(find.byKey(const ValueKey('miniai_history_search')), '2+2');
      await waitFor(() => rows().length == 1, max: const Duration(seconds: 10));
      expect(rows(), [math]);
      await rec.hold(const Duration(seconds: 1));
      await tester.enterText(find.byKey(const ValueKey('miniai_history_search')), '');
      await waitFor(() => rows().length == 2, max: const Duration(seconds: 10));
      await tester.tap(find.byKey(ValueKey('miniai_history_rename_$math')));
      await settle(tester, frames: 10);
      await tester.enterText(find.byKey(const ValueKey('miniai_rename_field')), 'Math');
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('miniai_rename_save')));
      await waitFor(() => plugin.controller!.summaries.any((s) => s.title == 'Math'), max: const Duration(seconds: 10));
      await tester.tap(find.byKey(ValueKey('miniai_history_open_$math')));
      await waitFor(() => plugin.controller!.chat.id == math, max: const Duration(seconds: 10));
      await settle(tester, frames: 10);
      expect(title(), 'Math');
      await rec.hold(const Duration(seconds: 1));

      // 7. The editor closes (the server stops); the project reopens in a
      //    new editor and the last chat comes back.
      await tester.runAsync(() => vm.shutdownPlugins(exiting: true));
      expect(local.status, LocalModelStatus.stopped);
      final stored = File('${pDir.path}/.lumina/plugins/lumina_plugin_miniai/chats/$math.json');
      expect(stored.existsSync(), isTrue, reason: 'chats live in the project');
      (vm, plugin) = await openEditor();
      await waitFor(() => plugin.controller!.chat.id == math, max: const Duration(seconds: 10));
      await settle(tester, frames: 20);
      // The right dock remembers the open panel; open it only if it is not.
      if (find.byKey(const ValueKey('miniai_chat_title')).evaluate().isEmpty) {
        await tester.tap(find.byKey(const ValueKey('slot_button_lumina_plugin_miniai.ai')));
        await settle(tester, frames: 20);
      }
      expect(title(), 'Math');
      expect(find.text('What is 2+2? Answer with the number only.'), findsOneWidget);
      await rec.hold(const Duration(seconds: 2));
      await shot('restored after reopening');

      // 8. Delete the other chat, confirmed.
      await tester.tap(find.byKey(const ValueKey('miniai_history')));
      await waitFor(() => rows().length == 2, max: const Duration(seconds: 10));
      await tester.tap(find.byKey(ValueKey('miniai_history_delete_$colour')));
      await settle(tester, frames: 10);
      expect(find.text('Delete chat?'), findsOneWidget);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('miniai_delete_confirm')));
      await waitFor(() => rows().length == 1, max: const Duration(seconds: 10));
      expect(rows(), [math]);
      await rec.hold(const Duration(seconds: 2));
      await shot('after delete');
      final minimum = Duration(milliseconds: (SmokeArtifacts.minimumVideoSeconds * 1000).ceil() + 500);
      if (rec.recorded < minimum) await rec.hold(minimum - rec.recorded);
      rec.save(name);
    } finally {
      PluginDataDir.override = null;
      for (final p in plugins) {
        final pid = p.controller?.local.pid;
        if (pid != null) await tester.runAsync(() => Process.run(Platform.isWindows ? 'taskkill' : 'kill', Platform.isWindows ? ['/T', '/F', '/PID', '$pid'] : ['-9', '$pid']));
      }
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  // MiniAI's Project Settings page — the default mode for new
  // chats goes into `.lmproject` `plugin_settings` on Apply, and the next
  // chat starts in it.
  testWidgets('plugin project settings section', (tester) async {
    const name = 'plugin project settings section';
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('plugin_settings_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/SettingsSmoke')..createSync(recursive: true);
    PluginDataDir.override = Directory('${tempProjectsDir.path}/plugin_data');
    try {
      const project = LuminaProject(projectName: 'SettingsSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      final manifest = File('${pDir.path}/SettingsSmoke.lmproject')..writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      final plugin = LuminaPluginMiniaiPlugin();
      vm.extensionRegistry.registerPlugin(plugin);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png);
      }

      Future<void> io([int n = 10]) async {
        for (var i = 0; i < n; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
          await tester.pump(const Duration(milliseconds: 20));
        }
      }

      String modeLabel() => (tester.widget(find.byKey(const ValueKey('miniai_mode'))) as Select<ApprovalMode>).value!.label;

      // The AI panel: a new chat starts in Ask.
      await tester.tap(find.byKey(const ValueKey('slot_button_lumina_plugin_miniai.ai')));
      await settle(tester, frames: 20);
      expect(modeLabel(), 'Ask');
      await rec.hold(const Duration(seconds: 1));

      // 1. Edit ▸ Project Settings… ▸ PLUGINS ▸ AI Assistant.
      await tester.tap(find.text('Edit').first);
      await settle(tester, frames: 10);
      await tester.tap(find.text('Project Settings...').last);
      await io();
      final category = ProjectSettingsViewModel.pluginCategoryId('lumina_plugin_miniai', 'miniai');
      expect(find.byKey(const ValueKey('project_settings_nav_plugins_header')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('project_settings_nav_$category')));
      await settle(tester, frames: 10);
      expect(find.text('AI ASSISTANT'), findsWidgets);
      await rec.hold(const Duration(seconds: 2));
      await shot('AI Assistant page');

      // 2. Default mode → Plan, Apply.
      await tester.tap(find.byKey(const ValueKey('miniai_settings_default_mode')));
      await settle(tester, frames: 15);
      await tester.tap(find.byKey(const ValueKey('miniai_settings_mode_plan')));
      await settle(tester, frames: 15);
      final settingsVm = (tester.state(find.byType(ProjectSettingsSubEditor)) as dynamic).viewModelForTest as ProjectSettingsViewModel;
      expect(settingsVm.pluginSettingsOf('lumina_plugin_miniai'), {'defaultMode': 'plan'});
      expect(settingsVm.isDirty, isTrue);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('project_settings_apply')));
      await io(20);
      final saved = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
      expect(saved['plugin_settings'], {
        'lumina_plugin_miniai': {'defaultMode': 'plan'},
      });
      expect(plugin.controller!.chat.gate.mode, ApprovalMode.ask, reason: 'the open chat keeps its mode');
      await rec.hold(const Duration(seconds: 1));
      await shot('applied');

      // 3. Back in the level, + New starts in Plan.
      vm.selectTab(0);
      await settle(tester, frames: 20);
      await tester.tap(find.byKey(const ValueKey('miniai_new_chat')));
      await settle(tester, frames: 10);
      expect(modeLabel(), 'Plan');
      await rec.hold(const Duration(seconds: 2));
      await shot('new chat in Plan');
      final minimum = Duration(milliseconds: (SmokeArtifacts.minimumVideoSeconds * 1000).ceil() + 500);
      if (rec.recorded < minimum) await rec.hold(minimum - rec.recorded);
      rec.save(name);
    } finally {
      PluginDataDir.override = null;
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  // Connect External Agents… writes the stdio bridge into
  // Antigravity's and Claude Code's config, and the written command really
  // reaches the running editor.
  testWidgets('MiniAI connects external agents', (tester) async {
    const name = 'MiniAI connects external agents';
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('miniai_connect_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/ConnectSmoke')..createSync(recursive: true);
    final home = Directory('${tempProjectsDir.path}/home')..createSync();
    PluginDataDir.override = Directory('${tempProjectsDir.path}/plugin_data');
    LuminaPluginMiniaiPlugin.connectEnvironment = {'USERPROFILE': home.path, 'HOME': home.path};
    Process? bridge;
    EditorViewModel? vmRef;
    try {
      const project = LuminaProject(projectName: 'ConnectSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/ConnectSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = vmRef = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      // The editor's own server, on an ephemeral port; its connection file
      // goes to this run's temp LuminaConfigDir.
      expect(await tester.runAsync(() => vm.mcpServer.start(port: 0)), isTrue);
      vm.extensionRegistry.registerPlugin(LuminaPluginMiniaiPlugin());

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png);
      }

      Future<void> io([int n = 15]) async {
        for (var i = 0; i < n; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
          await tester.pump(const Duration(milliseconds: 20));
        }
      }

      // 1. Plugins ▸ MiniAI ▸ Connect External Agents…
      await tester.tap(barItem('Plugins'));
      await settle(tester);
      await tester.tap(find.text('MiniAI'));
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Connect External Agents…').last);
      await io();
      expect(find.byKey(const ValueKey('miniai_connect_antigravity')), findsOneWidget);
      expect(find.byKey(const ValueKey('miniai_connect_claudeCode')), findsOneWidget);
      expect(find.text('Not connected'), findsNWidgets(2));
      await rec.hold(const Duration(seconds: 2));
      await shot('dialog');

      // 2. Connect both.
      await tester.tap(find.byKey(const ValueKey('miniai_connect_do_antigravity')));
      await io();
      await tester.tap(find.byKey(const ValueKey('miniai_connect_do_claudeCode')));
      await io();
      expect(find.text('Connected'), findsNWidgets(2));
      await rec.hold(const Duration(seconds: 2));
      await shot('connected');

      final antigravity = jsonDecode(File('${home.path}/.gemini/config/mcp_config.json').readAsStringSync()) as Map;
      final entry = (antigravity['mcpServers'] as Map)['lumina'] as Map;
      final claude = jsonDecode(File('${pDir.path}/.mcp.json').readAsStringSync()) as Map;
      expect(((claude['mcpServers'] as Map)['lumina'] as Map)['type'], 'stdio');

      // 3. Run exactly what Antigravity would run.
      final responses = <Map<String, Object?>>[];
      final result = await tester.runAsync(() async {
        final p = bridge = await Process.start(
          entry['command'] as String,
          [for (final a in entry['args'] as List) '$a'],
          environment: {LuminaConfigDir.environmentVariable: LuminaConfigDir.resolve().path},
        );
        final lines = p.stdout.transform(utf8.decoder).transform(const LineSplitter());
        final done = lines.take(2).forEach((l) => responses.add(Map<String, Object?>.from(jsonDecode(l) as Map)));
        p.stderr.drain<void>();
        p.stdin.writeln(jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-06-18',
            'capabilities': {},
            'clientInfo': {'name': 'antigravity-smoke', 'version': '1'},
          },
        }));
        p.stdin.writeln(jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}));
        p.stdin.writeln(jsonEncode({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'}));
        await p.stdin.flush();
        await done.timeout(const Duration(seconds: 60));
        return true;
      });
      expect(result, isTrue);
      final listed = ((responses.firstWhere((r) => r['id'] == 2)['result'] as Map)['tools'] as List).length;
      debugPrint('[miniai05_smoke] the bridge from mcp_config.json listed $listed tools');
      expect(listed, vm.mcpServer.tools.filtered().length);
      await io(5);
      await rec.hold(const Duration(seconds: 2));
      final minimum = Duration(milliseconds: (SmokeArtifacts.minimumVideoSeconds * 1000).ceil() + 500);
      if (rec.recorded < minimum) await rec.hold(minimum - rec.recorded);
      rec.save(name);
    } finally {
      bridge?.kill();
      LuminaPluginMiniaiPlugin.connectEnvironment = null;
      PluginDataDir.override = null;
      await tester.runAsync(() async => vmRef?.mcpServer.stop());
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  // The AI Assistant project settings (tool groups, rounds,
  // project notes) steer the local model; API Keys lists and removes a key.
  testWidgets('MiniAI project settings and API keys', (tester) async {
    const name = 'MiniAI project settings and API keys';
    final env = {...Platform.environment, 'FILAMENT_GPU': Platform.environment['FILAMENT_GPU'] ?? 'RTX PRO 2000'};
    final probe = LocalModelManager(root: LocalModelManager.defaultRoot(env), environment: env);
    final installed = probe.isInstalled();
    probe.dispose();
    if (!installed) {
      markTestSkipped('MiniCPM5 / llama-server not installed in ${LocalModelManager.defaultRoot(env)}');
      return;
    }
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('miniai_m06_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/NotesSmoke')..createSync(recursive: true);
    PluginDataDir.override = Directory('${tempProjectsDir.path}/plugin_data');
    LuminaPluginMiniaiPlugin? plugin;
    try {
      const project = LuminaProject(projectName: 'NotesSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      final manifest = File('${pDir.path}/NotesSmoke.lmproject')..writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      plugin = LuminaPluginMiniaiPlugin();
      vm.extensionRegistry.registerPlugin(plugin);
      final c = plugin.controller!;

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png);
      }

      Future<void> waitFor(bool Function() done, {Duration max = const Duration(minutes: 2)}) async {
        final sw = Stopwatch()..start();
        while (!done() && sw.elapsed < max) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
          await tester.pump(const Duration(milliseconds: 20));
          if (sw.elapsed.inMilliseconds % 1000 < 200) await rec.capture();
        }
        expect(done(), isTrue, reason: 'timed out after $max');
      }

      // 1. Project Settings ▸ AI Assistant: no `pie`, 3 rounds, a note → Apply.
      await tester.tap(find.text('Edit').first);
      await settle(tester, frames: 10);
      await tester.tap(find.text('Project Settings...').last);
      await waitFor(() => find.byKey(const ValueKey('project_settings_nav_plugins_header')).evaluate().isNotEmpty, max: const Duration(seconds: 10));
      await tester.tap(find.byKey(ValueKey('project_settings_nav_${ProjectSettingsViewModel.pluginCategoryId('lumina_plugin_miniai', 'miniai')}')));
      await settle(tester, frames: 10);
      await tester.tap(find.byKey(const ValueKey('miniai_settings_group_pie')));
      await settle(tester, frames: 5);
      await tester.tap(find.byKey(const ValueKey('miniai_settings_max_rounds')));
      await tester.enterText(find.byKey(const ValueKey('miniai_settings_max_rounds')), '3');
      await tester.tap(find.byKey(const ValueKey('miniai_settings_notes')).last);
      await tester.enterText(find.byKey(const ValueKey('miniai_settings_notes')).last, 'Answer in one word.');
      await settle(tester, frames: 5);
      await rec.hold(const Duration(seconds: 2));
      await shot('AI Assistant settings');
      await tester.tap(find.byKey(const ValueKey('project_settings_apply')));
      await waitFor(() => (jsonDecode(manifest.readAsStringSync()) as Map)['plugin_settings'] != null, max: const Duration(seconds: 10));
      expect((jsonDecode(manifest.readAsStringSync()) as Map)['plugin_settings'], {
        'lumina_plugin_miniai': {
          'disabledToolGroups': ['pie'],
          'maxRounds': 3,
          'projectNotes': 'Answer in one word.',
        },
      });

      // 2. The local model answers in one word.
      vm.selectTab(0);
      await settle(tester, frames: 20);
      if (find.byKey(const ValueKey('miniai_local_start')).evaluate().isEmpty) {
        await tester.tap(find.byKey(const ValueKey('slot_button_lumina_plugin_miniai.ai')));
        await settle(tester, frames: 20);
      }
      await tester.tap(find.byKey(const ValueKey('miniai_local_start')));
      await waitFor(() => c.local.status == LocalModelStatus.ready || c.local.status == LocalModelStatus.failed);
      expect(c.local.status, LocalModelStatus.ready, reason: c.local.message);
      await waitFor(() => c.settings.selected?.id == MiniAiController.localProviderId, max: const Duration(seconds: 10));
      await settle(tester, frames: 10);
      await tester.tap(find.byKey(const ValueKey('miniai_message')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('miniai_message')), 'What colour is the sky on a clear day?');
      await tester.tap(find.byKey(const ValueKey('miniai_send')));
      await waitFor(() => !c.running && c.chat.items.whereType<AssistantItem>().isNotEmpty);
      final answer = c.chat.items.whereType<AssistantItem>().last.text.toString().trim();
      debugPrint('[miniai06_smoke] answer: "$answer"');
      // The notes reach the model's instructions (deterministic); a 2B
      // model follows "one word" loosely, so the answer is only required
      // to lead with it.
      expect(c.chat.history.first.content, endsWith('<<<\nAnswer in one word.\n>>>'));
      expect(answer.toLowerCase(), startsWith('blue'), reason: answer);
      await settle(tester, frames: 10);
      await rec.hold(const Duration(seconds: 2));
      await shot('one-word answer');

      // 3. API Keys: a stored key is listed masked and removed.
      await tester.runAsync(() => c.settings.save(
            const ProviderConfig(id: 'team_cloud', name: 'Team cloud', baseUrl: 'https://api.example.com/v1', model: 'gpt'),
            apiKey: 'sk-smoke-0123456789wxyz',
          ));
      await tester.tap(barItem('Plugins'));
      await settle(tester);
      await tester.tap(find.text('MiniAI'));
      await settle(tester);
      await tester.tap(find.text('API Keys…').last);
      await settle(tester, frames: 15);
      expect(find.text('Stored · sk-…wxyz'), findsOneWidget);
      await rec.hold(const Duration(seconds: 2));
      await shot('API keys');
      await tester.tap(find.byKey(const ValueKey('miniai_key_remove_team_cloud')));
      await waitFor(() => c.settings.storedKeys.isEmpty, max: const Duration(seconds: 10));
      await settle(tester, frames: 10);
      expect(find.byKey(const ValueKey('miniai_key_remove_team_cloud')), findsNothing);
      expect(manifest.readAsStringSync(), isNot(contains('sk-smoke')));
      await rec.hold(const Duration(seconds: 2));
      await shot('key removed');
      await tester.runAsync(() => vm.shutdownPlugins(exiting: true));
      final minimum = Duration(milliseconds: (SmokeArtifacts.minimumVideoSeconds * 1000).ceil() + 500);
      if (rec.recorded < minimum) await rec.hold(minimum - rec.recorded);
      rec.save(name);
    } finally {
      PluginDataDir.override = null;
      final pid = plugin?.controller?.local.pid;
      if (pid != null) await tester.runAsync(() => Process.run(Platform.isWindows ? 'taskkill' : 'kill', Platform.isWindows ? ['/T', '/F', '/PID', '$pid'] : ['-9', '$pid']));
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  // A turn that placed a barrel is taken back with one click, and
  // only while it is the newest step.
  testWidgets('MiniAI undo this turn', (tester) async {
    const barrel = 'Props/Barrels/fuel_barrel_red.glb';
    const name = 'MiniAI undo this turn';
    final env = {...Platform.environment, 'FILAMENT_GPU': Platform.environment['FILAMENT_GPU'] ?? 'RTX PRO 2000'};
    final probe = LocalModelManager(root: LocalModelManager.defaultRoot(env), environment: env);
    final installed = probe.isInstalled();
    probe.dispose();
    if (!installed) {
      markTestSkipped('MiniCPM5 / llama-server not installed in ${LocalModelManager.defaultRoot(env)}');
      return;
    }
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('miniai_undo_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/UndoSmoke')..createSync(recursive: true);
    PluginDataDir.override = Directory('${tempProjectsDir.path}/plugin_data');
    LuminaPluginMiniaiPlugin? plugin;
    try {
      const project = LuminaProject(projectName: 'UndoSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/UndoSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrel'));
      vm.refreshAssets();
      final asset = vm.realAssets.firstWhere((a) => a.fileName == 'fuel_barrel_red.lmas' && a.type == AssetType.filamesh);
      plugin = LuminaPluginMiniaiPlugin();
      vm.extensionRegistry.registerPlugin(plugin);
      final c = plugin.controller!;

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png, usedAssets: const [barrel]);
      }

      Future<void> waitFor(bool Function() done, {Duration max = const Duration(minutes: 2)}) async {
        final sw = Stopwatch()..start();
        while (!done() && sw.elapsed < max) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
          await tester.pump(const Duration(milliseconds: 20));
          if (sw.elapsed.inMilliseconds % 1000 < 200) await rec.capture();
        }
        expect(done(), isTrue, reason: 'timed out after $max');
      }

      // The local model, Auto mode.
      await tester.tap(find.byKey(const ValueKey('slot_button_lumina_plugin_miniai.ai')));
      await settle(tester, frames: 20);
      await tester.tap(find.byKey(const ValueKey('miniai_local_start')));
      await waitFor(() => c.local.status == LocalModelStatus.ready || c.local.status == LocalModelStatus.failed);
      expect(c.local.status, LocalModelStatus.ready, reason: c.local.message);
      await waitFor(() => c.settings.selected?.id == MiniAiController.localProviderId, max: const Duration(seconds: 10));
      c.mode = ApprovalMode.auto;
      await settle(tester, frames: 10);

      // 1. Place a barrel.
      final before = vm.actors.length;
      await tester.tap(find.byKey(const ValueKey('miniai_message')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('miniai_message')), 'Place the asset ${asset.relativePath} once in the level at [0, 0, 0].');
      await tester.tap(find.byKey(const ValueKey('miniai_send')));
      await waitFor(() => !c.running && c.chat.turns.isNotEmpty);
      for (var i = 0; i < 40 && vm.actors.skip(before).any((a) => a.meshData == null); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      final turn = c.chat.turns.single;
      debugPrint('[miniai07_smoke] placed ${vm.actors.length - before}; scene step ${turn.sceneStep}; top "${vm.transactions.undoLabel}"');
      expect(vm.actors.length, greaterThan(before), reason: 'the model placed the barrel');
      expect(turn.sceneStep, isTrue);
      vm.frameLevelBounds();
      await settle(tester, frames: 20);
      expect(find.byKey(ValueKey('miniai_undo_turn_${turn.id}')), findsOneWidget);
      await rec.hold(const Duration(seconds: 2));
      await shot('barrel placed');

      // 2. Undo this turn.
      await tester.tap(find.byKey(ValueKey('miniai_undo_turn_${turn.id}')));
      await waitFor(() => turn.undone, max: const Duration(seconds: 10));
      await settle(tester, frames: 20);
      expect(vm.actors.length, before);
      expect(find.text('Undone: 1 scene step.'), findsOneWidget);
      expect(find.byKey(ValueKey('miniai_turn_undone_${turn.id}')), findsOneWidget);
      await rec.hold(const Duration(seconds: 3));
      await shot('turn undone');
      await tester.runAsync(() => vm.shutdownPlugins(exiting: true));
      final minimum = Duration(milliseconds: (SmokeArtifacts.minimumVideoSeconds * 1000).ceil() + 500);
      if (rec.recorded < minimum) await rec.hold(minimum - rec.recorded);
      rec.save(name, usedAssets: const [barrel]);
    } finally {
      PluginDataDir.override = null;
      final pid = plugin?.controller?.local.pid;
      if (pid != null) await tester.runAsync(() => Process.run(Platform.isWindows ? 'taskkill' : 'kill', Platform.isWindows ? ['/T', '/F', '/PID', '$pid'] : ['-9', '$pid']));
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  // MiniAI on the user's installed Claude Code CLI: Model provider… finds
  // it, `/` lists its commands, and a tiny prompt makes it call one
  // read-only editor tool through the editor's MCP server (one cheap model
  // call; skipped without a logged-in `claude`).
  testWidgets('MiniAI Claude Code provider', (tester) async {
    const barrel = 'Props/Barrels/fuel_barrel_red.glb';
    const name = 'MiniAI Claude Code provider';
    final install = await tester.runAsync(() => const ClaudeCodeCli().detect());
    if (install == null || !install.ready) {
      markTestSkipped('claude is not installed or not logged in (${install?.path ?? 'not found'})');
      return;
    }
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('miniai_cc_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/ClaudeSmoke')..createSync(recursive: true);
    PluginDataDir.override = Directory('${tempProjectsDir.path}/plugin_data');
    EditorViewModel? vmRef;
    LuminaPluginMiniaiPlugin? plugin;
    try {
      const project = LuminaProject(projectName: 'ClaudeSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/ClaudeSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      // A project command, so the list shows one next to the built-ins.
      File('${pDir.path}/.claude/commands/barrels.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('---\ndescription: Count the barrels in the level\n---\nCount the barrels in the open level with list_actors.\n');
      final vm = vmRef = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrel'));
      vm.refreshAssets();
      final asset = vm.realAssets.firstWhere((a) => a.fileName == 'fuel_barrel_red.lmas' && a.type == AssetType.filamesh);
      // Claude Code reaches the editor over HTTP through the stdio bridge.
      expect(await tester.runAsync(() => vm.mcpServer.start(port: 0)), isTrue);
      plugin = LuminaPluginMiniaiPlugin();
      vm.extensionRegistry.registerPlugin(plugin);
      final c = plugin.controller!;
      final placed = await tester.runAsync(
          () => c.mcp.callTool('spawn_actor_from_asset', {'asset': asset.relativePath, 'location': [0, 0, 0]}, caller: 'smoke'));
      expect(placed!.isError, isFalse, reason: placed.content.map((x) => x['text']).join());
      for (var i = 0; i < 40 && vm.actors.last.meshData == null; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      vm.frameLevelBounds();
      await settle(tester, frames: 20);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png, usedAssets: const [barrel]);
      }

      Future<void> waitFor(bool Function() done, {Duration max = const Duration(minutes: 2)}) async {
        final sw = Stopwatch()..start();
        while (!done() && sw.elapsed < max) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
          await tester.pump(const Duration(milliseconds: 20));
          if (sw.elapsed.inMilliseconds % 1000 < 200) await rec.capture();
        }
        expect(done(), isTrue, reason: 'timed out after $max');
      }

      // 1. Model provider… ▸ Claude Code: detected, Haiku, Use Claude Code.
      await tester.tap(find.byKey(const ValueKey('slot_button_lumina_plugin_miniai.ai')));
      await settle(tester, frames: 20);
      await tester.tap(find.byKey(const ValueKey('miniai_model_chip')));
      await settle(tester, frames: 10);
      Finder use() => find.byKey(const ValueKey('miniai_claude_use'));
      await waitFor(() => use().evaluate().isNotEmpty && tester.widget<PrimaryButton>(use()).onPressed != null, max: const Duration(seconds: 90));
      expect(tester.widget<Text>(find.byKey(const ValueKey('miniai_claude_status'))).data, contains('Logged in'));
      await tester.tap(find.byKey(const ValueKey('miniai_claude_model')));
      await settle(tester, frames: 10);
      await tester.tap(find.textContaining('Haiku').last);
      await settle(tester, frames: 10);
      await rec.hold(const Duration(seconds: 2));
      await shot('provider');
      await tester.tap(use());
      await waitFor(() => c.usesClaudeCode, max: const Duration(seconds: 10));
      await settle(tester, frames: 10);
      expect(find.byKey(const ValueKey('miniai_claude_state')), findsOneWidget);

      // 2. `/` lists the CLI's commands (no model call).
      await tester.tap(find.byKey(const ValueKey('miniai_message')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('miniai_message')), '/');
      await waitFor(() => c.claudeCommands.isNotEmpty || c.claudeError != null, max: const Duration(seconds: 90));
      expect(c.claudeError, isNull);
      await settle(tester, frames: 10);
      expect(find.byKey(const ValueKey('miniai_slash_menu')), findsOneWidget);
      expect(c.claudeCommands.map((x) => x.name), containsAll(['barrels', 'compact', 'context']));
      await tester.enterText(find.byKey(const ValueKey('miniai_message')), '/ba');
      await settle(tester, frames: 10);
      expect(find.byKey(const ValueKey('miniai_slash_barrels')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('miniai_message')), '/');
      await settle(tester, frames: 10);
      await rec.hold(const Duration(seconds: 3));
      await shot('slash commands');

      // 3. A tiny prompt: Claude Code calls list_actors through the editor.
      await tester.enterText(find.byKey(const ValueKey('miniai_message')),
          'Call the list_actors tool of the lumina MCP server once, then say in one short sentence how many actors the level has.');
      await tester.tap(find.byKey(const ValueKey('miniai_send')));
      await waitFor(() => !c.running && c.chat.turns.isNotEmpty, max: const Duration(minutes: 3));
      await settle(tester, frames: 20);
      final cards = c.chat.items.whereType<ToolCallItem>().where((i) => i.call.name == 'list_actors').toList();
      debugPrint('[miniai08_smoke] ${c.claudeState}; ${c.claudeUsage}; notes: '
          '${c.chat.items.whereType<NoteItem>().map((n) => n.text).join(' | ')}');
      expect(cards, isNotEmpty, reason: 'Claude Code called list_actors');
      expect(cards.last.status, ToolCallStatus.done);
      expect(cards.last.risk, McpToolRisk.readOnly);
      expect(cards.last.result, contains('fuel_barrel_red'));
      expect(c.lastTurnFailed, isFalse);
      expect(c.claudeUsage, contains('this session'));
      await tester.tap(find.text('list_actors').last);
      await settle(tester, frames: 10);
      await rec.hold(const Duration(seconds: 3));
      await shot('list_actors tool card');
      // The open card's arguments and result: coloured JSON in boxes at most
      // 200 px tall that scroll.
      final result = find.byKey(ValueKey('miniai_tool_result_${cards.last.call.id}'));
      expect(result, findsOneWidget);
      expect(tester.getSize(result).height, lessThanOrEqualTo(200));

      // 4. Claude Code asks a multiple-choice question (AskUserQuestion): the
      // card shows it, a click answers it, and the answer reaches the model.
      await tester.tap(find.byKey(const ValueKey('miniai_message')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('miniai_message')),
          'Use the AskUserQuestion tool exactly once to ask me which barrel colour I prefer, with the options Red and Blue. '
          'Then reply with only the colour I chose.');
      final sentBefore = c.chat.messageCount;
      await tester.tap(find.byKey(const ValueKey('miniai_send')));
      // The turn has started (its message is in the chat) and asks, or ended.
      await waitFor(() => c.chat.messageCount > sentBefore && (c.chat.pendingQuestions.isNotEmpty || !c.running), max: const Duration(minutes: 3));
      expect(c.chat.pendingQuestions, hasLength(1), reason: 'Claude Code asked through AskUserQuestion');
      final asked = c.chat.pendingQuestions.single;
      await settle(tester, frames: 10);
      final blue = find.byKey(ValueKey('miniai_question_option_${asked.call.id}_0_1'));
      await tester.ensureVisible(blue);
      await settle(tester, frames: 5);
      await rec.hold(const Duration(seconds: 2));
      await shot('AskUserQuestion card');
      await tester.tap(blue);
      await settle(tester, frames: 5);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.byKey(ValueKey('miniai_question_answer_${asked.call.id}')));
      await waitFor(() => !c.running, max: const Duration(minutes: 3));
      await settle(tester, frames: 20);
      expect(asked.status, ToolCallStatus.done);
      expect(asked.answers?.values.single, 'Blue');
      final reply = c.chat.items.whereType<AssistantItem>().last.text.toString();
      expect(reply, contains('Blue'));
      await rec.hold(const Duration(seconds: 3));
      await shot('AskUserQuestion answered');

      // 5. The answer's Markdown is styled: a heading, bold, inline code and
      // a bullet list, not raw markers.
      await tester.tap(find.byKey(const ValueKey('miniai_message')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('miniai_message')),
          'Without calling any tool, reply in Markdown only: a "## Barrel" heading, then a bullet list of two items: '
          '"**Colour:** Blue" and "**Asset:** `fuel_barrel_red`".');
      final mdBefore = c.chat.messageCount;
      await tester.tap(find.byKey(const ValueKey('miniai_send')));
      await waitFor(() => c.chat.messageCount > mdBefore && !c.running, max: const Duration(minutes: 3));
      await settle(tester, frames: 20);
      final mdIndex = c.chat.items.lastIndexWhere((i) => i is AssistantItem);
      final mdAnswer = find.byKey(ValueKey('miniai_assistant_$mdIndex'));
      await tester.ensureVisible(mdAnswer);
      await settle(tester, frames: 5);
      String plain(Finder f) => tester
          .widgetList<SelectableText>(find.descendant(of: f, matching: find.byType(SelectableText)))
          .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
          .join('\n');
      final shown = plain(mdAnswer);
      debugPrint('[miniai14_smoke] markdown answer: ${c.chat.items[mdIndex] is AssistantItem ? (c.chat.items[mdIndex] as AssistantItem).text : ''}');
      expect(shown, contains('Barrel'));
      expect(shown, contains('fuel_barrel_red'));
      expect(shown, isNot(contains('**')), reason: 'bold markers are styled away');
      expect(shown, isNot(contains('`')), reason: 'code markers are styled away');
      expect(find.descendant(of: mdAnswer, matching: find.text('•')), findsNWidgets(2));
      await rec.hold(const Duration(seconds: 3));
      await shot('Markdown answer');

      // 6. The engine guide: the model reads a topic with get_lumina_guide
      // through the editor and answers with a fact from it.
      await tester.tap(find.byKey(const ValueKey('miniai_message')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('miniai_message')),
          'Call the get_lumina_guide tool of the lumina MCP server once with topic "lights", then answer in one short '
          'sentence from what it says: in which unit is a point light\'s intensity given?');
      final guideBefore = c.chat.messageCount;
      await tester.tap(find.byKey(const ValueKey('miniai_send')));
      await waitFor(() => c.chat.messageCount > guideBefore && !c.running, max: const Duration(minutes: 3));
      await settle(tester, frames: 20);
      final guideCards = c.chat.items.whereType<ToolCallItem>().where((i) => i.call.name == 'get_lumina_guide').toList();
      expect(guideCards, isNotEmpty, reason: 'Claude Code called get_lumina_guide');
      expect(guideCards.last.status, ToolCallStatus.done);
      expect(guideCards.last.risk, McpToolRisk.readOnly);
      expect(guideCards.last.result, contains('lumens'));
      final guideAnswer = c.chat.items.whereType<AssistantItem>().last.text.toString();
      debugPrint('[miniai15_smoke] guide answer: $guideAnswer');
      expect(guideAnswer.toLowerCase(), contains('lumen'), reason: 'the answer uses what the guide says');
      await tester.tap(find.text('get_lumina_guide').last);
      await settle(tester, frames: 10);
      await rec.hold(const Duration(seconds: 3));
      await shot('Lumina guide tool card');
      await tester.runAsync(() => vm.shutdownPlugins(exiting: true));
      final minimum = Duration(milliseconds: (SmokeArtifacts.minimumVideoSeconds * 1000).ceil() + 500);
      if (rec.recorded < minimum) await rec.hold(minimum - rec.recorded);
      rec.save(name, usedAssets: const [barrel]);
    } finally {
      PluginDataDir.override = null;
      await tester.runAsync(() async => plugin?.controller?.claude.close());
      await tester.runAsync(() async => vmRef?.mcpServer.stop());
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  // The chat's context and feedback on a real editor with the local model on
  // GPU 1: the selection chip for a selected wall, the @ list over the real
  // project, the Thinking row expanded while MiniCPM5 streams its reasoning,
  // a viewport_screenshot tool card with its thumbnail (enlarged), and the
  // "Switch to Ask" chip after a Plan-mode request for a change.
  testWidgets('MiniAI chat context', (tester) async {
    const barrel = 'Props/Barrels/fuel_barrel_red.glb';
    const name = 'MiniAI chat context';
    final env = {...Platform.environment, 'FILAMENT_GPU': Platform.environment['FILAMENT_GPU'] ?? 'RTX PRO 2000'};
    final probe = LocalModelManager(root: LocalModelManager.defaultRoot(env), environment: env);
    final installed = probe.isInstalled();
    probe.dispose();
    if (!installed) {
      markTestSkipped('MiniCPM5 / llama-server not installed in ${LocalModelManager.defaultRoot(env)}');
      return;
    }
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // The test window goes on DISPLAY1 (the non-Samsung monitor).
    if (Platform.isWindows) await tester.runAsync(() => placeOnDisplay1(pid, width: 1920, height: 1200).catchError((_) => null));
    final tempProjectsDir = Directory.systemTemp.createTempSync('miniai_ctx_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/ContextSmoke')..createSync(recursive: true);
    PluginDataDir.override = Directory('${tempProjectsDir.path}/plugin_data');
    EditorViewModel? vmRef;
    LuminaPluginMiniaiPlugin? plugin;
    try {
      const project = LuminaProject(projectName: 'ContextSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/ContextSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = vmRef = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrel'));
      vm.refreshAssets();
      final asset = vm.realAssets.firstWhere((a) => a.fileName == 'fuel_barrel_red.lmas' && a.type == AssetType.filamesh);
      plugin = LuminaPluginMiniaiPlugin();
      vm.extensionRegistry.registerPlugin(plugin);
      final c = plugin.controller!;
      Future<Map<String, Object?>> call(String tool, Map<String, Object?> args) async {
        final r = await tester.runAsync(() => c.mcp.callTool(tool, args, caller: 'smoke'));
        expect(r!.isError, isFalse, reason: r.content.map((x) => x['text']).join());
        return Map<String, Object?>.from(r.structuredContent ?? jsonDecode('${r.content.first['text']}') as Map);
      }

      await call('spawn_actor', {'type': 'Primitive', 'name': 'Divider_Wall', 'location': [0, 250, 150], 'scale': [6, 0.4, 3]});
      final wallId = vm.actors.firstWhere((a) => a.name == 'Divider_Wall').id;
      await call('spawn_actor_from_asset', {'asset': asset.relativePath, 'location': [0, 0, 0]});
      for (var i = 0; i < 40 && vm.actors.any((a) => a.meshAssetPath != null && a.meshData == null); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      vm.frameLevelBounds();
      await settle(tester, frames: 20);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png, usedAssets: const [barrel]);
      }

      Future<void> waitFor(bool Function() done, {Duration max = const Duration(minutes: 2), Duration step = const Duration(milliseconds: 150)}) async {
        final sw = Stopwatch()..start();
        while (!done() && sw.elapsed < max) {
          await tester.runAsync(() => Future<void>.delayed(step));
          await tester.pump(const Duration(milliseconds: 20));
          await rec.capture();
        }
        expect(done(), isTrue, reason: 'timed out after $max');
      }

      String? chip() {
        final f = find.byKey(const ValueKey('miniai_selection_label'));
        return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
      }

      // 1. The panel; the selected wall becomes the chip above the message box.
      await tester.tap(find.byKey(const ValueKey('slot_button_lumina_plugin_miniai.ai')));
      await settle(tester, frames: 20);
      await call('select_actors', {
        'ids': [wallId],
      });
      await waitFor(() => chip() == 'Divider_Wall · Primitive', max: const Duration(seconds: 10));
      await rec.hold(const Duration(seconds: 2));
      await shot('selection chip');

      // 2. The local model on GPU 1 becomes the provider.
      await tester.runAsync(() => c.local.start());
      await waitFor(() => c.local.status == LocalModelStatus.ready && c.settings.isConfigured, max: const Duration(minutes: 2));
      await settle(tester, frames: 10);

      // 3. @ lists the project's real content: the imported barrel first.
      await tester.tap(find.byKey(const ValueKey('miniai_message')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('miniai_message')), 'Put a copy of @fuel');
      await waitFor(() => find.byKey(const ValueKey('miniai_mention_asset_0')).evaluate().isNotEmpty, max: const Duration(seconds: 10));
      final first = find.byKey(const ValueKey('miniai_mention_asset_0'));
      expect(find.descendant(of: first, matching: find.text('fuel_barrel_red')), findsOneWidget);
      expect(find.descendant(of: first, matching: find.textContaining(asset.relativePath)), findsOneWidget);
      await rec.hold(const Duration(seconds: 2));
      await shot('at mention list');
      await tester.enterText(find.byKey(const ValueKey('miniai_message')), '');
      await tester.pump();

      // 4. A screenshot request: the Thinking row, opened while the model
      // reasons, then the tool card with its thumbnail.
      Future<void> ask(String text) async {
        // Focus the composer first: after a send the text input connection
        // stays with the old focus and enterText would type nowhere.
        await tester.tap(find.byKey(const ValueKey('miniai_message')));
        await tester.pump();
        await tester.enterText(find.byKey(const ValueKey('miniai_message')), text);
        await tester.pump();
        expect(tester.widget<TextField>(find.byKey(const ValueKey('miniai_message'))).controller?.text, text);
        final turns = c.chat.turns.length;
        await tester.tap(find.byKey(const ValueKey('miniai_send')));
        await tester.pump();
        await waitFor(() => c.chat.turns.length > turns, max: const Duration(seconds: 10), step: const Duration(milliseconds: 20));
      }

      bool thinking() => c.chat.items.whereType<AssistantItem>().any((a) => a.thinkingActive);
      var streamedShot = false;
      ToolCallItem? screenshotCard() =>
          c.chat.items.whereType<ToolCallItem>().where((i) => i.call.name == 'viewport_screenshot' && i.images.isNotEmpty).lastOrNull;
      for (var attempt = 0; attempt < 3 && screenshotCard() == null; attempt++) {
        await ask(attempt == 0
            ? 'Take a screenshot of the viewport with the viewport_screenshot tool, then say in one sentence what it shows.'
            : 'Call the viewport_screenshot tool now.');
        // Open the row of the item that thinks now, as soon as it shows, and
        // capture it while the reasoning still streams (each round of this
        // model thinks for about a second).
        final toggle = find.byKey(const ValueKey('miniai_thinking_toggle'));
        var opened = 0;
        while (c.running && !streamedShot) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
          await tester.pump(const Duration(milliseconds: 10));
          final rows = toggle.evaluate().length;
          if (thinking() && rows > opened) {
            opened = rows;
            await tester.tap(toggle.last);
            await tester.pump(const Duration(milliseconds: 10));
            await tester.pump(const Duration(milliseconds: 10));
            if (thinking()) {
              await shot('thinking row while streaming');
              streamedShot = true;
              debugPrint('[miniai_ctx_smoke] thinking row captured while streaming');
            }
          }
        }
        await waitFor(() => !c.running, max: const Duration(minutes: 3));
        await settle(tester, frames: 10);
      }
      String describe(ChatItem i) => switch (i) {
            ToolCallItem() => 'tool:${i.call.name}:${i.status.name}:${i.images.length}',
            AssistantItem() => 'assistant(${i.thinkingTook?.inMilliseconds} ms)',
            UserItem() => 'user',
            NoteItem() => 'note:${i.text}',
          };
      debugPrint('[miniai_ctx_smoke] items: ${c.chat.items.map(describe).join(', ')}');
      expect(streamedShot, isTrue, reason: 'MiniCPM5 streams reasoning');
      final card = screenshotCard();
      expect(card, isNotNull, reason: 'the model called viewport_screenshot');
      expect(find.text('Context: Divider_Wall · Primitive'), findsWidgets, reason: 'the selection went with the message');
      final thumb = find.byKey(ValueKey('miniai_tool_thumb_${card!.call.id}_0'));
      await tester.ensureVisible(thumb);
      await settle(tester, frames: 10);
      expect(thumb, findsOneWidget);
      expect(find.textContaining(RegExp(r'^Thought for \d+ s$')), findsWidgets);
      await rec.hold(const Duration(seconds: 2));
      await shot('screenshot tool card');
      await tester.tap(thumb);
      await settle(tester, frames: 15);
      expect(find.byKey(const ValueKey('miniai_image_dialog')), findsOneWidget);
      await rec.hold(const Duration(seconds: 2));
      await shot('screenshot enlarged');
      await tester.tap(find.byKey(const ValueKey('miniai_image_dialog_close')));
      await waitFor(() => find.byKey(const ValueKey('miniai_image_dialog')).evaluate().isEmpty, max: const Duration(seconds: 10));
      await settle(tester, frames: 30);

      // 5. Plan mode: a request to add something shows the one-click switch.
      c.mode = ApprovalMode.plan;
      await settle(tester, frames: 5);
      await ask('Sahneye bir varil ekle.');
      await waitFor(() => !c.running, max: const Duration(minutes: 3));
      await settle(tester, frames: 10);
      final turn = c.chat.turns.last;
      debugPrint('[miniai_ctx_smoke] plan turn: mode ${c.mode.name}, turns ${c.chat.turns.length}, blocked ${turn.planBlocked}; '
          'items: ${c.chat.items.skip(turn.userItemIndex).map(describe).join(', ')}');
      expect(turn.planBlocked, isNotEmpty);
      final hint = find.byKey(ValueKey('miniai_plan_hint_${turn.id}'));
      await tester.ensureVisible(hint);
      await settle(tester, frames: 10);
      expect(hint, findsOneWidget);
      await rec.hold(const Duration(seconds: 2));
      await shot('plan mode switch chip');
      await tester.tap(find.byKey(const ValueKey('miniai_plan_switch')));
      await settle(tester, frames: 10);
      expect(c.mode, ApprovalMode.ask);
      await rec.hold(const Duration(seconds: 1));

      final minimum = Duration(milliseconds: (SmokeArtifacts.minimumVideoSeconds * 1000).ceil() + 500);
      if (rec.recorded < minimum) await rec.hold(minimum - rec.recorded);
      rec.save(name, usedAssets: const [barrel]);
    } finally {
      PluginDataDir.override = null;
      await tester.runAsync(() async => plugin?.controller?.local.stop());
      await tester.runAsync(() async => vmRef?.shutdownPlugins(exiting: true));
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 15)));

  // Enabling a code plugin generates the project's own editor
  // host; the launcher builds it for real behind the splash, execs it, and a
  // project without its host asks before building.
  perProjectEditorScenario(binding, pcgProjectEditor);
  perProjectEditorScenario(binding, miniaiProjectEditor);

  plainProjectEditorScenario(binding);
  sourceCopyProjectEditorScenario(binding);
}

/// A project's editor builds from its own copy of the engine
/// source. A project created under "…/Lumina Projects/Source Game" (a path
/// with spaces, as a real one), a barrel placed and saved, then Open: the
/// splash first copies the Dart source into `.lumina/editor/` (Filament
/// linked), then builds from that copy, through a space-free alias on
/// Windows; the built editor opens the project, and a second Open is served
/// from the cache without copying again.
void sourceCopyProjectEditorScenario(IntegrationTestWidgetsFlutterBinding binding) {
  testWidgets('project editor builds from its own source copy', (tester) async {
    const name = 'project editor builds from its own source copy';
    final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';
    try {
      Process.runSync(flutter, ['--version'], runInShell: Platform.isWindows);
    } on ProcessException {
      markTestSkipped('flutter is not on PATH: the project editor build needs the Flutter toolchain');
      return;
    }
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/dented_barrel.glb');
    expect(barrel.existsSync(), isTrue, reason: 'test-assets must hold the barrel');
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final temp = Directory.systemTemp.createTempSync('sc_');
    final location = Directory('${temp.path}/Lumina Projects')..createSync();
    final originalHandOff = EditorHandOff.instance;
    Process? projectEditor;
    try {
      final cacheBase = Directory('${temp.path}/cache')..createSync();
      final pubCache = Platform.environment['PUB_CACHE'] ??
          (Platform.isWindows ? '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache' : '${Platform.environment['HOME']}/.pub-cache');
      final buildEnv = Platform.isWindows ? {'LOCALAPPDATA': cacheBase.path, 'PUB_CACHE': pubCache} : {'HOME': cacheBase.path, 'PUB_CACHE': pubCache};
      final cache = EditorBuildCache(
        root: Directory(EditorBuildCache.defaultRoot(environment: buildEnv).path),
        nativeRoot: Directory('${EditorBuildCache.cacheBase(environment: buildEnv)}/native'),
      );
      final starts = <List<String>>[];
      EditorHandOff.instance = EditorHandOff(startDetached: (exe, args) async => starts.add([exe, ...args]), exitApp: (_) {});
      EditorBuildSplash.manageNativeWindow = false;

      // 1. Create the project through the launcher's create flow.
      final launcherConfig = Directory('${temp.path}/config')..createSync();
      final resolver = ProjectEditorResolver(cache: cache);
      final repo = ProjectRepository(configDir: launcherConfig, processRunner: offlineScaffoldRunner());
      late LauncherViewModel launcher;
      await tester.runAsync(() async => launcher = LauncherViewModel(
            configDir: launcherConfig,
            projectRepo: repo,
            editorResolver: resolver,
            buildServiceFactory: (r) => EditorBuildService(
              engineRoot: r.engineRoot,
              cache: r.cache,
              generator: r.generator,
              mode: r.mode,
              flutterInfo: r.flutterInfo,
              environment: buildEnv,
              hostAliasRoot: Directory('${temp.path}/hosts'),
            ),
          ));
      final create = CreateProjectViewModel(launcherVM: launcher, projectRepo: repo)
        ..updateName('source_game')
        ..updateLocation(location.path);
      await tester.runAsync(create.createProject);
      expect(create.creationError, isNull);
      final pDir = '${location.path}/source_game';
      final host = '$pDir/.lumina/editor';
      expect(File('$host/pubspec.yaml').readAsStringSync(), contains('  lumina_ui:\n    path: lumina_ui\n'),
          reason: 'the host points at the copy beside it');
      expect(Directory('$host/lumina_ui').existsSync(), isFalse, reason: 'the copy is made by the first build, not at creation');

      // 2. A barrel in its level (the stock editor, saved to disk).
      final project = (await tester.runAsync(() => repo.loadProject('$pDir/source_game.lmproject')))!;
      final editor = EditorViewModel(initialProject: project, projectLocation: location.path, enableTimers: false);
      await tester.runAsync(() async {
        await editor.ensureDefaultLevelAssets();
        await editor.processImportPipeline(sourceFilePath: barrel.path);
        editor.refreshAssets();
        final mesh = editor.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('dented_barrel'));
        await editor.spawnActorFromAsset(mesh, location: [0.0, 0.0, 0.0]);
        await editor.saveLevelAndGenerateCode();
      });
      final barrelName = editor.actors.last.name;
      editor.dispose();

      // 3. Open: the splash copies the source, then builds from the copy.
      final decision = await tester.runAsync(() => resolver.resolve(pDir));
      expect((decision as NeedsBuild).reason, 'the editor source is not in the project yet (about 650 MB will be copied)');
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: LauncherView(viewModel: launcher, initialProjectDir: pDir)),
      ));
      for (var i = 0; i < 600 && find.byType(EditorBuildSplash).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(find.byType(EditorBuildSplash), findsOneWidget);
      final build = tester.widget<EditorBuildSplash>(find.byType(EditorBuildSplash)).viewModel;
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String label) async => SmokeArtifacts.saveScreenshot('$name: $label',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
          usedAssets: [barrel.path]);

      final started = Stopwatch()..start();
      var copyShot = false, nativeShot = false;
      var lastCapture = Duration.zero;
      final phases = <EditorBuildPhase>[];
      while (build.state == EditorBuildSplashState.running && started.elapsed < const Duration(minutes: 45)) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump();
        if (phases.isEmpty || phases.last != build.phase) phases.add(build.phase);
        if (!copyShot && build.phase == EditorBuildPhase.copyingSource && build.percent >= 4) {
          copyShot = true;
          expect(build.statusText, contains('Copying editor source'));
          // At once: the copy is over in seconds.
          await shot('splash, copying the editor source');
          await rec.hold(const Duration(seconds: 1));
        }
        if (!nativeShot && build.phase == EditorBuildPhase.buildingNativeAssets) {
          nativeShot = true;
          await rec.hold(const Duration(seconds: 3));
          await shot('splash, building from the copy');
        }
        if (started.elapsed - lastCapture > const Duration(seconds: 2)) {
          lastCapture = started.elapsed;
          await rec.capture();
        }
      }
      expect(build.state, EditorBuildSplashState.succeeded, reason: build.logTail.join('\n'));
      expect(phases.first, EditorBuildPhase.copyingSource);
      expect(copyShot, isTrue, reason: 'the copy phase showed on the splash');
      final outcome = build.outcome as EditorBuildSucceeded;
      debugPrint('[plugins11_smoke] first build ${started.elapsed.inSeconds}s -> ${outcome.entry.executable}');
      // The finished splash, long enough for the video's minimum (the build's
      // frames are sampled every 2 s, so their count varies with its speed).
      final minimum = Duration(milliseconds: (SmokeArtifacts.minimumVideoSeconds * 1000).ceil() + 500);
      await rec.hold(rec.recorded < minimum - const Duration(seconds: 3) ? minimum - rec.recorded : const Duration(seconds: 3));
      rec.save(name, usedAssets: [barrel.path]);

      // The copy is in the project; Filament is linked, not copied.
      for (final f in ['lumina_ui/lib/main.dart', 'lumina/lib/lumina.dart', 'flutter_filament/hook/build.dart', 'lumina_editor_api/pubspec.yaml']) {
        expect(File('$host/$f').existsSync(), isTrue, reason: f);
      }
      expect(FileSystemEntity.isLinkSync('$host/filament'), isTrue);
      expect(FileSystemEntity.isLinkSync('$host/lumina_ui'), isFalse, reason: 'a real copy, not a link');
      expect(Directory('$host/lumina_ui/test').existsSync(), isFalse, reason: 'tests are not copied');
      // The engine lock travels with the copy, and the host resolved every
      // hosted package at its version, whatever pub.dev published since.
      expect(File('$host/${EditorSourceVendorService.engineLockFileName}').existsSync(), isTrue);
      expect(resolver.generator.movedFromEngineLock(host), isEmpty);
      final log = File(outcome.logPath!).readAsStringSync();
      expect(log, contains('Copying the editor source'));
      if (Platform.isWindows) expect(log, contains('Building through'), reason: 'the space-free alias');
      expect(starts.last.first, outcome.entry.executable);
      expect(starts.last.sublist(1, 3), ['--project', pDir]);

      // 4. The project editor opens the project (its MCP server answers).
      final editorConfig = Directory('${temp.path}/editor_config')..createSync();
      final port = await tester.runAsync(() async {
        final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final p = s.port;
        await s.close();
        return p;
      });
      File('${editorConfig.path}/mcp_server_settings.json').writeAsStringSync(jsonEncode({'enabled': true, 'port': port}));
      projectEditor = await tester.runAsync(() => Process.start(outcome.entry.executable, starts.last.sublist(1),
          environment: {'LUMINA_CONFIG_DIR': editorConfig.path, 'FLUTTER_TEST': ''}, mode: ProcessStartMode.detached));
      final connection = File('${editorConfig.path}/mcp_server.json');
      for (var i = 0; i < 240 && !connection.existsSync(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      }
      expect(connection.existsSync(), isTrue, reason: 'the project editor opened the project and started its MCP server');
      final info = jsonDecode(connection.readAsStringSync()) as Map<String, dynamic>;
      final client = McpTestClient(info['url'] as String, info['token'] as String);
      await tester.runAsync(() => client.handshake());
      final projectInfo = await tester.runAsync(() => client.callTool('project_info'));
      expect(projectInfo!.data['project_name'], 'source_game');
      final actors = await tester.runAsync(() => client.callTool('list_actors'));
      expect(actors!.text, contains(barrelName), reason: 'the saved level, barrel included');
      // The engine guide ships in the built editor: lumina_ui is a dependency
      // of the host there, so its assets are keyed packages/lumina_ui/….
      final guide = await tester.runAsync(() => client.callTool('get_lumina_guide', {'topic': 'blueprints'}));
      expect(guide!.isError, isFalse, reason: guide.text);
      expect(guide.text, startsWith('# Blueprints'));
      debugPrint('[plugins11_smoke] get_lumina_guide blueprints: ${guide.text.length} chars, '
          '"${guide.text.split('\n').first}"');
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
      final screenshot = await tester.runAsync(() => client.callTool('viewport_screenshot'));
      final image = screenshot!.content.firstWhere((c) => c['type'] == 'image')['data'] as String;
      SmokeArtifacts.saveScreenshot('$name: project editor viewport', base64Decode(image), usedAssets: [barrel.path]);
      client.close();

      // 5. A second Open: cached, and the copy is not made again.
      final stamp = File('$host/${EditorSourceVendorService.stampFileName}').readAsStringSync();
      late ProjectEditorDecision again;
      await tester.runAsync(() async => again = await resolver.resolve(pDir));
      expect(again, isA<ExecCached>());
      expect(File('$host/${EditorSourceVendorService.stampFileName}').readAsStringSync(), stamp);
      await tester.runAsync(() async => launcher.dispose());
    } finally {
      EditorHandOff.instance = originalHandOff;
      EditorBuildSplash.manageNativeWindow = true;
      if (projectEditor != null) await tester.runAsync(() => killProcessTree(projectEditor!.pid));
      await tester.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          try {
            if (temp.existsSync()) temp.deleteSync(recursive: true);
            break;
          } on FileSystemException {
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
        }
      });
    }
  }, timeout: const Timeout(Duration(minutes: 60)));
}

/// A project with no code plugins opens in its own project
/// editor. Created through the launcher's create flow (its host is written at
/// once), a barrel from test-assets placed and saved, then Open: the splash
/// builds `<project>_editor` for real, the launcher hands off, the built
/// editor opens the project (checked over its MCP server), and a second Open
/// is served from the cache.
void plainProjectEditorScenario(IntegrationTestWidgetsFlutterBinding binding) {
  testWidgets('Plugins Smoke Scenario: a plugin-less project opens in its own project editor', (tester) async {
    const name = 'Plugins Smoke Scenario: a plugin-less project opens in its own project editor';
    final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';
    try {
      Process.runSync(flutter, ['--version'], runInShell: Platform.isWindows);
    } on ProcessException {
      markTestSkipped('flutter is not on PATH: the project editor build needs the Flutter toolchain');
      return;
    }
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
    expect(barrel.existsSync(), isTrue, reason: 'test-assets must hold the barrel');
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A short temp root: MSBuild paths under <project>/.lumina/editor/build
    // must stay below Windows' 260-character limit.
    final temp = Directory.systemTemp.createTempSync('pl_');
    final originalHandOff = EditorHandOff.instance;
    Process? projectEditor;
    try {
      final cacheBase = Directory('${temp.path}/cache')..createSync();
      final pubCache = Platform.environment['PUB_CACHE'] ??
          (Platform.isWindows ? '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache' : '${Platform.environment['HOME']}/.pub-cache');
      final buildEnv = Platform.isWindows ? {'LOCALAPPDATA': cacheBase.path, 'PUB_CACHE': pubCache} : {'HOME': cacheBase.path, 'PUB_CACHE': pubCache};
      final cache = EditorBuildCache(
        root: Directory(EditorBuildCache.defaultRoot(environment: buildEnv).path),
        nativeRoot: Directory('${EditorBuildCache.cacheBase(environment: buildEnv)}/native'),
      );
      final starts = <List<String>>[];
      EditorHandOff.instance = EditorHandOff(startDetached: (exe, args) async => starts.add([exe, ...args]), exitApp: (_) {});
      EditorBuildSplash.manageNativeWindow = false;

      // 1. Create the project through the launcher's create flow.
      final launcherConfig = Directory('${temp.path}/config')..createSync();
      final resolver = ProjectEditorResolver(cache: cache);
      final repo = ProjectRepository(configDir: launcherConfig, processRunner: offlineScaffoldRunner());
      late LauncherViewModel launcher;
      await tester.runAsync(() async => launcher = LauncherViewModel(
            configDir: launcherConfig,
            projectRepo: repo,
            editorResolver: resolver,
            buildServiceFactory: (r) => EditorBuildService(
              engineRoot: r.engineRoot,
              cache: r.cache,
              generator: r.generator,
              mode: r.mode,
              flutterInfo: r.flutterInfo,
              environment: buildEnv,
            ),
          ));
      final create = CreateProjectViewModel(launcherVM: launcher, projectRepo: repo)
        ..updateName('plain_game')
        ..updateLocation(temp.path);
      await tester.runAsync(create.createProject);
      expect(create.creationError, isNull);
      final pDir = '${temp.path}/plain_game';
      expect(File('$pDir/.lumina/editor/pubspec.yaml').existsSync(), isTrue, reason: 'the host is written at creation');
      expect(File('$pDir/.lumina/editor/lib/plugin_registrar.dart').readAsStringSync(), isNot(contains('_plugin;')));

      // 2. A barrel in its level (the stock editor, saved to disk).
      final project = (await tester.runAsync(() => repo.loadProject('$pDir/plain_game.lmproject')))!;
      final editor = EditorViewModel(initialProject: project, projectLocation: temp.path, enableTimers: false);
      await tester.runAsync(() async {
        await editor.ensureDefaultLevelAssets();
        await editor.processImportPipeline(sourceFilePath: barrel.path);
        editor.refreshAssets();
        final mesh = editor.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_red'));
        await editor.spawnActorFromAsset(mesh, location: [0.0, 0.0, 0.0]);
        await editor.saveLevelAndGenerateCode();
      });
      final barrelName = editor.actors.last.name;
      editor.dispose();

      // 3. Open from the launcher: the first build behind the splash.
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: LauncherView(viewModel: launcher, initialProjectDir: pDir)),
      ));
      for (var i = 0; i < 600 && find.byType(EditorBuildSplash).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(find.byType(EditorBuildSplash), findsOneWidget, reason: 'a plugin-less project builds its own editor');
      final build = tester.widget<EditorBuildSplash>(find.byType(EditorBuildSplash)).viewModel;
      expect(build.hasPlugins, isFalse);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 6));
      SmokeArtifacts.saveScreenshot('$name: splash',
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
          usedAssets: [barrel.path]);
      final started = Stopwatch()..start();
      var lastCapture = Duration.zero;
      while (build.state == EditorBuildSplashState.running && started.elapsed < const Duration(minutes: 45)) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
        await tester.pump();
        if (started.elapsed - lastCapture > const Duration(seconds: 20)) {
          lastCapture = started.elapsed;
          await rec.capture();
        }
      }
      expect(build.state, EditorBuildSplashState.succeeded, reason: build.logTail.join('\n'));
      final outcome = build.outcome as EditorBuildSucceeded;
      await rec.hold(const Duration(seconds: 4));
      rec.save(name, usedAssets: [barrel.path]);
      debugPrint('[plugins09_smoke] first build ${started.elapsed.inSeconds}s -> ${outcome.entry.executable}');
      expect(starts.last.first, outcome.entry.executable, reason: 'the launcher execs the built project editor');
      expect(starts.last.sublist(1, 3), ['--project', pDir]);

      // 4. The project editor opens the project (its MCP server answers).
      final editorConfig = Directory('${temp.path}/editor_config')..createSync();
      final port = await tester.runAsync(() async {
        final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final p = s.port;
        await s.close();
        return p;
      });
      File('${editorConfig.path}/mcp_server_settings.json').writeAsStringSync(jsonEncode({'enabled': true, 'port': port}));
      projectEditor = await tester.runAsync(() => Process.start(outcome.entry.executable, starts.last.sublist(1),
          environment: {'LUMINA_CONFIG_DIR': editorConfig.path, 'FLUTTER_TEST': ''}, mode: ProcessStartMode.detached));
      final connection = File('${editorConfig.path}/mcp_server.json');
      for (var i = 0; i < 240 && !connection.existsSync(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      }
      expect(connection.existsSync(), isTrue, reason: 'the project editor opened the project and started its MCP server');
      final info = jsonDecode(connection.readAsStringSync()) as Map<String, dynamic>;
      final client = McpTestClient(info['url'] as String, info['token'] as String);
      await tester.runAsync(() => client.handshake());
      final projectInfo = await tester.runAsync(() => client.callTool('project_info'));
      expect(projectInfo!.data['project_name'], 'plain_game');
      final actors = await tester.runAsync(() => client.callTool('list_actors'));
      expect(actors!.text, contains(barrelName), reason: 'the saved level, barrel included');
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
      final screenshot = await tester.runAsync(() => client.callTool('viewport_screenshot'));
      final image = screenshot!.content.firstWhere((c) => c['type'] == 'image')['data'] as String;
      SmokeArtifacts.saveScreenshot('$name: project editor viewport', base64Decode(image), usedAssets: [barrel.path]);
      client.close();

      // 5. A second Open is served from the cache.
      late ProjectEditorDecision again;
      await tester.runAsync(() async => again = await resolver.resolve(pDir));
      expect(again, isA<ExecCached>());
      await tester.runAsync(() async => launcher.dispose());
    } finally {
      EditorHandOff.instance = originalHandOff;
      EditorBuildSplash.manageNativeWindow = true;
      if (projectEditor != null) await tester.runAsync(() => killProcessTree(projectEditor!.pid));
      await tester.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          try {
            if (temp.existsSync()) temp.deleteSync(recursive: true);
            break;
          } on FileSystemException {
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
        }
      });
    }
  }, timeout: const Timeout(Duration(minutes: 60)));
}

/// Slot buttons smoke plugin: a button in each named slot.
class _SlotSmokePlugin extends LuminaEditorPlugin {
  final Future<void> Function() onPlace;
  _SlotSmokePlugin({required this.onPlace});

  final ai = ValueNotifier(const EditorButtonState(icon: LucideIcons.sparkles, tooltip: 'Slot smoke: AI', label: 'AI'));
  final place = ValueNotifier(const EditorButtonState(icon: LucideIcons.cylinder, tooltip: 'Place a barrel', label: 'Barrel', tone: EditorTone.primary));
  final left = ValueNotifier(const EditorButtonState(icon: LucideIcons.gitBranch, tooltip: 'Branch', label: 'main'));
  final status = ValueNotifier(const EditorButtonState(icon: LucideIcons.cloud, tooltip: 'Sync state', label: 'Idle'));

  @override
  String get pluginName => 'slot_smoke';

  @override
  void register(LuminaEditorContext context) {
    EditorCommand cmd(String id, void Function() run) => EditorCommand(id: 'slot_smoke.$id', label: id, canExecute: () => true, execute: (_) => run());
    context.registerSlotButton(EditorSlotButton(id: EditorSlot.levelToolbarAfterBlueprints.name, slot: EditorSlot.levelToolbarAfterBlueprints, state: ai, command: cmd('ai', () {})));
    context.registerSlotButton(EditorSlotButton(id: EditorSlot.levelToolbarEnd.name, slot: EditorSlot.levelToolbarEnd, state: place, command: cmd('place', () => onPlace())));
    context.registerSlotButton(EditorSlotButton(id: EditorSlot.statusBarLeft.name, slot: EditorSlot.statusBarLeft, state: left, command: cmd('branch', () {})));
    context.registerSlotButton(EditorSlotButton(id: EditorSlot.statusBarRight.name, slot: EditorSlot.statusBarRight, state: status, command: cmd('sync', () {})));
  }

  @override
  void unregister(LuminaEditorContext context) {}
}

/// Right-dock panels smoke plugin: a right-docked actors panel (through
/// context.level) toggled by a slot button, and a notes panel.
class _DockSmokePlugin extends LuminaEditorPlugin {
  late EditorPanels panels;
  final button = ValueNotifier(const EditorButtonState(icon: LucideIcons.listTree, tooltip: 'Level actors', label: 'Actors'));

  @override
  String get pluginName => 'dock_smoke';

  @override
  void register(LuminaEditorContext context) {
    panels = context.panels;
    final level = (context as LuminaEditorHostContext).level;
    context.registerPanel(EditorPanelDescriptor(
      id: 'dock_smoke.actors',
      title: 'Level Actors',
      icon: LucideIcons.listTree,
      defaultDock: PanelDefaultDock.right,
      builder: (_) => ListenableBuilder(
        listenable: level.changes,
        builder: (_, _) => ListView(
          padding: const EdgeInsets.all(8),
          children: [
            for (final a in level.actors)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${a.name}  ·  ${a.type}', style: const TextStyle(fontSize: 11)),
              ),
          ],
        ),
      ),
    ));
    context.registerPanel(EditorPanelDescriptor(
      id: 'dock_smoke.notes',
      title: 'Notes',
      icon: LucideIcons.notebook,
      defaultDock: PanelDefaultDock.right,
      builder: (_) => const Padding(padding: EdgeInsets.all(8), child: Text('Notes for this level', style: TextStyle(fontSize: 11))),
    ));
    final open = panels.visibility('dock_smoke.actors');
    open.addListener(() => button.value = button.value.copyWith(active: open.value));
    context.registerSlotButton(EditorSlotButton(
      id: 'actors',
      slot: EditorSlot.levelToolbarAfterBlueprints,
      state: button,
      command: EditorCommand(id: 'dock_smoke.toggle', label: 'Actors', canExecute: () => true, execute: (_) => panels.toggle('dock_smoke.actors')),
    ));
  }

  @override
  void unregister(LuminaEditorContext context) {}
}

/// MCP tools smoke plugin: an MCP tool placing a barrel, and a right-dock
/// panel whose Run button calls it in process.
class _McpSmokePlugin extends LuminaEditorPlugin {
  _McpSmokePlugin(this.meshAsset);

  final String meshAsset;
  late EditorMcp mcp;
  late EditorPanels panels;
  final List<String> calls = [];
  int _placed = 0;

  @override
  String get pluginName => 'mcp_smoke';

  @override
  void register(LuminaEditorContext context) {
    mcp = context.mcp;
    panels = context.panels;
    final level = (context as LuminaEditorHostContext).level;
    mcp.calls.listen((e) => calls.add('${e.tool} by ${e.caller} (${e.transport.name})'));
    mcp.registerTool(McpTool(
      name: 'place_barrel',
      description: 'Places a fuel barrel in the open level.',
      inputSchema: McpSchema.object({'x': McpSchema.number('X in centimetres')}),
      handler: (args) async {
        _placed++;
        final ids = await level.addActors([
          EditorActorSpec(
            name: 'McpBarrel$_placed',
            type: 'Mesh',
            location: [args.optionalNumber('x') ?? 200, 0, 0],
            meshAssetPath: meshAsset,
          ),
        ], label: 'Place barrel');
        return McpToolResult.json({'placed': ids});
      },
      risk: McpToolRisk.mutating,
      groups: {McpToolGroups.level},
    ));
    context.registerPanel(EditorPanelDescriptor(
      id: 'mcp_smoke.panel',
      title: 'MCP Probe',
      icon: LucideIcons.bot,
      defaultDock: PanelDefaultDock.right,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('mcp_smoke.place_barrel', style: TextStyle(fontSize: 11)),
            const SizedBox(height: 8),
            PrimaryButton(
              key: const ValueKey('mcp_smoke_run'),
              onPressed: () => mcp.callTool('mcp_smoke.place_barrel', {'x': 200}, caller: 'mcp probe panel'),
              child: const Text('Run'),
            ),
          ],
        ),
      ),
    ));
  }

  @override
  void unregister(LuminaEditorContext context) {}
}

/// Storage and lifecycle smoke plugin: storage, lifecycle hooks and runTransaction.
class _LifecycleSmokePlugin extends LuminaEditorPlugin {
  _LifecycleSmokePlugin(this.meshAsset);

  final String meshAsset;
  late EditorLevelAccess level;
  late PluginStorage storage;

  @override
  String get pluginName => 'lifecycle_smoke';

  @override
  void register(LuminaEditorContext context) {
    level = (context as LuminaEditorHostContext).level;
    storage = context.storage;
  }

  @override
  void onProjectOpened(EditorProjectInfo project) {
    unawaited(storage.writeJson('opened', {'project': project.name}, project: true));
    unawaited(storage.writeJson('settings', {'placeCount': 3}));
  }

  @override
  Future<void> onEditorShutdown() => storage.writeJson('shutdown', {'clean': true}, project: true);

  Future<void> placeThree() => level.runTransaction('Place 3 barrels', () async {
        for (var i = 0; i < 3; i++) {
          await level.addActors([EditorActorSpec(name: 'LifeBarrel$i', type: 'Mesh', location: [i * 150.0 - 150, 0, 0], meshAssetPath: meshAsset)]);
        }
      });
}

/// A built-in code plugin the per-project editor build scenario enables.
class BuiltInCodePlugin {
  const BuiltInCodePlugin({
    required this.scenario,
    required this.package,
    required this.title,
    required this.short,
    required this.search,
    required this.registrar,
    this.openPanel,
  });

  final String scenario;
  final String package;

  /// Its Plugin Manager title.
  final String title;
  final String short;

  /// What the Plugin Manager search is typed with.
  final String search;

  /// Its plugin class, as the host registrar names it.
  final String registrar;

  /// A panel the project's saved layout has open before the rebuild.
  final String? openPanel;
}

const pcgProjectEditor = BuiltInCodePlugin(
  scenario: 'Plugins Smoke Scenario: per-project editor build',
  package: 'lumina_plugin_pcg',
  title: 'Procedural Content Generation',
  short: 'PCG',
  search: 'procedural',
  registrar: 'LuminaPluginPcgPlugin',
);

/// MiniAI reads its chat panel's visibility while it registers.
const miniaiProjectEditor = BuiltInCodePlugin(
  scenario: 'Plugins Smoke Scenario: per-project editor build with MiniAI',
  package: 'lumina_plugin_miniai',
  title: 'MiniAI',
  short: 'MiniAI',
  search: 'miniai',
  registrar: 'LuminaPluginMiniaiPlugin',
  openPanel: LuminaPluginMiniaiPlugin.chatPanelId,
);

/// Enables built-in [plugin] in a project from the Plugin Manager, restarts
/// through the launcher (the build splash, a real build of the project's
/// editor), boots the built project editor and checks it over MCP, then opens
/// the project without its host (the missing-binary prompt).
void perProjectEditorScenario(IntegrationTestWidgetsFlutterBinding binding, BuiltInCodePlugin plugin) {
  testWidgets(plugin.scenario, (tester) async {
    final name = plugin.scenario;
    final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';
    try {
      Process.runSync(flutter, ['--version'], runInShell: Platform.isWindows);
    } on ProcessException {
      markTestSkipped('flutter is not on PATH: the per-project editor build needs the Flutter toolchain');
      return;
    }
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A short temp root: MSBuild paths under <project>/.lumina/editor/build
    // must stay below Windows' 260-character limit.
    final temp = Directory.systemTemp.createTempSync('pe_');
    final pDir = Directory('${temp.path}/PeGame')..createSync(recursive: true);
    final originalHandOff = EditorHandOff.instance;
    Process? projectEditor;
    try {
      // The plugin is the engine's built-in (no copy in the project):
      // enabling it is what rebuilds this project's editor with it.
      const project = LuminaProject(projectName: 'PeGame', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/PeGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final openPanel = plugin.openPanel;
      if (openPanel != null) {
        // The saved layout has the plugin's panel open: the project editor
        // restores it while the plugin registers.
        File('${pDir.path}/.lumina/editor_layout.json')
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode({'pluginPanelVisible': {openPanel: true}, 'activeRightPanel': openPanel}));
      }
      final enginePubspec = File('${LuminaEditorHost.uiRoot}/pubspec.yaml');
      final enginePubspecBefore = enginePubspec.readAsBytesSync();

      // The build's caches in the temp root: the hooks runner passes a hook
      // only allow-listed variables, so the native library cache follows
      // LOCALAPPDATA (Windows) / HOME; PUB_CACHE keeps package resolution on
      // the real pub cache.
      final cacheBase = Directory('${temp.path}/cache')..createSync();
      final pubCache = Platform.environment['PUB_CACHE'] ??
          (Platform.isWindows ? '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache' : '${Platform.environment['HOME']}/.pub-cache');
      final buildEnv = Platform.isWindows ? {'LOCALAPPDATA': cacheBase.path, 'PUB_CACHE': pubCache} : {'HOME': cacheBase.path, 'PUB_CACHE': pubCache};
      final cache = EditorBuildCache(
        root: Directory(EditorBuildCache.defaultRoot(environment: buildEnv).path),
        nativeRoot: Directory('${EditorBuildCache.cacheBase(environment: buildEnv)}/native'),
      );

      // The hand-off is recorded instead of quitting the test app.
      final starts = <List<String>>[];
      final exits = <int>[];
      EditorHandOff.instance = EditorHandOff(startDetached: (exe, args) async => starts.add([exe, ...args]), exitApp: exits.add);
      EditorBuildSplash.manageNativeWindow = false;

      // 1. The editor: Plugins ▸ Plugin Manager ▸ enable the plugin.
      final vm = EditorViewModel(initialProject: project, projectDirPath: temp.path, enableTimers: false);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String label) async =>
          SmokeArtifacts.saveScreenshot('$name: $label', await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await settle(tester);
      await tester.tap(barItem('Plugins'));
      await settle(tester);
      await tester.tap(find.text('Plugin Manager...'));
      await settle(tester);
      await rec.hold(const Duration(seconds: 2));
      // Find the plugin with the search, then clear it.
      final pmSearch = find.byWidgetPredicate((w) =>
          w is TextField && w.placeholder is Text && (w.placeholder as Text).data == 'Search plugins...');
      await tester.tap(pmSearch);
      await rec.typeText(pmSearch, plugin.search, perCharacter: const Duration(milliseconds: 150));
      await settle(tester);
      expect(find.text(plugin.title), findsWidgets);
      await rec.hold(const Duration(seconds: 1));
      await tester.enterText(pmSearch, '');
      await settle(tester);
      // Its details: a code plugin (an editor module), not enabled yet.
      await tester.tap(find.text(plugin.title).first);
      await settle(tester);
      await rec.hold(const Duration(seconds: 2));
      final pluginTitle = find.text(plugin.title).first;
      final titleY = tester.getCenter(pluginTitle).dy;
      final pluginSwitch = find.byType(Switch).evaluate().firstWhere((e) => (tester.getCenter(find.byWidget(e.widget)).dy - titleY).abs() < 40).widget as Switch;
      expect(pluginSwitch.value, isFalse);
      expect(vm.pluginRegistry.entries.singleWhere((e) => e.descriptor.name == plugin.package).descriptor.origin, PluginOrigin.engine,
          reason: 'the built-in ${plugin.short}, not a project copy');
      await tester.tap(find.byWidget(pluginSwitch));
      final host = Directory('${pDir.path}/.lumina/editor');
      for (var i = 0; i < 100 && !File('${host.path}/pubspec.yaml').existsSync(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await settle(tester);
      expect(File('${host.path}/pubspec.yaml').readAsStringSync(), contains('${plugin.package}:'), reason: 'the host depends on ${plugin.short}');
      expect(find.text('Built-in Plugin'), findsNothing, reason: 'a built-in is enabled like any plugin');
      expect((jsonDecode(File('${pDir.path}/PeGame.lmproject').readAsStringSync()) as Map)['enabled_plugins'], [plugin.package]);
      expect(File('${host.path}/lib/plugin_registrar.dart').readAsStringSync(), contains('${plugin.registrar}()'));
      expect(enginePubspec.readAsBytesSync(), enginePubspecBefore, reason: 'the engine pubspec is untouched');
      expect(File('${LuminaEditorHost.uiRoot}/lib/generated/plugin_registrar.dart').existsSync(), isFalse);
      expect(find.text("Plugin changes require rebuilding this project's editor"), findsOneWidget);
      expect(find.text('Restart required'), findsWidgets, reason: 'the ${plugin.short} row waits for the rebuild');
      await rec.hold(const Duration(seconds: 3));
      await shot('${plugin.short} enabled, host generated');

      // Restart Editor → save, hand off to the launcher with --project.
      await tester.tap(find.text('Restart Editor'));
      for (var i = 0; i < 50 && exits.isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(exits, [0], reason: 'the editor quits after handing off');
      expect(starts.single.sublist(1), ['--project', pDir.path]);
      await rec.hold(const Duration(seconds: 2));
      rec.save('$name: enable and restart');
      vm.dispose();

      // 2. The launcher on --project: needsBuild → the splash, a real build.
      final resolver = ProjectEditorResolver(cache: cache);
      final launcherConfig = Directory('${temp.path}/config')..createSync();
      late LauncherViewModel launcher;
      await tester.runAsync(() async => launcher = LauncherViewModel(
            configDir: launcherConfig,
            editorResolver: resolver,
            buildServiceFactory: (r) => EditorBuildService(
              engineRoot: r.engineRoot,
              cache: r.cache,
              generator: r.generator,
              mode: r.mode,
              flutterInfo: r.flutterInfo,
              environment: buildEnv,
            ),
          ));
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: LauncherView(viewModel: launcher, initialProjectDir: starts.single[2])),
      ));
      for (var i = 0; i < 600 && find.byType(EditorBuildSplash).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(find.byType(EditorBuildSplash), findsOneWidget, reason: 'needsBuild shows the splash');
      final splash = tester.widget<EditorBuildSplash>(find.byType(EditorBuildSplash));
      final build = splash.viewModel;
      final splashRec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      final started = Stopwatch()..start();
      while (build.phase.index < EditorBuildPhase.buildingNativeAssets.index && build.state == EditorBuildSplashState.running) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump();
      }
      expect(build.phase, EditorBuildPhase.buildingNativeAssets);
      await splashRec.hold(const Duration(seconds: 12));
      await shot('splash, native assets phase');
      splashRec.save('$name: splash');
      final seen = <String>{};
      while (build.state == EditorBuildSplashState.running && started.elapsed < const Duration(minutes: 45)) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
        await tester.pump();
        final status = build.statusText;
        expect(status, matches(RegExp(r'^\d{1,3}% - .+$')));
        if (seen.add(build.phase.name)) debugPrint('[plugins07_smoke] ${started.elapsed.inSeconds}s $status');
      }
      final firstBuild = started.elapsed;
      expect(build.state, EditorBuildSplashState.succeeded, reason: build.logTail.join('\n'));
      final outcome = build.outcome as EditorBuildSucceeded;
      await tester.pump(const Duration(milliseconds: 300));
      await shot('splash, 100% starting editor');
      expect(starts.last.first, outcome.entry.executable, reason: 'the launcher execs the built project editor');
      expect(starts.last.sublist(1, 3), ['--project', pDir.path]);
      expect(File(outcome.entry.executable).existsSync(), isTrue);
      expect(File(outcome.logPath!).readAsStringSync(), contains('native cache store'), reason: 'the first build fills the temp native cache');
      expect(cache.hashes(), [outcome.entry.hash]);

      // A second Open resolves to the cached build at once.
      final reopen = Stopwatch()..start();
      late ProjectEditorDecision again;
      await tester.runAsync(() async => again = await resolver.resolve(pDir.path));
      final cachedOpen = reopen.elapsed;
      expect(again, isA<ExecCached>());
      debugPrint('[plugins07_smoke] PLUGINS07_TIMINGS first_build=${firstBuild.inSeconds}s cached_open=${cachedOpen.inMilliseconds}ms');

      // 3. The project editor itself boots on --project with the plugin compiled in.
      final editorConfig = Directory('${temp.path}/editor_config')..createSync();
      final port = await tester.runAsync(() async {
        final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final p = s.port;
        await s.close();
        return p;
      });
      File('${editorConfig.path}/mcp_server_settings.json').writeAsStringSync(jsonEncode({'enabled': true, 'port': port}));
      // Detached, as EditorHandOff starts it: undrained stdio pipes would
      // fill up and block the editor's UI thread.
      projectEditor = await tester.runAsync(() => Process.start(outcome.entry.executable, starts.last.sublist(1),
          environment: {'LUMINA_CONFIG_DIR': editorConfig.path, 'FLUTTER_TEST': ''}, mode: ProcessStartMode.detached));
      final connection = File('${editorConfig.path}/mcp_server.json');
      for (var i = 0; i < 240 && !connection.existsSync(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      }
      expect(connection.existsSync(), isTrue, reason: 'the project editor opened the project and started its MCP server');
      final info = jsonDecode(connection.readAsStringSync()) as Map<String, dynamic>;
      final client = McpTestClient(info['url'] as String, info['token'] as String);
      await tester.runAsync(() => client.handshake());
      final projectInfo = await tester.runAsync(() => client.callTool('project_info'));
      expect(projectInfo!.data['project_name'], 'PeGame');
      final log = await tester.runAsync(() => client.callTool('read_output_log', {'contains': 'Registered code plugin'}));
      expect(log!.text, contains('Registered code plugin ${plugin.package}'), reason: '${plugin.short} is compiled into the project editor');
      final failed = await tester.runAsync(() => client.callTool('read_output_log', {'contains': 'failed to register'}));
      expect(failed!.text, isNot(contains(plugin.package)), reason: 'its register() ran without an error');
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
      final screenshot = await tester.runAsync(() => client.callTool('viewport_screenshot'));
      final image = screenshot!.content.firstWhere((c) => c['type'] == 'image')['data'] as String;
      SmokeArtifacts.saveScreenshot('$name: project editor viewport', base64Decode(image));
      client.close();
      if (Platform.isWindows) {
        // The whole project editor window, on DISPLAY1: the editor UI, not a
        // blank window.
        final pid = projectEditor!.pid;
        (int, int, int, int)? rect;
        for (var i = 0; i < 40 && rect == null; i++) {
          rect = await tester.runAsync<(int, int, int, int)?>(() => placeOnDisplay1(pid, width: 1600, height: 1000));
          if (rect == null) await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
        }
        expect(rect, isNotNull, reason: 'the project editor has a window');
        final (x, y, w, h) = rect!;
        final video = recordRegionWebm(x: x, y: y, w: w, h: h, outWebm: '${temp.path}/project_editor.webm');
        await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 4)));
        final png = (await tester.runAsync(() => windowPng(pid, '${temp.path}/project_editor.png')))!;
        final colours = (await tester.runAsync(() => distinctColours(png)))!;
        expect(colours, greaterThan(20), reason: 'the project editor drew its UI (not a blank window)');
        SmokeArtifacts.saveScreenshot('$name: project editor window', png.readAsBytesSync(), metrics: {'distinct_colours': colours});
        SmokeArtifacts.saveVideo('$name: project editor window', (await tester.runAsync(() => video))!.readAsBytesSync());
      }

      // 4. Without its host (a fresh clone): the missing-binary prompt.
      await tester.runAsync(() => killProcessTree(projectEditor!.pid));
      projectEditor = null;
      await tester.runAsync(() => host.delete(recursive: true));
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        // A fresh app: the previous launcher's navigator still holds the splash.
        child: ShadcnApp(key: const ValueKey('reopen'), theme: luminaEditorTheme(), home: LauncherView(viewModel: launcher, initialProjectDir: pDir.path)),
      ));
      for (var i = 0; i < 300 && find.text('Editor binary not found').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      expect(find.text('Editor binary not found'), findsOneWidget);
      expect(find.textContaining('PeGame uses code plugins (${plugin.package})'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await shot('missing editor binary prompt');
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async => launcher.dispose());
    } finally {
      EditorHandOff.instance = originalHandOff;
      EditorBuildSplash.manageNativeWindow = true;
      if (projectEditor != null) await tester.runAsync(() => killProcessTree(projectEditor!.pid));
      await tester.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          try {
            if (temp.existsSync()) temp.deleteSync(recursive: true);
            break;
          } on FileSystemException {
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
        }
      });
    }
  }, timeout: const Timeout(Duration(minutes: 60)));
}
