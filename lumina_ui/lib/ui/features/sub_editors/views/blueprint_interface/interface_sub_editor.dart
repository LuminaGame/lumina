import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_interface_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/signature_editor.dart';

/// The Blueprint Interface sub-editor: the interface's
/// functions with their signatures. A function with outputs is implemented
/// as a Blueprint function; one without as an event.
class BlueprintInterfaceSubEditor extends StatefulWidget {
  final String assetName;
  final String assetPath;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final BlueprintInterfaceViewModel? viewModel;

  const BlueprintInterfaceSubEditor({super.key, required this.assetName, required this.assetPath, this.onClose, this.onBind, this.viewModel});

  @override
  State<BlueprintInterfaceSubEditor> createState() => BlueprintInterfaceSubEditorState();
}

class BlueprintInterfaceSubEditorState extends State<BlueprintInterfaceSubEditor> {
  late final BlueprintInterfaceViewModel _vm;
  late final bool _owns;
  String? _renaming;
  final TextEditingController _rename = TextEditingController();

  BlueprintInterfaceViewModel get viewModel => _vm;

  @override
  void initState() {
    super.initState();
    _owns = widget.viewModel == null;
    _vm = widget.viewModel ?? BlueprintInterfaceViewModel(assetPath: widget.assetPath);
    widget.onBind?.call(_vm, _vm.save, () => _vm.isDirty);
    if (_owns) _vm.load();
  }

  @override
  void dispose() {
    _rename.dispose();
    if (_owns) _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_vm, _vm.transactions]),
      builder: (context, _) {
        final selected = _vm.function(_vm.selectedFunction);
        return Container(
          color: EditorColors.background,
          child: Column(
            children: [
              _toolbar(),
              const Divider(height: 1),
              Expanded(
                child: ResizablePanel.horizontal(
                  children: [
                    ResizablePane(initialSize: 260, minSize: 200, child: _functionList()),
                    ResizablePane.flex(
                      child: Container(
                        color: EditorColors.cardHeader,
                        child: selected == null
                            ? const Center(child: Text('Select a function to edit its signature.', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)))
                            : _signature(selected),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
          const OutlineBadge(child: Text('BLUEPRINT INTERFACE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Flexible(
            child: Text('${_vm.name}${_vm.isDirty ? ' *' : ''}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground), overflow: TextOverflow.ellipsis),
          ),
          const Spacer(),
          GhostButton(key: const ValueKey('iface_undo'), size: ButtonSize.small, onPressed: tx.canUndo ? _vm.undo : null, child: const Icon(LucideIcons.undo2, size: 13)),
          GhostButton(key: const ValueKey('iface_redo'), size: ButtonSize.small, onPressed: tx.canRedo ? _vm.redo : null, child: const Icon(LucideIcons.redo2, size: 13)),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const ValueKey('iface_save'),
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

  Widget _functionList() {
    return Container(
      color: EditorColors.cardHeader,
      padding: const EdgeInsets.all(8),
      child: ListView(
        key: const ValueKey('iface_functions'),
        children: [
          Row(children: [
            const Icon(LucideIcons.squareFunction, size: 12, color: EditorColors.primary),
            const SizedBox(width: 6),
            const Text('FUNCTIONS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
            const Spacer(),
            GhostButton(key: const ValueKey('iface_add_function'), size: ButtonSize.small, onPressed: () => _vm.addFunction(), child: const Icon(LucideIcons.plus, size: 12)),
          ]),
          const SizedBox(height: 4),
          if (_vm.functions.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('No functions. Press + to add one.', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
          for (final f in _vm.functions)
            _renaming == f.name
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: TextField(
                      key: const ValueKey('iface_rename_field'),
                      controller: _rename,
                      autofocus: true,
                      style: const TextStyle(fontSize: 10),
                      onSubmitted: (v) {
                        _vm.renameFunction(f.name, v);
                        setState(() => _renaming = null);
                      },
                    ),
                  )
                : Clickable(
                    key: ValueKey('iface_function_row_${f.name}'),
                    onPressed: () => _vm.select(f.name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: _vm.selectedFunction == f.name ? EditorColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(children: [
                        Expanded(child: Text('${f.name}(${f.inputs.map((p) => p.name).join(', ')})${f.outputs.isEmpty ? '' : ' → ${f.outputs.map((p) => p.name).join(', ')}'}',
                            overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                        GhostButton(
                          key: ValueKey('iface_rename_${f.name}'),
                          size: ButtonSize.xSmall,
                          density: ButtonDensity.icon,
                          onPressed: () => setState(() {
                            _renaming = f.name;
                            _rename.text = f.name;
                          }),
                          child: const Icon(LucideIcons.pencil, size: 11),
                        ),
                        GhostButton(
                          key: ValueKey('iface_remove_${f.name}'),
                          size: ButtonSize.xSmall,
                          density: ButtonDensity.icon,
                          onPressed: () => _vm.removeFunction(f.name),
                          child: const Icon(LucideIcons.trash2, size: 11),
                        ),
                      ]),
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _signature(LuminaBlueprintFunctionSignature f) {
    return ListView(
      key: ValueKey('iface_signature_${f.name}'),
      padding: const EdgeInsets.all(12),
      children: [
        Row(children: [
          const Icon(LucideIcons.squareFunction, size: 12, color: EditorColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text('FUNCTION: ${f.name}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary))),
        ]),
        const SizedBox(height: 2),
        Text(f.outputs.isEmpty ? 'Implemented as an event in each Blueprint' : 'Implemented as a function in each Blueprint',
            style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),
        BlueprintSignatureEditor(
          title: 'Inputs',
          keyPrefix: 'iface_input',
          parameters: f.inputs,
          showDefaults: false,
          onChanged: (v) => _vm.setInputs(f.name, v),
        ),
        const SizedBox(height: 8),
        BlueprintSignatureEditor(
          title: 'Outputs',
          keyPrefix: 'iface_output',
          parameters: f.outputs,
          showDefaults: false,
          onChanged: (v) => _vm.setOutputs(f.name, v),
        ),
      ],
    );
  }
}
