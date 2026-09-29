import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import '../view_models/animation_editor_view_model.dart';
import '../../../core/theme/editor_theme.dart';
import '../../../core/property_editors/asset_picker_select.dart';

/// Modal dialog for retargeting an animation sequence to a different skeletal mesh character.
class AnimationRetargetModal extends StatefulWidget {
  final AnimationEditorViewModel viewModel;
  final String sourceAssetName;
  final VoidCallback? onCompleted;

  const AnimationRetargetModal({
    super.key,
    required this.viewModel,
    required this.sourceAssetName,
    this.onCompleted,
  });

  @override
  State<AnimationRetargetModal> createState() => _AnimationRetargetModalState();
}

class _AnimationRetargetModalState extends State<AnimationRetargetModal> {
  RealAssetInfo? _selectedTargetMesh;
  late TextEditingController _outputNameController;
  bool _isProcessing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final meshes = widget.viewModel.availableSkeletalMeshes;
    _selectedTargetMesh = widget.viewModel.previewMeshAsset ?? (meshes.isNotEmpty ? meshes.first : null);
    final targetBase = _selectedTargetMesh?.fileName.replaceAll('.lmas', '') ?? 'Target';
    final sourceBase = widget.sourceAssetName.replaceAll('.lmas', '');
    _outputNameController = TextEditingController(text: '${targetBase}_$sourceBase');
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
      final targetBase = mesh.fileName.replaceAll('.lmas', '');
      final sourceBase = widget.sourceAssetName.replaceAll('.lmas', '');
      _outputNameController.text = '${targetBase}_$sourceBase';
    });
  }

  Future<void> _handleRetarget() async {
    if (_selectedTargetMesh == null) return;
    final rawName = _outputNameController.text.trim();
    final outName = rawName.replaceAll(RegExp(r'\.lmas$'), '');
    if (outName.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final res = await widget.viewModel.executeRetarget(
        targetMeshAsset: _selectedTargetMesh!,
        outputName: outName,
      );
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = res != null ? 'Retarget exported successfully to $res' : 'Failed to export retargeted asset.';
        });
        if (res != null) {
          widget.onCompleted?.call();
          Future.delayed(const Duration(milliseconds: 400), () {
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

    return Center(
      child: Card(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.repeat, size: 16, color: Colors.cyan),
                  const SizedBox(width: 8),
                  const Text('Retarget Animation Asset', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GhostButton(
                    size: ButtonSize.small,
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Icon(LucideIcons.x, size: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Source Animation
              const Text('Source Animation', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: EditorColors.card,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: EditorColors.border),
                ),
                child: Text(widget.sourceAssetName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange)),
              ),
              const SizedBox(height: 14),

              // Target Skeletal Mesh
              const Text('Target Skeletal Mesh', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
              const SizedBox(height: 4),
              if (meshes.isNotEmpty)
                AssetPickerSelect(
                  key: const ValueKey('animation_retarget_target_select'),
                  keyPrefix: 'animation_retarget_target_picker',
                  assets: meshes,
                  selectedPath: _selectedTargetMesh?.relativePath,
                  placeholder: 'Pick a skeletal mesh',
                  allowClear: false,
                  onSelected: _onTargetMeshChanged,
                )
              else
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EditorColors.card,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('No other skeletal meshes found in project contents.', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                ),
              const SizedBox(height: 14),

              // Output Asset Name
              const Text('Output Asset Name', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
              const SizedBox(height: 4),
              TextField(
                controller: _outputNameController,
              ),
              const SizedBox(height: 14),

              // Humanoid Bone Chain Auto-mapping summary
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
                        Text('Humanoid IK Rig Auto-Mapping Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Root, Pelvis, Spine, Arms, and Legs will be scaled proportionally by height ratio with bind pose compensation.',
                      style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
                    ),
                  ],
                ),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _statusMessage!,
                  style: TextStyle(
                    fontSize: 10,
                    color: _statusMessage!.startsWith('Error') ? Colors.red : Colors.green,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Dialog Actions
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
                    size: ButtonSize.small,
                    onPressed: _isProcessing || _selectedTargetMesh == null ? null : _handleRetarget,
                    child: _isProcessing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Export Retargeted Asset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
