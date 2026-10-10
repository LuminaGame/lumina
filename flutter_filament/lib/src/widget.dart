import 'package:flutter/material.dart';

import 'package:flutter_filament/src/camera.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/frame_limiter.dart';
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

  /// Whether the frame sits in the rounded, bordered viewport panel (the
  /// default, editor tools) or fills the widget edge to edge (a game).
  final bool decorated;

  /// Whether the frame renders at the display's physical pixels (layout size
  /// × device pixel ratio, what a game wants on a scaled display) instead of
  /// the layout's logical size (the default).
  final bool physicalResolution;

  /// A fixed size, in physical pixels, to render at whatever the layout
  /// size (a game's chosen screen resolution); the frame is scaled to fill
  /// the widget. Null renders at the layout size ([physicalResolution]).
  final Size? renderResolution;

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
    this.vsyncEnabled = false,
    this.frameLimiter,
    this.decorated = true,
    this.physicalResolution = false,
    this.renderResolution,
  });

  /// Target frame rate in FPS; null or <= 0 means unlimited / display refresh rate.
  /// Frames are rendered on the display's refresh ([FilamentFrameLimiter]),
  /// so no target goes above the refresh rate.
  final int? targetFps;

  /// How [targetFps] paces the frames ([FilamentFrameLimiter.vsync]): true
  /// shows every frame for the same whole number of refreshes, false keeps
  /// the target as the average. The frame is presented by Flutter on the
  /// display's vsync either way.
  final bool vsyncEnabled;

  /// The limiter deciding which refreshes render; one the host shares with
  /// its own per-frame work (a game's world tick) so both run on the same
  /// refreshes. Null uses the widget's own. Configured from [targetFps] and
  /// [vsyncEnabled] either way.
  final FilamentFrameLimiter? frameLimiter;

  @override
  // A readback into a RawImage natively; a WebGL2 canvas on the web.
  State<FilamentWidget> createState() => FilamentWidgetStateImpl();
}
