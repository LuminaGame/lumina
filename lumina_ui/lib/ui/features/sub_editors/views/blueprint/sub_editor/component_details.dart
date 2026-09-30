part of '../blueprint_sub_editor.dart';

/// Details for variables, components and class defaults: property groups
/// and rows, game mode defaults, interfaces and asset pickers.
mixin _BlueprintSubEditorComponentDetails on _BlueprintSubEditorStateBase {

  @override
  Widget _buildVariableDetails(LuminaBlueprintVariable v) {
    final type = v.type;
    return ListView(
      key: const ValueKey('bp_variable_details'),
      padding: const EdgeInsets.all(12),
      children: [
        _detailsHeader(LucideIcons.variable, 'VARIABLE: ${v.name}', BlueprintPinStyle.variableLabel(v.typeName)),
        const Text('Default Value', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        if (type != null && BlueprintPinLiteralEditor.supports(type))
          BlueprintPinLiteralEditor(
            keyPrefix: 'variable_default_${v.name}',
            type: type,
            value: v.defaultValue,
            expanded: true,
            onCommit: (value) => _viewModel.setVariableDefault(v.name, value),
          ),
        const SizedBox(height: 12),
        Text('Used by ${_viewModel.nodesUsingVariable(v.name).length} node(s)',
            style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
      ],
    );
  }

  @override
  Widget _buildDetailsInspector() {
    final selectedId = _viewModel.selectedComponentId;
    final selectedNode = selectedId != null ? _viewModel.getComponent(selectedId) : null;

    if (selectedNode == null) {
      return _buildClassDefaultsInspector();
    }

    final schemas = BlueprintComponentRegistry.getSchema(selectedNode.type);
    final groups = <String, List<ComponentPropertySchema>>{};
    for (final s in schemas) {
      groups.putIfAbsent(s.group, () => []).add(s);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Component Header
        Row(
          children: [
            const Icon(LucideIcons.slidersHorizontal, size: 12, color: EditorColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'DETAILS: ${selectedNode.name}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(selectedNode.type, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 10),

        if (groups.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No configurable properties for this component', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
            ),
          )
        else
          ...groups.entries.map((entry) => _buildPropertyGroup(entry.key, entry.value, selectedNode)),
        // Collision shapes get the Collision section.
        if (BlueprintComponentRegistry.isCollisionCapable(selectedNode.type))
          CollisionSectionEditor(
            key: ValueKey('bp_collision_${selectedNode.id}'),
            keyPrefix: 'bp_collision',
            value: CollisionJson.of(selectedNode.properties),
            base: _viewModel.collisionBase(selectedNode.id),
            onChanged: (json) => _viewModel.setComponentCollision(selectedNode.id, json),
          ),
        // Collision shapes and static meshes get Physics.
        if (BlueprintEditorViewModel.isPhysicsCapable(selectedNode.type))
          Builder(builder: (context) {
            final inherited = _viewModel.inheritedPhysics(selectedNode.id);
            return PhysicsSectionEditor(
              key: ValueKey('bp_physics_${selectedNode.id}'),
              keyPrefix: 'bp_physics',
              value: PhysicsJson.of(selectedNode.properties),
              inherited: inherited?.physics,
              inheritedFrom: inherited?.meshName,
              computedMassKg: _viewModel.computedMassKg(selectedNode.id),
              onChanged: (json) => _viewModel.setComponentPhysics(selectedNode.id, json),
            );
          }),
      ],
    );
  }

  /// A GameMode Blueprint's class defaults: the
  /// Default Pawn Class, picked among the project's Pawn and Character
  /// Blueprints, and the Player Controller Class.
  List<Widget> _buildGameModeDefaults() {
    final defaults = _viewModel.document.classDefaults;
    final pawn = defaults['defaultPawnClass'] as String? ?? '';
    final controller = defaults['playerControllerClass'] as String? ?? '';
    return [
      const Text('Default Pawn Class', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
      const SizedBox(height: 4),
      AssetPickerSelect(
        key: const ValueKey('gm_default_pawn_select'),
        keyPrefix: 'gm_default_pawn',
        assets: [for (final p in _viewModel.pawnBlueprints) _pathAsset(p, AssetType.actor)],
        selectedPath: pawn.isEmpty ? null : pawn,
        placeholder: 'None (a plain pawn)',
        onSelected: (a) => _viewModel.setGameModeDefault('defaultPawnClass', a.relativePath),
        onCleared: () => _viewModel.setGameModeDefault('defaultPawnClass', ''),
      ),
      const SizedBox(height: 12),
      const Text('Player Controller Class', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
      const SizedBox(height: 4),
      Select<String>(
        key: const ValueKey('gm_player_controller_select'),
        value: controller.isEmpty ? 'LuminaPlayerController' : controller,
        itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 11)),
        onChanged: (v) => _viewModel.setGameModeDefault('playerControllerClass', v == 'LuminaPlayerController' ? '' : v ?? ''),
        popup: SelectPopup(
          items: SelectItemList(
            children: const [SelectItemButton(value: 'LuminaPlayerController', child: Text('LuminaPlayerController'))],
          ),
        ).call,
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _buildClassDefaultsInspector() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Row(
          children: [
            Icon(LucideIcons.shieldCheck, size: 12, color: EditorColors.primary),
            SizedBox(width: 6),
            Text('CLASS DEFAULTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary)),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 10),

        // Parent Class Selection
        const Text('Parent Class', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        Select<String>(
          value: _viewModel.document.parentClass,
          onChanged: (val) {
            if (val != null) _viewModel.setParentClass(val);
          },
          itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 11)),
          popup: SelectPopup(
            items: SelectItemList(
              children: const [
                SelectItemButton(value: 'LuminaActor', child: Text('LuminaActor')),
                SelectItemButton(value: 'LuminaPawn', child: Text('LuminaPawn')),
                SelectItemButton(value: 'LuminaCharacter', child: Text('LuminaCharacter')),
                SelectItemButton(value: BlueprintEditorViewModel.gameModeParent, child: Text('LuminaGameMode')),
              ],
            ),
          ).call,
        ),
        const SizedBox(height: 12),
        if (_viewModel.document.parentClass == BlueprintEditorViewModel.gameModeParent) ..._buildGameModeDefaults(),
        ..._buildInterfacesSection(),

        // Initial Health
        const Text('Initial Health', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        TextField(
          initialValue: (_viewModel.document.classDefaults['initialHealth'] ?? 100.0).toString(),
          onChanged: (val) {
            final parsed = double.tryParse(val);
            if (parsed != null) {
              _viewModel.setClassDefault('initialHealth', parsed);
            }
          },
        ),
      ],
    );
  }

  /// Class Defaults → Interfaces: the implemented
  /// interface assets, each removable, and a picker of the project's others.
  List<Widget> _buildInterfacesSection() {
    final implemented = _viewModel.document.interfaces;
    final available = [for (final i in _viewModel.projectInterfaces) if (!implemented.contains(i.name)) i.name];
    return [
      const Row(children: [
        Icon(LucideIcons.plug, size: 12, color: EditorColors.primary),
        SizedBox(width: 6),
        Text('INTERFACES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary)),
      ]),
      const SizedBox(height: 6),
      if (implemented.isEmpty)
        const Text('No interface implemented.', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
      for (final name in implemented)
        Padding(
          key: ValueKey('interface_row_$name'),
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            const Icon(LucideIcons.plug, size: 11, color: EditorColors.mutedForeground),
            const SizedBox(width: 6),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
            GhostButton(
              key: ValueKey('interface_remove_$name'),
              size: ButtonSize.xSmall,
              density: ButtonDensity.icon,
              onPressed: () => _viewModel.removeInterface(name),
              child: const Icon(LucideIcons.x, size: 10),
            ),
          ]),
        ),
      const SizedBox(height: 4),
      SizedBox(
        height: 26,
        child: Select<String>(
          key: const ValueKey('interface_add_select'),
          value: null,
          placeholder: Text(available.isEmpty ? 'No other interface in the project' : 'Add interface…', style: const TextStyle(fontSize: 10)),
          itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 10)),
          onChanged: (v) {
            if (v != null) _viewModel.addInterface(v);
          },
          popup: SelectPopup(
            items: SelectItemList(
              children: [
                for (final name in available)
                  SelectItemButton(key: ValueKey('interface_add_item_$name'), value: name, child: Text(name, style: const TextStyle(fontSize: 10))),
              ],
            ),
          ).call,
        ),
      ),
      const SizedBox(height: 4),
      const Text('Implemented functions appear as Event <Function> in the palette.', style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
      const SizedBox(height: 12),
    ];
  }

  Widget _buildPropertyGroup(String groupName, List<ComponentPropertySchema> properties, LuminaBlueprintComponent node) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(groupName, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          const SizedBox(height: 8),
          ...properties.map((prop) => _buildPropertyRow(prop, node)),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(ComponentPropertySchema prop, LuminaBlueprintComponent node) {
    final currentVal = node.properties[prop.dartField] ?? prop.defaultValue;

    switch (prop.type) {
      case ComponentPropertyType.number:
        // A slider over the schema's range plus a typed / scrubbed field that
        // may go past it up to the hard limits; one undo step per commit
        // (a slider drag on release, a typed value on Enter / blur).
        final numVal = (currentVal is num) ? currentVal.toDouble() : 0.0;
        final defaultVal = (prop.defaultValue is num) ? (prop.defaultValue as num).toDouble() : prop.min;
        return Padding(
          key: ValueKey('bp_prop_${node.id}_${prop.dartField}'),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prop.name, style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
              const SizedBox(height: 4),
              SliderField(
                value: numVal,
                defaultValue: defaultVal,
                min: prop.min,
                max: prop.max,
                hardMin: prop.lowerLimit,
                hardMax: prop.upperLimit,
                unit: _unitOf(prop),
                onChanged: (v) => _viewModel.previewProperty(node.id, prop.dartField, v),
                onCommit: (v) => _viewModel.commitProperty(node.id, prop.dartField, v),
                onReset: () => _viewModel.commitProperty(node.id, prop.dartField, defaultVal),
              ),
            ],
          ),
        );

      case ComponentPropertyType.boolean:
        final boolVal = currentVal == true;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(prop.name, style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
              Switch(
                value: boolVal,
                onChanged: (val) => _viewModel.setProperty(node.id, prop.dartField, val),
              ),
            ],
          ),
        );

      case ComponentPropertyType.vector3:
        List<double> vec = [0.0, 0.0, 0.0];
        if (currentVal is List) {
          vec = (currentVal).map((e) => (e as num).toDouble()).toList();
          while (vec.length < 3) {
            vec.add(0.0);
          }
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prop.name, style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: ValueKey('${node.id}.${prop.dartField}.0.${_viewModel.componentTransformRevision}'),
                      initialValue: vec[0].toStringAsFixed(1),
                      placeholder: const Text('X').small(),
                      onChanged: (val) {
                        final v = double.tryParse(val) ?? 0.0;
                        _viewModel.setProperty(node.id, prop.dartField, [v, vec[1], vec[2]]);
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      key: ValueKey('${node.id}.${prop.dartField}.1.${_viewModel.componentTransformRevision}'),
                      initialValue: vec[1].toStringAsFixed(1),
                      placeholder: const Text('Y').small(),
                      onChanged: (val) {
                        final v = double.tryParse(val) ?? 0.0;
                        _viewModel.setProperty(node.id, prop.dartField, [vec[0], v, vec[2]]);
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      key: ValueKey('${node.id}.${prop.dartField}.2.${_viewModel.componentTransformRevision}'),
                      initialValue: vec[2].toStringAsFixed(1),
                      placeholder: const Text('Z').small(),
                      onChanged: (val) {
                        final v = double.tryParse(val) ?? 0.0;
                        _viewModel.setProperty(node.id, prop.dartField, [vec[0], vec[1], v]);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case ComponentPropertyType.assetReference:
        if (prop.dartField == 'animClass') return _buildAnimClassPicker(prop, node);
        if (prop.dartField == 'hullAsset') return _buildHullAssetPicker(prop, node);
        final selectedVal = (currentVal is String) ? currentVal : '';
        final fieldLower = prop.dartField.toLowerCase();
        final nameLower = prop.name.toLowerCase();

        final isAnim = fieldLower.contains('anim') || nameLower.contains('anim');
        final isMat = fieldLower.contains('material') || fieldLower.contains('mat') || nameLower.contains('material');
        final isStatic = fieldLower.contains('static') || nameLower.contains('static mesh');
        final availableAssets = isAnim
            ? _viewModel.availableAnimations
            : (isMat
                ? _viewModel.availableMaterials
                : (isStatic
                    ? _viewModel.availableStaticMeshes
                    : _viewModel.availableSkeletalMeshes));

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(prop.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
                  const Spacer(),
                  Clickable(
                    onPressed: () => _viewModel.load(),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.refreshCw, size: 10, color: EditorColors.mutedForeground),
                        SizedBox(width: 2),
                        Text('Refresh', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // The shared searchable picker with thumbnails.
              AssetPickerSelect(
                key: ValueKey('bp_asset_${node.id}_${prop.dartField}'),
                keyPrefix: 'bp_asset_${prop.dartField}',
                assets: availableAssets,
                selectedPath: selectedVal.isNotEmpty ? selectedVal : null,
                onSelected: (a) => _viewModel.setMeshForComponent(node.id, prop.dartField, a.relativePath),
                onCleared: () => _viewModel.setMeshForComponent(node.id, prop.dartField, ''),
              ),
            ],
          ),
        );

      case ComponentPropertyType.enumType:
        final currentStr = currentVal?.toString() ?? prop.defaultValue?.toString() ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prop.name, style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
              const SizedBox(height: 4),
              Select<String>(
                value: prop.enumOptions.contains(currentStr) ? currentStr : (prop.enumOptions.isNotEmpty ? prop.enumOptions.first : null),
                onChanged: (val) {
                  if (val != null) _viewModel.setProperty(node.id, prop.dartField, val);
                },
                itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 11)),
                popup: SelectPopup(
                  items: SelectItemList(
                    children: prop.enumOptions.map((opt) => SelectItemButton(value: opt, child: Text(opt))).toList(),
                  ),
                ).call,
              ),
            ],
          ),
        );

      case ComponentPropertyType.color:
        // The level lights' colour picker: typed hex or picked, one undo
        // step per commit.
        final hex = currentVal is String ? currentVal : (prop.defaultValue as String? ?? '#FFFFFF');
        return Padding(
          key: ValueKey('bp_prop_${node.id}_${prop.dartField}'),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prop.name, style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
              const SizedBox(height: 4),
              ColorField(
                value: hex,
                defaultValue: prop.defaultValue as String? ?? '#FFFFFF',
                onChanged: (v) => _viewModel.previewProperty(node.id, prop.dartField, v),
                onCommit: (v) => _viewModel.commitProperty(node.id, prop.dartField, v),
                onReset: () => _viewModel.commitProperty(node.id, prop.dartField, prop.defaultValue),
              ),
            ],
          ),
        );

      case ComponentPropertyType.string:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prop.name, style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
              const SizedBox(height: 4),
              TextField(
                initialValue: currentVal?.toString() ?? '',
                onChanged: (val) => _viewModel.setProperty(node.id, prop.dartField, val),
              ),
            ],
          ),
        );
    }
  }

  /// The Anim Class picker: only Animation
  /// Blueprints whose target mesh is this component's skeletal mesh.
  Widget _buildAnimClassPicker(ComponentPropertySchema prop, LuminaBlueprintComponent node) {
    final mesh = node.properties['skeletalMeshAsset'] as String?;
    final options = _viewModel.animBlueprintsFor(mesh);
    final current = node.properties['animClass'] as String? ?? '';
    String short(String p) => p.split('/').last.replaceAll('.lmas', '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prop.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
          const SizedBox(height: 6),
          AssetPickerSelect(
            key: const ValueKey('anim_class_select'),
            keyPrefix: 'anim_class',
            assets: [for (final o in options) _pathAsset(o, AssetType.animBlueprint)],
            selectedPath: current.isEmpty ? null : current,
            placeholder: mesh == null || mesh.isEmpty ? 'Pick a Skeletal Mesh first' : 'None',
            onSelected: (a) => _viewModel.setAnimClass(node.id, a.relativePath),
            onCleared: () => _viewModel.setAnimClass(node.id, ''),
          ),
          const SizedBox(height: 4),
          Text(
            '${options.length} Animation Blueprint${options.length == 1 ? '' : 's'} for ${mesh == null || mesh.isEmpty ? 'no mesh' : short(mesh)}',
            style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
          ),
        ],
      ),
    );
  }

  /// A Convex Collision's hull: the project's static
  /// meshes with simple collision hulls; none warns that it collides as its
  /// box.
  Widget _buildHullAssetPicker(ComponentPropertySchema prop, LuminaBlueprintComponent node) {
    final options = _viewModel.convexHullMeshes;
    final current = node.properties['hullAsset'] as String? ?? '';
    final hasHull = ((node.properties['hullPoints'] as List?)?.length ?? 0) >= 4;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prop.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
          const SizedBox(height: 6),
          AssetPickerSelect(
            key: const ValueKey('hull_asset_select'),
            keyPrefix: 'hull_asset',
            assets: [
              for (final o in options)
                _viewModel.availableStaticMeshes.where((a) => a.relativePath == o).firstOrNull ?? _pathAsset(o, AssetType.filamesh),
            ],
            selectedPath: current.isEmpty ? null : current,
            onSelected: (a) => _viewModel.setConvexHullAsset(node.id, a.relativePath),
            onCleared: () => _viewModel.setConvexHullAsset(node.id, ''),
          ),
          const SizedBox(height: 4),
          if (!hasHull)
            const Row(
              key: ValueKey('hull_asset_warning'),
              children: [
                Icon(LucideIcons.triangleAlert, size: 11, color: EditorColors.primary),
                SizedBox(width: 4),
                Expanded(
                  child: Text('No hull: this component collides as its box.',
                      style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                ),
              ],
            )
          else
            Text('${options.length} static mesh${options.length == 1 ? '' : 'es'} with collision hulls',
                style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        ],
      ),
    );
  }
}

/// A stored project-relative `.lmas` path as an asset for the shared picker
/// (the editor's AssetPickerScope swaps in the scanned copy with its
/// thumbnail).
RealAssetInfo _pathAsset(String path, AssetType type) =>
    RealAssetInfo(fileName: path.split('/').last, relativePath: path, type: type, bytes: 0);

/// The unit a number row shows: centimetres for lengths.
String? _unitOf(ComponentPropertySchema prop) {
  final f = prop.dartField.toLowerCase();
  const lengths = ['radius', 'halfheight', 'length', 'height', 'clipplane', 'stepheight'];
  if (lengths.any(f.contains)) return 'cm';
  if (f.contains('speed') && !f.contains('lag')) return 'cm/s';
  if (f == 'fieldofview' || f.contains('angle') || f.contains('yaw')) return '°';
  if (f == 'intensity') return 'lm'; // a point light's luminous power
  return null;
}
