import 'package:lumina/lumina.dart' show RealAssetInfo;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/services/file_reveal.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/affected_actors_note.dart';
import 'package:lumina_ui/ui/features/main_editor/views/import_asset_folder_dialog.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';

/// A subfolder tile at the top of the content browser grid:
/// a click selects it, a double-click enters it, an
/// asset dropped on it moves there, and its context menu offers Open, New
/// Folder, Rename, Delete and Favorites.
class ContentBrowserFolderTile extends StatelessWidget {
  const ContentBrowserFolderTile({
    super.key,
    required this.viewModel,
    required this.path,
    required this.width,
    required this.height,
    required this.selected,
    required this.onSelect,
  });

  final EditorViewModel viewModel;
  final String path;
  final double width;
  final double height;
  final bool selected;
  final VoidCallback onSelect;

  String get _name => path.split('/').last;

  void _enter() {
    viewModel.showRecentlyModified = false;
    viewModel.activeCollection = null;
    viewModel.selectedFolder = path;
  }

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final assetCount = vm.realAssets.where((a) => a.relativePath.startsWith('$path/')).length;
    return EditorContextMenu(
      items: contentFolderMenuItems(context, vm, path, onOpen: _enter),
      child: DragTarget<RealAssetInfo>(
        onWillAcceptWithDetails: (details) => !details.data.relativePath.startsWith('$path/'),
        onAcceptWithDetails: (details) => vm.moveAssetToFolder(details.data, path),
        builder: (context, candidates, rejected) {
          final hover = candidates.isNotEmpty;
          final highlight = hover || selected;
          return GestureDetector(
            key: ValueKey('folder_tile_$path'),
            behavior: HitTestBehavior.opaque,
            onTap: onSelect,
            onDoubleTap: _enter,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: highlight ? EditorColors.primary.withValues(alpha: hover ? 0.3 : 0.18) : EditorColors.card,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: highlight ? EditorColors.primary : EditorColors.border,
                  width: highlight ? 1.8 : 1.0,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Icon(
                        LucideIcons.folder,
                        size: (height * 0.4).clamp(14.0, 120.0),
                        color: highlight ? EditorColors.primary : Colors.amber,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: highlight ? EditorColors.primary : EditorColors.foreground,
                      ),
                    ),
                  ),
                  Text(
                    assetCount == 1 ? '1 asset' : '$assetCount assets',
                    style: const TextStyle(fontSize: 7, color: EditorColors.mutedForeground),
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The folder context menu shared by the grid's folder tiles and the Sources
/// tree: Open (when [onOpen] is given), New Folder, Import Folder Here,
/// Rename, Delete, Show in Explorer (the platform file manager) and
/// Favorites. The `contents` root offers New Folder, Import Folder Here,
/// Show in Explorer and Favorites only.
List<MenuItem> contentFolderMenuItems(BuildContext context, EditorViewModel vm, String path, {VoidCallback? onOpen}) {
  final isRoot = !path.contains('/');
  return [
    if (onOpen != null)
      MenuButton(
        leading: const Icon(LucideIcons.folderOpen, size: 12),
        onPressed: (_) => onOpen(),
        child: const Text('Open', style: TextStyle(fontSize: 10)),
      ),
    MenuButton(
      leading: const Icon(LucideIcons.folderPlus, size: 12),
      onPressed: (_) => showNewContentFolderDialog(context, vm, path),
      child: const Text('New Folder...', style: TextStyle(fontSize: 10)),
    ),
    // A folder from disk, imported into this one.
    MenuButton(
      leading: const Icon(LucideIcons.folderInput, size: 12),
      onPressed: (_) => startImportAssetFolder(context, vm, targetFolder: path),
      child: const Text('Import Folder Here...', style: TextStyle(fontSize: 10)),
    ),
    if (!isRoot) ...[
      MenuButton(
        leading: const Icon(LucideIcons.pencil, size: 12),
        onPressed: (_) => showRenameContentFolderDialog(context, vm, path),
        child: const Text('Rename...', style: TextStyle(fontSize: 10)),
      ),
      MenuButton(
        leading: const Icon(LucideIcons.trash2, size: 12, color: EditorColors.destructive),
        onPressed: (_) => showDeleteContentFolderDialog(context, vm, path),
        child: const Text('Delete...', style: TextStyle(fontSize: 10, color: EditorColors.destructive)),
      ),
    ],
    const MenuDivider(),
    MenuButton(
      key: ValueKey('folder_menu_reveal_$path'),
      leading: const Icon(LucideIcons.folderSearch, size: 12),
      onPressed: (_) => FileReveal.reveal(FileReveal.resolve(vm.projectDirPath, path)),
      child: Text(FileReveal.menuLabel(), style: const TextStyle(fontSize: 10)),
    ),
    MenuButton(
      leading: const Icon(LucideIcons.star, size: 12),
      onPressed: (_) => vm.toggleFavoriteFolder(path),
      child: Text(vm.favoriteFolders.contains(path) ? 'Remove from Favorites' : 'Add to Favorites',
          style: const TextStyle(fontSize: 10)),
    ),
  ];
}

void _showFolderNameDialog(
  BuildContext context, {
  required String title,
  required String initial,
  required String confirm,
  required String? Function(String name) onConfirm,
}) {
  final controller = TextEditingController(text: initial);
  String? error;
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (dialogContext) {
      return StatefulBuilder(builder: (dialogContext, setModal) {
        void submit() {
          final err = onConfirm(controller.text);
          if (err == null) {
            Navigator.of(dialogContext).pop();
          } else {
            setModal(() => error = err);
          }
        }

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey('content_folder_name_field'),
                  controller: controller,
                  autofocus: true,
                  onSubmitted: (_) => submit(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 6),
                  Text(error!, style: const TextStyle(fontSize: 10, color: EditorColors.destructive)),
                ],
              ],
            ),
          ),
          actions: [
            OutlineButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            PrimaryButton(onPressed: submit, child: Text(confirm)),
          ],
        );
      });
    },
  );
}

