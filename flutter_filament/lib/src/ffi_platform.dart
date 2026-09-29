/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

/// `dart:ffi` on native platforms; the WebAssembly-backed layer on the web.
/// Wrappers import this instead of `dart:ffi`.
library;

export 'dart:ffi' if (dart.library.js_interop) 'web_ffi/ffi.dart';
