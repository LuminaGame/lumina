import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/testing.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import 'support/gasp_sandbox.dart';

/// The Game Animation Sample's MetaHuman keeps a steady heading while it
/// moves: walking, running and sprinting straight ahead, running diagonally
/// and running while the camera turns, the capsule's yaw, the body's
/// (pelvis) yaw and the follow camera's yaw change smoothly, without
/// left/right swings. Measures per-frame yaw and its oscillation (sign
/// changes of the yaw rate per second, peak-to-peak swing about the trend).
/// The project is built locally (MetaHuman + sample data, never shipped):
/// the scenario skips without it.
const _w = SmokeVideo.defaultWidth;
const _h = SmokeVideo.defaultHeight;

String get _projectDir =>
    Platform.environment['LUMINA_GASP_PROJECT_DIR'] ?? '${LuminaWorkspace.home}/Lumina Projects/game_animation_sample';

double _deg(double rad) => rad * 180.0 / math.pi;

double _wrap(double d) {
  var r = d % 360.0;
  if (r > 180.0) r -= 360.0;
  return r;
}

/// Oscillation of a yaw series (degrees, one sample per 1/60 s): sign changes
/// per second of the frame-to-frame yaw change (changes under [deadband]
/// degrees per frame count as still), and the largest swing about a 0.5 s
/// moving average.
({double flipsPerSecond, double swing, double maxStep}) _oscillation(List<double> yaw, {double deadband = 0.05}) {
  final unwrapped = <double>[];
  for (final y in yaw) {
    unwrapped.add(unwrapped.isEmpty ? y : unwrapped.last + _wrap(y - unwrapped.last));
  }
  var flips = 0;
  var lastSign = 0;
  var maxStep = 0.0;
  for (var i = 1; i < unwrapped.length; i++) {
    final d = unwrapped[i] - unwrapped[i - 1];
    maxStep = math.max(maxStep, d.abs());
    if (d.abs() < deadband) continue;
    final s = d.sign.toInt();
    if (lastSign != 0 && s != lastSign) flips++;
    lastSign = s;
  }
  var swing = 0.0;
  const half = 15;
  for (var i = half; i < unwrapped.length - half; i++) {
    var sum = 0.0;
    for (var k = i - half; k <= i + half; k++) {
      sum += unwrapped[k];
    }
    swing = math.max(swing, (unwrapped[i] - sum / (2 * half + 1)).abs());
  }
  return (flipsPerSecond: flips / (unwrapped.length / 60.0), swing: swing, maxStep: maxStep);
}

