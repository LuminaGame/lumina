import 'package:flutter/services.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blend_space_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/pin_literal_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blend_space/blend_space_grid.dart';

/// The Blend Space editor: the target mesh's clips on the left to drag onto the grid, the
/// grid with samples snapped to its divisions and a preview point, the
/// preview viewport playing the nearest sample, and axis / sample details.
class BlendSpaceSubEditor extends StatefulWidget {
  final String assetName;
  final String assetPath;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final BlendSpaceEditorViewModel? viewModel;

  /// False shows the preview's clip as text instead of mounting the
  /// Filament viewport (see AnimBlueprintSubEditor.showPreviewViewport).
  final bool showPreviewViewport;

  const BlendSpaceSubEditor({
    super.key,
    required this.assetName,
    required this.assetPath,
    this.onClose,
    this.onBind,
    this.viewModel,
    this.showPreviewViewport = true,
  });

  @override
  State<BlendSpaceSubEditor> createState() => BlendSpaceSubEditorState();
}

class BlendSpaceSubEditorState extends State<BlendSpaceSubEditor> {
  late final BlendSpaceEditorViewModel _vm;
  late final bool _owns;

  BlendSpaceEditorViewModel get viewModel => _vm;

  @override
  void initState() {
    super.initState();
    _owns = widget.viewModel == null;
    _vm = widget.viewModel ?? BlendSpaceEditorViewModel(assetPath: widget.assetPath);
    widget.onBind?.call(_vm, _vm.save, () => _vm.isDirty);
    if (_owns) _vm.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_vm.preview.isAttached) _vm.startHeadlessPreview();
    });
  }

  @override
  void dispose() {
    if (_owns) _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _vm.undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _vm.redo,
        const SingleActivator(LogicalKeyboardKey.delete): () {
          final i = _vm.selectedSample;
          if (i != null) _vm.removeSample(i);
        },
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([_vm, _vm.transactions]),
        builder: (context, _) => Container(
          color: EditorColors.background,
          child: Column(
            children: [
              _toolbar(),
              const Divider(height: 1),
              Expanded(
                child: ResizablePanel.horizontal(
                  children: [
                    ResizablePane(initialSize: 220, minSize: 180, child: _clipList()),
                    ResizablePane.flex(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 280,
                            child: widget.showPreviewViewport
                                ? SubEditor3DViewport(
                                    key: const ValueKey('bs_preview_viewport'),
                                    title: 'Blend Space Preview',
                                    showShapeSelector: false,
                                    yUpCamera: true,
                                    initialCameraDistance: 420,
                                    initialCameraTarget: Vector3(0, 95, 0),
                                    statsLabel: 'Preview: ${_vm.previewClip ?? 'no clip'} (nearest sample)',
                                    onPreviewWorldReady: _vm.attachPreviewWorld,
                                    onPreviewWorldDisposing: _vm.detachPreviewWorld,
                                  )
                                : Container(
                                    key: const ValueKey('bs_preview_text'),
                                    color: EditorColors.graphCanvas,
                                    alignment: Alignment.center,
                                    child: Text('Preview (no renderer): ${_vm.previewClip ?? 'no clip'}',
                                        style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                                  ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: BlendSpaceGrid(
                                key: const ValueKey('bs_grid'),
                                document: _vm.document,
                                point: _vm.previewPoint,
                                highlightClip: _vm.previewClip,
                                divisionsX: _vm.divisionsX,
                                divisionsY: _vm.divisionsY,
                                selectedSample: _vm.selectedSample,
                                onDropClip: (clip, x, y) => _vm.addSample(clip, x, y),
                                onSelectSample: _vm.selectSample,
                                onSampleDragStart: _vm.beginSampleDrag,
                                onSampleDrag: _vm.dragSample,
                                onSampleDragEnd: _vm.endSampleDrag,
                                onPointChanged: _vm.setPreviewPoint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ResizablePane(initialSize: 270, minSize: 220, child: _details()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    final tx = _vm.transactions;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.card,
      child: Row(
        children: [
          const OutlineBadge(child: Text('BLEND SPACE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Flexible(
            child: Text('${widget.assetName}${_vm.isDirty ? ' *' : ''}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
          ),
          const SizedBox(width: 8),
          Text('${_vm.is2D ? '2D' : '1D'} · ${_vm.document.samples.length} samples · Target: ${_vm.targetMesh.split('/').last.replaceAll('.lmas', '')}',
              style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          const Spacer(),
          GhostButton(
              key: const ValueKey('bs_undo'),
              size: ButtonSize.small,
              onPressed: tx.canUndo ? _vm.undo : null,
              child: const Icon(LucideIcons.undo2, size: 13)),
          GhostButton(
              key: const ValueKey('bs_redo'),
              size: ButtonSize.small,
              onPressed: tx.canRedo ? _vm.redo : null,
              child: const Icon(LucideIcons.redo2, size: 13)),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const ValueKey('bs_save'),
            size: ButtonSize.small,
            onPressed: () => _vm.save(),
            child: const Text('Save', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          GhostButton(size: ButtonSize.small, onPressed: widget.onClose, child: const Icon(LucideIcons.x, size: 14)),
        ],
      ),
    );
  }

  Widget _clipList() {
    return Container(
      color: EditorColors.cardHeader,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('CLIPS OF THE TARGET MESH',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          const SizedBox(height: 2),
          const Text('Drag a clip onto the grid.', style: TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              children: [
                if (_vm.clips.isEmpty)
                  const Text('No clips found.', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                for (final c in _vm.clips)
                  Draggable<BlendSpaceClipDrag>(
                    key: ValueKey('bs_clip_$c'),
                    data: BlendSpaceClipDrag(c),
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: EditorColors.card,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: EditorColors.primary),
                      ),
                      child: Text(c, style: const TextStyle(fontSize: 10, decoration: TextDecoration.none, color: EditorColors.foreground)),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        // the preview amber the debugger and state machine use for "playing now"
                    color: _vm.previewClip == c ? const Color(0x33FFB300) : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(children: [
                        const Icon(LucideIcons.clapperboard, size: 11, color: EditorColors.mutedForeground),
                        const SizedBox(width: 6),
                        Expanded(child: Text(c, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10))),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _details() {
    final axes = _vm.document.axes;
    final sampleIndex = _vm.selectedSample;
    final sample = sampleIndex == null || sampleIndex >= _vm.document.samples.length ? null : _vm.document.samples[sampleIndex];
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 3),
          child: Text(t, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        );
    return Container(
      color: EditorColors.cardHeader,
      child: ListView(
        key: const ValueKey('bs_details'),
        padding: const EdgeInsets.all(12),
        children: [
          const Text('AXES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary)),
          Row(children: [
            const Text('Dimensions', style: TextStyle(fontSize: 10)),
            const Spacer(),
            OutlineButton(
              key: const ValueKey('bs_dimensions_toggle'),
              size: ButtonSize.xSmall,
              onPressed: () => _vm.setDimensions(_vm.is2D ? 1 : 2),
              child: Text(_vm.is2D ? 'Make 1D' : 'Make 2D', style: const TextStyle(fontSize: 9)),
            ),
          ]),
          for (var i = 0; i < axes.length; i++) ...[
            label(i == 0 ? 'Horizontal Axis' : 'Vertical Axis'),
            BlueprintPinLiteralEditor(
              keyPrefix: 'bs_axis_${i}_name',
              type: LuminaPinType.name,
              value: axes[i].name,
              expanded: true,
              onCommit: (v) => _vm.setAxis(i, name: '$v'),
            ),
            const SizedBox(height: 4),
            Row(children: [
              const Text('Min', style: TextStyle(fontSize: 9)),
              const SizedBox(width: 4),
              BlueprintPinLiteralEditor(
                keyPrefix: 'bs_axis_${i}_min',
                type: LuminaPinType.float,
                value: axes[i].min,
                onCommit: (v) => _vm.setAxis(i, min: (v as num).toDouble()),
              ),
              const SizedBox(width: 8),
              const Text('Max', style: TextStyle(fontSize: 9)),
              const SizedBox(width: 4),
              BlueprintPinLiteralEditor(
                keyPrefix: 'bs_axis_${i}_max',
                type: LuminaPinType.float,
                value: axes[i].max,
                onCommit: (v) => _vm.setAxis(i, max: (v as num).toDouble()),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Text('Grid Divisions', style: TextStyle(fontSize: 9)),
              const SizedBox(width: 6),
              BlueprintPinLiteralEditor(
                keyPrefix: 'bs_axis_${i}_divisions',
                type: LuminaPinType.integer,
                value: i == 0 ? _vm.divisionsX : _vm.divisionsY,
                onCommit: (v) => i == 0 ? _vm.setDivisions(x: (v as num).toInt()) : _vm.setDivisions(y: (v as num).toInt()),
              ),
            ]),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 10),
          const Text('SAMPLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary)),
          if (sample == null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Click a sample to edit it.', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
            )
          else ...[
            label('Clip'),
            Text(sample.clip, key: const ValueKey('bs_sample_clip'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            label('Position'),
            Text('(${sample.x.toStringAsFixed(1)}${_vm.is2D ? ', ${sample.y.toStringAsFixed(1)}' : ''})',
                style: const TextStyle(fontSize: 11, fontFamily: EditorTypography.monoFamily)),
            const SizedBox(height: 8),
            DestructiveButton(
              key: const ValueKey('bs_sample_delete'),
              size: ButtonSize.small,
              onPressed: () => _vm.removeSample(sampleIndex!),
              child: const Text('Delete Sample', style: TextStyle(fontSize: 10)),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 10),
          const Text('PREVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary)),
          const SizedBox(height: 4),
          Text(
            'Point (${_vm.previewPoint.$1.toStringAsFixed(1)}${_vm.is2D ? ', ${_vm.previewPoint.$2.toStringAsFixed(1)}' : ''}) → '
            '${_vm.nearestSample?.clip ?? 'no sample'}',
            key: const ValueKey('bs_preview_details'),
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(height: 4),
          const Text('Nearest sample plus crossfade: what the game plays.',
              style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        ],
      ),
    );
  }
}
