import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_offscreen_frame_source.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/sequencer_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/curve_editor_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/key_details_panel.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/level_viewport.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/render_dialog.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/timeline_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sequencer/track_tree_widget.dart';

class SequencerSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final RealAssetInfo? asset;
  final SequencerViewModel? viewModel;
  final List<EditorActorNode>? levelActors;

  /// The live level the cinematic drives. Playback and scrubbing write the
  /// evaluated samples onto its actors and notify it so the outliner, details
  /// and Filament viewport update the same frame; `stop`/close restore them.
  final EditorViewModel? editorViewModel;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;

  const SequencerSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.asset,
    this.viewModel,
    this.levelActors,
    this.editorViewModel,
    this.onClose,
    this.onBind,
  });

  @override
  State<SequencerSubEditor> createState() => _SequencerSubEditorState();
}

class _SequencerSubEditorState extends State<SequencerSubEditor> with SingleTickerProviderStateMixin {
  late final SequencerViewModel _viewModel;
  late final bool _ownsViewModel;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    final path = widget.assetPath ?? widget.asset?.lmasPath ?? widget.asset?.relativePath ?? 'contents/cinematics/${widget.assetName}.lmas';
    _viewModel = widget.viewModel ?? SequencerViewModel(assetPath: path);
    _viewModel.attachTicker(this);

    final evm = widget.editorViewModel;
    if (evm != null) {
      _viewModel.bindLevel(
        actors: () => evm.actors,
        onChanged: evm.notifyListeners,
        selectActor: (id) {
          final actor = evm.actors.where((a) => a.id == id).firstOrNull;
          if (actor != null) evm.selectActor(actor);
        },
      );
      // Auto Key is a per-user preference; the level's transform edits of
      // the actors this sequence animates are keyed here while it is open.
      _viewModel.setAutoKey(evm.editorPreferences.sequencerAutoKey);
      _viewModel.onAutoKeyChanged = evm.editorPreferences.setSequencerAutoKey;
      evm.actorTransformEditHandler = _viewModel.handleLevelTransformEdits;
    } else if (widget.levelActors != null) {
      _viewModel.bindLevel(actors: () => widget.levelActors!);
    }

    widget.onBind?.call(_viewModel, _viewModel.save, () => _viewModel.isDirty);

