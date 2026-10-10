/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "opendlss_nr/opendlss_nr_config.h"

#if FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED

#include "opendlss_nr/model_check.h"

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <map>
#include <random>
#include <set>
#include <sstream>

#include "json.h"
#include "nr_graph.h"
#include "sha256.h"

namespace fs = std::filesystem;

namespace opendlss_nr {

namespace {

constexpr uint64_t kMaxManifestBytes = 16ull << 20;
constexpr int kMaxManifestDepth = 32;
constexpr uint32_t kStageCount = 11;   // the stage files a synthetic model is split into

fs::path utf8Path(const std::string& path) {
  return fs::path(std::u8string(reinterpret_cast<const char8_t*>(path.data()), path.size()));
}

// The JSON reader is recursive: refuse a manifest nested deeper than any real one before parsing it.
bool shallowEnough(const std::string& text) {
  int depth = 0;
  bool inString = false, escaped = false;
  for (char c : text) {
    if (inString) {
      if (escaped) escaped = false;
      else if (c == '\\') escaped = true;
      else if (c == '"') inString = false;
      continue;
    }
    if (c == '"') inString = true;
    else if (c == '[' || c == '{') {
      if (++depth > kMaxManifestDepth) return false;
    } else if (c == ']' || c == '}') {
      --depth;
    }
  }
  return true;
}

bool safeFileName(const std::string& name) {
  if (name.empty() || name.size() > 255) return false;
  if (name.find("..") != std::string::npos) return false;
  for (char c : name) {
    if (c == '/' || c == '\\' || c == ':' || static_cast<unsigned char>(c) < 0x20) return false;
  }
  return true;
}

std::string upper(std::string s) {
  for (char& c : s) c = (char)std::toupper((unsigned char)c);
  return s;
}

const json::Value* member(const json::Value& object, const char* key) {
  if (object.kind != json::Value::Object || !object.has(key)) return nullptr;
  return &object[key];
}

bool readInteger(const json::Value& object, const char* key, int64_t& out) {
  const json::Value* v = member(object, key);
  if (!v || v->kind != json::Value::Number || v->number < 0 || v->number > 4.0e9 || v->number != (double)(int64_t)v->number)
    return false;
  out = v->integer();
  return true;
}

bool readString(const json::Value& object, const char* key, std::string& out) {
  const json::Value* v = member(object, key);
  if (!v || v->kind != json::Value::String) return false;
  out = v->str();
  return true;
}

ModelCheck fail(int32_t code, std::string message) {
  ModelCheck check;
  check.code = code;
  check.message = std::move(message);
  return check;
}

uint32_t windowChannels(int block) {
  if (block <= 4 || block >= 66) return 32;
  if (block <= 8 || block >= 62) return 64;
  if (block <= 14 || block >= 56) return 128;
  return 256;   // 15-22 and 48-55
}

}  // namespace

std::string TensorRequirement::name() const {
  return "block" + std::to_string(block) + ".layer" + std::to_string(layer) + "." + parameter;
}

const std::vector<TensorRequirement>& requiredTensors() {
  static const std::vector<TensorRequirement> list = [] {
    std::vector<TensorRequirement> t;
    auto add = [&](int block, int layer, uint32_t bytes, bool exact, const char* parameter = "layer") {
      TensorRequirement r;
      r.block = block;
      r.layer = layer;
      r.bytes = bytes;
      r.exact = exact;
      r.parameter = parameter;
      t.push_back(r);
    };
    // The window blocks: one record each, the layout ends in 16 bytes of padding or, on the last block of an
    // encoder stage, the C -> 2C input projection of the next stage (docs/weights.md upstream).
    add(0, 0, nr::preFusedLayout().endWithoutPadding + 16, true);
    for (int block = 1; block <= 22; ++block) {
      const uint32_t c = windowChannels(block);
      const bool lastOfStage = block == 4 || block == 8 || block == 14 || block == 22;
      add(block, 0, nr::fusedLayout(c).endWithoutPadding + (lastOfStage ? 2 * c * c : 16), true);
    }
    // The 512 split blocks: branch MLPs, contraction + skip scale, qkv + priors + head scales, projection + scale.
    auto split = [&](int block) {
      add(block, 0, 512 * 512 + 8 * 64 * 256 + 8 * 256 * 64, false);
      add(block, 1, 512 * 512 + 512 * 2, false);
      add(block, 2, 512 * 512 * 3 + 16 * 8192 + 16 * 4, false);
      add(block, 3, 512 * 512 + 512 * 2, false);
    };
    for (int block = 23; block <= 30; ++block) split(block);
    add(30, 4, 512 * 1024, false);   // the 512 -> 1024 matrix into the ViT
    for (int block = 31; block <= 38; ++block) {
      add(block, 0, 1024 * 4096, false);
      add(block, 1, 4096 * 1024 + 1024 * 2, false);
      add(block, 2, 32 * 4 + 1024 * 3072, false);   // head scales first, then qkv
      add(block, 3, 0, false);                      // two unread bytes
      add(block, 4, 1024 * 1024 + 1024 * 2, false);
    }
    add(39, 0, 1024 * 512 + 512 * 2, false);   // 1024 -> 512 out of the ViT + skip scale
    for (int block = 40; block <= 47; ++block) split(block);
    for (int block = 48; block <= 69; ++block) {
      const uint32_t c = windowChannels(block);
      const bool firstOfStage = block == 48 || block == 56 || block == 62 || block == 66;
      add(block, 0, (firstOfStage ? nr::upsampleFusedLayout(2 * c, c) : nr::fusedLayout(c)).endWithoutPadding + 16, true);
    }
    add(70, 0, nr::postFusedLayout().endWithoutPadding, true);
    add(70, 0, 2, false, "blend_scale");
    return t;
  }();
  return list;
}

ModelCheck checkModel(const std::string& directory, bool verifyHashes) {
  try {
    const fs::path root = utf8Path(directory);
    std::error_code ec;
    if (directory.empty() || !fs::is_directory(root, ec)) return fail(kModelMissing, "no weights folder at '" + directory + "'");
    const fs::path manifestPath = root / "manifest.json";
    if (!fs::is_regular_file(manifestPath, ec)) return fail(kModelMissing, "no manifest.json in '" + directory + "'");
    const uint64_t manifestBytes = fs::file_size(manifestPath, ec);
    if (ec || manifestBytes == 0 || manifestBytes > kMaxManifestBytes)
      return fail(kModelInvalidManifest, "manifest.json is empty or larger than 16 MB");
    std::ifstream in(manifestPath, std::ios::binary);
    std::stringstream stream;
    stream << in.rdbuf();
    const std::string text = stream.str();
    if (!shallowEnough(text)) return fail(kModelInvalidManifest, "manifest.json is nested too deeply");
    json::Value manifest;
    try {
      manifest = json::parse(text);
    } catch (const std::exception& e) {
      return fail(kModelInvalidManifest, std::string("manifest.json is not valid JSON: ") + e.what());
    }
    if (manifest.kind != json::Value::Object) return fail(kModelInvalidManifest, "manifest.json is not an object");
    const json::Value* totals = member(manifest, "totals");
    int64_t blockCount = 0;
    if (!totals || !readInteger(*totals, "blockCount", blockCount))
      return fail(kModelInvalidManifest, "manifest.json has no totals.blockCount");
    if (blockCount != nr::Graph::kBlockCount)
      return fail(kModelInvalidManifest, "the model has " + std::to_string(blockCount) + " blocks; the network has " +
                                             std::to_string(nr::Graph::kBlockCount));
    const json::Value* stages = member(manifest, "stages");
    const json::Value* tensors = member(manifest, "tensors");
    if (!stages || stages->kind != json::Value::Array || stages->array.empty() || stages->array.size() > 256)
      return fail(kModelInvalidManifest, "manifest.json has no stages array");
    if (!tensors || tensors->kind != json::Value::Array || tensors->array.empty() || tensors->array.size() > 4096)
      return fail(kModelInvalidManifest, "manifest.json has no tensors array");

    ModelCheck check;
    check.blockCount = (uint32_t)blockCount;
    std::map<std::string, uint64_t> stageSizes;
    for (const json::Value& stage : stages->array) {
      std::string id, file, hash;
      int64_t length = 0;
      if (!readString(stage, "id", id) || !readString(stage, "file", file) || !readInteger(stage, "packedByteLength", length))
        return fail(kModelInvalidManifest, "a stage record lacks id, file or packedByteLength");
      if (!safeFileName(file)) return fail(kModelStageMismatch, "stage " + id + " has an unsafe file name '" + file + "'");
      if (stageSizes.count(id)) return fail(kModelInvalidManifest, "stage " + id + " is listed twice");
      const fs::path stagePath = root / "model" / utf8Path(file);
      if (!fs::is_regular_file(stagePath, ec)) return fail(kModelStageMismatch, "stage " + id + ": model/" + file + " is missing");
      const uint64_t size = fs::file_size(stagePath, ec);
      if (ec || size != (uint64_t)length)
        return fail(kModelStageMismatch, "stage " + id + ": model/" + file + " is " + std::to_string(size) +
                                             " bytes, the manifest says " + std::to_string(length));
      if (verifyHashes) {
        if (!readString(stage, "sha256", hash)) return fail(kModelHashMismatch, "stage " + id + " has no sha256");
        std::ifstream bin(stagePath, std::ios::binary);
        std::vector<uint8_t> bytes((size_t)size);
        if (size && !bin.read(reinterpret_cast<char*>(bytes.data()), (std::streamsize)size))
          return fail(kModelIoError, "cannot read model/" + file);
        if (upper(sha256Hex(bytes.data(), bytes.size())) != upper(hash))
          return fail(kModelHashMismatch, "stage " + id + ": model/" + file + " does not match its SHA-256");
      }
      stageSizes[id] = size;
      check.totalBytes += size;
    }
    check.stageCount = (uint32_t)stageSizes.size();

    std::map<std::string, uint64_t> lengths;
    for (const json::Value& tensor : tensors->array) {
      std::string name, stage;
      int64_t offset = 0, length = 0;
      if (!readString(tensor, "name", name) || !readString(tensor, "stage", stage) ||
          !readInteger(tensor, "stageOffset", offset) || !readInteger(tensor, "byteLength", length))
        return fail(kModelInvalidManifest, "a tensor record lacks name, stage, stageOffset or byteLength");
      auto s = stageSizes.find(stage);
      if (s == stageSizes.end()) return fail(kModelLayoutMismatch, "tensor " + name + " names an unknown stage " + stage);
      if ((uint64_t)offset + (uint64_t)length > s->second)
        return fail(kModelLayoutMismatch, "tensor " + name + " runs past the end of stage " + stage);
      if (lengths.count(name)) return fail(kModelInvalidManifest, "tensor " + name + " is listed twice");
      lengths[name] = (uint64_t)length;
    }
    check.tensorCount = (uint32_t)lengths.size();
    for (const TensorRequirement& r : requiredTensors()) {
      auto it = lengths.find(r.name());
      if (it == lengths.end()) return fail(kModelLayoutMismatch, "tensor " + r.name() + " is missing");
      if (r.exact ? it->second != r.bytes : it->second < r.bytes)
        return fail(kModelLayoutMismatch, "tensor " + r.name() + " is " + std::to_string(it->second) + " bytes; the network reads " +
                                              (r.exact ? "exactly " : "at least ") + std::to_string(r.bytes));
    }
    check.code = kModelOk;
    check.message = "ok";
    return check;
  } catch (const std::exception& e) {
    return fail(kModelIoError, e.what());
  }
}

std::string writeSyntheticModel(const std::string& directory, uint32_t seed, int fill) {
  try {
    const fs::path root = utf8Path(directory);
    fs::create_directories(root / "model");
    const auto& tensors = requiredTensors();
    std::mt19937 random(seed);
    auto code = [&]() -> uint8_t {
      // A small E4M3 value (exponent 1..6, any mantissa, either sign): finite read as E4M3, f16 or f32.
      const uint32_t r = random();
      return (uint8_t)((r & 0x80) | ((1 + (r >> 8) % 6) << 3) | ((r >> 16) & 7));
    };
    std::string tensorJson, stageJson;
    for (uint32_t s = 0; s < kStageCount; ++s) {
      std::vector<uint8_t> bytes;
      const std::string id = "stage" + std::to_string(s);
      for (size_t i = 0; i < tensors.size(); ++i) {
        if (i * kStageCount / tensors.size() != s) continue;
        const TensorRequirement& r = tensors[i];
        const uint32_t length = std::max<uint32_t>(r.bytes, 2);
        const size_t offset = bytes.size();
        bytes.resize(offset + length, 0);
        if (fill == 1) {
          for (uint32_t b = 0; b < length; ++b) bytes[offset + b] = code();
        }
        if (!tensorJson.empty()) tensorJson += ",\n";
        tensorJson += "    {\"name\": \"" + r.name() + "\", \"block\": " + std::to_string(r.block) + ", \"layer\": " +
                      std::to_string(r.layer) + ", \"parameter\": \"" + r.parameter + "\", \"stage\": \"" + id +
                      "\", \"stageOffset\": " + std::to_string(offset) + ", \"byteLength\": " + std::to_string(length) + "}";
      }
      const std::string file = id + ".bin";
      std::ofstream out(root / "model" / file, std::ios::binary | std::ios::trunc);
      out.write(reinterpret_cast<const char*>(bytes.data()), (std::streamsize)bytes.size());
      if (!out) return "cannot write model/" + file;
      if (!stageJson.empty()) stageJson += ",\n";
      stageJson += "    {\"id\": \"" + id + "\", \"file\": \"" + file + "\", \"packedByteLength\": " +
                   std::to_string(bytes.size()) + ", \"sha256\": \"" + sha256Hex(bytes.data(), bytes.size()) + "\"}";
    }
    std::ofstream manifest(root / "manifest.json", std::ios::binary | std::ios::trunc);
    manifest << "{\n  \"synthetic\": true,\n  \"totals\": {\"blockCount\": " << nr::Graph::kBlockCount
             << "},\n  \"stages\": [\n" << stageJson << "\n  ],\n  \"tensors\": [\n" << tensorJson << "\n  ]\n}\n";
    if (!manifest) return "cannot write manifest.json";
    return std::string();
  } catch (const std::exception& e) {
    return e.what();
  }
}

}  // namespace opendlss_nr

#endif  // FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED
