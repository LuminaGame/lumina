part of '../sub_editor_3d_viewport.dart';

/// The top toolbar HUD: shading mode, perspective label, scene lights,
/// gizmo tools, preview shape and Reset View.
mixin _SubEditor3DViewportToolbar
    on _SubEditor3DViewportStateBase, _SubEditor3DViewportCamera, _SubEditor3DViewportGizmo, _SubEditor3DViewportOverlays {
  Widget _buildToolbar() {
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Row(
        children: [
          // Shading Mode Selector
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: EditorColors.border),
            ),
            child: Row(
              children: ViewportShadingMode.values.map((m) {
                final sel = _shadingMode == m;
                return GestureDetector(
                  onTap: () => _updateShadingMode(m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: sel
                          ? EditorColors.primary.withValues(alpha: 0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      m.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: sel
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: sel
                            ? EditorColors.primary
                            : EditorColors.foreground,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 8),

          // Perspective Label
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: EditorColors.border),
            ),
            child: Text(
              _perspective,
              style: const TextStyle(
                fontSize: 9,
                color: EditorColors.foreground,
              ),
            ),
          ),

          if (widget.hasSceneLights) ...[
            const SizedBox(width: 8),
            _sceneLightsToggle(),
          ],

          if (_effectiveGizmo != null) ...[
            const SizedBox(width: 8),
            _gizmoToolCluster(_effectiveGizmo!),
          ],

          if (widget.showShapeSelector) ...[
            const SizedBox(width: 8),
            // Shape Selector
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: EditorColors.border),
              ),
              child: Row(
                children: PreviewShape.values
                    .where((s) => s != PreviewShape.mesh)
                    .map((s) {
                      final sel = _shape == s;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _shape = s;
                          if (_isMaterialPreview) {
                            _materialPreview.setShape(s);
                            if (_materialFramed) {
                              _cameraDistance = _materialFitDistance();
                              _updateNativeCamera();
                            }
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: sel
                                ? EditorColors.primary.withValues(
                                    alpha: 0.3,
                                  )
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            s.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: sel
                                  ? EditorColors.primary
                                  : EditorColors.foreground,
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
          ],

          const Spacer(),

          // Reset Camera Button
          GhostButton(
            onPressed: _resetCamera,
            child: const Row(
              children: [
                Icon(
                  LucideIcons.rotateCcw,
                  size: 11,
                  color: EditorColors.primary,
                ),
                SizedBox(width: 4),
                Text(
                  'Reset View',
                  style: TextStyle(
                    fontSize: 9,
                    color: EditorColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sceneLightsToggle() {
    final active = widget.renderSceneLights;
    return Tooltip(
      tooltip: (context) => TooltipContainer(
        child: Text(
          active
              ? 'Scene Lights: Active (using authored lights in scene)'
              : 'Scene Lights: Inactive (using studio daylight sun/sky)',
        ),
      ),
      child: GestureDetector(
        key: const ValueKey('sub_viewport_toggle_scene_lights'),
        onTap: () => widget.onToggleSceneLights?.call(!active),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: active
                ? EditorColors.primary.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: active ? EditorColors.primary : EditorColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.lightbulb,
                size: 11,
                color: active ? EditorColors.primary : EditorColors.foreground,
              ),
              const SizedBox(width: 4),
              Text(
                'SCENE LIGHTS',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? EditorColors.primary : EditorColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
