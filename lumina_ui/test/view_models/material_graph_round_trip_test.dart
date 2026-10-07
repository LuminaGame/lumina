import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart' show BlendingMode, FilamatShading;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_source.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_parser.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_types.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';

/// The material graph ⇄ `.mat` source round trip.
///
/// The CC body source is the one `AssetRepository.importExternalFile` writes for
/// `CCMH_Body_Male.glb` (the material the user opened); the barrel is imported
/// for real from test-assets.
const _ccBody = '''material {
  name : "M_Skin_Body_CCMH_CCMH_Body_Male",
  shadingModel : lit,
  requires : [ uv0 ],
  parameters : [
    { type : sampler2d, name : baseColorMap },
    { type : sampler2d, name : metallicRoughnessMap },
    { type : sampler2d, name : normalMap },
    { type : sampler2d, name : specularMap }
  ]
}
fragment {
  void material(inout MaterialInputs material) {
    material.normal = texture(materialParams_normalMap, getUV0()).xyz * 2.0 - 1.0;
    prepareMaterial(material);
    material.baseColor = vec4(0.8, 0.8, 0.8, 1.0);
    material.baseColor *= texture(materialParams_baseColorMap, getUV0());
    vec4 mr = texture(materialParams_metallicRoughnessMap, getUV0());
    material.roughness = mr.g;
    material.metallic = mr.b;
    material.reflectance = texture(materialParams_specularMap, getUV0()).r;
  }
}
''';

const _surface = MaterialSurface();

/// A structural description of what feeds each Material output pin, blind to
/// node ids, positions and the source's local names.
String describe(LuminaBlueprintGraph g) {
  String node(String id, String pin, Set<String> seen) {
    final n = g.node(id)!;
    if (!seen.add('$id.$pin')) return '<loop>';
    final inputs = MaterialNodes.inputsOf(n);
    final parts = <String>[];
    for (final p in inputs) {
      final w = g.wireInto(n.id, p.id);
      if (w != null) {
        parts.add('${p.id}=${node(w.fromNodeId, w.fromPinId, {...seen})}');
      } else if ((n.literals[p.id] ?? p.defaultValue) != null) {
        // The constant the input uses: its own, else the pin's default.
        parts.add('${p.id}=${n.literals[p.id] ?? p.defaultValue}');
      }
    }
    final settings = Map.of(n.literals)
      ..removeWhere((k, _) => inputs.any((p) => p.id == k) || k == 'varName' || k == 'declOrder' || k == 'declType');
    final name = n.registryId.replaceFirst('mat_', '');
    return '$name${settings.isEmpty ? '' : settings}.$pin(${parts.join(', ')})';
  }

  final out = g.node(MaterialNodes.outputNodeId)!;
  return [
    for (final p in MaterialNodes.inputsOf(out))
      if (g.wireInto(out.id, p.id) case final w?) '${p.id} <- ${node(w.fromNodeId, w.fromPinId, {})}',
  ].join('\n');
}

String _generate(LuminaBlueprintGraph g, String source, [MaterialSurface surface = _surface]) =>
    MaterialGraphCodegen.generate(g, currentSource: source, surface: surface);

Future<bool> _compiles(String source) async {
  final vm = MaterialEditorViewModel(
    assetPath: '${Directory.systemTemp.path}/does_not_matter.lmas',
    initialAsset: LuminaAsset(assetId: 'M', name: 'M_Test', type: AssetType.filamat, rawMatSource: source),
  );
  return vm.compile();
}

