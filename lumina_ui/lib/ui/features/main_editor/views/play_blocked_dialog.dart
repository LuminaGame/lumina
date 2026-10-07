import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';
import 'package:lumina_ui/ui/features/main_editor/services/blueprint_play_support.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// Opens Blueprint [path] (project-relative) in its editor tab and asks the
/// editor to select and frame [nodeId].
void openBlueprintAtNode(EditorViewModel vm, String path, String? nodeId) {
  // A level's path is its Level Blueprint.
  if (path.startsWith('contents/levels/')) {
    if (nodeId != null) BlueprintNavigation.instance.request(path, nodeId);
    vm.openLevelBlueprint(path);
    return;
  }
  var asset = vm.realAssets.where((a) => a.relativePath == path).firstOrNull;
  if (asset == null) {
    vm.refreshAssets();
    asset = vm.realAssets.where((a) => a.relativePath == path).firstOrNull;
  }
  if (asset == null) return;
  if (nodeId != null) BlueprintNavigation.instance.request(path, nodeId);
  vm.openSubEditorTab('Blueprint', asset: asset);
}

/// The "compile errors" dialog on Play: Play did
/// not start; each row is Blueprint → node → message, and clicking a row
/// opens that Blueprint framed on the node.
void showPlayBlockedDialog(BuildContext context, EditorViewModel vm, List<PlayBlocker> blockers) {
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (dialogContext) => PlayBlockedDialog(
      blockers: blockers,
      onOpen: (b) {
        closeOverlay(dialogContext);
        openBlueprintAtNode(vm, b.blueprintPath, b.nodeId);
      },
      onClose: () => closeOverlay(dialogContext),
    ),
  );
}

class PlayBlockedDialog extends StatelessWidget {
  final List<PlayBlocker> blockers;
  final ValueChanged<PlayBlocker> onOpen;
  final VoidCallback onClose;

  const PlayBlockedDialog({super.key, required this.blockers, required this.onOpen, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('play_blocked_dialog'),
      title: const Row(children: [
        Icon(LucideIcons.circleX, size: 16, color: EditorColors.destructive),
        SizedBox(width: 8),
        Text('Play stopped: Blueprint compile errors'),
      ]),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Fix these errors, then press Play again. Click a row to open the Blueprint at its node.',
                style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
            const SizedBox(height: 10),
            for (var i = 0; i < blockers.length; i++)
              Clickable(
                key: ValueKey('play_blocker_$i'),
                onPressed: () => onOpen(blockers[i]),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: EditorColors.card,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EditorColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.circleX, size: 12, color: EditorColors.destructive),
                      const SizedBox(width: 8),
                      Text(blockers[i].blueprintName,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EditorColors.primary)),
                      if (blockers[i].nodeTitle != null) ...[
                        const Text('  →  ', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
                        Text(blockers[i].nodeTitle!,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
                      ],
                      const Text('  ·  ', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
                      Expanded(child: Text(blockers[i].message, style: const TextStyle(fontSize: 11))),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [PrimaryButton(onPressed: onClose, child: const Text('OK'))],
    );
  }
}
