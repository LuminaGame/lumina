import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';

/// Which animation asset the Content Browser's Animation menu creates.
enum AnimAssetKind { animBlueprint, blendSpace, animationSequence, poseSearchDatabase }

/// Content Browser → Animation → Animation Blueprint / Blend Space /
/// Animation Sequence: pick the target skeletal mesh and a name (and, for a
/// sequence, its length and frame rate), then write `ABP_*.lmas` /
/// `BS_*.lmas` / the sequence next to the mesh's clips. [onCreated] gets the
/// new asset's project relative path.
void showCreateAnimAssetDialog(
  BuildContext context, {
  required String projectDir,
  required AnimAssetKind kind,
  required ValueChanged<String> onCreated,
}) {
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (dialogContext) => CreateAnimAssetDialog(
      projectDir: projectDir,
      kind: kind,
      onCancel: () => closeOverlay(dialogContext),
      onCreated: (path) {
        closeOverlay(dialogContext);
        onCreated(path);
      },
    ),
  );
}

class CreateAnimAssetDialog extends StatefulWidget {
  final String projectDir;
  final AnimAssetKind kind;
  final ValueChanged<String> onCreated;
  final VoidCallback onCancel;

  const CreateAnimAssetDialog({
    super.key,
    required this.projectDir,
    required this.kind,
    required this.onCreated,
    required this.onCancel,
  });

  @override
  State<CreateAnimAssetDialog> createState() => _CreateAnimAssetDialogState();
}

class _CreateAnimAssetDialogState extends State<CreateAnimAssetDialog> {
  late final List<RealAssetInfo> _meshes = AnimGraphAssetService.skeletalMeshes(widget.projectDir);
  String? _mesh;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _length = TextEditingController(text: '60');
  final TextEditingController _fps = TextEditingController(text: '30');

  /// The sequence length is typed in frames (true) or seconds.
  bool _lengthInFrames = true;
  String? _error;

  String get _prefix => switch (widget.kind) {
        AnimAssetKind.animBlueprint => 'ABP_',
        AnimAssetKind.blendSpace => 'BS_',
        AnimAssetKind.poseSearchDatabase => 'PSD_',
        AnimAssetKind.animationSequence => '',
      };

  String get _kindLabel => switch (widget.kind) {
        AnimAssetKind.animBlueprint => 'Animation Blueprint',
        AnimAssetKind.blendSpace => 'Blend Space',
        AnimAssetKind.poseSearchDatabase => 'Pose Search Database',
        AnimAssetKind.animationSequence => 'Animation Sequence',
      };

  double? get _frameRate {
    final v = double.tryParse(_fps.text.trim());
    return v != null && v > 0 && v <= 240 ? v : null;
  }

  /// The length in frames, from the field and its unit; null when invalid.
  int? get _lengthFrames {
    final fps = _frameRate;
    final v = double.tryParse(_length.text.trim());
    if (fps == null || v == null || v <= 0) return null;
    final frames = _lengthInFrames ? v.round() : (v * fps).round();
    return frames >= 1 ? frames : null;
  }

  @override
  void initState() {
    super.initState();
    if (_meshes.isNotEmpty) _pick(_meshes.first.relativePath);
  }

  void _pick(String mesh) {
    _mesh = mesh;
    final base = AnimGraphAssetService.baseName(mesh).replaceFirst(RegExp(r'^SKM_'), '');
    _name.text = switch (widget.kind) {
      AnimAssetKind.animBlueprint => 'ABP_$base',
      AnimAssetKind.blendSpace => 'BS_${base}_Locomotion',
      AnimAssetKind.poseSearchDatabase => 'PSD_${base}_Locomotion',
      AnimAssetKind.animationSequence => 'NewAnimation',
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _length.dispose();
    _fps.dispose();
    super.dispose();
  }

  void _create() {
    final mesh = _mesh;
    if (mesh == null) return;
    final String path;
    try {
      switch (widget.kind) {
        case AnimAssetKind.animBlueprint:
          path = AnimGraphAssetService.createAnimBlueprint(widget.projectDir, name: _name.text, meshRelPath: mesh);
        case AnimAssetKind.blendSpace:
          path = AnimGraphAssetService.createBlendSpace(widget.projectDir, name: _name.text, meshRelPath: mesh);
        case AnimAssetKind.poseSearchDatabase:
          path = AnimGraphAssetService.createPoseSearchDatabase(widget.projectDir, name: _name.text, meshRelPath: mesh);
        case AnimAssetKind.animationSequence:
          final frames = _lengthFrames;
          final fps = _frameRate;
          if (frames == null || fps == null) {
            setState(() => _error = 'Enter a positive length and a frame rate up to 240.');
            return;
          }
          path = AnimGraphAssetService.createAnimationSequence(widget.projectDir,
              name: _name.text, meshRelPath: mesh, lengthFrames: frames, frameRate: fps);
      }
    } catch (e) {
      setState(() => _error = '$e');
      EngineLoggerService().log('Could not create the $_kindLabel: $e', level: 'error', source: 'ContentBrowser');
      return;
    }
    EngineLoggerService().log('Created $_kindLabel $path', level: 'success', source: 'ContentBrowser');
    widget.onCreated(path);
  }

  Widget _labelled(String label, Widget field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
          const SizedBox(height: 4),
          field,
        ],
      );

