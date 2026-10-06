import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/code_generator_service.dart';

/// Actors hidden in the editor's outliner, themselves or through a folder,
/// are spawned hidden by the generated level.
void main() {
  final generator = DartCodeGeneratorService();

  List<Map<String, dynamic>> actors() => [
        {'id': 'props', 'name': 'Props', 'type': 'Folder', 'location': [0.0, 0.0, 0.0], 'isVisible': false},
        {
          'id': 'crate_in_hidden_folder',
          'name': 'Crate',
          'type': 'StaticMesh',
          'parentId': 'props',
          'location': [100.0, 0.0, 0.0],
          'meshAssetPath': 'contents/meshes/SM_Crate.lmas',
          'isVisible': true,
        },
        {
          'id': 'barrel_hidden',
          'name': 'Barrel',
          'type': 'StaticMesh',
          'location': [200.0, 0.0, 0.0],
          'meshAssetPath': 'contents/meshes/SM_Barrel.lmas',
          'isVisible': false,
        },
        {
          'id': 'barrel_shown',
          'name': 'Barrel 2',
          'type': 'StaticMesh',
          'location': [300.0, 0.0, 0.0],
          'meshAssetPath': 'contents/meshes/SM_Barrel.lmas',
          'isVisible': true,
        },
        {
          'id': 'turret_hidden',
          'name': 'Turret',
          'type': 'Blueprint',
          'blueprintClass': 'contents/blueprints/BP_Turret.lmas',
          'location': [0.0, 400.0, 0.0],
          'isVisible': false,
        },
        {'id': 'start', 'name': 'PlayerStart', 'type': 'PlayerStart', 'location': [0.0, 0.0, 0.0]},
      ];

  test('hidden actor ids follow the folder chain', () {
    expect(hiddenEditorActorIds(actors()), {'props', 'crate_in_hidden_folder', 'barrel_hidden', 'turret_hidden'});
  });

  test('the generated level hides them whatever class they are, and only them', () {
    final code = generator.generateLevelDart(levelName: 'L_Hidden', actors: const [], actorMaps: actors());
    String lineOf(String id) => code.split('\n').firstWhere((l) => l.contains("ValueKey('$id')"), orElse: () => '');
    expect(lineOf('crate_in_hidden_folder'), contains('visible: false'), reason: 'the folder above it is hidden');
    expect(lineOf('crate_in_hidden_folder'), contains('..hiddenInGame = true,'));
    expect(lineOf('barrel_hidden'), contains('visible: false'));
    expect(lineOf('barrel_hidden'), contains('..hiddenInGame = true,'));
    expect(lineOf('turret_hidden'), contains('..hiddenInGame = true,'), reason: 'a Blueprint factory actor is hidden by the cascade');
    expect(lineOf('barrel_shown'), contains('visible: true'));
    expect(lineOf('barrel_shown'), isNot(contains('hiddenInGame')));
    expect(lineOf('start'), isNot(contains('hiddenInGame')));
    expect(code, isNot(contains("ValueKey('props')")), reason: 'folders are not actors');
  });
}
