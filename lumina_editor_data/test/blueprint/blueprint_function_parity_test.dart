import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import 'blueprint_function_fixture.dart';
import '../../../lumina/test/blueprint/fixtures/project_functions/blueprint/blueprint_functions.g.dart';
import '../../../lumina/test/blueprint/fixtures/project_functions/health.dart';
import '../../../lumina/test/blueprint/fixtures/project_functions/markers.dart';
import '../../../lumina/test/blueprint/generated/bp_project_functions.g.dart';

/// The committed registration (what the scanner generates for
/// the fixture project) compiles and registers the annotated functions, the
/// VM runs them, and the generated Blueprint calling them directly traces
/// exactly like the VM (the codegen parity harness).
void main() {
  setUp(registerProjectBlueprintFunctions);
  tearDown(LuminaBlueprintFunctionRegistry.clear);

  LuminaWorld world() => LuminaWorld(worldType: LuminaWorldType.game);

  test('after registerProjectBlueprintFunctions() the VM runs BeginPlay → Apply Damage(25)', () {
    expect(LuminaBlueprintFunctionRegistry.entry(applyDamageId)!.callable, isTrue);
    expect(LuminaBlueprintNodeLibrary.spec(applyDamageId)!.title, 'Apply Damage');
    final doc = LuminaBlueprintDocument(eventGraph: LuminaBlueprintGraph(nodes: [
      LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'begin'),
      LuminaBlueprintNodeLibrary.place(applyDamageId, nodeId: 'damage', literals: {'amount': 25.0}),
    ], wires: const [
      LuminaBlueprintWire(id: 'w', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'damage', toPinId: 'exec_in'),
    ]));
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_Damage');
    expect(cls.diagnostics, isEmpty);
    final actor = cls.instantiate();
    final w = world()..persistentLevel.registerActor(actor);
    expect(healthOf(actor), 100.0);
    w.beginPlay();
    expect(healthOf(actor), 75.0);
  });

  test('a registered function is callable twice over, and registering again throws', () {
    expect(registerProjectBlueprintFunctions, throwsStateError);
    final f = LuminaBlueprintFunctionLibrary.functions[markerRingId]!;
    final out = f(LuminaBlueprintCallContext(LuminaActor()), {'index': 0, 'radius': 100.0, 'count': 4});
    expect((out['return_value'] as Vector3).y, closeTo(100.0, 1e-9));
    final state = LuminaBlueprintFunctionLibrary.functions[healthStateId]!(
        LuminaBlueprintCallContext(LuminaActor()), {'target': LuminaActor()});
    expect(state, {'percent': 1.0, 'dead': false});
  });

  test('the generated Blueprint calls the functions directly and traces exactly like the VM', () {
    final code = const BlueprintDartGenerator().generate(
      projectFunctionsBlueprint(),
      className: 'BpProjectFunctions',
      assetPath: 'contents/blueprints/BP_ProjectFunctions.lmas',
      functionImports: const {
        'package:fixture/health.dart': '../fixtures/project_functions/health.dart',
        'package:fixture/markers.dart': '../fixtures/project_functions/markers.dart',
        'package:fixture/types.dart': '../fixtures/project_functions/types.dart',
      },
    );
    expect(code.issues, isEmpty, reason: 'registered, so callable: no warnings');
    expect(code.code, contains('fn_fixture_health.applyDamage(this, 25.0);'));

    ({LuminaActor actor, List<LuminaBlueprintTraceEvent> trace}) run(bool generated) {
      final actor = generated
          ? BpProjectFunctions()
          : LuminaBlueprintClass.fromDocument(projectFunctionsBlueprint(), name: 'BP_ProjectFunctions').instantiate();
      final trace = <LuminaBlueprintTraceEvent>[];
      (actor as LuminaBlueprintRuntime).trace = trace.add;
      final w = world()..persistentLevel.registerActor(actor);
      w.beginPlay();
      w.tick(1 / 60);
      return (actor: actor, trace: trace);
    }

    final vm = run(false);
    final gen = run(true);
    expect(vm.trace.map((t) => t.nodeId), ['damage', 'count', 'twice', 'set_calls', 'ring', 'move', 'print']);
    expect(gen.trace.length, vm.trace.length);
    for (var i = 0; i < vm.trace.length; i++) {
      final a = vm.trace[i], b = gen.trace[i];
      final where = 'step $i: VM $a vs generated $b';
      expect(b.eventNodeId, a.eventNodeId, reason: where);
      expect(b.nodeId, a.nodeId, reason: where);
      expect(b.registryId, a.registryId, reason: where);
      expect(b.printed, a.printed, reason: where);
      expect(b.values.keys.toList(), a.values.keys.toList(), reason: where);
      for (final k in a.values.keys) {
        expect(b.values[k], a.values[k], reason: '$where, pin $k');
      }
    }
    expect(vm.trace.firstWhere((t) => t.nodeId == 'damage').values, {'amount': 25.0, 'lethal': false});
    expect(vm.trace.firstWhere((t) => t.nodeId == 'count').values, {'times': 2, 'return_value': 2});
    expect(vm.trace.firstWhere((t) => t.nodeId == 'set_calls').values, {'value': 4});
    for (final r in [vm, gen]) {
      expect(healthOf(r.actor), 75.0);
      expect(markersPlacedBy(r.actor), 0);
    }
    expect((vm.actor as LuminaBlueprintActor).variables['Calls'], 4);
    expect((gen.actor as BpProjectFunctions).calls, 4);
    expect(gen.actor.actorLocation, vm.actor.actorLocation);
    expect(LuminaBlueprintFunctionLibrary.toAuthoring(vm.actor.actorLocation).x, closeTo(250.0 * 0.8660254037844386, 1e-9));
  });
}
