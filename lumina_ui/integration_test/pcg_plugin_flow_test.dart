import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_plugin_pcg/lumina_plugin_pcg.dart';
import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina/data/services/workspace_paths.dart';

/// The PCG example plugin end to end on the real host:
/// installed into a temp project's `plugins/` root, discovered by
/// `PluginRegistryService` from its manifest, registered against the
/// editor (what the generated registrar does after the restart), then a
/// graph is created, a volume placed, Generate run, and the level saved —
/// asserted on disk.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The plugin checkout (plugins repo) where the workspace resolved it.
  final pluginCheckout = Directory(LuminaWorkspace.package('lumina_plugin_pcg'));

  testWidgets('install → discover → register → New Graph → Place Volume → Generate → actors on disk', (tester) async {
    final root = Directory.systemTemp.createTempSync('pcg_plugin_flow_');
    final projectDir = Directory('${root.path}/PcgFlow')..createSync(recursive: true);
    try {
      // 1. Install: a symlink into the project's plugins root (the README's
      //    development install, aimed at the project instead of ~/.local).
      final pluginsRoot = Directory('${projectDir.path}/plugins')..createSync(recursive: true);
      Link('${pluginsRoot.path}/lumina_plugin_pcg').createSync(pluginCheckout.absolute.path);
      expect(File('${pluginsRoot.path}/lumina_plugin_pcg/lumina_plugin_pcg.lmplugin').existsSync(), isTrue);

      // 2. Open the project: the view model's discovery scans <project>/plugins.
      //    A project is its .lmproject on disk: the registry reads the enabled
      //    plugins from it and lists nothing for a directory without one.
      const project = LuminaProject(projectName: 'PcgFlow', activeLevel: 'contents/levels/L_Main.lmas');
      File('${projectDir.path}/PcgFlow.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(
        initialProject: project,
        projectLocation: root.path,
        enableTimers: false,
      );
      addTearDown(vm.dispose);
      expect(vm.projectDirPath, projectDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
      final entry = vm.pluginRegistry.entries.where((e) => e.descriptor.name == 'lumina_plugin_pcg').firstOrNull;
      expect(entry, isNotNull, reason: 'the manifest is discovered from the project plugins root');
      expect(entry!.descriptor.friendlyName, 'Procedural Content Generation');
      expect(entry.descriptor.modules.single.registrationClass, 'LuminaPluginPcgPlugin');
      expect(entry.descriptor.modules.single.entryLibrary, 'lib/lumina_plugin_pcg.dart');
      expect(entry.descriptor.isContentOnly, isFalse);
      expect(entry.enabled, isFalse, reason: 'a code plugin is enabled in the Plugin Manager and takes effect after the restart');

      // 3. Register the plugin class against the host registry — exactly the
      //    call a project editor host's registrar makes at boot once the
      //    plugin is enabled and the editor restarted.
      //    When this editor build already has the plugin compiled in and
      //    enabled (the registrar lists it), the view model registered that
      //    instance at construction: use it rather than registering twice.
      final booted = LuminaEditorHost.plugins.whereType<LuminaPluginPcgPlugin>().firstOrNull;
      final plugin = booted ?? LuminaPluginPcgPlugin();
      if (booted == null) {
        vm.extensionRegistry.beginRegistration(plugin.pluginName);
        plugin.register(vm.extensionRegistry);
        vm.extensionRegistry.endRegistration();
      }
      expect(plugin.service, isNotNull, reason: 'the registry is a LuminaEditorHostContext');
      final menu = vm.extensionRegistry.allMenuCommands.map((e) => e.key).toList();
      expect(menu, containsAll(['Plugins/PCG/New PCG Graph', 'Plugins/PCG/Place PCG Volume', 'Plugins/PCG/Generate All', 'Plugins/PCG/Cleanup All']));
      expect(vm.extensionRegistry.allDetailsCustomizations.single.targetTypeId, 'PcgVolume');
      expect(vm.extensionRegistry.allAssetTypes.single.customTypeId, PcgGraphAsset.customTypeId);

      // 4. Real meshes through the real import pipeline.
      final assets = SmokeArtifacts.testAssetsDir.path;
      for (final b in ['fuel_barrel_red.glb', 'dented_barrel.glb']) {
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '$assets/Props/Barrels/$b'));
      }
      vm.refreshAssets();
      // (the default level assets add the starter rock mesh beside them)
      expect(vm.realAssets.where((a) => a.type == AssetType.filamesh && a.fileName.contains('barrel')), hasLength(2));

      EditorCommand command(String id) => vm.extensionRegistry.allMenuCommands.map((e) => e.value).firstWhere((c) => c.id == id);

      // 5. Tools → PCG → New PCG Graph writes contents/pcg/PCG_Graph_1.lmas
      //    and opens it in the plugin's editor tab.
      command('tools.lumina_plugin_pcg.newGraph').execute(null);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      final graphFile = File('${projectDir.path}/contents/pcg/PCG_Graph_1.lmas');
      expect(graphFile.existsSync(), isTrue);
      final graph = PcgGraphAsset.load(graphFile.path)!;
      expect(graph.nodeById('spawner')!.meshes.map((m) => m.path).where((p) => p.endsWith('.glb')), isNotEmpty,
          reason: 'the spawner lists the imported meshes');
      expect(vm.openTabs[vm.activeTabIndex].category, '${PluginExtensionRegistry.pluginAssetCategoryPrefix}${PcgGraphAsset.customTypeId}');
      expect(vm.openTabs[vm.activeTabIndex].title, 'PCG_Graph_1');
      expect(vm.realAssets.any((a) => a.fileName == 'PCG_Graph_1.lmas'), isTrue, reason: 'the Content Browser lists the graph');

      // 6. Place a volume, generate, count.
      command('tools.lumina_plugin_pcg.placeVolume').execute(null);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      final volume = vm.actors.firstWhere((a) => a.type == PcgTypes.volumeActor);
      expect(vm.selectedActorIds, [volume.id]);
      final settings = PcgVolumeSettings.of(vm.extensionRegistry.level.actors.firstWhere((a) => a.id == volume.id))!;
      expect(settings.graphPath, 'contents/pcg/PCG_Graph_1.lmas');
      final before = vm.actors.length;
      final report = await tester.runAsync(() => plugin.service!.generate(volume.id));
      expect(report!.ok, isTrue, reason: report.error);
      expect(report.spawned, greaterThan(0));
      expect(vm.actors.length, before + report.spawned);
      final generated = vm.actors.where((a) => a.parentId == volume.id).toList();
      expect(generated, hasLength(report.spawned));
      expect(generated.every((a) => a.type == 'StaticMesh' && a.meshData != null), isTrue, reason: 'real barrel geometry is loaded for the viewport');
      expect(vm.transactions.undoLabel, 'Undo PCG instance count');

      // Generate All through the menu regenerates deterministically.
      final firstLocations = generated.map((a) => a.location.join(',')).toList();
      command('tools.lumina_plugin_pcg.generateAll').execute(null);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      expect(vm.actors.where((a) => a.parentId == volume.id).map((a) => a.location.join(',')).toList(), firstLocations);
      expect(vm.actors.length, before + report.spawned, reason: 'replaced, not accumulated');

      // 7. Save: the level file carries the volume and its instances; the
      //    generated level code places plain mesh actors.
      await tester.runAsync(() => vm.saveLevelAndGenerateCode());
      final levelJson = jsonDecode(File('${projectDir.path}/contents/levels/L_Main.lmas').readAsStringSync()) as Map;
      final actors = ((levelJson['metadata'] as Map)['actors'] as List).cast<Map>();
      expect(actors.where((a) => a['type'] == 'PcgVolume'), hasLength(1));
      final onDisk = actors.where((a) => a['parentId'] == volume.id).toList();
      expect(onDisk, hasLength(report.spawned));
      expect(onDisk.every((a) => (a['meshAssetPath'] as String).startsWith(projectDir.path)), isTrue);
      final levelDart = File('${projectDir.path}/lib/levels/l_main.dart').readAsStringSync();
      expect(levelDart, contains('LuminaStaticMeshComponent'), reason: 'instances generate as ordinary static mesh actors');
      expect(levelDart, isNot(contains('Pcg')), reason: 'nothing PCG-specific reaches the game');

      // 8. Cleanup All empties it, and the file on disk follows the next save.
      command('tools.lumina_plugin_pcg.cleanupAll').execute(null);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      expect(vm.actors.where((a) => a.parentId == volume.id), isEmpty);
      await tester.runAsync(() => vm.saveLevelAndGenerateCode());
      final after = jsonDecode(File('${projectDir.path}/contents/levels/L_Main.lmas').readAsStringSync()) as Map;
      expect(((after['metadata'] as Map)['actors'] as List).where((a) => (a as Map)['parentId'] == volume.id), isEmpty);
    } finally {
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  });
}
