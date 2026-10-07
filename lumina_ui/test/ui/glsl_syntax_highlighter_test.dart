import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material.dart';
import 'package:lumina_core/lumina_core.dart' show AssetType, LuminaAsset;
import 'package:shadcn_flutter/shadcn_flutter.dart';

const _source = '''material {
    name : "M_Triplanar",
    shadingModel : lit,
    parameters : [ { type : sampler2d, name : mapColor } ]
}
fragment {
    void material(inout MaterialInputs material) {
        // world-space UVs
        vec3 p = getUserWorldPosition() * 1.5;
        if (p.x > 0.0) { p.x = 2.0; }
        prepareMaterial(material);
        material.baseColor = texture(materialParams_mapColor, p.xz);
    }
}''';

void main() {
  GlslTokenKind kindOf(String word, {int occurrence = 0}) {
    var at = -1;
    for (var i = 0; i <= occurrence; i++) {
      at = _source.indexOf(word, at + 1);
    }
    final t = GlslSyntaxHighlighter.tokenize(_source).firstWhere((t) => t.start <= at && at < t.end);
    return t.kind;
  }

  test('the .mat header, GLSL and Filament API each get their colour', () {
    expect(kindOf('name'), GlslTokenKind.headerKey);
    expect(kindOf('shadingModel'), GlslTokenKind.headerKey);
    expect(kindOf('"M_Triplanar"'), GlslTokenKind.string);
    expect(kindOf('sampler2d'), GlslTokenKind.type);
    expect(kindOf('fragment'), GlslTokenKind.headerKey);
    expect(kindOf('void'), GlslTokenKind.type);
    expect(kindOf('MaterialInputs'), GlslTokenKind.type);
    expect(kindOf('inout'), GlslTokenKind.keyword);
    expect(kindOf('// world-space UVs'), GlslTokenKind.comment);
    expect(kindOf('vec3'), GlslTokenKind.type);
    expect(kindOf('getUserWorldPosition'), GlslTokenKind.builtin);
    expect(kindOf('1.5'), GlslTokenKind.number);
    expect(kindOf('if'), GlslTokenKind.keyword);
    expect(kindOf('prepareMaterial'), GlslTokenKind.builtin);
    expect(kindOf('texture'), GlslTokenKind.function);
    expect(kindOf('materialParams_mapColor'), GlslTokenKind.builtin);
    expect(kindOf('baseColor'), GlslTokenKind.plain);
  });

  test('the highlighted spans spell the source exactly', () {
    final span = GlslSyntaxHighlighter.highlight(_source, const TextStyle(fontSize: 13));
    expect(span.toPlainText(), _source);
    expect(span.children!.whereType<TextSpan>().any((s) => s.style?.color == GlslSyntaxHighlighter.palette[GlslTokenKind.comment]),
        isTrue);
  });

  testWidgets('the material editor draws its source with syntax colours', (tester) async {
    final vm = MaterialEditorViewModel(
      assetPath: 'contents/materials/M_Triplanar.lmas',
      initialAsset: LuminaAsset(assetId: 'M_Triplanar', name: 'M_Triplanar', type: AssetType.filamat, rawMatSource: _source),
    );
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SizedBox(width: 1400, height: 900, child: MaterialSubEditor(assetName: 'M_Triplanar', viewModel: vm))),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    final editor = tester.widget<MaterialGlslEditorWidget>(find.byType(MaterialGlslEditorWidget));
    expect(editor.controller, isA<GlslCodeController>());
    final span = editor.controller.buildTextSpan(
        context: tester.element(find.byType(MaterialGlslEditorWidget)), style: const TextStyle(), withComposing: false);
    expect(span.children, isNotEmpty);
  });
}
