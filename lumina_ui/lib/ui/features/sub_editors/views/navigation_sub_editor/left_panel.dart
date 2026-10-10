part of '../navigation_sub_editor.dart';

// ---------------------------------------------------------------------------
// Left panel: bounds volumes
// ---------------------------------------------------------------------------

class _LeftPanel extends StatelessWidget {
  final NavigationEditorViewModel vm;
  final TextEditingController filterController;
  const _LeftPanel({required this.vm, required this.filterController});

  @override
  Widget build(BuildContext context) {
    final selected = vm.selectedVolume;
    return Container(
      color: EditorColors.cardHeader,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Text('NAV BOUNDS VOLUMES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              key: const ValueKey('nav_volume_filter'),
              controller: filterController,
              placeholder: const Text('Filter volumes…', style: TextStyle(fontSize: 9)),
              style: const TextStyle(fontSize: 9),
              onChanged: vm.setVolumeFilter,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Button.secondary(
              key: const ValueKey('nav_add_volume'),
              onPressed: vm.addBoundsVolume,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.plus, size: 11),
                  SizedBox(width: 4),
                  Text('Add Bounds Volume', style: TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: vm.volumes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'No NavMeshBoundsVolume in this level. Add one to define where the walkable grid is baked.',
                      style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                    ),
                  )
                : ListView(
                    children: [
                      for (final v in vm.filteredVolumes) _VolumeRow(vm: vm, volume: v, selected: selected?.id == v.id),
                    ],
                  ),
          ),
          if (selected != null) ...[
            const Divider(height: 1),
            _VolumeInspector(vm: vm, volume: selected),
          ],
        ],
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final NavigationEditorViewModel vm;
  final EditorActorNode volume;
  final bool selected;
  const _VolumeRow({required this.vm, required this.volume, required this.selected});

  @override
  Widget build(BuildContext context) {
    final extent = NavMeshBoundsVolume.extentMetresOf(volume);
    return EditorContextMenu(
      items: [
        MenuButton(
          leading: const Icon(LucideIcons.locate, size: 14, color: EditorColors.accent),
          onPressed: (ctx) => vm.focusVolume(volume.id),
          child: const Text('Focus in Viewport', style: TextStyle(fontSize: 10)),
        ),
        MenuButton(
          leading: const Icon(LucideIcons.pencil, size: 14),
          onPressed: (ctx) => _showRename(context),
          child: const Text('Rename', style: TextStyle(fontSize: 10)),
        ),
        const MenuDivider(),
        MenuButton(
          leading: const Icon(LucideIcons.trash2, size: 14, color: EditorColors.destructive),
          onPressed: (ctx) => _confirmDelete(context),
          child: const Text('Delete', style: TextStyle(fontSize: 10, color: EditorColors.destructive)),
        ),
      ],
      child: GestureDetector(
        key: ValueKey('nav_volume_row_${volume.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => vm.selectVolume(volume.id),
        onDoubleTap: () => vm.focusVolume(volume.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: selected ? EditorColors.selectionBg : null,
          child: Row(
            children: [
              const Icon(LucideIcons.box, size: 12, color: Colors.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  volume.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9.5, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: EditorColors.foreground),
                ),
              ),
              // Compact summary in metres (the stored scale); the inspector
              // below edits the same size in cm.
              Text(
                '${_m(extent[0])}×${_m(extent[1])}×${_m(extent[2])} m',
                key: ValueKey('nav_volume_size_${volume.id}'),
                style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _m(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  void _showRename(BuildContext context) {
    final controller = TextEditingController(text: volume.name);
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Bounds Volume'),
        content: TextField(
          key: const ValueKey('nav_rename_field'),
          controller: controller,
          autofocus: true,
          onSubmitted: (v) {
            vm.renameVolume(volume.id, v);
            closeOverlay(dialogContext);
          },
        ),
        actions: [
          GhostButton(child: const Text('Cancel'), onPressed: () => closeOverlay(dialogContext)),
          PrimaryButton(
            key: const ValueKey('nav_rename_confirm'),
            child: const Text('Rename'),
            onPressed: () {
              vm.renameVolume(volume.id, controller.text);
              closeOverlay(dialogContext);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Bounds Volume'),
        content: Text('Delete "${volume.name}" from the level? The grid inside it will no longer be baked. (Undo restores it.)'),
        actions: [
          GhostButton(child: const Text('Cancel'), onPressed: () => closeOverlay(dialogContext)),
          DestructiveButton(
            key: const ValueKey('nav_delete_confirm'),
            child: const Text('Delete'),
            onPressed: () {
              vm.deleteVolume(volume.id);
              closeOverlay(dialogContext);
            },
          ),
        ],
      ),
    );
  }
}

/// Centre / extent inputs of the selected volume, in cm along the authoring
/// X / Y / Z axes (Z up) — the same axes and numbers as the Details panel's
/// Location. Centre writes the actor location; extent writes the actor
/// scale (size in metres).
class _VolumeInspector extends StatelessWidget {
  final NavigationEditorViewModel vm;
  final EditorActorNode volume;
  const _VolumeInspector({required this.vm, required this.volume});

  @override
  Widget build(BuildContext context) {
    final centre = volume.location;
    final extent = NavMeshBoundsVolume.extentCmOf(volume);
    const axes = ['X', 'Y', 'Z'];
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(volume.name, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
          const SizedBox(height: 4),
          const Text('Center (cm, Z up)', style: TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
          for (var i = 0; i < 3; i++)
            KeyedSubtree(
              key: ValueKey('nav_vol_center_${axes[i].toLowerCase()}'),
              child: ScrubNumericField(
                value: centre.length > i ? centre[i] : 0.0,
                defaultValue: 0.0,
                label: axes[i],
                unit: 'cm',
                fractionDigits: 1,
                onChanged: (v) => vm.setVolumeCenter(volume.id, i, v, commit: false),
                onCommit: (v) => vm.setVolumeCenter(volume.id, i, v),
                onReset: () => vm.setVolumeCenter(volume.id, i, 0.0),
              ),
            ),
          const SizedBox(height: 4),
          const Text('Extent (cm, Z up)', style: TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
          for (var i = 0; i < 3; i++)
            KeyedSubtree(
              key: ValueKey('nav_vol_extent_${axes[i].toLowerCase()}'),
              child: ScrubNumericField(
                value: extent.length > i ? extent[i] : 0.0,
                defaultValue: LuminaUnits.metres(NavMeshBoundsVolume.defaultExtentMetres[i]),
                label: axes[i],
                unit: 'cm',
                fractionDigits: 1,
                min: NavMeshBoundsVolume.minExtentCm,
                onChanged: (v) => vm.setVolumeExtent(volume.id, i, v, commit: false),
                onCommit: (v) => vm.setVolumeExtent(volume.id, i, v),
                onReset: () => vm.setVolumeExtent(volume.id, i, LuminaUnits.metres(NavMeshBoundsVolume.defaultExtentMetres[i])),
              ),
            ),
        ],
      ),
    );
  }
}
