part of '../content_browser_widget.dart';

/// Importing: the Import menu, the import action, and the thumbnail and
/// in-progress import cards.
mixin _ContentBrowserImport on _ContentBrowserWidgetStateBase {

  /// "Generating Thumbnails (N left)", a bar, and the asset being rendered.
  Widget _buildThumbnailProgress(EditorViewModel vm) {
    return Card(
      key: const ValueKey('thumbnail_queue_progress'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generating Thumbnails (${vm.thumbnailQueueLength} left)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(value: vm.thumbnailQueueProgress),
          ),
          const SizedBox(height: 4),
          Text(
            vm.currentThumbnailJob ?? '',
            style: const TextStyle(
              fontSize: 10,
              color: EditorColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  /// The Import button's menu: files, or a whole folder.
  void _showImportMenu(BuildContext context, EditorViewModel? vm) {
    final box = _importButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    showDropdown(
      context: context,
      // An explicit position is where the menu opens; following the anchor
      // widget would drag it to that widget's bottom centre.
      follow: false,
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      position: Offset(origin.dx, origin.dy + box.size.height + 2),
      builder: (_) => DropdownMenu(
        children: [
          MenuButton(
            key: const ValueKey('content_browser_import_files'),
            leading: const Icon(LucideIcons.fileInput, size: 12),
            onPressed: (_) => _handleImportAssetClick(context, vm),
            child: const Text('Import Asset...', style: TextStyle(fontSize: 10)),
          ),
          MenuButton(
            key: const ValueKey('content_browser_import_folder'),
            leading: const Icon(LucideIcons.folderInput, size: 12),
            onPressed: vm == null ? null : (_) => startImportAssetFolder(context, vm),
            child: const Text('Import Asset Folder...', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleImportAssetClick(
    BuildContext context,
    EditorViewModel? vm,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      // The import pipeline's own table plus every
      // plugin importer's extensions.
      allowedExtensions: vm?.importExtensions ?? ImportFormats.extensions,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final filePaths = result.files.map((e) => e.path!).toList();
      // A plugin's formats go to the plugin, without the pipeline's options.
      final pluginFiles = [for (final p in filePaths) if (vm?.pluginImporterFor(p) != null) p];
      final pipelineFiles = [for (final p in filePaths) if (!pluginFiles.contains(p)) p];
      if (pluginFiles.isNotEmpty) await vm!.importWithPluginImporters(pluginFiles);
      if (pipelineFiles.isNotEmpty && context.mounted) {
        showImportAssetOptionsDialog(context, vm, pipelineFiles);
      }
    }
  }

  Widget _buildImportingCard(EditorViewModel vm) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: EditorColors.primary.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: EditorColors.primary.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: EditorColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: EditorColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: EditorColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Importing Asset in Background...',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: EditorColors.foreground,
                      ),
                    ),
                    if (vm.importProgress != null)
                      Text(
                        '${(vm.importProgress! * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: EditorColors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  vm.importStatusMessage.isNotEmpty
                      ? vm.importStatusMessage
                      : 'Processing 3D geometry and generating thumbnails...',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: EditorColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: vm.importProgress,
                    minHeight: 4,
                    backgroundColor: EditorColors.secondary,
                    color: EditorColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
