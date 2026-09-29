/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

/// `package:ffi` on native platforms; its web counterpart over the
/// WebAssembly module's heap on the web.
export 'package:ffi/ffi.dart' if (dart.library.js_interop) 'web_ffi/package_ffi.dart';
