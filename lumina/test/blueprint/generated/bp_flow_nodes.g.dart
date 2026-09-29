// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_flow_nodes.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpFlowNodes extends LuminaActor with LuminaBlueprintRuntime {
  BpFlowNodes({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_flow_nodes';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
  ];

  int ticks = 0;
  int n = 0;
  List<Object?> log = <Object?>[];
  String key_ = 'b';

  // Flow-control state (DoOnce, FlipFlop, Gate, DoN, MultiGate), reset at BeginPlay.
  bool? _flowOnce;
  bool? _flowFf;
  int? _flowDo_n;
  bool? _flowGate;
  List<int>? _flowMg;

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _flowOnce = null;
    _flowFf = null;
    _flowDo_n = null;
    _flowGate = null;
    _flowMg = null;
    _onBegin();
  }

  @override
  void onTick(double deltaSeconds) {
    super.onTick(deltaSeconds);
    advanceBlueprintLatent(deltaSeconds);
    _onTick(deltaSeconds);
  }

  /// Event BeginPlay (node begin).
  void _onBegin() {
    bool brkLoop = false;
    int? oloop_index;
    bool brkBrk_loop = false;
    int? obrk_loop_index;
    int? oset_n_value;
    Object? oeach_array_element;
    int? oeach_array_index;
    final l1 = 2;
    brkLoop = false;
    if (trace != null) blueprintTrace('begin', 'loop', 'for_loop', {'first_index': 0, 'last_index': l1});
    for (var i0 = 0;; i0++) {
      if (i0 > l1 || brkLoop) break;
      oloop_index = i0;
      if (trace != null) blueprintTrace('begin', 'loop', 'for_loop', {'index': i0});
      final p2 = LuminaBlueprintFunctionLibrary.intToString((oloop_index ?? 0));
      if (trace != null) blueprintTrace('begin', 'idx_text', 'int_to_string', {'in_int': (oloop_index ?? 0), 'return_value': p2});
      LuminaBlueprintFunctionLibrary.printString(this, p2, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'body', 'print_string', {'in_string': p2, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p2);
    }
    brkLoop = false;
    final l4 = 9;
    brkBrk_loop = false;
    if (trace != null) blueprintTrace('begin', 'brk_loop', 'for_loop_with_break', {'first_index': 0, 'last_index': l4});
    for (var i3 = 0;; i3++) {
      if (i3 > l4 || brkBrk_loop) break;
      obrk_loop_index = i3;
      if (trace != null) blueprintTrace('begin', 'brk_loop', 'for_loop_with_break', {'index': i3});
      final p5 = LuminaBlueprintFunctionLibrary.intEqual((obrk_loop_index ?? 0), 1);
      if (trace != null) blueprintTrace('begin', 'is_one', 'int_equal', {'a': (obrk_loop_index ?? 0), 'b': 1, 'return_value': p5});
      if (trace != null) blueprintTrace('begin', 'if_one', 'branch', {'condition': p5});
      if (p5) {
        brkBrk_loop = true;
      } else {
        final p6 = LuminaBlueprintFunctionLibrary.intToString((obrk_loop_index ?? 0));
        if (trace != null) blueprintTrace('begin', 'bidx_text', 'int_to_string', {'in_int': (obrk_loop_index ?? 0), 'return_value': p6});
        LuminaBlueprintFunctionLibrary.printString(this, p6, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
        if (trace != null) blueprintTrace('begin', 'bbody', 'print_string', {'in_string': p6, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p6);
      }
    }
    brkBrk_loop = false;
    if (trace != null) blueprintTrace('begin', 'count', 'while_loop', {});
    var n7 = 0;
    while (true) {
      final p8 = n;
      if (trace != null) blueprintTrace('begin', 'n', 'variable_get', {'value': p8});
      final p9 = LuminaBlueprintFunctionLibrary.intLess(p8, 3);
      if (trace != null) blueprintTrace('begin', 'lt', 'int_less', {'a': p8, 'b': 3, 'return_value': p9});
      if (!p9) {
        if (trace != null) blueprintTrace('begin', 'count', 'while_loop', {'condition': false, 'iterations': n7});
        break;
      }
      if (n7 >= LuminaBlueprintNodeLibrary.whileLoopCap) {
        LuminaBlueprintFunctionLibrary.whileLoopCapped(blueprintClassName, 'count');
        if (trace != null) blueprintTrace('begin', 'count', 'while_loop', {'condition': true, 'iterations': n7, 'capped': true});
        break;
      }
      if (trace != null) blueprintTrace('begin', 'count', 'while_loop', {'condition': true, 'iterations': n7});
      n7++;
      final p10 = n;
      if (trace != null) blueprintTrace('begin', 'n', 'variable_get', {'value': p10});
      final p11 = LuminaBlueprintFunctionLibrary.intIncrement(p10);
      if (trace != null) blueprintTrace('begin', 'inc', 'int_increment', {'a': p10, 'return_value': p11});
      n = p11;
      oset_n_value = p11;
      if (trace != null) blueprintTrace('begin', 'set_n', 'variable_set', {'value': p11});
    }
    final p12 = LuminaBlueprintFunctionLibrary.makeArray(['a', 'b', 'c']);
    if (trace != null) blueprintTrace('begin', 'names', 'make_array', {'item_0': 'a', 'item_1': 'b', 'item_2': 'c', 'return_value': p12});
    final a13 = p12;
    final e14 = LuminaBlueprintFunctionLibrary.arrayItems(a13);
    if (trace != null) blueprintTrace('begin', 'each', 'for_each_loop', {'array': a13});
    for (var i15 = 0; i15 < e14.length; i15++) {
      oeach_array_element = e14[i15];
      oeach_array_index = i15;
      if (trace != null) blueprintTrace('begin', 'each', 'for_each_loop', {'array_element': e14[i15], 'array_index': i15});
      final p16 = LuminaBlueprintFunctionLibrary.intToString((oeach_array_index ?? 0));
      if (trace != null) blueprintTrace('begin', 'each_idx', 'int_to_string', {'in_int': (oeach_array_index ?? 0), 'return_value': p16});
      final t17 = (oeach_array_element ?? '') as String;
      final p18 = LuminaBlueprintFunctionLibrary.append3(p16, ':', t17);
      if (trace != null) blueprintTrace('begin', 'label', 'append_3', {'a': p16, 'b': ':', 'c': t17, 'return_value': p18});
      LuminaBlueprintFunctionLibrary.printString(this, p18, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'each_body', 'print_string', {'in_string': p18, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p18);
    }
    final p19 = key_;
    if (trace != null) blueprintTrace('begin', 'key', 'variable_get', {'value': p19});
    final s20 = p19;
    if (trace != null) blueprintTrace('begin', 'sw', 'switch_on_string', {'selection': s20});
    if (s20 == 'a') {
      LuminaBlueprintFunctionLibrary.printString(this, 'case a', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'sa', 'print_string', {'in_string': 'case a', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'case a');
    } else if (s20 == 'b') {
      LuminaBlueprintFunctionLibrary.printString(this, 'case b', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'sb', 'print_string', {'in_string': 'case b', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'case b');
      final s21 = 5;
      if (trace != null) blueprintTrace('begin', 'swi', 'switch_on_int', {'selection': s21});
      if (s21 == 1) {
        LuminaBlueprintFunctionLibrary.printString(this, 'one', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
        if (trace != null) blueprintTrace('begin', 'i1', 'print_string', {'in_string': 'one', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'one');
      } else {
        LuminaBlueprintFunctionLibrary.printString(this, 'int default', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
        if (trace != null) blueprintTrace('begin', 'idef', 'print_string', {'in_string': 'int default', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'int default');
        final s22 = false;
        if (trace != null) blueprintTrace('begin', 'swb', 'switch_on_bool', {'selection': s22});
        if (!s22) {
          LuminaBlueprintFunctionLibrary.printString(this, 'no', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
          if (trace != null) blueprintTrace('begin', 'bf', 'print_string', {'in_string': 'no', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'no');
          if (trace != null) blueprintTrace('begin', 'twice', 'sequence', {});
          final d23 = _flowOnce ?? (false);
          if (trace != null) blueprintTrace('begin', 'once', 'do_once', {'fired': !d23});
          if (!d23) {
            _flowOnce = true;
            LuminaBlueprintFunctionLibrary.printString(this, 'once', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
            if (trace != null) blueprintTrace('begin', 'p_once', 'print_string', {'in_string': 'once', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'once');
          }
          final d24 = _flowOnce ?? (false);
          if (trace != null) blueprintTrace('begin', 'once', 'do_once', {'fired': !d24});
          if (!d24) {
            _flowOnce = true;
            LuminaBlueprintFunctionLibrary.printString(this, 'once', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
            if (trace != null) blueprintTrace('begin', 'p_once', 'print_string', {'in_string': 'once', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'once');
          }
        }
      }
    } else {
      LuminaBlueprintFunctionLibrary.printString(this, 'default', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'sd', 'print_string', {'in_string': 'default', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'default');
    }
  }

  /// Event Tick (node tick).
  void _onTick(double deltaSeconds) {
    bool? off_is_a;
    int? odo_n_counter;
    int? oadd_return_value;
    final f25 = _flowFf ?? true;
    _flowFf = !f25;
    off_is_a = f25;
    if (trace != null) blueprintTrace('tick', 'ff', 'flip_flop', {'is_a': f25});
    if (f25) {
      LuminaBlueprintFunctionLibrary.printString(this, 'A', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('tick', 'p_a', 'print_string', {'in_string': 'A', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'A');
      final c26 = _flowDo_n ?? 0;
      if (c26 >= 3) {
        if (trace != null) blueprintTrace('tick', 'do_n', 'do_n', {'n': 3, 'counter': c26});
      } else {
        _flowDo_n = c26 + 1;
        odo_n_counter = c26 + 1;
        if (trace != null) blueprintTrace('tick', 'do_n', 'do_n', {'n': 3, 'counter': c26 + 1});
        final p27 = LuminaBlueprintFunctionLibrary.intToString((odo_n_counter ?? 0));
        if (trace != null) blueprintTrace('tick', 'count_text', 'int_to_string', {'in_int': (odo_n_counter ?? 0), 'return_value': p27});
        LuminaBlueprintFunctionLibrary.printString(this, p27, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
        if (trace != null) blueprintTrace('tick', 'counted', 'print_string', {'in_string': p27, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p27);
        if (trace != null) blueprintTrace('tick', 'gate_seq', 'sequence', {});
        final g28 = _flowGate ?? !(false);
        _flowGate = g28;
        if (trace != null) blueprintTrace('tick', 'gate', 'gate', {'is_open': g28, 'pin': 'exec_in'});
        if (g28) {
          LuminaBlueprintFunctionLibrary.printString(this, 'through', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
          if (trace != null) blueprintTrace('tick', 'through', 'print_string', {'in_string': 'through', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'through');
          final m29 = LuminaBlueprintFunctionLibrary.multiGateNext(_flowMg, 2, false, true, -1);
          _flowMg = m29.used;
          if (trace != null) blueprintTrace('tick', 'mg', 'multi_gate', {'index': m29.index});
          if (m29.index == 0) {
            LuminaBlueprintFunctionLibrary.printString(this, 'out 0', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
            if (trace != null) blueprintTrace('tick', 'm0', 'print_string', {'in_string': 'out 0', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'out 0');
            final p30 = LuminaBlueprintFunctionLibrary.floatDivide(1.0, deltaSeconds);
            if (trace != null) blueprintTrace('tick', 'fps', 'float_divide', {'a': 1.0, 'b': deltaSeconds, 'return_value': p30});
            final p31 = LuminaBlueprintFunctionLibrary.round(p30);
            if (trace != null) blueprintTrace('tick', 'fps_round', 'round', {'a': p30, 'return_value': p31});
            final p32 = LuminaBlueprintFunctionLibrary.intToString(p31);
            if (trace != null) blueprintTrace('tick', 'fps_text', 'int_to_string', {'in_int': p31, 'return_value': p32});
            final p33 = LuminaBlueprintFunctionLibrary.formatString('FPS: {0}', p32, '', '', '');
            if (trace != null) blueprintTrace('tick', 'fps_label', 'format_string', {'format': 'FPS: {0}', 'arg_0': p32, 'arg_1': '', 'arg_2': '', 'arg_3': '', 'return_value': p33});
            LuminaBlueprintFunctionLibrary.printString(this, p33, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
            if (trace != null) blueprintTrace('tick', 'say_fps', 'print_string', {'in_string': p33, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p33);
            final p34 = log;
            if (trace != null) blueprintTrace('tick', 'log', 'variable_get', {'value': p34});
            final p35 = LuminaBlueprintFunctionLibrary.floatDivide(1.0, deltaSeconds);
            if (trace != null) blueprintTrace('tick', 'fps', 'float_divide', {'a': 1.0, 'b': deltaSeconds, 'return_value': p35});
            final p36 = LuminaBlueprintFunctionLibrary.round(p35);
            if (trace != null) blueprintTrace('tick', 'fps_round', 'round', {'a': p35, 'return_value': p36});
            final p37 = LuminaBlueprintFunctionLibrary.intToString(p36);
            if (trace != null) blueprintTrace('tick', 'fps_text', 'int_to_string', {'in_int': p36, 'return_value': p37});
            final p38 = LuminaBlueprintFunctionLibrary.formatString('FPS: {0}', p37, '', '', '');
            if (trace != null) blueprintTrace('tick', 'fps_label', 'format_string', {'format': 'FPS: {0}', 'arg_0': p37, 'arg_1': '', 'arg_2': '', 'arg_3': '', 'return_value': p38});
            final r39 = LuminaBlueprintFunctionLibrary.arrayAdd(p34, p38);
            oadd_return_value = r39;
            if (trace != null) blueprintTrace('tick', 'add', 'array_add', {'target_array': p34, 'new_item': p38, 'return_value': r39});
            final p40 = log;
            if (trace != null) blueprintTrace('tick', 'log', 'variable_get', {'value': p40});
            final p41 = LuminaBlueprintFunctionLibrary.arrayLength(p40);
            if (trace != null) blueprintTrace('tick', 'len', 'array_length', {'target_array': p40, 'return_value': p41});
            final p42 = LuminaBlueprintFunctionLibrary.intToString(p41);
            if (trace != null) blueprintTrace('tick', 'len_text', 'int_to_string', {'in_int': p41, 'return_value': p42});
            LuminaBlueprintFunctionLibrary.printString(this, p42, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
            if (trace != null) blueprintTrace('tick', 'say_len', 'print_string', {'in_string': p42, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p42);
            if (trace != null) blueprintTrace('tick', 'wait', 'retriggerable_delay', {'duration': 0.05});
            blueprintRetriggerableDelay('wait', 0.05, () => _resumeWaitFromTick(deltaSeconds));
          } else if (m29.index == 1) {
            LuminaBlueprintFunctionLibrary.printString(this, 'out 1', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
            if (trace != null) blueprintTrace('tick', 'm1', 'print_string', {'in_string': 'out 1', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'out 1');
            final p43 = LuminaBlueprintFunctionLibrary.floatDivide(1.0, deltaSeconds);
            if (trace != null) blueprintTrace('tick', 'fps', 'float_divide', {'a': 1.0, 'b': deltaSeconds, 'return_value': p43});
            final p44 = LuminaBlueprintFunctionLibrary.round(p43);
            if (trace != null) blueprintTrace('tick', 'fps_round', 'round', {'a': p43, 'return_value': p44});
            final p45 = LuminaBlueprintFunctionLibrary.intToString(p44);
            if (trace != null) blueprintTrace('tick', 'fps_text', 'int_to_string', {'in_int': p44, 'return_value': p45});
            final p46 = LuminaBlueprintFunctionLibrary.formatString('FPS: {0}', p45, '', '', '');
            if (trace != null) blueprintTrace('tick', 'fps_label', 'format_string', {'format': 'FPS: {0}', 'arg_0': p45, 'arg_1': '', 'arg_2': '', 'arg_3': '', 'return_value': p46});
            LuminaBlueprintFunctionLibrary.printString(this, p46, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
            if (trace != null) blueprintTrace('tick', 'say_fps', 'print_string', {'in_string': p46, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p46);
            final p47 = log;
            if (trace != null) blueprintTrace('tick', 'log', 'variable_get', {'value': p47});
            final p48 = LuminaBlueprintFunctionLibrary.floatDivide(1.0, deltaSeconds);
            if (trace != null) blueprintTrace('tick', 'fps', 'float_divide', {'a': 1.0, 'b': deltaSeconds, 'return_value': p48});
            final p49 = LuminaBlueprintFunctionLibrary.round(p48);
            if (trace != null) blueprintTrace('tick', 'fps_round', 'round', {'a': p48, 'return_value': p49});
            final p50 = LuminaBlueprintFunctionLibrary.intToString(p49);
            if (trace != null) blueprintTrace('tick', 'fps_text', 'int_to_string', {'in_int': p49, 'return_value': p50});
            final p51 = LuminaBlueprintFunctionLibrary.formatString('FPS: {0}', p50, '', '', '');
            if (trace != null) blueprintTrace('tick', 'fps_label', 'format_string', {'format': 'FPS: {0}', 'arg_0': p50, 'arg_1': '', 'arg_2': '', 'arg_3': '', 'return_value': p51});
            final r52 = LuminaBlueprintFunctionLibrary.arrayAdd(p47, p51);
            oadd_return_value = r52;
            if (trace != null) blueprintTrace('tick', 'add', 'array_add', {'target_array': p47, 'new_item': p51, 'return_value': r52});
            final p53 = log;
            if (trace != null) blueprintTrace('tick', 'log', 'variable_get', {'value': p53});
            final p54 = LuminaBlueprintFunctionLibrary.arrayLength(p53);
            if (trace != null) blueprintTrace('tick', 'len', 'array_length', {'target_array': p53, 'return_value': p54});
            final p55 = LuminaBlueprintFunctionLibrary.intToString(p54);
            if (trace != null) blueprintTrace('tick', 'len_text', 'int_to_string', {'in_int': p54, 'return_value': p55});
            LuminaBlueprintFunctionLibrary.printString(this, p55, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
            if (trace != null) blueprintTrace('tick', 'say_len', 'print_string', {'in_string': p55, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p55);
            if (trace != null) blueprintTrace('tick', 'wait', 'retriggerable_delay', {'duration': 0.05});
            blueprintRetriggerableDelay('wait', 0.05, () => _resumeWaitFromTick(deltaSeconds));
          }
        }
        _flowGate = !(_flowGate ?? !(false));
        if (trace != null) blueprintTrace('tick', 'gate', 'gate', {'is_open': _flowGate, 'pin': 'toggle'});
      }
    } else {
      LuminaBlueprintFunctionLibrary.printString(this, 'B', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('tick', 'p_b', 'print_string', {'in_string': 'B', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'B');
      final c56 = _flowDo_n ?? 0;
      if (c56 >= 3) {
        if (trace != null) blueprintTrace('tick', 'do_n', 'do_n', {'n': 3, 'counter': c56});
      } else {
        _flowDo_n = c56 + 1;
        odo_n_counter = c56 + 1;
        if (trace != null) blueprintTrace('tick', 'do_n', 'do_n', {'n': 3, 'counter': c56 + 1});
        final p57 = LuminaBlueprintFunctionLibrary.intToString((odo_n_counter ?? 0));
        if (trace != null) blueprintTrace('tick', 'count_text', 'int_to_string', {'in_int': (odo_n_counter ?? 0), 'return_value': p57});
        LuminaBlueprintFunctionLibrary.printString(this, p57, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
        if (trace != null) blueprintTrace('tick', 'counted', 'print_string', {'in_string': p57, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p57);
        if (trace != null) blueprintTrace('tick', 'gate_seq', 'sequence', {});
        final g58 = _flowGate ?? !(false);
        _flowGate = g58;
        if (trace != null) blueprintTrace('tick', 'gate', 'gate', {'is_open': g58, 'pin': 'exec_in'});
        if (g58) {
          LuminaBlueprintFunctionLibrary.printString(this, 'through', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
          if (trace != null) blueprintTrace('tick', 'through', 'print_string', {'in_string': 'through', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'through');
          final m59 = LuminaBlueprintFunctionLibrary.multiGateNext(_flowMg, 2, false, true, -1);
          _flowMg = m59.used;
          if (trace != null) blueprintTrace('tick', 'mg', 'multi_gate', {'index': m59.index});
          if (m59.index == 0) {
            LuminaBlueprintFunctionLibrary.printString(this, 'out 0', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
            if (trace != null) blueprintTrace('tick', 'm0', 'print_string', {'in_string': 'out 0', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'out 0');
            final p60 = LuminaBlueprintFunctionLibrary.floatDivide(1.0, deltaSeconds);
            if (trace != null) blueprintTrace('tick', 'fps', 'float_divide', {'a': 1.0, 'b': deltaSeconds, 'return_value': p60});
            final p61 = LuminaBlueprintFunctionLibrary.round(p60);
            if (trace != null) blueprintTrace('tick', 'fps_round', 'round', {'a': p60, 'return_value': p61});
            final p62 = LuminaBlueprintFunctionLibrary.intToString(p61);
            if (trace != null) blueprintTrace('tick', 'fps_text', 'int_to_string', {'in_int': p61, 'return_value': p62});
            final p63 = LuminaBlueprintFunctionLibrary.formatString('FPS: {0}', p62, '', '', '');
            if (trace != null) blueprintTrace('tick', 'fps_label', 'format_string', {'format': 'FPS: {0}', 'arg_0': p62, 'arg_1': '', 'arg_2': '', 'arg_3': '', 'return_value': p63});
            LuminaBlueprintFunctionLibrary.printString(this, p63, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
            if (trace != null) blueprintTrace('tick', 'say_fps', 'print_string', {'in_string': p63, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p63);
            final p64 = log;
            if (trace != null) blueprintTrace('tick', 'log', 'variable_get', {'value': p64});
            final p65 = LuminaBlueprintFunctionLibrary.floatDivide(1.0, deltaSeconds);
            if (trace != null) blueprintTrace('tick', 'fps', 'float_divide', {'a': 1.0, 'b': deltaSeconds, 'return_value': p65});
            final p66 = LuminaBlueprintFunctionLibrary.round(p65);
            if (trace != null) blueprintTrace('tick', 'fps_round', 'round', {'a': p65, 'return_value': p66});
            final p67 = LuminaBlueprintFunctionLibrary.intToString(p66);
            if (trace != null) blueprintTrace('tick', 'fps_text', 'int_to_string', {'in_int': p66, 'return_value': p67});
            final p68 = LuminaBlueprintFunctionLibrary.formatString('FPS: {0}', p67, '', '', '');
            if (trace != null) blueprintTrace('tick', 'fps_label', 'format_string', {'format': 'FPS: {0}', 'arg_0': p67, 'arg_1': '', 'arg_2': '', 'arg_3': '', 'return_value': p68});
            final r69 = LuminaBlueprintFunctionLibrary.arrayAdd(p64, p68);
            oadd_return_value = r69;
            if (trace != null) blueprintTrace('tick', 'add', 'array_add', {'target_array': p64, 'new_item': p68, 'return_value': r69});
            final p70 = log;
            if (trace != null) blueprintTrace('tick', 'log', 'variable_get', {'value': p70});
            final p71 = LuminaBlueprintFunctionLibrary.arrayLength(p70);
            if (trace != null) blueprintTrace('tick', 'len', 'array_length', {'target_array': p70, 'return_value': p71});
            final p72 = LuminaBlueprintFunctionLibrary.intToString(p71);
            if (trace != null) blueprintTrace('tick', 'len_text', 'int_to_string', {'in_int': p71, 'return_value': p72});
            LuminaBlueprintFunctionLibrary.printString(this, p72, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
            if (trace != null) blueprintTrace('tick', 'say_len', 'print_string', {'in_string': p72, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p72);
            if (trace != null) blueprintTrace('tick', 'wait', 'retriggerable_delay', {'duration': 0.05});
            blueprintRetriggerableDelay('wait', 0.05, () => _resumeWaitFromTick(deltaSeconds));
          } else if (m59.index == 1) {
            LuminaBlueprintFunctionLibrary.printString(this, 'out 1', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
            if (trace != null) blueprintTrace('tick', 'm1', 'print_string', {'in_string': 'out 1', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'out 1');
            final p73 = LuminaBlueprintFunctionLibrary.floatDivide(1.0, deltaSeconds);
            if (trace != null) blueprintTrace('tick', 'fps', 'float_divide', {'a': 1.0, 'b': deltaSeconds, 'return_value': p73});
            final p74 = LuminaBlueprintFunctionLibrary.round(p73);
            if (trace != null) blueprintTrace('tick', 'fps_round', 'round', {'a': p73, 'return_value': p74});
            final p75 = LuminaBlueprintFunctionLibrary.intToString(p74);
            if (trace != null) blueprintTrace('tick', 'fps_text', 'int_to_string', {'in_int': p74, 'return_value': p75});
            final p76 = LuminaBlueprintFunctionLibrary.formatString('FPS: {0}', p75, '', '', '');
            if (trace != null) blueprintTrace('tick', 'fps_label', 'format_string', {'format': 'FPS: {0}', 'arg_0': p75, 'arg_1': '', 'arg_2': '', 'arg_3': '', 'return_value': p76});
            LuminaBlueprintFunctionLibrary.printString(this, p76, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
            if (trace != null) blueprintTrace('tick', 'say_fps', 'print_string', {'in_string': p76, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p76);
            final p77 = log;
            if (trace != null) blueprintTrace('tick', 'log', 'variable_get', {'value': p77});
            final p78 = LuminaBlueprintFunctionLibrary.floatDivide(1.0, deltaSeconds);
            if (trace != null) blueprintTrace('tick', 'fps', 'float_divide', {'a': 1.0, 'b': deltaSeconds, 'return_value': p78});
            final p79 = LuminaBlueprintFunctionLibrary.round(p78);
            if (trace != null) blueprintTrace('tick', 'fps_round', 'round', {'a': p78, 'return_value': p79});
            final p80 = LuminaBlueprintFunctionLibrary.intToString(p79);
            if (trace != null) blueprintTrace('tick', 'fps_text', 'int_to_string', {'in_int': p79, 'return_value': p80});
            final p81 = LuminaBlueprintFunctionLibrary.formatString('FPS: {0}', p80, '', '', '');
            if (trace != null) blueprintTrace('tick', 'fps_label', 'format_string', {'format': 'FPS: {0}', 'arg_0': p80, 'arg_1': '', 'arg_2': '', 'arg_3': '', 'return_value': p81});
            final r82 = LuminaBlueprintFunctionLibrary.arrayAdd(p77, p81);
            oadd_return_value = r82;
            if (trace != null) blueprintTrace('tick', 'add', 'array_add', {'target_array': p77, 'new_item': p81, 'return_value': r82});
            final p83 = log;
            if (trace != null) blueprintTrace('tick', 'log', 'variable_get', {'value': p83});
            final p84 = LuminaBlueprintFunctionLibrary.arrayLength(p83);
            if (trace != null) blueprintTrace('tick', 'len', 'array_length', {'target_array': p83, 'return_value': p84});
            final p85 = LuminaBlueprintFunctionLibrary.intToString(p84);
            if (trace != null) blueprintTrace('tick', 'len_text', 'int_to_string', {'in_int': p84, 'return_value': p85});
            LuminaBlueprintFunctionLibrary.printString(this, p85, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
            if (trace != null) blueprintTrace('tick', 'say_len', 'print_string', {'in_string': p85, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p85);
            if (trace != null) blueprintTrace('tick', 'wait', 'retriggerable_delay', {'duration': 0.05});
            blueprintRetriggerableDelay('wait', 0.05, () => _resumeWaitFromTick(deltaSeconds));
          }
        }
        _flowGate = !(_flowGate ?? !(false));
        if (trace != null) blueprintTrace('tick', 'gate', 'gate', {'is_open': _flowGate, 'pin': 'toggle'});
      }
    }
  }

  /// After Retriggerable Delay (node wait).
  void _resumeWaitFromTick(double deltaSeconds) {
    LuminaBlueprintFunctionLibrary.printString(this, 'late', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('tick', 'late', 'print_string', {'in_string': 'late', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'late');
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
