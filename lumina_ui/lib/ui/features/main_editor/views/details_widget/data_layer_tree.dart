part of '../details_widget.dart';

/// The level's data layers as a tree with the World Outliner's rows: a
/// chevron on layers with children, two toggles (starts loaded, starts
/// ticking), the layer icon, the name, the initial-state badge and the
/// child count. Layers nest by drag and drop or the context menu, rename on
/// double-click, and the box is at most 200 px tall so long lists scroll.
class _DataLayerTree extends StatefulWidget {
  const _DataLayerTree({required this.vm});

  final EditorViewModel vm;

  static const double maxHeight = 200;

  @override
  State<_DataLayerTree> createState() => _DataLayerTreeState();
}

class _DataLayerTreeState extends State<_DataLayerTree> {
  static const _states = ['unloaded', 'loaded', 'activated'];
  static const _stateHelp = {
    'unloaded': 'not in the world until a streaming source or script loads it',
    'loaded': 'in the world, not ticking until activated',
    'activated': 'in the world and ticking from the start',
  };

  EditorViewModel get vm => widget.vm;

  String? _editing;
  bool _renameHadFocus = false;
  final _renameController = TextEditingController();
  final _renameFocus = FocusNode();
  String? _lastTapName;
  DateTime? _lastTapAt;
  String? _hovered;

  @override
  void initState() {
    super.initState();
    _renameFocus.addListener(_onRenameFocusChanged);
  }

  @override
  void dispose() {
    _renameFocus.removeListener(_onRenameFocusChanged);
    _renameController.dispose();
    _renameFocus.dispose();
    super.dispose();
  }

  void _onRenameFocusChanged() {
    if (_renameFocus.hasFocus) {
      _renameHadFocus = true;
    } else if (_renameHadFocus && _editing != null) {
      _commitRename();
    }
  }

  void _startRename(String name) {
    setState(() {
      _editing = name;
      _renameHadFocus = false;
      _renameController.text = name;
      _renameController.selection = TextSelection(baseOffset: 0, extentOffset: name.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing == name) _renameFocus.requestFocus();
    });
  }

  void _commitRename() {
    final old = _editing;
    if (old == null) return;
    final name = _renameController.text.trim();
    final index = _indexOf(old);
    if (name.isNotEmpty && name != old && index >= 0 && _indexOf(name) < 0) {
      vm.setWorldPartitionDataLayerName(index, name);
    }
    setState(() => _editing = null);
  }

  void _cancelRename() {
    _renameHadFocus = false;
    setState(() => _editing = null);
  }

  int _indexOf(String name) => vm.worldPartitionDataLayers.indexWhere((l) => l['name'] == name);

  bool _isUnder(String name, String ancestor) {
    final byName = {for (final l in vm.worldPartitionDataLayers) (l['name'] ?? '').toString(): l};
    var parent = byName[name]?['parent'];
    var guard = 0;
    while (parent is String && parent.isNotEmpty && ++guard < 64) {
      if (parent == ancestor) return true;
      parent = byName[parent]?['parent'];
    }
    return false;
  }

  /// Whether [dragged] may become a child of [target].
  bool _canDrop(String dragged, String target) => dragged != target && !_isUnder(target, dragged);

  @override
  Widget build(BuildContext context) {
    final layers = vm.worldPartitionDataLayers;
    final rows = vm.worldPartitionDataLayerRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('wp_layers_list'),
          constraints: const BoxConstraints(maxHeight: _DataLayerTree.maxHeight),
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
          'Initial state: ${_stateHelp.entries.map((e) => '${e.key} = ${e.value}').join(' · ')}. '
          'Double-click renames; drag a layer onto another to nest it.',
          style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }

