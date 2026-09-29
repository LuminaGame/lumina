import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../blueprint/typed_pins_blueprint.dart';

/// Engine stats, look-forward traces and queries, camera view
/// targets, actor lifecycle nodes and the actor events, on a real world.
void main() {
  var wireCount = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${wireCount++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  LuminaWorld world() {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    w.registerSubsystem(LuminaCollisionSubsystem());
    return w;
  }

  /// A Character Blueprint with the Third Person components (capsule, boom,
  /// follow camera), no graph yet.
  LuminaBlueprintDocument character() => LuminaBlueprintDocument(parentClass: 'LuminaCharacter', components: [
        LuminaBlueprintComponent(id: 'capsule', name: 'CapsuleComponent', type: 'LuminaCapsuleComponent'),
        LuminaBlueprintComponent(
            id: 'boom', name: 'CameraBoom', type: 'LuminaSpringArmComponent', parentId: 'capsule', properties: {'targetArmLength': 400.0}),
        LuminaBlueprintComponent(id: 'camera', name: 'FollowCamera', type: 'LuminaCameraComponent', parentId: 'boom'),
      ]);

  /// An Actor Blueprint with one capsule: what the traces and queries find.
  LuminaBlueprintDocument capsuleActor({double radius = 50.0, double halfHeight = 200.0}) =>
      LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
        LuminaBlueprintComponent(
            id: 'cap', name: 'Capsule', type: 'LuminaCapsuleComponent', properties: {'capsuleRadius': radius, 'capsuleHalfHeight': halfHeight}),
      ]);

  LuminaBlueprintNode Function(String id, String nodeId, [Map<String, dynamic>? literals]) placer(
          LuminaBlueprintDocument doc, String className) {
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: className, actorParents: {'BP_Target': 'LuminaActor', 'BP_Door': 'LuminaActor'});
    return (id, nodeId, [literals]) => LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  }

  /// Instantiates, registers, possesses and begins play; returns the actor with its trace.
  ({LuminaBlueprintCharacter me, LuminaPlayerController pc, List<LuminaBlueprintTraceEvent> trace}) play(
      LuminaWorld w, LuminaBlueprintDocument doc, String name, {Vector3? at}) {
    final cls = LuminaBlueprintClass.fromDocument(doc, name: name);
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final me = cls.instantiate(location: at ?? Vector3.zero()) as LuminaBlueprintCharacter;
    final trace = <LuminaBlueprintTraceEvent>[];
    me.trace = trace.add;
    final pc = LuminaPlayerController();
    w.persistentLevel.registerActor(me);
    pc.possess(me);
    return (me: me, pc: pc, trace: trace);
  }

  tearDown(LuminaBlueprintActorClasses.clear);

  test('Lumina|Engine nodes read the world stats, dilation and platform', () {
    final w = world();
    final doc = character();
    final p = placer(doc, 'BP_Stats');
    doc.eventGraph.nodes.addAll([
      p('event_tick', 'tick'),
      p('get_frame_rate', 'fps'),
      p('get_frame_number', 'frame'),
      p('get_frame_time_ms', 'ms'),
      p('get_game_time_in_seconds', 'game_time'),
      p('get_real_time_seconds', 'real_time'),
      p('get_actor_count', 'count'),
      p('get_time_dilation', 'dilation'),
      p('get_platform_name', 'platform'),
      p('is_editor', 'editor'),
      p('float_to_string', 'fps_text', {'decimals': 0}),
      p('print_string', 'say'),
      p('set_time_dilation', 'slomo', {'time_dilation': 0.5}),
    ]);
    doc.eventGraph.wires.addAll([
      wire('tick', 'exec_tick_out', 'say', 'exec_in'),
      wire('fps', 'return_value', 'fps_text', 'in_float'),
      wire('fps_text', 'return_value', 'say', 'in_string'),
      wire('say', 'exec_out', 'slomo', 'exec_in'),
    ]);
    final run = play(w, doc, 'BP_Stats');
    w.beginPlay();
    for (var i = 0; i < 60; i++) {
      run.pc.onTick(1 / 60);
      w.tick(1 / 60);
    }
    expect(run.trace.where((t) => t.printed != null).last.printed, '60');
    expect(w.timeDilation, 0.5);
    expect(w.frameNumber, 60);
    Object? value(String node) => run.trace.lastWhere((t) => t.nodeId == node).values['return_value'];
    // Every pure node is evaluated through the library on the live world.
    final ctx = LuminaBlueprintCallContext(run.me);
    expect(LuminaBlueprintFunctionLibrary.functions['get_frame_number']!(ctx, const {})['return_value'], 60);
    expect(LuminaBlueprintFunctionLibrary.functions['get_frame_time_ms']!(ctx, const {})['return_value'], closeTo(1000 / 60, 1e-6));
    expect(LuminaBlueprintFunctionLibrary.functions['get_real_time_seconds']!(ctx, const {})['return_value'], closeTo(1.0, 1e-9));
    expect(LuminaBlueprintFunctionLibrary.functions['get_game_time_in_seconds']!(ctx, const {})['return_value'], lessThan(1.0),
        reason: 'dilated after the first tick');
    expect(LuminaBlueprintFunctionLibrary.functions['get_actor_count']!(ctx, const {})['return_value'], 1);
    expect(LuminaBlueprintFunctionLibrary.functions['get_time_dilation']!(ctx, const {})['return_value'], 0.5);
    expect(LuminaBlueprintFunctionLibrary.functions['get_platform_name']!(ctx, const {})['return_value'], isNotEmpty);
    expect(LuminaBlueprintFunctionLibrary.functions['is_editor']!(ctx, const {})['return_value'], false);
    LuminaBlueprintRuntime.isEditor = true;
    addTearDown(() => LuminaBlueprintRuntime.isEditor = false);
    expect(LuminaBlueprintFunctionLibrary.functions['is_editor']!(ctx, const {})['return_value'], true);
    expect(value('fps'), closeTo(60.0, 1.0));
    var quit = 0;
    // No host hook in the editor: only logged (and nothing throws).
    LuminaBlueprintFunctionLibrary.quitGame(run.me);
    LuminaGame.onQuitRequested = () => quit++;
    addTearDown(() => LuminaGame.onQuitRequested = null);
    // Play-In-Editor's hook stops the session (Quit Game ends PIE);
    // the built game's exits.
    LuminaBlueprintFunctionLibrary.quitGame(run.me);
    expect(quit, 1, reason: 'the PIE host handles it');
    LuminaBlueprintRuntime.isEditor = false;
    LuminaBlueprintFunctionLibrary.quitGame(run.me);
    expect(quit, 2);
  });

  test('Line Trace Forward hits the target 300 cm ahead and misses when looking away', () {
    final w = world();
    final targetClass = LuminaBlueprintClass.fromDocument(capsuleActor(), name: 'BP_Target');
    // Runtime axes: forward at yaw 0 is −Z; the target's capsule spans the eye height.
    final target = targetClass.instantiate(location: Vector3(0, 100, -300));
    w.persistentLevel.registerActor(target);
    final doc = character();
    final p = placer(doc, 'BP_Tracer');
    doc.eventGraph.nodes.addAll([
      p('event_tick', 'tick'),
      p('line_trace_forward', 'trace', {'distance': 1000.0, 'draw_debug': true}),
      p('break_hit_result', 'hit'),
      p('branch', 'if_hit'),
      p('get_display_name', 'who'),
      p('print_string', 'say_hit'),
      p('print_string', 'say_miss', {'in_string': 'miss'}),
    ]);
    doc.eventGraph.wires.addAll([
      wire('tick', 'exec_tick_out', 'trace', 'exec_in'),
      wire('trace', 'exec_out', 'if_hit', 'exec_in'),
      wire('trace', 'return_value', 'if_hit', 'condition'),
      wire('trace', 'out_hit', 'hit', 'hit'),
      wire('hit', 'hit_actor', 'who', 'object'),
      wire('who', 'return_value', 'say_hit', 'in_string'),
      wire('if_hit', 'true_out', 'say_hit', 'exec_in'),
      wire('if_hit', 'false_out', 'say_miss', 'exec_in'),
    ]);
    final run = play(w, doc, 'BP_Tracer');
    w.beginPlay();
    run.pc.onTick(1 / 60);
    w.tick(1 / 60);
    final hit = run.trace.lastWhere((t) => t.registryId == 'break_hit_result').values;
    expect(hit['hit_actor'], same(target));
    expect(hit['blocking_hit'], isTrue);
    expect(hit['distance'], closeTo(250.0, 1.0), reason: '300 cm minus the capsule radius');
    expect(run.trace.last.printed, 'BP_Target');
    expect(run.me.debugShapes.map((s) => s.kind), contains(LuminaDebugShapeKind.line));
    expect(w.debugShapes, isNotEmpty);
    // Look away: yaw 180 turns the look direction to +Z.
    run.pc.controlRotation.y = 180.0;
    run.pc.onTick(1 / 60);
    w.tick(1 / 60);
    expect(run.trace.last.printed, 'miss');
    expect(run.trace.lastWhere((t) => t.nodeId == 'trace').values['return_value'], isFalse);
    expect(LuminaBlueprintFunctionLibrary.breakHitResult(run.trace.lastWhere((t) => t.nodeId == 'trace').values['out_hit']).hitActor, isNull);
    expect(w.debugShapes.where((s) => s.color[0] == 1.0), isNotEmpty, reason: 'a red segment for a miss');
    w.tick(1 / 60);
    expect(w.debugShapes.where((s) => s.expiresAt < w.realTimeSeconds), isEmpty, reason: 'one-frame shapes expired');
  });

  test('Get Actors In View Cone sorts the targets in front nearest first; the closest one is picked', () {
    final w = world();
    final targetClass = LuminaBlueprintClass.fromDocument(capsuleActor(), name: 'BP_Target');
    final near = targetClass.instantiate(location: Vector3(0, 100, -300));
    final far = targetClass.instantiate(location: Vector3(100, 100, -600));
    final behind = targetClass.instantiate(location: Vector3(0, 100, 300));
    for (final t in [far, behind, near]) {
      w.persistentLevel.registerActor(t);
    }
    final rock = LuminaActor(root: LuminaCollisionComponent(shapeType: CollisionShapeType.sphere, radius: 50), location: Vector3(0, 100, -150));
    w.persistentLevel.registerActor(rock);
    final doc = character();
    final p = placer(doc, 'BP_Looker');
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      p('get_actors_in_view_cone', 'cone', {'class': 'Actor:BP_Target', 'distance': 1000.0, 'cone_angle': 45.0}),
      p('array_length', 'n'),
      p('int_to_string', 'n_text'),
      p('print_string', 'say_n'),
      p('get_closest_actor_of_class_in_direction', 'closest', {'class': 'Actor:BP_Target'}),
      p('get_display_name', 'name'),
      p('print_string', 'say'),
      p('get_look_forward_direction', 'look'),
      p('get_actor_eyes_view_point', 'eyes'),
      p('find_look_at_location', 'ahead', {'distance': 100.0}),
      p('get_all_actors_of_class', 'all', {'class': 'Actor:BP_Target'}),
      p('get_actors_within_radius', 'nearby', {'location': [0.0, 0.0, 0.0], 'radius': 400.0}),
      p('sphere_overlap_actors', 'touching', {'location': [0.0, 150.0, 100.0], 'radius': 60.0}),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'say_n', 'exec_in'),
      wire('cone', 'return_value', 'n', 'target_array'),
      wire('n', 'return_value', 'n_text', 'in_int'),
      wire('n_text', 'return_value', 'say_n', 'in_string'),
      wire('say_n', 'exec_out', 'say', 'exec_in'),
      wire('closest', 'return_value', 'name', 'object'),
      wire('name', 'return_value', 'say', 'in_string'),
    ]);
    final run = play(w, doc, 'BP_Looker');
    w.beginPlay();
    expect(run.trace.last.printed, 'BP_Target');
    expect(run.trace.firstWhere((t) => t.printed != null).printed, '2');
    expect(run.trace.lastWhere((t) => t.nodeId == 'cone').values['return_value'], [near, far]);
    expect(run.trace.lastWhere((t) => t.nodeId == 'closest').values['return_value'], same(near));
    final me = run.me;
    expect(LuminaBlueprintFunctionLibrary.getLookForwardDirection(me), Vector3(0, 1, 0), reason: 'authoring forward is +Y at yaw 0');
    final eyes = LuminaBlueprintFunctionLibrary.getActorEyesViewPoint(me);
    expect(eyes.location.z, closeTo(me.baseEyeHeight, 1e-9));
    expect(LuminaBlueprintFunctionLibrary.findLookAtLocation(me, 100.0).y, closeTo(100.0, 1e-9));
    expect(LuminaBlueprintFunctionLibrary.getAllActorsOfClass(me, 'Actor:BP_Target'), unorderedEquals([near, far, behind]));
    expect(LuminaBlueprintFunctionLibrary.getAllActorsOfClass(me, 'Actor:LuminaActor'), hasLength(5), reason: 'me, rock, 3 targets');
    expect(LuminaBlueprintFunctionLibrary.getActorsWithinRadius(me, Vector3.zero(), 400.0, 'Actor:BP_Target'), unorderedEquals([near, behind]));
    expect(LuminaBlueprintFunctionLibrary.sphereOverlapActors(me, Vector3(0, 150, 100), 60.0), [rock]);
    LuminaBlueprintFunctionLibrary.addTag(me, near, 'Enemy');
    expect(LuminaBlueprintFunctionLibrary.getAllActorsWithTag(me, 'Enemy'), [near]);
  });

  test('Set View Target with Blend moves the rendered view to the security camera over one second', () {
    final w = world();
    final camDoc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'cam', name: 'Cam', type: 'LuminaCameraComponent', properties: {'autoActivate': false, 'fieldOfView': 40.0}),
    ]);
    final security = LuminaBlueprintClass.fromDocument(camDoc, name: 'BP_SecurityCamera').instantiate(location: Vector3(500, 300, 0));
    w.persistentLevel.registerActor(security);
    final doc = character();
    final p = placer(doc, 'BP_Viewer');
    doc.eventGraph.nodes.addAll([
      p('event_tick', 'tick'),
      p('do_once', 'once'),
      p('get_all_actors_of_class', 'cams', {'class': 'Actor:BP_SecurityCamera'}),
      p('array_first', 'cam', {'type': 'object', 'class': 'Actor:BP_SecurityCamera'}),
      p('set_view_target_with_blend', 'blend', {'blend_time': 1.0, 'blend_func': 'Linear'}),
      p('get_view_target', 'vt'),
      p('get_display_name', 'vt_name'),
      p('print_string', 'say'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('tick', 'exec_tick_out', 'once', 'exec_in'),
      wire('once', 'completed', 'blend', 'exec_in'),
      wire('cams', 'return_value', 'cam', 'target_array'),
      wire('cam', 'return_value', 'blend', 'target'),
      wire('blend', 'exec_out', 'say', 'exec_in'),
      wire('vt', 'return_value', 'vt_name', 'object'),
      wire('vt_name', 'return_value', 'say', 'in_string'),
    ]);
    final run = play(w, doc, 'BP_Viewer');
    w.beginPlay();
    final follow = run.me.blueprintComponents['camera'] as LuminaCameraComponent;
    expect(w.activeCamera, same(follow));
    final manager = run.pc.cameraManager;
    // First tick: the boom places the follow camera and DoOnce starts the blend.
    run.pc.onTick(1 / 60);
    w.tick(1 / 60);
    expect(manager.isBlending, isTrue);
    expect(run.trace.last.printed, 'BP_Viewer', reason: 'the view target switches when the blend ends');
    final followAt = follow.worldLocation.clone();
    run.pc.onTick(0.5);
    final securityCam = (security as LuminaBlueprintRuntime).blueprintComponents['cam'] as LuminaCameraComponent;
    final mid = (followAt + securityCam.worldLocation) * 0.5;
    final pov = w.viewPov!;
    w.tick(0.5);
    for (var i = 0; i < 3; i++) {
      expect(pov.location[i], closeTo(mid[i], 1e-6), reason: 'midpoint[$i]');
    }
    expect(pov.fovDegrees, closeTo((follow.fieldOfViewInDegrees + 40.0) / 2, 1e-9));
    run.pc.onTick(0.5);
    w.tick(0.5);
    final done = w.viewPov!;
    for (var i = 0; i < 3; i++) {
      expect(done.location[i], closeTo(securityCam.worldLocation[i], 1e-6));
    }
    expect(manager.isBlending, isFalse);
    expect(LuminaBlueprintFunctionLibrary.getViewTarget(run.me), same(security));
    expect(LuminaBlueprintFunctionLibrary.getCameraLocation(run.me),
        LuminaBlueprintFunctionLibrary.toAuthoring(securityCam.worldLocation));
    // Blend Time 0 cuts on the same tick, back to the pawn: the world follows its camera component again.
    LuminaBlueprintFunctionLibrary.setViewTargetWithBlend(run.me, run.me, 0.0);
    run.pc.onTick(1 / 60);
    w.tick(1 / 60);
    expect(w.viewTargetPov, isNull);
    expect(LuminaBlueprintFunctionLibrary.getViewTarget(run.me), same(run.me));
    expect(LuminaBlueprintFunctionLibrary.getPlayerCameraManager(run.me), same(manager));
  });

  test("Set Active Camera on the character's second camera changes the world's active camera", () {
    final w = world();
    final doc = character();
    doc.components.add(LuminaBlueprintComponent(
        id: 'cam2', name: 'ShoulderCamera', type: 'LuminaCameraComponent', parentId: 'capsule', properties: {'autoActivate': false}));
    final p = placer(doc, 'BP_TwoCams');
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      p(LuminaBlueprintNodeLibrary.getComponent, 'follow', {'component': 'FollowCamera'}),
      p(LuminaBlueprintNodeLibrary.getComponent, 'shoulder', {'component': 'ShoulderCamera'}),
      p('set_active_camera', 'off', {'active': false}),
      p('set_active_camera', 'on', {'active': true}),
      p('get_active_camera', 'active'),
      p('get_display_name', 'name'),
      p('print_string', 'say'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'off', 'exec_in'),
      wire('follow', 'return_value', 'off', 'target'),
      wire('off', 'exec_out', 'on', 'exec_in'),
      wire('shoulder', 'return_value', 'on', 'target'),
      wire('on', 'exec_out', 'say', 'exec_in'),
      wire('active', 'return_value', 'name', 'object'),
      wire('name', 'return_value', 'say', 'in_string'),
    ]);
    final run = play(w, doc, 'BP_TwoCams');
    w.beginPlay();
    expect(w.activeCamera, same(run.me.blueprintComponents['cam2']));
    expect(run.trace.last.printed, 'ShoulderCamera');
    expect(doc.eventGraph.node('active')!.pin('return_value')!.objectClass, 'Component:LuminaCameraComponent');
  });

  test('Spawn Actor from Class runs BeginPlay at once; Destroy fires Destroyed then EndPlay; Life Span destroys later', () {
    final w = world();
    final doorDoc = capsuleActor();
    final dp = placer(doorDoc, 'BP_Door');
    doorDoc.eventGraph.nodes.addAll([
      dp('event_beginplay', 'begin'),
      dp('print_string', 'hello', {'in_string': 'door begins'}),
      dp('event_destroyed', 'destroyed'),
      dp('print_string', 'bye', {'in_string': 'destroyed'}),
      dp('event_end_play', 'end'),
      dp('append', 'reason_text', {'a': 'end play: '}),
      dp('print_string', 'ended'),
      dp('event_any_damage', 'damaged'),
      dp('float_to_string', 'dmg_text', {'decimals': 0}),
      dp('get_display_name', 'causer'),
      dp('append_3', 'dmg_line', {'b': ' from '}),
      dp('print_string', 'say_damage'),
    ]);
    doorDoc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'hello', 'exec_in'),
      wire('destroyed', 'exec_out', 'bye', 'exec_in'),
      wire('end', 'exec_out', 'ended', 'exec_in'),
      wire('end', 'end_play_reason', 'reason_text', 'b'),
      wire('reason_text', 'return_value', 'ended', 'in_string'),
      wire('damaged', 'exec_out', 'say_damage', 'exec_in'),
      wire('damaged', 'damage', 'dmg_text', 'in_float'),
      wire('damaged', 'damage_causer', 'causer', 'object'),
      wire('dmg_text', 'return_value', 'dmg_line', 'a'),
      wire('causer', 'return_value', 'dmg_line', 'c'),
      wire('dmg_line', 'return_value', 'say_damage', 'in_string'),
    ]);
    final doorClass = LuminaBlueprintClass.fromDocument(doorDoc, name: 'BP_Door');
    expect(doorClass.diagnostics, isEmpty, reason: '${doorClass.diagnostics}');
    final doorTrace = <LuminaBlueprintTraceEvent>[];
    LuminaBlueprintActorClasses.register('BP_Door', () => (doorClass.instantiate() as LuminaBlueprintActor)..trace = doorTrace.add);

    final doc = character();
    doc.variables.addAll(const [
      LuminaBlueprintVariable(name: 'Door', typeName: 'Actor:BP_Door'),
      LuminaBlueprintVariable(name: 'Brief', typeName: 'Actor:BP_Door'),
    ]);
    final p = placer(doc, 'BP_Spawner');
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      p('spawn_actor_from_class', 'spawn', {
        'class': 'Actor:BP_Door',
        'spawn_transform': {'location': [100.0, 0.0, 0.0], 'rotation': [0.0, 0.0, 90.0], 'scale': [1.0, 1.0, 1.0]},
      }),
      p(LuminaBlueprintNodeLibrary.variableSet, 'set_door', {'variable': 'Door'}),
      p('spawn_actor_from_class', 'spawn_brief', {'class': 'Actor:BP_Door'}),
      p(LuminaBlueprintNodeLibrary.variableSet, 'set_brief', {'variable': 'Brief'}),
      p('set_life_span', 'brief_life', {'in_life_span': 0.5}),
      p('apply_damage', 'hurt', {'base_damage': 25.0}),
      p('add_tag', 'tag', {'tag': 'Openable'}),
      p('event_tick', 'tick'),
      p('do_once', 'once'),
      p(LuminaBlueprintNodeLibrary.variableGet, 'door', {'variable': 'Door'}),
      p('destroy_actor', 'kill'),
      p('get_actor_transform', 'xf'),
      p('break_transform', 'parts'),
      p('vector_to_string', 'xf_text'),
      p('print_string', 'say_xf'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'spawn', 'exec_in'),
      wire('spawn', 'exec_out', 'set_door', 'exec_in'),
      wire('spawn', 'return_value', 'set_door', 'value'),
      wire('set_door', 'exec_out', 'spawn_brief', 'exec_in'),
      wire('spawn_brief', 'exec_out', 'set_brief', 'exec_in'),
      wire('spawn_brief', 'return_value', 'set_brief', 'value'),
      wire('set_brief', 'exec_out', 'brief_life', 'exec_in'),
      wire('set_brief', 'value', 'brief_life', 'target'),
      wire('brief_life', 'exec_out', 'hurt', 'exec_in'),
      wire('set_door', 'value', 'hurt', 'damaged_actor'),
      wire('hurt', 'exec_out', 'tag', 'exec_in'),
      wire('set_door', 'value', 'tag', 'target'),
      wire('tick', 'exec_tick_out', 'once', 'exec_in'),
      wire('once', 'completed', 'kill', 'exec_in'),
      wire('door', 'value', 'kill', 'target'),
      wire('kill', 'exec_out', 'say_xf', 'exec_in'),
      wire('door', 'value', 'xf', 'target'),
      wire('xf', 'return_value', 'parts', 'in_transform'),
      wire('parts', 'location', 'xf_text', 'in_vec'),
      wire('xf_text', 'return_value', 'say_xf', 'in_string'),
    ]);
    expect(doc.eventGraph.node('spawn')!.pin('return_value')!.objectClass, 'Actor:BP_Door');
    expect(doc.eventGraph.node('spawn')!.title, 'SpawnActor BP_Door');
    final run = play(w, doc, 'BP_Spawner');
    expect(w.actors.length, 1);
    w.beginPlay();
    expect(w.actors.length, 3, reason: 'two doors spawned during BeginPlay');
    final door = run.me.variables['Door'] as LuminaActor;
    expect(door.hasBegunPlay, isTrue);
    expect((door as LuminaBlueprintRuntime).blueprintClassName, 'BP_Door');
    expect(doorTrace.where((t) => t.printed == 'door begins').length, 2);
    expect(LuminaBlueprintFunctionLibrary.getActorLocation(door), Vector3(100, 0, 0));
    expect(LuminaBlueprintFunctionLibrary.getActorRotation(door).yaw, closeTo(90.0, 1e-6));
    expect(door.owner, same(run.me));
    expect(door.instigator, same(run.me));
    expect(door.tags, ['Openable']);
    expect(doorTrace.last.printed, '25 from BP_Spawner');
    expect(LuminaBlueprintActorClasses.create('Actor:BP_Nope'), isNull);

    // First tick: DoOnce destroys the door; Destroyed then EndPlay (Destroyed) run when the world removes it.
    run.pc.onTick(0.1);
    w.tick(0.1);
    expect(w.actors.length, 2);
    expect(door.isDestroyed, isTrue);
    final doorPrints = [for (final t in doorTrace) if (t.printed != null) t.printed];
    expect(doorPrints.sublist(doorPrints.length - 2), ['destroyed', 'end play: Destroyed']);
    expect(run.trace.where((t) => t.registryId == 'destroy_actor').length, 1);
    final xf = run.trace.lastWhere((t) => t.nodeId == 'parts').values;
    expect(xf['location'], Vector3(100, 0, 0));
    expect(LuminaBlueprintFunctionLibrary.isActorBeingDestroyed(run.me, door), isTrue);
    expect(LuminaBlueprintFunctionLibrary.isActorBeingDestroyed(run.me), isFalse);
    // The Life Span door goes 0.5 s after it was spawned.
    for (var i = 0; i < 3; i++) {
      run.pc.onTick(0.1);
      w.tick(0.1);
    }
    expect(w.actors.length, 2, reason: '0.4 s: not yet');
    run.pc.onTick(0.1);
    w.tick(0.1);
    expect(w.actors.length, 1);
    expect((run.me.variables['Brief'] as LuminaActor).isDestroyed, isTrue);
    expect(doorTrace.where((t) => t.printed == 'end play: Destroyed').length, 2);
  });

  test('actor-level overlap and hit events fire from the real collision subsystem', () {
    final w = world();
    final triggerDoc = capsuleActor();
    final tp = placer(triggerDoc, 'BP_Trigger');
    triggerDoc.eventGraph.nodes.addAll([
      tp('event_actor_begin_overlap', 'enter'),
      tp('get_display_name', 'who'),
      tp('append', 'line', {'a': 'entered: '}),
      tp('print_string', 'say'),
      tp('event_actor_end_overlap', 'leave'),
      tp('print_string', 'say_left', {'in_string': 'left'}),
      tp('event_begin_overlap', 'comp_enter'),
      tp('print_string', 'say_comp', {'in_string': 'component overlap'}),
    ]);
    triggerDoc.eventGraph.wires.addAll([
      wire('enter', 'exec_out', 'say', 'exec_in'),
      wire('enter', 'other_actor', 'who', 'object'),
      wire('who', 'return_value', 'line', 'b'),
      wire('line', 'return_value', 'say', 'in_string'),
      wire('leave', 'exec_out', 'say_left', 'exec_in'),
      wire('comp_enter', 'exec_out', 'say_comp', 'exec_in'),
    ]);
    final wallDoc = capsuleActor();
    final wp = placer(wallDoc, 'BP_Wall');
    wallDoc.eventGraph.nodes.addAll([
      wp('event_hit', 'hit'),
      wp('break_hit_result', 'parts'),
      wp('get_display_name', 'who'),
      wp('append', 'line', {'a': 'hit by '}),
      wp('print_string', 'say'),
    ]);
    wallDoc.eventGraph.wires.addAll([
      wire('hit', 'exec_out', 'say', 'exec_in'),
      wire('parts', 'hit_actor', 'who', 'object'),
      wire('hit', 'hit', 'parts', 'hit'),
      wire('who', 'return_value', 'line', 'b'),
      wire('line', 'return_value', 'say', 'in_string'),
    ]);
    final trigger = LuminaBlueprintClass.fromDocument(triggerDoc, name: 'BP_Trigger').instantiate(location: Vector3(0, 0, 0));
    final wall = LuminaBlueprintClass.fromDocument(wallDoc, name: 'BP_Wall').instantiate(location: Vector3(2000, 0, 0));
    final triggerTrace = <LuminaBlueprintTraceEvent>[], wallTrace = <LuminaBlueprintTraceEvent>[];
    (trigger as LuminaBlueprintRuntime).trace = triggerTrace.add;
    (wall as LuminaBlueprintRuntime).trace = wallTrace.add;
    CollisionProfile.applyOverlapAll(trigger.blueprintComponents['cap'] as LuminaCollisionComponent);
    CollisionProfile.applyBlockAll(wall.blueprintComponents['cap'] as LuminaCollisionComponent);
    w.persistentLevel.registerActor(trigger);
    w.persistentLevel.registerActor(wall);
    final run = play(w, character(), 'BP_Walker', at: Vector3(0, 0, 500));
    CollisionProfile.applyOverlapAll(run.me.capsuleComponent);
    w.beginPlay();
    w.tick(1 / 60);
    expect(triggerTrace.where((t) => t.printed != null), isEmpty, reason: 'the walker is 5 m away');
    run.me.actorLocation = Vector3(0, 0, 0);
    w.tick(1 / 60);
    expect([for (final t in triggerTrace) if (t.printed != null) t.printed], ['entered: BP_Walker', 'component overlap']);
    expect(triggerTrace.firstWhere((t) => t.nodeId == 'who').values['return_value'], 'BP_Walker');
    run.me.actorLocation = Vector3(0, 0, 500);
    w.tick(1 / 60);
    expect(triggerTrace.last.printed, 'left');
    // A blocking pair: the walker blocks too, and stands inside the wall.
    CollisionProfile.applyBlockAll(run.me.capsuleComponent);
    run.me.actorLocation = Vector3(2000, 0, 0);
    w.tick(1 / 60);
    expect(wallTrace.last.printed, 'hit by BP_Walker');
    final parts = wallTrace.lastWhere((t) => t.nodeId == 'parts').values;
    expect(parts['hit_actor'], same(run.me));
    expect(parts['blocking_hit'], isTrue);
  });

  test('the FPS chain: Get Frame Rate → Round → Int To String → Set Text (FPSCounter) reads "60"', () {
    LuminaWidgetClassRegistry.register(typedPinsHud);
    addTearDown(LuminaWidgetClassRegistry.clear);
    final w = world();
    final doc = character();
    doc.variables.add(const LuminaBlueprintVariable(name: 'Hud', typeName: 'Widget:WBP_HUD'));
    final p = placer(doc, 'BP_Fps');
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      p('create_widget', 'create', {'class': 'WBP_HUD'}),
      p(LuminaBlueprintNodeLibrary.variableSet, 'set_hud', {'variable': 'Hud'}),
      p('event_tick', 'tick'),
      p(LuminaBlueprintNodeLibrary.variableGet, 'hud', {'variable': 'Hud'}),
      p(LuminaBlueprintNodeLibrary.getWidgetElement, 'fps', {'element': 'FPSCounter'}),
      p('get_frame_rate', 'rate'),
      p('round', 'rounded'),
      p('int_to_string', 'digits'),
      p('set_element_text', 'set_text'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'create', 'exec_in'),
      wire('create', 'exec_out', 'set_hud', 'exec_in'),
      wire('create', 'return_value', 'set_hud', 'value'),
      wire('tick', 'exec_tick_out', 'set_text', 'exec_in'),
      wire('hud', 'value', 'fps', 'target'),
      wire('fps', 'return_value', 'set_text', 'target'),
      wire('rate', 'return_value', 'rounded', 'a'),
      wire('rounded', 'return_value', 'digits', 'in_int'),
      wire('digits', 'return_value', 'set_text', 'in_text'),
    ]);
    final run = play(w, doc, 'BP_Fps');
    w.beginPlay();
    for (var i = 0; i < 30; i++) {
      run.pc.onTick(1 / 60);
      w.tick(1 / 60);
    }
    final widget = run.me.variables['Hud'] as Map<String, Object?>;
    expect(LuminaBlueprintFunctionLibrary.getElementText(LuminaBlueprintFunctionLibrary.getWidgetElement(widget, 'FPSCounter')), '60');
  });

  test('the validator refuses an unknown trace channel and a spawn without a class', () {
    final doc = character();
    final p = placer(doc, 'BP_Bad');
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      p('line_trace_forward', 'trace', {'channel': 'Laser'}),
      p('spawn_actor_from_class', 'spawn'),
      p('sphere_trace_by_channel', 'ok', {'channel': 'Layer 3'}),
    ]);
    final errors = validateBlueprint(doc, className: 'BP_Bad').where((d) => d.isError).map((d) => d.message).toList();
    expect(errors, hasLength(2));
    expect(errors, contains(contains("'Laser' is not a trace channel")));
    expect(errors, contains(contains('SpawnActor from Class needs a class')));
    expect(LuminaBlueprintFunctionLibrary.isTraceChannel('Layer 32'), isTrue);
    expect(LuminaBlueprintFunctionLibrary.isTraceChannel('Layer 33'), isFalse);
    expect(LuminaBlueprintFunctionLibrary.isTraceChannel('pawn'), isTrue);
    // Every node of the task exists with a behaviour and a call shape.
    for (final id in const [
      'get_frame_rate', 'get_frame_time_ms', 'get_frame_number', 'get_world_delta_seconds', 'get_game_time_in_seconds',
      'get_real_time_seconds', 'get_actor_count', 'get_time_dilation', 'set_time_dilation', 'get_platform_name', 'is_editor', 'quit_game',
      'line_trace_by_channel', 'line_trace_forward', 'multi_line_trace_by_channel', 'multi_line_trace_forward', 'sphere_trace_by_channel',
      'sphere_trace_forward', 'sphere_overlap_actors', 'get_look_forward_direction', 'get_actor_eyes_view_point', 'find_look_at_location',
      'get_all_actors_of_class', 'get_actors_in_view_cone', 'get_closest_actor_of_class_in_direction', 'get_all_actors_with_tag',
      'get_actors_within_radius', 'set_view_target', 'set_view_target_with_blend', 'get_view_target', 'get_player_camera_manager',
      'get_active_camera', 'set_active_camera', 'get_camera_location', 'get_camera_rotation', 'spawn_actor_from_class', 'destroy_actor',
      'set_life_span', 'get_actor_transform', 'set_actor_transform', 'set_actor_rotation', 'set_actor_scale_3d', 'get_actor_scale_3d',
      'set_actor_hidden_in_game', 'is_hidden', 'set_actor_enable_collision', 'get_actor_enable_collision', 'teleport', 'get_actor_bounds',
      'get_actor_forward_vector', 'get_actor_right_vector', 'get_actor_up_vector', 'attach_actor_to_component', 'detach_from_actor',
      'get_attach_parent_actor', 'get_owner', 'set_owner', 'get_instigator', 'actor_has_tag', 'add_tag', 'remove_tag', 'get_distance_to',
      'get_horizontal_distance_to', 'is_actor_being_destroyed', 'apply_damage', 'apply_point_damage', 'apply_radial_damage',
    ]) {
      expect(LuminaBlueprintNodeLibrary.spec(id), isNotNull, reason: id);
      expect(LuminaBlueprintFunctionLibrary.functions.containsKey(id), isTrue, reason: '$id has a behaviour');
      expect(LuminaBlueprintFunctionLibrary.callShapes.containsKey(id), isTrue, reason: '$id has a call shape');
    }
    for (final id in const [
      'event_end_play', 'event_destroyed', 'event_any_damage', 'event_take_point_damage', 'event_actor_begin_overlap',
      'event_actor_end_overlap', 'event_hit', 'event_begin_overlap', 'event_end_overlap',
    ]) {
      final spec = LuminaBlueprintNodeLibrary.spec(id)!;
      expect(spec.kind, LuminaBlueprintNodeKind.event, reason: id);
      expect(spec.unsupported, isNull, reason: '$id is dispatched now');
    }
  });
}
