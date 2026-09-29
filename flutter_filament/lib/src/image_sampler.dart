import 'ffi_platform.dart' as ffi;
import 'ffi_package_platform.dart';
import 'package:flutter_filament/src/linear_image.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Filter methods used for sampling / resampling images.
enum ImageFilter {
  defaultFilter(c.FilImageFilter.FIL_IMAGE_FILTER_DEFAULT),
  box(c.FilImageFilter.FIL_IMAGE_FILTER_BOX),
  nearest(c.FilImageFilter.FIL_IMAGE_FILTER_NEAREST),
  hermite(c.FilImageFilter.FIL_IMAGE_FILTER_HERMITE),
  gaussianScalars(c.FilImageFilter.FIL_IMAGE_FILTER_GAUSSIAN_SCALARS),
  gaussianNormals(c.FilImageFilter.FIL_IMAGE_FILTER_GAUSSIAN_NORMALS),
  mitchell(c.FilImageFilter.FIL_IMAGE_FILTER_MITCHELL),
  lanczos(c.FilImageFilter.FIL_IMAGE_FILTER_LANCZOS),
  minimum(c.FilImageFilter.FIL_IMAGE_FILTER_MINIMUM);

  final c.FilImageFilter _cEnum;
  const ImageFilter(this._cEnum);
  int get value => _cEnum.value;
}

/// Boundary behavior when sampling outside image borders.
enum ImageBoundary {
  exclude(c.FilImageBoundary.FIL_IMAGE_BOUNDARY_EXCLUDE),
  region(c.FilImageBoundary.FIL_IMAGE_BOUNDARY_REGION),
  clampToEdge(c.FilImageBoundary.FIL_IMAGE_BOUNDARY_CLAMP),
  repeat(c.FilImageBoundary.FIL_IMAGE_BOUNDARY_REPEAT),
  mirror(c.FilImageBoundary.FIL_IMAGE_BOUNDARY_MIRROR),
  color(c.FilImageBoundary.FIL_IMAGE_BOUNDARY_COLOR),
  neighbor(c.FilImageBoundary.FIL_IMAGE_BOUNDARY_NEIGHBOR);

  final c.FilImageBoundary _cEnum;
  const ImageBoundary(this._cEnum);
  int get value => _cEnum.value;
}

/// Resizes or blurs [src], producing a new [LinearImage] with [width] x [height] dimensions.
LinearImage resampleImage(
  LinearImage src,
  int width,
  int height, {
  ImageFilter filter = ImageFilter.defaultFilter,
}) {
  final ptr = c.filament_image_resample(
    src.handle,
    width,
    height,
    filter.value,
  );
  if (ptr == ffi.nullptr) {
    throw StateError('Failed to resample LinearImage');
  }
  return LinearImage.fromNativeHandle(ptr)!;
}

/// Resizes a subregion of [src] with explicit boundary modes.
LinearImage resampleImageRegion(
  LinearImage src,
  int width,
  int height, {
  ImageFilter filter = ImageFilter.defaultFilter,
  double left = 0.0,
  double top = 0.0,
  double right = 1.0,
  double bottom = 1.0,
  ImageBoundary horizontalBoundary = ImageBoundary.exclude,
  ImageBoundary verticalBoundary = ImageBoundary.exclude,
}) {
  final ptr = c.filament_image_resample_region(
    src.handle,
    width,
    height,
    filter.value,
    left,
    top,
    right,
    bottom,
    horizontalBoundary.value,
    verticalBoundary.value,
  );
  if (ptr == ffi.nullptr) {
    throw StateError('Failed to resample LinearImage region');
  }
  return LinearImage.fromNativeHandle(ptr)!;
}

/// Returns the number of mipmap levels required to downsample [img] to 1x1 (excluding base).
int getMipmapCount(LinearImage img) {
  return c.filament_image_get_mipmap_count(img.handle);
}

/// Generates a full mipmap chain for [src] using [filter].
///
/// Returns a list of [LinearImage] levels from mip 1 (half resolution) down to 1x1.
List<LinearImage> generateMipmaps(
  LinearImage src, {
  ImageFilter filter = ImageFilter.defaultFilter,
}) {
  final count = getMipmapCount(src);
  if (count == 0) return [];
  return using((Arena arena) {
    final outLevels = arena<ffi.Pointer<c.FilLinearImage>>(count);
    c.filament_image_generate_mipmaps(
      src.handle,
      filter.value,
      outLevels,
      count,
    );
    final list = <LinearImage>[];
    for (var i = 0; i < count; i++) {
      final handle = outLevels[i];
      if (handle != ffi.nullptr) {
        list.add(LinearImage.fromNativeHandle(handle)!);
      }
    }
    return list;
  });
}
