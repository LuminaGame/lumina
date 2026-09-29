import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../../core/theme/editor_theme.dart';
import '../../sub_editor_binding.dart';
import '../../view_models/blueprint_enum_view_model.dart';

/// The Enumeration sub-editor:
/// the enum's ordered values with add, rename (double-click or the pencil),
/// remove, move up / down; Save writes the `.lmas` and rewires the
/// project's `Switch on <enum>` cases by value name.
class BlueprintEnumSubEditor extends StatefulWidget {
  final String assetName;
  final String assetPath;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final BlueprintEnumViewModel? viewModel;

  const BlueprintEnumSubEditor({super.key, required this.assetName, required this.assetPath, this.onClose, this.onBind, this.viewModel});

  @override
  State<BlueprintEnumSubEditor> createState() => BlueprintEnumSubEditorState();
}

class BlueprintEnumSubEditorState extends State<BlueprintEnumSubEditor> {
  late final BlueprintEnumViewModel _vm;
  late final bool _owns;
  int? _renaming;
  final TextEditingController _rename = TextEditingController();

  BlueprintEnumViewModel get viewModel => _vm;

  @override
  void initState() {
    super.initState();
    _owns = widget.viewModel == null;
    _vm = widget.viewModel ?? BlueprintEnumViewModel(assetPath: widget.assetPath);
    widget.onBind?.call(_vm, _vm.save, () => _vm.isDirty);
    if (_owns) _vm.load();
  }

  @override
  void dispose() {
    _rename.dispose();
    if (_owns) _vm.dispose();
    super.dispose();
  }

  void _beginRename(int i) => setState(() {
        _renaming = i;
        _rename.text = _vm.values[i];
      });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_vm, _vm.transactions]),
      builder: (context, _) => Container(
        color: EditorColors.background,
        child: Column(
          children: [
            _toolbar(),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                key: const ValueKey('enum_editor_values'),
                padding: const EdgeInsets.all(12),
                children: [
                  Row(children: [
                    const Icon(LucideIcons.list, size: 12, color: EditorColors.primary),
                    const SizedBox(width: 6),
                    const Text('ENUMERATORS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary)),
                    const Spacer(),
                    OutlineButton(
                      key: const ValueKey('enum_add_value'),
                      size: ButtonSize.small,
                      onPressed: () => _vm.addValue(),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.plus, size: 10),
                        SizedBox(width: 4),
                        Text('Add Enumerator', style: TextStyle(fontSize: 10)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  if (_vm.values.isEmpty)
                    const Text('No values. Add one.', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                  for (var i = 0; i < _vm.values.length; i++) _row(i),
                  const SizedBox(height: 8),
                  const Text('Values are their names at run time; Switch on Enum cases follow a value when it is moved.',
                      style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    final tx = _vm.transactions;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.card,
      child: Row(
        children: [
          const OutlineBadge(child: Text('ENUMERATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Flexible(
            child: Text('${_vm.name}${_vm.isDirty ? ' *' : ''}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text('${_vm.values.length} value${_vm.values.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          const Spacer(),
          GhostButton(key: const ValueKey('enum_undo'), size: ButtonSize.small, onPressed: tx.canUndo ? _vm.undo : null, child: const Icon(LucideIcons.undo2, size: 13)),
          GhostButton(key: const ValueKey('enum_redo'), size: ButtonSize.small, onPressed: tx.canRedo ? _vm.redo : null, child: const Icon(LucideIcons.redo2, size: 13)),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const ValueKey('enum_save'),
            size: ButtonSize.small,
            onPressed: () => _vm.save(),
            child: const Text('Save', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          GhostButton(size: ButtonSize.small, onPressed: widget.onClose, child: const Icon(LucideIcons.x, size: 14)),
        ],
      ),
    );
  }

  Widget _row(int i) {
    final value = _vm.values[i];
    final selected = _vm.selectedIndex == i;
    return Container(
      key: ValueKey('enum_value_row_$value'),
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: selected ? EditorColors.primary.withValues(alpha: 0.15) : EditorColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Text('$i', style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground)),
          const SizedBox(width: 10),
          Expanded(
            child: _renaming == i
                ? SizedBox(
                    height: 22,
                    child: TextField(
                      key: const ValueKey('enum_rename_field'),
                      controller: _rename,
                      autofocus: true,
                      style: const TextStyle(fontSize: 10),
                      onSubmitted: (v) {
                        _vm.renameValue(i, v);
                        setState(() => _renaming = null);
                      },
                    ),
                  )
                : GestureDetector(
                    onDoubleTap: () => _beginRename(i),
                    child: Clickable(
                      onPressed: () => _vm.select(i),
                      child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
          ),
          GhostButton(key: ValueKey('enum_rename_$value'), size: ButtonSize.xSmall, density: ButtonDensity.icon, onPressed: () => _beginRename(i), child: const Icon(LucideIcons.pencil, size: 11)),
          GhostButton(key: ValueKey('enum_up_$value'), size: ButtonSize.xSmall, density: ButtonDensity.icon, onPressed: i == 0 ? null : () => _vm.moveUp(i), child: const Icon(LucideIcons.chevronUp, size: 11)),
          GhostButton(key: ValueKey('enum_down_$value'), size: ButtonSize.xSmall, density: ButtonDensity.icon, onPressed: i == _vm.values.length - 1 ? null : () => _vm.moveDown(i), child: const Icon(LucideIcons.chevronDown, size: 11)),
          GhostButton(key: ValueKey('enum_remove_$value'), size: ButtonSize.xSmall, density: ButtonDensity.icon, onPressed: () => _vm.removeValue(i), child: const Icon(LucideIcons.trash2, size: 11)),
        ],
      ),
    );
  }
}
