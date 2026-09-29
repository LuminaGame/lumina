import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'ffi_package_platform.dart';

import 'camera.dart';
import 'scene.dart';
import 'filament_bindings.dart' as ffi_bind;
import 'view.dart';

/// Mipmap generation result container.
class MipmapResult {
  final Uint8List pixels;
  final int width;
  final int height;

  MipmapResult({
    required this.pixels,
    required this.width,
    required this.height,
  });
}

/// RGB Color vector container for specular reflectance F0.
class SpecularF0Result {
  final double r;
  final double g;
  final double b;

  SpecularF0Result({
    required this.r,
    required this.g,
    required this.b,
  });
}

/// Image diff comparison result container (`diffimg` tool).
class ImageDiffResult {
  final double meanError;
  final double maxError;
  final Uint8List diffPixels;

  ImageDiffResult({
    required this.meanError,
    required this.maxError,
    required this.diffPixels,
  });
}

/// Native C/FFI integrated Filament Tools utility suite.
///
/// Provides zero-subprocess, native in-process access to Filament tools including:
/// - Material binary inspection (JSON & Text format via `matdbg`)
/// - Binary asset encoding into C++ header code (`resgen`)
/// - Box-filtered RGBA8 texture mipmap level generation (`mipgen`)
/// - GLSL shader minifier & comment stripper (`glslminifier`)
/// - Reoriented Normal Mapping (RNM) normal map blending (`normal-blending`)
/// - Dielectric & Conductor Fresnel F0 reflectance calculations (`specular-color`)
/// - Spherical Harmonics 3rd-order diffuse IBL calculation (`cmgen`)
/// - Image visual diff & comparison metrics (`diffimg`)
/// - Specular Ambient Occlusion LUT calculation (`cso-lut`)
/// - ZSTD archive compression & decompression (`uberz`)
/// - Frame pipeline render debug visualizer dump (`frame_pipeline_visualizer`)
class FilamentTools {
  /// Inspects a compiled `.filamat` binary buffer natively via FFI and returns a JSON metadata string.
  static String? inspectMaterialJson(Uint8List filamatBuffer) {
    if (filamatBuffer.isEmpty) return null;

    final pointer = calloc<ffi.Uint8>(filamatBuffer.length);
    try {
      pointer.asTypedList(filamatBuffer.length).setAll(0, filamatBuffer);
      final charPtr = ffi_bind.filament_tools_inspect_material_json(
        pointer.cast(),
        filamatBuffer.length,
      );

      if (charPtr.address == 0) return null;

      try {
        return charPtr.cast<Utf8>().toDartString();
      } finally {
        ffi_bind.filament_tools_free_string(charPtr);
      }
    } finally {
      calloc.free(pointer);
    }
  }

  /// Inspects a compiled `.filamat` binary buffer natively via FFI and returns a human-readable text summary string.
  static String? inspectMaterialText(Uint8List filamatBuffer) {
    if (filamatBuffer.isEmpty) return null;

    final pointer = calloc<ffi.Uint8>(filamatBuffer.length);
    try {
      pointer.asTypedList(filamatBuffer.length).setAll(0, filamatBuffer);
      final charPtr = ffi_bind.filament_tools_inspect_material_text(
        pointer.cast(),
        filamatBuffer.length,
      );

      if (charPtr.address == 0) return null;

      try {
        return charPtr.cast<Utf8>().toDartString();
      } finally {
        ffi_bind.filament_tools_free_string(charPtr);
      }
    } finally {
      calloc.free(pointer);
    }
  }

  /// Encodes a binary buffer into C/C++ header source code (`resgen` tool).
  static String? encodeResourceHeader({
    required Uint8List bytes,
    required String symbolName,
  }) {
    if (bytes.isEmpty || symbolName.isEmpty) return null;

    final pointer = calloc<ffi.Uint8>(bytes.length);
    final symbolPtr = symbolName.toNativeUtf8();

    try {
      pointer.asTypedList(bytes.length).setAll(0, bytes);
      final charPtr = ffi_bind.filament_tools_resgen_encode(
        pointer.cast(),
        bytes.length,
        symbolPtr.cast(),
      );

      if (charPtr.address == 0) return null;

      try {
        return charPtr.cast<Utf8>().toDartString();
      } finally {
        ffi_bind.filament_tools_free_string(charPtr);
      }
    } finally {
      calloc.free(pointer);
      calloc.free(symbolPtr);
    }
  }

