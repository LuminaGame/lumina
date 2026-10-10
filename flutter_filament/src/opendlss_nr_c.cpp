/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// The C surface of the OpenDLSS-NR post pass (see opendlss_nr_c.h and src/opendlss_nr/). Nothing here throws:
// every failure becomes a code and a message.

#include "opendlss_nr_c.h"

#include <algorithm>
#include <cstring>
#include <string>

#include "opendlss_nr/opendlss_nr_config.h"

namespace {

void writeMessage(char* out, int32_t capacity, const std::string& text) {
    if (!out || capacity <= 0) return;
    const size_t n = std::min<size_t>(text.size(), (size_t)capacity - 1);
    std::memcpy(out, text.data(), n);
    out[n] = '\0';
}

constexpr const char* kUnavailable = "OpenDLSS-NR is not available on this platform (desktop Vulkan only)";

} // namespace

#if FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED

#include <filament/Engine.h>
#include <filament/View.h>

#include "opendlss_nr/capability.h"
#include "opendlss_nr/model_check.h"
#include "opendlss_nr/neural_pass.h"

using namespace filament;

void filament_opendlss_nr_request_device_features(void) {
    opendlss_nr::requestDeviceFeatures();
}

int32_t filament_opendlss_nr_capability(void* engine, char* reason, int32_t capacity) {
    try {
        opendlss_nr::Capability c = opendlss_nr::checkCapability(engine);
        writeMessage(reason, capacity, c.reason);
        return c.code;
    } catch (const std::exception& e) {
        writeMessage(reason, capacity, e.what());
        return FILAMENT_OPENDLSS_NR_NOT_VULKAN;
    }
}

int32_t filament_opendlss_nr_validate_model(const char* directory, bool verify_hashes,
        filament_opendlss_nr_model_info* info, char* message, int32_t capacity) {
    if (info) *info = {};
    opendlss_nr::ModelCheck check = opendlss_nr::checkModel(directory ? directory : "", verify_hashes);
    if (info) {
        info->block_count = check.blockCount;
        info->stage_count = check.stageCount;
        info->tensor_count = check.tensorCount;
        info->total_bytes = check.totalBytes;
    }
    writeMessage(message, capacity, check.message);
    return check.code;
}

int32_t filament_opendlss_nr_write_synthetic_model(const char* directory, uint32_t seed, int32_t fill,
        char* message, int32_t capacity) {
    std::string error = opendlss_nr::writeSyntheticModel(directory ? directory : "", seed, fill);
    writeMessage(message, capacity, error);
    return error.empty() ? 0 : 1;
}

void* filament_opendlss_nr_model_load(void* engine, const char* directory, char* message, int32_t capacity) {
    std::string error;
    opendlss_nr::LoadedModel* model = nullptr;
    try {
        model = opendlss_nr::loadModel(static_cast<Engine*>(engine), directory ? directory : "", error);
    } catch (const std::exception& e) {
        error = e.what();
    }
    writeMessage(message, capacity, model ? std::string() : error);
    return model;
}

void filament_opendlss_nr_model_destroy(void* model) {
    if (!model) return;
    auto* m = static_cast<opendlss_nr::LoadedModel*>(model);
    // Uploads recorded into frames may still run.
    if (m->engine) m->engine->flushAndWait();
    delete m;
}

void* filament_opendlss_nr_create(void* engine, void* view, void* model, char* message, int32_t capacity) {
    if (!engine || !view || !model) {
        writeMessage(message, capacity, "an engine, a view and a loaded model are required");
        return nullptr;
    }
    auto* m = static_cast<opendlss_nr::LoadedModel*>(model);
    if (m->engine != engine) {
        writeMessage(message, capacity, "the model was loaded on another engine");
        return nullptr;
    }
    opendlss_nr::Capability c = opendlss_nr::checkCapability(engine);
    if (c.code != opendlss_nr::kCapable) {
        writeMessage(message, capacity, c.reason);
        return nullptr;
    }
    try {
        auto* pass = new opendlss_nr::NeuralPass(static_cast<Engine*>(engine), static_cast<View*>(view), m);
        static_cast<View*>(view)->setExternalPostPass(pass);
        writeMessage(message, capacity, std::string());
        return pass;
    } catch (const std::exception& e) {
        writeMessage(message, capacity, e.what());
        return nullptr;
    }
}

