part of '../static_mesh_sub_editor.dart';

/// The right panel: material slots and collision details.
mixin _StaticMeshSubEditorRightPanel on _StaticMeshSubEditorStateBase {
  Widget _buildRightPanel() {
    final vm = _viewModel;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 1. Material Slots Accordion
        EditorIslandSectionLabel('Material slots (${vm.materialSlots.length})', padding: const EdgeInsets.only(bottom: 6)),
        ...vm.materialSlots.map((slot) => _buildMaterialSlotRow(slot)),
        const SizedBox(height: 4),
        const EditorIslandSectionLabel('Collision settings'),
        const Text('Collision Complexity', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        Select<String>(
          value: vm.collisionComplexity,
          onChanged: (val) {
            if (val != null) vm.setCollisionComplexity(val);
          },
          itemBuilder: (context, item) {
            String label = 'Default';
            if (item == 'use_complex_as_simple') label = 'Use Complex As Simple';
            if (item == 'use_simple_as_complex') label = 'Use Simple As Complex';
            return Text(label, style: const TextStyle(fontSize: 10.5));
          },
          popup: SelectPopup(
            items: SelectItemList(
              children: const [
                SelectItemButton(value: 'default', child: Text('Default')),
                SelectItemButton(value: 'use_complex_as_simple', child: Text('Use Complex Collision As Simple')),
                SelectItemButton(value: 'use_simple_as_complex', child: Text('Use Simple Collision As Complex')),
              ],
            ),
          ).call,
        ),
        // The runtime has no per-triangle shape.
        if (vm.collisionComplexity == 'use_complex_as_simple') ...[
          const SizedBox(height: 4),
          const Text(
            'No per-triangle collision at runtime yet: this mesh plays with its simple collision, as Default.',
            style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
          ),
        ],
        const SizedBox(height: 8),
        Text('Generated Shapes: ${vm.collisionShapes.length}', style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        const EditorIslandSectionLabel('Physics properties'),
        const Text('Mass (Kg)', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        SyncedTextField(
          key: const ValueKey('static_mesh_mass_field'),
          text: vm.massKg.toStringAsFixed(1),
          onChanged: (val) {
            final parsed = double.tryParse(val);
            if (parsed != null) vm.setMass(parsed);
          },
        ),
      ],
    );
  }

  Widget _buildMaterialSlotRow(MaterialSlotBinding slot) {
    final isBound = slot.assignedMaterialPath != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isBound ? Colors.cyan : EditorColors.mutedForeground,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Element ${slot.index} (${slot.slotName})',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground),
              ),
              const Spacer(),
              // Highlight Button
              GhostButton(
                size: ButtonSize.small,
                onPressed: () => _viewModel.highlightMaterial(slot.index, !slot.isHighlighted),
                child: Icon(LucideIcons.sparkles, size: 11, color: slot.isHighlighted ? Colors.amber : EditorColors.mutedForeground),
              ),
              // Isolate Button
              GhostButton(
                size: ButtonSize.small,
                onPressed: () => _viewModel.isolateMaterial(slot.index, !slot.isIsolated),
                child: Icon(LucideIcons.eyeOff, size: 11, color: slot.isIsolated ? Colors.cyan : EditorColors.mutedForeground),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_viewModel.availableMaterials.isEmpty)
            Text(
              isBound ? slot.assignedMaterialPath! : '— unbound — (no materials in this project yet)',
              style: TextStyle(fontSize: 9, color: isBound ? Colors.cyan : EditorColors.mutedForeground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else
            AssetPickerSelect(
              key: ValueKey('static_mesh_material_slot_${slot.index}'),
              keyPrefix: 'static_mesh_material_picker_${slot.index}',
              placeholder: '— unbound —',
              selectedPath: slot.assignedMaterialPath,
              assets: _viewModel.availableMaterials,
              onSelected: (asset) {
                final path = asset.lmasPath;
                if (path == null) return;
                _viewModel.assignMaterial(slot.index, materialAssetPath: path, materialAssetId: asset.assetId ?? asset.fileName);
              },
              onCleared: () => _viewModel.clearMaterial(slot.index),
            ),
        ],
      ),
    );
  }
}
