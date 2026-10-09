/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "renderer_c.h"

#include <filament/Renderer.h>
#include <filament/Engine.h>
#include <filament/View.h>
#include <filament/SwapChain.h>
#include <filament/RenderTarget.h>
#include <backend/PixelBufferDescriptor.h>
#include <algorithm>
#include <chrono>

using namespace filament;

#define FFI_TRY try {
#define FFI_CATCH(return_val) } catch (...) { return return_val; }

static inline Renderer* toRenderer(void* ptr) {
  return static_cast<Renderer*>(ptr);
}

static inline View* toView(void* ptr) {
  return static_cast<View*>(ptr);
}

static inline SwapChain* toSwapChain(void* ptr) {
  return static_cast<SwapChain*>(ptr);
}

static inline RenderTarget* toRenderTarget(void* ptr) {
  return static_cast<RenderTarget*>(ptr);
}

extern "C" {

// ==========================================
// Clear Options
// ==========================================

void filament_renderer_set_clear_options_ex(void* renderer, const filament_clear_options_t* opts) {
  FFI_TRY
  if (!renderer || !opts) return;
  Renderer::ClearOptions options;
  options.clearColor = {opts->clear_color[0], opts->clear_color[1], opts->clear_color[2], opts->clear_color[3]};
  options.clearStencil = opts->clear_stencil;
  options.clear = opts->clear;
  options.discard = opts->discard;
  toRenderer(renderer)->setClearOptions(options);
  FFI_CATCH()
}

void filament_renderer_get_clear_options(void* renderer, filament_clear_options_t* out) {
  FFI_TRY
  if (!renderer || !out) return;
  const Renderer::ClearOptions& opts = toRenderer(renderer)->getClearOptions();
  out->clear_color[0] = static_cast<float>(opts.clearColor.r);
  out->clear_color[1] = static_cast<float>(opts.clearColor.g);
  out->clear_color[2] = static_cast<float>(opts.clearColor.b);
  out->clear_color[3] = static_cast<float>(opts.clearColor.a);
  out->clear_stencil = opts.clearStencil;
  out->clear = opts.clear;
  out->discard = opts.discard;
  FFI_CATCH()
}

void filament_renderer_set_clear_options(
    void* renderer, float r, float g, float b, float a, bool clear, bool discard) {
  FFI_TRY
  if (!renderer) return;
  Renderer::ClearOptions options;
  options.clearColor = {r, g, b, a};
  options.clear = clear;
  options.discard = discard;
  toRenderer(renderer)->setClearOptions(options);
  FFI_CATCH()
}

// ==========================================
// Frame Lifecycle & Execution
// ==========================================

bool filament_renderer_begin_frame(void* renderer, void* swap_chain, uint64_t vsync_ns) {
  FFI_TRY
  if (!renderer || !swap_chain) return false;
  return toRenderer(renderer)->beginFrame(toSwapChain(swap_chain), vsync_ns);
  FFI_CATCH(false)
}

void filament_renderer_render(void* renderer, void* view) {
  FFI_TRY
  if (!renderer || !view) return;
  toRenderer(renderer)->render(toView(view));
  FFI_CATCH()
}

void filament_renderer_end_frame(void* renderer) {
  FFI_TRY
  if (!renderer) return;
  toRenderer(renderer)->endFrame();
  FFI_CATCH()
}

// ==========================================
// Display & Frame Rate Options
// ==========================================

void filament_renderer_set_display_info(void* renderer, float refresh_rate) {
  FFI_TRY
  if (!renderer) return;
  Renderer::DisplayInfo info;
  info.refreshRate = refresh_rate;
  toRenderer(renderer)->setDisplayInfo(info);
  FFI_CATCH()
}

void filament_renderer_set_frame_rate_options(void* renderer,
    float head_room_ratio, float scale_rate, uint8_t history, uint8_t interval) {
  FFI_TRY
  if (!renderer) return;
  Renderer::FrameRateOptions options;
  options.headRoomRatio = head_room_ratio;
  options.scaleRate = scale_rate;
  options.history = history;
  options.interval = interval;
  toRenderer(renderer)->setFrameRateOptions(options);
  FFI_CATCH()
}

// ==========================================
// Frame Info & History
// ==========================================

uint32_t filament_renderer_get_present_times(void* renderer, uint64_t* out, uint32_t capacity) {
#if defined(__EMSCRIPTEN__)
  (void) renderer;
  (void) out;
  (void) capacity;
  return 0;
#else
  if (!renderer || !out || capacity == 0) return 0;
  auto times = toRenderer(renderer)->getPresentTimes();
  uint32_t const count = std::min(static_cast<uint32_t>(times.size()), capacity);
  size_t const first = times.size() - count;
  for (uint32_t i = 0; i < count; i++) out[i] = times[first + i];
  return count;
#endif
}

uint32_t filament_renderer_get_frame_info_history(void* renderer,
    filament_frame_info_t* out, uint32_t capacity) {
  FFI_TRY
  if (!renderer || !out || capacity == 0) return 0;
  auto history = toRenderer(renderer)->getFrameInfoHistory(capacity);
  uint32_t count = std::min(static_cast<uint32_t>(history.size()), capacity);
  for (uint32_t i = 0; i < count; i++) {
    const auto& fi = history[i];
    out[i].frame_id = fi.frameId;
    out[i].gpu_frame_duration = fi.gpuFrameDuration;
    out[i].denoised_gpu_frame_duration = fi.denoisedGpuFrameDuration;
    out[i].begin_frame = fi.beginFrame;
    out[i].end_frame = fi.endFrame;
    out[i].backend_begin_frame = fi.backendBeginFrame;
    out[i].backend_end_frame = fi.backendEndFrame;
    out[i].gpu_frame_complete = fi.gpuFrameComplete;
    out[i].vsync = fi.vsync;
    out[i].display_present = fi.displayPresent;
    out[i].present_deadline = fi.presentDeadline;
    out[i].display_present_interval = fi.displayPresentInterval;
    out[i].composition_to_present_latency = fi.compositionToPresentLatency;
    out[i].expected_present_latency = fi.expectedPresentLatency;
    out[i].frame_schedule_time = fi.frameScheduleTime;
  }
  return count;
  FFI_CATCH(0)
}

uint32_t filament_renderer_get_max_frame_history_size(void* renderer) {
  FFI_TRY
  if (!renderer) return 0;
  return static_cast<uint32_t>(toRenderer(renderer)->getMaxFrameHistorySize());
  FFI_CATCH(0)
}

int64_t filament_frame_info_invalid_sentinel(void) {
  return Renderer::FrameInfo::INVALID;
}

int64_t filament_frame_info_pending_sentinel(void) {
  return Renderer::FrameInfo::PENDING;
}

// ==========================================
// Standalone View & Read Pixels
// ==========================================

struct ReadPixelsUserData {
  FilamentReadPixelsCallback callback;
  void* user_data;
};

void filament_renderer_render_standalone_view(void* renderer, void* view) {
  FFI_TRY
  if (!renderer || !view) return;
  toRenderer(renderer)->renderStandaloneView(toView(view));
  FFI_CATCH()
}

void filament_renderer_read_pixels(
    void *renderer, void *engine, uint32_t x, uint32_t y, uint32_t width,
    uint32_t height, uint8_t *out_buffer, FilamentReadPixelsCallback callback, void* user_data) {
  FFI_TRY
  if (!renderer || !out_buffer) return;

  ReadPixelsUserData* data = nullptr;
  auto pbCallback = [](void* buffer, size_t size, void* user) {
    if (user) {
      ReadPixelsUserData* d = static_cast<ReadPixelsUserData*>(user);
      if (d->callback) {
        d->callback(buffer, d->user_data);
      }
      delete d;
    }
  };

  if (callback) {
    data = new ReadPixelsUserData{callback, user_data};
  }

  backend::PixelBufferDescriptor buffer(
      out_buffer, width * height * 4,
      backend::PixelBufferDescriptor::PixelDataFormat::RGBA,
      backend::PixelBufferDescriptor::PixelDataType::UBYTE,
      callback ? pbCallback : nullptr,
      data);

  toRenderer(renderer)->readPixels(x, y, width, height, std::move(buffer));
  FFI_CATCH()
}

void filament_renderer_read_pixels_render_target(
    void* renderer, void* render_target, uint32_t x, uint32_t y, uint32_t width, uint32_t height,
    int pixel_format, int pixel_type, void* buffer, uint32_t buffer_size_bytes,
    FilamentReadPixelsCallback callback, void* user_data) {
  FFI_TRY
  if (!renderer || !render_target || !buffer) return;

  ReadPixelsUserData* data = nullptr;
  auto pbCallback = [](void* buf, size_t size, void* user) {
    if (user) {
      ReadPixelsUserData* d = static_cast<ReadPixelsUserData*>(user);
      if (d->callback) {
        d->callback(buf, d->user_data);
      }
      delete d;
    }
  };

  if (callback) {
    data = new ReadPixelsUserData{callback, user_data};
  }

  backend::PixelBufferDescriptor pbd(
      buffer, buffer_size_bytes,
      static_cast<backend::PixelBufferDescriptor::PixelDataFormat>(pixel_format),
      static_cast<backend::PixelBufferDescriptor::PixelDataType>(pixel_type),
      callback ? pbCallback : nullptr,
      data);

  toRenderer(renderer)->readPixels(toRenderTarget(render_target), x, y, width, height, std::move(pbd));
  FFI_CATCH()
}

// ==========================================
// Presentation Time, Frame Skipping & Material Time
// ==========================================

void filament_renderer_set_vsync_time(void* renderer, uint64_t steady_clock_ns) {
  FFI_TRY
  if (!renderer) return;
  toRenderer(renderer)->setVsyncTime(steady_clock_ns);
  FFI_CATCH()
}

void filament_renderer_set_presentation_time(void* renderer, int64_t monotonic_clock_ns) {
  FFI_TRY
  if (!renderer) return;
  toRenderer(renderer)->setPresentationTime(monotonic_clock_ns);
  FFI_CATCH()
}

void filament_renderer_set_desired_presentation_time(void* renderer, int64_t ns) {
  FFI_TRY
  if (!renderer) return;
  toRenderer(renderer)->setDesiredPresentationTime(ns);
  FFI_CATCH()
}

void filament_renderer_set_rendering_deadline(void* renderer, int64_t deadline_ns) {
  FFI_TRY
  if (!renderer) return;
  toRenderer(renderer)->setRenderingDeadline(deadline_ns);
  FFI_CATCH()
}

void filament_renderer_set_frame_schedule_time(void* renderer, uint64_t ns) {
  FFI_TRY
  if (!renderer) return;
  toRenderer(renderer)->setFrameScheduleTime(ns);
  FFI_CATCH()
}

void filament_renderer_skip_frame(void* renderer, uint64_t vsync_steady_clock_ns) {
  FFI_TRY
  if (!renderer) return;
  toRenderer(renderer)->skipFrame(vsync_steady_clock_ns);
  FFI_CATCH()
}

bool filament_renderer_should_render_frame(void* renderer) {
  FFI_TRY
  if (!renderer) return false;
  return toRenderer(renderer)->shouldRenderFrame();
  FFI_CATCH(false)
}

bool filament_renderer_has_gpu_fallen_behind(void* renderer) {
  FFI_TRY
  if (!renderer) return false;
  return toRenderer(renderer)->hasGpuFallenBehind();
  FFI_CATCH(false)
}

double filament_renderer_get_material_time(void* renderer) {
  FFI_TRY
  if (!renderer) return 0.0;
  return toRenderer(renderer)->getMaterialTime();
  FFI_CATCH(0.0)
}

void filament_renderer_set_material_time_epoch(void* renderer, int64_t epoch_steady_ns) {
  FFI_TRY
  if (!renderer) return;
  toRenderer(renderer)->setMaterialTimeEpoch(epoch_steady_ns);
  FFI_CATCH()
}

void filament_renderer_skip_next_frames(void* renderer, size_t frame_count) {
  FFI_TRY
  if (!renderer) return;
  toRenderer(renderer)->skipNextFrames(frame_count);
  FFI_CATCH()
}

size_t filament_renderer_get_frame_to_skip_count(void* renderer) {
  FFI_TRY
  if (!renderer) return 0;
  return toRenderer(renderer)->getFrameToSkipCount();
  FFI_CATCH(0)
}

void filament_renderer_pause_render_thread(void* renderer, uint64_t duration_ns) {
  FFI_TRY
  if (!renderer) return;
  toRenderer(renderer)->pauseRenderThread(duration_ns);
  FFI_CATCH()
}

}
