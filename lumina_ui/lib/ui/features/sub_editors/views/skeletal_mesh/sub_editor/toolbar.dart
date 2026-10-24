part of '../skeletal_mesh_sub_editor.dart';

/// Top toolbar of the Skeletal Mesh sub-editor.
mixin _SkeletalMeshToolbar on _SkeletalMeshSubEditorStateBase {

  Widget _buildToolbar(bool isDirty) {
    return SubEditorToolbar(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.card,
      children: [
          SubEditorToolbarTitle(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('SKELETAL MESH', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.purple)),
          ),
const SizedBox(width: 8),
Text(
            '${widget.assetName}${isDirty ? ' *' : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground),
          ),
          ])),
          const SizedBox(width: 12),

          // Bones count badge
          OutlineBadge(
            child: Text('${_viewModel.boneCount} Bones', style: const TextStyle(fontSize: 9)),
          ),
          const SizedBox(width: 6),

          // Sockets count badge
          OutlineBadge(
            child: Text('${_viewModel.sockets.length} Sockets', style: const TextStyle(fontSize: 9, color: Colors.amber)),
          ),
          const Spacer(),

          // RigLogic DNA Button
          OutlineButton(
            size: ButtonSize.small,
            onPressed: () {
              setState(() => _activeLeftTab = 2);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.dna, size: 12, color: _viewModel.hasRigLogic ? Colors.blue : EditorColors.mutedForeground),
                const SizedBox(width: 4),
                Text(
                  _viewModel.hasRigLogic ? 'DNA: ${_viewModel.rigLogic!.characterName}' : 'DNA Rig',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: _viewModel.hasRigLogic ? Colors.blue : EditorColors.mutedForeground,
                    fontWeight: _activeLeftTab == 2 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),


          // Add Socket Button
          OutlineButton(
            size: ButtonSize.small,
            onPressed: () => _viewModel.addSocket(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, size: 12, color: Colors.amber),
                SizedBox(width: 4),
                Text('Add Socket', style: TextStyle(fontSize: 9.5, color: Colors.amber)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Save Button
          PrimaryButton(
            size: ButtonSize.small,
            onPressed: isDirty ? () => _viewModel.save() : null,
            child: const Text('Save', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),

          // Close Button
          SubEditorToolbarClose(child: GhostButton(
            size: ButtonSize.small,
            onPressed: widget.onClose,
            child: const Icon(LucideIcons.x, size: 14),
          ))
      ],
    );
  }
}
