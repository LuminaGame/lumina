import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/tab_bar_actions.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/audio_editor_state.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/audio_wav_decoder_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/audio_editor_view_model.dart';

part 'audio_sub_editor/attenuation_tab.dart';
part 'audio_sub_editor/painters.dart';
part 'audio_sub_editor/properties_panel.dart';

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
    return SubEditorToolbar(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.cardHeader,
      children: [
          SubEditorToolbarTitle(child: Row(mainAxisSize: MainAxisSize.min, children: [
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
          ])),
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
          )
      ],
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
