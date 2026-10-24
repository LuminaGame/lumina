part of '../static_mesh_sub_editor.dart';

/// The left panel: mesh stats, LOD settings and the node hierarchy.
mixin _StaticMeshSubEditorLeftPanel on _StaticMeshSubEditorStateBase {
  Widget _buildStatsPanel() {
    final vm = _viewModel;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const EditorIslandSectionLabel('Mesh statistics', padding: EdgeInsets.only(bottom: 6)),
        _buildStatRow('Triangles', '${vm.triangleCount}'),
        _buildStatRow('Vertices', '${vm.vertexCount}'),
        _buildStatRow('UV Channels', '${vm.uvChannelsCount}'),
        _buildStatRow('Sections', '${vm.sectionCount}'),
        _buildStatRow(
          'Bounds',
          // cm, W × D × H along X × Y × Z.
          '${vm.boundsWidth.toStringAsFixed(1)} × ${vm.boundsDepth.toStringAsFixed(1)} × ${vm.boundsHeight.toStringAsFixed(1)} cm',
        ),
        const EditorIslandSectionLabel('Bounding box extents'),
        _buildStatRow('Min Bounds (cm)', '[${vm.minBounds.map((e) => e.toStringAsFixed(1)).join(', ')}]'),
        _buildStatRow('Max Bounds (cm)', '[${vm.maxBounds.map((e) => e.toStringAsFixed(1)).join(', ')}]'),
      ],
    );
  }

  Widget _buildLodPanel() {
    final vm = _viewModel;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // LOD Global Settings
        EditorIslandSectionLabel(
          'LOD settings',
          padding: const EdgeInsets.only(bottom: 6),
          trailing: OutlineButton(
            size: ButtonSize.small,
            onPressed: vm.lods.length < 4 ? () => vm.addLod() : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, size: 10),
                SizedBox(width: 4),
                Text('Add LOD', style: TextStyle(fontSize: 9.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // LOD Group Selector
        const Text('LOD Group Preset', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        Select<String>(
          value: vm.lodGroup,
          onChanged: (val) {
            if (val != null) vm.setLodGroup(val);
          },
          itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 10.5)),
          popup: SelectPopup(
            items: SelectItemList(
              children: const [
                SelectItemButton(value: 'SmallProp', child: Text('Small Prop')),
                SelectItemButton(value: 'LargeProp', child: Text('Large Prop')),
                SelectItemButton(value: 'Foliage', child: Text('Foliage')),
                SelectItemButton(value: 'Architecture', child: Text('Architecture')),
                SelectItemButton(value: 'Decal', child: Text('Decal')),
              ],
            ),
          ).call,
        ),
        const SizedBox(height: 12),

        // Auto Compute Distances Switch
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Auto Compute Distances', style: TextStyle(fontSize: 9.5, color: EditorColors.foreground)),
            Switch(value: vm.autoComputeLodDistances, onChanged: (val) => vm.setAutoComputeLodDistances(val)),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // LOD Slots List
        ...vm.lods.map((lod) => _buildLodSlotCard(lod)),
      ],
    );
  }

  Widget _buildLodSlotCard(LodSlot lod) {
    final vm = _viewModel;
    final isBase = lod.level == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EditorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LOD ${lod.level} ${isBase ? '(Source)' : ''}',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: EditorColors.foreground),
              ),
              OutlineBadge(child: Text('${lod.triangleCount} tris', style: const TextStyle(fontSize: 9))),
              if (!isBase)
                GhostButton(
                  size: ButtonSize.small,
                  onPressed: () => vm.removeLod(lod.level),
                  child: const Icon(LucideIcons.trash2, size: 12, color: EditorColors.logError),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Reduction Ratio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Reduction: ', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
              Text(
                '${(lod.reductionRatio * 100).toInt()}%',
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground),
              ),
            ],
          ),
          if (!isBase)
            SliderField(
              key: ValueKey('static_mesh_lod_ratio_${lod.level}'),
              value: lod.reductionRatio,
              defaultValue: 0.5,
              min: 0.05,
              max: 1.0,
              onChanged: (v) => vm.setLodRatio(lod.level, v),
              onCommit: (v) => vm.setLodRatio(lod.level, v),
              onReset: () => vm.setLodRatio(lod.level, 0.5),
            ),
          const SizedBox(height: 6),

          // Screen Size Threshold
          Row(
            children: [
              const Text('Screen Size: ', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
              const Spacer(),
              SizedBox(
                width: 70,
                child: SyncedTextField(
                  key: ValueKey('static_mesh_lod_screen_size_${lod.level}'),
                  text: lod.screenSize.toStringAsFixed(2),
                  enabled: !isBase,
                  onChanged: (val) {
                    final parsed = double.tryParse(val);
                    if (parsed != null) vm.setLodScreenSize(lod.level, parsed);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: EditorTypography.ui(fontSize: EditorTypography.labelSize, color: EditorColors.mutedForeground),
          ),
          Text(
            value,
            style: EditorTypography.mono(fontSize: EditorTypography.labelSize, color: EditorColors.foreground),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyPanel() {
    final glb = _viewModel.glbMesh;
    if (glb == null || glb.allNodes.isEmpty) {
      return const Center(
        child: Text('No scene nodes found in mesh', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
      );
    }

    return SubEditorHierarchyWidget(
      rootNodes: glb.rootNodes,
      allNodes: glb.allNodes,
      selectedNode: _selectedNode,
      onNodeSelected: (node) => setState(() => _selectedNode = node),
    );
  }
}
