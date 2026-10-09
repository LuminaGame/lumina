part of '../texture_sub_editor.dart';

/// The zoomable texture canvas and its pixel inspector bar.
mixin _TextureSubEditorCanvas on _TextureSubEditorStateBase {
  Widget _buildCanvas() {
    final vm = _viewModel;
    return Stack(
      children: [
        // Zoom/Pan Canvas with Mouse Events
        Positioned.fill(
          child: Listener(
            onPointerSignal: (signal) {
              if (signal is PointerScrollEvent) {
                final delta = signal.scrollDelta.dy;
                final zoomFactor = delta < 0 ? 1.15 : 0.85;
                vm.setZoom(vm.zoom * zoomFactor);
              }
            },
            child: GestureDetector(
              onPanUpdate: (details) {
                vm.setPan(vm.pan + details.delta);
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return MouseRegion(
                    onHover: (event) {
                      final size = constraints.biggest;
                      final center = Offset(size.width / 2, size.height / 2) + vm.pan;
                      final imgW = vm.activeMip.width * vm.zoom;
                      final imgH = vm.activeMip.height * vm.zoom;
                      final imgLeft = center.dx - imgW / 2;
                      final imgTop = center.dy - imgH / 2;

                      final localX = event.localPosition.dx - imgLeft;
                      final localY = event.localPosition.dy - imgTop;

                      if (localX >= 0 && localX < imgW && localY >= 0 && localY < imgH) {
                        final u = (localX / imgW).clamp(0.0, 1.0);
                        final v = (localY / imgH).clamp(0.0, 1.0);
                        final px = (u * vm.activeMip.width).floor().clamp(0, vm.activeMip.width - 1);
                        final py = (v * vm.activeMip.height).floor().clamp(0, vm.activeMip.height - 1);
                        vm.setHover(u, v, px, py);
                      } else {
                        vm.clearHover();
                      }
                    },
                    onExit: (_) => vm.clearHover(),
                    child: CustomPaint(
                      painter: _TextureCanvasPainter(
                        image: vm.activeMipUiImage,
                        zoom: vm.zoom,
                        pan: vm.pan,
                        mipWidth: vm.activeMip.width,
                        mipHeight: vm.activeMip.height,
                      ),
                      size: Size.infinite,
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Floating HUD: Zoom Controls
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: EditorColors.card.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: EditorColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Zoom: ${(vm.zoom * 100).toInt()}%',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                ),
                const SizedBox(width: 8),
                // The zoom also takes a typed percentage.
                SizedBox(
                  width: 170,
                  child: SliderField(
                    key: const ValueKey('texture_zoom_slider'),
                    value: vm.zoom * 100,
                    defaultValue: 100,
                    min: 10,
                    max: 3200,
                    unit: '%',
                    fractionDigits: 0,
                    onChanged: (v) => vm.setZoom(v / 100),
                    onCommit: (v) => vm.setZoom(v / 100),
                    onReset: () => vm.setZoom(1.0),
                  ),
                ),
                const SizedBox(width: 8),
                OutlineButton(
                  size: ButtonSize.small,
                  onPressed: vm.resetZoom,
                  child: const Text('Reset', style: TextStyle(fontSize: 8.5)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPixelInspectorBar() {
    final vm = _viewModel;
    final hasHover = vm.hoverU != null && vm.hoverRgba != null;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.card,
      child: Row(
        children: [
          const Icon(LucideIcons.crosshair, size: 12, color: Colors.cyan),
          const SizedBox(width: 6),
          if (hasHover) ...[
            Text(
              'UV: ${vm.hoverU!.toStringAsFixed(4)}, ${vm.hoverV!.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground),
            ),
            const SizedBox(width: 12),
            Text(
              'XY: ${vm.hoverX}, ${vm.hoverY}',
              style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground),
            ),
            const SizedBox(width: 12),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color.fromARGB(vm.hoverRgba!.$4, vm.hoverRgba!.$1, vm.hoverRgba!.$2, vm.hoverRgba!.$3),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'RGBA: (${vm.hoverRgba!.$1}, ${vm.hoverRgba!.$2}, ${vm.hoverRgba!.$3}, ${vm.hoverRgba!.$4})',
              style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily, fontWeight: FontWeight.bold, color: Colors.cyan),
            ),
            const SizedBox(width: 8),
            Text(
              '${vm.hoverHex}',
              style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground),
            ),
          ] else ...[
            const Text(
              'Hover over the canvas to inspect exact pixel RGBA & UV coordinates',
              style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}
