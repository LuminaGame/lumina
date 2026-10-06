import 'package:lumina/lumina.dart' show AssetType;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'editor_theme.dart';

/// How the editor shows an asset kind: its colour (an
/// [EditorColors] token, so a theme slot), the human-readable type name the
/// Content Browser writes under a tile's name, the short label of its filter
/// chip, and the icon drawn when there is no thumbnail.
///
/// Every place that shows an asset type reads it from here: the grid tile's
/// strip and label, the tile tooltip, the filter chips, the delete / new-asset
/// dialogs and the asset pickers' thumbnails.
class AssetTypeStyle {
  const AssetTypeStyle._(this.color, this.displayName, this.filterLabel, this.icon);

  /// The type colour: an [EditorColors] token that resolves through the
  /// active theme (compare with `toARGB32()`, not `==`).
  final Color color;

  /// The asset-class name: "Animation Sequence", "Skeletal Mesh", ….
  final String displayName;

  /// The filter chip's label.
  final String filterLabel;

  final IconData icon;

  static AssetTypeStyle of(AssetType type) => switch (type) {
        AssetType.level => const AssetTypeStyle._(EditorColors.assetTypeLevel, 'Level', 'level', LucideIcons.map),
        AssetType.filamesh => const AssetTypeStyle._(EditorColors.assetTypeStaticMesh, 'Static Mesh', 'Mesh', LucideIcons.box),
        AssetType.filameshSk =>
          const AssetTypeStyle._(EditorColors.assetTypeSkeletalMesh, 'Skeletal Mesh', 'filameshSk', LucideIcons.bone),
        AssetType.filamat => const AssetTypeStyle._(EditorColors.assetTypeMaterial, 'Material', 'Material', LucideIcons.palette),
        AssetType.texture => const AssetTypeStyle._(EditorColors.assetTypeTexture, 'Texture', 'texture', LucideIcons.image),
        AssetType.actor =>
          const AssetTypeStyle._(EditorColors.assetTypeBlueprint, 'Blueprint Class', 'Blueprint', LucideIcons.gitBranch),
        AssetType.animation =>
          const AssetTypeStyle._(EditorColors.assetTypeAnimation, 'Animation Sequence', 'animation', LucideIcons.clapperboard),
        AssetType.particle =>
          const AssetTypeStyle._(EditorColors.assetTypeParticle, 'Particle System', 'particle', LucideIcons.sparkles),
        AssetType.audio => const AssetTypeStyle._(EditorColors.assetTypeAudio, 'Sound', 'audio', LucideIcons.music),
        AssetType.landscape =>
          const AssetTypeStyle._(EditorColors.assetTypeLandscape, 'Landscape', 'landscape', LucideIcons.mountain),
        AssetType.physicsAsset => const AssetTypeStyle._(
            EditorColors.assetTypePhysicsAsset, 'Physics Asset', 'physicsAsset', LucideIcons.personStanding),
        AssetType.sequencer =>
          const AssetTypeStyle._(EditorColors.assetTypeSequencer, 'Level Sequence', 'sequencer', LucideIcons.film),
        AssetType.widget =>
          const AssetTypeStyle._(EditorColors.assetTypeWidget, 'Widget Blueprint', 'widget', LucideIcons.layoutTemplate),
        AssetType.animBlueprint => const AssetTypeStyle._(
            EditorColors.assetTypeAnimBlueprint, 'Animation Blueprint', 'animBlueprint', LucideIcons.workflow),
        AssetType.blendSpace =>
          const AssetTypeStyle._(EditorColors.assetTypeBlendSpace, 'Blend Space', 'blendSpace', LucideIcons.grid2x2),
        AssetType.theme =>
          const AssetTypeStyle._(EditorColors.assetTypeTheme, 'Theme', 'theme', LucideIcons.palette),
        AssetType.unknown => const AssetTypeStyle._(EditorColors.mutedForeground, 'Asset', 'unknown', LucideIcons.file),
      };
}

/// The thin line in an asset type's colour along the bottom edge of a
/// thumbnail. Folders have none.
class AssetTypeStrip extends StatelessWidget {
  const AssetTypeStrip({super.key, required this.type, this.height = 3});

  final AssetType type;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: ColoredBox(color: AssetTypeStyle.of(type).color),
      );
}

/// A small rounded square in an asset type's colour (tooltips, filter chips).
class AssetTypeSwatch extends StatelessWidget {
  const AssetTypeSwatch({super.key, required this.type, this.size = 8});

  final AssetType type;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AssetTypeStyle.of(type).color,
          borderRadius: BorderRadius.circular(size / 4),
        ),
      );
}
