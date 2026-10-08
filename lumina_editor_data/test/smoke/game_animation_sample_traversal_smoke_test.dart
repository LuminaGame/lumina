import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/testing.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import 'support/gasp_sandbox.dart';

/// Traversal in the built Game Animation Sample project on GPU 1: the
/// MetaHuman walks or runs (project input: W, Left Shift) at traversable
/// blocks of `L_Sandbox` and presses Space in front of them — the
/// character Blueprint's Jump tries a traversal action first: a hurdle over
/// a thin wall, a vault off a platform's edge, a low and a high mantle. The
/// project is built locally from the sample's export and a MetaHuman
/// (neither can be shipped): the scenario skips without it.
const _w = SmokeVideo.defaultWidth;
const _h = SmokeVideo.defaultHeight;

String get _projectDir =>
    Platform.environment['LUMINA_GASP_PROJECT_DIR'] ?? '${LuminaWorkspace.home}/Lumina Projects/game_animation_sample';

/// One block run at: its name in L_Sandbox, the authoring direction of the
/// approach (unit, Z up), how far before its face to start, run or walk, and
/// the action the check should find.
class _Approach {
  final String label;
  final String block;
  final List<double> direction;
  final double startDistance;
  final bool run;
  final LuminaTraversalActionType action;
  const _Approach(this.label, this.block, this.direction, this.startDistance, this.run, this.action);
}

