/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "frame_pacer_c.h"
#include <filament/Engine.h>
#include <filament/FramePacer.h>
#include <filament/Renderer.h>
#include <vector>
#include "utils_c.h"

using namespace filament;

#define FFI_TRY try {
#define FFI_CATCH(return_val) } catch (...) { return return_val; }
#define FFI_CATCH_VOID() } catch (...) { }

static inline Engine* toEngine(void* ptr) {
    return reinterpret_cast<Engine*>(ptr);
}

static inline FramePacer* toFramePacer(void* ptr) {
    return reinterpret_cast<FramePacer*>(ptr);
}

static inline Renderer* toRenderer(void* ptr) {
    return reinterpret_cast<Renderer*>(ptr);
}

void* filament_frame_pacer_create(void* engine, const filament_frame_pacer_config_t* config) {
    FFI_TRY
    if (!engine) return nullptr;
    FramePacer::Builder builder;
    if (config) {
        if (config->target_frame_rate > 0) {
            builder.targetFrameRate(config->target_frame_rate);
        }
        if (config->latency_ns > 0) {
            builder.latency(std::chrono::nanoseconds(config->latency_ns));
        }
    }
    return builder.build(*toEngine(engine));
    FFI_CATCH(nullptr)
}

void filament_engine_destroy_frame_pacer(void* engine, void* pacer) {
    FFI_TRY
    if (engine && pacer) {
        toEngine(engine)->destroy(toFramePacer(pacer));
    }
    FFI_CATCH_VOID()
}

void filament_frame_pacer_configure(void* pacer, const filament_frame_pacer_config_t* config) {
    FFI_TRY
    if (!pacer || !config) return;
    FramePacer::Configuration cfg;
    cfg.targetFrameRate = config->target_frame_rate;
    cfg.latency = std::chrono::nanoseconds(config->latency_ns);
    toFramePacer(pacer)->configure(cfg);
    FFI_CATCH_VOID()
}

void filament_frame_pacer_get_configuration(void* pacer, filament_frame_pacer_config_t* out_config) {
    FFI_TRY
    if (!pacer || !out_config) return;
    const auto& cfg = toFramePacer(pacer)->getConfiguration();
    out_config->target_frame_rate = cfg.targetFrameRate;
    out_config->latency_ns = cfg.latency.count();
    FFI_CATCH_VOID()
}

int8_t filament_frame_pacer_setup_frame(void* pacer, const filament_vsync_tick_t* tick) {
    FFI_TRY
    if (!pacer || !tick) return static_cast<int8_t>(FramePacer::FrameStatus::SKIPPED_STALE);
    
    FramePacer::VsyncTick nativeTick;
    nativeTick.baseTime = FramePacer::time_point_t(std::chrono::nanoseconds(tick->base_time_ns));
    nativeTick.vsyncPeriod = std::chrono::nanoseconds(tick->vsync_period_ns);
    if (tick->frame_schedule_time_ns > 0) {
        nativeTick.frameScheduleTime = FramePacer::time_point_t(std::chrono::nanoseconds(tick->frame_schedule_time_ns));
    } else {
        nativeTick.frameScheduleTime = std::chrono::steady_clock::now();
    }
    
    std::vector<FramePacer::HardwareTimeline> timelinesVec;
    if (tick->timelines && tick->timeline_count > 0) {
        timelinesVec.reserve(tick->timeline_count);
        for (uint32_t i = 0; i < tick->timeline_count; ++i) {
            timelinesVec.push_back({
                FramePacer::time_point_t(std::chrono::nanoseconds(tick->timelines[i].expected_presentation_time_ns)),
                FramePacer::time_point_t(std::chrono::nanoseconds(tick->timelines[i].deadline_ns))
            });
        }
        nativeTick.timelines = utils::Slice<const FramePacer::HardwareTimeline>(timelinesVec.data(), timelinesVec.size());
    }
    
    auto status = toFramePacer(pacer)->setupFrame(nativeTick);
    return static_cast<int8_t>(status);
    FFI_CATCH(static_cast<int8_t>(FramePacer::FrameStatus::SKIPPED_STALE))
}

bool filament_frame_pacer_setup_extra_frame(void* pacer) {
    FFI_TRY
    if (!pacer) return false;
    return toFramePacer(pacer)->setupExtraFrame();
    FFI_CATCH(false)
}

bool filament_frame_pacer_has_gpu_fallen_behind(void* pacer, void* renderer) {
    FFI_TRY
    if (!pacer || !renderer) return false;
    return toFramePacer(pacer)->hasGpuFallenBehind(toRenderer(renderer));
    FFI_CATCH(false)
}

void filament_frame_pacer_apply_presentation_time(void* pacer, void* renderer) {
    FFI_TRY
    if (!pacer || !renderer) return;
    toFramePacer(pacer)->applyPresentationTime(toRenderer(renderer));
    FFI_CATCH_VOID()
}

void filament_frame_pacer_reset_pacing(void* pacer) {
    FFI_TRY
    if (!pacer) return;
    toFramePacer(pacer)->resetPacing();
    FFI_CATCH_VOID()
}

int64_t filament_frame_pacer_get_expected_presentation_time(void* pacer) {
    FFI_TRY
    if (!pacer) return 0;
    return toFramePacer(pacer)->getExpectedPresentationTime().time_since_epoch().count();
    FFI_CATCH(0)
}

int64_t filament_frame_pacer_get_rendering_deadline(void* pacer) {
    FFI_TRY
    if (!pacer) return 0;
    return toFramePacer(pacer)->getRenderingDeadline().time_since_epoch().count();
    FFI_CATCH(0)
}

int64_t filament_frame_pacer_get_effective_latency(void* pacer) {
    FFI_TRY
    if (!pacer) return 0;
    return toFramePacer(pacer)->getEffectiveLatency().count();
    FFI_CATCH(0)
}

int8_t filament_frame_pacer_get_pacing_status(void* pacer) {
    FFI_TRY
    if (!pacer) return 0;
    return static_cast<int8_t>(toFramePacer(pacer)->getPacingStatus());
    FFI_CATCH(0)
}

float filament_frame_pacer_get_selected_frame_rate(void* pacer) {
    FFI_TRY
    if (!pacer) return 0.0f;
    return toFramePacer(pacer)->getSelectedFrameRate();
    FFI_CATCH(0.0f)
}

bool filament_frame_pacer_is_exact_frame_rate_achieved(void* pacer) {
    FFI_TRY
    if (!pacer) return false;
    return toFramePacer(pacer)->isExactFrameRateAchieved();
    FFI_CATCH(false)
}
