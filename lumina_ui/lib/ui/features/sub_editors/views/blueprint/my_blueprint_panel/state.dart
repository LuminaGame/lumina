part of '../my_blueprint_panel.dart';

/// State shared by the My Blueprint panel's section mixins: the rename and
/// element-search fields and the helpers (menus, headers, rows) they share.
abstract class _BlueprintMyBlueprintPanelStateBase extends State<BlueprintMyBlueprintPanel> {
  /// Which list a rename is in: `var`, `fn`, `macro`, `dispatcher`, `local`.
  String _renamingKind = 'var';
  String? _renaming;
  final TextEditingController _renameController = TextEditingController();
  String? _renameError;
  final TextEditingController _elementSearch = TextEditingController();
  String _elementQuery = '';

  @override
  void dispose() {
    _renameController.dispose();
    _elementSearch.dispose();
    super.dispose();
  }

  /// The elements of the selected widget variable's class matching the
  /// search, or null when the selection is not a widget variable.
  List<LuminaBlueprintWidgetElement>? get visibleElements {
    final v = widget.variables.where((v) => v.name == widget.selected).firstOrNull;
    final cls = v?.objectClass;
    if (cls == null || LuminaBlueprintObjectClass.kind(cls) != LuminaBlueprintObjectClass.widgetKind) return null;
    final w = widget.context.widgetClass(LuminaBlueprintObjectClass.name(cls));
    if (w == null) return null;
    final q = _elementQuery.toLowerCase();
    return [
      for (final e in w.elements)
        if (q.isEmpty ||
            e.name.toLowerCase().contains(q) ||
            LuminaBlueprintObjectClass.displayName(e.objectClass).toLowerCase().contains(q))
          e,
    ];
  }

  /// Starts renaming [name] in place.
  void beginRename(String name, {String kind = 'var'}) {
    setState(() {
      _renamingKind = kind;
      _renaming = name;
      _renameError = null;
      _renameController.text = name;
    });
  }

  bool _rename(String old, String next) {
    final sections = widget.sections;
    return switch (_renamingKind) {
      'fn' => sections?.functionActions.onRename(old, next) ?? false,
      'macro' => sections?.macroActions.onRename(old, next) ?? false,
      'dispatcher' => sections?.dispatcherActions.onRename(old, next) ?? false,
      'local' => sections?.onRenameLocal?.call(old, next) ?? false,
      _ => widget.onRename(old, next),
    };
  }

  void _commitRename() {
    final old = _renaming;
    if (old == null) return;
    final next = _renameController.text.trim();
    if (next == old) {
      setState(() => _renaming = null);
      return;
    }
    if (_rename(old, next)) {
      setState(() => _renaming = null);
    } else {
      setState(() => _renameError = 'Not a valid, unused name');
    }
  }

