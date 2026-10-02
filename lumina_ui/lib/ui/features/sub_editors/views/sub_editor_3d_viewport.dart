import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_filament/flutter_filament.dart' hide GizmoMode;
import '../services/material_preview_renderer.dart';
import '../services/viewport_mesh.dart';
import '../services/preview_mesh_factory.dart';
import '../view_models/material_editor_view_model.dart'
    show MaterialParamModel, MaterialParamType;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import '../../../core/services/editor_mesh_budget.dart';
import '../../../core/services/editor_scene_environment.dart';
import '../../../core/theme/editor_theme.dart';
import 'package:vector_math/vector_math_64.dart'
    show Vector3, Matrix4, Quaternion, Ray;

import '../models/animation_playback_controller.dart';
import '../models/skeletal_mesh_socket.dart';
import '../models/skeletal_socket_attachment.dart';
import '../models/sub_editor_canvas_overlay.dart';
import '../models/sub_editor_line_set.dart';
import '../models/sub_editor_mesh_component.dart';
import '../models/viewport_ray.dart';
import '../models/sub_editor_transform_gizmo.dart';
import '../../main_editor/services/transform_gizmo.dart';
import 'sub_editor_transform_gizmo_painter.dart';

export '../models/sub_editor_canvas_overlay.dart';
export '../models/sub_editor_line_set.dart';
export '../models/sub_editor_mesh_component.dart';
export '../models/skeletal_socket_attachment.dart';

part 'sub_editor_3d_viewport/state.dart';
part 'sub_editor_3d_viewport/camera.dart';
part 'sub_editor_3d_viewport/gizmo.dart';
part 'sub_editor_3d_viewport/native_scene.dart';
part 'sub_editor_3d_viewport/overlays.dart';
part 'sub_editor_3d_viewport/pose_and_materials.dart';
part 'sub_editor_3d_viewport/mesh_painter.dart';
part 'sub_editor_3d_viewport/mesh_painting.dart';
part 'sub_editor_3d_viewport/widget.dart';
part 'sub_editor_3d_viewport/skeleton_painter.dart';