LuminaBlueprintWire _w(String from, String fromPin, String to, String toPin) =>
    LuminaBlueprintWire(id: '$from$fromPin$to$toPin', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

void main() {
  group('imported materials open as a graph', () {
    test('the CC body material reads as TextureSamples into the Material pins', () {
      final result = MaterialGraphParser.parse(_ccBody);
      expect(result.isFallback, isFalse, reason: result.fallbackReason);
      final g = result.graph;
      final d = describe(g);
      expect(d, contains('base_color <- multiply.out(a=constant4{value: [0.8, 0.8, 0.8, 1.0]}.out(), '
          'b=texture_sample{parameter: baseColorMap}.rgba())'));
      expect(d, contains('normal <- subtract.out(a=multiply.out(a=texture_sample{parameter: normalMap}.rgb(), b=2.0), b=1.0)'));
      expect(d, contains('roughness <- texture_sample{parameter: metallicRoughnessMap}.g()'));
      expect(d, contains('metallic <- texture_sample{parameter: metallicRoughnessMap}.b()'));
      expect(d, contains('specular <- texture_sample{parameter: specularMap}.r()'));
      // One shared sample feeds Roughness and Metallic, named as in the source.
      final mr = g.nodes.where((n) => n.literals['parameter'] == 'metallicRoughnessMap').toList();
      expect(mr, hasLength(1));
      expect(mr.single.literals['varName'], 'mr');
      expect(g.nodes.where((n) => n.registryId == MaterialNodes.custom || n.registryId == MaterialNodes.customFragment), isEmpty);
      expect(MaterialGraphChecker.check(g, _surface).hasErrors, isFalse);
      // Laid out left of the Material node, nothing stacked on anything.
      final out = g.node(MaterialNodes.outputNodeId)!;
      expect(g.nodes.where((n) => n.id != out.id).every((n) => n.x < out.x), isTrue);
    });

    test('its generated source compiles, declares the same samplers and reads back as the same graph', () async {
      final g = MaterialGraphParser.parse(_ccBody).graph;
      final generated = _generate(g, _ccBody);
      final src = MatSource.parse(generated);
      expect(src.parameters.map((p) => '${p.type} ${p.name}'),
          ['sampler2d baseColorMap', 'sampler2d metallicRoughnessMap', 'sampler2d normalMap', 'sampler2d specularMap']);
      expect(src.requires, ['uv0']);
      expect(src.materialName, 'M_Skin_Body_CCMH_CCMH_Body_Male');
      expect(generated, contains('vec4 mr = texture(materialParams_metallicRoughnessMap, getUV0());'));
      expect(generated.indexOf('material.normal'), lessThan(generated.indexOf('prepareMaterial(material)')));
      expect(await _compiles(generated), isTrue, reason: generated);

      final again = MaterialGraphParser.parse(generated);
      expect(again.isFallback, isFalse, reason: again.fallbackReason);
      expect(describe(again.graph), describe(g));
      // Stable: generating from the re-parsed graph gives the same text.
      expect(_generate(again.graph, generated), generated);
    });

    test('a real imported barrel material round-trips and compiles', () async {
      final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
      if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
      final project = Directory.systemTemp.createTempSync('material_graph_barrel_');
      addTearDown(() => project.deleteSync(recursive: true));
      Directory('${project.path}/contents').createSync();
      await AssetRepository().importExternalFile(projectPath: project.path, sourceFilePath: barrel.path);
      final file = Directory('${project.path}/contents/materials')
          .listSync(recursive: true)
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('.lmas'));
      final source = LuminaAsset.fromBytes(file.readAsBytesSync()).rawMatSource;
      final g = MaterialGraphParser.parse(source).graph;
      expect(describe(g), contains('base_color <- multiply.out(a=constant4'));
      expect(describe(g), contains('texture_sample{parameter: baseColorMap}.rgba()'));
      final generated = _generate(g, source);
      expect(await _compiles(generated), isTrue, reason: generated);
      expect(describe(MaterialGraphParser.parse(generated).graph), describe(g));
    });
  });

  group('a graph built node by node', () {
    LuminaBlueprintGraph build() {
      final g = LuminaBlueprintGraph();
      MaterialNodes.ensureOutput(g, materialName: 'M_Built');
      g.nodes.addAll([
        MaterialNodes.create(MaterialNodes.textureSample, id: 'tex', literals: {'parameter': 'albedo'}),
        MaterialNodes.create(MaterialNodes.vectorParameter, id: 'tint', literals: {'name': 'tint', 'default': [1.0, 0.5, 0.25, 1.0]}),
        MaterialNodes.create(MaterialNodes.multiply, id: 'mul'),
        MaterialNodes.create(MaterialNodes.scalarParameter, id: 'rough', literals: {'name': 'roughness', 'default': 0.4}),
        MaterialNodes.create(MaterialNodes.fresnel, id: 'fres'),
        MaterialNodes.create(MaterialNodes.custom, id: 'glow', literals: {
          'description': 'Glow',
          'outputType': 'float3',
          'inputs': ['F', 'C'],
          'code': 'return C * F * 2.0;',
        }),
        MaterialNodes.create(MaterialNodes.textureCoordinate, id: 'uv', literals: {'index': 0, 'uTiling': 2.0, 'vTiling': 2.0}),
      ]);
      g.wires.addAll([
        _w('uv', 'out', 'tex', 'uvs'),
        _w('tex', 'rgb', 'mul', 'a'),
        _w('tint', 'rgb', 'mul', 'b'),
        _w('mul', 'out', MaterialNodes.outputNodeId, MaterialNodes.baseColor),
        _w('rough', 'out', MaterialNodes.outputNodeId, MaterialNodes.roughness),
        _w('fres', 'out', 'glow', 'F'),
        _w('tint', 'rgb', 'glow', 'C'),
        _w('glow', 'out', MaterialNodes.outputNodeId, MaterialNodes.emissive),
      ]);
      return g;
    }

    const header = 'material {\n    name : "M_Built",\n    shadingModel : lit\n}\n';

    test('declares exactly its parameters, compiles and round-trips', () async {
      final g = build();
      final analysis = MaterialGraphChecker.check(g, _surface);
      expect(analysis.hasErrors, isFalse, reason: '${analysis.diagnostics}');
      expect(analysis.outputType('mul', 'out'), MaterialValueType.float3);
      final generated = _generate(g, header);
      final params = MatSource.parse(generated).parameters;
      expect(params.map((p) => '${p.type} ${p.name}'), unorderedEquals(['sampler2d albedo', 'float4 tint', 'float roughness']));
      expect(params.firstWhere((p) => p.name == 'roughness').defaultValue?.render(), '0.4');
      expect(generated, contains('lumina_fresnel('));
      expect(generated, contains('// Custom: Glow'));
      expect(generated, contains('(getUV0() * vec2(2.0, 2.0))'));
      expect(MatSource.parse(generated).requires, ['uv0']);
      expect(await _compiles(generated), isTrue, reason: generated);

      final again = MaterialGraphParser.parse(generated);
      expect(again.isFallback, isFalse, reason: again.fallbackReason);
      expect(describe(again.graph), describe(g));
      expect(_generate(again.graph, generated), generated);
    });

    test('a float Constant wired into an inline-constant input stays a Constant node', () {
      final g = LuminaBlueprintGraph();
      MaterialNodes.ensureOutput(g);
      g.nodes.addAll([
        MaterialNodes.create(MaterialNodes.constant, id: 'k', literals: {'value': 0.25}),
        MaterialNodes.create(MaterialNodes.multiply, id: 'mul'),
        MaterialNodes.create(MaterialNodes.time, id: 't'),
      ]);
      g.wires.addAll([
        _w('t', 'out', 'mul', 'a'),
        _w('k', 'out', 'mul', 'b'),
        _w('mul', 'out', MaterialNodes.outputNodeId, MaterialNodes.metallic),
      ]);
      final generated = _generate(g, header);
      final again = MaterialGraphParser.parse(generated).graph;
      expect(describe(again), describe(g));
      expect(again.nodes.where((n) => n.registryId == MaterialNodes.constant), hasLength(1));
    });
  });

  group('code outside the subset is never lost', () {
    test('an unknown built-in becomes a Custom expression node', () async {
      const source = '''material { name : "M_Pulse", shadingModel : lit }
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        float pulse = sin(getUserTime().x * 3.0) * 0.5 + 0.5;
        material.baseColor = vec4(vec3(pulse), 1.0);
        material.roughness = max(pulse, 0.2);
    }
}
''';
      final result = MaterialGraphParser.parse(source);
      expect(result.isFallback, isFalse, reason: result.fallbackReason);
      final customs = result.graph.nodes.where((n) => n.registryId == MaterialNodes.custom).toList();
      expect(customs.map((n) => n.literals['code']), containsAll(['return sin(In0);', 'return max(In0, 0.2);']));
      final generated = _generate(result.graph, source);
      expect(await _compiles(generated), isTrue, reason: generated);
      expect(describe(MaterialGraphParser.parse(generated).graph), describe(result.graph));
    });

    test('an if whose branches write material fields makes the whole fragment one Custom (Fragment) node, emitted verbatim',
        () async {
      const fragmentBody = '''
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        if (materialParams.strength > 0.5) {
            material.baseColor = vec4(1.0, 0.0, 0.0, 1.0);
        } else {
            material.baseColor = vec4(0.0, 0.0, 1.0, 1.0);
        }
    }''';
      const source = 'material {\n    name : "M_Branch",\n    shadingModel : lit,\n    culling : none,\n'
          '    parameters : [ { type : float, name : strength, default : 0.7 } ]\n}\n'
          'vertex {\n    void materialVertex(inout MaterialVertexInputs material) {\n    }\n}\n'
          'fragment {\n$fragmentBody\n}\n';
      final result = MaterialGraphParser.parse(source);
      expect(result.isFallback, isTrue);
      expect(result.fallbackReason, contains('material.baseColor'));
      final fragment = result.graph.nodes.singleWhere((n) => n.registryId == MaterialNodes.customFragment);
      expect(fragment.literals['code'], fragmentBody);
      expect(result.graph.nodes.where((n) => n.registryId == MaterialNodes.scalarParameter).single.literals['name'], 'strength');

      // A graph edit (a new parameter) keeps the fragment, the header's
      // unknown key and the vertex block as written.
      result.graph.nodes.add(MaterialNodes.create(MaterialNodes.scalarParameter, id: 'p', literals: {'name': 'extra', 'default': 1.0}));
      final generated = _generate(result.graph, source);
      expect(generated, contains('fragment {\n$fragmentBody\n}'));
      expect(generated, contains('culling : none'));
      expect(generated, contains('vertex {\n    void materialVertex(inout MaterialVertexInputs material) {\n    }\n}'));
      expect(MatSource.parse(generated).parameters.map((p) => p.name), ['strength', 'extra']);
      expect(await _compiles(generated), isTrue, reason: generated);
    });

    test('a parameter type the graph has no node for is kept in the header', () {
      const source = 'material {\n    name : "M",\n    parameters : [ { type : bool, name : flag }, '
          '{ type : float, name : amount, default : 0.5 } ]\n}\nfragment {\n    void material(inout MaterialInputs material) {\n'
          '        prepareMaterial(material);\n        material.metallic = materialParams.amount;\n    }\n}\n';
      final g = MaterialGraphParser.parse(source).graph;
      final generated = _generate(g, source);
      expect(MatSource.parse(generated).parameters.map((p) => '${p.type} ${p.name}'), ['float amount', 'bool flag']);
    });
  });

  group('type checking', () {
    MaterialGraphAnalysis check(void Function(LuminaBlueprintGraph g) build, [MaterialSurface surface = _surface]) {
      final g = LuminaBlueprintGraph();
      MaterialNodes.ensureOutput(g);
      build(g);
      return MaterialGraphChecker.check(g, surface);
    }

    test('float3 × float2 is an error on the Multiply node; float3 × float broadcasts', () {
      final bad = check((g) {
        g.nodes.addAll([
          MaterialNodes.create(MaterialNodes.constant3, id: 'c3'),
          MaterialNodes.create(MaterialNodes.constant2, id: 'c2'),
          MaterialNodes.create(MaterialNodes.multiply, id: 'mul'),
        ]);
        g.wires.addAll([
          _w('c3', 'out', 'mul', 'a'),
          _w('c2', 'out', 'mul', 'b'),
          _w('mul', 'out', MaterialNodes.outputNodeId, MaterialNodes.baseColor),
        ]);
      });
      expect(bad.hasErrors, isTrue);
      expect(bad.errorNodeIds, {'mul'});
      expect(bad.diagnostics.first.message, contains('float3 and float2'));
      expect(bad.inputHasError('mul', 'b'), isTrue);

      final ok = check((g) {
        g.nodes.addAll([
          MaterialNodes.create(MaterialNodes.constant3, id: 'c3'),
          MaterialNodes.create(MaterialNodes.multiply, id: 'mul', literals: {'b': 0.5}),
        ]);
        g.wires.addAll([
          _w('c3', 'out', 'mul', 'a'),
          _w('mul', 'out', MaterialNodes.outputNodeId, MaterialNodes.baseColor),
        ]);
      });
      expect(ok.hasErrors, isFalse);
      expect(ok.outputType('mul', 'out'), MaterialValueType.float3);
    });

    test('float2 into Base Color is an error; float4 into Base Color keeps its alpha', () {
      final bad = check((g) {
        g.nodes.add(MaterialNodes.create(MaterialNodes.constant2, id: 'c2'));
        g.wires.add(_w('c2', 'out', MaterialNodes.outputNodeId, MaterialNodes.baseColor));
      });
      expect(bad.errorNodeIds, {MaterialNodes.outputNodeId});
      expect(bad.diagnostics.single.message, 'Base Color expects float3, got float2');

      final g = LuminaBlueprintGraph();
      MaterialNodes.ensureOutput(g);
      g.nodes.add(MaterialNodes.create(MaterialNodes.vectorParameter, id: 'v', literals: {'name': 'tint'}));
      g.wires.add(_w('v', 'rgba', MaterialNodes.outputNodeId, MaterialNodes.baseColor));
      expect(MaterialGraphChecker.check(g, _surface).hasErrors, isFalse);
      expect(_generate(g, 'material { name : "M" }\n'), contains('material.baseColor = materialParams.tint;'));
      const translucent = MaterialSurface(blending: BlendingMode.transparent);
      g.nodes.add(MaterialNodes.create(MaterialNodes.constant, id: 'o', literals: {'value': 0.5}));
      g.wires.add(_w('o', 'out', MaterialNodes.outputNodeId, MaterialNodes.opacity));
      expect(_generate(g, 'material { name : "M" }\n', translucent),
          contains('material.baseColor = vec4(materialParams.tint.rgb, 0.5);'));
    });

    test('pins the unlit model does not use are warnings, and are not written', () {
      const unlit = MaterialSurface(shading: FilamatShading.unlit);
      final g = LuminaBlueprintGraph();
      MaterialNodes.ensureOutput(g);
      g.nodes.add(MaterialNodes.create(MaterialNodes.constant, id: 'k', literals: {'value': 1.0}));
      g.wires.add(_w('k', 'out', MaterialNodes.outputNodeId, MaterialNodes.metallic));
      final a = MaterialGraphChecker.check(g, unlit);
      expect(a.hasErrors, isFalse);
      expect(a.diagnostics.single.isError, isFalse);
      expect(a.diagnostics.single.message, contains('not used by the unlit shading model'));
      expect(_generate(g, 'material { name : "M", shadingModel : unlit }\n', unlit), isNot(contains('material.metallic')));
    });

    test('a missing input and an impossible mask are errors', () {
      final a = check((g) {
        g.nodes.addAll([
          MaterialNodes.create(MaterialNodes.power, id: 'pow'),
          MaterialNodes.create(MaterialNodes.constant2, id: 'c2'),
          MaterialNodes.create(MaterialNodes.componentMask, id: 'mask', literals: {'r': false, 'g': false, 'b': true, 'a': false}),
        ]);
        g.wires.addAll([
          _w('pow', 'out', MaterialNodes.outputNodeId, MaterialNodes.metallic),
          _w('c2', 'out', 'mask', 'in'),
          _w('mask', 'out', MaterialNodes.outputNodeId, MaterialNodes.roughness),
        ]);
      });
      expect(a.errorNodeIds, {'pow', 'mask'});
      expect(a.diagnostics.map((d) => d.message), contains(contains("missing input 'Base'")));
      expect(a.diagnostics.map((d) => d.message), contains(contains('has no B channel')));
    });
  });

  test('adding a node, wiring it and editing a constant are one undo step each, graph and source together', () async {
    final project = Directory.systemTemp.createTempSync('material_graph_undo_');
    addTearDown(() => project.deleteSync(recursive: true));
    final file = File('${project.path}/contents/materials/M_Skin.lmas')..createSync(recursive: true);
    file.writeAsBytesSync(LuminaAsset(assetId: 'M_Skin', name: 'M_Skin', type: AssetType.filamat, rawMatSource: _ccBody)
        .toProtoBufferBytes());
    final vm = MaterialEditorViewModel(assetPath: file.path);
    await vm.load();
    final controller = vm.graph..ensureSynced();
    final editor = controller.editor;
    final original = vm.currentCode;

    final k = editor.addNode(MaterialNodes.constant, const Offset(100, 700))!;
    final afterAdd = vm.currentCode;
    expect(controller.transactions.undoLabel, 'Undo Add Constant');
    expect(editor.addWire(fromNodeId: k.id, fromPinId: 'out', toNodeId: MaterialNodes.outputNodeId, toPinId: MaterialNodes.ambientOcclusion),
        isNotNull);
    expect(vm.currentCode, contains('material.ambientOcclusion = 0.0;'));
    expect(editor.setProperty(k.id, 'value', 0.75), isTrue);
    expect(vm.currentCode, contains('material.ambientOcclusion = 0.75;'));
    expect(controller.graph.node(k.id)!.title, '0.75');

    controller.undo();
    expect(vm.currentCode, contains('material.ambientOcclusion = 0.0;'));
    expect(controller.graph.node(k.id)!.literals['value'], 0.0);
    controller.undo();
    expect(vm.currentCode, afterAdd);
    expect(controller.graph.wireInto(MaterialNodes.outputNodeId, MaterialNodes.ambientOcclusion), isNull);
    controller.undo();
    expect(controller.graph.node(k.id), isNull);
    expect(vm.currentCode, original, reason: 'back to the imported source, text and all');
    controller.redo();
    controller.redo();
    controller.redo();
    expect(vm.currentCode, contains('material.ambientOcclusion = 0.75;'));
  });

  group('texture coordinates: the header keeps glTF UVs unflipped', () {
    // Every Lumina mesh carries glTF texture coordinates (v = 0 at the image
    // top), so a material the editor writes declares `flipUV : false`;
    // matc's default (`true`) would draw its textures upside down.
    String? flipUV(String source) => MatSource.parse(source).headerValue('flipUV')?.render();

    LuminaBlueprintGraph textured() {
      final g = LuminaBlueprintGraph();
      MaterialNodes.ensureOutput(g, materialName: 'M_Tex');
      g.nodes.add(MaterialNodes.create(MaterialNodes.textureSample, id: 'tex', literals: {'parameter': 'albedo'}));
      g.wires.add(_w('tex', 'rgba', MaterialNodes.outputNodeId, MaterialNodes.baseColor));
      return g;
    }

    test('the new-material template declares flipUV : false and compiles', () async {
      final project = Directory.systemTemp.createTempSync('material_template_flipuv_');
      addTearDown(() => project.deleteSync(recursive: true));
      final vm = MaterialEditorViewModel(assetPath: '${project.path}/contents/materials/M_New.lmas');
      await vm.load();
      expect(flipUV(vm.currentCode), 'false', reason: vm.currentCode);
      expect(await vm.compile(), isTrue, reason: vm.currentCode);
    });

    test('a header the graph writes declares flipUV : false and keeps it through graph → .mat → graph', () async {
      final generated = _generate(textured(), '');
      expect(flipUV(generated), 'false', reason: generated);
      expect(MatSource.parse(generated).requires, ['uv0']);
      expect(await _compiles(generated), isTrue, reason: generated);
      final again = MaterialGraphParser.parse(generated).graph;
      expect(_generate(again, generated), generated);
    });

    test('a Texture Sample added to the template keeps its flipUV : false', () async {
      final project = Directory.systemTemp.createTempSync('material_template_flipuv_');
      addTearDown(() => project.deleteSync(recursive: true));
      final vm = MaterialEditorViewModel(assetPath: '${project.path}/contents/materials/M_New.lmas');
      await vm.load();
      final generated = _generate(textured(), vm.currentCode);
      expect(flipUV(generated), 'false', reason: generated);
      expect(MatSource.parse(generated).requires, ['uv0']);
    });

    test("a hand-written header's flipUV, or its absence, is kept as written", () {
      const hand = 'material {\n    name : "M_Hand",\n    shadingModel : lit,\n    flipUV : true\n}\n';
      expect(flipUV(_generate(textured(), hand)), 'true');
      const handWithout = 'material {\n    name : "M_Hand",\n    shadingModel : lit\n}\n';
      final generated = _generate(textured(), handWithout);
      expect(flipUV(generated), isNull, reason: "no key keeps matc's meaning: $generated");
      expect(flipUV(_generate(MaterialGraphParser.parse(generated).graph, generated)), isNull);
    });
  });

  test('a re-parse keeps the positions the author gave the nodes', () {
    final before = MaterialGraphParser.parse(_ccBody).graph;
    final sample = before.nodes.firstWhere((n) => n.literals['parameter'] == 'specularMap');
    sample
      ..x = 1234
      ..y = 567;
    final edited = _ccBody.replaceFirst('mr.b;', 'mr.b * 0.5;');
    final after = MaterialGraphParser.parse(edited).graph;
    MaterialGraphLayout.keepPositions(after, before);
    final moved = after.nodes.firstWhere((n) => n.literals['parameter'] == 'specularMap');
    expect((moved.x, moved.y), (1234.0, 567.0));
  });
}
