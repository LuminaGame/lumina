import 'dart:async';
import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_filament/src/ffi_package_platform.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:flutter_filament/src/camera.dart';
import 'package:flutter_filament/src/direct_presenter.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/engine_host.dart';
import 'package:flutter_filament/src/filamat_builder.dart';
import 'package:flutter_filament/src/frame_limiter.dart';
import 'package:flutter_filament/src/native_surface.dart';
import 'package:flutter_filament/src/renderer.dart';
import 'package:flutter_filament/src/scene.dart';
import 'package:flutter_filament/src/swap_chain.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/view.dart';
import 'package:flutter_filament/src/widget.dart';

/// Native platforms: render into a headless swap chain and present the
/// readback through a [RawImage], or, given a [FilamentWidget.nativeSurface],
/// render into a SwapChain on that window and let Filament present.
typedef FilamentWidgetStateImpl = NativeFilamentWidgetState;

class NativeFilamentWidgetState extends State<FilamentWidget>
    with SingleTickerProviderStateMixin {
  FilamentEngine? _engine;

  /// This viewport's claim on the shared engine; null for a
  /// dedicated engine (`sharedEngine: false`).
  FilamentEngineLease? _lease;
  FilamentScene? _scene;
  FilamentView? _view;
  FilamentCamera? _camera;
  FilamentRenderer? _renderer;
  FilamentSwapChain? _swapChain;
  int? _cameraEntity;

  late AnimationController _ticker;
  int _fps = 60;
  int _framesThisSecond = 0;
  int _lastFpsTimestamp = DateTime.now().millisecondsSinceEpoch;
  String _status = 'Initializing 3D Viewport...';
  bool _isInitialized = false;

  int _viewWidth = 800;
  int _viewHeight = 600;

  /// The size the frame renders at, in pixels (the swap chain and viewport).
  @visibleForTesting
  (int, int) get renderSize => (_viewWidth, _viewHeight);

  ffi.Pointer<ffi.Uint8>? _nativePixelBuffer;
  ui.Image? _renderedImage;
  ui.Image? _previousImage;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    if (!widget.isPaused) {
      _ticker.repeat();
    }

    _ticker.addListener(_onFrameTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initEngine();
    });
  }

  /// Direct presentation, while it runs.
  FilamentDirectPresenter? _direct;
  bool _directStarting = false;
  FilamentPresentationStatus? _presentation;

  /// The main view's viewport in the direct SwapChain.
  (int, int, int, int)? _directViewport;

  void _reportPresentation(FilamentPresentationStatus status) {
    if (status == _presentation) return;
    _presentation = status;
    if (status.reason != null) debugPrint('[FilamentWidget] presenting through a Flutter texture: ${status.reason}');
    widget.onPresentationChanged?.call(status);
  }

  /// Starts or stops direct presentation to match [FilamentWidget.nativeSurface].
  Future<void> _syncPresentation() async {
    final surface = widget.nativeSurface;
    final engine = _engine;
    if (!_isInitialized || engine == null || _directStarting) return;
    if (surface == null) {
      if (_direct != null) await _stopDirect();
      _reportPresentation(const FilamentPresentationStatus(FilamentPresentationKind.texture));
      return;
    }
    if (_direct != null) return;
    _directStarting = true;
    final (presenter, reason) = await FilamentDirectPresenter.start(engine, surface, vsync: widget.vsyncEnabled);
    _directStarting = false;
    if (presenter == null) {
      _reportPresentation(FilamentPresentationStatus(FilamentPresentationKind.texture, reason: reason));
      return;
    }
    if (!mounted || !identical(widget.nativeSurface, surface)) {
      await presenter.dispose();
      if (mounted) unawaited(_syncPresentation());
      return;
    }
    _direct = presenter;
    _directViewport = null;
    presenter.surfaceListenable.addListener(_onSurfaceChanged);
    widget.onUiOverlay?.call(presenter.overlay);
    _reportPresentation(const FilamentPresentationStatus(FilamentPresentationKind.direct));
    setState(() {});
  }

  Future<void> _stopDirect() async {
    final presenter = _direct;
    if (presenter == null) return;
    _direct = null;
    presenter.surfaceListenable.removeListener(_onSurfaceChanged);
    widget.onUiOverlay?.call(null);
    await presenter.dispose();
    // The texture path's view size again.
    _view?.setViewport(0, 0, _viewWidth, _viewHeight);
    if (mounted) setState(() {});
  }

  void _onSurfaceChanged() {
    final next = _direct?.surfaceListenable.value;
    if (next != null) _direct?.updateHandle(next);
  }

  @override
  void didUpdateWidget(FilamentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.nativeSurface, widget.nativeSurface)) {
      _stopDirect().then((_) {
        if (mounted) _syncPresentation();
      });
    }
    _direct?.setVsync(widget.vsyncEnabled);
    if (widget.isPaused != oldWidget.isPaused) {
      if (widget.isPaused) {
        _ticker.stop();
        try {
          _engine?.flushAndWait();
        } catch (_) {}
      } else {
        if (!_ticker.isAnimating) {
          _ticker.repeat();
        }
      }
    }
  }

  void _initEngine() {
    try {
      FilamentMaterialBuilder.initEngine();

      final FilamentEngine? engine;
      if (widget.sharedEngine) {
        _lease = FilamentEngineHost.acquire(
          owner: widget.debugLabel ?? 'FilamentWidget',
          backend: widget.backend,
        );
        engine = _lease?.engine;
      } else {
        engine = FilamentEngine.create(backend: widget.backend);
      }
      if (engine == null) {
        setState(() => _status = 'Failed to create Filament 3D Engine.');
        return;
      }
      _engine = engine;

      final scene = engine.createScene();
      final view = engine.createView();
      final cameraEntity = engine.createEntity();
      final camera = engine.createCamera(cameraEntity);
      final renderer = engine.createRenderer();

      _viewWidth = widget.width.isInfinite ? 800 : widget.width.toInt();
      _viewHeight = widget.height.isInfinite ? 600 : widget.height.toInt();
      _nativePixelBuffer = calloc<ffi.Uint8>(_viewWidth * _viewHeight * 4);

      final swapChain = engine.createHeadlessSwapChain(_viewWidth, _viewHeight);

      view.scene = scene;
      view.camera = camera;
      view.setViewport(0, 0, _viewWidth, _viewHeight);
      camera.setProjectionFov(
        fovDegrees: 45.0,
        aspect: _viewWidth / _viewHeight,
        near: 0.1,
        far: 10000.0,
      );

      renderer.setClearOptions(
        r: 0.05,
        g: 0.05,
        b: 0.07,
        a: 1.0,
        clear: true,
        discard: true,
      );

      _scene = scene;
      _view = view;
      _camera = camera;
      _renderer = renderer;
      _swapChain = swapChain;
      _cameraEntity = cameraEntity;
      _isInitialized = true;

      widget.onSceneCreated?.call(engine, scene, camera, view);
      unawaited(_syncPresentation());

      setState(() {
        _status = 'Filament 3D Scene Running';
      });
    } catch (e, stack) {
      debugPrint('[Filament Engine Init Exception]: $e\n$stack');
      if (mounted) {
        setState(() => _status = 'Error initializing 3D Scene: $e');
      }
    }
  }

  bool _isRenderingFrame = false;

  /// Target FPS on the display's refresh (the ticker's vsync timestamps).
  final FilamentFrameLimiter _limiter = FilamentFrameLimiter();

  int _lastTickTimestamp = 0;
  void _onFrameTick() {
    if (!_isInitialized ||
        widget.isPaused ||
        widget.pauseRendering ||
        _isRenderingFrame ||
        _renderer == null ||
        _view == null ||
        _swapChain == null ||
        _nativePixelBuffer == null) {
      return;
    }
    if (_direct != null) {
      _renderDirect(_direct!);
      return;
    }

    final limiter = widget.frameLimiter ?? _limiter;
    limiter.configure(targetFps: widget.targetFps ?? 0, vsync: widget.vsyncEnabled);
    if (!limiter.shouldRender(SchedulerBinding.instance.currentFrameTimeStamp)) return;
    final int startTick = DateTime.now().microsecondsSinceEpoch;

    _isRenderingFrame = true;
    try {
      if (widget.cameraManipulator != null && _camera != null) {
        widget.cameraManipulator!.updateCamera(_camera!);
      }

      final selectedViews = widget.frameViews?.call(_view!, _viewWidth, _viewHeight);
      final views = selectedViews == null || selectedViews.isEmpty ? [_view!] : selectedViews;
      if (_renderer!.beginFrame(_swapChain!)) {
        for (final view in views) {
          _renderer!.render(view);
        }
        
        if (!widget.skipReadPixels) {
          c.filament_renderer_read_pixels(
            _renderer!.nativePointer,
            _engine!.nativePointer,
            0,
            0,
            _viewWidth,
            _viewHeight,
            _nativePixelBuffer!.cast(),
            ffi.nullptr,
            ffi.nullptr,
          );
          _engine!.flushAndWait();
        }
        
        _renderer!.endFrame();
        _engine!.flushAndWait();
        
        final endTick = DateTime.now().microsecondsSinceEpoch;
        if (widget.onFrame != null && _lastTickTimestamp != 0) {
          final frameCpu = Duration(microseconds: endTick - startTick);
          final frameTime = Duration(microseconds: endTick - _lastTickTimestamp);
          widget.onFrame!(frameCpu, frameTime);
        }
        _lastTickTimestamp = endTick;
        
        _framesThisSecond++;
        final int now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastFpsTimestamp >= 1000) {
          _fps = _framesThisSecond;
          _framesThisSecond = 0;
          _lastFpsTimestamp = now;
        }

        if (widget.skipReadPixels) {
          _isRenderingFrame = false;
          return;
        }

        final snapshot = Uint8List.fromList(
          _nativePixelBuffer!.asTypedList(_viewWidth * _viewHeight * 4),
        );
        ui.decodeImageFromPixels(
          snapshot,
          _viewWidth,
          _viewHeight,
          ui.PixelFormat.rgba8888,
          (ui.Image image) {
            _isRenderingFrame = false;
            if (mounted) {
              final old = _previousImage;
              _previousImage = _renderedImage;
              _renderedImage = image;
              old?.dispose();
              setState(() {});
            } else {
              image.dispose();
            }
          },
        );
      } else {
        _isRenderingFrame = false;
      }
    } catch (e) {
      _isRenderingFrame = false;
      debugPrint('[Filament Frame Loop Error (Handled Safely)]: $e');
    }
  }

  /// One frame into the native window's SwapChain: the views, then the UI
  /// overlay; Filament presents. No readback and no wait for the GPU.
  void _renderDirect(FilamentDirectPresenter direct) {
    final limiter = widget.frameLimiter ?? _limiter;
    limiter.configure(targetFps: widget.targetFps ?? 0, vsync: widget.vsyncEnabled);
    if (!limiter.shouldRender(SchedulerBinding.instance.currentFrameTimeStamp)) return;
    final surface = direct.handle;
    if (!surface.isVisible) return; // minimised
    final startTick = DateTime.now().microsecondsSinceEpoch;
    try {
      final fixed = widget.renderResolution;
      final viewport = FilamentDirectPresenter.viewportFor(surface.width, surface.height,
          renderAspect: fixed == null || fixed.height <= 0 ? null : fixed.width / fixed.height);
      if (viewport != _directViewport) {
        _directViewport = viewport;
        _view!.setViewport(viewport.$1, viewport.$2, viewport.$3, viewport.$4);
        _camera?.setProjectionFov(fovDegrees: 45.0, aspect: viewport.$3 / viewport.$4, near: 0.1, far: 10000.0);
        widget.cameraManipulator?.setViewport(viewport.$3, viewport.$4);
      }
      if (_camera != null) widget.cameraManipulator?.updateCamera(_camera!);
      final selected = widget.frameViews?.call(_view!, viewport.$3, viewport.$4);
      final views = selected == null || selected.isEmpty ? [_view!] : selected;
      if (_renderer!.beginFrame(direct.swapChain)) {
        for (final view in views) {
          _renderer!.render(view);
        }
        direct.overlay.render(_renderer!);
        _renderer!.endFrame();
        final endTick = DateTime.now().microsecondsSinceEpoch;
        if (widget.onFrame != null && _lastTickTimestamp != 0) {
          widget.onFrame!(
              Duration(microseconds: endTick - startTick), Duration(microseconds: endTick - _lastTickTimestamp));
        }
        _lastTickTimestamp = endTick;
        _framesThisSecond++;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastFpsTimestamp >= 1000) {
          _fps = _framesThisSecond;
          _framesThisSecond = 0;
          _lastFpsTimestamp = now;
        }
      }
    } catch (e) {
      debugPrint('[Filament Direct Frame Error (Handled Safely)]: $e');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    final direct = _direct;
    _direct = null;
    if (direct != null) {
      direct.surfaceListenable.removeListener(_onSurfaceChanged);
      // Before the engine and the view go; the window is released after.
      unawaited(direct.dispose());
    }
    try {
      _engine?.flushAndWait();
    } catch (_) {}
    try {
      // The consumer frees what it created while the engine is alive.
      widget.onDispose?.call();
    } catch (e, stack) {
      debugPrint('[Filament onDispose Exception]: $e\n$stack');
    }
    _renderedImage?.dispose();
    _previousImage?.dispose();
    if (_nativePixelBuffer != null) {
      calloc.free(_nativePixelBuffer!);
      _nativePixelBuffer = null;
    }
    final engine = _engine;
    if (engine != null && !engine.isDisposed) {
      try {
        engine.flushAndWait();
      } catch (_) {}
      // This viewport's own objects, dependents first: the view references
      // the scene and the camera. On a shared engine nothing else is
      // destroyed here — other viewports keep drawing.
      try {
        _view?.dispose();
        _scene?.dispose();
        if (_cameraEntity != null) {
          _camera?.dispose();
          engine.destroyEntity(_cameraEntity!);
        }
        _renderer?.dispose();
        _swapChain?.dispose();
      } catch (e) {
        debugPrint('[Filament Viewport Teardown]: $e');
      }
      if (_lease != null) {
        _lease!.release();
      } else {
        engine.dispose();
      }
    } else {
      _lease?.release();
    }
    _lease = null;
    _engine = null;
    super.dispose();
  }

  void _updateViewportDimensions(int targetWidth, int targetHeight) {
    if (targetWidth <= 0 || targetHeight <= 0) return;
    if (_viewWidth == targetWidth && _viewHeight == targetHeight) return;

    try {
      _engine?.flushAndWait();
    } catch (_) {}

    _viewWidth = targetWidth;
    _viewHeight = targetHeight;
    if (_nativePixelBuffer != null) {
      calloc.free(_nativePixelBuffer!);
    }
    _nativePixelBuffer = calloc<ffi.Uint8>(_viewWidth * _viewHeight * 4);

    if (_isInitialized && _engine != null) {
      try {
        _engine?.flushAndWait();
        _swapChain?.dispose();
        _swapChain = _engine!.createHeadlessSwapChain(_viewWidth, _viewHeight);
        _view?.setViewport(0, 0, _viewWidth, _viewHeight);
        _camera?.setProjectionFov(
          fovDegrees: 45.0,
          aspect: _viewWidth / _viewHeight,
          near: 0.1,
          far: 10000.0,
        );
        widget.cameraManipulator?.setViewport(_viewWidth, _viewHeight);
      } catch (e) {
        debugPrint('[Filament Viewport Resize Error]: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Presenting directly, the native window shows the frame: nothing to
        // paint here (the UI above is composited by Filament).
        if (_direct != null) return const SizedBox.expand();
        final double layoutWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (widget.width.isFinite ? widget.width : 800);
        final double layoutHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : widget.height;
        // Logical pixels, or the display's physical pixels for a game.
        final double scale = widget.physicalResolution
            ? (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0)
            : 1.0;
        final int maxSize = widget.physicalResolution ? 8192 : 4096;
        final Size? fixed = widget.renderResolution;
        final int targetWidth = (fixed?.width ?? layoutWidth * scale).round().clamp(1, maxSize);
        final int targetHeight = (fixed?.height ?? layoutHeight * scale).round().clamp(1, maxSize);

        if (_viewWidth != targetWidth || _viewHeight != targetHeight) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateViewportDimensions(targetWidth, targetHeight);
            }
          });
        }

        return Container(
          width: layoutWidth,
          height: layoutHeight,
          // A game fills the widget edge to edge; tools get the panel.
          decoration: !widget.decorated
              ? const BoxDecoration(color: Colors.black)
              : BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.deepOrange.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.decorated ? 10 : 0),
            child: Stack(
              children: [
                // Live Rendered 3D Scene RawImage Widget
                if (_renderedImage != null)
                  Positioned.fill(
                    child: Listener(
                      onPointerDown: (PointerDownEvent event) {
                        if (widget.cameraManipulator == null) return;
                        final RenderBox? renderBox =
                            context.findRenderObject() as RenderBox?;
                        if (renderBox == null) return;
                        final Offset localPos =
                            renderBox.globalToLocal(event.position);
                        final bool isPan =
                            event.buttons == kSecondaryMouseButton ||
                            event.buttons == kMiddleMouseButton;
                        widget.cameraManipulator!.grabBegin(
                          localPos.dx.toInt(),
                          localPos.dy.toInt(),
                          strafe: isPan,
                        );
                      },
                      onPointerMove: (PointerMoveEvent event) {
                        if (widget.cameraManipulator == null) return;
                        final RenderBox? renderBox =
                            context.findRenderObject() as RenderBox?;
                        if (renderBox == null) return;
                        final Offset localPos =
                            renderBox.globalToLocal(event.position);
                        widget.cameraManipulator!.grabUpdate(
                          localPos.dx.toInt(),
                          localPos.dy.toInt(),
                        );
                      },
                      onPointerUp: (_) => widget.cameraManipulator?.grabEnd(),
                      onPointerCancel: (_) => widget.cameraManipulator?.grabEnd(),
                      onPointerSignal: (PointerSignalEvent event) {
                        if (widget.cameraManipulator == null) return;
                        if (event is PointerScrollEvent) {
                          final RenderBox? renderBox =
                              context.findRenderObject() as RenderBox?;
                          if (renderBox == null) return;
                          final Offset localPos =
                              renderBox.globalToLocal(event.position);
                          widget.cameraManipulator!.scroll(
                            localPos.dx.toInt(),
                            localPos.dy.toInt(),
                            event.scrollDelta.dy > 0 ? -1.0 : 1.0,
                          );
                        }
                      },
                      // Its own layer: a new frame arrives up to every vsync,
                      // and without a boundary each one repainted the whole
                      // host window.
                      child: RepaintBoundary(
                        child: RawImage(image: _renderedImage, fit: BoxFit.fill),
                      ),
                    ),
                  )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.view_in_ar,
                      size: 64,
                      color: Colors.deepOrangeAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            // Top Badge Overlay (Optional)
            if (widget.showFpsBadge)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.deepOrange, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.hub,
                        size: 12,
                        color: Colors.deepOrangeAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'FILAMENT 3D | $_fps FPS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
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
}
