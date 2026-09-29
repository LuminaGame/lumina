part of '../animation_dope_sheet_widget.dart';

/// Dope sheet top header bar: title, key mode badge, snap toggle, zoom
/// and add-key / add-notify / delete-key actions.
mixin _DopeSheetTopHeader on _AnimationDopeSheetWidgetStateBase {

  Widget _buildTopHeader(
    BuildContext context,
    int currentFrame,
    int totalFrames,
    AnimationEditorViewModel vm,
    int animatedBoneCount,
  ) {
    final clipKeyframeCount = vm.activeClipKeyframes.length;
    final isZoomedIn = vm.timelineZoom >= 1.8;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: EditorColors.card,
      child: Row(
        children: [
          const Icon(LucideIcons.listTree, size: 15, color: EditorColors.primary),
          const SizedBox(width: 6),
          const Text(
            'DOPE SHEET',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
              color: EditorColors.foreground,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: EditorColors.background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: EditorColors.border),
            ),
            child: Text(
              'Frame $currentFrame / $totalFrames (${vm.positionSeconds.toStringAsFixed(3)}s)',
              style: const TextStyle(fontSize: 11, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground),
            ),
          ),
          if (animatedBoneCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: EditorColors.chart4.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: EditorColors.chart4.withValues(alpha: 0.4)),
              ),
              child: Text(
                '$animatedBoneCount Animated Bones',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.chart4),
              ),
            ),
          ],
          if (clipKeyframeCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: EditorColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: EditorColors.primary.withValues(alpha: 0.4)),
              ),
              child: Text(
                '$clipKeyframeCount Keys',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary),
              ),
            ),
          ],
          const SizedBox(width: 10),

          // Strip / Keyframe Mode Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isZoomedIn ? EditorColors.primary.withValues(alpha: 0.12) : EditorColors.cardHeader,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: EditorColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isZoomedIn ? LucideIcons.diamond : LucideIcons.stretchHorizontal,
                  size: 11,
                  color: isZoomedIn ? EditorColors.primary : EditorColors.mutedForeground,
                ),
                const SizedBox(width: 4),
                Text(
                  isZoomedIn ? 'Keys Detail Mode' : 'Track Strip Mode',
                  style: TextStyle(
                    fontSize: 10,
                    color: isZoomedIn ? EditorColors.primary : EditorColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Snap Toggle
          GhostButton(
            size: ButtonSize.small,
            onPressed: () => vm.setSnap(!vm.snapToFrames),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.magnet,
                  size: 13,
                  color: vm.snapToFrames ? EditorColors.primary : EditorColors.mutedForeground,
                ),
                const SizedBox(width: 4),
                Text(
                  vm.snapToFrames ? 'Snap: On' : 'Snap: Off',
                  style: TextStyle(
                    fontSize: 11,
                    color: vm.snapToFrames ? EditorColors.primary : EditorColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Zoom Controls
          GhostButton(
            size: ButtonSize.small,
            onPressed: () => vm.setTimelineZoom(vm.timelineZoom - 0.25),
            child: const Icon(LucideIcons.zoomOut, size: 13),
          ),
          Text(
            '${(vm.timelineZoom * 100).toInt()}%',
            style: const TextStyle(fontSize: 11, color: EditorColors.mutedForeground),
          ),
          GhostButton(
            size: ButtonSize.small,
            onPressed: () => vm.setTimelineZoom(vm.timelineZoom + 0.25),
            child: const Icon(LucideIcons.zoomIn, size: 13),
          ),

          const Spacer(),

          // Actions
          PrimaryButton(
            size: ButtonSize.small,
            onPressed: () => vm.addKeyAtCurrentFrame(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.keyRound, size: 13),
                SizedBox(width: 4),
                Text('+ Key', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          OutlineButton(
            size: ButtonSize.small,
            onPressed: () {
              final notifyNum = vm.notifies.length + 1;
              vm.addNotify('Notify_$notifyNum', vm.positionSeconds);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.bellRing, size: 13),
                SizedBox(width: 4),
                Text('+ Notify', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
          if (vm.selectedKeyframeIds.isNotEmpty) ...[
            const SizedBox(width: 6),
            DestructiveButton(
              size: ButtonSize.small,
              onPressed: () => vm.deleteSelectedKeys(),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.trash2, size: 13),
                  SizedBox(width: 4),
                  Text('Delete Key', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
