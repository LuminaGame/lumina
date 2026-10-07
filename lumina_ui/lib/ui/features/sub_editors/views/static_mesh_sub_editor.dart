import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina/lumina.dart';
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

class StaticMeshSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final RealAssetInfo? asset;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final StaticMeshEditorViewModel? viewModel;

  const StaticMeshSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.asset,
    this.onClose,
    this.onBind,
    this.viewModel,
  });

  @override
  State<StaticMeshSubEditor> createState() => _StaticMeshSubEditorState();
}

class _StaticMeshSubEditorState extends State<StaticMeshSubEditor> {
  late final StaticMeshEditorViewModel _viewModel;
  late final bool _ownsViewModel;

  final GlobalKey _collisionBtnKey = GlobalKey();
  final GlobalKey _forcedLodBtnKey = GlobalKey();
  int _activeLeftTab = 0; // 0: Stats, 1: LODs, 2: Hierarchy
  GlbNode? _selectedNode;

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

  void _showCollisionMenu() {
    final renderBox = _collisionBtnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final offset = renderBox.localToGlobal(Offset.zero);
      final position = Offset(offset.dx, offset.dy + renderBox.size.height + 2);
      showDropdown(
        context: context,
        // An explicit position is where the menu opens; following the
        // anchor widget would drag it to that widget's bottom centre.
        follow: false,
        // Top-left corner at the point, as editor context menus open.
        alignment: Alignment.topLeft,
        anchorAlignment: Alignment.topLeft,
        position: position,
        builder: (context) => DropdownMenu(
          children: [
            MenuButton(
              leading: const Icon(LucideIcons.box, size: 12),
              child: const Text('Box Collision', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) {
                _viewModel.generateCollision(StaticMeshCollisionShapeType.box);
              },
            ),
            MenuButton(
              leading: const Icon(LucideIcons.circle, size: 12),
              child: const Text('Sphere Collision', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) {
                _viewModel.generateCollision(StaticMeshCollisionShapeType.sphere);
              },
            ),
            MenuButton(
              leading: const Icon(LucideIcons.cylinder, size: 12),
              child: const Text('Capsule Collision', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) {
                _viewModel.generateCollision(StaticMeshCollisionShapeType.capsule);
              },
            ),
            MenuButton(
              leading: const Icon(LucideIcons.triangle, size: 12),
              child: const Text('Convex (hull)', style: TextStyle(fontSize: 10)),
              onPressed: (ctx) {
                _viewModel.generateCollision(StaticMeshCollisionShapeType.convex);
              },
            ),
            const MenuDivider(),
            MenuButton(
              leading: const Icon(LucideIcons.trash2, size: 12, color: EditorColors.logError),
              child: const Text('Remove Collision', style: TextStyle(fontSize: 10, color: EditorColors.logError)),
              onPressed: (ctx) {
                _viewModel.removeCollision();
              },
            ),
          ],
        ),
      );
    }
  }

  void _showForcedLodMenu() {
    final renderBox = _forcedLodBtnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final offset = renderBox.localToGlobal(Offset.zero);
      final position = Offset(offset.dx, offset.dy + renderBox.size.height + 2);
      showDropdown(
        context: context,
        // An explicit position is where the menu opens; following the
        // anchor widget would drag it to that widget's bottom centre.
        follow: false,
        // Top-left corner at the point, as editor context menus open.
        alignment: Alignment.topLeft,
        anchorAlignment: Alignment.topLeft,
        position: position,
        builder: (context) => DropdownMenu(
          children: [
            MenuButton(
              child: Text(
                'Auto Preview (LOD 0)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: _viewModel.forcedLod == null ? FontWeight.bold : FontWeight.normal,
                  color: _viewModel.forcedLod == null ? EditorColors.primary : EditorColors.foreground,
                ),
              ),
              onPressed: (ctx) {
                _viewModel.setForcedLod(null);
              },
            ),
            const MenuDivider(),
            ..._viewModel.lods.map((lod) {
              final isSelected = _viewModel.forcedLod == lod.level;
              return MenuButton(
                child: Text(
                  'LOD ${lod.level} (${(lod.reductionRatio * 100).toInt()}%, ${lod.triangleCount} tris)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? EditorColors.primary : EditorColors.foreground,
                  ),
                ),
                onPressed: (ctx) {
                  _viewModel.setForcedLod(lod.level);
                },
              );
            }),
          ],
        ),
      );
    }
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
          return Container(
            color: EditorColors.background,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
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
                Text('Failed to load static mesh "${widget.assetName}"',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                const SizedBox(height: 6),
                Text('Asset path: ${_viewModel.assetPath}',
                    style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                const SizedBox(height: 16),
                OutlineButton(
                  onPressed: widget.onClose,
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }

        final activeLod = _viewModel.activePreviewLod;

        return Container(
          color: EditorColors.background,
          child: Column(
            children: [
              // Top Toolbar
              _buildToolbar(isDirty),
              const Divider(height: 1),

              // Main Workspace Splitter
              Expanded(
                child: ResizablePanel.horizontal(
                  children: [
                    // 1. Left Panel: Stats, LOD Settings & Hierarchy
                    ResizablePane(
                      initialSize: 280,
                      minSize: 220,
                      child: Container(
                        color: EditorColors.cardHeader,
                        child: Column(
                          children: [
                            // Left Tabs
                            Container(
                              height: 30,
                              color: EditorColors.card,
                              child: Row(
                                children: [
                                  _buildLeftTabBtn(0, 'Mesh Stats'),
                                  _buildLeftTabBtn(1, 'LODs (${_viewModel.lods.length})'),
                                  if (_viewModel.glbMesh?.allNodes.isNotEmpty == true)
                                    _buildLeftTabBtn(2, 'Hierarchy'),
                                ],
                              ),
                            ),
                            const Divider(height: 1),

                            Expanded(
                              child: _activeLeftTab == 0
                                  ? _buildStatsPanel()
                                  : _activeLeftTab == 1
                                      ? _buildLodPanel()
                                      : _buildHierarchyPanel(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 2. Center Panel: 3D Viewport with LOD Stats Overlay
                    ResizablePane.flex(
                      child: Stack(
                        children: [
                          SubEditor3DViewport(
                            title: 'Static Mesh 3D Preview Viewport',
                            glbMesh: _viewModel.glbMesh,
                            initialShape: PreviewShape.mesh,
                            selectedNode: _selectedNode,
                            showShapeSelector: true,
                            // The collision view.
                            collisionLines: _viewModel.collisionOverlayLines,
                          ),
                          // LOD Info Overlay
                          Positioned(
                            top: 48,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: EditorColors.card.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: EditorColors.border),
                              ),
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

                    // 3. Right Panel: Material Slots & Collision Details
                    ResizablePane(
                      initialSize: 280,
                      minSize: 230,
                      child: Container(
                        color: EditorColors.cardHeader,
                        child: _buildRightPanel(),
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

  Widget _buildToolbar(bool isDirty) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.card,
      child: Row(
        children: [
          const OutlineBadge(
            child: Text('STATIC MESH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyan)),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.assetName}${isDirty ? ' *' : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground),
          ),
          const SizedBox(width: 12),

          // Forced LOD Selector
          OutlineButton(
            key: _forcedLodBtnKey,
            size: ButtonSize.small,
            onPressed: _showForcedLodMenu,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.layers, size: 12, color: Colors.cyan),
                const SizedBox(width: 4),
                Text(
                  _viewModel.forcedLod == null ? 'Forced LOD: Auto (0)' : 'Forced LOD: ${_viewModel.forcedLod}',
                  style: const TextStyle(fontSize: 10),
                ),
                const SizedBox(width: 2),
                const Icon(LucideIcons.chevronDown, size: 10),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Collision Shape Count Badge
          OutlineBadge(
            child: Text(
              '${_viewModel.collisionShapes.length} Collision Shape${_viewModel.collisionShapes.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 9),
            ),
          ),
          const Spacer(),

          // Collision Generation Dropdown
          OutlineButton(
            key: _collisionBtnKey,
            size: ButtonSize.small,
            onPressed: _showCollisionMenu,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.shield, size: 12, color: Colors.amber),
                SizedBox(width: 4),
                Text('Collision', style: TextStyle(fontSize: 10)),
                SizedBox(width: 2),
                Icon(LucideIcons.chevronDown, size: 10),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Collision Wireframe Toggle
          GhostButton(
            size: ButtonSize.small,
            onPressed: _viewModel.toggleCollisionWireframe,
            child: Icon(
              LucideIcons.eye,
              size: 14,
              color: _viewModel.showCollisionWireframe ? EditorColors.primary : EditorColors.mutedForeground,
            ),
          ),
          const SizedBox(width: 8),

          // Save Button
          PrimaryButton(
            size: ButtonSize.small,
            onPressed: () => _viewModel.save(),
            child: const Text('Save', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),

          // Close Button
          GhostButton(
            size: ButtonSize.small,
            onPressed: widget.onClose,
            child: const Icon(LucideIcons.x, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftTabBtn(int index, String label) {
    final isActive = _activeLeftTab == index;
    return Clickable(
      onPressed: () => setState(() => _activeLeftTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? EditorColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? EditorColors.primary : EditorColors.mutedForeground,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsPanel() {
    final vm = _viewModel;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Row(
          children: [
            Icon(LucideIcons.chartColumn, size: 12, color: Colors.cyan),
            SizedBox(width: 6),
            Text('MESH STATISTICS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyan)),
          ],
        ),
        const SizedBox(height: 10),
        _buildStatRow('Triangles', '${vm.triangleCount}'),
        _buildStatRow('Vertices', '${vm.vertexCount}'),
        _buildStatRow('UV Channels', '${vm.uvChannelsCount}'),
        _buildStatRow('Sections', '${vm.sectionCount}'),
        _buildStatRow(
          'Bounds',
          // cm, W × D × H along X × Y × Z.
          '${vm.boundsWidth.toStringAsFixed(1)} × ${vm.boundsDepth.toStringAsFixed(1)} × ${vm.boundsHeight.toStringAsFixed(1)} cm',
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),

        const Row(
          children: [
            Icon(LucideIcons.ruler, size: 12, color: EditorColors.mutedForeground),
            SizedBox(width: 6),
            Text('BOUNDING BOX EXTENTS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          ],
        ),
        const SizedBox(height: 8),
        _buildStatRow('Min Bounds (cm)', '[${vm.minBounds.map((e) => e.toStringAsFixed(1)).join(', ')}]'),
        _buildStatRow('Max Bounds (cm)', '[${vm.maxBounds.map((e) => e.toStringAsFixed(1)).join(', ')}]'),
      ],
    );
  }

  Widget _buildLodPanel() {
    final vm = _viewModel;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // LOD Global Settings
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.layers, size: 12, color: Colors.cyan),
                SizedBox(width: 6),
                Text('LOD SETTINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyan)),
              ],
            ),
            OutlineButton(
              size: ButtonSize.small,
              onPressed: vm.lods.length < 4 ? () => vm.addLod() : null,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.plus, size: 10),
                  SizedBox(width: 4),
                  Text('Add LOD', style: TextStyle(fontSize: 9.5)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // LOD Group Selector
        const Text('LOD Group Preset', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        Select<String>(
          value: vm.lodGroup,
          onChanged: (val) {
            if (val != null) vm.setLodGroup(val);
          },
          itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 10.5)),
          popup: SelectPopup(
            items: SelectItemList(
              children: const [
                SelectItemButton(value: 'SmallProp', child: Text('Small Prop')),
                SelectItemButton(value: 'LargeProp', child: Text('Large Prop')),
                SelectItemButton(value: 'Foliage', child: Text('Foliage')),
                SelectItemButton(value: 'Architecture', child: Text('Architecture')),
                SelectItemButton(value: 'Decal', child: Text('Decal')),
              ],
            ),
          ).call,
        ),
        const SizedBox(height: 12),

        // Auto Compute Distances Switch
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Auto Compute Distances', style: TextStyle(fontSize: 9.5, color: EditorColors.foreground)),
            Switch(
              value: vm.autoComputeLodDistances,
              onChanged: (val) => vm.setAutoComputeLodDistances(val),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // LOD Slots List
        ...vm.lods.map((lod) => _buildLodSlotCard(lod)),
      ],
    );
  }

  Widget _buildLodSlotCard(LodSlot lod) {
    final vm = _viewModel;
    final isBase = lod.level == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LOD ${lod.level} ${isBase ? '(Source)' : ''}',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: EditorColors.foreground),
              ),
              OutlineBadge(
                child: Text('${lod.triangleCount} tris', style: const TextStyle(fontSize: 9)),
              ),
              if (!isBase)
                GhostButton(
                  size: ButtonSize.small,
                  onPressed: () => vm.removeLod(lod.level),
                  child: const Icon(LucideIcons.trash2, size: 12, color: EditorColors.logError),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Reduction Ratio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Reduction: ', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
              Text('${(lod.reductionRatio * 100).toInt()}%',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
            ],
          ),
          if (!isBase)
            SliderField(
              key: ValueKey('static_mesh_lod_ratio_${lod.level}'),
              value: lod.reductionRatio,
              defaultValue: 0.5,
              min: 0.05,
              max: 1.0,
              onChanged: (v) => vm.setLodRatio(lod.level, v),
              onCommit: (v) => vm.setLodRatio(lod.level, v),
              onReset: () => vm.setLodRatio(lod.level, 0.5),
            ),
          const SizedBox(height: 6),

          // Screen Size Threshold
          Row(
            children: [
              const Text('Screen Size: ', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
              const Spacer(),
              SizedBox(
                width: 70,
                child: SyncedTextField(
                  key: ValueKey('static_mesh_lod_screen_size_${lod.level}'),
                  text: lod.screenSize.toStringAsFixed(2),
                  enabled: !isBase,
                  onChanged: (val) {
                    final parsed = double.tryParse(val);
                    if (parsed != null) vm.setLodScreenSize(lod.level, parsed);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          Text(
            value,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyPanel() {
    final glb = _viewModel.glbMesh;
    if (glb == null || glb.allNodes.isEmpty) {
      return const Center(
        child: Text('No scene nodes found in mesh', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
      );
    }

    return SubEditorHierarchyWidget(
      rootNodes: glb.rootNodes,
      allNodes: glb.allNodes,
      selectedNode: _selectedNode,
      onNodeSelected: (node) => setState(() => _selectedNode = node),
    );
  }

  Widget _buildRightPanel() {
    final vm = _viewModel;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 1. Material Slots Accordion
        Row(
          children: [
            const Icon(LucideIcons.palette, size: 12, color: EditorColors.primary),
            const SizedBox(width: 6),
            Text('MATERIAL SLOTS (${vm.materialSlots.length})',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary)),
          ],
        ),
        const SizedBox(height: 8),
        ...vm.materialSlots.map((slot) => _buildMaterialSlotRow(slot)),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // 2. Collision Settings Accordion
        const Row(
          children: [
            Icon(LucideIcons.shield, size: 12, color: Colors.amber),
            SizedBox(width: 6),
            Text('COLLISION SETTINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Collision Complexity', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        Select<String>(
          value: vm.collisionComplexity,
          onChanged: (val) {
            if (val != null) vm.setCollisionComplexity(val);
          },
          itemBuilder: (context, item) {
            String label = 'Default';
            if (item == 'use_complex_as_simple') label = 'Use Complex As Simple';
            if (item == 'use_simple_as_complex') label = 'Use Simple As Complex';
            return Text(label, style: const TextStyle(fontSize: 10.5));
          },
          popup: SelectPopup(
            items: SelectItemList(
              children: const [
                SelectItemButton(value: 'default', child: Text('Default')),
                SelectItemButton(value: 'use_complex_as_simple', child: Text('Use Complex Collision As Simple')),
                SelectItemButton(value: 'use_simple_as_complex', child: Text('Use Simple Collision As Complex')),
              ],
            ),
          ).call,
        ),
        // The runtime has no per-triangle shape.
        if (vm.collisionComplexity == 'use_complex_as_simple') ...[
          const SizedBox(height: 4),
          const Text(
            'No per-triangle collision at runtime yet: this mesh plays with its simple collision, as Default.',
            style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
          ),
        ],
        const SizedBox(height: 8),
        Text('Generated Shapes: ${vm.collisionShapes.length}',
            style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // 3. Physics Settings Accordion
        const Row(
          children: [
            Icon(LucideIcons.activity, size: 12, color: Colors.green),
            SizedBox(width: 6),
            Text('PHYSICS PROPERTIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Mass (Kg)', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        SyncedTextField(
          key: const ValueKey('static_mesh_mass_field'),
          text: vm.massKg.toStringAsFixed(1),
          onChanged: (val) {
            final parsed = double.tryParse(val);
            if (parsed != null) vm.setMass(parsed);
          },
        ),
      ],
    );
  }

  Widget _buildMaterialSlotRow(MaterialSlotBinding slot) {
    final isBound = slot.assignedMaterialPath != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isBound ? Colors.cyan : EditorColors.mutedForeground,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text('Element ${slot.index} (${slot.slotName})',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
              const Spacer(),
              // Highlight Button
              GhostButton(
                size: ButtonSize.small,
                onPressed: () => _viewModel.highlightMaterial(slot.index, !slot.isHighlighted),
                child: Icon(
                  LucideIcons.sparkles,
                  size: 11,
                  color: slot.isHighlighted ? Colors.amber : EditorColors.mutedForeground,
                ),
              ),
              // Isolate Button
              GhostButton(
                size: ButtonSize.small,
                onPressed: () => _viewModel.isolateMaterial(slot.index, !slot.isIsolated),
                child: Icon(
                  LucideIcons.eyeOff,
                  size: 11,
                  color: slot.isIsolated ? Colors.cyan : EditorColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_viewModel.availableMaterials.isEmpty)
            Text(
              isBound ? slot.assignedMaterialPath! : '— unbound — (no materials in this project yet)',
              style: TextStyle(
                fontSize: 9,
                color: isBound ? Colors.cyan : EditorColors.mutedForeground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else
            AssetPickerSelect(
              key: ValueKey('static_mesh_material_slot_${slot.index}'),
              keyPrefix: 'static_mesh_material_picker_${slot.index}',
              placeholder: '— unbound —',
              selectedPath: slot.assignedMaterialPath,
              assets: _viewModel.availableMaterials,
              onSelected: (asset) {
                final path = asset.lmasPath;
                if (path == null) return;
                _viewModel.assignMaterial(
                  slot.index,
                  materialAssetPath: path,
                  materialAssetId: asset.assetId ?? asset.fileName,
                );
              },
              onCleared: () => _viewModel.clearMaterial(slot.index),
            ),
        ],
      ),
    );
  }
}