  Widget _row(({int index, int depth, bool hasChildren}) row, Map<String, dynamic> layer) {
    final i = row.index;
    final name = (layer['name'] ?? '').toString();
    return Draggable<String>(
      data: name,
      maxSimultaneousDrags: _editing == name ? 0 : 1,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: EditorColors.primary,
        child: Text(name, style: const TextStyle(fontSize: 10, color: EditorColors.accentForeground)),
      ),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (d) => _canDrop(d.data, name),
        onAcceptWithDetails: (d) => vm.setWorldPartitionDataLayerParent(_indexOf(d.data), name),
        builder: (context, candidates, _) => EditorContextMenu(
          items: _menu(i, name, row.hasChildren),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = name),
            onExit: (_) => setState(() => _hovered = null),
            child: GestureDetector(
              key: ValueKey('wp_layer_row_$i'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _tap(name),
              child: _rowContent(row, layer, isDropTarget: candidates.isNotEmpty),
            ),
          ),
        ),
      ),
    );
  }

  /// A second click on the selected row within the double-tap timeout
  /// renames it; otherwise the click selects.
  void _tap(String name) {
    final now = DateTime.now();
    final isDouble = _lastTapName == name && _lastTapAt != null && now.difference(_lastTapAt!) <= kDoubleTapTimeout;
    _lastTapName = isDouble ? null : name;
    _lastTapAt = isDouble ? null : now;
    if (isDouble) {
      _startRename(name);
      return;
    }
    vm.selectWorldPartitionDataLayer(name);
  }

  Widget _rowContent(({int index, int depth, bool hasChildren}) row, Map<String, dynamic> layer,
      {required bool isDropTarget}) {
    final i = row.index;
    final name = (layer['name'] ?? '').toString();
    final state = (layer['initialState'] ?? 'unloaded').toString();
    final startsLoaded = state != 'unloaded';
    final startsTicking = state == 'activated';
    final isSelected = vm.selectedWorldPartitionDataLayer == name;
    final isEditing = _editing == name;
    final expanded = vm.isWorldPartitionDataLayerExpanded(name);
    final childCount = vm.worldPartitionDataLayers.where((l) => l['parent'] == name).length;

    return Container(
      height: EditorDensity.rowHeight,
      padding: EdgeInsets.only(
        left: EditorDensity.gutter + row.depth * EditorDensity.indentStep,
        right: EditorDensity.gutter,
      ),
      decoration: BoxDecoration(
        color: isDropTarget
            ? EditorColors.primary.withValues(alpha: 0.18)
            : isSelected
                ? EditorColors.selectionBg
                : _hovered == name
                    ? EditorColors.rowHover
                    : Colors.transparent,
        border: isDropTarget
            ? Border.all(color: EditorColors.primary, width: 1)
            : isSelected
                ? const Border(left: BorderSide(color: EditorColors.primary, width: EditorDensity.selectionBarWidth))
                : null,
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
          // Starts loaded (eye) — unloaded layers wait for a source or script.
          Tooltip(
            tooltip: (context) => TooltipContainer(
              child: Text(startsLoaded ? 'Starts loaded. Click: start unloaded.' : 'Starts unloaded. Click: start loaded.'),
            ),
            child: GhostButton(
              key: ValueKey('wp_layer_eye_$i'),
              density: ButtonDensity.compact,
              onPressed: () => vm.setWorldPartitionDataLayerState(i, startsLoaded ? 'unloaded' : 'loaded'),
              child: Icon(
                startsLoaded ? LucideIcons.eye : LucideIcons.eyeOff,
                size: 11,
                color: startsLoaded ? EditorColors.mutedForeground : EditorColors.destructive,
              ),
            ),
          ),
          // Starts ticking (activated).
          Tooltip(
            tooltip: (context) => TooltipContainer(
              child: Text(startsTicking ? 'Starts activated (ticking). Click: loaded only.' : 'Click: start activated (ticking).'),
            ),
            child: GhostButton(
              key: ValueKey('wp_layer_tick_$i'),
              density: ButtonDensity.compact,
              onPressed: () => vm.setWorldPartitionDataLayerState(i, startsTicking ? 'loaded' : 'activated'),
              child: Icon(
                startsTicking ? LucideIcons.zap : LucideIcons.zapOff,
                size: 11,
                color: startsTicking ? EditorColors.warning : EditorColors.border,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(LucideIcons.layers, size: 12, color: row.depth == 0 ? EditorColors.primary : EditorColors.mutedForeground),
          const SizedBox(width: 6),
          Expanded(
            child: isEditing
                ? SizedBox(
                    height: 18,
                    child: CallbackShortcuts(
                      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancelRename},
                      child: TextField(
                        key: const ValueKey('wp_layer_rename_field'),
                        controller: _renameController,
                        focusNode: _renameFocus,
                        style: const TextStyle(fontSize: 10, color: EditorColors.foreground),
                        onSubmitted: (_) {
                          _renameHadFocus = false;
                          _commitRename();
                        },
                      ),
                    ),
                  )
                : Text(
                    name,
                    key: ValueKey('wp_layer_name_$i'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? EditorColors.primary
                          : startsLoaded
                              ? EditorColors.foreground
                              : EditorColors.mutedForeground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          Tooltip(
            tooltip: (context) => TooltipContainer(child: Text('Initial state: ${_stateHelp[state] ?? state}')),
            child: Container(
              key: ValueKey('wp_layer_state_$i'),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: EditorColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(state, style: const TextStyle(fontSize: 8, color: EditorColors.primary)),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            row.hasChildren ? '$childCount' : 'Layer',
            style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
          ),
        ],
      ),
    );
  }

  List<MenuItem> _menu(int i, String name, bool hasChildren) {
    final layers = vm.worldPartitionDataLayers;
    final current = (layers[i]['initialState'] ?? 'unloaded').toString();
    final parent = layers[i]['parent'];
    final targets = [
      for (final l in layers)
        if (_canDrop(name, (l['name'] ?? '').toString())) (l['name'] ?? '').toString(),
    ];
    return [
      MenuButton(
        key: ValueKey('wp_layer_menu_rename_$i'),
        leading: const Icon(LucideIcons.pencil, size: 14),
        onPressed: (ctx) => _startRename(name),
        child: const Text('Rename', style: TextStyle(fontSize: 10)),
      ),
      MenuButton(
        key: ValueKey('wp_layer_menu_add_child_$i'),
        leading: const Icon(LucideIcons.plus, size: 14),
        onPressed: (ctx) => vm.addWorldPartitionDataLayer('DataLayer', name),
        child: const Text('Add Child Layer', style: TextStyle(fontSize: 10)),
      ),
      MenuButton(
        leading: const Icon(LucideIcons.power, size: 14),
        subMenu: [
          for (final s in _states)
            MenuButton(
              key: ValueKey('wp_layer_menu_state_${i}_$s'),
              leading: Icon(s == current ? LucideIcons.check : LucideIcons.circle, size: 12),
              onPressed: (ctx) => vm.setWorldPartitionDataLayerState(i, s),
              child: Text('$s — ${_stateHelp[s]}', style: const TextStyle(fontSize: 10)),
            ),
        ],
        child: const Text('Initial State', style: TextStyle(fontSize: 10)),
      ),
      MenuButton(
        leading: const Icon(LucideIcons.folderInput, size: 14),
        subMenu: [
          MenuButton(
            key: ValueKey('wp_layer_menu_move_root_$i'),
            enabled: parent != null,
            onPressed: (ctx) => vm.setWorldPartitionDataLayerParent(i, null),
            child: const Text('Top level', style: TextStyle(fontSize: 10)),
          ),
          for (final t in targets)
            MenuButton(
              enabled: t != parent,
              onPressed: (ctx) => vm.setWorldPartitionDataLayerParent(i, t),
              child: Text(t, style: const TextStyle(fontSize: 10)),
            ),
        ],
        child: const Text('Move Under', style: TextStyle(fontSize: 10)),
      ),
      const MenuDivider(),
      MenuButton(
        key: ValueKey('wp_layer_menu_remove_$i'),
        leading: const Icon(LucideIcons.trash2, size: 14, color: EditorColors.destructive),
        onPressed: (ctx) => vm.removeWorldPartitionDataLayer(i),
        child: Text(
          hasChildren ? 'Remove Layer and Children' : 'Remove Layer',
          style: const TextStyle(fontSize: 10, color: EditorColors.destructive),
        ),
      ),
    ];
  }
}
