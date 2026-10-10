/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// The OpenDLSS-NR model directory (manifest.json + model/<stage files>) as the vendored loader and graph read it:
// a validator that refuses anything the graph could not run on (before any byte reaches the GPU), and a writer of
// synthetic models of the same layout (zero or random weights, never real model data) for tests and timing.
#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace opendlss_nr {

enum ModelCheckCode : int32_t {
  kModelOk = 0,
  kModelMissing = 1,         // no directory, or no manifest.json in it
  kModelInvalidManifest = 2, // not JSON, too large, too deep, missing keys, wrong block count
  kModelStageMismatch = 3,   // a stage file missing, of the wrong size, or with an unsafe name
  kModelLayoutMismatch = 4,  // a tensor the graph reads missing, too small, out of its stage
  kModelHashMismatch = 5,    // a stage file whose SHA-256 differs from the manifest
  kModelIoError = 6,
};

struct ModelCheck {
  int32_t code = kModelMissing;
  std::string message;
  uint32_t blockCount = 0, stageCount = 0, tensorCount = 0;
  uint64_t totalBytes = 0;
};

// One tensor the 71-block graph reads: its record name, the bytes it reads from it and whether the layout fixes
// the length exactly.
struct TensorRequirement {
  int block = 0, layer = 0;
  std::string parameter = "layer";
  uint32_t bytes = 0;
  bool exact = false;
  std::string name() const;
};

const std::vector<TensorRequirement>& requiredTensors();

ModelCheck checkModel(const std::string& directory, bool verifyHashes);

// fill: 0 zeros, 1 small random E4M3 codes (finite as halves and floats too). Returns an empty string or the error.
std::string writeSyntheticModel(const std::string& directory, uint32_t seed, int fill);

}  // namespace opendlss_nr
