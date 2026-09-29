#pragma once
#include <ibl/Cubemap.h>
#include <ibl/Image.h>
#include <ibl/CubemapUtils.h>
#include <utils/JobSystem.h>
#include <functional>
#include <utility>

struct FilIblImage {
    filament::ibl::Image image;
    FilIblImage() = default;
    FilIblImage(size_t w, size_t h) : image(w, h) {}
};

struct FilIblCubemap {
    filament::ibl::Image backingImage;
    filament::ibl::Cubemap cubemap;
    size_t dim;
    FilIblCubemap(size_t dimension) : cubemap(dimension), dim(dimension) {
        cubemap = filament::ibl::CubemapUtils::create(backingImage, dimension);
    }
};

template<typename F>
inline auto withJobSystem(F&& f) -> decltype(f(std::declval<utils::JobSystem&>())) {
    utils::JobSystem js(0);
    js.adopt();
    auto res = f(js);
    js.emancipate();
    return res;
}

template<typename F>
inline void withJobSystemVoid(F&& f) {
    utils::JobSystem js(0);
    js.adopt();
    f(js);
    js.emancipate();
}
