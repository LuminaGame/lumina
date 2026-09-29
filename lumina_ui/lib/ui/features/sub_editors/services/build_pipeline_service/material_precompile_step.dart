part of '../build_pipeline_service.dart';

// --- 1. material precompile -------------------------------------------------

class MaterialCompileOutcome {
  final bool ok;
  final String? error;

  /// Extra detail for the log line (e.g. "compiled from GLSL source").
  final String? note;
  const MaterialCompileOutcome.ok({this.note}) : ok = true, error = null;
  const MaterialCompileOutcome.failed(this.error) : ok = false, note = null;
}

/// What the precompile seam receives for one FILAMAT asset.
class MaterialCompileInput {
  final String name;
  final String relativePath;
  final Uint8List package;
  final String source;
  const MaterialCompileInput({required this.name, required this.relativePath, required this.package, required this.source});
}

/// Compiles one FILAMAT asset; injectable so tests need no GPU.
typedef MaterialCompiler = Future<MaterialCompileOutcome> Function(MaterialCompileInput input);

/// The real seam: builds the `Material` on a headless Filament engine from the
/// asset's compiled package bytes (or, when the asset only carries GLSL
/// source, from a package built by the in-process filamat compiler exactly
/// the way the Material Editor does) and warms its variants via `compile()`.
class FilamentMaterialCompiler {
  FilamentEngine? _engine;
  bool _engineFailed = false;
  bool _builderReady = false;
  final Duration timeout;

  FilamentMaterialCompiler({this.timeout = const Duration(seconds: 30)});

  static const List<int> _packageMagic = [0x53, 0x52, 0x45, 0x56, 0x5F, 0x54, 0x41, 0x4D];

  /// Whether [bytes] look like a compiled `.filamat` package (a `MAT_VERS`
  /// chunk of size 4). Filament aborts the process on arbitrary bytes, so
  /// this guard is mandatory before `fromBuffer`.
  static bool isFilamatPackage(Uint8List? bytes) {
    if (bytes == null || bytes.length < 16) return false;
    for (var i = 0; i < _packageMagic.length; i++) {
      if (bytes[i] != _packageMagic[i]) return false;
    }
    return ByteData.view(bytes.buffer, bytes.offsetInBytes + 8, 4).getUint32(0, Endian.little) == 4;
  }

  /// Mirrors the Material Editor: the `fragment { … }` body is what the
  /// filamat builder compiles; header keys pick shading/blending.
  static String extractFragmentBody(String source) {
    final fragIndex = source.indexOf('fragment {');
    if (fragIndex == -1) return source;
    final afterFrag = source.substring(fragIndex + 10);
    final lastBrace = afterFrag.lastIndexOf('}');
    return (lastBrace == -1 ? afterFrag : afterFrag.substring(0, lastBrace)).trim();
  }

  static FilamatShading shadingOf(String source) {
    if (RegExp(r'shadingModel\s*:\s*unlit').hasMatch(source)) return FilamatShading.unlit;
    if (RegExp(r'shadingModel\s*:\s*cloth').hasMatch(source)) return FilamatShading.cloth;
    if (RegExp(r'shadingModel\s*:\s*subsurface').hasMatch(source)) return FilamatShading.subsurface;
    return FilamatShading.lit;
  }

  static BlendingMode blendingOf(String source) {
    if (RegExp(r'blending\s*:\s*transparent').hasMatch(source)) return BlendingMode.transparent;
    if (RegExp(r'blending\s*:\s*masked').hasMatch(source)) return BlendingMode.masked;
    if (RegExp(r'blending\s*:\s*add').hasMatch(source)) return BlendingMode.add;
    return BlendingMode.opaque;
  }

  /// Parameters declared in the `.mat` header
  /// (`parameters : [ { type : float4, name : baseColor } ]`) as
  /// (type, name) pairs, so `materialParams.<name>` resolves when compiling.
  static List<(String, String)> headerParameters(String source) {
    final out = <(String, String)>[];
    final block = RegExp(r'parameters\s*:\s*\[(.*?)\]', dotAll: true).firstMatch(source);
    if (block == null) return out;
    for (final m in RegExp(r'\{([^}]*)\}').allMatches(block.group(1)!)) {
      final entry = m.group(1)!;
      final type = RegExp(r'type\s*:\s*([A-Za-z0-9_]+)').firstMatch(entry)?.group(1);
      final name = RegExp(r'name\s*:\s*"?([A-Za-z_][A-Za-z0-9_]*)"?').firstMatch(entry)?.group(1);
      if (type != null && name != null) out.add((type, name));
    }
    return out;
  }

  /// Vertex attributes the `.mat` header's `requires : [ uv0, … ]` block asks
  /// for, as `VertexAttribute` indices, the way the Material Editor reads them:
  /// `getUV0()` in the fragment only compiles when UV0 is required.
  static Set<int> requiredAttributes(String source) {
    final match = RegExp(r'requires\s*:\s*\[([^\]]*)\]').firstMatch(source);
    if (match == null) return const {};
    return {
      for (final raw in match.group(1)!.split(',')) ?MaterialVertexAttribute.fromName(raw),
    };
  }

  static UniformType? uniformTypeFor(String matType) => switch (matType) {
        'bool' => UniformType.boolType,
        'bool2' => UniformType.bool2,
        'bool3' => UniformType.bool3,
        'bool4' => UniformType.bool4,
        'float' => UniformType.floatType,
        'float2' => UniformType.float2,
        'float3' => UniformType.float3,
        'float4' => UniformType.float4,
        'int' => UniformType.intType,
        'int2' => UniformType.int2,
        'int3' => UniformType.int3Type,
        'int4' => UniformType.int4,
        'uint' => UniformType.uint,
        'uint2' => UniformType.uint2,
        'uint3' => UniformType.uint3,
        'uint4' => UniformType.uint4,
        'mat3' => UniformType.mat3,
        'mat4' => UniformType.mat4,
        _ => null,
      };

