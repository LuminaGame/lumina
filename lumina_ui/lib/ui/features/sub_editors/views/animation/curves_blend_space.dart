part of '../animation_sub_editor.dart';

/// Right sidebar Curves and Blend Space tabs.
mixin _AnimationCurvesBlendSpace on _AnimationSubEditorStateBase {

  @override
  Widget _buildCurvesPanel() {
    final vm = _viewModel;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: EditorColors.card,
          child: Row(
            children: [
              const Icon(LucideIcons.spline, size: 12, color: Colors.cyan),
              const SizedBox(width: 6),
              const Text('ANIMATION CURVES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.cyan)),
              const Spacer(),
              PrimaryButton(
                size: ButtonSize.small,
                onPressed: () {
                  final name = 'Curve_${vm.curves.length + 1}';
                  vm.addCurve(name);
                  vm.addCurveKey(name, 0.0, 0.0);
                  vm.addCurveKey(name, vm.duration > 0 ? vm.duration : 1.0, 1.0);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 11),
                    SizedBox(width: 2),
                    Text('Add Curve', style: TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: vm.curves.isEmpty
              ? const Center(
                  child: Text('No animation curves added', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: vm.curves.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final c = vm.curves[idx];
                    final currentVal = vm.evaluateCurve(c.name);
                    return Container(
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
                              Text(c.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.cyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text('Live: ${currentVal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 8.5, color: Colors.cyan, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              GhostButton(
                                size: ButtonSize.small,
                                onPressed: () => vm.removeCurve(c.name),
                                child: const Icon(LucideIcons.trash2, size: 11, color: EditorColors.logError),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Keys Table
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${c.keys.length} Keyframes', style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
                              OutlineButton(
                                size: ButtonSize.small,
                                onPressed: () => vm.addCurveKey(c.name, vm.positionSeconds, 1.0),
                                child: const Text('+ Key at Playhead', style: TextStyle(fontSize: 8)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          ...List.generate(c.keys.length, (kIdx) {
                            final k = c.keys[kIdx];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Text('#$kIdx  t: ${k.time.toStringAsFixed(2)}s  v: ${k.value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 8.5, color: EditorColors.foreground)),
                                  const Spacer(),
                                  GhostButton(
                                    size: ButtonSize.small,
                                    onPressed: () => vm.removeCurveKey(c.name, kIdx),
                                    child: const Icon(LucideIcons.x, size: 10),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget _buildBlendSpacePanel() {
    final vm = _viewModel;
    final bs = vm.blendSpace;
    final weights = vm.currentBlendWeights;
    final dominant = vm.dominantSample;

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Row(
          children: [
            const Icon(LucideIcons.grid3x3, size: 12, color: Colors.green),
            const SizedBox(width: 6),
            const Text('BLENDSPACE EDITOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
            const Spacer(),
            // An Animation Blueprint plays Blend
            // Space assets, so this animation's space can be written as one.
            GhostButton(
              key: const ValueKey('anim_extract_blend_space'),
              size: ButtonSize.xSmall,
              onPressed: bs.samples.isEmpty
                  ? null
                  : () {
                      final path = vm.extractBlendSpaceAsset();
                      if (path == null) return;
                      showToast(
                        context: context,
                        builder: (context, overlay) => SurfaceCard(child: Text('Extracted to $path')),
                      );
                    },
              child: const Text('Extract to Blend Space asset', style: TextStyle(fontSize: 9)),
            ),
            const SizedBox(width: 4),
            Select<bool>(
              value: bs.is2D,
              onChanged: (val) {
                if (val != null) vm.setBlendSpace2D(val);
              },
              itemBuilder: (context, item) => Text(item ? '2D Space' : '1D Strip', style: const TextStyle(fontSize: 9)),
              popup: const SelectPopup(
                items: SelectItemList(
                  children: [
                    SelectItemButton(value: false, child: Text('1D Strip')),
                    SelectItemButton(value: true, child: Text('2D Space')),
                  ],
                ),
              ).call,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Interactive 2D / 1D Canvas Grid
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: EditorColors.background,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: EditorColors.border),
          ),
          child: GestureDetector(
            onPanUpdate: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final local = details.localPosition;
                final normX = (local.dx / 260.0).clamp(0.0, 1.0);
                final normY = 1.0 - (local.dy / 160.0).clamp(0.0, 1.0);
                final paramX = bs.xAxis.min + normX * (bs.xAxis.max - bs.xAxis.min);
                final paramY = bs.yAxis.min + normY * (bs.yAxis.max - bs.yAxis.min);
                vm.setBlendParam(paramX, paramY);
              }
            },
            child: CustomPaint(
              painter: _BlendSpaceCanvasPainter(
                blendSpace: bs,
                paramX: vm.blendParamX,
                paramY: vm.blendParamY,
                weights: weights,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Live Parameters & Dominant Sample
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Param: X=${vm.blendParamX.toStringAsFixed(1)} Y=${vm.blendParamY.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 9, fontFamily: EditorTypography.monoFamily, color: Colors.cyan),
            ),
            if (dominant != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text('Dominant: ${dominant.assetName}', style: const TextStyle(fontSize: 8.5, color: Colors.green, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Add Sample Button
        PrimaryButton(
          size: ButtonSize.small,
          onPressed: () {
            final name = 'Clip_${bs.samples.length + 1}';
            vm.addBlendSample('contents/animations/$name.lmas', name, vm.blendParamX, vm.blendParamY);
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.plus, size: 11),
              SizedBox(width: 4),
              Text('Place Sample at Crosshair', style: TextStyle(fontSize: 9)),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Samples & Computed Weights Table
        const Text('SAMPLES & WEIGHTS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        ...bs.samples.map((s) {
          final w = weights[s.id] ?? 0.0;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: EditorColors.card,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: EditorColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.assetName, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                      Text('(${s.x.toStringAsFixed(1)}, ${s.y.toStringAsFixed(1)})', style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: (w * 0.4 + 0.1).clamp(0.1, 0.5)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text('${(w * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.green)),
                ),
                const SizedBox(width: 4),
                GhostButton(
                  size: ButtonSize.small,
                  onPressed: () => vm.removeBlendSample(s.id),
                  child: const Icon(LucideIcons.x, size: 10),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),

        const Text(
          'Note: Viewport plays highest-weight sample clip until native multi-clip pose blending lands.',
          style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

class _BlendSpaceCanvasPainter extends CustomPainter {
  final BlendSpaceData blendSpace;
  final double paramX;
  final double paramY;
  final Map<String, double> weights;

  _BlendSpaceCanvasPainter({
    required this.blendSpace,
    required this.paramX,
    required this.paramY,
    required this.weights,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = EditorColors.secondary;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final gridPaint = Paint()
      ..color = EditorColors.borderSolid
      ..strokeWidth = 1.0;

    // Draw grid divisions
    for (int i = 1; i < 4; i++) {
      final x = size.width * (i / 4.0);
      final y = size.height * (i / 4.0);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final xSpan = (blendSpace.xAxis.max - blendSpace.xAxis.min).clamp(1e-4, double.infinity);
    final ySpan = (blendSpace.yAxis.max - blendSpace.yAxis.min).clamp(1e-4, double.infinity);

    // Draw samples
    final samplePaint = Paint()..color = Colors.green;
    for (final s in blendSpace.samples) {
      final normX = (s.x - blendSpace.xAxis.min) / xSpan;
      final normY = 1.0 - (s.y - blendSpace.yAxis.min) / ySpan;
      final px = normX * size.width;
      final py = normY * size.height;

      final w = weights[s.id] ?? 0.0;
      final r = 4.0 + w * 6.0;
      canvas.drawCircle(Offset(px, py), r, samplePaint);
    }

    // Draw Crosshair preview
    final crossX = ((paramX - blendSpace.xAxis.min) / xSpan) * size.width;
    final crossY = (1.0 - (paramY - blendSpace.yAxis.min) / ySpan) * size.height;

    final crossPaint = Paint()
      ..color = EditorColors.destructive
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(crossX - 8, crossY), Offset(crossX + 8, crossY), crossPaint);
    canvas.drawLine(Offset(crossX, crossY - 8), Offset(crossX, crossY + 8), crossPaint);
    canvas.drawCircle(Offset(crossX, crossY), 3, crossPaint);
  }

  @override
  bool shouldRepaint(covariant _BlendSpaceCanvasPainter oldDelegate) => true;
}
