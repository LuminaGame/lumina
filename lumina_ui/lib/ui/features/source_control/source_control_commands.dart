import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/features/main_editor/commands/editor_command.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/source_control/view_models/source_control_view_model.dart';
import 'package:lumina_ui/ui/features/source_control/views/commit_dialog.dart';
import 'package:lumina_ui/ui/features/source_control/views/history_dialog.dart';
import 'package:lumina_ui/ui/features/source_control/views/revert_dialog.dart';

/// `Tools → Source Control` commands registered into the editor's command
/// registry (Commit…, History for Active Level, Refresh, Initialize).
List<EditorCommand> buildSourceControlCommands(EditorViewModel vm) {
  SourceControlViewModel sc() => vm.sourceControl;
  bool ready() => sc().isAvailable && sc().isRepo;
  return [
    EditorCommand(
      id: SourceControlViewModel.commitCommandId,
      label: 'Commit…',
      icon: LucideIcons.gitCommitHorizontal,
      canExecute: ready,
      execute: (ctx) {
        if (ctx != null) showCommitDialog(ctx, sc());
      },
    ),
    EditorCommand(
      id: SourceControlViewModel.historyCommandId,
      label: 'History for Active Level',
      icon: LucideIcons.history,
      canExecute: ready,
      execute: (ctx) {
        if (ctx != null) showHistoryDialog(ctx, sc(), vm.project.activeLevel);
      },
    ),
    EditorCommand(
      id: SourceControlViewModel.refreshCommandId,
      label: 'Refresh Status',
      icon: LucideIcons.refreshCw,
      canExecute: () => sc().isAvailable,
      execute: (_) => sc().refresh(),
    ),
    EditorCommand(
      id: SourceControlViewModel.initCommandId,
      label: 'Initialize Repository',
      icon: LucideIcons.gitBranchPlus,
      canExecute: () => sc().isAvailable && !sc().isRepo,
      execute: (_) => sc().initRepository(),
    ),
  ];
}

/// Project-relative git paths an asset tile represents: its `.lmas` and, when
/// different, the raw file the tile was scanned from.
List<String> sourceControlPathsForAsset(EditorViewModel vm, RealAssetInfo asset) {
  final root = vm.projectDirPath;
  final paths = <String>{asset.relativePath};
  final lmas = asset.lmasPath;
  if (lmas != null && lmas.startsWith('$root/')) paths.add(lmas.substring(root.length + 1));
  return paths.toList();
}

/// Content Browser context-menu entries for one asset (`Commit`, `History`,
/// `Revert File`). Empty when the project is not a repository, so the menu is
/// unchanged on hosts without git.
List<MenuItem> sourceControlAssetMenuItems(BuildContext context, EditorViewModel vm, RealAssetInfo asset) {
  final sc = vm.sourceControl;
  if (!sc.isAvailable || !sc.isRepo) return const [];
  final paths = sourceControlPathsForAsset(vm, asset);
  final changedPath = paths.where((p) => sc.stateFor(p) != null).firstOrNull;
  return [
    const MenuDivider(),
    MenuButton(
      leading: const Icon(LucideIcons.gitCommitHorizontal, size: 14),
      onPressed: (_) => showCommitDialog(context, sc, preChecked: paths.toSet()),
      child: const Text('Commit', style: TextStyle(fontSize: 10)),
    ),
    MenuButton(
      leading: const Icon(LucideIcons.history, size: 14),
      onPressed: (_) => showHistoryDialog(context, sc, paths.first),
      child: const Text('History', style: TextStyle(fontSize: 10)),
    ),
    MenuButton(
      leading: const Icon(LucideIcons.undo2, size: 14),
      enabled: changedPath != null,
      onPressed: changedPath == null ? null : (_) => showRevertDialog(context, sc, changedPath),
      child: const Text('Revert File', style: TextStyle(fontSize: 10)),
    ),
  ];
}
