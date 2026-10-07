// The level code generator writes engine actors from the editor's
// `metadata.actors`: what each placed actor type becomes in the generated
// game, and that the generated values match what the engine reads.
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

void main() {
  group('camera', () {
    test('the generated level builds a placed camera as a camera actor with its saved settings', () {
      final code = DartCodeGeneratorService().generateLevelDart(levelName: 'L_Cam', actors: const [], actorMaps: [
        {
          'id': 'cam_1', 'name': 'Camera_1', 'type': 'Camera', 'location': [0.0, -500.0, 150.0], 'rotation': [0.0, 0.0, 0.0],
          'components': [
            {'id': 'cam_1_camera', 'type': 'LuminaCameraComponent', 'name': 'Camera', 'properties': {'fieldOfView': 30.0, 'nearClipPlane': 5.0, 'autoActivateForPlayer': true}},
          ],
        },
      ]);
      expect(code, contains("LuminaCameraActor(key: const LuminaObjectKey('cam_1'), location: Vector3(0.0000, 150.0000, 500.0000)"));
      expect(code, contains('settings: LuminaCameraSettings.fromProperties('));
      expect(code, contains("'fieldOfView': 30.0"));
      expect(code, contains("'autoActivateForPlayer': true"));
    });
  });

  group('axes', () {
    test('the level code generator converts stored Z-up transforms to the runtime', () {
      final code = DartCodeGeneratorService().generateLevelDart(levelName: 'L_Axes', actors: const [], actorMaps: [
        {'id': 'm', 'name': 'Marker', 'type': 'StaticMesh', 'location': [400.0, 0.0, 60.0], 'rotation': [0.0, 0.0, 90.0], 'scale': [1.0, 2.0, 3.0]},
      ]);
      expect(code, contains('location: Vector3(400.0000, 60.0000, 0.0000)'));
      expect(code, contains('rotation: luminaAuthoringRotation(0.0000, 0.0000, 90.0000)'));
      expect(code, contains('scale: Vector3(1.0000, 3.0000, 2.0000)'));
    });
  });

  group('Procedural sky code generation', () {
    test('a ProceduralSky actor round-trips through metadata.actors into Dart', () {
      final gen = DartCodeGeneratorService();
      final dart = gen.generateLevelDart(
        levelName: 'L_Ocean',
        actors: const [],
        actorMaps: [
          {
            'id': 'act_proc_sky',
            'name': 'ProceduralSky_Ocean',
            'type': 'ProceduralSky',
            'location': [0.0, 0.0, 0.0],
            'isVisible': true,
            'components': [
              {
                'id': 'act_proc_sky_c',
                'type': 'LuminaProceduralSkyComponent',
                'name': 'Procedural Sky',
                'properties': {
                  'timeOfDay': 17.5,
                  'turbidity': 4.0,
                  'cloudCoverage': 0.72,
                  'waterStrength': 55.0,
                  'dayCycleSpeed': 0.25,
                },
              },
            ],
          },
        ],
      );

      expect(dart, contains('LuminaProceduralSkyComponent('));
      expect(dart, contains('timeOfDay: 17.5'));
      expect(dart, contains('turbidity: 4.0'));
      expect(dart, contains('cloudCoverage: 0.72'));
      expect(dart, contains('waterStrength: 55.0'));
      expect(dart, contains('dayCycleSpeed: 0.25'));
      expect(dart, contains('visible: true'));
    });

    test('a ProceduralSky actor with no component falls back to the defaults', () {
      final gen = DartCodeGeneratorService();
      final dart = gen.generateLevelDart(
        levelName: 'L_Ocean',
        actors: const [],
        actorMaps: [
          {
            'id': 'act_proc_sky',
            'name': 'ProceduralSky',
            'type': 'ProceduralSky',
            'location': [0.0, 0.0, 0.0],
            'isVisible': true,
          },
        ],
      );
      expect(dart, contains('timeOfDay: 12.0'));
      expect(dart, contains('cloudCoverage: 0.4'));
    });
  });
}
