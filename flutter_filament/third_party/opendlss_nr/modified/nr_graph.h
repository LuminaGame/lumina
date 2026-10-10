// The NR network graph: 71 blocks over a six-level encoder/decoder with a global
// ViT bottleneck, recorded into one Vulkan command buffer.
//
// Modified by Lumina from OpenDLSS-NR 9d08f41 src/nr_graph.h (MIT, see ../LICENSE): GLSL route only. Removed: the
// PTX routes and their counter chaining, the deferred projection (a PTX fusion), the parity capture options and
// the environment switches. The fused GLSL route (fused 32-channel blocks, fused QKV + attention, fused MLP and
// the pre / pool / upres / post fusions) is kept as the default; Options::fusedBlocks = false runs the reference
// kernels.
#pragma once
#include <map>
#include <memory>
#include <set>
#include <string>
#include <vector>

#include "kernels.h"
#include "nr_model.h"

namespace nr {

struct Geometry {
  uint32_t validWidth = 0, validHeight = 0;
  uint32_t fullWidth = 0, fullHeight = 0;
  struct Level { uint32_t width, height; } levels[6];
  static Geometry fromValid(uint32_t validWidth, uint32_t validHeight);
  uint32_t vitTokens() const { return levels[5].width * levels[5].height; }
  uint32_t paddedVitTokens() const { return (vitTokens() + 63) & ~63u; }
};

struct FusedLayout {
  uint32_t hidden = 128, heads = 1;
  uint32_t expand = 0, contractWeights = 0, inputAdapter = 0, ffnCosSkip = 0, qkv = 0, relative = 0, scale = 0,
           projection = 0, attnCosSkip = 0, endWithoutPadding = 0;
  uint32_t upsampleWeight = 0, transitionScale = 0, inputScale = 0, adapterScale = 0, postWeights = 0;
  bool expertFfn = false;
  uint32_t expertCount = 0;
};
FusedLayout fusedLayout(uint32_t channels, uint32_t base = 0);
FusedLayout preFusedLayout();
FusedLayout upsampleFusedLayout(uint32_t inputChannels, uint32_t channels);
FusedLayout postFusedLayout();

class Graph {
 public:
  static constexpr uint32_t kBlockCount = 71;   // blocks 0..70; the graph's stage boundaries are hard-coded

  struct Options {
    bool fusedBlocks = true;            // one fused dispatch per 32-channel block (false: reference kernels)
  };
  Graph(vk::Context& context, Model& model, Kernels& kernels, const Geometry& geometry, Options options);
  ~Graph();

  // Record the complete network. `inputFeatures` is f32 [fullWidth*fullHeight][16].
  void record(VkCommandBuffer commands, const Activation& inputFeatures);

  const Activation& head() const { return *head_; }  // f32 [full rows][4]
  const Geometry& geometry() const { return geometry_; }

  Activation* allocate(const std::string& label, uint32_t rows, uint32_t channels, Format format);

 private:
  // Window phases. Every resolution level runs its own four-phase cycle of half-window shifts; the phase advances
  // once per block at that level in visit order, and a decoder stage continues the count its encoder stage left.
  static constexpr int kFullLevel = 6;   // levels 0..5 are Geometry::levels, 6 is the un-pooled field
  uint32_t windowPhase_[7]{};
  uint32_t takeWindowPhase(int level) { return windowPhase_[level]++; }
  struct Temporaries {
    Activation* ffn = nullptr;           // E4 [rows][hidden or experts*128]
    Activation* ffnNarrow = nullptr;     // E4 [rows][channels] (expert W2 outputs)
    Activation* ffnResidual = nullptr;   // F16 [rows][channels]
    Activation* ffnQuantized = nullptr;  // E4 [rows][channels]
    Activation* qkv = nullptr;           // F16 [rows][3*channels]
    Activation* normalized = nullptr;    // E4 [rows][3*channels]
    Activation* attended = nullptr;      // E4 [rows][channels]
  };
  struct SplitTemporaries {
    Activation* branch = nullptr;   // E4 [rows][512]
    Activation* middle = nullptr;   // E4 [rows][2048]
    Activation* layer0 = nullptr;   // E4 [rows][512]
    Activation* ffnResidual = nullptr;  // E4 [rows][512]
    Activation* qkv = nullptr;      // F16 [rows][1536]
    Activation* normalized = nullptr;  // E4
    Activation* attended = nullptr;    // E4 [rows][512]
  };
  Temporaries createTemporaries(const std::string& label, uint32_t rows, uint32_t channels);
  SplitTemporaries createSplitTemporaries(const std::string& label, uint32_t rows);

  void encodeFusedBlock(VkCommandBuffer commands, Temporaries& temps, const Activation& state, Activation* output,
                        int block, uint32_t channels, uint32_t width, uint32_t height, uint32_t phase,
                        const FusedLayout& layout, const Tensor& tensor, const Activation* ffnSkipOverride,
                        Activation* rawOutput, Activation* pooledOutput = nullptr, uint32_t pooledWidth = 0);
  void encodeSplitBlock(VkCommandBuffer commands, SplitTemporaries& temps, const Activation& state,
                        Activation* output, int block, uint32_t width, uint32_t height, uint32_t phase,
                        Activation* rawOutput);
  void encodeVit(VkCommandBuffer commands, Activation& state, uint32_t tokens);
  // The fused GLSL route (the default) and the reference kernels.
  bool fused() const { return options_.fusedBlocks; }

  vk::Context& context_;
  Model& model_;
  Kernels& kernels_;
  Geometry geometry_;
  Options options_;
  std::vector<std::unique_ptr<Activation>> activations_;
  std::map<std::string, Activation*> allocationsByKey_;
  std::set<std::string> usedThisRecord_;
  Activation* head_ = nullptr;
  Activation* inputHalf_ = nullptr;
};

}  // namespace nr
