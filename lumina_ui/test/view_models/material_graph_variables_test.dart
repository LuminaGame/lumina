import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaBlueprintGraph, LuminaBlueprintWire;
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_source.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_parser.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_types.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';

/// Custom vertex → fragment interpolants (`variables`) in the material graph:
/// Set Vertex Variable nodes are the vertex block, Vertex Variable nodes read
/// the interpolants in the fragment, and the source round-trips.
const _surface = MaterialSurface();

/// What feeds each Material pin and each Set Vertex Variable, blind to node
/// ids, positions and local names.
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
        parts.add('${p.id}=${n.literals[p.id] ?? p.defaultValue}');
      }
    }
    final settings = Map.of(n.literals)
      ..removeWhere((k, _) => inputs.any((p) => p.id == k) || k == 'varName' || k == 'declOrder' || k == 'declType');
    final name = n.registryId.replaceFirst('mat_', '');
    return '$name${settings.isEmpty ? '' : settings}.$pin(${parts.join(', ')})';
  }

  final out = g.node(MaterialNodes.outputNodeId)!;
  final setters = [for (final n in g.nodes) if (n.registryId == MaterialNodes.setVertexVariable) n]
    ..sort((a, b) => '${a.literals['name']}'.compareTo('${b.literals['name']}'));
  return [
    for (final p in MaterialNodes.inputsOf(out))
      if (g.wireInto(out.id, p.id) case final w?) '${p.id} <- ${node(w.fromNodeId, w.fromPinId, {})}',
    for (final s in setters)
      'vertex ${s.literals['name']} <- ${switch (g.wireInto(s.id, 'value')) {
        final w? => node(w.fromNodeId, w.fromPinId, {}),
        null => '(unwired)',
      }}',
  ].join('\n');
}

String _generate(LuminaBlueprintGraph g, String source, [MaterialSurface surface = _surface]) =>
    MaterialGraphCodegen.generate(g, currentSource: source, surface: surface);

