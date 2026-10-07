import 'dart:io';

import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/import_target_skeleton_select.dart';
import 'package:lumina_ui/ui/features/main_editor/views/import_textures_folder_row.dart';

/// The Content Browser's Import Asset Options dialog for [filePaths]
/// (auto organize, LODs, an animation's target skeleton, an FBX's textures
/// folder). Import Asset
/// queues every file on the editor's background import queue and closes at
/// once; progress shows in the import panel.
void showImportAssetOptionsDialog(
  BuildContext context,
  EditorViewModel? vm,
  List<String> filePaths,
) {
  bool autoOrganize = true;
  bool generateLods = false;
  // Null = match a skeleton by bone names, '' = none.
  String? targetSkeleton;
  final showSkeleton = ImportTargetSkeletonSelect.appliesTo(filePaths);
  // Where an FBX's textures are looked for first.
  String? texturesFolder;
  final showTexturesFolder = ImportTexturesFolderRow.appliesTo(filePaths);
  final skeletalMeshes = [
    for (final a in vm?.realAssets ?? const <RealAssetInfo>[])
      if (a.type == AssetType.filameshSk) a,
  ];

  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateModal) {
          final fileNamesText = filePaths.length == 1
              ? File(filePaths.first).uri.pathSegments.last
              : '${filePaths.length} files selected';
          final filePathsText = filePaths.length == 1
              ? filePaths.first
              : filePaths.join(', ');

          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AlertDialog(
              title: const Text('Import Asset Options'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Source Files: $fileNamesText',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: EditorColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      filePathsText,
                      style: const TextStyle(
                        fontSize: 8,
                        color: EditorColors.mutedForeground,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          state: autoOrganize
                              ? CheckboxState.checked
                              : CheckboxState.unchecked,
                          onChanged: (val) => setStateModal(
                            () => autoOrganize = val == CheckboxState.checked,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Auto Organize Files (Default)',
                          style: TextStyle(
                            fontSize: 10,
                            color: EditorColors.foreground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Checkbox(
                          state: generateLods
                              ? CheckboxState.checked
                              : CheckboxState.unchecked,
                          onChanged: (val) => setStateModal(
                            () => generateLods = val == CheckboxState.checked,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Generate LODs (Level of Detail)',
                          style: TextStyle(
                            fontSize: 10,
                            color: EditorColors.foreground,
                          ),
                        ),
                      ],
                    ),
                    if (showSkeleton) ...[
                      const SizedBox(height: 10),
                      ImportTargetSkeletonSelect(
                        skeletalMeshes: skeletalMeshes,
                        value: targetSkeleton,
                        onChanged: (v) => setStateModal(() => targetSkeleton = v),
                      ),
                    ],
                    if (showTexturesFolder) ...[
                      const SizedBox(height: 10),
                      ImportTexturesFolderRow(
                        value: texturesFolder,
                        picker: vm?.importTexturesFolderPicker,
                        onChanged: (v) => setStateModal(() => texturesFolder = v),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                OutlineButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                PrimaryButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // The batch is queued and runs
                    // in the background; the dialog closes at once.
                    vm?.importAssetFiles(
                      filePaths,
                      targetSubFolder: vm.selectedFolder,
                      autoOrganize: autoOrganize,
                      generateLods: generateLods,
                      targetSkeletonPath: targetSkeleton,
                      textureSearchDirs: [?texturesFolder],
                    );
                  },
                  child: const Text(
                    'Import Asset',
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
