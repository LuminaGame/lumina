import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/ffi_package_platform.dart';
import 'package:flutter_filament/src/linear_image.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Extracts a single channel at [channelIndex] from [src] as a 1-channel [LinearImage].
LinearImage extractChannel(LinearImage src, int channelIndex) {
  if (channelIndex < 0 || channelIndex >= src.channels) {
    throw RangeError.range(channelIndex, 0, src.channels - 1, 'channelIndex');
  }
  final ptr = c.filament_image_extract_channel(src.handle, channelIndex);
  if (ptr == ffi.nullptr) {
    throw StateError('Failed to extract channel');
  }
  return LinearImage.fromNativeHandle(ptr)!;
}

/// Combines a list of single-channel [images] into a single multi-channel [LinearImage].
LinearImage combineChannels(List<LinearImage> images) {
  if (images.isEmpty) {
    throw ArgumentError('images list must not be empty');
  }
  final w = images.first.width;
  final h = images.first.height;
  for (final img in images) {
    if (img.width != w || img.height != h) {
      throw ArgumentError('All images must have the same dimensions');
    }
    if (img.channels != 1) {
      throw ArgumentError('All images must be single-channel');
    }
  }

  return using((Arena arena) {
    final ptrs = arena<ffi.Pointer<c.FilLinearImage>>(images.length);
    for (var i = 0; i < images.length; i++) {
      ptrs[i] = images[i].handle;
    }
    final res = c.filament_image_combine_channels(ptrs, images.length);
    if (res == ffi.nullptr) {
      throw StateError('Failed to combine channels');
    }
    return LinearImage.fromNativeHandle(res)!;
  });
}

/// Packs Occlusion (R), Roughness (G), and Metallic (B) single-channel images into a standard 3-channel ORM texture.
LinearImage packOrm({
  required LinearImage occlusion,
  required LinearImage roughness,
  required LinearImage metallic,
}) {
  return combineChannels([occlusion, roughness, metallic]);
}

/// Crops a subregion from [src] using half-open bounds [left], [top], [right], [bottom].
LinearImage cropRegion(
  LinearImage src, {
  required int left,
  required int top,
  required int right,
  required int bottom,
}) {
  if (left < 0 || top < 0 || right > src.width || bottom > src.height || left >= right || top >= bottom) {
    throw ArgumentError('Invalid crop bounds ($left, $top, $right, $bottom) for image (${src.width}x${src.height})');
  }
  final ptr = c.filament_image_crop_region(src.handle, left, top, right, bottom);
  if (ptr == ffi.nullptr) {
    throw StateError('Failed to crop region');
  }
  return LinearImage.fromNativeHandle(ptr)!;
}

/// Copies the content of [src] into [dst] at destination offset ([x], [y]).
void blitImage(LinearImage dst, LinearImage src, [int x = 0, int y = 0]) {
  c.filament_image_blit(dst.handle, src.handle, x, y);
}

/// Concatenates [images] horizontally.
LinearImage horizontalStack(List<LinearImage> images) {
  if (images.isEmpty) throw ArgumentError('images list must not be empty');
  return using((Arena arena) {
    final ptrs = arena<ffi.Pointer<c.FilLinearImage>>(images.length);
    for (var i = 0; i < images.length; i++) {
      ptrs[i] = images[i].handle;
    }
    final res = c.filament_image_horizontal_stack(ptrs, images.length);
    if (res == ffi.nullptr) throw StateError('Failed to horizontalStack');
    return LinearImage.fromNativeHandle(res)!;
  });
}

/// Concatenates [images] vertically.
LinearImage verticalStack(List<LinearImage> images) {
  if (images.isEmpty) throw ArgumentError('images list must not be empty');
  return using((Arena arena) {
    final ptrs = arena<ffi.Pointer<c.FilLinearImage>>(images.length);
    for (var i = 0; i < images.length; i++) {
      ptrs[i] = images[i].handle;
    }
    final res = c.filament_image_vertical_stack(ptrs, images.length);
    if (res == ffi.nullptr) throw StateError('Failed to verticalStack');
    return LinearImage.fromNativeHandle(res)!;
  });
}

/// Horizontally mirrors [src].
LinearImage horizontalFlip(LinearImage src) {
  final res = c.filament_image_horizontal_flip(src.handle);
  if (res == ffi.nullptr) throw StateError('Failed to horizontalFlip');
  return LinearImage.fromNativeHandle(res)!;
}

/// Vertically mirrors [src].
LinearImage verticalFlip(LinearImage src) {
  final res = c.filament_image_vertical_flip(src.handle);
  if (res == ffi.nullptr) throw StateError('Failed to verticalFlip');
  return LinearImage.fromNativeHandle(res)!;
}

/// Transposes [src] by swapping rows and columns.
LinearImage transpose(LinearImage src) {
  final res = c.filament_image_transpose(src.handle);
  if (res == ffi.nullptr) throw StateError('Failed to transpose');
  return LinearImage.fromNativeHandle(res)!;
}

/// Maps vectors in [-1, +1] to color representation in [0, +1].
LinearImage vectorsToColors(LinearImage src) {
  final res = c.filament_image_vectors_to_colors(src.handle);
  if (res == ffi.nullptr) throw StateError('Failed to convert vectors to colors');
  return LinearImage.fromNativeHandle(res)!;
}

/// Maps color representation in [0, +1] to vector coordinates in [-1, +1].
LinearImage colorsToVectors(LinearImage src) {
  final res = c.filament_image_colors_to_vectors(src.handle);
  if (res == ffi.nullptr) throw StateError('Failed to convert colors to vectors');
  return LinearImage.fromNativeHandle(res)!;
}

/// Lexicographically compares two images with tolerance [epsilon]. Returns 0 if equal.
int compareImages(LinearImage a, LinearImage b, {double epsilon = 0.0}) {
  return c.filament_image_compare(a.handle, b.handle, epsilon);
}

/// Sets all pixels in all channels to [value].
void clearToValue(LinearImage img, double value) {
  c.filament_image_clear_to_value(img.handle, value);
}
