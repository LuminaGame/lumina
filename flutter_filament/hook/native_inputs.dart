/// What the native-assets hook compiles and links: the wrapper sources and the
/// Filament static libraries per platform. `tool/filament/prebuilt_manifest.dart`
/// reads the library lists from this file, so the prebuilt archives carry them.
library;

/// The Filament static libraries the Windows build links, relative to
/// `filament/out/cmake-release-windows/` — the MSVC counterparts of the Linux
/// list above, plus the zlib/libpng/tinyexr Filament builds itself (Linux
/// takes `-lpng -lz` from the system).
const windowsFilamentLibs = [
  'filament/filament.lib',
  'filament/backend/backend.lib',
  'libs/utils/utils.lib',
  'libs/gltfio/gltfio.lib',
  'libs/gltfio/uberarchive.lib',
  'libs/filabridge/filabridge.lib',
  'libs/filamat/filamat.lib',
  'libs/camutils/camutils.lib',
  'libs/matdbg/matdbg.lib',
  'libs/matdbg/matdbg_resources.lib',
  'third_party/civetweb/tnt/civetweb.lib',
  'third_party/abseil/tnt/filament-abseil.lib',
  'shaders/shaders.lib',
  'libs/bluegl/bluegl.lib',
  'libs/bluevk/bluevk.lib',
  'libs/geometry/geometry.lib',
  'third_party/draco/tnt/dracodec.lib',
  'third_party/basisu/tnt/basis_transcoder.lib',
  'third_party/basisu/tnt/basis_encoder.lib',
  'third_party/meshoptimizer/tnt/meshoptimizer.lib',
  'third_party/mikktspace/mikktspace.lib',
  'libs/filameshio/filameshio.lib',
  'samples/suzanne-resources.lib',
  'samples/sample-resources.lib',
  'libs/filaflat/filaflat.lib',
  'libs/gltfio/gltfio_core.lib',
  'third_party/spirv-cross/tnt/spirv-cross-glsl.lib',
  'third_party/spirv-cross/tnt/spirv-cross-core.lib',
  'third_party/spirv-cross/tnt/spirv-cross-msl.lib',
  'third_party/spirv-tools/source/SPIRV-Tools.lib',
  'third_party/spirv-tools/source/opt/SPIRV-Tools-opt.lib',
  'third_party/glslang/tnt/glslang/glslang.lib',
  'third_party/glslang/tnt/SPIRV/SPIRV.lib',
  'third_party/glslang/tnt/glslang/OSDependent/Windows/OSDependent.lib',
  'third_party/zstd/tnt/zstd.lib',
  'libs/image/image.lib',
  'libs/imageio/imageio.lib',
  'libs/ibl/ibl.lib',
  'libs/ktxreader/ktxreader.lib',
  'libs/iblprefilter/filament-iblprefilter.lib',
  'libs/uberz/uberzlib.lib',
  'third_party/libwebp/libwebpdecoder.lib',
  'third_party/stb/tnt/stb.lib',
  'third_party/tinyexr/tnt/tinyexr.lib',
  'third_party/libpng/tnt/png.lib',
  'third_party/libz/tnt/z.lib',
];

