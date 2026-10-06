// design-token-exempt: 3D viewport canvas painter overlays and debug stats
import 'package:lumina_ui/ui/features/main_editor/services/gizmo_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/services/transform_gizmo.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart' hide GizmoMode;
import 'package:flutter_filament/flutter_filament.dart' as fil show GizmoMode;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import '../../../core/services/editor_mesh_budget.dart';
import '../../../core/services/editor_procedural_sky.dart';
import '../../../core/services/editor_scene_environment.dart';
import '../../../core/widgets/rtx_settings_popover.dart';
import '../../../core/theme/editor_theme.dart';
import '../view_models/editor_view_model.dart';
import '../services/snap_service.dart';
import '../services/viewport_picker.dart';
import '../services/editor_preferences.dart';
import '../services/editor_transform.dart';
import '../services/blueprint_play_support.dart';
import '../services/editor_level_lights.dart';
import '../services/editor_level_post_process.dart';
import '../services/editor_level_scene.dart';
import '../services/editor_view_layers.dart';
import 'viewport_widget/mesh_bind_scheduler.dart';
import '../services/environment_actor_properties.dart';
import '../services/light_actor_properties.dart';
import 'pie_debug_draw_layer.dart';
import 'pie_mouse_capture_layer.dart';
import 'pie_widget_layer.dart';
import '../services/pie_debug_projection.dart';
import 'play_blocked_dialog.dart';
import 'camera_preview_panel.dart';

part 'viewport_widget/state.dart';
part 'viewport_widget/wireframes.dart';
part 'viewport_widget/scene_sync.dart';
part 'viewport_widget/pie_session.dart';
part 'viewport_widget/camera_controls.dart';
part 'viewport_widget/pointer_interaction.dart';
part 'viewport_widget/painters.dart';

class ViewportWidget extends StatefulWidget {
  final EditorViewModel viewModel;

  const ViewportWidget({super.key, required this.viewModel});

  @override
  State<ViewportWidget> createState() => _ViewportWidgetState();
}

