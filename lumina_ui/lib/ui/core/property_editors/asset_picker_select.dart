import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/services/asset_picker_catalog.dart';
import 'package:lumina_ui/ui/core/theme/asset_type_style.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select/asset_picker_popup.dart';

export 'package:lumina_ui/ui/core/property_editors/asset_picker_select/asset_picker_popup.dart';

/// What the editor lends every [AssetPickerSelect] below it: the
/// asset list's change notifications and freshest copy (thumbnails land in
/// the background), on-demand thumbnail generation, and "Browse to asset" in
/// the Content Browser. The main editor provides it; a picker outside it
/// still searches and shows the thumbnails its assets carry.
class AssetPickerScope extends InheritedWidget {
  const AssetPickerScope({
    super.key,
    required super.child,
    this.changes,
    this.allAssets,
    this.latest,
    this.requestThumbnail,
    this.browse,
  });

  /// Fires when assets (and their thumbnails) change.
  final Listenable? changes;

  /// Returns all available project assets.
  final List<RealAssetInfo> Function()? allAssets;

  /// The current copy of an asset (with a thumbnail rendered since the list
  /// was built); the asset itself when unknown.
  final RealAssetInfo Function(RealAssetInfo asset)? latest;

  /// Queues a thumbnail for an asset that has none.
  final void Function(RealAssetInfo asset)? requestThumbnail;

  /// Selects an asset in the Content Browser.
  final void Function(RealAssetInfo asset)? browse;

  static AssetPickerScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AssetPickerScope>();

  @override
  bool updateShouldNotify(AssetPickerScope oldWidget) =>
      changes != oldWidget.changes ||
      allAssets != oldWidget.allAssets ||
      latest != oldWidget.latest ||
      requestThumbnail != oldWidget.requestThumbnail ||
      browse != oldWidget.browse;
}

/// The asset types whose thumbnail is a render or the image itself; the rest
/// (animations, Blueprints, levels…) show their type icon.
const Set<AssetType> kRenderedThumbnailTypes = {
  AssetType.filamesh,
  AssetType.filameshSk,
  AssetType.filamat,
  AssetType.texture,
};

/// A fixed choice a picker lists above its assets ("Auto" / "None"
/// entries), e.g. the import dialog's "Auto (match bone names)".
class AssetPickerOption {
  const AssetPickerOption({required this.id, required this.label, this.icon = LucideIcons.circleDot});

  final String id;
  final String label;
  final IconData icon;
}

/// The icon an asset type is drawn with when it has no thumbnail
/// ([AssetTypeStyle]).
IconData assetTypeIcon(AssetType type) => AssetTypeStyle.of(type).icon;

/// An asset's thumbnail, rounded: its PNG when it has one, otherwise its type
/// icon (also while a thumbnail is being generated). Like a Content Browser
/// tile it carries its asset type's strip along the bottom edge; an empty
/// slot has none.
class AssetThumbnail extends StatelessWidget {
  const AssetThumbnail({super.key, required this.asset, this.size = 24});

  final RealAssetInfo? asset;
  final double size;

  /// The type strip's height at this size.
  double get stripHeight => math.max(2, size / 12);

  /// The PNG shown, or null for the icon.
  Uint8List? get bytes {
    final b = asset?.thumbnailBytes;
    return b != null && b.isNotEmpty ? b : null;
  }

  @override
  Widget build(BuildContext context) {
    final b = bytes;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(math.min(4, size / 6)),
        border: Border.all(color: EditorColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          b != null
              ? Image.memory(
                  b,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stack) => _icon(),
                )
              : _icon(),
          if (asset != null)
            Positioned(left: 0, right: 0, bottom: 0, child: AssetTypeStrip(type: asset!.type, height: stripHeight)),
        ],
      ),
    );
  }

  Widget _icon() => Icon(
        asset == null ? LucideIcons.circleSlash : assetTypeIcon(asset!.type),
        size: size * 0.5,
        color: EditorColors.mutedForeground,
      );
}

