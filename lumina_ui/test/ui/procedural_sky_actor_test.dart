import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/services/editor_procedural_sky.dart';
import 'package:lumina_ui/ui/core/services/editor_scene_environment.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// The Procedural Sky & Ocean as placeable content.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_procsky_test_');
    Directory('${tempDir.path}/SkyGame').createSync(recursive: true);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  EditorViewModel makeEditor() => EditorViewModel(
        initialProject: const LuminaProject(
          projectName: 'SkyGame',
          activeLevel: 'contents/levels/L_Main.lmas',
        ),
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      );

  EditorActorNode skyActor({Map<String, dynamic>? properties, bool visible = true}) =>
      EditorActorNode(
        id: 'act_proc_sky',
        name: 'ProceduralSky',
        type: EditorProceduralSky.actorType,
        location: [0.0, 0.0, 0.0],
        isVisible: visible,
        components: [
          EditorComponentNode(
            id: 'act_proc_sky_proceduralsky',
            type: EditorProceduralSky.componentType,
            name: 'Procedural Sky',
            properties: properties ?? LuminaProceduralSkyDescription.defaults.toProperties(),
          ),
        ],
      );

  group('EditorProceduralSky.describeLevel', () {
    test('a level without the actor has no procedural sky at all', () {
      expect(EditorProceduralSky.describeLevel(const []), isNull);
      expect(
        EditorProceduralSky.describeLevel([
          EditorActorNode(id: 'a', name: 'Floor', type: 'StaticMesh', location: [0, 0, 0]),
        ]),
        isNull,
        reason: 'an ordinary level must not pay for a sky it did not place',
      );
    });

    test('reads the actor component properties the Details panel writes', () {
      final d = EditorProceduralSky.describeLevel([
        skyActor(properties: const {
          'timeOfDay': 19.5,
          'turbidity': 5.0,
          'cloudCoverage': 0.85,
          'waterStrength': 70.0,
          'dayCycleSpeed': 0.5,
        }),
      ]);
      expect(d, isNotNull);
      expect(d!.timeOfDay, 19.5);
      expect(d.turbidity, 5.0);
      expect(d.cloudCoverage, 0.85);
      expect(d.waterStrength, 70.0);
      expect(d.dayCycleSpeed, 0.5);
      expect(d.isNight, isTrue, reason: '19:30 is past sunset');
    });

    test('the outliner eye toggle hides the sky', () {
      expect(EditorProceduralSky.describeLevel([skyActor(visible: false)])!.visible, isFalse);
      expect(EditorProceduralSky.describeLevel([skyActor()])!.visible, isTrue);
    });
  });

  group('Procedural sky vs the Environment actor skybox', () {
    EditorActorNode environmentActor({bool visible = true}) => EditorActorNode(
          id: 'act_env_sky',
          name: 'Sky&Atmosphere_Env',
          type: EditorSceneEnvironment.environmentActorType,
          location: [0.0, 0.0, 0.0],
          isVisible: visible,
          components: [
            EditorComponentNode(
              id: 'act_env_sky_luminaskycomponent',
              type: EditorSceneEnvironment.skyComponentType,
              name: 'Sky',
              properties: const {'mode': 'color', 'colorHex': '#5C7FB8'},
            ),
          ],
        );

    test('a visible procedural sky suppresses the static skybox but keeps the ambient light', () {
      // Filament paints a Skybox into every pixel nothing wrote depth to, and
      // the procedural sky is a depthWrite:false renderable — so leaving both
      // on means the static skybox covers the procedural one completely.
      final both = EditorSceneEnvironment.describeLevel([environmentActor(), skyActor()])!;
      expect(both.skyVisible, isFalse, reason: 'the procedural sky is the background');
      expect(both.iblIntensity, greaterThan(0),
          reason: 'the Environment actor is still what lights the level');
    });

    test('the Environment actor keeps its skybox when there is no procedural sky', () {
      expect(EditorSceneEnvironment.describeLevel([environmentActor()])!.skyVisible, isTrue);
    });

    test('hiding the procedural sky gives the static skybox back', () {
      final d = EditorSceneEnvironment.describeLevel(
          [environmentActor(), skyActor(visible: false)])!;
      expect(d.skyVisible, isTrue);
    });
  });

  group('EditorProceduralSky', () {
    test('is inert before it is attached to an engine', () {
      final sky = EditorProceduralSky();
      expect(sky.isActive, isFalse);
      sky.apply(LuminaProceduralSkyDescription.defaults);
      expect(sky.isActive, isFalse, reason: 'nothing native exists without an engine');
      expect(sky.advance(1.0), isNull);
      sky.detach();
    });

    test('advance is a no-op without a running day cycle', () {
      final sky = EditorProceduralSky();
      sky.apply(const LuminaProceduralSkyDescription(dayCycleSpeed: 0.0));
      expect(sky.advance(1.0), isNull);
    });

    test('applying null tears the sky down', () {
      final sky = EditorProceduralSky();
      sky.apply(LuminaProceduralSkyDescription.defaults);
      sky.apply(null);
      expect(sky.description, isNull);
      expect(sky.isActive, isFalse);
    });
  });

  group('Level round-trip', () {
    test('a placed procedural sky survives save and reload with every parameter', () async {
      final vm = makeEditor();
      addTearDown(vm.dispose);

      vm.spawnNewActor('ProceduralSky');
      final placed = vm.actors.singleWhere((a) => a.type == 'ProceduralSky');
      final component =
          placed.components.singleWhere((c) => c.type == 'LuminaProceduralSkyComponent');

      // Author it the way the Details panel does.
      component.properties['timeOfDay'] = 17.25;
      component.properties['cloudCoverage'] = 0.9;
      component.properties['waterStrength'] = 65.0;
      component.properties['dayCycleSpeed'] = 0.75;

      // The actor map is what `metadata.actors` stores in the `.lmas`.
      final roundTripped = EditorActorNode.fromMap(placed.toMap());
      final d = EditorProceduralSky.describeLevel([roundTripped]);
      expect(d, isNotNull);
      expect(d!.timeOfDay, 17.25);
      expect(d.cloudCoverage, 0.9);
      expect(d.waterStrength, 65.0);
      expect(d.dayCycleSpeed, 0.75);
    });

    test('the code generator emits the authored sky from the actor map', () {
      final vm = makeEditor();
      addTearDown(vm.dispose);

      vm.spawnNewActor('ProceduralSky');
      final placed = vm.actors.singleWhere((a) => a.type == 'ProceduralSky');
      placed.components
          .singleWhere((c) => c.type == 'LuminaProceduralSkyComponent')
          .properties['timeOfDay'] = 5.5;

      final dart = DartCodeGeneratorService().generateLevelDart(
        levelName: 'L_Main',
        actors: const [],
        actorMaps: [placed.toMap()],
      );
      expect(dart, contains('LuminaProceduralSkyComponent('));
      expect(dart, contains('timeOfDay: 5.5'));
    });
  });

  group('Play-In-Editor', () {
    test('the actor becomes a real LuminaProceduralSkyComponent with its parameters', () {
      final actor = EditorPieGame.mapEditorActor(skyActor(properties: const {
        'timeOfDay': 8.0,
        'cloudCoverage': 0.66,
        'dayCycleSpeed': 2.0,
      }));
      expect(actor, isA<LuminaActor>());
      final root = (actor as LuminaActor).rootComponent;
      expect(root, isA<LuminaProceduralSkyComponent>());
      final sky = root as LuminaProceduralSkyComponent;
      expect(sky.timeOfDay, 8.0);
      expect(sky.cloudCoverage, 0.66);
      expect(sky.dayCycleSpeed, 2.0);
      expect(sky.visible, isTrue);
    });

    test('a hidden actor plays as a hidden sky', () {
      final actor = EditorPieGame.mapEditorActor(skyActor(visible: false)) as LuminaActor;
      expect((actor.rootComponent as LuminaProceduralSkyComponent).visible, isFalse);
    });
  });
}
