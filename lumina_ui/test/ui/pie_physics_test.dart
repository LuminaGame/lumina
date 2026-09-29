import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/details/services/blueprint_collision_overrides.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

import '../helpers/blueprint_test_project.dart';
import '../helpers/scaffold_game_project.dart';

/// Physics in Play-In-Editor, on a real Third Person project: a
/// simulating BP_Chair placed 150 cm above the ground falls and rests with
/// the mass of its static mesh's `.lmas`, the character walking into it tips
/// it over, and a placement's level override of Simulate Physics is what
/// Play simulates (stored in the level `.lmas`).
void main() {
  late Directory root;
  late String dir;
  const chairPath = 'contents/blueprints/BP_Chair.lmas';
  const chairMesh = 'contents/meshes/static/SM_Chair.lmas';

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_bp12_pie_');
    dir = await scaffoldGameProject(root, name: 'physics_play', widgetLibrary: 'flutter');
    Directory('$dir/contents/meshes/static').createSync(recursive: true);
    File('$dir/$chairMesh').writeAsBytesSync(LuminaAsset(
      assetId: 'sm_chair',
      name: 'SM_Chair',
      type: AssetType.filamesh,
      metadata: {
        'physics': jsonEncode({'massKg': 23.0, 'centerOfMassOffset': [0.0, 0.0, 0.0]}),
      },
    ).toProtoBufferBytes());
    // BP_Chair: a tall 60 × 60 × 120 cm Box (Simulate Physics) and its mesh.
    writeBlueprint(
      dir,
      'BP_Chair',
      LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
        LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
        LuminaBlueprintComponent(id: 'box', name: 'Box', type: 'LuminaBoxComponent', parentId: 'root', properties: {
          'boxExtent': [30.0, 30.0, 60.0],
          'location': [0.0, 0.0, 60.0],
          'physics': {'simulate': true},
        }),
        LuminaBlueprintComponent(
            id: 'chair', name: 'Chair', type: 'LuminaStaticMeshComponent', parentId: 'box', properties: {'staticMeshAsset': chairMesh}),
      ]),
    );
  });
  tearDownAll(() {
    LuminaBlueprintComponents.meshPhysicsResolver = null;
    root.deleteSync(recursive: true);
  });
  tearDown(() => BlueprintPieDebugger.instance.clear());

  LuminaProject manifest() =>
      LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/physics_play.lmproject').readAsStringSync()) as Map));

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

  /// Where W walks the character from the Player Start (runtime).
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
    final d = pawn.actorLocation - start;
    d.y = 0;
    vm.pieController.stopHeadlessForTest();
    return (start: start, dir: d.normalized());
  }

  Future<EditorActorNode> place(WidgetTester tester, EditorViewModel vm, List<double> location) async {
    vm.refreshAssets();
    final asset = vm.realAssets.firstWhere((a) => a.relativePath == chairPath);
    await tester.runAsync(() => vm.spawnActorFromAsset(asset, location: location));
    return vm.actors.lastWhere((a) => a.blueprintClass == chairPath);
  }

  double tilt(Quaternion q) {
    final up = Vector3(0, 1, 0)..applyQuaternion(q);
    return math.acos(up.y.clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  testWidgets('a simulating BP_Chair placed 150 cm up falls and rests with its mesh\'s 23 kg; walking into it tips it over',
      (tester) async {
    final vm = await editorFor(tester);
    final w = await measureWalk(tester, vm);
    final floorY = w.start.y - 90; // the template capsule's half height
    final at = LuminaAxes.toAuthoringLocation(w.start + w.dir * 250)..[2] = LuminaAxes.toAuthoringLocation(Vector3(0, floorY, 0))[2] + 150;
    final chair = await place(tester, vm, at);

    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    final world = LuminaWorld();
    final game = vm.pieController.startHeadlessForTest(world);
    final runtime = world.persistentLevel.actors.firstWhere((a) => a.key == ValueKey(chair.id)) as LuminaBlueprintInstance;
    final box = runtime.blueprintComponents['box'] as LuminaBoxComponent;
    expect(box.isSimulatingPhysics, isTrue);
    expect(box.resolvedMassKg, 23.0, reason: 'inherited from SM_Chair.lmas');
    final startY = box.worldLocation.y;
    run(world, 150);
    // Fell 150 cm and rests upright on the floor: its centre at half its height.
    expect(startY - box.worldLocation.y, greaterThan(120), reason: 'fell (from $startY to ${box.worldLocation.y})');
    expect(box.physicsBody!.linearVelocity.length, lessThan(5), reason: 'at rest');
    expect(tilt(box.worldRotation), lessThan(5));
    final restY = box.worldLocation.y;

    game.injectKeyDown(LuminaKey.keyW);
    var peak = 0.0;
    run(world, 180, (_) => peak = math.max(peak, tilt(box.worldRotation)));
    game.injectKeyUp(LuminaKey.keyW);
    run(world, 60, (_) => peak = math.max(peak, tilt(box.worldRotation)));
    expect(peak, greaterThan(30), reason: 'walking into it tipped it (peak ${peak.toStringAsFixed(1)}°)');
    expect(box.worldLocation.y, lessThan(restY + 5), reason: 'still on the floor');
    vm.pieController.stopHeadlessForTest();
  });

  testWidgets('a placed BP_Chair overrides Simulate Physics in the level Details: Play keeps it in the air; the level .lmas stores it',
      (tester) async {
    final vm = await editorFor(tester);
    final chair = await place(tester, vm, [300, 0, 150]);
    final box = BlueprintCollisionOverrides.physicsComponentsOf(chair, vm.projectDirPath).firstWhere((c) => c.id == 'box');
    expect(BlueprintCollisionOverrides.physicsOf(chair, box)['simulate'], isTrue, reason: 'the class simulates');
    expect(vm.setActorComponentPhysics(chair.id, box, {...BlueprintCollisionOverrides.physicsOf(chair, box), 'simulate': false}), isTrue);
    expect(vm.transactions.undoLabel, 'Undo Edit Physics of ${chair.name}.Box');

    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    final world = LuminaWorld();
    vm.pieController.startHeadlessForTest(world);
    final runtime = world.persistentLevel.actors.firstWhere((a) => a.key == ValueKey(chair.id)) as LuminaBlueprintInstance;
    final built = runtime.blueprintComponents['box'] as LuminaBoxComponent;
    final y = built.worldLocation.y;
    run(world, 60);
    expect(built.isSimulatingPhysics, isFalse);
    expect(built.worldLocation.y, closeTo(y, 1e-6), reason: 'not simulating: it stays where it was placed');
    vm.pieController.stopHeadlessForTest();

    await tester.runAsync(vm.saveLevelAndGenerateCode);
    final level = jsonDecode(File('${vm.projectDirPath}/contents/levels/${vm.activeLevelName}.lmas').readAsStringSync()) as Map;
    final actors = (level['metadata'] as Map)['actors'];
    final saved = (actors is String ? jsonDecode(actors) : actors) as List;
    final node = ((saved.firstWhere((a) => a['id'] == chair.id) as Map)['components'] as List)
        .firstWhere((c) => (c['properties'] as Map)['blueprintComponentId'] == 'box') as Map;
    expect(((node['properties'] as Map)['physics'] as Map)['simulate'], isFalse);
    // lumina reads the same override for the generated level.
    expect(LuminaBlueprintCollisionOverrides.fromActorMap(Map<String, dynamic>.from(saved.firstWhere((a) => a['id'] == chair.id) as Map))['box']?['physics'],
        containsPair('simulate', false));
  });
}
