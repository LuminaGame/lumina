/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

/// Platform initialisation for flutter_filament.
abstract final class FilamentWeb {
  /// Native platforms link the library at build time: nothing to do.
  static Future<void> ensureInitialized({String moduleUrl = 'flutter_filament.js'}) async {}

  /// Whether this is a web build.
  static const bool isWeb = false;
}
