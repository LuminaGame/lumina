part of '../content_browser_widget.dart';

/// Row and tile builders: folders, asset icons/colours, sidebar section
/// headers, collections, smart views and breadcrumbs.
mixin _ContentBrowserItemBuilders on _ContentBrowserWidgetStateBase {

  /// A Favorites row: the Sources tree's row without a chevron.
  Widget _buildFolderItem(String path, EditorViewModel? vm) {
    return ContentFolderRow(
      key: ValueKey('favorite_folder_row_$path'),
      path: path,
      vm: vm,
      selected: vm?.selectedFolder == path && !(vm?.showRecentlyModified ?? false) && vm?.activeCollection == null,
      onTap: () {
        vm?.showRecentlyModified = false;
        vm?.activeCollection = null;
        vm?.selectedFolder = path;
      },
    );
  }

  /// The type icon and colour come from the shared [AssetTypeStyle],
  /// so the tile, its strip and the dialogs agree.
  @override
  IconData _getAssetIcon(AssetType type) => AssetTypeStyle.of(type).icon;

  @override
  Color _getAssetColor(AssetType type) => AssetTypeStyle.of(type).color;

  Widget _buildSectionHeader(String title, {VoidCallback? action, IconData? actionIcon, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 10, color: EditorColors.mutedForeground), const SizedBox(width: 4)],
              Text(
                title,
                // `text-[9px] uppercase tracking-widest text-muted-foreground
                //  font-semibold` on the Sources heading.
                style: EditorTypography.panelHeading
                    .copyWith(fontSize: EditorTypography.captionSize),
              ),
            ],
          ),
          if (action != null && actionIcon != null)
            GhostButton(
              onPressed: action,
              child: Icon(actionIcon, size: 10, color: EditorColors.primary),
            ),
        ],
      ),
    );
  }

  Widget _buildCollectionItem(Collection c, EditorViewModel vm) {
    final isSelected = vm.activeCollection == c.name;
    return EditorContextMenu(
      items: [
        MenuButton(
          onPressed: (_) => vm.deleteCollection(c.name),
          child: const Text('Delete Collection', style: TextStyle(fontSize: 10, color: EditorColors.destructive)),
        ),
      ],
      child: GestureDetector(
        onTap: () => vm.activeCollection = c.name,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? EditorColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.library,
                    size: 11,
                    color: isSelected
                        ? EditorColors.primary
                        : EditorColors.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.name,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? EditorColors.primary : EditorColors.foreground,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: EditorColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${c.assets.length}', style: const TextStyle(fontSize: 8, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The Marketplace smart view: every asset under
  /// `contents/Marketplace/`.
  Widget _buildMarketplaceSmartView(EditorViewModel vm) {
    final selected = vm.showMarketplaceAssets;
    final color = selected ? EditorColors.primary : EditorColors.foreground;
    return GestureDetector(
      key: const ValueKey('content_browser_smart_view_marketplace'),
      onTap: () => vm.showMarketplaceAssets = true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? EditorColors.primary.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.store, size: 11, color: selected ? EditorColors.primary : EditorColors.mutedForeground),
            const SizedBox(width: 6),
            Text('Marketplace',
                style: TextStyle(fontSize: 9, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartViewItem(String name, IconData icon, EditorViewModel? vm) {
    final isSelected = vm?.showRecentlyModified ?? false;
    return GestureDetector(
      onTap: () => vm?.showRecentlyModified = true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? EditorColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 11,
              color: isSelected
                  ? EditorColors.primary
                  : EditorColors.mutedForeground,
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? EditorColors.primary : EditorColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewCollectionModal(BuildContext context, EditorViewModel? vm) {
    final controller = TextEditingController();
    showOverlay(context, const DialogConfiguration(), builder: (context) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AlertDialog(
          title: const Text('New Collection'),
          content: TextField(
            controller: controller,
            placeholder: const Text('Collection Name'),
            autofocus: true,
          ),
          actions: [
            OutlineButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            PrimaryButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  vm?.createCollection(controller.text.trim());
                }
                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      );
    });
  }
  
  List<Widget> _buildBreadcrumbs(EditorViewModel? vm) {
    if (vm == null) return [];
    if (vm.showMarketplaceAssets) {
      return [Text('Marketplace', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary))];
    }
    if (vm.showRecentlyModified) {
      return [const Text('Recently Modified', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary))];
    }
    if (vm.activeCollection != null) {
      return [const Text('Collection: ', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)), Text(vm.activeCollection!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary))];
    }
    
    final path = vm.selectedFolder ?? 'contents';
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final List<Widget> widgets = [];
    
    String currentPath = '';
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      currentPath += (i == 0) ? seg : '/$seg';
      final isLast = i == segments.length - 1;
      
      final navPath = currentPath;
      widgets.add(
        GhostButton(
          density: ButtonDensity.compact,
          onPressed: () {
            vm.activeCollection = null;
            vm.showRecentlyModified = false;
            vm.selectedFolder = navPath;
          },
          child: Text(seg, style: TextStyle(fontSize: 10, fontWeight: isLast ? FontWeight.bold : FontWeight.normal, color: isLast ? EditorColors.primary : EditorColors.foreground)),
        ),
      );
      
      if (!isLast) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('›', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        ));
      }
    }
    return widgets;
  }
}