  /// Generates box-filtered RGBA8 texture mipmap level (`mipgen` tool).
  static MipmapResult? generateMipmap({
    required Uint8List srcPixels,
    required int width,
    required int height,
    required int targetLevel,
  }) {
    if (srcPixels.length != width * height * 4 || width == 0 || height == 0) {
      return null;
    }

    final srcPtr = calloc<ffi.Uint8>(srcPixels.length);
    final outPtr = calloc<ffi.Uint8>(srcPixels.length);
    final outWidthPtr = calloc<ffi.Uint32>();
    final outHeightPtr = calloc<ffi.Uint32>();

    try {
      srcPtr.asTypedList(srcPixels.length).setAll(0, srcPixels);

      final success = ffi_bind.filament_tools_generate_mipmap_level_rgba8(
        srcPtr.cast(),
        width,
        height,
        targetLevel,
        outPtr.cast(),
        outWidthPtr,
        outHeightPtr,
      );

      if (success == 0) return null;

      final resWidth = outWidthPtr.value;
      final resHeight = outHeightPtr.value;
      final resSize = resWidth * resHeight * 4;

      final resultBytes = Uint8List.fromList(outPtr.asTypedList(resSize));
      return MipmapResult(
        pixels: resultBytes,
        width: resWidth,
        height: resHeight,
      );
    } finally {
      calloc.free(srcPtr);
      calloc.free(outPtr);
      calloc.free(outWidthPtr);
      calloc.free(outHeightPtr);
    }
  }

  /// Minifies GLSL shader source code by removing comments, empty lines, and indentation (`glslminifier` tool).
  static String? minifyGlsl(String glslCode) {
    if (glslCode.isEmpty) return '';

    final codePtr = glslCode.toNativeUtf8();
    try {
      final charPtr = ffi_bind.filament_tools_minify_glsl(
        codePtr.cast(),
        0x7,
      );

      if (charPtr.address == 0) return null;

      try {
        return charPtr.cast<Utf8>().toDartString();
      } finally {
        ffi_bind.filament_tools_free_string(charPtr);
      }
    } finally {
      calloc.free(codePtr);
    }
  }

  /// Blends two RGBA8 normal maps using Reoriented Normal Mapping (RNM) (`normal-blending` tool).
  static Uint8List? blendNormalMaps({
    required Uint8List basePixels,
    required Uint8List detailPixels,
    required int width,
    required int height,
  }) {
    final expectedSize = width * height * 4;
    if (basePixels.length != expectedSize || detailPixels.length != expectedSize) {
      return null;
    }

    final basePtr = calloc<ffi.Uint8>(expectedSize);
    final detailPtr = calloc<ffi.Uint8>(expectedSize);
    final outPtr = calloc<ffi.Uint8>(expectedSize);

    try {
      basePtr.asTypedList(expectedSize).setAll(0, basePixels);
      detailPtr.asTypedList(expectedSize).setAll(0, detailPixels);

      final success = ffi_bind.filament_tools_blend_normal_maps_rgba8(
        basePtr.cast(),
        detailPtr.cast(),
        width,
        height,
        outPtr.cast(),
      );

      if (success == 0) return null;

      return Uint8List.fromList(outPtr.asTypedList(expectedSize));
    } finally {
      calloc.free(basePtr);
      calloc.free(detailPtr);
      calloc.free(outPtr);
    }
  }

  /// Computes dielectric specular reflectance F0 from Index of Refraction (IOR) (`specular-color` tool).
  static double computeDielectricF0(double ior) {
    return ffi_bind.filament_tools_compute_dielectric_f0(ior);
  }

  /// Computes conductor specular reflectance F0 from complex IOR (n, k) (`specular-color` tool).
  static SpecularF0Result computeConductorF0({
    required double nR,
    required double nG,
    required double nB,
    required double kR,
    required double kG,
    required double kB,
  }) {
    final rPtr = calloc<ffi.Float>();
    final gPtr = calloc<ffi.Float>();
    final bPtr = calloc<ffi.Float>();

    try {
      ffi_bind.filament_tools_compute_conductor_f0(
        nR, nG, nB,
        kR, kG, kB,
        rPtr, gPtr, bPtr,
      );

      return SpecularF0Result(
        r: rPtr.value,
        g: gPtr.value,
        b: bPtr.value,
      );
    } finally {
      calloc.free(rPtr);
      calloc.free(gPtr);
      calloc.free(bPtr);
    }
  }

  /// Computes 9-coefficient (27 floats) Spherical Harmonics (SH3) RGB values for diffuse IBL (`cmgen` tool).
  static Float32List? computeSphericalHarmonics({
    required Uint8List equirectPixels,
    required int width,
    required int height,
  }) {
    if (equirectPixels.length != width * height * 4 || width == 0 || height == 0) {
      return null;
    }

    final inputPtr = calloc<ffi.Uint8>(equirectPixels.length);
    final shPtr = calloc<ffi.Float>(27);

    try {
      inputPtr.asTypedList(equirectPixels.length).setAll(0, equirectPixels);

      final success = ffi_bind.filament_tools_compute_spherical_harmonics_rgba8(
        inputPtr.cast(),
        width,
        height,
        shPtr.cast(),
      );

      if (success == 0) return null;

      final result = Float32List(27);
      result.setAll(0, shPtr.asTypedList(27));
      return result;
    } finally {
      calloc.free(inputPtr);
      calloc.free(shPtr);
    }
  }

