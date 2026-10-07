/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'package:flutter_filament/src/math_types.web.g.dart' show $registerMathTypes;
import 'package:flutter_filament/src/third_party/filament_c.web.g.dart' show $registerFilamentBindings;
import 'package:flutter_filament/src/web_ffi/module.dart';

/// Platform initialisation for flutter_filament.
abstract final class FilamentWeb {
  static bool _registered = false;

  /// Loads the WebAssembly module (`flutter_filament.js` + `.wasm` from
  /// [moduleUrl]'s directory) and registers the generated struct layouts and
  /// callback types. Call once before using any flutter_filament API on the
  /// web. Idempotent.
  static Future<void> ensureInitialized({String moduleUrl = 'flutter_filament.js'}) async {
    if (!_registered) {
      _registered = true;
      $registerFilamentBindings();
      $registerMathTypes();
    }
    await FlutterFilamentModule.load(scriptUrl: moduleUrl);
  }

  /// Whether this is a web build.
  static const bool isWeb = true;
}
