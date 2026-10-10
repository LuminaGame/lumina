import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

import '../blueprint/screen_resolution_and_apply_blueprint.dart';
import 'game/display_test_support.dart';

/// The setters that only stage a value until Apply Scalability Settings runs.
const _staged = [
  'set_shadow_quality',
  'set_anti_aliasing_quality',
  'set_post_processing_quality',
  'set_texture_quality',
  'set_shading_quality',
  'set_resolution_scale',
  'set_target_fps',
  'set_vsync_enabled',
  'set_ray_tracing_enabled',
  'set_ray_traced_shadows_enabled',
  'set_restir_enabled',
  'set_restir_candidates',
  'set_restir_spatial_samples',
  'set_upscaler',
  'set_upscaler_quality',
  'set_upscaler_sharpness',
  'set_frame_generation_enabled',
  'set_frame_generator',
  'set_dlss_generated_frames',
  'set_screen_resolution',
  'set_fullscreen_monitor',
];

/// Setters that act at once.
const _immediate = [
  'set_overall_scalability_level',
  'set_view_distance_quality',
  'set_view_distance',
  'set_fullscreen_mode',
  'toggle_fullscreen',
  'apply_scalability_settings',
  'set_screen_resolution_and_apply',
];

LuminaBlueprintDocument _graph(List<String> nodeIds, {List<String> functionNodeIds = const []}) {
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_settings');
  final chain = ['begin', for (var k = 0; k < nodeIds.length; k++) 'n$k'];
  doc.eventGraph.nodes.add(LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'begin', context: context));
  for (var k = 0; k < nodeIds.length; k++) {
    doc.eventGraph.nodes.add(LuminaBlueprintNodeLibrary.place(nodeIds[k], nodeId: 'n$k', context: context));
  }
  for (var k = 0; k + 1 < chain.length; k++) {
    doc.eventGraph.wires.add(LuminaBlueprintWire(
        id: 'w$k', fromNodeId: chain[k], fromPinId: 'exec_out', toNodeId: chain[k + 1], toPinId: 'exec_in'));
  }
  if (functionNodeIds.isNotEmpty) {
    final f = LuminaBlueprintFunctionGraph(name: 'ApplyAll');
    doc.functions.add(f);
    f.graph.nodes.add(LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.functionEntry,
        nodeId: 'entry', context: LuminaBlueprintTypeContext.forFunction(doc, f)));
    for (var k = 0; k < functionNodeIds.length; k++) {
      f.graph.nodes.add(LuminaBlueprintNodeLibrary.place(functionNodeIds[k], nodeId: 'f$k', context: context));
    }
  }
  return doc;
}

List<String> _stagedWarnings(LuminaBlueprintDocument doc) => [
      for (final d in validateBlueprint(doc, className: 'bp_settings'))
        if (!d.isError && d.message.contains('Apply Scalability Settings')) d.message,
    ];

