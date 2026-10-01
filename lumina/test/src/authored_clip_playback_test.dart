import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

Directory get _assets => Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');

/// A clip authored in frames, written into SKM_Manny_Simple's GLB, plays
/// through gltfio's animator — the path the Animation editor, Anim
/// Blueprints, Play-In-Editor and the generated game use — as the Dart
/// sampler evaluates it.
void main() {
  final manny = File('${_assets.path}/mannequin/SKM_Manny_Simple.glb');
  late Directory temp;
  late String meshPath;
  late AuthoredAnimationClip clip;
  late GlbSkeleton skeleton;

  late FilamentEngine engine;
  late FilamentScene scene;
  late LuminaWorld world;

  setUpAll(() {
    if (!manny.existsSync()) return;
    final glb = manny.readAsBytesSync();
    skeleton = GlbSkeleton.fromGlb(glb);
    final armRest = skeleton.rest(skeleton.indexOf('upperarm_r')).r;
    final raised = Quaternion.axisAngle(Vector3(0, 0, 1), 70 * math.pi / 180) * armRest;
    final turned = Quaternion.axisAngle(Vector3(1, 0, 0), 35 * math.pi / 180) * skeleton.rest(skeleton.indexOf('head')).r;
    clip = AuthoredAnimationClip(name: 'Authored_Raise', lengthFrames: 30)
      ..setKey('upperarm_r', AuthoredChannel.rotation, 0, [armRest.x, armRest.y, armRest.z, armRest.w])
      ..setKey('upperarm_r', AuthoredChannel.rotation, 30, [raised.x, raised.y, raised.z, raised.w])
      ..setKey('head', AuthoredChannel.rotation, 15, [turned.x, turned.y, turned.z, turned.w])
      ..setKey('root', AuthoredChannel.translation, 0, const [0, 0, 0])
      ..setKey('root', AuthoredChannel.translation, 30, const [0, 0, 0.4]);
    temp = Directory.systemTemp.createTempSync('lumina_authored_play_');
    meshPath = '${temp.path}/SKM_Manny_Authored.glb';
    File(meshPath).writeAsBytesSync(GlbAuthoredClipWriter.write(meshGlb: glb, clip: clip).glb);
  });

  tearDownAll(() {
    try {
      temp.deleteSync(recursive: true);
    } catch (_) {}
  });

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

  List<double> jointLocal(LuminaAnimatedMeshComponent mesh, String bone) {
    final doc = GlbDocument.parse(File(meshPath).readAsBytesSync());
    final joints = ((doc.json['skins'] as List).first as Map)['joints'] as List;
    final skinSlot = joints.indexOf(skeleton.indexOf(bone));
    expect(skinSlot, isNonNegative, reason: '$bone must be a skin joint');
    final entity = mesh.assetInstance!.jointsAt(0)[skinSlot];
    return FilamentTransformManager(engine).getTransform(entity);
  }

  void expectPose(LuminaAnimatedMeshComponent mesh, double time, String bone) {
    final expected = clip.samplePose(skeleton, time)[skeleton.indexOf(bone)]!.toMatrix().storage;
    final actual = jointLocal(mesh, bone);
    for (var i = 0; i < 16; i++) {
      expect(actual[i], closeTo(expected[i], 1e-4), reason: '$bone at ${time.toStringAsFixed(3)} s, element $i');
    }
  }

  test('gltfio plays the authored clip by name as the sampler evaluates it, at keys and between them', () async {
    if (!manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: meshPath);
    world.persistentLevel.registerActor(LuminaActor(root: mesh));
    world.beginPlay();
    await mesh.loaded;
    expect(mesh.hasClip('Authored_Raise'), isTrue);
    expect(mesh.clipDuration('Authored_Raise'), closeTo(1.0, 1e-5));

    for (final frame in [0, 7, 15, 22, 29]) {
      final t = frame / 30;
      mesh.play('Authored_Raise', startTime: t);
      mesh.playRate = 0.0;
      world.tick(1 / 60);
      expectPose(mesh, t, 'upperarm_r');
      expectPose(mesh, t, 'head');
      expectPose(mesh, t, 'root');
      expectPose(mesh, t, 'lowerarm_r');
    }
  });

  test('an Anim Blueprint whose state plays the authored clip poses the arm as authored', () async {
    if (!manny.existsSync()) return markTestSkipped('test-assets/mannequin/SKM_Manny_Simple.glb is missing');
    final document = LuminaAnimBlueprintDocument(
      targetMesh: meshPath,
      eventGraph: LuminaBlueprintGraph(nodes: [
        LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.updateAnimation, nodeId: 'update', x: 0, y: 0),
      ]),
      stateMachines: [
        LuminaAnimStateMachine(
          name: 'Locomotion',
          entryState: 'Raise',
          states: [LuminaAnimState('Raise', LuminaAnimPose.clip('Authored_Raise'), x: 0, y: 0)],
          transitions: [],
        ),
      ],
    );
    final animClass = LuminaAnimBlueprintClass.fromDocument(document, name: 'ABP_Authored');
    expect(animClass.hasErrors, isFalse, reason: animClass.diagnostics.join('; '));

    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: meshPath);
    final actor = LuminaCharacter(location: Vector3.zero());
    actor.addComponent(mesh);
    actor.addComponent(animClass.factory(mesh));
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    await mesh.loaded;
    expect(mesh.currentClip, 'Authored_Raise');

    world.tick(0.5);
    expect(mesh.currentTime, closeTo(0.5, 1e-6));
    expectPose(mesh, mesh.currentTime, 'upperarm_r');
    expectPose(mesh, mesh.currentTime, 'head');
  });
}
