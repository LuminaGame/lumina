import 'package:lumina/lumina.dart';

import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_asset_catalog.dart';
import 'package:lumina_ui/ui/features/main_editor/services/widget_blueprint_assets.dart';

/// The sub-editor tab category [asset] opens in (`openSubEditorTab`'s first
/// argument) — the one mapping the Content Browser's double-click,
/// `EditorViewModel.openAssetEditorByPath` (File → New Asset, plugin level
/// access) and the MCP `open_asset_editor` tool all use.
///
/// Returns null for a level: a level opens in the level editor
/// (`switchLevel`), not in a sub-editor tab. An `.lmas` a plugin registered an
/// asset type for (matched by `metadata.custom_type`) opens with
/// that plugin's editor when [extensions] is given.
String? subEditorCategoryFor(RealAssetInfo asset, {PluginExtensionRegistry? extensions}) {
  final lower = asset.relativePath.toLowerCase();
  final nameLower = asset.fileName.toLowerCase();
  bool looksAnimation() =>
      !nameLower.startsWith('bp_') &&
      !nameLower.startsWith('wbp_') &&
      (lower.contains('/animations/') ||
          lower.contains('/anim/') ||
          nameLower.startsWith('anim_') ||
          nameLower.startsWith('as_') ||
          nameLower.startsWith('mf_') ||
          nameLower.contains('_anim') ||
          nameLower.contains('_walk') ||
          nameLower.contains('_run') ||
          nameLower.contains('_idle') ||
          nameLower.contains('_bwd') ||
          nameLower.contains('_fwd') ||
          nameLower.contains('_sprint') ||
          nameLower.contains('_jump'));
  bool looksSkeletal() =>
      !nameLower.startsWith('bp_') &&
      !nameLower.startsWith('wbp_') &&
      (lower.contains('/skeletal') ||
          lower.contains('/skm') ||
          nameLower.startsWith('skm_') ||
          nameLower.contains('skeletal') ||
          nameLower.contains('skeleton'));

  switch (asset.type) {
    case AssetType.level:
      return null;
    case AssetType.filamat:
      return 'Material';
    case AssetType.actor:
      final blueprintKind = BlueprintAssetCatalog.documentKindOf(asset.lmasPath);
      if (blueprintKind == LuminaBlueprintEnumDocument.kind) return 'BlueprintEnum';
      if (blueprintKind == LuminaBlueprintInterfaceDocument.kind) return 'BlueprintInterface';
      // Created with the LuminaWidget parent before such Blueprints were
      // written as widgets: the widget designer opens it.
      if (isWidgetBlueprintLmas(asset.lmasPath)) return 'Widget';
      if (blueprintKind == 'class' ||
          nameLower.startsWith('bp_') ||
          lower.contains('/blueprints/')) {
        return 'Blueprint';
      }
      if (looksSkeletal() || lower.contains('/meshes/')) return 'Skeleton';
      return 'Blueprint';
    case AssetType.filameshSk:
      return 'Skeleton';
    case AssetType.filamesh:
      if (looksAnimation()) return 'Animation';
      if (looksSkeletal()) return 'Skeleton';
      return 'Mesh';
    case AssetType.texture:
      return 'Texture';
    case AssetType.animation:
      return 'Animation';
    case AssetType.particle:
      return 'Particle';
    case AssetType.audio:
      return 'Audio';
    case AssetType.landscape:
      return 'Landscape';
    case AssetType.physicsAsset:
      return 'PhysicsAsset';
    case AssetType.sequencer:
      return 'Sequencer';
    case AssetType.widget:
      return 'Widget';
    case AssetType.animBlueprint:
      return 'AnimBlueprint';
    case AssetType.blendSpace:
      return 'BlendSpace';
    case AssetType.theme:
      return 'Theme';
    case AssetType.unknown:
      // An .lmas a plugin registered an asset type for opens with
      // that plugin's editor.
      final handler = extensions?.handlerForAsset(asset);
      if (handler != null) return '${PluginExtensionRegistry.pluginAssetCategoryPrefix}${handler.customTypeId}';
      if (lower.contains('/themes/') || nameLower.startsWith('theme_') || nameLower.endsWith('_theme')) return 'Theme';
      if (nameLower.startsWith('bp_') || lower.contains('/blueprints/')) return 'Blueprint';
      if (looksSkeletal()) return 'Skeleton';
      if (lower.contains('/animations/') || lower.contains('/anim/') || nameLower.startsWith('anim_') || nameLower.startsWith('as_') || nameLower.startsWith('mf_')) {
        return 'Animation';
      }
      if (lower.contains('/meshes/') || lower.endsWith('.obj') || lower.endsWith('.glb')) return 'Mesh';
      if (lower.contains('/materials/')) return 'Material';
      if (lower.contains('/textures/')) return 'Texture';
      return 'Asset';
  }
}
