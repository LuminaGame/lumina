#include "utils_c.h"

#include <utils/Log.h>
#include <utils/Panic.h>

#include <mutex>
#include <string.h>

namespace {
    std::mutex g_panicMutex;
    char g_lastPanicMessage[1024] = {0};

    FilamentPanicHandler g_panicHandler = nullptr;
    void* g_panicUserData = nullptr;

    void customPanicHandler(void* user, utils::Panic const& panic) noexcept {
        const char* func = panic.getFunction();
        const char* file = panic.getFile();
        int line = 0; // Panic class doesn't expose line directly, we'll just pass 0
        const char* reason = panic.getReason();
        const char* what = panic.what();
        
        char fullMessage[1024];
        snprintf(fullMessage, sizeof(fullMessage), "%s: %s", what, reason);

        {
            std::lock_guard<std::mutex> lock(g_panicMutex);
            strncpy(g_lastPanicMessage, fullMessage, sizeof(g_lastPanicMessage) - 1);
            g_lastPanicMessage[sizeof(g_lastPanicMessage) - 1] = '\0';
        }

        if (g_panicHandler) {
            g_panicHandler(
                func ? strdup(func) : nullptr,
                file ? strdup(file) : nullptr,
                line,
                strdup(fullMessage),
                g_panicUserData
            );
        } else {
            // Default behavior if not handled
            fprintf(stderr, "Filament PANIC: %s\n", fullMessage);
            std::terminate();
        }
    }

    FilamentLogHandler g_logHandler = nullptr;
    void* g_logUserData = nullptr;

    void dispatchLog(int priority, const char* message) {
        if (g_logHandler) {
            g_logHandler(priority, strdup("Filament"), message ? strdup(message) : nullptr, g_logUserData);
        }
    }

    void logConsumerV(void*, const char* msg) { dispatchLog(2, msg); }
    void logConsumerD(void*, const char* msg) { dispatchLog(3, msg); }
    void logConsumerI(void*, const char* msg) { dispatchLog(4, msg); }
    void logConsumerW(void*, const char* msg) { dispatchLog(5, msg); }
    void logConsumerE(void*, const char* msg) { dispatchLog(6, msg); }
}

void filament_set_panic_handler(FilamentPanicHandler handler, void* user_data) {
    g_panicHandler = handler;
    g_panicUserData = user_data;
    utils::Panic::setPanicHandler(customPanicHandler, nullptr);
}

void filament_clear_panic_handler(void) {
    g_panicHandler = nullptr;
    g_panicUserData = nullptr;
    // We can't clear utils::Panic::setPanicHandler easily if it expects non-null, but we can set it to default.
    // Actually, setting it to our custom one that calls std::terminate is safe if handler is null.
}

bool filament_get_last_panic(char* out_message, size_t max_len) {
    std::lock_guard<std::mutex> lock(g_panicMutex);
    if (g_lastPanicMessage[0] != '\0') {
        strncpy(out_message, g_lastPanicMessage, max_len - 1);
        out_message[max_len - 1] = '\0';
        // Clear it after reading
        g_lastPanicMessage[0] = '\0';
        return true;
    }
    return false;
}

void filament_set_log_callback(FilamentLogHandler handler, void* user_data) {
    g_logHandler = handler;
    g_logUserData = user_data;
    utils::slog.v.setConsumer(logConsumerV, nullptr);
    utils::slog.d.setConsumer(logConsumerD, nullptr);
    utils::slog.i.setConsumer(logConsumerI, nullptr);
    utils::slog.w.setConsumer(logConsumerW, nullptr);
    utils::slog.e.setConsumer(logConsumerE, nullptr);
}

void filament_clear_log_callback(void) {
    g_logHandler = nullptr;
    g_logUserData = nullptr;
    utils::slog.v.setConsumer(nullptr, nullptr);
    utils::slog.d.setConsumer(nullptr, nullptr);
    utils::slog.i.setConsumer(nullptr, nullptr);
    utils::slog.w.setConsumer(nullptr, nullptr);
    utils::slog.e.setConsumer(nullptr, nullptr);
}

void filament_test_trigger_panic(void) {
    try {
        PANIC_PRECONDITION("Test panic message");
    } catch (...) {
        // Prevent the panic exception from crashing the Dart isolate during tests.
    }
}

void filament_test_log(const char* msg) {
    utils::slog.w << msg << utils::io::endl;
}

