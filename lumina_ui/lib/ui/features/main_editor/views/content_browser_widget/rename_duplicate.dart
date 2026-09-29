part of '../content_browser_widget.dart';

/// Content Browser → Rename… (F2) and Duplicate (Ctrl+D) on an asset.
mixin _ContentBrowserRenameDuplicate on _ContentBrowserWidgetStateBase {
  void _showRenameAssetDialog(BuildContext context, EditorViewModel? vm, RealAssetInfo asset) {
    final path = asset.lmasPath;
    if (vm == null || path == null) return;
    final controller = TextEditingController(text: _displayName(asset.fileName));
    String? error;
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setModal) {
        void submit() {
          final err = vm.renameAsset(path, controller.text);
          if (err == null) {
            Navigator.of(dialogContext).pop();
            setState(() {
              _selectedAssetPaths.clear();
              _lastSelectedAssetPath = null;
            });
          } else {
            setModal(() => error = err);
          }
        }

        return AlertDialog(
          title: const Text('Rename Asset'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey('asset_rename_field'),
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
            PrimaryButton(key: const ValueKey('asset_rename_confirm'), onPressed: submit, child: const Text('Rename')),
          ],
        );
      }),
    );
  }

  void _duplicateAssets(EditorViewModel? vm, Iterable<RealAssetInfo> assets) {
    if (vm == null) return;
    for (final asset in assets) {
      final path = asset.lmasPath;
      if (path != null) vm.duplicateAsset(path);
    }
    setState(() {});
  }
}
