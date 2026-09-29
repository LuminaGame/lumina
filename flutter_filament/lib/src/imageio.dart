import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'ffi_package_platform.dart';
import 'package:flutter_filament/src/linear_image.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

enum ImageColorSpace {
  linear(c.FilImageDecoderColorSpace.FIL_IMAGE_DECODER_COLOR_SPACE_LINEAR),
  srgb(c.FilImageDecoderColorSpace.FIL_IMAGE_DECODER_COLOR_SPACE_SRGB);

  final c.FilImageDecoderColorSpace _cEnum;
  const ImageColorSpace(this._cEnum);
  int get value => _cEnum.value;
}

enum ImageEncoderFormat {
  png(c.FilImageEncoderFormat.FIL_IMAGE_ENCODER_FORMAT_PNG),
  pngLinear(c.FilImageEncoderFormat.FIL_IMAGE_ENCODER_FORMAT_PNG_LINEAR),
  hdr(c.FilImageEncoderFormat.FIL_IMAGE_ENCODER_FORMAT_HDR),
  rgbm(c.FilImageEncoderFormat.FIL_IMAGE_ENCODER_FORMAT_RGBM),
  psd(c.FilImageEncoderFormat.FIL_IMAGE_ENCODER_FORMAT_PSD),
  exr(c.FilImageEncoderFormat.FIL_IMAGE_ENCODER_FORMAT_EXR),
  dds(c.FilImageEncoderFormat.FIL_IMAGE_ENCODER_FORMAT_DDS),
  ddsLinear(c.FilImageEncoderFormat.FIL_IMAGE_ENCODER_FORMAT_DDS_LINEAR),
  rgb101111Rev(c.FilImageEncoderFormat.FIL_IMAGE_ENCODER_FORMAT_RGB_10_11_11_REV);

  final c.FilImageEncoderFormat _cEnum;
  const ImageEncoderFormat(this._cEnum);
  int get value => _cEnum.value;
}

/// Decodes image file bytes (PNG, JPEG, HDR, EXR, PSD) into a [LinearImage].
LinearImage decodeImage(
  Uint8List bytes, {
  ImageColorSpace colorSpace = ImageColorSpace.srgb,
  String sourceName = '',
}) {
  return using((Arena arena) {
    final dataPtr = arena<ffi.Uint8>(bytes.length);
    dataPtr.asTypedList(bytes.length).setAll(0, bytes);
    final namePtr = sourceName.toNativeUtf8(allocator: arena);

    final res = c.filament_image_decode(
      dataPtr,
      bytes.length,
      namePtr.cast<ffi.Char>(),
      colorSpace.value,
    );
    if (res == ffi.nullptr) {
      throw FormatException('Failed to decode image $sourceName');
    }
    return LinearImage.fromNativeHandle(res)!;
  });
}

/// Encodes [img] into compressed or container bytes according to [format].
Uint8List encodeImage(
  ImageEncoderFormat format,
  LinearImage img, {
  String? compression,
}) {
  return using((Arena arena) {
    final outData = arena<ffi.Pointer<ffi.Uint8>>();
    final outSize = arena<ffi.Size>();
    final compPtr = compression != null ? compression.toNativeUtf8(allocator: arena) : ffi.nullptr;

    final ok = c.filament_image_encode(
      format.value,
      img.handle,
      compPtr != ffi.nullptr ? compPtr.cast<ffi.Char>() : ffi.nullptr,
      outData,
      outSize,
    );

    if (!ok || outData.value == ffi.nullptr || outSize.value == 0) {
      throw FormatException('Failed to encode image to format $format');
    }

    final rawPtr = outData.value;
    final size = outSize.value;
    final bytes = Uint8List(size);
    bytes.setAll(0, rawPtr.asTypedList(size));
    c.filament_image_encode_free(rawPtr);
    return bytes;
  });
}

/// Builder for compressing texture mipmaps into a Basis-Universal KTX2 container.
class BasisEncoderBuilder {
  final int mipCount;
  final bool grayscale;
  final bool normals;
  final bool linear;
  ffi.Pointer<c.FilBasisEncoderBuilder>? _builderHandle;

  BasisEncoderBuilder({
    required this.mipCount,
    this.grayscale = false,
    this.normals = false,
    this.linear = false,
  }) {
    _builderHandle = c.filament_basis_encoder_builder_create(
      mipCount,
      grayscale,
      normals,
      linear,
    );
    if (_builderHandle == ffi.nullptr) {
      throw StateError('Failed to create BasisEncoderBuilder');
    }
  }

  void mipLevel(int index, LinearImage img) {
    final b = _builderHandle;
    if (b == null || b == ffi.nullptr) throw StateError('Builder already consumed or destroyed');
    c.filament_basis_encoder_builder_miplevel(b, index, img.handle);
  }

  void useUastc(bool uastc) {
    final b = _builderHandle;
    if (b == null || b == ffi.nullptr) throw StateError('Builder already consumed or destroyed');
    c.filament_basis_encoder_builder_intermediate_format(b, uastc);
  }

  /// Builds the encoder, compresses the texture levels, and returns the output KTX2 bytes.
  Uint8List buildAndEncode() {
    final b = _builderHandle;
    if (b == null || b == ffi.nullptr) throw StateError('Builder already consumed or destroyed');
    _builderHandle = null;

    final enc = c.filament_basis_encoder_builder_build(b);
    if (enc == ffi.nullptr) {
      throw StateError('Failed to build BasisEncoder');
    }

    try {
      final ok = c.filament_basis_encoder_encode(enc);
      if (!ok) {
        throw StateError('Failed to encode Basis texture');
      }

      final count = c.filament_basis_encoder_get_ktx2_byte_count(enc);
      final dataPtr = c.filament_basis_encoder_get_ktx2_data(enc);
      if (dataPtr == ffi.nullptr || count == 0) {
        throw StateError('Empty KTX2 buffer produced');
      }

      final result = Uint8List(count);
      result.setAll(0, dataPtr.asTypedList(count));
      return result;
    } finally {
      c.filament_basis_encoder_destroy(enc);
    }
  }
}
