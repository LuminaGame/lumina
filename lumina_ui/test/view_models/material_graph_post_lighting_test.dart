import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart' show FilamatShading;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/material_graph_parser.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';

/// The Material node's Post Lighting Color and Post Lighting Mix pins: they
/// write MaterialInputs.postLightingColor / postLightingMixFactor, for every
/// shading model including unlit, and the header's postLightingBlending says
/// how the colour is blended.
const _unlit = MaterialSurface(shading: FilamatShading.unlit);
const _header = 'material { name : "M_PostLight", shadingModel : unlit }\n';

LuminaBlueprintWire _w(String from, String fromPin, String to, String toPin) =>
    LuminaBlueprintWire(id: '$from$fromPin$to$toPin', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

LuminaBlueprintGraph _graph({bool color = true, bool mix = true}) {
  final g = LuminaBlueprintGraph();
  MaterialNodes.ensureOutput(g);
  g.nodes.addAll([
    MaterialNodes.create(MaterialNodes.constant3, id: 'base', literals: {'value': [0.8, 0.1, 0.1]}),
    MaterialNodes.create(MaterialNodes.constant3, id: 'post', literals: {'value': [0.1, 0.2, 0.9]}),
    MaterialNodes.create(MaterialNodes.constant, id: 'mix', literals: {'value': 0.25}),
  ]);
  g.wires.add(_w('base', 'out', MaterialNodes.outputNodeId, MaterialNodes.baseColor));
  if (color) g.wires.add(_w('post', 'out', MaterialNodes.outputNodeId, MaterialNodes.postLightingColor));
  if (mix) g.wires.add(_w('mix', 'out', MaterialNodes.outputNodeId, MaterialNodes.postLightingMix));
  return g;
}

Future<bool> _compiles(String source) => MaterialEditorViewModel(
      assetPath: '${Directory.systemTemp.path}/does_not_matter.lmas',
      initialAsset: LuminaAsset(assetId: 'M', name: 'M_PostLight', type: AssetType.filamat, rawMatSource: source),
    ).compile();

void main() {
  test('the unlit model uses the post lighting pins, as matc does', () {
    expect(_unlit.uses(MaterialNodes.postLightingColor), isTrue);
    expect(_unlit.uses(MaterialNodes.postLightingMix), isTrue);
    expect(_unlit.uses(MaterialNodes.metallic), isFalse);
    expect(MaterialNodes.outputFields[MaterialNodes.postLightingMix], 'postLightingMixFactor');
  });

  test('an unlit graph writes both fields and the material compiles', () async {
    final source = MaterialGraphCodegen.generate(_graph(), currentSource: _header, surface: _unlit);
    expect(source, contains('material.postLightingColor = vec4(vec3(0.1, 0.2, 0.9), 1.0);'));
    expect(source, contains('material.postLightingMixFactor = 0.25;'));
    expect(await _compiles(source), isTrue);
  });

  test('a mix without a colour is not written (Filament has no field for it then)', () async {
    final source = MaterialGraphCodegen.generate(_graph(color: false), currentSource: _header, surface: _unlit);
    expect(source, isNot(contains('postLighting')));
    expect(await _compiles(source), isTrue);
  });

  test('the generated source parses back into the same pins', () {
    final source = MaterialGraphCodegen.generate(_graph(), currentSource: _header, surface: _unlit);
    final parsed = MaterialGraphParser.parse(source);
    expect(parsed.fallbackReason, isNull);
    expect(parsed.graph.wireInto(MaterialNodes.outputNodeId, MaterialNodes.postLightingColor), isNotNull);
    expect(parsed.graph.wireInto(MaterialNodes.outputNodeId, MaterialNodes.postLightingMix), isNotNull);
  });

  test('the header setting writes postLightingBlending and only accepts what matc accepts', () async {
    final dir = Directory.systemTemp.createTempSync('lumina_post_lighting_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final source = MaterialGraphCodegen.generate(_graph(), currentSource: _header, surface: _unlit);
    final vm = MaterialEditorViewModel(
      assetPath: '${dir.path}/M_PostLight.lmas',
      initialAsset: LuminaAsset(assetId: 'M', name: 'M_PostLight', type: AssetType.filamat, rawMatSource: source),
    );
    expect(vm.postLightingBlending, 'transparent');
    expect(MaterialEditorViewModel.postLightingBlendings, containsAll(['opaque', 'transparent', 'add', 'multiply', 'screen']));
    await vm.updateHeaderSettings(postLightingBlending: 'screen');
    expect(vm.currentCode, contains('postLightingBlending : screen'));
    expect(vm.postLightingBlending, 'screen');
    expect(vm.syntaxStatus, startsWith('Compile OK'));
    await vm.updateHeaderSettings(postLightingBlending: 'add');
    expect(RegExp('postLightingBlending').allMatches(vm.currentCode).length, 1);
    expect(() => vm.updateHeaderSettings(postLightingBlending: 'dynamicLighting'), throwsArgumentError);
  });
}
