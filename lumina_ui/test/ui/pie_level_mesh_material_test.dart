// Play draws the material assigned to a placed mesh or basic shape (the
// actor's `materialPath`, set in the Details panel or with
// `set_actor_property material`), as the generated level does; a material
// that cannot be drawn leaves the mesh its own.
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

void main() {
  late Directory project;

  setUpAll(() {
    project = Directory.systemTemp.createTempSync('lumina_pie_mesh_material_');
    FilamentMaterialBuilder.initEngine();
    final builder = FilamentMaterialBuilder.create()
      ..setName('M_Red')
      ..setShading(FilamatShading.lit)
      ..addParameter('baseColorFactor', UniformType.float4)
      ..platform(MaterialPlatform.desktop)
      ..targetApi(TargetApi.vulkan)
      ..optimization(OptimizationLevel.none)
      ..setCode('''
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = materialParams.baseColorFactor;
    }
  ''');
    final package = builder.build()!;
    builder.dispose();
    void write(String relative, LuminaAsset asset) => File('${project.path}/$relative')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(asset.toProtoBufferBytes());
    write('contents/materials/M_Red.lmas',
        LuminaAsset(assetId: 'm-red', name: 'M_Red', type: AssetType.filamat, rawPayload: package));
    write('contents/materials/M_Draft.lmas',
        LuminaAsset(assetId: 'm-draft', name: 'M_Draft', type: AssetType.filamat, rawMatSource: 'material { name : M_Draft }'));
    LuminaAssets.projectDir = project.path;
  });

  tearDownAll(() {
    LuminaAssets.projectDir = null;
    project.deleteSync(recursive: true);
  });

  EditorActorNode mesh(String? material) => EditorActorNode(
        id: 'barrel',
        name: 'Barrel',
        type: 'Mesh',
        location: [0, 0, 0],
        meshAssetPath: '${project.path}/contents/meshes/static/SM_Barrel.lmas',
        materialPath: material,
      );

  test('a placed mesh plays with its assigned material on every section', () {
    final actor = EditorPieGame.mapEditorActor(mesh('contents/materials/M_Red.lmas'));
    final root = (actor! as LuminaActor).rootComponent;
    expect(root, isA<LuminaStaticMeshComponent>());
    expect((root as LuminaStaticMeshComponent).materialOverrideAsset, 'contents/materials/M_Red.lmas');
  });

  test('a basic shape plays with its assigned material', () {
    final node = EditorActorNode(
      id: 'cube',
      name: 'Cube',
      type: 'Primitive',
      location: [0, 0, 0],
      materialPath: 'contents/materials/M_Red.lmas',
      components: [
        EditorComponentNode(id: 'cube_mesh', type: 'LuminaProceduralMeshComponent', name: 'Mesh', properties: {'shape': 'box'}),
      ],
    );
    final actor = EditorPieGame.mapEditorActor(node);
    expect((actor! as LuminaPrimitiveActor).meshComponent.materialOverrideAsset, 'contents/materials/M_Red.lmas');
  });

  test('no material, an old placeholder name or an uncompiled material plays the mesh as it is', () {
    for (final material in [null, 'M_Barrel_Mat', 'contents/materials/M_Draft.lmas', 'contents/materials/M_Gone.lmas']) {
      final actor = EditorPieGame.mapEditorActor(mesh(material));
      expect(((actor! as LuminaActor).rootComponent as LuminaStaticMeshComponent).materialOverrideAsset, isNull,
          reason: '$material');
    }
  });
}
