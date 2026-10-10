part of '../blueprint_dart_generator.dart';

/// The flow-control macros of [_GraphCompiler]: Do Once, Gate, loops,
/// Multi Gate and the rest, entered through their Enter or side pins.
extension _GraphCompilerFlow on _GraphCompiler {
  /// A flow macro entered through a side pin: Break, Reset, Open, Close, Toggle.
  void _flowSide(_Frame frame, LuminaBlueprintNode node, String inPin, List<String> out, String pad,
      String Function(String values) flowTrace, String Function(String pin) input) {
    final id = node.id;
    switch (node.registryId) {
      case 'for_loop':
      case 'for_loop_with_break':
        if (inPin == 'break') out.add('$pad${_breakFlag(frame, id)} = true;');
      case 'do_once':
        if (inPin == 'reset') {
          out.add('$pad${_stateField(id, 'bool')} = false;');
          out.add(flowTrace("{'fired': false}"));
        }
      case 'do_n':
        if (inPin == 'reset') {
          out.add('$pad${_stateField(id, 'int')} = 0;');
          out.add(flowTrace("{'counter': 0}"));
        }
      case 'multi_gate':
        if (inPin == 'reset') {
          out.add('$pad${_stateField(id, 'List<int>')} = null;');
          out.add(flowTrace("{'index': -1}"));
        }
      case 'gate':
        final field = _stateField(id, 'bool');
        final startClosed = input('start_closed');
        final value = switch (inPin) {
          'open' => 'true',
          'close' => 'false',
          _ => '!($field ?? !($startClosed))',
        };
        out.add('$pad$field = $value;');
        out.add(flowTrace("{'is_open': $field, 'pin': ${_str(inPin)}}"));
    }
  }

  String _breakFlag(_Frame frame, String nodeId) {
    final name = 'brk${_cap(_id(nodeId))}';
    if (!frame.declarations.contains('bool $name = false;')) frame.declarations.add('bool $name = false;');
    return name;
  }

