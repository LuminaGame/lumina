import 'ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/linear_image.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Generates a 2-channel field of unnormalized coordinates pointing to the nearest pixel
/// where [src] component at [channel] > [threshold].
LinearImage computeCoordField(
  LinearImage src, {
  double threshold = 0.5,
  int channel = 0,
}) {
  final res = c.filament_image_compute_coord_field(
    src.handle,
    threshold,
    channel,
  );
  if (res == ffi.nullptr) throw StateError('Failed to computeCoordField');
  return LinearImage.fromNativeHandle(res)!;
}

/// Generates a 1-channel Euclidean distance field from [coordField].
LinearImage edtFromCoordField(
  LinearImage coordField, {
  bool sqrt = true,
}) {
  final res = c.filament_image_edt_from_coord_field(
    coordField.handle,
    sqrt,
  );
  if (res == ffi.nullptr) throw StateError('Failed to edtFromCoordField');
  return LinearImage.fromNativeHandle(res)!;
}

/// Dereferences the given coordinate field to propagate nearest feature pixel colors from [src].
LinearImage voronoiFromCoordField(
  LinearImage coordField,
  LinearImage src,
) {
  final res = c.filament_image_voronoi_from_coord_field(
    coordField.handle,
    src.handle,
  );
  if (res == ffi.nullptr) throw StateError('Failed to voronoiFromCoordField');
  return LinearImage.fromNativeHandle(res)!;
}

/// Generates a signed distance field (SDF) from a binary/coverage [mask].
LinearImage signedDistanceField(
  LinearImage mask, {
  double threshold = 0.5,
  int channel = 0,
}) {
  final coordInside = computeCoordField(mask, threshold: threshold, channel: channel);
  final distOutside = edtFromCoordField(coordInside, sqrt: true);

  // Inverted mask
  final inverted = LinearImage(mask.width, mask.height, 1);
  for (var i = 0; i < mask.width * mask.height; i++) {
    inverted.data[i] = mask.data[i * mask.channels + channel] > threshold ? 0.0 : 1.0;
  }
  final coordOutside = computeCoordField(inverted, threshold: 0.5, channel: 0);
  final distInside = edtFromCoordField(coordOutside, sqrt: true);

  // signed: outside positive, inside negative
  final sdf = LinearImage(mask.width, mask.height, 1);
  for (var i = 0; i < mask.width * mask.height; i++) {
    sdf.data[i] = distOutside.data[i] - distInside.data[i];
  }
  return sdf;
}

/// Dilates UV island boundaries into gutters using Voronoi nearest neighbor coloring.
LinearImage dilateUvIslands(
  LinearImage baked,
  LinearImage coverageMask, {
  double threshold = 0.5,
  int channel = 0,
}) {
  final coord = computeCoordField(coverageMask, threshold: threshold, channel: channel);
  return voronoiFromCoordField(coord, baked);
}
