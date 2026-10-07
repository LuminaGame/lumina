import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart';

/// Modal dialog for retargeting an Animation Blueprint and all its linked
/// animation clips and Blend Spaces onto another skeletal mesh character.
class AnimBlueprintRetargetModal extends StatefulWidget {
  final AnimBlueprintEditorViewModel viewModel;
  final String? initialTargetMeshPath;
  final VoidCallback? onCompleted;

  const AnimBlueprintRetargetModal({
    super.key,
    required this.viewModel,
    this.initialTargetMeshPath,
    this.onCompleted,
  });

  @override
  State<AnimBlueprintRetargetModal> createState() => _AnimBlueprintRetargetModalState();
}

class _AnimBlueprintRetargetModalState extends State<AnimBlueprintRetargetModal> {
  RealAssetInfo? _selectedTargetMesh;
  late TextEditingController _outputNameController;
  bool _saveAsNew = false;
  bool _isProcessing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final meshes = widget.viewModel.availableSkeletalMeshes;
    final currentMesh = widget.viewModel.document.targetMesh;

    if (widget.initialTargetMeshPath != null) {
      _selectedTargetMesh = meshes.where((m) => m.relativePath == widget.initialTargetMeshPath).firstOrNull;
    }
    _selectedTargetMesh ??= meshes.where((m) => m.relativePath != currentMesh).firstOrNull ?? (meshes.isNotEmpty ? meshes.first : null);

    final targetBase = _selectedTargetMesh != null ? AnimGraphAssetService.baseName(_selectedTargetMesh!.relativePath) : 'Target';
    _outputNameController = TextEditingController(text: 'ABP_$targetBase');
  }

  @override
  void dispose() {
    _outputNameController.dispose();
    super.dispose();
  }

  void _onTargetMeshChanged(RealAssetInfo? mesh) {
    if (mesh == null) return;
    setState(() {
      _selectedTargetMesh = mesh;
      final targetBase = AnimGraphAssetService.baseName(mesh.relativePath);
      _outputNameController.text = 'ABP_$targetBase';
    });
  }

  Future<void> _handleRetarget() async {
    if (_selectedTargetMesh == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final res = await widget.viewModel.executeRetarget(
        targetMeshAsset: _selectedTargetMesh!,
        outputName: _saveAsNew ? _outputNameController.text.trim() : null,
        saveAsNew: _saveAsNew,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = res != null ? 'Retarget completed successfully!' : 'Failed to retarget animation blueprint.';
        });

        if (res != null) {
          widget.onCompleted?.call();
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted) Navigator.of(context).maybePop(res);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meshes = widget.viewModel.availableSkeletalMeshes;
    final sourceMeshName = AnimGraphAssetService.baseName(widget.viewModel.document.targetMesh);
    final linkedClips = widget.viewModel.linkedClips;
    final linkedBlendSpaces = widget.viewModel.linkedBlendSpacePaths;

    return Center(
      child: Card(
        child: Container(
          width: 520,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Icon(LucideIcons.repeat, size: 16, color: Colors.cyan),
                  const SizedBox(width: 8),
                  const Text('Retarget Animation Blueprint', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GhostButton(
                    size: ButtonSize.small,
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Icon(LucideIcons.x, size: 14),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 12),

              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Source Skeletal Mesh
                    const Text('Source Skeletal Mesh',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: EditorColors.card,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EditorColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.personStanding, size: 14, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(sourceMeshName.isNotEmpty ? sourceMeshName : 'None',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange)),
                          const Spacer(),
                          Text(widget.viewModel.document.targetMesh,
                              style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Target Skeletal Mesh
                    const Text('Target Skeletal Mesh',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
                    const SizedBox(height: 4),
                    if (meshes.isNotEmpty)
                      AssetPickerSelect(
                        key: const ValueKey('abp_retarget_target_select'),
                        keyPrefix: 'abp_retarget_target_picker',
                        assets: meshes,
                        selectedPath: _selectedTargetMesh?.relativePath,
                        placeholder: 'Pick a skeletal mesh',
                        allowClear: false,
                        // The mesh the Blueprint targets today reads "(current)".
                        labelOf: (m) => m.relativePath == widget.viewModel.document.targetMesh
                            ? '${AnimGraphAssetService.baseName(m.relativePath)} (current)'
                            : AnimGraphAssetService.baseName(m.relativePath),
                        onSelected: _onTargetMeshChanged,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: EditorColors.card, borderRadius: BorderRadius.circular(4)),
                        child: const Text('No other skeletal meshes found in project.',
                            style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                      ),
                    const SizedBox(height: 12),

                    // Linked Animations To Retarget
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: EditorColors.card,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: EditorColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.film, size: 12, color: Colors.cyan),
                              const SizedBox(width: 6),
                              Text(
                                'Linked Animations (${linkedClips.length} Clips · ${linkedBlendSpaces.length} Blend Spaces)',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyan),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'All referenced animation clips and blend spaces will be retargeted to the new skeleton and linked automatically:',
                            style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final c in linkedClips)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: EditorColors.background,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: EditorColors.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.play, size: 8, color: Colors.green),
                                      const SizedBox(width: 3),
                                      Text(c, style: const TextStyle(fontSize: 9, color: EditorColors.foreground)),
                                    ],
                                  ),
                                ),
                              for (final bs in linkedBlendSpaces)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: EditorColors.background,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: EditorColors.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.grid3x3, size: 8, color: Colors.purple),
                                      const SizedBox(width: 3),
                                      Text(AnimGraphAssetService.baseName(bs),
                                          style: const TextStyle(fontSize: 9, color: EditorColors.blendSpaceLabel)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Humanoid IK Rig Auto-Mapping active
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: EditorColors.card,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: EditorColors.border),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.checkCheck, size: 12, color: Colors.green),
                              SizedBox(width: 6),
                              Text('Humanoid IK Rig Auto-Mapping Active',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Pelvis, Spine, Neck, Head, Arms, and Legs are scaled proportionally with bind pose model-space rotation compensation.',
                            style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Save as new blueprint option
                    Row(
                      children: [
                        Checkbox(
                          state: _saveAsNew ? CheckboxState.checked : CheckboxState.unchecked,
                          onChanged: (s) => setState(() => _saveAsNew = s == CheckboxState.checked),
                        ),
                        const SizedBox(width: 8),
                        const Text('Save as a new Animation Blueprint', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    if (_saveAsNew) ...[
                      const SizedBox(height: 6),
                      const Text('New Blueprint Name',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
                      const SizedBox(height: 4),
                      TextField(controller: _outputNameController),
                    ],
                  ],
                ),
              ),

              if (_statusMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _statusMessage!,
                  style: TextStyle(
                    fontSize: 10,
                    color: _statusMessage!.startsWith('Error') ? Colors.red : Colors.green,
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlineButton(
                    size: ButtonSize.small,
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  PrimaryButton(
                    key: const ValueKey('abp_confirm_retarget_button'),
                    size: ButtonSize.small,
                    onPressed: _isProcessing || _selectedTargetMesh == null ? null : _handleRetarget,
                    child: _isProcessing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Retarget All & Apply', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
