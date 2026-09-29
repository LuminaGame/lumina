part of '../content_browser_widget.dart';

/// Delete confirmation dialogs for one asset or the whole selection.
mixin _ContentBrowserDeletion on _ContentBrowserWidgetStateBase {
  /// A delete moves the files to the project trash as
  /// one undo step (files and actors come back with Edit → Undo), and a
  /// toast names the trash entry.
  void _deleteToTrash(EditorViewModel? vm, List<RealAssetInfo> assets) {
    if (vm == null || assets.isEmpty) return;
    final browserContext = context;
    vm.deleteAssetsToTrash(assets.toSet().toList()).then((result) {
      if (!browserContext.mounted) return;
      showToast(
        context: browserContext,
        location: ToastLocation.bottomRight,
        builder: (toastContext, overlay) => SurfaceCard(
          child: Basic(
            title: const Text('Moved to the project trash'),
            content: Text(
              '${result.entry.files.length} file(s) → .lumina/trash/${result.entry.id}. Edit → Undo brings them back.',
              key: const ValueKey('delete_trash_toast'),
            ),
          ),
        ),
      );
    });
  }

  void _confirmDeleteAssetDialog(
    BuildContext context,
    EditorViewModel? vm,
    RealAssetInfo asset,
  ) {
    final baseName = asset.fileName.split('.').first;
    final allAssets = vm?.realAssets ?? [];

    final linkedDependencies = allAssets.where((a) {
      if (a.relativePath == asset.relativePath) return false;
      final aBase = a.fileName.split('.').first;
      return aBase.contains(baseName) || baseName.contains(aBase);
    }).toList();

    final selectedToDelete = <RealAssetInfo>{...linkedDependencies};

    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AlertDialog(
                title: const Text('Delete Asset & Dependencies'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Move "${_displayName(asset.fileName)}" to the project trash? Edit → Undo or '
                      'AI Agent Access → Trash brings it back.',
                      key: const ValueKey('delete_dialog_trash_note'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: EditorColors.foreground,
                      ),
                    ),
                    AffectedActorsNote(
                      actors: vm?.actorsReferencingAssets({asset, ...selectedToDelete}) ?? const [],
                    ),
                    if (linkedDependencies.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Associated materials & textures to move to the trash:',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: EditorColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...linkedDependencies.map((dep) {
                        final isChecked = selectedToDelete.contains(dep);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Checkbox(
                                state: isChecked
                                    ? CheckboxState.checked
                                    : CheckboxState.unchecked,
                                onChanged: (val) {
                                  setStateModal(() {
                                    if (val == CheckboxState.checked) {
                                      selectedToDelete.add(dep);
                                    } else {
                                      selectedToDelete.remove(dep);
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                _getAssetIcon(dep.type),
                                size: 12,
                                color: _getAssetColor(dep.type),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _displayName(dep.fileName),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: EditorColors.foreground,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
                actions: [
                  OutlineButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  PrimaryButton(
                    onPressed: () {
                      _deleteToTrash(vm, [asset, ...selectedToDelete]);
                      setState(() {
                        _selectedAssetPaths.remove(asset.relativePath);
                        if (_lastSelectedAssetPath == asset.relativePath) {
                          _lastSelectedAssetPath = null;
                        }
                      });
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Delete Selected',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteSelectedAssets(
    BuildContext context,
    EditorViewModel? vm,
    List<RealAssetInfo> allAssets,
  ) {
    final selectedAssets = allAssets
        .where((a) => _selectedAssetPaths.contains(a.relativePath))
        .toList();
    if (selectedAssets.isEmpty) return;

    if (selectedAssets.length == 1) {
      _confirmDeleteAssetDialog(context, vm, selectedAssets.first);
      return;
    }

    final allSelectedBases = selectedAssets
        .map((a) => a.fileName.split('.').first)
        .toSet();
    final linkedDependencies = allAssets.where((a) {
      if (selectedAssets.any((s) => s.relativePath == a.relativePath)) {
        return false;
      }
      final aBase = a.fileName.split('.').first;
      return allSelectedBases.any(
        (baseName) => aBase.contains(baseName) || baseName.contains(aBase),
      );
    }).toList();

    final selectedToDelete = <RealAssetInfo>{...linkedDependencies};

    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AlertDialog(
                title: Text(
                  'Delete ${selectedAssets.length} Assets & Dependencies',
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Move these ${selectedAssets.length} selected assets to the project trash? Edit → Undo or '
                      'AI Agent Access → Trash brings them back.',
                      key: const ValueKey('delete_dialog_trash_note'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: EditorColors.foreground,
                      ),
                    ),
                    AffectedActorsNote(
                      actors: vm?.actorsReferencingAssets({...selectedAssets, ...selectedToDelete}) ?? const [],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: EditorColors.cardHeader,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EditorColors.border),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: selectedAssets.length,
                        separatorBuilder: (_, _) => const Divider(height: 4),
                        itemBuilder: (context, idx) {
                          final item = selectedAssets[idx];
                          return Row(
                            children: [
                              Icon(
                                _getAssetIcon(item.type),
                                size: 12,
                                color: _getAssetColor(item.type),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _displayName(item.fileName),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: EditorColors.foreground,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                item.formattedSize,
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: EditorColors.mutedForeground,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    if (linkedDependencies.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Associated materials & textures to move to the trash:',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: EditorColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 90),
                        child: ListView(
                          shrinkWrap: true,
                          children: linkedDependencies.map((dep) {
                            final isChecked = selectedToDelete.contains(dep);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  Checkbox(
                                    state: isChecked
                                        ? CheckboxState.checked
                                        : CheckboxState.unchecked,
                                    onChanged: (val) {
                                      setStateModal(() {
                                        if (val == CheckboxState.checked) {
                                          selectedToDelete.add(dep);
                                        } else {
                                          selectedToDelete.remove(dep);
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    _getAssetIcon(dep.type),
                                    size: 12,
                                    color: _getAssetColor(dep.type),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _displayName(dep.fileName),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: EditorColors.foreground,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  OutlineButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  PrimaryButton(
                    onPressed: () {
                      _deleteToTrash(vm, [...selectedAssets, ...selectedToDelete]);
                      setState(() {
                        _selectedAssetPaths.clear();
                        _lastSelectedAssetPath = null;
                      });
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Delete (${selectedAssets.length + selectedToDelete.length}) Assets',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
