import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';

import '../helpers/scaffold_game_project.dart';
import '../helpers/temp_project.dart';

/// The user's Level Blueprint, `Event BeginPlay → Set Show
/// Mouse Cursor (true)`, left Play's pointer hidden and captured, so a
/// widget's button could not be clicked. Play now follows the possessed
/// controller: a shown cursor or a UI input mode frees the pointer, and
/// setting it back captures again. A real Third Person project, played
/// headless.
void main() {
  late Directory root;
  late String dir;
  const name = 'bp_cursor_play';

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_bugs61_pie_');
    dir = await scaffoldGameProject(root, name: name, widgetLibrary: 'flutter');
  });
  tearDownAll(() => deleteTempProject(root));
  tearDown(() {
    BlueprintPieDebugger.instance.clear();
    LuminaBlueprintActorClasses.clear();
  });

  LuminaProject manifest() =>
      LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/$name.lmproject').readAsStringSync()) as Map));

  /// Level BeginPlay → Set Show Mouse Cursor (true); Target wired from Get
  /// Player Controller (0) when [wired], unwired as in the user's graph when not.
  LuminaLevelBlueprintDocument cursorScript(LuminaLevelDocument level, {required bool wired}) {
    final doc = LuminaLevelBlueprintDocument(levelPath: level.relativePath);
    final context = LuminaBlueprintTypeContext.forLevel(doc, levelActors: level.levelActorRefs);
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    doc.blueprint.eventGraph.nodes.addAll([
      p('event_level_begin_play', 'begin'),
      p('set_show_mouse_cursor', 'cursor', {'show_mouse_cursor': true}),
      if (wired) p('get_player_controller', 'pc'),
    ]);
    doc.blueprint.eventGraph.wires.addAll([
      const LuminaBlueprintWire(id: 'w0', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'cursor', toPinId: 'exec_in'),
      if (wired)
        const LuminaBlueprintWire(id: 'w1', fromNodeId: 'pc', fromPinId: 'return_value', toNodeId: 'cursor', toPinId: 'target'),
    ]);
    expect(validateBlueprint(doc.blueprint, typeContext: context).where((d) => d.isError), isEmpty);
    return doc;
  }

  for (final wired in [true, false]) {
    testWidgets('Set Show Mouse Cursor on BeginPlay (Target ${wired ? 'wired' : 'unwired'}) frees the pointer in Play',
        (tester) async {
      final project = manifest();
      final repo = LuminaLevelRepository(dir);
      final level = repo.load(project.activeLevel)!;
      repo.saveLevelBlueprint(cursorScript(level, wired: wired));

      final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
      addTearDown(vm.dispose);
      await tester.runAsync(vm.ensureDefaultLevelAssets);
      vm.refreshAssets();
      expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
      final pie = vm.pieController;
      final world = LuminaWorld();
      pie.startHeadlessForTest(world);
      await tester.pump();
      final pc = pie.game!.playerController!;
      expect(pc.bShowMouseCursor, isTrue, reason: 'the Level Blueprint ran on the player controller');

      final capture = pie.mouseCapture;
      expect(capture.isSessionActive, isTrue);
      expect(capture.isCaptured, isFalse, reason: 'the game asked for the cursor');
      expect(capture.hidesCursor, isFalse);
      expect(pie.acceptsGameInput, isTrue, reason: 'the game still takes keyboard input');

      // The game takes the pointer back when it hides the cursor again.
      pc.setShowMouseCursor(false);
      expect(capture.isCaptured, isTrue);
      expect(capture.hidesCursor, isTrue);
      // A UI input mode frees it as well.
      pc.setInputModeUIOnly();
      expect(capture.hidesCursor, isFalse);
      pc.setInputModeGameOnly();
      expect(capture.hidesCursor, isTrue);
      // F4 still gives the cursor back on top of the game's choice.
      capture.release();
      expect(capture.hidesCursor, isFalse);

      pie.stopHeadlessForTest();
      expect(capture.hidesCursor, isFalse);
      pc.setShowMouseCursor(true);
      expect(capture.isSessionActive, isFalse, reason: 'a stopped session ignores the old controller');
      vm.stopSimulation();
    });
  }
}
