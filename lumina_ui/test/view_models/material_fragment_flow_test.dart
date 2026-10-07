import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaBlueprintWire;
import 'package:lumina_ui/ui/features/sub_editors/models/material_fragment_pins.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_parser.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_types.dart';

/// A triplanar material whose `if`/`else` the graph cannot express: the
/// fragment stays one verbatim node, but its flow is still drawn.
const _triplanar = '''material {
    name : "Mobile_Optimized_PBR_Triplanar",
    shadingModel : lit,
    blending : opaque,
    requires : [ tangents ],
    parameters : [
        { type : sampler2d, name : mapColor },
        { type : sampler2d, name : mapNormal },
        { type : sampler2d, name : mapRoughness },
        { type : sampler2d, name : mapAO }
    ]
}

fragment {
    void material(inout MaterialInputs material) {
        vec3 worldPos = getUserWorldPosition();
        vec3 n = abs(getWorldGeometricNormalVector());
        vec2 finalUV;
        if (n.x >= n.y && n.x >= n.z) {
            finalUV = worldPos.yz;
        } else if (n.y >= n.x && n.y >= n.z) {
            finalUV = worldPos.xz;
        } else {
            finalUV = worldPos.xy;
        }
        vec3 albedo = texture(materialParams_mapColor, finalUV).rgb;
        vec3 normal = texture(materialParams_mapNormal, finalUV).rgb;
        float roughness = texture(materialParams_mapRoughness, finalUV).r;
        float ao = texture(materialParams_mapAO, finalUV).r;
        material.normal = normal * 2.0 - 1.0;
        material.ambientOcclusion = ao;
        prepareMaterial(material);
        material.baseColor = vec4(albedo, 1.0);
        material.roughness = roughness;
        material.metallic = 0.0;
    }
}''';

void main() {
  const surface = MaterialSurface();

  test('a verbatim fragment is wired from the parameters it reads to the fields it writes', () {
    final result = MaterialGraphParser.parse(_triplanar);
    expect(result.isFallback, isTrue, reason: 'control flow keeps the fragment verbatim');
    final g = result.graph;
    final fragment = g.nodes.singleWhere((n) => n.registryId == MaterialNodes.customFragment);

    expect(MaterialNodes.inputsOf(fragment).map((p) => p.id), ['mapColor', 'mapNormal', 'mapRoughness', 'mapAO']);
    expect(MaterialNodes.outputsOf(fragment).map((p) => p.id), [
      MaterialNodes.baseColor,
      MaterialNodes.metallic,
      MaterialNodes.roughness,
      MaterialNodes.normal,
      MaterialNodes.ambientOcclusion,
    ]);

    for (final name in ['mapColor', 'mapNormal', 'mapRoughness', 'mapAO']) {
      final w = g.wireInto(fragment.id, name);
      expect(w, isNotNull, reason: '$name is wired in');
      expect(g.node(w!.fromNodeId)!.literals['name'], name);
    }
    for (final pin in [MaterialNodes.baseColor, MaterialNodes.normal, MaterialNodes.ambientOcclusion]) {
      final w = g.wireInto(MaterialNodes.outputNodeId, pin);
      expect(w?.fromNodeId, fragment.id, reason: '$pin comes from the fragment');
    }

    // The flow wires are not an error, and the code is written back verbatim.
    expect(MaterialGraphChecker.check(g, surface).hasErrors, isFalse);
    final out = MaterialGraphCodegen.generate(g, currentSource: _triplanar, surface: surface);
    expect(out, contains('finalUV = worldPos.yz;'));
    expect(out, contains('material.normal = normal * 2.0 - 1.0;'));
  });

  test('editing the fragment code rewires it', () {
    final g = MaterialGraphParser.parse(_triplanar).graph;
    final fragment = g.nodes.singleWhere((n) => n.registryId == MaterialNodes.customFragment);
    fragment.literals['code'] = '''    void material(inout MaterialInputs material) {
        if (true) { }
        prepareMaterial(material);
        material.baseColor = texture(materialParams_mapColor, getUV0());
    }''';
    MaterialFragmentPins.syncWires(g);
    expect(MaterialNodes.inputsOf(fragment).map((p) => p.id), ['mapColor']);
    expect(g.wireInto(fragment.id, 'mapNormal'), isNull);
    expect(g.wireInto(MaterialNodes.outputNodeId, MaterialNodes.normal), isNull);
    expect(g.wireInto(MaterialNodes.outputNodeId, MaterialNodes.baseColor)?.fromNodeId, fragment.id);
  });

  test('a wire from another node into the Material node next to a verbatim fragment is still an error', () {
    final g = MaterialGraphParser.parse(_triplanar).graph;
    final param = g.nodes.firstWhere((n) => n.literals['name'] == 'mapColor');
    final sample = MaterialNodes.create(MaterialNodes.textureSample, id: 'sample', literals: {'parameter': 'mapColor'});
    g.nodes.add(sample);
    g.wires.add(LuminaBlueprintWire(id: 'extra', fromNodeId: param.id, fromPinId: 'tex', toNodeId: sample.id, toPinId: 'tex'));
    g.wires.add(LuminaBlueprintWire(
        id: 'extra2', fromNodeId: sample.id, fromPinId: 'rgb', toNodeId: MaterialNodes.outputNodeId, toPinId: MaterialNodes.emissive));
    expect(MaterialGraphChecker.check(g, surface).hasErrors, isTrue);
  });
}
