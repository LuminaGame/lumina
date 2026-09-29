part of '../skeletal_mesh_sub_editor.dart';

/// Left sidebar tab switcher plus the Morph Targets and RigLogic (DNA)
/// panels.
/// flutter_riglogic's DNA test fixture, offered as a one-click sample when the
/// workspace has it (the package lives in the tools repo: found where the
/// workspace resolved it).
final String _sampleDnaPath = [LuminaWorkspace.package('flutter_riglogic'), 'test', 'fixtures', 'sample.dna']
    .join(Platform.pathSeparator);

mixin _SkeletalMeshLeftSidebar on _SkeletalMeshSubEditorStateBase {

  Widget _buildLeftSidebar() {
    return Column(
      children: [
        // Tabs Header (Skeleton Tree / Morph Targets / RigLogic)
        Container(
          padding: const EdgeInsets.all(6),
          color: EditorColors.card,
          child: Row(
            children: [
              Expanded(
                child: GhostButton(
                  size: ButtonSize.small,
                  onPressed: () => setState(() => _activeLeftTab = 0),
                  child: Text(
                    'Skeleton (${_viewModel.boneCount})',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: _activeLeftTab == 0 ? FontWeight.bold : FontWeight.normal,
                      color: _activeLeftTab == 0 ? Colors.purple : EditorColors.mutedForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: GhostButton(
                  size: ButtonSize.small,
                  onPressed: () => setState(() => _activeLeftTab = 1),
                  child: Text(
                    'Morphs (${_viewModel.morphTargets.length})',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: _activeLeftTab == 1 ? FontWeight.bold : FontWeight.normal,
                      color: _activeLeftTab == 1 ? Colors.cyan : EditorColors.mutedForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: GhostButton(
                  size: ButtonSize.small,
                  onPressed: () => setState(() => _activeLeftTab = 2),
                  child: Text(
                    _viewModel.hasRigLogic ? 'RigLogic ✓' : 'RigLogic',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: _activeLeftTab == 2 ? FontWeight.bold : FontWeight.normal,
                      color: _activeLeftTab == 2 ? Colors.blue : (_viewModel.hasRigLogic ? Colors.blue.withOpacity(0.8) : EditorColors.mutedForeground),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _activeLeftTab == 0
              ? _buildBoneTreePanel()
              : (_activeLeftTab == 1 ? _buildMorphTargetsPanel() : _buildRigLogicPanel()),
        ),
      ],
    );
  }

  Widget _buildMorphTargetsPanel() {
    final vm = _viewModel;
    final morphs = vm.morphTargets;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: EditorColors.card,
          child: Row(
            children: [
              const Icon(LucideIcons.slidersHorizontal, size: 12, color: Colors.cyan),
              const SizedBox(width: 6),
              const Text('MORPH TARGETS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyan)),
              const Spacer(),
              if (morphs.isNotEmpty)
                GhostButton(
                  size: ButtonSize.small,
                  onPressed: vm.resetMorphs,
                  child: const Text('Reset All', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: morphs.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No morph targets in this mesh',
                      style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: morphs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final target = morphs[index];
                    final weight = vm.morphWeights[target.name] ?? 0.0;
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EditorColors.card,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: weight > 0 ? Colors.cyan.withValues(alpha: 0.3) : EditorColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  target.name,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: weight > 0 ? FontWeight.bold : FontWeight.normal,
                                    color: weight > 0 ? Colors.cyan : EditorColors.foreground,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SliderField(
                            key: ValueKey('skeletal_morph_${target.name}'),
                            value: weight,
                            defaultValue: 0.0,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (v) => vm.setMorphWeight(target.name, v),
                            onCommit: (v) => vm.setMorphWeight(target.name, v),
                            onReset: () => vm.setMorphWeight(target.name, 0.0),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRigLogicPanel() {
    final vm = _viewModel;

    if (!vm.hasRigLogic) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: EditorColors.card,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.dna, size: 32, color: Colors.blue),
              ),
              const SizedBox(height: 12),
              const Text(
                'MetaHuman RigLogic DNA',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground),
              ),
              const SizedBox(height: 6),
              const Text(
                'Load a MetaHuman or character .dna file to evaluate facial expressions, bone deltas, and live blend shapes in real-time.',
                style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                size: ButtonSize.small,
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['dna'],
                  );
                  if (result != null && result.files.single.path != null) {
                    await vm.loadDnaFile(result.files.single.path!);
                  }
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.upload, size: 12),
                    SizedBox(width: 6),
                    Text('Load .DNA File...'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (File(_sampleDnaPath).existsSync())
                GhostButton(
                  size: ButtonSize.small,
                  onPressed: () async {
                    await vm.loadDnaFile(_sampleDnaPath);
                  },
                  child: const Text('Load Sample DNA Fixture', style: TextStyle(fontSize: 10, color: Colors.blue)),
                ),
            ],
          ),
        ),
      );
    }

    final evaluator = vm.rigLogic!;
    final controlNames = vm.rigLogicControlNames.where((name) {
      if (_dnaControlSearchFilter.isEmpty) return true;
      return name.toLowerCase().contains(_dnaControlSearchFilter.toLowerCase());
    }).toList();

    return Column(
      children: [
        // RigLogic Header & Stats
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: EditorColors.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.dna, size: 12, color: Colors.blue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'RIGLOGIC: ${evaluator.characterName.toUpperCase()}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GhostButton(
                    size: ButtonSize.small,
                    onPressed: () => vm.resetRigLogicControls(),
                    child: const Icon(LucideIcons.rotateCcw, size: 12, color: EditorColors.mutedForeground),
                  ),
                  const SizedBox(width: 4),
                  GhostButton(
                    size: ButtonSize.small,
                    onPressed: () => vm.unloadDna(),
                    child: const Icon(LucideIcons.x, size: 12, color: EditorColors.logError),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildDnaBadge('Joints', '${evaluator.jointCount}'),
                  _buildDnaBadge('Morphs', '${evaluator.blendShapeCount}'),
                  _buildDnaBadge('Controls', '${evaluator.rawControlCount}'),
                  _buildDnaBadge('Wrinkles', '${evaluator.animatedMapCount}'),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                placeholder: const Text('Search facial controls...'),
                onChanged: (val) => setState(() => _dnaControlSearchFilter = val),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Controls Sliders
        Expanded(
          child: controlNames.isEmpty
              ? const Center(
                  child: Text('No controls match filter', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: controlNames.length,
                  itemBuilder: (context, index) {
                    final name = controlNames[index];
                    final val = vm.rigLogicControlValues[name] ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: val > 0.0 ? FontWeight.bold : FontWeight.normal,
                                    color: val > 0.0 ? Colors.blue : EditorColors.foreground,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SliderField(
                            key: ValueKey('skeletal_riglogic_$name'),
                            value: val,
                            defaultValue: 0.0,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (v) => vm.setRigLogicControl(name, v),
                            onCommit: (v) => vm.setRigLogicControl(name, v),
                            onReset: () => vm.setRigLogicControl(name, 0.0),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDnaBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: EditorColors.input,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border, width: 0.5),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
      ),
    );
  }
}
