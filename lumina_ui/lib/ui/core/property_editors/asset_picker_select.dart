import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/services/asset_picker_catalog.dart';
import 'package:lumina_ui/ui/core/services/file_reveal.dart';
import 'package:lumina_ui/ui/core/theme/asset_type_style.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';

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

/// The popup of [AssetPickerSelect]: search row, `— clear —`, `Recently
/// used`, and the lazy list of matches.
class AssetPickerPopup extends StatefulWidget {
  const AssetPickerPopup({
    super.key,
    required this.assets,
    required this.selectedPath,
    required this.onSelected,
    required this.recents,
    this.typeFilter,
    this.onCleared,
    this.onBrowse,
    this.labelOf,
    this.thumbnailSize = 24,
    this.width = 300,
    this.keyPrefix = 'asset_picker',
    this.clearLabel = '— clear —',
    this.scope,
    this.options = const [],
    this.selectedOption,
    this.onOption,
    this.onClose,
  });

  final List<RealAssetInfo> assets;
  final Set<AssetType>? typeFilter;
  final String? selectedPath;
  final void Function(RealAssetInfo asset) onSelected;
  final VoidCallback? onCleared;
  final void Function(RealAssetInfo asset)? onBrowse;
  final String Function(RealAssetInfo asset)? labelOf;
  final double thumbnailSize;
  final double width;
  final String keyPrefix;
  final String clearLabel;
  final AssetPickerRecents recents;
  final AssetPickerScope? scope;
  final List<AssetPickerOption> options;
  final String? selectedOption;
  final void Function(String id)? onOption;

  /// Closes the popup (Escape).
  final VoidCallback? onClose;

  /// Height of one asset row.
  static const double rowExtent = 36;

  /// Height of the list before it scrolls.
  static const double maxListHeight = 320;

  @override
  State<AssetPickerPopup> createState() => _AssetPickerPopupState();
}