class _SubEditor3DViewportState extends _SubEditor3DViewportStateBase
    with
        _SubEditor3DViewportCamera,
        _SubEditor3DViewportGizmo,
        _SubEditor3DViewportNativeScene,
        _SubEditor3DViewportOverlays,
        _SubEditor3DViewportPoseAndMaterials {

  static bool _usedNativePreview(SubEditor3DViewport w) =>
      w.onPreviewWorldReady != null ||
      SubEditor3DViewport.usesNativePreview(
        glbMesh: w.glbMesh,
        meshComponents: w.meshComponents,
        previewMaterialBytes: w.previewMaterialBytes,
      );

  /// Pixels the gizmo's arrows span on screen, whatever the distance.
  static const double _gizmoScreenPixels = 110.0;

  @override
  void initState() {
    super.initState();
    _shape = widget.initialShape;
    _cameraYaw = widget.initialCameraYaw ?? -35.0;
    widget.playbackController?.addListener(_onPlaybackChanged);
    widget.transformGizmo?.addListener(_onGizmoChanged);
    _recalculateBoundsAndFraming();
    EditorSceneEnvironment.ensureAssetsLoaded();
    // Preview worlds load meshes by path: budget them like the payloads.
    EditorMeshBudget.ensureInstalled();
    _startWarmupTimer();
  }

  @override
  void didUpdateWidget(covariant SubEditor3DViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playbackController != oldWidget.playbackController) {
      oldWidget.playbackController?.removeListener(_onPlaybackChanged);
      widget.playbackController?.addListener(_onPlaybackChanged);
    }
    if (widget.transformGizmo != oldWidget.transformGizmo) {
      oldWidget.transformGizmo?.removeListener(_onGizmoChanged);
      widget.transformGizmo?.addListener(_onGizmoChanged);
    }
    final componentsChanged =
        widget.meshComponents != oldWidget.meshComponents ||
        (widget.meshComponents?.length != oldWidget.meshComponents?.length);
    final meshSourceChanged =
        oldWidget.glbMesh?.rawPayload != widget.glbMesh?.rawPayload ||
        (oldWidget.glbMesh == null) != (widget.glbMesh == null) ||
        componentsChanged;
    if (meshSourceChanged) {
      _skipReadPixelsFrames = 25;
      _startWarmupTimer();
      _recalculateBoundsAndFraming();
      _updateNativeCamera();
    } else if (_hasNativePreview && !_usedNativePreview(oldWidget)) {
      // A material opened from disk has no compiled package on its first
      // build, so the warm-up could not start in initState. Start it now,
      // or the readback skip never counts down and the preview shows only
      // FilamentWidget's status text.
      _skipReadPixelsFrames = 25;
      _startWarmupTimer();
    }
    if (componentsChanged &&
        _nativeEngine != null &&
        _nativeScene != null &&
        _drawsMeshes) {
      _rebuildComponentAssets(_nativeEngine!, _nativeScene!);
    }
    final glbMeshChanged =
        oldWidget.glbMesh?.rawPayload != widget.glbMesh?.rawPayload ||
        (oldWidget.glbMesh == null) != (widget.glbMesh == null) ||
        oldWidget.meshSourcePath != widget.meshSourcePath;
    if (glbMeshChanged &&
        _nativeEngine != null &&
        _nativeScene != null &&
        _drawsMeshes &&
        (widget.meshComponents == null || widget.meshComponents!.isEmpty)) {
      if (widget.glbMesh?.rawPayload != null &&
          widget.glbMesh!.rawPayload!.isNotEmpty) {
        _loadNativeMesh(
          _nativeEngine!,
          _nativeScene!,
          widget.glbMesh!.rawPayload!,
        );
      } else if (_nativeAsset != null) {
        _releaseSocketAttachments();
        _nativeAsset!.removeFromScene(_nativeScene!);
        _nativeAsset!.dispose();
        _nativeAsset = null;
        if (_nativeWireframeMesh != null) {
          _nativeScene!.removeEntity(_nativeWireframeMesh!.entityId);
          _nativeWireframeMesh!.dispose();
          _nativeWireframeMesh = null;
        }
      }
    }
    if (_isMaterialPreview && _nativeEngine != null && _nativeScene != null) {
      final bytesChanged = !identical(
        oldWidget.previewMaterialBytes,
        widget.previewMaterialBytes,
      );
      if (bytesChanged || !_materialPreview.isMounted) {
        _mountMaterialPreview(_nativeEngine!, _nativeScene!);
      } else if (oldWidget.previewMaterialRevision !=
          widget.previewMaterialRevision) {
        _materialPreview.applyParameters(widget.previewMaterialParams);
      }
      if (oldWidget.initialShape != widget.initialShape) {
        _shape = widget.initialShape;
        _materialPreview.setShape(_shape);
        if (_materialFramed) {
          _cameraDistance = _materialFitDistance();
          _updateNativeCamera();
        }
      }
    }
    _updateNodeVisibilities();
    _updateSelectedNodeWireframe();
    _updateCollisionLines();
    _updateOverlayLines();
    if (oldWidget.socketAttachments.map((a) => a.signature).join(';') !=
        widget.socketAttachments.map((a) => a.signature).join(';')) {
      _syncSocketAttachments();
    }

    if (widget.morphWeights != oldWidget.morphWeights ||
        !_mapEquals(_appliedMorphWeights, widget.morphWeights)) {
      _applyMorphWeights();
      _applySectionMaterials();
      if (_shadingMode == ViewportShadingMode.wireframe) {
        _updateWireframeMesh();
      }
    }

    if (!identical(widget.jointLocalPose, oldWidget.jointLocalPose)) {
      _applyJointLocalPose();
    }

    if (widget.jointDeltas != oldWidget.jointDeltas ||
        !_jointDeltasEquals(_appliedJointDeltas, widget.jointDeltas)) {
      _applyJointTransforms();
    }
  }

  @override
  void dispose() {
    widget.playbackController?.removeListener(_onPlaybackChanged);
    widget.transformGizmo?.removeListener(_onGizmoChanged);
    _viewportFocus.dispose();
    _warmupTimer?.cancel();
    _sceneEnvironment.detach();
    // Normally already done by the FilamentWidget's onDispose; the lease
    // keeps the engine alive for whatever is left, then goes.
    _disposeNative();
    _engineLease?.release();
    _engineLease = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final triCount =
        widget.glbMesh?.triangleCount ??
        (_shape == PreviewShape.sphere ? 1280 : 384);
    final vertCount =
        widget.glbMesh?.vertexCount ??
        (_shape == PreviewShape.sphere ? 642 : 192);

    final hasNativePayload = _hasNativePreview;
    if (widget.transformGizmo != null) _syncGizmoState();

    return Container(
      color: EditorColors.background,
      child: Stack(
        children: [
          // 3D Viewport Layer (Controls: RMB Flycam, LMB Walk/Orbit, MMB Pan, Alt Dolly)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 0 && constraints.maxHeight > 0) {
                  _viewportSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final newAspect =
                      constraints.maxWidth / constraints.maxHeight;
                  if ((_viewportAspect - newAspect).abs() > 0.001) {
                    _viewportAspect = newAspect;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      if (_isMaterialPreview && _materialFramed) {
                        _cameraDistance = _materialFitDistance();
                      }
                      _updateNativeCamera();
                    });
                  }
                }
                return Focus(
                  focusNode: _viewportFocus,
                  autofocus: widget.transformGizmo != null,
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent || event is KeyRepeatEvent) {
                      if (_handleGizmoKey(event)) return KeyEventResult.handled;
                      if (event.logicalKey == LogicalKeyboardKey.keyF) {
                        _resetCamera();
                        return KeyEventResult.handled;
                      }
                      final label = event.logicalKey.keyLabel.toLowerCase();
                      if ([
                        'w',
                        'a',
                        's',
                        'd',
                        'q',
                        'e',
                        'arrow up',
                        'arrow down',
                        'arrow left',
                        'arrow right',
                      ].contains(label)) {
                        _moveWASD(label);
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Listener(
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        setState(() {
                          final zoomStep = hasNativePayload
                              ? (widget.initialCameraDistance != null
                                    ? widget.initialCameraDistance! / 800.0
                                    : 0.01)
                              : 0.4;
                          _materialFramed = false;
                          _cameraDistance +=
                              pointerSignal.scrollDelta.dy * zoomStep;
                          _cameraDistance = _cameraDistance.clamp(
                            hasNativePayload ? 0.5 : 40.0,
                            1500.0,
                          );
                          _updateNativeCamera();
                        });
                      }
                    },
                    child: Listener(
                      onPointerHover: (event) {
                        if (widget.transformGizmo != null) _handleGizmoHover(event.localPosition);
                        final brush = widget.brushInput;
                        final ray = brush == null ? null : _brushRay(event.localPosition);
                        if (ray != null) brush!.onHover(ray);
                      },
                      onPointerDown: (event) {
                        if (widget.transformGizmo != null) {
                          _viewportFocus.requestFocus();
                          if (event.buttons == kPrimaryMouseButton &&
                              !HardwareKeyboard.instance.isAltPressed &&
                              _beginGizmoDrag(event.localPosition)) {
                            _tapDownPosition = null;
                            return;
                          }
                        }
                        _isDragging = true;
                        _tapDownPosition = event.localPosition;
                        _tapDownButtons = event.buttons;
                        // A plain LMB press is the brush's (Alt+LMB orbits).
                        final brush = widget.brushInput;
                        if (brush != null &&
                            event.buttons == kPrimaryMouseButton &&
                            !HardwareKeyboard.instance.isAltPressed) {
                          final ray = _brushRay(event.localPosition);
                          _brushStroking = ray != null &&
                              brush.onStrokeStart(ray, invert: HardwareKeyboard.instance.isShiftPressed);
                        }
                      },
                      onPointerMove: (event) {
                        if (_gizmoDragging) {
                          if (_gizmoDrag != null) _updateGizmoDrag(event.localPosition);
                          return;
                        }
                        if (_brushStroking) {
                          final ray = _brushRay(event.localPosition);
                          if (ray != null) widget.brushInput?.onStrokeUpdate(ray);
                          return;
                        }
                        if (_isDragging) {
                          final delta = event.delta;
                          final isAlt = HardwareKeyboard.instance.isAltPressed;
                          final isRmb =
                              (event.buttons & kSecondaryMouseButton) != 0;
                          final isMmb =
                              (event.buttons & kMiddleMouseButton) != 0;
                          final isLmb =
                              (event.buttons & kPrimaryMouseButton) != 0;

                          setState(() {
                            if (isMmb ||
                                (isLmb &&
                                    isAlt &&
                                    HardwareKeyboard.instance.isShiftPressed)) {
                              // MMB Screen-space pan
                              final panFactor = hasNativePayload ? 0.01 : 0.5;
                              _cameraPan += Offset(
                                delta.dx * panFactor,
                                delta.dy * panFactor,
                              );
                            } else if (isRmb && isAlt) {
                              // Alt + RMB smooth dolly
                              _materialFramed = false;
                              final zoomStep = hasNativePayload ? 0.02 : 0.8;
                              _cameraDistance =
                                  (_cameraDistance - delta.dy * zoomStep).clamp(
                                    hasNativePayload ? 0.5 : 40.0,
                                    1500.0,
                                  );
                            } else if (isRmb) {
                              // RMB free-look mouselook
                              _cameraYaw += delta.dx * 0.4;
                              _cameraPitch = (_cameraPitch - delta.dy * 0.4)
                                  .clamp(-89.0, 89.0);
                            } else if (isLmb) {
                              if (isAlt) {
                                // Alt + LMB orbit
                                _cameraYaw += delta.dx * 0.5;
                                _cameraPitch = (_cameraPitch + delta.dy * 0.5)
                                    .clamp(-89.0, 89.0);
                              } else {
                                // LMB orbit/turn
                                _cameraYaw += delta.dx * 0.5;
                                _cameraPitch = (_cameraPitch + delta.dy * 0.5)
                                    .clamp(-89.0, 89.0);
                              }
                            }
                            _updateNativeCamera();
                          });
                        }
                      },
                      onPointerUp: (event) {
                        if (_gizmoDragging) {
                          _endGizmoDrag();
                          _handleGizmoHover(event.localPosition);
                          return;
                        }
                        _isDragging = false;
                        if (_brushStroking) {
                          _brushStroking = false;
                          _tapDownPosition = null;
                          widget.brushInput?.onStrokeEnd();
                          return;
                        }
                        final down = _tapDownPosition;
                        _tapDownPosition = null;
                        if (down == null) return;
                        if ((_tapDownButtons & kPrimaryMouseButton) == 0) {
                          return;
                        }
                        if ((event.localPosition - down).distance > 4.0) return;
                        if (widget.transformGizmo != null &&
                            !HardwareKeyboard.instance.isAltPressed) {
                          _handleGizmoClick(event.localPosition);
                        }
                        if (widget.onFloorTap == null) return;
                        _handleFloorTap(event.localPosition);
                      },
                      onPointerCancel: (_) {
                        if (_gizmoDragging) _cancelGizmoDrag();
                        _isDragging = false;
                        _tapDownPosition = null;
                        if (_brushStroking) {
                          _brushStroking = false;
                          widget.brushInput?.onStrokeEnd();
                        }
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: hasNativePayload
                                ? FilamentWidget(
                                    showFpsBadge: false,
                                    skipReadPixels: _skipReadPixelsFrames > 0,
                                    debugLabel: 'SubEditor3DViewport',
                                    onDispose: _disposeNative,
                                    onSceneCreated: (engine, scene, camera, view) {
                                      try {
                                        _nativeEngine = engine;
                                        if (_engineLease == null || _engineLease!.isReleased) {
                                          _engineLease = FilamentEngineHost.retain(
                                            engine,
                                            owner: 'SubEditor3DViewport state',
                                          );
                                        }
                                        _nativeCamera = camera;
                                        _nativeScene = scene;
                                        camera.setProjection(
                                          fovDegrees: 45.0,
                                          aspect: _viewportAspect,
                                          near: 0.1,
                                          far: 3000.0,
                                        );
                                        _updateNativeCamera();

                                         // Native 3D GPU Grid with adaptive sizing
                                         final mesh = widget.glbMesh;
                                         final double gridExtent;
                                         final double gridStep;
                                         if (widget.gridExtent != null &&
                                             widget.gridStep != null) {
                                           gridExtent = widget.gridExtent!;
                                           gridStep = widget.gridStep!;
                                         } else if (mesh != null &&
                                             mesh.positions.isNotEmpty) {
                                           final spanX = (mesh.maxBounds[0] -
                                                   mesh.minBounds[0])
                                               .abs();
                                           final spanY = (mesh.maxBounds[1] -
                                                   mesh.minBounds[1])
                                               .abs();
                                           final spanZ = (mesh.maxBounds[2] -
                                                   mesh.minBounds[2])
                                               .abs();
                                           final maxSpan = math.max(
                                             spanX,
                                             math.max(spanY, spanZ),
                                           );
                                           if (maxSpan < 5.0) {
                                             gridExtent = math.max(
                                               5.0,
                                               maxSpan * 8.0,
                                             );
                                             gridStep = gridExtent > 15.0
                                                 ? 0.5
                                                 : 0.25;
                                           } else if (maxSpan < 50.0) {
                                             gridExtent = math.max(
                                               50.0,
                                               maxSpan * 4.0,
                                             );
                                             gridStep = 2.0;
                                           } else {
                                             gridExtent = math.max(
                                               500.0,
                                               maxSpan * 2.5,
                                             );
                                             gridStep = 50.0;
                                           }
                                         } else {
                                           gridExtent = 20.0;
                                           gridStep = 0.5;
                                         }
                                         _nativeGrid = FilamentEditorGrid.create(
                                           engine: engine,
                                           extent: gridExtent,
                                           step: gridStep,
                                         );
                                         if (widget.showGrid) _nativeGrid!.addToScene(scene);

                                        // Image-based lighting. Without a real
                                        // IndirectLight, Filament gives a PBR
                                        // surface no ambient diffuse and no
                                        // ambient specular at all, so anything the
                                        // key light does not face renders black —
                                        // the black-silhouette bug. The preview
                                        // world branch below lights itself through
                                        // its own LuminaSkyComponent.
                                        if (widget.onPreviewWorldReady ==
                                            null) {
                                          _sceneEnvironment.attach(
                                            engine,
                                            scene,
                                          );
                                          _sceneEnvironment.apply(
                                            LuminaSkyDescription.studioDefaults,
                                          );
                                        }

                                        // Level/environment preview: hand a lumina world over and let
                                        // its components (sun, sky, meshes, post-process) light the frame.
                                        if (widget.onPreviewWorldReady !=
                                            null) {
                                          final world = LuminaWorld(
                                            worldType: LuminaWorldType.editor,
                                          );
                                          world.initializeNativeContext(
                                            engine,
                                            scene,
                                            view: view,
                                          );
                                          _previewWorld = world;
                                          widget.onPreviewWorldReady!(world);
                                          _updateOverlayLines(force: true);
                                          return;
                                        }

                                        // Create Sun Light & Directional Fill Light for PBR Shading
                                        final lightManager =
                                            FilamentLightManager(engine);

                                        // Create 3-Point Studio Lighting (Key, Fill, Rim) with neutral daylight spectrum
                                        final keyEntity = engine.createEntity();
                                        lightManager.createLight(
                                          entity: keyEntity,
                                          type: LightType.directional,
                                          colorR: 1.0,
                                          colorG: 0.98,
                                          colorB: 0.95,
                                          intensity: 90000.0,
                                          dirX: -0.4,
                                          dirY: -0.6,
                                          dirZ: -0.7,
                                          castShadows: true,
                                        );
                                        scene.addEntity(keyEntity);
                                        _studioLights.add(keyEntity);

                                        final fillEntity = engine
                                            .createEntity();
                                        lightManager.createLight(
                                          entity: fillEntity,
                                          type: LightType.directional,
                                          colorR: 0.98,
                                          colorG: 0.98,
                                          colorB: 0.98,
                                          intensity: 40000.0,
                                          dirX: 0.5,
                                          dirY: 0.5,
                                          dirZ: -0.5,
                                          castShadows: false,
                                        );
                                        scene.addEntity(fillEntity);
                                        _studioLights.add(fillEntity);

                                        final rimEntity = engine.createEntity();
                                        lightManager.createLight(
                                          entity: rimEntity,
                                          type: LightType.directional,
                                          colorR: 1.0,
                                          colorG: 1.0,
                                          colorB: 1.0,
                                          intensity: 45000.0,
                                          dirX: 0.0,
                                          dirY: -0.8,
                                          dirZ: 0.6,
                                          castShadows: false,
                                        );
                                        scene.addEntity(rimEntity);
                                        _studioLights.add(rimEntity);

                                        if (_isMaterialPreview) {
                                          _mountMaterialPreview(engine, scene);
                                          return;
                                        }
                                        // Meshes come from the engine's
                                        // shared cache: a
                                        // mesh another viewport shows is
                                        // not uploaded again.
                                        _drawsMeshes = true;
                                        if (widget.meshComponents != null &&
                                            widget.meshComponents!.isNotEmpty) {
                                          _rebuildComponentAssets(engine, scene);
                                          _recalculateBoundsAndFraming();
                                        } else if (widget.glbMesh?.rawPayload != null &&
                                            widget.glbMesh!.rawPayload!.isNotEmpty) {
                                          _loadNativeMesh(engine, scene, widget.glbMesh!.rawPayload!);
                                        }
                                      } catch (e) {
                                        debugPrint(
                                          '[Lumina Studio UI] Native Filament C++ FFI error: $e',
                                        );
                                      }
                                    },
                                  )
                                : CustomPaint(
                                    painter: _SubEditor3DPainter(
                                      glbMesh: widget.glbMesh,
                                      meshComponents: widget.meshComponents,
                                      selectedNode: widget.selectedNode,
                                      shape: _shape,
                                      shadingMode: _shadingMode,
                                      baseColor: previewBaseColorFromParams(
                                        widget.previewMaterialParams,
                                      ),
                                      roughness: previewScalarFromParams(
                                        widget.previewMaterialParams,
                                        'roughness',
                                        0.6,
                                      ),
                                      metallic: previewScalarFromParams(
                                        widget.previewMaterialParams,
                                        'metallic',
                                        0.0,
                                      ),
                                      hiddenSectionIndices:
                                          widget.hiddenSectionIndices,
                                      highlightedSectionIndices:
                                          widget.highlightedSectionIndices,
                                      cameraYaw: _cameraYaw,
                                      cameraPitch: _cameraPitch,
                                      cameraDistance: _cameraDistance,
                                      cameraPan: _cameraPan,
                                    ),
                                    size: Size.infinite,
                                  ),
                          ),
                          if ((widget.showBones ||
                                  widget.showSockets ||
                                  widget.ghostSkeletons.isNotEmpty ||
                                  widget.overlayMarkers.isNotEmpty ||
                                  widget.overlayPaths.isNotEmpty) &&
                              widget.glbMesh != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _SubEditorGizmoPainter(
                                    glbMesh: widget.glbMesh,
                                    showBones: widget.showBones,
                                    showSockets: widget.showSockets,
                                    sockets: widget.sockets,
                                    selectedNode: widget.selectedNode,
                                    selectedSocket: widget.selectedSocket,
                                    jointDeltas: widget.jointDeltas,
                                    jointLocalPose: widget.jointLocalPose,
                                    ghostSkeletons: widget.ghostSkeletons,
                                    overlayMarkers: widget.overlayMarkers,
                                    overlayPaths: widget.overlayPaths,
                                    cameraYaw: _cameraYaw,
                                    cameraPitch: _cameraPitch,
                                    cameraDistance: _cameraDistance,
                                    cameraPan: _cameraPan,
                                  ),
                                  size: Size.infinite,
                                ),
                              ),
                            ),
                          if (widget.transformGizmo != null)
                            Builder(builder: (context) {
                              final model = _transformGizmoModel();
                              if (model == null) return const SizedBox.shrink();
                              return Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    key: const ValueKey('sub_editor_transform_gizmo'),
                                    painter: SubEditorTransformGizmoPainter(
                                      model: model,
                                      activeHandle: _gizmoDragHandle ?? _gizmoHover,
                                      dragging: _gizmoDragging,
                                      locked: widget.transformGizmo!.target?.locked ?? false,
                                    ),
                                    size: Size.infinite,
                                  ),
                                ),
                              );
                            }),
                          if (_gizmoBanner != null)
                            Builder(builder: (context) {
                              final centre = _transformGizmoModel()?.project(widget.transformGizmo!.target!.pivot);
                              final at = centre ?? Offset(_viewportSize.width / 2, _viewportSize.height / 2);
                              return Positioned(
                                left: (at.dx + 24.0).clamp(8.0, math.max(8.0, _viewportSize.width - 200.0)),
                                top: (at.dy + 24.0).clamp(8.0, math.max(8.0, _viewportSize.height - 40.0)),
                                child: IgnorePointer(
                                  child: Container(
                                    key: const ValueKey('sub_editor_gizmo_banner'),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: EditorColors.hudSurfaceStrong,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: _gizmoDragLocked ? EditorColors.warning : SubEditorTransformGizmoPainter.highlight,
                                      ),
                                    ),
                                    child: Text(
                                      _gizmoBanner!,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _gizmoDragLocked ? EditorColors.warning : SubEditorTransformGizmoPainter.highlight,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Top Toolbar HUD
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                // Shading Mode Selector
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EditorColors.border),
                  ),
                  child: Row(
                    children: ViewportShadingMode.values.map((m) {
                      final sel = _shadingMode == m;
                      return GestureDetector(
                        onTap: () => _updateShadingMode(m),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: sel
                                ? EditorColors.primary.withValues(alpha: 0.3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            m.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: sel
                                  ? EditorColors.primary
                                  : EditorColors.foreground,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8),

                // Perspective Label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: EditorColors.border),
                  ),
                  child: Text(
                    _perspective,
                    style: const TextStyle(
                      fontSize: 9,
                      color: EditorColors.foreground,
                    ),
                  ),
                ),

                if (widget.transformGizmo != null) ...[
                  const SizedBox(width: 8),
                  _gizmoToolCluster(widget.transformGizmo!),
                ],

                if (widget.showShapeSelector) ...[
                  const SizedBox(width: 8),
                  // Shape Selector
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: EditorColors.border),
                    ),
                    child: Row(
                      children: PreviewShape.values
                          .where((s) => s != PreviewShape.mesh)
                          .map((s) {
                            final sel = _shape == s;
                            return GestureDetector(
                              onTap: () => setState(() {
                                _shape = s;
                                if (_isMaterialPreview) {
                                  _materialPreview.setShape(s);
                                  if (_materialFramed) {
                                    _cameraDistance = _materialFitDistance();
                                    _updateNativeCamera();
                                  }
                                }
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                margin: const EdgeInsets.only(right: 2),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? EditorColors.primary.withValues(
                                          alpha: 0.3,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  s.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: sel
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: sel
                                        ? EditorColors.primary
                                        : EditorColors.foreground,
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ],

                const Spacer(),

                // Reset Camera Button
                GhostButton(
                  onPressed: _resetCamera,
                  child: const Row(
                    children: [
                      Icon(
                        LucideIcons.rotateCcw,
                        size: 11,
                        color: EditorColors.primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Reset View',
                        style: TextStyle(
                          fontSize: 9,
                          color: EditorColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Stats HUD
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: EditorColors.border),
              ),
              child: Text(
                widget.statsLabel ??
                    'Triangles: $triCount  ·  Vertices: $vertCount  ·  FPS: 60.0  ·  Renderer: Filament C++',
                style: const TextStyle(
                  fontSize: 8,
                  fontFamily: EditorTypography.monoFamily,
                  color: Colors.cyan,
                ),
              ),
            ),
          ),

          if (widget.overlayHUD != null) widget.overlayHUD!,
        ],
      ),
    );
  }
}