    if (_ownsViewModel) {
      _viewModel.load();
    }
  }

  @override
  void dispose() {
    // Closing the editor must never leave a cinematic pose on the level.
    final evm = widget.editorViewModel;
    if (evm != null && evm.actorTransformEditHandler == _viewModel.handleLevelTransformEdits) {
      evm.actorTransformEditHandler = null;
    }
    _viewModel.onAutoKeyChanged = null;
    _viewModel.detachTicker();
    if (_ownsViewModel) {
      _viewModel.dispose();
    } else {
      _viewModel.restoreLevel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final isDirty = _viewModel.isDirty;

        if (_viewModel.isLoading) {
          return Container(
            color: EditorColors.background,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading Sequencer timeline & actor tracks...', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
                ],
              ),
            ),
          );
        }

        if (_viewModel.hasError) {
          return Container(
            color: EditorColors.background,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.triangleAlert, size: 28, color: EditorColors.logError),
                  const SizedBox(height: 8),
                  Text('Failed to load Sequencer asset at ${_viewModel.assetPath}', style: const TextStyle(fontSize: 11, color: EditorColors.foreground)),
                  const SizedBox(height: 16),
                  OutlineButton(
                    onPressed: widget.onClose,
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          color: EditorColors.background,
          child: Column(
            children: [
              // 1. Top Toolbar
              _buildToolbar(isDirty),
              const Divider(height: 1),

              // 2. Main Middle Workspace: Left Outliner + Center (Viewport / Curves)
              Expanded(
                flex: 5,
                child: ResizablePanel.horizontal(
                  children: [
                    // Left Track Outliner
                    ResizablePane(
                      initialSize: 280,
                      minSize: 230,
                      child: Container(
                        color: EditorColors.cardHeader,
                        child: SequencerTrackTreeWidget(
                          viewModel: _viewModel,
                          levelActors: widget.levelActors,
                        ),
                      ),
                    ),

                    // Center Panel: Viewport / Curves Tabs
                    ResizablePane.flex(
                      child: Container(
                        color: EditorColors.background,
                        child: Column(
                          children: [
                            _buildCenterTabsHeader(),
                            Expanded(
                              child: _activeTabIndex == 0
                                  ? _buildViewport()
                                  : SequencerCurveEditorWidget(viewModel: _viewModel),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Right: the selected key's frame, values and interpolation
                    ResizablePane(
                      initialSize: 270,
                      minSize: 220,
                      child: Container(
                        color: EditorColors.card,
                        child: SequencerKeyDetailsPanel(
                          key: const ValueKey('seq_key_panel'),
                          viewModel: _viewModel,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 3. Transport bar (play/pause/stop, keyframe jumps, loop, range, time format)
              _buildTransportBar(),
              const Divider(height: 1),

              // 4. Bottom Multi-Track Timeline Canvas
              Expanded(
                flex: 4,
                child: Container(
                  color: EditorColors.card,
                  child: SequencerTimelineWidget(
                    viewModel: _viewModel,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(bool isDirty) {
    final vm = _viewModel;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.card,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('SEQUENCER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.indigo)),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.assetName}${isDirty ? ' *' : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground),
          ),
          const SizedBox(width: 16),

          // Undo / Redo buttons
          GhostButton(
            size: ButtonSize.small,
            onPressed: vm.canUndo ? () => vm.undo() : null,
            child: const Icon(LucideIcons.undo2, size: 12),
          ),
          GhostButton(
            size: ButtonSize.small,
            onPressed: vm.canRedo ? () => vm.redo() : null,
            child: const Icon(LucideIcons.redo2, size: 12),
          ),
          const SizedBox(width: 12),

          // FPS Selector
          const Text('FPS: ', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
          SizedBox(
            width: 85,
            child: Select<int>(
              value: vm.fps,
              onChanged: (val) {
                if (val != null) vm.setFps(val);
              },
              itemBuilder: (context, item) => Text('$item FPS', style: const TextStyle(fontSize: 9.5)),
              popup: const SelectPopup(
                items: SelectItemList(
                  children: [
                    SelectItemButton(value: 24, child: Text('24 FPS (Cinematic)')),
                    SelectItemButton(value: 30, child: Text('30 FPS (Standard)')),
                    SelectItemButton(value: 60, child: Text('60 FPS (Smooth)')),
                  ],
                ),
              ).call,
            ),
          ),
          const SizedBox(width: 12),

          // Length in Frames
          const Text('Length: ', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
          SizedBox(
            width: 70,
            child: Select<int>(
              value: vm.lengthFrames,
              onChanged: (val) {
                if (val != null) vm.setLengthFrames(val);
              },
              itemBuilder: (context, item) => Text('$item f', style: const TextStyle(fontSize: 9.5)),
              popup: const SelectPopup(
                items: SelectItemList(
                  children: [
                    SelectItemButton(value: 60, child: Text('60 Frames (2s)')),
                    SelectItemButton(value: 120, child: Text('120 Frames (4s)')),
                    SelectItemButton(value: 240, child: Text('240 Frames (8s)')),
                    SelectItemButton(value: 480, child: Text('480 Frames (16s)')),
                  ],
                ),
              ).call,
            ),
          ),
          const SizedBox(width: 12),

          // Auto Key: a transform change is keyed at the playhead when made.
          Tooltip(
            tooltip: (_) => const TooltipContainer(
              child: Text('Auto Key: a move / rotate / scale is keyed at the playhead frame.\nOff: changes preview only; a scrub reverts them unless you press Key.',
                  style: TextStyle(fontSize: 9)),
            ),
            child: Toggle(
              key: const ValueKey('seq_auto_key'),
              value: vm.autoKey,
              onChanged: vm.setAutoKey,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.keyRound, size: 11, color: vm.autoKey ? EditorColors.logError : EditorColors.mutedForeground),
                  const SizedBox(width: 4),
                  Text('Auto Key', style: TextStyle(fontSize: 9, color: vm.autoKey ? EditorColors.logError : EditorColors.mutedForeground)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          ListenableBuilder(
            listenable: widget.editorViewModel ?? vm,
            builder: (context, _) => Tooltip(
            tooltip: (_) => TooltipContainer(
              child: Text(
                  vm.hasPendingPreview
                      ? 'Key the previewed changes at frame ${vm.playheadFrame}'
                      : 'Key the selected actor\'s transform at frame ${vm.playheadFrame}',
                  style: const TextStyle(fontSize: 9)),
            ),
            child: OutlineButton(
              key: const ValueKey('seq_key_button'),
              size: ButtonSize.small,
              onPressed: vm.hasPendingPreview || widget.editorViewModel?.selectedActor != null
                  ? () => vm.keyPendingOrSelected(selectedActorId: widget.editorViewModel?.selectedActor?.id)
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.diamondPlus, size: 11),
                  const SizedBox(width: 4),
                  Text(vm.hasPendingPreview ? 'Key *' : 'Key', style: const TextStyle(fontSize: 9.5)),
                ],
              ),
            ),
          )),
          const SizedBox(width: 12),

          // Timecode & Frame Readout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: EditorColors.background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: EditorColors.border),
            ),
            child: Text(
              '${vm.timeReadout} (${vm.playheadFrame}/${vm.lengthFrames}f)',
              style: const TextStyle(fontSize: 10, fontFamily: EditorTypography.monoFamily, fontWeight: FontWeight.bold, color: Colors.cyan),
            ),
          ),
          const Spacer(),

          // Render Movie (offscreen PNG frame-sequence export)
          SecondaryButton(
            size: ButtonSize.small,
            onPressed: vm.isRendering ? null : () => _openRenderDialog(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.clapperboard, size: 12),
                const SizedBox(width: 5),
                Text(
                  vm.isRendering ? 'Rendering…' : 'Render Movie',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Save Button
          PrimaryButton(
            size: ButtonSize.small,
            onPressed: isDirty ? () => vm.save() : null,
            child: const Text('Save', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),

          // Close Button
          GhostButton(
            size: ButtonSize.small,
            onPressed: widget.onClose,
            child: const Icon(LucideIcons.x, size: 14),
          ),
        ],
      ),
    );
  }

  /// The actors the offscreen movie render draws — the same level bindings the
  /// preview uses, carrying their mesh file so the render queue shows the real
  /// models, not stand-ins.
  List<SequencerRenderActor> _renderActors() =>
      sequencerRenderActors(widget.editorViewModel?.actors ?? widget.levelActors ?? const <EditorActorNode>[]);

  void _openRenderDialog() {
    final evm = widget.editorViewModel;
    if (evm != null) _viewModel.projectDirPath = evm.projectDirPath;
    final available = SequencerOffscreenFrameSource.isSupported;

    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogCtx) => SequencerRenderDialog(
        sequence: _viewModel.data,
        sequenceName: _viewModel.fileBasename,
        projectDirPath: _viewModel.projectDirPath,
        defaultStartFrame: _viewModel.rangeStart,
        defaultEndFrame: _viewModel.rangeEnd,
        engineAvailable: available,
        viewModel: _viewModel,
        onStartRender: (job) => _viewModel.startRender(
          job,
          frameSource: SequencerOffscreenFrameSource(actors: _renderActors()),
          saveFirst: _viewModel.renderRequiresSave,
        ),
        onCancelRender: _viewModel.cancelRender,
        onClose: () => Navigator.of(dialogCtx).pop(),
      ),
    );
  }

  /// The level the sequence drives, drawn live; without a level editor
  /// (a sequence opened on its own) there is no level to draw.
  Widget _buildViewport() {
    final evm = widget.editorViewModel;
    if (evm == null) {
      return const Center(
        child: Text('No level is open: the viewport draws the level this sequence animates.',
            style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
      );
    }
    return SequencerLevelViewport(
      key: const ValueKey('seq_level_viewport'),
      editorViewModel: evm,
      sequencer: _viewModel,
    );
  }

  Widget _buildCenterTabsHeader() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          _buildTabButton('3D Viewport', 0, LucideIcons.box),
          const SizedBox(width: 4),
          _buildTabButton('Curves & Tangents', 1, LucideIcons.spline),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index, IconData icon) {
    final isActive = _activeTabIndex == index;
    return GhostButton(
      size: ButtonSize.small,
      onPressed: () => setState(() => _activeTabIndex = index),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: isActive ? Colors.indigo : EditorColors.mutedForeground),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.indigo : EditorColors.foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transportButton({required IconData icon, required VoidCallback? onPressed, required String tooltip, Color? color, Key? key}) {
    return Tooltip(
      tooltip: (_) => TooltipContainer(child: Text(tooltip, style: const TextStyle(fontSize: 9))),
      child: GhostButton(
        key: key,
        size: ButtonSize.small,
        onPressed: onPressed,
        child: Icon(icon, size: 13, color: color ?? EditorColors.foreground),
      ),
    );
  }

  Widget _buildTransportBar() {
    final vm = _viewModel;
    final previewing = vm.isPreviewingLevel;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: EditorColors.card,
      child: Row(
        children: [
          _transportButton(
            key: const ValueKey('seq_transport_first'),
            icon: LucideIcons.skipBack,
            tooltip: 'Go to first frame (range start)',
            onPressed: vm.goToFirstFrame,
          ),
          _transportButton(
            key: const ValueKey('seq_transport_prev_key'),
            icon: LucideIcons.chevronsLeft,
            tooltip: 'Previous keyframe',
            onPressed: vm.previousKeyframe,
          ),
          _transportButton(
            key: const ValueKey('seq_transport_play'),
            icon: vm.isPlaying ? LucideIcons.pause : LucideIcons.play,
            tooltip: vm.isPlaying ? 'Pause' : 'Play',
            color: vm.isPlaying ? Colors.amber : EditorColors.logSuccess,
            onPressed: vm.togglePlay,
          ),
          _transportButton(
            key: const ValueKey('seq_transport_stop'),
            icon: LucideIcons.square,
            tooltip: 'Stop (return to range start, restore actors)',
            color: previewing || vm.isPlaying ? EditorColors.logError : EditorColors.mutedForeground,
            onPressed: vm.stop,
          ),
          _transportButton(
            key: const ValueKey('seq_transport_next_key'),
            icon: LucideIcons.chevronsRight,
            tooltip: 'Next keyframe',
            onPressed: vm.nextKeyframe,
          ),
          const SizedBox(width: 4),
          Toggle(
            key: const ValueKey('seq_transport_loop'),
            value: vm.isLooping,
            onChanged: vm.setLooping,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.repeat, size: 11, color: vm.isLooping ? Colors.cyan : EditorColors.mutedForeground),
                const SizedBox(width: 4),
                Text('Loop', style: TextStyle(fontSize: 9, color: vm.isLooping ? Colors.cyan : EditorColors.mutedForeground)),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Playback range
          const Text('Range: ', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
          SizedBox(
            width: 58,
            child: TextField(
              key: ValueKey('seq_range_start_${vm.rangeStart}'),
              initialValue: '${vm.rangeStart}',
              style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily),
              onSubmitted: (v) {
                final parsed = int.tryParse(v.trim());
                if (parsed != null) vm.setRangeStart(parsed);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('–', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
          ),
          SizedBox(
            width: 58,
            child: TextField(
              key: ValueKey('seq_range_end_${vm.rangeEnd}'),
              initialValue: '${vm.rangeEnd}',
              style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily),
              onSubmitted: (v) {
                final parsed = int.tryParse(v.trim());
                if (parsed != null) vm.setRangeEnd(parsed);
              },
            ),
          ),
          const SizedBox(width: 12),

          // Time format
          SizedBox(
            width: 104,
            child: Select<SequencerTimeFormat>(
              value: vm.timeFormat,
              onChanged: (val) {
                if (val != null) vm.setTimeFormat(val);
              },
              itemBuilder: (context, item) => Text(_formatLabel(item), style: const TextStyle(fontSize: 9.5)),
              popup: const SelectPopup(
                items: SelectItemList(
                  children: [
                    SelectItemButton(value: SequencerTimeFormat.frames, child: Text('Frames')),
                    SelectItemButton(value: SequencerTimeFormat.seconds, child: Text('Seconds')),
                    SelectItemButton(value: SequencerTimeFormat.timecode, child: Text('Timecode')),
                  ],
                ),
              ).call,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            vm.timeReadout,
            key: const ValueKey('seq_time_readout'),
            style: const TextStyle(fontSize: 10, fontFamily: EditorTypography.monoFamily, fontWeight: FontWeight.bold, color: Colors.cyan),
          ),
          const Spacer(),
          if (!vm.hasLevelBinding)
            const Text('No level bound — playback evaluates without writing actors',
                style: TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground))
          else if (previewing)
            const Text('PREVIEWING LEVEL', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.amber)),
        ],
      ),
    );
  }

  String _formatLabel(SequencerTimeFormat f) {
    switch (f) {
      case SequencerTimeFormat.frames:
        return 'Frames';
      case SequencerTimeFormat.seconds:
        return 'Seconds';
      case SequencerTimeFormat.timecode:
        return 'Timecode';
    }
  }
}
