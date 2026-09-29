part of '../physics_asset_sub_editor.dart';

/// Left panel: bone / body / constraint tree rows and their context
/// menus.
mixin _PhysicsAssetTreePanel on _PhysicsAssetSubEditorStateBase {

  // ---------------------------------------------------------- left panel

  @override
  Widget _buildTreePanel() {
    final selectedBone = _viewModel.selectedBoneName;
    final hasBody = selectedBone != null && _viewModel.document.bodyForBone(selectedBone) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: EditorColors.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.bone, size: 12, color: Colors.purple),
                  SizedBox(width: 6),
                  Text('SKELETON TREE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('physics_bone_filter'),
                controller: _filterController,
                placeholder: const Text('Filter bones (pelvis, spine)...'),
                onChanged: _viewModel.setBoneFilter,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final shape in PhysicsShapeType.values) ...[
                    OutlineButton(
                      key: ValueKey('physics_add_body_${shape.name}'),
                      size: ButtonSize.small,
                      onPressed: selectedBone == null
                          ? null
                          : () => hasBody
                              ? _viewModel.replaceBody(selectedBone, shape)
                              : _viewModel.addBody(selectedBone, shape),
                      child: Text(shape.label, style: const TextStyle(fontSize: 8.5)),
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  OutlineButton(
                    key: const ValueKey('physics_add_constraint'),
                    size: ButtonSize.small,
                    onPressed: selectedBone == null || !hasBody
                        ? null
                        : () {
                            final parent = _viewModel.nearestParentBodyBone(selectedBone);
                            if (parent != null) _viewModel.addConstraint(parent, selectedBone);
                          },
                    child: const Text('Add Constraint', style: TextStyle(fontSize: 8.5)),
                  ),
                  const SizedBox(width: 4),
                  OutlineButton(
                    key: const ValueKey('physics_remove_body'),
                    size: ButtonSize.small,
                    onPressed: !hasBody ? null : () => _viewModel.removeBody(selectedBone),
                    child: const Text('Remove Body', style: TextStyle(fontSize: 8.5)),
                  ),
                ],
              ),
              if (_viewModel.lastError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_viewModel.lastError!,
                      style: const TextStyle(fontSize: 8.5, color: EditorColors.logError)),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            children: _viewModel.rootBones.map((n) => _buildBoneRow(n, 0)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBoneRow(GlbNode node, int depth) {
    if (!_viewModel.matchesFilter(node)) return const SizedBox.shrink();
    final body = _viewModel.document.bodyForBone(node.name);
    final constraints = _viewModel.document.constraintsForBone(node.name);
    final expanded = !_collapsedBones.contains(node.name);
    final isSelected = _viewModel.selectedBoneName == node.name && _viewModel.selectedBody == null;
    final hasChildren = node.children.isNotEmpty || body != null || constraints.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onSecondaryTapDown: (d) => _showBoneContextMenu(context, d.globalPosition, node),
          child: Clickable(
            onPressed: () => _viewModel.selectBone(node.name),
            child: Container(
              key: ValueKey('physics_bone_row_${node.name}'),
              height: 22,
              padding: EdgeInsets.only(left: 6.0 + depth * 12.0, right: 8.0),
              color: isSelected ? Colors.purple.withValues(alpha: 0.22) : Colors.transparent,
              child: Row(
                children: [
                  if (hasChildren)
                    GestureDetector(
                      onTap: () => setState(() {
                        if (expanded) {
                          _collapsedBones.add(node.name);
                        } else {
                          _collapsedBones.remove(node.name);
                        }
                      }),
                      child: Icon(expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                          size: 11, color: EditorColors.mutedForeground),
                    )
                  else
                    const SizedBox(width: 11),
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.bone, size: 10, color: Colors.purple),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(node.name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: EditorColors.foreground,
                        ),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...[
          if (body != null) _buildBodyRow(body, depth + 1),
          ...constraints.map((c) => _buildConstraintRow(c, depth + 1)),
          ...node.children.map((c) => _buildBoneRow(c, depth + 1)),
        ],
      ],
    );
  }

  IconData _shapeIcon(PhysicsShapeType shape) {
    switch (shape) {
      case PhysicsShapeType.capsule:
        return LucideIcons.pill;
      case PhysicsShapeType.box:
        return LucideIcons.box;
      case PhysicsShapeType.sphere:
        return LucideIcons.circle;
    }
  }

  Widget _buildBodyRow(PhysicsBody body, int depth) {
    final isSelected = _viewModel.selectedBody?.boneName == body.boneName;
    final dimmed = _viewModel.document.disabledCollisionPairs.any((p) => p.contains(body.boneName));
    return GestureDetector(
      onSecondaryTapDown: (d) => _showBodyContextMenu(context, d.globalPosition, body),
      child: Clickable(
        onPressed: () => _viewModel.selectBody(body.boneName),
        child: Container(
          key: ValueKey('physics_body_row_${body.boneName}'),
          height: 20,
          padding: EdgeInsets.only(left: 6.0 + depth * 12.0, right: 8.0),
          color: isSelected ? Colors.cyan.withValues(alpha: 0.22) : Colors.transparent,
          child: Row(
            children: [
              const SizedBox(width: 11),
              Icon(_shapeIcon(body.shape), size: 10, color: dimmed ? EditorColors.mutedForeground : Colors.cyan),
              const SizedBox(width: 6),
              Expanded(
                child: Text(body.name,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: dimmed ? EditorColors.mutedForeground : Colors.cyan,
                    ),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${body.massKg.toStringAsFixed(1)} kg',
                  style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConstraintRow(PhysicsConstraint constraint, int depth) {
    final isSelected = _viewModel.selectedConstraint?.name == constraint.name;
    return Clickable(
      onPressed: () => _viewModel.selectConstraint(constraint.name),
      child: Container(
        key: ValueKey('physics_constraint_row_${constraint.name}'),
        height: 20,
        padding: EdgeInsets.only(left: 6.0 + depth * 12.0, right: 8.0),
        color: isSelected ? Colors.amber.withValues(alpha: 0.22) : Colors.transparent,
        child: Row(
          children: [
            const SizedBox(width: 11),
            const Icon(LucideIcons.link, size: 10, color: Colors.amber),
            const SizedBox(width: 6),
            Expanded(
              child: Text(constraint.name,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: Colors.amber,
                  ),
                  overflow: TextOverflow.ellipsis),
            ),
            Text(constraint.angularMode.label,
                style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
          ],
        ),
      ),
    );
  }

  void _showBoneContextMenu(BuildContext context, Offset position, GlbNode node) {
    final hasBody = _viewModel.document.bodyForBone(node.name) != null;
    final parentBody = _viewModel.nearestParentBodyBone(node.name);
    showDropdown(
      context: context,
      // An explicit position is where the menu opens; following the
      // anchor widget would drag it to that widget's bottom centre.
      follow: false,
      // Top-left corner at the point, as editor context menus open.
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      position: position,
      builder: (ctx) => DropdownMenu(
        children: [
          for (final shape in PhysicsShapeType.values)
            MenuButton(
              leading: Icon(_shapeIcon(shape), size: 12, color: Colors.cyan),
              child: Text('${hasBody ? 'Replace' : 'Add'} Body: ${shape.label}',
                  style: const TextStyle(fontSize: 10)),
              onPressed: (c) {
                hasBody ? _viewModel.replaceBody(node.name, shape) : _viewModel.addBody(node.name, shape);
              },
            ),
          const MenuDivider(),
          MenuButton(
            enabled: hasBody,
            leading: const Icon(LucideIcons.trash2, size: 12, color: EditorColors.logError),
            child: const Text('Remove Body', style: TextStyle(fontSize: 10)),
            onPressed: (c) {
              _viewModel.removeBody(node.name);
            },
          ),
          MenuButton(
            enabled: hasBody && parentBody != null,
            leading: const Icon(LucideIcons.link, size: 12, color: Colors.amber),
            child: Text(
              parentBody == null
                  ? 'Add Constraint to Parent Body'
                  : 'Add Constraint to $parentBody',
              style: const TextStyle(fontSize: 10),
            ),
            onPressed: (c) {
              if (parentBody != null) _viewModel.addConstraint(parentBody, node.name);
            },
          ),
          MenuButton(
            leading: const Icon(LucideIcons.copy, size: 12),
            child: const Text('Copy Bone Name', style: TextStyle(fontSize: 10)),
            onPressed: (c) {
              Clipboard.setData(ClipboardData(text: node.name));
            },
          ),
        ],
      ),
    );
  }

  void _showBodyContextMenu(BuildContext context, Offset position, PhysicsBody body) {
    final others = _viewModel.document.bodies.where((b) => b.boneName != body.boneName).toList();
    showDropdown(
      context: context,
      // An explicit position is where the menu opens; following the
      // anchor widget would drag it to that widget's bottom centre.
      follow: false,
      // Top-left corner at the point, as editor context menus open.
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      position: position,
      builder: (ctx) => DropdownMenu(
        children: [
          MenuButton(
            leading: const Icon(LucideIcons.eyeOff, size: 12),
            subMenu: [
              if (others.isEmpty)
                const MenuButton(enabled: false, child: Text('No other bodies', style: TextStyle(fontSize: 10))),
              for (final other in others)
                MenuButton(
                  child: Text(
                    '${_viewModel.isCollisionDisabled(body.boneName, other.boneName) ? '✓ ' : ''}${other.name}',
                    style: const TextStyle(fontSize: 10),
                  ),
                  onPressed: (c) {
                    if (_viewModel.isCollisionDisabled(body.boneName, other.boneName)) {
                      _viewModel.enableCollisionBetween(body.boneName, other.boneName);
                    } else {
                      _viewModel.disableCollisionBetween(body.boneName, other.boneName);
                    }
                  },
                ),
            ],
            child: const Text('Disable Collision With…', style: TextStyle(fontSize: 10)),
          ),
          MenuButton(
            leading: const Icon(LucideIcons.trash2, size: 12, color: EditorColors.logError),
            child: const Text('Remove Body', style: TextStyle(fontSize: 10)),
            onPressed: (c) {
              _viewModel.removeBody(body.boneName);
            },
          ),
        ],
      ),
    );
  }
}
