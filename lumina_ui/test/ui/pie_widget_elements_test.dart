import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/toolbar_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_compile_status.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_graph_editor.dart';

import '../helpers/scaffold_game_project.dart';
import '../helpers/widget_class_test_project.dart';

/// The FPS HUD authored through the context-sensitive
/// palette plays in PIE with per-element widget state, on a real Third
/// Person project with a real `WBP_HUD.lmas`.
/// The last exec output of the chain that starts at [nodeStart].[pin]: the
/// node whose exec output is not wired yet.
({LuminaBlueprintNode node, String pin}) execChainEnd(BlueprintGraphEditor g, LuminaBlueprintNode nodeStart, String pin) {
  var node = nodeStart;
  var out = pin;
  while (true) {
    final next = g.wires.where((w) => w.fromNodeId == node.id && w.fromPinId == out).firstOrNull;
    if (next == null) return (node: node, pin: out);
    final to = g.node(next.toNodeId)!;
    final exec = g.pinsOf(to).outputs.where((p) => p.type == LuminaPinType.exec).firstOrNull;
    if (exec == null) return (node: node, pin: out);
    node = to;
    out = exec.id;
  }
}

void main() {
  late Directory root;
  late String dir;
  const characterPath = LuminaThirdPersonContent.characterBlueprintPath;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_bp07_pie_');
    dir = await scaffoldGameProject(root, name: 'hud_play', widgetLibrary: 'flutter');
    writeWidgetBlueprint(dir, 'WBP_HUD', hudDocument());
  });
  tearDownAll(() {
    LuminaWidgetClassRegistry.clear();
    root.deleteSync(recursive: true);
  });

  LuminaProject manifest() =>
      LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/hud_play.lmproject').readAsStringSync()) as Map));

  /// The user's flow, through the palette rows a drag offers at each step:
  /// BeginPlay → Create Widget (WBP_HUD) → Promote to Variable (HudWidget) →
  /// Add to Viewport; Tick → Get HudWidget → Is Valid? → Get FPSCounter →
  /// Set Text (Text) ← Format Text "FPS: {0}" ← To String (int) ← Round ←
  /// 1 / Delta Seconds.
  Future<BlueprintEditorViewModel> authorFpsHud(WidgetTester tester) async {
    final bp = BlueprintEditorViewModel(assetPath: '$dir/$characterPath');
    await tester.runAsync(bp.load);
    final g = bp.eventGraph;
    BlueprintPinRef out(LuminaBlueprintNode n, String pin) => BlueprintPinRef.of(n.id, g.pin(n.id, pin, output: true)!, isOutput: true);
    LuminaBlueprintNode pick(BlueprintPinRef from, String title, Offset at, {Map<String, dynamic>? literals}) {
      final entries = g.paletteEntriesFor(from);
      final entry = entries.firstWhere((e) => e.title == title && (literals == null || literals.entries.every((l) => e.literals[l.key] == l.value)),
          orElse: () => throw StateError('$title not offered from ${from.pinId}: ${entries.map((e) => e.title).toList()}'));
      return g.placeEntry(entry, at, from: from)!;
    }

    final begin = bp.addGraphNode('event_beginplay', const Offset(0, 1200))!;
    final create = pick(out(begin, 'exec_out'), 'Create Widget', const Offset(260, 1200));
    bp.setPinLiteral(create.id, 'class', 'WBP_HUD');
    final promote = g.paletteEntriesFor(out(create, 'return_value')).first;
    expect(promote.action, BlueprintPaletteAction.promoteToVariable);
    final set = g.placeEntry(promote, const Offset(560, 1200), from: out(create, 'return_value'))!;
    expect(bp.document.variable('HudWidget')!.typeName, 'Widget:WBP_HUD');
    final add = pick(out(set, 'exec_out'), 'Add to Viewport', const Offset(860, 1200));
    expect(g.addWire(fromNodeId: set.id, fromPinId: 'value', toNodeId: add.id, toPinId: 'target'), isNotNull);

    // The template already has an Event Tick (lumina 33bd632: Tick → Line
    // Trace Forward → Set WallAhead); a second one would not compile. The
    // FPS chain splices after its last exec node.
    final tick = g.nodes.singleWhere((n) => n.registryId == 'event_tick');
    final tail = execChainEnd(g, tick, 'exec_tick_out');
    final get = bp.eventGraph.placeVariable('HudWidget', set: false, position: const Offset(0, 1600))!;
    final valid = pick(out(get, 'value'), 'Is Valid', const Offset(260, 1500), literals: const {});
    final validBranch = valid.registryId == LuminaBlueprintNodeLibrary.isValidBranch
        ? valid
        : (g.removeNode(valid.id) ? g.placeEntry(g.paletteEntriesFor(out(get, 'value')).firstWhere((e) => e.registryId == LuminaBlueprintNodeLibrary.isValidBranch), const Offset(260, 1500), from: out(get, 'value'))! : valid);
    expect(g.addWire(fromNodeId: tail.node.id, fromPinId: tail.pin, toNodeId: validBranch.id, toPinId: 'exec_in'), isNotNull);
    expect(tail.node.id, isNot(tick.id), reason: 'the template\'s WallAhead trace still runs first');
    final fps = pick(out(get, 'value'), 'Get FPSCounter', const Offset(260, 1650));
    final setText = pick(out(fps, 'return_value'), 'Set Text (Text)', const Offset(600, 1500));
    expect(g.addWire(fromNodeId: validBranch.id, fromPinId: 'is_valid', toNodeId: setText.id, toPinId: 'exec_in'), isNotNull);
    final divide = bp.addGraphNode('float_divide', const Offset(260, 1800), literals: {'a': 1.0})!;
    expect(g.addWire(fromNodeId: tick.id, fromPinId: 'delta_seconds', toNodeId: divide.id, toPinId: 'b'), isNotNull);
    final round = pick(out(divide, 'return_value'), 'Round', const Offset(460, 1800));
    final toString = pick(out(round, 'return_value'), 'To String (int)', const Offset(660, 1800));
    final format = pick(out(toString, 'return_value'), 'Format Text', const Offset(860, 1800));
    expect(g.pinsOf(format).inputs.where((p) => p.id.startsWith('arg_')).map((p) => p.name), ['{0}']);
    // The drop joined the first string input (Format); move it to {0}, as a
    // user re-drags it.
    expect(g.addWire(fromNodeId: toString.id, fromPinId: 'return_value', toNodeId: format.id, toPinId: 'arg_0'), isNotNull);
    expect(g.breakLinks(format.id, 'format', output: false), isTrue);
    bp.setPinLiteral(format.id, 'format', 'FPS: {0}');
    expect(g.addWire(fromNodeId: format.id, fromPinId: 'return_value', toNodeId: setText.id, toPinId: 'in_text'), isNotNull);
    expect(await tester.runAsync(bp.compile), isTrue, reason: '${bp.diagnostics}');
    expect(bp.compileStatus, BlueprintCompileStatus.upToDate);
    expect(await tester.runAsync(bp.save), isTrue);
    return bp;
  }

  testWidgets('PIE registers WBP_HUD, and after 30 frames FPSCounter reads FPS: <n> while Health keeps its designer percent',
      (tester) async {
    LuminaWidgetClassRegistry.clear();
    final bp = await authorFpsHud(tester);

    final vm = EditorViewModel(initialProject: manifest(), projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();
    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');

    final world = LuminaWorld();
    final game = vm.pieController.startHeadlessForTest(world);
    final hud = LuminaWidgetClassRegistry.lookup('WBP_HUD');
    expect(hud, isNotNull, reason: 'Play registers the project\'s widget classes');
    expect(hud!.elements.map((e) => e.name), ['FPSCounter', 'Health']);
    final pawn = game.possessedPawn!;
    expect((pawn as LuminaBlueprintInstance).blueprintClass.name, 'BP_ThirdPersonCharacter');

    for (var i = 0; i < 30; i++) {
      world.tick(1 / 60);
    }
    final subsystem = world.getSubsystem<LuminaWidgetSubsystem>()!;
    final instance = subsystem.activeWidgets.value.singleWhere((w) => w['class'] == 'WBP_HUD');
    expect(instance['inViewport'], isTrue);
    final elements = instance['elements'] as Map;
    final fpsText = (elements['FPSCounter'] as Map)['text'] as String;
    expect(fpsText, matches(RegExp(r'^FPS: \d+$')), reason: 'Set Text wrote only FPSCounter');
    expect(fpsText, 'FPS: 60', reason: '1 / (1/60)');
    expect((elements['Health'] as Map)['percent'], 0.75, reason: 'the designer\'s percent is untouched');
    expect((elements['Health'] as Map).containsKey('text'), isFalse, reason: 'no element shares state with another');

    // The toolbar's FPS is the Play world's own frame rate: what Get Frame
    // Rate reads, rounded the same way.
    final stats = ToolbarFrameStats.of(vm);
    expect(stats.fromWorld, isTrue);
    expect(stats.fps.round(), LuminaBlueprintFunctionLibrary.getFrameRate(pawn).round());
    expect(stats.fps.round(), 60);
    expect(stats.label(0), endsWith('60 FPS'));
    expect(fpsText, 'FPS: ${stats.fps.round()}', reason: 'the HUD and the toolbar agree');
    vm.pieController.stopHeadlessForTest();
    bp.dispose();
  });
}
