import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';

/// Every asset reference row of the Blueprint Details panel offers only the
/// asset types its field takes: a cloth's Cloth Settings offers cloth
/// settings, its Texture textures, its Material materials; a Skeletal Mesh's
/// mesh skeletal meshes.
void main() {
  late BlueprintTestProject project;
  setUpAll(() async {
    project = BlueprintTestProject.create(name: 'AssetRefTypes');
    final repo = AssetRepository();
    for (final (folder, file, type) in [
      ('physics', 'CS_Silk.lmas', AssetType.clothSettings),
      ('textures', 'T_Flag.lmas', AssetType.texture),
      ('materials', 'M_Flag.lmas', AssetType.filamat),
      ('meshes/skeletal', 'SKM_Hero.lmas', AssetType.filameshSk),
      ('meshes/static', 'SM_Pole.lmas', AssetType.filamesh),
      ('animations', 'A_Wave.lmas', AssetType.animation),
    ]) {
      await repo.createAsset(projectPath: project.dir, subFolder: folder, fileName: file, type: type);
    }
  });
  tearDownAll(() => project.dispose());

  test('every asset reference field of the Blueprint schema names the asset types it takes', () {
    for (final d in BlueprintComponentRegistry.registeredComponents) {
      for (final p in d.properties) {
        if (p.type != ComponentPropertyType.assetReference) continue;
        if (p.dartField == 'animClass' || p.dartField == 'hullAsset') continue; // their own pickers
        expect(p.assetTypes, isNotEmpty, reason: '${d.typeName}.${p.dartField}');
      }
    }
  });

  testWidgets('a cloth offers cloth settings, textures and materials in their fields; meshes in Mesh Asset', (tester) async {
    final vm = BlueprintEditorViewModel(assetPath: project.createBlueprint('BP_Flag', parentClass: 'LuminaActor'));
    addTearDown(vm.dispose);
    await tester.runAsync(vm.load);
    final cloth = vm.addComponent('LuminaClothComponent')!;
    final mesh = vm.addComponent('LuminaSkeletalMeshComponent')!;
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: BlueprintSubEditor(assetName: 'BP_Flag', assetPath: vm.assetPath, viewModel: vm, showPreviewViewport: false)),
    ));
    await tester.pump(const Duration(milliseconds: 50));

    Set<AssetType> offered(String componentId, String field) => {
      for (final a in tester.widget<AssetPickerSelect>(find.byKey(ValueKey('bp_asset_${componentId}_$field'))).assets) a.type,
    };

    vm.selectComponent(cloth.id);
    await tester.pumpAndSettle();
    expect(offered(cloth.id, 'clothSettingsAsset'), {AssetType.clothSettings});
    expect(offered(cloth.id, 'baseColorTexture'), {AssetType.texture});
    expect(offered(cloth.id, 'materialAsset'), {AssetType.filamat});
    expect(offered(cloth.id, 'meshAsset'), {AssetType.filamesh, AssetType.filameshSk});

    vm.selectComponent(mesh.id);
    await tester.pumpAndSettle();
    expect(offered(mesh.id, 'skeletalMeshAsset'), {AssetType.filameshSk});
    expect(offered(mesh.id, 'animToPlay'), {AssetType.animation});
    expect(offered(mesh.id, 'materialOverride'), {AssetType.filamat});
    await tester.pumpWidget(const SizedBox());
  });
}