/// The shared asset picker: the
/// closed control shows the selected asset's thumbnail and name (or
/// [placeholder]); a click opens a popup with a search field (name, folder
/// and type, as you type, matches highlighted), `Recently used`, then every
/// asset as a thumbnail row with its folder, in a lazy list. Up/Down move,
/// Enter picks the highlighted (first) match, Escape closes. [onCleared]
/// adds the `— clear —` row; "Browse to asset" (row context menu and the
/// icon beside the control) selects the asset in the Content Browser.
///
/// [selectedPath] may be an absolute `.lmas` path, a project-relative path or
/// a stored path that no longer exists (shown in red as missing).
class AssetPickerSelect extends StatefulWidget {
  const AssetPickerSelect({
    super.key,
    required this.assets,
    required this.selectedPath,
    required this.onSelected,
    this.onCleared,
    this.placeholder = 'None',
    this.typeFilter,
    this.labelOf,
    this.thumbnailSize = 24,
    this.valueThumbnailSize,
    this.allowClear = true,
    this.clearLabel = '— clear —',
    this.onBrowse,
    this.keyPrefix = 'asset_picker',
    this.recents,
    this.enabled = true,
    this.expand = true,
    this.options = const [],
    this.selectedOption,
    this.onOption,
  });

  /// The assets offered (narrowed by [typeFilter] when given).
  final List<RealAssetInfo> assets;

  /// The picked asset's stored path, or null.
  final String? selectedPath;
  final void Function(RealAssetInfo asset) onSelected;

  /// Clears the value; the `— clear —` row shows when this is set and
  /// [allowClear] is on.
  final VoidCallback? onCleared;

  /// Shown in the closed control when nothing is picked.
  final String placeholder;
  final Set<AssetType>? typeFilter;

  /// How an asset is named; its file name without `.lmas` by default.
  final String Function(RealAssetInfo asset)? labelOf;

  /// Row thumbnail size in the popup.
  final double thumbnailSize;

  /// Thumbnail size in the closed control (defaults to [thumbnailSize]).
  final double? valueThumbnailSize;
  final bool allowClear;
  final String clearLabel;

  /// "Browse to asset"; defaults to the [AssetPickerScope]'s.
  final void Function(RealAssetInfo asset)? onBrowse;

  /// Prefix of the popup's keys: `<prefix>_search`, `<prefix>_clear`,
  /// `<prefix>_item_<file name>`, `<prefix>_recent_<file name>`,
  /// `<prefix>_browse`, `<prefix>_value`.
  final String keyPrefix;

  /// Where `Recently used` is kept; the editor preferences file by default.
  final AssetPickerRecents? recents;
  final bool enabled;

  /// Whether the closed control fills the available width.
  final bool expand;

  /// Fixed choices listed above the assets (keys `<prefix>_option_<id>`).
  final List<AssetPickerOption> options;

  /// The [options] entry currently chosen (shown in the closed control), if
  /// the value is not an asset.
  final String? selectedOption;
  final void Function(String id)? onOption;

  @override
  State<AssetPickerSelect> createState() => _AssetPickerSelectState();
}

class _AssetPickerSelectState extends State<AssetPickerSelect> {
  String _label(RealAssetInfo a) => widget.labelOf?.call(a) ?? AssetPickerCatalog.defaultLabel(a);

  List<RealAssetInfo> _offered(AssetPickerScope? scope) {
    final filter = widget.typeFilter;
    return [
      for (final a in widget.assets)
        if (filter == null || filter.contains(a.type)) scope?.latest?.call(a) ?? a,
    ];
  }