class _AssetPickerPopupState extends State<AssetPickerPopup> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final Set<String> _requested = {};
  late final List<String> _recentPaths;
  String _query = '';
  int _highlight = 0;

  /// Recent rows in the last build (their list sits under a header).
  int _recentCount = 0;

  @override
  void initState() {
    super.initState();
    final types = widget.typeFilter ?? {for (final a in widget.assets) a.type};
    _recentPaths = widget.recents.recentPaths(types);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _label(RealAssetInfo a) => widget.labelOf?.call(a) ?? AssetPickerCatalog.defaultLabel(a);

  List<RealAssetInfo> _offered() {
    final filter = widget.typeFilter;
    final latest = widget.scope?.latest;
    return [
      for (final a in widget.assets)
        if (filter == null || filter.contains(a.type)) latest?.call(a) ?? a,
    ];
  }

  /// The rows, in order: recents (empty query only), then the matches.
  List<({RealAssetInfo asset, bool recent})> _rows(List<RealAssetInfo> offered) {
    final matches = AssetPickerCatalog.filter(offered, _query, labelOf: _label);
    if (_query.trim().isNotEmpty) return [for (final a in matches) (asset: a, recent: false)];
    final recent = [for (final p in _recentPaths) ?AssetPickerCatalog.find(offered, p)];
    return [
      for (final a in recent) (asset: a, recent: true),
      for (final a in matches) (asset: a, recent: false),
    ];
  }

  void _requestMissing(RealAssetInfo a) {
    final request = widget.scope?.requestThumbnail;
    if (request == null || !kRenderedThumbnailTypes.contains(a.type)) return;
    if ((a.thumbnailBytes?.isNotEmpty ?? false) || !_requested.add(a.relativePath)) return;
    // Never during build: the queue notifies its listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) => request(a));
  }

  void _move(int delta, int count) {
    if (count == 0) return;
    setState(() => _highlight = (_highlight + delta).clamp(0, count - 1));
    final headersAbove = _recentCount == 0 ? 0 : (_highlight < _recentCount ? 1 : 2);
    final target = (_highlight + headersAbove) * AssetPickerPopup.rowExtent;
    if (_scroll.hasClients) {
      final view = _scroll.position.viewportDimension;
      if (target < _scroll.offset) {
        _scroll.jumpTo(target);
      } else if (target + AssetPickerPopup.rowExtent > _scroll.offset + view) {
        _scroll.jumpTo(target + AssetPickerPopup.rowExtent - view);
      }
    }
  }

  Widget _highlighted(String text, TextStyle style) {
    final ranges = AssetPickerCatalog.matchRanges(text, _query);
    if (ranges.isEmpty) return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    final spans = <TextSpan>[];
    var at = 0;
    for (final (start, end) in ranges) {
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(TextSpan(
        text: text.substring(start, end),
        style: const TextStyle(color: EditorColors.primary, fontWeight: FontWeight.bold),
      ));
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(TextSpan(style: style, children: spans), maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Widget _row(RealAssetInfo a, {required bool recent, required bool highlighted}) {
    _requestMissing(a);
    final selected = AssetPickerCatalog.matchesPath(a, widget.selectedPath);
    final row = Clickable(
      key: ValueKey('${widget.keyPrefix}_${recent ? 'recent' : 'item'}_${a.fileName}'),
      onPressed: () => widget.onSelected(a),
      child: Container(
        height: AssetPickerPopup.rowExtent,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: highlighted
              ? EditorColors.primary.withValues(alpha: 0.22)
              : (selected ? EditorColors.primary.withValues(alpha: 0.12) : null),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            AssetThumbnail(asset: a, size: widget.thumbnailSize),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _highlighted(_label(a), const TextStyle(fontSize: 10.5, color: EditorColors.foreground)),
                  _highlighted(AssetPickerCatalog.folderOf(a),
                      const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
                ],
              ),
            ),
            if (selected) const Icon(LucideIcons.check, size: 11, color: EditorColors.primary),
          ],
        ),
      ),
    );
    final browse = widget.onBrowse;
    final file = a.lmasPath;
    if (browse == null && file == null) return row;
    return EditorContextMenu(
      items: [
        if (browse != null)
          MenuButton(
            leading: const Icon(LucideIcons.folderSearch, size: 12),
            onPressed: (_) => browse(a),
            child: const Text('Browse to asset', style: TextStyle(fontSize: 10)),
          ),
        // The asset's .lmas in the platform file manager.
        if (file != null)
          MenuButton(
            leading: const Icon(LucideIcons.folderOpen, size: 12),
            onPressed: (_) => FileReveal.reveal(file),
            child: Text(FileReveal.menuLabel(), style: const TextStyle(fontSize: 10)),
          ),
      ],
      child: row,
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
        child: Text(text, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
      );

  @override
  Widget build(BuildContext context) {
    final changes = widget.scope?.changes;
    return changes == null ? _content(context) : ListenableBuilder(listenable: changes, builder: (context, _) => _content(context));
  }

  Widget _content(BuildContext context) {
    final offered = _offered();
    final rows = _rows(offered);
    final recentCount = _recentCount = rows.where((r) => r.recent).length;
    final highlight = rows.isEmpty ? -1 : _highlight.clamp(0, rows.length - 1);
    // Headers ("Recently used", "All assets") sit in the list as rows too.
    final showHeaders = recentCount > 0;
    final itemCount = rows.length + (showHeaders ? 2 : 0);
    final listHeight = math.min(itemCount * AssetPickerPopup.rowExtent, AssetPickerPopup.maxListHeight);

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: EditorColors.popover,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: EditorColors.border),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Focus(
            // Arrow keys reach this before the text field's own shortcuts.
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                _move(1, rows.length);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                _move(-1, rows.length);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                widget.onClose?.call();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              key: ValueKey('${widget.keyPrefix}_search'),
              controller: _search,
              autofocus: true,
              placeholder: Text('Search ${offered.length} assets...', style: const TextStyle(fontSize: 10)),
              features: const [InputFeature.leading(Icon(LucideIcons.search, size: 12))],
              onChanged: (v) => setState(() {
                _query = v;
                _highlight = 0;
                if (_scroll.hasClients) _scroll.jumpTo(0);
              }),
              onSubmitted: (_) {
                if (highlight >= 0) widget.onSelected(rows[highlight].asset);
              },
            ),
          ),
          const SizedBox(height: 6),
          if (widget.onOption != null)
            for (final o in widget.options)
              Clickable(
                key: ValueKey('${widget.keyPrefix}_option_${o.id}'),
                onPressed: () => widget.onOption!(o.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  decoration: BoxDecoration(
                    color: o.id == widget.selectedOption ? EditorColors.primary.withValues(alpha: 0.12) : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(o.icon, size: 12, color: EditorColors.mutedForeground),
                      const SizedBox(width: 8),
                      Expanded(child: Text(o.label, style: const TextStyle(fontSize: 10.5, color: EditorColors.foreground))),
                      if (o.id == widget.selectedOption) const Icon(LucideIcons.check, size: 11, color: EditorColors.primary),
                    ],
                  ),
                ),
              ),
          if (widget.onCleared != null)
            Clickable(
              key: ValueKey('${widget.keyPrefix}_clear'),
              onPressed: widget.onCleared,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                child: Row(
                  children: [
                    const Icon(LucideIcons.x, size: 12, color: EditorColors.mutedForeground),
                    const SizedBox(width: 8),
                    Text(widget.clearLabel, style: const TextStyle(fontSize: 10.5, color: EditorColors.mutedForeground)),
                  ],
                ),
              ),
            ),
          const Divider(height: 1),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                offered.isEmpty ? 'No assets of this type in the project.' : 'No asset matches "$_query".',
                style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
              ),
            )
          else
            SizedBox(
              height: listHeight,
              child: ListView.builder(
                key: ValueKey('${widget.keyPrefix}_list'),
                controller: _scroll,
                itemExtent: AssetPickerPopup.rowExtent,
                itemCount: itemCount,
                itemBuilder: (context, i) {
                  if (showHeaders) {
                    if (i == 0) return _header('RECENTLY USED');
                    if (i == recentCount + 1) return _header('ALL ASSETS');
                    final r = i <= recentCount ? i - 1 : i - 2;
                    return _row(rows[r].asset, recent: rows[r].recent, highlighted: r == highlight);
                  }
                  return _row(rows[i].asset, recent: false, highlighted: i == highlight);
                },
              ),
            ),
        ],
      ),
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

