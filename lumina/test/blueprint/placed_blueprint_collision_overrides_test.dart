import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// A placed Blueprint actor's per-instance collision overrides
/// (stored in the level `.lmas`) are applied by
/// the generated level, as Play-In-Editor applies them.
void main() {
  const doorPath = 'contents/blueprints/BP_Door.lmas';

  LuminaBlueprintDocument door() => LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
        LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
        LuminaBlueprintComponent(
            id: 'box',
            name: 'DoorBox',
            type: 'LuminaBoxComponent',
            parentId: 'root',
            properties: {'boxExtent': [50.0, 10.0, 100.0], 'preset': 'BlockAll', 'generateOverlapEvents': true}),
        LuminaBlueprintComponent(
            id: 'mesh', name: 'Mesh', type: 'LuminaStaticMeshComponent', parentId: 'root', properties: {}),
      ]);

  // As the level Details writes a preset pick (lumina_ui CollisionJson), cut
  // to two keys: the rest keeps the class's values.
  const overlapAll = <String, dynamic>{'preset': 'overlapAll', 'collisionEnabled': true};

  Map<String, dynamic> placedDoor({bool withOverride = true}) => {
        'id': 'door_1',
        'name': 'BP_Door',
        'type': 'Actor',
        'blueprintClass': doorPath,
        'location': [100.0, 0.0, 0.0],
        'rotation': [0.0, 0.0, 0.0],
        'components': [
          {'id': 'door_1.tag', 'type': 'LuminaSceneComponent', 'name': 'Tag', 'properties': {'preset': 'noCollision'}},
          if (withOverride)
            {
              'id': 'door_1.collision.box',
              'type': 'LuminaBoxComponent',
              'name': 'DoorBox',
              'enabled': true,
              'properties': {'blueprintComponentId': 'box', ...overlapAll, 'extra': 1},
            },
          {
            'id': 'door_1.collision.mesh',
            'type': 'LuminaStaticMeshComponent',
            'name': 'Mesh',
            'properties': {'blueprintComponentId': 'mesh', 'meshAssetPath': 'x'},
          },
        ],
      };

  group('LuminaBlueprintCollisionOverrides', () {
    test('fromActorMap keeps the collision keys of the nodes that name a Blueprint component', () {
      expect(LuminaBlueprintCollisionOverrides.fromActorMap(placedDoor()), {'box': overlapAll});
      expect(LuminaBlueprintCollisionOverrides.fromActorMap(placedDoor(withOverride: false)), isEmpty);
      expect(LuminaBlueprintCollisionOverrides.fromActorMap({'id': 'a'}), isEmpty);
    });

    test('apply sets the instance collision on the built component; missing keys keep the class values', () {
      final actor = LuminaBlueprintClass.fromDocument(door(), name: 'BP_Door').instantiate();
      final box = (actor as LuminaBlueprintRuntime).blueprintComponents['box'] as LuminaCollisionComponent;
      expect(box.preset, LuminaCollisionPreset.blockAll);
      final applied = LuminaBlueprintCollisionOverrides.apply(actor, {
        'box': overlapAll,
        'mesh': {'preset': 'blockAll'},
        'missing': {'preset': 'blockAll'},
      });
      expect(applied, 1, reason: 'only the collision component');
      expect(box.preset, LuminaCollisionPreset.overlapAll);
      expect(box.responses[CollisionObjectType.pawn], CollisionResponse.overlap);
      expect(box.generateOverlapEvents, isTrue, reason: 'the override does not name it: the class value stays');
      expect(LuminaBlueprintCollisionOverrides.apply(LuminaActor(), {'box': overlapAll}), 0);
    });

    test('luminaWithCollisionOverrides returns the same actor, overridden', () {
      final actor = LuminaBlueprintClass.fromDocument(door(), name: 'BP_Door').instantiate();
      expect(identical(luminaWithCollisionOverrides(actor, {'box': overlapAll}), actor), isTrue);
      final box = (actor as LuminaBlueprintRuntime).blueprintComponents['box'] as LuminaCollisionComponent;
      expect(box.preset, LuminaCollisionPreset.overlapAll);
    });
  });

  group('generated level', () {
    final generator = DartCodeGeneratorService();
    final transform = 'location: ${_vector3(LuminaAxes.location([100.0, 0.0, 0.0]))}, '
        'rotation: luminaAuthoringRotation(0.0000, 0.0000, 0.0000)';

    test('a placed Blueprint with an override wraps its factory call in luminaWithCollisionOverrides', () {
      final level = generator.generateLevelDart(levelName: 'L_Doors', actors: const [], actorMaps: [placedDoor()]);
      expect(
          level,
          contains("luminaWithCollisionOverrides(luminaBlueprintFactories['$doorPath']!(key: const LuminaObjectKey('door_1'), "
              '$transform), const <String, Map<String, dynamic>>{'
              "'box': <String, dynamic>{'preset': 'overlapAll', 'collisionEnabled': true}}),"));
    });

    test('a placed Blueprint without overrides emits the plain factory line unchanged', () {
      final level = generator.generateLevelDart(
          levelName: 'L_Doors', actors: const [], actorMaps: [placedDoor(withOverride: false)]);
      expect(level, contains("luminaBlueprintFactories['$doorPath']!(key: const LuminaObjectKey('door_1'), $transform),"));
      expect(level, isNot(contains('luminaWithCollisionOverrides')));
    });
  });
}

String _vector3(Vector3 v) {
  String f(double x) => (x == 0 ? 0.0 : x).toStringAsFixed(4);
  return 'Vector3(${f(v.x)}, ${f(v.y)}, ${f(v.z)})';
}