  void _open(AssetPickerScope? scope) {
    final box = context.findRenderObject() as RenderBox?;
    final width = math.max(280.0, box?.size.width ?? 280);
    final recents = widget.recents ?? AssetPickerRecents();
    final browse = widget.onBrowse ?? scope?.browse;
    OverlayCompleter<void>? handle;
    void close() => handle?.close();
    // Anchored to the control (not a fixed position): the popup's top-left
    // sits under the control's bottom-left and follows it if it moves.
    handle = showDropdown<void>(
      context: context,
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.bottomLeft,
      offset: const Offset(0, 2),
      builder: (_) => AssetPickerPopup(
        assets: widget.assets,
        typeFilter: widget.typeFilter,
        selectedPath: widget.selectedPath,
        labelOf: widget.labelOf,
        thumbnailSize: widget.thumbnailSize,
        width: width,
        keyPrefix: widget.keyPrefix,
        clearLabel: widget.clearLabel,
        recents: recents,
        scope: scope,
        onClose: close,
        options: widget.options,
        selectedOption: widget.selectedOption,
        onOption: widget.onOption == null
            ? null
            : (id) {
                close();
                widget.onOption!(id);
              },
        onSelected: (a) {
          close();
          recents.record(a);
          widget.onSelected(a);
        },
        onCleared: widget.allowClear && widget.onCleared != null
            ? () {
                close();
                widget.onCleared!();
              }
            : null,
        onBrowse: browse == null
            ? null
            : (a) {
                close();
                browse(a);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AssetPickerScope.maybeOf(context);
    final offered = _offered(scope);
    final selected = AssetPickerCatalog.find(offered, widget.selectedPath);
    final option = widget.options.where((o) => o.id == widget.selectedOption).firstOrNull;
    final missing = selected == null && option == null && (widget.selectedPath?.isNotEmpty ?? false);
    final missingName = missing ? widget.selectedPath!.replaceAll(r'\', '/').split('/').last.replaceAll('.lmas', '') : null;
    final browse = widget.onBrowse ?? scope?.browse;
    final size = widget.valueThumbnailSize ?? widget.thumbnailSize;

    final control = Button(
      key: ValueKey('${widget.keyPrefix}_value'),
      style: const ButtonStyle.outline(density: ButtonDensity.compact),
      enabled: widget.enabled,
      onPressed: widget.enabled ? () => _open(scope) : null,
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          AssetThumbnail(key: ValueKey('${widget.keyPrefix}_value_thumbnail'), asset: selected, size: size),
          const SizedBox(width: 6),
          Flexible(
            fit: widget.expand ? FlexFit.tight : FlexFit.loose,
            child: Text(
              selected != null ? _label(selected) : (option?.label ?? missingName ?? widget.placeholder),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: selected != null || option != null
                    ? EditorColors.foreground
                    : (missing ? EditorColors.destructive : EditorColors.mutedForeground),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(LucideIcons.chevronsUpDown, size: 11, color: EditorColors.mutedForeground),
        ],
      ),
    );

    return Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.expand) Expanded(child: control) else control,
        if (browse != null && selected != null) ...[
          const SizedBox(width: 2),
          Tooltip(
            tooltip: (_) => const TooltipContainer(child: Text('Browse to asset in the Content Browser')),
            child: GhostButton(
              key: ValueKey('${widget.keyPrefix}_browse'),
              density: ButtonDensity.icon,
              onPressed: () => browse(selected),
              child: const Icon(LucideIcons.folderSearch, size: 12, color: EditorColors.mutedForeground),
            ),
          ),
        ],
      ],
    );
  }
}

/// A general-purpose asset picker combobox for the editor and plugins.
/// Automatically resolves available assets from [AssetPickerScope] or explicit [assets],
/// and filters them by [typeFilter] (e.g. `{AssetType.filameshSk}`, `{AssetType.animation}`, etc.).
class AssetPickerCombobox extends StatelessWidget {
  final String? selectedPath;
  final ValueChanged<String?> onSelected;
  final Set<AssetType>? typeFilter;
  final List<RealAssetInfo>? assets;
  final String placeholder;
  final bool allowClear;
  final bool expand;
  final String keyPrefix;
  final double thumbnailSize;

  const AssetPickerCombobox({
    super.key,
    required this.selectedPath,
    required this.onSelected,
    this.typeFilter,
    this.assets,
    this.placeholder = 'None',
    this.allowClear = false,
    this.expand = true,
    this.keyPrefix = 'asset_combobox',
    this.thumbnailSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final scope = AssetPickerScope.maybeOf(context);
    final all = assets ?? scope?.allAssets?.call() ?? const <RealAssetInfo>[];
    return AssetPickerSelect(
      keyPrefix: keyPrefix,
      assets: all,
      typeFilter: typeFilter,
      selectedPath: selectedPath,
      placeholder: placeholder,
      allowClear: allowClear,
      expand: expand,
      thumbnailSize: thumbnailSize,
      onSelected: (asset) => onSelected(asset.relativePath),
      onCleared: allowClear ? () => onSelected(null) : null,
    );
  }
}