/// The C/C++ sources of the wrapper, the same on every target: what a platform
/// lacks is compiled out inside the file (`__EMSCRIPTEN__`, `__ANDROID__`, the
/// `*_ENABLED` switches), so every `filament_*` symbol exists everywhere and
/// reports "unsupported" where the feature does not. [filament] is the
/// Filament checkout (`filamentDir` in build.dart).
List<String> nativeSources(String filament) => [
    'src/android_compat.cpp',
    'src/engine_c.cpp',
    'src/async_resource_c.cpp',
    'src/gpu_c.cpp',
    'src/gpu_engine_c.cpp',
    'src/external_vulkan_c.cpp',
    'src/view_c.cpp',
    'src/geometry_c.cpp',
    'src/lighting_c.cpp',
    'src/gltf_c.cpp',
    'src/manipulator_c.cpp',
    'src/filamat_c.cpp',
    'src/matc_c.cpp',
    'src/tools_c.cpp',
    'src/buffer_descriptor_c.cpp',
    'src/callback_bridge_c.cpp',
    'src/enum_check_c.cpp',
    'src/math_abi_c.cpp',
    'src/instance_c.cpp',
    'src/texture_sampler_c.cpp',
    'src/texture_c.cpp',
    'src/vertex_buffer_c.cpp',
    'src/buffer_object_c.cpp',
    'src/skinning_buffer_c.cpp',
    'src/index_buffer_c.cpp',
    'src/material_c.cpp',
    'src/material_instance_c.cpp',
    'src/utils_c.cpp',
    'src/tangent_space_mesh_c.cpp',
    'src/filamesh_c.cpp',
    'src/ktx2_reader_c.cpp',
    'src/ktx1_c.cpp',
    'src/iblprefilter_c.cpp',
    'src/color_grading_c.cpp',
    'src/camera_c.cpp',
    'src/renderer_c.cpp',
    'src/swap_chain_c.cpp',
    'src/fence_c.cpp',
    'src/frame_pacer_c.cpp',
    'src/debug_registry_c.cpp',
    'src/morph_target_buffer_c.cpp',
    'src/instance_buffer_c.cpp',
    'src/linear_image_c.cpp',
    'src/image_sampler_c.cpp',
    'src/dlss_c.cpp',
    'src/ngx_c.cpp',
    'src/dlss_rr_c.cpp',
    'src/dlss_fg_c.cpp',
    'src/ray_tracing_c.cpp',
    'src/restir_c.cpp',
    'src/post_pass_c.cpp',
    'src/ui_overlay_c.cpp',
    // OpenDLSS-NR (third-party, MIT): the C surface, Lumina's Vulkan host and frame pass, and the
    // vendored network sources (third_party/opendlss_nr); desktop Vulkan only, compiled out elsewhere.
    'src/opendlss_nr_c.cpp',
    'src/opendlss_nr/vk_context.cpp',
    'src/opendlss_nr/model_check.cpp',
    'src/opendlss_nr/capability.cpp',
    'src/opendlss_nr/neural_pass.cpp',
    'src/opendlss_nr/network_model.cpp',
    'src/opendlss_nr/network_kernels.cpp',
    'src/opendlss_nr/network_graph.cpp',
    'src/guide_buffers_c.cpp',
    'src/image_ops_c.cpp',
    'src/color_transform_c.cpp',
    'src/image_sdf_c.cpp',
    'src/imageio_c.cpp',
    'src/ibl_cubemap_c.cpp',
    'src/ibl_sh_c.cpp',
    'src/ibl_bake_c.cpp',
    'src/web_c.cpp',
    'src/web_stubs_c.cpp',
    '$filament/third_party/smol-v/source/smolv.cpp',
    // Filament's .mat parser (matc's matp library), vendored: the
    // prebuilt Filament archives carry no matp (third_party/filament_matp/README.md).
    for (final matp in matpSources) 'third_party/filament_matp/src/$matp',
];

/// The vendored matp sources (`third_party/filament_matp/src/`).
const matpSources = [
  'DirIncluder.cpp',
  'Includes.cpp',
  'JsonishLexer.cpp',
  'JsonishParser.cpp',
  'MaterialLexer.cpp',
  'MaterialParser.cpp',
  'ParametersProcessor.cpp',
];

/// Win32 import libraries the Filament backends and civetweb need.
const windowsSystemLibs = [
  'opengl32',
  'gdi32',
  'user32',
  'shell32',
  'shlwapi',
  'advapi32',
  'ole32',
  'ws2_32',
];

/// The static libraries linked on Android, relative to
/// `out/android-release/filament/lib/<abi>/`. Filament installs some of them
/// combined with their dependencies: `libgeometry.a` holds meshoptimizer and
/// mikktspace, `libfilamat.a` glslang, SPIRV-Tools, spirv-cross and zstd, and
/// `libabseil.a` all of abseil, so those parts are not listed again (the link
/// takes every member of each archive). smol-v is compiled from source
/// ([nativeSources]), as on desktop.
const androidFilamentLibs = [
  'libfilament.a',
  'libbackend.a',
  'libutils.a',
  'libgltfio_core.a',
  'libuberarchive.a',
  'libfilabridge.a',
  'libfilamat.a',
  'libcamutils.a',
  'libabseil.a',
  'libcivetweb.a',
  'libshaders.a',
  'libbluevk.a',
  'libgeometry.a',
  'libdracodec.a',
  'libbasis_transcoder.a',
  'libfilameshio.a',
  'libfilaflat.a',
  'libimage.a',
  'libibl.a',
  'libktxreader.a',
  'libfilament-iblprefilter.a',
  'libuberzlib.a',
  'libwebpdecoder.a',
  'libstb.a',
];
