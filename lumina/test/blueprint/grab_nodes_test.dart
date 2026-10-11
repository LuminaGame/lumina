import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../interaction/grab/grab_fixture.dart';
import 'generated/bp_grab_to_pose.g.dart';
import 'grab_to_pose_blueprint.dart';

/// Runs [actor] (the VM's or the generated class) in a world with a scripted
/// grabber that grabs a character's right hand, drags it and lets go;
/// returns the trace.
List<LuminaBlueprintTraceEvent> _run(LuminaActor actor) {
  final world = LuminaWorld(worldType: LuminaWorldType.game);
  addTearDown(world.cleanup);
  final trace = <LuminaBlueprintTraceEvent>[];
  (actor as LuminaBlueprintRuntime).trace = trace.add;
  world.persistentLevel.registerActor(actor);
  world.beginPlay();
  final interactor = actor.getComponent<LuminaPoseGrabInteractor>()!;
  final character = GrabRun();
  interactor
    ..findPosersInReach = false
    ..showHandles = false
    ..register(character.poser);
  final g = ScriptedGrabber('right', at: character.handle('hand_r') + Vector3(0, 0, 3));
  expect(LuminaPoseAuthoringNodes.registerGrabber(actor, g), isTrue);
  expect(LuminaPoseAuthoringNodes.registerGrabber(actor, 'not a grabber'), isFalse);
  void frame() {
    world.tick(1 / 60);
    character.tick();
  }

  frame();
  g.gripValue = 1;
  frame();
  g.position.add(Vector3(0, 10, 0));
  frame();
  g.gripValue = 0;
  frame();
  expect(character.handle('hand_r').distanceTo(character.poser.handleWorldLocation('hand_r')!), lessThan(1e-9));
  expect(LuminaPoseAuthoringNodes.undoLastGrab(actor), isTrue);
  return trace;
}

void main() {
  test('every grab node has a spec, a VM function and a call shape; the events have actor hooks', () {
    for (final id in ['add_grab_interactor', 'register_grabber', 'set_grab_radius', 'undo_last_grab']) {
      expect(LuminaBlueprintNodeLibrary.spec(id), isNotNull, reason: id);
      expect(LuminaBlueprintFunctionLibrary.builtInFunctions.containsKey(id), isTrue, reason: id);
      expect(LuminaBlueprintFunctionLibrary.callShapes.containsKey(id), isTrue, reason: id);
    }
    expect(LuminaBlueprintNodeLibrary.actorEventHooks['event_pose_handle_grabbed'], 'onPoseHandleGrabbed');
    expect(LuminaBlueprintNodeLibrary.actorEventHooks['event_pose_handle_released'], 'onPoseHandleReleased');
    expect(LuminaBlueprintNodeLibrary.actorEventHooks['event_pose_handle_hovered'], 'onPoseHandleHovered');
    final c = LuminaPoseGrabInteractor.fromProperties({'grabRadius': 10.0, 'useMouse': true});
    expect(c.grabRadius, 10.0);
    expect(c.useMouse, isTrue);
    expect(LuminaBlueprintComponents.classNameOf(c), 'LuminaPoseGrabInteractor');
  });

  test('On Pose Handle Grabbed → Print handle name runs in the VM with a scripted grabber, and the generated class matches', () {
    final vm = _run(LuminaBlueprintClass.fromDocument(grabToPoseBlueprint(), name: 'bp_grab_to_pose').instantiate());
    final generated = _run(BpGrabToPose());
    final printed = [for (final t in vm) if (t.printed != null) t.printed!];
    expect(printed, ['hand_r', 'right']);
    expect([for (final t in generated) if (t.printed != null) t.printed!], printed);
    expect(generated.length, vm.length);
    for (var i = 0; i < vm.length; i++) {
      expect(generated[i].nodeId, vm[i].nodeId, reason: 'step $i');
      expect(generated[i].registryId, vm[i].registryId, reason: 'step $i');
      expect(generated[i].values.keys.toList(), vm[i].values.keys.toList(), reason: 'step $i');
    }
  });
}
