/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'dart:ui_web' as ui_web;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'package:flutter_filament/src/camera.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/renderer.dart';
import 'package:flutter_filament/src/scene.dart';
import 'package:flutter_filament/src/swap_chain.dart';
import 'package:flutter_filament/src/view.dart';
import 'package:flutter_filament/src/web_ffi/module.dart';
import 'package:flutter_filament/src/web_init.dart';
import 'package:flutter_filament/src/widget.dart';

/// Web builds: Filament's WebGL2 backend presents straight
/// into a `<canvas>` hosted by a platform view — no readback, no decode.
typedef FilamentWidgetStateImpl = WebFilamentWidgetState;

class WebFilamentWidgetState extends State<FilamentWidget> with SingleTickerProviderStateMixin {
  static int _nextId = 0;

  final int _id = _nextId++;
  late final String _viewType = 'flutter-filament-canvas-$_id';
  late final String _canvasName = 'flutter-filament-$_id';
  late final web.HTMLCanvasElement _canvas;

  FilamentEngine? _engine;
  FilamentScene? _scene;
  FilamentView? _view;
  FilamentCamera? _camera;
  FilamentRenderer? _renderer;
  FilamentSwapChain? _swapChain;
  int? _cameraEntity;

  late final AnimationController _ticker;
  bool _isInitialized = false;
  bool _disposed = false;
  String _status = 'Initializing 3D Viewport...';

  int _fps = 60;
  int _framesThisSecond = 0;
  int _lastFpsTimestamp = DateTime.now().millisecondsSinceEpoch;
  int _lastTickTimestamp = 0;

  // The canvas drawing buffer, in physical pixels.
  int _pixelWidth = 0;
  int _pixelHeight = 0;

