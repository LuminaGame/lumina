import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/project_blueprint_functions.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/node_palette.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';
import '../helpers/scaffold_game_project.dart';

/// Project functions in Blueprints on a real Third Person project (scaffolded with a real
/// `flutter pub get --offline`, so lumina's analyzer-based scanner resolves
/// it) and real annotated source files under its lib/.
void main() {
  late Directory root;
  late String dir;

  const applyDamageId = 'fn:package:fn_game/health.dart#applyDamage';

  const healthSource = '''
import 'package:lumina/lumina_runtime.dart';

/// Hit points by actor: 100 until damaged.
final Expando<double> _health = Expando<double>('health');

/// Takes [amount] hit points from the actor running the node.
@BlueprintCallable(category: 'Game|Health', keywords: ['hurt', 'hit'])
void applyDamage(LuminaActor self, double amount) {
  final left = (_health[self] ?? 100.0) - amount;
  _health[self] = left < 0.0 ? 0.0 : left;
  print('[applyDamage] \${self.runtimeType} took \$amount, \${_health[self]} left');
}
''';

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_bp06_');
    dir = await scaffoldGameProject(root, name: 'fn_game', widgetLibrary: 'flutter');
  });
  tearDownAll(() {
    LuminaBlueprintFunctionRegistry.clearDeclared();
    root.deleteSync(recursive: true);
  });

  /// lib/health.dart with Apply Damage — what the first test leaves in the
  /// project and the later ones build on. Each of them writes it when it is
  /// missing: a sharded run (`--total-shards`) runs every test of
  /// this file in its own process, where no earlier test ran.
  void ensureHealthSource() {
    final health = File('$dir/lib/health.dart');
    if (!health.existsSync() || health.readAsStringSync() != healthSource) health.writeAsStringSync(healthSource);
  }

  /// BP_Target: BeginPlay → Apply Damage (25) → Set Actor Location (0, 0, 500),
  /// compiled and saved (the Apply Damage compile test's Blueprint, which the
  /// PIE test plays).
  Future<void> buildTargetBlueprint() async {
    ensureHealthSource();
    await ProjectBlueprintFunctions(dir).scan();
    final path = writeBlueprint(dir, 'BP_Target', BlueprintEditorViewModel.createDefaultDocument('BP_Target', parentClass: 'LuminaActor'));
    final bp = BlueprintEditorViewModel(assetPath: path);
    await bp.load();
    final begin = bp.graphNodes.where((n) => n.registryId == 'event_beginplay').firstOrNull ??
        bp.addGraphNode('event_beginplay', const Offset(0, 600))!;
    final damage = bp.addGraphNode(applyDamageId, const Offset(300, 600))!;
    expect(damage.title, 'Apply Damage');
    final move = bp.addGraphNode('set_actor_location', const Offset(600, 600))!;
    expect(bp.addGraphWire(fromNodeId: begin.id, fromPinId: 'exec_out', toNodeId: damage.id, toPinId: 'exec_in'), isNotNull);
    expect(bp.addGraphWire(fromNodeId: damage.id, fromPinId: 'exec_out', toNodeId: move.id, toPinId: 'exec_in'), isNotNull);
    bp.setPinLiteral(damage.id, 'amount', 25.0);
    bp.setPinLiteral(move.id, 'new_location', [0.0, 0.0, 500.0]);

    expect(await bp.compile(), isTrue, reason: '${bp.diagnostics}');
    expect(bp.diagnostics.where((d) => d.isError), isEmpty);
    expect(bp.diagnostics.where((d) => d.nodeId == damage.id).single.message, contains('requires Play Standalone'));
    await bp.save();
  }

  BlueprintPaletteEntry? paletteEntry(String id) =>
      BlueprintPalette.entries().where((e) => e.registryId == id).firstOrNull;

  Future<void> until(bool Function() done, {Duration timeout = const Duration(seconds: 60)}) async {
    final sw = Stopwatch()..start();
    while (!done() && sw.elapsed < timeout) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  Iterable<String> logLines(String source) =>
      EngineLoggerService().logs.where((l) => l.source == source).map((l) => l.message);

  test('an annotated function added under lib/ appears in the palette under its category; removing the annotation removes it',
      () async {
    final fns = ProjectBlueprintFunctions(dir);
    addTearDown(fns.dispose);
    await fns.open();
    expect(paletteEntry(applyDamageId), isNull);

    // Warm the analyzer once (the first resolution of package:lumina in a
    // process is the slow part), as the editor has by the time a user edits.
    File('$dir/lib/warmup.dart').writeAsStringSync('''
import 'package:lumina/lumina_runtime.dart';

/// Warms the analyzer.
@BlueprintPure()
double warmup(double x) => x;
''');
    await fns.scan();
    expect(fns.functions.map((f) => f.spec.title), ['Warmup']);
    File('$dir/lib/warmup.dart').deleteSync();
    await fns.scan();

    final sw = Stopwatch()..start();
    File('$dir/lib/health.dart').writeAsStringSync(healthSource);
    await until(() => paletteEntry(applyDamageId) != null);
    final appeared = sw.elapsed;
    // ignore: avoid_print
    print('[bp06] Apply Damage appeared ${appeared.inMilliseconds} ms after the save '
        '(debounce ${fns.debounce.inMilliseconds} ms + scan ${fns.lastScanDuration?.inMilliseconds} ms)');
    final entry = paletteEntry(applyDamageId)!;
    expect(entry.title, 'Apply Damage');
    expect(entry.category, 'Game|Health');
    expect(entry.isProject, isTrue);
    expect(entry.tooltip, contains('Takes [amount] hit points'));
    expect(appeared, lessThan(fns.debounce + fns.lastScanDuration! + const Duration(seconds: 1)),
        reason: 'the watcher rescans once, a debounce after the save');
    // The budget: with the analyzer warm, a saved function
    // reaches the palette within 2 s.
    expect(appeared, lessThan(const Duration(seconds: 2)), reason: 'appeared after $appeared');
    expect(File('$dir/lib/blueprint/blueprint_functions.g.dart').readAsStringSync(), contains('applyDamage'));
    expect(File('$dir/project.blueprint_functions.json').readAsStringSync(), contains(applyDamageId));

    // Removing the annotation removes the node.
    File('$dir/lib/health.dart').writeAsStringSync(healthSource.replaceFirst(
        "@BlueprintCallable(category: 'Game|Health', keywords: ['hurt', 'hit'])\n", ''));
    await until(() => paletteEntry(applyDamageId) == null);
    expect(paletteEntry(applyDamageId), isNull);
    expect(File('$dir/lib/blueprint/blueprint_functions.g.dart').readAsStringSync(), isNot(contains('applyDamage')));

    File('$dir/lib/health.dart').writeAsStringSync(healthSource);
    await until(() => paletteEntry(applyDamageId) != null);
    expect(paletteEntry(applyDamageId), isNotNull);
  });

  testWidgets('the palette lists project functions in a Project section with a badge and their doc comment',
      (tester) async {
    await tester.runAsync(() {
      ensureHealthSource();
      return ProjectBlueprintFunctions(dir).scan();
    });
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: BlueprintNodePalette(entries: BlueprintPalette.entries(), onSelect: (_) {}, onClose: () {}),
      ),
    ));
    await tester.enterText(find.byKey(const ValueKey('palette_search')), 'damage');
    await tester.pump();
    expect(find.byKey(const ValueKey('palette_project_section')), findsOneWidget);
    expect(find.text('GAME › HEALTH'), findsOneWidget);
    expect(find.byKey(const ValueKey('palette_project_badge_$applyDamageId')), findsOneWidget);
    expect(find.byKey(const ValueKey('palette_tooltip_$applyDamageId')), findsOneWidget);
    final sectionY = tester.getTopLeft(find.byKey(const ValueKey('palette_project_section'))).dy;
    final rowY = tester.getTopLeft(find.byKey(const ValueKey('palette_entry_$applyDamageId'))).dy;
    expect(rowY, greaterThan(sectionY));
  });

  test('BeginPlay → Apply Damage compiles with no errors; the generated class calls applyDamage(this, …) and the project analyzes clean',
      () async {
    await buildTargetBlueprint();

    final generated = File('$dir/lib/actors/bp_target.dart').readAsStringSync();
    expect(generated, contains('import \'package:fn_game/health.dart\' as fn_fn_game_health;'));
    expect(generated, contains('fn_fn_game_health.applyDamage(this, 25.0)'));

    // The editor's main.dart registers the functions for the VM.
    final vm = EditorViewModel(
        initialProject: LuminaProject.fromMap(
            Map<String, dynamic>.from(jsonDecode(File('$dir/fn_game.lmproject').readAsStringSync()) as Map)),
        projectLocation: root.path,
        enableTimers: false,
        autoInitAssets: false);
    addTearDown(vm.dispose);
    await vm.ensureDefaultLevelAssets();
    await vm.saveLevelAndGenerateCode();
    final main = File('$dir/lib/main.dart').readAsStringSync();
    expect(main, contains("import 'blueprint/blueprint_functions.g.dart';"));
    expect(main, contains('registerProjectBlueprintFunctions();'));

    final analyze = await analyzeGameProject(dir);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('a Future-returning function is not listed: the Output Log names file and line, and a node using it says why',
      () async {
    final fns = ProjectBlueprintFunctions(dir);
    addTearDown(fns.dispose);
    File('$dir/lib/regen.dart').writeAsStringSync('''
import 'package:lumina/lumina_runtime.dart';

/// Heals the actor.
@BlueprintCallable(category: 'Game|Health')
void regenerate(LuminaActor self) {}
''');
    await fns.scan();
    const regenId = 'fn:package:fn_game/regen.dart#regenerate';
    expect(paletteEntry(regenId), isNotNull);
    final path = writeBlueprint(dir, 'BP_Healer', BlueprintEditorViewModel.createDefaultDocument('BP_Healer', parentClass: 'LuminaActor'));
    final bp = BlueprintEditorViewModel(assetPath: path);
    await bp.load();
    final begin = bp.addGraphNode('event_beginplay', const Offset(0, 600))!;
    final regen = bp.addGraphNode(regenId, const Offset(300, 600))!;
    bp.addGraphWire(fromNodeId: begin.id, fromPinId: 'exec_out', toNodeId: regen.id, toPinId: 'exec_in');

    // The function becomes async: the scanner refuses it.
    File('$dir/lib/regen.dart').writeAsStringSync('''
import 'package:lumina/lumina_runtime.dart';

/// Heals the actor, later.
@BlueprintCallable(category: 'Game|Health')
Future<void> regenerate(LuminaActor self) async {}
''');
    final before = EngineLoggerService().logs.length;
    await fns.scan();
    expect(paletteEntry(regenId), isNull, reason: 'a Future return is not a Blueprint node');
    final finding = fns.diagnosticFor('regenerate')!;
    expect(finding.path, 'lib/regen.dart');
    expect(finding.line, 5);
    final logged = EngineLoggerService().logs.skip(before).where((l) => l.source == 'BlueprintFunctions' && l.level == 'error');
    expect(logged.map((l) => l.message), contains(startsWith('lib/regen.dart:5: ')));

    expect(await bp.compile(), isFalse);
    final error = bp.diagnostics.singleWhere((d) => d.nodeId == regen.id);
    expect(error.isError, isTrue);
    expect(error.message, contains('lib/regen.dart:5'));
    File('$dir/lib/regen.dart').deleteSync();
    await fns.scan();
  });

  testWidgets('PIE warns that Apply Damage requires Play Standalone, naming the node, and plays the rest of the graph',
      (tester) async {
    await tester.runAsync(() async {
      ensureHealthSource();
      await ProjectBlueprintFunctions(dir).scan();
      if (!File('$dir/contents/blueprints/BP_Target.lmas').existsSync()) await buildTargetBlueprint();
    });
    final vm = EditorViewModel(
        initialProject: LuminaProject.fromMap(
            Map<String, dynamic>.from(jsonDecode(File('$dir/fn_game.lmproject').readAsStringSync()) as Map)),
        projectLocation: root.path,
        enableTimers: false,
        autoInitAssets: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();
    final asset = vm.realAssets.firstWhere((a) => a.relativePath == 'contents/blueprints/BP_Target.lmas');
    await tester.runAsync(() => vm.spawnActorFromAsset(asset, location: [0.0, 800.0, 0.0]));
    final placed = vm.actors.firstWhere((a) => a.blueprintClass == asset.relativePath);

    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: 'warnings never block: ${vm.playBlockers}');
    final warning = vm.playWarnings.singleWhere((w) => w.blueprintName == 'BP_Target' && w.nodeId != null);
    expect(warning.nodeTitle, 'Apply Damage');
    expect(warning.message, contains('requires Play Standalone'));
    expect(logLines('Blueprint'), contains(allOf(contains('BP_Target → Apply Damage'), contains('requires Play Standalone'))));

    final before = EngineLoggerService().logs.length;
    final world = LuminaWorld();
    vm.pieController.startHeadlessForTest(world);
    for (var i = 0; i < 10; i++) {
      world.tick(1 / 60);
    }
    final runtime = world.persistentLevel.actors.firstWhere((a) => a.key == ValueKey(placed.id));
    // Set Actor Location after the skipped node ran: the rest of the graph plays.
    expect((runtime.actorLocation - LuminaAxes.location([0.0, 0.0, 500.0])).length, lessThan(1e-6),
        reason: 'at ${runtime.actorLocation}');
    final notices = EngineLoggerService()
        .logs
        .skip(before)
        .where((l) => l.source == 'PIE' && l.message.contains('Apply Damage') && l.message.contains('requires Play Standalone'));
    expect(notices, hasLength(1), reason: 'logged once, when the node is reached');
    vm.pieController.stopHeadlessForTest();
    BlueprintPieDebugger.instance.clear();
  });
}
