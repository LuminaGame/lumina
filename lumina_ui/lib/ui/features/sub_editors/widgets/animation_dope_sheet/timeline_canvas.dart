part of '../animation_dope_sheet_widget.dart';

/// Scrollable timeline canvas with the master sequence strip and the
/// bone-tracks group strip.
mixin _DopeSheetTimelineCanvas on _AnimationDopeSheetWidgetStateBase {

  Widget _buildTimelineCanvas(
    BuildContext context,
    int currentFrame,
    int totalFrames,
    AnimationEditorViewModel vm,
    List<AnimBoneTrackInfo> filteredBones,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final contentWidth = (availableWidth * vm.timelineZoom).clamp(availableWidth, 20000.0);
        final duration = vm.duration > 0 ? vm.duration : 1.0;

        return SingleChildScrollView(
          controller: _horizontalTimelineScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            child: Column(
              children: [
                // Top Ruler
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final normalized = (details.localPosition.dx / contentWidth).clamp(0.0, 1.0);
                    vm.seek(normalized * duration);
                  },
                  onHorizontalDragUpdate: (details) {
                    final normalized = (details.localPosition.dx / contentWidth).clamp(0.0, 1.0);
                    vm.seek(normalized * duration);
                  },
                  child: Container(
                    height: 26,
                    color: EditorColors.background,
                    child: CustomPaint(
                      size: Size(contentWidth, 26),
                      painter: _DopeSheetRulerPainter(
                        duration: duration,
                        fps: vm.frameRate,
                        currentPosition: vm.positionSeconds,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),

                // Tracks Grid & Track Strips
                Expanded(
                  child: SingleChildScrollView(
                    controller: _verticalTracksScroll,
                    child: SizedBox(
                      width: contentWidth,
                      child: Stack(
                        children: [
                          // Background grid lines
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _DopeSheetGridPainter(
                                duration: duration,
                                fps: vm.frameRate,
                              ),
                            ),
                          ),

                          // Tracks Rows
                          Column(
                            children: [
                              // Master Sequence Track Strip
                              _buildMasterSequenceTrackStrip(contentWidth, duration, vm),
                              const Divider(height: 1),

                              // Bone Tracks Group Summary Strip
                              _buildBoneTracksGroupStrip(contentWidth, duration, vm),
                              const Divider(height: 1),

                              // Expanded Bone Tracks Subrows (with nested component sub-tracks)
                              if (_expandBoneTracks) ...[
                                // Space matching search bar
                                Container(height: 28, color: EditorColors.background.withValues(alpha: 0.5)),
                                const Divider(height: 1),
                                ...filteredBones.expand(
                                  (b) => [
                                    _buildIndividualBoneTrackStrip(b, contentWidth, duration, vm),
                                    if (_expandedBones.contains(b.boneName))
                                      ...b.subTracks.map(
                                        (st) => _buildSubTrackStrip(b, st, contentWidth, duration, vm),
                                      ),
                                  ],
                                ),
                              ],

                              // Notifies Track Row
                              _buildNotifiesTrackRow(contentWidth, duration, vm),
                              const Divider(height: 1),

                              // Curves Master Row
                              _buildCurvesTrackRow(contentWidth, duration, vm),
                              const Divider(height: 1),

                              // Individual Curve Rows
                              ...vm.curves.map(
                                (c) => _buildIndividualCurveRow(c, contentWidth, duration, vm),
                              ),
                            ],
                          ),

                          // Playhead Needle
                          Positioned(
                            left: (vm.positionSeconds / duration * contentWidth) - 1,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 2,
                              color: EditorColors.logError,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Master Sequence Track Strip spanning the full clip duration with keyframes on zoom
  Widget _buildMasterSequenceTrackStrip(double trackWidth, double duration, AnimationEditorViewModel vm) {
    final showKeys = vm.timelineZoom >= 1.8;
    final keys = vm.activeClipKeyframes;

    return Container(
      height: 32,
      color: EditorColors.primary.withValues(alpha: 0.04),
      child: Stack(
        children: [
          // Solid Track Strip Bar
          Positioned(
            left: 2,
            right: 2,
            top: 6,
            bottom: 6,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final normalized = (details.localPosition.dx / (trackWidth - 4)).clamp(0.0, 1.0);
                vm.seek(normalized * duration);
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      EditorColors.primary.withValues(alpha: 0.75),
                      EditorColors.primary.withValues(alpha: 0.55),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: EditorColors.primary, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: EditorColors.primary.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${vm.activeClip?.name ?? 'Clip'} (0.00s)',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.accentForeground),
                    ),
                    Text(
                      '${duration.toStringAsFixed(2)}s',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.accentForeground),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Render Keyframe Diamonds if Zoomed In
          if (showKeys)
            ...keys.map((t) {
              final x = _AnimationDopeSheetWidgetStateBase._markLeft(t / duration * trackWidth, trackWidth, 12);
              final keyId = 'master_${t.toStringAsFixed(3)}';
              final isSelected = vm.selectedKeyframeIds.contains(keyId);

              return Positioned(
                left: x,
                top: 10,
                child: GestureDetector(
                  onTap: () {
                    vm.selectKeyframe(keyId);
                    vm.seek(t);
                  },
                  child: Transform.rotate(
                    angle: 0.785398, // 45 degrees
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        // a keyframe diamond, drawn small on a dark strip where the accent blue is too dim to find
                        color: isSelected ? EditorColors.accentForeground : const Color(0xFF00E5FF),
                        border: Border.all(
                          // black text on a bright keyframe diamond; the palette has no foreground dark enough
                          color: isSelected ? EditorColors.primary : const Color(0xFF000000),
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

  /// Bone Tracks Group summary strip
  Widget _buildBoneTracksGroupStrip(double trackWidth, double duration, AnimationEditorViewModel vm) {
    final bones = vm.animatedBoneTracks;
    final showKeys = vm.timelineZoom >= 1.8;

    return Container(
      height: 32,
      color: EditorColors.chart4.withValues(alpha: 0.04),
      child: Stack(
        children: [
          // Range Bars for each animated bone superimposed
          ...bones.map((b) {
            final bar = _AnimationDopeSheetWidgetStateBase._rangeBar(b.startTime, b.endTime, duration, trackWidth, 4);

            return Positioned(
              left: bar.left,
              width: bar.width,
              top: 8,
              bottom: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: EditorColors.chart4.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),

          // Composite keyframe diamonds if zoomed in
          if (showKeys)
            ...vm.activeClipKeyframes.map((t) {
              final x = _AnimationDopeSheetWidgetStateBase._markLeft(t / duration * trackWidth, trackWidth, 8);

              return Positioned(
                left: x,
                top: 12,
                child: Transform.rotate(
                  angle: 0.785398,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: EditorColors.chart4.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
