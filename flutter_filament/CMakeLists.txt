cmake_minimum_required(VERSION 3.19)
project(flutter_filament_c CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include_directories(
    src
    ../filament/filament/include
    ../filament/filament/backend/include
    ../filament/filament/include
    ../filament/libs/filabridge/include
    ../filament/libs/gltfio/include
    ../filament/libs/filamat/include
    ../filament/libs/camutils/include
    ../filament/libs/utils/include
    ../filament/libs/math/include
    ../filament/libs/filaflat/include
    ../filament/libs/image/include
    ../filament/libs/imageio/include
    ../filament/libs/ibl/include
    ../filament/libs/iblprefilter/include
    ../filament/libs/ktxreader/include
    ../filament/libs/filameshio/include
    ../filament/third_party/zstd/lib
    ../filament/third_party/robin-map/include
    ../filament/third_party/draco/src
)

add_library(flutter_filament SHARED
    src/engine_c.cpp
    src/view_c.cpp
    src/geometry_c.cpp
    src/lighting_c.cpp
    src/gltf_c.cpp
    src/manipulator_c.cpp
    src/filamat_c.cpp
    src/tools_c.cpp
    src/buffer_descriptor_c.cpp
    src/callback_bridge_c.cpp
    src/enum_check_c.cpp
    src/math_abi_c.cpp
    src/tangent_space_mesh_c.cpp
    src/instance_c.cpp
    src/texture_sampler_c.cpp
    src/texture_c.cpp
    src/vertex_buffer_c.cpp
    src/buffer_object_c.cpp
    src/skinning_buffer_c.cpp
    src/index_buffer_c.cpp
    src/material_c.cpp
    src/material_instance_c.cpp
    src/renderer_c.cpp
    src/swap_chain_c.cpp
    src/fence_c.cpp
    src/frame_pacer_c.cpp
    src/debug_registry_c.cpp
    src/morph_target_buffer_c.cpp
    src/instance_buffer_c.cpp
    src/linear_image_c.cpp
    src/image_sampler_c.cpp
    src/image_ops_c.cpp
    src/color_transform_c.cpp
    src/image_sdf_c.cpp
    src/imageio_c.cpp
    src/ibl_cubemap_c.cpp
    src/ibl_sh_c.cpp
    src/ibl_bake_c.cpp
)
