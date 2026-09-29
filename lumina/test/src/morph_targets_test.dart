import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';

// Fake implementations for tests
class FakeFilamentAsset implements FilamentAsset {
  final Map<int, List<String?>> _entitiesToTargets = {};

  void setEntityTargets(int entity, List<String?> targets) {
    _entitiesToTargets[entity] = targets;
  }

  @override
  int getMorphTargetCountAt(int entity) {
    return _entitiesToTargets[entity]?.length ?? 0;
  }

  @override
  String? getMorphTargetNameAt(int entity, int target) {
    return _entitiesToTargets[entity]?[target];
  }

  @override
  List<int> get entities => _entitiesToTargets.keys.toList();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Morph Targets Tests', () {
    late FakeFilamentAsset asset;
    late LuminaSkinnedMeshComponent comp;
    late LuminaWorld world;

    setUp(() {
      asset = FakeFilamentAsset();
      comp = LuminaSkinnedMeshComponent();
      world = LuminaWorld(worldType: LuminaWorldType.game);
      
      final actor = LuminaActor();
      actor.addComponent(comp);
      world.persistentLevel.registerActor(actor);
    });

    test('Fake asset: entity 10 with targets [smile, frown], entity 11 with [smile]', () {
      asset.setEntityTargets(10, ['smile', 'frown']);
      asset.setEntityTargets(11, ['smile']);

      comp.discoverMorphTargets(asset);

      expect(comp.morphTargetNames, containsAll(['smile', 'frown']));

      comp.setMorphTarget('smile', 0.7);
      
      expect(comp.getMorphTarget('smile'), closeTo(0.7, 0.001));
      expect(comp.getMorphTarget('frown'), 0.0);
    });

    test('setMorphTarget with unknown target throws', () {
      asset.setEntityTargets(10, ['smile', 'frown']);
      comp.discoverMorphTargets(asset);

      expect(() => comp.setMorphTarget('blink', 1.0), throwsArgumentError);
    });

    test('clearMorphTargets resets to 0', () {
      asset.setEntityTargets(10, ['smile', 'frown']);
      comp.discoverMorphTargets(asset);

      comp.setMorphTarget('smile', 1.0);
      expect(comp.getMorphTarget('smile'), 1.0);
      
      comp.clearMorphTargets();
      expect(comp.getMorphTarget('smile'), 0.0);
    });

    test('resolveMorphTarget handle speeds up setting', () {
      asset.setEntityTargets(10, ['smile', 'frown']);
      comp.discoverMorphTargets(asset);

      final handle = comp.resolveMorphTarget('smile');
      comp.setMorphTargetByHandle(handle, 0.5);
      
      expect(comp.getMorphTarget('smile'), 0.5);
    });
    
    test('Synthetic names generated for unnamed targets', () {
      asset.setEntityTargets(10, [null, 'frown']);
      comp.discoverMorphTargets(asset);
      
      expect(comp.morphTargetNames, containsAll(['morph_0', 'frown']));
      comp.setMorphTarget('morph_0', 1.0);
      expect(comp.getMorphTarget('morph_0'), 1.0);
    });
  });
}
