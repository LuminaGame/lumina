/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'package:flutter/foundation.dart';

/// A native window a [FilamentWidget] can present into directly
/// (`FilamentWidget.nativeSurface`): an HWND on Windows, an X11 window on
/// Linux. The host owns it (a generated game's runner creates a child window
/// of the Flutter view that takes no input); the widget creates a Vulkan
/// SwapChain on it and renders there instead of reading frames back into a
/// Flutter texture.
abstract class FilamentNativeSurface {
  /// Creates or shows the window; null when there is none, with the reason
  /// in [unavailableReason].
  Future<FilamentNativeSurfaceHandle?> acquire();

  /// Hides or destroys the window; the widget no longer presents into it.
  Future<void> release();

  /// Why [acquire] returned null.
  String? get unavailableReason;

  /// The window's current handle and size; the widget follows its changes
  /// (resize, DPI change, minimise to 0 × 0).
  ValueListenable<FilamentNativeSurfaceHandle?> get current;
}

/// A native window and its size in physical pixels.
@immutable
class FilamentNativeSurfaceHandle {
  const FilamentNativeSurfaceHandle({required this.handle, required this.width, required this.height});

  /// The window handle (HWND, X11 Window).
  final int handle;

  /// The client area in physical pixels; 0 while minimised.
  final int width;
  final int height;

  /// Whether there is anything to present into.
  bool get isVisible => width > 0 && height > 0;

  @override
  bool operator ==(Object other) =>
      other is FilamentNativeSurfaceHandle && other.handle == handle && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(handle, width, height);

  @override
  String toString() => 'FilamentNativeSurfaceHandle(0x${handle.toRadixString(16)}, $width x $height)';
}

/// How a [FilamentWidget] presents its frames.
enum FilamentPresentationKind {
  /// Rendered offscreen, read back and shown by Flutter as an image.
  texture,

  /// Rendered into a SwapChain on a native window and presented by Filament.
  direct,
}

/// What a [FilamentWidget] presents through, and why it fell back when it
/// was asked for direct presentation and could not.
@immutable
class FilamentPresentationStatus {
  const FilamentPresentationStatus(this.kind, {this.reason});

  final FilamentPresentationKind kind;

  /// Why direct presentation is not in use (null when it is, or when it was
  /// not asked for).
  final String? reason;

  @override
  bool operator ==(Object other) => other is FilamentPresentationStatus && other.kind == kind && other.reason == reason;

  @override
  int get hashCode => Object.hash(kind, reason);

  @override
  String toString() => 'FilamentPresentationStatus(${kind.name}${reason == null ? '' : ': $reason'})';
}
