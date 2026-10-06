part of '../details_widget.dart';

/// The level's World Partition settings in the Details panel: the switch, the
/// grid and streaming numbers with what each one means, and the data layers
/// with their initial state. Authoring only: the generated game and Play run
/// `LuminaWorldPartitionSubsystem` with these values; the editor never
/// unloads cells while editing.
class _WorldPartitionSection extends StatelessWidget {
  const _WorldPartitionSection({required this.vm});

  final EditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final enabled = vm.worldPartitionEnabled;
    final layers = vm.worldPartitionDataLayers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CategoryHeader(title: 'WORLD PARTITION'),
        Container(
          color: EditorColors.background,
          padding: const EdgeInsets.all(EditorDensity.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          enabled ? 'Streaming on' : 'Streaming off',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          enabled
                              ? 'The game splits this level into grid cells and loads the ones around its streaming sources (the player start, cameras). Each actor belongs to the cell under its position; the outliner shows it.'
                              : 'The whole level loads at once. Turn this on for large worlds so the game streams cells around the player.',
                          style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    key: const ValueKey('wp_enabled'),
                    value: enabled,
                    onChanged: vm.setWorldPartitionEnabled,
                  ),
                ],
              ),
              if (enabled) ...[
                const SizedBox(height: 10),
                const _WpGroupLabel('GRID'),
                const SizedBox(height: 4),
                ScrubNumericField(
                  key: const ValueKey('wp_cell_size'),
                  label: 'Cell Size',
                  labelWidth: 110,
                  unit: 'cm',
                  value: vm.worldPartitionCellSize,
                  defaultValue: kWorldPartitionDefaultCellSize,
                  min: 1,
                  onChanged: (v) => vm.setWorldPartitionCellSize(v, commit: false),
                  onCommit: (v) => vm.setWorldPartitionCellSize(v),
                  onReset: () => vm.setWorldPartitionCellSize(kWorldPartitionDefaultCellSize),
                ),
                _WpHelp('${_metres(vm.worldPartitionCellSize)} per cell edge. Smaller cells stream finer but change state more often.'),
                const SizedBox(height: 8),
                const _WpGroupLabel('STREAMING'),
                const SizedBox(height: 4),
                ScrubNumericField(
                  key: const ValueKey('wp_loading_range'),
                  label: 'Loading Range',
                  labelWidth: 110,
                  unit: 'cm',
                  value: vm.worldPartitionLoadingRange,
                  defaultValue: kWorldPartitionDefaultLoadingRange,
                  min: 0,
                  onChanged: (v) => vm.setWorldPartitionLoadingRange(v, commit: false),
                  onCommit: (v) => vm.setWorldPartitionLoadingRange(v),
                  onReset: () => vm.setWorldPartitionLoadingRange(kWorldPartitionDefaultLoadingRange),
                ),
                _WpHelp(
                  'Cells within ${_metres(vm.worldPartitionLoadingRange)} of a streaming source load; '
                  '${_cellsAcross(vm.worldPartitionLoadingRange, vm.worldPartitionCellSize)} cells across at this cell size.',
                ),
                const SizedBox(height: 4),
                ScrubNumericField(
                  key: const ValueKey('wp_max_transitions'),
                  label: 'Transitions / Tick',
                  labelWidth: 110,
                  value: vm.worldPartitionMaxCellTransitionsPerTick.toDouble(),
                  defaultValue: kWorldPartitionDefaultMaxCellTransitionsPerTick.toDouble(),
                  min: 1,
                  fractionDigits: 0,
                  onChanged: (v) => vm.setWorldPartitionMaxCellTransitionsPerTick(v.round(), commit: false),
                  onCommit: (v) => vm.setWorldPartitionMaxCellTransitionsPerTick(v.round()),
                  onReset: () => vm.setWorldPartitionMaxCellTransitionsPerTick(kWorldPartitionDefaultMaxCellTransitionsPerTick),
                ),
                const _WpHelp('How many cells may load, activate or unload in one frame. Lower spreads the work out; higher reacts faster.'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const _WpGroupLabel('DATA LAYERS'),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: EditorColors.muted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${layers.length}', style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                    ),
                    const Spacer(),
                    OutlineButton(
                      key: const ValueKey('wp_add_layer'),
                      size: ButtonSize.small,
                      onPressed: () => vm.addWorldPartitionDataLayer(),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.plus, size: 12, color: EditorColors.primary),
                          SizedBox(width: 4),
                          Text('Add', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const _WpHelp('Named groups of actors with their own initial state, on top of the cell they are in. '
                    'Nest layers to organise them like outliner folders.'),
                const SizedBox(height: 6),
                _DataLayerTree(vm: vm),
              ],
              const SizedBox(height: 10),
              const _WpHelp(
                'Authoring only: the editor shows the whole level while editing. The generated game and Play in Editor '
                'stream with these values.',
                italic: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _metres(double cm) {
    final m = cm / 100.0;
    return m >= 10 ? '${m.round()} m' : '${m.toStringAsFixed(1)} m';
  }

  static String _cellsAcross(double range, double cellSize) {
    if (cellSize <= 0) return '?';
    final n = (range * 2 / cellSize).ceil();
    return n <= 0 ? '0' : '$n';
  }
}

class _WpGroupLabel extends StatelessWidget {
  const _WpGroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: EditorColors.primary),
      );
}

