import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_filament/flutter_filament.dart';

/// A plain top-level Win32 window (the predefined STATIC class, so no window
/// procedure is needed) for a real Vulkan swap chain in tests.
class Win32TestWindow {
  Win32TestWindow._(this.hwnd, this._msg);

  final ffi.Pointer<ffi.Void> hwnd;
  final ffi.Pointer<ffi.Uint8> _msg;

  static final _user32 = ffi.DynamicLibrary.open('user32.dll');
  static final _create = _user32.lookupFunction<
      ffi.Pointer<ffi.Void> Function(ffi.Uint32, ffi.Pointer<Utf16>, ffi.Pointer<Utf16>, ffi.Uint32, ffi.Int32,
          ffi.Int32, ffi.Int32, ffi.Int32, ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>,
          ffi.Pointer<ffi.Void>),
      ffi.Pointer<ffi.Void> Function(int, ffi.Pointer<Utf16>, ffi.Pointer<Utf16>, int, int, int, int, int,
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>)>('CreateWindowExW');
  static final _destroy = _user32.lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>),
      int Function(ffi.Pointer<ffi.Void>)>('DestroyWindow');
  static final _peek = _user32.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<ffi.Uint8>, ffi.Pointer<ffi.Void>, ffi.Uint32, ffi.Uint32, ffi.Uint32),
      int Function(ffi.Pointer<ffi.Uint8>, ffi.Pointer<ffi.Void>, int, int, int)>('PeekMessageW');
  static final _clientRect = _user32.lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Int32>),
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Int32>)>('GetClientRect');
  static final _dispatch = _user32.lookupFunction<ffi.IntPtr Function(ffi.Pointer<ffi.Uint8>),
      int Function(ffi.Pointer<ffi.Uint8>)>('DispatchMessageW');
  static final _setPos = _user32.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>, ffi.Int32, ffi.Int32, ffi.Int32, ffi.Int32,
          ffi.Uint32),
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>, int, int, int, int, int)>('SetWindowPos');

  static Win32TestWindow open(int width, int height, String title) {
    const wsOverlappedWindow = 0x00CF0000, wsVisible = 0x10000000;
    final cls = 'STATIC'.toNativeUtf16();
    final name = title.toNativeUtf16();
    try {
      final hwnd = _create(0, cls, name, wsOverlappedWindow | wsVisible, 100, 100, width, height, ffi.nullptr,
          ffi.nullptr, ffi.nullptr, ffi.nullptr);
      if (hwnd == ffi.nullptr) throw StateError('CreateWindowExW failed');
      return Win32TestWindow._(hwnd, calloc<ffi.Uint8>(64));
    } finally {
      calloc.free(cls);
      calloc.free(name);
    }
  }

  /// The size of the client area (what the swap chain covers).
  (int, int) get clientSize {
    final rect = calloc<ffi.Int32>(4);
    try {
      _clientRect(hwnd, rect);
      return (rect[2] - rect[0], rect[3] - rect[1]);
    } finally {
      calloc.free(rect);
    }
  }

  /// Resizes the whole window (frame included).
  void resize(int width, int height) {
    const swpNoMove = 0x2, swpNoZOrder = 0x4;
    _setPos(hwnd, ffi.nullptr, 0, 0, width, height, swpNoMove | swpNoZOrder);
  }

  /// Handles the pending messages of the window.
  void pump() {
    const pmRemove = 1;
    while (_peek(_msg, ffi.nullptr, 0, 0, pmRemove) != 0) {
      _dispatch(_msg);
    }
  }

  void close() {
    _destroy(hwnd);
    calloc.free(_msg);
  }
}

/// A [FilamentNativeSurface] over a [Win32TestWindow].
class Win32TestSurface implements FilamentNativeSurface {
  Win32TestSurface(this.window);

  final Win32TestWindow window;
  final ValueNotifier<FilamentNativeSurfaceHandle?> _current = ValueNotifier(null);
  int acquires = 0;
  int releases = 0;

  @override
  Future<FilamentNativeSurfaceHandle?> acquire() async {
    acquires++;
    final (w, h) = window.clientSize;
    return _current.value = FilamentNativeSurfaceHandle(handle: window.hwnd.address, width: w, height: h);
  }

  /// Reports the window's new client size (what a runner's resize message does).
  void sizeChanged() {
    final (w, h) = window.clientSize;
    _current.value = FilamentNativeSurfaceHandle(handle: window.hwnd.address, width: w, height: h);
  }

  @override
  Future<void> release() async => releases++;

  @override
  String? get unavailableReason => null;

  @override
  ValueListenable<FilamentNativeSurfaceHandle?> get current => _current;
}

/// A surface the host cannot provide.
class MissingSurface implements FilamentNativeSurface {
  @override
  Future<FilamentNativeSurfaceHandle?> acquire() async => null;

  @override
  Future<void> release() async {}

  @override
  String? get unavailableReason => 'the runner has no presentation surface';

  @override
  ValueListenable<FilamentNativeSurfaceHandle?> get current => ValueNotifier(null);
}
