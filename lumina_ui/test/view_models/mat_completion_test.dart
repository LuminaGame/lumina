import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_completion.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_fuzzy_match.dart';

/// The caret marker in the sources below.
const caret = '‸';

MatCompletionResult suggestAt(String marked, {bool explicit = false}) {
  final offset = marked.indexOf(caret);
  expect(offset, isNonNegative, reason: 'the source needs a caret marker');
  return MatCompletion.suggest(marked.replaceFirst(caret, ''), offset, explicit: explicit);
}

List<String> labels(MatCompletionResult r) => [for (final i in r.items) i.label];

String fragmentSource(String body, {String header = 'name : "M_Test",\n    shadingModel : lit,'}) =>
    '''
material {
    $header
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        $body
    }
}
''';

void main() {
  group('header', () {
    test('suggests header keys at a key position and inserts "key : "', () {
      final r = suggestAt('material {\n    name : "M",\n    shad$caret\n}\n');
      expect(labels(r).first, 'shadingModel');
      final item = r.items.first;
      expect(item.kind, MatCompletionKind.property);
      expect(item.insertText, 'shadingModel : ');
      expect(item.documentation, contains('Default: lit'));
    });

    test('leaves out keys the header already sets', () {
      final r = suggestAt('material {\n    name : "M",\n    $caret\n}\n', explicit: true);
      expect(labels(r), contains('shadingModel'));
      expect(labels(r), contains('blending'));
      expect(labels(r), isNot(contains('name')));
    });

    test('suggests the allowed values after "<key> :"', () {
      final shading = suggestAt('material {\n    shadingModel : $caret\n}\n', explicit: true);
      expect(labels(shading), ['cloth', 'lit', 'specularGlossiness', 'subsurface', 'unlit']);
      final blending = suggestAt('material {\n    blending : tr$caret\n}\n');
      expect(labels(blending), ['transparent']);
      final culling = suggestAt('material {\n    culling : $caret\n}\n', explicit: true);
      expect(labels(culling), containsAll(['none', 'front', 'back', 'frontAndBack']));
    });

    test('suggests vertex attributes inside the requires list', () {
      final r = suggestAt('material {\n    requires : [ uv0, $caret ]\n}\n', explicit: true);
      expect(labels(r), containsAll(['uv0', 'uv1', 'color', 'position', 'tangents', 'custom0', 'custom7']));
      final cust = suggestAt('material {\n    requires : [ cus$caret ]\n}\n');
      expect(labels(cust), hasLength(8));
    });

    test('suggests parameter types after "type :" in a parameters entry', () {
      final r = suggestAt('material {\n    parameters : [\n        { type : sam$caret, name : albedo }\n    ]\n}\n');
      expect(labels(r), containsAll(['sampler2d', 'sampler2dArray', 'samplerExternal', 'samplerCubemap']));
      expect(r.items.every((i) => i.kind == MatCompletionKind.type), isTrue);
      final all = suggestAt('material {\n    parameters : [ { type : $caret } ]\n}\n', explicit: true);
      expect(labels(all), containsAll(['float', 'float2', 'float3', 'float4', 'int', 'bool', 'float3x3', 'float4x4']));
    });

    test('suggests entry keys inside a parameters entry', () {
      final r = suggestAt('material {\n    parameters : [ { type : float4, $caret } ]\n}\n', explicit: true);
      expect(labels(r), containsAll(['name', 'precision']));
      expect(labels(r), isNot(contains('type')));
      expect(labels(r), isNot(contains('shadingModel')));
      final precision = suggestAt('material {\n    parameters : [ { type : float4, precision : $caret } ]\n}\n',
          explicit: true);
      expect(labels(precision), containsAll(['default', 'low', 'medium', 'high']));
    });

    test('suggests nothing right after a complete value', () {
      final r = suggestAt('material {\n    shadingModel : lit $caret\n}\n', explicit: true);
      expect(r.items, isEmpty);
    });
  });

  group('fragment', () {
    test('suggests MaterialInputs fields after "material."', () {
      final r = suggestAt(fragmentSource('material.$caret'));
      expect(labels(r), containsAll(['baseColor', 'roughness', 'metallic', 'normal', 'emissive', 'clearCoat']));
      expect(r.items.every((i) => i.kind == MatCompletionKind.field), isTrue);
      final base = r.items.firstWhere((i) => i.label == 'baseColor');
      expect(base.detail, 'float4');
      expect(base.documentation, contains('float4(1.0)'));
    });

    test('filters MaterialInputs fields by the header shading model', () {
      final unlit = suggestAt(fragmentSource('material.$caret', header: 'shadingModel : unlit,'));
      expect(labels(unlit), unorderedEquals(['baseColor', 'emissive', 'postLightingColor']));
      final cloth = suggestAt(fragmentSource('material.$caret', header: 'shadingModel : cloth,'));
      expect(labels(cloth), containsAll(['sheenColor', 'subsurfaceColor', 'roughness']));
      expect(labels(cloth), isNot(contains('metallic')));
      expect(labels(cloth), isNot(contains('clearCoat')));
      final lit = suggestAt(fragmentSource('material.$caret'));
      expect(labels(lit), isNot(contains('subsurfacePower')));
      expect(labels(lit), isNot(contains('glossiness')));
    });

    test('suggests non-sampler parameters after "materialParams." and samplers after "materialParams_"', () {
      const header = 'shadingModel : lit,\n    parameters : [\n        { type : float4, name : tint },\n'
          '        { type : sampler2d, name : albedoMap },\n        { type : float, name : gloss }\n    ],';
      final dot = suggestAt(fragmentSource('material.baseColor = materialParams.$caret', header: header));
      expect(labels(dot), unorderedEquals(['gloss', 'tint']));
      final underscore = suggestAt(fragmentSource('material.baseColor = materialParams_$caret', header: header));
      expect(labels(underscore), ['materialParams_albedoMap']);
      expect(underscore.items.single.detail, 'sampler2d');
    });

    test('suggests header variables as variable_<name> and constants as materialConstants_<name>', () {
      const header = 'variables : [ eyeDirection, { name : eyeColor, precision : medium } ],\n'
          '    constants : [ { name : overrideAlpha, type : bool } ],';
      final v = suggestAt(fragmentSource('float4 d = variable_$caret', header: header));
      expect(labels(v), unorderedEquals(['variable_eyeColor', 'variable_eyeDirection']));
      final c = suggestAt(fragmentSource('if (materialConst$caret', header: header));
      expect(labels(c).first, 'materialConstants_overrideAlpha');
    });

    test('suggests locals declared earlier in the block, not later ones', () {
      final src = fragmentSource('float3 tintColor = vec3(1.0);\n        tint$caret\n        float tintLater = 0.0;');
      final r = suggestAt(src);
      expect(labels(r), contains('tintColor'));
      expect(labels(r), isNot(contains('tintLater')));
      expect(r.items.first.label, 'tintColor');
      expect(r.items.first.kind, MatCompletionKind.variable);
      final param = suggestAt(fragmentSource('mat$caret'));
      expect(r.items.where((i) => i.label == 'material'), isEmpty);
      expect(param.items.firstWhere((i) => i.label == 'material').kind, MatCompletionKind.parameter);
    });

    test('suggests fragment functions with their signature and puts the caret in the parentheses', () {
      final r = suggestAt(fragmentSource('float3 p = getW$caret'));
      expect(labels(r), contains('getWorldPosition'));
      expect(labels(r), isNot(contains('getWorldFromModelMatrix')), reason: 'vertex only');
      final pos = r.items.firstWhere((i) => i.label == 'getWorldPosition');
      expect(pos.kind, MatCompletionKind.function);
      expect(pos.detail, 'float3 getWorldPosition()');
      expect(pos.insertText, 'getWorldPosition()');
      expect(pos.caretOffset, 'getWorldPosition()'.length);
      final mul = suggestAt(fragmentSource('mulMat4$caret')).items.first;
      expect(mul.label, 'mulMat4x4Float3');
      expect(mul.caretOffset, 'mulMat4x4Float3('.length);
      final tex = suggestAt(fragmentSource('textu$caret')).items.first;
      expect(tex.label, 'texture');
      expect(tex.insertText, 'texture()');
      expect(tex.caretOffset, 'texture('.length);
    });

    test('offers GLSL built-ins, types, keywords and constants', () {
      expect(labels(suggestAt(fragmentSource('norm$caret'))), contains('normalize'));
      expect(labels(suggestAt(fragmentSource('flo$caret'))), containsAll(['float', 'float3', 'float4x4']));
      expect(labels(suggestAt(fragmentSource('disc$caret'))), contains('discard'));
      expect(labels(suggestAt(fragmentSource('HALF$caret'))), contains('HALF_PI'));
      expect(labels(suggestAt(fragmentSource('satu$caret'))), contains('saturate'));
      expect(labels(suggestAt(fragmentSource('prepareM$caret'))), contains('prepareMaterial'));
    });

    test('matches camelCase word starts', () {
      final r = suggestAt(fragmentSource('gwp$caret'));
      expect(labels(r).first, 'getWorldPosition');
      expect(r.items.first.highlights, [0, 3, 8]);
    });

    test('ranks an exact-case prefix above a case-insensitive prefix above word starts above substrings', () {
      expect(matchLabel('getWorldPosition', 'getW')!.tier, 0);
      expect(matchLabel('getWorldPosition', 'GETW')!.tier, 1);
      expect(matchLabel('getWorldPosition', 'gwp')!.tier, 2);
      expect(matchLabel('getWorldPosition', 'orldPos')!.tier, 3);
      expect(matchLabel('getWorldPosition', 'xyz'), isNull);
      final items = MatCompletion.rank([
        const MatCompletionItem(label: 'aposition', kind: MatCompletionKind.function),
        const MatCompletionItem(label: 'getPosition', kind: MatCompletionKind.function),
        const MatCompletionItem(label: 'Position', kind: MatCompletionKind.function),
        const MatCompletionItem(label: 'position', kind: MatCompletionKind.function),
      ], 'pos');
      expect([for (final i in items) i.label], ['position', 'Position', 'getPosition', 'aposition']);
    });

    test('suggests nothing with an empty prefix unless invoked explicitly', () {
      expect(suggestAt(fragmentSource('float x = $caret')).items, isEmpty);
      expect(suggestAt(fragmentSource('float x = $caret'), explicit: true).items, isNotEmpty);
    });
  });

  group('vertex', () {
    const vertexSource = '''
material {
    shadingModel : lit,
    variables : [ eyeDirection ],
    requires : [ uv0 ]
}
vertex {
    void materialVertex(inout MaterialVertexInputs material) {
        ‸
    }
}
''';

    test('suggests MaterialVertexInputs fields and the header variables after "material."', () {
      final r = suggestAt(vertexSource.replaceFirst(caret, 'material.$caret'));
      expect(labels(r), containsAll(['worldPosition', 'worldNormal', 'uv0', 'clipSpaceTransform', 'eyeDirection']));
      expect(labels(r), isNot(contains('variable0')));
      expect(labels(r), isNot(contains('baseColor')));
    });

    test('suggests vertex functions and leaves out fragment-only ones', () {
      final r = suggestAt(vertexSource.replaceFirst(caret, 'get$caret'));
      expect(labels(r), containsAll(['getPosition', 'getCustom0', 'getCustom7', 'getWorldFromModelMatrix']));
      expect(labels(r), isNot(contains('getWorldPosition')));
      expect(labels(r), isNot(contains('getUV0')));
      expect(labels(r), isNot(contains('prepareMaterial')));
      expect(labels(suggestAt(vertexSource.replaceFirst(caret, 'variable_$caret'))), isEmpty);
    });
  });

  group('comments, strings and ranges', () {
    test('suggests nothing inside comments or strings', () {
      expect(suggestAt(fragmentSource('// getW$caret')).items, isEmpty);
      expect(suggestAt(fragmentSource('/* material.$caret */')).items, isEmpty);
      expect(suggestAt('material {\n    name : "shad$caret",\n}\n').items, isEmpty);
      expect(suggestAt('material {\n    // shad$caret\n}\n').items, isEmpty);
      expect(suggestAt(fragmentSource('/* closed */ getW$caret')).items, isNotEmpty);
    });

    test('replaces the whole identifier around the caret', () {
      final src = fragmentSource('float3 p = getWo${caret}rldPos;');
      final r = suggestAt(src);
      final clean = src.replaceFirst(caret, '');
      expect(clean.substring(r.replaceStart, r.replaceEnd), 'getWorldPos');
      final dot = suggestAt(fragmentSource('material.rough$caret = 1.0;'));
      expect(fragmentSource('material.rough = 1.0;').substring(dot.replaceStart, dot.replaceEnd), 'rough');
      expect(labels(dot).first, 'roughness');
    });

    test('suggests the block snippets at the top level', () {
      final r = suggestAt('material {\n    name : M,\n}\n\nfrag$caret');
      expect(labels(r), ['fragment']);
      final snippet = r.items.single;
      expect(snippet.kind, MatCompletionKind.snippet);
      expect(snippet.insertText, contains('void material(inout MaterialInputs material)'));
      expect(snippet.insertText.substring(0, snippet.caretOffset), endsWith('prepareMaterial(material);\n        '));
    });

    test('answers a 200-line source within a few milliseconds per keystroke', () {
      final body = List.generate(190, (i) => 'float v$i = saturate($i.0) * getUserTimeMod(2.0);').join('\n        ');
      final src = fragmentSource('$body\n        getW$caret');
      suggestAt(src); // warm the static tables
      final sw = Stopwatch()..start();
      for (var k = 0; k < 20; k++) {
        // A new text version each time, as typing produces.
        suggestAt(src.replaceFirst('v0 ', 'v0${'x' * (k + 1)} '));
      }
      sw.stop();
      expect(sw.elapsedMicroseconds / 20, lessThan(5000));
    });
  });
}
