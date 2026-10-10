[Türkçe](../../tr/flutter_filament/opendlss-nr.md)

# OpenDLSS-NR (experimental, third-party)

[OpenDLSS-NR](https://github.com/maanHimself/OpenDLSS-NR) is a third-party, unofficial re-implementation of NVIDIA's DLSS 5 neural rendering network (a generative pass that re-renders the finished frame). flutter_filament can run it as an [external post pass](external-post-pass.md) on the HDR frame, **only on model weights the user supplies**. Lumina does not provide the weights, does not download, extract or convert them, and does not describe how to obtain them; NVIDIA's model weights may not be redistributed, and obtaining or using them may violate NVIDIA's licence terms. The upstream project page documents its own requirements. Neither OpenDLSS-NR nor Lumina is affiliated with NVIDIA; "DLSS" is NVIDIA's trademark and names the upstream project only. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [What runs](#what-runs)
- [Requirements and capability](#requirements-and-capability)
- [The model folder](#the-model-folder)
- [Dart API](#dart-api)
- [Native C bridge](#native-c-bridge)
- [Measurements](#measurements)
- [Limits and risks](#limits-and-risks)

## What runs

Per frame, inside Filament's command buffer (patch `0011`'s `View::setExternalPostPass`), after TAA / FSR3 and before depth of field, bloom and colour grading:

1. `src/opendlss_nr/shaders/nr_features.comp`: 16 input lanes per pixel of the padded field: Gaussian noise, the display proxy of the HDR colour (paper-white relative, soft shoulder, sRGB code values), the previous output reprojected with the hook's motion (five-tap Catmull-Rom, only where the history flag is set and no reset happened), and the conditioning scalars (style id, tone, structure, skin, auto mask).
2. The vendored network (`third_party/opendlss_nr`, the upstream GLSL cooperative-matrix route: FP8 E4M3 activations, a 71-block Swin / ViT U-net) on those features, recorded by `nr::Graph`.
3. `src/opendlss_nr/shaders/nr_composite.comp`: the RGB residual on the proxy, the temporal blend with the history (the network's own blend logit times the model's learned cap), the next history (truncated to halves), the optional style preset and intensity, then a luminance-preserving tone upgrade back onto the HDR frame, written to the hook's `OUTPUT`. A non-finite result falls back to the frame.

The upstream PTX / CUDA route (`VK_NV_cuda_kernel_launch`) is not included: the GLSL route computes the same function without NVIDIA's CUDA interop extension, more slowly. See `third_party/opendlss_nr/README.md` for what was vendored (pinned commit `9d08f41`, MIT) and what Lumina changed.

## Requirements and capability

- Desktop Vulkan (Windows, Linux x86_64), an NVIDIA GPU with FP8 cooperative matrices (Ada or newer), and a driver with `VK_KHR_cooperative_matrix`, `VK_NV_cooperative_matrix2`, `VK_EXT_shader_float8`, `VK_KHR_shader_float16_int8`, `VK_KHR_8bit_storage`, `VK_KHR_vulkan_memory_model`, `VK_EXT_subgroup_size_control` and `VK_KHR_maintenance4`.
- `OpenDlssNr.requestDeviceFeatures()` before `FilamentEngine.create` asks for those extensions and feature members (through the feature chains of [External post pass and Vulkan device features](external-post-pass.md)).
- `OpenDlssNr.capability(engine)` returns `capable`, or the reason: `notVulkan`, `notNvidia`, `missingExtension`, `olderGpu` (no FP8 tensor cores), `notEnabled` (the engine was created before the request).
- `requestDeviceFeatures` also asks for `shaderInt16` and `storageBuffer16BitAccess` (merged into the structures Filament chains itself, patch `0018`) and a Vulkan 1.3 instance (`VulkanFeatures.requestApiVersion`; the kernels are SPIR-V 1.6). The capability check requires both: an engine created at API 1.1 reports `notEnabled`. With the Khronos validation layer the post pass, OpenDLSS-NR and DLSS Ray Reconstruction tests report none of these errors any more.

## The model folder

The upstream layout: `manifest.json` (`totals.blockCount` = 71, `stages[]` with `id`, `file`, `packedByteLength`, `sha256`, `tensors[]` with `name`, `block`, `layer`, `parameter`, `stage`, `stageOffset`, `byteLength`) and `model/<stage files>`. `OpenDlssNr.validateModel(path, verifyHashes:)` checks it before anything reaches the GPU:

| result | when |
|---|---|
| `missing` | no folder, or no `manifest.json` |
| `invalidManifest` | not JSON, over 16 MB, nested too deeply, keys missing, a block count other than 71 |
| `stageMismatch` | a stage file missing, of another size than the manifest says, or with a name that leaves the folder |
| `layoutMismatch` | one of the 153 tensors the network reads missing, too small (exactly sized where the layout fixes it), or past its stage |
| `hashMismatch` | with `verifyHashes`, a stage file whose SHA-256 differs |

`OpenDlssNr.writeSyntheticModel(path, random:)` writes a model of that layout filled with zeros or small random values. It holds no trained weights and exists for tests and timing.

## Dart API

`lib/src/opendlss_nr.dart`, exported by `package:flutter_filament/filament.dart`:

```dart
OpenDlssNr.requestDeviceFeatures();            // before the engine exists
final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
if (OpenDlssNr.capability(engine).supported) {
  final check = OpenDlssNr.validateModel(dir);  // blocking: call from an isolate
  if (check.ok) {
    final model = OpenDlssNr.loadModel(engine, dir); // or loadModelAddress on an isolate
    final pass = OpenDlssNrPass.create(engine: engine, view: view, model: model,
        controls: const OpenDlssNrControls(intensity: 0.8, style: OpenDlssNrStyle.natural));
    // ... pass.status: frames, gpuMs, failed / failure
    pass.destroy();
    model.destroy();
  }
}
```

`OpenDlssNrControls`: `enabled` (false passes the frame through), `intensity`, `localTone`, `localStructure`, `skinStructure` (-1 follows structure), `autoMask`, `style` (`none`, `natural`, `cinematic`), `paperWhite`, `colorStrength`. `OpenDlssNr.loadModelAddress(engineAddress, dir)` makes no Filament call and is meant for a background isolate; `OpenDlssNrModel.fromAddress` takes the result back. A pass that fails at any point (pipeline creation, memory, a frame larger than 2560 × 1600) turns itself off, `status.failed` and `status.failure` say why, and the view renders without it.

## Native C bridge

`src/opendlss_nr_c.h` (implementation in `src/opendlss_nr_c.cpp` and `src/opendlss_nr/`): `filament_opendlss_nr_request_device_features`, `_capability`, `_validate_model`, `_write_synthetic_model`, `_model_load`, `_model_destroy`, `_create`, `_set_controls`, `_get_status`, `_destroy`. Messages go into caller buffers, so validation can run on several threads. The kernels' SPIR-V is generated into `src/opendlss_nr/spirv.h` by `dart tool/build_opendlss_nr_shaders.dart` (glslang 16.6 or newer); the web build and other platforms compile stubs that report "not available".

## Measurements

`test/src/opendlss_nr_test.dart` on the RTX PRO 2000 Blackwell (GPU 1, 70 W), synthetic random weights, the whole pass (features, network, composite), GPU timestamps averaged over 40 frames:

| colour size | GPU time | dispatches | device memory |
|---|---|---|---|
| 1024 × 768 | about 11 ms | 311 | about 920 MiB |
| 1920 × 1088 (a 1920 × 1080 view) | about 27.5 ms | 302 | about 1.36 GiB |

Weights do not change the arithmetic's cost, so a real model costs the same. At 1080p the pass alone exceeds a 60 fps frame budget on this GPU.

## Limits and risks

- Experimental: the upstream "bit-exact" claim rests on private captures, and an upstream report shows wrong colours on an RTX 4080 laptop; output correctness cannot be checked without weights.
- Desktop Vulkan on NVIDIA Ada or newer only; the web, Android, macOS, OpenGL and other vendors report it unavailable.
- Frames above 2560 × 1600 are refused (the GLSL route materializes every intermediate).
- The editor viewport and PIE each hold their own activations (about 1 GB at 1080p).
