// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_display_settings.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpDisplaySettings extends LuminaActor with LuminaBlueprintRuntime {
  BpDisplaySettings({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_display_settings';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
  ];

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
    LuminaBlueprintFunctionLibrary.setScreenResolution(this, 1920, 1080);
    if (trace != null) blueprintTrace('begin', 'resolution', 'set_screen_resolution', {'width': 1920, 'height': 1080});
    LuminaBlueprintFunctionLibrary.setFullscreenMonitor(this, 0);
    if (trace != null) blueprintTrace('begin', 'monitor', 'set_fullscreen_monitor', {'index': 0});
    LuminaBlueprintFunctionLibrary.applyScalabilitySettings(this);
    if (trace != null) blueprintTrace('begin', 'apply', 'apply_scalability_settings', {});
    final p0 = LuminaBlueprintFunctionLibrary.getScreenResolution(this);
    if (trace != null) blueprintTrace('begin', 'screen', 'get_screen_resolution', {'width': p0.width, 'height': p0.height});
    final p1 = LuminaBlueprintFunctionLibrary.intToString(p0.width);
    if (trace != null) blueprintTrace('begin', 'width_text', 'int_to_string', {'in_int': p0.width, 'return_value': p1});
    LuminaBlueprintFunctionLibrary.printString(this, p1, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_width', 'print_string', {'in_string': p1, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p1);
    final p2 = LuminaBlueprintFunctionLibrary.getScreenResolution(this);
    if (trace != null) blueprintTrace('begin', 'screen', 'get_screen_resolution', {'width': p2.width, 'height': p2.height});
    final p3 = LuminaBlueprintFunctionLibrary.intToString(p2.height);
    if (trace != null) blueprintTrace('begin', 'height_text', 'int_to_string', {'in_int': p2.height, 'return_value': p3});
    LuminaBlueprintFunctionLibrary.printString(this, p3, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_height', 'print_string', {'in_string': p3, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p3);
    final p4 = LuminaBlueprintFunctionLibrary.getSupportedResolutions(this);
    if (trace != null) blueprintTrace('begin', 'supported', 'get_supported_resolutions', {'return_value': p4});
    final p5 = LuminaBlueprintFunctionLibrary.arrayLength(p4);
    if (trace != null) blueprintTrace('begin', 'supported_count', 'array_length', {'target_array': p4, 'return_value': p5});
    final p6 = LuminaBlueprintFunctionLibrary.intToString(p5);
    if (trace != null) blueprintTrace('begin', 'supported_text', 'int_to_string', {'in_int': p5, 'return_value': p6});
    LuminaBlueprintFunctionLibrary.printString(this, p6, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_supported', 'print_string', {'in_string': p6, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p6);
    final p7 = LuminaBlueprintFunctionLibrary.getMonitorCount(this);
    if (trace != null) blueprintTrace('begin', 'monitors', 'get_monitor_count', {'return_value': p7});
    final p8 = LuminaBlueprintFunctionLibrary.intToString(p7);
    if (trace != null) blueprintTrace('begin', 'monitors_text', 'int_to_string', {'in_int': p7, 'return_value': p8});
    LuminaBlueprintFunctionLibrary.printString(this, p8, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_monitors', 'print_string', {'in_string': p8, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p8);
    final p9 = LuminaBlueprintFunctionLibrary.getCurrentMonitor(this);
    if (trace != null) blueprintTrace('begin', 'current', 'get_current_monitor', {'index': p9.index, 'name': p9.name});
    LuminaBlueprintFunctionLibrary.printString(this, p9.name, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_current', 'print_string', {'in_string': p9.name, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p9.name);
    final p10 = LuminaBlueprintFunctionLibrary.getDesktopResolution(this);
    if (trace != null) blueprintTrace('begin', 'desktop', 'get_desktop_resolution', {'width': p10.width, 'height': p10.height, 'refresh_rate': p10.refreshRate});
    final p11 = LuminaBlueprintFunctionLibrary.intToString(p10.refreshRate);
    if (trace != null) blueprintTrace('begin', 'desktop_hz_text', 'int_to_string', {'in_int': p10.refreshRate, 'return_value': p11});
    LuminaBlueprintFunctionLibrary.printString(this, p11, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_desktop_hz', 'print_string', {'in_string': p11, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p11);
    final p12 = LuminaBlueprintFunctionLibrary.getSupportedRefreshRates(this, 1920, 1080);
    if (trace != null) blueprintTrace('begin', 'rates', 'get_supported_refresh_rates', {'width': 1920, 'height': 1080, 'return_value': p12});
    final p13 = LuminaBlueprintFunctionLibrary.arrayLength(p12);
    if (trace != null) blueprintTrace('begin', 'rates_count', 'array_length', {'target_array': p12, 'return_value': p13});
    final p14 = LuminaBlueprintFunctionLibrary.intToString(p13);
    if (trace != null) blueprintTrace('begin', 'rates_text', 'int_to_string', {'in_int': p13, 'return_value': p14});
    LuminaBlueprintFunctionLibrary.printString(this, p14, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_rates', 'print_string', {'in_string': p14, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p14);
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
