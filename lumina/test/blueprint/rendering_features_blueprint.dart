import 'package:lumina/lumina.dart';

/// A game settings Blueprint: BeginPlay asks for ray tracing (ReSTIR on,
/// ray-traced sun shadows off, 16 candidates, 4 spatial samples), DLSS at
/// Performance with sharpness 0.7 and frame generation, applies the settings,
/// then prints the chosen upscaler, the active one, whether DLSS is
/// supported and whether ray tracing is active.
LuminaBlueprintDocument renderingFeaturesBlueprint({String upscaler = 'DLSS'}) {
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_graphics_settings');
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  doc.eventGraph.nodes.addAll([
    place('event_beginplay', 'begin'),
    place('set_ray_tracing_enabled', 'rt', {'enabled': true}),
    place('set_ray_traced_shadows_enabled', 'rt_shadows', {'enabled': false}),
    place('set_restir_enabled', 'restir', {'enabled': true}),
    place('set_restir_candidates', 'candidates', {'candidates': 16}),
    place('set_restir_spatial_samples', 'spatial', {'samples': 4}),
    place('set_upscaler', 'upscaler', {'upscaler': upscaler}),
    place('set_upscaler_quality', 'quality', {'quality': 'Performance'}),
    place('set_upscaler_sharpness', 'sharpness', {'sharpness': 0.7}),
    place('set_frame_generation_enabled', 'framegen', {'enabled': true}),
    place('apply_scalability_settings', 'apply'),
    place('get_upscaler', 'chosen'),
    place('print_string', 'say_chosen'),
    place('get_active_upscaler', 'active'),
    place('print_string', 'say_active'),
    place('is_dlss_supported', 'dlss_supported'),
    place('bool_to_string', 'dlss_text'),
    place('print_string', 'say_dlss'),
    place('is_ray_tracing_active', 'rt_active'),
    place('bool_to_string', 'rt_text'),
    place('print_string', 'say_rt'),
  ]);
  const chain = ['begin', 'rt', 'rt_shadows', 'restir', 'candidates', 'spatial', 'upscaler', 'quality', 'sharpness', 'framegen', 'apply',
    'say_chosen', 'say_active', 'say_dlss', 'say_rt'];
  for (var k = 0; k + 1 < chain.length; k++) {
    doc.eventGraph.wires.add(wire(chain[k], 'exec_out', chain[k + 1], 'exec_in'));
  }
  doc.eventGraph.wires.addAll([
    wire('chosen', 'return_value', 'say_chosen', 'in_string'),
    wire('active', 'return_value', 'say_active', 'in_string'),
    wire('dlss_supported', 'return_value', 'dlss_text', 'in_bool'),
    wire('dlss_text', 'return_value', 'say_dlss', 'in_string'),
    wire('rt_active', 'return_value', 'rt_text', 'in_bool'),
    wire('rt_text', 'return_value', 'say_rt', 'in_string'),
  ]);
  return doc;
}

/// A game's graphics menu as a Blueprint: four custom events a menu calls,
/// each choosing a mode, applying the settings and printing the active
/// upscaler and whether ray tracing is active:
/// - `UseNative`: no ray tracing, no upscaler;
/// - `UseRayTracing`: ray tracing with ray-traced sun shadows and ReSTIR;
/// - `UseFsr3`: FSR3 at Performance with sharpness 0.6 and frame generation;
/// - `UseDlss`: DLSS at Performance (FSR3 or none where DLSS is missing).
LuminaBlueprintDocument graphicsToggleBlueprint() {
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_graphics_menu');
  LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

  void mode(String event, String key, {required bool rayTracing, required String upscaler, bool frameGeneration = false}) {
    final steps = <LuminaBlueprintNode>[
      place('custom_event', '${key}_event', {'name': event}),
      place('set_ray_tracing_enabled', '${key}_rt', {'enabled': rayTracing}),
      place('set_ray_traced_shadows_enabled', '${key}_rt_shadows', {'enabled': true}),
      place('set_restir_enabled', '${key}_restir', {'enabled': rayTracing}),
      place('set_upscaler', '${key}_upscaler', {'upscaler': upscaler}),
      place('set_upscaler_quality', '${key}_quality', {'quality': 'Performance'}),
      place('set_upscaler_sharpness', '${key}_sharpness', {'sharpness': 0.6}),
      place('set_frame_generation_enabled', '${key}_framegen', {'enabled': frameGeneration}),
      place('apply_scalability_settings', '${key}_apply'),
      place('print_string', '${key}_say_upscaler'),
      place('print_string', '${key}_say_rt'),
    ];
    doc.eventGraph.nodes.addAll([
      ...steps,
      place('get_active_upscaler', '${key}_active'),
      place('is_ray_tracing_active', '${key}_rt_active'),
      place('bool_to_string', '${key}_rt_text'),
    ]);
    for (var k = 0; k + 1 < steps.length; k++) {
      doc.eventGraph.wires.add(wire(steps[k].id, 'exec_out', steps[k + 1].id, 'exec_in'));
    }
    doc.eventGraph.wires.addAll([
      wire('${key}_active', 'return_value', '${key}_say_upscaler', 'in_string'),
      wire('${key}_rt_active', 'return_value', '${key}_rt_text', 'in_bool'),
      wire('${key}_rt_text', 'return_value', '${key}_say_rt', 'in_string'),
    ]);
  }

  mode('UseNative', 'native', rayTracing: false, upscaler: 'None');
  mode('UseRayTracing', 'rt', rayTracing: true, upscaler: 'None');
  mode('UseFsr3', 'fsr3', rayTracing: false, upscaler: 'FSR3', frameGeneration: true);
  mode('UseDlss', 'dlss', rayTracing: false, upscaler: 'DLSS');
  return doc;
}
