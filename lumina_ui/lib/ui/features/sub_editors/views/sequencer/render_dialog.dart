import 'dart:io';

import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_movie_render_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/sequencer_view_model.dart';

/// One entry of the resolution `Select`.
class _ResolutionPreset {
  final String label;
  final int width;
  final int height;
  const _ResolutionPreset(this.label, this.width, this.height);
}

const List<_ResolutionPreset> _presets = [
  _ResolutionPreset('1280 × 720', 1280, 720),
  _ResolutionPreset('1920 × 1080', 1920, 1080),
  _ResolutionPreset('2560 × 1440', 2560, 1440),
  _ResolutionPreset('3840 × 2160', 3840, 2160),
];

const String _customPreset = 'Custom';

/// The Movie Render Queue dialog: configure an offscreen PNG-sequence export,
/// then watch it run with a live progress bar, ETA and a working Cancel.
///
/// Honest scope — the only format this stack can write is a numbered PNG
/// sequence (see [MovieRenderFormat]); no MP4/EXR options are offered because
/// no encoder for them exists here.
class SequencerRenderDialog extends StatefulWidget {
  final SequencerData sequence;
  final String sequenceName;
  final String projectDirPath;
  final int defaultStartFrame;
  final int defaultEndFrame;

  /// False when the native offscreen render capability is missing; the Start
  /// button is then disabled with the missing symbol named.
  final bool engineAvailable;

  /// Injected clock so the default output folder name is deterministic in tests.
  final DateTime? now;

  /// Live render state. When null the dialog is a pure form (widget tests).
  final SequencerViewModel? viewModel;

  final void Function(MovieRenderJob job) onStartRender;
  final VoidCallback? onCancelRender;
  final VoidCallback? onClose;

  const SequencerRenderDialog({
    super.key,
    required this.sequence,
    required this.sequenceName,
    required this.projectDirPath,
    required this.defaultStartFrame,
    required this.defaultEndFrame,
    required this.onStartRender,
    this.engineAvailable = true,
    this.now,
    this.viewModel,
    this.onCancelRender,
    this.onClose,
  });

  @override
  State<SequencerRenderDialog> createState() => _SequencerRenderDialogState();
}

class _SequencerRenderDialogState extends State<SequencerRenderDialog> {
  late final TextEditingController _width;
  late final TextEditingController _height;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late final TextEditingController _warmup;
  late final TextEditingController _name;
  late int _fps;

