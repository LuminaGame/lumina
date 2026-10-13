/// The Jolt backend: the native library where `dart:ffi` exists, the
/// WebAssembly module on the web (once loaded), nothing elsewhere.
library;

export 'package:lumina/src/physics/jolt/jolt_backend_factory_stub.dart'
    if (dart.library.ffi) 'package:lumina/src/physics/jolt/jolt_backend_factory_io.dart'
    if (dart.library.js_interop) 'package:lumina/src/physics/jolt/jolt_backend_factory_web.dart';
