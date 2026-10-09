import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/services/asset_picker_catalog.dart';
import 'package:lumina_ui/ui/core/services/file_reveal.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';

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
