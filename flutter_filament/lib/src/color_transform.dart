import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'ffi_package_platform.dart';
import 'package:flutter_filament/src/linear_image.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Converts an sRGB [LinearImage] to linear color space using the exact piecewise sRGB transfer function.
LinearImage srgbToLinear(LinearImage src) {
  final res = c.filament_color_srgb_to_linear(src.handle);
  if (res == ffi.nullptr) throw StateError('Failed to convert sRGB to linear');
  return LinearImage.fromNativeHandle(res)!;
}

/// Converts a linear [LinearImage] to sRGB color space.
LinearImage linearToSrgb(LinearImage src) {
  final res = c.filament_color_linear_to_srgb(src.handle);
  if (res == ffi.nullptr) throw StateError('Failed to convert linear to sRGB');
  return LinearImage.fromNativeHandle(res)!;
}

/// Converts a [LinearImage] to 1-channel grayscale using Rec.709 luminance weights (0.2126R + 0.7152G + 0.0722B).
LinearImage toGrayscale(LinearImage src) {
  final res = c.filament_color_to_grayscale(src.handle);
  if (res == ffi.nullptr) throw StateError('Failed to convert to grayscale');
  return LinearImage.fromNativeHandle(res)!;
}

/// Decodes sRGB byte buffer (e.g. from decoded PNG/JPEG) into a linear float [LinearImage].
LinearImage srgbBytesToLinear(
  int width,
  int height,
  int channels,
  Uint8List bytes, {
  int? bytesPerRow,
}) {
  if (channels != 3 && channels != 4 && channels != 1) {
    throw ArgumentError('channels must be 1, 3, or 4');
  }
  return using((Arena arena) {
    final ptr = arena<ffi.Uint8>(bytes.length);
    ptr.asTypedList(bytes.length).setAll(0, bytes);
    final res = c.filament_color_srgb_bytes_to_linear(
      width,
      height,
      bytesPerRow ?? (width * channels),
      channels,
      ptr,
    );
    if (res == ffi.nullptr) throw StateError('Failed to convert sRGB bytes to linear');
    return LinearImage.fromNativeHandle(res)!;
  });
}

/// Converts a linear [LinearImage] to an sRGB byte buffer with optional row stride.
Uint8List linearToSrgbBytes(LinearImage src, {int? bytesPerRow}) {
  final bpr = bytesPerRow ?? (src.width * src.channels);
  final totalBytes = bpr * src.height;
  return using((Arena arena) {
    final ptr = arena<ffi.Uint8>(totalBytes);
    c.filament_color_linear_to_srgb_bytes(src.handle, ptr, bpr);
    final result = Uint8List(totalBytes);
    result.setAll(0, ptr.asTypedList(totalBytes));
    return result;
  });
}

/// Converts a linear HDR [LinearImage] to a 4-channel RGBM representation.
LinearImage linearToRgbm(LinearImage src) {
  final res = c.filament_color_linear_to_rgbm(src.handle);
  if (res == ffi.nullptr) throw StateError('Failed to convert linear to RGBM');
  return LinearImage.fromNativeHandle(res)!;
}

/// Converts an RGBM [LinearImage] back to a 3-channel linear HDR image.
LinearImage rgbmToLinear(LinearImage src) {
  final res = c.filament_color_rgbm_to_linear(src.handle);
  if (res == ffi.nullptr) throw StateError('Failed to convert RGBM to linear');
  return LinearImage.fromNativeHandle(res)!;
}

/// Encodes a linear [LinearImage] to a packed RGB_10_11_11_REV (R11G11B10F) uint32 buffer.
Uint32List linearToRgb101111Rev(LinearImage src) {
  final count = src.width * src.height;
  return using((Arena arena) {
    final ptr = arena<ffi.Uint32>(count);
    c.filament_color_linear_to_rgb_10_11_11_rev(src.handle, ptr);
    final result = Uint32List(count);
    result.setAll(0, ptr.asTypedList(count));
    return result;
  });
}
