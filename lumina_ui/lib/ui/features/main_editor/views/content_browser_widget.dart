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
part 'content_browser_widget/toolbar.dart';
part 'content_browser_widget/asset_area.dart';

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
        _ContentBrowserAssetTile,
        _ContentBrowserToolbar,
        _ContentBrowserAssetArea {

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
                _buildContentToolbar(context, vm),

                const Divider(height: 1),

                // Search & Path Bar
                _buildSearchAndPathBar(context, vm, allAssets, filteredAssets),

                const Divider(height: 1),

                // Assets Grid or Empty Placeholder
                _buildAssetArea(context, vm, allAssets, filteredAssets, visibleFolders),
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
