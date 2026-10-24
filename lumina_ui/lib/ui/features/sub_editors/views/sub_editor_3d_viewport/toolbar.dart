part of '../sub_editor_3d_viewport.dart';

/// The viewport chrome in the Aurora design language: the pill row
/// top-left (shading mode, projection, scene lights, preview shape, the
/// transform space and snaps), the tool column under it while a gizmo is
/// active, and Reset View top-right.
mixin _SubEditor3DViewportToolbar
    on _SubEditor3DViewportStateBase, _SubEditor3DViewportCamera, _SubEditor3DViewportGizmo, _SubEditor3DViewportOverlays {
  static String _title(String name) => name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}';

  Widget _buildToolbar() {
    final gizmo = _effectiveGizmo;
    return Positioned(
      top: ViewportPillStyle.inset,
      left: ViewportPillStyle.inset,
      right: ViewportPillStyle.inset,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: ViewportPillStyle.gap,
                    runSpacing: ViewportPillStyle.gap,
                    children: [
                      ViewportPill(
                        key: const ValueKey('sub_viewport_shading'),
                        icon: LucideIcons.sun,
                        label: _title(_shadingMode.name),
                        tooltip: 'View mode',
                        menu: () => [
                          for (final m in ViewportShadingMode.values)
                            viewportMenuItem(_title(m.name), checked: _shadingMode == m, onPressed: () => _updateShadingMode(m)),
                        ],
                      ),
                      ViewportPill(
                        key: const ValueKey('sub_viewport_projection'),
                        icon: LucideIcons.video,
                        label: _perspective,
                      ),
                      if (widget.hasSceneLights) _sceneLightsToggle(),
                      if (widget.showShapeSelector)
                        ViewportPill(
                          key: const ValueKey('sub_viewport_shape'),
                          icon: LucideIcons.shapes,
                          label: _title(_shape.name),
                          tooltip: 'Preview shape',
                          menu: () => [
                            for (final s in PreviewShape.values.where((s) => s != PreviewShape.mesh))
                              viewportMenuItem(_title(s.name), checked: _shape == s, onPressed: () => _selectShape(s)),
                          ],
                        ),
                      if (widget.showItems.isNotEmpty)
                        ViewportPill(
                          key: const ValueKey('sub_viewport_show'),
                          icon: LucideIcons.eye,
                          label: 'Show · ${widget.showItems.where((i) => i.value).length}',
                          tooltip: 'Overlays drawn in the viewport',
                          menu: () => [
                            for (final item in widget.showItems)
                              viewportMenuItem(item.label,
                                  key: ValueKey('sub_viewport_show_${item.label.toLowerCase()}'),
                                  checked: item.value,
                                  onPressed: () => item.onChanged(!item.value)),
                          ],
                        ),
                      if (gizmo != null) TransformGizmoToolbar(gizmo: gizmo),
                    ],
                  ),
                  if (gizmo != null) ...[
                    const SizedBox(height: 8),
                    TransformGizmoToolColumn(gizmo: gizmo, onFocus: _resetCamera),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          ViewportPill(
            key: const ValueKey('sub_viewport_reset_view'),
            icon: LucideIcons.rotateCcw,
            label: 'Reset View',
            tooltip: 'Back to the framing the editor opened with',
            onPressed: _resetCamera,
          ),
        ],
      ),
    );
  }

  void _selectShape(PreviewShape s) => setState(() {
        _shape = s;
        if (_isMaterialPreview) {
          _materialPreview.setShape(s);
          if (_materialFramed) {
            _cameraDistance = _materialFitDistance();
            _updateNativeCamera();
          }
        }
      });

  Widget _sceneLightsToggle() {
    final active = widget.renderSceneLights;
    return ViewportPill(
      key: const ValueKey('sub_viewport_toggle_scene_lights'),
      icon: LucideIcons.lightbulb,
      accentIcon: active,
      highlighted: active,
      label: 'Scene Lights',
      tooltip: active
          ? 'Scene Lights: Active (using authored lights in scene)'
          : 'Scene Lights: Inactive (using studio daylight sun/sky)',
      onPressed: () => widget.onToggleSceneLights?.call(!active),
    );
  }
}
