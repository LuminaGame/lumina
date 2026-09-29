import 'dart:async';
import 'ffi_platform.dart' as ffi;
import 'ffi_package_platform.dart';

import 'filament_bindings.dart' as ffi_gen;

/// Represents an intercepted Filament `PANIC_PRECONDITION` or assertion.
class FilamentPanicException implements Exception {
  final String message;
  final String function;
  final String file;
  final int line;

  FilamentPanicException(this.message, this.function, this.file, this.line);

  @override
  String toString() {
    return 'FilamentPanicException: $message\n  at $function ($file:$line)';
  }
}

/// A log record emitted by Filament's internal engine.
class FilamentLogRecord {
  final int priority;
  final String tag;
  final String message;

  FilamentLogRecord(this.priority, this.tag, this.message);

  @override
  String toString() {
    return '[$tag] (Level $priority): $message';
  }
}

/// Provides a bridge to intercept Filament engine panics and internal logs.
class FilamentDiagnostics {
  static ffi.NativeCallable<ffi.Void Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>, ffi.Int, ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Void>)>? _panicCallable;
  static ffi.NativeCallable<ffi.Void Function(ffi.Int, ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Void>)>? _logCallable;
  
  static final _panicController = StreamController<FilamentPanicException>.broadcast();
  static final _logController = StreamController<FilamentLogRecord>.broadcast();

  /// Stream of Filament panics.
  static Stream<FilamentPanicException> get onPanic => _panicController.stream;

  /// Gets the last recorded panic message if one occurred.
  /// Used primarily as a synchronous fallback since NativeCallable.listener delivers asynchronously.
  static String? get lastPanic {
    final ptr = calloc<ffi.Char>(1024);
    try {
      final hasPanic = ffi_gen.filament_get_last_panic(ptr, 1024);
      if (hasPanic) {
        return ptr.cast<Utf8>().toDartString();
      }
      return null;
    } finally {
      calloc.free(ptr);
    }
  }

  /// Installs the panic handler. Filament panics will be thrown asynchronously 
  /// into the Dart isolate.
  static void installPanicHandler() {
    if (_panicCallable != null) return;

    _panicCallable = ffi.NativeCallable.listener((ffi.Pointer<ffi.Char> func, ffi.Pointer<ffi.Char> file, int line, ffi.Pointer<ffi.Char> msg, ffi.Pointer<ffi.Void> user) {
      final functionName = func != ffi.nullptr ? func.cast<Utf8>().toDartString() : 'unknown';
      final fileName = file != ffi.nullptr ? file.cast<Utf8>().toDartString() : 'unknown';
      final message = msg != ffi.nullptr ? msg.cast<Utf8>().toDartString() : 'Panic';
      
      if (func != ffi.nullptr) ffi_gen.filament_free_string(func);
      if (file != ffi.nullptr) ffi_gen.filament_free_string(file);
      if (msg != ffi.nullptr) ffi_gen.filament_free_string(msg);
      
      _panicController.add(FilamentPanicException(message, functionName, fileName, line));
    });

    ffi_gen.filament_set_panic_handler(_panicCallable!.nativeFunction.cast(), ffi.nullptr);
  }

  /// Clears the panic handler, allowing panics to crash the process.
  static void clearPanicHandler() {
    ffi_gen.filament_clear_panic_handler();
    _panicCallable?.close();
    _panicCallable = null;
  }

  /// Stream of Filament internal logs (warnings, errors, etc.)
  static Stream<FilamentLogRecord> get onLog => _logController.stream;

  /// Installs the log handler to route `slog` output to `onLog` stream.
  static void installLogHandler() {
    if (_logCallable != null) return;

    _logCallable = ffi.NativeCallable.listener((int priority, ffi.Pointer<ffi.Char> tag, ffi.Pointer<ffi.Char> msg, ffi.Pointer<ffi.Void> user) {
      final tagStr = tag != ffi.nullptr ? tag.cast<Utf8>().toDartString() : 'Filament';
      final message = msg != ffi.nullptr ? msg.cast<Utf8>().toDartString() : '';
      
      if (tag != ffi.nullptr) ffi_gen.filament_free_string(tag);
      if (msg != ffi.nullptr) ffi_gen.filament_free_string(msg);
      
      _logController.add(FilamentLogRecord(priority, tagStr, message));
    });

    ffi_gen.filament_set_log_callback(_logCallable!.nativeFunction.cast(), ffi.nullptr);
  }

  /// Clears the log handler.
  static void clearLogHandler() {
    ffi_gen.filament_clear_log_callback();
    _logCallable?.close();
    _logCallable = null;
  }

  /// Triggers a test panic on the C++ side.
  static void testTriggerPanic() {
    ffi_gen.filament_test_trigger_panic();
  }

  /// Sends a test log to `slog.w` on the C++ side.
  static void testLog(String message) {
    final ptr = message.toNativeUtf8();
    ffi_gen.filament_test_log(ptr.cast());
    calloc.free(ptr);
  }
}
