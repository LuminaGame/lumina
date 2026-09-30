import 'dart:convert';
import 'dart:typed_data';

import 'ffi_platform.dart' as ffi;
import 'ffi_package_platform.dart';
import 'filamat_builder.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// How serious a [MatcDiagnostic] is.
enum MatcSeverity { error, warning }

/// One message of a matc compile, kept as matc wrote it.
class MatcDiagnostic {
  final MatcSeverity severity;

  /// The `.mat` line the message points at (1-based), when it names one: matc's
  /// `at line:N`, glslang's `ERROR: 0:N:` (the material's blocks keep their
  /// `.mat` line numbers), or an included file's line (then [file] names it).
  final int? line;

  /// The file a glslang message names when it is not the material itself
  /// (an `#include`d file), otherwise null.
  final String? file;

  /// matc's message (one or more lines of its output), verbatim.
  final String message;

  const MatcDiagnostic({required this.severity, required this.message, this.line, this.file});

  static final _atLine = RegExp(r'\bline:\s*(\d+)');
  static final _glslang = RegExp(r'^(ERROR|WARNING):\s*("?)([^:"]*)\2:(\d+):');

  /// Where one of matc's messages begins; any other line continues the
  /// message before it (a key's error and its list of valid values, the
  /// detail lines under `JsonishParser error`).
  static final _messageStart = RegExp(
    r'^(ERROR|WARNING|Warning|Error while processing material|Ignoring config entry|Could not compile|'
    r'JsonishParser error|Unknown identifier|Unexpected character|An identifier was expected|Identifier at line|'
    r'A block was expected|Input MUST|The included file|File |Unable to open|Include depth|'
    r'Undefined template macro|Material feature level|Input file is empty|Value for key)',
  );

  /// Splits matc's output into diagnostics, one per message (see
  /// [_messageStart]). A message is a warning when matc calls it one
  /// (`WARNING:`, `Warning:`, `Ignoring config entry`); the rest are errors
  /// when the compile [failed], warnings when it succeeded. [rootFile] is the
  /// name the material's own `#line` directives use.
  static List<MatcDiagnostic> parseLog(String log, {required bool failed, String? rootFile}) {
    final groups = <List<String>>[];
    for (final raw in const LineSplitter().convert(log)) {
      final text = raw.trimRight();
      if (text.trim().isEmpty) continue;
      if (groups.isEmpty || _messageStart.hasMatch(text)) {
        groups.add([text]);
      } else {
        groups.last.add(text);
      }
    }
    final out = <MatcDiagnostic>[];
    for (final group in groups) {
      final lower = group.first.trimLeft().toLowerCase();
      final isWarning = lower.startsWith('warning') || lower.startsWith('ignoring config entry');
      int? line;
      String? file;
      for (final text in group) {
        final glslang = _glslang.firstMatch(text.trimLeft());
        if (glslang != null) {
          line = int.tryParse(glslang.group(4)!);
          final name = glslang.group(3)!.trim();
          if (name.isNotEmpty && name != '0' && name != rootFile) file = name;
          break;
        }
        final at = _atLine.firstMatch(text);
        if (at != null) {
          line = int.tryParse(at.group(1)!);
          break;
        }
      }
      out.add(MatcDiagnostic(
        severity: isWarning || !failed ? MatcSeverity.warning : MatcSeverity.error,
        message: group.join('\n'),
        line: line,
        file: file,
      ));
    }
    return out;
  }

  @override
  String toString() => '${severity.name}${line != null ? ' (line $line)' : ''}: $message';
}

/// The outcome of [FilamentMatc.compile].
class MatcResult {
  /// The compiled `.filamat` package, or null when matc rejected the material.
  final Uint8List? package;

  /// Everything matc printed for this compile, in order.
  final String log;

  /// [log], one diagnostic per line.
  final List<MatcDiagnostic> diagnostics;

  const MatcResult({required this.package, required this.log, required this.diagnostics});

  bool get ok => package != null;

  /// The error lines, joined; the whole [log] when none is marked an error.
  String get errorText {
    final errors = [for (final d in diagnostics) if (d.severity == MatcSeverity.error) d.message];
    return errors.isEmpty ? log.trim() : errors.join('\n');
  }
}

/// Compiles whole Filament material definitions (`.mat` files) the way
/// Filament's `matc` tool does, in process: Filament's own `.mat` parser
/// reads the `material { … }` header (every key matc knows), the `vertex { … }`
/// and `fragment { … }` / `compute { … }` blocks in any order and `#include`s,
/// and filamat builds the package.
///
/// Desktop only; in a web build nothing compiles and the result says so.
abstract final class FilamentMatc {
  /// Compiles [source].
  ///
  /// [fileName] is the name `#line` directives give the material (matc uses the
  /// input file's); [includeDirectory] is where `#include "…"` looks (none:
  /// every include fails as not found); [defaultName] names a material whose
  /// header has no `name`. [platform], [targetApi], [optimization], [debug] and
  /// [variantFilter] are matc's `--platform`, `--api`, `-O…`, `-g` and
  /// `--variant-filter`; unlike matc (OpenGL only) the default [targetApi] is
  /// every API, so the package loads on any backend.
  static MatcResult compile(
    String source, {
    String? fileName,
    String? includeDirectory,
    String? defaultName,
    MaterialPlatform? platform,
    TargetApi targetApi = TargetApi.all,
    OptimizationLevel? optimization,
    bool debug = false,
    int variantFilter = 0,
  }) {
    final bytes = utf8.encode(source);
    final nativeSource = calloc<ffi.Uint8>(bytes.isEmpty ? 1 : bytes.length);
    final nativeFile = fileName?.toNativeUtf8();
    final nativeInclude = includeDirectory?.toNativeUtf8();
    final nativeName = defaultName?.toNativeUtf8();
    final outSize = calloc<ffi.Size>();
    final outDiagnostics = calloc<ffi.Pointer<ffi.Char>>();
    try {
      nativeSource.asTypedList(bytes.length).setAll(0, bytes);
      outDiagnostics.value = ffi.nullptr;
      final package = c.filament_matc_compile(
        nativeSource.cast(),
        bytes.length,
        nativeFile?.cast() ?? ffi.nullptr,
        nativeInclude?.cast() ?? ffi.nullptr,
        nativeName?.cast() ?? ffi.nullptr,
        platform?.value ?? -1,
        targetApi.value,
        optimization?.value ?? -1,
        debug,
        variantFilter,
        outSize,
        outDiagnostics,
      );
      var log = '';
      final diagnosticsPointer = outDiagnostics.value;
      if (diagnosticsPointer != ffi.nullptr) {
        log = diagnosticsPointer.cast<Utf8>().toDartString();
        c.filament_matc_free(diagnosticsPointer.cast());
      }
      Uint8List? result;
      if (package != ffi.nullptr) {
        result = Uint8List.fromList(package.cast<ffi.Uint8>().asTypedList(outSize.value));
        c.filament_matc_free(package);
      } else if (log.trim().isEmpty) {
        log = 'Material compilation is not available in this build (filamat is desktop-only).';
      }
      return MatcResult(
        package: result,
        log: log,
        diagnostics: MatcDiagnostic.parseLog(log, failed: result == null, rootFile: fileName),
      );
    } finally {
      calloc.free(nativeSource);
      if (nativeFile != null) calloc.free(nativeFile);
      if (nativeInclude != null) calloc.free(nativeInclude);
      if (nativeName != null) calloc.free(nativeName);
      calloc.free(outSize);
      calloc.free(outDiagnostics);
    }
  }
}
