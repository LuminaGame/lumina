// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_graphics_settings.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpGraphicsSettings extends LuminaActor with LuminaBlueprintRuntime {
  BpGraphicsSettings({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_graphics_settings';

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
    LuminaBlueprintFunctionLibrary.setRayTracingEnabled(this, true);
    if (trace != null) blueprintTrace('begin', 'rt', 'set_ray_tracing_enabled', {'enabled': true});
    LuminaBlueprintFunctionLibrary.setRayTracedShadowsEnabled(this, false);
    if (trace != null) blueprintTrace('begin', 'rt_shadows', 'set_ray_traced_shadows_enabled', {'enabled': false});
    LuminaBlueprintFunctionLibrary.setRestirEnabled(this, true);
    if (trace != null) blueprintTrace('begin', 'restir', 'set_restir_enabled', {'enabled': true});
    LuminaBlueprintFunctionLibrary.setRestirCandidates(this, 16);
    if (trace != null) blueprintTrace('begin', 'candidates', 'set_restir_candidates', {'candidates': 16});
    LuminaBlueprintFunctionLibrary.setRestirSpatialSamples(this, 4);
    if (trace != null) blueprintTrace('begin', 'spatial', 'set_restir_spatial_samples', {'samples': 4});
    LuminaBlueprintFunctionLibrary.setUpscaler(this, 'DLSS');
    if (trace != null) blueprintTrace('begin', 'upscaler', 'set_upscaler', {'upscaler': 'DLSS'});
    LuminaBlueprintFunctionLibrary.setUpscalerQuality(this, 'Performance');
    if (trace != null) blueprintTrace('begin', 'quality', 'set_upscaler_quality', {'quality': 'Performance'});
    LuminaBlueprintFunctionLibrary.setUpscalerSharpness(this, 0.7);
    if (trace != null) blueprintTrace('begin', 'sharpness', 'set_upscaler_sharpness', {'sharpness': 0.7});
    LuminaBlueprintFunctionLibrary.setFrameGenerationEnabled(this, true);
    if (trace != null) blueprintTrace('begin', 'framegen', 'set_frame_generation_enabled', {'enabled': true});
    LuminaBlueprintFunctionLibrary.applyScalabilitySettings(this);
    if (trace != null) blueprintTrace('begin', 'apply', 'apply_scalability_settings', {});
    final p0 = LuminaBlueprintFunctionLibrary.getUpscaler(this);
    if (trace != null) blueprintTrace('begin', 'chosen', 'get_upscaler', {'return_value': p0});
    LuminaBlueprintFunctionLibrary.printString(this, p0, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_chosen', 'print_string', {'in_string': p0, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p0);
    final p1 = LuminaBlueprintFunctionLibrary.getActiveUpscaler(this);
    if (trace != null) blueprintTrace('begin', 'active', 'get_active_upscaler', {'return_value': p1});
    LuminaBlueprintFunctionLibrary.printString(this, p1, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_active', 'print_string', {'in_string': p1, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p1);
    final p2 = LuminaBlueprintFunctionLibrary.isDlssSupported(this);
    if (trace != null) blueprintTrace('begin', 'dlss_supported', 'is_dlss_supported', {'return_value': p2});
    final p3 = LuminaBlueprintFunctionLibrary.boolToString(p2);
    if (trace != null) blueprintTrace('begin', 'dlss_text', 'bool_to_string', {'in_bool': p2, 'return_value': p3});
    LuminaBlueprintFunctionLibrary.printString(this, p3, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_dlss', 'print_string', {'in_string': p3, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p3);
    final p4 = LuminaBlueprintFunctionLibrary.isRayTracingActive(this);
    if (trace != null) blueprintTrace('begin', 'rt_active', 'is_ray_tracing_active', {'return_value': p4});
    final p5 = LuminaBlueprintFunctionLibrary.boolToString(p4);
    if (trace != null) blueprintTrace('begin', 'rt_text', 'bool_to_string', {'in_bool': p4, 'return_value': p5});
    LuminaBlueprintFunctionLibrary.printString(this, p5, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_rt', 'print_string', {'in_string': p5, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p5);
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
