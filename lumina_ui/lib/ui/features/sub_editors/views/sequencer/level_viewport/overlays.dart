part of '../level_viewport.dart';

/// The viewport's overlays: letterbox bars, gizmo tool strip and camera HUD.
extension _SequencerLevelViewportOverlays on SequencerLevelViewportState {
  /// Black bars outside the film gate.
  List<Widget> _letterbox(Rect gate) {
    const bar = ColoredBox(color: Colors.black);
    return [
      if (gate.top > 0) ...[
        Positioned(left: 0, right: 0, top: 0, height: gate.top, child: bar),
        Positioned(left: 0, right: 0, bottom: 0, height: _size.height - gate.bottom, child: bar),
      ],
      if (gate.left > 0) ...[
        Positioned(left: 0, top: 0, bottom: 0, width: gate.left, child: bar),
        Positioned(right: 0, top: 0, bottom: 0, width: _size.width - gate.right, child: bar),
      ],
    ];
  }

  /// Move / Rotate / Scale (W/E/R), World/Local and the three snap toggles:
  /// the level viewport's own settings.
  Widget _buildGizmoTools() {
    Widget button({
      required Key key,
      required IconData icon,
      required bool active,
      required String tip,
      required VoidCallback onPressed,
      String? label,
    }) {
      final color = active ? EditorColors.primary : EditorColors.foreground;
      return Tooltip(
        tooltip: (_) => TooltipContainer(child: Text(tip, style: const TextStyle(fontSize: 9))),
        child: GestureDetector(
          key: key,
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: active ? EditorColors.primary.withValues(alpha: 0.3) : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 11, color: color),
              if (label != null) ...[
                const SizedBox(width: 3),
                Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
              ],
            ]),
          ),
        ),
      );
    }

    final mode = _gizmoMode;
    final local = _evm.gizmoSpace == 'local';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: EditorColors.hudSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
              key: const ValueKey('seq_gizmo_translate'),
              icon: LucideIcons.move,
              active: mode == GizmoMode.translate,
              tip: 'Move (W)',
              onPressed: () => _evm.setActiveTool('translate')),
          button(
              key: const ValueKey('seq_gizmo_rotate'),
              icon: LucideIcons.rotateCcw,
              active: mode == GizmoMode.rotate,
              tip: 'Rotate (E)',
              onPressed: () => _evm.setActiveTool('rotate')),
          button(
              key: const ValueKey('seq_gizmo_scale'),
              icon: LucideIcons.maximize2,
              active: mode == GizmoMode.scale,
              tip: 'Scale (R)',
              onPressed: () => _evm.setActiveTool('scale')),
          const SizedBox(width: 4),
          button(
              key: const ValueKey('seq_gizmo_space'),
              icon: local ? LucideIcons.box : LucideIcons.globe,
              active: local,
              label: local ? 'LOCAL' : 'WORLD',
              tip: local ? 'Local space (click for World)' : 'World space (click for Local)',
              onPressed: _evm.toggleGizmoSpace),
          const SizedBox(width: 4),
          button(
              key: const ValueKey('seq_gizmo_snap_translate'),
              icon: LucideIcons.magnet,
              active: _evm.translateSnapEnabled,
              tip: 'Grid snap (${_evm.translateSnapStep} cm)',
              onPressed: () => _evm.updateTranslateSnapEnabled(!_evm.translateSnapEnabled)),
          button(
              key: const ValueKey('seq_gizmo_snap_rotate'),
              icon: LucideIcons.rotateCw,
              active: _evm.rotateSnapEnabled,
              tip: 'Rotation snap (${_evm.rotateSnapStep}°)',
              onPressed: () => _evm.updateRotateSnapEnabled(!_evm.rotateSnapEnabled)),
          button(
              key: const ValueKey('seq_gizmo_snap_scale'),
              icon: LucideIcons.scaling,
              active: _evm.scaleSnapEnabled,
              tip: 'Scale snap (${_evm.scaleSnapStep})',
              onPressed: () => _evm.updateScaleSnapEnabled(!_evm.scaleSnapEnabled)),
        ],
      ),
    );
  }

  Widget _buildHud(EditorActorNode? locked) {
    final cameras = cameraCandidates;
    const editorValue = '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: EditorColors.hudSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(locked != null ? LucideIcons.video : LucideIcons.move3d, size: 12, color: locked != null ? Colors.amber : EditorColors.foreground),
          const SizedBox(width: 6),
          SizedBox(
            width: 170,
            child: Select<String>(
              key: const ValueKey('seq_viewport_camera'),
              value: _lockedCameraId ?? editorValue,
              onChanged: (v) => lockToCamera(v == null || v.isEmpty ? null : v),
              itemBuilder: (context, id) => Text(
                id.isEmpty ? 'Editor Camera' : 'Lock: ${cameras.where((c) => c.id == id).firstOrNull?.name ?? id}',
                style: const TextStyle(fontSize: 9.5),
              ),
              popup: SelectPopup(
                items: SelectItemList(
                  children: [
                    const SelectItemButton(value: editorValue, child: Text('Editor Camera', style: TextStyle(fontSize: 9.5))),
                    for (final c in cameras)
                      SelectItemButton(value: c.id, child: Text('Lock: ${c.name}', style: const TextStyle(fontSize: 9.5))),
                  ],
                ),
              ).call,
            ),
          ),
          if (locked == null) ...[
            const SizedBox(width: 4),
            Tooltip(
              tooltip: (_) => const TooltipContainer(
                child: Text('Frame the animated actors (F)\nDrag: orbit · Middle-drag / Shift+drag: pan\nWheel: dolly · Right button + WASD/QE: fly',
                    style: TextStyle(fontSize: 9)),
              ),
              child: GhostButton(
                key: const ValueKey('seq_viewport_focus'),
                size: ButtonSize.small,
                onPressed: focusAnimatedActors,
                child: const Icon(LucideIcons.scan, size: 12),
              ),
            ),
          ] else ...[
            const SizedBox(width: 8),
            Text('PILOTING ${locked.name}',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
          ],
        ],
      ),
    );
  }
}