  /// Length (frames or seconds) and frame rate of a new sequence.
  Widget _sequenceFields() {
    final frames = _lengthFrames;
    final fps = _frameRate;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _labelled(
                'Length',
                TextField(
                  key: const ValueKey('anim_sequence_length'),
                  controller: _length,
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Toggle(
              key: const ValueKey('anim_sequence_unit_frames'),
              value: _lengthInFrames,
              onChanged: (_) => setState(() => _lengthInFrames = true),
              child: const Text('Frames', style: TextStyle(fontSize: 10)),
            ),
            const SizedBox(width: 4),
            Toggle(
              key: const ValueKey('anim_sequence_unit_seconds'),
              value: !_lengthInFrames,
              onChanged: (_) => setState(() => _lengthInFrames = false),
              child: const Text('Seconds', style: TextStyle(fontSize: 10)),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: _labelled(
                'Frame Rate',
                TextField(
                  key: const ValueKey('anim_sequence_fps'),
                  controller: _fps,
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          frames == null || fps == null
              ? 'Enter a positive length and a frame rate up to 240.'
              : '$frames frames at ${fps == fps.roundToDouble() ? fps.toInt() : fps} FPS = '
                  '${(frames / fps).toStringAsFixed(2)} s; the skeleton starts in its rest pose.',
          key: const ValueKey('anim_sequence_summary'),
          style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sequence = widget.kind == AnimAssetKind.animationSequence;
    final folder = _mesh == null ? '…' : AnimGraphAssetService.baseName(_mesh!);
    return AlertDialog(
      title: Text('New $_kindLabel'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Target Skeletal Mesh', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
            const SizedBox(height: 4),
            if (_meshes.isEmpty)
              const Text('The project has no skeletal mesh. Import one first.',
                  style: TextStyle(fontSize: 11, color: EditorColors.destructive))
            else
              AssetPickerSelect(
                key: const ValueKey('anim_asset_mesh_select'),
                keyPrefix: 'anim_asset_mesh',
                assets: _meshes,
                selectedPath: _mesh,
                placeholder: 'Pick a skeletal mesh',
                allowClear: false,
                onSelected: (m) => setState(() => _pick(m.relativePath)),
              ),
            const SizedBox(height: 12),
            const Text('Name', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
            const SizedBox(height: 4),
            TextField(
              key: const ValueKey('anim_asset_name'),
              controller: _name,
              onChanged: (_) => setState(() => _error = null),
            ),
            if (sequence) _sequenceFields(),
            const SizedBox(height: 6),
            Text(
              sequence
                  ? 'Saved under contents/animations/$folder/ and stored as a clip in the mesh, '
                      'so Animation Blueprints, Play and the game play it.'
                  : 'Saved as ${AnimGraphAssetService.withPrefix(_name.text, _prefix)}.lmas under contents/animations/$folder/',
              style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!,
                  key: const ValueKey('anim_asset_error'), style: const TextStyle(fontSize: 10, color: EditorColors.destructive)),
            ],
          ],
        ),
      ),
      actions: [
        GhostButton(onPressed: widget.onCancel, child: const Text('Cancel')),
        PrimaryButton(key: const ValueKey('anim_asset_create'), onPressed: _mesh == null ? null : _create, child: const Text('Create')),
      ],
    );
  }
}
