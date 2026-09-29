import 'dart:io';

import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';

/// ABP_Character, BS_Walk and BS_Locomotion (the Walk state's walk / jog blend
/// space), lumina's reference content for the Third Person mannequin, written
/// into [projectDir] where the template keeps them, unless the project
/// already has them (the Third Person template scaffolds them).
void ensureTemplateAnimAssets(String projectDir) {
  const mesh = LuminaThirdPersonContent.projectMeshAssetPath;
  for (final e in LuminaThirdPersonContent.blendSpaces.entries) {
    if (File('$projectDir/${e.key}').existsSync()) continue;
    AnimGraphAssetService.writeBlendSpace(projectDir, e.key, e.value, targetMesh: mesh);
  }
  if (!File('$projectDir/${LuminaThirdPersonContent.projectAnimBlueprintPath}').existsSync()) {
    AnimGraphAssetService.writeAnimBlueprint(
        projectDir, LuminaThirdPersonContent.projectAnimBlueprintPath, LuminaThirdPersonContent.animBlueprint);
  }
}
