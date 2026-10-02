/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// Desktop only: filamat (the runtime material compiler) is not in Filament's WebAssembly build. Web builds get
// src/web_stubs_c.cpp (tool/web/gen_web_stubs.mjs).
#ifndef __EMSCRIPTEN__

#include "matc_c.h"

#include "log_tap.h"

// Filament's .mat parser, vendored unmodified under third_party/filament_matp (see its README).
#include <filament-matp/Config.h>
#include <filament-matp/MaterialParser.h>
#include "DirIncluder.h"
#include "Includes.h"

#include <filamat/MaterialBuilder.h>
#include <filamat/Package.h>
#include <utils/CString.h>
#include <utils/JobSystem.h>
#include <utils/Panic.h>
#include <utils/Path.h>

#include <cstdlib>
#include <cstring>
#include <exception>
#include <iostream>
#include <memory>
#include <mutex>
#include <streambuf>
#include <string>
#include <string_view>

namespace {

// matp reads its options from a matp::Config, which matc fills from its command line.
class WrapperConfig final : public matp::Config {
public:
    WrapperConfig(int platform, int targetApi, int optimization, bool debug, uint32_t variantFilter) {
        if (platform >= 0) mPlatform = static_cast<Platform>(platform);
        if (targetApi > 0) mTargetApi = static_cast<TargetApi>(targetApi);
        if (optimization >= 0) mOptimizationLevel = static_cast<Optimization>(optimization);
        mDebug = debug;
        mVariantFilter = static_cast<filament::UserVariantFilterMask>(variantFilter);
    }

    Output* getOutput() const noexcept override { return nullptr; }
    Input* getInput() const noexcept override { return nullptr; }
    std::string toString() const noexcept override { return "flutter_filament filament_matc_compile"; }
    std::string toPIISafeString() const noexcept override { return toString(); }
};

// Everything matc would print for one compile, in the order it was printed.
class DiagnosticsCapture {
public:
    void append(const char* text, size_t length) {
        std::lock_guard<std::mutex> lock(mMutex);
        mText.append(text, length);
    }
    void append(const char* text) { append(text, std::strlen(text)); }
    void appendLine(std::string_view text) {
        std::lock_guard<std::mutex> lock(mMutex);
        if (!mText.empty() && mText.back() != '\n') mText.push_back('\n');
        mText.append(text);
        if (mText.empty() || mText.back() != '\n') mText.push_back('\n');
    }
    // matp prints a failing key's status to std::cerr before returning it; matc then prints it again.
    void appendLineOnce(std::string_view text) {
        {
            std::lock_guard<std::mutex> lock(mMutex);
            if (mText.find(text) != std::string::npos) return;
        }
        appendLine(text);
    }
    std::string text() {
        std::lock_guard<std::mutex> lock(mMutex);
        return mText;
    }

private:
    std::mutex mMutex;
    std::string mText;
};

// std::cerr, while a compile runs: matp reports unknown keys and the key that failed there.
class CaptureStreambuf final : public std::streambuf {
public:
    explicit CaptureStreambuf(DiagnosticsCapture& capture) : mCapture(capture) {}

protected:
    int_type overflow(int_type ch) override {
        if (ch != traits_type::eof()) {
            const char c = static_cast<char>(ch);
            mCapture.append(&c, 1);
        }
        return traits_type::not_eof(ch);
    }
    std::streamsize xsputn(const char* s, std::streamsize n) override {
        mCapture.append(s, static_cast<size_t>(n));
        return n;
    }

private:
    DiagnosticsCapture& mCapture;
};

// utils::slog, while a compile runs: filamat reports GLSL and validation errors there.
void captureLog(void* user, int priority, const char* message) {
    if (priority < 5 || message == nullptr) return;  // warnings and errors
    static_cast<DiagnosticsCapture*>(user)->append(message);
}

std::mutex gCompileMutex;

char* copyString(const std::string& text) {
    char* out = static_cast<char*>(std::malloc(text.size() + 1));
    if (out) std::memcpy(out, text.c_str(), text.size() + 1);
    return out;
}

// matc's MaterialCompiler::run for an in-memory source (tools/matc/src/matc/MaterialCompiler.cpp).
void* compile(const char* source, size_t length, const char* fileName, const char* includeDir,
        const char* defaultName, const WrapperConfig& config, DiagnosticsCapture& capture, size_t& outSize) {
    if (source == nullptr || length == 0) {
        capture.appendLine("Input file is empty");
        return nullptr;
    }

    // #include resolution, with matc's #line directives around every included file.
    matp::IncludeResult root{
        .includeName = utils::CString(fileName ? fileName : ""),
        .text = utils::CString(source, length),
        .name = utils::CString(""),
    };
    const matp::ResolveOptions options{
        .insertLineDirectives = config.getInsertLineDirectives(),
        .insertLineDirectiveCheck = config.getInsertLineDirectiveChecks(),
    };
    matp::IncludeCallback includer;
    if (includeDir != nullptr && includeDir[0] != '\0' && utils::Path(includeDir).isDirectory()) {
        matp::DirIncluder dirIncluder;
        dirIncluder.setIncludeDirectory(utils::Path(includeDir));
        includer = dirIncluder;
    } else {
        // No folder to look in: every #include is a file that could not be found.
        includer = [](const utils::CString&, matp::IncludeResult&) { return false; };
    }
    if (utils::Status const resolved = matp::resolveIncludesRecursively(root, includer, options); !resolved.isOk()) {
        capture.appendLine(resolved.getMessage());
        return nullptr;
    }

    ssize_t size = static_cast<ssize_t>(root.text.size());
    std::unique_ptr<const char[]> buffer;
    {
        auto copy = std::make_unique<char[]>(size);
        std::memcpy(copy.get(), root.text.c_str(), size);
        buffer = std::move(copy);
    }

    matp::MaterialParser parser;
    if (utils::Status const substituted = parser.processTemplateSubstitutions(config, size, buffer);
            !substituted.isOk()) {
        capture.appendLine(substituted.getMessage());
        return nullptr;
    }

    filamat::MaterialBuilder::init();
    struct Shutdown {
        ~Shutdown() { filamat::MaterialBuilder::shutdown(); }
    } shutdown;

    filamat::MaterialBuilder builder;
    // The header's `name` (processed by parse) replaces this.
    if (defaultName != nullptr && defaultName[0] != '\0') builder.name(defaultName);

    if (utils::Status const status = parser.parse(builder, config, size, buffer); !status.isOk()) {
        capture.appendLineOnce(status.getMessage());
        return nullptr;
    }

    builder.compilationParameters(config.toPIISafeString().c_str());

    utils::JobSystem js;
    js.adopt();
    filamat::Package const package = builder.build(js);
    js.emancipate();

    if (!package.isValid()) {
        // matc names the input file here.
        const char* const name = fileName ? fileName : (defaultName ? defaultName : "");
        capture.appendLine(std::string("Could not compile material ") + name);
        return nullptr;
    }

    outSize = package.getSize();
    void* bytes = std::malloc(outSize);
    if (bytes) std::memcpy(bytes, package.getData(), outSize);
    return bytes;
}

} // namespace