  @override
  void initState() {
    super.initState();
    _width = TextEditingController(text: '1920');
    _height = TextEditingController(text: '1080');
    _start = TextEditingController(text: '${widget.defaultStartFrame}');
    _end = TextEditingController(text: '${widget.defaultEndFrame}');
    _warmup = TextEditingController(text: '0');
    _name = TextEditingController(
      text: MovieRenderJob.defaultOutputName(widget.sequenceName, widget.now),
    );
    _fps = widget.sequence.fps > 0 ? widget.sequence.fps : 30;
  }

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    _start.dispose();
    _end.dispose();
    _warmup.dispose();
    _name.dispose();
    super.dispose();
  }

  // --- validation -----------------------------------------------------------

  int? _asInt(TextEditingController c) => int.tryParse(c.text.trim());

  String? get _widthError {
    final v = _asInt(_width);
    if (v == null || v < 16 || v > 4096 || v.isOdd) {
      return 'Width must be an even number between 16 and 4096';
    }
    return null;
  }

  String? get _heightError {
    final v = _asInt(_height);
    if (v == null || v < 16 || v > 4096 || v.isOdd) {
      return 'Height must be an even number between 16 and 4096';
    }
    return null;
  }

  String? get _rangeError {
    final s = _asInt(_start);
    final e = _asInt(_end);
    if (s == null || e == null || s < 0 || e < 0) return 'Frame range must be whole frame numbers';
    if (s > e) return 'Start frame must not be after the end frame';
    return null;
  }

  String? get _warmupError {
    final v = _asInt(_warmup);
    if (v == null || v < 0 || v > 120) return 'Warmup frames must be between 0 and 120';
    return null;
  }

  String? get _nameError {
    final n = _name.text.trim();
    if (n.isEmpty) return 'Output folder name is required';
    if (RegExp(r'[\\/:*?"<>|]').hasMatch(n)) return 'Output folder name contains invalid characters';
    return null;
  }

  bool get _isValid =>
      _widthError == null &&
      _heightError == null &&
      _rangeError == null &&
      _warmupError == null &&
      _nameError == null;

  String get _resolvedPath => 'saved/movie_renders/${_name.text.trim()}/';

  int get _frameCount {
    final s = _asInt(_start);
    final e = _asInt(_end);
    if (s == null || e == null || s > e) return 0;
    return e - s + 1;
  }

  MovieRenderJob _buildJob() => MovieRenderJob(
        sequence: widget.sequence,
        sequenceName: widget.sequenceName,
        width: _asInt(_width)!,
        height: _asInt(_height)!,
        fps: _fps,
        startFrame: _asInt(_start)!,
        endFrame: _asInt(_end)!,
        warmupFrames: _asInt(_warmup)!,
        outputDir: MovieRenderJob.resolveOutputDir(widget.projectDirPath, _name.text.trim()),
      );

  String get _presetLabel {
    final w = _asInt(_width);
    final h = _asInt(_height);
    for (final p in _presets) {
      if (p.width == w && p.height == h) return p.label;
    }
    return _customPreset;
  }

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    if (vm == null) return _dialog(_form());
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (vm.isRendering) return _dialog(_progressBody(vm));
        if (vm.renderError != null) return _dialog(_errorBody(vm));
        final progress = vm.renderProgress;
        if (progress != null &&
            (progress.phase == MovieRenderPhase.completed ||
                progress.phase == MovieRenderPhase.cancelled)) {
          return _dialog(_finishedBody(vm, progress));
        }
        return _dialog(_form(vm));
      },
    );
  }

  Widget _dialog(Widget body) {
    return AlertDialog(
      title: const Text('Render Movie'),
      content: SizedBox(width: 430, child: body),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 10),
        child: Text(text,
            style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
      );

  Widget _error(String? message) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(message, style: const TextStyle(fontSize: 9.5, color: EditorColors.logError)),
    );
  }

  Widget _form([SequencerViewModel? vm]) {
    final capabilityMissing = !widget.engineAvailable;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Resolution'),
          Select<String>(
            value: _presetLabel,
            onChanged: (val) {
              if (val == null || val == _customPreset) return;
              final p = _presets.firstWhere((p) => p.label == val);
              setState(() {
                _width.text = '${p.width}';
                _height.text = '${p.height}';
              });
            },
            itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 9.5)),
            popup: const SelectPopup(
              items: SelectItemList(
                children: [
                  SelectItemButton(value: '1280 × 720', child: Text('1280 × 720')),
                  SelectItemButton(value: '1920 × 1080', child: Text('1920 × 1080')),
                  SelectItemButton(value: '2560 × 1440', child: Text('2560 × 1440')),
                  SelectItemButton(value: '3840 × 2160', child: Text('3840 × 2160')),
                  SelectItemButton(value: _customPreset, child: Text(_customPreset)),
                ],
              ),
            ).call,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('render-width'),
                  controller: _width,
                  placeholder: const Text('Width'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('render-height'),
                  controller: _height,
                  placeholder: const Text('Height'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          _error(_widthError),
          _error(_heightError),
          _label('Frame Rate'),
          Select<int>(
            value: _fps,
            onChanged: (val) {
              if (val != null) setState(() => _fps = val);
            },
            itemBuilder: (context, item) => Text('$item FPS', style: const TextStyle(fontSize: 9.5)),
            popup: const SelectPopup(
              items: SelectItemList(
                children: [
                  SelectItemButton(value: 24, child: Text('24 FPS')),
                  SelectItemButton(value: 30, child: Text('30 FPS')),
                  SelectItemButton(value: 60, child: Text('60 FPS')),
                ],
              ),
            ).call,
          ),
          _label('Frame Range (render frames, inclusive)'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('render-start-frame'),
                  controller: _start,
                  placeholder: const Text('Start'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('render-end-frame'),
                  controller: _end,
                  placeholder: const Text('End'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          _error(_rangeError),
          _label('Warmup Frames (rendered, not written)'),
          TextField(
            key: const ValueKey('render-warmup'),
            controller: _warmup,
            onChanged: (_) => setState(() {}),
          ),
          _error(_warmupError),
          _label('Format'),
          Select<String>(
            value: MovieRenderFormat.pngSequence.label,
            onChanged: (_) {},
            itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 9.5)),
            popup: const SelectPopup(
              items: SelectItemList(
                children: [
                  SelectItemButton(value: 'PNG Sequence', child: Text('PNG Sequence')),
                ],
              ),
            ).call,
          ),
          _label('Output Folder Name'),
          TextField(
            key: const ValueKey('render-output-name'),
            controller: _name,
            onChanged: (_) => setState(() {}),
          ),
          _error(_nameError),
          const SizedBox(height: 8),
          Text(
            _resolvedPath,
            style: const TextStyle(
                fontSize: 9.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground),
          ),
          const SizedBox(height: 4),
          Text(
            '$_frameCount frame(s) at ${_asInt(_width) ?? 0}×${_asInt(_height) ?? 0}',
            style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
          ),
          if (capabilityMissing)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Alert(
                title: const Text('Offscreen rendering unavailable'),
                content: const Text(
                  'The native capability renderStandaloneView / '
                  'readPixelsFromRenderTarget is not available in this build, so '
                  'no frames can be produced.',
                  style: TextStyle(fontSize: 9.5),
                ),
              ),
            ),
          if (vm != null && vm.renderMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Alert(
                title: Text(vm.renderMessage!),
                content: vm.renderRequiresSave
                    ? const Text(
                        'The render walks the sequence as it exists on disk.',
                        style: TextStyle(fontSize: 9.5),
                      )
                    : null,
              ),
            ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlineButton(
                size: ButtonSize.small,
                onPressed: widget.onClose,
                child: const Text('Close', style: TextStyle(fontSize: 10)),
              ),
              const SizedBox(width: 8),
              PrimaryButton(
                key: const ValueKey('render-start'),
                size: ButtonSize.small,
                onPressed: (_isValid && widget.engineAvailable)
                    ? () => widget.onStartRender(_buildJob())
                    : null,
                child: Text(
                  vm != null && vm.renderRequiresSave ? 'Save & Render' : 'Start Render',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressBody(SequencerViewModel vm) {
    final p = vm.renderProgress;
    final fraction = p?.fraction ?? 0.0;
    final eta = p?.eta;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frame ${p == null ? 0 : p.framesDone} / ${p?.total ?? _frameCount} '
          '(${(fraction * 100).toStringAsFixed(0)}%)',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Progress(progress: fraction * 100.0, min: 0, max: 100),
        const SizedBox(height: 10),
        Text(
          'Elapsed ${MovieRenderProgress.formatDuration(p?.elapsed ?? Duration.zero)}'
          '${eta == null ? '' : '   ·   ETA ${MovieRenderProgress.formatDuration(eta)}'}',
          style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
        ),
        const SizedBox(height: 4),
        Text(
          'Last written: ${p?.fileName ?? '—'}',
          style: const TextStyle(
              fontSize: 9.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground),
        ),
        const SizedBox(height: 4),
        Text(
          'Output size: ${MovieRenderProgress.formatBytes(p?.bytesWritten ?? 0)}',
          style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
        ),
        if (vm.renderMessage != null) ...[
          const SizedBox(height: 6),
          Text(vm.renderMessage!,
              style: const TextStyle(fontSize: 9.5, color: EditorColors.logWarning)),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DestructiveButton(
              key: const ValueKey('render-cancel'),
              size: ButtonSize.small,
              onPressed: widget.onCancelRender ?? vm.cancelRender,
              child: const Text('Cancel', style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _finishedBody(SequencerViewModel vm, MovieRenderProgress p) {
    final cancelled = p.phase == MovieRenderPhase.cancelled;
    final dir = vm.lastRenderDir;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cancelled
              ? 'Render cancelled — ${p.framesDone} frame(s) kept'
              : 'Render complete — ${p.framesDone} frame(s)',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          dir?.path ?? '—',
          style: const TextStyle(
              fontSize: 9.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground),
        ),
        const SizedBox(height: 4),
        Text(
          'Total size ${MovieRenderProgress.formatBytes(p.bytesWritten)}  ·  '
          'wall time ${MovieRenderProgress.formatDuration(p.elapsed)}',
          style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlineButton(
              key: const ValueKey('render-open-folder'),
              size: ButtonSize.small,
              onPressed: dir == null ? null : () => openFolder(dir.path),
              child: const Text('Open Folder', style: TextStyle(fontSize: 10)),
            ),
            const SizedBox(width: 8),
            PrimaryButton(
              size: ButtonSize.small,
              onPressed: widget.onClose,
              child: const Text('Done', style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _errorBody(SequencerViewModel vm) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Alert(
          title: const Text('Render failed'),
          content: Text(vm.renderError!, style: const TextStyle(fontSize: 9.5)),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlineButton(
              size: ButtonSize.small,
              onPressed: widget.onClose,
              child: const Text('Close', style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ],
    );
  }

  /// Reveals the finished frame folder in the platform file manager.
  static Future<void> openFolder(String path) async {
    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [path]);
      }
    } catch (_) {
      // Opening a file manager is a convenience; never fail the render over it.
    }
  }
}
