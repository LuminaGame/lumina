import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_core/testing.dart';
import 'package:lumina_editor_data/lumina_editor_data.dart';
import 'package:vector_math/vector_math_64.dart';

/// The Game Animation Sample example builder's pieces that need no sample
/// data: the database text parser, the level block conversion, and the
/// character / Animation Blueprint documents in the VM.
void main() {
  group('sample databases', () {
    // The shape of a pose search database's text export (written for this
    // test; not taken from the sample).
    const t3d = '''
Begin Object Class=/Script/PoseSearch.PoseSearchDatabase Name="PSD_Test_Walk_Starts"
   DatabaseAnimationAssets(0)=(AnimAsset="/Script/Engine.AnimSequence'/Game/Anim/Walk/Walk_Start_F.Walk_Start_F'",BranchInId=1)
   DatabaseAnimationAssets(1)=(AnimAsset="/Script/Engine.AnimSequence'/Game/Anim/Walk/Walk_Loop_F.Walk_Loop_F'",SamplingRange=(Min=0.100000,Max=0.500000),MirrorOption=UnmirroredAndMirrored)
   DatabaseAnimationAssets(2)=(AnimAsset="/Script/Engine.AnimSequence'/Game/Anim/Walk/Walk_Old.Walk_Old'",bEnabled=False)
   DatabaseAnimationAssets(3)=(AnimAsset="/Script/Engine.BlendSpace'/Game/Anim/Walk/BS_Walk.BS_Walk'")
End Object''';

    test('a database text export lists its sequences with sampling ranges, mirroring and the enabled flag', () {
      final db = GaspExport.parseDatabase({
        'path': '/Game/Anim/PSD_Test_Walk_Starts.PSD_Test_Walk_Starts',
        'schema': '/Game/Anim/PSS_Default.PSS_Default',
        'tags': ['Starts'],
        'base_cost_bias': 0.1,
        'looping_cost_bias': -0.005,
        'continuing_pose_cost_bias': -0.01,
        't3d': t3d,
      });
      expect(db.name, 'PSD_Test_Walk_Starts');
      expect(db.schema, 'PSS_Default');
      expect(db.clips.map((c) => c.clip), ['Walk_Start_F', 'Walk_Loop_F', 'Walk_Old'], reason: 'blend spaces are skipped');
      expect(db.clips[1].samplingStart, 0.1);
      expect(db.clips[1].samplingEnd, 0.5);
      expect(db.clips[1].mirror, 'UnmirroredAndMirrored');
      expect(db.clips[0].mirror, isNull);
      expect(db.clips[2].enabled, isFalse);
      expect(db.baseCostBias, 0.1);
    });

    test('a plan merges its source databases into one document tagged by gait, with the sample biases', () {
      final export = GaspExport.parse('C:/export', {
        'assets': {
          'PoseSearchDatabase': [
            {
              'path': '/Game/Anim/PSD_Dense_Stand_Walk_Starts.PSD_Dense_Stand_Walk_Starts',
              'tags': ['Starts'],
              'base_cost_bias': 0.1,
              'looping_cost_bias': -0.005,
              't3d': t3d.replaceAll('PSD_Test_Walk_Starts', 'PSD_Dense_Stand_Walk_Starts'),
            },
          ],
        },
      }, const []);
      final plan = GaspDatabases.plans.firstWhere((p) => p.name == GaspDatabases.stand);
      final (doc, missing) = GaspDatabases.document(plan, export,
          targetMesh: 'contents/meshes/skeletal/SK_Test.lmas', available: {'Walk_Start_F', 'Walk_Loop_F'});
      expect(doc.targetMesh, 'contents/meshes/skeletal/SK_Test.lmas');
      expect(doc.clips.map((c) => c.clip), ['Walk_Start_F', 'Walk_Loop_F']);
      expect(doc.clips.first.tags, ['Walk', 'Starts']);
      expect(doc.clips.first.loop, isFalse);
      expect(doc.clips.first.costBias, 0.0, reason: 'base biases rank databases in the sample, not clips');
      expect(doc.clips[1].loop, isTrue);
      expect(doc.clips[1].costBias, closeTo(-0.005, 1e-9), reason: 'the looping bias');
      expect(doc.clips[1].mirror, isTrue);
      expect(doc.clips[1].samplingEnd, 0.5);
      expect(doc.schema.trajectoryTimes, [-0.05, 0.35, 0.7, 1.0]);
      expect(missing, contains('PSD_Dense_Stand_Idles'), reason: 'source databases the export lacks are reported');
    });

    test('the export lists FBX clips by folder and keeps the first of two clips with one name', () {
      const root = 'C:/export';
      final files = [
        '$root/${GaspExport.animationsFolder}/Walk/M_Walk_Loop_F.fbx',
        '$root/${GaspExport.animationsFolder}/Traversal/Mantle/M_Mantle_1M.fbx',
        '$root/${GaspExport.animationsFolder}/Run/M_Walk_Loop_F.fbx',
        'C:/elsewhere/M_Other.fbx',
      ];
      final export = GaspExport.parse(root, {
        'anim_sequences': [
          {'path': '/Game/Anim/M_Walk_Loop_F.M_Walk_Loop_F', 'length_s': 4.0},
        ],
      }, files);
      expect(export.sequences.map((s) => '${s.folder}/${s.name}'), ['Traversal/Mantle/M_Mantle_1M', 'Walk/M_Walk_Loop_F']);
      expect(export.sequence('M_Mantle_1M')!.category, 'Traversal');
      expect(export.sequence('M_Walk_Loop_F')!.lengthSeconds, 4.0);
    });
  });

  group('sandbox level blocks', () {
    /// The eight corners of a corner-pivot 100 cm cube in the sample's
    /// left-handed frame, scaled by [scale], turned [yawDeg] about Z and
    /// placed at [at].
    List<List<double>> cube(List<double> at, List<double> scale, double yawDeg) {
      final c = math.cos(yawDeg * math.pi / 180), s = math.sin(yawDeg * math.pi / 180);
      return [
        for (final x in [0.0, 100.0])
          for (final y in [0.0, 100.0])
            for (final z in [0.0, 100.0])
              () {
                final lx = x * scale[0], ly = y * scale[1], lz = z * scale[2];
                // Left-handed yaw: +X turns toward +Y.
                return [at[0] + lx * c - ly * s, at[1] + lx * s + ly * c, at[2] + lz];
              }(),
      ];
    }

    test('a corner-pivot cube becomes a centred box in authoring space', () {
      final plain = GaspLevelBlock.fromCorners('A', cube([100, 200, 0], [4, 2, 1], 0));
      // The sample's X (forward) is authoring Y; its Y (right) authoring X.
      expect(plain.center, [300.0, 300.0, 50.0]);
      expect(plain.size, [200.0, 400.0, 100.0]);
      expect(plain.rotation, [0.0, 0.0, 0.0]);

      final turned = GaspLevelBlock.fromCorners('B', cube([100, 200, 0], [4, 2, 1], 90));
      expect(turned.size.map((v) => v.roundToDouble()), [200.0, 400.0, 100.0]);
      expect(turned.center.map((v) => v.roundToDouble()), [400.0, 0.0, 50.0]);
      expect(turned.rotation, [0.0, 0.0, 90.0], reason: 'the box faces +X: yaw 90');
    });

    test('authoring rotations round-trip through their matrix', () {
      for (final r in const [
        [20.0, 0.0, 35.0],
        [-15.0, 10.0, -120.0],
        [0.0, 30.0, 0.0],
        [44.0, 0.0, 179.0],
      ]) {
        final q = LuminaAxes.rotation(r);
        // Runtime matrix → authoring matrix (runtime (x, y, z) = authoring (x, −z, y)... inverted).
        final m = q.asRotationMatrix();
        final toRuntime = Matrix3(1, 0, 0, 0, 0, -1, 0, 1, 0);
        final authoring = toRuntime.transposed() * m * toRuntime;
        final back = GaspLevelBlock.authoringRotation(authoring);
        for (var i = 0; i < 3; i++) {
          expect(back[i], closeTo(r[i], 1e-3), reason: '$r → $back');
        }
      }
    });

    test('the default playground has ramps, stairs, blocks and a beam, and the level binds the game mode', () {
      final blocks = GaspSandboxLevel.defaultBlocks();
      expect(blocks.map((b) => b.name), containsAll(['Ramp', 'Beam', 'Block_Low', 'Block_High', 'Stairs_0', 'Stairs_9']));
      final ramp = blocks.firstWhere((b) => b.name == 'Ramp');
      expect(ramp.rotation[0], lessThan(44.0), reason: 'walkable');
      final actors = GaspSandboxLevel.actors(blocks: blocks, playerStart: const [0, -400, 100], gameModePath: 'contents/blueprints/GM.lmas');
      final start = actors.firstWhere((a) => a['type'] == 'PlayerStart');
      final binding = (start['components'] as List).cast<Map>().firstWhere((c) => c['type'] == 'LuminaGameModeBinding');
      expect((binding['properties'] as Map)['gameModeBlueprint'], 'contents/blueprints/GM.lmas');
      expect(actors.where((a) => a['type'] == 'Primitive').length, blocks.length + 1, reason: 'plus the floor');
      expect(actors.map((a) => a['type']), containsAll(['DirectionalLight', 'Environment', 'ExponentialHeightFog']));
      final container = jsonDecode(jsonEncode(GaspSandboxLevel.levelContainer(actors))) as Map;
      expect(LuminaLevelDocument.tryParse(jsonEncode(container), relativePath: GaspSandboxLevel.levelPath), isNotNull);
    });

    test('the grid materials compile with the material compiler', () {
      for (final name in GaspSandboxLevel.gridColors.keys) {
        final result = FilamentMatc.compile(GaspSandboxLevel.gridMaterialSource(name), fileName: '$name.mat', defaultName: name);
        expect(result.ok, isTrue, reason: result.errorText);
      }
    });
  });

  group('character', () {
    const mesh = 'contents/meshes/skeletal/SK_Test.lmas';

    test('the Animation Blueprint validates with the four databases and switches stance by the pawn', () {
      final docs = {
        for (final plan in GaspDatabases.plans)
          GaspCharacterContent.databasePath(mesh, plan.name):
              const LuminaPoseSearchDatabaseDocument(targetMesh: mesh, clips: [LuminaPoseSearchClip('Idle', loop: true)]),
      };
      final abp = GaspCharacterContent.animBlueprint(meshAssetPath: mesh);
      final cls = LuminaAnimBlueprintClass.fromDocument(abp, poseDatabases: docs);
      expect(cls.diagnostics.where((d) => d.isError), isEmpty, reason: '${cls.diagnostics}');
      final machine = abp.stateMachine!;
      expect(machine.states.map((s) => s.name), ['Stand', 'Crouch', 'Air', 'Land']);
      expect(machine.states.every((s) => s.pose.kind == LuminaAnimPoseKind.motionMatching), isTrue,
          reason: 'no root-motion clip is ever played by gltfio');
      expect(LuminaAnimBlueprintClass.fromDocument(abp).hasErrors, isTrue, reason: 'missing databases are reported');
    });

    test('the character walks, runs, sprints and crouches at the sample gait speeds from the project input', () {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), world);
      world.persistentLevel.registerActor(LuminaPrimitiveActor(
        shape: LuminaPrimitiveShape.box,
        size: Vector3(20000.0, 100.0, 20000.0),
        color: Vector3.all(0.5),
        location: Vector3(0.0, -50.0, 0.0),
      ));
      final bound = ProjectInputBinder.bind(GaspCharacterContent.input);
      expect(bound.unboundKeys, isEmpty);
      final input = world.registerSubsystem(LuminaInputSubsystem());
      for (final c in bound.contexts) {
        input.addMappingContext(c.context, priority: c.priority);
      }
      final actions = bound.actions.values.toList();
      final cls = LuminaBlueprintClass.fromDocument(
        GaspCharacterContent.characterBlueprint(meshAssetPath: 'never_loaded.lmas', inputActions: actions),
        name: GaspCharacterContent.characterName,
        inputActions: actions,
        animBlueprints: (_) => null,
      );
      expect(cls.diagnostics.where((d) => d.isError), isEmpty, reason: '${cls.diagnostics}');
      final character = cls.instantiate(location: Vector3(0.0, 100.0, 0.0)) as LuminaCharacter;
      final pc = LuminaPlayerController();
      world.persistentLevel.registerActor(character);
      pc.possess(character);
      world.beginPlay();
      void tick(int frames) {
        for (var i = 0; i < frames; i++) {
          pc.onTick(1 / 60);
          world.tick(1 / 60);
        }
      }

      void tap(LuminaKey key) {
        input.injectKeyDown(key);
        tick(2);
        input.injectKeyUp(key);
        tick(2);
      }

      double speed() {
        final v = character.characterMovement.velocity;
        return math.sqrt(v.x * v.x + v.z * v.z);
      }

      tick(30);
      input.injectKeyDown(LuminaKey.keyW);
      tick(120);
      expect(speed(), closeTo(GaspCharacterContent.runSpeed, 5), reason: 'run is the default gait');
      tap(LuminaKey.keyLeftControl);
      tick(120);
      expect(speed(), closeTo(GaspCharacterContent.walkSpeed, 5), reason: 'Left Ctrl toggles walking');
      tap(LuminaKey.keyLeftControl);
      input.injectKeyDown(LuminaKey.keyLeftShift);
      tick(120);
      expect(speed(), closeTo(GaspCharacterContent.sprintSpeed, 5), reason: 'held Left Shift sprints');
      input.injectKeyUp(LuminaKey.keyLeftShift);
      tap(LuminaKey.keyC);
      tick(120);
      expect(speed(), closeTo(GaspCharacterContent.crouchSpeed, 5), reason: 'C toggles crouching');
      tap(LuminaKey.keyC);
      tick(120);
      expect(speed(), closeTo(GaspCharacterContent.runSpeed, 5));
      input.injectKeyUp(LuminaKey.keyW);
      tap(LuminaKey.keySpace);
      expect(character.characterMovement.isFalling, isTrue, reason: 'Space jumps');
      expect(character.bUseControllerRotationYaw, isFalse, reason: 'motion matching turns the body');
    });
  });

  group('root height', () {
    test('a landing clip whose root starts high above the ground keeps its root at its rest height, not up there', () {
      final glb = LuminaSyntheticLocomotionRig.build([LuminaSyntheticLocomotionRig.walk('Land', 0, 1)]);
      final doc = GlbDocument.parse(glb);
      final nodes = (doc.json['nodes'] as List).cast<Map>();
      final root = nodes.indexWhere((n) => n['name'] == 'root');
      final rest = ((nodes[root]['translation'] as List?) ?? const [0, 0, 0]).map((v) => (v as num).toDouble()).toList();
      final animation = (doc.json['animations'] as List).cast<Map>().first;
      final channel = (animation['channels'] as List).cast<Map>()
          .firstWhere((c) => (c['target'] as Map)['node'] == root && (c['target'] as Map)['path'] == 'translation');
      final accessor = (doc.json['accessors'] as List).cast<Map>()[((animation['samplers'] as List)[channel['sampler'] as int] as Map)['output'] as int];
      final view = (doc.json['bufferViews'] as List).cast<Map>()[accessor['bufferView'] as int];
      final base = ((view['byteOffset'] as int?) ?? 0) + ((accessor['byteOffset'] as int?) ?? 0);
      final data = ByteData.sublistView(doc.bin);
      final count = accessor['count'] as int;
      // The root falls from 3 m above its rest to the ground over the clip.
      for (var k = 0; k < count; k++) {
        data.setFloat32(base + k * 12 + 4, rest[1] + 3.0 * (1 - k / (count - 1)), Endian.little);
      }
      final flat = GlbDocument.parse(GaspAnimationImport.removeRootHeight(GlbDocument(doc.json, doc.bin).encode()));
      final out = ByteData.sublistView(flat.bin);
      for (var k = 0; k < count; k++) {
        expect(out.getFloat32(base + k * 12 + 4, Endian.little), closeTo(rest[1], 1e-5), reason: 'key $k');
      }
    });


    test('a clip whose root rises and falls keeps its root at its rest height', () {
      final glb = LuminaSyntheticLocomotionRig.build([LuminaSyntheticLocomotionRig.walk('Walk', 0, 1)]);
      final doc = GlbDocument.parse(glb);
      final nodes = (doc.json['nodes'] as List).cast<Map>();
      final root = nodes.indexWhere((n) => n['name'] == 'root');
      expect(root, greaterThanOrEqualTo(0));
      // Lift the root's translation keys by a parabola (a jump arc).
      final accessors = (doc.json['accessors'] as List).cast<Map>();
      final views = (doc.json['bufferViews'] as List).cast<Map>();
      final animation = (doc.json['animations'] as List).cast<Map>().first;
      final channel = (animation['channels'] as List).cast<Map>()
          .firstWhere((c) => (c['target'] as Map)['node'] == root && (c['target'] as Map)['path'] == 'translation');
      final accessor = accessors[((animation['samplers'] as List)[channel['sampler'] as int] as Map)['output'] as int];
      final view = views[accessor['bufferView'] as int];
      final base = ((view['byteOffset'] as int?) ?? 0) + ((accessor['byteOffset'] as int?) ?? 0);
      final data = ByteData.sublistView(doc.bin);
      final count = accessor['count'] as int;
      final forward = <double>[];
      for (var k = 0; k < count; k++) {
        final o = base + k * 12;
        data.setFloat32(o + 4, data.getFloat32(o + 4, Endian.little) + 0.5 * math.sin(math.pi * k / (count - 1)), Endian.little);
        forward.add(data.getFloat32(o + 8, Endian.little));
      }
      final lifted = GlbDocument(doc.json, doc.bin).encode();
      final flat = GlbDocument.parse(GaspAnimationImport.removeRootHeight(lifted));
      final out = ByteData.sublistView(flat.bin);
      final restY = (((nodes[root]['translation'] as List?) ?? const [0, 0, 0])[1] as num).toDouble();
      for (var k = 0; k < count; k++) {
        final o = base + k * 12;
        expect(out.getFloat32(o + 4, Endian.little), closeTo(restY, 1e-5), reason: 'key $k');
        expect(out.getFloat32(o + 8, Endian.little), closeTo(forward[k], 1e-5), reason: 'ground motion kept');
      }
    });
  });
}
