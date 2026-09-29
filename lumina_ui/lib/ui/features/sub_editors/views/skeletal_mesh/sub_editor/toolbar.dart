part of '../skeletal_mesh_sub_editor.dart';

/// Top toolbar of the Skeletal Mesh sub-editor.
mixin _SkeletalMeshToolbar on _SkeletalMeshSubEditorStateBase {

  Widget _buildToolbar(bool isDirty) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.card,
      child: Row(
        children: [
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

          // Show Bones Toggle
          OutlineButton(
            size: ButtonSize.small,
            onPressed: _viewModel.toggleShowBones,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.bone, size: 12, color: _viewModel.showBones ? Colors.purple : EditorColors.mutedForeground),
                const SizedBox(width: 4),
                Text('Show Bones', style: TextStyle(fontSize: 9.5, color: _viewModel.showBones ? Colors.purple : EditorColors.mutedForeground)),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Display Sockets Toggle
          OutlineButton(
            size: ButtonSize.small,
            onPressed: _viewModel.toggleDisplaySockets,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.crosshair, size: 12, color: _viewModel.displaySockets ? Colors.amber : EditorColors.mutedForeground),
                const SizedBox(width: 4),
                Text('Display Sockets', style: TextStyle(fontSize: 9.5, color: _viewModel.displaySockets ? Colors.amber : EditorColors.mutedForeground)),
              ],
            ),
          ),
          const SizedBox(width: 6),

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

          // Skin Weight Heatmap Toggle
          OutlineButton(
            size: ButtonSize.small,
            onPressed: _viewModel.toggleHeatmap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.flame, size: 12, color: _viewModel.heatmapEnabled ? Colors.orange : EditorColors.mutedForeground),
                const SizedBox(width: 4),
                Text(
                  'Skin Weight Heatmap',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: _viewModel.heatmapEnabled ? FontWeight.bold : FontWeight.normal,
                    color: _viewModel.heatmapEnabled ? Colors.orange : EditorColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

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
          GhostButton(
            size: ButtonSize.small,
            onPressed: widget.onClose,
            child: const Icon(LucideIcons.x, size: 14),
          ),
        ],
      ),
    );
  }
}
