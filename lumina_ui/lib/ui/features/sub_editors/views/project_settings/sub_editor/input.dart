part of '../../project_settings_sub_editor.dart';

/// Enhanced Input category: mapping contexts and key-capture rows.
mixin _ProjectSettingsInput on _ProjectSettingsSubEditorStateBase {

  // Enhanced Input
  @override
  Widget _buildInput() {
    final input = _vm.project.input;
    final actionNames = input.actions.map((a) => a.name).toList();
    return Column(children: [
      _section('Input Actions', [
        for (var i = 0; i < input.actions.length; i++)
          _row(
            'Input Action',
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  key: ValueKey('project_settings_action_name_$i'),
                  controller: _controllerFor('action_$i', input.actions[i].name),
                  focusNode: _focusFor('action_$i'),
                  onChanged: (v) => _vm.updateAction(i, name: v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _select(
                  input.actions[i].valueType.name,
                  ProjectInputValueType.values.map((v) => v.name).toList(),
                  (v) => _vm.updateAction(i, valueType: ProjectInputValueType.values.firstWhere((t) => t.name == v)),
                  label: (v) => switch (v) { 'axis1D' => 'Axis 1D', 'axis2D' => 'Axis 2D', _ => 'Digital (bool)' },
                ),
              ),
              GhostButton(
                key: ValueKey('project_settings_action_remove_$i'),
                onPressed: () => _vm.removeAction(i),
                child: const Icon(LucideIcons.trash2, size: 12),
              ),
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: GhostButton(
            key: const ValueKey('project_settings_action_add'),
            onPressed: () => _vm.addAction(),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.plus, size: 12),
              SizedBox(width: 4),
              Text('Add Input Action', style: TextStyle(fontSize: 10)),
            ]),
          ),
        ),
      ]),
      _section('Mapping Contexts', [
        for (var c = 0; c < input.mappingContexts.length; c++) _buildMappingContext(c, input.mappingContexts[c], actionNames),
        Align(
          alignment: Alignment.centerLeft,
          child: GhostButton(
            key: const ValueKey('project_settings_context_add'),
            onPressed: () => _vm.addMappingContext(),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.plus, size: 12),
              SizedBox(width: 4),
              Text('Add Mapping Context', style: TextStyle(fontSize: 10)),
            ]),
          ),
        ),
      ]),
    ]);
  }

  Widget _buildMappingContext(int c, ProjectMappingContext ctx, List<String> actionNames) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: EditorColors.background,
        border: Border.all(color: EditorColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              key: ValueKey('project_settings_context_name_$c'),
              controller: _controllerFor('ctx_$c', ctx.name),
              focusNode: _focusFor('ctx_$c'),
              placeholder: const Text('Mapping context name'),
              onChanged: (v) => _vm.updateMappingContext(c, name: v),
            ),
          ),
          const SizedBox(width: 8),
          const Text('Priority', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(width: 4),
          SizedBox(
            width: 56,
            child: TextField(
              key: ValueKey('project_settings_context_priority_$c'),
              controller: _controllerFor('ctxp_$c', ctx.priority.toString()),
              focusNode: _focusFor('ctxp_$c'),
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null) _vm.updateMappingContext(c, priority: n);
              },
            ),
          ),
          GhostButton(onPressed: () => _vm.removeMappingContext(c), child: const Icon(LucideIcons.trash2, size: 12)),
        ]),
        const SizedBox(height: 6),
        for (var m = 0; m < ctx.mappings.length; m++) _buildMappingRow(c, m, ctx.mappings[m], actionNames),
        GhostButton(
          key: ValueKey('project_settings_mapping_add_$c'),
          onPressed: actionNames.isEmpty
              ? null
              : () => _vm.addMapping(c, ProjectInputMapping(action: actionNames.first, keyId: 0, keyLabel: '')),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.plus, size: 12),
            SizedBox(width: 4),
            Text('Add Key Binding', style: TextStyle(fontSize: 10)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildMappingRow(int c, int m, ProjectInputMapping map, List<String> actionNames) {
    final capturing = _capturingContext == c && _capturingMapping == m;
    final action = _vm.project.input.actions.cast<ProjectInputAction?>().firstWhere((a) => a!.name == map.action, orElse: () => null);
    final isAxis = action != null && action.valueType != ProjectInputValueType.digital;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(flex: 3, child: _select(map.action, actionNames, (v) => _vm.updateMapping(c, m, action: v))),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: Focus(
            key: ValueKey('project_settings_key_capture_${c}_$m'),
            focusNode: capturing ? _captureFocus : null,
            onKeyEvent: (node, event) {
              if (!capturing || event is! KeyDownEvent) return KeyEventResult.ignored;
              final key = event.logicalKey;
              if (key == LogicalKeyboardKey.escape) {
                setState(() {
                  _capturingContext = null;
                  _capturingMapping = null;
                });
                return KeyEventResult.handled;
              }
              _vm.updateMapping(c, m, keyId: key.keyId, keyLabel: key.keyLabel.isEmpty ? key.debugName ?? 'Key ${key.keyId}' : key.keyLabel);
              setState(() {
                _capturingContext = null;
                _capturingMapping = null;
              });
              return KeyEventResult.handled;
            },
            child: (capturing ? PrimaryButton.new : OutlineButton.new)(
              onPressed: () {
                setState(() {
                  _capturingContext = c;
                  _capturingMapping = m;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) => _captureFocus.requestFocus());
              },
              child: Text(
                capturing ? 'Press a key…' : (map.keyLabel.isEmpty ? 'Set key' : map.keyLabel),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 60,
          child: TextField(
            key: ValueKey('project_settings_mapping_scale_${c}_$m'),
            controller: _controllerFor('scale_${c}_$m', map.scale.toString()),
            focusNode: _focusFor('scale_${c}_$m'),
            enabled: isAxis,
            onChanged: (v) {
              final d = double.tryParse(v);
              if (d != null) _vm.updateMapping(c, m, scale: d);
            },
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: isAxis
              ? _select(map.axis.isEmpty ? 'X' : map.axis, const ['X', 'Y'], (v) => _vm.updateMapping(c, m, axis: v))
              : const Text('digital', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        ),
        GhostButton(
          key: ValueKey('project_settings_mapping_remove_${c}_$m'),
          onPressed: () => _vm.removeMapping(c, m),
          child: const Icon(LucideIcons.trash2, size: 12),
        ),
      ]),
    );
  }
}
