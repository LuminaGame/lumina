import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/preview_mesh_factory.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

const _source = '''material {
    name : "M_Size",
    shadingModel : lit
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
    }
}''';

void main() {
  test('each primitive is scaled so its largest dimension is the asked size', () {
    for (final shape in [PreviewShape.sphere, PreviewShape.cube, PreviewShape.cylinder, PreviewShape.plane]) {
      final mesh = PreviewMeshFactory.build(shape, size: 200.0);
      expect(mesh.largestDimension, closeTo(200.0, 0.01), reason: '$shape');
      expect(mesh.vertexCount, PreviewMeshFactory.build(shape).vertexCount);
    }
    expect(PreviewMeshFactory.build(PreviewShape.sphere).largestDimension, closeTo(2.0, 1e-6),
        reason: 'without a size the unit-scale primitive stays');
  });

  test('grid cells are a round length', () {
    expect(SubEditor3DViewport.roundGridStep(2.5), 2.0);
    expect(SubEditor3DViewport.roundGridStep(12.5), 10.0);
    expect(SubEditor3DViewport.roundGridStep(25.0), 20.0);
    expect(SubEditor3DViewport.roundGridStep(40.0), 50.0);
    expect(SubEditor3DViewport.roundGridStep(250.0), 200.0);
  });

  testWidgets('the preview starts at 1 m, the Size select changes it and the choice is remembered', (tester) async {
    final vm = MaterialEditorViewModel(
      assetPath: 'contents/materials/M_Size.lmas',
      initialAsset: LuminaAsset(assetId: 'M_Size', name: 'M_Size', type: AssetType.filamat, rawMatSource: _source),
    );
    expect(await tester.runAsync(() => vm.compile()), isTrue);
    Widget editor() => ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(child: SizedBox(width: 1400, height: 900, child: MaterialSubEditor(assetName: 'M_Size', viewModel: vm))),
        );
    await tester.pumpWidget(editor());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport)).previewShapeSize, 100.0);

    await tester.tap(find.byKey(const ValueKey('material_preview_size')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.widgetWithText(SelectItemButton<double>, '2 m').last);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport)).previewShapeSize, 200.0);

    // Closing and reopening the material keeps 2 m for this session.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(editor());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport)).previewShapeSize, 200.0);

    // The custom mesh keeps its own size: no Size select there.
    await tester.tap(find.byKey(const ValueKey('material_preview_custom')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('material_preview_size')), findsNothing);
  });
}
