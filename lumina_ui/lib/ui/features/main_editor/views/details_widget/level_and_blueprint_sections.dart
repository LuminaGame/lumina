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
        _WorldPartitionSection(vm: vm),
      ],
    );
  }
}
