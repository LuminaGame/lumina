import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import '../helpers/locomotion_fbx_fixture.dart';

/// The sample's traversal clips (hurdle, vault, mantle, climb start; FBX on
/// the UEFN mannequin in test-assets) with the chooser rows and warp windows
/// read from the export's metadata: real root motion warped onto measured
/// boxes lands on the ledges and the floor.
void main() {
  final dir = Directory('${LocomotionFbxFixture.directory.path}/Traversal');
  final skip = dir.existsSync() && LocomotionFbxFixture.available ? null : 'test-assets/FBX/GameAnimationSample/Traversal is missing';
  late List<LuminaTraversalAnimation> rows;
  late Map<String, Uint8List> sources;
  late LuminaPoseSearchRig rig;

  setUpAll(() async {
    if (skip != null) return;
    final metadata = jsonDecode(File('${dir.path}/metadata.json').readAsStringSync()) as Map<String, dynamic>;
    final clips = [
      for (final f in dir.listSync().whereType<File>())
        if (f.path.endsWith('.fbx')) f,
    ]..sort((a, b) => a.path.compareTo(b.path));
    var glb = (await FbxImportService.convert(LocomotionFbxFixture.meshFbx.path)).glb;
    sources = {};
    for (final f in clips) {
      final name = LocomotionFbxFixture.clipName(f);
      final clip = (await FbxImportService.convert(f.path)).glb;
      sources[name] = clip;
      glb = GlbAnimationRetargeter.retargetInto(target: glb, clip: clip, clipName: name).glb;
    }
    rig = LuminaPoseSearchRig(
        LuminaGlbAnimationSampler.fromGlb(glb), GaspDatabases.schema.copyWith(rootBone: GaspTraversal.rootBone));
    rows = GaspTraversal.withWarpPointOffsets([
      for (final r in GaspTraversal.rows(metadata))
        if (sources.containsKey(r.clip)) r,
    ], sources);
  });

  LuminaTraversalAnimation row(String clip) => rows.firstWhere((r) => r.clip == clip);

  test('the chooser rows and montage windows come from the metadata', () {
    final hurdle = row('M_Neutral_Traversal_Hurdle_1_0_run_F_Lfoot');
    expect(hurdle.action, LuminaTraversalActionType.hurdle);
    expect(hurdle.maxDepth, 25);
    expect(hurdle.maxHeight, 125);
    expect(hurdle.minSpeed, 250);
    expect(hurdle.maxSpeed, double.infinity);
    expect(hurdle.blendOutTime, closeTo(1.123, 1e-3));
    expect([for (final w in hurdle.windows) w.target], ['FrontLedge', 'BackFloor']);
    expect(hurdle.windows.first.start, closeTo(0.499, 1e-3));
    expect(hurdle.windows.first.warpRotation, isTrue);
    expect(hurdle.windows.first.warpPointBone, 'attach');
    final climb = row('M_Neutral_Traversal_Climb_Start_2_5_run_F_Lfoot');
    expect(climb.action, LuminaTraversalActionType.mantle);
    expect(climb.minHeight, 150);
    expect(climb.maxHeight, 275);
    expect(row('M_Neutral_Traversal_Mantle_1_0_stand_F_Lfoot').maxSpeed, 100);
    expect(row('M_Neutral_Traversal_Vault_1_0_run_F_Lfoot').action, LuminaTraversalActionType.vault);
  }, skip: skip);

  test('warp points are measured on the source clips: the hand contact on the ledge', () {
    for (final r in rows) {
      for (final w in r.windows.where((w) => w.warpPointBone != null)) {
        final o = w.warpPointOffset;
        expect(o, isNotNull, reason: '${r.clip} ${w.target}');
        // ignore: avoid_print
        print('${r.clip} ${w.target} @${w.end.toStringAsFixed(3)}: '
            '(${o!.x.toStringAsFixed(1)}, ${o.y.toStringAsFixed(1)}, ${o.z.toStringAsFixed(1)})');
        expect(o.x.abs(), lessThan(60), reason: r.clip);
        expect(o.z.abs(), lessThan(150), reason: r.clip);
      }
    }
  }, skip: skip);

  /// Plays [clip] against a box [height] × [depth] whose face is [distance]
  /// cm ahead, running at [speed]: the component, the check, the largest
  /// miss of a warp target at its window end (cm) and the character.
  (LuminaTraversalComponent, LuminaTraversalCheckResult, double, LuminaCharacter) play(
      String clip, double height, double depth, double distance, double speed,
      {double dropBehind = 0}) {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), world);
    void box(Vector3 min, Vector3 max) {
      final actor = LuminaActor(location: (min + max) * 0.5);
      final c = LuminaCollisionComponent(shapeType: CollisionShapeType.box)..boxExtent = (max - min) * 0.5;
      CollisionProfile.applyBlockAll(c);
      actor.addComponent(c);
      world.persistentLevel.registerActor(actor);
    }

    final back = -distance - depth;
    box(Vector3(-3000, -100, back), Vector3(3000, 0, 3000));
    box(Vector3(-3000, -100 - dropBehind, -3000), Vector3(3000, -dropBehind, back));
    box(Vector3(-300, 0, back), Vector3(300, height, -distance));
    final character = LuminaCharacter(location: Vector3(0, 90.2, 0));
    character.capsuleComponent
      ..radius = 35
      ..halfHeight = 90;
    final traversal = LuminaTraversalComponent(animations: [row(clip)])..useRig(rig);
    character.addComponent(traversal);
    world.persistentLevel.registerActor(character);
    world.beginPlay();
    world.tick(1 / 60);
    character.characterMovement.velocity.setValues(0, 0, -speed);
    expect(traversal.tryTraversalAction(), isTrue, reason: '${traversal.lastCheck}');
    final check = traversal.lastCheck!;
    final player = traversal.player!;
    var miss = 0.0;
    final ends = [for (final w in player.windows) w.end]..sort();
    while (traversal.isTraversing) {
      final next = ends.firstWhere((e) => e > player.time + 1e-6, orElse: () => double.infinity);
      final dt = math.min(1 / 60, (next - player.time) / player.montage.playRate);
      world.tick(math.max(dt, 1e-4));
      for (final w in player.windows) {
        if ((player.time - w.end).abs() < 1e-6 && player.warper.targets.containsKey(w.target)) {
          final yaw = w.warpRotation ? player.warper.targets[w.target]!.yaw : player.rootYaw;
          miss = math.max(miss, player.rootLocation.distanceTo(player.warper.rootTargetOf(w, yaw)));
        }
      }
    }
    return (traversal, check, miss, character);
  }

  test('a run hurdle over a 100 cm wall reaches its targets and lands behind it', () {
    final (_, check, miss, character) = play('M_Neutral_Traversal_Hurdle_1_0_run_F_Lfoot', 100, 20, 250, 400);
    expect(check.actionType, LuminaTraversalActionType.hurdle);
    expect(miss, lessThan(1.0));
    expect(character.actorLocation.z, lessThan(-270 - 35), reason: 'behind the wall');
    expect(character.actorLocation.y, closeTo(90, 3), reason: 'on the floor');
    expect(character.characterMovement.isWalking, isTrue);
  }, skip: skip);

  test('a run vault over a wall above a drop reaches its targets and leaves it over the drop', () {
    final (_, check, miss, character) = play('M_Neutral_Traversal_Vault_1_0_run_F_Lfoot', 100, 30, 250, 400, dropBehind: 200);
    expect(check.actionType, LuminaTraversalActionType.vault);
    expect(miss, lessThan(1.0));
    expect(character.actorLocation.z, lessThan(-250), reason: 'over the wall');
  }, skip: skip);

  test('low and high mantles end standing on top', () {
    for (final (clip, height, speed, distance) in [
      ('M_Neutral_Traversal_Mantle_1_0_run_F_Lfoot', 110.0, 400.0, 250.0),
      ('M_Neutral_Traversal_Mantle_1_0_stand_F_Lfoot', 120.0, 0.0, 70.0),
      ('M_Neutral_Traversal_Climb_Start_2_5_run_F_Lfoot', 220.0, 400.0, 250.0),
    ]) {
      final (_, check, miss, character) = play(clip, height, 300, distance, speed);
      expect(check.actionType, LuminaTraversalActionType.mantle, reason: clip);
      expect(miss, lessThan(1.0), reason: clip);
      expect(character.actorLocation.y, closeTo(height + 90, 4), reason: '$clip on top');
      expect(character.actorLocation.z, lessThan(-distance), reason: clip);
    }
  }, skip: skip);
}
