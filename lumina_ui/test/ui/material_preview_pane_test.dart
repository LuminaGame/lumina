import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

const _source = '''material {
    name : "M_Pane",
    shadingModel : lit,
    parameters : [
        { type : float, name : roughness, default : 0.5 }
    ],
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.roughness = materialParams.roughness;
    }
}''';

void main() {
  final assets = Directory(Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets');
  final aircon = File('${assets.path}/Props/AC_units/aircon_small.glb');
  final barrel = File('${assets.path}/Props/Barrels/dented_barrel.glb');
  final haveAssets = aircon.existsSync() && barrel.existsSync();

  group('material slot sections', () {
    test('a two-slot mesh splits its sections by slot, a one-slot mesh gives all of them', () async {
      final two = (await GlbParserService.parseGlb(aircon.readAsBytesSync()))!;
      expect(two.materialNames, hasLength(2));
      final slot0 = MaterialPreviewPane.sectionsOfSlot(two, 0);
      final slot1 = MaterialPreviewPane.sectionsOfSlot(two, 1);
      expect(slot0, isNotEmpty);
      expect(slot1, isNotEmpty);
      expect(slot0.intersection(slot1), isEmpty);
      expect(slot0.union(slot1), {for (var i = 0; i < two.subPrimitives.length; i++) i});

      final one = (await GlbParserService.parseGlb(barrel.readAsBytesSync()))!;
      expect(MaterialPreviewPane.sectionsOfSlot(one, 0), {for (var i = 0; i < one.subPrimitives.length; i++) i});
    }, skip: haveAssets ? false : 'test-assets missing');
  });

  testWidgets('settings sit under the preview, the viewport HUD is gone, Plane and Custom drive the viewport',
      (tester) async {
    final project = Directory.systemTemp.createTempSync('mat_pane_');
    addTearDown(() => project.deleteSync(recursive: true));
    Directory('${project.path}/contents/materials').createSync(recursive: true);
    final meshDir = Directory('${project.path}/contents/meshes/static')..createSync(recursive: true);
    if (haveAssets) {
      final mesh = LuminaAsset(
        assetId: 'SM_AirconSmall',
        name: 'SM_AirconSmall',
        type: AssetType.filamesh,
        rawPayload: aircon.readAsBytesSync(),
      );
      File('${meshDir.path}/SM_AirconSmall.lmas').writeAsBytesSync(mesh.toProtoBufferBytes());
    }

    final vm = MaterialEditorViewModel(
      assetPath: '${project.path}/contents/materials/M_Pane.lmas',
      initialAsset: LuminaAsset(assetId: 'M_Pane', name: 'M_Pane', type: AssetType.filamat, rawMatSource: _source),
    );
    expect(await tester.runAsync(() => vm.compile()), isTrue);

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SizedBox(width: 1400, height: 900, child: MaterialSubEditor(assetName: 'M_Pane', viewModel: vm)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Settings live in the left column, under the preview; the right panel keeps the parameters.
    expect(find.descendant(of: find.byType(MaterialPreviewPane), matching: find.byType(MaterialSettingsSection)),
        findsOneWidget);
    expect(find.descendant(of: find.byType(MaterialParameterPanel), matching: find.text('MATERIAL SETTINGS')),
        findsNothing);
    expect(find.text('MATERIAL SETTINGS'), findsOneWidget);

    // No shading / projection / shape HUD over the preview.
    var viewport = tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport));
    expect(viewport.showToolbar, isFalse);
    expect(find.text('WIREFRAME'), findsNothing);
    expect(find.text('Perspective'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('material_preview_plane')));
    await tester.pump(const Duration(milliseconds: 50));
    viewport = tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport));
    expect(viewport.initialShape, PreviewShape.plane);
    expect(viewport.previewMaterialBytes, same(vm.compiledBytes));

    if (!haveAssets) return;

    await tester.tap(find.byKey(const ValueKey('material_preview_custom')));
    for (var i = 0; i < 50 && find.byKey(const ValueKey('material_preview_mesh_picker')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('material_preview_mesh_picker')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('material_preview_mesh_value')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('material_preview_mesh_item_SM_AirconSmall.lmas')).last);
    for (var i = 0; i < 100 && find.byKey(const ValueKey('material_preview_slot')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('material_preview_slot')), findsOneWidget,
        reason: 'the picked mesh has two material slots');

    viewport = tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport));
    expect(viewport.glbMesh, isNotNull);
    expect(viewport.previewMaterialSections, MaterialPreviewPane.sectionsOfSlot(viewport.glbMesh!, 0));
    expect(viewport.previewMaterialBytes, same(vm.compiledBytes));
    expect(viewport.showToolbar, isFalse);

    // Slot 1 moves the material to the other sections.
    await tester.tap(find.byKey(const ValueKey('material_preview_slot')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.widgetWithText(SelectItemButton<int>, '1 · aircon_small_vent_export').last);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    viewport = tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport));
    expect(viewport.previewMaterialSections, MaterialPreviewPane.sectionsOfSlot(viewport.glbMesh!, 1));
  });
}
