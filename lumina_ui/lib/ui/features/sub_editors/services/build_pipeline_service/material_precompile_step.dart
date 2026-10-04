part of '../build_pipeline_service.dart';

// --- 1. material precompile -------------------------------------------------

class MaterialCompileOutcome {
  final bool ok;
  final String? error;

  /// Extra detail for the log line (e.g. "compiled from .mat source").
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

  /// The folder `#include "…"` in [source] resolves against (the asset's own).
  final String? includeDirectory;
  const MaterialCompileInput({
    required this.name,
    required this.relativePath,
    required this.package,
    required this.source,
    this.includeDirectory,
  });
}

/// Compiles one FILAMAT asset; injectable so tests need no GPU.
typedef MaterialCompiler = Future<MaterialCompileOutcome> Function(MaterialCompileInput input);

/// The real seam: builds the `Material` on a headless Filament engine from the
/// asset's compiled package bytes (or, when the asset only carries `.mat`
/// source, from a package the material compiler — Filament's own `.mat`
/// parser, as the Material Editor uses it — builds from the whole source) and
/// warms its variants via `compile()`.
class FilamentMaterialCompiler {
  FilamentEngine? _engine;
  bool _engineFailed = false;
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

  /// Compiles the whole `.mat` [source] with the material compiler (every
  /// header key, `vertex` and `fragment` blocks, `#include`s from
  /// [includeDirectory]), as the Material Editor does.
  MatcResult buildPackageFromSource(String name, String source, {String? includeDirectory}) =>
      FilamentMatc.compile(source, fileName: '$name.mat', defaultName: name, includeDirectory: includeDirectory);

  Future<MaterialCompileOutcome> call(MaterialCompileInput input) async {
    Uint8List package = input.package;
    String? note;
    if (!isFilamatPackage(package)) {
      if (input.source.trim().isEmpty) {
        return MaterialCompileOutcome.failed(
            'no compiled filamat package (${package.length} bytes) and no .mat source — compile it in the Material Editor first');
      }
      try {
        final result = buildPackageFromSource(input.name, input.source, includeDirectory: input.includeDirectory);
        final built = result.package;
        if (built == null || !isFilamatPackage(built)) {
          return MaterialCompileOutcome.failed('matc: ${result.errorText}');
        }
        package = built;
        note = 'compiled from .mat source (${built.length} byte package, not written back)';
      } catch (e) {
        return MaterialCompileOutcome.failed('material compiler failed: $e');
      }
    }
    if (_engineFailed) return const MaterialCompileOutcome.failed('Filament engine unavailable on this host');
    try {
      _engine ??= FilamentEngine.create(
        config: const EngineConfig(
          minCommandBufferSizeMB: 4,
          commandBufferSizeMB: 16,
        ),
      );
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
        includeDirectory: m.file.parent.path,
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
