part of '../physics_asset_sub_editor.dart';

/// Toolbar, the mesh binder shown before a skeletal mesh is bound, and
/// the workspace (preview viewport framing and panel layout).
mixin _PhysicsAssetToolbarWorkspace on _PhysicsAssetSubEditorStateBase {

  // ------------------------------------------------------------- toolbar

  Widget _buildToolbar() {
    final errors = _viewModel.validationErrors;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('PHYSICS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.purple)),
          ),
          const SizedBox(width: 8),
          Text(widget.assetName,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
          if (_viewModel.isDirty)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('*', style: TextStyle(fontSize: 12, color: Colors.orange)),
            ),
          const SizedBox(width: 12),
          SizedBox(
            width: 170,
            child: Select<PhysicsViewMode>(
              key: const ValueKey('physics_view_mode'),
              value: _viewModel.viewMode,
              onChanged: (m) {
                if (m != null) _viewModel.setViewMode(m);
              },
              itemBuilder: (context, m) => Text(m.label, style: const TextStyle(fontSize: 9.5)),
              popup: SelectPopup(
                items: SelectItemList(
                  children: PhysicsViewMode.values
                      .map((m) => SelectItemButton(value: m, child: Text(m.label)))
                      .toList(),
                ),
              ).call,
            ),
          ),
          const Spacer(),
          if (errors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  const Icon(LucideIcons.triangleAlert, size: 12, color: EditorColors.logError),
                  const SizedBox(width: 4),
                  Text(errors.first, style: const TextStyle(fontSize: 9, color: EditorColors.logError)),
                ],
              ),
            ),
          OutlineButton(
            key: const ValueKey('physics_validate_overlaps'),
            size: ButtonSize.small,
            onPressed: _viewModel.document.bodies.length < 2 ? null : _viewModel.validateOverlaps,
            child: const Text('Validate Overlaps', style: TextStyle(fontSize: 9)),
          ),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const ValueKey('physics_save'),
            size: ButtonSize.small,
            onPressed: _viewModel.isDirty && errors.isEmpty ? () => _viewModel.save() : null,
            child: const Text('Save', style: TextStyle(fontSize: 9)),
          ),
          if (widget.onClose != null) ...[
            const SizedBox(width: 6),
            GhostButton(
              key: const ValueKey('physics_close'),
              onPressed: widget.onClose!,
              child: const Icon(LucideIcons.x, size: 14),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------- mesh binding

  Widget _buildMeshBinder() {
    final candidates = widget.skeletalMeshCandidates;
    return Center(
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: EditorColors.card,
          border: Border.all(color: EditorColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.triangleAlert, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('No skeletal mesh bound',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _viewModel.linkError ?? 'This physics asset has no skeletal_mesh reference.',
              style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
            ),
            const SizedBox(height: 14),
            if (candidates.isEmpty)
              const Text(
                'No skeletal mesh assets exist in this project yet — import one through the Content Browser first.',
                style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
              )
            else ...[
              const Text('Skeletal Mesh', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
              const SizedBox(height: 4),
              AssetPickerSelect(
                key: const ValueKey('physics_mesh_picker'),
                keyPrefix: 'physics_mesh',
                assets: candidates,
                selectedPath: _pendingMeshBinding,
                placeholder: 'Select a skeletal mesh',
                allowClear: false,
                onSelected: (a) => setState(() => _pendingMeshBinding = a.lmasPath ?? a.relativePath),
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                key: const ValueKey('physics_bind_mesh'),
                size: ButtonSize.small,
                onPressed: _pendingMeshBinding == null
                    ? null
                    : () {
                        final picked = candidates.firstWhere(
                          (a) => (a.lmasPath ?? a.relativePath) == _pendingMeshBinding,
                        );
                        _viewModel.bindSkeletalMesh(
                          picked.lmasPath ?? picked.relativePath,
                          assetId: picked.assetId,
                        );
                      },
                child: const Text('Bind Skeletal Mesh', style: TextStyle(fontSize: 9)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ({Vector3 target, double distance})? _previewFraming() {
    if (_framedMeshPath != _viewModel.skeletalMeshPath || _framing == null) {
      _framedMeshPath = _viewModel.skeletalMeshPath;
      _framing = _viewModel.previewFraming;
    }
    return _framing;
  }

  Widget _buildWorkspace() {
    final framing = _previewFraming();
    // A cm grid under the mesh: 10 cm cells, out past the mesh's footprint.
    final bounds = _viewModel.meshWorldBounds;
    final span = bounds == null ? 0.0 : (bounds.max - bounds.min).length;
    final gridExtent = math.max(200.0, (span * 1.5 / 100.0).ceil() * 100.0);
    return ResizablePanel.horizontal(
      children: [
        ResizablePane(
          initialSize: 280,
          minSize: 220,
          child: Container(color: EditorColors.cardHeader, child: _buildTreePanel()),
        ),
        ResizablePane.flex(
          child: Stack(
            children: [
              // The mesh is drawn by the preview scene, through lumina, at the
              // scale the bodies are authored in (cm): the viewport's own GLB
              // path is not taken in a preview world.
              SubEditor3DViewport(
                key: ValueKey('physics_viewport_${_viewModel.skeletalMeshPath}'),
                title: 'Physics Asset Viewport — ${_viewModel.viewMode.label}',
                initialShape: PreviewShape.mesh,
                showShapeSelector: false,
                yUpCamera: true,
                initialCameraDistance: framing?.distance,
                initialCameraTarget: framing?.target,
                gridExtent: gridExtent,
                gridStep: 10.0,
                statsLabel: 'Tris: ${_viewModel.glbMesh?.triangleCount ?? 0} · '
                    'Bones: ${_viewModel.allBones.length} · Bodies: ${_viewModel.document.bodies.length} · cm',
                onPreviewWorldReady: (world) {
                  _previewScene.attach(world);
                  _syncOverlay();
                },
                onPreviewWorldDisposing: (_) => _previewScene.detach(),
              ),
              Positioned(
                top: 48,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: EditorColors.card.withValues(alpha: 0.85),
                    border: Border.all(color: EditorColors.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Bodies: ${_viewModel.document.bodies.length}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                      Text('Constraints: ${_viewModel.document.constraints.length}',
                          style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                      Text('Collision disables: ${_viewModel.document.disabledCollisionPairs.length}',
                          style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                      Text('Bones: ${_viewModel.allBones.length}',
                          style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                    ],
                  ),
                ),
              ),
              if (_viewModel.hasValidated)
                Positioned(left: 12, right: 12, bottom: 12, child: _buildValidationPanel()),
            ],
          ),
        ),
        ResizablePane(
          initialSize: 300,
          minSize: 240,
          child: Container(color: EditorColors.cardHeader, child: _buildInspector()),
        ),
      ],
    );
  }
}
