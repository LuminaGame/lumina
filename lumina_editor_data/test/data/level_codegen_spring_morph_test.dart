// A placed skeletal mesh plays as an animated mesh (the runtime's level
// skeletal mesh factory) with its springs and its Mesh Component Details.
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
    expect(code, contains("LuminaLevelSkeletalMesh.build(key: const LuminaObjectKey('mh_1'), meshAssetPath: "));
    expect(code, contains(', springs: <String, dynamic>{'));
    expect(code, contains("'amplitude': 0.8"));
    expect(code, contains("'bone': 'spine_05'"));
    expect(code, contains("'-y': 'BreastJiggleDownL'"));
  });

  test('a skeletal mesh without springs is an animated skeletal mesh too, with no springs', () {
    final code = DartCodeGeneratorService().generateLevelDart(levelName: 'L_Plain', actors: const [], actorMaps: [skeletal()]);
    expect(code, contains("LuminaLevelSkeletalMesh.build(key: const LuminaObjectKey('mh_1'), meshAssetPath: "));
    expect(code, isNot(contains('LuminaStaticMeshComponent')));
    expect(code, isNot(contains('springs:')));
  });

  test("the Mesh Component's cast shadow, slot and pose from reach the game; an unset pose from is left out", () {
    final code = DartCodeGeneratorService().generateLevelDart(levelName: 'L_Slots', actors: const [], actorMaps: [
      skeletal(components: [
        {
          'id': 'mh_1_mesh',
          'type': 'LuminaSkeletalMeshComponent',
          'name': 'Mesh Component',
          'properties': {'castShadow': false, 'slot': 'Hair', 'poseFrom': 'body_1', 'minDrawDistance': 0.0},
        },
      ]),
      {
        ...skeletal(components: [
          {'id': 'b_mesh', 'type': 'LuminaSkeletalMeshComponent', 'name': 'Mesh Component', 'properties': {'poseFrom': 'None'}},
        ]),
        'id': 'body_1',
      },
    ]);
    expect(code, contains("details: <String, dynamic>{'castShadow': false, 'slot': 'Hair', 'poseFrom': 'body_1'}"));
    expect(code, contains("LuminaLevelSkeletalMesh.build(key: const LuminaObjectKey('body_1'), meshAssetPath: "));
    expect(RegExp("LuminaObjectKey\('body_1'\)[^\n]*details:").hasMatch(code), isFalse, reason: 'None is no pose from');
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
