/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// The OpenDLSS-NR post pass runs on desktop Vulkan (Windows, Linux) only; elsewhere every entry point reports
// "not available" and the vendored network code is compiled out.
#pragma once

#if !defined(__EMSCRIPTEN__) && (defined(_WIN32) || (defined(__linux__) && !defined(__ANDROID__)))
#define FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED 1
#else
#define FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED 0
#endif
