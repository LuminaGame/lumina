import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/static_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/static_mesh_sub_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sm_ui_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('StaticMeshSubEditor renders real geometry stats and collision actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final assetFile = File('${tempDir.path}/SM_UnitCube.lmas');
    final asset = LuminaAsset(
      assetId: 'SM_UnitCube',
      name: 'SM_UnitCube',
      type: AssetType.filamesh,
      metadata: {
        'triangle_count': '12',
        'vertex_count': '8',
        'uv_channels': '1',
        'sections': '1',
        'min_bounds': '-0.5,-0.5,-0.5',
        'max_bounds': '0.5,0.5,0.5',
      },
    );
    assetFile.writeAsBytesSync(asset.toProtoBufferBytes());

    final vm = StaticMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
    await tester.runAsync(() async {
      await vm.load();
    });

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: StaticMeshSubEditor(
            assetName: 'SM_UnitCube',
            assetPath: assetFile.path,
            viewModel: vm,
          ),
        ),
      ),
    );

    expect(find.text('STATIC MESH'), findsOneWidget);
    expect(find.text('SM_UnitCube'), findsOneWidget);

    // Verify real stats (NO MOCK DATA 17352/15162)
    expect(find.text('Triangles: '), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Vertices: '), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.textContaining('17352'), findsNothing);
    expect(find.textContaining('15162'), findsNothing);

    // Verify collision toolbar button
    expect(find.text('Collision'), findsOneWidget);

    // A mass set outside the field (MCP set_static_mesh_collision,
    // a reload) shows in Physics Properties → Mass (Kg).
    String textOf(Finder f) => tester.widget<EditableText>(find.descendant(of: f, matching: find.byType(EditableText))).controller.text;
    final massField = find.byKey(const ValueKey('static_mesh_mass_field'));
    expect(massField, findsOneWidget);
    expect(textOf(massField), '10.0');
    vm.setMass(80);
    await tester.pump();
    expect(textOf(massField), '80.0');
  });

  // The slot rows were display-only; nothing in the UI called
  // `assignMaterial`, so a material could not be bound from the editor at all.
  testWidgets('a material slot row picks one of the project\'s FILAMAT .lmas and Save persists the binding', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // A real project on disk: two materials and one static mesh.
    final projectDir = Directory('${tempDir.path}/SlotProject');
    for (final name in ['M_Brick', 'M_Metal']) {
      final f = File('${projectDir.path}/contents/materials/$name.lmas')..createSync(recursive: true);
      f.writeAsBytesSync(LuminaAsset(
        assetId: 'id-$name',
        name: name,
        type: AssetType.filamat,
        rawMatSource: 'material { name : $name, shadingModel : lit }\nfragment { void material(inout MaterialInputs material) { prepareMaterial(material); } }\n',
      ).toProtoBufferBytes());
    }
    final meshFile = File('${projectDir.path}/contents/meshes/static/SM_Crate.lmas')..createSync(recursive: true);
    meshFile.writeAsBytesSync(const LuminaAsset(
      assetId: 'SM_Crate',
      name: 'SM_Crate',
      type: AssetType.filamesh,
      metadata: {'triangle_count': '12', 'vertex_count': '8', 'sections': '1', 'min_bounds': '-0.5,-0.5,-0.5', 'max_bounds': '0.5,0.5,0.5'},
    ).toProtoBufferBytes());

    final vm = StaticMeshEditorViewModel(assetPath: meshFile.path);
    await tester.runAsync(() => vm.load());
    expect(vm.materialSlots.single.assignedMaterialPath, isNull);

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: StaticMeshSubEditor(assetName: 'SM_Crate', assetPath: meshFile.path, viewModel: vm),
        ),
      ),
    );
    await tester.pump();

    final picker = find.byKey(const ValueKey('static_mesh_material_slot_0'));
    expect(picker, findsOneWidget, reason: 'the slot row must offer a material picker');
    await tester.tap(picker);
    await tester.pumpAndSettle();
    // The shared searchable picker, one row per project material.
    expect(find.byKey(const ValueKey('static_mesh_material_picker_0_search')), findsOneWidget);
    expect(find.byKey(const ValueKey('static_mesh_material_picker_0_item_M_Brick.lmas')), findsOneWidget,
        reason: 'the picker lists the project\'s real materials');
    await tester.tap(find.byKey(const ValueKey('static_mesh_material_picker_0_item_M_Metal.lmas')));
    await tester.pumpAndSettle();

    final metalPath = '${projectDir.path}/contents/materials/M_Metal.lmas';
    expect(vm.materialSlots.single.assignedMaterialPath, metalPath);
    expect(vm.materialSlots.single.assignedMaterialId, 'id-M_Metal');
    expect(vm.isDirty, isTrue);

    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    final saved = LuminaAsset.fromBytes(meshFile.readAsBytesSync());
    final ref = saved.references.singleWhere((r) => r.slotName == 'element_0');
    expect(ref.assetPath, metalPath);
    expect(ref.assetId, 'id-M_Metal');

    // Reopening the mesh shows the binding it was saved with.
    final reopened = StaticMeshEditorViewModel(assetPath: meshFile.path);
    await tester.runAsync(() => reopened.load());
    expect(reopened.materialSlots.single.assignedMaterialPath, metalPath);
  });
}