void main() {
  final level = File('$_projectDir/${GaspSandboxLevel.levelPath}');
  final skip = level.existsSync() ? false : 'the Game Animation Sample project is not built here ($_projectDir)';

  test('game animation sample: the MetaHuman and the follow camera keep a steady heading while walking, running, sprinting, strafing and turning', () async {
    const name =
        'game animation sample: the MetaHuman and the follow camera keep a steady heading while walking, running, sprinting, strafing and turning';
    final sandbox = await GaspSandbox.open(_projectDir);
    final world = sandbox.world;
    final pc = sandbox.pc;
    final input = sandbox.input;
    final character = sandbox.character;
    final anim = sandbox.anim;
    final camera = character.blueprintComponents['camera'] as LuminaSceneComponent;

    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);

    final pelvisWorld = Float64List(4096);
    final q = Float64List(4);
    final axis = Float64List(3);
    int? pelvisIndex;
    var pelvisAxis = -1;

    /// The pelvis's yaw in the mesh's model space (degrees), from the pose
    /// the motion matching player shows; null before it shows one.
    double? pelvisYaw() {
      final player = anim.motionMatching.player;
      if (player == null || !anim.motionMatching.active) return null;
      final sampler = player.database.sampler;
      pelvisIndex ??= player.poseNodeNames.indexOf('pelvis');
      if (pelvisIndex! < 0) return null;
      final world = pelvisWorld.length >= sampler.nodeCount * LuminaPoseMath.affineStride
          ? pelvisWorld
          : Float64List(sampler.nodeCount * LuminaPoseMath.affineStride);
      sampler.world(player.pose, world);
      LuminaPoseMath.affineRotation(world, pelvisIndex! * LuminaPoseMath.affineStride, q, 0);
      if (pelvisAxis < 0) {
        // The pelvis axis that lies most horizontal at the first frame.
        var best = 2.0;
        for (var a = 0; a < 3; a++) {
          LuminaPoseMath.rotateVector(q, 0, a == 0 ? 1 : 0, a == 1 ? 1 : 0, a == 2 ? 1 : 0, axis, 0);
          if (axis[1].abs() < best) {
            best = axis[1].abs();
            pelvisAxis = a;
          }
        }
      }
      final a = pelvisAxis;
      LuminaPoseMath.rotateVector(q, 0, a == 0 ? 1 : 0, a == 1 ? 1 : 0, a == 2 ? 1 : 0, axis, 0);
      return _deg(math.atan2(axis[0], axis[2]));
    }

    double cameraYaw() {
      final f = Vector3(0, 0, -1)..applyQuaternion(camera.worldRotation);
      return _deg(luminaWorldYaw(f));
    }

    // A game's frame times vary (mostly 60 Hz, some faster and slower
    // frames); the facing must hold steady through them.
    final random = math.Random(7);
    const frameTimes = [1 / 60, 1 / 60, 1 / 60, 1 / 50, 1 / 75, 1 / 40, 1 / 90, 1 / 30];
    final frames = <Map<String, Object?>>[];
    final series = <String, Map<String, List<double>>>{};

    Future<void> phase(String label, double seconds, {List<LuminaKey> hold = const [], double mouseX = 0.0}) async {
      for (final k in hold) {
        input.injectKeyDown(k);
      }
      final n = (seconds * 60).round();
      final s = series[label] = {'capsule': [], 'mesh': [], 'pelvis': [], 'camera': [], 'control': [], 'desired': []};
      for (var f = 0; f < n; f++) {
        if (mouseX != 0) input.injectAnalog(LuminaKey.mouseX, mouseX);
        final dt = frameTimes[random.nextInt(frameTimes.length)];
        pc.onTick(dt);
        world.tick(dt);
        final capsule = _deg(LuminaMotionMatchingCharacter.facingYaw(character));
        final meshF = Vector3(0, 0, 1)..applyQuaternion(sandbox.mesh.worldRotation);
        final mesh = _deg(luminaWorldYaw(meshF));
        final pelvis = pelvisYaw();
        final cam = cameraYaw();
        final input3 = character.characterMovement.lastInputVector;
        final desired = input3.length > 1e-3 ? _deg(luminaWorldYaw(input3)) : capsule;
        // Skip the first second of a phase: the turn into the new
        // direction is wanted.
        if (f >= 60) {
          s['capsule']!.add(capsule);
          s['mesh']!.add(mesh);
          if (pelvis != null) s['pelvis']!.add(_wrap(pelvis + mesh));
          s['camera']!.add(cam);
          s['control']!.add(pc.controlRotation.y);
          s['desired']!.add(desired);
        }
        frames.add({
          'phase': label,
          'f': f,
          'capsule': capsule.toStringAsFixed(2),
          'mesh': mesh.toStringAsFixed(2),
          'pelvis': pelvis?.toStringAsFixed(2),
          'camera': cam.toStringAsFixed(2),
          'control': pc.controlRotation.y.toStringAsFixed(2),
          'desired': desired.toStringAsFixed(2),
          'clip': anim.variables[LuminaAnimBlueprintInstance.matchedClipVariable],
          'state': anim.currentState,
        });
        if (f.isEven) {
          final frame = sandbox.capture();
          video.addFrame(frame);
          if (f == n - 2) {
            SmokeArtifacts.saveScreenshot('$name — $label', SmokeArtifacts.encodePng(_w, _h, frame),
                usedAssets: sandbox.usedAssets.toList(),
                metrics: {'phase': label, 'capsule_yaw': capsule.toStringAsFixed(1), 'camera_yaw': cam.toStringAsFixed(1)});
          }
        }
      }
      for (final k in hold) {
        input.injectKeyUp(k);
      }
    }

    await phase('idle', 1.0);
    await phase('walk forward', 4.0, hold: const [LuminaKey.keyW]);
    await phase('run forward', 4.0, hold: const [LuminaKey.keyW, LuminaKey.keyLeftShift]);
    await phase('sprint forward', 4.0, hold: const [LuminaKey.keyW, LuminaKey.keyLeftShift, LuminaKey.keyLeftControl]);
    await phase('run forward right', 4.0, hold: const [LuminaKey.keyW, LuminaKey.keyD, LuminaKey.keyLeftShift]);
    await phase('walk forward left', 4.0, hold: const [LuminaKey.keyW, LuminaKey.keyA]);
    await phase('run while turning the camera', 4.0, hold: const [LuminaKey.keyW, LuminaKey.keyLeftShift], mouseX: 2.0);

    final out = SmokeArtifacts.dir.parent..createSync(recursive: true);
    File('${out.path}/gasp_facing_frames.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(frames));

    final metrics = <String, String>{};
    final results = <String, Map<String, ({double flipsPerSecond, double swing, double maxStep})>>{};
    for (final MapEntry(key: label, value: s) in series.entries) {
      if (label == 'idle') continue;
      final r = results[label] = {
        for (final k in const ['capsule', 'pelvis', 'camera']) if (s[k]!.length > 60) k: _oscillation(s[k]!),
      };
      for (final MapEntry(key: k, value: o) in r.entries) {
        metrics['${label.replaceAll(' ', '_')}_${k}_flips_per_s'] = o.flipsPerSecond.toStringAsFixed(2);
        metrics['${label.replaceAll(' ', '_')}_${k}_swing_deg'] = o.swing.toStringAsFixed(2);
        metrics['${label.replaceAll(' ', '_')}_${k}_max_step_deg'] = o.maxStep.toStringAsFixed(2);
      }
    }
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert(metrics));
    expect(video.seconds, greaterThanOrEqualTo(SmokeArtifacts.minimumVideoSeconds));
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: sandbox.usedAssets.toList());

    // The capsule and the camera hold their heading; the pelvis is reported
    // only (it sways with every step and turns through the matched turn
    // clips).
    for (final MapEntry(key: label, value: r) in results.entries) {
      for (final k in const ['capsule', 'camera']) {
        final o = r[k]!;
        expect(o.flipsPerSecond, lessThan(1.0), reason: '$label: $k yaw rate flips ${o.flipsPerSecond}/s');
        expect(o.swing, lessThan(1.5), reason: '$label: $k yaw swings ${o.swing}°');
      }
    }
  }, skip: skip, timeout: const Timeout(Duration(minutes: 20)));
}
