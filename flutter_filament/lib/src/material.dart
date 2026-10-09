import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/src/ffi_package_platform.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/texture.dart';
import 'package:flutter_filament/src/texture_sampler.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

import 'package:flutter_filament/src/enums.dart';

import 'package:flutter_filament/src/callback_bridge.dart';
import 'package:flutter_filament/src/filamat_builder.dart';

part 'material/filament_material.dart';
part 'material/material_instance.dart';
part 'material/material_instance_render_state.dart';

/// Specialization constant for material compilation.
sealed class MaterialConstant {
  final String name;
  const MaterialConstant._(this.name);

  const factory MaterialConstant.int32(String name, int value) = _Int32MaterialConstant;
  const factory MaterialConstant.float(String name, double value) = _FloatMaterialConstant;
  const factory MaterialConstant.bool_(String name, bool value) = _BoolMaterialConstant;
}

class _Int32MaterialConstant extends MaterialConstant {
  final int value;
  const _Int32MaterialConstant(super.name, this.value) : super._();
}

class _FloatMaterialConstant extends MaterialConstant {
  final double value;
  const _FloatMaterialConstant(super.name, this.value) : super._();
}

class _BoolMaterialConstant extends MaterialConstant {
  final bool value;
  const _BoolMaterialConstant(super.name, this.value) : super._();
}

/// Quality of shadow sampling for material builders.
enum ShadowSamplingQuality {
  low(0),
  medium(1),
  high(2),
  ultra(3);

  final int value;
  const ShadowSamplingQuality(this.value);
}

/// Holds reflected information about a [FilamentMaterial] parameter.
class MaterialParameter {
  final String name;
  final bool isSampler;
  final bool isSubpass;
  final UniformType? uniformType;
  final TextureSamplerType? samplerType;
  final int count;
  final ParameterPrecision precision;

  const MaterialParameter({
    required this.name,
    required this.isSampler,
    required this.isSubpass,
    this.uniformType,
    this.samplerType,
    required this.count,
    required this.precision,
  });

  @override
  String toString() {
    return 'MaterialParameter(name: $name, isSampler: $isSampler, isSubpass: $isSubpass, '
        'uniformType: $uniformType, samplerType: $samplerType, count: $count, precision: $precision)';
  }
}

/// Represents a compiled Filament material.
/// The material package version this engine build accepts.
///
/// A compiled `.filamat` carries its version in its header; if the two differ
/// the engine refuses the material at load time. It logs and carries on, so
/// the only visible symptom is that whatever used the material renders
/// nothing — check this instead of trusting a successful load.
int get filamentExpectedMaterialVersion => c.filament_expected_material_version();

/// The version recorded in a compiled `.filamat` package's header.
int filamentMaterialPackageVersion(Uint8List package) {
  if (package.length < 13) {
    throw ArgumentError('not a .filamat package: ${package.length} bytes');
  }
  return package[12];
}