  void _confirmDelete(String name, {String kind = 'var', String noun = 'variable', int? uses, ValueChanged<String>? onDelete}) {
    final count = uses ?? widget.usageCount(name);
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $noun $name?'),
        content: Text(count == 0
            ? 'No node uses it.'
            : '$count node${count == 1 ? '' : 's'} use${count == 1 ? 's' : ''} it and will be removed from the graph.'),
        actions: [
          GhostButton(onPressed: () => closeOverlay(dialogContext), child: const Text('Cancel')),
          DestructiveButton(
            key: ValueKey('${kind}_delete_confirm'),
            onPressed: () {
              closeOverlay(dialogContext);
              (onDelete ?? widget.onDelete)(name);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _menu(String name, Offset global, {String kind = 'var', String noun = 'variable', int? uses, ValueChanged<String>? onDelete}) {
    showDropdown(
      context: context,
      // An explicit position is where the menu opens; following the
      // anchor widget would drag it to that widget's bottom centre.
      follow: false,
      // Top-left corner at the point, as editor context menus open.
      alignment: Alignment.topLeft,
      anchorAlignment: Alignment.topLeft,
      position: global,
      builder: (context) => DropdownMenu(
        children: [
          MenuButton(
            key: ValueKey('${kind}_menu_rename'),
            leading: const Icon(LucideIcons.pencil, size: 12),
            child: const Text('Rename', style: TextStyle(fontSize: 10)),
            onPressed: (ctx) => beginRename(name, kind: kind),
          ),
          MenuButton(
            key: ValueKey('${kind}_menu_delete'),
            leading: const Icon(LucideIcons.trash2, size: 12),
            child: const Text('Delete', style: TextStyle(fontSize: 10)),
            onPressed: (ctx) => _confirmDelete(name, kind: kind, noun: noun, uses: uses, onDelete: onDelete),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, {VoidCallback? onAdd, String? addKey}) => Row(
        children: [
          Icon(icon, size: 12, color: EditorColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(title, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          ),
          if (onAdd != null)
            GhostButton(
              key: ValueKey(addKey ?? 'add_$title'),
              size: ButtonSize.small,
              onPressed: onAdd,
              child: const Icon(LucideIcons.plus, size: 12),
            ),
        ],
      );

  Widget _renameField() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('var_rename_field'),
              controller: _renameController,
              autofocus: true,
              style: const TextStyle(fontSize: 10),
              onSubmitted: (_) => _commitRename(),
            ),
            if (_renameError != null) Text(_renameError!, style: const TextStyle(fontSize: 8, color: EditorColors.destructive)),
          ],
        ),
      );


  /// The coloured type pill: a menu of the type groups.
  Widget _typeChip({required Key key, required String typeName, required ValueChanged<String> onPick}) {
    final color = BlueprintPinStyle.color(LuminaPinType.parseVariableType(typeName));
    return Builder(
      builder: (chipContext) => Clickable(
        key: key,
        onPressed: () {
          final box = chipContext.findRenderObject() as RenderBox?;
          showDropdown(
            context: context,
            // An explicit position is where the menu opens; following the
            // anchor widget would drag it to that widget's bottom centre.
            follow: false,
            // Top-left corner at the point, as editor context menus open.
            alignment: Alignment.topLeft,
            anchorAlignment: Alignment.topLeft,
            position: box?.localToGlobal(box.size.bottomLeft(Offset.zero)) ?? Offset.zero,
            builder: (context) => DropdownMenu(
              children: [
                for (final group in BlueprintPinStyle.variableTypeGroups(widget.context))
                  if (group.typeNames.isNotEmpty) ...[
                    MenuLabel(
                      key: ValueKey('var_type_group_${group.title}'),
                      child: Text(group.title.toUpperCase(),
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
                    ),
                    for (final t in group.typeNames)
                      MenuButton(
                        key: ValueKey('var_type_item_$t'),
                        leading: Container(width: 10, height: 4, color: BlueprintPinStyle.color(LuminaPinType.parseVariableType(t))),
                        child: Text(BlueprintPinStyle.variableLabel(t), style: const TextStyle(fontSize: 10)),
                        onPressed: (ctx) => onPick(t),
                      ),
                  ],
              ],
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: Text(BlueprintPinStyle.variableLabel(typeName), style: TextStyle(fontSize: 8.5, color: color, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _draggableRow({required Key key, required Object data, required Color color, required String title, required String subtitle}) {
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 10, color: EditorColors.foreground, fontWeight: FontWeight.w600)),
      ],
    );
    return Draggable<Object>(
      key: key,
      data: data,
      // The whole row starts the drag, not only its label.
      hitTestBehavior: HitTestBehavior.opaque,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: EditorColors.card,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color),
        ),
        child: DefaultTextStyle(style: const TextStyle(decoration: TextDecoration.none), child: chip),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        margin: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Expanded(child: chip),
            Text(subtitle, style: TextStyle(fontSize: 8.5, color: color.withValues(alpha: 0.9))),
          ],
        ),
      ),
    );
  }
}
