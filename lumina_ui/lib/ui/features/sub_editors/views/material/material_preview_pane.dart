import 'dart:isolate';

import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/material_settings_section.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Material Editor's left column: the 3D preview (a primitive, or a
/// project mesh with the material on one of its slots) above the material
/// settings, split by a draggable divider.
class MaterialPreviewPane extends StatefulWidget {
  final MaterialEditorViewModel viewModel;

  /// Bumped by the editor on every view-model change so the preview
  /// re-applies the parameter values.
  final int parameterRevision;

  const MaterialPreviewPane({super.key, required this.viewModel, required this.parameterRevision});

  /// The mesh asset types the custom preview offers.
  static const Set<AssetType> meshTypes = {AssetType.filamesh, AssetType.filameshSk};

  /// The geometry sections of [mesh] that belong to material slot [slot]:
  /// every section when the mesh has at most one slot.
  static Set<int> sectionsOfSlot(GlbMeshData mesh, int slot) {
    final sections = mesh.subPrimitives;
    if (mesh.materialNames.length <= 1) return {for (var i = 0; i < sections.length; i++) i};
    final name = slot < mesh.materialNames.length ? mesh.materialNames[slot] : null;
    return {
      for (var i = 0; i < sections.length; i++)
        if (sections[i].materialIndex == slot ||
            (sections[i].materialIndex == null && name != null && sections[i].materialName == name))
          i,
    };
  }

  /// The project's mesh assets under [projectRoot], scanned on a background
  /// isolate (static, so the isolate's closure captures only [projectRoot]).
  static Future<List<RealAssetInfo>> scanMeshes(String projectRoot) => Isolate.run(() => AssetRepository()
      .scanProjectContents(projectRoot)
      .where((a) => meshTypes.contains(a.type))
      .toList());

  @override
  State<MaterialPreviewPane> createState() => _MaterialPreviewPaneState();
}

enum _PreviewGeometry { sphere, cube, cylinder, plane, custom }

class _MaterialPreviewPaneState extends State<MaterialPreviewPane> {
  _PreviewGeometry _geometry = _PreviewGeometry.sphere;
  bool _gridEnabled = true;

  List<RealAssetInfo>? _meshes;
  bool _scanning = false;
  RealAssetInfo? _meshAsset;
  GlbMeshData? _mesh;
  bool _loadingMesh = false;
  String? _meshError;
  int _slot = 0;

  /// Guards against an older mesh load finishing after a newer pick.
  int _loadGeneration = 0;

  static const _labels = {
    _PreviewGeometry.sphere: 'Sphere',
    _PreviewGeometry.cube: 'Cube',
    _PreviewGeometry.cylinder: 'Cylinder',
    _PreviewGeometry.plane: 'Plane',
    _PreviewGeometry.custom: 'Custom',
  };

  void _select(_PreviewGeometry geometry) {
    setState(() => _geometry = geometry);
    if (geometry == _PreviewGeometry.custom && _meshes == null) _scanMeshes();
  }

