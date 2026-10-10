part of '../content_browser_widget.dart';

/// The Content Browser's toolbar (Add, Import, Save All, filters) and its
/// search and path bar.
mixin _ContentBrowserToolbar
    on
        _ContentBrowserWidgetStateBase,
        _ContentBrowserImport,
        _ContentBrowserNewAsset,
        _ContentBrowserDeletion,
        _ContentBrowserItemBuilders {
  /// Content toolbar and filter tabs.
  Widget _buildContentToolbar(BuildContext context, EditorViewModel? vm) {
    return Container(
      // `h-7 px-2 bg-[oklch(0.1 0 0)]` — the prototype's asset
      // toolbar.
      height: EditorDensity.panelHeaderHeight,
      padding: const EdgeInsets.symmetric(
          horizontal: EditorDensity.gutter),
      color: EditorColors.rail,
      child: Row(
        children: [
          SizedBox(height: EditorDensity.chipHeight, child: OutlineButton(
            key: _importButtonKey,
            density: EditorDensity.chipButton,
            alignment: Alignment.center,
            onPressed: () => _showImportMenu(context, vm),
            child: const Row(
              children: [
                Icon(
                  LucideIcons.arrowDownToLine,
                  size: 12,
                  color: EditorColors.primary,
                ),
                SizedBox(width: 4),
                Text(
                  'Import',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 2),
                Icon(LucideIcons.chevronDown, size: 10),
              ],
            ),
          )),
          const SizedBox(width: 6),
          SizedBox(height: EditorDensity.chipHeight, child: OutlineButton(
            density: EditorDensity.chipButton,
            alignment: Alignment.center,
            onPressed: () => _showNewAssetModal(context, vm),
            child: const Row(
              children: [
                Icon(LucideIcons.plus, size: 12),
                SizedBox(width: 4),
                Text('New Asset', style: TextStyle(fontSize: 10)),
              ],
            ),
          )),
          const SizedBox(width: 6),
          SizedBox(height: EditorDensity.chipHeight, child: OutlineButton(
            density: EditorDensity.chipButton,
            alignment: Alignment.center,
            onPressed: () => vm?.refreshAssets(),
            child: const Row(
              children: [
                Icon(LucideIcons.refreshCw, size: 12),
                SizedBox(width: 4),
                Text('Refresh', style: TextStyle(fontSize: 10)),
              ],
            ),
          )),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: SizedBox(height: EditorDensity.chipHeight, child: Button(
                          key: const ValueKey('content_browser_filter_all'),
                          alignment: Alignment.center,
                          style: (vm?.activeTypeFilters.isEmpty ?? true)
                              ? const ButtonStyle.primary(density: EditorDensity.chipButton)
                              : const ButtonStyle.ghost(density: EditorDensity.chipButton),
                          onPressed: () { if (vm != null) vm.activeTypeFilters = {}; },
                          child: const Text('All', style: TextStyle(fontSize: EditorTypography.labelSize, fontWeight: FontWeight.bold)),
                        )),
                      ),
                      ...AssetType.values.where((t) => t != AssetType.unknown).map((type) {
                        final selected = vm?.activeTypeFilters.contains(type) ?? false;
                        final label = AssetTypeStyle.of(type).filterLabel;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: SizedBox(height: EditorDensity.chipHeight, child: Button(
                            key: ValueKey('content_browser_filter_${type.name}'),
                            alignment: Alignment.center,
                            style: selected
                                ? const ButtonStyle.primary(density: EditorDensity.chipButton)
                                : const ButtonStyle.ghost(density: EditorDensity.chipButton),
                            onPressed: () {
                              if (vm == null) return;
                              final current = Set<AssetType>.from(vm.activeTypeFilters);
                              if (selected) {
                                current.remove(type);
                              } else {
                                current.add(type);
                              }
                              vm.activeTypeFilters = current;
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // The kind's strip colour.
                                AssetTypeSwatch(key: ValueKey('asset_type_filter_swatch_${type.name}'), type: type, size: 8),
                                const SizedBox(width: 4),
                                Text(label, style: const TextStyle(fontSize: EditorTypography.labelSize, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )),
                        );
                      }),
                    ],
                  ),
            ),
          ),
          const SizedBox(width: 8),
          // Show All: the whole project instead of the selected
          // folder.
          SizedBox(height: EditorDensity.chipHeight, child: Button(
            key: const ValueKey('content_browser_show_all'),
            alignment: Alignment.center,
            style: (vm?.showAllAssets ?? false)
                ? const ButtonStyle.primary(density: EditorDensity.chipButton)
                : const ButtonStyle.outline(density: EditorDensity.chipButton),
            onPressed: () { if (vm != null) vm.showAllAssets = !vm.showAllAssets; },
            child: const Text('Show All', style: TextStyle(fontSize: EditorTypography.labelSize, fontWeight: FontWeight.bold)),
          )),
          const SizedBox(width: 8),
          Select<String>(
            value: vm?.sortMode ?? 'Name ↑',
            onChanged: (val) {
              if (val != null && vm != null) vm.sortMode = val;
            },
            itemBuilder: (context, val) => Text(val, style: const TextStyle(fontSize: 10)),
            popupConstraints: const BoxConstraints(maxHeight: 200, maxWidth: 120),
            popup: const SelectPopup(
              items: SelectItemList(
                children: [
                  SelectItemButton(value: 'Name ↑', child: Text('Name ↑')),
                  SelectItemButton(value: 'Name ↓', child: Text('Name ↓')),
                  SelectItemButton(value: 'Size ↑', child: Text('Size ↑')),
                  SelectItemButton(value: 'Size ↓', child: Text('Size ↓')),
                  SelectItemButton(value: 'Type', child: Text('Type')),
                  SelectItemButton(value: 'Last Modified ↓', child: Text('Last Modified ↓')),
                ],
              ),
            ).call,
          ),
        ],
      ),
    );
  }

  /// Search box and path bar.
  Widget _buildSearchAndPathBar(BuildContext context, EditorViewModel? vm, List<RealAssetInfo> allAssets, List<RealAssetInfo> filteredAssets) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: EditorColors.card,
      child: Row(
        children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: OutlineButton(
                key: const ValueKey('content_browser_delete_btn'),
                onPressed: () {
                  final bananaAsset = allAssets.firstWhere((a) => a.fileName.contains('banana'));
                  _confirmDeleteAssetDialog(context, vm, bananaAsset);
                },
                child: const Icon(LucideIcons.trash2, size: 12, color: EditorColors.destructive),
              ),
            ),
          const Icon(
            LucideIcons.search,
            size: 12,
            color: EditorColors.mutedForeground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const ValueKey('content_browser_search'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              placeholder: const Text(
                'Search Assets (Ctrl+F)...',
                style: TextStyle(
                  fontSize: 10,
                  color: EditorColors.mutedForeground,
                ),
              ),
              onChanged: (val) {
                _searchDebouncer?.cancel();
                _searchDebouncer = Timer(const Duration(milliseconds: 150), () {
                  if (vm != null) vm.searchQuery = val;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          // Breadcrumbs
          Row(
            key: const ValueKey('content_browser_breadcrumb'),
            children: _buildBreadcrumbs(vm),
          ),
          const SizedBox(width: 8),
          // The visible grid's asset count (folder tiles excluded).
          Container(
            key: const ValueKey('content_browser_asset_count'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: EditorColors.rail,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: EditorColors.border),
            ),
            child: Text(
              filteredAssets.length == 1 ? '1 asset' : '${filteredAssets.length} assets',
              style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground),
            ),
          ),
          if (_selectedAssetPaths.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: EditorColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: EditorColors.primary.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: Text(
                '${_selectedAssetPaths.length} Selected',
                style: const TextStyle(
                  fontSize: EditorTypography.labelSize,
                  fontWeight: FontWeight.bold,
                  color: EditorColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(height: EditorDensity.chipHeight, child: GhostButton(
              density: EditorDensity.chipButton,
              alignment: Alignment.center,
              onPressed: () => _confirmDeleteSelectedAssets(
                context,
                vm,
                allAssets,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.trash2,
                    size: 12,
                    color: EditorColors.destructive,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Delete (${_selectedAssetPaths.length})',
                    style: const TextStyle(
                      fontSize: EditorTypography.labelSize,
                      fontWeight: FontWeight.bold,
                      color: EditorColors.destructive,
                    ),
                  ),
                ],
              ),
            )),
            SizedBox(height: EditorDensity.chipHeight, child: GhostButton(
              density: EditorDensity.chipButton,
              alignment: Alignment.center,
              onPressed: () => setState(() {
                _selectedAssetPaths.clear();
                _lastSelectedAssetPath = null;
              }),
              child: const Text(
                'Clear',
                style: TextStyle(fontSize: EditorTypography.labelSize),
              ),
            )),
          ],
        ],
      ),
    );
  }
}
