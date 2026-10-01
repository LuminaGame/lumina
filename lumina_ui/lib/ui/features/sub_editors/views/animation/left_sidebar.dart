part of '../animation_sub_editor.dart';

/// Left sidebar tabs: asset properties, bone track tree and notifies.
mixin _AnimationLeftSidebar on _AnimationSubEditorStateBase {

  Widget _buildLeftSidebar() {
    return Column(
      children: [
        // Tabs Header
        Container(
          padding: const EdgeInsets.all(6),
          color: EditorColors.card,
          child: Row(
            children: [
              Expanded(
                child: GhostButton(
                  size: ButtonSize.small,
                  onPressed: () => setState(() => _activeLeftTab = 0),
                  child: Text(
                    'Properties',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: _activeLeftTab == 0 ? FontWeight.bold : FontWeight.normal,
                      color: _activeLeftTab == 0 ? Colors.orange : EditorColors.mutedForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: GhostButton(
                  size: ButtonSize.small,
                  onPressed: () => setState(() => _activeLeftTab = 1),
                  child: Text(
                    'Bone Tracks',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: _activeLeftTab == 1 ? FontWeight.bold : FontWeight.normal,
                      color: _activeLeftTab == 1 ? Colors.purple : EditorColors.mutedForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: GhostButton(
                  size: ButtonSize.small,
                  onPressed: () => setState(() => _activeLeftTab = 2),
                  child: Text(
                    'Notifies (${_viewModel.notifies.length})',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: _activeLeftTab == 2 ? FontWeight.bold : FontWeight.normal,
                      color: _activeLeftTab == 2 ? Colors.amber : EditorColors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _activeLeftTab == 0
              ? _buildAssetPropertiesPanel()
              : _activeLeftTab == 1
                  ? _buildBoneTracksPanel()
                  : _buildNotifiesPanel(),
        ),
      ],
    );
  }

  Widget _buildAssetPropertiesPanel() {
    final vm = _viewModel;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Row(
          children: [
            Icon(LucideIcons.slidersHorizontal, size: 12, color: Colors.orange),
            SizedBox(width: 6),
            Text('ASSET PROPERTIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
          ],
        ),
        const SizedBox(height: 12),

        // Preview Skeletal Mesh
        const Text('Preview Mesh', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        if (vm.availableSkeletalMeshes.isNotEmpty)
          AssetPickerSelect(
            key: const ValueKey('animation_preview_mesh_select'),
            keyPrefix: 'animation_preview_mesh_picker',
            assets: vm.availableSkeletalMeshes,
            selectedPath: vm.previewMeshAsset?.relativePath,
            placeholder: 'Default Embedded Skeleton',
            allowClear: false,
            onSelected: vm.setPreviewMesh,
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: EditorColors.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: EditorColors.border),
            ),
            child: const Text('Default Embedded Skeleton', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
          ),
        const SizedBox(height: 12),

        // Rate Scale
        const Text('Rate Scale', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        TextField(
          initialValue: vm.rateScale.toStringAsFixed(2),
          onSubmitted: (val) {
            final parsed = double.tryParse(val.trim());
            if (parsed != null && parsed > 0) {
              vm.setRateScale(parsed);
            }
          },
        ),
        const SizedBox(height: 12),

        // Interpolation
        const Text('Interpolation', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        Select<String>(
          value: vm.interpolation,
          onChanged: (val) {
            if (val != null) vm.setInterpolation(val);
          },
          itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 10)),
          popup: SelectPopup(
            items: const SelectItemList(
              children: [
                SelectItemButton(value: 'Linear', child: Text('Linear')),
                SelectItemButton(value: 'Step', child: Text('Step (Whole Frames)')),
              ],
            ),
          ).call,
        ),
        const SizedBox(height: 12),

        // Additive Anim Type
        const Text('Additive Anim Type', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        Select<String>(
          value: vm.additiveType,
          onChanged: (val) {
            if (val != null) vm.setAdditiveType(val);
          },
          itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 10)),
          popup: SelectPopup(
            items: const SelectItemList(
              children: [
                SelectItemButton(value: 'No Additive', child: Text('No Additive')),
                SelectItemButton(value: 'Local Space', child: Text('Local Space')),
                SelectItemButton(value: 'Mesh Space', child: Text('Mesh Space')),
              ],
            ),
          ).call,
        ),
        const SizedBox(height: 12),

        // Frame Rate (FPS)
        const Text('Frame Rate (FPS)', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        Select<double>(
          value: vm.frameRate,
          onChanged: (val) {
            if (val != null) vm.setFrameRate(val);
          },
          itemBuilder: (context, item) => Text('${item.toInt()} FPS', style: const TextStyle(fontSize: 10)),
          popup: SelectPopup(
            items: const SelectItemList(
              children: [
                SelectItemButton(value: 24.0, child: Text('24 FPS (Film)')),
                SelectItemButton(value: 30.0, child: Text('30 FPS (Standard)')),
                SelectItemButton(value: 60.0, child: Text('60 FPS (Smooth)')),
              ],
            ),
          ).call,
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Clip Statistics
        const Text('CLIP METRICS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.cyan)),
        const SizedBox(height: 8),
        _buildMetricRow('Active Clip', vm.activeClip?.name ?? 'None'),
        _buildMetricRow('Duration', '${vm.duration.toStringAsFixed(3)}s'),
        _buildMetricRow('Total Frames', '${vm.totalFrames}'),
        _buildMetricRow('Animated Bones', '${vm.activeAnimatedNodeIndices.length} / ${vm.allBones.length}'),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
          Text(value, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        ],
      ),
    );
  }

  Widget _buildBoneTracksPanel() {
    final vm = _viewModel;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: EditorColors.card,
          child: Row(
            children: [
              const Icon(LucideIcons.bone, size: 12, color: Colors.purple),
              const SizedBox(width: 6),
              const Text('ANIMATED BONE TRACKS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
              const Spacer(),
              OutlineBadge(
                child: Text('${vm.activeAnimatedNodeIndices.length} Animated', style: const TextStyle(fontSize: 8.5, color: Colors.orange)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Search Filter TextField
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          color: EditorColors.background,
          child: TextField(
            key: const ValueKey('anim_bone_filter'),
            initialValue: vm.boneSearchQuery,
            placeholder: const Text('Filter bones (e.g. foot, spine)...', style: TextStyle(fontSize: 10)),
            style: const TextStyle(fontSize: 10),
            onChanged: (val) => vm.setBoneSearchQuery(val),
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: vm.allBones.isEmpty
              ? const Center(
                  child: Text('No skeleton bones in this asset', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: vm.rootBones.map((node) => _buildTrackTreeNode(node, 0)).toList(),
                ),
        ),
      ],
    );
  }

  bool _nodeMatchesFilter(GlbNode node, String query) {
    if (query.isEmpty) return true;
    if (node.name.toLowerCase().contains(query.toLowerCase())) return true;
    for (final child in node.children) {
      if (_nodeMatchesFilter(child, query)) return true;
    }
    return false;
  }

  Widget _buildTrackTreeNode(GlbNode node, int depth) {
    final vm = _viewModel;
    final query = vm.boneSearchQuery.trim();
    if (query.isNotEmpty && !_nodeMatchesFilter(node, query)) {
      return const SizedBox.shrink();
    }
    final isExpanded = query.isNotEmpty ? true : _expandedNodeIndices.contains(node.index);
    final isAnimated = vm.activeAnimatedNodeIndices.contains(node.index);
    final isSelectedBone = vm.isAuthored && vm.selectedBone == node.name;
    final childBones = node.children.where((c) => c.type != GlbNodeType.mesh && (query.isEmpty || _nodeMatchesFilter(c, query))).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          key: ValueKey('anim_bone_tree_${node.name}'),
          onTap: () {
            if (vm.isAuthored) {
              // Authored sequence: the bone gets the viewport's gizmo.
              vm.selectBone(node.name);
              return;
            }
            final activeAnim = vm.animatedBoneTracks.where((b) => b.boneName == node.name).firstOrNull;
            final t = activeAnim != null ? activeAnim.startTime : vm.positionSeconds;
            final keyId = 'bone_${node.name}_${t.toStringAsFixed(3)}';
            vm.selectKeyframe(keyId);
            vm.seek(t);
            setState(() => _activeRightTab = 0);
          },
          child: Container(
            height: 24,
            padding: EdgeInsets.only(left: 6.0 + depth * 14.0, right: 8.0),
            color: isSelectedBone
                ? Colors.amber.withValues(alpha: 0.25)
                : (isAnimated ? Colors.orange.withValues(alpha: 0.12) : Colors.transparent),
            child: Row(
              children: [
                if (childBones.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedNodeIndices.remove(node.index);
                        } else {
                          _expandedNodeIndices.add(node.index);
                        }
                      });
                    },
                    child: Icon(
                      isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                      size: 12,
                      color: EditorColors.mutedForeground,
                    ),
                  )
                else
                  const SizedBox(width: 12),
                const SizedBox(width: 4),

                Icon(
                  LucideIcons.bone,
                  size: 11,
                  color: isAnimated ? Colors.orange : EditorColors.mutedForeground,
                ),
                const SizedBox(width: 6),

                Expanded(
                  child: Text(
                    node.name,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isAnimated ? FontWeight.bold : FontWeight.normal,
                      color: isAnimated ? Colors.orange : EditorColors.foreground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                if (isAnimated)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text('Track', style: TextStyle(fontSize: 7.5, color: Colors.orange, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ),

        if (isExpanded) ...childBones.map((c) => _buildTrackTreeNode(c, depth + 1)),
      ],
    );
  }

  Widget _buildNotifiesPanel() {
    final vm = _viewModel;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: EditorColors.card,
          child: Row(
            children: [
              const Icon(LucideIcons.bell, size: 12, color: Colors.amber),
              const SizedBox(width: 6),
              const Text('ANIM NOTIFIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
              const Spacer(),
              PrimaryButton(
                size: ButtonSize.small,
                onPressed: () {
                  final name = 'Notify_${vm.notifies.length + 1}';
                  vm.addNotify(name, vm.positionSeconds);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 11),
                    SizedBox(width: 2),
                    Text('Add', style: TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: vm.notifies.isEmpty
              ? const Center(
                  child: Text('No anim notifies placed on timeline', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: vm.notifies.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
                  itemBuilder: (context, idx) {
                    final n = vm.notifies[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: EditorColors.card,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EditorColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            n.type == AnimNotifyType.footstep
                                ? LucideIcons.footprints
                                : n.type == AnimNotifyType.playSound
                                    ? LucideIcons.volume2
                                    : n.type == AnimNotifyType.spawnParticle
                                        ? LucideIcons.sparkles
                                        : LucideIcons.bell,
                            size: 13,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.name,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                                ),
                                Text(
                                  '${n.time.toStringAsFixed(3)}s  [${n.type.name}]',
                                  style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground),
                                ),
                              ],
                            ),
                          ),
                          GhostButton(
                            size: ButtonSize.small,
                            onPressed: () => vm.seek(n.time),
                            child: const Icon(LucideIcons.play, size: 11),
                          ),
                          GhostButton(
                            size: ButtonSize.small,
                            onPressed: () => vm.removeNotify(n.id),
                            child: const Icon(LucideIcons.trash2, size: 11, color: EditorColors.logError),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