  /// A flow macro entered through its Enter pin, written as Dart control
  /// flow that traces exactly what the VM traces.
  void _flowEnter(_Frame frame, LuminaBlueprintNode node, List<String> out, int indent, Set<String> here,
      Map<String, Map<String, String>> step, String Function(String values) flowTrace, String Function(String pin) input) {
    final id = node.id;
    final pad = '  ' * indent;
    final nodePins = pins[node.id]!;
    List<String> chain(String pin, [int extra = 1]) {
      final body = <String>[];
      _chain(frame, id, pin, body, indent + extra, here);
      return body;
    }

    switch (node.registryId) {
      case 'do_once':
        final field = _stateField(id, 'bool');
        final startClosed = input('start_closed');
        final done = 'd${_counter.next()}';
        out.add('${pad}final $done = $field ?? ($startClosed);');
        out.add(flowTrace("{'fired': !$done}"));
        out.add('${pad}if (!$done) {');
        out.add('$pad  $field = true;');
        out.addAll(chain('completed'));
        out.add('$pad}');
      case 'flip_flop':
        final field = _stateField(id, 'bool');
        final isA = 'f${_counter.next()}';
        out.add('${pad}final $isA = $field ?? true;');
        out.add('$pad$field = !$isA;');
        out.add('$pad${_impureVar(frame, id, 'is_a', LuminaPinType.boolean)} = $isA;');
        out.add(flowTrace("{'is_a': $isA}"));
        final a = chain('a');
        final b = chain('b');
        if (a.isEmpty && b.isEmpty) break;
        out.add('${pad}if (${a.isEmpty ? '!$isA' : isA}) {');
        out.addAll(a.isEmpty ? b : a);
        if (a.isNotEmpty && b.isNotEmpty) {
          out.add('$pad} else {');
          out.addAll(b);
        }
        out.add('$pad}');
      case 'gate':
        final field = _stateField(id, 'bool');
        final startClosed = input('start_closed');
        final open = 'g${_counter.next()}';
        out.add('${pad}final $open = $field ?? !($startClosed);');
        out.add('$pad$field = $open;');
        out.add(flowTrace("{'is_open': $open, 'pin': 'exec_in'}"));
        final exit = chain('exit');
        if (exit.isEmpty) break;
        out.add('${pad}if ($open) {');
        out.addAll(exit);
        out.add('$pad}');
      case 'do_n':
        final field = _stateField(id, 'int');
        final n = input('n');
        final count = 'c${_counter.next()}';
        out.add('${pad}final $count = $field ?? 0;');
        out.add('${pad}if ($count >= $n) {');
        out.add('  ${flowTrace("{'n': $n, 'counter': $count}")}');
        out.add('$pad} else {');
        out.add('$pad  $field = $count + 1;');
        out.add('$pad  ${_impureVar(frame, id, 'counter', LuminaPinType.integer)} = $count + 1;');
        out.add('  ${flowTrace("{'n': $n, 'counter': $count + 1}")}');
        out.addAll(chain('exit'));
        out.add('$pad}');
      case 'for_loop':
      case 'for_loop_with_break':
        final first = input('first_index');
        final last = input('last_index');
        final brk = _breakFlag(frame, id);
        final i = 'i${_counter.next()}';
        final lastVar = 'l${_counter.next()}';
        out.add('${pad}final $lastVar = $last;');
        out.add('$pad$brk = false;');
        out.add(flowTrace("{'first_index': $first, 'last_index': $lastVar}"));
        out.add('${pad}for (var $i = $first;; $i++) {');
        out.add('$pad  if ($i > $lastVar || $brk) break;');
        out.add('$pad  ${_impureVar(frame, id, 'index', LuminaPinType.integer)} = $i;');
        out.add('  ${flowTrace("{'index': $i}")}');
        out.addAll(chain('loop_body'));
        out.add('$pad}');
        out.add('$pad$brk = false;');
        out.addAll(chain('completed', 0));
      case 'while_loop':
        final n = 'n${_counter.next()}';
        out.add(flowTrace('{}'));
        out.add('${pad}var $n = 0;');
        out.add('${pad}while (true) {');
        final condStep = <String, Map<String, String>>{};
        final cond = _input(frame, node, 'condition', condStep, out, '$pad  ');
        out.add('$pad  if (!$cond) {');
        out.add('    ${flowTrace("{'condition': false, 'iterations': $n}")}');
        out.add('$pad    break;');
        out.add('$pad  }');
        out.add('$pad  if ($n >= LuminaBlueprintNodeLibrary.whileLoopCap) {');
        out.add('$pad    LuminaBlueprintFunctionLibrary.whileLoopCapped(blueprintClassName, ${_str(id)});');
        out.add('    ${flowTrace("{'condition': true, 'iterations': $n, 'capped': true}")}');
        out.add('$pad    break;');
        out.add('$pad  }');
        out.add('  ${flowTrace("{'condition': true, 'iterations': $n}")}');
        out.add('$pad  $n++;');
        out.addAll(chain('loop_body'));
        out.add('$pad}');
        out.addAll(chain('completed', 0));
      case 'for_each_loop':
        final array = input('array');
        final arr = 'a${_counter.next()}';
        final items = 'e${_counter.next()}';
        final i = 'i${_counter.next()}';
        out.add('${pad}final $arr = $array;');
        out.add('${pad}final $items = LuminaBlueprintFunctionLibrary.arrayItems($arr);');
        out.add(flowTrace("{'array': $arr}"));
        out.add('${pad}for (var $i = 0; $i < $items.length; $i++) {');
        out.add('$pad  ${_impureVar(frame, id, 'array_element', LuminaPinType.wildcard)} = $items[$i];');
        out.add('$pad  ${_impureVar(frame, id, 'array_index', LuminaPinType.integer)} = $i;');
        out.add('  ${flowTrace("{'array_element': $items[$i], 'array_index': $i}")}');
        out.addAll(chain('loop_body'));
        out.add('$pad}');
        out.addAll(chain('completed', 0));
      case 'retriggerable_delay':
        final duration = input('duration');
        final resume = '_resume${_cap(_id(id))}From${_cap(frame.methodSuffix)}';
        out.add(flowTrace("{'duration': $duration}"));
        out.add('${pad}blueprintRetriggerableDelay(${_str(id)}, $duration, () => $resume(${frame.args}));');
        if (_resumeMethods.add(resume)) {
          final next = _Frame(frame.eventNodeId, frame.methodSuffix, frame.eventOutputs, frame.params, frame.args,
              traceId: frame.traceId);
          methods.add(_eventMethodAfter(resume, next, node));
        }
      case 'switch_on_int':
      case 'switch_on_string':
      case 'switch_on_name':
        final selection = input('selection');
        final sel = 's${_counter.next()}';
        out.add('${pad}final $sel = $selection;');
        out.add(flowTrace("{'selection': $sel}"));
        final cases = node.literals['cases'];
        final list = cases is List ? cases : const [];
        final seen = <String>{};
        var opened = false;
        for (var c = 0; c < list.length; c++) {
          final value = list[c];
          final literal = node.registryId == 'switch_on_int'
              ? '${value is num ? value.toInt() : int.tryParse('$value') ?? 0}'
              : _str('$value');
          if (!seen.add(literal)) continue;
          final body = chain('case_$c');
          if (body.isEmpty) continue;
          out.add('$pad${opened ? '} else ' : ''}if ($sel == $literal) {');
          out.addAll(body);
          opened = true;
        }
        final fallback = chain('default');
        if (fallback.isNotEmpty) {
          if (opened) {
            out.add('$pad} else {');
            out.addAll(fallback);
          } else {
            final none = seen.isEmpty ? 'true' : seen.map((l) => '$sel != $l').join(' && ');
            out.add('${pad}if ($none) {');
            out.addAll(fallback);
          }
          opened = true;
        }
        if (opened) out.add('$pad}');
      case 'switch_on_bool':
        final selection = input('selection');
        final sel = 's${_counter.next()}';
        out.add('${pad}final $sel = $selection;');
        out.add(flowTrace("{'selection': $sel}"));
        final whenTrue = chain('true_out');
        final whenFalse = chain('false_out');
        if (whenTrue.isEmpty && whenFalse.isEmpty) break;
        out.add('${pad}if (${whenTrue.isEmpty ? '!$sel' : sel}) {');
        out.addAll(whenTrue.isEmpty ? whenFalse : whenTrue);
        if (whenTrue.isNotEmpty && whenFalse.isNotEmpty) {
          out.add('$pad} else {');
          out.addAll(whenFalse);
        }
        out.add('$pad}');
      case 'multi_gate':
        final field = _stateField(id, 'List<int>');
        final outs = nodePins.outputs.where((p) => p.type == LuminaPinType.exec).map((p) => p.id).toList();
        final isRandom = input('is_random');
        final loop = input('loop');
        final startIndex = input('start_index');
        final r = 'm${_counter.next()}';
        out.add('${pad}final $r = LuminaBlueprintFunctionLibrary.multiGateNext($field, ${outs.length}, $isRandom, $loop, $startIndex);');
        out.add('$pad$field = $r.used;');
        out.add(flowTrace("{'index': $r.index}"));
        var opened = false;
        for (var i = 0; i < outs.length; i++) {
          final body = chain(outs[i]);
          if (body.isEmpty) continue;
          out.add('$pad${opened ? '} else ' : ''}if ($r.index == $i) {');
          out.addAll(body);
          opened = true;
        }
        if (opened) out.add('$pad}');
    }
  }
}
