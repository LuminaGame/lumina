import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../blueprint/conversions_blueprint.dart';

const _conversionIds = [
  'int_to_float',
  'truncate',
  'round',
  'floor',
  'ceil',
  'bool_to_int',
  'int_to_bool',
  'bool_to_float',
  'int_to_string',
  'float_to_string',
  'bool_to_string',
  'string_to_int',
  'string_to_float',
  'name_to_string',
  'string_to_name',
  'float_to_vector',
  'float_to_vector2d',
];

/// The Math|Conversions nodes: their edge cases in the VM, their palette
/// entries, and the conversion lookup the editor inserts nodes from.
void main() {
  final ctx = LuminaBlueprintCallContext(LuminaActor());
  Map<String, Object?> run(String id, Map<String, Object?> inputs) => LuminaBlueprintFunctionLibrary.functions[id]!(ctx, inputs);
  Object? call(String id, Map<String, Object?> inputs) => run(id, inputs)['return_value'];

  const maxInt = 9223372036854775807;
  const minInt = -9223372036854775807 - 1;

  test('float → integer: rounding direction, NaN, infinities and out-of-range values', () {
    expect(call('round', {'a': 2.5}), 3);
    expect(call('round', {'a': -2.5}), -3, reason: 'half away from zero');
    expect(call('round', {'a': 0.49}), 0);
    expect(call('truncate', {'a': -2.7}), -2);
    expect(call('truncate', {'a': 2.7}), 2);
    expect(call('floor', {'a': -2.1}), -3);
    expect(call('ceil', {'a': 2.1}), 3);
    for (final id in ['round', 'truncate', 'floor', 'ceil']) {
      expect(call(id, {'a': double.nan}), 0, reason: '$id NaN');
      expect(call(id, {'a': double.infinity}), maxInt, reason: '$id +inf saturates');
      expect(call(id, {'a': double.negativeInfinity}), minInt, reason: '$id -inf saturates');
      expect(call(id, {'a': 1e300}), maxInt, reason: '$id beyond the 64-bit range');
      expect(call(id, {'a': -1e300}), minInt, reason: '$id beyond the 64-bit range');
    }
    expect(LuminaBlueprintFunctionLibrary.truncate(double.infinity), maxInt, reason: 'the generated-code entry point agrees');
  });

  test('int, bool and float convert into each other', () {
    expect(call('int_to_float', {'a': 3}), 3.0);
    expect(call('int_to_float', {'a': -7}), -7.0);
    expect(call('bool_to_int', {'in_bool': true}), 1);
    expect(call('bool_to_int', {'in_bool': false}), 0);
    expect(call('bool_to_float', {'in_bool': true}), 1.0);
    expect(call('bool_to_float', {'in_bool': false}), 0.0);
    expect(call('int_to_bool', {'in_int': 0}), isFalse);
    expect(call('int_to_bool', {'in_int': 5}), isTrue);
    expect(call('int_to_bool', {'in_int': -1}), isTrue, reason: 'any non-zero value');
  });

  test('String to Int / String to Float report Success', () {
    ({Object? value, Object? success}) parse(String id, String s) {
      final out = run(id, {'in_string': s});
      return (value: out['return_value'], success: out['success']);
    }

    expect(parse('string_to_int', ' 42 '), (value: 42, success: true));
    expect(parse('string_to_int', '-8'), (value: -8, success: true));
    expect(parse('string_to_int', '12.7'), (value: 12, success: true), reason: 'a decimal truncates toward zero');
    expect(parse('string_to_int', '1e3'), (value: 1000, success: true));
    expect(parse('string_to_int', 'abc'), (value: 0, success: false));
    expect(parse('string_to_int', ''), (value: 0, success: false));
    expect(parse('string_to_int', 'NaN'), (value: 0, success: false));
    expect(parse('string_to_float', '2.5'), (value: 2.5, success: true));
    expect(parse('string_to_float', '-1e-2'), (value: -0.01, success: true));
    expect(parse('string_to_float', 'Infinity'), (value: 0.0, success: false));
    expect(parse('string_to_float', 'x'), (value: 0.0, success: false));
    expect(LuminaBlueprintFunctionLibrary.stringToIntChecked('7'), (returnValue: 7, success: true));
    expect(LuminaBlueprintFunctionLibrary.stringToFloatChecked('nope'), (returnValue: 0.0, success: false));
    // The single-value entry points keep their old results.
    expect(LuminaBlueprintFunctionLibrary.stringToInt('x'), 0);
    expect(LuminaBlueprintFunctionLibrary.stringToFloat(' 2.5 '), 2.5);
  });

  test('to string, name and vector conversions', () {
    expect(call('float_to_string', {'in_float': 3.14159, 'decimals': 2}), '3.14');
    expect(call('float_to_string', {'in_float': double.nan, 'decimals': 2}), 'NaN');
    expect(call('int_to_string', {'in_int': -3}), '-3');
    expect(call('bool_to_string', {'in_bool': false}), 'false');
    expect(call('name_to_string', {'in_name': 'Door_01'}), 'Door_01');
    expect(call('string_to_name', {'in_string': 'Door_01'}), 'Door_01');
    expect(call('float_to_vector', {'in_float': 2.5}), Vector3(2.5, 2.5, 2.5));
    expect(call('float_to_vector2d', {'in_float': -1.0}), Vector2(-1, -1));
  });

  test('every conversion node is in Math|Conversions with a VM function, a call shape and search keywords', () {
    for (final id in _conversionIds) {
      final spec = LuminaBlueprintNodeLibrary.builtIn(id);
      expect(spec, isNotNull, reason: id);
      expect(spec!.category, 'Math|Conversions', reason: id);
      expect(spec.kind, LuminaBlueprintNodeKind.pure, reason: id);
      expect(spec.keywords, containsAll(['convert', 'cast']), reason: id);
      expect(LuminaBlueprintFunctionLibrary.builtInFunctions[id], isNotNull, reason: id);
      expect(LuminaBlueprintFunctionLibrary.callShapes[id], isNotNull, reason: id);
    }
    for (final id in ['truncate', 'round', 'floor', 'ceil']) {
      expect(LuminaBlueprintNodeLibrary.builtIn(id)!.keywords, contains('float to int'), reason: id);
    }
    expect(LuminaBlueprintNodeLibrary.builtIn('int_to_float')!.keywords, contains('int to float'));
    expect(LuminaBlueprintNodeLibrary.builtIn('bool_to_int')!.title, 'To Integer (Bool)');
    expect(LuminaBlueprintNodeLibrary.builtIn('int_to_bool')!.title, 'To Bool (Integer)');
    expect(LuminaBlueprintNodeLibrary.builtIn('bool_to_float')!.title, 'To Float (Bool)');
    expect(LuminaBlueprintNodeLibrary.builtIn('float_to_vector')!.title, 'To Vector (Float)');
    expect(LuminaBlueprintNodeLibrary.builtIn('float_to_vector2d')!.title, 'To Vector 2D (Float)');
    expect([for (final p in LuminaBlueprintNodeLibrary.builtIn('string_to_int')!.outputs) (p.id, p.type)],
        [('return_value', LuminaPinType.integer), ('success', LuminaPinType.boolean)]);
    expect([for (final p in LuminaBlueprintNodeLibrary.builtIn('string_to_float')!.outputs) (p.id, p.type)],
        [('return_value', LuminaPinType.float), ('success', LuminaPinType.boolean)]);
  });

  test('conversionNodeFor names the node the editor inserts; connectionError stays strict', () {
    final i2f = LuminaBlueprintNodeLibrary.conversionNodeFor(LuminaPinType.integer, LuminaPinType.float)!;
    expect((i2f.nodeId, i2f.inputPin, i2f.outputPin, i2f.lossy), ('int_to_float', 'a', 'return_value', false));
    final f2i = LuminaBlueprintNodeLibrary.conversionNodeFor(LuminaPinType.float, LuminaPinType.integer)!;
    expect((f2i.nodeId, f2i.inputPin, f2i.outputPin, f2i.lossy), ('truncate', 'a', 'return_value', true));
    expect(f2i.hint, contains('fraction'));
    final expected = {
      (LuminaPinType.boolean, LuminaPinType.integer): ('bool_to_int', 'in_bool'),
      (LuminaPinType.boolean, LuminaPinType.float): ('bool_to_float', 'in_bool'),
      (LuminaPinType.integer, LuminaPinType.string): ('int_to_string', 'in_int'),
      (LuminaPinType.float, LuminaPinType.string): ('float_to_string', 'in_float'),
      (LuminaPinType.boolean, LuminaPinType.string): ('bool_to_string', 'in_bool'),
      (LuminaPinType.name, LuminaPinType.string): ('name_to_string', 'in_name'),
      (LuminaPinType.vector, LuminaPinType.string): ('vector_to_string', 'in_vec'),
      (LuminaPinType.rotator, LuminaPinType.string): ('rotator_to_string', 'in_rot'),
      (LuminaPinType.string, LuminaPinType.name): ('string_to_name', 'in_string'),
    };
    for (final e in expected.entries) {
      final c = LuminaBlueprintNodeLibrary.conversionNodeFor(e.key.$1, e.key.$2);
      expect(c, isNotNull, reason: '${e.key}');
      expect((c!.nodeId, c.inputPin, c.outputPin, c.lossy), (e.value.$1, e.value.$2, 'return_value', false), reason: '${e.key}');
      // The named pins exist and carry the two types.
      final spec = LuminaBlueprintNodeLibrary.builtIn(c.nodeId)!;
      expect(spec.inputs.singleWhere((p) => p.id == c.inputPin).type, e.key.$1);
      expect(spec.outputs.singleWhere((p) => p.id == c.outputPin).type, e.key.$2);
    }
    for (final (from, to) in [
      (LuminaPinType.string, LuminaPinType.integer),
      (LuminaPinType.string, LuminaPinType.float),
      (LuminaPinType.float, LuminaPinType.boolean),
      (LuminaPinType.vector, LuminaPinType.float),
      (LuminaPinType.object, LuminaPinType.string),
      (LuminaPinType.exec, LuminaPinType.float),
      (LuminaPinType.wildcard, LuminaPinType.float),
      (LuminaPinType.integer, LuminaPinType.integer),
    ]) {
      expect(LuminaBlueprintNodeLibrary.conversionNodeFor(from, to), isNull, reason: '$from → $to');
    }
    expect(
      LuminaBlueprintNodeLibrary.connectionError(
          const LuminaBlueprintPinSpec('o', 'O', LuminaPinType.integer), const LuminaBlueprintPinSpec('i', 'I', LuminaPinType.float)),
      'Cannot connect integer to float.',
    );
  });

  LuminaBlueprintRuntime instantiate(LuminaBlueprintDocument doc, List<LuminaBlueprintTraceEvent> trace) {
    final actor = LuminaBlueprintClass.fromDocument(doc, name: 'bp_conversions').instantiate();
    (actor as LuminaBlueprintRuntime).trace = trace.add;
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    return actor;
  }

  test('a Blueprint of every conversion prints the documented values in the VM', () {
    final doc = conversionsBlueprint();
    final diagnostics = validateBlueprint(doc, className: 'bp_conversions');
    expect(diagnostics.where((d) => d.isError), isEmpty, reason: '$diagnostics');
    final trace = <LuminaBlueprintTraceEvent>[];
    instantiate(doc, trace);
    expect([for (final t in trace) if (t.printed != null) t.printed], conversionsBlueprintPrints);
  });

  test('an older String to Int saved without the Success pin loads and runs unchanged', () {
    final json = jsonDecode(jsonEncode(conversionsBlueprint().toJson())) as Map<String, dynamic>;
    var stripped = 0;
    for (final graph in [json['eventGraph'] as Map<String, dynamic>]) {
      for (final node in (graph['nodes'] as List).cast<Map<String, dynamic>>()) {
        if (node['registryId'] == 'string_to_int') {
          (node['outputs'] as List).removeWhere((p) => (p as Map)['id'] == 'success');
          node['category'] = 'Utilities|String';
          stripped++;
        }
      }
      // An older graph never wired Success.
      (graph['connections'] as List).removeWhere((w) => (w as Map)['fromNodeId'] == 's2i' && w['fromPinId'] == 'success');
      const gone = {'s2i_ok_text', 'say_s2i_ok'};
      (graph['nodes'] as List).removeWhere((n) => gone.contains((n as Map)['id']));
      for (final w in (graph['connections'] as List).cast<Map<String, dynamic>>()) {
        if (w['fromNodeId'] == 'say_s2i' && w['fromPinId'] == 'exec_out') w['toNodeId'] = 'say_s2f_ok';
      }
      (graph['connections'] as List)
          .removeWhere((w) => gone.contains((w as Map)['fromNodeId']) || gone.contains(w['toNodeId']));
    }
    expect(stripped, 2);
    final trace = <LuminaBlueprintTraceEvent>[];
    instantiate(LuminaBlueprintDocument.fromJson(json), trace);
    expect([for (final t in trace) if (t.printed != null) t.printed], [
      for (final p in conversionsBlueprintPrints.indexed)
        if (p.$1 != 9) p.$2,
    ]);
  });
}
