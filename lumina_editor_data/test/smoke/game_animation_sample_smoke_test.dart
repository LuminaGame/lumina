import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/testing.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'support/gasp_sandbox.dart';

/// The Game Animation Sample example project played on the GPU: its
/// `L_Sandbox`, its game mode spawning the MetaHuman character, and the
/// project input driving idle → walk → run → sprint → stop → crouch walk →
/// jump. The project is built locally from the sample's export and a
/// MetaHuman (neither can be shipped): the scenario skips without it.
const _w = SmokeVideo.defaultWidth;
const _h = SmokeVideo.defaultHeight;

String get _projectDir =>
    Platform.environment['LUMINA_GASP_PROJECT_DIR'] ?? '${LuminaWorkspace.home}/Lumina Projects/game_animation_sample';

void main() {
  final level = File('$_projectDir/${GaspSandboxLevel.levelPath}');
  final skip = level.existsSync() ? false : 'the Game Animation Sample project is not built here ($_projectDir)';

  test('game animation sample: the MetaHuman walks, runs, sprints, stops, crouches and jumps in L_Sandbox', () async {
    const name = 'game animation sample: the MetaHuman walks, runs, sprints, stops, crouches and jumps in L_Sandbox';
    final dir = _projectDir;
    final sandbox = await GaspSandbox.open(dir);
    final world = sandbox.world;
    final pc = sandbox.pc;
    final input = sandbox.input;
    final character = sandbox.character;
    final anim = sandbox.anim;
    final usedAssets = sandbox.usedAssets;
    final meshLoad = sandbox.meshLoad;
    final databasesLoad = sandbox.databasesLoad;
    final capture = sandbox.capture;

    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    final tickMicros = <int>[];
    final renderMicros = <int>[];
    final phaseClips = <String, Set<String>>{};
    final phaseStates = <String, Set<String>>{};
    final phaseSpeeds = <String, double>{};

    double speed() {
      final v = character.characterMovement.velocity;
      return math.sqrt(v.x * v.x + v.z * v.z);
    }

    Future<void> phase(String label, double seconds,
        {List<LuminaKey> hold = const [], List<LuminaKey> tap = const [], double mouseX = 0.0}) async {
      for (final k in tap) {
        input.injectKeyDown(k);
        pc.onTick(1 / 60);
        world.tick(1 / 60);
        input.injectKeyUp(k);
      }
      for (final k in hold) {
        input.injectKeyDown(k);
      }
      final frames = (seconds * 60).round();
      var peak = 0.0;
      for (var f = 0; f < frames; f++) {
        if (mouseX != 0) input.injectAnalog(LuminaKey.mouseX, mouseX);
        final w = Stopwatch()..start();
        pc.onTick(1 / 60);
        world.tick(1 / 60);
        tickMicros.add(w.elapsedMicroseconds);
        final clip = anim.variables[LuminaAnimBlueprintInstance.matchedClipVariable];
        if (clip is String && clip.isNotEmpty) (phaseClips[label] ??= {}).add(clip);
        (phaseStates[label] ??= {}).add(anim.currentState ?? '');
        peak = math.max(peak, speed());
        if (f.isEven) {
          final r = Stopwatch()..start();
          final frame = capture();
          renderMicros.add(r.elapsedMicroseconds);
          video.addFrame(frame);
          if (f == frames - 2) {
            SmokeArtifacts.saveScreenshot('$name — $label', SmokeArtifacts.encodePng(_w, _h, frame),
                usedAssets: usedAssets.toList(),
                metrics: {
                  'phase': label,
                  'speed_cm_s': speed().toStringAsFixed(0),
                  'state': anim.currentState ?? '',
                  'matched_clip': '${anim.variables[LuminaAnimBlueprintInstance.matchedClipVariable] ?? ''}',
                });
          }
        }
      }
      for (final k in hold) {
        input.injectKeyUp(k);
      }
      phaseSpeeds[label] = peak;
    }

    await phase('idle', 1.5);
    await phase('walk', 3.0, tap: const [LuminaKey.keyLeftControl], hold: const [LuminaKey.keyW]);
    await phase('run', 3.0, tap: const [LuminaKey.keyLeftControl], hold: const [LuminaKey.keyW], mouseX: 1.5);
    await phase('sprint', 3.0, hold: const [LuminaKey.keyW, LuminaKey.keyLeftShift]);
    await phase('stop', 2.0);
    await phase('crouch walk', 3.0, tap: const [LuminaKey.keyC], hold: const [LuminaKey.keyW]);
    await phase('stand up', 1.0, tap: const [LuminaKey.keyC]);
    await phase('jump', 1.5, tap: const [LuminaKey.keySpace]);
    await phase('running jump', 3.0, tap: const [LuminaKey.keySpace], hold: const [LuminaKey.keyW]);

    final player = anim.motionMatching.player!;
    String median(List<int> v) {
      final s = [...v]..sort();
      return (s[s.length ~/ 2] / 1000).toStringAsFixed(2);
    }

    final metrics = {
      'mesh_load_s': (meshLoad.inMilliseconds / 1000).toStringAsFixed(1),
      'mesh_and_databases_load_s': (databasesLoad.inMilliseconds / 1000).toStringAsFixed(1),
      'tick_ms_median': median(tickMicros),
      'tick_ms_max': (tickMicros.reduce(math.max) / 1000).toStringAsFixed(2),
      'render_readback_ms_median': median(renderMicros),
      'mm_update_us_mean': player.meanUpdateMicroseconds.toStringAsFixed(0),
      'mm_search_us_mean': player.meanSearchMicroseconds.toStringAsFixed(0),
      'mm_search_us_max': '${player.maxSearchMicroseconds}',
      'mm_rows': '${player.database.index.rowCount}',
      for (final e in phaseSpeeds.entries) 'speed_${e.key.replaceAll(' ', '_')}': e.value.toStringAsFixed(0),
      for (final e in phaseClips.entries) 'clips_${e.key.replaceAll(' ', '_')}': e.value.take(6).join(' '),
    };
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert({'metrics': metrics, 'states': phaseStates.map((k, v) => MapEntry(k, v.toList()))}));

    bool played(String phaseName, String part) => (phaseClips[phaseName] ?? const {}).any((c) => c.contains(part));
    expect(played('walk', 'Walk'), isTrue, reason: '${phaseClips['walk']}');
    expect(played('run', 'Run'), isTrue, reason: '${phaseClips['run']}');
    expect(played('sprint', 'Sprint'), isTrue, reason: '${phaseClips['sprint']}');
    expect(played('crouch walk', 'Crouch'), isTrue, reason: '${phaseClips['crouch walk']}');
    expect(phaseStates['jump'], contains('Air'));
    expect(phaseSpeeds['walk'], closeTo(GaspCharacterContent.walkSpeed, 10));
    expect(phaseSpeeds['run'], closeTo(GaspCharacterContent.runSpeed, 10));
    expect(phaseSpeeds['sprint'], closeTo(GaspCharacterContent.sprintSpeed, 10));
    expect(phaseSpeeds['crouch walk'], closeTo(GaspCharacterContent.crouchSpeed, 10));
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: usedAssets.toList());
  }, skip: skip, timeout: const Timeout(Duration(minutes: 20)));

  test('game animation sample: the MetaHuman stays on the ground after standing, running and block jumps', () async {
    const name = 'game animation sample: the MetaHuman stays on the ground after standing, running and block jumps';
    final s = await GaspSandbox.open(_projectDir);
    final character = s.character;
    final movement = character.characterMovement;
    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    const halfHeight = GaspCharacterContent.capsuleHalfHeight;

    /// The root bone's height above the capsule's feet (cm): 0 when the body
    /// stands where the capsule does.
    double rootAboveFeet() => s.mesh.jointWorldTransform('root')!.getTranslation().y - (character.actorLocation.y - halfHeight);

    final results = <String, String>{};
    var worst = 0.0;
    var worstAt = '';
    Future<void> jump(String label, {List<LuminaKey> hold = const [], double runUp = 0.0, double seconds = 2.5}) async {
      for (final k in hold) {
        s.input.injectKeyDown(k);
      }
      var frame = 0;
      void tick() {
        s.pc.onTick(1 / 60);
        s.world.tick(1 / 60);
        if (frame++ % 2 == 0) video.addFrame(s.capture());
      }

      for (var f = 0; f < (runUp * 60).round(); f++) {
        tick();
      }
      s.input.injectKeyDown(LuminaKey.keySpace);
      tick();
      s.input.injectKeyUp(LuminaKey.keySpace);
      var airborne = false, landed = false, wasFalling = false, reJumps = 0;
      var peak = 0.0;
      var savedPng = false;
      for (var f = 0; f < (seconds * 60).round(); f++) {
        tick();
        if (movement.isFalling) {
          // Walking off a ledge after landing falls again; only rising
          // again would be a jump.
          if (landed && !wasFalling && movement.velocity.y > 50) reJumps++;
          airborne = true;
          wasFalling = true;
        } else if (airborne) {
          wasFalling = false;
          landed = true;
          final above = rootAboveFeet();
          peak = math.max(peak, above);
          if (above > worst) {
            worst = above;
            worstAt = '$label ${s.anim.currentState} ${s.anim.variables[LuminaAnimBlueprintInstance.matchedClipVariable]}';
          }
          if (!savedPng && s.anim.currentState == 'Land') {
            savedPng = true;
            SmokeArtifacts.saveScreenshot('$name — $label landing', SmokeArtifacts.encodePng(_w, _h, s.capture()),
                usedAssets: s.usedAssets.toList(),
                metrics: {'root_above_feet_cm': above.toStringAsFixed(1), 'state': s.anim.currentState ?? ''});
          }
        }
      }
      for (final k in hold) {
        s.input.injectKeyUp(k);
      }
      expect(airborne && landed, isTrue, reason: '$label: jumped and landed');
      expect(reJumps, 0, reason: '$label: one Space press jumps once');
      results[label] = 'root ≤ ${peak.toStringAsFixed(1)} cm above the feet after touchdown';
    }

    await jump('standing jump');
    await jump('running jump', hold: const [LuminaKey.keyW], runUp: 1.0);
    // Onto the top of a block 80–260 cm high, then jump off it forward.
    final block = s.blocks.firstWhere(
        (b) => !b.rotated && b.size[2] >= 80 && b.size[2] <= 260 && b.size[0] >= 150 && b.size[1] >= 150,
        orElse: () => throw StateError('L_Sandbox has no block to jump off'));
    character.actorLocation = LuminaAxes.location([block.center[0], block.center[1], block.center[2] + block.size[2] / 2 + halfHeight + 2]);
    for (var f = 0; f < 30; f++) {
      s.pc.onTick(1 / 60);
      s.world.tick(1 / 60);
      s.engine.flushAndWait();
    }
    expect(movement.isFalling, isFalse, reason: 'standing on the block');
    await jump('jump off a ${block.size[2].round()} cm block', hold: const [LuminaKey.keyW], seconds: 3.5);
    await jump('standing jump after the drop');

    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert({...results, 'worst': '${worst.toStringAsFixed(1)} cm ($worstAt)'}));
    expect(worst, lessThan(5.0), reason: 'after touchdown the body stays on the ground: $worstAt');
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: s.usedAssets.toList());
  }, skip: skip, timeout: const Timeout(Duration(minutes: 20)));
}
