import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/audio_editor_state.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/audio_wav_decoder_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/audio_editor_view_model.dart';

/// AudioEditor.
///
/// Scoped honestly to what the engine's audio layer really provides today:
/// PCM decoded in Dart, a transport routed through
/// [LuminaAudioBackend], and an attenuation curve editor that evaluates the
/// runtime's own [LuminaSoundAttenuation]. The doc's Sound Cue / MetaSound
/// node graph, HRTF/binaural, occlusion and the spectrum analyzer are future
/// scope and deliberately absent rather than shipped as dead tabs.
class AudioSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final RealAssetInfo? asset;
  final AudioEditorViewModel? viewModel;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;

  const AudioSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.asset,
    this.viewModel,
    this.onClose,
    this.onBind,
  });

  @override
  State<AudioSubEditor> createState() => _AudioSubEditorState();
}

class _AudioSubEditorState extends State<AudioSubEditor> with SingleTickerProviderStateMixin {
  late final AudioEditorViewModel _viewModel;
  late final bool _ownsViewModel;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  int _tab = 0;

  /// Exposed for smoke/integration tests that drive the real editor shell.
  AudioEditorViewModel get viewModelForTest => _viewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    final path = widget.assetPath ??
        widget.asset?.lmasPath ??
        widget.asset?.relativePath ??
        'contents/audio/${widget.assetName}.lmas';
    _viewModel = widget.viewModel ?? AudioEditorViewModel(assetPath: path);
    widget.onBind?.call(_viewModel, _viewModel.save, () => _viewModel.isDirty);
    if (_ownsViewModel) _viewModel.load();

