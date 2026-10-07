/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

/// Web builds: the subset of `dart:ffi` flutter_filament uses,
/// implemented over the WebAssembly module's linear memory. On desktop,
/// `ffi_platform.dart` exports the real `dart:ffi` instead, so the same wrapper
/// code runs on both.
///
/// A [Pointer] is a byte address in the module's memory (wasm32: pointers and
/// `size_t` are 4 bytes). [Struct]s are views at an address; their accessors
/// are generated (tool/ffigen_web.dart).
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_filament/src/web_ffi/module.dart';

const Endian _le = Endian.little;
ByteData get _heap => FlutterFilamentModule.heap;

// --- native types --------------------------------------------------------------

abstract class NativeType {
  const NativeType();
}

/// A native type whose size is known (`sizeOf` works on it).
abstract class SizedNativeType extends NativeType {
  const SizedNativeType();
}

final class Void extends NativeType {
  const Void();
}

abstract class Opaque extends NativeType {
  const Opaque();
}

final class Bool extends SizedNativeType {
  const Bool();
}

final class Int8 extends SizedNativeType {
  const Int8();
}

final class Uint8 extends SizedNativeType {
  const Uint8();
}

final class Int16 extends SizedNativeType {
  const Int16();
}

final class Uint16 extends SizedNativeType {
  const Uint16();
}

final class Int32 extends SizedNativeType {
  const Int32();
}

final class Uint32 extends SizedNativeType {
  const Uint32();
}

final class Int64 extends SizedNativeType {
  const Int64();
}

final class Uint64 extends SizedNativeType {
  const Uint64();
}

final class Float extends SizedNativeType {
  const Float();
}

final class Double extends SizedNativeType {
  const Double();
}

/// C `char` (signed on wasm32).
final class Char extends SizedNativeType {
  const Char();
}

final class Int extends SizedNativeType {
  const Int();
}

final class UnsignedInt extends SizedNativeType {
  const UnsignedInt();
}

final class Size extends SizedNativeType {
  const Size();
}

final class IntPtr extends SizedNativeType {
  const IntPtr();
}

final class UintPtr extends SizedNativeType {
  const UintPtr();
}

final class NativeFunction<T extends Function> extends NativeType {
  const NativeFunction();
}

// --- pointers --------------------------------------------------------------------

final class Pointer<T extends NativeType> extends SizedNativeType {
  /// The byte address in the module's linear memory.
  final int address;

  const Pointer.fromAddress(this.address);

  Pointer<U> cast<U extends NativeType>() => Pointer<U>.fromAddress(address);

  @override
  bool operator ==(Object other) => other is Pointer && other.address == address;

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() => 'Pointer: address=0x${address.toRadixString(16)}';
}

/// The null pointer.
const Pointer<Never> nullptr = Pointer<Never>.fromAddress(0);

// --- sizes -----------------------------------------------------------------------

final class _Layout {
  final int size;
  final int alignment;
  final Object Function(int address)? view;
  const _Layout(this.size, this.alignment, [this.view]);
}

final Map<Type, _Layout> _layouts = {
  Bool: const _Layout(1, 1),
  Int8: const _Layout(1, 1),
  Uint8: const _Layout(1, 1),
  Char: const _Layout(1, 1),
  Int16: const _Layout(2, 2),
  Uint16: const _Layout(2, 2),
  Int32: const _Layout(4, 4),
  Uint32: const _Layout(4, 4),
  Int: const _Layout(4, 4),
  UnsignedInt: const _Layout(4, 4),
  Size: const _Layout(4, 4),
  IntPtr: const _Layout(4, 4),
  UintPtr: const _Layout(4, 4),
  Float: const _Layout(4, 4),
  Int64: const _Layout(8, 8),
  Uint64: const _Layout(8, 8),
  Double: const _Layout(8, 8),
};

/// Registers a generated struct or union view (tool/ffigen_web.dart).
void $registerStruct<T extends NativeType>(int size, int alignment, T Function(int address) view) {
  _layouts[T] = _Layout(size, alignment, view);
}

