import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../sub_editor_binding.dart';
import '../../view_models/theme_editor_view_model.dart';
import 'theme_custom_style_dialog.dart';
import 'theme_preview_showcase.dart';
import 'theme_tree_panel.dart';

/// Sub-editor workspace for authoring and customizing UI Themes (.lmas).
///
/// The work area is split into two panels:
/// - Left panel: Tree view of theme objects, color tokens, typography, and component styles,
///   with an editable property inspector below for whichever item is selected.
/// - Right panel: Live preview showcase of all widgets styled by the theme. If a component
///   lacks a dedicated style override, a "Create Style" button is shown below it.
class ThemeSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final RealAssetInfo? asset;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final ThemeEditorViewModel? viewModel;

  const ThemeSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.asset,
    this.onClose,
    this.onBind,
    this.viewModel,
  });

  @override
  State<ThemeSubEditor> createState() => _ThemeSubEditorState();
}

class _ThemeSubEditorState extends State<ThemeSubEditor> {
  late final ThemeEditorViewModel _vm;
  late final bool _ownsVm;

  @override
  void initState() {
    super.initState();
    _ownsVm = widget.viewModel == null;
    _vm = widget.viewModel ??
        ThemeEditorViewModel(
          assetPath: widget.assetPath ?? widget.asset?.lmasPath ?? '',
        );

    widget.onBind?.call(_vm, _vm.save, () => _vm.isDirty);
    _vm.addListener(_onVmChanged);
    if (_ownsVm && !_vm.isLoaded) {
      _vm.load();
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    if (_ownsVm) _vm.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleSave() async {
    final ok = await _vm.save();
    if (mounted && ok) {
      // Saved feedback
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Toolbar
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colorScheme.card,
              border: Border(bottom: BorderSide(color: colorScheme.border)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.palette, size: 15, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 8),
                Text(
                  widget.assetName + (_vm.isDirty ? ' *' : ''),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _vm.isDirty ? const Color(0xFFF59E0B) : colorScheme.foreground,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0x338B5CF6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'UI Theme',
                    style: TextStyle(fontSize: 10, color: Color(0xFFA78BFA), fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                GhostButton(
                  density: ButtonDensity.compact,
                  onPressed: () => ThemeCustomStyleDialog.show(context, _vm),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.sparkles, size: 12),
                      SizedBox(width: 4),
                      Text('New Custom Style', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (_vm.isDirty)
                  OutlineButton(
                    density: ButtonDensity.compact,
                    onPressed: _vm.revert,
                    child: const Text('Revert', style: TextStyle(fontSize: 11)),
                  ),
                const SizedBox(width: 6),
                PrimaryButton(
                  density: ButtonDensity.compact,
                  onPressed: _vm.isDirty ? _handleSave : null,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.save, size: 12),
                      SizedBox(width: 4),
                      Text('Save Theme', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                if (widget.onClose != null) ...[
                  const SizedBox(width: 8),
                  GhostButton(
                    density: ButtonDensity.iconDense,
                    onPressed: widget.onClose,
                    child: const Icon(LucideIcons.x, size: 14),
                  ),
                ],
              ],
            ),
          ),

          // Main Work Area Split View
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Panel: Tree & Inspector
                SizedBox(
                  width: 320,
                  child: ThemeTreePanel(viewModel: _vm),
                ),

                // Right Panel: Showcase
                Expanded(
                  child: ThemePreviewShowcase(viewModel: _vm),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