void main() {
  final level = File('$_projectDir/${GaspSandboxLevel.levelPath}');
  final skip = level.existsSync() ? false : 'the Game Animation Sample project is not built here ($_projectDir)';

  test('game animation sample: the MetaHuman hurdles, vaults and mantles L_Sandbox blocks on Jump', () async {
    const name = 'game animation sample: the MetaHuman hurdles, vaults and mantles L_Sandbox blocks on Jump';
    final s = await GaspSandbox.open(_projectDir);
    final character = s.character;
    final traversal = character.blueprintComponents['traversal'];
    expect(traversal, isA<LuminaTraversalComponent>(), reason: 'the project was built with traversal rows');
    final t = traversal! as LuminaTraversalComponent;
    final halfHeight = GaspCharacterContent.capsuleHalfHeight;
    final actors = ((jsonDecode(level.readAsStringSync()) as Map)['metadata']['actors'] as List).cast<Map>();
    ({List<double> center, List<double> size}) block(String n) {
      final a = actors.firstWhere((a) => a['name'] == n);
      final p = Map<String, dynamic>.from(((a['components'] as List).first as Map)['properties'] as Map);
      return (
        center: [for (final v in (a['location'] as List)) (v as num).toDouble()],
        size: [for (final k in ['sizeX', 'sizeY', 'sizeZ']) (p[k] as num).toDouble()],
      );
    }

    const approaches = [
      _Approach('01 hurdle (walk)', 'LevelBlock_Traversable8', [0, 1], 260, false, LuminaTraversalActionType.hurdle),
      _Approach('02 hurdle (run)', 'LevelBlock_Traversable9', [0, 1], 420, true, LuminaTraversalActionType.hurdle),
      _Approach('03 low mantle (walk)', 'LevelBlock_Traversable4', [0, 1], 260, false, LuminaTraversalActionType.mantle),
      _Approach('04 high mantle (run)', 'LevelBlock_Traversable24', [0, 1], 420, true, LuminaTraversalActionType.mantle),
      _Approach('05 vault off a platform (walk)', 'LevelBlock_Traversable14', [0, 1], 200, false, LuminaTraversalActionType.vault),
    ];

    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    var frame = 0;
    void tick() {
      s.pc.onTick(1 / 60);
      s.world.tick(1 / 60);
      if ((frame++).isEven) video.addFrame(s.capture());
    }

    /// The controller yaw (degrees) whose movement forward is [dir]
    /// (authoring).
    double controlYawFor(List<double> dir) {
      var best = 0.0, bestDot = -2.0;
      for (var yaw = 0.0; yaw < 360.0; yaw += 90.0) {
        s.pc.controlRotation = Vector3(0, yaw, 0);
        final r = LuminaBlueprintFunctionLibrary.getControlRotation(character);
        final f = LuminaBlueprintFunctionLibrary.getForwardVector(LuminaBlueprintFunctionLibrary.makeRotator(0, 0, r.z));
        final dot = f.x * dir[0] + f.y * dir[1];
        if (dot > bestDot) {
          bestDot = dot;
          best = yaw;
        }
      }
      return best;
    }

    final results = <String, String>{};
    for (final a in approaches) {
      final b = block(a.block);
      // The block's near face along the approach, and the floor it stands on.
      final halfAlong = (a.direction[0].abs() * b.size[0] + a.direction[1].abs() * b.size[1]) / 2;
      final bottom = b.center[2] - b.size[2] / 2;
      final face = [b.center[0] - a.direction[0] * halfAlong, b.center[1] - a.direction[1] * halfAlong];
      final start = [face[0] - a.direction[0] * a.startDistance, face[1] - a.direction[1] * a.startDistance];
      character.characterMovement.stopMovementImmediately();
      character.actorLocation = LuminaAxes.location([start[0], start[1], bottom + halfHeight + 2]);
      final runtimeDir = LuminaAxes.location([a.direction[0], a.direction[1], 0]);
      LuminaMotionMatchingCharacter.setFacingYaw(character, math.atan2(runtimeDir.x, runtimeDir.z));
      s.pc.controlRotation = Vector3(-15, controlYawFor(a.direction), 0);
      for (var i = 0; i < 30; i++) {
        tick();
      }
      final hold = [LuminaKey.keyW, if (a.run) LuminaKey.keyLeftShift];
      for (final k in hold) {
        s.input.injectKeyDown(k);
      }
      final before = t.actionCount;
      var pressed = false;
      for (var i = 0; i < 300 && t.actionCount == before; i++) {
        final p = LuminaAxes.toAuthoringLocation(character.actorLocation);
        final toFace = (face[0] - p[0]) * a.direction[0] + (face[1] - p[1]) * a.direction[1];
        if (!pressed && toFace < (a.run ? 230 : 110)) {
          pressed = true;
          s.input.injectKeyDown(LuminaKey.keySpace);
        } else if (pressed) {
          s.input.injectKeyUp(LuminaKey.keySpace);
        }
        tick();
        if (pressed && t.actionCount == before && !t.isTraversing && character.characterMovement.isFalling) break;
      }
      s.input.injectKeyUp(LuminaKey.keySpace);
      expect(t.actionCount, before + 1, reason: '${a.label}: ${t.lastCheck}');
      expect(t.lastCheck!.actionType, a.action, reason: '${a.label}: ${t.lastCheck}');
      var shot = false;
      while (t.isTraversing) {
        tick();
        final p = t.player;
        if (!shot && p != null && p.windows.isNotEmpty && p.time >= p.windows.first.end) {
          shot = true;
          SmokeArtifacts.saveScreenshot('$name — ${a.label}', SmokeArtifacts.encodePng(_w, _h, s.capture()),
              usedAssets: s.usedAssets.toList(),
              metrics: {'clip': t.lastChoice!.animation.clip, 'check': '${t.lastCheck}'});
        }
      }
      for (var i = 0; i < 60; i++) {
        tick();
      }
      for (final k in hold) {
        s.input.injectKeyUp(k);
      }
      for (var i = 0; i < 40; i++) {
        tick();
      }
      final feet = LuminaAxes.toAuthoringLocation(character.actorLocation)[2] - halfHeight;
      results[a.label] = '${t.lastChoice!.animation.clip} (start ${t.lastChoice!.startTime.toStringAsFixed(2)} s): '
          '${t.lastCheck}; feet at ${feet.toStringAsFixed(1)} cm, state ${s.anim.currentState}';
      expect(s.mesh.poseDriver, same(s.anim.motionMatching.player), reason: '${a.label}: motion matching took the mesh back');
      if (a.action == LuminaTraversalActionType.mantle) {
        expect(feet, closeTo(b.center[2] + b.size[2] / 2, 6), reason: '${a.label}: standing on the block');
      }
    }
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert(results));
    expect(video.seconds, greaterThanOrEqualTo(SmokeArtifacts.minimumVideoSeconds));
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: s.usedAssets.toList());
  }, skip: skip, timeout: const Timeout(Duration(minutes: 20)));
}
