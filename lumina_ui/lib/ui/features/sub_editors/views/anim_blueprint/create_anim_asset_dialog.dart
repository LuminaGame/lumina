import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../../core/property_editors/asset_picker_select.dart';
import '../../../../core/theme/editor_theme.dart';
import '../../services/anim_graph_asset_service.dart';

/// Which animation asset the Content Browser's Animation menu creates.
enum AnimAssetKind { animBlueprint, blendSpace }

/// Content Browser → Animation → Animation Blueprint / Blend Space: pick the
/// target skeletal mesh and a name, then write `ABP_*.lmas` / `BS_*.lmas`
/// next to the mesh's clips. [onCreated] gets the new asset's project
/// relative path.
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

  String get _prefix => widget.kind == AnimAssetKind.animBlueprint ? 'ABP_' : 'BS_';

  @override
  void initState() {
    super.initState();
    if (_meshes.isNotEmpty) _pick(_meshes.first.relativePath);
  }

  void _pick(String mesh) {
    _mesh = mesh;
    final base = AnimGraphAssetService.baseName(mesh).replaceFirst(RegExp(r'^SKM_'), '');
    _name.text = widget.kind == AnimAssetKind.animBlueprint ? 'ABP_$base' : 'BS_${base}_Locomotion';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    final mesh = _mesh;
    if (mesh == null) return;
    final path = widget.kind == AnimAssetKind.animBlueprint
        ? AnimGraphAssetService.createAnimBlueprint(widget.projectDir, name: _name.text, meshRelPath: mesh)
        : AnimGraphAssetService.createBlendSpace(widget.projectDir, name: _name.text, meshRelPath: mesh);
    EngineLoggerService().log('Created ${widget.kind == AnimAssetKind.animBlueprint ? 'Animation Blueprint' : 'Blend Space'} $path',
        level: 'success', source: 'ContentBrowser');
    widget.onCreated(path);
  }

  @override
  Widget build(BuildContext context) {
    final abp = widget.kind == AnimAssetKind.animBlueprint;
    return AlertDialog(
      title: Text(abp ? 'New Animation Blueprint' : 'New Blend Space'),
      content: SizedBox(
        width: 380,
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
            TextField(key: const ValueKey('anim_asset_name'), controller: _name),
            const SizedBox(height: 6),
            Text(
              'Saved as ${AnimGraphAssetService.withPrefix(_name.text, _prefix)}.lmas under contents/animations/'
              '${_mesh == null ? '…' : AnimGraphAssetService.baseName(_mesh!)}/',
              style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
            ),
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
