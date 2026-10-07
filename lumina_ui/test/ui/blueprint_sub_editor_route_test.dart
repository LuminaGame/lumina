import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/services/asset_editor_category.dart';

void main() {
  group('subEditorCategoryFor Blueprint routing', () {
    test('Blueprint in contents/animations/ routes to Blueprint, not Animation', () {
      final asset = RealAssetInfo(
        fileName: 'BP_NewBlueprint.lmas',
        relativePath: 'contents/animations/SK_MH_1/BP_NewBlueprint.lmas',
        type: AssetType.actor,
        bytes: 1024,
      );
      expect(subEditorCategoryFor(asset), 'Blueprint');
    });

    test('Blueprint with motion keyword in name routes to Blueprint, not Animation', () {
      final asset = RealAssetInfo(
        fileName: 'BP_WalkCharacter.lmas',
        relativePath: 'contents/blueprints/BP_WalkCharacter.lmas',
        type: AssetType.actor,
        bytes: 1024,
      );
      expect(subEditorCategoryFor(asset), 'Blueprint');
    });

    test('Blueprint in contents/meshes/ routes to Blueprint, not Skeleton', () {
      final asset = RealAssetInfo(
        fileName: 'BP_SkeletalTrap.lmas',
        relativePath: 'contents/meshes/skeletal/BP_SkeletalTrap.lmas',
        type: AssetType.actor,
        bytes: 1024,
      );
      expect(subEditorCategoryFor(asset), 'Blueprint');
    });

    test('Real animation sequence still routes to Animation', () {
      final asset = RealAssetInfo(
        fileName: 'MF_Walk_Fwd.lmas',
        relativePath: 'contents/animations/MF_Walk_Fwd.lmas',
        type: AssetType.animation,
        bytes: 1024,
      );
      expect(subEditorCategoryFor(asset), 'Animation');
    });

    test('Unknown asset with bp_ prefix in animations folder routes to Blueprint', () {
      final asset = RealAssetInfo(
        fileName: 'BP_CustomEnemy.lmas',
        relativePath: 'contents/animations/BP_CustomEnemy.lmas',
        type: AssetType.unknown,
        bytes: 1024,
      );
      expect(subEditorCategoryFor(asset), 'Blueprint');
    });
  });
}
