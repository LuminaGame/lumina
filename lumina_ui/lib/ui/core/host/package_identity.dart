/// Whether this process runs with an MSIX package identity (installed from
/// the Microsoft Store or an `.msix`), and which.
///
/// Pure `dart:ffi` (no Flutter imports), like the startup guard that uses it.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// `APPMODEL_ERROR_NO_PACKAGE`: the process has no package identity.
const int _appModelErrorNoPackage = 15700;

/// `ERROR_INSUFFICIENT_BUFFER`.
const int _errorInsufficientBuffer = 122;

/// The package family name of this process (e.g.
/// `LuminaEngine.LuminaEngine_w6wj9n9zwya6m`), or null when it has no package
/// identity, off Windows, or on a Windows without the API.
String? currentPackageFamilyName() {
  if (!Platform.isWindows) return null;
  final int Function(Pointer<Uint32>, Pointer<Utf16>) getName;
  try {
    getName = DynamicLibrary.open('kernel32.dll')
        .lookupFunction<Int32 Function(Pointer<Uint32>, Pointer<Utf16>), int Function(Pointer<Uint32>, Pointer<Utf16>)>(
            'GetCurrentPackageFamilyName');
  } on ArgumentError {
    return null;
  }
  return using((arena) {
    final length = arena<Uint32>()..value = 0;
    final first = getName(length, nullptr);
    if (first == _appModelErrorNoPackage || first != _errorInsufficientBuffer || length.value == 0) return null;
    final name = arena<Uint16>(length.value).cast<Utf16>();
    if (getName(length, name) != 0) return null;
    return name.toDartString();
  });
}