_Layout _layoutOf<T>() {
  final layout = _layouts[T];
  if (layout != null) return layout;
  // Every Pointer<X> is 4 bytes on wasm32, whatever X is.
  if (<T>[] is List<Pointer>) return const _Layout(4, 4);
  throw UnsupportedError('flutter_filament web: no size for $T (unregistered struct?)');
}

int sizeOf<T extends NativeType>() => _layoutOf<T>().size;

/// Alignment used by the allocators.
int $alignOf<T extends NativeType>() => _layoutOf<T>().alignment;

// --- structs, unions, inline arrays ------------------------------------------------

abstract class Struct extends SizedNativeType {
  /// Where this view sits in the module's memory.
  final int $address;
  Struct.$at(this.$address);
}

abstract class Union extends SizedNativeType {
  final int $address;
  Union.$at(this.$address);
}

/// `@Array(n)` / `@Array.multi([...])` annotations, and inline-array views.
final class Array<T extends NativeType> extends NativeType {
  final int dimension1;
  final List<int>? dimensions;
  final int $address;
  final int $length;

  const Array(this.dimension1)
      : dimensions = null,
        $address = 0,
        $length = 0;

  const Array.multi(List<int> this.dimensions)
      : dimension1 = 0,
        $address = 0,
        $length = 0;

  const Array.$view(this.$address, this.$length)
      : dimension1 = 0,
        dimensions = null;

  int get length => $length;
}

// --- typed access ---------------------------------------------------------------

extension Int8Pointer on Pointer<Int8> {
  int get value => _heap.getInt8(address);
  set value(int v) => _heap.setInt8(address, v);
  int operator [](int i) => _heap.getInt8(address + i);
  void operator []=(int i, int v) => _heap.setInt8(address + i, v);
  Int8List asTypedList(int length) => FlutterFilamentModule.heapBytes.buffer.asInt8List(address, length);
  Pointer<Int8> operator +(int n) => Pointer<Int8>.fromAddress(address + n);
  Pointer<Int8> operator -(int n) => Pointer<Int8>.fromAddress(address - n);
}

extension CharPointer on Pointer<Char> {
  int get value => _heap.getInt8(address);
  set value(int v) => _heap.setInt8(address, v);
  int operator [](int i) => _heap.getInt8(address + i);
  void operator []=(int i, int v) => _heap.setInt8(address + i, v);
  Pointer<Char> operator +(int n) => Pointer<Char>.fromAddress(address + n);
}

extension Uint8Pointer on Pointer<Uint8> {
  int get value => _heap.getUint8(address);
  set value(int v) => _heap.setUint8(address, v);
  int operator [](int i) => _heap.getUint8(address + i);
  void operator []=(int i, int v) => _heap.setUint8(address + i, v);
  Uint8List asTypedList(int length) => FlutterFilamentModule.heapBytes.buffer.asUint8List(address, length);
  Pointer<Uint8> operator +(int n) => Pointer<Uint8>.fromAddress(address + n);
  Pointer<Uint8> operator -(int n) => Pointer<Uint8>.fromAddress(address - n);
}

extension BoolPointer on Pointer<Bool> {
  bool get value => _heap.getUint8(address) != 0;
  set value(bool v) => _heap.setUint8(address, v ? 1 : 0);
  bool operator [](int i) => _heap.getUint8(address + i) != 0;
  void operator []=(int i, bool v) => _heap.setUint8(address + i, v ? 1 : 0);
  Pointer<Bool> operator +(int n) => Pointer<Bool>.fromAddress(address + n);
}

extension Int16Pointer on Pointer<Int16> {
  int get value => _heap.getInt16(address, _le);
  set value(int v) => _heap.setInt16(address, v, _le);
  int operator [](int i) => _heap.getInt16(address + 2 * i, _le);
  void operator []=(int i, int v) => _heap.setInt16(address + 2 * i, v, _le);
  Int16List asTypedList(int length) => FlutterFilamentModule.heapBytes.buffer.asInt16List(address, length);
  Pointer<Int16> operator +(int n) => Pointer<Int16>.fromAddress(address + 2 * n);
}

