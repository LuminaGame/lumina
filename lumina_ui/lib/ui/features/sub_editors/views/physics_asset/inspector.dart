part of '../physics_asset_sub_editor.dart';

/// Validation panel and the inspector for the selected body or
/// constraint, with its number / vector field helpers.
mixin _PhysicsAssetInspector on _PhysicsAssetSubEditorStateBase {

  // -------------------------------------------------------- validation

  @override
  Widget _buildValidationPanel() {
    final results = _viewModel.lastValidation;
    final hits = results.where((r) => r.isColliding).toList();
    return Container(
      key: const ValueKey('physics_validation_results'),
      constraints: const BoxConstraints(maxHeight: 160),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: EditorColors.card.withValues(alpha: 0.94),
        border: Border.all(color: EditorColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(hits.isEmpty ? LucideIcons.circleCheck : LucideIcons.triangleAlert,
                  size: 12, color: hits.isEmpty ? Colors.green : Colors.orange),
              const SizedBox(width: 6),
              Text(
                'Overlap Validation — Bind Pose (${hits.length} interpenetrating ${hits.length == 1 ? 'pair' : 'pairs'})',
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground),
              ),
              const Spacer(),
              GhostButton(
                size: ButtonSize.small,
                onPressed: () => _viewModel.selectBody(null),
                child: const Text('Re-run with Validate Overlaps', style: TextStyle(fontSize: 8)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Flexible(
            child: results.isEmpty
                ? const Text('No interpenetrating bodies in bind pose.',
                    style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground))
                : ListView(
                    shrinkWrap: true,
                    children: results.map((r) {
                      return Clickable(
                        onPressed: () => _viewModel.selectBody(r.boneA),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(r.disabled ? LucideIcons.eyeOff : LucideIcons.zap,
                                  size: 10, color: r.disabled ? EditorColors.mutedForeground : Colors.orange),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('${r.bodyA}  ↔  ${r.bodyB}',
                                    style: const TextStyle(fontSize: 9, color: EditorColors.foreground)),
                              ),
                              Text(
                                r.disabled
                                    ? 'Collision disabled — skipped'
                                    : 'depth ${r.penetrationDepth.toStringAsFixed(2)} cm',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: r.disabled ? EditorColors.mutedForeground : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- inspector

  @override
  Widget _buildInspector() {
    final body = _viewModel.selectedBody;
    final constraint = _viewModel.selectedConstraint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: EditorColors.card,
          child: Text(
            body != null
                ? 'BODY: ${body.name}'
                : (constraint != null ? 'CONSTRAINT: ${constraint.name}' : 'DETAILS'),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: body != null
                ? _buildBodyInspector(body)
                : (constraint != null
                    ? _buildConstraintInspector(constraint)
                    : const Text('Select a body or constraint in the tree.',
                        style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground))),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground));

  Widget _numberField({
    required String fieldKey,
    required double value,
    required ValueChanged<double> onChanged,
    bool enabled = true,
  }) {
    final text = value.toStringAsFixed(3);
    return SizedBox(
      height: 28,
      child: TextField(
        key: ValueKey(fieldKey),
        controller: _controller(fieldKey, text),
        enabled: enabled,
        onEditingComplete: () {
          final parsed = double.tryParse(_controllers[fieldKey]!.text);
          if (parsed != null) onChanged(parsed);
        },
        onSubmitted: (raw) {
          final parsed = double.tryParse(raw);
          if (parsed != null) onChanged(parsed);
        },
        onChanged: _userEdit((raw) {
          final parsed = double.tryParse(raw);
          if (parsed != null) onChanged(parsed);
        }),
      ),
    );
  }

  Widget _vectorRow({
    required String fieldPrefix,
    required List<double> values,
    required void Function(int axis, double value) onChanged,
  }) {
    const axes = ['X', 'Y', 'Z'];
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(axes[i]),
                _numberField(
                  fieldKey: '${fieldPrefix}_${axes[i].toLowerCase()}',
                  value: values[i],
                  onChanged: (v) => onChanged(i, v),
                ),
              ],
            ),
          ),
          if (i < 2) const SizedBox(width: 4),
        ],
      ],
    );
  }

  Widget _buildBodyInspector(PhysicsBody body) {
    final bone = body.boneName;
    return Accordion(
      items: [
        AccordionItem(
          expanded: true,
          trigger: const AccordionTrigger(child: Text('Primitive', style: TextStyle(fontSize: 10))),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Primitive Type'),
              const SizedBox(height: 4),
              Select<PhysicsShapeType>(
                key: const ValueKey('physics_body_shape'),
                value: body.shape,
                onChanged: (s) {
                  if (s != null) _viewModel.setBodyShape(bone, s);
                },
                itemBuilder: (context, s) => Text(s.label, style: const TextStyle(fontSize: 9.5)),
                popup: SelectPopup(
                  items: SelectItemList(
                    children: PhysicsShapeType.values
                        .map((s) => SelectItemButton(value: s, child: Text(s.label)))
                        .toList(),
                  ),
                ).call,
              ),
              const SizedBox(height: 8),
              if (body.shape == PhysicsShapeType.box)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Box Half Extents (cm)'),
                    _vectorRow(
                      fieldPrefix: 'physics_body_extent',
                      values: body.halfExtents,
                      onChanged: (axis, v) => _viewModel.setBodyExtent(bone, axis, v),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Radius (cm)'),
                          _numberField(
                            fieldKey: 'physics_body_radius',
                            value: body.radius,
                            onChanged: (v) => _viewModel.setBodyRadius(bone, v),
                          ),
                        ],
                      ),
                    ),
                    if (body.shape == PhysicsShapeType.capsule) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Half Height (cm, full capsule)'),
                            _numberField(
                              fieldKey: 'physics_body_half_height',
                              value: body.halfHeight,
                              onChanged: (v) => _viewModel.setBodyHalfHeight(bone, v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              if (body.shape == PhysicsShapeType.capsule && body.halfHeight < body.radius)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Half height is clamped to the radius (degenerate capsule = sphere).',
                      style: TextStyle(fontSize: 8.5, color: Colors.orange)),
                ),
            ],
          ),
        ),
        AccordionItem(
          expanded: true,
          trigger: const AccordionTrigger(child: Text('Relative Transform', style: TextStyle(fontSize: 10))),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Offset Location (cm, vs bone)'),
              _vectorRow(
                fieldPrefix: 'physics_body_offset_loc',
                values: body.offsetLocation,
                onChanged: (axis, v) => _viewModel.setBodyOffsetLocation(bone, axis, v),
              ),
              const SizedBox(height: 6),
              _label('Offset Rotation (deg, vs bone)'),
              _vectorRow(
                fieldPrefix: 'physics_body_offset_rot',
                values: body.offsetRotationDeg,
                onChanged: (axis, v) => _viewModel.setBodyOffsetRotation(bone, axis, v),
              ),
            ],
          ),
        ),
        AccordionItem(
          expanded: true,
          trigger: const AccordionTrigger(child: Text('Physics', style: TextStyle(fontSize: 10))),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Mass in Kg'),
              _numberField(
                fieldKey: 'physics_body_mass',
                value: body.massKg,
                onChanged: (v) => _viewModel.setBodyMass(bone, v),
              ),
              const SizedBox(height: 6),
              _label('Linear Damping'),
              _numberField(
                fieldKey: 'physics_body_linear_damping',
                value: body.linearDamping,
                onChanged: (v) => _viewModel.setBodyLinearDamping(bone, v),
              ),
              const SizedBox(height: 6),
              _label('Angular Damping'),
              _numberField(
                fieldKey: 'physics_body_angular_damping',
                value: body.angularDamping,
                onChanged: (v) => _viewModel.setBodyAngularDamping(bone, v),
              ),
              const SizedBox(height: 6),
              _label('Physics Material'),
              SizedBox(
                height: 28,
                child: TextField(
                  key: const ValueKey('physics_body_material'),
                  controller: _controller('physics_body_material', body.physicsMaterial),
                  placeholder: const Text('PM_Flesh'),
                  onChanged: _userEdit((v) => _viewModel.setBodyPhysicsMaterial(bone, v)),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Mass and damping are authored for a future dynamics solver — lumina runs kinematic collision only, so nothing simulates here.',
                style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConstraintInspector(PhysicsConstraint constraint) {
    final limits = _viewModel.constraintLimitsEnabled(constraint);
    final bodyA = _viewModel.document.bodyForBone(constraint.bodyA);
    final bodyB = _viewModel.document.bodyForBone(constraint.bodyB);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Constrained Bodies'),
        const SizedBox(height: 2),
        Text(bodyA?.name ?? '${constraint.bodyA} (missing)',
            style: TextStyle(fontSize: 10, color: bodyA == null ? EditorColors.logError : EditorColors.foreground)),
        Text(bodyB?.name ?? '${constraint.bodyB} (missing)',
            style: TextStyle(fontSize: 10, color: bodyB == null ? EditorColors.logError : EditorColors.foreground)),
        const SizedBox(height: 10),
        _label('Angular Constraint Mode'),
        const SizedBox(height: 4),
        Select<PhysicsAngularMode>(
          key: const ValueKey('physics_constraint_mode'),
          value: constraint.angularMode,
          onChanged: (m) {
            if (m != null) _viewModel.setConstraintMode(constraint.name, m);
          },
          itemBuilder: (context, m) => Text(m.label, style: const TextStyle(fontSize: 9.5)),
          popup: SelectPopup(
            items: SelectItemList(
              children: PhysicsAngularMode.values
                  .map((m) => SelectItemButton(value: m, child: Text(m.label)))
                  .toList(),
            ),
          ).call,
        ),
        const SizedBox(height: 10),
        _label('Swing 1 Limit (deg)'),
        _numberField(
          fieldKey: 'physics_constraint_swing1',
          value: constraint.swing1Deg,
          enabled: limits,
          onChanged: (v) => _viewModel.setConstraintSwing1(constraint.name, v),
        ),
        const SizedBox(height: 6),
        _label('Swing 2 Limit (deg)'),
        _numberField(
          fieldKey: 'physics_constraint_swing2',
          value: constraint.swing2Deg,
          enabled: limits,
          onChanged: (v) => _viewModel.setConstraintSwing2(constraint.name, v),
        ),
        const SizedBox(height: 6),
        _label('Twist Limit (deg)'),
        _numberField(
          fieldKey: 'physics_constraint_twist',
          value: constraint.twistDeg,
          enabled: limits,
          onChanged: (v) => _viewModel.setConstraintTwist(constraint.name, v),
        ),
        const SizedBox(height: 10),
        DestructiveButton(
          key: const ValueKey('physics_remove_constraint'),
          size: ButtonSize.small,
          onPressed: () => _viewModel.removeConstraint(constraint.name),
          child: const Text('Remove Constraint', style: TextStyle(fontSize: 9)),
        ),
      ],
    );
  }
}
