import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// Plays the clips merged into the Third Person template's
/// mannequin through gltfio's animator, on a real (headless) engine.
void main() {
  const bundle = LuminaThirdPersonContent.bundledMeshPath;
  const idle = LuminaThirdPersonContent.idleClip;
  const walkFwd = 'Walk_Fwd_Loop';
  const walkBwd = 'Walk_Bwd_Loop';

  group('LuminaAnimatedMeshComponent', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late LuminaWorld world;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      scene = engine.createScene();
      world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
    });

    tearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    Future<LuminaAnimatedMeshComponent> spawn([void Function(LuminaAnimatedMeshComponent)? beforeRegister]) async {
      final mesh = LuminaAnimatedMeshComponent(meshAssetPath: bundle);
      beforeRegister?.call(mesh);
      world.persistentLevel.registerActor(LuminaActor(root: mesh));
      world.beginPlay();
      await mesh.loaded;
      return mesh;
    }

    /// The local transform of the skin joint named [bone].
    List<double> jointLocal(LuminaAnimatedMeshComponent mesh, String bone) {
      final doc = GlbDocument.parse(File(bundle).readAsBytesSync());
      final nodes = (doc.json['nodes'] as List).cast<Map<String, dynamic>>();
      final joints = ((doc.json['skins'] as List).first as Map)['joints'] as List;
      final slot = joints.indexWhere((n) => nodes[n as int]['name'] == bone);
      expect(slot, isNonNegative, reason: '$bone must be a skin joint');
      final entity = mesh.assetInstance!.jointsAt(0)[slot];
      return FilamentTransformManager(engine).getTransform(entity);
    }

    double maxDifference(List<double> a, List<double> b) {
      var d = 0.0;
      for (var i = 0; i < a.length; i++) {
        final x = (a[i] - b[i]).abs();
        if (x > d) d = x;
      }
      return d;
    }

    test('lists the merged clips once the asset is loaded', () async {
      final mesh = LuminaAnimatedMeshComponent(meshAssetPath: bundle);
      expect(mesh.clipNames, isEmpty, reason: 'nothing is known before load');

      world.persistentLevel.registerActor(LuminaActor(root: mesh));
      world.beginPlay();
      await mesh.loaded;

      expect(mesh.clipNames, LuminaThirdPersonContent.clipNames);
      expect(mesh.hasClip(walkFwd), isTrue);
      expect(mesh.clipDuration(walkFwd), closeTo(1.3333, 1e-3));
      expect(mesh.clipDuration(walkBwd), closeTo(1.3333, 1e-3));
    });

    test('playing a walk moves the thigh away from its idle pose', () async {
      final mesh = await spawn();

      mesh.play(idle, startTime: 0.4);
      world.tick(1 / 60);
      final idlePose = jointLocal(mesh, 'thigh_l');

      mesh.play(walkFwd, startTime: 0.4);
      world.tick(1 / 60);
      final walkPose = jointLocal(mesh, 'thigh_l');

      expect(maxDifference(idlePose, walkPose), greaterThan(0.05),
          reason: 'the walk swings the leg; the idle does not');
      expect(mesh.currentClip, walkFwd);
    });

    test('time advances by dt * playRate, wraps at the clip length, and freezes at rate 0', () async {
      final mesh = await spawn();
      mesh.play(walkFwd);
      mesh.playRate = 2.0;
      world.tick(0.1);
      expect(mesh.currentTime, closeTo(0.2, 1e-6));

      for (var i = 0; i < 8; i++) {
        world.tick(0.1);
      }
      // 1.8 s of clip time into a 1.333 s loop.
      expect(mesh.currentTime, closeTo(1.8 - mesh.clipDuration(walkFwd), 1e-6));

      mesh.playRate = 0.0;
      final frozen = mesh.currentTime;
      final pose = jointLocal(mesh, 'thigh_l');
      world.tick(0.1);
      expect(mesh.currentTime, frozen);
      expect(maxDifference(pose, jointLocal(mesh, 'thigh_l')), lessThan(1e-9));

      expect(() => mesh.playRate = -1.0, throwsArgumentError);
    });

    test('a non-looping play holds the last frame', () async {
      final mesh = await spawn();
      mesh.play(walkFwd, loop: false);
      for (var i = 0; i < 20; i++) {
        world.tick(0.1);
      }
      expect(mesh.currentTime, closeTo(mesh.clipDuration(walkFwd), 1e-6));
    });

    test('a clip requested before the asset loads is applied on load', () async {
      final mesh = await spawn((m) => m.play('Walk_Left_Loop'));
      expect(mesh.currentClip, 'Walk_Left_Loop');
    });

    test('an unknown clip after load throws, naming the clips there are', () async {
      final mesh = await spawn();
      expect(
        () => mesh.play('Nope'),
        throwsA(isA<ArgumentError>().having((e) => e.message.toString(), 'message', contains(idle))),
      );
      expect(() => mesh.crossFadeTo('Nope'), throwsArgumentError);
    });

    test('cross-fading with syncPhase starts the new clip at the old clip\'s phase', () async {
      final mesh = await spawn();
      mesh.play(walkFwd, startTime: mesh.clipDuration(walkFwd) / 2); // half-way through the cycle
      mesh.crossFadeTo(walkBwd, duration: 0.2, syncPhase: true);

      expect(mesh.currentClip, walkBwd);
      expect(mesh.currentTime, closeTo(0.5 * mesh.clipDuration(walkBwd), 1e-6));
      expect(mesh.isCrossFading, isTrue);

      world.tick(0.1);
      expect(mesh.isCrossFading, isTrue);
      world.tick(0.15);
      expect(mesh.isCrossFading, isFalse);
    });

    test('cross-fading to the clip already playing does nothing', () async {
      final mesh = await spawn();
      mesh.play(walkFwd, startTime: 0.3);
      mesh.crossFadeTo(walkFwd);
      expect(mesh.isCrossFading, isFalse);
      expect(mesh.currentTime, closeTo(0.3, 1e-9));
    });
  });
}
