import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';

void main() {
  test('SkeletalMeshComponent registry schema contains skeletalMeshAsset', () {
    final desc = BlueprintComponentRegistry.getDescriptor('LuminaSkeletalMeshComponent');
    expect(desc, isNotNull);
    expect(desc!.properties.any((p) => p.dartField == 'skeletalMeshAsset'), isTrue);
    expect(desc.properties.any((p) => p.dartField == 'animMode'), isTrue);
    expect(desc.properties.any((p) => p.dartField == 'animToPlay'), isTrue);
    expect(desc.properties.any((p) => p.dartField == 'materialOverride'), isTrue);
  });

  test('BlueprintEditorViewModel discovers skeletal meshes and sets property', () async {
    final tempDir = await Directory.systemTemp.createTemp('bp_skm_unit_');
    try {
      await Directory('${tempDir.path}/contents/meshes/skeletal').create(recursive: true);
      final pubspec = File('${tempDir.path}/pubspec.yaml');
      await pubspec.writeAsString('name: test_project\n');

      final skmAsset = LuminaAsset(
        assetId: 'SKM_Character',
        name: 'SKM_Character',
        type: AssetType.filamesh,
      );
      final skmFile = File('${tempDir.path}/contents/meshes/skeletal/SKM_Character.lmas');
      await skmFile.writeAsBytes(skmAsset.toProtoBufferBytes());

      final assetPath = '${tempDir.path}/contents/actors/BP_Hero.lmas';
      await File(assetPath).parent.create(recursive: true);

      final vm = BlueprintEditorViewModel(assetPath: assetPath);
      await vm.load();

      final comp = vm.addComponent('LuminaSkeletalMeshComponent');
      expect(comp, isNotNull);
      vm.selectComponent(comp!.id);

      expect(vm.availableSkeletalMeshes.isNotEmpty, isTrue);
      expect(vm.availableSkeletalMeshes.first.fileName, contains('SKM_Character'));

      await vm.setMeshForComponent(comp.id, 'skeletalMeshAsset', 'contents/meshes/skeletal/SKM_Character.lmas');
      expect(comp.properties['skeletalMeshAsset'], equals('contents/meshes/skeletal/SKM_Character.lmas'));
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test('BlueprintEditorViewModel strictly segregates Skeletal Meshes, Static Meshes, Animations, and Materials', () async {
    final tempDir = await Directory.systemTemp.createTemp('bp_segregation_test_');
    try {
      await Directory('${tempDir.path}/contents/meshes/skeletal').create(recursive: true);
      await Directory('${tempDir.path}/contents/meshes/static').create(recursive: true);
      await Directory('${tempDir.path}/contents/animations').create(recursive: true);
      await Directory('${tempDir.path}/contents/materials').create(recursive: true);
      await Directory('${tempDir.path}/contents/textures').create(recursive: true);

      final pubspec = File('${tempDir.path}/pubspec.yaml');
      await pubspec.writeAsString('name: test_project\n');

      // 1. Skeletal Mesh
      final skm = LuminaAsset(assetId: 'SKM_Manny', name: 'SKM_Manny', type: AssetType.filameshSk);
      await File('${tempDir.path}/contents/meshes/skeletal/SKM_Manny.lmas').writeAsBytes(skm.toProtoBufferBytes());

      // 2. Static Mesh
      final sm = LuminaAsset(assetId: 'SM_Rock', name: 'SM_Rock', type: AssetType.filamesh);
      await File('${tempDir.path}/contents/meshes/static/SM_Rock.lmas').writeAsBytes(sm.toProtoBufferBytes());

      // 3. Animation
      final anim = LuminaAsset(assetId: 'Idle_Loop', name: 'Idle_Loop', type: AssetType.animation);
      await File('${tempDir.path}/contents/animations/Idle_Loop.lmas').writeAsBytes(anim.toProtoBufferBytes());

      // 4. Material
      final mat = LuminaAsset(assetId: 'M_SKM_Manny_MI', name: 'M_SKM_Manny_MI', type: AssetType.filamat);
      await File('${tempDir.path}/contents/materials/M_SKM_Manny_MI.lmas').writeAsBytes(mat.toProtoBufferBytes());

      // 5. Texture
      final tex = LuminaAsset(assetId: 'T_Manny_01_BN', name: 'T_Manny_01_BN', type: AssetType.texture);
      await File('${tempDir.path}/contents/textures/T_Manny_01_BN.lmas').writeAsBytes(tex.toProtoBufferBytes());

      final vm = BlueprintEditorViewModel(assetPath: '${tempDir.path}/contents/blueprints/BP_Hero.lmas');
      await vm.load();

      // Verify Skeletal Meshes contain ONLY SKM_Manny and NO materials/textures/static meshes
      expect(vm.availableSkeletalMeshes.length, equals(1));
      expect(vm.availableSkeletalMeshes.first.fileName, equals('SKM_Manny.lmas'));

      // Verify Static Meshes contain ONLY SM_Rock
      expect(vm.availableStaticMeshes.length, equals(1));
      expect(vm.availableStaticMeshes.first.fileName, equals('SM_Rock.lmas'));

      // Verify Animations contain ONLY Idle_Loop
      expect(vm.availableAnimations.length, equals(1));
      expect(vm.availableAnimations.first.fileName, equals('Idle_Loop.lmas'));

      // Verify Materials contain ONLY M_SKM_Manny_MI
      expect(vm.availableMaterials.length, equals(1));
      expect(vm.availableMaterials.first.fileName, equals('M_SKM_Manny_MI.lmas'));
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}
