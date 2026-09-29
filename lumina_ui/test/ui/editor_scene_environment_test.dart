import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/services/editor_scene_environment.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

EditorActorNode _environmentActor({Map<String, dynamic>? sky, bool visible = true}) {
  return EditorActorNode(
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
        properties: sky ?? {},
      ),
    ],
  );
}

void main() {
  group('EditorSceneEnvironment.describeLevel', () {
    // As in the built game, a level without an
    // Environment actor (and no environment section) has no sky and no
    // image-based light; the viewport is lit only by what the level holds.
    test('a level without an Environment actor gets no sky and no ambient light', () {
      expect(EditorSceneEnvironment.describeLevel(const []), isNull);
      expect(
        EditorSceneEnvironment.describeLevel([
          EditorActorNode(id: 'a', name: 'Floor', type: 'StaticMesh', location: [0, 0, 0]),
        ]),
        isNull,
      );
    });

    test('reads the Environment actor LuminaSkyComponent properties', () {
      final d = EditorSceneEnvironment.describeLevel([
        EditorActorNode(id: 'a', name: 'Floor', type: 'StaticMesh', location: [0, 0, 0]),
        _environmentActor(sky: const {
          'mode': 'color',
          'colorHex': '#FF8844',
          'skyIntensity': 55000.0,
          'iblIntensity': 18000.0,
          'rotationDegrees': 120.0,
          'showSun': true,
        }),
      ])!;
      expect(d.useEnvironmentMap, isFalse);
      expect(d.skyIntensity, 55000.0);
      expect(d.iblIntensity, 18000.0);
      expect(d.rotationDegrees, 120.0);
      expect(d.showSun, isTrue);
      expect(d.color, LuminaSkyDescription.colorFromHex('#FF8844'));
    });

    test('hiding the Environment actor in the outliner hides the sky but keeps the ambient light', () {
      final d = EditorSceneEnvironment.describeLevel([_environmentActor(visible: false)])!;
      expect(d.skyVisible, isFalse);
      expect(d.iblIntensity, greaterThan(0));
    });

    test('the levels metadata.environment section wins over the actor components', () {
      final d = EditorSceneEnvironment.describeLevel(
        [
          _environmentActor(sky: const {'colorHex': '#FF0000', 'skyIntensity': 1.0}),
        ],
        environmentSection: const {
          'version': 1,
          'sky': {'mode': 'color', 'colorHex': '#00FF00', 'skyIntensity': 44000.0},
        },
      )!;
      expect(d.skyIntensity, 44000.0);
      expect(d.color, LuminaSkyDescription.colorFromHex('#00FF00'));
    });

    test('an HDRI environment reference is carried through', () {
      final d = EditorSceneEnvironment.describeLevel([
        _environmentActor(sky: const {
          'mode': 'environment',
          'sky_environment': {
            'slot_name': 'sky_environment',
            'asset_id': '',
            'asset_path': 'contents/textures/venetian_crossroads_2k.ktx',
          },
        }),
      ])!;
      expect(d.useEnvironmentMap, isTrue);
      expect(d.environmentAssetPath, 'contents/textures/venetian_crossroads_2k.ktx');
    });
  });

  group('EditorSceneEnvironment', () {
    test('sub-editor previews suppress the sky background but keep the ambient light', () {
      final env = EditorSceneEnvironment(showSkyBackground: false);
      env.apply(LuminaSkyDescription.defaults);
      expect(env.description.skyVisible, isFalse);
      expect(env.description.iblIntensity, LuminaSkyDescription.defaults.iblIntensity);
    });

    test('the level viewport keeps the sky background', () {
      final env = EditorSceneEnvironment();
      env.apply(LuminaSkyDescription.defaults);
      expect(env.description.skyVisible, isTrue);
    });

    test('is inert before it is attached to an engine', () {
      final env = EditorSceneEnvironment();
      expect(env.isAttached, isFalse);
      env.apply(LuminaSkyDescription.defaults);
      env.detach();
      expect(env.isAttached, isFalse);
    });
  });
}