    // The playhead runs on the ticker (game-tick time), never a wall-clock
    // Timer — same rule the runtime spec bolds for fades. It only runs while
    // something is playing, so an idle editor still settles.
    _ticker = createTicker(_onTick);
    _viewModel.addListener(_syncTicker);
  }

  void _syncTicker() {
    if (!mounted) return;
    if (_viewModel.isPlaying && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!_viewModel.isPlaying && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt > 0 && _viewModel.isPlaying) _viewModel.tick(math.min(dt, 0.1));
  }

  @override
  void dispose() {
    _viewModel.removeListener(_syncTicker);
    _ticker.dispose();
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final vm = _viewModel;
        return Container(
          color: EditorColors.background,
          child: Column(
            children: [
              _toolbar(vm),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _center(vm)),
                    Container(width: 1, color: EditorColors.border),
                    SizedBox(width: 300, child: _AudioPropertiesPanel(vm: vm)),
                  ],
                ),
              ),
              const Divider(height: 1),
              _transportBar(vm),
            ],
          ),
        );
      },
    );
  }

  // --- toolbar -------------------------------------------------------------

  Widget _toolbar(AudioEditorViewModel vm) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('AUDIO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          const SizedBox(width: 8),
          Text(widget.assetName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
          if (vm.isDirty) ...[
            const SizedBox(width: 6),
            const Text('*', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: EditorColors.primary)),
          ],
          const Spacer(),
          OutlineButton(
            key: const ValueKey('audio_play'),
            enabled: vm.audio != null,
            onPressed: () => vm.play(),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.play, size: 11),
              SizedBox(width: 4),
              Text('Play', style: TextStyle(fontSize: 10)),
            ]),
          ),
          const SizedBox(width: 6),
          OutlineButton(
            key: const ValueKey('audio_stop'),
            enabled: vm.audio != null,
            onPressed: vm.stop,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.square, size: 11),
              SizedBox(width: 4),
              Text('Stop', style: TextStyle(fontSize: 10)),
            ]),
          ),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const ValueKey('audio_save'),
            onPressed: () async {
              await vm.save();
              widget.onClose?.call();
            },
            child: const Text('Save', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- center --------------------------------------------------------------

  Widget _center(AudioEditorViewModel vm) {
    if (vm.isLoading) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Decoding PCM…', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
        ]),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Tabs(
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
            children: const [
              TabItem(key: ValueKey('audio_tab_waveform'), child: Text('Waveform', style: TextStyle(fontSize: 9))),
              TabItem(key: ValueKey('audio_tab_attenuation'), child: Text('Attenuation', style: TextStyle(fontSize: 9))),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _tab == 0 ? _waveformTab(vm) : _AttenuationTab(vm: vm),
          ),
        ),
      ],
    );
  }

  Widget _waveformTab(AudioEditorViewModel vm) {
    if (vm.hasError || vm.audio == null) {
      return Center(
        key: const ValueKey('audio_decode_error'),
        child: Card(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.triangleAlert, size: 28, color: EditorColors.logError),
            const SizedBox(height: 8),
            const Text('This audio payload could not be decoded',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
            const SizedBox(height: 6),
            SizedBox(
              width: 360,
              child: Text(
                vm.errorMessage ?? 'Unknown decode error.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
              ),
            ),
          ]),
        ),
      );
    }

    final audio = vm.audio!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 4, runSpacing: 4, children: [
          _fact('audio_badge_rate', vm.sampleRateLabel),
          _fact('audio_badge_depth', vm.bitDepthLabel),
          _fact('audio_badge_channels', vm.channelsLabel),
          _fact('audio_badge_duration', vm.durationLabel),
          _fact('audio_badge_samples', vm.sampleCountLabel),
          _fact('audio_badge_zoom', '${vm.zoom.toStringAsFixed(1)}× zoom'),
        ]),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Listener(
                onPointerSignal: (signal) {
                  if (signal is PointerScrollEvent && constraints.maxWidth > 0) {
                    final focus = (signal.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                    vm.zoomBy(signal.scrollDelta.dy < 0 ? 1.25 : 0.8, focusFraction: focus);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    if (constraints.maxWidth <= 0) return;
                    final f = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                    final total = audio.frameCount;
                    final frame = vm.visibleStartFrame + f * (vm.visibleEndFrame - vm.visibleStartFrame);
                    vm.seekFraction(total == 0 ? 0.0 : frame / total);
                  },
                  onHorizontalDragUpdate: (details) {
                    if (constraints.maxWidth <= 0) return;
                    final f = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                    final total = audio.frameCount;
                    final frame = vm.visibleStartFrame + f * (vm.visibleEndFrame - vm.visibleStartFrame);
                    vm.seekFraction(total == 0 ? 0.0 : frame / total);
                  },
                  child: CustomPaint(
                    key: const ValueKey('audio_waveform_canvas'),
                    size: Size.infinite,
                    painter: AudioWaveformPainter(
                      audio: audio,
                      startFrame: vm.visibleStartFrame,
                      endFrame: vm.visibleEndFrame,
                      playheadSeconds: vm.positionSeconds,
                      binCount: math.max(32, constraints.maxWidth.round()),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _fact(String key, String label) => SecondaryBadge(
        key: ValueKey(key),
        child: Text(label, style: const TextStyle(fontSize: 8)),
      );

  // --- transport -----------------------------------------------------------

  Widget _transportBar(AudioEditorViewModel vm) {
    final peaks = vm.vuPeaks;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          Icon(vm.isPlaying ? LucideIcons.volume2 : LucideIcons.volumeX,
              size: 13, color: vm.isPlaying ? EditorColors.primary : EditorColors.mutedForeground),
          const SizedBox(width: 8),
          Text(
            vm.positionLabel,
            key: const ValueKey('audio_position_label'),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EditorColors.foreground),
          ),
          const SizedBox(width: 16),
          const Text('Loop', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(width: 4),
          Switch(key: const ValueKey('audio_loop'), value: vm.settings.looping, onChanged: vm.setLooping),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < peaks.length; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(children: [
                      SizedBox(
                        width: 12,
                        child: Text(
                          peaks.length == 1 ? 'M' : (c == 0 ? 'L' : 'R'),
                          style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
                        ),
                      ),
                      Expanded(
                        child: Progress(
                          key: ValueKey('audio_vu_$c'),
                          progress: peaks[c].clamp(0.0, 1.0),
                          color: peaks[c] > 0.9 ? EditorColors.logError : EditorColors.logSuccess,
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            vm.backendStatus,
            key: const ValueKey('audio_backend_status'),
            style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

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

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

/// Draws the min/max peak envelope per channel (L/R stacked), a time ruler and
/// the playhead needle. Peaks are always re-binned from the decoded samples.
class AudioWaveformPainter extends CustomPainter {
  final DecodedAudio audio;
  final int startFrame;
  final int endFrame;
  final double playheadSeconds;
  final int binCount;

  AudioWaveformPainter({
    required this.audio,
    required this.startFrame,
    required this.endFrame,
    required this.playheadSeconds,
    required this.binCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    const rulerHeight = 16.0;
    final bg = Paint()..color = EditorColors.background;
    canvas.drawRect(Offset.zero & size, bg);

    final channelHeight = math.max(1.0, (size.height - rulerHeight) / audio.channels);
    final envelopes = audio.peakEnvelope(math.max(1, binCount), startFrame: startFrame, endFrame: endFrame);
    final binWidth = size.width / math.max(1, binCount);

    final wavePaint = Paint()
      ..color = EditorColors.chart3
      ..strokeWidth = math.max(1.0, binWidth);
    final axisPaint = Paint()
      ..color = EditorColors.border
      ..strokeWidth = 1.0;

    for (var c = 0; c < audio.channels; c++) {
      final top = rulerHeight + c * channelHeight;
      final mid = top + channelHeight / 2;
      canvas.drawLine(Offset(0, mid), Offset(size.width, mid), axisPaint);
      final env = envelopes[c];
      for (var b = 0; b < env.binCount; b++) {
        final x = b * binWidth + binWidth / 2;
        final yMax = mid - env.maxs[b] * (channelHeight / 2 - 2);
        final yMin = mid - env.mins[b] * (channelHeight / 2 - 2);
        canvas.drawLine(Offset(x, yMin), Offset(x, yMax), wavePaint);
      }
    }

    // Time ruler over the visible window.
    final startSeconds = startFrame / audio.sampleRate;
    final endSeconds = endFrame / audio.sampleRate;
    final tickPaint = Paint()
      ..color = EditorColors.mutedForeground
      ..strokeWidth = 1.0;
    const tickCount = 8;
    for (var i = 0; i <= tickCount; i++) {
      final x = size.width * i / tickCount;
      canvas.drawLine(Offset(x, 0), Offset(x, rulerHeight - 6), tickPaint);
      final t = startSeconds + (endSeconds - startSeconds) * i / tickCount;
      final tp = TextPainter(
        text: TextSpan(
          text: AudioEditorViewModel.formatTime(t),
          style: const TextStyle(fontSize: 7, color: EditorColors.mutedForeground),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(math.min(x + 2, size.width - tp.width), 1));
    }

    // Playhead needle.
    if (endSeconds > startSeconds) {
      final f = (playheadSeconds - startSeconds) / (endSeconds - startSeconds);
      if (f >= 0 && f <= 1) {
        final x = size.width * f;
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          Paint()
            ..color = EditorColors.primary
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant AudioWaveformPainter old) =>
      old.audio != audio ||
      old.startFrame != startFrame ||
      old.endFrame != endFrame ||
      old.playheadSeconds != playheadSeconds ||
      old.binCount != binCount;
}

/// Plots gain (0–1) against distance for the selected attenuation model, with
/// the inner-radius and falloff handles and the distance probe.
class AudioAttenuationPainter extends CustomPainter {
  final double Function(double distance) gainAt;
  final double maxDistance;
  final double innerRadius;
  final double outerDistance;
  final double probeDistance;
  final double probeGain;
  final bool enabled;

  AudioAttenuationPainter({
    required this.gainAt,
    required this.maxDistance,
    required this.innerRadius,
    required this.outerDistance,
    required this.probeDistance,
    required this.probeGain,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = EditorColors.background);

    final grid = Paint()
      ..color = EditorColors.border
      ..strokeWidth = 1.0;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }

    final curve = Path();
    final steps = math.max(16, size.width.round());
    for (var i = 0; i <= steps; i++) {
      final d = maxDistance * i / steps;
      final g = gainAt(d).clamp(0.0, 1.0);
      final p = Offset(size.width * i / steps, size.height * (1.0 - g));
      if (i == 0) {
        curve.moveTo(p.dx, p.dy);
      } else {
        curve.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      curve,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = enabled ? EditorColors.accent : EditorColors.mutedForeground,
    );

    void handle(double distance, Color color, String label) {
      final x = size.width * (distance / maxDistance).clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = color
          ..strokeWidth = 2.0,
      );
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(fontSize: 8, color: color)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(math.min(x + 3, size.width - tp.width), 3));
    }

    handle(innerRadius, EditorColors.logSuccess, 'Inner ${innerRadius.toStringAsFixed(0)}');
    handle(outerDistance, EditorColors.logWarning, 'Falloff ${outerDistance.toStringAsFixed(0)}');

    // Distance probe.
    final px = size.width * (probeDistance / maxDistance).clamp(0.0, 1.0);
    final py = size.height * (1.0 - probeGain.clamp(0.0, 1.0));
    canvas.drawCircle(Offset(px, py), 4.0, Paint()..color = EditorColors.primary);
  }

  @override
  bool shouldRepaint(covariant AudioAttenuationPainter old) =>
      old.maxDistance != maxDistance ||
      old.innerRadius != innerRadius ||
      old.outerDistance != outerDistance ||
      old.probeDistance != probeDistance ||
      old.probeGain != probeGain ||
      old.enabled != enabled ||
      old.gainAt != gainAt;
}
