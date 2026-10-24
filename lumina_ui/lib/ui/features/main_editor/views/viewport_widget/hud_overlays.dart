part of '../viewport_widget.dart';

/// The viewport's HUD overlays: banners, badges, the camera header, the
/// quick controls and the bottom coordinate bar.
mixin _ViewportHudOverlays on _ViewportWidgetStateBase, _ViewportCameraControls {
  /// The active gizmo axis banner (axis, tool, the selection's location).
  Widget _buildActiveAxisBanner(String activeAxis) {
    return Positioned(
      top: 40,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: EditorColors.warning,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.black,
              width: 1.5,
            ),
            // Drop shadow under a HUD chip: an opacity, not a surface colour.
            boxShadow: const [
              BoxShadow(
                // A black scrim over the render, so the HUD reads over any scene.
                color: Color(0xAA000000),
                blurRadius: 12,
              ),
            ],
          ),
          child: Text(
            _draggingGizmoAxis != null
                ? 'Δ ${_draggingGizmoAxis!} (Dragging) — ${widget.viewModel.activeTool.toUpperCase()} — ${widget.viewModel.selectedActor!.location.map((e) => e.toStringAsFixed(1)).join(' | ')}'
                : 'ACTIVE AXIS [ $activeAxis ] — ${widget.viewModel.activeTool.toUpperCase()} — X: ${widget.viewModel.selectedActor!.location[0].toStringAsFixed(1)} | Y: ${widget.viewModel.selectedActor!.location[1].toStringAsFixed(1)} | Z: ${widget.viewModel.selectedActor!.location[2].toStringAsFixed(1)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: EditorTypography.monoFamily,
            ),
          ),
        ),
      ),
    );
  }

  /// The camera speed toast shown after RMB + wheel or the HUD speed button.
  Widget _buildCameraSpeedBadge() {
    return Positioned(
      top: 40,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: EditorColors.hudSurfaceStrong,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: EditorColors.primary,
              width: 1.5,
            ),
            // Drop shadow under a HUD chip: an opacity, not a surface colour.
            boxShadow: const [
              BoxShadow(
                // A black scrim over the render, so the HUD reads over any scene.
                color: Color(0xAA000000),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.gauge,
                size: 14,
                color: EditorColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'CAMERA SPEED: ${widget.viewModel.cameraSpeedScalar} (${widget.viewModel.cameraSpeedMultiplier}x)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: EditorTypography.monoFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The tint and label while an asset is dragged over the viewport.
  Widget _buildDropHoverOverlay() {
    return Container(
      color: EditorColors.primary.withValues(alpha: 0.12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: EditorColors.primary,
            borderRadius: BorderRadius.circular(4),
            // Drop shadow under a HUD chip: an opacity, not a surface colour.
            boxShadow: const [
              BoxShadow(
                // A lighter black scrim over the render for secondary HUD chips.
                color: Color(0x8A000000),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.plus,
                color: Colors.black,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'DROP ASSET INTO 3D SCENE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The top banner while Play runs (or is paused).
  Widget _buildPieBanner() {
    return Positioned(
      top: 8,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: EditorColors.primary,
            borderRadius: BorderRadius.circular(3),
            // Drop shadow under a HUD chip: an opacity, not a surface colour.
            boxShadow: const [
              BoxShadow(
                // A black scrim over the render, so the HUD reads over any scene.
                color: Color(0x8A000000),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(
            widget.viewModel.isPaused
                ? 'PAUSED — PIE SIMULATION'
                : 'SIMULATE — PIE ACTIVE',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  /// The top-left camera / view mode header.
  Widget _buildCameraHeader() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: EditorColors.hudSurface,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: EditorColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.video,
              size: 12,
              color: Colors.amber,
            ),
            const SizedBox(width: 6),
            Text(
              '${widget.viewModel.cameraMode}  |  ${widget.viewModel.viewportMode}  |  Realtime',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: EditorColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The top-right HUD buttons: speed, DLSS, FSR3, ray tracing, focus, zoom, reset.
  Widget _buildQuickControls() {
    return Positioned(
      top: 8,
      right: 8,
      child: Row(
        children: [
          _buildCameraSpeedHudBtn(),
          const SizedBox(width: 4),
          _buildRtxFeatureHudBtn(RtxSettingsKind.dlss),
          const SizedBox(width: 4),
          _buildRtxFeatureHudBtn(RtxSettingsKind.fsr3),
          const SizedBox(width: 4),
          _buildRtxFeatureHudBtn(RtxSettingsKind.rayTracing),
          const SizedBox(width: 4),
          _buildHudBtn(
            LucideIcons.scan,
            'Focus Selection [F]',
            () {
              if (widget.viewModel.selectedActor != null) {
                widget.viewModel.focusCameraOnActor(
                  widget.viewModel.selectedActor!,
                );
              } else {
                widget.viewModel.resetCamera();
              }
              _updateNativeCamera();
            },
          ),
          const SizedBox(width: 4),
          _buildHudBtn(LucideIcons.zoomIn, 'Zoom In', () {
            widget.viewModel.dollyCamera(-60);
            _updateNativeCamera();
          }),
          const SizedBox(width: 4),
          _buildHudBtn(LucideIcons.zoomOut, 'Zoom Out', () {
            widget.viewModel.dollyCamera(60);
            _updateNativeCamera();
          }),
          const SizedBox(width: 4),
          _buildHudBtn(
            LucideIcons.refreshCw,
            'Reset Camera',
            () {
              widget.viewModel.resetCamera();
              _updateNativeCamera();
            },
          ),
        ],
      ),
    );
  }

  /// The bottom bar: camera position/angles/speed, the selection, frame stats.
  Widget _buildCoordinateBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: EditorColors.hudSurfaceStrong,
        child: Row(
          children: [
            Text(
              'Camera: Pos [${widget.viewModel.cameraPanX.toStringAsFixed(0)}, ${widget.viewModel.cameraPanY.toStringAsFixed(0)}, ${widget.viewModel.cameraPanZ.toStringAsFixed(0)}]  Pitch ${widget.viewModel.cameraPitch.toStringAsFixed(1)}°  Yaw ${widget.viewModel.cameraYaw.toStringAsFixed(1)}°  Dist ${widget.viewModel.cameraDistance.toStringAsFixed(0)}  Speed ${widget.viewModel.cameraSpeedScalar} (${widget.viewModel.cameraSpeedMultiplier}x)',
              style: const TextStyle(
                fontSize: 9,
                fontFamily: EditorTypography.monoFamily,
                color: EditorColors.mutedForeground,
              ),
            ),
            const VerticalDivider(
              width: 16,
              indent: 4,
              endIndent: 4,
            ),
            Text(
              'Selected: ${widget.viewModel.selectedActor?.name ?? "None"}',
              style: const TextStyle(
                fontSize: 9,
                fontFamily: EditorTypography.monoFamily,
                color: EditorColors.primary,
              ),
            ),
            const Spacer(),
            // Updates every rendered frame.
            RepaintBoundary(
              child: ListenableBuilder(
                listenable: widget.viewModel.frameStats,
                builder: (context, _) => Text(
                  widget.viewModel.viewportStatsLabel,
                  style: const TextStyle(
                    fontSize: 9,
                    fontFamily: EditorTypography.monoFamily,
                    color: Colors.amber,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
