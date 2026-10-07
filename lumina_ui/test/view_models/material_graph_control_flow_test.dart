import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_logic_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_parser.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_types.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';

/// `if` / `else` chains, comparisons, logic and `?:` in the material graph:
/// they lower into Compare / And / Or / Not / If nodes, the generator writes
/// them back as GLSL conditionals that matc compiles, and the source
/// round-trips to the same graph.
const _surface = MaterialSurface();

/// The triplanar material a user opened: world-space UVs picked by the
/// dominant axis of the geometric normal.
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
}
''';

const _logicHeader = 'material {\n    name : "M_Logic",\n    shadingModel : lit,\n    parameters : [\n'
    '        { type : float, name : a, default : 0.2 },\n'
    '        { type : float, name : b, default : 0.6 },\n'
    '        { type : float, name : d, default : 1.0 }\n'
    '    ]\n}\n';

String _logicSource(String body) =>
    '${_logicHeader}fragment {\n    void material(inout MaterialInputs material) {\n$body\n    }\n}\n';

String _generate(LuminaBlueprintGraph g, String source) =>
    MaterialGraphCodegen.generate(g, currentSource: source, surface: _surface);

Future<bool> _compiles(String source) async {
  final vm = MaterialEditorViewModel(
    assetPath: '${Directory.systemTemp.path}/does_not_matter.lmas',
    initialAsset: LuminaAsset(assetId: 'M', name: 'M_Test', type: AssetType.filamat, rawMatSource: source),
  );
  return vm.compile();
}

/// A node as the round trip must keep it: its kind and settings, blind to
/// ids, positions and local names.
String _signature(LuminaBlueprintNode n) {
  final settings = Map.of(n.literals)..removeWhere((k, _) => k == 'varName' || k == 'declOrder' || k == 'declType');
  final keys = settings.keys.toList()..sort();
  return '${n.registryId}{${[for (final k in keys) '$k: ${settings[k]}'].join(', ')}}';
}

/// The graph's nodes and wires as sorted multisets of signatures.
({List<String> nodes, List<String> wires}) _multisets(LuminaBlueprintGraph g) {
  String sig(String id) => _signature(g.node(id)!);
  return (
    nodes: [for (final n in g.nodes) _signature(n)]..sort(),
    wires: [for (final w in g.wires) '${sig(w.fromNodeId)}.${w.fromPinId} -> ${sig(w.toNodeId)}.${w.toPinId}']..sort(),
  );
}

List<LuminaBlueprintNode> _ofKind(LuminaBlueprintGraph g, String kind) =>
    [for (final n in g.nodes) if (n.registryId == kind) n];

LuminaBlueprintNode _from(LuminaBlueprintGraph g, String nodeId, String pin) => g.node(g.wireInto(nodeId, pin)!.fromNodeId)!;

/// Parses [source] without fallback, regenerates it, compiles that with matc
/// and checks it parses back to the same nodes and wires.
Future<(LuminaBlueprintGraph, String)> _roundTrip(String source) async {
  final result = MaterialGraphParser.parse(source);
  expect(result.isFallback, isFalse, reason: result.fallbackReason);
  final g = result.graph;
  final analysis = MaterialGraphChecker.check(g, _surface);
  expect(analysis.hasErrors, isFalse, reason: '${analysis.diagnostics}');
  final generated = _generate(g, source);
  expect(await _compiles(generated), isTrue, reason: generated);
  final again = MaterialGraphParser.parse(generated);
  expect(again.isFallback, isFalse, reason: again.fallbackReason);
  final before = _multisets(g), after = _multisets(again.graph);
  expect(after.nodes, before.nodes);
  expect(after.wires, before.wires);
  expect(_generate(again.graph, generated), generated, reason: 'generating again gives the same text');
  return (g, generated);
}

void main() {
  group('the triplanar material', () {
    test('parses without fallback into Compare, And and nested If nodes feeding the four Texture Samples', () {
      final result = MaterialGraphParser.parse(_triplanar);
      expect(result.isFallback, isFalse, reason: result.fallbackReason);
      final g = result.graph;
      expect(_ofKind(g, MaterialNodes.customFragment), isEmpty);

      final compares = _ofKind(g, MaterialLogicNodes.compare);
      expect(compares, hasLength(4));
      expect(compares.map(MaterialLogicNodes.operatorOf).toSet(), {'>='});
      final ands = _ofKind(g, MaterialLogicNodes.and);
      expect(ands, hasLength(2));
      for (final and in ands) {
        expect(_from(g, and.id, 'a').registryId, MaterialLogicNodes.compare);
        expect(_from(g, and.id, 'b').registryId, MaterialLogicNodes.compare);
      }
      final ifs = _ofKind(g, MaterialLogicNodes.ifNode);
      expect(ifs, hasLength(2));
      // The outer If picks yz, else the inner one: xz, else xy.
      final outer = ifs.singleWhere((n) => _from(g, n.id, 'else').registryId == MaterialLogicNodes.ifNode);
      final inner = _from(g, outer.id, 'else');
      expect(outer.literals['varName'], 'finalUV');
      String mask(LuminaBlueprintNode n) => MaterialNodes.maskChannels(n);
      expect(mask(_from(g, outer.id, 'then')), 'gb');
      expect(mask(_from(g, inner.id, 'then')), 'rb');
      expect(mask(_from(g, inner.id, 'else')), 'rg');
      expect(_from(g, outer.id, 'condition').registryId, MaterialLogicNodes.and);
      expect(_from(g, inner.id, 'condition').registryId, MaterialLogicNodes.and);

      final samples = _ofKind(g, MaterialNodes.textureSample);
      expect(samples.map((s) => s.literals['parameter']).toSet(), {'mapColor', 'mapNormal', 'mapRoughness', 'mapAO'});
      for (final s in samples) {
        expect(g.wireInto(s.id, 'uvs')?.fromNodeId, outer.id, reason: '${s.literals['parameter']} samples at finalUV');
      }
      expect(MaterialGraphChecker.check(g, _surface).hasErrors, isFalse);
    });

    test('its generated code compiles with matc and parses back to the same nodes and wires', () async {
      final (_, generated) = await _roundTrip(_triplanar);
      expect(generated, contains('vec2 finalUV = ((('));
      expect(generated, contains(' >= '));
      expect(generated, contains(' && '));
      expect(generated, contains(' ? '));
      expect(generated, isNot(contains('if (')));
      expect(generated.indexOf('vec2 finalUV'), lessThan(generated.indexOf('prepareMaterial(material)')),
          reason: 'the UVs feed Normal, which is set before prepareMaterial');
    });

    test('a branch that writes material.baseColor still falls back, naming the field', () {
      final source = _triplanar.replaceFirst('finalUV = worldPos.xy;', 'finalUV = worldPos.xy;\n'
          '            material.baseColor = vec4(1.0, 0.0, 0.0, 1.0);');
      final result = MaterialGraphParser.parse(source);
      expect(result.isFallback, isTrue);
      expect(result.fallbackReason, contains('material.baseColor'));
      expect(_ofKind(result.graph, MaterialNodes.customFragment), hasLength(1));
    });

    test('reading finalUV when only the if branch assigns it falls back', () {
      final start = _triplanar.indexOf('        } else if');
      final end = _triplanar.indexOf('        vec3 albedo');
      final source = '${_triplanar.substring(0, start)}        }\n${_triplanar.substring(end)}';
      final result = MaterialGraphParser.parse(source);
      expect(result.isFallback, isTrue);
      expect(result.fallbackReason, contains('finalUV may be read unassigned'));
    });

    test('a local declared inside a branch and read after it falls back', () {
      final source = _triplanar
          .replaceFirst('finalUV = worldPos.xy;', 'finalUV = worldPos.xy;\n            float k = 2.0;')
          .replaceFirst('material.metallic = 0.0;', 'material.metallic = k;');
      final result = MaterialGraphParser.parse(source);
      expect(result.isFallback, isTrue);
      expect(result.fallbackReason, contains("'k' is declared inside an if branch"));
    });
  });

  group('expressions', () {
    test('x = c ? a : b and !(a < b) || d == 1.0 round-trip exactly', () async {
      final source = _logicSource('''
        prepareMaterial(material);
        float x;
        x = materialParams.a > materialParams.b ? materialParams.a : materialParams.b;
        bool keep = !(materialParams.a < materialParams.b) || materialParams.d == 1.0;
        material.roughness = x;
        material.metallic = keep ? 1.0 : 0.25;''');
      final (g, generated) = await _roundTrip(source);
      final roughnessIf = _from(g, MaterialNodes.outputNodeId, MaterialNodes.roughness);
      expect(roughnessIf.registryId, MaterialLogicNodes.ifNode);
      expect(MaterialLogicNodes.operatorOf(_from(g, roughnessIf.id, 'condition')), '>');
      final metallicIf = _from(g, MaterialNodes.outputNodeId, MaterialNodes.metallic);
      expect(metallicIf.literals['else'], 0.25);
      final or = _from(g, metallicIf.id, 'condition');
      expect(or.registryId, MaterialLogicNodes.or);
      expect(or.literals['varName'], 'keep');
      final not = _from(g, or.id, 'a');
      expect(not.registryId, MaterialLogicNodes.not);
      expect(MaterialLogicNodes.operatorOf(_from(g, not.id, 'a')), '<');
      final equal = _from(g, or.id, 'b');
      expect(MaterialLogicNodes.operatorOf(equal), '==');
      expect(equal.literals['b'], 1.0);
      expect(generated, contains('bool keep = ((!(materialParams.a < materialParams.b)) || (materialParams.d == 1.0));'));
      expect(generated, contains('material.metallic = (keep ? 1.0 : 0.25);'));
    });

    test('a compound assignment inside a branch lowers to If(c, x + 1, x)', () async {
      final source = _logicSource('''
        prepareMaterial(material);
        float x = materialParams.a;
        if (materialParams.b > 0.5) x += 1.0;
        material.roughness = x;''');
      final (g, _) = await _roundTrip(source);
      final ifNode = _from(g, MaterialNodes.outputNodeId, MaterialNodes.roughness);
      expect(ifNode.registryId, MaterialLogicNodes.ifNode);
      final add = _from(g, ifNode.id, 'then');
      expect(add.registryId, MaterialNodes.add);
      expect(_from(g, add.id, 'a').literals['name'], 'a');
      expect(add.literals['b'] ?? 1.0, 1.0);
      expect(_from(g, ifNode.id, 'else').literals['name'], 'a', reason: 'no branch assigns it: the value before');
      final cond = _from(g, ifNode.id, 'condition');
      expect(MaterialLogicNodes.operatorOf(cond), '>');
      expect(cond.literals['b'], 0.5);
    });

    test('a nested if inside a branch lowers recursively', () async {
      final source = _logicSource('''
        prepareMaterial(material);
        float x = 0.1;
        if (materialParams.a > 0.5) {
            if (materialParams.b > 0.5) {
                x = 0.9;
            } else {
                x = 0.6;
            }
        }
        material.roughness = x;''');
      final (g, _) = await _roundTrip(source);
      final outer = _from(g, MaterialNodes.outputNodeId, MaterialNodes.roughness);
      expect(outer.registryId, MaterialLogicNodes.ifNode);
      final inner = _from(g, outer.id, 'then');
      expect(inner.registryId, MaterialLogicNodes.ifNode);
      expect((inner.literals['then'], inner.literals['else']), (0.9, 0.6));
    });

    test('a comparison in the vertex block feeds a Set Vertex Variable and compiles', () async {
      const source = 'material {\n    name : "M_VertexLogic",\n    shadingModel : unlit,\n    variables : [ band ]\n}\n'
          'vertex {\n    void materialVertex(inout MaterialVertexInputs material) {\n'
          '        material.band = vec4(material.worldPosition.y > 0.0 ? 1.0 : 0.25);\n    }\n}\n'
          'fragment {\n    void material(inout MaterialInputs material) {\n        prepareMaterial(material);\n'
          '        material.baseColor = vec4(variable_band.rgb, 1.0);\n    }\n}\n';
      final (g, generated) = await _roundTrip(source);
      final setter = _ofKind(g, MaterialNodes.setVertexVariable).single;
      expect(_from(g, setter.id, 'value').registryId, MaterialLogicNodes.ifNode);
      expect(generated, contains('? 1.0 : 0.25)'));
    });

    test('a bool never mixes with float math', () {
      final result = MaterialGraphParser.parse(_logicSource('''
        prepareMaterial(material);
        material.roughness = (materialParams.a > materialParams.b) * 2.0;'''));
      expect(result.isFallback, isTrue);
      expect(result.fallbackReason, contains('bool'));
    });

    test('loops still fall back', () {
      final result = MaterialGraphParser.parse(_logicSource('''
        prepareMaterial(material);
        for (int i = 0; i < 2; i++) { }'''));
      expect(result.isFallback, isTrue);
      expect(result.fallbackReason, contains("'for'"));
    });
  });
}
