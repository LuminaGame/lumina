import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/plugin_manager/services/plugin_importer.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';

/// The Plugin Manager's Import from Folder / Import from Zip: picks a plugin
/// folder or a plugin package zip, validates and copies it into the user
/// plugin directory, asks Replace / Cancel when that plugin is already
/// installed there, and reports the outcome.
Future<void> startPluginImport(BuildContext context, PluginManagerViewModel vm, PluginImportSource source) async {
  final picker = switch (source) {
    PluginImportSource.folder => vm.folderPicker ?? () => FilePicker.platform.getDirectoryPath(dialogTitle: 'Import Plugin from Folder'),
    PluginImportSource.zip => vm.zipPicker ??
        () async {
          final picked = await FilePicker.platform.pickFiles(
            dialogTitle: 'Import Plugin from Zip',
            type: FileType.custom,
            allowedExtensions: const ['zip'],
          );
          return picked?.files.singleOrNull?.path;
        },
  };
  final path = await picker();
  if (path == null || path.isEmpty) return;

  var result = await vm.importPlugin(source, path);
  if (result.status == PluginImportStatus.alreadyInstalled) {
    if (!context.mounted) {
      vm.cancelImport(result);
      return;
    }
    final replace = await _askReplace(context, result);
    if (!replace) {
      vm.cancelImport(result);
      return;
    }
    result = await vm.confirmReplace(result);
  }
  if (!context.mounted) return;
  if (result.status == PluginImportStatus.installed) {
    _showImported(context, result);
  } else {
    _showRefused(context, result, source);
  }
}

Future<bool> _askReplace(BuildContext context, PluginImportResult pending) {
  final done = Completer<bool>();
  final c = pending.candidate!;
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('plugin_import_replace_dialog'),
      title: const Text('Plugin Already Installed'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Text(
          '${c.displayName} is already installed in ${pending.existingDir?.path}. '
          'Replace it with version ${c.version} from ${c.sourcePath}? The installed copy is removed.',
        ),
      ),
      actions: [
        OutlineButton(
          key: const ValueKey('plugin_import_cancel'),
          onPressed: () {
            closeOverlay(dialogContext);
            if (!done.isCompleted) done.complete(false);
          },
          child: const Text('Cancel'),
        ),
        DestructiveButton(
          key: const ValueKey('plugin_import_replace'),
          onPressed: () {
            closeOverlay(dialogContext);
            if (!done.isCompleted) done.complete(true);
          },
          child: const Text('Replace'),
        ),
      ],
    ),
  );
  return done.future;
}

void _showImported(BuildContext context, PluginImportResult result) {
  final c = result.candidate!;
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('plugin_import_done_dialog'),
      title: const Text('Plugin Imported'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${c.displayName} ${c.version} was installed into ${result.installedDir?.path}. '
                'Enable it in the list to use it in this project.'),
            for (final w in result.warnings) ...[
              const SizedBox(height: 6),
              Text(w, style: const TextStyle(fontSize: 11, color: EditorColors.warning)),
            ],
          ],
        ),
      ),
      actions: [
        PrimaryButton(
          key: const ValueKey('plugin_import_ok'),
          onPressed: () => closeOverlay(dialogContext),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void _showRefused(BuildContext context, PluginImportResult result, PluginImportSource source) {
  final what = source == PluginImportSource.folder ? 'folder' : 'zip';
  final title = switch (result.status) {
    PluginImportStatus.conflict => 'Plugin Name Taken',
    PluginImportStatus.failed => 'Import Failed',
    _ => 'Not a Valid Plugin $what',
  };
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('plugin_import_error'),
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.status == PluginImportStatus.invalid) const Text('Nothing was installed:'),
              for (final m in result.messages) ...[
                const SizedBox(height: 6),
                Text('• $m', style: const TextStyle(fontSize: 11)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        PrimaryButton(
          key: const ValueKey('plugin_import_error_ok'),
          onPressed: () => closeOverlay(dialogContext),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
