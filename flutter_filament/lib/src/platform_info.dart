/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'package:flutter_filament/src/platform_os_native.dart'
    if (dart.library.js_interop) 'package:flutter_filament/src/platform_os_web.dart' as os;
import 'package:flutter_filament/src/web_init.dart';

/// What the running build of flutter_filament is, for code that picks a
/// different path per platform (a material provider, a backend, a feature).
abstract final class FilamentPlatformInfo {
  /// A web (WebAssembly + WebGL2) build.
  static bool get isWeb => FilamentWeb.isWeb;

  /// An Android build (phones and standalone headsets such as the Quest).
  /// Its engine defaults to Vulkan and falls back to OpenGL ES; it runs at a
  /// mobile feature level and loads the MOBILE shaders of a material, has no
  /// JIT glTF material provider (use the ubershader one), no matdbg and no
  /// imageio encoders, and reports ray queries, ReSTIR and DLSS as unsupported.
  static bool get isAndroid => !isWeb && os.hostIsAndroid;

  /// Whether the JIT glTF material provider (runtime material compilation) is
  /// in this build; when false, use [FilamentMaterialProvider.ubershader].
  static bool get hasJitMaterialProvider => !isWeb && !isAndroid;
}