class _ViewportWidgetState extends _ViewportWidgetStateBase
    with
        _ViewportWireframes,
        _ViewportSceneSync,
        _ViewportPieSession,
        _ViewportCameraControls,
        _ViewportPointerInteraction {

  /// Gizmo geometry, in gizmo-local units, mirrored from
  /// `FilamentTransformGizmo`: the axis length and the plane-handle offset.
  static const double _gizmoAxisLen = 65.0;
  static const double _gizmoPlaneDist = 22.0;

  static const double _gizmoScreenFraction = 0.16;

  /// The static-mesh wireframe colour and its selection colour.
  static const _wireframeColor = (0.0, 0.5, 1.0);
  static const _wireframeSelectedColor = (1.0, 0.55, 0.1);

  /// The sub-editor's cap for a selected node's wireframe, per actor.
  static const _wireframeIndexCap = 600000;

  /// Length of a directional light's arrow, cm.
  static const double _lightArrowLength = 150.0;

  @override
  void initState() {
    super.initState();
    // PIE loads meshes by path: budget them like the actors' payloads.
    EditorMeshBudget.ensureInstalled();
    widget.viewModel.addListener(_onViewModelUpdated);
    _flyTicker = createTicker(_onFlyTick);
    _flyTicker.start();
    _pieTicker = createTicker(_onPieTick);
    _pieTicker.start();
    widget.viewModel.onStartSimulationRequest = _startPie;
    widget.viewModel.onStopSimulationRequest = _stopPie;
    widget.viewModel.onPlayBlocked = _showPlayBlocked;
    widget.viewModel.onPlayWarnings = _showPlayWarnings;
    EditorSceneEnvironment.ensureAssetsLoaded();
  }

  @override
  void didUpdateWidget(covariant ViewportWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_onViewModelUpdated);
      widget.viewModel.addListener(_onViewModelUpdated);
    }
    final isPaused = widget.viewModel.activeTabIndex != 0 || widget.viewModel.buildManagerViewModel.isRunning;
    if (!isPaused) {
      if (_pendingSceneSync) {
        _pendingSceneSync = false;
        _syncPieSession();
        _syncActorAssets();
        _syncGrid();
        _syncSceneEnvironment();
        _syncProceduralSky();
        _syncAutoExposure();
        if (_editorCameraPose != _pushedCameraPose) _updateNativeCamera();
      }
    }
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelUpdated);
    _flyTicker.dispose();
    _pieTicker.dispose();
    _keyboardFocus.dispose();
    if (widget.viewModel.onStartSimulationRequest == _startPie) {
      widget.viewModel.onStartSimulationRequest = null;
    }
    if (widget.viewModel.onStopSimulationRequest == _stopPie) {
      widget.viewModel.onStopSimulationRequest = null;
    }
    if (widget.viewModel.onPlayBlocked == _showPlayBlocked) widget.viewModel.onPlayBlocked = null;
    if (widget.viewModel.onPlayWarnings == _showPlayWarnings) widget.viewModel.onPlayWarnings = null;
    _stopPie();
    _speedBadgeTimer?.cancel();
    // Normally done in the FilamentWidget's onDispose, while the scene lives;
    // idempotent. Then give the engine back.
    _disposeNative();
    _engineLease?.release();
    _engineLease = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _applyEditorQuality();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 0 &&
            (_viewportWidth != constraints.maxWidth ||
                _viewportHeight != constraints.maxHeight)) {
          _viewportWidth = constraints.maxWidth;
          _viewportHeight = constraints.maxHeight;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _updateNativeCamera(),
          );
        }
        return Container(
          key: _viewportKey,
          color: EditorColors.viewportBackdrop,
          child: DragTarget<RealAssetInfo>(
            onWillAcceptWithDetails: (details) => true,
            onMove: (details) {
              final renderBox =
                  _viewportKey.currentContext?.findRenderObject() as RenderBox?;
              setState(() {
                _dropPreviewPos = null;
                _dropPreviewAsset = null;
              });
              if (renderBox != null) {
                setState(() {
                  _dropPreviewPos = renderBox.globalToLocal(details.offset);
                  _dropPreviewAsset = details.data;
                });
              }
            },
            onLeave: (data) {
              setState(() {
                _dropPreviewPos = null;
                _dropPreviewAsset = null;
              });
            },
            onAcceptWithDetails: (details) async {
              final renderBox =
                  _viewportKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                final localOffset = renderBox.globalToLocal(details.offset);
                final worldPos = _unprojectRayToFloor(
                  localOffset,
                  renderBox.size,
                  widget.viewModel.cameraYaw,
                  widget.viewModel.cameraPitch,
                  widget.viewModel.cameraDistance,
                  widget.viewModel.cameraPanX,
                  widget.viewModel.cameraPanY,
                  widget.viewModel.cameraPanZ,
                );
                EngineLoggerService().log(
                  'DragTarget accepted asset "${details.data.fileName}" at screen offset (${localOffset.dx.toStringAsFixed(1)}, ${localOffset.dy.toStringAsFixed(1)}) -> Unprojected 3D floor coordinate: [${worldPos.dx.toStringAsFixed(2)}, ${worldPos.dy.toStringAsFixed(2)}, 0.0]',
                  level: 'info',
                  source: 'ViewportDragDrop',
                );
                // The drop is done: the marker must go, or a green cross sits on
                // the viewport until the next drag happens to clear it.
                setState(() {
                  _dropPreviewPos = null;
                  _dropPreviewAsset = null;
                  _skipReadPixelsFrames = 20;
                });
                await widget.viewModel.spawnActorFromAsset(
                  details.data,
                  location: [worldPos.dx, worldPos.dy, 0.0],
                );
                if (mounted) {
                  setState(() {
                    _dropPreviewPos = null;
                    _dropPreviewAsset = null;
                    _skipReadPixelsFrames = 20;
                  });
                }
              }
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;

              final activeAxis = _draggingGizmoAxis ?? _hoveredGizmoAxis;

              return Focus(
                focusNode: _keyboardFocus,
                autofocus: true,
                onKeyEvent: (node, event) {
                  // The running game takes the keyboard itself, in PieController,
                  // because the editor's focus can be on any panel when Play is
                  // pressed. Here we only keep the editor flycam off those keys.
                  if (widget.viewModel.pieController.acceptsGameInput) {
                    return KeyEventResult.ignored;
                  }
                  if (event is KeyDownEvent || event is KeyRepeatEvent) {
                    _pressedKeys.add(event.logicalKey);
                    // Chords (Ctrl+S, Ctrl+D, Ctrl+Z, Alt+P, ...) are the
                    // editor shell's shortcuts, not camera keys.
                    final keyboard = HardwareKeyboard.instance;
                    if (keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed) {
                      return KeyEventResult.ignored;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.keyF) {
                      if (widget.viewModel.selectedActor != null) {
                        widget.viewModel.focusCameraOnActor(
                          widget.viewModel.selectedActor!,
                        );
                      } else {
                        widget.viewModel.resetCamera();
                      }
                      _updateNativeCamera();
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.end) {
                      _handleEndDrop();
                      return KeyEventResult.handled;
                    }
                    final label = event.logicalKey.keyLabel.toLowerCase();
                    // W/A/S/D/Q/E fly the camera as Editor Preferences say
                    // (by default while the right button is
                    // held); otherwise Q/W/E/R are the transform tools, which
                    // the shell's shortcuts switch.
                    if (['w', 'a', 's', 'd', 'q', 'e'].contains(label)) {
                      return _wasdFlies ? KeyEventResult.handled : KeyEventResult.ignored;
                    }
                    // Space cycles Move → Rotate → Scale.
                    if (event.logicalKey == LogicalKeyboardKey.space) {
                      if (event is KeyDownEvent) _cycleTransformTool();
                      return KeyEventResult.handled;
                    }
                    if ([
                      'arrow up',
                      'arrow down',
                      'arrow left',
                      'arrow right',
                    ].contains(label)) {
                      if (!_isRmbDown) {
                        widget.viewModel.moveCameraWASD(label);
                        _updateNativeCamera();
                      }
                      return KeyEventResult.handled;
                    }
                  } else if (event is KeyUpEvent) {
                    _pressedKeys.remove(event.logicalKey);
                  }
                  return KeyEventResult.ignored;
                },
                child: Stack(
                  children: [
                    // 1. Native Filament C++ Vulkan GPU Viewport Background Layer
                    Positioned.fill(
                      child: FilamentWidget(
                        showFpsBadge: widget.viewModel.showFlags['FPS'] == true,
                        onFrame: (cpu, frame) {
                          widget.viewModel.reportFrameTime(cpu, frame);
                          // A sky light that finished loading, a light a
                          // Play session switched.
                          _syncAutoExposure();
                        },
                        isPaused: widget.viewModel.activeTabIndex != 0 || widget.viewModel.buildManagerViewModel.isRunning,
                        pauseRendering: widget.viewModel.buildManagerViewModel.isRunning,
                        skipReadPixels: _skipReadPixelsFrames > 0,
                        debugLabel: 'Level viewport',
                        onDispose: _disposeNative,
                        onSceneCreated: (engine, scene, camera, view) {
                          try {
                            _nativeEngine = engine;
                            // Keep the shared engine until State.dispose.
                            if (_engineLease == null || _engineLease!.isReleased) {
                              _engineLease?.release();
                              _engineLease = FilamentEngineHost.retain(engine, owner: 'Level viewport state');
                            }
                            // The GPU this engine landed on, for the status
                            // bar and Launcher Settings.
                            LuminaGraphicsDevices.reportEngine(engine);
                            _nativeCamera = camera;
                            _appliedEv100 = null;
                            _nativeScene = scene;
                            _nativeView = view;
                            _appliedViewLayers = null;
                            view.setDynamicLightingOptions(LuminaUnits.dynamicLightingNear, LuminaUnits.dynamicLightingFar);
                            _rtxController?.dispose();
                            _rtxController = LuminaRtxController(engine: engine, view: view, scene: scene);
                            _applyEditorQuality(force: true);

                            _updateNativeCamera();

                            // The level's own lights, as PIE lights it: no
                            // preview sun or fill light.
                            _levelLights.attach(engine, scene, view);
                            _levelPostProcess.attach(engine, scene, view);

                            // The level's sky + image-based lighting, when it
                            // has an Environment actor (none otherwise).
                            _sceneEnvironment.attach(engine, scene);
                            _syncSceneEnvironment();
                            _proceduralSky.attach(engine, scene);
                            _syncProceduralSky();

                            // Initialize Native Filament 3D GPU Editor Visuals
                            _syncGrid();
                            // _selectionBoxes managed in _syncActorAssets
                            _nativeGizmo = FilamentTransformGizmo(engine);

                            // Meshes come from lumina's shared engine cache,
                            // not a loader of our own.
                            _syncActorAssets();

                            // Other views of the level (the Sequencer's
                            // viewport) draw this scene.
                            widget.viewModel.levelScene.value = EditorLevelScene(engine: engine, scene: scene, camera: camera);
                          } catch (e) {
                            debugPrint(
                              '[Lumina Main Viewport] Filament C++ FFI init error: $e',
                            );
                          }
                        },
                      ),
                    ),

                    // 3D Viewport Interaction Layer (Navigation: RMB Flycam, LMB Walk/Orbit, MMB Pan, Alt Dolly, Scroll Speed)
                    MouseRegion(
                      cursor: _viewportCursor(),
                      onHover: (event) {
                        if (widget.viewModel.pieController.acceptsGameInput) {
                          widget.viewModel.pieController.injectPointerDelta(
                            event.delta.dx,
                            event.delta.dy,
                          );
                          return;
                        }
                        final renderBox =
                            _viewportKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        if (renderBox != null) {
                          _handleMouseHover(
                            event.localPosition,
                            renderBox.size,
                          );
                        }
                      },
                      child: Listener(
                        onPointerDown: (event) {
                          _downPos = event.localPosition;
                          _hasMovedDuringDrag = false;
                          if (!_keyboardFocus.hasPrimaryFocus) _keyboardFocus.requestFocus();
                          // A text field this press lands outside of (a search
                          // box, a Details field) unfocuses itself on the same
                          // pointer event, after this listener, which would hand
                          // focus to the shell's scope and leave RMB + WASD dead
                          // Ask again once that has run.
                          scheduleMicrotask(() {
                            if (mounted && !_keyboardFocus.hasPrimaryFocus) _keyboardFocus.requestFocus();
                          });

                          if ((event.buttons & kSecondaryMouseButton) != 0) {
                            _isRmbDown = true;
                            // The shell's single-key shortcuts stand down while flying.
                            widget.viewModel.isFlyNavigating = true;
                          }
                          if ((event.buttons & kPrimaryMouseButton) != 0) {
                            _isLmbDown = true;
                            final renderBox =
                                _viewportKey.currentContext?.findRenderObject()
                                    as RenderBox?;
                            if (renderBox != null) {
                              _handlePanStart(
                                event.localPosition,
                                renderBox.size,
                              );
                              if (_draggingGizmoAxis == null &&
                                  widget.viewModel.activeTool == 'select') {
                                if (!_checkActorHitForMarqueeStart(
                                  event.localPosition,
                                  renderBox.size,
                                )) {
                                  _marqueeStart = event.localPosition;
                                  _marqueeCurrent = event.localPosition;
                                }
                              }
                            }
                          }
                          if ((event.buttons & kMiddleMouseButton) != 0) {
                            _isMmbDown = true;
                          }
                          setState(() {});
                        },
                        onPointerMove: (event) {
                          if (widget.viewModel.pieController.acceptsGameInput) {
                            widget.viewModel.pieController.injectPointerDelta(
                              event.delta.dx,
                              event.delta.dy,
                            );
                            return;
                          }
                          if ((event.position - _downPos).distance > 3.0) {
                            _hasMovedDuringDrag = true;
                          }

                          final isAlt = HardwareKeyboard.instance.isAltPressed;
                          final buttons = event.buttons;

                          // A. Both Left + Right Buttons Held Together (Pan & Pedestal)
                          if ((buttons &
                                  (kPrimaryMouseButton |
                                      kSecondaryMouseButton)) ==
                              (kPrimaryMouseButton | kSecondaryMouseButton)) {
                            widget.viewModel.panPedestal(
                              event.delta.dx,
                              event.delta.dy,
                            );
                            _updateNativeCamera();
                          }
                          // B. Right Mouse Button (Flycam Look / Alt+RMB Dolly)
                          else if ((buttons & kSecondaryMouseButton) != 0) {
                            if (isAlt) {
                              // Alt + RMB Smooth Dolly Zoom
                              widget.viewModel.dollyCamera(
                                -event.delta.dy * 2.0,
                              );
                              _updateNativeCamera();
                            } else {
                              // RMB Mouselook (First-person gaze rotation)
                              widget.viewModel.rotateCamera(
                                event.delta.dx,
                                event.delta.dy,
                              );
                              _updateNativeCamera();
                            }
                          }
                          // C. Left Mouse Button (Alt+LMB Orbit, Gizmo Drag, or Walk & Turn)
                          else if ((buttons & kPrimaryMouseButton) != 0) {
                            if (isAlt) {
                              // Alt + LMB Orbit / Tumble Camera around Pivot
                              widget.viewModel.orbitCamera(
                                event.delta.dx,
                                event.delta.dy,
                              );
                              _updateNativeCamera();
                            } else if (_draggingGizmoAxis != null) {
                              // Dragging 3D Actor Transform Gizmo Axis
                              _handleGizmoDrag(event.localPosition);
                              _updateNativeCamera();
                            } else if (_marqueeStart != null) {
                              _marqueeCurrent = event.localPosition;
                              setState(() {});
                            } else if (_hasMovedDuringDrag) {
                              // LMB Walk (Forward/Backward & Turn Yaw)
                              widget.viewModel.walkMove(
                                event.delta.dx,
                                event.delta.dy,
                              );
                              _updateNativeCamera();
                            }
                          }
                          // D. Middle Mouse Button (MMB Screen-Space Pan)
                          else if ((buttons & kMiddleMouseButton) != 0 ||
                              (buttons == kPrimaryMouseButton &&
                                  isAlt &&
                                  HardwareKeyboard.instance.isShiftPressed)) {
                            widget.viewModel.panCamera(
                              event.delta.dx,
                              event.delta.dy,
                            );
                            _updateNativeCamera();
                          }
                          // E. Hovering without buttons
                          else {
                            final renderBox =
                                _viewportKey.currentContext?.findRenderObject()
                                    as RenderBox?;
                            if (renderBox != null) {
                              _handleMouseHover(
                                event.localPosition,
                                renderBox.size,
                              );
                            }
                          }
                        },
                        onPointerUp: (event) {
                          if ((event.buttons & kSecondaryMouseButton) == 0) {
                            _isRmbDown = false;
                            widget.viewModel.isFlyNavigating = false;
                          }
                          // A left-button release only: releasing the right
                          // button (fly / look) or the middle one is camera
                          // navigation, never a selection click.
                          if (_isLmbDown && (event.buttons & kPrimaryMouseButton) == 0) {
                            if (_draggingGizmoAxis != null) {
                              widget.viewModel.endTransformDrag();
                              _draggingGizmoAxis = null;
                              _marqueeStart = null;
                              _marqueeCurrent = null;
                            } else if (!_hasMovedDuringDrag) {
                              // Click selection only when mouse did not drag
                              final renderBox =
                                  _viewportKey.currentContext
                                          ?.findRenderObject()
                                      as RenderBox?;
                              if (renderBox != null) {
                                if (_marqueeStart != null &&
                                    _marqueeCurrent != null &&
                                    (_marqueeStart! - _marqueeCurrent!)
                                            .distance >
                                        5.0) {
                                  // Perform Marquee selection
                                  _applyMarqueeSelection(renderBox.size);
                                } else {
                                  _handleViewportClick(
                                    event.localPosition,
                                    renderBox.size,
                                  );
                                }
                              }
                            }
                            _marqueeStart = null;
                            _marqueeCurrent = null;
                            _isLmbDown = false;
                          }
                          if ((event.buttons & kMiddleMouseButton) == 0) {
                            _isMmbDown = false;
                          }
                          setState(() {});
                        },
                        onPointerCancel: (_) {
                          _isRmbDown = false;
                          widget.viewModel.isFlyNavigating = false;
                          _isLmbDown = false;
                          _isMmbDown = false;
                          _draggingGizmoAxis = null;
                          setState(() {});
                        },
                        onPointerSignal: (event) {
                          if (event is PointerScrollEvent) {
                            if (_isRmbDown) {
                              // RMB + Scroll Wheel = Adjust Camera Fly Speed
                              widget.viewModel.adjustCameraSpeed(
                                event.scrollDelta.dy > 0 ? -1 : 1,
                              );
                              _triggerSpeedFeedback();
                            } else {
                              // Standard Dolly Zoom Step
                              widget.viewModel.dollyCamera(
                                event.scrollDelta.dy * 0.5,
                              );
                            }
                            _updateNativeCamera();
                          }
                        },
                        child: CustomPaint(
                          size: Size.infinite,
                          // While the game's camera owns the view, every editor
                          // overlay is drawn with the wrong projection and belongs
                          // to a scene the player is not looking at. Suspend them.
                          painter: _pieCameraDrivesView
                              ? null
                              : _PerspectiveGridPainter(
                                  viewModel: widget.viewModel,
                                  activeGizmoAxis:
                                      _hoveredGizmoAxis ?? _draggingGizmoAxis,
                                  marqueeRect:
                                      (_marqueeStart != null &&
                                          _marqueeCurrent != null)
                                      ? Rect.fromPoints(
                                          _marqueeStart!,
                                          _marqueeCurrent!,
                                        )
                                      : null,
                                  dropPreviewPos: _dropPreviewPos,
                                  dropPreviewName: _dropPreviewAsset?.fileName,
                                ),
                        ),
                      ),
                    ),

                    // Active Gizmo Axis Floating HUD Overlay Banner
                    if (activeAxis != null &&
                        widget.viewModel.selectedActor != null)
                      Positioned(
                        top: 40,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: EditorColors.warning,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.black,
                                width: 1.5,
                              ),
                              // Drop shadow under a HUD chip: an opacity, not a surface colour.
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xAA000000),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Text(
                              _draggingGizmoAxis != null
                                  ? 'Δ ${_draggingGizmoAxis!} (Dragging) — ${widget.viewModel.activeTool.toUpperCase()} — ${widget.viewModel.selectedActor!.location.map((e) => e.toStringAsFixed(1)).join(' | ')}'
                                  : 'ACTIVE AXIS [ $activeAxis ] — ${widget.viewModel.activeTool.toUpperCase()} — X: ${widget.viewModel.selectedActor!.location[0].toStringAsFixed(1)} | Y: ${widget.viewModel.selectedActor!.location[1].toStringAsFixed(1)} | Z: ${widget.viewModel.selectedActor!.location[2].toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontFamily: EditorTypography.monoFamily,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Camera Speed Feedback Toast Banner (shows when adjusting speed via RMB+Wheel or HUD)
                    if (_showSpeedBadge)
                      Positioned(
                        top: 40,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: EditorColors.hudSurfaceStrong,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: EditorColors.primary,
                                width: 1.5,
                              ),
                              // Drop shadow under a HUD chip: an opacity, not a surface colour.
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xAA000000),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.gauge,
                                  size: 14,
                                  color: EditorColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'CAMERA SPEED: ${widget.viewModel.cameraSpeedScalar} (${widget.viewModel.cameraSpeedMultiplier}x)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: EditorTypography.monoFamily,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Drag & Drop Hover Visual Overlay
                    if (isHovering)
                      Container(
                        color: EditorColors.primary.withValues(alpha: 0.12),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: EditorColors.primary,
                              borderRadius: BorderRadius.circular(4),
                              // Drop shadow under a HUD chip: an opacity, not a surface colour.
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x8A000000),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.plus,
                                  color: Colors.black,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'DROP ASSET INTO 3D SCENE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Play's mouse capture: the F4 hint, and the
                    // click that takes the mouse back.
                    Positioned.fill(
                      child: PieMouseCaptureLayer(pie: widget.viewModel.pieController),
                    ),

                    // Active UMG widgets added to viewport in PIE
                    if (widget.viewModel.isPlaying)
                      Positioned.fill(
                        child: PieWidgetLayer(
                          pieController: widget.viewModel.pieController,
                          projectDirPath: widget.viewModel.projectDirPath,
                        ),
                      ),

                    // Blueprint debug shapes and Print String lines during
                    // Play.
                    if (widget.viewModel.isPlaying)
                      Positioned.fill(
                        child: PieDebugDrawLayer(
                          world: () => widget.viewModel.pieController.game?.world,
                          projection: _pieDebugProjector,
                        ),
                      ),

                    // Top PIE Active Banner
                    if (widget.viewModel.isPlaying)
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: EditorColors.primary,
                              borderRadius: BorderRadius.circular(3),
                              // Drop shadow under a HUD chip: an opacity, not a surface colour.
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x8A000000),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Text(
                              widget.viewModel.isPaused
                                  ? 'PAUSED — PIE SIMULATION'
                                  : 'SIMULATE — PIE ACTIVE',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Top Left Viewport Camera Header Overlay
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: EditorColors.hudSurface,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: EditorColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.video,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.viewModel.cameraMode}  |  ${widget.viewModel.viewportMode}  |  Realtime',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: EditorColors.foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Top Right Quick Controls Overlay
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        children: [
                          _buildCameraSpeedHudBtn(),
                          const SizedBox(width: 4),
                          _buildRtxFeatureHudBtn(RtxSettingsKind.dlss),
                          const SizedBox(width: 4),
                          _buildRtxFeatureHudBtn(RtxSettingsKind.fsr3),
                          const SizedBox(width: 4),
                          _buildRtxFeatureHudBtn(RtxSettingsKind.rayTracing),
                          const SizedBox(width: 4),
                          _buildHudBtn(
                            LucideIcons.scan,
                            'Focus Selection [F]',
                            () {
                              if (widget.viewModel.selectedActor != null) {
                                widget.viewModel.focusCameraOnActor(
                                  widget.viewModel.selectedActor!,
                                );
                              } else {
                                widget.viewModel.resetCamera();
                              }
                              _updateNativeCamera();
                            },
                          ),
                          const SizedBox(width: 4),
                          _buildHudBtn(LucideIcons.zoomIn, 'Zoom In', () {
                            widget.viewModel.dollyCamera(-60);
                            _updateNativeCamera();
                          }),
                          const SizedBox(width: 4),
                          _buildHudBtn(LucideIcons.zoomOut, 'Zoom Out', () {
                            widget.viewModel.dollyCamera(60);
                            _updateNativeCamera();
                          }),
                          const SizedBox(width: 4),
                          _buildHudBtn(
                            LucideIcons.refreshCw,
                            'Reset Camera',
                            () {
                              widget.viewModel.resetCamera();
                              _updateNativeCamera();
                            },
                          ),
                        ],
                      ),
                    ),

                    // Bottom Left Live World Coordinate Info
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        color: EditorColors.hudSurfaceStrong,
                        child: Row(
                          children: [
                            Text(
                              'Camera: Pos [${widget.viewModel.cameraPanX.toStringAsFixed(0)}, ${widget.viewModel.cameraPanY.toStringAsFixed(0)}, ${widget.viewModel.cameraPanZ.toStringAsFixed(0)}]  Pitch ${widget.viewModel.cameraPitch.toStringAsFixed(1)}°  Yaw ${widget.viewModel.cameraYaw.toStringAsFixed(1)}°  Dist ${widget.viewModel.cameraDistance.toStringAsFixed(0)}  Speed ${widget.viewModel.cameraSpeedScalar} (${widget.viewModel.cameraSpeedMultiplier}x)',
                              style: const TextStyle(
                                fontSize: 9,
                                fontFamily: EditorTypography.monoFamily,
                                color: EditorColors.mutedForeground,
                              ),
                            ),
                            const VerticalDivider(
                              width: 16,
                              indent: 4,
                              endIndent: 4,
                            ),
                            Text(
                              'Selected: ${widget.viewModel.selectedActor?.name ?? "None"}',
                              style: const TextStyle(
                                fontSize: 9,
                                fontFamily: EditorTypography.monoFamily,
                                color: EditorColors.primary,
                              ),
                            ),
                            const Spacer(),
                            // Updates every rendered frame.
                            RepaintBoundary(
                              child: ListenableBuilder(
                                listenable: widget.viewModel.frameStats,
                                builder: (context, _) => Text(
                                  widget.viewModel.viewportStatsLabel,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontFamily: EditorTypography.monoFamily,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // A selected camera's preview, bottom-left: what it sees.
                    Positioned.fill(
                      child: CameraPreviewOverlay(
                        viewModel: widget.viewModel,
                        viewportSize: Size(_viewportWidth, _viewportHeight),
                        isPaused: widget.viewModel.activeTabIndex != 0,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Vertical field of view of the editor viewport camera, in degrees. The
/// native Filament camera and the 2D overlay projection must agree on it, or
/// what the user points at is not what the editor thinks they pointed at.
const double kViewportFovDegrees = 45.0;
