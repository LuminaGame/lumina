import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/parameter_panel.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material_sub_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

class MockParamPanelCompilerRunner implements FilamatCompilerRunner {
  @override
  Future<MaterialCompileResult> compile({
    required String name,
    required String source,
    String? includeDirectory,
  }) async {
    return MaterialCompileResult(bytes: Uint8List.fromList([0x46, 0x49, 0x4C, 0x41, 0x01, 0x02]));
  }
}

void main() {
  testWidgets('MaterialParameterPanel renders reflected float, color, and texture rows', (tester) async {
    const source = '''material {
    name : "M_Props",
    parameters : [
        { type : float, name : roughness, default : 0.7 },
        { type : float4, name : baseColor, default : [1.0, 0.0, 0.0, 1.0] },
        { type : sampler2d, name : normalMap }
    ],
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
    }
}''';

    final asset = LuminaAsset(
      assetId: 'M_Props',
      name: 'M_Props',
      type: AssetType.filamat,
      rawMatSource: source,
    );

    final vm = MaterialEditorViewModel(
      assetPath: 'contents/materials/M_Props.lmas',
      initialAsset: asset,
      compilerRunner: MockParamPanelCompilerRunner(),
    );

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: MaterialParameterPanel(
            viewModel: vm,
          ),
        ),
      ),
    );

    // The header settings moved under the preview (MaterialSettingsSection).
    expect(find.text('MATERIAL SETTINGS'), findsNothing);
    expect(find.text('PARAMETERS & UNIFORMS'), findsOneWidget);
    expect(find.text('roughness'), findsOneWidget);
    expect(find.text('baseColor'), findsOneWidget);
    expect(find.text('normalMap'), findsOneWidget);
  });

  testWidgets('MaterialSubEditor allows switching preview geometry between Sphere, Cube, Cylinder, Plane, and Custom', (tester) async {
    final asset = LuminaAsset(
      assetId: 'M_Preview',
      name: 'M_Preview',
      type: AssetType.filamat,
      rawMatSource: '''material {
    name : "M_Preview"
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
    }
}''',
    );

    final vm = MaterialEditorViewModel(
      assetPath: 'contents/materials/M_Preview.lmas',
      initialAsset: asset,
      compilerRunner: MockParamPanelCompilerRunner(),
    );

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: MaterialSubEditor(
            assetName: 'M_Preview',
            assetPath: 'contents/materials/M_Preview.lmas',
            viewModel: vm,
          ),
        ),
      ),
    );

    expect(find.text('Sphere'), findsOneWidget);
    expect(find.text('Cube'), findsOneWidget);
    expect(find.text('Cylinder'), findsOneWidget);
    expect(find.text('Plane'), findsOneWidget);

    // Tap Cube
    await tester.tap(find.text('Cube'));
    await tester.pump();

    // Tap Plane
    await tester.tap(find.text('Plane'));
    await tester.pump();
  });
}
