part of '../particle_sub_editor.dart';

/// The left panel: the emitter list, rename and delete.
mixin _ParticleSubEditorLeftPanel on _ParticleSubEditorStateBase {
  // ------------------------------------------------------------- left panel

  Widget _leftPanel() {
    return Container(
      color: EditorColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('EMITTERS', trailing: [
            GhostButton(
              key: const ValueKey('particle_add_emitter'),
              onPressed: () => vm.addEmitter('Emitter ${vm.emitters.length + 1}'),
              child: const Icon(LucideIcons.plus, size: 12),
            ),
          ]),
          SizedBox(
            height: 150,
            child: ListView.builder(
              itemCount: vm.emitters.length,
              itemBuilder: (context, i) => _emitterRow(i),
            ),
          ),
          const Divider(height: 1),
          _sectionHeader('EMITTER STACK'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Accordion(
                items: [
                  for (final stage in ParticleStage.values)
                    AccordionItem(
                      expanded: stage == _stage,
                      trigger: AccordionTrigger(
                        child: GestureDetector(
                          onTap: () => setState(() => _stage = stage),
                          child: Text(stage.title.toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      content: KeyedSubtree(
                        key: ValueKey('particle_stage_${stage.key}'),
                        child: GestureDetector(
                          onTap: () => setState(() => _stage = stage),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              vm.stageSummary(stage.key),
                              style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emitterRow(int index) {
    final entry = vm.emitters[index];
    final selected = index == vm.selectedEmitterIndex;
    return EditorContextMenu(
      items: [
        MenuButton(
          onPressed: (_) => vm.duplicateEmitter(index),
          child: const Text('Duplicate Emitter'),
        ),
        MenuButton(
          onPressed: (_) => _promptRename(index),
          child: const Text('Rename Emitter'),
        ),
        MenuButton(
          onPressed: (_) => _confirmDelete(index),
          enabled: vm.emitters.length > 1,
          child: const Text('Delete Emitter'),
        ),
      ],
      child: GestureDetector(
        onTap: () => vm.selectEmitter(index),
        child: Container(
          key: ValueKey('particle_emitter_row_$index'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          color: selected ? EditorColors.primary.withValues(alpha: 0.18) : Colors.transparent,
          child: Row(
            children: [
              Checkbox(
                key: ValueKey('particle_emitter_enabled_$index'),
                state: entry.enabled ? CheckboxState.checked : CheckboxState.unchecked,
                onChanged: (s) => vm.setEmitterEnabled(index, s == CheckboxState.checked),
              ),
              const SizedBox(width: 6),
              const Icon(LucideIcons.sparkles, size: 12, color: EditorColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.name,
                  style: TextStyle(
                    fontSize: 10,
                    color: entry.enabled ? EditorColors.foreground : EditorColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _promptRename(int index) {
    final controller = TextEditingController(text: vm.emitters[index].name);
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) => AlertDialog(
      title: const Text('Rename Emitter'),
      content: TextField(controller: controller, key: const ValueKey('particle_rename_field')),
      actions: [
        OutlineButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        PrimaryButton(
          onPressed: () {
            vm.renameEmitter(index, controller.text);
            Navigator.of(context).pop();
          },
          child: const Text('Rename'),
        ),
      ],
      ),
    );
  }

  void _confirmDelete(int index) {
    final name = vm.emitters[index].name;
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) => AlertDialog(
      title: const Text('Delete Emitter'),
      content: Text('Delete "$name" from this particle system?'),
      actions: [
        OutlineButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        DestructiveButton(
          key: const ValueKey('particle_delete_confirm'),
          onPressed: () {
            vm.deleteEmitter(index);
            Navigator.of(context).pop();
          },
          child: const Text('Delete'),
        ),
      ],
      ),
    );
  }
}
