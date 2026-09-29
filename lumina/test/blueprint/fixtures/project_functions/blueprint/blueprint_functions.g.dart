// GENERATED CODE - DO NOT MODIFY BY HAND
// The project's Dart functions exposed to Blueprints: every
// @BlueprintCallable / @BlueprintPure function under lib/, read by
// BlueprintFunctionScanner. Generated Blueprint classes call them directly; this
// registers them for the Blueprint VM.

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

import '../health.dart' as fn_fixture_health;
import '../markers.dart' as fn_fixture_markers;
import '../types.dart' as fn_fixture_types;

/// Registers the functions with [LuminaBlueprintFunctionRegistry] so the
/// Blueprint VM can run them. The generated game's `main()` calls it once,
/// before the world starts.
void registerProjectBlueprintFunctions() {
  // lib/health.dart:13
  LuminaBlueprintFunctionRegistry.register(
    const LuminaBlueprintNodeSpec(
      id: 'fn:package:fixture/health.dart#applyDamage',
      title: 'Apply Damage',
      category: 'Game|Health',
      kind: LuminaBlueprintNodeKind.impure,
      headerColor: 0xFF1565C0,
      keywords: ['hurt', 'hit'],
      tooltip: 'Takes [amount] hit points from the actor running the node.\n[lethal] kills it outright.',
      inputs: [
        LuminaBlueprintPinSpec('exec_in', 'Exec In', LuminaPinType.exec),
        LuminaBlueprintPinSpec('amount', 'Amount', LuminaPinType.float),
        LuminaBlueprintPinSpec('lethal', 'Lethal', LuminaPinType.boolean, defaultValue: false),
      ],
      outputs: [
        LuminaBlueprintPinSpec('exec_out', 'Exec Out', LuminaPinType.exec),
      ],
    ),
    (context, inputs) {
      fn_fixture_health.applyDamage(context.self, inputs['amount'] as double, lethal: inputs['lethal'] as bool);
      return const {};
    },
    call: const LuminaBlueprintCallShape('applyDamage', ['amount', 'lethal'], self: true, library: 'package:fixture/health.dart', named: {'lethal'}, optional: {'lethal'}),
  );

  // lib/health.dart:21
  LuminaBlueprintFunctionRegistry.register(
    const LuminaBlueprintNodeSpec(
      id: 'fn:package:fixture/health.dart#healthState',
      title: 'Health State',
      category: 'Project',
      kind: LuminaBlueprintNodeKind.pure,
      headerColor: 0xFF2E7D32,
      tooltip: 'How healthy [target] is: its hit points as a fraction of 100, and whether\nit is dead.',
      inputs: [
        LuminaBlueprintPinSpec('target', 'Target', LuminaPinType.object, required: true),
      ],
      outputs: [
        LuminaBlueprintPinSpec('percent', 'Percent', LuminaPinType.float),
        LuminaBlueprintPinSpec('dead', 'Dead', LuminaPinType.boolean),
      ],
    ),
    (context, inputs) {
      final result = fn_fixture_health.healthState(inputs['target'] as LuminaActor);
      return {'percent': result.percent, 'dead': result.dead};
    },
    call: const LuminaBlueprintCallShape('healthState', ['target'], outputs: ['percent', 'dead'], library: 'package:fixture/health.dart', record: true),
  );

  // lib/markers.dart:35
  LuminaBlueprintFunctionRegistry.register(
    const LuminaBlueprintNodeSpec(
      id: 'fn:package:fixture/markers.dart#markerRing',
      title: 'Marker Ring Offset',
      category: 'Game|Markers',
      kind: LuminaBlueprintNodeKind.pure,
      headerColor: 0xFF2E7D32,
      tooltip: 'Where marker [index] of [count] goes on a ring of [radius] cm, as an\noffset on the ground (cm, Z up).',
      inputs: [
        LuminaBlueprintPinSpec('index', 'Index', LuminaPinType.integer),
        LuminaBlueprintPinSpec('radius', 'Radius', LuminaPinType.float, defaultValue: 250.0),
        LuminaBlueprintPinSpec('count', 'Count', LuminaPinType.integer, defaultValue: 3),
      ],
      outputs: [
        LuminaBlueprintPinSpec('return_value', 'Return Value', LuminaPinType.vector),
      ],
    ),
    (context, inputs) {
      final result = fn_fixture_markers.markerRing(inputs['index'] as int, radius: inputs['radius'] as double, count: inputs['count'] as int);
      return {'return_value': result};
    },
    call: const LuminaBlueprintCallShape('markerRing', ['index', 'radius', 'count'], outputs: ['return_value'], library: 'package:fixture/markers.dart', named: {'radius', 'count'}, optional: {'radius', 'count'}),
  );

  // lib/markers.dart:18
  LuminaBlueprintFunctionRegistry.register(
    const LuminaBlueprintNodeSpec(
      id: 'fn:package:fixture/markers.dart#spawnMarker',
      title: 'Spawn Marker',
      category: 'Game|Markers',
      kind: LuminaBlueprintNodeKind.impure,
      headerColor: 0xFF1565C0,
      keywords: ['spawn', 'post', 'flag'],
      tooltip: 'Places a marker post standing on [at] (cm, Z up) in the world of the actor\nrunning the node.',
      inputs: [
        LuminaBlueprintPinSpec('exec_in', 'Exec In', LuminaPinType.exec),
        LuminaBlueprintPinSpec('at', 'At', LuminaPinType.vector),
      ],
      outputs: [
        LuminaBlueprintPinSpec('exec_out', 'Exec Out', LuminaPinType.exec),
      ],
    ),
    (context, inputs) {
      fn_fixture_markers.spawnMarker(context.self, inputs['at'] as Vector3);
      return const {};
    },
    call: const LuminaBlueprintCallShape('spawnMarker', ['at'], self: true, library: 'package:fixture/markers.dart'),
  );

  // lib/types.dart:32
  LuminaBlueprintFunctionRegistry.register(
    const LuminaBlueprintNodeSpec(
      id: 'fn:package:fixture/types.dart#FixtureMath.twice',
      title: 'Twice',
      category: 'Fixture|Math',
      kind: LuminaBlueprintNodeKind.pure,
      headerColor: 0xFF2E7D32,
      tooltip: 'Twice [value].',
      inputs: [
        LuminaBlueprintPinSpec('value', 'Value', LuminaPinType.integer),
      ],
      outputs: [
        LuminaBlueprintPinSpec('return_value', 'Return Value', LuminaPinType.integer),
      ],
    ),
    (context, inputs) {
      final result = fn_fixture_types.FixtureMath.twice(inputs['value'] as int);
      return {'return_value': result};
    },
    call: const LuminaBlueprintCallShape('FixtureMath.twice', ['value'], outputs: ['return_value'], library: 'package:fixture/types.dart'),
  );

  // lib/types.dart:26
  LuminaBlueprintFunctionRegistry.register(
    const LuminaBlueprintNodeSpec(
      id: 'fn:package:fixture/types.dart#countCalls',
      title: 'Count Calls',
      category: 'Fixture|Types',
      kind: LuminaBlueprintNodeKind.impure,
      headerColor: 0xFF1565C0,
      tooltip: 'Counts the actor\'s calls, [times] at a time, and returns the total.',
      inputs: [
        LuminaBlueprintPinSpec('exec_in', 'Exec In', LuminaPinType.exec),
        LuminaBlueprintPinSpec('times', 'Times', LuminaPinType.integer, defaultValue: 1),
      ],
      outputs: [
        LuminaBlueprintPinSpec('exec_out', 'Exec Out', LuminaPinType.exec),
        LuminaBlueprintPinSpec('return_value', 'Return Value', LuminaPinType.integer),
      ],
    ),
    (context, inputs) {
      final result = fn_fixture_types.countCalls(context.self, inputs['times'] as int);
      return {'return_value': result};
    },
    call: const LuminaBlueprintCallShape('countCalls', ['times'], self: true, outputs: ['return_value'], library: 'package:fixture/types.dart', optional: {'times'}),
  );

  // lib/types.dart:8
  LuminaBlueprintFunctionRegistry.register(
    const LuminaBlueprintNodeSpec(
      id: 'fn:package:fixture/types.dart#describeTypes',
      title: 'Describe Types',
      category: 'Fixture|Types',
      kind: LuminaBlueprintNodeKind.pure,
      headerColor: 0xFF2E7D32,
      keywords: ['all'],
      tooltip: 'Every pin type at once.',
      inputs: [
        LuminaBlueprintPinSpec('count', 'Count', LuminaPinType.integer),
        LuminaBlueprintPinSpec('label', 'Label', LuminaPinType.string),
        LuminaBlueprintPinSpec('size', 'Size', LuminaPinType.vector2D),
        LuminaBlueprintPinSpec('at', 'At', LuminaPinType.vector),
        LuminaBlueprintPinSpec('facing', 'Facing', LuminaPinType.rotator),
        LuminaBlueprintPinSpec('pawn', 'Pawn', LuminaPinType.object, required: true),
        LuminaBlueprintPinSpec('scale', 'Scale', LuminaPinType.float, defaultValue: 1.5),
        LuminaBlueprintPinSpec('turn', 'Turn', LuminaPinType.rotator, defaultValue: [0.0, 0.0, 90.0]),
        LuminaBlueprintPinSpec('other', 'Other', LuminaPinType.object),
      ],
      outputs: [
        LuminaBlueprintPinSpec('return_value', 'Return Value', LuminaPinType.string),
      ],
    ),
    (context, inputs) {
      final result = fn_fixture_types.describeTypes(inputs['count'] as int, inputs['label'] as String, inputs['size'] as Vector2, inputs['at'] as Vector3, inputs['facing'] as LuminaRotator, inputs['pawn'] as LuminaPawn, scale: inputs['scale'] as double, turn: inputs['turn'] as LuminaRotator, other: inputs['other'] as LuminaActor?);
      return {'return_value': result};
    },
    call: const LuminaBlueprintCallShape('describeTypes', ['count', 'label', 'size', 'at', 'facing', 'pawn', 'scale', 'turn', 'other'], outputs: ['return_value'], library: 'package:fixture/types.dart', named: {'scale', 'turn', 'other'}, optional: {'scale', 'turn', 'other'}),
  );
}
