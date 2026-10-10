/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_OPENDLSS_NR_C_H
#define FLUTTER_FILAMENT_OPENDLSS_NR_C_H

#include <stdbool.h>
#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

// OpenDLSS-NR (experimental, third-party): the network of github.com/maanHimself/OpenDLSS-NR (MIT, vendored GLSL
// route in third_party/opendlss_nr) as an external post pass on the HDR frame (View::setExternalPostPass). It runs
// only on model weights the user supplies; nothing here ships, fetches or derives any. Desktop Vulkan on NVIDIA Ada
// or newer only; every other platform reports "not available". Messages are UTF-8, written into the caller's
// buffer (truncated to `capacity` bytes, always terminated).

typedef enum filament_opendlss_nr_capability_code {
    FILAMENT_OPENDLSS_NR_CAPABLE = 0,
    FILAMENT_OPENDLSS_NR_NOT_VULKAN = 1,
    FILAMENT_OPENDLSS_NR_NOT_NVIDIA = 2,
    FILAMENT_OPENDLSS_NR_MISSING_EXTENSION = 3,
    FILAMENT_OPENDLSS_NR_OLDER_GPU = 4,
    FILAMENT_OPENDLSS_NR_NOT_ENABLED = 5
} filament_opendlss_nr_capability_code;

typedef enum filament_opendlss_nr_model_code {
    FILAMENT_OPENDLSS_NR_MODEL_OK = 0,
    FILAMENT_OPENDLSS_NR_MODEL_MISSING = 1,
    FILAMENT_OPENDLSS_NR_MODEL_INVALID_MANIFEST = 2,
    FILAMENT_OPENDLSS_NR_MODEL_STAGE_MISMATCH = 3,
    FILAMENT_OPENDLSS_NR_MODEL_LAYOUT_MISMATCH = 4,
    FILAMENT_OPENDLSS_NR_MODEL_HASH_MISMATCH = 5,
    FILAMENT_OPENDLSS_NR_MODEL_IO_ERROR = 6,
    FILAMENT_OPENDLSS_NR_MODEL_UNAVAILABLE = 7
} filament_opendlss_nr_model_code;

typedef struct filament_opendlss_nr_model_info {
    uint32_t block_count;
    uint32_t stage_count;
    uint32_t tensor_count;
    uint64_t total_bytes;
} filament_opendlss_nr_model_info;

typedef struct filament_opendlss_nr_controls {
    bool enabled;            // false: the frame passes through unchanged
    float intensity;         // 0..1
    float local_tone;        // conditioning scalars the network sees
    float local_structure;
    float skin_structure;    // -1 follows local_structure
    bool auto_mask;
    uint32_t style;          // 0 none, 1 natural, 2 cinematic
    float paper_white;       // scene value shown as paper white (the network's display proxy)
    float color_strength;    // 0..1: 0 keeps the frame's colours, 1 takes the network's
} filament_opendlss_nr_controls;

typedef struct filament_opendlss_nr_status {
    uint64_t frames;
    uint32_t width;
    uint32_t height;
    bool failed;
    double gpu_ms;
    double gpu_ms_average;
    uint32_t dispatches;
    uint64_t device_bytes;
} filament_opendlss_nr_status;

// Asks the engines created from now on for the extensions and feature members the kernels need.
FFI_PLUGIN_EXPORT void filament_opendlss_nr_request_device_features(void);

// Whether `engine`'s device runs the pass (filament_opendlss_nr_capability_code); the reason or the device.
FFI_PLUGIN_EXPORT int32_t filament_opendlss_nr_capability(void* engine, char* reason, int32_t capacity);

// Checks a model directory (manifest.json + model/<stage files>) against what the network reads; with
// `verify_hashes` also the stage files' SHA-256. Any thread. Returns a filament_opendlss_nr_model_code.
FFI_PLUGIN_EXPORT int32_t filament_opendlss_nr_validate_model(const char* directory, bool verify_hashes,
        filament_opendlss_nr_model_info* info, char* message, int32_t capacity);

// Writes a synthetic model of the network's layout (fill 0: zeros, 1: small random values from `seed`) for tests
// and timing. It holds no trained weights. Returns 0, or 1 with the message.
FFI_PLUGIN_EXPORT int32_t filament_opendlss_nr_write_synthetic_model(const char* directory, uint32_t seed, int32_t fill,
        char* message, int32_t capacity);

// Loads a validated model onto `engine`'s device. Any thread (no Filament calls). NULL with the message on failure.
FFI_PLUGIN_EXPORT void* filament_opendlss_nr_model_load(void* engine, const char* directory, char* message, int32_t capacity);

// Releases a model once no pass uses it (waits for the engine). Safe with NULL.
FFI_PLUGIN_EXPORT void filament_opendlss_nr_model_destroy(void* model);

// Registers the pass on `view` (the engine's thread). NULL with the message when it cannot run there.
FFI_PLUGIN_EXPORT void* filament_opendlss_nr_create(void* engine, void* view, void* model, char* message, int32_t capacity);

FFI_PLUGIN_EXPORT void filament_opendlss_nr_set_controls(void* pass, const filament_opendlss_nr_controls* controls);

// The pass's state; `failure` gets the reason it turned itself off (empty while it runs).
FFI_PLUGIN_EXPORT void filament_opendlss_nr_get_status(void* pass, filament_opendlss_nr_status* status, char* failure,
        int32_t capacity);

// Unregisters the pass, waits for the engine and frees it. Safe with NULL.
FFI_PLUGIN_EXPORT void filament_opendlss_nr_destroy(void* pass);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_OPENDLSS_NR_C_H
