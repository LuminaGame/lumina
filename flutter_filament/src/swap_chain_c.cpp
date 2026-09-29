/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "swap_chain_c.h"
#include <filament/Engine.h>
#include <filament/SwapChain.h>
#include <backend/Platform.h>
#include "utils_c.h"

using namespace filament;

#define FFI_TRY try {
#define FFI_CATCH(return_val) } catch (...) { return return_val; }
#define FFI_CATCH_VOID() } catch (...) { return; }

static inline Engine* toEngine(void* ptr) {
    return reinterpret_cast<Engine*>(ptr);
}

static inline SwapChain* toSwapChain(void* ptr) {
    return reinterpret_cast<SwapChain*>(ptr);
}

bool filament_swap_chain_is_srgb_supported(void* engine) {
    FFI_TRY
    if (!engine) return false;
    return SwapChain::isSRGBSwapChainSupported(*toEngine(engine));
    FFI_CATCH(false)
}

bool filament_swap_chain_is_msaa_supported(void* engine, uint32_t samples) {
    FFI_TRY
    if (!engine) return false;
    return SwapChain::isMSAASwapChainSupported(*toEngine(engine), samples);
    FFI_CATCH(false)
}

bool filament_swap_chain_is_protected_content_supported(void* engine) {
    FFI_TRY
    if (!engine) return false;
    return SwapChain::isProtectedContentSupported(*toEngine(engine));
    FFI_CATCH(false)
}

uint64_t filament_swap_chain_config_value(int which) {
    switch (which) {
        case 0: return SwapChain::CONFIG_TRANSPARENT;
        case 1: return SwapChain::CONFIG_READABLE;
        case 2: return SwapChain::CONFIG_ENABLE_XCB;
        case 3: return SwapChain::CONFIG_APPLE_CVPIXELBUFFER;
        case 4: return SwapChain::CONFIG_SRGB_COLORSPACE;
        case 5: return SwapChain::CONFIG_HAS_STENCIL_BUFFER;
        case 6: return SwapChain::CONFIG_PROTECTED_CONTENT;
        case 7: return SwapChain::CONFIG_MSAA_4_SAMPLES;
        default: return 0;
    }
}

void filament_swap_chain_set_frame_rate(
    void* swap_chain, float frame_rate, int compatibility, int change_strategy) {
    FFI_TRY
    if (!swap_chain) return;
    auto comp = static_cast<backend::Platform::FrameRateCompatibility>(compatibility);
    auto strat = static_cast<backend::Platform::ChangeFrameRateStrategy>(change_strategy);
    toSwapChain(swap_chain)->setFrameRate(frame_rate, comp, strat);
    FFI_CATCH_VOID()
}

int filament_swap_chain_is_frame_rate_change_supported(void* swap_chain) {
    FFI_TRY
    if (!swap_chain) return 2; // indeterminate
    auto tb = toSwapChain(swap_chain)->isFrameRateChangeSupported();
    if (tb.is_true()) return 1;
    if (tb.is_false()) return 0;
    return 2;
    FFI_CATCH(2)
}

void* filament_swap_chain_get_native_window(void* swap_chain) {
    FFI_TRY
    if (!swap_chain) return nullptr;
    return toSwapChain(swap_chain)->getNativeWindow();
    FFI_CATCH(nullptr)
}

bool filament_swap_chain_is_frame_scheduled_callback_set(void* swap_chain) {
    FFI_TRY
    if (!swap_chain) return false;
    return toSwapChain(swap_chain)->isFrameScheduledCallbackSet();
    FFI_CATCH(false)
}

void filament_swap_chain_set_frame_scheduled_callback(
    void* swap_chain, FilamentSwapChainCallback callback, void* user_data, uint64_t flags) {
    FFI_TRY
    if (!swap_chain) return;
    auto* sc = toSwapChain(swap_chain);
    if (!callback) {
        sc->setFrameScheduledCallback(nullptr, {}, flags);
    } else {
        sc->setFrameScheduledCallback(nullptr, [callback, user_data, sc](backend::PresentCallable presentCallable) {
            presentCallable();
            if (callback) {
                callback(sc, user_data);
            }
        }, flags);
    }
    FFI_CATCH_VOID()
}

void filament_swap_chain_set_frame_completed_callback(
    void* swap_chain, FilamentSwapChainCallback callback, void* user_data) {
    FFI_TRY
    if (!swap_chain) return;
    auto* sc = toSwapChain(swap_chain);
    if (!callback) {
        sc->setFrameCompletedCallback(nullptr, {});
    } else {
        sc->setFrameCompletedCallback(nullptr, [callback, user_data](SwapChain* s) {
            callback(s, user_data);
        });
    }
    FFI_CATCH_VOID()
}