/// New Folder under [parent]; the browser then shows [parent] with the new
/// tile.
void showNewContentFolderDialog(BuildContext context, EditorViewModel vm, String parent) {
  _showFolderNameDialog(
    context,
    title: 'New Folder in ${parent.split('/').last}',
    initial: 'NewFolder',
    confirm: 'Create',
    onConfirm: (name) {
      if (name.trim().isEmpty) return 'Enter a folder name.';
      vm.createContentFolder(parent, name);
      vm.selectedFolder = parent;
      return null;
    },
  );
}

/// Rename [folder]; references to its assets follow the new path.
void showRenameContentFolderDialog(BuildContext context, EditorViewModel vm, String folder) {
  _showFolderNameDialog(
    context,
    title: 'Rename Folder',
    initial: folder.split('/').last,
    confirm: 'Rename',
    onConfirm: (name) =>
        vm.renameContentFolder(folder, name) == null ? 'That name is empty, invalid or already taken.' : null,
  );
}

/// Confirms, then deletes [folder] with every asset in it.
void showDeleteContentFolderDialog(BuildContext context, EditorViewModel vm, String folder) {
  final inside = vm.realAssets.where((a) => a.relativePath.startsWith('$folder/')).toList();
  final count = inside.length;
  final holdsLevel = vm.project.activeLevel.startsWith('$folder/');
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete Folder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            holdsLevel
                ? '"${folder.split('/').last}" holds the open level and cannot be deleted.'
                : 'Permanently delete "${folder.split('/').last}" and its $count asset(s)?',
            style: const TextStyle(fontSize: 11),
          ),
          if (!holdsLevel) AffectedActorsNote(actors: vm.actorsReferencingAssets(inside)),
        ],
      ),
      actions: [
        OutlineButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
        if (!holdsLevel)
          DestructiveButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              vm.deleteContentFolder(folder);
            },
            child: const Text('Delete'),
          ),
      ],
    ),
  );
}
