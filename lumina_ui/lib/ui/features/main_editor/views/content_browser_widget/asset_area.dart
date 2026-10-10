part of '../content_browser_widget.dart';

/// The Content Browser's asset grid or list, its empty placeholder, and the
/// drop and context-menu handling around it.
mixin _ContentBrowserAssetArea
    on
        _ContentBrowserWidgetStateBase,
        _ContentBrowserSelection,
        _ContentBrowserImport,
        _ContentBrowserNewAsset,
        _ContentBrowserDeletion,
        _ContentBrowserRenameDuplicate,
        _ContentBrowserReferencesSizeMigrate,
        _ContentBrowserItemBuilders,
        _ContentBrowserAssetTile {
  /// The assets grid, or the empty placeholder.
  Widget _buildAssetArea(BuildContext context, EditorViewModel? vm, List<RealAssetInfo> allAssets, List<RealAssetInfo> filteredAssets, List<String> visibleFolders) {
    return Expanded(
      child: EditorContextMenu(
        items: [
          MenuButton(
            leading: const Icon(LucideIcons.refreshCw, size: 12),
            onPressed: (ctx) => vm?.refreshAssets(),
            child: const Text(
              'Refresh Assets',
              style: TextStyle(fontSize: 10),
            ),
          ),
          const MenuDivider(),
          if (vm != null && vm.showsFolderTiles)
            MenuButton(
              leading: const Icon(LucideIcons.folderPlus, size: 12),
              onPressed: (ctx) => showNewContentFolderDialog(context, vm, vm.selectedFolder ?? 'contents'),
              child: const Text('New Folder...', style: TextStyle(fontSize: 10)),
            ),
          MenuButton(
            onPressed: (ctx) => _showNewAssetModal(context, vm),
            child: const Text(
              'New Asset...',
              style: TextStyle(fontSize: 10),
            ),
          ),
          const MenuDivider(),
          MenuButton(
            onPressed: (ctx) =>
                _handleImportAssetClick(context, vm),
            child: const Text(
              'Import Asset...',
              style: TextStyle(fontSize: 10),
            ),
          ),
          if (vm != null)
            MenuButton(
              leading: const Icon(LucideIcons.folderInput, size: 12),
              onPressed: (ctx) => startImportAssetFolder(context, vm),
              child: const Text(
                'Import Asset Folder...',
                style: TextStyle(fontSize: 10),
              ),
            ),
        ],
        child: Container(
          color: Colors.transparent,
          width: double.infinity,
          height: double.infinity,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vm != null && vm.isImporting)
                  _buildImportingCard(vm),
                if (filteredAssets.isEmpty &&
                    visibleFolders.isEmpty &&
                    (vm == null || !vm.isImporting))
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.folderOpen,
                            size: 24,
                            color: EditorColors.mutedForeground,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No assets found',
                            style: const TextStyle(
                              fontSize: 10,
                              color: EditorColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.topLeft,
                    child: Wrap(
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Subfolders first.
                        if (vm != null)
                          for (final folder in visibleFolders)
                            ContentBrowserFolderTile(
                              viewModel: vm,
                              path: folder,
                              width: (_iconSize * 1.35).clamp(48.0, 320.0),
                              height: (_iconSize * 1.45).clamp(56.0, 340.0),
                              selected: _selectedFolderTile == folder,
                              onSelect: () => setState(() {
                                _selectedFolderTile = folder;
                                _selectedAssetPaths.clear();
                              }),
                            ),
                        ...filteredAssets.map((asset) {
                        final hasPngThumbnail =
                            asset.thumbnailBytes != null &&
                            asset.thumbnailBytes!.isNotEmpty;
                        final cardWidth = _iconSize * 1.35;
                        final cardHeight = _iconSize * 1.45;
                        final isSelected = _selectedAssetPaths
                            .contains(asset.relativePath);
                        final isMultiSelected =
                            isSelected &&
                            _selectedAssetPaths.length > 1;

                        final itemWidget = _buildAssetTile(
                          vm,
                          asset,
                          isSelected: isSelected,
                          width: cardWidth.clamp(48.0, 320.0),
                          height: cardHeight.clamp(56.0, 340.0),
                        );

                        final contextMenuItems = isMultiSelected
                            ? [
                                MenuButton(
                                  leading: const Icon(
                                    LucideIcons.plus,
                                    size: 14,
                                    color: EditorColors.primary,
                                  ),
                                  onPressed: (ctx) {
                                    final selectedAssets = allAssets
                                        .where(
                                          (a) => _selectedAssetPaths
                                              .contains(
                                                a.relativePath,
                                              ),
                                        )
                                        .toList();
                                    for (final a
                                        in selectedAssets) {
                                      vm?.spawnActorFromAsset(a);
                                    }
                                  },
                                  child: Text(
                                    'Place (${_selectedAssetPaths.length}) in 3D Scene',
                                    style: const TextStyle(
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                if (vm != null)
                                  MenuButton(
                                    leading: const Icon(
                                      LucideIcons.refreshCw,
                                      size: 14,
                                    ),
                                    onPressed: (ctx) {
                                      for (final a in allAssets) {
                                        if (a.lmasPath != null &&
                                            _selectedAssetPaths.contains(a.relativePath)) {
                                          vm.regenerateThumbnail(a.lmasPath!);
                                        }
                                      }
                                    },
                                    child: Text(
                                      'Regenerate (${_selectedAssetPaths.length}) Thumbnails',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                const MenuDivider(),
                                if (vm != null && vm.activeCollection != null)
                                  MenuButton(
                                    leading: const Icon(LucideIcons.x, size: 14),
                                    onPressed: (_) => vm.removeFromCollection(vm.activeCollection!, asset.assetId!),
                                    child: const Text('Remove from Collection', style: TextStyle(fontSize: 10)),
                                  ),
                                if (vm != null)
                                  MenuButton(
                                    leading: const Icon(LucideIcons.library, size: 14),
                                    subMenu: [
                                      MenuButton(
                                        onPressed: (_) => _showNewCollectionModal(context, vm),
                                        child: const Text('New Collection...', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                                      ),
                                      if (vm.collections.isNotEmpty) const MenuDivider(),
                                      ...vm.collections.map((c) => MenuButton(
                                        onPressed: (_) => vm.addToCollection(c.name, asset.assetId!),
                                        child: Text(c.name, style: const TextStyle(fontSize: 10)),
                                      )),
                                    ],
                                    child: const Text('Add to Collection', style: TextStyle(fontSize: 10)),
                                  ),
                                const MenuDivider(),
                                MenuButton(
                                  leading: const Icon(
                                    LucideIcons.trash2,
                                    size: 14,
                                    color: EditorColors.destructive,
                                  ),
                                  onPressed: (ctx) {
                                    _confirmDeleteSelectedAssets(
                                      context,
                                      vm,
                                      allAssets,
                                    );
                                  },
                                  child: Text(
                                    'Delete (${_selectedAssetPaths.length}) Assets...',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: EditorColors.destructive,
                                    ),
                                  ),
                                ),
                              ]
                            : [
                                MenuButton(
                                  leading: const Icon(
                                    LucideIcons.plus,
                                    size: 14,
                                    color: EditorColors.primary,
                                  ),
                                  onPressed: (ctx) {
                                    vm?.spawnActorFromAsset(asset);
                                  },
                                  child: const Text(
                                    'Place in 3D Scene',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                                MenuButton(
                                  leading: const Icon(
                                    LucideIcons.externalLink,
                                    size: 14,
                                  ),
                                  onPressed: (ctx) {
                                    _openSubEditor(context, asset);
                                  },
                                  child: const Text(
                                    'Open Sub-Editor',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                                if (vm != null && asset.lmasPath != null) ...[
                                  MenuButton(
                                    leading: const Icon(LucideIcons.pencil, size: 14),
                                    trailing: const Text('F2', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                                    onPressed: (ctx) => _showRenameAssetDialog(context, vm, asset),
                                    child: const Text('Rename...', style: TextStyle(fontSize: 10)),
                                  ),
                                  MenuButton(
                                    leading: const Icon(LucideIcons.copy, size: 14),
                                    trailing: const Text('Ctrl+D', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                                    onPressed: (ctx) => _duplicateAssets(vm, [asset]),
                                    child: const Text('Duplicate', style: TextStyle(fontSize: 10)),
                                  ),
                                  MenuButton(
                                    key: const ValueKey('asset_menu_reference_viewer'),
                                    leading: const Icon(LucideIcons.gitFork, size: 14),
                                    onPressed: (ctx) => _showReferenceViewer(context, vm, asset),
                                    child: const Text('Reference Viewer...', style: TextStyle(fontSize: 10)),
                                  ),
                                  MenuButton(
                                    key: const ValueKey('asset_menu_size_info'),
                                    leading: const Icon(LucideIcons.hardDrive, size: 14),
                                    onPressed: (ctx) => _showSizeInfo(context, vm, asset),
                                    child: const Text('Size Info...', style: TextStyle(fontSize: 10)),
                                  ),
                                  MenuButton(
                                    key: const ValueKey('asset_menu_migrate'),
                                    leading: const Icon(LucideIcons.folderOutput, size: 14),
                                    onPressed: (ctx) => _migrateAsset(context, vm, asset),
                                    child: const Text('Migrate...', style: TextStyle(fontSize: 10)),
                                  ),
                                  // The asset's .lmas in the platform file manager.
                                  MenuButton(
                                    key: const ValueKey('asset_menu_reveal'),
                                    leading: const Icon(LucideIcons.folderSearch, size: 14),
                                    onPressed: (ctx) => FileReveal.reveal(FileReveal.resolve(vm.projectDirPath, asset.lmasPath!)),
                                    child: Text(FileReveal.menuLabel(), style: const TextStyle(fontSize: 10)),
                                  ),
                                ],
                                if (vm != null && asset.lmasPath != null)
                                  MenuButton(
                                    leading: const Icon(
                                      LucideIcons.refreshCw,
                                      size: 14,
                                    ),
                                    onPressed: (ctx) {
                                      vm.regenerateThumbnail(asset.lmasPath!);
                                    },
                                    child: const Text(
                                      'Regenerate Thumbnail',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ),
                                if (vm != null)
                                  ...sourceControlAssetMenuItems(context, vm, asset),
                                const MenuDivider(),
                                if (vm != null && vm.activeCollection != null)
                                  MenuButton(
                                    leading: const Icon(LucideIcons.x, size: 14),
                                    onPressed: (_) => vm.removeFromCollection(vm.activeCollection!, asset.assetId!),
                                    child: const Text('Remove from Collection', style: TextStyle(fontSize: 10)),
                                  ),
                                if (vm != null)
                                  MenuButton(
                                    leading: const Icon(LucideIcons.library, size: 14),
                                    subMenu: [
                                      MenuButton(
                                        onPressed: (_) => _showNewCollectionModal(context, vm),
                                        child: const Text('New Collection...', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                                      ),
                                      if (vm.collections.isNotEmpty) const MenuDivider(),
                                      ...vm.collections.map((c) => MenuButton(
                                        onPressed: (_) => vm.addToCollection(c.name, asset.assetId!),
                                        child: Text(c.name, style: const TextStyle(fontSize: 10)),
                                      )),
                                    ],
                                    child: const Text('Add to Collection', style: TextStyle(fontSize: 10)),
                                  ),
                                const MenuDivider(),
                                MenuButton(
                                  leading: const Icon(
                                    LucideIcons.trash2,
                                    size: 14,
                                    color: EditorColors.destructive,
                                  ),
                                  onPressed: (ctx) {
                                    _confirmDeleteAssetDialog(
                                      context,
                                      vm,
                                      asset,
                                    );
                                  },
                                  child: const Text(
                                    'Delete Asset...',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: EditorColors.destructive,
                                    ),
                                  ),
                                ),
                              ];

                        return EditorContextMenu(
                          items: contextMenuItems,
                          child: GestureDetector(
                            key: ValueKey(
                              'asset_item_${asset.relativePath}',
                            ),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _handleAssetClick(
                              asset,
                              filteredAssets,
                            ),
                            onSecondaryTap: () {
                              if (!_selectedAssetPaths.contains(
                                asset.relativePath,
                              )) {
                                setState(() {
                                  _selectedAssetPaths.clear();
                                  _selectedAssetPaths.add(
                                    asset.relativePath,
                                  );
                                  _lastSelectedAssetPath =
                                      asset.relativePath;
                                });
                              }
                            },
                            onDoubleTap: () =>
                                _openSubEditor(context, asset),
                            child: Draggable<RealAssetInfo>(
                              data: asset,
                              feedback: Container(
                                width: (_iconSize * 1.5).clamp(
                                  60.0,
                                  200.0,
                                ),
                                height: (_iconSize * 1.5).clamp(
                                  60.0,
                                  200.0,
                                ),
                                decoration: BoxDecoration(
                                  // The drag preview floats over
                                  // the viewport, so the popover
                                  // surface is nearly opaque.
                                  color: EditorColors.popover
                                      .withValues(alpha: 0.93),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  border: Border.all(
                                    color: EditorColors.primary,
                                    width: 2.0,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      // a drop shadow/scrim: black at 67%, not a surface
                                      color: Color(0xAA000000),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.all(6),
                                        child: hasPngThumbnail
                                            ? Image.memory(
                                                asset
                                                    .thumbnailBytes!,
                                                fit: BoxFit.contain,
                                              )
                                            : Icon(
                                                _getAssetIcon(
                                                  asset.type,
                                                ),
                                                size:
                                                    _iconSize * 0.6,
                                                color:
                                                    _getAssetColor(
                                                      asset.type,
                                                    ),
                                              ),
                                      ),
                                    ),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                      color: EditorColors.primary
                                          .withValues(alpha: 0.25),
                                      child: Text(
                                        _displayName(
                                          asset.fileName,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight:
                                              FontWeight.bold,
                                          color: Colors.white,
                                          decoration:
                                              TextDecoration.none,
                                        ),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              child: itemWidget,
                            ),
                          ),
                        );
                      }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
