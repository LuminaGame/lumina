/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

/// Web builds: the WebAssembly module
/// (`web/flutter_filament.{js,wasm}`, built by `tool/web/build_module.sh`) and
/// its linear memory. Everything the web `dart:ffi` layer reads or writes goes
/// through here.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// The Emscripten module instance (`MODULARIZE=1`, `EXPORT_NAME=FlutterFilament`).
extension type FlutterFilamentJs._(JSObject _) implements JSObject {
  // ignore: non_constant_identifier_names
  external JSUint8Array get HEAPU8;
  external JSNumber _malloc(JSNumber size);
  external void _free(JSNumber pointer);
  external JSNumber addFunction(JSFunction function, JSString signature);
  external void removeFunction(JSNumber index);
}

@JS('FlutterFilament')
external JSFunction? get _factory;

@JS('BigInt')
external JSBigInt _jsBigInt(JSAny value);

@JS('String')
external JSString _jsString(JSAny value);

/// Loads and holds the module. Desktop code never touches this.
abstract final class FlutterFilamentModule {
  static FlutterFilamentJs? _instance;
  static Future<void>? _loading;

  /// Whether [load] has completed.
  static bool get isLoaded => _instance != null;

  /// The loaded module. Throws when [load] has not completed.
  static FlutterFilamentJs get instance =>
      _instance ??
      (throw StateError('flutter_filament: the WebAssembly module is not loaded; await FlutterFilamentModule.load() first'));

  /// Loads `flutter_filament.js` from [scriptUrl] (unless the page already
  /// did) and instantiates the module; the `.wasm` is fetched from the same
  /// directory. Idempotent.
  static Future<void> load({String scriptUrl = 'flutter_filament.js'}) {
    return _loading ??= _load(scriptUrl);
  }

  static Future<void> _load(String scriptUrl) async {
    if (_factory == null) {
      final script = web.document.createElement('script') as web.HTMLScriptElement;
      script.src = scriptUrl;
      final loaded = Completer<void>();
      script.onload = ((web.Event _) => loaded.complete()).toJS;
      script.onerror = ((web.Event _) => loaded.completeError(StateError('flutter_filament: could not load $scriptUrl'))).toJS;
      web.document.head!.append(script);
      await loaded.future;
    }
    final base = scriptUrl.contains('/') ? scriptUrl.substring(0, scriptUrl.lastIndexOf('/') + 1) : '';
    final options = JSObject();
    options['locateFile'] = ((JSString path, JSString prefix) => '$base${path.toDart}'.toJS).toJS;
    final promise = _factory!.callAsFunction(null, options) as JSPromise<JSObject>;
    _instance = FlutterFilamentJs._(await promise.toDart);
    _heapJs = null;
    for (final register in _onLoad) {
      register();
    }
  }

  static final List<void Function()> _onLoad = [];

  /// Runs [register] once the module is loaded (immediately if it is).
  static void whenLoaded(void Function() register) {
    if (isLoaded) {
      register();
    } else {
      _onLoad.add(register);
    }
  }

  // --- linear memory ---------------------------------------------------------

  static JSUint8Array? _heapJs;
  static ByteData? _heapData;
  static Uint8List? _heapBytes;

  /// The module's memory as [ByteData]. Re-derived when the heap has grown
  /// (Emscripten replaces `HEAPU8` and detaches the old buffer).
  static ByteData get heap {
    _refresh();
    return _heapData!;
  }

  /// The module's memory as bytes (same backing buffer as [heap]).
  static Uint8List get heapBytes {
    _refresh();
    return _heapBytes!;
  }

  static void _refresh() {
    final current = instance.HEAPU8;
    if (!identical(current, _heapJs) || _heapData == null) {
      _heapJs = current;
      final bytes = current.toDart;
      _heapBytes = bytes;
      _heapData = bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
    }
  }

  static int malloc(int size) => instance._malloc(size.toJS).toDartInt;
  static void free(int address) => instance._free(address.toJS);

  // --- function table (callbacks, function pointers) -------------------------

  static final Map<int, JSFunction> _tableFunctions = {};

  /// Adds [function] to the module's function table with the wasm
  /// [signature] (`'vii'`, `'ifd'`, …) and returns its index — the value a C
  /// function pointer holds.
  static int addFunction(JSFunction function, String signature) {
    final index = instance.addFunction(function, signature.toJS).toDartInt;
    _tableFunctions[index] = function;
    return index;
  }

  static void removeFunction(int index) {
    _tableFunctions.remove(index);
    instance.removeFunction(index.toJS);
  }

  /// The JS function behind a table index added through [addFunction].
  static JSFunction? tableFunction(int index) => _tableFunctions[index];

  /// A module export (`'_filament_x'`) as a JS function.
  static JSFunction export(String symbol) => instance[symbol] as JSFunction;

  // --- canvases ---------------------------------------------------------------

  /// Makes [canvas] reachable by the C side as `'!<name>'` (Emscripten's
  /// `specialHTMLTargets`), whether or not it is in the document yet or
  /// inside a shadow root — Flutter's platform views may be either.
  static String registerCanvas(String name, JSObject canvas) {
    final targets = instance['specialHTMLTargets'] as JSObject;
    targets['!$name'] = canvas;
    return '!$name';
  }

  static void unregisterCanvas(String name) {
    if (!isLoaded) return;
    final targets = instance['specialHTMLTargets'] as JSObject;
    targets.delete('!$name'.toJS);
  }

  // --- 64-bit integers cross the JS boundary as BigInt ------------------------

  static JSBigInt toBigInt(int value) => _jsBigInt(value.toJS);

  /// A BigInt is a JS primitive, not an object: convert it with `String()`.
  static int fromBigInt(JSAny? value) {
    if (value == null) return 0;
    return int.parse(_jsString(value).toDart);
  }
}