class _WpHelp extends StatelessWidget {
  const _WpHelp(this.text, {this.italic = false});

  final String text;
  final bool italic;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            color: EditorColors.mutedForeground,
          ),
        ),
      );
}

/// The data layers as a tree, in the outliner's row style: indentation per
/// depth, a chevron on layers with children, the name (editable), the initial
/// state and the row's actions. At most 200 px tall; longer lists scroll.
class _DataLayerTree extends StatelessWidget {
  const _DataLayerTree({required this.vm});

  final EditorViewModel vm;

  static const double maxHeight = 200;

  static const _stateHelp = {
    'unloaded': 'not in the world until a streaming source or script loads it',
    'loaded': 'in the world, not ticking until activated',
    'activated': 'in the world and ticking from the start',
  };

  @override
  Widget build(BuildContext context) {
    final layers = vm.worldPartitionDataLayers;
    final rows = vm.worldPartitionDataLayerRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('wp_layers_list'),
          constraints: const BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: EditorColors.sidebar,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: EditorColors.border),
          ),
          child: layers.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    'No data layers yet. Everything follows its cell.',
                    style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: EditorColors.mutedForeground),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  itemCount: rows.length,
                  itemExtent: EditorDensity.rowHeight,
                  itemBuilder: (context, r) => _row(rows[r], layers[rows[r].index]),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          'Initial state: ${_stateHelp.entries.map((e) => '${e.key} = ${e.value}').join(' · ')}.',
          style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }

  Widget _row(({int index, int depth, bool hasChildren}) row, Map<String, dynamic> layer) {
    final i = row.index;
    final name = (layer['name'] ?? '').toString();
    final state = (layer['initialState'] ?? 'unloaded').toString();
    final expanded = vm.isWorldPartitionDataLayerExpanded(name);
    return _HoverRow(
      child: Padding(
        padding: EdgeInsets.only(
          left: EditorDensity.gutter + row.depth * EditorDensity.indentStep,
          right: 2,
        ),
        child: Row(
          children: [
            if (row.hasChildren)
              GestureDetector(
                key: ValueKey('wp_layer_chevron_$i'),
                behavior: HitTestBehavior.opaque,
                onTap: () => vm.toggleWorldPartitionDataLayerExpanded(name),
                child: Icon(
                  expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                  size: 14,
                  color: EditorColors.mutedForeground,
                ),
              )
            else
              const SizedBox(width: 14),
            const SizedBox(width: 4),
            Icon(LucideIcons.layers, size: 12, color: row.depth == 0 ? EditorColors.primary : EditorColors.mutedForeground),
            const SizedBox(width: 6),
            Expanded(
              flex: 5,
              child: SizedBox(
                height: EditorDensity.inlineFieldHeight,
                child: TextField(
                  key: ValueKey('wp_layer_name_$i'),
                  initialValue: name,
                  placeholder: const Text('Layer name'),
                  style: const TextStyle(fontSize: 10),
                  onSubmitted: (v) => vm.setWorldPartitionDataLayerName(i, v),
                  onEditingComplete: () {},
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 4,
              child: Tooltip(
                tooltip: (context) => TooltipContainer(child: Text('Starts $state: ${_stateHelp[state] ?? ''}')),
                child: EnumField(
                  key: ValueKey('wp_layer_state_$i'),
                  value: state,
                  enumValues: const ['unloaded', 'loaded', 'activated'],
                  isRadioGroup: false,
                  onCommit: (v) => vm.setWorldPartitionDataLayerState(i, v),
                ),
              ),
            ),
            Tooltip(
              tooltip: (context) => const TooltipContainer(child: Text('Add a layer under this one')),
              child: IconButton.ghost(
                key: ValueKey('wp_layer_add_child_$i'),
                icon: const Icon(LucideIcons.plus, size: 12, color: EditorColors.mutedForeground),
                onPressed: () => vm.addWorldPartitionDataLayer('DataLayer', name),
              ),
            ),
            Tooltip(
              tooltip: (context) => const TooltipContainer(child: Text('Remove this layer and the layers under it')),
              child: IconButton.ghost(
                key: ValueKey('wp_layer_remove_$i'),
                icon: const Icon(LucideIcons.trash2, size: 12, color: EditorColors.mutedForeground),
                onPressed: () => vm.removeWorldPartitionDataLayer(i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row that lights up under the pointer like the outliner's rows.
class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child});

  final Widget child;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: ColoredBox(
        color: _hover ? EditorColors.rowHover : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}
