import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_core/lumina_core.dart';

class _FakeDnaFilamentAsset implements FilamentAsset {
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
  final fixturePath = '${LuminaWorkspace.package('flutter_riglogic')}/test/fixtures/sample.dna';

  group('RigLogicEvaluator Tests', () {
    test('verifies fixture file exists on disk', () {
      final file = File(fixturePath);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), equals(4164));
    });

    test('loads DNA from file and verifies character metadata and channels', () {
      final evaluator = RigLogicEvaluator.fromFile(fixturePath);
      addTearDown(evaluator.dispose);

      expect(evaluator.isDisposed, isFalse);
      expect(evaluator.characterName, equals('test'));
      expect(evaluator.lodCount, equals(2));
      expect(evaluator.jointCount, equals(9));
      expect(evaluator.blendShapeCount, equals(9));
      expect(evaluator.rawControlCount, equals(9));
      expect(evaluator.animatedMapCount, equals(10));

      expect(evaluator.rawControlNames, containsAll(['RA', 'RB']));
      expect(evaluator.blendShapeNames, containsAll(['BA', 'BB', 'BI']));
      expect(evaluator.jointNames, containsAll(['JA', 'JB', 'JI']));
      expect(evaluator.animatedMapNames, contains('AA'));

      expect(evaluator.indexOfRawControl('RA'), equals(0));
      expect(evaluator.indexOfRawControl('RB'), equals(1));
    });

    test('loads DNA from memory buffer', () {
      final bytes = File(fixturePath).readAsBytesSync();
      final evaluator = RigLogicEvaluator.fromMemory(bytes);
      addTearDown(evaluator.dispose);

      expect(evaluator.characterName, equals('test'));
      expect(evaluator.rawControlCount, equals(9));
      expect(evaluator.blendShapeCount, equals(9));
    });

    test('evaluates controls and computes blend shape weights and joint outputs', () {
      final evaluator = RigLogicEvaluator.fromFile(fixturePath);
      addTearDown(evaluator.dispose);

      // Initial evaluation: all outputs zero/rest
      var result = evaluator.evaluate();
      expect(result.blendShapeWeights['BA'], closeTo(0.0, 0.001));
      expect(result.blendShapeWeights['BB'], closeTo(0.0, 0.001));
      expect(result.jointOutputs.length, equals(81));
      expect(result.animatedMapOutputs.length, equals(10));

      // Set RA to 0.7, RB to 0.4
      evaluator.setRawControl(0, 0.7);
      final setSuccess = evaluator.setControlByName('RB', 0.4);
      expect(setSuccess, isTrue);

      expect(evaluator.getRawControl(0), closeTo(0.7, 0.001));
      expect(evaluator.getControlByName('RB'), closeTo(0.4, 0.001));

      // Evaluate
      result = evaluator.evaluate();
      expect(result.blendShapeWeights['BA'], closeTo(0.7, 0.001));
      expect(result.blendShapeWeights['BB'], closeTo(0.4, 0.001));
      expect(result.blendShapeWeights['BC'], closeTo(0.0, 0.001));

      // Animated map outputs
      expect(result.animatedMapOutputs[0], closeTo(0.7, 0.001));
      expect(result.animatedMapOutputs[1], closeTo(0.86, 0.001));
      expect(result.animatedMapOutputs[6], closeTo(0.4, 0.001));

      // Reset controls
      evaluator.resetControls();
      expect(evaluator.getRawControl(0), equals(0.0));
      result = evaluator.evaluate();
      expect(result.blendShapeWeights['BA'], closeTo(0.0, 0.001));
    });

    test('applyToSkinnedMesh sets matching morph targets on mesh component', () {
      final evaluator = RigLogicEvaluator.fromFile(fixturePath);
      addTearDown(evaluator.dispose);

      final asset = _FakeDnaFilamentAsset();
      asset.setEntityTargets(1, ['BA', 'BB', 'unrelated_morph']);

      final comp = LuminaSkinnedMeshComponent();
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final actor = LuminaActor();
      actor.addComponent(comp);
      world.persistentLevel.registerActor(actor);

      comp.discoverMorphTargets(asset);

      evaluator.setControlByName('RA', 0.85);
      evaluator.setControlByName('RB', 0.35);

      final result = evaluator.applyToSkinnedMesh(comp);

      expect(result.blendShapeWeights['BA'], closeTo(0.85, 0.001));
      expect(result.blendShapeWeights['BB'], closeTo(0.35, 0.001));

      expect(comp.getMorphTarget('BA'), closeTo(0.85, 0.001));
      expect(comp.getMorphTarget('BB'), closeTo(0.35, 0.001));
      expect(comp.getMorphTarget('unrelated_morph'), equals(0.0));
    });

    test('disposed evaluator throws on operation', () {
      final evaluator = RigLogicEvaluator.fromFile(fixturePath);
      evaluator.dispose();
      expect(evaluator.isDisposed, isTrue);

      expect(() => evaluator.evaluate(), throwsStateError);
      expect(() => evaluator.setRawControl(0, 0.5), throwsStateError);
      expect(() => evaluator.getRawControl(0), throwsStateError);
    });
  });
}
