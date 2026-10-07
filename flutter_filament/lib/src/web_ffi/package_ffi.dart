/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

/// Web builds: the subset of `package:ffi` flutter_filament
/// uses — `calloc` / `malloc`, `Arena` / `using`, and UTF-8 strings — over the
/// WebAssembly module's `_malloc` / `_free`.
library;

import 'dart:convert';

import 'package:flutter_filament/src/web_ffi/ffi.dart';
import 'package:flutter_filament/src/web_ffi/module.dart';

final class _WasmAllocator implements Allocator {
  final bool zero;
  const _WasmAllocator({required this.zero});

  @override
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment}) {
    // Emscripten's malloc aligns to 8 (16 with -msimd128), enough for every
    // type the bindings use.
    final address = FlutterFilamentModule.malloc(byteCount < 1 ? 1 : byteCount);
    if (address == 0) throw StateError('flutter_filament web: out of memory allocating $byteCount bytes');
    if (zero) FlutterFilamentModule.heapBytes.fillRange(address, address + byteCount, 0);
    return Pointer<T>.fromAddress(address);
  }

  @override
  void free(Pointer<NativeType> pointer) {
    if (pointer.address != 0) FlutterFilamentModule.free(pointer.address);
  }
}

/// Zero-initialised allocations (C `calloc`).
const Allocator calloc = _WasmAllocator(zero: true);

/// Uninitialised allocations (C `malloc`).
const Allocator malloc = _WasmAllocator(zero: false);

extension AllocatorAlloc on Allocator {
  /// Allocates room for [count] values of [T].
  Pointer<T> call<T extends SizedNativeType>([int count = 1]) =>
      allocate<T>(sizeOf<T>() * count, alignment: $alignOf<T>());
}

/// Frees everything it allocated at once ([releaseAll], or the end of [using]).
class Arena implements Allocator {
  final Allocator _wrapped;
  final List<Pointer<NativeType>> _managed = [];
  final List<void Function()> _onRelease = [];
  bool _inUse = true;

  Arena([Allocator allocator = calloc]) : _wrapped = allocator;

  @override
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment}) {
    if (!_inUse) throw StateError('Arena no longer in use');
    final p = _wrapped.allocate<T>(byteCount, alignment: alignment);
    _managed.add(p);
    return p;
  }

  /// A no-op, like package:ffi: memory goes back in [releaseAll].
  @override
  void free(Pointer<NativeType> pointer) {}

  T using<T>(T resource, void Function(T) releaseCallback) {
    _onRelease.add(() => releaseCallback(resource));
    return resource;
  }

  void onReleaseAll(void Function() callback) => _onRelease.add(callback);

  void releaseAll({bool reuse = false}) {
    if (!reuse) _inUse = false;
    while (_onRelease.isNotEmpty) {
      _onRelease.removeLast()();
    }
    for (final p in _managed) {
      _wrapped.free(p);
    }
    _managed.clear();
  }
}

/// Runs [computation] with an [Arena] released afterwards (also after async work).
R using<R>(R Function(Arena) computation, [Allocator wrappedAllocator = calloc]) {
  final arena = Arena(wrappedAllocator);
  var isAsync = false;
  try {
    final result = computation(arena);
    if (result is Future) {
      isAsync = true;
      return (result.whenComplete(arena.releaseAll) as R);
    }
    return result;
  } finally {
    if (!isAsync) arena.releaseAll();
  }
}

/// A NUL-terminated UTF-8 string.
final class Utf8 extends Opaque {
  const Utf8();
}

extension Utf8Pointer on Pointer<Utf8> {
  /// Bytes before the NUL terminator.
  int get length {
    final bytes = FlutterFilamentModule.heapBytes;
    var end = address;
    while (bytes[end] != 0) {
      end++;
    }
    return end - address;
  }

  String toDartString({int? length}) {
    final n = length ?? this.length;
    return utf8.decode(FlutterFilamentModule.heapBytes.sublist(address, address + n), allowMalformed: true);
  }
}

extension StringUtf8Pointer on String {
  Pointer<Utf8> toNativeUtf8({Allocator allocator = malloc}) {
    final units = utf8.encode(this);
    final p = allocator.allocate<Utf8>(units.length + 1);
    final bytes = FlutterFilamentModule.heapBytes;
    bytes.setRange(p.address, p.address + units.length, units);
    bytes[p.address + units.length] = 0;
    return p;
  }
}
