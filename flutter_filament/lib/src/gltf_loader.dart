import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/src/ffi_package_platform.dart';

import 'dart:async';

import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/math/box.dart';
import 'package:flutter_filament/src/scene.dart';
import 'package:flutter_filament/src/texture_provider.dart';
import 'package:flutter_filament/src/material.dart';
import 'package:flutter_filament/src/name_component_manager.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

part 'gltf_loader/asset.dart';
part 'gltf_loader/asset_instance.dart';
part 'gltf_loader/asset_loader.dart';
part 'gltf_loader/material_provider.dart';
part 'gltf_loader/resource_loader.dart';

/// Helper wrapper / alias for loading glTF and GLB assets.
class GltfLoader {
  final FilamentAssetLoader _loader;

  GltfLoader({
    required FilamentEngine engine,
    required FilamentMaterialProvider materialProvider,
    NameComponentManager? names,
  }) : _loader = FilamentAssetLoader.create(
          engine: engine,
          materialProvider: materialProvider,
          names: names,
        );

  FilamentAssetLoader get assetLoader => _loader;

  FilamentAsset? loadGltf(Uint8List bytes) => _loader.createAsset(bytes);

  void dispose() => _loader.dispose();
}
