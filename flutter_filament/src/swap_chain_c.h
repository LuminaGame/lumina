/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_SWAP_CHAIN_C_H
#define FLUTTER_FILAMENT_SWAP_CHAIN_C_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifndef FFI_PLUGIN_EXPORT
#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*FilamentSwapChainCallback)(void* swap_chain, void* user_data);

// Capability queries (Engine&)
FFI_PLUGIN_EXPORT bool filament_swap_chain_is_srgb_supported(void* engine);
FFI_PLUGIN_EXPORT bool filament_swap_chain_is_msaa_supported(void* engine, uint32_t samples);
FFI_PLUGIN_EXPORT bool filament_swap_chain_is_protected_content_supported(void* engine);

// Config flag values (truth source from SwapChain.h)
FFI_PLUGIN_EXPORT uint64_t filament_swap_chain_config_value(int which);

// Instance methods
FFI_PLUGIN_EXPORT void filament_swap_chain_set_frame_rate(
    void* swap_chain, float frame_rate, int compatibility, int change_strategy);
FFI_PLUGIN_EXPORT int filament_swap_chain_is_frame_rate_change_supported(void* swap_chain);
FFI_PLUGIN_EXPORT void* filament_swap_chain_get_native_window(void* swap_chain);
FFI_PLUGIN_EXPORT bool filament_swap_chain_is_frame_scheduled_callback_set(void* swap_chain);

// Frame callbacks
FFI_PLUGIN_EXPORT void filament_swap_chain_set_frame_scheduled_callback(
    void* swap_chain, FilamentSwapChainCallback callback, void* user_data, uint64_t flags);
FFI_PLUGIN_EXPORT void filament_swap_chain_set_frame_completed_callback(
    void* swap_chain, FilamentSwapChainCallback callback, void* user_data);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_SWAP_CHAIN_C_H
