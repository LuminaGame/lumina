part of '../my_blueprint_panel.dart';

/// The variable rows: own variables (rename, type chip, menu) and
/// inherited ones (read-only).
mixin _MyBlueprintVariableRows on _BlueprintMyBlueprintPanelStateBase {
  Widget _row(LuminaBlueprintVariable v) {
    final color = BlueprintPinStyle.color(v.type);
    final selected = widget.selected == v.name;
    if (_renaming == v.name && _renamingKind == 'var') {
      return Padding(
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
            if (_renameError != null)
              Text(_renameError!, style: const TextStyle(fontSize: 8, color: EditorColors.destructive)),
          ],
        ),
      );
    }
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(v.name, style: const TextStyle(fontSize: 10, color: EditorColors.foreground, fontWeight: FontWeight.w600)),
      ],
    );
    return Draggable<BlueprintVariableDrag>(
      key: ValueKey('var_row_${v.name}'),
      data: BlueprintVariableDrag(v.name),
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
      child: GestureDetector(
        onSecondaryTapUp: (d) => _menu(v.name, d.globalPosition),
        child: Clickable(
          onPressed: () => widget.onSelect(v.name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: selected ? EditorColors.primary.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              children: [
                Expanded(child: chip),
                // The type chip: a coloured pill, a menu of the types.
                Builder(
                  builder: (chipContext) => Clickable(
                    key: ValueKey('var_type_${v.name}'),
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
                            // The type picker groups; one flat menu with
                            // group labels so every type is one click away.
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
                                    leading: Container(
                                      width: 10,
                                      height: 4,
                                      color: BlueprintPinStyle.color(LuminaPinType.parseVariableType(t)),
                                    ),
                                    child: Text(BlueprintPinStyle.variableLabel(t), style: const TextStyle(fontSize: 10)),
                                    onPressed: (ctx) => widget.onSetType(v.name, t),
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
                      child: Text(BlueprintPinStyle.variableLabel(v.typeName),
                          style: TextStyle(fontSize: 8.5, color: color, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                Builder(
                  builder: (buttonContext) => GhostButton(
                    key: ValueKey('var_menu_${v.name}'),
                    size: ButtonSize.xSmall,
                    density: ButtonDensity.icon,
                    onPressed: () {
                      final box = buttonContext.findRenderObject() as RenderBox?;
                      final origin = box?.localToGlobal(box.size.bottomLeft(Offset.zero)) ?? Offset.zero;
                      _menu(v.name, origin);
                    },
                    child: const Icon(LucideIcons.ellipsisVertical, size: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inheritedVariableRow(LuminaBlueprintVariable v) {
    final color = BlueprintPinStyle.color(v.type);
    final selected = widget.selected == v.name;
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(v.name, style: const TextStyle(fontSize: 10, color: EditorColors.foreground, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: EditorColors.muted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: EditorColors.border, width: 0.5),
          ),
          child: const Text('Inherited', style: TextStyle(fontSize: 7.5, color: EditorColors.mutedForeground)),
        ),
      ],
    );
    return Draggable<BlueprintVariableDrag>(
      key: ValueKey('var_inherited_row_${v.name}'),
      data: BlueprintVariableDrag(v.name),
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
      child: Clickable(
        onPressed: () => widget.onSelect(v.name),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: selected ? EditorColors.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: [
              Expanded(child: chip),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.7)),
                ),
                child: Text(BlueprintPinStyle.variableLabel(v.typeName),
                    style: TextStyle(fontSize: 8.5, color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
