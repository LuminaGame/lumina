import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/editor_level_access.dart';
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons, Text;
import '../helpers/temp_project.dart';

/// The level half of the plugin API over the real view model —
/// one undo entry per plugin edit, real meshes loaded, plugin assets routed
/// to their editor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late EditorViewModel vm;
  late EditorLevelAccess level;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_plugin_level_');
    vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'LevelApi', activeLevel: 'contents/levels/L_Main.lmas'),
      projectLocation: root.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    await vm.ensureDefaultLevelAssets();
    level = vm.extensionRegistry.level;
  });
  // close() waits until nothing uses the project folder.
  tearDown(() async {
    await vm.close();
    // A just-closed editor may still hold the folder on Windows.
    await deleteTempProject(root);
  });

  final barrel = '${Directory.current.path}/../test-assets/Props/Barrels/fuel_barrel_red.glb';

  test('the registry is a host context whose level is the open project', () {
    expect(vm.extensionRegistry, isA<LuminaEditorHostContext>());
    expect(vm.extensionRegistry.hasLevel, isTrue);
    expect(level, isA<EditorViewModelLevelAccess>());
    expect(level.projectDirPath, vm.projectDirPath);
    expect(level.activeLevelPath, 'contents/levels/L_Main.lmas');
    expect(level.actors.map((a) => a.id), vm.actors.map((a) => a.id));
    final bare = PluginExtensionRegistry(logger: EngineLoggerService());
    expect(() => bare.level, throwsStateError, reason: 'a registry without an attached level is a bare context');
  });

  test('addActors places real mesh actors as ONE undo entry, with geometry loaded from disk; removeActors is one entry too', () async {
    final meshes = Directory('${vm.projectDirPath}/contents/meshes')..createSync(recursive: true);
    final copied = File(barrel).copySync('${meshes.path}/fuel_barrel_red.glb');
    final before = vm.actors.length;
    final ids = await level.addActors([
      for (var i = 0; i < 5; i++)
        EditorActorSpec(
          name: 'Barrel_$i',
          type: 'StaticMesh',
          parentId: null,
          location: [i * 100.0, 0.0, 0.0],
          rotation: [0.0, 0.0, i * 10.0],
          scale: const [1.0, 1.0, 1.0],
          meshAssetPath: copied.path,
          components: const [EditorComponentSpec(type: 'LuminaMeshComponent', name: 'Mesh')],
        ),
    ], label: 'PCG Generate Test');
    expect(ids, hasLength(5));
    expect(ids.toSet(), hasLength(5), reason: 'unique ids');
    expect(vm.actors.length, before + 5);
    final placed = vm.actors.where((a) => ids.contains(a.id)).toList();
    for (final a in placed) {
      expect(a.meshData, isNotNull, reason: 'the .glb was parsed so the viewport can draw it');
      expect(a.meshAssetPath, copied.path);
      expect(a.components.single.type, 'LuminaMeshComponent');
    }
    expect(placed[3].location, [300.0, 0.0, 0.0]);
    expect(placed[3].rotation, [0.0, 0.0, 30.0]);
    expect(vm.transactions.undoLabel, 'Undo PCG Generate Test');
    expect(vm.project.isDirty, isTrue);

    vm.transactions.undo();
    expect(vm.actors.length, before, reason: 'all five go in one undo');
    vm.transactions.redo();
    expect(vm.actors.length, before + 5);

    final snapshots = level.actors.where((a) => ids.contains(a.id)).toList();
    expect(snapshots, hasLength(5));
    expect(() => snapshots.first.location.add(1.0), throwsUnsupportedError, reason: 'snapshots are immutable');

    level.removeActors(ids.take(3), label: 'PCG Cleanup Test');
    expect(vm.actors.length, before + 2);
    expect(vm.transactions.undoLabel, 'Undo PCG Cleanup Test');
    vm.transactions.undo();
    expect(vm.actors.length, before + 5);
  });

  test('removeActors takes children with the parent; setComponentProperty is undoable without a selection', () async {
    final ids = await level.addActors([
      const EditorActorSpec(
        id: 'vol_1',
        name: 'Volume',
        type: 'PcgVolume',
        location: [0.0, 0.0, 0.0],
        components: [EditorComponentSpec(type: 'LuminaPcgComponent', name: 'PCG', properties: {'seed': 1})],
      ),
      const EditorActorSpec(id: 'child_1', name: 'Child', type: 'StaticMesh', parentId: 'vol_1', location: [1.0, 2.0, 3.0]),
    ]);
    expect(ids, ['vol_1', 'child_1']);
    level.setComponentProperty('vol_1', 'LuminaPcgComponent', 'seed', 42, label: 'Seed');
    EditorComponentSnapshot comp() => level.actors.firstWhere((a) => a.id == 'vol_1').componentOfType('LuminaPcgComponent')!;
    expect(comp().properties['seed'], 42);
    expect(vm.transactions.undoLabel, 'Undo Seed');
    vm.transactions.undo();
    expect(comp().properties['seed'], 1);
    vm.transactions.redo();
    expect(comp().properties['seed'], 42);
    level.setComponentProperty('vol_1', 'LuminaPcgComponent', 'graphPath', 'contents/pcg/G.lmas');
    vm.transactions.undo();
    expect(comp().properties.containsKey('graphPath'), isFalse, reason: 'undo of a new key removes it');
    level.setComponentProperty('nope', 'LuminaPcgComponent', 'seed', 9);

    level.selectActors(['vol_1']);
    expect(level.selectedActorIds, ['vol_1']);
    level.removeActors(['vol_1']);
    expect(vm.actors.any((a) => a.id == 'child_1'), isFalse);
    expect(level.selectedActorIds, isEmpty);
  });

  test('saveLevel writes the plugin-placed actors into the level .lmas on disk', () async {
    await level.addActors(const [EditorActorSpec(id: 'p_1', name: 'PluginActor', type: 'StaticMesh', location: [5.0, 6.0, 7.0])]);
    await level.saveLevel();
    final file = File('${vm.projectDirPath}/contents/levels/L_Main.lmas');
    final actors = ((jsonDecode(file.readAsStringSync()) as Map)['metadata']['actors'] as List).cast<Map>();
    final saved = actors.firstWhere((a) => a['id'] == 'p_1');
    expect(saved['location'], [5.0, 6.0, 7.0]);
    expect(vm.project.isDirty, isFalse);
    level.log('hello from a plugin', source: 'PCG');
    expect(vm.logger.logs.last.message, 'hello from a plugin');
  });

  test('a plugin asset type routes its .lmas to the plugin editor tab; foreign assets do not', () async {
    var built = 0;
    vm.extensionRegistry.beginRegistration('pcg');
    vm.extensionRegistry.registerAssetType(EditorAssetTypeHandler(
      customTypeId: 'pcg.graph',
      displayName: 'PCG Graph',
      icon: LucideIcons.workflow,
      thumbnailBuilder: (_) async => null,
      editorFactory: (_, asset) {
        built++;
        return Text(asset.metadata[kAssetPathMetadataKey] ?? 'no path');
      },
    ));
    vm.extensionRegistry.endRegistration();
    final dir = Directory('${vm.projectDirPath}/contents/pcg')..createSync(recursive: true);
    File('${dir.path}/G.lmas').writeAsBytesSync(const LuminaAsset(
      assetId: 'g',
      name: 'G',
      type: AssetType.unknown,
      metadata: {kCustomAssetTypeKey: 'pcg.graph'},
    ).toProtoBufferBytes());
    File('${dir.path}/Other.lmas').writeAsBytesSync(const LuminaAsset(assetId: 'o', name: 'Other', type: AssetType.unknown).toProtoBufferBytes());
    vm.refreshAssets();
    final g = vm.realAssets.firstWhere((a) => a.fileName == 'G.lmas');
    final other = vm.realAssets.firstWhere((a) => a.fileName == 'Other.lmas');
    expect(vm.extensionRegistry.handlerForAsset(g)?.customTypeId, 'pcg.graph');
    expect(vm.extensionRegistry.handlerForAsset(other), isNull);
    expect(vm.extensionRegistry.customTypeOf(g.lmasPath!), 'pcg.graph');

    level.openAssetEditor('contents/pcg/G.lmas');
    final tab = vm.openTabs[vm.activeTabIndex];
    expect(tab.category, '${PluginExtensionRegistry.pluginAssetCategoryPrefix}pcg.graph');
    expect(tab.title, 'G');
    expect(tab.asset?.lmasPath, g.lmasPath);
    level.openAssetEditor(g.lmasPath!);
    expect(vm.openTabs.where((t) => t.category.startsWith(PluginExtensionRegistry.pluginAssetCategoryPrefix)), hasLength(1), reason: 'reopening focuses the tab');
    level.openAssetEditor('contents/pcg/Missing.lmas');
    expect(vm.logger.logs.last.message, contains('Missing.lmas'));
    expect(built, 0, reason: 'the editor widget is built by the tab, not by opening');
  });

  // A plugin groups its level edits into one undo step.
  test('runTransaction makes three addActors calls one undo step; a nested call joins it', () async {
    final meshes = Directory('${vm.projectDirPath}/contents/meshes')..createSync(recursive: true);
    final copied = File(barrel).copySync('${meshes.path}/fuel_barrel_red.glb');
    final before = vm.actors.length;
    final undoDepth = vm.transactions.undoLabel;
    await level.runTransaction('Place 3 barrels', () async {
      for (var i = 0; i < 2; i++) {
        await level.addActors([EditorActorSpec(name: 'Grouped_$i', type: 'StaticMesh', location: [i * 100.0, 0, 0], meshAssetPath: copied.path)]);
      }
      await level.runTransaction('Inner', () async {
        await level.addActors([EditorActorSpec(name: 'Grouped_2', type: 'StaticMesh', location: const [200.0, 0, 0], meshAssetPath: copied.path)]);
      });
    });
    expect(vm.actors.length, before + 3);
    expect(vm.transactions.undoLabel, 'Undo Place 3 barrels');
    vm.transactions.undo();
    expect(vm.actors.length, before, reason: 'one Undo removed all three');
    expect(vm.transactions.undoLabel, undoDepth, reason: 'exactly one step was pushed');
    vm.transactions.redo();
    expect(vm.actors.where((a) => a.name.startsWith('Grouped_')), hasLength(3));
  });

  // "Undo this turn" undoes only the step it made.
  test('undoTopLabel names the newest step; undoIfTop undoes only that step', () async {
    final meshes = Directory('${vm.projectDirPath}/contents/meshes')..createSync(recursive: true);
    final copied = File(barrel).copySync('${meshes.path}/fuel_barrel_red.glb');
    final before = vm.actors.length;
    await level.runTransaction('AI: Place a barrel', () async {
      await level.addActors([EditorActorSpec(name: 'Turn_0', type: 'StaticMesh', location: const [0.0, 0, 0], meshAssetPath: copied.path)]);
    });
    expect(level.undoTopLabel, 'AI: Place a barrel');
    expect(level.undoIfTop('AI: Something else'), isFalse);
    expect(vm.actors.length, before + 1);

    // A newer step on top: the turn can no longer be undone alone.
    await level.addActors([EditorActorSpec(name: 'User_0', type: 'StaticMesh', location: const [100.0, 0, 0], meshAssetPath: copied.path)], label: 'User add');
    expect(level.undoIfTop('AI: Place a barrel'), isFalse);
    vm.transactions.undo();

    expect(level.undoIfTop('AI: Place a barrel'), isTrue);
    expect(vm.actors.length, before);
    expect(level.undoTopLabel, isNot('AI: Place a barrel'));
  });

  test('openLevel saves the open level, opens a level the plugin wrote with each mesh actor drawing its own file, and re-reads the open level', () async {
    final meshes = Directory('${vm.projectDirPath}/contents/meshes')..createSync(recursive: true);
    final barrelFile = File(barrel).copySync('${meshes.path}/fuel_barrel_red.glb');
    // A name that does not match the mesh file: the actor still draws the
    // file its meshAssetPath names.
    File(barrel).copySync('${meshes.path}/road_decoy.glb');
    const generated = 'contents/levels/L_Generated.lmas';
    LuminaLevelRepository(vm.projectDirPath).save(
      LuminaLevelDocument(relativePath: generated)
        ..actors = [
          {'id': 'gen_folder', 'name': 'Roads', 'type': 'Folder', 'location': [0.0, 0.0, 0.0]},
          {
            'id': 'gen_road',
            'name': 'Road_primary_0_0',
            'type': 'StaticMesh',
            'parentId': 'gen_folder',
            'location': [1200.0, -300.0, 400.0],
            'meshAssetPath': barrelFile.path,
            'components': [],
          },
        ],
    );
    // The open level has an unsaved plugin actor.
    await level.addActors(const [EditorActorSpec(id: 'unsaved_1', name: 'Unsaved', type: 'StaticMesh', location: [1.0, 2.0, 3.0])]);
    expect(vm.project.isDirty, isTrue);

    expect(await level.openLevel('contents/levels/L_Missing.lmas'), isFalse);
    expect(level.activeLevelPath, 'contents/levels/L_Main.lmas');

    expect(await level.openLevel(generated, show: false), isTrue);
    expect(level.activeLevelPath, generated);
    final main = File('${vm.projectDirPath}/contents/levels/L_Main.lmas').readAsStringSync();
    expect(main, contains('unsaved_1'), reason: 'the level that was open was saved first');
    expect(level.actors.map((a) => a.id), ['gen_folder', 'gen_road']);
    final road = vm.actors.firstWhere((a) => a.id == 'gen_road');
    expect(road.parentId, 'gen_folder');
    expect(road.location, [1200.0, -300.0, 400.0], reason: 'the stored location is kept as written');
    for (var i = 0; i < 100 && road.meshData == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(road.meshData, isNotNull);
    expect(road.meshAssetPath, barrelFile.path, reason: 'the mesh the actor names, not a file guessed from its name');

    // Rewritten on disk while open: opened again, the new contents are read.
    final doc = LuminaLevelRepository(vm.projectDirPath).load(generated)!;
    doc.actors = [...doc.actors, {'id': 'gen_extra', 'name': 'Extra', 'type': 'StaticMesh', 'location': [0.0, 0.0, 0.0]}];
    LuminaLevelRepository(vm.projectDirPath).save(doc);
    expect(await level.openLevel(generated), isTrue);
    expect(level.actors.map((a) => a.id), contains('gen_extra'));
    expect(vm.project.isDirty, isFalse);
  });
}
