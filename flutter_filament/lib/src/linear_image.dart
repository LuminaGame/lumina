import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// A high-performance floating-point image holding packed 32-bit float channels
/// arranged into a row-major grid.
///
/// The underlying pixel buffer has shared ownership semantics. Dart gets a zero-copy
/// [Float32List] view over the underlying pixel buffer.
class LinearImage implements ffi.Finalizable {
  ffi.Pointer<c.FilLinearImage>? _handle;
  Float32List? _data;
  final int width;
  final int height;
  final int channels;

  /// A real C function pointer: the GC runs finalizers off the mutator
  /// thread, where a Dart trampoline aborts the VM.
  static final ffi.NativeFinalizer _finalizer = ffi.NativeFinalizer(
    ffi.Native.addressOf<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<c.FilLinearImage>)>>(
      c.filament_linear_image_destroy,
    ).cast(),
  );

  /// Allocates a zeroed-out image with dimensions [width] x [height] and [channels] components.
  LinearImage(this.width, this.height, this.channels) {
    if (width <= 0 || height <= 0 || channels <= 0) {
      throw ArgumentError('width, height, and channels must be positive');
    }
    final ptr = c.filament_linear_image_create(width, height, channels);
    if (ptr == ffi.nullptr) {
      throw StateError('Failed to create LinearImage');
    }
    _handle = ptr;
    final pixelPtr = c.filament_linear_image_get_pixel_data(ptr);
    _data = pixelPtr.asTypedList(width * height * channels);
    _finalizer.attach(this, ptr.cast<ffi.Void>(), detach: this);
  }

  /// Creates a [LinearImage] initialized with copies of [data].
  LinearImage.fromData(this.width, this.height, this.channels, Float32List data) {
    if (width <= 0 || height <= 0 || channels <= 0) {
      throw ArgumentError('width, height, and channels must be positive');
    }
    if (data.length != width * height * channels) {
      throw ArgumentError(
        'data length (${data.length}) must match width * height * channels ($width * $height * $channels = ${width * height * channels})',
      );
    }
    final ptr = c.filament_linear_image_create(width, height, channels);
    if (ptr == ffi.nullptr) {
      throw StateError('Failed to create LinearImage');
    }
    _handle = ptr;
    final pixelPtr = c.filament_linear_image_get_pixel_data(ptr);
    _data = pixelPtr.asTypedList(width * height * channels);
    _data!.setAll(0, data);
    _finalizer.attach(this, ptr.cast<ffi.Void>(), detach: this);
  }

  LinearImage._fromHandle(ffi.Pointer<c.FilLinearImage> handle)
      : _handle = handle,
        width = c.filament_linear_image_get_width(handle),
        height = c.filament_linear_image_get_height(handle),
        channels = c.filament_linear_image_get_channels(handle) {
    final pixelPtr = c.filament_linear_image_get_pixel_data(handle);
    _data = pixelPtr.asTypedList(width * height * channels);
    _finalizer.attach(this, handle.cast<ffi.Void>(), detach: this);
  }

  /// Wraps a native handle or returns `null` if the pointer is null.
  static LinearImage? fromNativeHandle(ffi.Pointer<c.FilLinearImage> handle) {
    if (handle == ffi.nullptr) return null;
    return LinearImage._fromHandle(handle);
  }

  /// The underlying native pointer.
  ffi.Pointer<c.FilLinearImage> get handle {
    final h = _handle;
    if (h == null || h == ffi.nullptr) {
      throw StateError('LinearImage has been destroyed');
    }
    return h;
  }

  /// Whether the underlying native image holds valid pixel storage.
  /// Returns false once the image is destroyed.
  bool get isValid {
    final h = _handle;
    if (h == null || h == ffi.nullptr) return false;
    return c.filament_linear_image_is_valid(h);
  }

  /// Whether this image has been disposed or destroyed.
  bool get isDisposed => _handle == null || _handle == ffi.nullptr;

  /// A zero-copy [Float32List] view over the underlying pixel buffer.
  Float32List get data {
    final d = _data;
    if (d == null || _handle == null) {
      throw StateError('LinearImage has been destroyed');
    }
    // On the web a heap growth detaches earlier views: re-derive.
    if (d.lengthInBytes == 0 && width * height * channels > 0) {
      return _data = c.filament_linear_image_get_pixel_data(_handle!).asTypedList(width * height * channels);
    }
    return d;
  }

  /// Convenience getter for reading a single channel component of pixel at (x, y).
  double getPixel(int x, int y, int channel) {
    if (x < 0 || x >= width || y < 0 || y >= height || channel < 0 || channel >= channels) {
      throw RangeError('Pixel coordinate ($x, $y, $channel) out of bounds ($width, $height, $channels)');
    }
    return data[(y * width + x) * channels + channel];
  }

  /// Convenience setter for modifying a single channel component of pixel at (x, y).
  void setPixel(int x, int y, int channel, double value) {
    if (x < 0 || x >= width || y < 0 || y >= height || channel < 0 || channel >= channels) {
      throw RangeError('Pixel coordinate ($x, $y, $channel) out of bounds ($width, $height, $channels)');
    }
    data[(y * width + x) * channels + channel] = value;
  }

  /// Creates a shallow copy of this image sharing the same underlying pixel block.
  LinearImage share() {
    final sharedHandle = c.filament_linear_image_share(handle);
    if (sharedHandle == ffi.nullptr) {
      throw StateError('Failed to share LinearImage');
    }
    return LinearImage._fromHandle(sharedHandle);
  }

  /// Explicitly destroys this image handle.
  void destroy() {
    final h = _handle;
    if (h != null && h != ffi.nullptr) {
      _finalizer.detach(this);
      c.filament_linear_image_destroy(h);
      _handle = null;
      _data = null;
    }
  }
}