  Future<void> _scanMeshes() async {
    final root = widget.viewModel.projectRoot;
    if (root == null || _scanning) {
      if (root == null) setState(() => _meshes = const []);
      return;
    }
    setState(() => _scanning = true);
    List<RealAssetInfo> found;
    try {
      found = await MaterialPreviewPane.scanMeshes(root);
      found.sort((a, b) => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()));
    } catch (_) {
      found = const [];
    }
    if (!mounted) return;
    setState(() {
      _meshes = found;
      _scanning = false;
    });
  }

  Future<void> _pickMesh(RealAssetInfo asset) async {
    final root = widget.viewModel.projectRoot;
    final path = asset.lmasPath ?? (root == null ? null : p.join(root, asset.relativePath));
    if (path == null) return;
    final generation = ++_loadGeneration;
    setState(() {
      _meshAsset = asset;
      _mesh = null;
      _slot = 0;
      _meshError = null;
      _loadingMesh = true;
    });
    final mesh = await AssetRepository.loadMeshFromDisk(path);
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _loadingMesh = false;
      _mesh = mesh;
      if (mesh == null) _meshError = 'Could not load ${asset.fileName}';
    });
  }

  PreviewShape get _shape => switch (_geometry) {
        _PreviewGeometry.cube => PreviewShape.cube,
        _PreviewGeometry.cylinder => PreviewShape.cylinder,
        _PreviewGeometry.plane => PreviewShape.plane,
        _ => PreviewShape.sphere,
      };

  @override
  Widget build(BuildContext context) {
    return ResizablePanel.vertical(
      draggerBuilder: (_) => const VerticalResizableDragger(),
      children: [
        ResizablePane.flex(
          minSize: 200,
          child: Container(
            padding: const EdgeInsets.all(12),
            color: EditorColors.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('3D PREVIEW MESH',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
                    const Spacer(),
                    const Text('Grid', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                    const SizedBox(width: 6),
                    Switch(
                      key: const ValueKey('material_preview_grid'),
                      value: _gridEnabled,
                      onChanged: (val) => setState(() => _gridEnabled = val),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final g in _PreviewGeometry.values)
                      SecondaryButton(
                        key: ValueKey('material_preview_${g.name}'),
                        onPressed: () => _select(g),
                        child: Text(_labels[g]!,
                            style: TextStyle(
                                fontSize: 9,
                                color: _geometry == g ? EditorColors.primary : EditorColors.foreground)),
                      ),
                  ],
                ),
                if (_geometry == _PreviewGeometry.custom) ..._customControls(),
                const SizedBox(height: 12),
                Expanded(child: _viewport()),
              ],
            ),
          ),
        ),
        ResizablePane(
          initialSize: 190,
          minSize: 120,
          child: MaterialSettingsSection(viewModel: widget.viewModel),
        ),
      ],
    );
  }

  List<Widget> _customControls() {
    final meshes = _meshes;
    final mesh = _mesh;
    return [
      const SizedBox(height: 8),
      if (meshes == null || _scanning)
        const Text('Scanning the project meshes…', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground))
      else if (meshes.isEmpty)
        const Text('No meshes in this project yet.', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground))
      else
        AssetPickerSelect(
          key: const ValueKey('material_preview_mesh_picker'),
          keyPrefix: 'material_preview_mesh',
          assets: meshes,
          selectedPath: _meshAsset?.lmasPath,
          placeholder: 'Select a mesh',
          thumbnailSize: 24,
          allowClear: false,
          onSelected: _pickMesh,
        ),
      if (mesh != null && mesh.materialNames.length > 1) ...[
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(
              width: 80,
              child: Text('Material slot', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
            ),
            Expanded(
              child: Select<int>(
                key: const ValueKey('material_preview_slot'),
                value: _slot,
                onChanged: (v) {
                  if (v != null) setState(() => _slot = v);
                },
                itemBuilder: (context, i) => Text(_slotLabel(mesh, i), style: const TextStyle(fontSize: 11)),
                popup: SelectPopup(
                  items: SelectItemList(
                    children: [
                      for (var i = 0; i < mesh.materialNames.length; i++)
                        SelectItemButton(value: i, child: Text(_slotLabel(mesh, i))),
                    ],
                  ),
                ).call,
              ),
            ),
          ],
        ),
      ],
      if (_meshError != null) ...[
        const SizedBox(height: 4),
        Text(_meshError!, style: const TextStyle(fontSize: 10, color: EditorColors.destructive)),
      ],
    ];
  }

  static String _slotLabel(GlbMeshData mesh, int i) {
    final name = mesh.materialNames[i];
    return '$i · ${name.isEmpty ? 'Slot $i' : name}';
  }

  Widget _viewport() {
    final vm = widget.viewModel;
    if (_geometry == _PreviewGeometry.custom) {
      final mesh = _mesh;
      if (mesh == null) {
        return Center(
          child: Text(
            _loadingMesh ? 'Loading ${_meshAsset?.fileName ?? 'mesh'}…' : 'Pick a mesh to preview the material on.',
            style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
          ),
        );
      }
      return SubEditor3DViewport(
        // A new mesh, slot or compiled package mounts a fresh preview.
        key: ValueKey(
            'material_preview_custom:${_meshAsset?.lmasPath}:$_slot:$_gridEnabled:${identityHashCode(vm.compiledBytes)}'),
        title: 'Material 3D Preview Viewport',
        glbMesh: mesh,
        meshSourcePath: _meshAsset?.lmasPath,
        showShapeSelector: false,
        showToolbar: false,
        showGrid: _gridEnabled,
        previewMaterialBytes: vm.compiledBytes,
        previewMaterialParams: vm.parameters,
        previewMaterialRevision: widget.parameterRevision,
        previewMaterialSections: MaterialPreviewPane.sectionsOfSlot(mesh, _slot),
      );
    }
    return SubEditor3DViewport(
      key: ValueKey('material_preview_primitive:$_gridEnabled'),
      title: 'Material 3D Preview Viewport',
      initialShape: _shape,
      showShapeSelector: false,
      showToolbar: false,
      showGrid: _gridEnabled,
      previewMaterialBytes: vm.compiledBytes,
      previewMaterialParams: vm.parameters,
      previewMaterialRevision: widget.parameterRevision,
    );
  }
}
