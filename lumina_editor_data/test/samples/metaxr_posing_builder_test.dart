import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// The test-assets mannequin stands in for the mobile MetaHuman.
final String _mannequin = '${Directory.current.parent.parent.path}/test-assets/mannequin/SKM_Manny_Simple.glb';

/// The posing example built into a real project (Lumina's project pipeline,
/// a real import, real Blueprint compilation and code generation).
void main() {
  test('the builder writes the project: both XR plugins, the Quest target, L_Room, Maps & Modes and the game code', () async {
    if (!File(_mannequin).existsSync()) return markTestSkipped('test-assets mannequin missing');
    final temp = Directory.systemTemp.createTempSync('metaxr_posing_');
    LuminaConfigDir.override = Directory('${temp.path}/config')..createSync();
    addTearDown(() {
      LuminaConfigDir.override = null;
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException catch (_) {}
    });
    final projectDir = await MetaXrPosingBuilder.createProject(temp.path, 'metaxr_posing');
    final report = await MetaXrPosingBuilder(projectDir: projectDir, characterGlb: _mannequin).build();
    expect(report.meshAssetPath, startsWith('contents/meshes/skeletal/'));

    final manifest = jsonDecode(File('$projectDir/metaxr_posing.lmproject').readAsStringSync()) as Map<String, dynamic>;
    final project = LuminaProject.fromMap(manifest);
    expect(project.enabledPlugins, containsAll(['lumina_plugin_openxr', 'lumina_plugin_metaxr']));
    expect(project.packaging.targets, ['android']);
    final android = project.packaging.android;
    expect(android.isQuest, isTrue);
    expect(android.applicationIdFor(project.projectName), 'com.lumina.metaxr_posing');
    expect(android.refreshRate, 72);
    expect(android.multiview, isTrue);
    expect(android.minSdk, kQuestMinSdk);
    expect(project.mapsAndModes.gameDefaultMap, MetaXrPosingLevel.levelPath);
    expect(project.mapsAndModes.defaultGameMode, MetaXrPosingContent.gameModePath);
    expect(project.mapsAndModes.defaultPawnClass, MetaXrPosingContent.playerPath);
    expect(project.input.actions.map((a) => a.name), contains('IA_TogglePassthrough'));

    // L_Room: passthrough (underlay), the XR origin at the floor, the
    // character in front of it, lights, and no floor or sky.
    final level = jsonDecode(File('$projectDir/${MetaXrPosingLevel.levelPath}').readAsStringSync()) as Map<String, dynamic>;
    final actors = ((level['metadata'] as Map)['actors'] as List).cast<Map<String, dynamic>>();
    final passthrough = actors.firstWhere((a) => a['blueprintClass'] == MetaXrPosingContent.passthroughPath);
    final component = (passthrough['components'] as List).cast<Map>().single;
    expect(component['type'], 'LuminaMetaPassthroughComponent');
    expect((component['properties'] as Map)['placement'], 'underlay');
    final origin = actors.firstWhere((a) => a['type'] == 'PlayerStart');
    expect(origin['location'], [0.0, 0.0, 0.0], reason: 'the XR origin at LOCAL_FLOOR');
    final character = actors.firstWhere((a) => a['blueprintClass'] == MetaXrPosingContent.characterPath);
    expect(character['location'], [0.0, MetaXrPosingLevel.characterDistance, 0.0]);
    expect(actors.where((a) => a['type'] == 'DirectionalLight'), hasLength(2));
    expect(actors.any((a) => a['type'] == 'Environment' || a['type'] == 'Primitive'), isFalse);

    // The Blueprints compiled into the game, the level and main.
    for (final file in ['bp_posed_character.dart', 'bp_xr_player.dart', 'bp_room_passthrough.dart', 'bp_posing_game_mode.dart']) {
      expect(File('$projectDir/lib/actors/$file').existsSync(), isTrue, reason: file);
    }
    final playerCode = File('$projectDir/lib/actors/bp_xr_player.dart').readAsStringSync();
    expect(playerCode, contains('package:lumina_plugin_metaxr/runtime.dart'), reason: 'the passthrough toggle calls the plugin');
    expect(File('$projectDir/lib/levels/l_room.dart').readAsStringSync(), contains('LuminaObjectKey(\'act_character\')'));
    final main = File('$projectDir/lib/main.dart').readAsStringSync();
    expect(main, contains("initialLevel: 'L_Room'"));
    expect(main, contains('BP_PosingGameMode'));
    expect(File('$projectDir/${MetaXrPosingWidgets.hudPath}').existsSync(), isTrue);
    expect(File('$projectDir/Saved/MetaXrPosing/report.json').existsSync(), isTrue);

    // Building again keeps the import and rewrites the same project.
    final again = await MetaXrPosingBuilder(projectDir: projectDir, characterGlb: _mannequin).build();
    expect(again.meshAssetPath, report.meshAssetPath);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
