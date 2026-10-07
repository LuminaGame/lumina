import 'package:flutter/material.dart';

import 'package:flutter_filament/src/camera.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/manipulator.dart';
import 'package:flutter_filament/src/scene.dart';
import 'package:flutter_filament/src/view.dart';
import 'package:flutter_filament/src/widget_state.dart';

/// Controller callback for configuring a 3D Filament scene.
typedef FilamentSceneCreatedCallback =
    void Function(
      FilamentEngine engine,
      FilamentScene scene,
      FilamentCamera camera,
      FilamentView view,
    );

/// Selects the views to render into one surface, within one GPU frame.
/// Each view supplies its own viewport in physical pixels (bottom-left origin).
typedef FilamentFrameViewsCallback =
    List<FilamentView> Function(
      FilamentView defaultView,
      int width,
      int height,
    );

/// A Flutter widget for rendering 3D Filament scenes natively.
///
/// Manages its viewport's render objects, frame loop and dimensions. The
/// engine is shared with every other widget on the same GPU
/// ([FilamentEngineHost]) unless [sharedEngine] is false.
class FilamentWidget extends StatefulWidget {
  /// Callback fired when the Filament 3D engine, scene, and camera are initialized.
  final FilamentSceneCreatedCallback? onSceneCreated;

  /// Backend engine to use (defaults to Metal on macOS, Vulkan/OpenGL on Linux/Android).
  final FilamentBackend backend;

  /// Width of the 3D viewport canvas.
  final double width;

  /// Height of the 3D viewport canvas.
  final double height;

  /// Optional callback executed when the 3D widget is being disposed (for resource cleanup).
  final VoidCallback? onDispose;

  /// Optional camera manipulator for interactive orbit, pan, and zoom gestures.
  final FilamentCameraManipulator? cameraManipulator;

  /// Optional flag to render FPS badge overlay (defaults to false).
  /// Optional flag to render FPS badge overlay (defaults to false).
  final bool showFpsBadge;

  /// Whether 3D GPU frame rendering is paused (e.g. when viewport tab is inactive).
  final bool isPaused;

  /// Whether to temporarily pause just the pixel readback & rendering loop
  /// while heavy operations (like mesh loading) are happening to prevent GPU fence timeouts.
  final bool pauseRendering;

  /// Whether to skip readPixels for the current frame. Useful when the first frame of a new
  /// complex asset is rendered, which causes shader compilation and might timeout the readPixels fence.
  final bool skipReadPixels;

  final void Function(Duration cpu, Duration frame)? onFrame;

  /// Whether this widget renders on the process's shared engine for
  /// [backend] and the current GPU preference (the default) —
  /// with its own swap chain, renderer, view, scene and camera — instead of
  /// creating and destroying a dedicated engine. Ignored on the web, where a
  /// WebGL2 engine belongs to its canvas.
  final bool sharedEngine;

  /// Who this widget's engine lease is for (`FilamentEngineHost.leaseOwners`).
  final String? debugLabel;

  final FilamentFrameViewsCallback? frameViews;

  const FilamentWidget({
    super.key,
    this.onSceneCreated,
    this.onDispose,
    this.cameraManipulator,
    this.showFpsBadge = false,
    this.isPaused = false,
    this.pauseRendering = false,
    this.skipReadPixels = false,
    this.onFrame,
    this.sharedEngine = true,
    this.debugLabel,
    this.frameViews,
    this.backend = FilamentBackend.defaultBackend,
    this.width = double.infinity,
    this.height = double.infinity,
    this.targetFps,
  });

  /// Target frame rate in FPS; null or <= 0 means unlimited / display refresh rate.
  final int? targetFps;

  @override
  // A readback into a RawImage natively; a WebGL2 canvas on the web.
  State<FilamentWidget> createState() => FilamentWidgetStateImpl();
}
