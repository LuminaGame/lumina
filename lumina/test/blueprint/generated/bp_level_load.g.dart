// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_level_load.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpLevelLoad extends LuminaActor with LuminaBlueprintRuntime {
  BpLevelLoad({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_level_load';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
    LuminaBlueprintComponent(
      id: 'root',
      name: 'DefaultSceneRoot',
      type: 'LuminaSceneComponent',
      parentId: null,
      properties: <String, dynamic>{},
      isSceneComponent: true,
    ),
  ];

  double lastPercent = 0.0;
  double eventPercent = 0.0;
  int updates = 0;

  /// Custom events, functions and interface events by name.
  @override
  Map<String, Object?> callBlueprint(String name, Map<String, Object?> args) {
    switch (name) {
      case 'StartLoading':
        _onStart(); return const {};
      case 'OnLoadProgress':
        _onProgress_event((args['Percent'] as double?) ?? 0.0, (args['TotalCount'] as int?) ?? 0, (args['LoadedCount'] as int?) ?? 0, (args['CurrentContent'] as String?) ?? ''); return const {};
      case 'TryBadLevel':
        _onBad(); return const {};
      case 'LoadAndGo':
        _onGo(); return const {};
      case 'StopLoading':
        _onStop(); return const {};
      default:
        return super.callBlueprint(name, args);
    }
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _onBegin();
  }

  @override
  void onTick(double deltaSeconds) {
    super.onTick(deltaSeconds);
    advanceBlueprintLatent(deltaSeconds);
  }

  /// Event BeginPlay (node begin).
  void _onBegin() {
    LuminaBlueprintFunctionLibrary.printString(this, 'loader ready', false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_ready', 'print_string', {'in_string': 'loader ready', 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'loader ready');
  }

  /// StartLoading (node start).
  void _onStart() {
    if (trace != null) blueprintTrace('start', 'load', 'load_level', {'level_name': 'L_Second', 'on_progress_event': LuminaBlueprintDelegate(this, 'OnLoadProgress'), 'on_error_event': null, 'on_success_event': null});
    LuminaBlueprintFunctionLibrary.loadLevel(this, 'L_Second', (pin, o) {
      if (pin == 'on_progress') {
        _resumeLoadOn_progressFromStart(o);
      } else if (pin == 'on_error') {
        _resumeLoadOn_errorFromStart(o);
      } else if (pin == 'on_success') {
        _resumeLoadOn_successFromStart(o);
      }
    }, LuminaBlueprintDelegate(this, 'OnLoadProgress'), null, null);
  }

  /// OnLoadProgress (node progress_event).
  void _onProgress_event(double percent, int totalCount, int loadedCount, String currentContent) {
    double? oset_event_pct_value;
    eventPercent = percent;
    oset_event_pct_value = percent;
    if (trace != null) blueprintTrace('progress_event', 'set_event_pct', 'variable_set', {'value': percent});
    final p5 = LuminaBlueprintFunctionLibrary.append('event ', currentContent);
    if (trace != null) blueprintTrace('progress_event', 'event_line', 'append', {'a': 'event ', 'b': currentContent, 'return_value': p5});
    LuminaBlueprintFunctionLibrary.printString(this, p5, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('progress_event', 'say_event', 'print_string', {'in_string': p5, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p5);
  }

  /// TryBadLevel (node bad).
  void _onBad() {
    if (trace != null) blueprintTrace('bad', 'bad_change', 'change_level', {'level_name': 'L_Nowhere', 'on_error_event': null, 'on_success_event': null});
    LuminaBlueprintFunctionLibrary.changeLevel(this, 'L_Nowhere', (pin, o) {
      if (pin == 'on_error') {
        _resumeBad_changeOn_errorFromBad(o);
      }
    }, null, null);
  }

  /// LoadAndGo (node go).
  void _onGo() {
    if (trace != null) blueprintTrace('go', 'load_and_change', 'load_and_change_level', {'level_name': 'L_First', 'on_error_event': null, 'on_success_event': null});
    LuminaBlueprintFunctionLibrary.loadAndChangeLevel(this, 'L_First', (pin, o) {
      if (pin == 'on_success') {
        _resumeLoad_and_changeOn_successFromGo(o);
      }
    }, null, null);
  }

  /// StopLoading (node stop).
  void _onStop() {
    LuminaBlueprintFunctionLibrary.cancelLevelLoad(this, '');
    if (trace != null) blueprintTrace('stop', 'cancel', 'cancel_level_load', {'level_name': ''});
  }

  /// After Load Level (node load).
  void _resumeLoadOn_progressFromStart(Map<String, Object?> o) {
    double? oset_pct_value;
    int? oset_updates_value;
    lastPercent = (o['percent'] as double);
    oset_pct_value = (o['percent'] as double);
    if (trace != null) blueprintTrace('load', 'set_pct', 'variable_set', {'value': (o['percent'] as double)});
    final p0 = updates;
    if (trace != null) blueprintTrace('load', 'get_updates', 'variable_get', {'value': p0});
    final p1 = LuminaBlueprintFunctionLibrary.intAdd(p0, 1);
    if (trace != null) blueprintTrace('load', 'plus_one', 'int_add', {'a': p0, 'b': 1, 'return_value': p1});
    updates = p1;
    oset_updates_value = p1;
    if (trace != null) blueprintTrace('load', 'set_updates', 'variable_set', {'value': p1});
    LuminaBlueprintFunctionLibrary.printString(this, (o['current_content'] as String), false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('load', 'say_item', 'print_string', {'in_string': (o['current_content'] as String), 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: (o['current_content'] as String));
  }

  /// After Load Level (node load).
  void _resumeLoadOn_errorFromStart(Map<String, Object?> o) {
    LuminaBlueprintFunctionLibrary.printString(this, (o['error'] as String), false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('load', 'say_load_error', 'print_string', {'in_string': (o['error'] as String), 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: (o['error'] as String));
  }

  /// After Change Level (node change).
  void _resumeChangeOn_errorFromLoadOn_success(Map<String, Object?> o) {
    LuminaBlueprintFunctionLibrary.printString(this, (o['error'] as String), false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('change', 'say_change_error', 'print_string', {'in_string': (o['error'] as String), 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: (o['error'] as String));
  }

  /// After Change Level (node change).
  void _resumeChangeOn_successFromLoadOn_success(Map<String, Object?> o) {
    LuminaBlueprintFunctionLibrary.printString(this, 'changed', false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('change', 'say_changed', 'print_string', {'in_string': 'changed', 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'changed');
  }

  /// After Load Level (node load).
  void _resumeLoadOn_successFromStart(Map<String, Object?> o) {
    final p2 = LuminaBlueprintFunctionLibrary.isLevelLoaded(this, 'L_Second');
    if (trace != null) blueprintTrace('load', 'loaded', 'is_level_loaded', {'level_name': 'L_Second', 'return_value': p2});
    final p3 = LuminaBlueprintFunctionLibrary.boolToString(p2);
    if (trace != null) blueprintTrace('load', 'loaded_text', 'bool_to_string', {'in_bool': p2, 'return_value': p3});
    final p4 = LuminaBlueprintFunctionLibrary.append('loaded ', p3);
    if (trace != null) blueprintTrace('load', 'loaded_line', 'append', {'a': 'loaded ', 'b': p3, 'return_value': p4});
    LuminaBlueprintFunctionLibrary.printString(this, p4, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('load', 'say_loaded', 'print_string', {'in_string': p4, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p4);
    if (trace != null) blueprintTrace('load', 'change', 'change_level', {'level_name': 'L_Second', 'on_error_event': null, 'on_success_event': null});
    LuminaBlueprintFunctionLibrary.changeLevel(this, 'L_Second', (pin, o) {
      if (pin == 'on_error') {
        _resumeChangeOn_errorFromLoadOn_success(o);
      } else if (pin == 'on_success') {
        _resumeChangeOn_successFromLoadOn_success(o);
      }
    }, null, null);
  }

  /// After Change Level (node bad_change).
  void _resumeBad_changeOn_errorFromBad(Map<String, Object?> o) {
    final p6 = LuminaBlueprintFunctionLibrary.append('bad: ', (o['error'] as String));
    if (trace != null) blueprintTrace('bad_change', 'bad_line', 'append', {'a': 'bad: ', 'b': (o['error'] as String), 'return_value': p6});
    LuminaBlueprintFunctionLibrary.printString(this, p6, false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('bad_change', 'say_bad', 'print_string', {'in_string': p6, 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p6);
  }

  /// After Load And Change Level (node load_and_change).
  void _resumeLoad_and_changeOn_successFromGo(Map<String, Object?> o) {
    LuminaBlueprintFunctionLibrary.printString(this, 'went', false, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('load_and_change', 'say_went', 'print_string', {'in_string': 'went', 'print_to_screen': false, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'went');
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
