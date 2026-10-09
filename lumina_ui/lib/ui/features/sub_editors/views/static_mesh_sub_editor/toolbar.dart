part of '../static_mesh_sub_editor.dart';

/// The toolbar and its Collision and LOD preview menus.
mixin _StaticMeshSubEditorToolbar on _StaticMeshSubEditorStateBase {
  void _showCollisionMenu() {
    final renderBox = _collisionBtnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final offset = renderBox.localToGlobal(Offset.zero);
      final position = Offset(offset.dx, offset.dy + renderBox.size.height + 2);
      showDropdown(
        context: context,
        // An explicit position is where the menu opens; following the
        // anchor widget would drag it to that widget's bottom centre.
        follow: false,
        // Top-left corner at the point, as editor context menus open.
        alignment: Alignment.topLeft,
        anchorAlignment: Alignment.topLeft,
        position: position,
        builder: (context) => DropdownMenu(
          children: [
            MenuButton(
              leading: const Icon(LucideIcons.box, size: 12),
              child: const Text('Box Collision', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) {
                _viewModel.generateCollision(StaticMeshCollisionShapeType.box);
              },
            ),
            MenuButton(
              leading: const Icon(LucideIcons.circle, size: 12),
              child: const Text('Sphere Collision', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) {
                _viewModel.generateCollision(StaticMeshCollisionShapeType.sphere);
              },
            ),
            MenuButton(
              leading: const Icon(LucideIcons.cylinder, size: 12),
              child: const Text('Capsule Collision', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) {
                _viewModel.generateCollision(StaticMeshCollisionShapeType.capsule);
              },
            ),
            MenuButton(
              leading: const Icon(LucideIcons.triangle, size: 12),
              child: const Text('Convex (hull)', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) {
                _viewModel.generateCollision(StaticMeshCollisionShapeType.convex);
              },
            ),
            const MenuDivider(),
            MenuButton(
              leading: const Icon(LucideIcons.trash2, size: 12, color: EditorColors.logError),
              child: const Text('Remove Collision', style: TextStyle(fontSize: 10, color: EditorColors.logError)),
              onPressed: (ctx) {
                _viewModel.removeCollision();
              },
            ),
          ],
        ),
      );
    }
  }

  void _showForcedLodMenu() {
    final renderBox = _forcedLodBtnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final offset = renderBox.localToGlobal(Offset.zero);
      final position = Offset(offset.dx, offset.dy + renderBox.size.height + 2);
      showDropdown(
        context: context,
        // An explicit position is where the menu opens; following the
        // anchor widget would drag it to that widget's bottom centre.
        follow: false,
        // Top-left corner at the point, as editor context menus open.
        alignment: Alignment.topLeft,
        anchorAlignment: Alignment.topLeft,
        position: position,
        builder: (context) => DropdownMenu(
          children: [
            MenuButton(
              child: Text(
                'Auto Preview (LOD 0)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: _viewModel.forcedLod == null ? FontWeight.bold : FontWeight.normal,
                  color: _viewModel.forcedLod == null ? EditorColors.primary : EditorColors.foreground,
                ),
              ),
              onPressed: (ctx) {
                _viewModel.setForcedLod(null);
              },
            ),
            const MenuDivider(),
            ..._viewModel.lods.map((lod) {
              final isSelected = _viewModel.forcedLod == lod.level;
              return MenuButton(
                child: Text(
                  'LOD ${lod.level} (${(lod.reductionRatio * 100).toInt()}%, ${lod.triangleCount} tris)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? EditorColors.primary : EditorColors.foreground,
                  ),
                ),
                onPressed: (ctx) {
                  _viewModel.setForcedLod(lod.level);
                },
              );
            }),
          ],
        ),
      );
    }
  }

  Widget _buildToolbar(bool isDirty) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.card,
      child: Row(
        children: [
          const OutlineBadge(
            child: Text('STATIC MESH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyan)),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.assetName}${isDirty ? ' *' : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground),
          ),
          const SizedBox(width: 12),

          // Forced LOD Selector
          OutlineButton(
            key: _forcedLodBtnKey,
            size: ButtonSize.small,
            onPressed: _showForcedLodMenu,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.layers, size: 12, color: Colors.cyan),
                const SizedBox(width: 4),
                Text(
                  _viewModel.forcedLod == null ? 'Forced LOD: Auto (0)' : 'Forced LOD: ${_viewModel.forcedLod}',
                  style: const TextStyle(fontSize: 10),
                ),
                const SizedBox(width: 2),
                const Icon(LucideIcons.chevronDown, size: 10),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Collision Shape Count Badge
          OutlineBadge(
            child: Text(
              '${_viewModel.collisionShapes.length} Collision Shape${_viewModel.collisionShapes.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 9),
            ),
          ),
          const Spacer(),

          // Collision Generation Dropdown
          OutlineButton(
            key: _collisionBtnKey,
            size: ButtonSize.small,
            onPressed: _showCollisionMenu,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.shield, size: 12, color: Colors.amber),
                SizedBox(width: 4),
                Text('Collision', style: TextStyle(fontSize: 10)),
                SizedBox(width: 2),
                Icon(LucideIcons.chevronDown, size: 10),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Collision Wireframe Toggle
          GhostButton(
            size: ButtonSize.small,
            onPressed: _viewModel.toggleCollisionWireframe,
            child: Icon(
              LucideIcons.eye,
              size: 14,
              color: _viewModel.showCollisionWireframe ? EditorColors.primary : EditorColors.mutedForeground,
            ),
          ),
          const SizedBox(width: 8),

          // Save Button
          PrimaryButton(
            size: ButtonSize.small,
            onPressed: () => _viewModel.save(),
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