void* filament_matc_compile(const char* source, size_t length, const char* file_name, const char* include_dir,
        const char* default_name, int platform, int target_api, int optimization, bool debug,
        uint32_t variant_filter, size_t* out_size, char** out_diagnostics) {
    if (out_size) *out_size = 0;
    if (out_diagnostics) *out_diagnostics = nullptr;

    // One compile at a time: the diagnostics capture swaps process-wide streams.
    std::lock_guard<std::mutex> lock(gCompileMutex);
    DiagnosticsCapture capture;
    CaptureStreambuf cerrCapture(capture);
    std::streambuf* const previousCerr = std::cerr.rdbuf(&cerrCapture);
    flutter_filament::setLogTap(captureLog, &capture);

    const WrapperConfig config(platform, target_api, optimization, debug, variant_filter);
    void* package = nullptr;
    size_t size = 0;
    try {
        package = compile(source, length, file_name, include_dir, default_name, config, capture, size);
    } catch (const utils::Panic& e) {
        capture.appendLine(e.what());
    } catch (const std::exception& e) {
        capture.appendLine(e.what());
    } catch (...) {
        capture.appendLine("matc: unknown exception");
    }

    flutter_filament::setLogTap(nullptr, nullptr);
    std::cerr.flush();
    std::cerr.rdbuf(previousCerr);

    if (package && out_size) *out_size = size;
    if (out_diagnostics) *out_diagnostics = copyString(capture.text());
    return package;
}

void filament_matc_free(void* pointer) {
    std::free(pointer);
}

#endif  // __EMSCRIPTEN__
