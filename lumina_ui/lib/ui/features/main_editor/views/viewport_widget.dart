// design-token-exempt: 3D viewport canvas painter overlays and debug stats
import 'package:lumina_ui/ui/core/widgets/viewport_pills.dart';
import 'package:lumina_ui/ui/features/main_editor/views/level_viewport_chrome.dart';
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
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/services/editor_mesh_budget.dart';
import 'package:lumina_ui/ui/core/services/editor_procedural_sky.dart';
import 'package:lumina_ui/ui/core/services/editor_scene_environment.dart';
import 'package:lumina_ui/ui/core/widgets/rtx_settings_popover.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/services/snap_service.dart';
import 'package:lumina_ui/ui/features/main_editor/services/viewport_picker.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_preferences.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_transform.dart';
import 'package:lumina_ui/ui/features/main_editor/services/blueprint_play_support.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_level_lights.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_level_post_process.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_neural_rendering.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_level_scene.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_view_layers.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget/mesh_bind_scheduler.dart';
import 'package:lumina_ui/ui/features/main_editor/services/environment_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/services/light_actor_properties.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_debug_draw_layer.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_mouse_capture_layer.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_widget_layer.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_debug_projection.dart';
import 'package:lumina_ui/ui/features/main_editor/views/play_blocked_dialog.dart';
import 'package:lumina_ui/ui/features/main_editor/views/camera_preview_panel.dart';

part 'viewport_widget/state.dart';
part 'viewport_widget/wireframes.dart';
part 'viewport_widget/scene_sync.dart';
part 'viewport_widget/pie_session.dart';
part 'viewport_widget/camera_controls.dart';
part 'viewport_widget/pointer_interaction.dart';
part 'viewport_widget/painters.dart';
part 'viewport_widget/input_layer.dart';
part 'viewport_widget/hud_overlays.dart';

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
        _ViewportPointerInteraction,
        _ViewportInputLayer,
        _ViewportHudOverlays {

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
    if (!_sceneSyncPaused) {
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
                onKeyEvent: _onViewportKeyEvent,
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
                          _neuralRendering.tick();
                        },
                        isPaused: widget.viewModel.activeTabIndex != 0 || widget.viewModel.buildManagerViewModel.isRunning,
                        pauseRendering: widget.viewModel.buildManagerViewModel.isRunning,
                        skipReadPixels: _skipReadPixelsFrames > 0,
                        debugLabel: 'Level viewport',
                        // Play shows the game edge to edge: the view's pixels
                        // are the viewport's, where the game's mouse maps.
                        decorated: !_pieOwnsTheScene,
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
                            // Project Settings > Neural rendering (OpenDLSS-NR), on this view for editing and PIE.
                            _neuralRendering.attach(engine, view);
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
                    _buildViewportInputLayer(),

                    // Active Gizmo Axis Floating HUD Overlay Banner
                    if (activeAxis != null &&
                        widget.viewModel.selectedActor != null)
                      _buildActiveAxisBanner(activeAxis),

                    // Camera Speed Feedback Toast Banner (shows when adjusting speed via RMB+Wheel or HUD)
                    if (_showSpeedBadge)
                      _buildCameraSpeedBadge(),

                    // Drag & Drop Hover Visual Overlay
                    if (isHovering)
                      _buildDropHoverOverlay(),

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
                      _buildPieBanner(),

                    // The chrome's top row: pills and tool column at the
                    // left, stats and quick controls at the right.
                    _buildCameraHeader(),

                    // Bottom Left Live World Coordinate Info
                    _buildCoordinateBar(),

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
