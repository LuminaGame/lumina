part of '../details_widget.dart';

/// One selected actor: transform, collision, component blocks, property
/// rows and the Add Component popover.
mixin _DetailsSingleSelection on _DetailsWidgetStateBase {

  Widget _buildTransformBlock(EditorActorNode actor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CategoryHeader(title: 'Transform'),
        Container(
          color: EditorColors.background,
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 60, child: Text('LOCATION', style: EditorTypography.sectionLabel)),
                  Expanded(
                    child: VectorRow(
                      // The axis letters carry the manipulator's own colours,
                      // so the panel and the 3D gizmo agree on which axis is
                      // which. See EditorColors.axisX/Y/Z.
                      labelColors: const [
                        EditorColors.axisX,
                        EditorColors.axisY,
                        EditorColors.axisZ,
                      ],
                      value: actor.location,
                      onChanged: (v) => widget.viewModel.updateActorLocation(v, isCommit: false),
                      onCommit: (v) => widget.viewModel.updateActorLocation(v, isCommit: true),
                      onReset: () => widget.viewModel.updateActorLocation([0.0, 0.0, 0.0], isCommit: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 60, child: Text('ROTATION', style: EditorTypography.sectionLabel)),
                  Expanded(
                    child: RotationRow(
                      labelColors: const [
                        EditorColors.axisX,
                        EditorColors.axisY,
                        EditorColors.axisZ,
                      ],
                      value: actor.rotation,
                      onChanged: (v) => widget.viewModel.updateActorRotation(v, isCommit: false),
                      onCommit: (v) => widget.viewModel.updateActorRotation(v, isCommit: true),
                      onReset: () => widget.viewModel.updateActorRotation([0.0, 0.0, 0.0], isCommit: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 60, child: Text('SCALE', style: EditorTypography.sectionLabel)),
                  Expanded(
                    child: VectorRow(
                      labelColors: const [
                        EditorColors.axisX,
                        EditorColors.axisY,
                        EditorColors.axisZ,
                      ],
                      value: actor.scale,
                      defaultValue: const [1.0, 1.0, 1.0],
                      onChanged: (v) => widget.viewModel.updateActorScale(v, isCommit: false),
                      onCommit: (v) => widget.viewModel.updateActorScale(v, isCommit: true),
                      onReset: () => widget.viewModel.updateActorScale([1.0, 1.0, 1.0], isCommit: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Mobility', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _MobilityBtn(
                            label: 'Static',
                            active: actor.mobility == 'Static',
                            onTap: () => widget.viewModel.updateActorMobility('Static'),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _MobilityBtn(
                            label: 'Stationary',
                            active: actor.mobility == 'Stationary',
                            onTap: () => widget.viewModel.updateActorMobility('Stationary'),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _MobilityBtn(
                            label: 'Movable',
                            active: actor.mobility == 'Movable',
                            onTap: () => widget.viewModel.updateActorMobility('Movable'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// One Collision section per collision component of a placed Blueprint's
  /// class: the class's values with this instance's
  /// override on top; an edit stores the override in the level.
  List<Widget> _buildBlueprintCollisionBlocks(EditorActorNode actor) {
    final vm = widget.viewModel;
    final components = BlueprintCollisionOverrides.collisionComponentsOf(actor, vm.projectDirPath);
    if (components.isEmpty && BlueprintCollisionOverrides.physicsComponentsOf(actor, vm.projectDirPath).isEmpty) return const [];
    final doc = BlueprintCollisionOverrides.documentOf(vm.projectDirPath, actor.blueprintClass!);
    return [
      for (final c in components) ...[
        _CategoryHeader(title: '${c.name} (${c.type.replaceAll('Lumina', '').replaceAll('Component', '')})'),
        Container(
          color: EditorColors.background,
          padding: const EdgeInsets.all(8),
          child: CollisionSectionEditor(
            key: ValueKey('details_collision_${c.id}'),
            keyPrefix: 'details_collision_${c.id}',
            value: BlueprintCollisionOverrides.collisionOf(actor, c),
            base: BlueprintCollisionOverrides.baseOf(doc, c),
            onChanged: (json) => vm.setActorComponentCollision(actor.id, c.id, json, blueprintComponent: c),
          ),
        ),
        const SizedBox(height: 8),
      ],
      // Each shape's and static mesh's Physics section.
      for (final c in BlueprintCollisionOverrides.physicsComponentsOf(actor, vm.projectDirPath)) ...[
        _CategoryHeader(title: '${c.name} Physics'),
        Container(
          color: EditorColors.background,
          padding: const EdgeInsets.all(8),
          child: PhysicsSectionEditor(
            key: ValueKey('details_physics_${c.id}'),
            keyPrefix: 'details_physics_${c.id}',
            value: BlueprintCollisionOverrides.physicsOf(actor, c),
            inherited: _inheritedPhysics(doc, c),
            onChanged: (json) => vm.setActorComponentPhysics(actor.id, c, json),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  /// The static mesh physics [c] inherits in Blueprint [doc]: the baked
  /// values of its Physics section, else its (or the nearest) mesh's `.lmas`.
  LuminaMeshPhysics? _inheritedPhysics(LuminaBlueprintDocument? doc, LuminaBlueprintComponent c) {
    final physics = c.properties['physics'];
    final baked = physics is Map ? LuminaMeshPhysics.fromJson(physics['meshPhysics']) : null;
    if (baked != null) return baked;
    final meshes = [
      if (c.type == 'LuminaStaticMeshComponent') c,
      ...?doc?.components.where((o) => o.type == 'LuminaStaticMeshComponent'),
    ];
    for (final m in meshes) {
      final stored = m.properties['staticMeshAsset'] as String? ?? '';
      if (stored.isEmpty) continue;
      final found = MeshPhysicsService.forMeshAsset(stored, projectDir: widget.viewModel.projectDirPath);
      if (found != null) return found;
    }
    return null;
  }

  Widget _buildComponentBlock(EditorActorNode actor, EditorComponentNode comp) {
    // A placed Blueprint's collision override shows in its class's section.
    if (BlueprintCollisionOverrides.isOverride(comp)) return const SizedBox.shrink();
    // A placed camera's own component is the Camera section above.
    if (ActorCameraSection.appliesTo(actor) && identical(comp, CameraActorProperties.componentOf(actor))) return const SizedBox.shrink();
    final desc = ComponentPropertyRegistry.descriptors[comp.type];
    // An actor's own collision component gets the
    // Collision section in place of the old preset / matrix rows.
    final collisionCapable = BlueprintComponentRegistry.isCollisionCapable(comp.type);
    if (desc == null && !collisionCapable) return const SizedBox.shrink();
    if (desc == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _CategoryHeader(title: comp.name),
        Container(color: EditorColors.background, padding: const EdgeInsets.all(8), child: _componentCollisionSection(actor, comp)),
        const SizedBox(height: 8),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _CategoryHeader(title: comp.name)),
            IconButton.ghost(
              icon: const Icon(LucideIcons.x, size: 12, color: Colors.red),
              onPressed: () {
                widget.viewModel.removeComponentWithTransaction(actor.id, comp.id);
              },
            ),
          ],
        ),
        // A limit stated honestly above the rows.
        if (desc.note != null)
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
            color: EditorColors.background,
            child: Text(desc.note!, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground, fontStyle: FontStyle.italic)),
          ),
        if (!comp.enabled)
          Container(
            padding: const EdgeInsets.all(4),
            color: EditorColors.background,
            child: const Text('Component Disabled', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground, fontStyle: FontStyle.italic)),
          ),
        if (comp.enabled)
          Container(
            color: EditorColors.background,
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
               ...desc.sections.map((section) {
                final props = desc.properties
                    .where((p) => p.group == section)
                    .where((p) => !collisionCapable || (p.id != 'collisionPreset' && p.id != 'collisionResponses'))
                    .toList();
                
                final matchingProps = props.where((p) => 
                  _searchQuery.isEmpty || 
                  p.label.toLowerCase().contains(_searchQuery) ||
                  p.id.toLowerCase().contains(_searchQuery)
                ).toList();
                
                if (matchingProps.isEmpty) return const SizedBox.shrink();
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(section, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary)),
                    ),
                    ...matchingProps.map((prop) => _buildPropertyRow(actor, comp, prop)),
                    const Divider(),
                  ],
                );
              }),
               if (collisionCapable) _componentCollisionSection(actor, comp),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _componentCollisionSection(EditorActorNode actor, EditorComponentNode comp) => CollisionSectionEditor(
        key: ValueKey('details_collision_${comp.id}'),
        keyPrefix: 'details_collision_${comp.id}',
        value: CollisionJson.of(comp.properties),
        onChanged: (json) => widget.viewModel.setActorComponentCollision(actor.id, comp.id, json),
      );

  Widget _buildPropertyRow(EditorActorNode actor, EditorComponentNode comp, PropertyDescriptor prop) {
    final val = comp.properties[prop.id] ?? prop.defaultValue;
    dynamic effectiveValue = val;
    Widget editorWidget;
    switch (prop.editor) {
      case PropertyEditorType.boolean:
        editorWidget = Checkbox(
          state: (effectiveValue == true) ? CheckboxState.checked : CheckboxState.unchecked,
          onChanged: (v) => widget.viewModel.updateComponentPropertyWithTransaction(actor.id, comp.id, prop.id, v == CheckboxState.checked),
        );
        break;
      case PropertyEditorType.float:
        double doubleVal = (effectiveValue as num?)?.toDouble() ?? 0.0;
        editorWidget = SliderField(
          value: doubleVal,
          defaultValue: (prop.defaultValue as num?)?.toDouble() ?? 0.0,
          min: prop.min ?? 0.0,
          max: prop.max ?? 100.0,
          unit: prop.unit,
          onChanged: (v) => widget.viewModel.updateComponentProperty(actor.id, comp.id, prop.id, v),
          onCommit: (v) => widget.viewModel.updateComponentPropertyWithTransaction(actor.id, comp.id, prop.id, v),
          onReset: () => widget.viewModel.updateComponentPropertyWithTransaction(actor.id, comp.id, prop.id, prop.defaultValue),
        );
        break;
      case PropertyEditorType.dropdown:
        editorWidget = EnumField(
          value: effectiveValue as String? ?? '',
          enumValues: prop.enumValues ?? [],
          isRadioGroup: false,
          onCommit: (v) => widget.viewModel.updateComponentPropertyWithTransaction(actor.id, comp.id, prop.id, v),
        );
        break;
      case PropertyEditorType.vector3:
        List<double> vals = effectiveValue is List ? effectiveValue.map((e) => (e as num).toDouble()).toList() : [0.0, 0.0, 0.0];
        editorWidget = VectorRow(
          value: vals,
          defaultValue: (prop.defaultValue as List?)?.map((e)=>(e as num).toDouble()).toList() ?? [0.0,0.0,0.0],
          onChanged: (v) => widget.viewModel.updateComponentProperty(actor.id, comp.id, prop.id, v),
          onCommit: (v) => widget.viewModel.updateComponentPropertyWithTransaction(actor.id, comp.id, prop.id, v),
          onReset: () => widget.viewModel.updateComponentPropertyWithTransaction(actor.id, comp.id, prop.id, prop.defaultValue),
        );
        break;
      case PropertyEditorType.color:
        editorWidget = ColorField(
          value: effectiveValue as String? ?? '#FFFFFF',
          defaultValue: (prop.defaultValue as String?) ?? '#FFFFFF',
          onChanged: (v) => widget.viewModel.updateComponentProperty(actor.id, comp.id, prop.id, v),
          onCommit: (v) => widget.viewModel.updateComponentPropertyWithTransaction(actor.id, comp.id, prop.id, v),
          onReset: () => widget.viewModel.updateComponentPropertyWithTransaction(actor.id, comp.id, prop.id, prop.defaultValue),
        );
        break;
      case PropertyEditorType.assetRef:
        editorWidget = AssetRefField(
          value: effectiveValue as Map<String, dynamic>?,
          slotName: prop.id,
          assetType: prop.type ?? '',
          onCommit: (v) => widget.viewModel.updateComponentPropertyWithTransaction(actor.id, comp.id, prop.id, v),
          viewModel: widget.viewModel,
        );
        break;
      case PropertyEditorType.collisionMatrix:
        editorWidget = const Text('Matrix Editor (WIP)', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground));
        break;
      default:
        editorWidget = Text(effectiveValue?.toString() ?? '', style: const TextStyle(fontSize: 9));
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: prop.editor == PropertyEditorType.vector3 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Row(
              children: [
                Expanded(child: Text(prop.label, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
                if (prop.unit != null)
                  Text(' (${prop.unit})', style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: editorWidget),
        ],
      ),
    );
  }

  void _showAddComponentPopover(BuildContext context, String actorId) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Component', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 250,
            height: 250,
            child: ListView(
              children: ComponentPropertyRegistry.descriptors.keys.map((type) {
                return GhostButton(
                  onPressed: () {
                    widget.viewModel.addComponentWithTransaction(actorId, type);
                    Navigator.of(context).pop();
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(type.replaceAll('Lumina', '').replaceAll('Component', ''), style: const TextStyle(fontSize: 10)),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            OutlineButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
