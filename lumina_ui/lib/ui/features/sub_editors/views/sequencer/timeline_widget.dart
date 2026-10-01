import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import '../../view_models/sequencer_view_model.dart';
import 'package:lumina_ui/ui/core/widgets/editor_context_menu.dart';

class SequencerTimelineWidget extends StatefulWidget {
  final SequencerViewModel viewModel;

  const SequencerTimelineWidget({
    super.key,
    required this.viewModel,
  });

  @override
  State<SequencerTimelineWidget> createState() => _SequencerTimelineWidgetState();
}

class _SequencerTimelineWidgetState extends State<SequencerTimelineWidget> {
  final FocusNode _focusNode = FocusNode();
  (String trackId, String channelName, int keyIndex)? _draggedKey;

  /// Which playback-range bracket is being dragged on the ruler (if any).
  SequencerRangeBracket? _draggedBracket;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
            (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowRight) &&
            vm.selectedKeys.isNotEmpty) {
          // Nudge the selected keys one frame (Shift: ten).
          final step = HardwareKeyboard.instance.isShiftPressed ? 10 : 1;
          vm.nudgeSelectedKeys(event.logicalKey == LogicalKeyboardKey.arrowLeft ? -step : step);
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.delete ||
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (vm.selectedKeys.isNotEmpty) {
              vm.deleteSelectedKeys();
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.keyZ &&
              HardwareKeyboard.instance.isControlPressed) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              vm.redo();
            } else {
              vm.undo();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyY &&
              HardwareKeyboard.instance.isControlPressed) {
            vm.redo();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          // Timeline Header & Scrubber Slider
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: EditorColors.cardHeader,
            child: Row(
              children: [
                const Icon(LucideIcons.timer, size: 12, color: Colors.cyan),
                const SizedBox(width: 6),
                Text(
                  'TIMELINE (${vm.lengthFrames} FRAMES)',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.cyan),
                ),
                const Spacer(),
                Expanded(
                  flex: 3,
                  child: Slider(
                    value: SliderValue.single(vm.playheadFrame.toDouble()),
                    min: 0.0,
                    max: vm.lengthFrames.toDouble(),
                    onChanged: (val) => vm.scrubToFrame(val.value.round()),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Multi-Track Timeline Canvas Painter
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                return EditorContextMenu(
                  items: [
                    MenuButton(
                      onPressed: (ctx) {
                        if (vm.tracks.isNotEmpty && vm.tracks.first.channels.isNotEmpty) {
                          final tr = vm.selectedTrackId != null
                              ? vm.findTrack(vm.selectedTrackId!) ?? vm.tracks.first
                              : vm.tracks.first;
                          vm.addKey(tr.id, tr.channels.first.name, vm.playheadFrame, 0.0);
                        }
                      },
                      child: Text('Add Key at Frame ${vm.playheadFrame}', style: const TextStyle(fontSize: 10)),
                    ),
                    if (vm.selectedKey != null) ...[
                      const MenuDivider(),
                      MenuButton(
                        onPressed: (ctx) {
                          final sel = vm.selectedKey!;
                          vm.deleteKey(sel.$1, sel.$2, sel.$3);
                        },
                        child: const Text('Delete Keyframe', style: TextStyle(fontSize: 10, color: EditorColors.logError)),
                      ),
                      MenuButton(
                        onPressed: (ctx) {
                          final sel = vm.selectedKey!;
                          vm.setKeyInterpolation(sel.$1, sel.$2, sel.$3, KeyInterpolation.linear);
                        },
                        child: const Text('Interpolation: Linear', style: TextStyle(fontSize: 10)),
                      ),
                      MenuButton(
                        onPressed: (ctx) {
                          final sel = vm.selectedKey!;
                          vm.setKeyInterpolation(sel.$1, sel.$2, sel.$3, KeyInterpolation.constant);
                        },
                        child: const Text('Interpolation: Constant', style: TextStyle(fontSize: 10)),
                      ),
                      MenuButton(
                        onPressed: (ctx) {
                          final sel = vm.selectedKey!;
                          vm.setKeyInterpolation(sel.$1, sel.$2, sel.$3, KeyInterpolation.cubic);
                        },
                        child: const Text('Interpolation: Cubic Bézier', style: TextStyle(fontSize: 10)),
                      ),
                    ],
                  ],
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      _focusNode.requestFocus();
                      final localPos = details.localPosition;

                      // Check if clicked on a diamond
                      final hitKey = _hitTestKey(localPos, width);
                      if (hitKey != null) {
                        if (HardwareKeyboard.instance.isShiftPressed) {
                          vm.toggleKeySelection(hitKey.$1, hitKey.$2, hitKey.$3);
                        } else {
                          vm.selectKey(hitKey.$1, hitKey.$2, hitKey.$3);
                        }
                      } else {
                        // Clicked empty area -> scrub to that frame
                        final frame = ((localPos.dx / width) * vm.lengthFrames).round().clamp(0, vm.lengthFrames);
                        vm.scrubToFrame(frame);
                        vm.clearKeySelection();
                      }
                    },
                    onDoubleTapDown: (details) {
                      final localPos = details.localPosition;
                      final hitLane = _hitTestLane(localPos);
                      if (hitLane != null) {
                        final frame = ((localPos.dx / width) * vm.lengthFrames).round().clamp(0, vm.lengthFrames);
                        vm.addKey(hitLane.$1, hitLane.$2, frame, 0.0);
                      }
                    },
                    onPanStart: (details) {
                      final bracket = SequencerTimelinePainter.hitTestRangeBracket(
                        details.localPosition,
                        width: width,
                        lengthFrames: vm.lengthFrames,
                        rangeStart: vm.rangeStart,
                        rangeEnd: vm.rangeEnd,
                      );
                      if (bracket != null) {
                        _draggedBracket = bracket;
                        return;
                      }
                      final hitKey = _hitTestKey(details.localPosition, width);
                      if (hitKey != null) {
                        _draggedKey = hitKey;
                        if (!vm.isKeySelected(hitKey.$1, hitKey.$2, hitKey.$3)) vm.selectKey(hitKey.$1, hitKey.$2, hitKey.$3);
                      }
                    },
                    onPanUpdate: (details) {
                      if (_draggedBracket != null) {
                        final frame = ((details.localPosition.dx / width) * vm.lengthFrames).round().clamp(0, vm.lengthFrames);
                        if (_draggedBracket == SequencerRangeBracket.start) {
                          vm.setRangeStart(frame.clamp(0, vm.rangeEnd));
                        } else {
                          vm.setRangeEnd(frame.clamp(vm.rangeStart, vm.lengthFrames));
                        }
                      } else if (_draggedKey != null) {
                        final frame = ((details.localPosition.dx / width) * vm.lengthFrames).round().clamp(0, vm.lengthFrames);
                        vm.moveKey(_draggedKey!.$1, _draggedKey!.$2, _draggedKey!.$3, frame);
                        // Update dragged key index if moved in sorted order
                        final ch = vm.findChannel(_draggedKey!.$1, _draggedKey!.$2);
                        if (ch != null) {
                          final newIdx = ch.keys.indexWhere((k) => k.frame == frame);
                          if (newIdx >= 0) {
                            _draggedKey = (_draggedKey!.$1, _draggedKey!.$2, newIdx);
                          }
                        }
                      } else {
                        final frame = ((details.localPosition.dx / width) * vm.lengthFrames).round().clamp(0, vm.lengthFrames);
                        vm.scrubToFrame(frame);
                      }
                    },
                    onPanEnd: (_) {
                      _draggedKey = null;
                      _draggedBracket = null;
                    },
                    child: CustomPaint(
                      painter: SequencerTimelinePainter(
                        tracks: vm.tracks,
                        lengthFrames: vm.lengthFrames,
                        playheadFrame: vm.playheadFrame,
                        fps: vm.fps,
                        selectedKey: vm.selectedKey,
                        selectedKeys: vm.selectedKeys,
                        rangeStart: vm.rangeStart,
                        rangeEnd: vm.rangeEnd,
                      ),
                      size: Size(width, height),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  (String trackId, String channelName, int keyIndex)? _hitTestKey(Offset pos, double width) {
    const rulerHeight = 20.0;
    const laneHeight = 26.0;
    final vm = widget.viewModel;

    double currentY = rulerHeight;
    for (final track in vm.tracks) {
      for (final channel in track.channels) {
        final laneCenterY = currentY + laneHeight / 2;
        for (int k = 0; k < channel.keys.length; k++) {
          final key = channel.keys[k];
          final kx = (key.frame / (vm.lengthFrames > 0 ? vm.lengthFrames : 1)) * width;
          final keyRect = Rect.fromCenter(center: Offset(kx, laneCenterY), width: 16, height: 16);
          if (keyRect.contains(pos)) {
            return (track.id, channel.name, k);
          }
        }
        currentY += laneHeight;
      }
    }
    return null;
  }

  (String trackId, String channelName)? _hitTestLane(Offset pos) {
    const rulerHeight = 20.0;
    const laneHeight = 26.0;
    if (pos.dy < rulerHeight) return null;

    final vm = widget.viewModel;
    double currentY = rulerHeight;
    for (final track in vm.tracks) {
      for (final channel in track.channels) {
        final laneRect = Rect.fromLTWH(0, currentY, double.infinity, laneHeight);
        if (pos.dy >= laneRect.top && pos.dy < laneRect.bottom) {
          return (track.id, channel.name);
        }
        currentY += laneHeight;
      }
    }
    return null;
  }
}

/// Which playback-range bracket on the ruler a drag targets.
enum SequencerRangeBracket { start, end }

class SequencerTimelinePainter extends CustomPainter {
  final List<SequencerTrack> tracks;
  final int lengthFrames;
  final int playheadFrame;
  final int fps;
  final (String trackId, String channelName, int keyIndex)? selectedKey;

  /// Every selected key (Shift-click adds keys); all are highlighted.
  final Set<(String trackId, String channelName, int keyIndex)> selectedKeys;

  /// Playback range rendered as brackets on the ruler; frames outside it are
  /// shaded. Null keeps the whole sequence.
  final int? rangeStart;
  final int? rangeEnd;

  SequencerTimelinePainter({
    required this.tracks,
    required this.lengthFrames,
    required this.playheadFrame,
    required this.fps,
    this.selectedKey,
    this.selectedKeys = const {},
    this.rangeStart,
    this.rangeEnd,
  });

  static const double rulerHeight = 20.0;
  static const double bracketHitWidth = 7.0;

  /// The ruler rects of the playback-range brackets for a canvas [width].
  static ({Rect start, Rect end}) rangeBracketRects({
    required double width,
    required int lengthFrames,
    required int rangeStart,
    required int rangeEnd,
  }) {
    final len = lengthFrames > 0 ? lengthFrames : 1;
    final sx = (rangeStart / len) * width;
    final ex = (rangeEnd / len) * width;
    return (
      start: Rect.fromLTWH(sx - bracketHitWidth, 0, bracketHitWidth * 2, rulerHeight),
      end: Rect.fromLTWH(ex - bracketHitWidth, 0, bracketHitWidth * 2, rulerHeight),
    );
  }

  static SequencerRangeBracket? hitTestRangeBracket(
    Offset pos, {
    required double width,
    required int lengthFrames,
    required int rangeStart,
    required int rangeEnd,
  }) {
    if (pos.dy > rulerHeight) return null;
    final rects = rangeBracketRects(width: width, lengthFrames: lengthFrames, rangeStart: rangeStart, rangeEnd: rangeEnd);
    // When both brackets overlap prefer the end bracket unless the pointer is left of it.
    if (rects.end.contains(pos) && (!rects.start.contains(pos) || pos.dx >= rects.end.center.dx)) return SequencerRangeBracket.end;
    if (rects.start.contains(pos)) return SequencerRangeBracket.start;
    return null;
  }

  /// Helper to compute diamond rects for tests or hit testing
  static List<Rect> computeKeyRects({
    required List<SequencerTrack> tracks,
    required int lengthFrames,
    required Size size,
  }) {
    final rects = <Rect>[];
    const rulerHeight = 20.0;
    const laneHeight = 26.0;
    double currentY = rulerHeight;

    for (final track in tracks) {
      for (final channel in track.channels) {
        for (final key in channel.keys) {
          final kx = (key.frame / (lengthFrames > 0 ? lengthFrames : 1)) * size.width;
          final ky = currentY + laneHeight / 2;
          rects.add(Rect.fromCenter(center: Offset(kx, ky), width: 10, height: 10));
        }
        currentY += laneHeight;
      }
    }
    return rects;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = EditorColors.background;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    if (lengthFrames <= 0) return;

    // 1. Draw Top Frame Ruler (height 20px)
    const rulerHeight = 20.0;
    final rulerPaint = Paint()..color = EditorColors.secondary;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, rulerHeight), rulerPaint);

    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..strokeWidth = 1.0;

    final frameStep = (fps <= 30) ? 10 : 30;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int f = 0; f <= lengthFrames; f += frameStep) {
      final x = (f / lengthFrames) * size.width;
      canvas.drawLine(Offset(x, rulerHeight - 8), Offset(x, rulerHeight), tickPaint);

      textPainter.text = TextSpan(
        text: '$f',
        style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, 2));
    }

    // 2. Draw Track Lanes
    const laneHeight = 26.0;
    double currentY = rulerHeight;

    final laneDividerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 0.5;

    final diamondPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.fill;

    final selectedDiamondPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;

    for (final track in tracks) {
      for (final channel in track.channels) {
        // Draw lane background alternating
        final isEven = ((currentY - rulerHeight) / laneHeight).floor() % 2 == 0;
        if (isEven) {
          final laneBg = Paint()..color = Colors.white.withValues(alpha: 0.02);
          canvas.drawRect(Rect.fromLTWH(0, currentY, size.width, laneHeight), laneBg);
        }

        canvas.drawLine(Offset(0, currentY + laneHeight), Offset(size.width, currentY + laneHeight), laneDividerPaint);

        // Draw Keyframe Diamonds
        for (int k = 0; k < channel.keys.length; k++) {
          final key = channel.keys[k];
          final kx = (key.frame / lengthFrames) * size.width;
          final ky = currentY + laneHeight / 2;

          final isKeySelected = (selectedKey?.$1 == track.id && selectedKey?.$2 == channel.name && selectedKey?.$3 == k) ||
              selectedKeys.contains((track.id, channel.name, k));

          final path = Path()
            ..moveTo(kx, ky - 5)
            ..lineTo(kx + 5, ky)
            ..lineTo(kx, ky + 5)
            ..lineTo(kx - 5, ky)
            ..close();

          canvas.drawPath(path, isKeySelected ? selectedDiamondPaint : diamondPaint);
        }

        currentY += laneHeight;
        if (currentY > size.height) break;
      }
      if (currentY > size.height) break;
    }

    // 3. Playback range: shade outside, brackets on the ruler
    final rs = (rangeStart ?? 0).clamp(0, lengthFrames);
    final re = (rangeEnd ?? lengthFrames).clamp(0, lengthFrames);
    final rsX = (rs / lengthFrames) * size.width;
    final reX = (re / lengthFrames) * size.width;
    final outsidePaint = Paint()..color = Colors.black.withValues(alpha: 0.35);
    if (rsX > 0) canvas.drawRect(Rect.fromLTRB(0, rulerHeight, rsX, size.height), outsidePaint);
    if (reX < size.width) canvas.drawRect(Rect.fromLTRB(reX, rulerHeight, size.width, size.height), outsidePaint);
    final rangeBand = Paint()..color = Colors.cyan.withValues(alpha: 0.18);
    canvas.drawRect(Rect.fromLTRB(rsX, rulerHeight - 4, reX, rulerHeight), rangeBand);
    final startBracket = Path()
      ..moveTo(rsX, 0)
      ..lineTo(rsX + 7, 0)
      ..lineTo(rsX + 7, 3)
      ..lineTo(rsX + 2, 3)
      ..lineTo(rsX + 2, rulerHeight)
      ..lineTo(rsX, rulerHeight)
      ..close();
    final endBracket = Path()
      ..moveTo(reX, 0)
      ..lineTo(reX - 7, 0)
      ..lineTo(reX - 7, 3)
      ..lineTo(reX - 2, 3)
      ..lineTo(reX - 2, rulerHeight)
      ..lineTo(reX, rulerHeight)
      ..close();
    canvas.drawPath(startBracket, Paint()..color = EditorColors.logSuccess);
    canvas.drawPath(endBracket, Paint()..color = EditorColors.logWarning);

    // 4. Draw Playhead Vertical Scrubber Line
    final playheadX = (playheadFrame / lengthFrames) * size.width;
    final playheadLinePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(playheadX, 0), Offset(playheadX, size.height), playheadLinePaint);

    final playheadHandle = Path()
      ..moveTo(playheadX - 6, 0)
      ..lineTo(playheadX + 6, 0)
      ..lineTo(playheadX, 10)
      ..close();
    canvas.drawPath(playheadHandle, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(covariant SequencerTimelinePainter oldDelegate) => true;
}
