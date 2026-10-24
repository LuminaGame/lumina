import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/widgets/editor_island.dart';
import 'package:lumina_ui/ui/core/widgets/viewport_pills.dart' show ViewportPillStyle, ViewportShowItem;
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/property_editors/synced_text_field.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/static_mesh_collision.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_slot_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/static_mesh_lod.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/static_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_hierarchy_widget.dart';

part 'static_mesh_sub_editor/state.dart';
part 'static_mesh_sub_editor/toolbar.dart';
part 'static_mesh_sub_editor/left_panel.dart';
part 'static_mesh_sub_editor/right_panel.dart';

class StaticMeshSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final RealAssetInfo? asset;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final StaticMeshEditorViewModel? viewModel;

  const StaticMeshSubEditor({super.key, required this.assetName, this.assetPath, this.asset, this.onClose, this.onBind, this.viewModel});

  @override
  State<StaticMeshSubEditor> createState() => _StaticMeshSubEditorState();
}

class _StaticMeshSubEditorState extends _StaticMeshSubEditorStateBase
    with _StaticMeshSubEditorToolbar, _StaticMeshSubEditorLeftPanel, _StaticMeshSubEditorRightPanel {
  /// The editor's view model, for the smoke.
  @visibleForTesting
  StaticMeshEditorViewModel get viewModelForTest => _viewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    final path = widget.assetPath ?? widget.asset?.lmasPath ?? 'contents/meshes/static/${widget.assetName}.lmas';
    _viewModel = widget.viewModel ?? StaticMeshEditorViewModel(assetPath: path);
    widget.onBind?.call(_viewModel, _viewModel.save, () => _viewModel.isDirty);

    if (_ownsViewModel) {
      _viewModel.load();
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
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        final isDirty = _viewModel.isDirty;
        final hasError = _viewModel.hasError;
        final isLoading = _viewModel.isLoading;

        if (isLoading) {
          return Container(color: EditorColors.background, alignment: Alignment.center, child: const CircularProgressIndicator());
        }

        if (hasError) {
          return Container(
            color: EditorColors.background,
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.triangleAlert, size: 36, color: EditorColors.logError),
                const SizedBox(height: 12),
                Text(
                  'Failed to load static mesh "${widget.assetName}"',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                ),
                const SizedBox(height: 6),
                Text('Asset path: ${_viewModel.assetPath}', style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                const SizedBox(height: 16),
                OutlineButton(onPressed: widget.onClose, child: const Text('Close')),
              ],
            ),
          );
        }

        final activeLod = _viewModel.activePreviewLod;

        final hasHierarchy = _viewModel.glbMesh?.allNodes.isNotEmpty == true;
        final leftTab = hasHierarchy ? _activeLeftTab : 0;

        return Column(
          children: [
            _buildToolbar(isDirty),
            // The workspace: islands on the ground. Left, the LODs (and the
            // node hierarchy) over the mesh stats; centre, the viewport;
            // right, the details.
            Expanded(
              child: EditorIslandGround(
                child: ResizablePanel.horizontal(
                  dividerBuilder: EditorIslandDividers.gap,
                  children: [
                    ResizablePane(
                      initialSize: 280,
                      minSize: 220,
                      child: ResizablePanel.vertical(
                        dividerBuilder: EditorIslandDividers.grip,
                        children: [
                          ResizablePane.flex(
                            child: EditorIsland(
                              key: const ValueKey('static_mesh_island_lods'),
                              header: EditorIslandTabHeader(
                                keyPrefix: 'static_mesh_left',
                                tabs: ['LODs (${_viewModel.lods.length})', if (hasHierarchy) 'Hierarchy'],
                                active: leftTab,
                                onSelect: (i) => setState(() => _activeLeftTab = i),
                              ),
                              child: leftTab == 0 ? _buildLodPanel() : _buildHierarchyPanel(),
                            ),
                          ),
                          ResizablePane(
                            initialSize: 230,
                            minSize: 120,
                            child: EditorIsland(
                              key: const ValueKey('static_mesh_island_stats'),
                              header: const EditorIslandHeader(title: 'Mesh stats'),
                              child: _buildStatsPanel(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ResizablePane.flex(
                      child: EditorIsland(
                        key: const ValueKey('static_mesh_island_viewport'),
                        color: EditorColors.viewportBackdrop,
                        child: Stack(
                          children: [
                            SubEditor3DViewport(
                              title: 'Static Mesh 3D Preview Viewport',
                              glbMesh: _viewModel.glbMesh,
                              initialShape: PreviewShape.mesh,
                              selectedNode: _selectedNode,
                              showShapeSelector: true,
                              // The collision view and the bounds box, toggled from Show.
                              collisionLines: _viewModel.collisionOverlayLines,
                              overlayLines: [?_viewModel.boundsLineSet],
                              showItems: [
                                ViewportShowItem(
                                  label: 'Collision',
                                  value: _viewModel.showCollisionWireframe,
                                  onChanged: _viewModel.setShowCollisionWireframe,
                                ),
                                ViewportShowItem(label: 'Bounds', value: _viewModel.showBounds, onChanged: _viewModel.setShowBounds),
                              ],
                            ),
                            // LOD Info Overlay, bottom-left above the stats strip:
                            // the pill row owns the top.
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
                                            color: activeLod.level == 0 ? Colors.green : Colors.amber,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'LOD ${activeLod.level} ${activeLod.level == 0 ? '(Source)' : '(${(activeLod.reductionRatio * 100).toInt()}%)'}',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Triangles: ${activeLod.triangleCount} | Vertices: ${activeLod.vertexCount}',
                                      style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                                    ),
                                    Text(
                                      'Screen Size: ${(activeLod.screenSize * 100).toStringAsFixed(1)}%',
                                      style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
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
                      initialSize: 280,
                      minSize: 230,
                      child: EditorIsland(
                        key: const ValueKey('static_mesh_island_details'),
                        header: const EditorIslandHeader(title: 'Details'),
                        child: _buildRightPanel(),
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
