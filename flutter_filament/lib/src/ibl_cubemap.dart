import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/src/linear_image.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// The 6 faces of a cubemap in standard Filament/OpenGL order.
enum IblCubemapFace {
  px(c.FilCubemapFace.FIL_CUBEMAP_FACE_PX),
  nx(c.FilCubemapFace.FIL_CUBEMAP_FACE_NX),
  py(c.FilCubemapFace.FIL_CUBEMAP_FACE_PY),
  ny(c.FilCubemapFace.FIL_CUBEMAP_FACE_NY),
  pz(c.FilCubemapFace.FIL_CUBEMAP_FACE_PZ),
  nz(c.FilCubemapFace.FIL_CUBEMAP_FACE_NZ);

  final c.FilCubemapFace _cEnum;
  const IblCubemapFace(this._cEnum);
  int get value => _cEnum.value;
}

/// A 3-channel (RGB float) CPU image used in the IBL pipeline.
class IblImage implements ffi.Finalizable {
  ffi.Pointer<c.FilIblImage>? _handle;
  Float32List? _data;
  final int width;
  final int height;

  /// The finalizer must be a real C function: the garbage collector runs it
  /// off the mutator thread, and a `Pointer.fromFunction` trampoline into Dart
  /// aborts the VM there ("Native callbacks must be invoked on the mutator
  /// thread"). `filament_ibl_image_destroy` frees only the wrapper.
  static final ffi.NativeFinalizer _finalizer = ffi.NativeFinalizer(
    ffi.Native.addressOf<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<c.FilIblImage>)>>(
      c.filament_ibl_image_destroy,
    ).cast(),
  );

  IblImage(this.width, this.height) {
    final ptr = c.filament_ibl_image_create(width, height);
    if (ptr == ffi.nullptr) throw StateError('Failed to create IblImage');
    _handle = ptr;
    final dataPtr = c.filament_ibl_image_get_data(ptr);
    _data = dataPtr.asTypedList(width * height * 3);
    _finalizer.attach(this, ptr.cast<ffi.Void>(), detach: this);
  }

  IblImage._fromHandle(ffi.Pointer<c.FilIblImage> handle)
      : _handle = handle,
        width = c.filament_ibl_image_get_width(handle),
        height = c.filament_ibl_image_get_height(handle) {
    final dataPtr = c.filament_ibl_image_get_data(handle);
    if (isContiguous) {
      _data = dataPtr.asTypedList(width * height * 3);
    } else {
      // Sub-image of a larger image (e.g. a cubemap face inside the cross):
      // rows are strided, so expose a tight per-row copy. Writes go through
      // [setPixel] which honours the stride.
      _data = _copyRows(dataPtr);
    }
    _finalizer.attach(this, handle.cast<ffi.Void>(), detach: this);
  }

  /// Row stride in bytes as stored natively.
  int get bytesPerRow => c.filament_ibl_image_get_bytes_per_row(handle);

  /// True when rows are packed (`bytesPerRow == width * 3 * 4`) and [data] is
  /// a live view; false for cubemap face sub-images where [data] is a copy.
  bool get isContiguous => bytesPerRow == width * 3 * 4;

  Float32List _copyRows(ffi.Pointer<ffi.Float> dataPtr) {
    final stride = bytesPerRow ~/ 4; // floats per native row
    final rowFloats = width * 3;
    final out = Float32List(width * height * 3);
    final view = dataPtr.asTypedList(stride * (height - 1) + rowFloats);
    for (var y = 0; y < height; y++) {
      out.setRange(y * rowFloats, (y + 1) * rowFloats, view, y * stride);
    }
    return out;
  }

  /// Fills every pixel with the given RGB value (stride-aware).
  void fill(double r, double g, double b) {
    final stride = bytesPerRow ~/ 4;
    final p = c.filament_ibl_image_get_data(handle);
    for (var y = 0; y < height; y++) {
      var base = y * stride;
      for (var x = 0; x < width; x++) {
        p[base] = r;
        p[base + 1] = g;
        p[base + 2] = b;
        base += 3;
      }
    }
    if (!isContiguous && _data != null) {
      final d = _data!;
      for (var i = 0; i < d.length; i += 3) {
        d[i] = r;
        d[i + 1] = g;
        d[i + 2] = b;
      }
    }
  }

  /// Writes tightly packed RGB floats (`width * height * 3`) into the image,
  /// honouring the native row stride.
  void writeData(Float32List tight) {
    if (tight.length != width * height * 3) {
      throw ArgumentError.value(tight.length, 'tight.length', 'expected ${width * height * 3}');
    }
    final stride = bytesPerRow ~/ 4;
    final rowFloats = width * 3;
    final p = c.filament_ibl_image_get_data(handle);
    final view = p.asTypedList(stride * (height - 1) + rowFloats);
    for (var y = 0; y < height; y++) {
      view.setRange(y * stride, y * stride + rowFloats, tight, y * rowFloats);
    }
    if (!isContiguous && _data != null) _data!.setAll(0, tight);
  }

  /// Reads one RGB pixel honouring the native stride.
  List<double> getPixel(int x, int y) {
    final stride = bytesPerRow ~/ 4;
    final p = c.filament_ibl_image_get_data(handle);
    final base = y * stride + x * 3;
    return [p[base], p[base + 1], p[base + 2]];
  }

  /// Writes one RGB pixel honouring the native stride (works for face
  /// sub-images too); keeps [data] in sync for strided images.
  void setPixel(int x, int y, double r, double g, double b) {
    final stride = bytesPerRow ~/ 4;
    final p = c.filament_ibl_image_get_data(handle);
    final base = y * stride + x * 3;
    p[base] = r;
    p[base + 1] = g;
    p[base + 2] = b;
    if (!isContiguous && _data != null) {
      final i = (y * width + x) * 3;
      _data![i] = r;
      _data![i + 1] = g;
      _data![i + 2] = b;
    }
  }

  static IblImage? fromNativeHandle(ffi.Pointer<c.FilIblImage> handle) {
    if (handle == ffi.nullptr) return null;
    return IblImage._fromHandle(handle);
  }

  factory IblImage.fromLinearImage(LinearImage img) {
    final ptr = c.filament_ibl_image_from_linear_image(img.handle);
    if (ptr == ffi.nullptr) throw StateError('Failed to create IblImage from LinearImage');
    return IblImage._fromHandle(ptr);
  }

  LinearImage toLinearImage() {
    final ptr = c.filament_ibl_image_to_linear_image(handle);
    if (ptr == ffi.nullptr) throw StateError('Failed to convert IblImage to LinearImage');
    return LinearImage.fromNativeHandle(ptr)!;
  }

  ffi.Pointer<c.FilIblImage> get handle {
    final h = _handle;
    if (h == null || h == ffi.nullptr) throw StateError('IblImage is disposed');
    return h;
  }

  /// RGB float pixels, row-major, tightly packed. For contiguous images this
  /// is a live view of native memory (writes take effect immediately); for
  /// strided sub-images (see [isContiguous]) it is a snapshot — use
  /// [setPixel] to write.
  Float32List get data {
    final d = _data;
    if (d == null || _handle == null) throw StateError('IblImage is disposed');
    // On the web a heap growth detaches earlier views: re-derive
    // (strided sub-images hold a Dart copy, which never detaches).
    if (d.lengthInBytes == 0 && isContiguous && width * height > 0) {
      return _data = c.filament_ibl_image_get_data(_handle!).asTypedList(width * height * 3);
    }
    return d;
  }

  void destroy() {
    final h = _handle;
    if (h != null && h != ffi.nullptr) {
      _finalizer.detach(this);
      c.filament_ibl_image_destroy(h);
      _handle = null;
      _data = null;
    }
  }
}

