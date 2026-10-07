/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

/// `dart:ffi` natively, flutter_filament's WebAssembly-backed counterpart on
/// the web. Packages that pass pointers to flutter_filament
/// import this instead of `dart:ffi`, so they build for the web too.
library;

export 'package:flutter_filament/src/ffi_platform.dart';
