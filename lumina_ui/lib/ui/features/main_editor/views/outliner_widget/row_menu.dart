part of '../outliner_widget.dart';

/// An outliner row's context menu (rename, folders, attach, visibility,
/// reveal) and the Add Actor and folder-delete dialogs.
mixin _OutlinerRowMenu on _OutlinerWidgetStateBase, _OutlinerRenameAndDrop {
  /// The absolute path of the asset file [node] is placed from, when it is
  /// on disk: its mesh, else a placed Blueprint's class `.lmas`.
  String? _assetFileOf(EditorActorNode node) {
    final ref = node.meshAssetPath ?? node.blueprintClass;
    if (ref == null || ref.isEmpty) return null;
    final path = FileReveal.resolve(_vm.projectDirPath, ref);
    return File(path).existsSync() ? path : null;
  }

  List<MenuItem> _rowMenu(EditorActorNode node, List<String> ids) {
    final vm = _vm;
    final isFolder = node.type == 'Folder';
    final targets = vm.folderPaths.where((f) => ids.any((id) => vm.canMoveToFolder(id, f.folder.id))).toList();
    final canMoveToRoot = ids.any((id) => vm.canMoveToFolder(id, null));

    return [
      MenuButton(
        leading: const Icon(LucideIcons.pencil, size: 14),
        trailing: const Text('F2', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        onPressed: (ctx) => vm.requestOutlinerRename(node.id),
        child: const Text('Rename', style: TextStyle(fontSize: 10)),
      ),
      MenuButton(
        leading: const Icon(LucideIcons.folderPlus, size: 14),
        onPressed: (ctx) => isFolder
            ? vm.createFolder(parentFolderId: node.id)
            : vm.createFolder(parentFolderId: _sharedParentFolder(ids), wrapIds: ids),
        child: Text(isFolder ? 'New Subfolder' : 'New Folder', style: const TextStyle(fontSize: 10)),
      ),
      MenuButton(
        leading: const Icon(LucideIcons.folderInput, size: 14),
        subMenu: [
          if (canMoveToRoot)
            MenuButton(
              onPressed: (ctx) => vm.moveToFolder(ids, null),
              child: const Text('(Root)', style: TextStyle(fontSize: 10)),
            ),
          for (final target in targets)
            MenuButton(
              leading: const Icon(LucideIcons.folder, size: 12),
              onPressed: (ctx) => vm.moveToFolder(ids, target.folder.id),
              child: Text(target.path, style: const TextStyle(fontSize: 10)),
            ),
          if (canMoveToRoot || targets.isNotEmpty) const MenuDivider(),
          MenuButton(
            leading: const Icon(LucideIcons.folderPlus, size: 12),
            onPressed: (ctx) => vm.createFolder(parentFolderId: _sharedParentFolder(ids), wrapIds: ids),
            child: const Text('New Folder…', style: TextStyle(fontSize: 10)),
          ),
        ],
        child: const Text('Move to Folder', style: TextStyle(fontSize: 10)),
      ),
      if (!isFolder) ...[
        MenuButton(
          leading: const Icon(LucideIcons.copy, size: 14),
          onPressed: (ctx) => vm.duplicateSelectedActor(),
          child: const Text('Duplicate', style: TextStyle(fontSize: 10)),
        ),
        MenuButton(
          leading: const Icon(LucideIcons.locate, size: 14, color: EditorColors.accent),
          onPressed: (ctx) => vm.focusCameraOnActor(node),
          child: const Text('Focus Camera on Actor', style: TextStyle(fontSize: 10)),
        ),
        // The file the actor is placed from (its mesh, or a Blueprint's
        // class asset) in the platform file manager.
        if (_assetFileOf(node) case final asset?)
          MenuButton(
            key: const ValueKey('outliner_menu_reveal_asset'),
            leading: const Icon(LucideIcons.folderSearch, size: 14),
            onPressed: (ctx) => FileReveal.reveal(asset),
            child: Text(FileReveal.menuLabel(subject: 'Asset'), style: const TextStyle(fontSize: 10)),
          ),
      ],
      if (node.type == 'Environment' || node.type == 'Light' || node.type == 'DirectionalLight')
        MenuButton(
          leading: const Icon(LucideIcons.sun, size: 14, color: EditorColors.warning),
          onPressed: (ctx) => vm.commands.execute('tools.environmentLighting'),
          child: const Text('Open Environment Mixer', style: TextStyle(fontSize: 10)),
        ),
      if (isFolder) ...[
        const MenuDivider(),
        MenuButton(
          leading: const Icon(LucideIcons.chevronsUpDown, size: 14),
          onPressed: (ctx) => vm.expandAllInOutliner(under: node.id),
          child: const Text('Expand All Inside', style: TextStyle(fontSize: 10)),
        ),
        MenuButton(
          leading: const Icon(LucideIcons.chevronsDownUp, size: 14),
          onPressed: (ctx) => vm.collapseAllInOutliner(under: node.id),
          child: const Text('Collapse All Inside', style: TextStyle(fontSize: 10)),
        ),
      ],
      const MenuDivider(),
      MenuButton(
        leading: const Icon(LucideIcons.trash2, size: 14, color: EditorColors.destructive),
        onPressed: (ctx) {
          if (isFolder) {
            _showFolderDeleteDialog(context, vm, node.id);
          } else {
            vm.deleteActorSubtreeWithTransaction(node.id);
          }
        },
        child: Text(
          isFolder ? 'Delete Folder' : 'Delete Actor',
          style: const TextStyle(fontSize: 10, color: EditorColors.destructive),
        ),
      ),
    ];
  }

  void _showAddActorDialog(BuildContext context, EditorViewModel vm) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) => AlertDialog(
        title: const Text('Spawn New Actor Into Scene'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final category in EditorActorCatalog.categories) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      category.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: EditorColors.mutedForeground,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  for (final type in EditorActorCatalog.inCategory(category))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SizedBox(
                        width: double.infinity,
                        child: Builder(
                          builder: (context) {
                            final refusal = vm.spawnRefusalFor(type.id);
                            return OutlineButton(
                              key: ValueKey('spawn_actor_${type.id}'),
                              onPressed: refusal != null
                                  ? null
                                  : () {
                                      vm.spawnNewActor(type.id, parentId: vm.selectedActorId);
                                      Navigator.of(context).pop();
                                    },
                              child: Row(
                                children: [
                                  Icon(type.icon, size: 14, color: type.color),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(type.label, style: const TextStyle(fontSize: 10)),
                                        Text(
                                          refusal ?? type.description,
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            color: refusal != null ? EditorColors.logWarning : EditorColors.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          OutlineButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  void _showFolderDeleteDialog(BuildContext context, EditorViewModel vm, String id) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: const Text('Do you want to delete the contents as well, or keep the children?'),
        actions: [
          OutlineButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(fontSize: 10)),
          ),
          OutlineButton(
            onPressed: () {
              vm.deleteActorSubtreeWithTransaction(id, keepChildren: true);
              Navigator.of(context).pop();
            },
            child: const Text('Keep Children', style: TextStyle(fontSize: 10)),
          ),
          DestructiveButton(
            onPressed: () {
              vm.deleteActorSubtreeWithTransaction(id, keepChildren: false);
              Navigator.of(context).pop();
            },
            child: const Text('Delete Contents', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }
}
