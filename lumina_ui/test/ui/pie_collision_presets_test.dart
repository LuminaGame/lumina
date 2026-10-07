import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/details/services/blueprint_collision_overrides.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../helpers/blueprint_test_project.dart';
import '../helpers/scaffold_game_project.dart';

/// Collision presets in Play-In-Editor, on a real Third Person project:
/// collision presets authored in Blueprints (and a placement's level
/// override) are what the playing world collides with — a Trigger sphere
/// ahead of the Player Start lets the character through and fires Event
/// ActorBeginOverlap in the Blueprint debugger, a Block All box stops it.
void main() {
  late Directory root;
  late String dir;
  const triggerPath = 'contents/blueprints/BP_TriggerSphere.lmas';
  const wallPath = 'contents/blueprints/BP_BoxWall.lmas';

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_bp10_pie_');
    dir = await scaffoldGameProject(root, name: 'collision_play', widgetLibrary: 'flutter');
  });
  tearDownAll(() => root.deleteSync(recursive: true));
  tearDown(() => BlueprintPieDebugger.instance.clear());

  LuminaProject manifest() =>
      LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/collision_play.lmproject').readAsStringSync()) as Map));

  Future<EditorViewModel> editorFor(WidgetTester tester) async {
    final vm = EditorViewModel(initialProject: manifest(), projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();
    return vm;
  }

  void run(LuminaWorld world, int frames, [void Function(int frame)? each]) {
    for (var i = 0; i < frames; i++) {
      world.tick(1 / 60);
      each?.call(i);
    }
  }

  /// Where W walks the character from the Player Start: its start (runtime,
  /// on the floor) and unit direction, from a Play session of the empty
  /// template level.
  Future<({Vector3 start, Vector3 dir})> measureWalk(WidgetTester tester, EditorViewModel vm) async {
    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    final world = LuminaWorld();
    final game = vm.pieController.startHeadlessForTest(world);
    final pawn = game.possessedPawn!;
    run(world, 30);
    final start = pawn.actorLocation.clone();
    game.injectKeyDown(LuminaKey.keyW);
    run(world, 60);
    game.injectKeyUp(LuminaKey.keyW);
    final dir = pawn.actorLocation - start;
    dir.y = 0;
    vm.pieController.stopHeadlessForTest();
    expect(dir.length, greaterThan(50), reason: 'W walks the character');
    return (start: start, dir: dir.normalized());
  }

  /// A placement [distance] cm along the walk, authoring space.
  List<double> ahead(({Vector3 start, Vector3 dir}) walk, double distance) =>
      LuminaAxes.toAuthoringLocation(walk.start + walk.dir * distance);

  /// Places Blueprint [path] at [location] and returns the level actor.
  Future<EditorActorNode> place(WidgetTester tester, EditorViewModel vm, String path, List<double> location) async {
    vm.refreshAssets();
    final asset = vm.realAssets.firstWhere((a) => a.relativePath == path);
    await tester.runAsync(() => vm.spawnActorFromAsset(asset, location: location));
    return vm.actors.lastWhere((a) => a.blueprintClass == path);
  }

  /// A box wall across the walk: thin along it, wide across it (authoring
  /// axes; the walk runs along an authoring axis from the template's start).
  List<double> wallExtent(({Vector3 start, Vector3 dir}) walk) {
    final d = LuminaAxes.toAuthoringLocation(walk.dir);
    return d[0].abs() > d[1].abs() ? [20.0, 250.0, 120.0] : [250.0, 20.0, 120.0];
  }

  void writeTrigger() {
    final overlap = LuminaBlueprintNodeLibrary.place('event_actor_begin_overlap', nodeId: 'overlap', x: 0, y: 0);
    final print = LuminaBlueprintNodeLibrary.place('print_string', nodeId: 'print', x: 300, y: 0,
        literals: {'in_string': 'Trigger overlapped', 'print_to_screen': false});
    writeBlueprint(
      dir,
      'BP_TriggerSphere',
      LuminaBlueprintDocument(
        parentClass: 'LuminaActor',
        components: [
          LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
          LuminaBlueprintComponent(id: 'sphere', name: 'TriggerSphere', type: 'LuminaSphereComponent', parentId: 'root', properties: {
            'radius': 80.0,
            ...LuminaCollisionProfile.forPreset(LuminaCollisionPreset.trigger).toJson(),
          }),
        ],
        eventGraph: LuminaBlueprintGraph(
          nodes: [overlap, print],
          wires: [LuminaBlueprintWire(id: 'w0', fromNodeId: 'overlap', fromPinId: 'exec_out', toNodeId: 'print', toPinId: 'exec_in')],
        ),
      ),
    );
  }

  void writeWall(List<double> extent) {
    writeBlueprint(
      dir,
      'BP_BoxWall',
      LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
        LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
        LuminaBlueprintComponent(id: 'box', name: 'WallBox', type: 'LuminaBoxComponent', parentId: 'root', properties: {
          'boxExtent': extent,
          ...LuminaCollisionProfile.forPreset(LuminaCollisionPreset.blockAll).toJson(),
        }),
      ]),
    );
  }

  /// Walks W for [frames] and returns the distance covered along the walk,
  /// per frame.
  List<double> walk(EditorPieGame game, LuminaWorld world, LuminaActor pawn, ({Vector3 start, Vector3 dir}) w, int frames,
      [void Function(int frame)? each]) {
    run(world, 30);
    game.injectKeyDown(LuminaKey.keyW);
    final track = <double>[];
    run(world, frames, (i) {
      track.add((pawn.actorLocation - w.start).dot(w.dir));
      each?.call(i);
    });
    game.injectKeyUp(LuminaKey.keyW);
    return track;
  }

  testWidgets('a Trigger sphere 3 m ahead lets the character through and lights Event ActorBeginOverlap; a Block All box 7 m ahead stops it',
      (tester) async {
    final vm = await editorFor(tester);
    final w = await measureWalk(tester, vm);
    writeTrigger();
    writeWall(wallExtent(w));
    final trigger = await place(tester, vm, triggerPath, ahead(w, 300));
    await place(tester, vm, wallPath, ahead(w, 700));
    vm.selectActorById(trigger.id);

    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    final world = LuminaWorld();
    final game = vm.pieController.startHeadlessForTest(world);
    final pawn = game.possessedPawn!;
    final runtimeTrigger = world.persistentLevel.actors.firstWhere((a) => a.key == LuminaObjectKey(trigger.id)) as LuminaBlueprintInstance;
    final sphere = runtimeTrigger.blueprintComponents['sphere'] as LuminaSphereComponent;
    expect(sphere.preset, LuminaCollisionPreset.trigger);
    final recorder = BlueprintPieDebugger.instance.recorderFor(triggerPath);
    expect(recorder, isNotNull, reason: 'the selected placed Blueprint is debugged');

    int? litAt;
    var printed = false;
    final track = walk(game, world, pawn, w, 600, (i) {
      if (litAt == null && recorder!.activeNodeIds.contains('overlap')) litAt = i;
      printed |= recorder!.activeNodeIds.contains('print');
    });
    expect(litAt, isNotNull, reason: 'Event ActorBeginOverlap fired in the debugger');
    expect(printed, isTrue, reason: 'its Print String ran');
    expect(track[litAt!], inInclusiveRange(150, 320), reason: 'it fired entering the sphere');
    expect(track.reduce((a, b) => a > b ? a : b), greaterThan(400), reason: 'the trigger let the character through');
    // The Block All wall stopped it: in front of the wall's near face, and
    // still for the last second.
    final capsule = (pawn as LuminaCharacter).capsuleComponent.radius;
    expect(track.last, lessThan(700 - 20 - capsule + 2), reason: 'stopped at the wall, not through it (${track.last})');
    expect(track.last, greaterThan(700 - 20 - capsule - 30), reason: 'walked up to the wall (${track.last})');
    expect((track.last - track[track.length - 60]).abs(), lessThan(1.0), reason: 'pushing into the wall, not moving');
    vm.pieController.stopHeadlessForTest();
  });

  testWidgets('the level\'s Overlap All override of the placed wall is what Play collides with: the character walks through', (tester) async {
    final vm = await editorFor(tester);
    final w = await measureWalk(tester, vm);
    writeWall(wallExtent(w));
    final wall = await place(tester, vm, wallPath, ahead(w, 400));
    final box = BlueprintCollisionOverrides.collisionComponentsOf(wall, vm.projectDirPath).single;
    expect(
        vm.setActorComponentCollision(wall.id, box.id, LuminaCollisionProfile.forPreset(LuminaCollisionPreset.overlapAll).toJson(),
            blueprintComponent: box),
        isTrue);

    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    final world = LuminaWorld();
    final game = vm.pieController.startHeadlessForTest(world);
    final runtime = world.persistentLevel.actors.firstWhere((a) => a.key == LuminaObjectKey(wall.id)) as LuminaBlueprintInstance;
    expect((runtime.blueprintComponents['box'] as LuminaBoxComponent).preset, LuminaCollisionPreset.overlapAll);
    final track = walk(game, world, game.possessedPawn!, w, 300);
    expect(track.last, greaterThan(400 + 20 + 40), reason: 'through the overlapping wall (${track.last})');
    vm.pieController.stopHeadlessForTest();
  });
}