  @override
  void initState() {
    super.initState();
    _canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..id = _canvasName
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      // Flutter's Listener above it receives the pointer events.
      ..style.pointerEvents = 'none';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) => _canvas);

    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 1))..addListener(_onFrameTick);
    if (!widget.isPaused) _ticker.repeat();

    FilamentWeb.ensureInitialized().then((_) {
      if (!_disposed) _initEngine();
    }, onError: (Object e) {
      if (mounted) setState(() => _status = 'Failed to load the Filament WebAssembly module: $e');
    });
  }

  @override
  void didUpdateWidget(FilamentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused != oldWidget.isPaused) {
      if (widget.isPaused) {
        _ticker.stop();
      } else if (!_ticker.isAnimating) {
        _ticker.repeat();
      }
    }
  }

  void _initEngine() {
    try {
      final selector = FlutterFilamentModule.registerCanvas(_canvasName, _canvas);
      if (_pixelWidth > 0 && _pixelHeight > 0) {
        _canvas
          ..width = _pixelWidth
          ..height = _pixelHeight;
      }
      final engine = FilamentEngine.createForCanvas(selector);
      if (engine == null) {
        setState(() => _status = 'WebGL2 is not available for the Filament canvas.');
        return;
      }
      _engine = engine;
      final scene = engine.createScene();
      final view = engine.createView();
      final cameraEntity = engine.createEntity();
      final camera = engine.createCamera(cameraEntity);
      final renderer = engine.createRenderer();
      // WebGL presents into the canvas's default framebuffer.
      final swapChain = engine.createSwapChain(ffi.nullptr);

      final width = _canvas.width;
      final height = _canvas.height;
      view
        ..scene = scene
        ..camera = camera
        ..setViewport(0, 0, width, height);
      camera.setProjectionFov(fovDegrees: 45.0, aspect: width / height, near: 0.1, far: 10000.0);
      renderer.setClearOptions(r: 0.05, g: 0.05, b: 0.07, a: 1.0, clear: true, discard: true);
      widget.cameraManipulator?.setViewport(width, height);

      _scene = scene;
      _view = view;
      _camera = camera;
      _renderer = renderer;
      _swapChain = swapChain;
      _cameraEntity = cameraEntity;
      _isInitialized = true;

      widget.onSceneCreated?.call(engine, scene, camera, view);
      setState(() => _status = 'Filament 3D Scene Running');
    } catch (e, stack) {
      debugPrint('[Filament Engine Init Exception]: $e\n$stack');
      if (mounted) setState(() => _status = 'Error initializing 3D Scene: $e');
    }
  }

  void _onFrameTick() {
    if (!_isInitialized || widget.isPaused || widget.pauseRendering) return;
    final renderer = _renderer!;
    final start = DateTime.now().microsecondsSinceEpoch;
    try {
      if (widget.cameraManipulator != null && _camera != null) {
        widget.cameraManipulator!.updateCamera(_camera!);
      }
      final selectedViews = widget.frameViews?.call(_view!, _pixelWidth, _pixelHeight);
      final views = selectedViews == null || selectedViews.isEmpty ? [_view!] : selectedViews;
      if (renderer.beginFrame(_swapChain!)) {
        for (final view in views) {
          renderer.render(view);
        }
        renderer.endFrame();
        // Single-threaded WebGL: run the driver now so the canvas holds the
        // frame when the browser composites.
        _engine!.flushAndWait();

        final end = DateTime.now().microsecondsSinceEpoch;
        if (widget.onFrame != null && _lastTickTimestamp != 0) {
          widget.onFrame!(Duration(microseconds: end - start), Duration(microseconds: end - _lastTickTimestamp));
        }
        _lastTickTimestamp = end;
        _framesThisSecond++;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastFpsTimestamp >= 1000) {
          _fps = _framesThisSecond;
          _framesThisSecond = 0;
          _lastFpsTimestamp = now;
          if (widget.showFpsBadge && mounted) setState(() {});
        }
      }
    } catch (e) {
      debugPrint('[Filament Frame Loop Error (Handled Safely)]: $e');
    }
  }

  /// Sizes the drawing buffer to the widget's physical pixels.
  void _resize(int width, int height) {
    if (width <= 0 || height <= 0 || (width == _pixelWidth && height == _pixelHeight)) return;
    _pixelWidth = width;
    _pixelHeight = height;
    _canvas
      ..width = width
      ..height = height;
    if (!_isInitialized) return;
    _view?.setViewport(0, 0, width, height);
    _camera?.setProjectionFov(fovDegrees: 45.0, aspect: width / height, near: 0.1, far: 10000.0);
    widget.cameraManipulator?.setViewport(width, height);
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    widget.onDispose?.call();
    final engine = _engine;
    if (engine != null) {
      try {
        engine.flushAndWait();
      } catch (_) {}
      if (_cameraEntity != null) {
        _camera?.dispose();
        engine.destroyEntity(_cameraEntity!);
      }
      _scene?.dispose();
      _view?.dispose();
      _renderer?.dispose();
      _swapChain?.dispose();
      // Destroys the engine, then its WebGL context.
      engine.dispose();
    }
    FlutterFilamentModule.unregisterCanvas(_canvasName);
    _canvas.remove();
    super.dispose();
  }

  Offset? _local(BuildContext context, Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global);
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : (widget.width.isFinite ? widget.width : 800.0);
        final height = constraints.maxHeight.isFinite ? constraints.maxHeight : (widget.height.isFinite ? widget.height : 600.0);
        final fixed = widget.renderResolution;
        _resize((fixed?.width ?? width * dpr).round().clamp(1, 8192),
            (fixed?.height ?? height * dpr).round().clamp(1, 8192));
        final manipulator = widget.cameraManipulator;
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(child: HtmlElementView(viewType: _viewType)),
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) {
                    final p = manipulator == null ? null : _local(context, event.position);
                    if (p == null) return;
                    final isPan = event.buttons == kSecondaryMouseButton || event.buttons == kMiddleMouseButton;
                    manipulator!.grabBegin((p.dx * dpr).toInt(), (p.dy * dpr).toInt(), strafe: isPan);
                  },
                  onPointerMove: (event) {
                    final p = manipulator == null ? null : _local(context, event.position);
                    if (p == null) return;
                    manipulator!.grabUpdate((p.dx * dpr).toInt(), (p.dy * dpr).toInt());
                  },
                  onPointerUp: (_) => manipulator?.grabEnd(),
                  onPointerCancel: (_) => manipulator?.grabEnd(),
                  onPointerSignal: (event) {
                    if (manipulator == null || event is! PointerScrollEvent) return;
                    final p = _local(context, event.position);
                    if (p == null) return;
                    manipulator.scroll((p.dx * dpr).toInt(), (p.dy * dpr).toInt(), event.scrollDelta.dy > 0 ? -1.0 : 1.0);
                  },
                  child: const SizedBox.expand(),
                ),
              ),
              if (!_isInitialized)
                Center(child: Text(_status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
              if (widget.showFpsBadge)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.deepOrange, width: 1),
                    ),
                    child: Text('FILAMENT 3D | $_fps FPS',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