void main() {
  late Directory temp;
  late String settingsPath;

  setUp(() {
    resetDisplay();
    temp = Directory.systemTemp.createTempSync('lumina_staged_');
    settingsPath = LuminaGameWindow.settingsFileFor('${temp.path}/SaveGames');
  });
  tearDown(() {
    resetDisplay();
    temp.deleteSync(recursive: true);
  });

  test('every staged settings setter is flagged and says it needs Apply Scalability Settings', () {
    for (final id in _staged) {
      final spec = LuminaBlueprintNodeLibrary.builtIn(id);
      expect(spec, isNotNull, reason: id);
      expect(spec!.requiresApply, isTrue, reason: id);
      expect(spec.tooltip, endsWith(LuminaBlueprintNodeSpec.stagedNote), reason: id);
      expect(spec.tooltip!.length, greaterThan(LuminaBlueprintNodeSpec.stagedNote.length + 10), reason: id);
    }
    expect(LuminaBlueprintNodeSpec.stagedNote, 'Staged: takes effect when Apply Scalability Settings runs.');
    expect(LuminaBlueprintNodeSpec.applyHint, 'Needs Apply Scalability Settings');
  });

  test('setters that act at once are not flagged and say so', () {
    for (final id in _immediate) {
      final spec = LuminaBlueprintNodeLibrary.builtIn(id);
      expect(spec, isNotNull, reason: id);
      expect(spec!.requiresApply, isFalse, reason: id);
      expect(spec.tooltip, isNotNull, reason: id);
      expect(spec.tooltip, isNot(contains('Staged:')), reason: id);
    }
    expect(LuminaBlueprintNodeLibrary.builtIn('set_screen_resolution')!.tooltip, contains('Set Screen Resolution And Apply'));
    expect(LuminaBlueprintNodeLibrary.builtIn('get_screen_resolution')!.requiresApply, isFalse);
  });

  test('Set Screen Resolution And Apply is a Settings|Display node with a VM function and a call shape', () {
    final spec = LuminaBlueprintNodeLibrary.builtIn('set_screen_resolution_and_apply')!;
    expect(spec.title, 'Set Screen Resolution And Apply');
    expect(spec.category, 'Settings|Display');
    expect(spec.kind, LuminaBlueprintNodeKind.impure);
    expect([for (final p in spec.inputs) p.id], ['exec_in', 'width', 'height']);
    expect(spec.keywords, containsAll(['resolution', 'apply']));
    expect(LuminaBlueprintFunctionLibrary.builtInFunctions['set_screen_resolution_and_apply'], isNotNull);
    expect(LuminaBlueprintFunctionLibrary.callShapes['set_screen_resolution_and_apply']!.method, 'setScreenResolutionAndApply');
  });

  test('Set Screen Resolution And Apply applies and keeps only the resolution', () async {
    final window = FakeRunnerWindow();
    installRunner(window);
    await LuminaGameWindow.restore(settingsFilePath: settingsPath);
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = LuminaActor();
    world.persistentLevel.registerActor(actor);

    LuminaBlueprintFunctionLibrary.setFullscreenMonitor(actor, 1);
    LuminaBlueprintFunctionLibrary.setShadowQuality(actor, 'Low');
    LuminaBlueprintFunctionLibrary.setScreenResolutionAndApply(actor, 1600, 900);
    await LuminaGameDisplay.pendingApply;
    expect(window.resizes, [(1600, 900)]);
    expect(window.moves, isEmpty, reason: 'the staged monitor waits for Apply Scalability Settings');
    expect(LuminaGameDisplay.screenResolution, (1600, 900));
    expect(LuminaBlueprintFunctionLibrary.getScreenResolution(actor), (width: 1600, height: 900));
    expect(world.userSettings.fullscreenMonitorSetting, 1);
    expect(world.userSettings.hasStagedDisplaySettings, isTrue);
    final saved = jsonDecode(File(settingsPath).readAsStringSync()) as Map<String, dynamic>;
    expect(saved[LuminaGameDisplay.resolutionKey], {'width': 1600, 'height': 900});
    expect(saved.containsKey(LuminaGameDisplay.monitorKey), isFalse);

    LuminaBlueprintFunctionLibrary.applyScalabilitySettings(actor);
    await LuminaGameDisplay.pendingApply;
    expect(window.moves, [1]);
    expect(window.resizes.last, (1600, 900));
  });

  test('a Blueprint with Set Screen Resolution And Apply runs in the VM', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final actor = LuminaBlueprintClass.fromDocument(screenResolutionAndApplyBlueprint(), name: 'bp_screen_resolution_and_apply')
        .instantiate();
    final trace = <LuminaBlueprintTraceEvent>[];
    (actor as LuminaBlueprintRuntime).trace = trace.add;
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    world.tick(1 / 60);
    expect([for (final t in trace) if (t.printed != null) t.printed], ['1600', '900']);
    expect(LuminaGameDisplay.renderResolution.value, (1600, 900));
    expect(world.userSettings.toMap()[LuminaGameDisplay.resolutionKey], {'width': 1600, 'height': 900});
    expect(validateBlueprint(screenResolutionAndApplyBlueprint(), className: 'bp_screen_resolution_and_apply')
        .where((d) => d.isError), isEmpty);
  });

  group('validator', () {
    test('a staged setter without Apply Scalability Settings warns once', () {
      final warnings = _stagedWarnings(_graph(['set_screen_resolution', 'set_vsync_enabled']));
      expect(warnings, hasLength(1));
      expect(warnings.single, startsWith('Set Screen Resolution only stages its value'));
    });

    test('Apply Scalability Settings in the event graph or a function silences it', () {
      expect(_stagedWarnings(_graph(['set_vsync_enabled', 'apply_scalability_settings'])), isEmpty);
      expect(_stagedWarnings(_graph(['set_vsync_enabled'], functionNodeIds: ['apply_scalability_settings'])), isEmpty);
    });

    test('Set Screen Resolution And Apply alone needs no Apply', () {
      expect(_stagedWarnings(_graph(['set_screen_resolution_and_apply'])), isEmpty);
    });
  });
}
