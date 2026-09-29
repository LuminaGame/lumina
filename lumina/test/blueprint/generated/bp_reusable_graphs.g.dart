// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_reusable_graphs.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpReusableGraphs extends LuminaActor with LuminaBlueprintRuntime {
  BpReusableGraphs({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintInterfaces = const ['BPI_Interactable'];
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_reusable_graphs';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
  ];

  double health = 100.0;
  int score = 0;
  String state = 'Closed';
  LuminaTimerHandle? pulse;

  // Flow-control state (DoOnce, FlipFlop, Gate, DoN, MultiGate), reset at BeginPlay.
  bool? _flowPause_once;

  // Event dispatchers.
  LuminaMulticastDelegate get onScored => blueprintDispatcher('OnScored');

  /// Custom events, functions and interface events by name.
  @override
  Map<String, Object?> callBlueprint(String name, Map<String, Object?> args) {
    switch (name) {
      case 'Scored':
        _onScored((args['Points'] as int?) ?? 0); return const {};
      case 'OnPulse':
        _onPulse(); return const {};
      case 'NextTick':
        _onNext(); return const {};
      case 'Named':
        _onNamed(); return const {};
      case 'Interact':
        _onOn_interact(args['Instigator']); return const {};
      case 'AddHealth':
        return _fnAddHealth(args);
      case 'HealthPercent':
        return _fnHealthPercent(args);
      case 'GetPrompt':
        return _fnGetPrompt(args);
      default:
        return super.callBlueprint(name, args);
    }
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _flowPause_once = null;
    _onBegin();
  }

  @override
  void onTick(double deltaSeconds) {
    super.onTick(deltaSeconds);
    advanceBlueprintLatent(deltaSeconds);
    _onTick(deltaSeconds);
  }

  /// Scored (node scored).
  void _onScored(int points) {
    int? oset_score_value;
    final p0 = score;
    if (trace != null) blueprintTrace('scored', 'score', 'variable_get', {'value': p0});
    final p1 = LuminaBlueprintFunctionLibrary.intAdd(p0, points);
    if (trace != null) blueprintTrace('scored', 'score_add', 'int_add', {'a': p0, 'b': points, 'return_value': p1});
    score = p1;
    oset_score_value = p1;
    if (trace != null) blueprintTrace('scored', 'set_score', 'variable_set', {'value': p1});
    final p2 = LuminaBlueprintFunctionLibrary.intToString((oset_score_value ?? 0));
    if (trace != null) blueprintTrace('scored', 'score_text', 'int_to_string', {'in_int': (oset_score_value ?? 0), 'return_value': p2});
    final p3 = LuminaBlueprintFunctionLibrary.append('score ', p2);
    if (trace != null) blueprintTrace('scored', 'score_line', 'append', {'a': 'score ', 'b': p2, 'return_value': p3});
    LuminaBlueprintFunctionLibrary.printString(this, p3, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('scored', 'say_score', 'print_string', {'in_string': p3, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p3);
  }

  /// OnPulse (node pulse).
  void _onPulse() {
    LuminaBlueprintFunctionLibrary.printString(this, 'pulse', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('pulse', 'say_pulse', 'print_string', {'in_string': 'pulse', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'pulse');
  }

  /// NextTick (node next).
  void _onNext() {
    LuminaBlueprintFunctionLibrary.printString(this, 'next tick', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('next', 'say_next', 'print_string', {'in_string': 'next tick', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'next tick');
  }

  /// Named (node named).
  void _onNamed() {
    LuminaBlueprintFunctionLibrary.printString(this, 'named', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('named', 'say_named', 'print_string', {'in_string': 'named', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'named');
  }

  /// Event BeginPlay (node begin).
  void _onBegin() {
    double? oadd1_NewHealth;
    double? oadd2_NewHealth;
    String? oask_Prompt;
    String? oset_state_value;
    LuminaTimerHandle? otimer_return_value;
    LuminaTimerHandle? oset_pulse_value;
    LuminaTimerHandle? onext_timer_return_value;
    LuminaTimerHandle? onamed_timer_return_value;
    if (trace != null) blueprintTrace('begin', 'seq', 'sequence', {});
    final r4 = LuminaBlueprintFunctionLibrary.callFunction(this, 'AddHealth', <String, Object?>{'Amount': 30.0});
    oadd1_NewHealth = ((r4['NewHealth'] as double?) ?? 0.0);
    if (trace != null) blueprintTrace('begin', 'add1', 'call_function', {'Amount': 30.0, 'NewHealth': oadd1_NewHealth});
    final p5 = LuminaBlueprintFunctionLibrary.floatToString((oadd1_NewHealth ?? 0.0), 1);
    if (trace != null) blueprintTrace('begin', 'add1_text', 'float_to_string', {'in_float': (oadd1_NewHealth ?? 0.0), 'decimals': 1, 'return_value': p5});
    LuminaBlueprintFunctionLibrary.printString(this, p5, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_add1', 'print_string', {'in_string': p5, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p5);
    final r6 = LuminaBlueprintFunctionLibrary.callFunction(this, 'AddHealth', <String, Object?>{'Amount': 50.0});
    oadd2_NewHealth = ((r6['NewHealth'] as double?) ?? 0.0);
    if (trace != null) blueprintTrace('begin', 'add2', 'call_function', {'Amount': 50.0, 'NewHealth': oadd2_NewHealth});
    final p7 = LuminaBlueprintFunctionLibrary.callFunction(this, 'HealthPercent', <String, Object?>{});
    final p8 = ((p7['Percent'] as double?) ?? 0.0);
    if (trace != null) blueprintTrace('begin', 'pct', 'call_function_pure', {'Percent': p8});
    final p9 = LuminaBlueprintFunctionLibrary.floatToString(p8, 2);
    if (trace != null) blueprintTrace('begin', 'pct_text', 'float_to_string', {'in_float': p8, 'decimals': 2, 'return_value': p9});
    LuminaBlueprintFunctionLibrary.printString(this, p9, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_pct', 'print_string', {'in_string': p9, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p9);
    final p10 = LuminaBlueprintFunctionLibrary.floatClamp(999.0, 0.0, 150.0);
    if (trace != null) blueprintTrace('begin', 'mac__clamp', 'float_clamp', {'value': 999.0, 'min': 0.0, 'max': 150.0, 'return_value': p10});
    final p11 = LuminaBlueprintFunctionLibrary.floatToString(p10, 1);
    if (trace != null) blueprintTrace('begin', 'mac__text', 'float_to_string', {'in_float': p10, 'decimals': 1, 'return_value': p11});
    LuminaBlueprintFunctionLibrary.printString(this, p11, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'mac__say', 'print_string', {'in_string': p11, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p11);
    final p12 = LuminaBlueprintFunctionLibrary.floatClamp(999.0, 0.0, 150.0);
    if (trace != null) blueprintTrace('begin', 'mac__clamp', 'float_clamp', {'value': 999.0, 'min': 0.0, 'max': 150.0, 'return_value': p12});
    final p13 = LuminaBlueprintFunctionLibrary.floatToString(p12, 0);
    if (trace != null) blueprintTrace('begin', 'mac_text', 'float_to_string', {'in_float': p12, 'decimals': 0, 'return_value': p13});
    LuminaBlueprintFunctionLibrary.printString(this, p13, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_mac', 'print_string', {'in_string': p13, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p13);
    LuminaBlueprintFunctionLibrary.bindEventToDispatcher(this, null, 'OnScored', LuminaBlueprintDelegate(this, 'Scored'));
    if (trace != null) blueprintTrace('begin', 'bind', 'bind_event_to_dispatcher', {'target': null, 'event': LuminaBlueprintDelegate(this, 'Scored')});
    LuminaBlueprintFunctionLibrary.callDispatcher(this, 'OnScored', <String, Object?>{'Points': 7});
    if (trace != null) blueprintTrace('begin', 'fire', 'call_dispatcher', {'Points': 7});
    LuminaBlueprintFunctionLibrary.callCustomEvent(this, 'Scored', <String, Object?>{'Points': 3});
    if (trace != null) blueprintTrace('begin', 'direct', 'call_custom_event', {'Points': 3});
    LuminaBlueprintFunctionLibrary.unbindAllEvents(this, null, 'OnScored');
    if (trace != null) blueprintTrace('begin', 'unbind', 'unbind_all_events', {'target': null});
    LuminaBlueprintFunctionLibrary.callDispatcher(this, 'OnScored', <String, Object?>{'Points': 100});
    if (trace != null) blueprintTrace('begin', 'fire2', 'call_dispatcher', {'Points': 100});
    final r14 = LuminaBlueprintFunctionLibrary.interfaceMessage(this, null, 'BPI_Interactable', 'Interact', <String, Object?>{'Instigator': null});
    if (trace != null) blueprintTrace('begin', 'interact', 'interface_message', {'target': null, 'Instigator': null});
    final r15 = LuminaBlueprintFunctionLibrary.interfaceMessage(this, null, 'BPI_Interactable', 'GetPrompt', <String, Object?>{});
    oask_Prompt = ((r15['Prompt'] as String?) ?? '');
    if (trace != null) blueprintTrace('begin', 'ask', 'interface_message', {'target': null, 'Prompt': oask_Prompt});
    LuminaBlueprintFunctionLibrary.printString(this, (oask_Prompt ?? ''), true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_prompt', 'print_string', {'in_string': (oask_Prompt ?? ''), 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: (oask_Prompt ?? ''));
    final p16 = LuminaBlueprintFunctionLibrary.doesImplementInterface(this, null, 'BPI_Interactable');
    if (trace != null) blueprintTrace('begin', 'impl', 'implements_interface', {'target': null, 'return_value': p16});
    final p17 = LuminaBlueprintFunctionLibrary.boolToString(p16);
    if (trace != null) blueprintTrace('begin', 'impl_text', 'bool_to_string', {'in_bool': p16, 'return_value': p17});
    LuminaBlueprintFunctionLibrary.printString(this, p17, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_impl', 'print_string', {'in_string': p17, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p17);
    final p18 = LuminaBlueprintFunctionLibrary.enumLiteral('E_DoorState', 'Opening');
    if (trace != null) blueprintTrace('begin', 'opening', 'enum_literal', {'return_value': p18});
    state = p18;
    oset_state_value = p18;
    if (trace != null) blueprintTrace('begin', 'set_state', 'variable_set', {'value': p18});
    final s19 = (oset_state_value ?? '');
    if (trace != null) blueprintTrace('begin', 'sw', 'switch_on_enum', {'selection': s19});
    if (s19 == 'Closed') {
      LuminaBlueprintFunctionLibrary.printString(this, 'closed', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_closed', 'print_string', {'in_string': 'closed', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'closed');
    } else if (s19 == 'Opening') {
      LuminaBlueprintFunctionLibrary.printString(this, 'opening', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_opening', 'print_string', {'in_string': 'opening', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'opening');
      final p20 = LuminaBlueprintFunctionLibrary.enumToInt('E_DoorState', (oset_state_value ?? ''));
      if (trace != null) blueprintTrace('begin', 'idx', 'enum_to_int', {'value': (oset_state_value ?? ''), 'return_value': p20});
      final p21 = LuminaBlueprintFunctionLibrary.intToString(p20);
      if (trace != null) blueprintTrace('begin', 'idx_text', 'int_to_string', {'in_int': p20, 'return_value': p21});
      LuminaBlueprintFunctionLibrary.printString(this, p21, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_idx', 'print_string', {'in_string': p21, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p21);
      final p22 = LuminaBlueprintFunctionLibrary.intToEnum('E_DoorState', 9);
      if (trace != null) blueprintTrace('begin', 'last', 'int_to_enum', {'value': 9, 'return_value': p22});
      final p23 = LuminaBlueprintFunctionLibrary.enumToString(p22);
      if (trace != null) blueprintTrace('begin', 'last_text', 'enum_to_string', {'value': p22, 'return_value': p23});
      LuminaBlueprintFunctionLibrary.printString(this, p23, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_last', 'print_string', {'in_string': p23, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p23);
      final p24 = LuminaBlueprintFunctionLibrary.getEnumValueCount('E_DoorState');
      if (trace != null) blueprintTrace('begin', 'count', 'get_enum_value_count', {'return_value': p24});
      final p25 = LuminaBlueprintFunctionLibrary.intToString(p24);
      if (trace != null) blueprintTrace('begin', 'count_text', 'int_to_string', {'in_int': p24, 'return_value': p25});
      LuminaBlueprintFunctionLibrary.printString(this, p25, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_count', 'print_string', {'in_string': p25, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p25);
      final p26 = LuminaBlueprintFunctionLibrary.enumLiteral('E_DoorState', 'Opening');
      if (trace != null) blueprintTrace('begin', 'opening', 'enum_literal', {'return_value': p26});
      final p27 = LuminaBlueprintFunctionLibrary.enumEqual((oset_state_value ?? ''), p26);
      if (trace != null) blueprintTrace('begin', 'same', 'enum_equal', {'a': (oset_state_value ?? ''), 'b': p26, 'return_value': p27});
      final p28 = LuminaBlueprintFunctionLibrary.boolToString(p27);
      if (trace != null) blueprintTrace('begin', 'same_text', 'bool_to_string', {'in_bool': p27, 'return_value': p28});
      LuminaBlueprintFunctionLibrary.printString(this, p28, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
      if (trace != null) blueprintTrace('begin', 'say_same', 'print_string', {'in_string': p28, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p28);
    }
    final r29 = LuminaBlueprintFunctionLibrary.setTimerByEvent(this, LuminaBlueprintDelegate(this, 'OnPulse'), 0.25, true, -1.0);
    otimer_return_value = r29;
    if (trace != null) blueprintTrace('begin', 'timer', 'set_timer_by_event', {'event': LuminaBlueprintDelegate(this, 'OnPulse'), 'time': 0.25, 'looping': true, 'initial_start_delay': -1.0, 'return_value': r29});
    pulse = otimer_return_value;
    oset_pulse_value = otimer_return_value;
    if (trace != null) blueprintTrace('begin', 'set_pulse', 'variable_set', {'value': otimer_return_value});
    final r30 = LuminaBlueprintFunctionLibrary.setTimerForNextTick(this, LuminaBlueprintDelegate(this, 'NextTick'));
    onext_timer_return_value = r30;
    if (trace != null) blueprintTrace('begin', 'next_timer', 'set_timer_for_next_tick', {'event': LuminaBlueprintDelegate(this, 'NextTick'), 'return_value': r30});
    final r31 = LuminaBlueprintFunctionLibrary.setTimerByFunctionName(this, 'Named', 0.1, false, -1.0);
    onamed_timer_return_value = r31;
    if (trace != null) blueprintTrace('begin', 'named_timer', 'set_timer_by_function_name', {'function_name': 'Named', 'time': 0.1, 'looping': false, 'initial_start_delay': -1.0, 'return_value': r31});
    _tlSwing.play();
    if (trace != null) blueprintTrace('begin', 'swing', 'timeline', {'pin': 'play'});
  }

  /// Event Interact (node on_interact).
  void _onOn_interact(Object? instigator_) {
    final p32 = LuminaBlueprintFunctionLibrary.getDisplayName(instigator_);
    if (trace != null) blueprintTrace('on_interact', 'who', 'get_display_name', {'object': instigator_, 'return_value': p32});
    final p33 = LuminaBlueprintFunctionLibrary.append('interact by ', p32);
    if (trace != null) blueprintTrace('on_interact', 'who_line', 'append', {'a': 'interact by ', 'b': p32, 'return_value': p33});
    LuminaBlueprintFunctionLibrary.printString(this, p33, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('on_interact', 'say_who', 'print_string', {'in_string': p33, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p33);
  }

  /// Event Tick (node tick).
  void _onTick(double deltaSeconds) {
    final p34 = LuminaBlueprintFunctionLibrary.getGameTimeInSeconds(this);
    if (trace != null) blueprintTrace('tick', 'time', 'get_game_time_in_seconds', {'return_value': p34});
    final p35 = LuminaBlueprintFunctionLibrary.floatGreater(p34, 1.6);
    if (trace != null) blueprintTrace('tick', 'late', 'float_greater', {'a': p34, 'b': 1.6, 'return_value': p35});
    if (trace != null) blueprintTrace('tick', 'if_late', 'branch', {'condition': p35});
    if (p35) {
      final d36 = _flowPause_once ?? (false);
      if (trace != null) blueprintTrace('tick', 'pause_once', 'do_once', {'fired': !d36});
      if (!d36) {
        _flowPause_once = true;
        final p37 = pulse;
        if (trace != null) blueprintTrace('tick', 'pulse_var', 'variable_get', {'value': p37});
        LuminaBlueprintFunctionLibrary.pauseTimer(this, p37);
        if (trace != null) blueprintTrace('tick', 'pause', 'pause_timer', {'handle': p37});
        final p38 = pulse;
        if (trace != null) blueprintTrace('tick', 'pulse_var', 'variable_get', {'value': p38});
        final p39 = LuminaBlueprintFunctionLibrary.isTimerPaused(this, p38);
        if (trace != null) blueprintTrace('tick', 'paused', 'is_timer_paused', {'handle': p38, 'return_value': p39});
        final p40 = LuminaBlueprintFunctionLibrary.boolToString(p39);
        if (trace != null) blueprintTrace('tick', 'paused_text', 'bool_to_string', {'in_bool': p39, 'return_value': p40});
        LuminaBlueprintFunctionLibrary.printString(this, p40, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
        if (trace != null) blueprintTrace('tick', 'say_paused', 'print_string', {'in_string': p40, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p40);
        final p41 = pulse;
        if (trace != null) blueprintTrace('tick', 'pulse_var', 'variable_get', {'value': p41});
        final p42 = LuminaBlueprintFunctionLibrary.getTimerRemainingTime(this, p41);
        if (trace != null) blueprintTrace('tick', 'left', 'get_timer_remaining_time', {'handle': p41, 'return_value': p42});
        final p43 = LuminaBlueprintFunctionLibrary.floatToString(p42, 2);
        if (trace != null) blueprintTrace('tick', 'left_text', 'float_to_string', {'in_float': p42, 'decimals': 2, 'return_value': p43});
        LuminaBlueprintFunctionLibrary.printString(this, p43, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
        if (trace != null) blueprintTrace('tick', 'say_left', 'print_string', {'in_string': p43, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p43);
      }
    }
  }

  /// Function AddHealth.
  Map<String, Object?> _fnAddHealth(Map<String, Object?> args) {
    final amount = (args['Amount'] as double?) ?? 0.0;
    double lSum = 0.0;
    double? oset_sum_value;
    double? oset_health_value;
    final p44 = health;
    if (trace != null) blueprintTrace('entry', 'health', 'variable_get', {'value': p44});
    final p45 = LuminaBlueprintFunctionLibrary.floatAdd(p44, amount);
    if (trace != null) blueprintTrace('entry', 'plus', 'float_add', {'a': p44, 'b': amount, 'return_value': p45});
    lSum = p45;
    oset_sum_value = p45;
    if (trace != null) blueprintTrace('entry', 'set_sum', 'local_variable_set', {'value': p45});
    final p46 = lSum;
    if (trace != null) blueprintTrace('entry', 'sum', 'local_variable_get', {'value': p46});
    health = p46;
    oset_health_value = p46;
    if (trace != null) blueprintTrace('entry', 'set_health', 'variable_set', {'value': p46});
    final p47 = lSum;
    if (trace != null) blueprintTrace('entry', 'sum', 'local_variable_get', {'value': p47});
    final p48 = LuminaBlueprintFunctionLibrary.floatClamp(p47, 0.0, 150.0);
    if (trace != null) blueprintTrace('entry', 'clamp__clamp', 'float_clamp', {'value': p47, 'min': 0.0, 'max': 150.0, 'return_value': p48});
    final p49 = LuminaBlueprintFunctionLibrary.floatToString(p48, 1);
    if (trace != null) blueprintTrace('entry', 'clamp__text', 'float_to_string', {'in_float': p48, 'decimals': 1, 'return_value': p49});
    LuminaBlueprintFunctionLibrary.printString(this, p49, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('entry', 'clamp__say', 'print_string', {'in_string': p49, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p49);
    final p50 = lSum;
    if (trace != null) blueprintTrace('entry', 'sum', 'local_variable_get', {'value': p50});
    if (trace != null) blueprintTrace('entry', 'result', 'function_result', {'NewHealth': p50});
    return {'NewHealth': p50};
    return {'NewHealth': 0.0};
  }

  /// Function HealthPercent (pure).
  Map<String, Object?> _fnHealthPercent(Map<String, Object?> args) {
    final p51 = health;
    if (trace != null) blueprintTrace('pentry', 'h', 'variable_get', {'value': p51});
    final p52 = LuminaBlueprintFunctionLibrary.floatDivide(p51, 200.0);
    if (trace != null) blueprintTrace('pentry', 'div', 'float_divide', {'a': p51, 'b': 200.0, 'return_value': p52});
    return {'Percent': p52};
  }

  /// Function GetPrompt.
  Map<String, Object?> _fnGetPrompt(Map<String, Object?> args) {
    if (trace != null) blueprintTrace('gentry', 'gresult', 'function_result', {'Prompt': 'Open'});
    return {'Prompt': 'Open'};
    return {'Prompt': ''};
  }

  /// Timeline Swing (node swing).
  LuminaTimeline get _tlSwing => blueprintTimelines['swing'] ??= (LuminaTimeline.fromLiterals(<String, dynamic>{'name': 'Swing', 'length': 0.5, 'loop': false, 'auto_play': false, 'tracks': <dynamic>[<String, dynamic>{'name': 'Angle', 'type': 'float', 'keys': <dynamic>[<String, dynamic>{'time': 0.0, 'value': 0.0, 'interp': 'linear'}, <String, dynamic>{'time': 0.5, 'value': 90.0, 'interp': 'linear'}]}, <String, dynamic>{'name': 'Tint', 'type': 'color', 'keys': <dynamic>[<String, dynamic>{'time': 0.0, 'value': <dynamic>[1.0, 0.0, 0.0, 1.0], 'interp': 'constant'}, <String, dynamic>{'time': 0.25, 'value': <dynamic>[0.0, 1.0, 0.0, 1.0], 'interp': 'constant'}]}]})
    ..onUpdate = _tlSwingUpdate
    ..onFinished = _tlSwingFinished);

  void _tlSwingUpdate() {
    final values = _tlSwing.values();
    final p53 = LuminaBlueprintFunctionLibrary.floatToString((values['Angle'] as double), 1);
    if (trace != null) blueprintTrace('swing', 'angle_text', 'float_to_string', {'in_float': (values['Angle'] as double), 'decimals': 1, 'return_value': p53});
    final p54 = LuminaBlueprintFunctionLibrary.append('angle ', p53);
    if (trace != null) blueprintTrace('swing', 'angle_line', 'append', {'a': 'angle ', 'b': p53, 'return_value': p54});
    LuminaBlueprintFunctionLibrary.printString(this, p54, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('swing', 'say_angle', 'print_string', {'in_string': p54, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p54);
  }

  void _tlSwingFinished() {
    final values = _tlSwing.values();
    final p55 = LuminaBlueprintFunctionLibrary.enumToString(_tlSwing.direction);
    if (trace != null) blueprintTrace('swing', 'dir_text', 'enum_to_string', {'value': _tlSwing.direction, 'return_value': p55});
    final p56 = LuminaBlueprintFunctionLibrary.append('finished ', p55);
    if (trace != null) blueprintTrace('swing', 'done_line', 'append', {'a': 'finished ', 'b': p55, 'return_value': p56});
    LuminaBlueprintFunctionLibrary.printString(this, p56, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('swing', 'say_done', 'print_string', {'in_string': p56, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p56);
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
