/// The Jolt backend where `dart:ffi` exists, nothing on the web.
library;

export 'package:lumina/src/physics/jolt/jolt_backend_factory_stub.dart'
    if (dart.library.ffi) 'package:lumina/src/physics/jolt/jolt_backend_factory_io.dart';
