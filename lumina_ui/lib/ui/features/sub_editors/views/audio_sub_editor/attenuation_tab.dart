part of '../audio_sub_editor.dart';

// ---------------------------------------------------------------------------
// Attenuation tab
// ---------------------------------------------------------------------------

class _AttenuationTab extends StatelessWidget {
  final AudioEditorViewModel vm;

  const _AttenuationTab({required this.vm});

  @override
  Widget build(BuildContext context) {
    final att = vm.settings.attenuation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Attenuation Function', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(width: 8),
          SizedBox(
            width: 220,
            child: Select<LuminaAttenuationModel>(
              key: const ValueKey('audio_model_select'),
              value: att.model,
              onChanged: (m) {
                if (m != null) vm.setAttenuationModel(m);
              },
              itemBuilder: (context, m) => Text(attenuationModelLabel(m), style: const TextStyle(fontSize: 9.5)),
              popup: SelectPopup(
                items: SelectItemList(
                  children: LuminaAttenuationModel.values
                      .map((m) => SelectItemButton(value: m, child: Text(attenuationModelLabel(m))))
                      .toList(),
                ),
              ).call,
            ),
          ),
          const Spacer(),
          if (!vm.settings.spatialized)
            const Text('Spatialization is off — the curve is inactive for this sound',
                style: TextStyle(fontSize: 8.5, color: EditorColors.logWarning)),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              void dragHandle(Offset local) {
                if (constraints.maxWidth <= 0) return;
                final f = (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
                // Whichever handle is nearer follows the pointer.
                final dInner = (f - vm.innerRadiusHandleFraction).abs();
                final dOuter = (f - vm.falloffHandleFraction).abs();
                if (dInner <= dOuter) {
                  vm.dragInnerRadiusToFraction(f);
                } else {
                  vm.dragFalloffEdgeToFraction(f);
                }
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => dragHandle(d.localPosition),
                onHorizontalDragUpdate: (d) => dragHandle(d.localPosition),
                child: CustomPaint(
                  key: const ValueKey('audio_attenuation_canvas'),
                  size: Size.infinite,
                  painter: AudioAttenuationPainter(
                    gainAt: vm.gainAt,
                    maxDistance: vm.plotMaxDistance,
                    innerRadius: att.innerRadius,
                    outerDistance: vm.outerDistance,
                    probeDistance: vm.probeDistance,
                    probeGain: vm.probeGain,
                    enabled: vm.settings.spatialized,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Inner Radius', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
              ScrubNumericField(
                key: const ValueKey('audio_inner_radius'),
                value: att.innerRadius,
                defaultValue: 400.0,
                label: '',
                min: 0.0,
                onChanged: vm.setInnerRadius,
                onCommit: vm.setInnerRadius,
                onReset: () => vm.setInnerRadius(400.0),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Falloff Distance', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
              ScrubNumericField(
                key: const ValueKey('audio_falloff_distance'),
                value: att.falloffDistance,
                defaultValue: 3500.0,
                label: '',
                min: 0.0,
                onChanged: vm.setFalloffDistance,
                onCommit: vm.setFalloffDistance,
                onReset: () => vm.setFalloffDistance(3500.0),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Text('Distance Probe', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(width: 8),
          Expanded(
            child: SliderField(
              key: const ValueKey('audio_probe_slider'),
              value: vm.probeDistance,
              defaultValue: 1200.0,
              min: 0.0,
              max: vm.plotMaxDistance,
              unit: 'cm',
              fractionDigits: 0,
              onChanged: vm.setProbeDistance,
              onCommit: vm.setProbeDistance,
              onReset: () => vm.setProbeDistance(1200.0),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            vm.probeLabel,
            key: const ValueKey('audio_probe_label'),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary),
          ),
        ]),
      ],
    );
  }
}
