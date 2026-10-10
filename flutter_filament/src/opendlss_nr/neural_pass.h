/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// The OpenDLSS-NR network as Filament's external post pass (View::setExternalPostPass): per frame, the input
// features from the HDR frame and the reprojected history, the vendored network graph, and the composite back onto
// the HDR frame, all recorded into Filament's command buffer. Any failure turns the pass off with a reason (the
// view then renders without it); nothing here throws out of evaluate().
#pragma once

#include "opendlss_nr/opendlss_nr_config.h"

#if FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED

#include <atomic>
#include <memory>
#include <mutex>
#include <string>

#include <filament/Engine.h>
#include <filament/View.h>
#include <backend/ExternalPass.h>

#include "opendlss_nr/vk_context.h"

namespace nr {
class Model;
class Kernels;
class Graph;
struct Activation;
}  // namespace nr

namespace opendlss_nr {

// Weights loaded on the engine's device (shared by every pass of that engine).
struct LoadedModel {
  filament::Engine* engine = nullptr;
  std::unique_ptr<vk::Context> context;
  std::unique_ptr<nr::Model> model;
  float blendScale = 0.0f;
  std::atomic<int> passes{0};
  ~LoadedModel();
};

// Loads `directory` (checked by checkModel first) on `engine`'s Vulkan device. Safe on any thread: it reads files,
// re-lays the weights out and creates device buffers whose uploads wait for the first frame.
LoadedModel* loadModel(filament::Engine* engine, const std::string& directory, std::string& error);

struct Controls {
  bool enabled = true;          // false: the frame passes through (the history stays primed)
  float intensity = 1.0f;       // 0..1, blend back towards the frame
  float localTone = 1.0f;       // conditioning: local tone
  float localStructure = 1.0f;  // conditioning: structure
  float skinStructure = -1.0f;  // conditioning: skin structure (-1 follows structure)
  bool autoMask = true;         // conditioning: automatic mask
  uint32_t style = 0;           // 0 none, 1 natural, 2 cinematic (the style id the network sees)
  float paperWhite = 1.0f;      // scene value displayed as paper white
  float colorStrength = 1.0f;   // 0 keeps the frame's colours (luminance only), 1 the network's
};

struct Status {
  uint64_t frames = 0;
  uint32_t width = 0, height = 0;
  bool failed = false;
  double gpuMs = 0.0;          // the last measured frame (features + network + composite)
  double gpuMsAverage = 0.0;   // exponential average
  uint32_t dispatches = 0;
  uint64_t deviceBytes = 0;
};

class NeuralPass final : public filament::ExternalPostPass {
 public:
  NeuralPass(filament::Engine* engine, filament::View* view, LoadedModel* model);
  ~NeuralPass();

  bool supports(uint32_t width, uint32_t height) noexcept override;
  void evaluate(filament::backend::ExternalPassContext const& context) noexcept override;

  void setControls(const Controls& controls);
  Status status() const;
  std::string failure() const;
  filament::Engine* engine() const { return engine_; }
  filament::View* view() const { return view_; }
  LoadedModel* model() const { return model_; }
  // The GPU is idle (the caller waited on the engine): free every Vulkan object of the pass.
  void destroyObjects();

 private:
  void fail(const std::string& reason) noexcept;
  void ensureFrameObjects();
  void ensureGraph(uint32_t width, uint32_t height, VkCommandBuffer commands);
  void releaseSized();
  void record(filament::backend::ExternalPassContext const& context, VkCommandBuffer commands);
  void recordComposite(VkCommandBuffer commands, filament::backend::ExternalPassContext const& context, bool network);
  void readTimestamps();

  filament::Engine* const engine_;
  filament::View* const view_;
  LoadedModel* const model_;
  vk::Context& vk_;
  VkDevice device_;

  mutable std::mutex mutex_;
  Controls controls_;
  std::string failure_;
  std::atomic<bool> failed_{false};
  std::atomic<uint64_t> frames_{0};
  std::atomic<uint32_t> width_{0}, height_{0};
  std::atomic<uint32_t> dispatches_{0};
  double gpuMs_ = 0.0, gpuMsAverage_ = 0.0;

  std::unique_ptr<nr::Kernels> kernels_;
  std::unique_ptr<nr::Graph> graph_;
  nr::Activation* features_ = nullptr;
  uint32_t fullWidth_ = 0, fullHeight_ = 0;
  vk::Image history_[2];
  bool historyPrimed_ = false;
  uint64_t frame_ = 0;

  VkSampler linear_ = VK_NULL_HANDLE, nearest_ = VK_NULL_HANDLE;
  VkDescriptorSetLayout frameSetLayout_ = VK_NULL_HANDLE;
  VkPipelineLayout frameLayout_ = VK_NULL_HANDLE;
  VkDescriptorPool framePool_ = VK_NULL_HANDLE;
  static constexpr uint32_t kRing = 16;
  VkDescriptorSet featureSets_[kRing] = {}, compositeSets_[kRing] = {};
  vk::Pipeline featuresPipeline_, compositePipeline_;
  VkQueryPool queries_ = VK_NULL_HANDLE;
};

}  // namespace opendlss_nr

#endif  // FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED
