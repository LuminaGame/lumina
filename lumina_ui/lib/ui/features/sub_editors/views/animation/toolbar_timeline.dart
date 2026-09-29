part of '../animation_sub_editor.dart';

/// Top toolbar (clip selector, retarget dialog, save/close) and the
/// bottom timeline panel (transport controls and dope sheet).
mixin _AnimationToolbarTimeline on _AnimationSubEditorStateBase {

  Widget _buildToolbar(bool isDirty) {
    final vm = _viewModel;
    final clips = vm.clips;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.card,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('ANIMATION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.assetName}${isDirty ? ' *' : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground),
          ),
          const SizedBox(width: 12),

          // Clips count badge
          OutlineBadge(
            child: Text('${clips.length} Clips', style: const TextStyle(fontSize: 9)),
          ),
          const SizedBox(width: 12),

          // Preview Animation Selector
          if (clips.isNotEmpty) ...[
            const Text('Clip: ', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
            const SizedBox(width: 4),
            SizedBox(
              width: 140,
              child: Select<int>(
                value: vm.selectedClip,
                onChanged: (val) {
                  if (val != null) vm.selectClip(val);
                },
                itemBuilder: (context, item) {
                  final c = item < clips.length ? clips[item] : null;
                  return Text(c?.name ?? 'Clip $item', style: const TextStyle(fontSize: 10));
                },
                popup: SelectPopup(
                  items: SelectItemList(
                    children: List.generate(clips.length, (idx) {
                      final c = clips[idx];
                      return SelectItemButton(
                        value: idx,
                        child: Text('${c.name} (${c.duration.toStringAsFixed(1)}s)'),
                      );
                    }),
                  ),
                ).call,
              ),
            ),
          ],

          const Spacer(),

          // Retarget Animation Button
          GhostButton(
            size: ButtonSize.small,
            onPressed: () => _openRetargetDialog(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.repeat, size: 12, color: Colors.cyan),
                SizedBox(width: 4),
                Text('Retarget Animation', style: TextStyle(fontSize: 10, color: Colors.cyan, fontWeight: FontWeight.bold)),
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

  void _openRetargetDialog(BuildContext context) {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (ctx) => AnimationRetargetModal(
        viewModel: _viewModel,
        sourceAssetName: widget.assetName,
        onCompleted: widget.onAssetsModified,
      ),
    );
  }

  Widget _buildBottomTimelinePanel() {
    final vm = _viewModel;
    final maxDuration = vm.duration > 0 ? vm.duration : 0.001;

    return Container(
      height: 240,
      color: EditorColors.cardHeader,
      child: Column(
        children: [
          // Row 1: Transport Controls & Speed Selector
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            color: EditorColors.card,
            child: Row(
              children: [
                // Play / Pause Button
                PrimaryButton(
                  key: const ValueKey('anim_play_pause'),
                  size: ButtonSize.small,
                  onPressed: vm.togglePlay,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(vm.isPlaying ? LucideIcons.pause : LucideIcons.play, size: 12),
                      const SizedBox(width: 4),
                      Text(vm.isPlaying ? 'Pause' : 'Play', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Step Back 1 Frame
                OutlineButton(
                  key: const ValueKey('anim_step_back'),
                  size: ButtonSize.small,
                  onPressed: () => vm.stepFrame(-1),
                  child: const Icon(LucideIcons.chevronLeft, size: 13),
                ),
                const SizedBox(width: 4),

                // Step Forward 1 Frame
                OutlineButton(
                  key: const ValueKey('anim_step_forward'),
                  size: ButtonSize.small,
                  onPressed: () => vm.stepFrame(1),
                  child: const Icon(LucideIcons.chevronRight, size: 13),
                ),
                const SizedBox(width: 8),

                // Loop Toggle
                OutlineButton(
                  key: const ValueKey('anim_loop_toggle'),
                  size: ButtonSize.small,
                  onPressed: () => vm.setLooping(!vm.isLooping),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.repeat, size: 12, color: vm.isLooping ? Colors.green : EditorColors.mutedForeground),
                      const SizedBox(width: 4),
                      Text(
                        'Loop',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: vm.isLooping ? FontWeight.bold : FontWeight.normal,
                          color: vm.isLooping ? Colors.green : EditorColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Speed Selector
                const Text('Speed:', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                const SizedBox(width: 4),
                SizedBox(
                  width: 75,
                  child: Select<double>(
                    value: vm.speed,
                    onChanged: (val) {
                      if (val != null) vm.setSpeed(val);
                    },
                    itemBuilder: (context, item) => Text('${item}x', style: const TextStyle(fontSize: 9.5)),
                    popup: SelectPopup(
                      items: const SelectItemList(
                        children: [
                          SelectItemButton(value: 0.1, child: Text('0.1x')),
                          SelectItemButton(value: 0.25, child: Text('0.25x')),
                          SelectItemButton(value: 0.5, child: Text('0.5x')),
                          SelectItemButton(value: 1.0, child: Text('1.0x')),
                          SelectItemButton(value: 2.0, child: Text('2.0x')),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),

                // Timecode & Frame Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: EditorColors.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EditorColors.border),
                  ),
                  child: Text(
                    '${vm.formattedTime} / ${vm.formattedTotalTime}  [Frame ${vm.currentFrame} / ${vm.totalFrames}]',
                    style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily, fontWeight: FontWeight.bold, color: Colors.cyan),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Multi-Track Dope Sheet Widget
          Expanded(
            child: AnimationDopeSheetWidget(
              viewModel: vm,
            ),
          ),
        ],
      ),
    );
  }
}
