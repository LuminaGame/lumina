import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/testing.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'support/gasp_sandbox.dart';

/// Falls and the ragdoll in the built Game Animation Sample project on GPU
/// 1: the MetaHuman walks off the top of L_Sandbox's 7 m block, goes limp in
/// the air (its joints pulled toward the sample's flail clip), lands,
/// settles and gets up with the sample's get-up clip that lies like it; then
/// R makes it limp on the floor and R again gets it up. The project is built
/// locally from the sample's export and a MetaHuman (neither can be
/// shipped): the scenario skips without it.
const _w = SmokeVideo.defaultWidth;
const _h = SmokeVideo.defaultHeight;

String get _projectDir =>
    Platform.environment['LUMINA_GASP_PROJECT_DIR'] ?? '${LuminaWorkspace.home}/Lumina Projects/game_animation_sample';

void main() {
  final level = File('$_projectDir/${GaspSandboxLevel.levelPath}');
  final skip = level.existsSync() ? false : 'the Game Animation Sample project is not built here ($_projectDir)';

  test('game animation sample: the MetaHuman falls off the high block into a ragdoll, gets up, and R toggles the ragdoll', () async {
    const name = 'game animation sample: the MetaHuman falls off the high block into a ragdoll, gets up, and R toggles the ragdoll';
    final s = await GaspSandbox.open(_projectDir);
    final character = s.character;
    final ragdoll = character.getComponent<LuminaRagdollComponent>();
    expect(ragdoll, isNotNull, reason: 'the project was built with the ragdoll');
    final r = ragdoll!;
    await r.ready.timeout(const Duration(minutes: 2));
    s.usedAssets.add(PhysicsAssetGeneration.assetPathFor('contents/meshes/skeletal/SK_MH_Sandbox.lmas'));
    const halfHeight = GaspCharacterContent.capsuleHalfHeight;

    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    var frame = 0;
    final saved = <String>{};
    void shot(String label, Map<String, Object?> metrics) {
      if (!saved.add(label)) return;
      SmokeArtifacts.saveScreenshot('$name — $label', SmokeArtifacts.encodePng(_w, _h, s.capture()),
          usedAssets: s.usedAssets.toList(), metrics: metrics);
    }

    void tick() {
      s.pc.onTick(1 / 60);
      s.world.tick(1 / 60);
      if ((frame++).isEven) video.addFrame(s.capture());
    }

    // On top of LevelBlock6 (top at 700 cm), 60 cm from its +X edge,
    // facing +X with the camera behind.
    final actors = ((jsonDecode(level.readAsStringSync()) as Map)['metadata']['actors'] as List).cast<Map>();
    final block = actors.firstWhere((a) => a['name'] == 'LevelBlock6');
    final props = Map<String, dynamic>.from(((block['components'] as List).first as Map)['properties'] as Map);
    final center = [for (final v in (block['location'] as List)) (v as num).toDouble()];
    final top = center[2] + (props['sizeZ'] as num).toDouble() / 2;
    final edgeX = center[0] + (props['sizeX'] as num).toDouble() / 2;
    character.characterMovement.stopMovementImmediately();
    character.actorLocation = LuminaAxes.location([edgeX - 60, center[1], top + halfHeight + 2]);
    final dir = LuminaAxes.location([1, 0, 0]);
    LuminaMotionMatchingCharacter.setFacingYaw(character, math.atan2(dir.x, dir.z));
    for (var i = 0; i < 40; i++) {
      tick();
    }
    shot('01 on the 7 m block', {'feet_cm': LuminaAxes.toAuthoringLocation(character.actorLocation)[2] - halfHeight});

    // Walk off the edge; time the fall into the ragdoll, the landing, the get-up.
    double? limpAt, limpFeet, getUpAt, standAt;
    String? clip;
    r.onGetUpStarted = (c) => clip = c;
    var t = 0.0;
    var worstJoint = 0.0, restingJoint = 0.0;
    final ragdollFrameMicros = <int>[];
    for (var i = 0; i < 12 * 60 && standAt == null; i++) {
      if (r.state == LuminaRagdollState.animated && limpAt == null) {
        character.characterMovement.addInputVector(dir);
      }
      final w = Stopwatch()..start();
      tick();
      if (r.isRagdoll) {
        ragdollFrameMicros.add(w.elapsedMicroseconds);
        worstJoint = math.max(worstJoint, r.ragdoll!.maxJointError);
        if (limpAt != null && t > limpAt + 1.5) restingJoint = math.max(restingJoint, r.ragdoll!.maxJointError);
      }
      t += 1 / 60;
      if (limpAt == null && r.isRagdoll) {
        limpAt = t;
        limpFeet = LuminaAxes.toAuthoringLocation(r.ragdoll!.root.boneFrame().position)[2];
      }
      if (limpAt != null && t > limpAt + 0.2) shot('02 limp in the air', {'pelvis_cm_at_limp': limpFeet});
      if (limpAt != null && t > limpAt + 2.0 && r.isRagdoll) shot('03 lying on the floor', {'joint_error_cm': worstJoint});
      if (getUpAt == null && r.state == LuminaRagdollState.gettingUp) getUpAt = t;
      if (getUpAt != null && t > getUpAt + 0.6 && r.state == LuminaRagdollState.gettingUp) shot('04 getting up', {'clip': clip});
      if (getUpAt != null && r.state == LuminaRagdollState.animated) standAt = t;
    }
    for (var i = 0; i < 60; i++) {
      tick();
    }
    shot('05 standing again', {'state': s.anim.currentState, 'mode': '${character.characterMovement.movementMode}'});

    // R: limp on the spot; R again: up.
    final before = 'state ${r.state}, mode ${character.characterMovement.movementMode} '
        '(${character.characterMovement.customMovementModeIndex}), overlay ${r.overlayClip}';
    s.input.injectKeyDown(LuminaKey.keyR);
    tick();
    s.input.injectKeyUp(LuminaKey.keyR);
    final toggled = r.isRagdoll;
    for (var i = 0; i < 50; i++) {
      tick();
    }
    shot('06 R: ragdoll', {'ragdoll': r.isRagdoll});
    final stillLimp = r.isRagdoll;
    if (r.isRagdoll) {
      s.input.injectKeyDown(LuminaKey.keyR);
      tick();
      s.input.injectKeyUp(LuminaKey.keyR);
    }
    for (var i = 0; i < 480 && r.state != LuminaRagdollState.animated; i++) {
      tick();
    }
    for (var i = 0; i < 60; i++) {
      tick();
    }
    shot('07 R again: up', {'state': '${r.state}'});

    final metrics = {
      'limp_at_s': limpAt,
      'pelvis_height_at_limp_cm': limpFeet,
      'get_up_at_s': getUpAt,
      'standing_at_s': standAt,
      'get_up_clip': clip,
      'worst_joint_error_cm': worstJoint,
      'resting_joint_error_cm': restingJoint,
      'ragdoll_frame_mean_ms': ragdollFrameMicros.isEmpty
          ? null
          : ragdollFrameMicros.reduce((a, b) => a + b) / ragdollFrameMicros.length / 1000,
      'bodies': r.physicsAsset?.bodies.length,
    };
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert(metrics));
    expect(limpAt, isNotNull, reason: 'the fall went limp');
    expect(limpFeet!, greaterThan(60), reason: 'in the air, before touching down');
    expect(getUpAt, isNotNull, reason: 'it settled and started getting up');
    expect(clip, isIn(GaspRagdoll.getUpClips));
    expect(standAt, isNotNull, reason: 'it stood up');
    expect(toggled, isTrue, reason: 'R went limp ($before)');
    expect(stillLimp, isTrue);
    expect(r.state, LuminaRagdollState.animated, reason: 'R again got up');
    expect(character.characterMovement.movementMode, MovementMode.walking);
    // The touchdown at ~1200 cm/s stretches the joints for a few frames;
    // lying down they hold.
    expect(worstJoint, lessThan(15.0));
    expect(restingJoint, lessThan(2.0));
    expect(video.seconds, greaterThanOrEqualTo(SmokeArtifacts.minimumVideoSeconds));
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: s.usedAssets.toList());
  }, skip: skip, timeout: const Timeout(Duration(minutes: 20)));
}
