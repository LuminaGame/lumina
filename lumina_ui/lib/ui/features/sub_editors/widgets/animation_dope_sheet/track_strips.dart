part of '../animation_dope_sheet_widget.dart';

/// Per-row key strips: individual bone tracks, their sub-tracks,
/// notifies and curves.
mixin _DopeSheetTrackStrips on _AnimationDopeSheetWidgetStateBase {

  /// Individual animated bone track strip starting at startTime and ending at endTime
  @override
  Widget _buildIndividualBoneTrackStrip(
    AnimBoneTrackInfo bone,
    double trackWidth,
    double duration,
    AnimationEditorViewModel vm,
  ) {
    // An authored sequence's few keys are shown (and draggable). Dense clips only show keys when zoomed.
    final showKeys = vm.timelineZoom >= 1.8 || (vm.isAuthored && bone.keyframeTimes.length <= 16);
    final bar = _AnimationDopeSheetWidgetStateBase._rangeBar(bone.startTime, bone.endTime, duration, trackWidth, 6);
    final startX = bar.left;
    final barWidth = bar.width;

    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: EditorColors.background.withValues(alpha: 0.2),
        border: Border(bottom: BorderSide(color: EditorColors.border.withValues(alpha: 0.3))),
      ),
      child: Stack(
        children: [
          // Active Movement Range Bar
          Positioned(
            left: startX,
            width: barWidth,
            top: 4,
            bottom: 4,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final normalized = ((startX + details.localPosition.dx) / trackWidth).clamp(0.0, 1.0);
                final clickedTime = normalized * duration;
                double closestTime = bone.startTime;
                double minDiff = double.infinity;
                for (final t in bone.keyframeTimes) {
                  final diff = (t - clickedTime).abs();
                  if (diff < minDiff) {
                    minDiff = diff;
                    closestTime = t;
                  }
                }
                final keyId = 'bone_${bone.boneName}_${closestTime.toStringAsFixed(3)}';
                vm.selectKeyframe(keyId);
                vm.seek(closestTime);
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      EditorColors.chart4.withValues(alpha: 0.85),
                      EditorColors.chart4.withValues(alpha: 0.70),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    // a tint of the bone-track violet (EditorColors.chart4) for text on a violet fill
                    color: const Color(0xFFE9D5FF),
                    width: 0.8,
                  ),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: barWidth > 60
                    ? Text(
                        '${bone.startTime.toStringAsFixed(2)}s - ${bone.endTime.toStringAsFixed(2)}s',
                        style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: EditorColors.accentForeground),
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
              ),
            ),
          ),

          // Individual Keyframe Diamonds if Zoomed In (Only for active keyframe timestamps)
          if (showKeys)
            ...bone.keyframeTimes.where((t) => t >= bone.startTime - 1e-4 && t <= bone.endTime + 1e-4).map((t) {
              final keyId = 'bone_${bone.boneName}_${t.toStringAsFixed(3)}';
              final isSelected = vm.selectedKeyframeIds.contains(keyId);
              // A selected key follows a drag of any selected key.
              final dragX = vm.isAuthored && isSelected && _boneKeyDragDx != null ? _boneKeyDragDx! : 0.0;
              final x = _AnimationDopeSheetWidgetStateBase._markLeft(t / duration * trackWidth + dragX, trackWidth, 9);

              return Positioned(
                left: x,
                top: 8,
                child: GestureDetector(
                  key: ValueKey('dope_bone_key_${bone.boneName}_${(t * vm.frameRate).round()}'),
                  onTap: () {
                    vm.selectKeyframe(keyId, multiSelect: HardwareKeyboard.instance.isShiftPressed);
                    if (vm.isAuthored) vm.selectBone(bone.boneName);
                    vm.seek(t);
                  },
                  // Authored keys drag along the timeline (snapped to frames).
                  onHorizontalDragStart: !vm.isAuthored
                      ? null
                      : (_) {
                          if (!vm.selectedKeyframeIds.contains(keyId)) {
                            vm.selectKeyframe(keyId, multiSelect: HardwareKeyboard.instance.isShiftPressed);
                          }
                          setState(() => _boneKeyDragDx = 0.0);
                        },
                  onHorizontalDragUpdate: !vm.isAuthored
                      ? null
                      : (d) => setState(() => _boneKeyDragDx = (_boneKeyDragDx ?? 0.0) + d.delta.dx),
                  onHorizontalDragEnd: !vm.isAuthored
                      ? null
                      : (_) {
                          final dx = _boneKeyDragDx ?? 0.0;
                          setState(() => _boneKeyDragDx = null);
                          final frames = (dx / trackWidth * duration * vm.frameRate).round();
                          if (frames != 0) vm.moveSelectedBoneKeysBy(frames);
                        },
                  onHorizontalDragCancel: !vm.isAuthored ? null : () => setState(() => _boneKeyDragDx = null),
                  child: Transform.rotate(
                    angle: 0.785398,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        // a tint of the bone-track violet (EditorColors.chart4) for text on a violet fill
                        color: isSelected ? EditorColors.accentForeground : const Color(0xFFFAF5FF),
                        border: Border.all(
                          // a shade of the bone-track violet (EditorColors.chart4) for a keyframe outline
                          color: isSelected ? EditorColors.primary : const Color(0xFF7E22CE),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Individual Component Sub-Track timeline strip (Location X/Y/Z, Rotation P/Y/R, Scale X/Y/Z)
  @override
  Widget _buildSubTrackStrip(
    AnimBoneTrackInfo bone,
    AnimBoneSubTrack subTrack,
    double trackWidth,
    double duration,
    AnimationEditorViewModel vm,
  ) {
    if (!subTrack.hasVariation || subTrack.keyframeTimes.isEmpty) {
      // Static component: No movement occurs on this axis across the entire animation
      return Container(
        height: 22,
        decoration: BoxDecoration(
          color: EditorColors.background.withValues(alpha: 0.1),
          border: Border(bottom: BorderSide(color: EditorColors.border.withValues(alpha: 0.15))),
        ),
        child: Center(
          child: Container(
            height: 1,
            color: EditorColors.border.withValues(alpha: 0.2),
          ),
        ),
      );
    }

    final showKeys = vm.timelineZoom >= 1.8;
    final bar = _AnimationDopeSheetWidgetStateBase._rangeBar(subTrack.startTime, subTrack.endTime, duration, trackWidth, 4);
    final startX = bar.left;
    final barWidth = bar.width;

    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: subTrack.color.withValues(alpha: 0.04),
        border: Border(bottom: BorderSide(color: EditorColors.border.withValues(alpha: 0.2))),
      ),
      child: Stack(
        children: [
          // Sub-track movement range bar in channel color (Only for actively moving components)
          Positioned(
            left: startX,
            width: barWidth,
            top: 4,
            bottom: 4,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final normalized = ((startX + details.localPosition.dx) / trackWidth).clamp(0.0, 1.0);
                final clickedTime = normalized * duration;
                double closestTime = subTrack.startTime;
                double minDiff = double.infinity;
                for (final t in subTrack.keyframeTimes) {
                  final diff = (t - clickedTime).abs();
                  if (diff < minDiff) {
                    minDiff = diff;
                    closestTime = t;
                  }
                }
                final keyId = 'bone_${bone.boneName}_${subTrack.label}_${closestTime.toStringAsFixed(3)}';
                vm.selectKeyframe(keyId);
                vm.seek(closestTime);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: subTrack.color.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: subTrack.color, width: 0.6),
                ),
              ),
            ),
          ),

          // Sub-Track Keyframe Diamonds if Zoomed In (Only for active keyframes within movement range)
          if (showKeys)
            ...subTrack.keyframeTimes.where((t) => t >= subTrack.startTime - 1e-4 && t <= subTrack.endTime + 1e-4).map((t) {
              final x = _AnimationDopeSheetWidgetStateBase._markLeft(t / duration * trackWidth, trackWidth, 8);
              final keyId = 'bone_${bone.boneName}_${subTrack.label}_${t.toStringAsFixed(3)}';
              final isSelected = vm.selectedKeyframeIds.contains(keyId);

              return Positioned(
                left: x,
                top: 6,
                child: GestureDetector(
                  onTap: () {
                    vm.selectKeyframe(keyId);
                    vm.seek(t);
                  },
                  child: Transform.rotate(
                    angle: 0.785398,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isSelected ? EditorColors.accentForeground : subTrack.color,
                        border: Border.all(
                          // black text on a bright keyframe diamond; the palette has no foreground dark enough
                          color: isSelected ? EditorColors.primary : const Color(0xFF000000),
                          width: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget _buildNotifiesTrackRow(double trackWidth, double duration, AnimationEditorViewModel vm) {
    return Container(
      height: 32,
      color: EditorColors.background.withValues(alpha: 0.4),
      child: Stack(
        children: vm.notifies.map((n) {
          final x = _AnimationDopeSheetWidgetStateBase._markLeft(n.time / duration * trackWidth, trackWidth, 60);
          final isSelected = vm.selectedKeyframeIds.contains(n.id);

          return Positioned(
            left: x,
            top: 4,
            child: GestureDetector(
              onTap: () {
                vm.selectKeyframe(n.id);
                vm.seek(n.time);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? EditorColors.primary : EditorColors.logWarning.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected ? EditorColors.foreground : EditorColors.border,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.bellRing, size: 10, color: EditorColors.accentForeground),
                    const SizedBox(width: 4),
                    Text(
                      n.name,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: EditorColors.accentForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget _buildCurvesTrackRow(double trackWidth, double duration, AnimationEditorViewModel vm) {
    return Container(
      height: 32,
      color: EditorColors.card.withValues(alpha: 0.3),
      child: const SizedBox.expand(),
    );
  }

  @override
  Widget _buildIndividualCurveRow(AnimCurveData curve, double trackWidth, double duration, AnimationEditorViewModel vm) {
    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: EditorColors.background.withValues(alpha: 0.2),
        border: Border(bottom: BorderSide(color: EditorColors.border.withValues(alpha: 0.3))),
      ),
      child: Stack(
        children: curve.keys.map((k) {
          final x = _AnimationDopeSheetWidgetStateBase._markLeft(k.time / duration * trackWidth, trackWidth, 14);
          final keyId = '${curve.name}_${k.time.toStringAsFixed(3)}';
          final isSelected = vm.selectedKeyframeIds.contains(keyId);

          return Positioned(
            left: x,
            top: 6,
            child: GestureDetector(
              onTap: () {
                vm.selectKeyframe(keyId);
                vm.seek(k.time);
              },
              child: Transform.rotate(
                angle: 0.785398, // 45 degrees for diamond handle
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: isSelected ? EditorColors.accentForeground : EditorColors.primary,
                    border: Border.all(
                      color: isSelected ? EditorColors.primary : EditorColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
