import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../sub_editor_binding.dart';
import 'package:lumina/lumina.dart';
import '../../../core/theme/editor_theme.dart';
import '../../../core/property_editors/asset_picker_select.dart';
import '../../../core/property_editors/lumina_transform_widget.dart';
import '../../main_editor/services/editor_preferences.dart';
import '../models/anim_notify_and_curves.dart';
import '../models/selected_keyframe_details.dart';
import '../models/sub_editor_transform_gizmo.dart';
import '../view_models/animation_editor_view_model.dart';
import 'sequencer/key_details_panel.dart' show SequencerNumberField;
import '../widgets/animation_retarget_modal.dart';
import '../widgets/animation_dope_sheet_widget.dart';
import 'sub_editor_3d_viewport.dart';

part 'animation/state.dart';
part 'animation/toolbar_timeline.dart';
part 'animation/left_sidebar.dart';
part 'animation/keyframe_details.dart';
part 'animation/curves_blend_space.dart';
part 'animation/authoring.dart';
part 'animation/pose_tools.dart';

class AnimationSubEditor extends StatefulWidget {
  final String assetName;
  final String? assetPath;
  final RealAssetInfo? asset;
  final AnimationEditorViewModel? viewModel;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final VoidCallback? onAssetsModified;

  /// The per-user preferences (Auto Key is remembered there).
  final EditorPreferences? preferences;

  const AnimationSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.asset,
    this.viewModel,
    this.onClose,
    this.onBind,
    this.onAssetsModified,
    this.preferences,
  });

  @override
  State<AnimationSubEditor> createState() => _AnimationSubEditorState();
}

