import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_filament/src/ffi_package_platform.dart';
import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/renderer.dart';

/// One frame read back from the GPU: its pixels (RGBA8, [width] × [height],
/// bottom row first as Filament reads them) and the CPU time its submission
/// took.
class FilamentReadbackFrame {
  final int width;
  final int height;
  final Uint8List pixels;
  final Duration cpu;

  const FilamentReadbackFrame(this.width, this.height, this.pixels, this.cpu);
}

class _Slot {
  final ffi.Pointer<ffi.Uint8> buffer;
  final int width;
  final int height;
  final Duration cpu;
  int waitedTicks = 0;

  _Slot(this.buffer, this.width, this.height, this.cpu);
}

/// The texture path's readbacks, pipelined: a frame's pixels are read back
/// asynchronously ([submit] queues the read with the frame, Filament calls
/// back once the GPU wrote them) so the UI thread never waits for the GPU,
/// and up to [maxInFlight] frames are on the GPU while the CPU prepares the
/// next one. Completed frames arrive in submission order through [onFrame].
///
/// Filament runs the callbacks when its message queues are pumped:
/// [poll] does that every tick, also while no frame is submitted.
class FilamentTextureReadback {
  FilamentTextureReadback({required this.onFrame, this.maxInFlight = 2});

  /// Frames on the GPU at once.
  final int maxInFlight;

  /// A frame's pixels are ready.
  final void Function(FilamentReadbackFrame frame) onFrame;

  /// After this many [poll]s without a readback completing, the oldest is
  /// forced (the engine waits for the GPU once), so a backend that never
  /// calls back cannot stall the viewport.
  static const int stallTicks = 120;

  static int _nextToken = 1;
  static final Map<int, (FilamentTextureReadback, _Slot)> _pending = {};

  /// One listener for every readback, made in the root zone: it outlives
  /// the zone of whichever widget asked first.
  static ffi.NativeCallable<c.FilamentReadPixelsCallbackFunction>? _callable;

  static ffi.Pointer<ffi.NativeFunction<c.FilamentReadPixelsCallbackFunction>> get _callback =>
      (_callable ??= Zone.root.run<ffi.NativeCallable<c.FilamentReadPixelsCallbackFunction>>(
        () => ffi.NativeCallable<c.FilamentReadPixelsCallbackFunction>.listener(_onRead),
      )).nativeFunction;

  static void _onRead(ffi.Pointer<ffi.Void> buffer, ffi.Pointer<ffi.Void> user) {
    final entry = _pending.remove(user.address);
    if (entry == null) return;
    entry.$1._complete(entry.$2);
  }

  final List<_Slot> _inFlight = [];
  final List<_Slot> _free = [];
  bool _disposed = false;

  /// Frames submitted and not yet read back.
  int get inFlight => _inFlight.length;

  /// Whether another frame may be submitted now.
  bool get canSubmit => !_disposed && _inFlight.length < maxInFlight;

  /// Queues the read of the frame being rendered ([renderer] between
  /// `beginFrame` and `endFrame`), [width] × [height] from the origin.
  void submit(FilamentRenderer renderer, FilamentEngine engine, int width, int height, Duration cpu) {
    if (_disposed) return;
    final slot = _take(width, height, cpu);
    final token = _nextToken++;
    _pending[token] = (this, slot);
    _inFlight.add(slot);
    c.filament_renderer_read_pixels(
      renderer.nativePointer,
      engine.nativePointer,
      0,
      0,
      width,
      height,
      slot.buffer,
      _callback,
      ffi.Pointer<ffi.Void>.fromAddress(token),
    );
  }

  /// Lets the driver deliver finished reads and runs Filament's pending
  /// callbacks; forces the oldest readback after
  /// [stallTicks] polls without progress.
  void poll(FilamentEngine engine) {
    if (_disposed || _inFlight.isEmpty) return;
    // An empty flush lets the driver thread run: it hands the finished
    // reads to the callbacks, which the pump then calls.
    engine.flush();
    engine.pumpMessageQueues();
    if (_inFlight.isEmpty) return;
    final oldest = _inFlight.first;
    if (++oldest.waitedTicks < stallTicks) return;
    // The GPU is done with everything after this: the pixels are written.
    engine.flushAndWait();
    engine.pumpMessageQueues();
    if (_inFlight.isNotEmpty && identical(_inFlight.first, oldest)) {
      _pending.removeWhere((_, e) => identical(e.$2, oldest));
      _complete(oldest);
    }
  }

  _Slot _take(int width, int height, Duration cpu) {
    final i = _free.indexWhere((s) => s.width == width && s.height == height);
    final buffer = i >= 0 ? _free.removeAt(i).buffer : calloc<ffi.Uint8>(width * height * 4);
    return _Slot(buffer, width, height, cpu);
  }

  void _complete(_Slot slot) {
    if (_disposed || !_inFlight.remove(slot)) return;
    final pixels = Uint8List.fromList(slot.buffer.asTypedList(slot.width * slot.height * 4));
    // Keep one spare buffer per size the frames have now.
    _free.removeWhere((s) {
      if (s.width == slot.width && s.height == slot.height) return false;
      calloc.free(s.buffer);
      return true;
    });
    if (_free.length < maxInFlight) {
      _free.add(slot);
    } else {
      calloc.free(slot.buffer);
    }
    onFrame(FilamentReadbackFrame(slot.width, slot.height, pixels, slot.cpu));
  }

  /// Frees every buffer. The caller has waited for the GPU first
  /// (`flushAndWait`), so no read still writes into one.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending.removeWhere((_, e) => identical(e.$1, this));
    for (final s in [..._inFlight, ..._free]) {
      calloc.free(s.buffer);
    }
    _inFlight.clear();
    _free.clear();
  }
}
