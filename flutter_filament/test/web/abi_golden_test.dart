import 'dart:convert';
import 'dart:io';

import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:flutter_test/flutter_test.dart';

/// The desktop half of the ABI parity check. The native library's
/// struct sizes and enum values are the golden (`test/web/abi_golden.json`);
/// `test/web/module_test.mjs` checks the WebAssembly module against it.
/// `UPDATE_ABI_GOLDEN=1 flutter test test/web/abi_golden_test.dart` rewrites it.
const _ordinals = 32;

final Map<String, int Function()> _sizeofs = {
  'filament_sizeof_float2': c.filament_sizeof_float2,
  'filament_sizeof_float3': c.filament_sizeof_float3,
  'filament_sizeof_float4': c.filament_sizeof_float4,
  'filament_sizeof_int2': c.filament_sizeof_int2,
  'filament_sizeof_int3': c.filament_sizeof_int3,
  'filament_sizeof_int4': c.filament_sizeof_int4,
  'filament_sizeof_uint2': c.filament_sizeof_uint2,
  'filament_sizeof_uint3': c.filament_sizeof_uint3,
  'filament_sizeof_uint4': c.filament_sizeof_uint4,
  'filament_sizeof_bool2': c.filament_sizeof_bool2,
  'filament_sizeof_bool3': c.filament_sizeof_bool3,
  'filament_sizeof_bool4': c.filament_sizeof_bool4,
  'filament_sizeof_short4': c.filament_sizeof_short4,
  'filament_sizeof_quatf': c.filament_sizeof_quatf,
  'filament_sizeof_mat3f': c.filament_sizeof_mat3f,
  'filament_sizeof_mat4f': c.filament_sizeof_mat4f,
  'filament_sizeof_mat4': c.filament_sizeof_mat4,
};

final Map<String, int Function(int)> _enums = {
  'filament_enum_primitive_type': c.filament_enum_primitive_type,
  'filament_enum_index_type': c.filament_enum_index_type,
  'filament_enum_texture_usage': c.filament_enum_texture_usage,
  'filament_enum_builder_result': c.filament_enum_builder_result,
  'filament_enum_morph_type': c.filament_enum_morph_type,
  'filament_enum_backend': c.filament_enum_backend,
  'filament_enum_light_type': c.filament_enum_light_type,
  'filament_enum_manipulator_mode': c.filament_enum_manipulator_mode,
  'filament_enum_filamat_shading': c.filament_enum_filamat_shading,
  'filament_enum_texture_format': c.filament_enum_texture_format,
  'filament_enum_internal_format': c.filament_enum_internal_format,
  'filament_enum_sampler_type': c.filament_enum_sampler_type,
  'filament_enum_texture_swizzle': c.filament_enum_texture_swizzle,
  'filament_enum_pixel_format': c.filament_enum_pixel_format,
  'filament_enum_pixel_type': c.filament_enum_pixel_type,
  'filament_enum_attribute_type': c.filament_enum_attribute_type,
  'filament_enum_vertex_attribute': c.filament_enum_vertex_attribute,
  'filament_enum_uniform_type': c.filament_enum_uniform_type,
  'filament_enum_precision': c.filament_enum_precision,
  'filament_enum_culling_mode': c.filament_enum_culling_mode,
  'filament_enum_depth_func': c.filament_enum_depth_func,
  'filament_enum_transparency_mode': c.filament_enum_transparency_mode,
};

Map<String, Object> _native() => {
      for (final e in _sizeofs.entries) e.key: e.value(),
      for (final e in _enums.entries) e.key: [for (var i = 0; i < _ordinals; i++) e.value(i)],
    };

Set<String> _declared(String header, String prefix) => RegExp('FFI_PLUGIN_EXPORT \\w+ ($prefix\\w+)\\((?:void|int32_t ordinal)\\)')
    .allMatches(File(header).readAsStringSync())
    .map((m) => m.group(1)!)
    .toSet();

void main() {
  test('every size / enum probe declared in the headers is in the golden table', () {
    expect(_sizeofs.keys.toSet(), _declared('src/math_abi_c.h', 'filament_sizeof_'));
    expect(_enums.keys.toSet(), _declared('src/enum_check_c.h', 'filament_enum_'));
  });

  test('the native ABI matches test/web/abi_golden.json', () {
    final golden = File('test/web/abi_golden.json');
    final native = _native();
    if (Platform.environment['UPDATE_ABI_GOLDEN'] == '1' || !golden.existsSync()) {
      golden.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(native));
    }
    expect(jsonDecode(golden.readAsStringSync()), native);
  });
}