void filament_opendlss_nr_set_controls(void* pass, const filament_opendlss_nr_controls* controls) {
    if (!pass || !controls) return;
    opendlss_nr::Controls c;
    c.enabled = controls->enabled;
    c.intensity = controls->intensity;
    c.localTone = controls->local_tone;
    c.localStructure = controls->local_structure;
    c.skinStructure = controls->skin_structure;
    c.autoMask = controls->auto_mask;
    c.style = controls->style;
    c.paperWhite = controls->paper_white;
    c.colorStrength = controls->color_strength;
    static_cast<opendlss_nr::NeuralPass*>(pass)->setControls(c);
}

void filament_opendlss_nr_get_status(void* pass, filament_opendlss_nr_status* status, char* failure, int32_t capacity) {
    if (status) *status = {};
    writeMessage(failure, capacity, std::string());
    if (!pass) return;
    auto* p = static_cast<opendlss_nr::NeuralPass*>(pass);
    opendlss_nr::Status s = p->status();
    if (status) {
        status->frames = s.frames;
        status->width = s.width;
        status->height = s.height;
        status->failed = s.failed;
        status->gpu_ms = s.gpuMs;
        status->gpu_ms_average = s.gpuMsAverage;
        status->dispatches = s.dispatches;
        status->device_bytes = s.deviceBytes;
    }
    writeMessage(failure, capacity, p->failure());
}

void filament_opendlss_nr_destroy(void* pass) {
    if (!pass) return;
    auto* p = static_cast<opendlss_nr::NeuralPass*>(pass);
    if (p->view()->getExternalPostPass() == p) p->view()->setExternalPostPass(nullptr);
    // frames recorded before this call may still run the pass
    p->engine()->flushAndWait();
    p->destroyObjects();
    delete p;
}

#else // !FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED

void filament_opendlss_nr_request_device_features(void) {}

int32_t filament_opendlss_nr_capability(void* engine, char* reason, int32_t capacity) {
    (void) engine;
    writeMessage(reason, capacity, kUnavailable);
    return FILAMENT_OPENDLSS_NR_NOT_VULKAN;
}

int32_t filament_opendlss_nr_validate_model(const char* directory, bool verify_hashes,
        filament_opendlss_nr_model_info* info, char* message, int32_t capacity) {
    (void) directory;
    (void) verify_hashes;
    if (info) *info = {};
    writeMessage(message, capacity, kUnavailable);
    return FILAMENT_OPENDLSS_NR_MODEL_UNAVAILABLE;
}

int32_t filament_opendlss_nr_write_synthetic_model(const char* directory, uint32_t seed, int32_t fill,
        char* message, int32_t capacity) {
    (void) directory;
    (void) seed;
    (void) fill;
    writeMessage(message, capacity, kUnavailable);
    return 1;
}

void* filament_opendlss_nr_model_load(void* engine, const char* directory, char* message, int32_t capacity) {
    (void) engine;
    (void) directory;
    writeMessage(message, capacity, kUnavailable);
    return nullptr;
}

void filament_opendlss_nr_model_destroy(void* model) {
    (void) model;
}

void* filament_opendlss_nr_create(void* engine, void* view, void* model, char* message, int32_t capacity) {
    (void) engine;
    (void) view;
    (void) model;
    writeMessage(message, capacity, kUnavailable);
    return nullptr;
}

void filament_opendlss_nr_set_controls(void* pass, const filament_opendlss_nr_controls* controls) {
    (void) pass;
    (void) controls;
}

void filament_opendlss_nr_get_status(void* pass, filament_opendlss_nr_status* status, char* failure, int32_t capacity) {
    (void) pass;
    if (status) *status = {};
    writeMessage(failure, capacity, std::string());
}

void filament_opendlss_nr_destroy(void* pass) {
    (void) pass;
}

#endif // FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED
