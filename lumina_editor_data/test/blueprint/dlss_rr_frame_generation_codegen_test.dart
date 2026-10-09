import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// The DLSS Ray Reconstruction and DLSS Frame Generation nodes compile to the
/// same library calls the VM makes.
void main() {
  test('a graphics menu Blueprint with DLSS RR and DLSS frame generation compiles to the library calls', () {
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'bp_dlss_neural_settings');
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    doc.eventGraph.nodes.addAll([
      place('event_beginplay', 'begin'),
      place('set_upscaler', 'upscaler', {'upscaler': 'DLSS RR'}),
      place('set_frame_generator', 'generator', {'generator': 'DLSS'}),
      place('set_dlss_generated_frames', 'frames', {'frames': 3}),
      place('set_frame_generation_enabled', 'framegen', {'enabled': true}),
      place('apply_scalability_settings', 'apply'),
      place('is_ray_reconstruction_supported', 'rr_supported'),
      place('bool_to_string', 'rr_text'),
      place('print_string', 'say_rr'),
      place('get_max_dlss_generated_frames', 'max_frames'),
      place('int_to_string', 'max_text'),
      place('print_string', 'say_max'),
      place('is_dlss_frame_generation_supported', 'fg_supported'),
      place('get_frame_generator', 'generator_now'),
      place('get_dlss_generated_frames', 'frames_now'),
    ]);
    const chain = ['begin', 'upscaler', 'generator', 'frames', 'framegen', 'apply', 'say_rr', 'say_max'];
    for (var k = 0; k + 1 < chain.length; k++) {
      doc.eventGraph.wires.add(wire(chain[k], 'exec_out', chain[k + 1], 'exec_in'));
    }
    doc.eventGraph.wires.addAll([
      wire('rr_supported', 'return_value', 'rr_text', 'in_bool'),
      wire('rr_text', 'return_value', 'say_rr', 'in_string'),
      wire('max_frames', 'return_value', 'max_text', 'in_int'),
      wire('max_text', 'return_value', 'say_max', 'in_string'),
    ]);

    final result = const BlueprintDartGenerator()
        .generate(doc, className: 'BpDlssNeuralSettings', assetPath: 'contents/blueprints/bp_dlss_neural_settings.lmas');
    expect(result.issues.where((i) => i.isError), isEmpty, reason: result.issues.join('\n'));
    final code = result.code!;
    for (final call in [
      "LuminaBlueprintFunctionLibrary.setUpscaler(this, 'DLSS RR')",
      "LuminaBlueprintFunctionLibrary.setFrameGenerator(this, 'DLSS')",
      'LuminaBlueprintFunctionLibrary.setDlssGeneratedFrames(this, 3)',
      'LuminaBlueprintFunctionLibrary.isRayReconstructionSupported(this)',
      'LuminaBlueprintFunctionLibrary.getMaxDlssGeneratedFrames(this)',
    ]) {
      expect(code, contains(call), reason: call);
    }
  });
}
