import 'dart:async';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/services/file_reveal.dart';
import 'package:lumina_ui/ui/core/theme/asset_type_style.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/affected_actors_note.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_folder_tile.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_folder_tree.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_layout_state.dart';
import 'package:lumina_ui/ui/features/main_editor/services/asset_editor_category.dart';
import 'package:lumina_ui/ui/features/main_editor/views/import_asset_options_dialog.dart';
import 'package:lumina_ui/ui/features/main_editor/views/import_asset_folder_dialog.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/landscape_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/anim_blueprint/create_anim_asset_dialog.dart';
import 'package:lumina_ui/ui/features/source_control/source_control_commands.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_asset_catalog.dart';
import 'package:lumina_ui/ui/features/source_control/views/source_control_badge.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';

part 'content_browser_widget/state.dart';
part 'content_browser_widget/selection.dart';
part 'content_browser_widget/import.dart';
part 'content_browser_widget/new_asset.dart';
part 'content_browser_widget/deletion.dart';
part 'content_browser_widget/rename_duplicate.dart';
part 'content_browser_widget/references_size_migrate.dart';
part 'content_browser_widget/create_blueprint_dialog.dart';
part 'content_browser_widget/item_builders.dart';
part 'content_browser_widget/asset_tile.dart';
part 'content_browser_widget/lumina_classes.dart';

class ContentBrowserWidget extends StatefulWidget {
  final EditorViewModel? viewModel;

  const ContentBrowserWidget({super.key, this.viewModel});

  @override
  State<ContentBrowserWidget> createState() => _ContentBrowserWidgetState();
}

class _ContentBrowserWidgetState extends _ContentBrowserWidgetStateBase
    with
        _ContentBrowserSelection,
        _ContentBrowserImport,
        _ContentBrowserNewAsset,
        _ContentBrowserDeletion,
        _ContentBrowserRenameDuplicate,
        _ContentBrowserReferencesSizeMigrate,
        _ContentBrowserCreateBlueprintDialog,
        _ContentBrowserItemBuilders,
        _ContentBrowserAssetTile {

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.viewModel?.searchQuery ?? '';
  }

  @override
  void dispose() {
    _searchDebouncer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _browserFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    if (vm != null) _applyRevealRequest(vm);
    final allAssets = vm?.realAssets ?? [];

    final filteredAssets = vm?.visibleAssets ?? [];
    final visibleFolders = vm?.visibleFolders ?? const <String>[];

    final browser = Focus(
      focusNode: _browserFocusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.delete ||
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_selectedAssetPaths.isNotEmpty) {
              _confirmDeleteSelectedAssets(context, vm, allAssets);
              return KeyEventResult.handled;
            }
          }
          // Ctrl+F searches the browser; Ctrl+P is the editor's
          // Open Asset palette everywhere.
          if (event.logicalKey == LogicalKeyboardKey.keyF && (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
            _searchFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.f5) {
            vm?.refreshAssets();
            return KeyEventResult.handled;
          }
          // F2 renames the one selected asset; Ctrl+D duplicates the
          // selection.
          final selected = allAssets.where((a) => _selectedAssetPaths.contains(a.relativePath)).toList();
          if (event.logicalKey == LogicalKeyboardKey.f2 && selected.length == 1) {
            _showRenameAssetDialog(context, vm, selected.single);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.keyD &&
              (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed) &&
              selected.isNotEmpty) {
            _duplicateAssets(vm, selected);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      // The Sources rail and the asset grid split by the
      // editor shell's own resizable splitter; the rail's width is part of
      // the persisted layout (one write per drag) and Reset Layout re-keys
      // the pane, since a pane ignores a changed initial size.
      child: ResizablePanel.horizontal(
        draggerBuilder: (context) => const HorizontalResizableDragger(),
        children: [
          ResizablePane(
            key: ValueKey('content_browser_sources_pane_${vm?.layoutState.resetSerial ?? 0}'),
            initialSize: vm?.layoutState.sourcesWidth ?? EditorLayoutState.defaultSourcesWidth,
            minSize: EditorLayoutState.minSourcesWidth,
            maxSize: EditorLayoutState.maxSourcesWidth,
            onSizeChangeEnd: (size) => vm?.setPaneSize(sourcesWidth: size),
            child: Container(
              // `bg-[oklch(0.1 0 0)]` — the prototype's Sources column.
              key: const ValueKey('content_browser_sources_rail'),
              color: EditorColors.rail,
              child: ContentBrowserSourcesRail(
                vm: vm,
                before: [
                  // FAVORITES
                  if (vm != null && vm.favoriteFolders.isNotEmpty) ...[
                    _buildSectionHeader('FAVORITES', icon: LucideIcons.star),
                    ...vm.favoriteFolders.map((f) => _buildFolderItem(f, vm)),
                    const SizedBox(height: 12),
                  ],

                  // SOURCES (the tree follows)
                  _buildSectionHeader('SOURCES', action: () => _handleImportAssetClick(context, vm), actionIcon: LucideIcons.plus),
                ],
                after: [
                  const SizedBox(height: 12),

                  // COLLECTIONS
                  _buildSectionHeader('COLLECTIONS', action: () => _showNewCollectionModal(context, vm), actionIcon: LucideIcons.plus),
                  if (vm != null)
                    ...vm.collections.map((c) => _buildCollectionItem(c, vm)),
                  const SizedBox(height: 12),

                  // SMART VIEWS
                  _buildSectionHeader('SMART VIEWS'),
                  _buildSmartViewItem('Recently Modified', LucideIcons.clock, vm),
                  if (vm != null) _buildMarketplaceSmartView(vm),
                ],
              ),
            ),
          ),

          // Main Content View
          ResizablePane.flex(
            child: Column(
              children: [
                // Content Toolbar & Filter Tabs
                Container(
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
                ),

                const Divider(height: 1),

                // Search & Path Bar
                Container(
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
                ),

                const Divider(height: 1),

                // Assets Grid or Empty Placeholder
                Expanded(
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
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // The thumbnail queue's progress card floats over the browser's corner
    // while stale thumbnails re-render in the background.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // A click anywhere in the browser gives it the keyboard; a click in
        // its search box keeps the box focused.
        Listener(
          onPointerDown: (_) {
            if (!_browserFocusNode.hasFocus) _browserFocusNode.requestFocus();
          },
          child: browser,
        ),
        if (vm != null && vm.thumbnailQueueLength > 0)
          Positioned(
            bottom: 16,
            right: 16,
            child: _buildThumbnailProgress(vm),
          ),
      ],
    );
  }
}
