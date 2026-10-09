import 'package:lumina_editor_data/lumina_editor.dart' show LuminaParticleEmitterConfig, RealAssetInfo;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Vector4;

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/particle_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/particle/curve_editors.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';

part 'particle_sub_editor/state.dart';
part 'particle_sub_editor/left_panel.dart';
part 'particle_sub_editor/center_panel.dart';
part 'particle_sub_editor/right_panel.dart';
part 'particle_sub_editor/num_field.dart';

/// Particle sub-editor.
///
/// Edits exactly `LuminaParticleEmitterConfig`: the engine's CPU emitter.
/// GPU-compute simulation, a scratch-pad node graph, curl-noise /
/// attraction / collision forces and ribbon / light renderers are **not**
/// built: the engine runs none of them, so no dead controls exist for them.
/// They are future scope.
class ParticleSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final String? projectDirPath;
  final SubEditorBindCallback? onBind;
  final VoidCallback? onClose;

  /// A view model already bound to the tab (an MCP tool opened the asset
  /// first); the editor adopts it and neither opens nor
  /// disposes it.
  final ParticleEditorViewModel? viewModel;

  const ParticleSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.projectDirPath,
    this.onBind,
    this.onClose,
    this.viewModel,
  });

  @override
  State<ParticleSubEditor> createState() => _ParticleSubEditorState();
}

/// The five stage blocks of the emitter stack.
enum ParticleStage { spawn, lifetime, forces, overLife, render }

extension on ParticleStage {
  String get key => switch (this) {
        ParticleStage.spawn => 'spawn',
        ParticleStage.lifetime => 'lifetime',
        ParticleStage.forces => 'forces',
        ParticleStage.overLife => 'overlife',
        ParticleStage.render => 'render',
      };

  String get title => switch (this) {
        ParticleStage.spawn => 'Spawn',
        ParticleStage.lifetime => 'Lifetime & Velocity',
        ParticleStage.forces => 'Forces',
        ParticleStage.overLife => 'Over-Life',
        ParticleStage.render => 'Render',
      };
}

class _ParticleSubEditorState extends _ParticleSubEditorStateBase
    with _ParticleSubEditorLeftPanel, _ParticleSubEditorCenterPanel, _ParticleSubEditorRightPanel {
  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    vm = widget.viewModel ??
        ParticleEditorViewModel(
          assetPath: widget.assetPath ?? '${widget.assetName}.lmas',
          projectDirPath: widget.projectDirPath,
        );
    if (_ownsViewModel) vm.open();
    vm.addListener(_onVm);
    widget.onBind?.call(vm, vm.save, () => vm.isDirty);
  }

  /// Test/smoke hook: the live view model behind this editor.
  ParticleEditorViewModel get viewModelForTest => vm;

  void _onVm() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    vm.removeListener(_onVm);
    if (_ownsViewModel) vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EditorColors.background,
      child: Column(
        children: [
          _toolbar(),
          const Divider(height: 1),
          Expanded(
            child: ResizablePanel.horizontal(
              children: [
                ResizablePane(initialSize: 280, minSize: 200, child: _leftPanel()),
                ResizablePane.flex(child: _centerPanel()),
                ResizablePane(initialSize: 300, minSize: 240, child: _rightPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- toolbar

  Widget _toolbar() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('PARTICLE VFX',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
          ),
          const SizedBox(width: 8),
          Text(widget.assetName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
          if (vm.isDirty) ...[
            const SizedBox(width: 6),
            Container(
              key: const ValueKey('particle_dirty_indicator'),
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: EditorColors.primary, shape: BoxShape.circle),
            ),
          ],
          const SizedBox(width: 10),
          const OutlineBadge(
            child: Text(ParticleEditorViewModel.backendLabel, style: TextStyle(fontSize: 8)),
          ),
          const Spacer(),
          GhostButton(
            key: const ValueKey('particle_reset_sim'),
            onPressed: vm.resetSimulation,
            child: const Text('Reset Sim', style: TextStyle(fontSize: 9)),
          ),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const ValueKey('particle_save'),
            onPressed: vm.canSave && vm.isDirty ? () => vm.save() : null,
            child: const Text('Save', style: TextStyle(fontSize: 9)),
          ),
          if (widget.onClose != null) ...[
            const SizedBox(width: 8),
            GhostButton(onPressed: widget.onClose, child: const Icon(LucideIcons.x, size: 14)),
          ],
        ],
      ),
    );
  }

}
