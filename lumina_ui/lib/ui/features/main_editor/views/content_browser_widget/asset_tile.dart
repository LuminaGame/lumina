part of '../content_browser_widget.dart';

/// The asset tile's card: thumbnail, the asset-type strip under it, the name
/// and the type name, with the
/// source-control badge on its corner and a tooltip naming type, size and
/// path.
mixin _ContentBrowserAssetTile on _ContentBrowserWidgetStateBase {
  Widget _buildAssetTile(
    EditorViewModel? vm,
    RealAssetInfo asset, {
    required bool isSelected,
    required double width,
    required double height,
  }) {
    final style = AssetTypeStyle.of(asset.type);
    final thumbnail = asset.thumbnailBytes;
    final hasPngThumbnail = thumbnail != null && thumbnail.isNotEmpty;
    Widget typeIcon(double size) => Icon(style.icon, size: size, color: style.color);

    final card = Container(
      key: ValueKey('asset_tile_card_${asset.relativePath}'),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isSelected ? EditorColors.primary.withValues(alpha: 0.18) : EditorColors.card,
        borderRadius: BorderRadius.circular(4),
        // The selection border frames the whole tile, strip included.
        border: Border.all(
          color: isSelected ? EditorColors.primary : EditorColors.border,
          width: isSelected ? 1.8 : 1.0,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: hasPngThumbnail
                  ? Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.memory(
                        thumbnail,
                        key: ValueKey('asset_thumbnail_${asset.relativePath}'),
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) => typeIcon(_iconSize * 0.5),
                      ),
                    )
                  : typeIcon((_iconSize * 0.45).clamp(14.0, 120.0)),
            ),
          ),
          // The type bar along the thumbnail's bottom edge.
          AssetTypeStrip(key: ValueKey('asset_type_strip_${asset.relativePath}'), type: asset.type),
          Container(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
            child: Text(
              _displayName(asset.fileName),
              style: TextStyle(
                fontSize: (_iconSize * 0.14).clamp(7.0, 12.0),
                fontWeight: FontWeight.bold,
                color: isSelected ? EditorColors.primary : EditorColors.foreground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
            child: Text(
              style.displayName,
              key: ValueKey('asset_type_label_${asset.relativePath}'),
              style: TextStyle(fontSize: (_iconSize * 0.11).clamp(6.0, 10.0), color: EditorColors.mutedForeground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return Tooltip(
      tooltip: (context) => TooltipContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AssetTypeSwatch(type: asset.type, size: 8),
                const SizedBox(width: 6),
                Text(style.displayName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 2),
            Text(_displayName(asset.fileName), style: const TextStyle(fontSize: 10)),
            Text('${asset.formattedSize} · ${asset.relativePath}', style: const TextStyle(fontSize: 9)),
          ],
        ),
      ),
      // Git status badge (M/A/?/D/C) on the tile corner; null → untouched.
      child: SourceControlBadgeOverlay(
        state: vm?.sourceControl.stateForAny(sourceControlPathsForAsset(vm, asset)),
        path: asset.relativePath,
        child: card,
      ),
    );
  }
}
