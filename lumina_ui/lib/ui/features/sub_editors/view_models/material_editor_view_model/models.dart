part of '../material_editor_view_model.dart';

enum MaterialCompileSeverity {
  error,
  warning,
  info,
}

class MaterialCompileIssue {
  final int line;
  final String message;
  final MaterialCompileSeverity severity;

  /// The graph node the issue is about (a type error), when it comes from
  /// the node graph rather than a source line.
  final String? nodeId;

  /// Whether the material compiler (matc) reported it, as opposed to the
  /// editor's own checks or the node graph.
  final bool fromCompiler;

  const MaterialCompileIssue({
    required this.line,
    required this.message,
    this.severity = MaterialCompileSeverity.error,
    this.nodeId,
    this.fromCompiler = false,
  });

  /// matc's [diagnostic] as an issue: its `.mat` line (0 when it names none)
  /// and its message verbatim.
  factory MaterialCompileIssue.fromMatc(MatcDiagnostic diagnostic) => MaterialCompileIssue(
        line: diagnostic.file == null ? (diagnostic.line ?? 0) : 0,
        message: diagnostic.message,
        severity: diagnostic.severity == MatcSeverity.error ? MaterialCompileSeverity.error : MaterialCompileSeverity.warning,
        fromCompiler: true,
      );
}

/// What one compile of a `.mat` source produced.
class MaterialCompileResult {
  /// The compiled `.filamat` package; null when the source was rejected.
  final Uint8List? bytes;

  /// The compiler's messages (errors when it failed, warnings either way).
  final List<MaterialCompileIssue> issues;

  const MaterialCompileResult({required this.bytes, this.issues = const []});

  bool get ok => bytes != null && bytes!.isNotEmpty;
}

/// Compiles a whole `.mat` material definition; injectable so a test can
/// observe what the editor hands the compiler.
abstract class FilamatCompilerRunner {
  /// [source] is the complete material definition as written (header,
  /// `vertex` and `fragment` blocks); [name] names a material whose header has
  /// none; `#include "…"` resolves against [includeDirectory].
  Future<MaterialCompileResult> compile({
    required String name,
    required String source,
    String? includeDirectory,
  });
}

/// The editor's compiler: Filament's own `.mat` parser (the one `matc` uses)
/// through [FilamentMatc], so every header key, the `vertex` and `fragment`
/// blocks in any order and `#include`s mean what they mean to matc, and a
/// failure lists matc's messages with their `.mat` line numbers.
class DefaultFilamatCompilerRunner implements FilamatCompilerRunner {
  @override
  Future<MaterialCompileResult> compile({
    required String name,
    required String source,
    String? includeDirectory,
  }) async {
    try {
      // matc takes about a second: off the UI isolate, so typing, the
      // viewport and the rest of the editor keep running while it compiles.
      final result = await _compileOnWorker((source: source, name: name, include: includeDirectory));
      return MaterialCompileResult(
        bytes: result.package,
        issues: [for (final d in result.diagnostics) MaterialCompileIssue.fromMatc(d)],
      );
    } catch (e, st) {
      EngineLoggerService().log('Material compiler failed: $e\n$st', level: 'error', source: 'FilamatCompiler');
      return MaterialCompileResult(
        bytes: null,
        issues: [MaterialCompileIssue(line: 0, message: 'Material compiler failed: $e', fromCompiler: true)],
      );
    }
  }

  /// Static, so the worker's closure captures only [job].
  static Future<MatcResult> _compileOnWorker(({String source, String name, String? include}) job) =>
      Isolate.run(() => FilamentMatc.compile(
            job.source,
            fileName: '${job.name}.mat',
            defaultName: job.name,
            includeDirectory: job.include,
          ));
}

/// Maps an editor-side parameter type onto the builder's [UniformType].
/// Returns null for [MaterialParamType.sampler2dType], which goes through
/// `addSamplerParameter` instead, and for anything without a mapping.
UniformType? uniformTypeFor(MaterialParamType type) => switch (type) {
      MaterialParamType.floatType => UniformType.floatType,
      MaterialParamType.vec2Type => UniformType.float2,
      MaterialParamType.vec3Type => UniformType.float3,
      MaterialParamType.vec4Type => UniformType.float4,
      MaterialParamType.colorType => UniformType.float4,
      MaterialParamType.boolType => UniformType.boolType,
      MaterialParamType.sampler2dType => null,
    };

enum MaterialParamType {
  floatType,
  colorType,
  sampler2dType,
  boolType,
  vec2Type,
  vec3Type,
  vec4Type,
}

class MaterialParamModel {
  final String name;
  final MaterialParamType type;
  dynamic value;
  final double min;
  final double max;
  final bool isSampler;
  AssetReference? textureRef;

  /// [textureRef]'s path made absolute, for anything that has to open the file.
  ///
  /// References are stored project-relative so a project stays portable; the
  /// preview renderer needs a real path. Runtime only — never persisted.
  String? resolvedTexturePath;

  MaterialParamModel({
    required this.name,
    required this.type,
    this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.isSampler = false,
    this.textureRef,
  });
}
