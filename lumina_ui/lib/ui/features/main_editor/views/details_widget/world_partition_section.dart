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
