part of '../navigation_sub_editor.dart';

// ---------------------------------------------------------------------------
// Right panel: Agent / Grid Generation / Build
// ---------------------------------------------------------------------------

class _RightPanel extends StatelessWidget {
  final NavigationEditorViewModel vm;
  final TextEditingController maskController;
  final FocusNode maskFocus;
  const _RightPanel({required this.vm, required this.maskController, required this.maskFocus});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EditorColors.cardHeader,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Text('AGENT & GRID', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Accordion(
                items: [
                  AccordionItem(
                    expanded: true,
                    trigger: const AccordionTrigger(child: Text('Agent', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                    content: _agentSection(),
                  ),
                  AccordionItem(
                    expanded: true,
                    trigger: const AccordionTrigger(child: Text('Grid Generation', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                    content: _gridSection(),
                  ),
                  AccordionItem(
                    expanded: true,
                    trigger: const AccordionTrigger(child: Text('Build', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                    content: _buildSection(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Text(text, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
      );

  Widget _agentSection() {
    final c = vm.config;
    final d = NavigationEditorConfig.defaults();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Agent Radius (cm) — inflates every obstacle at bake time'),
        KeyedSubtree(
          key: const ValueKey('nav_agent_radius'),
          child: SliderField(
            value: c.agentRadius,
            defaultValue: d.agentRadius,
            min: 0.0,
            max: 200.0,
            unit: 'cm',
            onChanged: (v) => vm.setAgentRadius(v, commit: false),
            onCommit: vm.setAgentRadius,
            onReset: () => vm.setAgentRadius(d.agentRadius),
          ),
        ),
        _label('Agent Height (cm) — geometry above this is overhead'),
        KeyedSubtree(
          key: const ValueKey('nav_agent_height'),
          child: SliderField(
            value: c.agentHeight,
            defaultValue: d.agentHeight,
            min: 50.0,
            max: 400.0,
            unit: 'cm',
            onChanged: (v) => vm.setAgentHeight(v, commit: false),
            onCommit: vm.setAgentHeight,
            onReset: () => vm.setAgentHeight(d.agentHeight),
          ),
        ),
        _label('Max Step Height (cm) — geometry below this is floor'),
        KeyedSubtree(
          key: const ValueKey('nav_step_height'),
          child: SliderField(
            value: c.maxStepHeight,
            defaultValue: d.maxStepHeight,
            min: 0.0,
            max: 150.0,
            unit: 'cm',
            onChanged: (v) => vm.setMaxStepHeight(v, commit: false),
            onCommit: vm.setMaxStepHeight,
            onReset: () => vm.setMaxStepHeight(d.maxStepHeight),
          ),
        ),
      ],
    );
  }

  Widget _gridSection() {
    final c = vm.config;
    final d = NavigationEditorConfig.defaults();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(
          'Cell Size (cm, ${NavigationEditorViewModel.formatCm(NavigationEditorConfig.minCellSize)}–'
          '${NavigationEditorViewModel.formatCm(NavigationEditorConfig.maxCellSize)})',
        ),
        KeyedSubtree(
          key: const ValueKey('nav_cell_size'),
          child: SliderField(
            value: c.cellSize,
            defaultValue: d.cellSize,
            min: NavigationEditorConfig.minCellSize,
            max: NavigationEditorConfig.maxCellSize,
            unit: 'cm',
            onChanged: (v) => vm.setCellSize(v, commit: false),
            onCommit: vm.setCellSize,
            onReset: () => vm.setCellSize(d.cellSize),
          ),
        ),
        _label('Walkable Layer Mask (hex)'),
        TextField(
          key: const ValueKey('nav_layer_mask'),
          controller: maskController,
          focusNode: maskFocus,
          style: const TextStyle(fontSize: 9.5),
          onSubmitted: (text) {
            if (!vm.setWalkableLayerMaskText(text)) {
              maskController.text = vm.walkableLayerMaskHex;
            }
          },
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Backend: uniform walkable grid rasterized from collision AABBs, 8-connected A* with string pulling. '
            'No Recast tiles, polygons, area costs or nav links exist in the engine.',
            style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context) {
    final can = vm.canBuild;
    final button = PrimaryButton(
      key: const ValueKey('nav_build'),
      onPressed: can ? () => vm.build() : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.hammer, size: 11),
          const SizedBox(width: 4),
          Text(vm.isBuilding ? 'Building…' : 'Build Navigation', style: const TextStyle(fontSize: 9)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        can ? button : Tooltip(tooltip: (ctx) => TooltipContainer(child: Text(vm.buildDisabledReason)), child: button),
        if (!can)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(vm.buildDisabledReason, key: const ValueKey('nav_build_reason'), style: const TextStyle(fontSize: 8.5, color: EditorColors.logWarning)),
          ),
        const SizedBox(height: 6),
        Text(vm.lastBuildLabel, key: const ValueKey('nav_last_build'), style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
        if (vm.isStale)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: OutlineBadge(child: Text('Stale — scene or settings changed', style: TextStyle(fontSize: 8))),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Switch(
              key: const ValueKey('nav_auto_rebuild'),
              value: vm.config.autoRebuild,
              onChanged: vm.setAutoRebuild,
            ),
            const SizedBox(width: 8),
            const Expanded(child: Text('Auto-rebuild on change (500 ms debounce)', style: TextStyle(fontSize: 9))),
          ],
        ),
      ],
    );
  }
}