void filament_free_string(char* str) {
    if (str) {
        free((void*)str);
    }
}

#include <utils/NameComponentManager.h>
#include <utils/EntityManager.h>

#define FFI_TRY try {
#define FFI_CATCH(return_value) \
} catch (const utils::Panic& e) { \
    fprintf(stderr, "[Utils C++ Panic (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (const std::exception& e) { \
    fprintf(stderr, "[Utils C++ Exception (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (...) { \
    fprintf(stderr, "[Utils C++ Unknown Exception (Handled Safely)]\n"); \
    return return_value; \
}

static inline utils::NameComponentManager* toNcm(void* p) {
    return reinterpret_cast<utils::NameComponentManager*>(p);
}

void* filament_name_component_manager_create(void) {
    FFI_TRY
    return new utils::NameComponentManager(utils::EntityManager::get());
    FFI_CATCH(nullptr)
}

void filament_name_component_manager_destroy(void* ncm) {
    FFI_TRY
    if (ncm) {
        delete toNcm(ncm);
    }
    FFI_CATCH()
}

void filament_name_component_manager_add_component(void* ncm, uint32_t entity) {
    FFI_TRY
    if (!ncm || entity == 0) return;
    toNcm(ncm)->addComponent(utils::Entity::import(entity));
    FFI_CATCH()
}

void filament_name_component_manager_remove_component(void* ncm, uint32_t entity) {
    FFI_TRY
    if (!ncm || entity == 0) return;
    toNcm(ncm)->removeComponent(utils::Entity::import(entity));
    FFI_CATCH()
}

int32_t filament_name_component_manager_get_instance(void* ncm, uint32_t entity) {
    FFI_TRY
    if (!ncm || entity == 0) return 0;
    return static_cast<int32_t>(toNcm(ncm)->getInstance(utils::Entity::import(entity)).asValue());
    FFI_CATCH(0)
}

void filament_name_component_manager_set_name(void* ncm, uint32_t entity, const char* name) {
    FFI_TRY
    if (!ncm || entity == 0 || !name) return;
    auto* mgr = toNcm(ncm);
    auto instance = mgr->getInstance(utils::Entity::import(entity));
    if (instance) {
        mgr->setName(instance, name);
    }
    FFI_CATCH()
}

const char* filament_name_component_manager_get_name(void* ncm, uint32_t entity) {
    FFI_TRY
    if (!ncm || entity == 0) return nullptr;
    auto* mgr = toNcm(ncm);
    auto instance = mgr->getInstance(utils::Entity::import(entity));
    if (instance) {
        return mgr->getName(instance);
    }
    return nullptr;
    FFI_CATCH(nullptr)
}

void filament_name_component_manager_gc(void* ncm) {
    FFI_TRY
    if (ncm) {
        utils::EntityManager::get().advanceEpoch();
        toNcm(ncm)->gc();
    }
    FFI_CATCH()
}

class DartEntityDestructionListener : public utils::EntityManager::Listener {
public:
    DartEntityDestructionListener(FilamentEntityDestructionCallback cb, void* user_data)
        : mCallback(cb), mUserData(user_data) {}

    void onEntitiesDestroyed(size_t n, utils::Entity const* entities) noexcept override {
        if (!mCallback || n == 0 || !entities) return;
        uint32_t* buf = static_cast<uint32_t*>(malloc(n * sizeof(uint32_t)));
        if (!buf) return;
        for (size_t i = 0; i < n; ++i) {
            buf[i] = entities[i].getId();
        }
        mCallback(buf, n, mUserData);
    }

private:
    FilamentEntityDestructionCallback mCallback;
    void* mUserData;
};

void* filament_entity_manager_register_destruction_callback(FilamentEntityDestructionCallback callback, void* user_data) {
    FFI_TRY
    if (!callback) return nullptr;
    auto* listener = new DartEntityDestructionListener(callback, user_data);
    utils::EntityManager::get().registerListener(listener);
    return listener;
    FFI_CATCH(nullptr)
}

void filament_entity_manager_unregister_destruction_callback(void* registration) {
    FFI_TRY
    if (!registration) return;
    auto* listener = reinterpret_cast<DartEntityDestructionListener*>(registration);
    utils::EntityManager::get().unregisterListener(listener);
    delete listener;
    FFI_CATCH()
}
