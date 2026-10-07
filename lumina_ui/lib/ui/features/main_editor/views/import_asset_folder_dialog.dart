import 'package:file_picker/file_picker.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// File → Import Asset Folder…: picks a folder, walks
/// it ([ImportFolderScanner], off the UI isolate) and shows the summary
/// dialog. [targetFolder] is where the tree lands by default (the Content
/// Browser's selected folder, or the folder right-clicked).
Future<void> startImportAssetFolder(BuildContext context, EditorViewModel vm, {String? targetFolder}) async {
  final picker = vm.importFolderPicker ?? () => FilePicker.platform.getDirectoryPath(dialogTitle: 'Import Asset Folder');
  final root = await picker();
  if (root == null || root.isEmpty) return;
  final ImportFolderScan scan;
  try {
    scan = await ImportFolderScanner.scanInBackground(root);
  } catch (e) {
    EngineLoggerService().log('Import Asset Folder: cannot read $root: $e', level: 'error', source: 'ContentBrowser');
    return;
  }
  if (!context.mounted) return;
  showImportAssetFolderDialog(context, vm, scan, targetFolder: targetFolder);
}

/// The Import Asset Folder summary for [scan]: what imports (counts per
/// type, size, grouped companions), what is skipped and why, and the
/// options — Mirror folder structure, target folder, what to do with assets
/// that already exist, Auto Organize, Generate LODs. Import queues the files
/// on the background import queue (its progress panel shows the batch).
void showImportAssetFolderDialog(BuildContext context, EditorViewModel vm, ImportFolderScan scan, {String? targetFolder}) {
  var options = ImportFolderOptions(targetFolder: targetFolder ?? vm.selectedFolder ?? 'contents');
  final targetController = TextEditingController(text: options.targetFolder);

  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (dialogContext) {
      return StatefulBuilder(builder: (dialogContext, setModal) {
        final targetError = importFolderTargetError(options.targetFolder);
        final plan = targetError == null ? ImportFolderPlan.build(scan, projectPath: vm.projectDirPath, options: options) : null;
        final example = scan.files.where((f) => f.relativeDir.isNotEmpty).firstOrNull ?? scan.files.firstOrNull;

        Widget option({required Key key, required String label, required bool value, required ValueChanged<bool> onChanged, bool enabled = true}) {
          return Checkbox(
            key: key,
            state: value ? CheckboxState.checked : CheckboxState.unchecked,
            enabled: enabled,
            onChanged: enabled ? (s) => setModal(() => onChanged(s == CheckboxState.checked)) : null,
            trailing: Text(label, style: TextStyle(fontSize: 10, color: enabled ? EditorColors.foreground : EditorColors.mutedForeground)),
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AlertDialog(
            key: const ValueKey('import_folder_dialog'),
            title: const Text('Import Asset Folder'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scan.root, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Text(
                      importFolderHeadline(scan),
                      key: const ValueKey('import_folder_headline'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EditorColors.primary),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final e in scan.countsByKind.entries)
                          SecondaryBadge(child: Text(importKindCount(e.key, e.value), style: const TextStyle(fontSize: 9))),
                        if (scan.companionCount > 0)
                          OutlineBadge(child: Text('${scan.companionCount} companion file${scan.companionCount == 1 ? '' : 's'} grouped', style: const TextStyle(fontSize: 9))),
                      ],
                    ),
                    if (scan.skipped.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Skipped (${scan.skipped.length})',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                      const SizedBox(height: 4),
                      Container(
                        key: const ValueKey('import_folder_skipped'),
                        constraints: const BoxConstraints(maxHeight: 96),
                        decoration: BoxDecoration(
                          color: EditorColors.muted,
                          border: Border.all(color: EditorColors.border),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(6),
                          children: [
                            for (final s in scan.skipped)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text.rich(
                                  TextSpan(children: [
                                    TextSpan(text: s.relativePath, style: const TextStyle(color: EditorColors.foreground)),
                                    TextSpan(text: ' — ${s.reason}', style: const TextStyle(color: EditorColors.mutedForeground)),
                                  ]),
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text('Target Folder', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                    const SizedBox(height: 4),
                    TextField(
                      key: const ValueKey('import_folder_target_field'),
                      controller: targetController,
                      enabled: !options.autoOrganize,
                      style: const TextStyle(fontSize: 10),
                      onChanged: (v) => setModal(() => options = options.copyWith(targetFolder: v)),
                    ),
                    if (targetError != null && !options.autoOrganize) ...[
                      const SizedBox(height: 2),
                      Text(targetError, style: const TextStyle(fontSize: 9, color: EditorColors.destructive)),
                    ],
                    const SizedBox(height: 8),
                    option(
                      key: const ValueKey('import_folder_mirror'),
                      label: 'Mirror folder structure',
                      value: options.mirrorFolderStructure,
                      enabled: !options.autoOrganize,
                      onChanged: (v) => options = options.copyWith(mirrorFolderStructure: v),
                    ),
                    if (example != null && targetError == null)
                      Padding(
                        padding: const EdgeInsets.only(left: 24, top: 2),
                        child: Text(
                          options.autoOrganize
                              ? 'Sorted by type into contents/meshes/, contents/textures/, contents/audio/…'
                              : '${example.relativePath} → ${ImportFolderPlan.folderFor(example, options)}/',
                          key: const ValueKey('import_folder_example'),
                          style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 10),
                    const Text('If an asset already exists', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                    const SizedBox(height: 4),
                    Select<ImportConflictPolicy>(
                      key: const ValueKey('import_folder_conflict_select'),
                      value: options.conflictPolicy,
                      onChanged: (v) {
                        if (v != null) setModal(() => options = options.copyWith(conflictPolicy: v));
                      },
                      itemBuilder: (context, v) => Text(importConflictLabel(v), style: const TextStyle(fontSize: 10)),
                      popup: SelectPopup(
                        items: SelectItemList(children: [
                          for (final v in ImportConflictPolicy.values)
                            SelectItemButton(
                              key: ValueKey('import_folder_conflict_${v.name}'),
                              value: v,
                              child: Text(importConflictLabel(v), style: const TextStyle(fontSize: 10)),
                            ),
                        ]),
                      ).call,
                    ),
                    const SizedBox(height: 10),
                    option(
                      key: const ValueKey('import_folder_auto_organize'),
                      label: 'Auto Organize by type (ignores the target folder)',
                      value: options.autoOrganize,
                      onChanged: (v) => options = options.copyWith(autoOrganize: v),
                    ),
                    const SizedBox(height: 6),
                    option(
                      key: const ValueKey('import_folder_lods'),
                      label: 'Generate LODs (Level of Detail)',
                      value: options.generateLods,
                      onChanged: (v) => options = options.copyWith(generateLods: v),
                    ),
                    const SizedBox(height: 12),
                    if (plan != null)
                      Text(
                        importFolderPlanLine(plan, options.conflictPolicy),
                        key: const ValueKey('import_folder_plan'),
                        style: const TextStyle(fontSize: 10, color: EditorColors.foreground),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              OutlineButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
              PrimaryButton(
                key: const ValueKey('import_folder_confirm'),
                onPressed: plan == null || plan.imports.isEmpty
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        // Queued in the background; the dialog closes at once.
                        vm.importAssetFolder(scan, options);
                      },
                child: Text(plan == null ? 'Import' : 'Import ${plan.imports.length} File${plan.imports.length == 1 ? '' : 's'}'),
              ),
            ],
          ),
        );
      });
    },
  );
}

/// Why [folder] cannot be the target, or null: it must be `contents` or a
/// folder under it.
String? importFolderTargetError(String folder) {
  final f = ImportFolderPlan.normalizeFolder(folder);
  if (f != 'contents' && !f.startsWith('contents/')) return 'The target folder must be under contents/';
  if (f.split('/').any((s) => s.isEmpty || s == '.' || s == '..')) return 'The target folder is not a valid path';
  return null;
}

/// "14 files · 2.3 MB · 5 folders" for [scan].
String importFolderHeadline(ImportFolderScan scan) {
  final n = scan.files.length;
  final folders = scan.folders.length;
  return '$n file${n == 1 ? '' : 's'} to import · ${formatImportBytes(scan.totalBytes)} · '
      '$folders folder${folders == 1 ? '' : 's'}';
}

String importKindCount(ImportFormatKind kind, int n) => switch (kind) {
      ImportFormatKind.mesh => '$n mesh${n == 1 ? '' : 'es'}',
      ImportFormatKind.texture => '$n texture${n == 1 ? '' : 's'}',
      ImportFormatKind.audio => '$n sound${n == 1 ? '' : 's'}',
      ImportFormatKind.asset => '$n .lmas asset${n == 1 ? '' : 's'}',
    };

String importConflictLabel(ImportConflictPolicy p) => switch (p) {
      ImportConflictPolicy.skip => 'Skip files that already exist',
      ImportConflictPolicy.overwrite => 'Overwrite (re-import, keeps references)',
      ImportConflictPolicy.rename => 'Rename (import as name_1)',
    };

/// "Imports 12 files · 3 already exist: skipped".
String importFolderPlanLine(ImportFolderPlan plan, ImportConflictPolicy policy) {
  final n = plan.imports.length;
  final conflicts = plan.conflicts;
  final what = switch (policy) {
    ImportConflictPolicy.skip => 'skipped',
    ImportConflictPolicy.overwrite => 'overwritten',
    ImportConflictPolicy.rename => 'renamed',
  };
  return 'Imports $n file${n == 1 ? '' : 's'}'
      '${conflicts == 0 ? '' : ' · $conflicts already exist${conflicts == 1 ? 's' : ''}: $what'}';
}

String formatImportBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