LuminaBlueprintWire _w(String from, String fromPin, String to, String toPin) =>
    LuminaBlueprintWire(id: '$from$fromPin$to$toPin', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

const _header = 'material {\n    name : "M_HeightTint",\n    shadingModel : unlit\n}\n';

/// World height → a two-colour gradient handed to the fragment as
/// `heightTint`, the vertex colour as `paint`; the fragment multiplies them.
LuminaBlueprintGraph _heightTintGraph() {
  final g = LuminaBlueprintGraph();
  MaterialNodes.ensureOutput(g, materialName: 'M_HeightTint');
  g.nodes.addAll([
    MaterialNodes.create(MaterialNodes.worldPosition, id: 'world'),
    MaterialNodes.create(MaterialNodes.componentMask, id: 'height', literals: {'r': false, 'g': true, 'b': false, 'a': false}),
    MaterialNodes.create(MaterialNodes.scalarParameter, id: 'scale', literals: {'name': 'heightScale', 'default': 0.8}),
    MaterialNodes.create(MaterialNodes.multiply, id: 'scaled'),
    MaterialNodes.create(MaterialNodes.add, id: 'shifted', literals: {'b': 0.5}),
    MaterialNodes.create(MaterialNodes.clamp, id: 'alpha'),
    MaterialNodes.create(MaterialNodes.constant3, id: 'low', literals: {'value': [0.1, 0.3, 1.0]}),
    MaterialNodes.create(MaterialNodes.constant3, id: 'high', literals: {'value': [1.0, 0.45, 0.1]}),
    MaterialNodes.create(MaterialNodes.lerp, id: 'gradient'),
    MaterialNodes.create(MaterialNodes.setVertexVariable, id: 'set_tint', literals: {'name': 'heightTint'}),
    MaterialNodes.create(MaterialNodes.vertexColor, id: 'vcolor'),
    MaterialNodes.create(MaterialNodes.setVertexVariable, id: 'set_paint', literals: {'name': 'paint'}),
    MaterialNodes.create(MaterialNodes.vertexVariable, id: 'get_tint', literals: {'name': 'heightTint'}),
    MaterialNodes.create(MaterialNodes.vertexVariable, id: 'get_paint', literals: {'name': 'paint'}),
    MaterialNodes.create(MaterialNodes.multiply, id: 'tinted'),
  ]);
  g.wires.addAll([
    _w('world', 'out', 'height', 'in'),
    _w('height', 'out', 'scaled', 'a'),
    _w('scale', 'out', 'scaled', 'b'),
    _w('scaled', 'out', 'shifted', 'a'),
    _w('shifted', 'out', 'alpha', 'in'),
    _w('low', 'out', 'gradient', 'a'),
    _w('high', 'out', 'gradient', 'b'),
    _w('alpha', 'out', 'gradient', 'alpha'),
    _w('gradient', 'out', 'set_tint', 'value'),
    _w('vcolor', 'rgba', 'set_paint', 'value'),
    _w('get_tint', 'rgb', 'tinted', 'a'),
    _w('get_paint', 'rgb', 'tinted', 'b'),
    _w('tinted', 'out', MaterialNodes.outputNodeId, MaterialNodes.baseColor),
  ]);
  return g;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a graph with vertex variables', () {
    test('writes variables, the vertex block and variable_ reads, and reads back as the same graph', () {
      final g = _heightTintGraph();
      final analysis = MaterialGraphChecker.check(g, const MaterialSurface(shading: FilamatShading.unlit));
      expect(analysis.hasErrors, isFalse, reason: '${analysis.diagnostics}');
      expect(analysis.vertexReachable, containsAll(['world', 'height', 'scale', 'gradient', 'set_tint', 'vcolor']));
      expect(analysis.vertexReachable, isNot(contains('get_tint')));

      final generated = _generate(g, _header, const MaterialSurface(shading: FilamatShading.unlit));
      final src = MatSource.parse(generated);
      expect(src.variables.map((v) => v.name), ['heightTint', 'paint']);
      expect(src.requires, ['color']);
      expect(src.parameters.map((p) => p.name), ['heightScale']);
      final vertex = src.block('vertex')!.body;
      expect(vertex, contains('void materialVertex(inout MaterialVertexInputs material)'));
      expect(vertex, contains('mulMat4x4Float3(getUserWorldFromWorldMatrix(), material.worldPosition.xyz).xyz'));
      expect(vertex, contains('materialParams.heightScale'));
      expect(vertex, matches(RegExp(r'material\.heightTint = vec4\(.*, 1\.0\);')));
      expect(vertex, contains('material.paint = material.color;'));
      expect(vertex, isNot(contains('getColor()')));
      final fragment = src.block('fragment')!.body;
      expect(fragment, contains('variable_heightTint.rgb'));
      expect(fragment, contains('variable_paint.rgb'));
      expect(fragment, isNot(contains('getUserWorldFromWorldMatrix')));
      // The vertex block comes before the fragment.
      expect(generated.indexOf('vertex {'), lessThan(generated.indexOf('fragment {')));

      final again = MaterialGraphParser.parse(generated);
      expect(again.isFallback, isFalse, reason: again.fallbackReason);
      expect(describe(again.graph), describe(g));
      expect(again.graph.nodes.where((n) => n.registryId == MaterialNodes.vertexVariable), hasLength(2));
      expect(_generate(again.graph, generated, const MaterialSurface(shading: FilamatShading.unlit)), generated);
    });

    test('the generated source compiles with matc into a material that reads the vertex colour', () async {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      addTearDown(engine.dispose);
      final dir = Directory.systemTemp.createTempSync('material_graph_variables_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final generated = _generate(_heightTintGraph(), _header, const MaterialSurface(shading: FilamatShading.unlit));

      Future<MaterialEditorViewModel> open(String source) async {
        final file = File('${dir.path}/M_HeightTint.lmas');
        file.writeAsBytesSync(LuminaAsset(
          assetId: 'M_HeightTint',
          name: 'M_HeightTint',
          type: AssetType.filamat,
          rawMatSource: source,
          rawPayload: Uint8List.fromList([1]),
        ).toProtoBufferBytes());
        final vm = MaterialEditorViewModel(assetPath: file.path);
        await vm.load();
        return vm;
      }

      final vm = await open(generated);
      expect(await vm.compile(), isTrue, reason: '${vm.issues.map((i) => i.message).join('\n')}\n$generated');
      final material = FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: vm.compiledBytes!);
      expect(material.shading, FilamatShading.unlit);
      expect(material.requiredAttributes, contains(VertexAttribute.color));
      expect(material.hasParameter('heightScale'), isTrue);
      material.dispose();

      // The interpolant is what joins the stages: written under another name
      // in the vertex block, matc rejects it.
      final broken = generated.replaceFirst('material.paint =', 'material.nowhere =');
      final vm2 = await open(broken);
      expect(await vm2.compile(), isFalse);
      expect(vm2.issues.any((i) => i.message.contains('nowhere')), isTrue, reason: vm2.issues.map((i) => i.message).join('\n'));
    });

    test('deleting the last setter removes the vertex block and the variables entry', () {
      final g = _heightTintGraph();
      final generated = _generate(g, _header, const MaterialSurface(shading: FilamatShading.unlit));
      final parsed = MaterialGraphParser.parse(generated).graph;
      parsed.nodes.removeWhere((n) =>
          n.registryId == MaterialNodes.setVertexVariable || n.registryId == MaterialNodes.vertexVariable);
      parsed.wires.removeWhere((w) => parsed.node(w.fromNodeId) == null || parsed.node(w.toNodeId) == null);
      final code = _generate(parsed, generated, const MaterialSurface(shading: FilamatShading.unlit));
      final src = MatSource.parse(code);
      expect(src.block('vertex'), isNull);
      expect(src.headerValue('variables'), isNull);
    });
  });

  group('a hand-written material with variables', () {
    const source = '''material {
    name : M_HandTint,
    shadingModel : unlit,
    variables : [ tint, { name : pulse, precision : medium } ],
    parameters : [ { type : float, name : strength, default : 0.5 } ]
}

vertex {
    void materialVertex(inout MaterialVertexInputs material) {
        vec3 p = material.worldPosition.xyz * 0.5;
        material.tint = vec4(p, 1.0);
        material.pulse = vec4(sin(getUserTime().x));
    }
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(variable_tint.rgb * variable_pulse.r * materialParams.strength, 1.0);
    }
}
''';

    test('opens as nodes: setters, readers, one Time node and a camera-relative WorldPosition', () {
      final result = MaterialGraphParser.parse(source);
      expect(result.isFallback, isFalse, reason: result.fallbackReason);
      final g = result.graph;
      final setters = g.nodes.where((n) => n.registryId == MaterialNodes.setVertexVariable).toList();
      expect(setters.map((n) => n.literals['name']), unorderedEquals(['tint', 'pulse']));
      expect(setters.firstWhere((n) => n.literals['name'] == 'pulse').literals['precision'], 'medium');
      expect(g.nodes.where((n) => n.registryId == MaterialNodes.vertexVariable).map((n) => n.literals['name']),
          unorderedEquals(['tint', 'pulse']));
      expect(g.nodes.where((n) => n.registryId == MaterialNodes.time), hasLength(1));
      final world = g.nodes.singleWhere((n) => n.registryId == MaterialNodes.worldPosition);
      expect(world.literals['space'], 'camera_relative');
      expect(g.nodes.where((n) => n.registryId == MaterialNodes.customFragment), isEmpty);
      final d = describe(g);
      expect(d, contains('vertex tint <- multiply'));
      expect(d, contains('world_position{space: camera_relative}'));
      expect(d, contains('vertex pulse <- custom'));
      expect(MaterialGraphChecker.check(g, const MaterialSurface(shading: FilamatShading.unlit)).hasErrors, isFalse,
          reason: '${MaterialGraphChecker.check(g, const MaterialSurface(shading: FilamatShading.unlit)).diagnostics}');

      final generated = _generate(g, source, const MaterialSurface(shading: FilamatShading.unlit));
      expect(generated, contains('{ name : pulse, precision : medium }'));
      expect(generated, contains('material.worldPosition.xyz'));
      final again = MaterialGraphParser.parse(generated);
      expect(again.isFallback, isFalse, reason: again.fallbackReason);
      expect(describe(again.graph), d);
    });

    test('a vertex block that moves vertices stays as written; its variables are still read as nodes', () {
      final moving = source.replaceFirst(
          '        material.tint = vec4(p, 1.0);', '        material.worldPosition.xyz += p;\n        material.tint = vec4(p, 1.0);');
      final result = MaterialGraphParser.parse(moving);
      expect(result.isFallback, isFalse, reason: result.fallbackReason);
      final g = result.graph;
      expect(g.nodes.where((n) => n.registryId == MaterialNodes.setVertexVariable), isEmpty);
      expect(g.nodes.where((n) => n.registryId == MaterialNodes.vertexVariable), hasLength(2));
      expect(result.notes.join('\n'), contains('vertex block is kept as written'));
      const unlit = MaterialSurface(shading: FilamatShading.unlit);
      expect(MaterialGraphChecker.check(g, unlit).hasErrors, isFalse);
      final generated = _generate(g, moving, unlit);
      expect(generated, contains('material.worldPosition.xyz += p;'));
      expect(generated, contains('{ name : pulse, precision : medium }'));

      // A setter would overwrite the hand-written block: an error, not a rewrite.
      g.nodes.add(MaterialNodes.create(MaterialNodes.setVertexVariable, id: 'extra', literals: {'name': 'tint'}));
      g.nodes.add(MaterialNodes.create(MaterialNodes.constant4, id: 'c4'));
      g.wires.add(_w('c4', 'out', 'extra', 'value'));
      final diagnostics = MaterialGraphChecker.check(g, unlit).diagnostics.where((d) => d.nodeId == 'extra');
      expect(diagnostics.map((d) => d.message).join('\n'), contains('hand-written'));
    });
  });

  group('checker', () {
    LuminaBlueprintGraph base() {
      final g = LuminaBlueprintGraph();
      MaterialNodes.ensureOutput(g);
      return g;
    }

    List<String> errorsOn(LuminaBlueprintGraph g, String nodeId) => [
          for (final d in MaterialGraphChecker.check(g, _surface).diagnostics)
            if (d.isError && d.nodeId == nodeId) d.message,
        ];

    test('fragment-only expressions cannot feed a vertex variable', () {
      final g = base();
      g.nodes.addAll([
        MaterialNodes.create(MaterialNodes.textureSample, id: 'tex', literals: {'parameter': 'albedo'}),
        MaterialNodes.create(MaterialNodes.fresnel, id: 'fres'),
        MaterialNodes.create(MaterialNodes.multiply, id: 'mul'),
        MaterialNodes.create(MaterialNodes.setVertexVariable, id: 'set', literals: {'name': 'v'}),
      ]);
      g.wires.addAll([_w('tex', 'rgb', 'mul', 'a'), _w('fres', 'out', 'mul', 'b'), _w('mul', 'out', 'set', 'value')]);
      expect(errorsOn(g, 'tex').join(), contains('not available in the vertex stage'));
      expect(errorsOn(g, 'fres').join(), contains('not available in the vertex stage'));
      expect(errorsOn(g, 'mul'), isEmpty);
    });

    test('a Vertex Variable nothing writes or declares is an error', () {
      final g = base();
      g.nodes.add(MaterialNodes.create(MaterialNodes.vertexVariable, id: 'get', literals: {'name': 'ghost'}));
      g.wires.add(_w('get', 'rgb', MaterialNodes.outputNodeId, MaterialNodes.baseColor));
      expect(errorsOn(g, 'get').join(), contains("'ghost'"));
    });

    test("more variables than matc allows, and a duplicate name, are errors", () {
      final g = base();
      for (var k = 0; k < 6; k++) {
        g.nodes.add(MaterialNodes.create(MaterialNodes.setVertexVariable, id: 's$k', literals: {'name': 'v$k'}));
        g.nodes.add(MaterialNodes.create(MaterialNodes.constant, id: 'c$k'));
        g.wires.add(_w('c$k', 'out', 's$k', 'value'));
      }
      expect(errorsOn(g, 's4'), isEmpty);
      expect(errorsOn(g, 's5').join(), contains('at most 5'));

      // With the colour attribute required, only four.
      g.nodes.add(MaterialNodes.create(MaterialNodes.vertexColor, id: 'vc'));
      g.wires.removeWhere((w) => w.toNodeId == 's0');
      g.wires.add(_w('vc', 'rgba', 's0', 'value'));
      expect(errorsOn(g, 's4').join(), contains('at most 4'));

      g.nodes.firstWhere((n) => n.id == 's1').literals['name'] = 'v0';
      expect(errorsOn(g, 's1').join(), contains("'v0'"));
    });
  });
}