extension Uint16Pointer on Pointer<Uint16> {
  int get value => _heap.getUint16(address, _le);
  set value(int v) => _heap.setUint16(address, v, _le);
  int operator [](int i) => _heap.getUint16(address + 2 * i, _le);
  void operator []=(int i, int v) => _heap.setUint16(address + 2 * i, v, _le);
  Uint16List asTypedList(int length) => FlutterFilamentModule.heapBytes.buffer.asUint16List(address, length);
  Pointer<Uint16> operator +(int n) => Pointer<Uint16>.fromAddress(address + 2 * n);
}

extension Int32Pointer on Pointer<Int32> {
  int get value => _heap.getInt32(address, _le);
  set value(int v) => _heap.setInt32(address, v, _le);
  int operator [](int i) => _heap.getInt32(address + 4 * i, _le);
  void operator []=(int i, int v) => _heap.setInt32(address + 4 * i, v, _le);
  Int32List asTypedList(int length) => FlutterFilamentModule.heapBytes.buffer.asInt32List(address, length);
  Pointer<Int32> operator +(int n) => Pointer<Int32>.fromAddress(address + 4 * n);
}

extension IntPointer on Pointer<Int> {
  int get value => _heap.getInt32(address, _le);
  set value(int v) => _heap.setInt32(address, v, _le);
  int operator [](int i) => _heap.getInt32(address + 4 * i, _le);
  void operator []=(int i, int v) => _heap.setInt32(address + 4 * i, v, _le);
  Pointer<Int> operator +(int n) => Pointer<Int>.fromAddress(address + 4 * n);
}

extension Uint32Pointer on Pointer<Uint32> {
  int get value => _heap.getUint32(address, _le);
  set value(int v) => _heap.setUint32(address, v, _le);
  int operator [](int i) => _heap.getUint32(address + 4 * i, _le);
  void operator []=(int i, int v) => _heap.setUint32(address + 4 * i, v, _le);
  Uint32List asTypedList(int length) => FlutterFilamentModule.heapBytes.buffer.asUint32List(address, length);
  Pointer<Uint32> operator +(int n) => Pointer<Uint32>.fromAddress(address + 4 * n);
}

extension UnsignedIntPointer on Pointer<UnsignedInt> {
  int get value => _heap.getUint32(address, _le);
  set value(int v) => _heap.setUint32(address, v, _le);
  int operator [](int i) => _heap.getUint32(address + 4 * i, _le);
  void operator []=(int i, int v) => _heap.setUint32(address + 4 * i, v, _le);
}

extension SizePointer on Pointer<Size> {
  int get value => _heap.getUint32(address, _le);
  set value(int v) => _heap.setUint32(address, v, _le);
  int operator [](int i) => _heap.getUint32(address + 4 * i, _le);
  void operator []=(int i, int v) => _heap.setUint32(address + 4 * i, v, _le);
}

extension Int64Pointer on Pointer<Int64> {
  int get value => _getInt64(address);
  set value(int v) => _setInt64(address, v);
  int operator [](int i) => _getInt64(address + 8 * i);
  void operator []=(int i, int v) => _setInt64(address + 8 * i, v);
}

extension Uint64Pointer on Pointer<Uint64> {
  int get value => _getInt64(address);
  set value(int v) => _setInt64(address, v);
  int operator [](int i) => _getInt64(address + 8 * i);
  void operator []=(int i, int v) => _setInt64(address + 8 * i, v);
}

/// 64-bit reads and writes for generated struct fields.
int $readInt64(int address) => _getInt64(address);
void $writeInt64(int address, int v) => _setInt64(address, v);

// JS numbers hold 53 bits: 64-bit values are read and written as two halves.
int _getInt64(int address) {
  final lo = _heap.getUint32(address, _le);
  final hi = _heap.getInt32(address + 4, _le);
  return hi * 0x100000000 + lo;
}

void _setInt64(int address, int v) {
  _heap.setUint32(address, v % 0x100000000, _le);
  _heap.setInt32(address + 4, (v - v % 0x100000000) ~/ 0x100000000, _le);
}

