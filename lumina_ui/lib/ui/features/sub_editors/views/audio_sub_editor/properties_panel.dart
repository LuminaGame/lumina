part of '../audio_sub_editor.dart';

// ---------------------------------------------------------------------------
// Properties panel
// ---------------------------------------------------------------------------

class _AudioPropertiesPanel extends StatelessWidget {
  final AudioEditorViewModel vm;

  const _AudioPropertiesPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    final s = vm.settings;
    return Container(
      color: EditorColors.cardHeader,
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        child: Accordion(
          items: [
            AccordionItem(
              expanded: true,
              trigger: const AccordionTrigger(
                  child: Text('Sound Properties', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Volume Multiplier', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                SliderField(
                  key: const ValueKey('audio_volume_multiplier'),
                  value: s.volumeMultiplier,
                  defaultValue: 1.0,
                  min: 0.0,
                  max: 2.0,
                  onChanged: vm.setVolumeMultiplier,
                  onCommit: vm.setVolumeMultiplier,
                  onReset: () => vm.setVolumeMultiplier(1.0),
                ),
                const SizedBox(height: 6),
                const Text('Pitch Multiplier', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                SliderField(
                  key: const ValueKey('audio_pitch_multiplier'),
                  value: s.pitchMultiplier,
                  defaultValue: 1.0,
                  min: 0.5,
                  max: 2.0,
                  onChanged: vm.setPitchMultiplier,
                  onCommit: vm.setPitchMultiplier,
                  onReset: () => vm.setPitchMultiplier(1.0),
                ),
                const SizedBox(height: 6),
                const Text('Pitch Randomization ±', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                ScrubNumericField(
                  key: const ValueKey('audio_pitch_randomization'),
                  value: s.pitchRandomization,
                  defaultValue: 0.0,
                  label: '',
                  min: 0.0,
                  max: 1.0,
                  onChanged: vm.setPitchRandomization,
                  onCommit: vm.setPitchRandomization,
                  onReset: () => vm.setPitchRandomization(0.0),
                ),
                const SizedBox(height: 6),
                const Text('Sound Class', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                const SizedBox(height: 4),
                Select<AudioSoundClass>(
                  key: const ValueKey('audio_sound_class'),
                  value: s.soundClass,
                  onChanged: (c) {
                    if (c != null) vm.setSoundClass(c);
                  },
                  itemBuilder: (context, c) => Text(c.label, style: const TextStyle(fontSize: 9.5)),
                  popup: SelectPopup(
                    items: SelectItemList(
                      children:
                          AudioSoundClass.values.map((c) => SelectItemButton(value: c, child: Text(c.label))).toList(),
                    ),
                  ).call,
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(child: Text('Looping', style: TextStyle(fontSize: 9, color: EditorColors.foreground))),
                  Switch(key: const ValueKey('audio_looping'), value: s.looping, onChanged: vm.setLooping),
                ]),
                Row(children: [
                  const Expanded(
                      child:
                          Text('Enable Spatialization', style: TextStyle(fontSize: 9, color: EditorColors.foreground))),
                  Switch(key: const ValueKey('audio_spatialization'), value: s.spatialized, onChanged: vm.setSpatialized),
                ]),
              ]),
            ),
            AccordionItem(
              expanded: true,
              trigger: const AccordionTrigger(
                  child: Text('Playback Backend', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  vm.backendStatus,
                  key: const ValueKey('audio_backend_status_panel'),
                  style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground),
                ),
                const SizedBox(height: 4),
                const Text(
                  'The engine routes every sound through LuminaAudioBackend; no concrete backend has been chosen yet, '
                  'so the preview drives the playhead, the time readout and the PCM-derived VU meter without audible output.',
                  style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
                ),
              ]),
            ),
            AccordionItem(
              trigger: const AccordionTrigger(
                  child: Text('Source', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Asset: ${vm.fileBasename}', style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
                Text('Encoding: ${vm.bitDepthLabel} · ${vm.channelsLabel} · ${vm.sampleRateLabel}',
                    style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
                Text('Duration: ${vm.durationLabel} (${vm.sampleCountLabel})',
                    style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
                const SizedBox(height: 4),
                const Text('Uncompressed .wav only — compressed formats need a decoder the stack does not ship.',
                    style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
