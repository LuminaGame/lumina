/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

/// The C bindings: ffigen's `@Native` externals on native platforms, the
/// generated WebAssembly calls on the web (tool/ffigen_web.dart).
library;

export 'package:flutter_filament/src/third_party/filament_c.g.dart' if (dart.library.js_interop) 'third_party/filament_c.web.g.dart';