extension FloatPointer on Pointer<Float> {
  double get value => _heap.getFloat32(address, _le);
  set value(double v) => _heap.setFloat32(address, v, _le);
  double operator [](int i) => _heap.getFloat32(address + 4 * i, _le);
  void operator []=(int i, double v) => _heap.setFloat32(address + 4 * i, v, _le);
  Float32List asTypedList(int length) => FlutterFilamentModule.heapBytes.buffer.asFloat32List(address, length);
  Pointer<Float> operator +(int n) => Pointer<Float>.fromAddress(address + 4 * n);
}

extension DoublePointer on Pointer<Double> {
  double get value => _heap.getFloat64(address, _le);
  set value(double v) => _heap.setFloat64(address, v, _le);
  double operator [](int i) => _heap.getFloat64(address + 8 * i, _le);
  void operator []=(int i, double v) => _heap.setFloat64(address + 8 * i, v, _le);
  Float64List asTypedList(int length) => FlutterFilamentModule.heapBytes.buffer.asFloat64List(address, length);
  Pointer<Double> operator +(int n) => Pointer<Double>.fromAddress(address + 8 * n);
}

extension PointerPointer<T extends NativeType> on Pointer<Pointer<T>> {
  Pointer<T> get value => Pointer<T>.fromAddress(_heap.getUint32(address, _le));
  set value(Pointer<T> v) => _heap.setUint32(address, v.address, _le);
  Pointer<T> operator [](int i) => Pointer<T>.fromAddress(_heap.getUint32(address + 4 * i, _le));
  void operator []=(int i, Pointer<T> v) => _heap.setUint32(address + 4 * i, v.address, _le);
  Pointer<Pointer<T>> operator +(int n) => Pointer<Pointer<T>>.fromAddress(address + 4 * n);
}

extension StructPointer<T extends Struct> on Pointer<T> {
  T get ref => _layoutOf<T>().view!(address) as T;
  set ref(T value) => _copy(value.$address, address, _layoutOf<T>().size);
  T operator [](int i) => _layoutOf<T>().view!(address + i * _layoutOf<T>().size) as T;
  void operator []=(int i, T value) {
    final size = _layoutOf<T>().size;
    _copy(value.$address, address + i * size, size);
  }

  Pointer<T> operator +(int n) => Pointer<T>.fromAddress(address + n * _layoutOf<T>().size);
}

extension UnionPointer<T extends Union> on Pointer<T> {
  T get ref => _layoutOf<T>().view!(address) as T;
  T operator [](int i) => _layoutOf<T>().view!(address + i * _layoutOf<T>().size) as T;
}

void _copy(int from, int to, int size) {
  final bytes = FlutterFilamentModule.heapBytes;
  bytes.setRange(to, to + size, bytes, from);
}

/// Copies a struct view's bytes to [to] (generated nested-struct setters).
void $copyStruct(int from, int to, int size) => _copy(from, to, size);

extension FloatArray on Array<Float> {
  double operator [](int i) => _heap.getFloat32($address + 4 * _check(i, $length), _le);
  void operator []=(int i, double v) => _heap.setFloat32($address + 4 * _check(i, $length), v, _le);
}

extension DoubleArray on Array<Double> {
  double operator [](int i) => _heap.getFloat64($address + 8 * _check(i, $length), _le);
  void operator []=(int i, double v) => _heap.setFloat64($address + 8 * _check(i, $length), v, _le);
}

extension Uint8Array on Array<Uint8> {
  int operator [](int i) => _heap.getUint8($address + _check(i, $length));
  void operator []=(int i, int v) => _heap.setUint8($address + _check(i, $length), v);
}

extension Int8Array on Array<Int8> {
  int operator [](int i) => _heap.getInt8($address + _check(i, $length));
  void operator []=(int i, int v) => _heap.setInt8($address + _check(i, $length), v);
}

extension CharArray on Array<Char> {
  int operator [](int i) => _heap.getInt8($address + _check(i, $length));
  void operator []=(int i, int v) => _heap.setInt8($address + _check(i, $length), v);
}

