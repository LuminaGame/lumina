import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../../core/theme/editor_theme.dart';
import '../models/anim_notify_and_curves.dart';
import '../models/anim_bone_track_info.dart';
import '../view_models/animation_editor_view_model.dart';

part 'animation_dope_sheet/state.dart';
part 'animation_dope_sheet/top_header.dart';
part 'animation_dope_sheet/track_headers.dart';
part 'animation_dope_sheet/timeline_canvas.dart';
part 'animation_dope_sheet/track_strips.dart';
part 'animation_dope_sheet/painters.dart';

/// Multi-Track Dope Sheet & Animation Track Strip Editor.
class AnimationDopeSheetWidget extends StatefulWidget {
  final AnimationEditorViewModel viewModel;

  const AnimationDopeSheetWidget({
    super.key,
    required this.viewModel,
  });

  @override
  State<AnimationDopeSheetWidget> createState() => _AnimationDopeSheetWidgetState();
}

class _AnimationDopeSheetWidgetState extends _AnimationDopeSheetWidgetStateBase
    with
        _DopeSheetTopHeader,
        _DopeSheetTrackHeaders,
        _DopeSheetTimelineCanvas,
        _DopeSheetTrackStrips {

  @override
  void initState() {
    super.initState();
    _verticalTracksScroll.addListener(_syncTracksToHeaders);
    _verticalHeadersScroll.addListener(_syncHeadersToTracks);
  }

  void _syncTracksToHeaders() {
    if (_isSyncingScroll) return;
    if (_verticalHeadersScroll.hasClients &&
        (_verticalHeadersScroll.offset - _verticalTracksScroll.offset).abs() > 0.5) {
      _isSyncingScroll = true;
      _verticalHeadersScroll.jumpTo(
        _verticalTracksScroll.offset.clamp(0.0, _verticalHeadersScroll.position.maxScrollExtent),
      );
      _isSyncingScroll = false;
    }
  }

  void _syncHeadersToTracks() {
    if (_isSyncingScroll) return;
    if (_verticalTracksScroll.hasClients &&
        (_verticalTracksScroll.offset - _verticalHeadersScroll.offset).abs() > 0.5) {
      _isSyncingScroll = true;
      _verticalTracksScroll.jumpTo(
        _verticalHeadersScroll.offset.clamp(0.0, _verticalTracksScroll.position.maxScrollExtent),
      );
      _isSyncingScroll = false;
    }
  }

  @override
  void dispose() {
    _verticalTracksScroll.removeListener(_syncTracksToHeaders);
    _verticalHeadersScroll.removeListener(_syncHeadersToTracks);
    _horizontalTimelineScroll.dispose();
    _verticalTracksScroll.dispose();
    _verticalHeadersScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final totalFrames = (vm.duration * vm.frameRate).round().clamp(1, 9999);
        final currentFrame = (vm.positionSeconds * vm.frameRate).round();

        // Filter out static bones and apply search query from ViewModel
        final animatedBones = vm.animatedBoneTracks;
        final filteredBones = vm.filteredAnimatedBoneTracks;

        return Container(
          decoration: BoxDecoration(
            color: EditorColors.cardHeader,
            border: Border(
              top: BorderSide(color: EditorColors.border),
            ),
          ),
          child: Column(
            children: [
              // Top Header Bar
              _buildTopHeader(context, currentFrame, totalFrames, vm, animatedBones.length),
              const Divider(height: 1),

              // Tracks & Timeline Viewport
              Expanded(
                child: Row(
                  children: [
                    // Left Column: Track Headers
                    _buildTrackHeaders(context, vm, animatedBones.length, filteredBones),
                    const VerticalDivider(width: 1),

                    // Right Column: Timeline Ruler & Dope Sheet Track Strips
                    Expanded(
                      child: _buildTimelineCanvas(context, currentFrame, totalFrames, vm, filteredBones),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
