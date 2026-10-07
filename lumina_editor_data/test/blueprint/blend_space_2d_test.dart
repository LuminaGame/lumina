import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../../lumina/test/blueprint/anim_blueprints.dart';
import '../../../lumina/test/blueprint/anim_rig.dart';
import '../../../lumina/test/blueprint/generated/abp_character.g.dart';

/// The Third Person template's BS_Locomotion — Direction ×
/// Speed with the walk row at walkReferenceSpeed and the jog row at
/// jogReferenceSpeed — weights its samples bilinearly, plays the dominant
/// one, and plays it at the ground speed over that sample's row.
void main() {
  final space = LuminaThirdPersonContent.locomotionBlendSpace;
  const walk = LuminaThirdPersonContent.walkReferenceSpeed;
  const jog = LuminaThirdPersonContent.jogReferenceSpeed;
  const midway = (walk + jog) / 2;

  test('BS_Locomotion: two axes, the eight walks on the walk row and the eight jogs on the jog row, backward at ±180', () {
    expect(LuminaThirdPersonContent.locomotionBlendSpaceName, 'BS_Locomotion');
    expect(space.axes.map((a) => a.name), ['Direction', 'Speed']);
    expect(space.rows, [walk, jog]);
    expect(space.samples, hasLength(18));
    for (final (clips, row) in [(LuminaThirdPersonContent.walkClips, walk), (LuminaThirdPersonContent.jogClips, jog)]) {
      final inRow = space.samples.where((s) => s.y == row).toList();
      expect(inRow.map((s) => s.clip).toSet(), clips.values.toSet());
      expect(inRow.first.x, -180.0);
      expect(inRow.last.x, 180.0);
      expect(inRow.first.clip, clips[LuminaLocomotionDirection.backward]);
    }
    expect(LuminaThirdPersonContent.jogClips.values, LuminaThirdPersonClips.jogs);
    final json = space.toJson();
    expect(LuminaBlendSpaceDocument.fromJson(json).toJson(), json);
  });

  test('bilinear weights: (0, jog) is all Jog_Fwd_Loop; (22.5, midway) splits four samples a quarter each', () {
    final atJog = space.weights(0.0, jog);
    expect(atJog['Jog_Fwd_Loop'], greaterThanOrEqualTo(0.95));
    expect(space.dominant(0.0, jog)!.clip, 'Jog_Fwd_Loop');

    final between = space.weights(22.5, midway);
    for (final clip in ['Walk_Fwd_Loop', 'Walk_Fwd_Right_Loop', 'Jog_Fwd_Loop', 'Jog_Fwd_Right_Loop']) {
      expect(between[clip], closeTo(0.25, 1e-9), reason: clip);
    }
    expect(between.values.fold(0.0, (a, b) => a + b), closeTo(1.0, 1e-9));

    // On a sample's own direction only the two rows share it; clamped outside the rows.
    final at45 = space.weights(45.0, walk + 0.25 * (jog - walk));
    expect(at45['Walk_Fwd_Right_Loop'], closeTo(0.75, 1e-9));
    expect(at45['Jog_Fwd_Right_Loop'], closeTo(0.25, 1e-9));
    expect(space.weights(-90.0, 0.0), {'Walk_Left_Loop': 1.0});
    expect(space.weights(90.0, 900.0), {'Jog_Right_Loop': 1.0});
    // Backward wraps: ±180 are the same clip.
    expect(space.weights(179.0, jog).keys, containsAll(['Jog_Bwd_Loop']));
    expect(space.dominant(-175.0, walk)!.clip, 'Walk_Bwd_Loop');

    // Past midway the jog row dominates; before it, the walk row.
    expect(space.dominant(0.0, midway - 1)!.clip, 'Walk_Fwd_Loop');
    expect(space.dominant(0.0, midway + 1)!.clip, 'Jog_Fwd_Loop');

    // A 1D space keeps its line weights.
    final walk1d = LuminaThirdPersonContent.walkBlendSpace;
    expect(walk1d.weights(22.5), {'Walk_Fwd_Loop': 0.5, 'Walk_Fwd_Right_Loop': 0.5});
  });

  group('the Walk state on ABP_Character', () {
    ({AnimRig rig, LuminaAnimBlueprintInstance anim}) rigAt(double speed, {LuminaAnimBlueprintFactory? factory}) {
      final r = AnimRig.abp(
          factory ?? (m) => templateAnimClass().instantiate(m)..clipDurationFallbacks.addAll(templateClipDurations),
          maxWalkSpeed: speed);
      return (rig: r, anim: r.anim!);
    }

    test('plays each row at rate 1 on its own reference speed and holds the dominant row between them', () {
      for (final (speed, clip, rate) in [
        (walk, 'Walk_Fwd_Loop', 1.0),
        (jog, 'Jog_Fwd_Loop', 1.0),
        (300.0, 'Walk_Fwd_Loop', 300.0 / walk),
        (420.0, 'Jog_Fwd_Loop', 420.0 / jog),
      ]) {
        final r = rigAt(speed);
        r.rig.walk(Vector3(0, 0, -1), 90);
        expect(r.anim.currentState, 'Walk', reason: '$speed');
        expect(r.anim.variables['GroundSpeed'], closeTo(speed, 1.0), reason: '$speed');
        expect(r.rig.mesh.currentClip, clip, reason: '$speed');
        expect(r.rig.mesh.playRate, closeTo(rate, 0.01), reason: '$speed: the ground speed over the playing row');
        final weights = r.anim.blendWeights;
        expect(weights[clip], greaterThan(0.5), reason: '$speed');
        expect(weights.values.fold(0.0, (a, b) => a + b), closeTo(1.0, 1e-9));
      }
    });

    test('the generated ABP_Character carries the same 2D blend space and plays the same clips, rates and weights as the VM', () {
      final generated = const BlueprintDartGenerator().generateAnimBlueprint(LuminaThirdPersonContent.animBlueprint,
          className: 'AbpCharacter', assetPath: LuminaThirdPersonContent.projectAnimBlueprintPath, blendSpaces: templateBlendSpaces());
      expect(generated.errors, isEmpty);
      expect(generated.code, contains("LuminaBlendSpaceAxis('Speed', 0.0, 600.0)"));
      expect(generated.code, contains("LuminaBlendSpaceSample('Jog_Fwd_Loop', 0.0, 600.0)"));
      expect(generated.code, contains('rateRows: true'));

      final vm = rigAt(480.0);
      final gen = rigAt(480.0,
          factory: (m) => AbpCharacter(mesh: m)
            ..clipDurationFallbacks.addAll(templateClipDurations)
            ..random = math.Random(1));
      for (final (direction, frames) in [
        (Vector3(0, 0, -1), 60),
        (Vector3(-1, 0, 0), 60),
        (Vector3(1, 0, -1), 60),
        (Vector3(0, 0, 1), 60),
        (Vector3.zero(), 30),
      ]) {
        for (var i = 0; i < frames; i++) {
          vm.rig.walk(direction, 1);
          gen.rig.walk(direction, 1);
          expect(gen.rig.mesh.currentClip, vm.rig.mesh.currentClip);
          expect(gen.rig.mesh.playRate, closeTo(vm.rig.mesh.playRate, 1e-12));
          expect(gen.anim.blendWeights, vm.anim.blendWeights);
        }
      }
    });
  });

  test('the Dart locomotion driver picks the same row: jog past midway at the jog reference, walk below', () {
    const clips = LuminaThirdPersonContent.mannequinLocomotion;
    expect(clips.hasJog, isTrue);
    expect(clips.jog, LuminaThirdPersonContent.jogClips);
    expect(clips.allClips, containsAll(LuminaThirdPersonClips.jogs));
    final facing = Vector3(0, 0, -1);
    LuminaLocomotionPose at(double speed, Vector3 dir) =>
        selectLocomotionPose(clips: clips, velocity: dir.normalized() * speed, facing: facing, isFalling: false);
    expect(at(300, Vector3(0, 0, -1)).toString(), 'Walk_Fwd_Loop@${300 / walk}');
    expect(at(480, Vector3(0, 0, -1)).toString(), 'Jog_Fwd_Loop@${480 / jog}');
    expect(at(480, Vector3(-1, 0, 0)).clip, 'Jog_Left_Loop');
    expect(at(midway + 1, Vector3(0, 0, 1)).clip, 'Jog_Bwd_Loop');
    expect(at(midway - 1, Vector3(0, 0, 1)).clip, 'Walk_Bwd_Loop');
    expect(clips.isCycleClip('Jog_Fwd_Loop') && clips.isCycleClip('Walk_Fwd_Loop'), isTrue);
  });

  test('rateRows round-trips through the pose JSON', () {
    final walkState = LuminaThirdPersonContent.animBlueprint.stateMachine!.state('Walk')!.pose;
    expect(walkState.blendSpace, LuminaThirdPersonContent.projectLocomotionBlendSpacePath);
    expect(walkState.yVariable, 'GroundSpeed');
    expect(walkState.rateRows, isTrue);
    expect(walkState.toJson()['rateRows'], isTrue);
    expect(LuminaAnimPose.fromJson(walkState.toJson()).rateRows, isTrue);
    expect(const LuminaAnimPose.blendSpace('bs', xVariable: 'x').toJson().containsKey('rateRows'), isFalse);
  });
}