extension Int16Array on Array<Int16> {
  int operator [](int i) => _heap.getInt16($address + 2 * _check(i, $length), _le);
  void operator []=(int i, int v) => _heap.setInt16($address + 2 * _check(i, $length), v, _le);
}

extension Uint16Array on Array<Uint16> {
  int operator [](int i) => _heap.getUint16($address + 2 * _check(i, $length), _le);
  void operator []=(int i, int v) => _heap.setUint16($address + 2 * _check(i, $length), v, _le);
}

extension Int32Array on Array<Int32> {
  int operator [](int i) => _heap.getInt32($address + 4 * _check(i, $length), _le);
  void operator []=(int i, int v) => _heap.setInt32($address + 4 * _check(i, $length), v, _le);
}

extension Uint32Array on Array<Uint32> {
  int operator [](int i) => _heap.getUint32($address + 4 * _check(i, $length), _le);
  void operator []=(int i, int v) => _heap.setUint32($address + 4 * _check(i, $length), v, _le);
}

extension BoolArray on Array<Bool> {
  bool operator [](int i) => _heap.getUint8($address + _check(i, $length)) != 0;
  void operator []=(int i, bool v) => _heap.setUint8($address + _check(i, $length), v ? 1 : 0);
}

int _check(int i, int length) {
  if (i < 0 || i >= length) throw RangeError.index(i, null, 'index', null, length);
  return i;
}

// --- function pointers, callbacks, finalizers ----------------------------------

/// How a value crosses the JS boundary for one parameter or return slot.
/// `v` void, `i` 32-bit int, `u` unsigned 32-bit, `p` pointer, `b` bool,
/// `f` float, `d` double, `j` 64-bit int.
final class $CallbackSignature {
  final String result;
  final List<String> params;
  const $CallbackSignature(this.result, this.params);

  /// The Emscripten `addFunction` signature string.
  String get wasm => _wasmChar(result) + params.map(_wasmChar).join();

  static String _wasmChar(String kind) => switch (kind) {
        'v' => 'v',
        'f' => 'f',
        'd' => 'd',
        'j' => 'j',
        _ => 'i',
      };
}

final Map<Type, $CallbackSignature> _callbackSignatures = {};

/// Registers the native function type [T] (generated from every
/// `NativeCallable<T>` and callback typedef in the package).
void $registerCallbackType<T extends Function>($CallbackSignature signature) {
  _callbackSignatures[T] = signature;
}

Object? _fromJs(JSAny? value, String kind) => switch (kind) {
      'p' => Pointer<Never>.fromAddress((value as JSNumber).toDartInt),
      'b' => (value as JSNumber).toDartInt != 0,
      'f' || 'd' => (value as JSNumber).toDartDouble,
      'j' => FlutterFilamentModule.fromBigInt(value),
      'u' => (value as JSNumber).toDartInt.toUnsigned(32),
      _ => (value as JSNumber).toDartInt,
    };

JSAny? _toJs(Object? value, String kind) => switch (kind) {
      'v' => null,
      'p' => (value as Pointer).address.toJS,
      'b' => ((value as bool) ? 1 : 0).toJS,
      'f' || 'd' => (value as double).toJS,
      'j' => FlutterFilamentModule.toBigInt(value as int),
      _ => (value as int).toJS,
    };

