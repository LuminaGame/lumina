import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/blueprint_codegen/blueprint_dart_generator.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'anim_blueprints.dart';
import 'anim_rig.dart';
import 'generated/abp_character.g.dart';

/// The Anim Blueprint's aim offset clamps, splits the aim
/// across its bones by weight, interpolates, round-trips and generates.
void main() {
  double overrideDegrees(RecordingMesh mesh, String bone) => mesh.jointOverrides[bone]!.rotationDegrees;

  /// A rig whose character a (never ticked) player controller possesses, so
  /// ABP_Character's update graph reads AimYaw / AimPitch = control − actor
  /// rotation from [aim] while the body stays put.
  ({AnimRig rig, RecordingMesh mesh, LuminaPlayerController pc}) rigWithAim(
      [LuminaAnimBlueprintFactory? factory]) {
    final rig = AnimRig.abp(factory ?? (m) => templateAnimClass().instantiate(m)..random = math.Random(1));
    final pc = LuminaPlayerController()..possess(rig.character);
    return (rig: rig, mesh: rig.mesh, pc: pc);
  }

  /// Points the controller [yaw] / [pitch] degrees off the body.
  void aim(({AnimRig rig, RecordingMesh mesh, LuminaPlayerController pc}) r, double yaw, double pitch) =>
      r.pc.controlRotation = Vector3(pitch, yaw, 0.0);

  test('ABP_Character carries the aim offset (spine_03 / neck_01 / Head, AimYaw / AimPitch, ±80 / ±45, speed 10)', () {
    final aim = LuminaThirdPersonContent.animBlueprint.aimOffset!;
    expect(aim.bones.map((b) => b.name), ['spine_03', 'neck_01', 'Head']);
    expect(aim.bones.map((b) => b.weight), [0.15, 0.25, 0.6]);
    expect(aim.yawVariable, 'AimYaw');
    expect(aim.pitchVariable, 'AimPitch');
    expect(aim.maxYaw, 80.0);
    expect(aim.maxPitch, 45.0);
    expect(aim.interpSpeed, 10.0);
    expect(LuminaThirdPersonContent.animBlueprint.variables.map((v) => v.name), containsAll(['AimYaw', 'AimPitch']));
    expect(validateAnimBlueprint(LuminaThirdPersonContent.animBlueprint, blendSpaces: templateBlendSpaces()).where((d) => d.isError), isEmpty);
  });

  test('yaw 100 clamps to 80 and splits 12 / 20 / 48 degrees; pitch −60 clamps to −45; the target is reached within 0.5 s at speed 10', () {
    final r = rigWithAim();
    final anim = r.rig.anim!;
    aim(r, 100.0, 0.0);
    r.rig.walk(Vector3.zero(), 30);
    expect(anim.variables['AimYaw'], closeTo(100.0, 1e-9), reason: 'the update graph: control − actor yaw');
    expect(anim.aimYaw, closeTo(80.0, 0.6), reason: 'clamped and settled after 0.5 s (e^-5)');
    expect(overrideDegrees(r.mesh, 'spine_03'), closeTo(12.0, 0.2));
    expect(overrideDegrees(r.mesh, 'neck_01'), closeTo(20.0, 0.2));
    expect(overrideDegrees(r.mesh, 'Head'), closeTo(48.0, 0.5), reason: '0.6 × 80, 99.3 % of the way after 0.5 s');
    expect(r.mesh.jointOverrides.keys, ['spine_03', 'neck_01', 'Head']);

    aim(r, 0.0, -60.0);
    r.rig.walk(Vector3.zero(), 30);
    expect(anim.variables['AimPitch'], closeTo(-60.0, 1e-9));
    expect(anim.aimPitch, closeTo(-45.0, 0.4));
    expect(anim.aimYaw.abs(), lessThan(0.6));
    expect(overrideDegrees(r.mesh, 'Head'), closeTo(27.0, 0.3), reason: '0.6 × 45');

    // Interpolation: one 1/60 s step covers 1 − e^(−10/60) ≈ 15 % of the way.
    aim(r, 60.0, -45.0);
    final before = anim.aimYaw;
    r.rig.walk(Vector3.zero(), 1);
    expect(anim.aimYaw - before, closeTo((60.0 - before) * (1 - math.exp(-10 / 60)), 1e-6));
  });

  test('a positive AimPitch (the camera looking up) turns the aim bones up, a negative one down', () {
    for (final (pitch, sign) in [(30.0, 1.0), (-30.0, -1.0)]) {
      final r = rigWithAim();
      aim(r, 0.0, pitch);
      r.rig.walk(Vector3.zero(), 30);
      // The body faces its drawn −Z at yaw 0, so the turn is the world turn.
      final forward = r.mesh.jointOverrides['Head']!.rotation.rotateVector(Vector3(0, 0, -1));
      expect(forward.y * sign, greaterThan(0.2), reason: 'AimPitch $pitch turns the head forward to $forward');
    }
  });

  test('the aim offset round-trips through JSON', () {
    const aim = LuminaAnimAimOffset(
      bones: [LuminaAnimAimOffsetBone('neck_01', 0.4), LuminaAnimAimOffsetBone('head', 0.6)],
      yawVariable: 'LookYaw',
      pitchVariable: 'LookPitch',
      maxYaw: 70,
      maxPitch: 30,
      interpSpeed: 6,
    );
    final doc = LuminaAnimBlueprintDocument(aimOffset: aim);
    final json = doc.toJson();
    expect(json['aimOffset'], {
      'bones': [
        {'name': 'neck_01', 'weight': 0.4},
        {'name': 'head', 'weight': 0.6},
      ],
      'yawVariable': 'LookYaw',
      'pitchVariable': 'LookPitch',
      'maxYaw': 70.0,
      'maxPitch': 30.0,
      'interpSpeed': 6.0,
    });
    final back = LuminaAnimBlueprintDocument.fromJson(json).aimOffset!;
    expect(back.toJson(), aim.toJson());
    expect(LuminaAnimBlueprintDocument.fromJson(LuminaAnimBlueprintDocument().toJson()).aimOffset, isNull);
  });

  test('the generated ABP_Character carries the same aim offset and aims the same as the VM', () {
    final generated = const BlueprintDartGenerator().generateAnimBlueprint(LuminaThirdPersonContent.animBlueprint,
        className: 'AbpCharacter', assetPath: LuminaThirdPersonContent.projectAnimBlueprintPath, blendSpaces: templateBlendSpaces());
    expect(generated.errors, isEmpty);
    expect(generated.code, contains('aimOffset: const LuminaAnimAimOffset('));
    expect(generated.code, contains("LuminaAnimAimOffsetBone('Head', 0.6)"));

    final mesh = RecordingMesh();
    final gen = AbpCharacter(mesh: mesh);
    expect(gen.aimOffset!.toJson(), LuminaThirdPersonContent.animBlueprint.aimOffset!.toJson());

    // Both instances, fed the same variables, write the same head override.
    final vmRig = rigWithAim();
    final genRig = rigWithAim((mm) => AbpCharacter(mesh: mm)..random = math.Random(1));
    for (final r in [vmRig, genRig]) {
      aim(r, 50.0, 10.0);
      r.rig.walk(Vector3.zero(), 20);
    }
    expect(vmRig.rig.anim!.aimYaw, greaterThan(40.0), reason: 'interpolating toward 50');
    expect(genRig.rig.anim!.aimYaw, closeTo(vmRig.rig.anim!.aimYaw, 1e-9));
    expect(overrideDegrees(genRig.mesh, 'Head'), closeTo(overrideDegrees(vmRig.mesh, 'Head'), 1e-9));
  });
}