  /// Builds a package from GLSL [source] with the in-process filamat
  /// compiler; null when the compiler rejects it.
  Uint8List? buildPackageFromSource(String name, String source) {
    if (!_builderReady) {
      FilamentMaterialBuilder.initEngine();
      _builderReady = true;
    }
    final builder = FilamentMaterialBuilder.create();
    try {
      builder.setName(name);
      for (final attribute in requiredAttributes(source)) {
        builder.requireAttribute(attribute);
      }
      for (final (type, pname) in headerParameters(source)) {
        final uniform = uniformTypeFor(type);
        if (uniform != null) {
          builder.addParameter(pname, uniform);
        } else if (type.startsWith('sampler')) {
          builder.addSamplerParameter(pname);
        }
      }
      builder.setCode(extractFragmentBody(source));
      builder.setShading(shadingOf(source));
      builder.blending(blendingOf(source));
      builder.setDoubleSided(RegExp(r'doubleSided\s*:\s*true').hasMatch(source));
      return builder.build();
    } finally {
      builder.dispose();
    }
  }

  Future<MaterialCompileOutcome> call(MaterialCompileInput input) async {
    Uint8List package = input.package;
    String? note;
    if (!isFilamatPackage(package)) {
      if (input.source.trim().isEmpty) {
        return MaterialCompileOutcome.failed(
            'no compiled filamat package (${package.length} bytes) and no GLSL source — compile it in the Material Editor first');
      }
      try {
        final built = buildPackageFromSource(input.name, input.source);
        if (built == null || !isFilamatPackage(built)) {
          return const MaterialCompileOutcome.failed('filamat rejected the GLSL source (no package produced)');
        }
        package = built;
        note = 'compiled from GLSL source (${built.length} byte package, not written back)';
      } catch (e) {
        return MaterialCompileOutcome.failed('filamat build from source failed: $e');
      }
    }
    if (_engineFailed) return const MaterialCompileOutcome.failed('Filament engine unavailable on this host');
    try {
      _engine ??= FilamentEngine.create();
    } catch (e) {
      _engineFailed = true;
      return MaterialCompileOutcome.failed('Filament engine could not be created: $e');
    }
    final engine = _engine;
    if (engine == null) {
      _engineFailed = true;
      return const MaterialCompileOutcome.failed('Filament engine could not be created on this host');
    }
    FilamentMaterial? material;
    try {
      material = FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: package);
      final done = material.compile();
      // Compile callbacks are delivered through the engine's message queues.
      final deadline = DateTime.now().add(timeout);
      var completed = false;
      unawaited(done.then((_) => completed = true, onError: (_) => completed = true));
      while (!completed) {
        engine.flushAndWait();
        engine.pumpMessageQueues();
        if (completed) break;
        if (DateTime.now().isAfter(deadline)) {
          return MaterialCompileOutcome.failed('compile() did not complete within ${timeout.inSeconds}s');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await done;
      return MaterialCompileOutcome.ok(note: note);
    } catch (e) {
      return MaterialCompileOutcome.failed(e.toString());
    } finally {
      try {
        material?.dispose();
      } catch (_) {}
    }
  }

  void dispose() {
    try {
      _engine?.dispose();
    } catch (_) {}
    _engine = null;
  }
}

class MaterialPrecompileStep implements BuildStep {
  final MaterialCompiler _compiler;
  MaterialPrecompileStep({MaterialCompiler? compiler}) : _compiler = compiler ?? FilamentMaterialCompiler().call;

  @override
  BuildStepKind get kind => BuildStepKind.precompileMaterials;

  @override
  Future<StepResult> execute(BuildStepContext ctx) async {
    final materials = _scanLmas(ctx.projectDir, onError: (p, e) => ctx.log('Unreadable asset $p: $e', level: 'warning'))
        .where((s) => s.asset.type == AssetType.filamat)
        .toList();
    if (materials.isEmpty) return const StepResult.skipped('No FILAMAT assets in contents/ — nothing to precompile');
    ctx.log('Precompiling ${materials.length} material(s)…');
    var done = 0;
    var failed = 0;
    for (final m in materials) {
      if (ctx.token.isCancelled) return StepResult.cancelled('Material precompile cancelled after $done/${materials.length}');
      final sw = Stopwatch()..start();
      final outcome = await _compiler(MaterialCompileInput(
        name: m.asset.name,
        relativePath: m.relativePath,
        package: m.asset.rawPayload ?? Uint8List(0),
        source: m.asset.rawMatSource,
      ));
      done++;
      if (outcome.ok) {
        ctx.log('${m.asset.name}: compiled (${_fmt(sw.elapsed)})${outcome.note != null ? ' — ${outcome.note}' : ''} — ${m.relativePath}', level: 'success');
      } else {
        failed++;
        ctx.log('${m.asset.name}: FAILED — ${outcome.error} (${m.relativePath})', level: 'error');
      }
      ctx.progress(completed: done, total: materials.length, failed: failed, label: 'Materials: $done/${materials.length} compiled, $failed failed');
    }
    final summary = 'Materials: $done/${materials.length} compiled, $failed failed';
    return failed > 0 ? StepResult.failed(summary) : StepResult.ok(summary);
  }
}