JSFunction _jsCallback(Function callback, $CallbackSignature sig, Object? exceptionalReturn) {
  Object? call(List<JSAny?> args) {
    final dartArgs = [for (var i = 0; i < sig.params.length; i++) _fromJs(args[i], sig.params[i])];
    try {
      return Function.apply(callback, dartArgs);
    } catch (e) {
      if (sig.result == 'v') rethrow;
      return exceptionalReturn;
    }
  }

  JSAny? done(Object? r) => _toJs(r, sig.result);
  return switch (sig.params.length) {
    0 => (() => done(call(const []))).toJS,
    1 => ((JSAny? a) => done(call([a]))).toJS,
    2 => ((JSAny? a, JSAny? b) => done(call([a, b]))).toJS,
    3 => ((JSAny? a, JSAny? b, JSAny? c) => done(call([a, b, c]))).toJS,
    4 => ((JSAny? a, JSAny? b, JSAny? c, JSAny? d) => done(call([a, b, c, d]))).toJS,
    5 => ((JSAny? a, JSAny? b, JSAny? c, JSAny? d, JSAny? e) => done(call([a, b, c, d, e]))).toJS,
    6 => ((JSAny? a, JSAny? b, JSAny? c, JSAny? d, JSAny? e, JSAny? f) => done(call([a, b, c, d, e, f]))).toJS,
    7 => ((JSAny? a, JSAny? b, JSAny? c, JSAny? d, JSAny? e, JSAny? f, JSAny? g) =>
        done(call([a, b, c, d, e, f, g]))).toJS,
    8 => ((JSAny? a, JSAny? b, JSAny? c, JSAny? d, JSAny? e, JSAny? f, JSAny? g, JSAny? h) =>
        done(call([a, b, c, d, e, f, g, h]))).toJS,
    _ => throw UnsupportedError('flutter_filament web: callbacks with ${sig.params.length} parameters'),
  };
}

/// A Dart function callable from C through a function pointer. The module
/// is single-threaded, so both constructors call back synchronously, on the
/// thread that called into C.
final class NativeCallable<T extends Function> {
  final int _index;
  bool _closed = false;

  NativeCallable._(this._index);

  factory NativeCallable.isolateLocal(Function callback, {Object? exceptionalReturn}) =>
      NativeCallable<T>._(_add<T>(callback, exceptionalReturn));

  factory NativeCallable.listener(Function callback) => NativeCallable<T>._(_add<T>(callback, null));

  static int _add<T extends Function>(Function callback, Object? exceptionalReturn) {
    final sig = _callbackSignatures[T] ??
        (throw UnsupportedError('flutter_filament web: no callback signature for $T (tool/ffigen_web.dart)'));
    return FlutterFilamentModule.addFunction(_jsCallback(callback, sig, exceptionalReturn), sig.wasm);
  }

  Pointer<NativeFunction<T>> get nativeFunction => Pointer<NativeFunction<T>>.fromAddress(_closed ? 0 : _index);

  bool keepIsolateAlive = true;

  void close() {
    if (_closed) return;
    _closed = true;
    FlutterFilamentModule.removeFunction(_index);
  }
}

/// Marker for objects a [NativeFinalizer] may be attached to.
abstract interface class Finalizable {}

/// Calls a native `void f(void*)` with a token when the attached object is
/// garbage collected (dart:core [Finalizer] underneath).
final class NativeFinalizer {
  final Finalizer<int> _finalizer;

  NativeFinalizer(Pointer<NativeType> callback)
      : _finalizer = Finalizer<int>((token) {
          final fn = FlutterFilamentModule.tableFunction(callback.address);
          fn?.callAsFunction(null, token.toJS);
        });

  void attach(Finalizable value, Pointer<NativeType> token, {Object? detach, int? externalSize}) {
    _finalizer.attach(value as Object, token.address, detach: detach);
  }

  void detach(Object detach) => _finalizer.detach(detach);
}

/// The `@Native` annotation's companion: the address of a bound C function.
final class Native<T> {
  const Native({String? symbol, bool isLeaf = false});

  static Pointer<T> addressOf<T extends NativeType>(Object native) {
    final entry = _nativeAddresses[native] ??
        (throw UnsupportedError('flutter_filament web: Native.addressOf of an unregistered function'));
    return Pointer<T>.fromAddress(entry);
  }
}

final Map<Object, int> _nativeAddresses = {};

/// Registers a generated binding's C export so [Native.addressOf] can hand
/// out a function-table index for it (tool/ffigen_web.dart).
void $registerNativeAddress(Object binding, String symbol, String signature) {
  FlutterFilamentModule.whenLoaded(() {
    _nativeAddresses[binding] = FlutterFilamentModule.addFunction(FlutterFilamentModule.export(symbol), signature);
  });
}

// --- allocation ----------------------------------------------------------------

/// Manages memory in the module's heap.
abstract interface class Allocator {
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment});
  void free(Pointer<NativeType> pointer);
}
