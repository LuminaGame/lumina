part of '../details_widget.dart';

/// Plugin detail sections, the placed Blueprint's class block and the
/// Level settings shown when nothing is selected.
mixin _DetailsLevelAndBlueprintSections on _DetailsWidgetStateBase {
  
  /// The Details sections plugins registered for [actor]'s type. The
  /// plugin sees an immutable [EditorActorSnapshot]; its edits come back
  /// through `DetailsTarget.setProperty` as `<ComponentType>.<property>`
  /// (an undoable component edit) or `name` / `location` / `rotation` /
  /// `scale` (the same view-model paths the built-in blocks use).
  List<Widget> _buildPluginSections(BuildContext context, EditorActorNode actor) {
    final vm = widget.viewModel;
    final sections = vm.extensionRegistry.allDetailsCustomizations.where((c) => c.targetTypeId == actor.type).toList();
    if (sections.isEmpty) return const [];
    final target = DetailsTarget(
      target: EditorViewModelLevelAccess.snapshotOf(actor),
      setProperty: (name, value) {
        final dot = name.indexOf('.');
        if (dot > 0) {
          vm.setComponentPropertyWithTransaction(actor.id, name.substring(0, dot), name.substring(dot + 1), value);
          return;
        }
        List<double>? triple() =>
            value is List && value.length >= 3 ? [for (var i = 0; i < 3; i++) (value[i] as num).toDouble()] : null;
        switch (name) {
          case 'name':
            vm.renameActorWithTransaction(actor.id, value.toString());
          case 'location':
            final v = triple();
            if (v != null) vm.updateActorLocation(v, isCommit: true);
          case 'rotation':
            final v = triple();
            if (v != null) vm.updateActorRotation(v, isCommit: true);
          case 'scale':
            final v = triple();
            if (v != null) vm.updateActorScale(v, isCommit: true);
          default:
            vm.logger.log('Plugin details property "$name" is not an actor or component property', level: 'warning', source: 'Details');
        }
      },
    );
    return [
      for (final section in sections) ...[
        _CategoryHeader(title: section.sectionTitle),
        Container(
          key: ValueKey('details_plugin_section_${section.targetTypeId}_${section.sectionTitle}'),
          color: EditorColors.background,
          child: section.builder(context, target),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  /// A placed Blueprint's class and "Edit Blueprint".
  Widget _buildBlueprintClassBlock(EditorActorNode actor) {
    final path = actor.blueprintClass!;
    final preview = actor.blueprintPreview;
    return Container(
      key: const ValueKey('details_blueprint_class'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BLUEPRINT CLASS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(LucideIcons.gitBranch, size: 12, color: EditorColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(path.split('/').last.replaceAll('.lmas', ''),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
            ),
            Text(preview?.parentClass ?? '', style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          ]),
          const SizedBox(height: 2),
          Text(path, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(height: 6),
          OutlineButton(
            key: const ValueKey('details_edit_blueprint'),
            size: ButtonSize.small,
            onPressed: () => openBlueprintAtNode(widget.viewModel, path, null),
            child: const Text('Edit Blueprint', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  /// With nothing selected the panel shows the *level's* own settings — the
  /// place the level's World Partition configuration belongs.
  Widget _buildLevelSettings(BuildContext context) {
    final vm = widget.viewModel;
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Select an actor to view its details. These are the level\'s own settings.',
            style: TextStyle(color: EditorColors.mutedForeground, fontSize: 10),
          ),
        ),
        const _CategoryHeader(title: 'WORLD PARTITION'),
        Container(
          color: EditorColors.background,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Enabled',
                      style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                    ),
                  ),
                  Switch(
                    key: const ValueKey('wp_enabled'),
                    value: vm.worldPartitionEnabled,
                    onChanged: vm.setWorldPartitionEnabled,
                  ),
                ],
              ),
              if (vm.worldPartitionEnabled) ...[
                const SizedBox(height: 8),
                ScrubNumericField(
                  key: const ValueKey('wp_cell_size'),
                  label: 'Cell Size',
                  labelWidth: 96,
                  unit: 'cm',
                  value: vm.worldPartitionCellSize,
                  defaultValue: kWorldPartitionDefaultCellSize,
                  min: 1,
                  onChanged: (v) => vm.setWorldPartitionCellSize(v, commit: false),
                  onCommit: (v) => vm.setWorldPartitionCellSize(v),
                  onReset: () => vm.setWorldPartitionCellSize(kWorldPartitionDefaultCellSize),
                ),
                const SizedBox(height: 4),
                ScrubNumericField(
                  key: const ValueKey('wp_loading_range'),
                  label: 'Loading Range',
                  labelWidth: 96,
                  unit: 'cm',
                  value: vm.worldPartitionLoadingRange,
                  defaultValue: kWorldPartitionDefaultLoadingRange,
                  min: 0,
                  onChanged: (v) => vm.setWorldPartitionLoadingRange(v, commit: false),
                  onCommit: (v) => vm.setWorldPartitionLoadingRange(v),
                  onReset: () => vm.setWorldPartitionLoadingRange(kWorldPartitionDefaultLoadingRange),
                ),
                const SizedBox(height: 4),
                ScrubNumericField(
                  key: const ValueKey('wp_max_transitions'),
                  label: 'Max Cell Transitions / Tick',
                  labelWidth: 96,
                  value: vm.worldPartitionMaxCellTransitionsPerTick.toDouble(),
                  defaultValue: kWorldPartitionDefaultMaxCellTransitionsPerTick.toDouble(),
                  min: 1,
                  fractionDigits: 0,
                  onChanged: (v) => vm.setWorldPartitionMaxCellTransitionsPerTick(v.round(), commit: false),
                  onCommit: (v) => vm.setWorldPartitionMaxCellTransitionsPerTick(v.round()),
                  onReset: () => vm.setWorldPartitionMaxCellTransitionsPerTick(
                      kWorldPartitionDefaultMaxCellTransitionsPerTick),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Data Layers',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary),
                      ),
                    ),
                    OutlineButton(
                      key: const ValueKey('wp_add_layer'),
                      size: ButtonSize.small,
                      onPressed: () => vm.addWorldPartitionDataLayer(),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.plus, size: 12, color: EditorColors.primary),
                          SizedBox(width: 4),
                          Text('Add', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                for (var i = 0; i < vm.worldPartitionDataLayers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 22,
                            child: TextField(
                              key: ValueKey('wp_layer_name_$i'),
                              initialValue: (vm.worldPartitionDataLayers[i]['name'] ?? '').toString(),
                              style: const TextStyle(fontSize: 10),
                              onSubmitted: (v) => vm.setWorldPartitionDataLayerName(i, v),
                              onEditingComplete: () {},
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 3,
                          child: EnumField(
                            key: ValueKey('wp_layer_state_$i'),
                            value: (vm.worldPartitionDataLayers[i]['initialState'] ?? 'unloaded').toString(),
                            enumValues: const ['unloaded', 'loaded', 'activated'],
                            isRadioGroup: false,
                            onCommit: (v) => vm.setWorldPartitionDataLayerState(i, v),
                          ),
                        ),
                        IconButton.ghost(
                          key: ValueKey('wp_layer_remove_$i'),
                          icon: const Icon(LucideIcons.x, size: 12, color: Colors.red),
                          onPressed: () => vm.removeWorldPartitionDataLayer(i),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              const Text(
                'Authoring only: the editor does not stream cells in and out while editing. '
                'These values configure LuminaWorldPartitionSubsystem in the generated game.',
                style: TextStyle(
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                  color: EditorColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
