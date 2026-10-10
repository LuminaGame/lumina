/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// What the OpenDLSS-NR kernels need from the device: the extensions and feature members requested before an engine
// exists, and the check of an engine's device (NVIDIA, FP8 cooperative matrices = Ada or newer, everything enabled).
#pragma once

#include <cstdint>
#include <string>

namespace opendlss_nr {

enum CapabilityCode : int32_t {
  kCapable = 0,
  kNotVulkan = 1,          // not the desktop Vulkan backend (or the web)
  kNotNvidia = 2,          // another vendor
  kMissingExtension = 3,   // the driver lacks an extension
  kOlderGpu = 4,           // no FP8 cooperative matrices: older than Ada
  kNotEnabled = 5,         // the device supports it but the engine was created without it
};

struct Capability {
  int32_t code = kNotVulkan;
  std::string reason;
  std::string deviceName;
};

void requestDeviceFeatures();
Capability checkCapability(void* engine);

}  // namespace opendlss_nr
