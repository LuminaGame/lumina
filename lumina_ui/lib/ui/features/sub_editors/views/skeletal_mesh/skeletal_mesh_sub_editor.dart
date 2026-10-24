import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/editor_island.dart';
import 'package:lumina_ui/ui/core/widgets/viewport_pills.dart' show ViewportPillStyle, ViewportShowItem;
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/property_editors/synced_text_field.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/skeletal_mesh_socket.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/skeletal_mesh/material_slots_panel.dart';

part 'sub_editor/state.dart';
part 'sub_editor/toolbar.dart';
part 'sub_editor/left_sidebar.dart';
part 'sub_editor/bone_tree.dart';
part 'sub_editor/inspector.dart';

class SkeletalMeshSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final RealAssetInfo? asset;
  final SkeletalMeshEditorViewModel? viewModel;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;

  const SkeletalMeshSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.asset,
    this.viewModel,
    this.onClose,
    this.onBind,
  });

  @override
  State<SkeletalMeshSubEditor> createState() => _SkeletalMeshSubEditorState();
}

class _SkeletalMeshSubEditorState extends _SkeletalMeshSubEditorStateBase
    with
        _SkeletalMeshToolbar,
        _SkeletalMeshLeftSidebar,
        _SkeletalMeshBoneTree,
        _SkeletalMeshInspector {

  /// The live view model, for integration/smoke tests that drive the editor
  /// through the real shell.
  SkeletalMeshEditorViewModel get viewModelForTest => _viewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    final path = widget.assetPath ?? widget.asset?.lmasPath ?? widget.asset?.relativePath ?? 'contents/meshes/skeletal/${widget.assetName}.lmas';
    _viewModel = widget.viewModel ?? SkeletalMeshEditorViewModel(assetPath: path);
    widget.onBind?.call(_viewModel, _viewModel.save, () => _viewModel.isDirty);

    if (_ownsViewModel) {
      _viewModel.load().then((_) {
        if (mounted) {
          setState(() {
            for (final node in _viewModel.allBones) {
              _expandedNodeIndices.add(node.index);
            }
          });
        }
      });
    } else {
      for (final node in _viewModel.allBones) {
        _expandedNodeIndices.add(node.index);
      }
    }
  }

  @override
  void dispose() {
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final isDirty = _viewModel.isDirty;

        if (_viewModel.isLoading) {
          return Container(
            color: EditorColors.background,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading Skeletal Mesh geometry & rig...', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
                ],
              ),
            ),
          );
        }

        if (_viewModel.hasError) {
          return Container(
            color: EditorColors.background,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.triangleAlert, size: 28, color: EditorColors.logError),
                  const SizedBox(height: 8),
                  Text('Failed to load skeletal mesh asset at ${_viewModel.assetPath}', style: const TextStyle(fontSize: 11, color: EditorColors.foreground)),
                  const SizedBox(height: 16),
                  OutlineButton(
                    onPressed: widget.onClose,
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        }

        // Prepare dynamically deformed / recolored GlbMeshData
        GlbMeshData? effectiveMesh;
        if (_viewModel.glbMesh != null) {
          final orig = _viewModel.glbMesh!;
          effectiveMesh = GlbMeshData(
            subPrimitives: orig.subPrimitives,
            positions: _viewModel.deformedPositions(),
            indices: orig.indices,
            uvs: orig.uvs,
            minBounds: orig.minBounds,
            maxBounds: orig.maxBounds,
            baseColor: orig.baseColor,
            vertexColors: _viewModel.heatmapEnabled
                ? _viewModel.heatmapColors(_viewModel.selectedBone?.index)
                : orig.vertexColors,
            rawPayload: orig.rawPayload,
            rootNodes: orig.rootNodes,
            allNodes: orig.allNodes,
            materialNames: orig.materialNames,
            skeletonJointIndices: orig.skeletonJointIndices,
            morphTargets: orig.morphTargets,
            jointsPerVertex: orig.jointsPerVertex,
            weightsPerVertex: orig.weightsPerVertex,
            maxInfluences: orig.maxInfluences,
          );
        }

        return Column(
          children: [
            _buildToolbar(isDirty),
            // The workspace: islands on the ground. Left, the skeleton tree
            // over the morph targets / RigLogic; centre, the viewport;
            // right, the details.
            Expanded(
              child: EditorIslandGround(
                child: ResizablePanel.horizontal(
                  dividerBuilder: EditorIslandDividers.gap,
                  children: [
                    ResizablePane(
                      initialSize: 300,
                      minSize: 240,
                      child: _buildLeftSidebar(),
                    ),
                    ResizablePane.flex(
                      child: EditorIsland(
                        key: const ValueKey('skeletal_mesh_island_viewport'),
                        color: EditorColors.viewportBackdrop,
                        child: Stack(
                          children: [
                          SubEditor3DViewport(
                            title: 'Skeletal Mesh & Rig Viewport',
                            glbMesh: effectiveMesh,
                            initialShape: PreviewShape.mesh,
                            selectedNode: _viewModel.selectedBone,
                            showShapeSelector: true,
                            showBones: _viewModel.showBones,
                            showSockets: _viewModel.displaySockets,
                            sockets: _viewModel.sockets,
                            selectedSocket: _viewModel.selectedSocket,
                            socketAttachments: _viewModel.socketAttachments,
                            morphWeights: Map<String, double>.from(_viewModel.morphWeights),
                            jointDeltas: Map<String, List<double>>.from(_viewModel.jointDeltas),
                            hiddenSectionIndices: _viewModel.hiddenSectionIndices,
                            highlightedSectionIndices: _viewModel.highlightedSectionIndices,
                            sectionMaterialOverrides: _viewModel.slotCompiledMaterials,
                            showSkinWeightHeatmap: _viewModel.heatmapEnabled,
                            skinWeightHeatmapBone: _viewModel.selectedBone?.index,
                            // Bones, skin weights and sockets, toggled from Show.
                            showItems: [
                              ViewportShowItem(label: 'Bones', value: _viewModel.showBones, onChanged: (_) => _viewModel.toggleShowBones()),
                              ViewportShowItem(label: 'Weights', value: _viewModel.heatmapEnabled, onChanged: _viewModel.setHeatmapEnabled),
                              ViewportShowItem(
                                  label: 'Sockets', value: _viewModel.displaySockets, onChanged: (_) => _viewModel.toggleDisplaySockets()),
                            ],
                          ),
                          // The stats box, bottom-left above the stats strip: the pill row
                          // and the tool column own the top-left.
                          Positioned(
                            bottom: 40,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: ViewportPillStyle.decoration(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.purple,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Active Bones: ${_viewModel.boneCount}',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sockets: ${_viewModel.sockets.length} | Max Influences: ${_viewModel.maxInfluences}',
                                    style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                                  ),
                                  Text(
                                    'Triangles: ${_viewModel.triangleCount} | Vertices: ${_viewModel.vertexCount}',
                                    style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                                  ),
                                  Text(
                                    'Active Morph Targets: ${_viewModel.activeMorphTargetCount}',
                                    style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                                  ),
                                  if (_viewModel.hasRigLogic)
                                    Text(
                                      'RigLogic DNA: ${_viewModel.rigLogic!.characterName} (${_viewModel.rigLogicControlNames.length} controls)',
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                  if (_viewModel.heatmapEnabled)
                                    Text(
                                      'Heatmap Bone: ${_viewModel.selectedBone?.name ?? "Select Bone"}',
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange),
                                    ),
                                  if (_viewModel.selectedSocket != null || _viewModel.selectedBone != null)
                                    Text(
                                      'Selected: ${_viewModel.selectedSocket?.name ?? _viewModel.selectedBone?.name}',
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.cyan),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          ],
                        ),
                      ),
                    ),
                    ResizablePane(
                      initialSize: 300,
                      minSize: 240,
                      child: EditorIsland(
                        key: const ValueKey('skeletal_mesh_island_details'),
                        header: const EditorIslandHeader(title: 'Details'),
                        child: _buildRightInspectorPanel(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
