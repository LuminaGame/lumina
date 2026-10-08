// A placed skeletal mesh that carries spring-driven morph targets plays as an
// animated mesh with its springs; any other skeletal mesh generates as before.
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

void main() {
  Map<String, dynamic> skeletal({List<Map<String, dynamic>> components = const []}) => {
    'id': 'mh_1',
    'name': 'Character',
    'type': 'SkeletalMesh',
    'location': [0.0, 0.0, 0.0],
    'meshAssetPath': 'contents/Characters/Ada.lmas',
    'components': components,
  };

  test('a skeletal mesh with a spring component becomes an animated mesh with the springs', () {
    final code = DartCodeGeneratorService().generateLevelDart(levelName: 'L_Springs', actors: const [], actorMaps: [
      skeletal(components: [
        {
          'id': 'mh_1_c0',
          'type': 'LuminaSpringMorphComponent',
          'name': 'Breast Jiggle',
          'properties': {
            'amplitude': 0.8,
            'springs': [
              {
                'name': 'left',
                'bone': 'spine_05',
                'offset': [9.0, -4.0, 12.0],
                'frequency': 2.2,
                'morphs': {'+y': 'BreastJiggleUpL', '-y': 'BreastJiggleDownL'},
              },
            ],
          },
        },
      ]),
    ]);
    expect(code, contains("LuminaActor(key: const LuminaObjectKey('mh_1'), root: LuminaAnimatedMeshComponent(meshAssetPath: "));
    expect(code, contains('..addComponent(LuminaSpringMorphComponent.fromProperties('));
    expect(code, contains("'amplitude': 0.8"));
    expect(code, contains("'bone': 'spine_05'"));
    expect(code, contains("'-y': 'BreastJiggleDownL'"));
  });

  test('a skeletal mesh without springs generates as a static mesh, as before', () {
    final code = DartCodeGeneratorService().generateLevelDart(levelName: 'L_Plain', actors: const [], actorMaps: [skeletal()]);
    expect(code, contains('root: LuminaStaticMeshComponent(meshAssetPath: '));
    expect(code, isNot(contains('LuminaAnimatedMeshComponent')));
    expect(code, isNot(contains('LuminaSpringMorphComponent')));
  });

  test('a spring component on a static mesh is not a skeletal one: unchanged', () {
    final code = DartCodeGeneratorService().generateLevelDart(levelName: 'L_Static', actors: const [], actorMaps: [
      {
        ...skeletal(components: [
          {'id': 'c', 'type': 'LuminaSpringMorphComponent', 'name': 'Springs', 'properties': <String, dynamic>{}},
        ]),
        'type': 'StaticMesh',
      },
    ]);
    expect(code, isNot(contains('LuminaSpringMorphComponent')));
  });
}
