import 'package:lumina/data/models/lumina_plugin_descriptor.dart';
import 'package:lumina/data/services/plugin_registry_service.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/plugin_manager/services/plugin_remover.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';

/// The details pane's Remove: works out what removing [entry] deletes and
/// shows it in a confirmation dialog before anything is deleted; Remove
/// deletes it. A removal that stopped keeps the dialog open with what was
/// and was not removed.
void confirmPluginRemoval(BuildContext context, PluginManagerViewModel vm, PluginEntry entry) {
  final plan = vm.planRemoval(entry);
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (dialogContext) => _PluginRemoveDialog(
      plan: plan,
      viewModel: vm,
      onClose: () => closeOverlay(dialogContext),
    ),
  );
}

/// Bytes as B / KB / MB / GB.
String formatPluginBytes(int bytes) {
  if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(2)} GB';
  if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
  if (bytes >= 1 << 10) return '${(bytes / (1 << 10)).toStringAsFixed(1)} KB';
  return '$bytes B';
}

String _files(int count) => count == 1 ? '1 file' : '$count files';

class _PluginRemoveDialog extends StatefulWidget {
  const _PluginRemoveDialog({required this.plan, required this.viewModel, required this.onClose});

  final PluginRemovalPlan plan;
  final PluginManagerViewModel viewModel;
  final VoidCallback onClose;

  @override
  State<_PluginRemoveDialog> createState() => _PluginRemoveDialogState();
}

class _PluginRemoveDialogState extends State<_PluginRemoveDialog> {
  bool _deleteData = false;
  bool _busy = false;
  PluginRemovalResult? _failed;

  Future<void> _remove() async {
    setState(() => _busy = true);
    final result = await widget.viewModel.removePlugin(widget.plan, deleteData: _deleteData);
    if (!mounted) return;
    if (result.removed && result.notRemoved.isEmpty) {
      widget.onClose();
      return;
    }
    setState(() {
      _busy = false;
      _failed = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final failed = _failed;
    return AlertDialog(
      key: const ValueKey('plugin_remove_dialog'),
      title: Text(failed == null ? 'Remove ${plan.displayName}?' : 'Removing ${plan.displayName} did not finish'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
        child: SingleChildScrollView(
          child: failed == null ? _plan(plan) : _failure(failed),
        ),
      ),
      actions: failed != null
          ? [
              PrimaryButton(
                key: const ValueKey('plugin_remove_close'),
                onPressed: widget.onClose,
                child: const Text('Close'),
              ),
            ]
          : [
              OutlineButton(
                key: const ValueKey('plugin_remove_cancel'),
                enabled: !_busy,
                onPressed: widget.onClose,
                child: const Text('Cancel'),
              ),
              DestructiveButton(
                key: const ValueKey('plugin_remove_confirm'),
                enabled: !_busy,
                leading: const Icon(LucideIcons.trash2, size: 14),
                onPressed: _remove,
                child: Text(_busy ? 'Removing...' : 'Remove'),
              ),
            ],
    );
  }

  Widget _plan(PluginRemovalPlan plan) {
    final lines = <Widget>[
      const Text('This deletes:', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      _path(plan.pluginDir.path),
      const SizedBox(height: 2),
      if (plan.linked)
        Text('Linked from ${plan.linkTarget}; only the link is removed. The folder it points to and its files stay.',
            key: const ValueKey('plugin_remove_linked'), style: const TextStyle(fontSize: 12))
      else
        Text('${_files(plan.fileCount)}, ${formatPluginBytes(plan.bytes)}',
            key: const ValueKey('plugin_remove_size'), style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 10),
      _note(plan.origin == PluginOrigin.user
          ? 'A user plugin: it is removed for every project on this machine.'
          : 'A project plugin: it is removed from this project\'s plugins/ folder.'),
      if (plan.marketplaceRecord != null)
        _note('Installed from the Marketplace (${plan.marketplaceRecord!.title} ${plan.marketplaceRecord!.version}); '
            'its license record is removed too.'),
      if (plan.enabled) ...[
        _note(
          'Enabled in this project: it is disabled (enabled_plugins in the .lmproject)'
          '${plan.dependents.isEmpty ? '' : ', with the plugins that depend on it: ${plan.dependents.join(', ')}'}'
          '${plan.contentOnly ? '.' : ', and the project editor is rebuilt on the next restart.'}',
          key: const ValueKey('plugin_remove_enabled'),
        ),
      ],
      if (plan.loaded)
        _note('It is loaded in this editor session and stays active until you restart the editor.',
            key: const ValueKey('plugin_remove_loaded')),
      if (plan.revealedDir != null)
        _note(
          'The ${plan.revealedOrigin == PluginOrigin.engine ? 'built-in' : '${plan.revealedOrigin!.name} plugin'} '
          '${plan.name} (${plan.revealedDir!.path}) takes its place again, disabled.',
          key: const ValueKey('plugin_remove_comes_back'),
        ),
      const SizedBox(height: 10),
      if (plan.data.isEmpty)
        Text('It has no saved data.', key: const ValueKey('plugin_remove_no_data'), style: _muted)
      else ...[
        GestureDetector(
          onTap: _busy ? null : () => setState(() => _deleteData = !_deleteData),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Checkbox(
              key: const ValueKey('plugin_remove_data'),
              state: _deleteData ? CheckboxState.checked : CheckboxState.unchecked,
              onChanged: _busy ? null : (s) => setState(() => _deleteData = s == CheckboxState.checked),
            ),
            const SizedBox(width: 8),
            const Text('Also delete its saved data', style: TextStyle(fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 4),
        for (final d in plan.data)
          Padding(
            padding: const EdgeInsets.only(left: 26, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _path(d.dir.path),
                Text(
                  '${d.kind == PluginDataKind.user ? 'Per-user data, for every project' : 'This project\'s data'}: '
                  '${_files(d.fileCount)}, ${formatPluginBytes(d.bytes)}',
                  style: _muted,
                ),
              ],
            ),
          ),
        if (!_deleteData) Text('Unticked, the saved data stays where it is.', style: _muted),
      ],
    ];
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: lines);
  }

  Widget _failure(PluginRemovalResult result) => Column(
        key: const ValueKey('plugin_remove_error'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.removed
                ? 'The plugin was removed, but not everything could be deleted.'
                : 'Nothing was removed: the plugin folder could not be moved (a file in it may be open, '
                    'for example a library this editor loaded). Close what uses it, or restart the editor, and try again.',
            style: const TextStyle(fontSize: 12),
          ),
          if (result.removedPaths.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Removed:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            for (final path in result.removedPaths) _path(path),
          ],
          const SizedBox(height: 10),
          const Text('Not removed:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          for (final line in result.notRemoved)
            Text(line, style: const TextStyle(fontSize: 11, color: EditorColors.destructive, fontFamily: EditorTypography.monoFamily)),
        ],
      );

  static const TextStyle _muted = TextStyle(fontSize: 11, color: EditorColors.mutedForeground);

  Widget _path(String path) => Text(path, style: const TextStyle(fontSize: 11, fontFamily: EditorTypography.monoFamily));

  Widget _note(String text, {Key? key}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, key: key, style: const TextStyle(fontSize: 12)),
      );
}
