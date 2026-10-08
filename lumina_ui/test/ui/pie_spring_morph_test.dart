import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/details/models/component_property_registry.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// Play builds a placed skeletal mesh with spring-driven morph targets as
/// the generated game does: an animated mesh plus its springs.
void main() {
  EditorActorNode character({bool springs = true}) {
    final actor = EditorActorNode(id: 'mh', name: 'Ada', type: 'SkeletalMesh', location: [0, 0, 0], meshAssetPath: 'contents/Characters/Ada.lmas');
    if (springs) {
      actor.components.add(EditorComponentNode(
        id: 'mh_c0',
        type: 'LuminaSpringMorphComponent',
        name: 'Breast Jiggle',
        properties: {
          'amplitude': 0.6,
          'springs': [
            {'name': 'left', 'bone': 'spine_05', 'offset': [9.0, -4.0, 12.0], 'morphs': {'-y': 'BreastJiggleDownL'}},
          ],
        },
      ));
    }
    return actor;
  }

  test('a skeletal mesh with springs plays as an animated mesh with them', () {
    final built = EditorPieGame.mapEditorActor(character()) as LuminaActor;
    expect(built.rootComponent, isA<LuminaAnimatedMeshComponent>());
    // After its mesh, so they tick after it.
    expect(built.components.indexWhere((c) => c is LuminaSpringMorphComponent), greaterThan(built.components.indexOf(built.rootComponent)));
    final springs = built.components.whereType<LuminaSpringMorphComponent>().single;
    expect(springs.amplitude, 0.6);
    expect(springs.springs.single.bone, 'spine_05');
    expect(springs.springs.single.morphs['-y'], 'BreastJiggleDownL');
  });

  test('a skeletal mesh without springs plays as before', () {
    final built = EditorPieGame.mapEditorActor(character(springs: false)) as LuminaActor;
    expect(built.rootComponent, isNot(isA<LuminaAnimatedMeshComponent>()));
    expect(built.components.whereType<LuminaSpringMorphComponent>(), isEmpty);
  });

  test('the Details panel describes the spring component', () {
    final d = ComponentPropertyRegistry.descriptors['LuminaSpringMorphComponent']!;
    expect([for (final p in d.properties) p.id], ['enabled', 'amplitude', 'stiffnessScale', 'dampingScale']);
  });
}
