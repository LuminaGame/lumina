part of '../skeletal_mesh_sub_editor.dart';

/// Bone hierarchy tree with socket rows, the bone context menu and the
/// remove-socket confirmation.
mixin _SkeletalMeshBoneTree on _SkeletalMeshSubEditorStateBase {

  @override
  Widget _buildBoneTreePanel() {
    final vm = _viewModel;
    return Column(
      children: [
        // Panel Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: EditorColors.card,
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.bone, size: 12, color: Colors.purple),
                  const SizedBox(width: 6),
                  const Text('SKELETON TREE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                  const Spacer(),
                  GhostButton(
                    size: ButtonSize.small,
                    onPressed: () => vm.addSocket(),
                    child: const Icon(LucideIcons.plus, size: 12, color: Colors.amber),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                placeholder: const Text('Search bones...'),
                onChanged: (val) => vm.setBoneSearchFilter(val),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Tree List
        Expanded(
          child: vm.allBones.isEmpty
              ? const Center(
                  child: Text('No skeleton bones found in mesh', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: vm.rootBones.map((node) => _buildTreeNode(node, 0)).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildTreeNode(GlbNode node, int depth) {
    final vm = _viewModel;
    final isExpanded = _expandedNodeIndices.contains(node.index);
    final isSelected = vm.selectedBone?.index == node.index;
    final isBone = node.type == GlbNodeType.bone;
    final childBones = node.children.where((c) => c.type == GlbNodeType.bone || c.children.isNotEmpty).toList();
    final boneSockets = vm.getSocketsForBone(node.name);

    // Search filter filtering
    if (vm.boneSearchFilter.isNotEmpty) {
      final matchesSelf = node.name.toLowerCase().contains(vm.boneSearchFilter);
      final matchesDescendants = node.getAllDescendantNodeIndices().any((idx) {
        final d = vm.glbMesh?.allNodes[idx];
        return d != null && d.name.toLowerCase().contains(vm.boneSearchFilter);
      });
      final matchesSockets = boneSockets.any((s) => s.name.toLowerCase().contains(vm.boneSearchFilter));
      if (!matchesSelf && !matchesDescendants && !matchesSockets) {
        return const SizedBox.shrink();
      }
    }

    final retargetOption = vm.boneRetargeting[node.name];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onSecondaryTapDown: (details) {
            _showBoneContextMenu(context, details.globalPosition, node);
          },
          child: Clickable(
            onPressed: () {
              vm.selectBone(node);
            },
            child: Container(
              height: 24,
              padding: EdgeInsets.only(left: 6.0 + depth * 14.0, right: 8.0),
              color: isSelected ? Colors.purple.withValues(alpha: 0.22) : Colors.transparent,
              child: Row(
                children: [
                  if (childBones.isNotEmpty || boneSockets.isNotEmpty)
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
                    isBone ? LucideIcons.bone : LucideIcons.box,
                    size: 11,
                    color: isBone ? Colors.purple : EditorColors.mutedForeground,
                  ),
                  const SizedBox(width: 6),

                  Expanded(
                    child: Text(
                      node.name,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.purple : EditorColors.foreground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  if (retargetOption != null)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(retargetOption, style: const TextStyle(fontSize: 7.5, color: Colors.blue)),
                    ),

                  if (boneSockets.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text('${boneSockets.length}', style: const TextStyle(fontSize: 7.5, color: Colors.amber, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Children and Sockets if expanded
        if (isExpanded) ...[
          // Render child bones
          ...childBones.map((c) => _buildTreeNode(c, depth + 1)),

          // Render sockets under this bone
          ...boneSockets.map((s) => _buildSocketRow(s, depth + 1)),
        ],
      ],
    );
  }

  @override
  Widget _buildSocketRow(SkeletalMeshSocket socket, int depth) {
    final vm = _viewModel;
    final isSelected = vm.selectedSocket?.name == socket.name;

    return Clickable(
      onPressed: () {
        vm.selectSocket(socket);
      },
      child: Container(
        height: 22,
        padding: EdgeInsets.only(left: 12.0 + depth * 14.0, right: 8.0),
        color: isSelected ? Colors.amber.withValues(alpha: 0.18) : Colors.transparent,
        child: Row(
          children: [
            const Icon(LucideIcons.crosshair, size: 10, color: Colors.amber),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                socket.name,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.amber : EditorColors.foreground,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Text('Socket', style: TextStyle(fontSize: 7.5, color: Colors.amber)),
            ),
          ],
        ),
      ),
    );
  }

  void _showBoneContextMenu(BuildContext context, Offset position, GlbNode node) {
    showDropdown(
      context: context,
      // An explicit position is where the menu opens; following the
      // anchor widget would drag it to that widget's bottom centre.
      follow: false,
      // Top-left corner at the point, as editor context menus open.
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      position: position,
      builder: (context) {
        return DropdownMenu(
          children: [
            MenuButton(
              leading: const Icon(LucideIcons.plus, size: 12, color: Colors.amber),
              child: const Text('Add Socket', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) {
                _viewModel.addSocket(parentBone: node.name);
              },
            ),
            MenuButton(
              leading: const Icon(LucideIcons.copy, size: 12),
              child: const Text('Copy Bone Name', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) {
                Clipboard.setData(ClipboardData(text: node.name));
              },
            ),
            const MenuDivider(),
            MenuButton(
              child: const Text('Retarget: Animation (Default)', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) {
                _viewModel.setBoneRetargeting(node.name, 'Animation');
              },
            ),
            MenuButton(
              child: const Text('Retarget: Skeleton', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) {
                _viewModel.setBoneRetargeting(node.name, 'Skeleton');
              },
            ),
            MenuButton(
              child: const Text('Retarget: Animation Scaled', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) {
                _viewModel.setBoneRetargeting(node.name, 'AnimationScaled');
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void _confirmRemoveSocket(String socketName) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) => AlertDialog(
        title: const Text('Remove Socket'),
        content: Text('Are you sure you want to remove socket "$socketName"?'),
        actions: [
          OutlineButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          DestructiveButton(
            onPressed: () {
              Navigator.of(context).pop();
              _viewModel.removeSocket(socketName);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
