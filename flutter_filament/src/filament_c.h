/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

/// Umbrella C wrapper header for Google Filament rendering engine.
///
/// This file includes all modular C wrapper sub-headers.
/// Consumed by `package:ffigen` via `tool/ffigen.dart` to generate Dart FFI bindings.

#ifndef FLUTTER_FILAMENT_C_H
#define FLUTTER_FILAMENT_C_H

#include "engine_c.h"
#include "view_c.h"
#include "geometry_c.h"
#include "lighting_c.h"
#include "gltf_c.h"
#include "manipulator_c.h"
#include "filamat_c.h"
#include "tools_c.h"
#include "buffer_descriptor_c.h"
#include "callback_bridge_c.h"
#include "enum_check_c.h"
#include "material_instance_c.h"
#include "tangent_space_mesh_c.h"
#include "instance_c.h"
#include "texture_sampler_c.h"
#include "texture_c.h"
#include "vertex_buffer_c.h"
#include "buffer_object_c.h"
#include "math_abi_c.h"
#include "index_buffer_c.h"
#include "skinning_buffer_c.h"
#include "material_c.h"
#include "utils_c.h"
#include "filamesh_c.h"
#include "ktx2_reader_c.h"
#include "ktx1_c.h"
#include "iblprefilter_c.h"
#include "color_grading_c.h"
#include "camera_c.h"
#include "renderer_c.h"
#include "swap_chain_c.h"
#include "fence_c.h"
#include "frame_pacer_c.h"
#include "debug_registry_c.h"
#include "morph_target_buffer_c.h"
#include "instance_buffer_c.h"
#include "linear_image_c.h"
#include "image_sampler_c.h"
#include "image_ops_c.h"
#include "color_transform_c.h"
#include "gpu_c.h"
#include "image_sdf_c.h"
#include "imageio_c.h"
#include "ibl_cubemap_c.h"
#include "ibl_sh_c.h"
#include "ibl_bake_c.h"
#include "web_c.h"

#endif // FLUTTER_FILAMENT_C_H
