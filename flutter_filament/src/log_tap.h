/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// Internal (C++ only, not part of the FFI surface): lets a C wrapper see what Filament logs through utils::slog
// while it runs, without taking the log over from the Dart log bridge (filament_set_log_callback).

#ifndef FLUTTER_FILAMENT_LOG_TAP_H
#define FLUTTER_FILAMENT_LOG_TAP_H

namespace flutter_filament {

/// Receives every utils::slog line: `priority` is the Android-style level the Dart log bridge uses
/// (2 verbose, 3 debug, 4 info, 5 warning, 6 error).
using LogTap = void (*)(void* user, int priority, const char* message);

/// Installs `tap` (NULL removes it). While a tap is installed every slog stream is routed through the wrapper:
/// a registered Dart log callback still receives each line, and without one the line is printed to stdout/stderr
/// as Filament would have printed it.
void setLogTap(LogTap tap, void* user);

} // namespace flutter_filament

#endif // FLUTTER_FILAMENT_LOG_TAP_H
