import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/parameter_panel.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A colour/vector parameter's declared `default: [r, g, b, a]` was
/// replaced by white, so the parameter panel and the preview showed white.
void main() {
  const source = '''material {
    name : "M_DeclaredRed",
    parameters : [
        { type : float, name : roughness, default : 0.35 },
        { type : float4, name : baseColor, default : [0.85, 0.15, 0.10, 1.0] },
        { type : float3, name : tint, default : [0.2, 0.4, 0.6] },
        { type : float4, name : emissive }
    ],
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = materialParams.baseColor;
        material.roughness = materialParams.roughness;
    }
}''';

  late Directory project;
  late File assetFile;

  setUp(() {
    project = Directory.systemTemp.createTempSync('lumina_material_float4_default_');
    final materials = Directory('${project.path}/contents/materials')..createSync(recursive: true);
    final asset = LuminaAsset(assetId: 'M_DeclaredRed', name: 'M_DeclaredRed', type: AssetType.filamat, rawMatSource: source);
    assetFile = File('${materials.path}/M_DeclaredRed.lmas')..writeAsBytesSync(asset.toProtoBufferBytes());
  });

  tearDown(() => project.deleteSync(recursive: true));

  /// Opens the material the way the editor does: the `.lmas` read from disk.
  MaterialEditorViewModel open() =>
      MaterialEditorViewModel(assetPath: assetFile.path, initialAsset: LuminaAsset.fromBytes(assetFile.readAsBytesSync()));

  List<double> valueOf(MaterialEditorViewModel vm, String name) =>
      (vm.parameters.firstWhere((p) => p.name == name).value as List).map((e) => (e as num).toDouble()).toList();

  test('a float4 parameter takes the default its header declares', () {
    final vm = open();
    expect(valueOf(vm, 'baseColor'), [0.85, 0.15, 0.10, 1.0]);
  });

  test('a float3 default fills the colour, alpha stays opaque; no default stays white', () {
    final vm = open();
    expect(valueOf(vm, 'tint'), [0.2, 0.4, 0.6, 1.0]);
    expect(valueOf(vm, 'emissive'), [1.0, 1.0, 1.0, 1.0]);
  });

  testWidgets('the parameter panel shows the declared colour, not white', (tester) async {
    final vm = open();
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: MaterialParameterPanel(viewModel: vm)),
    ));
    await tester.pump();
    expect(find.text('R:0.85 G:0.15 B:0.10'), findsOneWidget);
    expect(find.text('R:0.20 G:0.40 B:0.60'), findsOneWidget);
  });
}