  /// Compares two RGBA8 image buffers and computes difference metrics and diff map (`diffimg` tool).
  static ImageDiffResult? compareImages({
    required Uint8List pixelsA,
    required Uint8List pixelsB,
    required int width,
    required int height,
  }) {
    final expectedSize = width * height * 4;
    if (pixelsA.length != expectedSize || pixelsB.length != expectedSize) {
      return null;
    }

    final aPtr = calloc<ffi.Uint8>(expectedSize);
    final bPtr = calloc<ffi.Uint8>(expectedSize);
    final diffPtr = calloc<ffi.Uint8>(expectedSize);
    final meanErrPtr = calloc<ffi.Float>();
    final maxErrPtr = calloc<ffi.Float>();

    try {
      aPtr.asTypedList(expectedSize).setAll(0, pixelsA);
      bPtr.asTypedList(expectedSize).setAll(0, pixelsB);

      final success = ffi_bind.filament_tools_compare_images_rgba8(
        aPtr.cast(),
        bPtr.cast(),
        width,
        height,
        diffPtr.cast(),
        meanErrPtr,
        maxErrPtr,
      );

      if (success == 0) return null;

      return ImageDiffResult(
        meanError: meanErrPtr.value.toDouble(),
        maxError: maxErrPtr.value.toDouble(),
        diffPixels: Uint8List.fromList(diffPtr.asTypedList(expectedSize)),
      );
    } finally {
      calloc.free(aPtr);
      calloc.free(bPtr);
      calloc.free(diffPtr);
      calloc.free(meanErrPtr);
      calloc.free(maxErrPtr);
    }
  }

  /// Computes Specular Ambient Occlusion (SAO) LUT value (`cso-lut` tool).
  static double computeSpecularAo({
    required double roughness,
    required double ndotv,
    required double ao,
  }) {
    return ffi_bind.filament_tools_compute_specular_ao(roughness, ndotv, ao);
  }

  /// Compresses binary buffer using ZSTD algorithm (`uberz` tool).
  static Uint8List? zstdCompress(Uint8List data) {
    if (data.isEmpty) return null;

    final srcPtr = calloc<ffi.Uint8>(data.length);
    final sizePtr = calloc<ffi.Uint32>();

    try {
      srcPtr.asTypedList(data.length).setAll(0, data);
      final outPtr = ffi_bind.filament_tools_zstd_compress(
        srcPtr.cast(),
        data.length,
        sizePtr,
      );

      if (outPtr.address == 0) return null;

      final compSize = sizePtr.value;
      try {
        return Uint8List.fromList(outPtr.cast<ffi.Uint8>().asTypedList(compSize));
      } finally {
        ffi_bind.filament_tools_free_buffer(outPtr);
      }
    } finally {
      calloc.free(srcPtr);
      calloc.free(sizePtr);
    }
  }

  /// Decompresses ZSTD compressed binary buffer (`uberz` tool).
  static Uint8List? zstdDecompress(Uint8List compressedData) {
    if (compressedData.isEmpty) return null;

    final srcPtr = calloc<ffi.Uint8>(compressedData.length);
    final sizePtr = calloc<ffi.Uint32>();

    try {
      srcPtr.asTypedList(compressedData.length).setAll(0, compressedData);
      final outPtr = ffi_bind.filament_tools_zstd_decompress(
        srcPtr.cast(),
        compressedData.length,
        sizePtr,
      );

      if (outPtr.address == 0) return null;

      final decompSize = sizePtr.value;
      try {
        return Uint8List.fromList(outPtr.cast<ffi.Uint8>().asTypedList(decompSize));
      } finally {
        ffi_bind.filament_tools_free_buffer(outPtr);
      }
    } finally {
      calloc.free(srcPtr);
      calloc.free(sizePtr);
    }
  }

  /// Generates a debug JSON dump of the rendering pipeline state (`frame_pipeline_visualizer` tool).
  static String? dumpFramePipelineJson({
    required FilamentView view,
    required FilamentScene scene,
    required FilamentCamera camera,
  }) {
    final charPtr = ffi_bind.filament_tools_dump_frame_pipeline_json(
      view.nativePointer,
      scene.nativePointer,
      camera.nativePointer,
    );

    if (charPtr.address == 0) return null;

    try {
      return charPtr.cast<Utf8>().toDartString();
    } finally {
      ffi_bind.filament_tools_free_string(charPtr);
    }
  }
}