/// A CPU cubemap consisting of 6 square [IblImage] faces with dimensions [dimensions] x [dimensions].
class IblCubemap implements ffi.Finalizable {
  ffi.Pointer<c.FilIblCubemap>? _handle;
  final int dimensions;

  /// A real C function pointer — see the note on [IblImage]'s finalizer.
  static final ffi.NativeFinalizer _finalizer = ffi.NativeFinalizer(
    ffi.Native.addressOf<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<c.FilIblCubemap>)>>(
      c.filament_cubemap_destroy,
    ).cast(),
  );

  IblCubemap(this.dimensions) {
    final ptr = c.filament_cubemap_create(dimensions);
    if (ptr == ffi.nullptr) throw StateError('Failed to create IblCubemap');
    _handle = ptr;
    _finalizer.attach(this, ptr.cast<ffi.Void>(), detach: this);
  }

  IblCubemap._fromHandle(ffi.Pointer<c.FilIblCubemap> handle)
      : _handle = handle,
        dimensions = c.filament_cubemap_get_dimensions(handle) {
    _finalizer.attach(this, handle.cast<ffi.Void>(), detach: this);
  }

  static IblCubemap? fromNativeHandle(ffi.Pointer<c.FilIblCubemap> handle) {
    if (handle == ffi.nullptr) return null;
    return IblCubemap._fromHandle(handle);
  }

  ffi.Pointer<c.FilIblCubemap> get handle {
    final h = _handle;
    if (h == null || h == ffi.nullptr) throw StateError('IblCubemap is disposed');
    return h;
  }

  IblImage faceImage(IblCubemapFace face) {
    final ptr = c.filament_cubemap_get_face_image(handle, face.value);
    if (ptr == ffi.nullptr) throw StateError('Failed to get face image');
    return IblImage.fromNativeHandle(ptr)!;
  }

  void destroy() {
    final h = _handle;
    if (h != null && h != ffi.nullptr) {
      _finalizer.detach(this);
      c.filament_cubemap_destroy(h);
      _handle = null;
    }
  }
}

/// Utility conversions for CPU cubemaps and equirectangular environments.
class CubemapUtils {
  static void equirectangularToCubemap(IblCubemap dst, IblImage src) {
    c.filament_cubemap_utils_equirect_to_cubemap(dst.handle, src.handle);
  }

  static void cubemapToEquirectangular(IblImage dst, IblCubemap src) {
    c.filament_cubemap_utils_cubemap_to_equirect(dst.handle, src.handle);
  }

  static void setAllFacesFromCross(IblCubemap cMap, IblImage cross) {
    c.filament_cubemap_utils_set_all_faces_from_cross(cMap.handle, cross.handle);
  }

  static IblCubemap crossToCubemap(IblImage cross) {
    final ptr = c.filament_cubemap_utils_cross_to_cubemap(cross.handle);
    if (ptr == ffi.nullptr) throw StateError('Failed to convert cross to cubemap');
    return IblCubemap.fromNativeHandle(ptr)!;
  }

  static void cubemapToOctahedron(IblImage dst, IblCubemap src) {
    c.filament_cubemap_utils_cubemap_to_octahedron(dst.handle, src.handle);
  }

  static void mirrorCubemap(IblCubemap dst, IblCubemap src) {
    c.filament_cubemap_utils_mirror_cubemap(dst.handle, src.handle);
  }

  static void downsampleCubemapLevelBoxFilter(IblCubemap dst, IblCubemap src) {
    c.filament_cubemap_utils_downsample_boxfilter(dst.handle, src.handle);
  }

  static void makeSeamless(IblCubemap cMap) {
    c.filament_cubemap_utils_make_seamless(cMap.handle);
  }
}
