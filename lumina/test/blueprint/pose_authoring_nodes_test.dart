import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'generated/bp_pose_authoring.g.dart';
import 'pose_authoring_blueprint.dart';

const _ids = [
  'add_pose_authoring',
  'set_pose_handle_target',
  'get_pose_handle_transform',
  'clear_pose_handle',
  'reset_pose',
  'find_nearest_pose_handle',
  'capture_pose',
  'apply_pose',
  'save_pose',
  'load_pose',
];

Object get _skip => File(poseAuthoringMeshPath).existsSync() ? false : 'test-assets/mannequin is missing';

/// Runs [actor] (the VM's or the generated class) in a game world until its
/// rig has loaded and one pose was solved; returns its trace.
Future<(List<LuminaBlueprintTraceEvent>, LuminaPoseAuthoringComponent)> _run(LuminaActor actor) async {
  final world = LuminaWorld(worldType: LuminaWorldType.game);
  addTearDown(world.cleanup);
  final trace = <LuminaBlueprintTraceEvent>[];
  (actor as LuminaBlueprintRuntime).trace = trace.add;
  world.persistentLevel.registerActor(actor);
  world.beginPlay();
  final component = actor.getComponent<LuminaPoseAuthoringComponent>()!;
  await component.ready.timeout(const Duration(seconds: 30));
  return (trace, component);
}

void main() {
  test('every Pose Authoring node has a spec, a VM function and a call shape; the event has an actor hook', () {
    for (final id in _ids) {
      expect(LuminaBlueprintNodeLibrary.spec(id), isNotNull, reason: id);
      expect(LuminaBlueprintFunctionLibrary.builtInFunctions.containsKey(id), isTrue, reason: id);
      expect(LuminaBlueprintFunctionLibrary.callShapes.containsKey(id), isTrue, reason: id);
    }
    expect(LuminaBlueprintNodeLibrary.actorEventHooks['event_pose_handle_changed'], 'onPoseHandleChanged');
    expect(LuminaBlueprintObjectClass.ancestors('Component:LuminaPoseAuthoringComponent'), ['Component:LuminaActorComponent']);
    final c = LuminaPoseAuthoringComponent.fromProperties({'weight': 0.4, 'captureMode': 'bakeToPose', 'rigAsset': 'r.lmas'});
    expect(c.weight, 0.4);
    expect(c.captureMode, LuminaPoseCaptureMode.bakeToPose);
    expect(c.rigAssetPath, 'r.lmas');
    expect(LuminaBlueprintComponents.classNameOf(c), 'LuminaPoseAuthoringComponent');
  });

  test('Begin Play → Add Pose Authoring → Set Pose Handle Target(hand_r): the VM and the generated class give the same trace and pose',
      () async {
    final (vmTrace, vmComponent) =
        await _run(LuminaBlueprintClass.fromDocument(poseAuthoringBlueprint(), name: 'bp_pose_authoring').instantiate());
    final (genTrace, genComponent) = await _run(BpPoseAuthoring());

    final printed = [for (final t in vmTrace) if (t.printed != null) t.printed!];
    // The target was taken, nothing is near it before the rig loads, and the
    // handle reported its change once the rig was ready.
    expect(printed, ['true', '', 'hand_r']);
    expect([for (final t in genTrace) if (t.printed != null) t.printed!], printed);
    expect(genTrace.length, vmTrace.length);
    for (var i = 0; i < vmTrace.length; i++) {
      expect(genTrace[i].nodeId, vmTrace[i].nodeId, reason: 'step $i');
      expect(genTrace[i].registryId, vmTrace[i].registryId, reason: 'step $i');
      expect(jsonEncode(genTrace[i].values.keys.toList()), jsonEncode(vmTrace[i].values.keys.toList()), reason: 'step $i');
    }

    // Both reach the same spot with the same pose.
    final target = LuminaBlueprintFunctionLibrary.toRuntime(Vector3.array(poseAuthoringHandTarget));
    final poses = <List<double>>[];
    for (final c in [vmComponent, genComponent]) {
      final mesh = c.mesh!;
      final pose = c.rig!.restPoseCopy();
      c.modifyPose(pose, mesh.renderTransform, 1 / 60);
      expect(c.rig!.worldPositionOf(pose, mesh.renderTransform, 'hand_r').distanceTo(target), lessThan(0.05));
      poses.add(pose);
    }
    for (var i = 0; i < poses[0].length; i++) {
      expect(poses[1][i], closeTo(poses[0][i], 1e-12));
    }

    // The other nodes, through the VM functions on the posed actor.
    final self = vmComponent.owner!;
    LuminaBlueprintCallContext ctx() => LuminaBlueprintCallContext(self);
    Map<String, Object?> call(String id, Map<String, Object?> inputs) =>
        LuminaBlueprintFunctionLibrary.builtInFunctions[id]!(ctx(), inputs);
    final transform = call('get_pose_handle_transform', {'handle': 'hand_r'});
    expect((transform['location'] as Vector3).distanceTo(Vector3.array(poseAuthoringHandTarget)), lessThan(0.05));
    final nearest = call('find_nearest_pose_handle', {'location': Vector3.array(poseAuthoringHandTarget), 'max_distance': 8.0});
    expect(nearest['handle'], 'hand_r');
    final pose = call('capture_pose', {'name': 'Reach'})['pose'] as String;
    expect(AuthoredPose.fromJson(jsonDecode(pose) as Map<String, dynamic>).bones, contains('upperarm_r'));
    call('reset_pose', const {});
    expect(vmComponent.handles['hand_r']!.hasTarget, isFalse);
    expect(call('apply_pose', {'pose': pose, 'blend_time': 0.0})['return_value'], isTrue);
    expect(call('apply_pose', {'pose': 'not json', 'blend_time': 0.0})['return_value'], isFalse);
    call('clear_pose_handle', {'handle': 'hand_r'});

    // Save Pose / Load Pose through a save game slot in a temp directory.
    final dir = Directory.systemTemp.createTempSync('pose_nodes_');
    addTearDown(() => dir.deleteSync(recursive: true));
    self.world!.registerSubsystem(LuminaSaveGameSubsystem(saveDirectoryPath: dir.path));
    expect(call('save_pose', {'slot': 'Poses', 'name': 'Reach'})['return_value'], isTrue);
    expect(call('load_pose', {'slot': 'Poses', 'name': 'Reach', 'blend_time': 0.2})['return_value'], isTrue);
    expect(call('load_pose', {'slot': 'Poses', 'name': 'Missing', 'blend_time': 0.2})['return_value'], isFalse);
  }, skip: _skip);
}
