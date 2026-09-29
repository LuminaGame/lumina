part of '../content_browser_widget.dart';

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Content Browser → Reference Viewer…, Size Info… and Migrate… on an asset,
/// over the `.lmas` reference graph.
mixin _ContentBrowserReferencesSizeMigrate on _ContentBrowserWidgetStateBase {
  /// What the asset depends on and what references it; a row click browses
  /// the Content Browser to that asset.
  void _showReferenceViewer(BuildContext context, EditorViewModel vm, RealAssetInfo asset) {
    final id = asset.assetId;
    final dependencies = id == null ? const <RealAssetInfo>[] : vm.dependenciesOf(id);
    final referencers = id == null ? const <RealAssetInfo>[] : vm.referencersOf(id);

    Widget section(String title, String keyName, List<RealAssetInfo> assets, String empty, BuildContext dialogContext) =>
        Column(
          key: ValueKey('reference_viewer_$keyName'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$title (${assets.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (assets.isEmpty)
              Text(empty, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground))
            else
              for (final a in assets)
                GhostButton(
                  key: ValueKey('reference_viewer_${keyName}_${a.relativePath}'),
                  density: ButtonDensity.compact,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    vm.browseToAsset(a);
                  },
                  child: Row(children: [
                    Icon(AssetTypeStyle.of(a.type).icon, size: 12, color: AssetTypeStyle.of(a.type).color),
                    const SizedBox(width: 6),
                    Expanded(child: Text(a.relativePath, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                  ]),
                ),
            const SizedBox(height: 10),
          ],
        );

    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: Text('Reference Viewer — ${_displayName(asset.fileName)}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              section('Depends on', 'dependencies', dependencies, 'References no other asset.', dialogContext),
              section('Referenced by', 'referencers', referencers, 'No asset references it.', dialogContext),
            ]),
          ),
        ),
        actions: [
          OutlineButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  /// The asset's own file, its decoded payload and thumbnail, and its whole
  /// dependency closure on disk.
  void _showSizeInfo(BuildContext context, EditorViewModel vm, RealAssetInfo asset) {
    final path = asset.lmasPath;
    if (path == null) return;
    final info = vm.sizeInfo(path);
    Widget row(String label, String key) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
            Text(_formatBytes(info[key] ?? 0), key: ValueKey('size_info_$key'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        );
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: Text('Size Info — ${_displayName(asset.fileName)}'),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            row('.lmas file', 'file'),
            row('Payload (decoded)', 'payload'),
            row('Thumbnail', 'thumbnail'),
            row('Dependency closure on disk', 'closure'),
          ]),
        ),
        actions: [
          OutlineButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  /// Picks a target project, previews the closure with sizes and conflicts,
  /// then copies it (conflicting files are skipped, never overwritten).
  Future<void> _migrateAsset(BuildContext context, EditorViewModel vm, RealAssetInfo asset) async {
    final path = asset.lmasPath;
    if (path == null) return;
    final pick = vm.migrateTargetPicker ?? () => FilePicker.platform.getDirectoryPath(dialogTitle: 'Migrate to project');
    final target = await pick();
    if (target == null || !context.mounted) return;
    List<AssetMigrateEntry> preview;
    try {
      preview = vm.migratePreview(path, target);
    } on ArgumentError catch (e) {
      if (context.mounted) _showMigrateMessage(context, 'Cannot migrate', '${e.message}');
      return;
    }
    if (!context.mounted) return;
    final conflicts = preview.where((e) => e.conflict).length;
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: Text('Migrate ${_displayName(asset.fileName)}'),
        content: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('To $target', style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Column(children: [
                  for (final e in preview)
                    Padding(
                      key: ValueKey('migrate_row_${e.relativePath}'),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Expanded(child: Text(e.relativePath, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                        Text(_formatBytes(e.bytes), style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                        if (e.conflict) ...[
                          const SizedBox(width: 8),
                          const Text('exists — skipped', style: TextStyle(fontSize: 10, color: EditorColors.warning)),
                        ],
                      ]),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${preview.length} files, ${_formatBytes(preview.fold(0, (s, e) => s + e.bytes))}'
              '${conflicts == 0 ? '' : ' · $conflicts already in the target (kept as they are)'}',
              key: const ValueKey('migrate_summary'),
              style: const TextStyle(fontSize: 10),
            ),
          ]),
        ),
        actions: [
          OutlineButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          PrimaryButton(
            key: const ValueKey('migrate_confirm'),
            onPressed: () {
              final report = vm.migrateAsset(path, target);
              Navigator.of(dialogContext).pop();
              final copied = report.where((e) => e.copied).length;
              _showMigrateMessage(context, 'Migrate complete',
                  '$copied copied, ${report.length - copied} skipped (already in the target).');
            },
            child: const Text('Migrate'),
          ),
        ],
      ),
    );
  }

  void _showMigrateMessage(BuildContext context, String title, String message) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message, key: const ValueKey('migrate_message'), style: const TextStyle(fontSize: 11)),
        actions: [OutlineButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK'))],
      ),
    );
  }
}