class _AnimationSubEditorState extends _AnimationSubEditorStateBase
    with
        _AnimationToolbarTimeline,
        _AnimationLeftSidebar,
        _AnimationKeyframeDetails,
        _AnimationCurvesBlendSpace,
        _AnimationAuthoring,
        _AnimationPoseTools {

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    final path = widget.assetPath ?? widget.asset?.lmasPath ?? widget.asset?.relativePath ?? 'contents/animations/${widget.assetName}.lmas';
    _viewModel = widget.viewModel ?? AnimationEditorViewModel(assetPath: path, vsync: this);
    widget.onBind?.call(_viewModel, _viewModel.save, () => _viewModel.isDirty);
    // Auto Key is a per-user preference.
    final preferences = widget.preferences;
    if (preferences != null) {
      _viewModel.setAutoKey(preferences.animationAutoKey);
      _viewModel.onAutoKeyChanged = preferences.setAnimationAutoKey;
    }

    if (_ownsViewModel) {
      _viewModel.load().then((_) {
        if (mounted) {
          setState(() {
            if (_viewModel.allBones.length <= 60) {
              for (final node in _viewModel.allBones) {
                _expandedNodeIndices.add(node.index);
              }
            } else {
              for (final node in _viewModel.rootBones) {
                _expandedNodeIndices.add(node.index);
              }
            }
            // An authored sequence is posed bone by bone: show the skeleton.
            if (_viewModel.isAuthored) _activeLeftTab = 1;
          });
        }
      });
    } else {
      if (_viewModel.allBones.length <= 60) {
        for (final node in _viewModel.allBones) {
          _expandedNodeIndices.add(node.index);
        }
      } else {
        for (final node in _viewModel.rootBones) {
          _expandedNodeIndices.add(node.index);
        }
      }
      if (_viewModel.isAuthored) _activeLeftTab = 1;
    }
  }

  @override
  void dispose() {
    if (_viewModel.onAutoKeyChanged == widget.preferences?.setAnimationAutoKey) _viewModel.onAutoKeyChanged = null;
    _focusNode.dispose();
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_handleAuthoringKey(event)) return KeyEventResult.handled;

    if (event.logicalKey == LogicalKeyboardKey.space) {
      _viewModel.togglePlay();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _viewModel.stepFrame(-1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _viewModel.stepFrame(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      // A click anywhere in the editor brings its shortcuts back (Space,
      // arrows, Ctrl+Z, Delete, K) when focus was elsewhere.
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (!_focusNode.hasFocus) _focusNode.requestFocus();
        },
        child: ListenableBuilder(
        listenable: Listenable.merge([_viewModel, _viewModel.transactions]),
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
                    Text('Loading Animation clip & character rig...', style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
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
                    Text('Failed to load animation asset at ${_viewModel.assetPath}', style: const TextStyle(fontSize: 11, color: EditorColors.foreground)),
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

                // 2. Main Workspace (Left Sidebar + Center 3D Viewport + Right Panels)
                Expanded(
                  child: ResizablePanel.horizontal(
                    children: [
                      // Left Panel: Asset Properties & Skeleton Bone Tracks & Notifies
                      ResizablePane(
                        initialSize: 280,
                        minSize: 220,
                        child: Container(
                          color: EditorColors.cardHeader,
                          child: _buildLeftSidebar(),
                        ),
                      ),

                      // Center Panel: 3D Viewport + Bottom Timeline Transport (vertically resizable)
                      ResizablePane.flex(
                        child: ResizablePanel.vertical(
                          key: const ValueKey('anim_center_vertical_panel'),
                          draggerBuilder: (context) => const VerticalResizableDragger(),
                          children: [
                            // 3D Viewport with Live Stats Overlay & Root Motion Switch
                            ResizablePane.flex(
                              child: Stack(
                                children: [
                                  _buildViewport(),
                                  // Top-Left Stats Overlay HUD
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: EditorColors.card.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: EditorColors.border),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: _viewModel.isPlaying ? Colors.green : Colors.orange,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Frame: ${_viewModel.currentFrame} / ${_viewModel.totalFrames}',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '(${_viewModel.formattedTime} / ${_viewModel.formattedTotalTime}s)',
                                                style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Clip: ${_viewModel.activeClip?.name ?? "None"} | ${_viewModel.frameRate.toInt()} FPS | Speed: ${_viewModel.speed}x',
                                            style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                                          ),
                                          if (_viewModel.rateScale != 1.0)
                                            Text(
                                              'Rate Scale: ${_viewModel.rateScale.toStringAsFixed(2)}x (Effective: ${(_viewModel.speed * _viewModel.rateScale).toStringAsFixed(2)}x)',
                                              style: const TextStyle(fontSize: 8.5, color: Colors.cyan),
                                            ),
                                          if (_viewModel.recentlyFiredNotifies.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Row(
                                                children: [
                                                  const Icon(LucideIcons.bellRing, size: 10, color: Colors.orange),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Active Notifies: ${_viewModel.recentlyFiredNotifies.length} (${_viewModel.recentlyFiredNotifies.map((n) => n.name).join(", ")})',
                                                    style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.orange),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Bottom-Left Onion Skin HUD (authored sequences)
                                  if (_viewModel.isAuthored)
                                    Positioned(
                                      left: 12,
                                      bottom: 44,
                                      child: _onionSkinHud(),
                                    ),

                                  // Top-Right Root Motion Toggle HUD
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: EditorColors.card.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: EditorColors.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Enable Root Motion',
                                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                                          ),
                                          const SizedBox(width: 8),
                                          Switch(
                                            value: _viewModel.enableRootMotion,
                                            onChanged: (val) => _viewModel.setRootMotion(val),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Bottom Transport Timeline Panel
                            ResizablePane(
                              initialSize: _bottomTimelineHeight,
                              minSize: 120,
                              onSizeChangeEnd: (size) => setState(() => _bottomTimelineHeight = size),
                              child: _buildBottomTimelinePanel(),
                            ),
                          ],
                        ),
                      ),

                      // Right Panel: Curves & BlendSpace Editors
                      ResizablePane(
                        initialSize: 320,
                        minSize: 260,
                        child: Container(
                          color: EditorColors.cardHeader,
                          child: _buildRightSidebar(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        ),
      ),
    );
  }
}
