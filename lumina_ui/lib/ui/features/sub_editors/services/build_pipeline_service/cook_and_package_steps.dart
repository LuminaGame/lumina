part of '../build_pipeline_service.dart';

// --- 5. cook & package ------------------------------------------------------

/// Result of the pre-spawn code-generation pass.
class CookCodeGenOutcome {
  final bool ok;
  final String message;
  final List<String> writtenFiles;
  const CookCodeGenOutcome(this.ok, this.message, {this.writtenFiles = const []});
}

/// Regenerates the game's Dart code; the default reads the active level from
/// disk, the editor injects its own save-and-generate path.
typedef CookCodeGenerator = Future<CookCodeGenOutcome> Function(BuildStepContext ctx);

class CookAndPackageStep implements BuildStep {
  final String target;
  final BuildConfiguration configuration;
  final String extraFlags;
  final String flutterExecutable;
  final BuildProcessStarter _starter;
  final CookCodeGenerator _codeGen;

  /// flutter_filament's WebAssembly module, served next to a web build's
  /// `index.html`. Required for `web`.
  final FlutterFilamentWebModule? webModule;

  /// For `web`: ship CanvasKit and the other engine web resources inside the
  /// build (`--no-web-resources-cdn`) instead of loading them from Google's
  /// CDN, so the game also runs offline.
  final bool bundleWebResources;

  static const String bundleWebResourcesFlag = '--no-web-resources-cdn';

  /// Windows: where the space-free alias the build runs through lives
  /// ([SpaceFreeBuildDir]; default [SpaceFreeBuildDir.defaultAliasRoot]).
  final Directory? buildAliasRoot;

  CookAndPackageStep({
    required this.target,
    required this.configuration,
    this.extraFlags = '',
    this.flutterExecutable = 'flutter',
    BuildProcessStarter? processStarter,
    CookCodeGenerator? codeGenerator,
    this.webModule,
    this.bundleWebResources = false,
    this.buildAliasRoot,
  })  : _starter = processStarter ?? defaultBuildProcessStarter,
        _codeGen = codeGenerator ?? levelFileCodeGenerator;

  @override
  BuildStepKind get kind => BuildStepKind.cookAndPackage;

  /// Where `flutter build <target>` leaves its output for [configuration].
  static String artifactPathFor(String projectDir, String target, BuildConfiguration configuration) {
    final mode = configuration.modeDir;
    final cap = '${mode[0].toUpperCase()}${mode.substring(1)}';
    return switch (target) {
      'linux' => '$projectDir/build/linux/x64/$mode/bundle',
      'windows' => '$projectDir/build/windows/x64/runner/$cap',
      'macos' => '$projectDir/build/macos/Build/Products/$cap',
      'apk' => '$projectDir/build/app/outputs/flutter-apk/app-$mode.apk',
      'appbundle' => '$projectDir/build/app/outputs/bundle/$mode/app-$mode.aab',
      'web' => '$projectDir/build/web',
      'ios' => '$projectDir/build/ios/iphoneos/Runner.app',
      _ => '$projectDir/build',
    };
  }

  /// The argv the step spawns: `flutter build <target> <flag> [extra…]`.
  List<String> buildArguments() {
    final extra = shellSplit(extraFlags);
    return [
      'build',
      target,
      configuration.flag,
      // An unsigned Runner.app: signing needs the developer's team in Xcode.
      if (target == 'ios' && !extra.contains('--no-codesign')) '--no-codesign',
      if (target == 'web' && bundleWebResources && !extra.contains(bundleWebResourcesFlag)) bundleWebResourcesFlag,
      ...extra,
    ];
  }

  /// Splits a flags string the way a POSIX shell would (quotes and backslash
  /// escapes honoured, no expansion).
  static List<String> shellSplit(String input) {
    final out = <String>[];
    final cur = StringBuffer();
    var inToken = false;
    String? quote;
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (quote != null) {
        if (ch == quote) {
          quote = null;
        } else if (ch == r'\' && quote == '"' && i + 1 < input.length) {
          cur.write(input[++i]);
        } else {
          cur.write(ch);
        }
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
        inToken = true;
      } else if (ch == r'\' && i + 1 < input.length) {
        cur.write(input[++i]);
        inToken = true;
      } else if (ch == ' ' || ch == '\t' || ch == '\n') {
        if (inToken) {
          out.add(cur.toString());
          cur.clear();
          inToken = false;
        }
      } else {
        cur.write(ch);
        inToken = true;
      }
    }
    if (inToken) out.add(cur.toString());
    return out;
  }

  /// Default code-gen: reads the active level's actors + environment from its
  /// `.lmas` and runs [GenerateDartCodeUseCase] (fresh `lib/main.dart` +
  /// `lib/levels/<level>.dart`, dirty flag cleared, timestamp stamped).
  static Future<CookCodeGenOutcome> levelFileCodeGenerator(BuildStepContext ctx) async {
    final levelFile = ctx.activeLevelFile;
    final levelName = ctx.activeLevelName;
    if (levelFile == null || levelName == null) {
      return const CookCodeGenOutcome(false, 'Project manifest has no active level — cannot generate code');
    }
    var actors = <Map<String, dynamic>>[];
    Map<String, dynamic>? environment;
    if (levelFile.existsSync()) {
      try {
        final map = _readLevelMap(levelFile);
        final meta = map['metadata'];
        if (meta is Map) {
          actors = (meta['actors'] as List? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
          if (meta['environment'] is Map) environment = Map<String, dynamic>.from(meta['environment'] as Map);
        }
      } catch (e) {
        return CookCodeGenOutcome(false, 'Level ${levelFile.path} is not readable: $e');
      }
    } else {
      ctx.log('Level file ${levelFile.path} does not exist yet — generating an empty level', level: 'warning');
    }
    final result = await GenerateDartCodeUseCase()(
      projectDir: ctx.projectDir,
      levelName: levelName,
      actors: actors,
      project: ctx.project,
      environment: environment,
    );
    if (!result.isSuccess) return CookCodeGenOutcome(false, result.error ?? 'code generation failed');
    return CookCodeGenOutcome(true, 'Generated ${result.writtenFiles.length} file(s): ${result.writtenFiles.join(', ')}', writtenFiles: result.writtenFiles);
  }

  /// Why a web cook of [projectDir] cannot start, or null. Checked before
  /// anything is generated or spawned.
  String? _webPrecheck(String projectDir) {
    if (webModule == null) return 'Cannot cook for the web: ${FlutterFilamentWebModule.missingReason}';
    final index = File('$projectDir/web/index.html');
    if (!index.existsSync()) {
      return 'Cannot cook for the web: ${index.path} is missing, so the project has no web platform. '
          'Add it by running `flutter create --platforms=web .` in the project folder.';
    }
    return null;
  }

  /// Puts flutter_filament's module next to the built `index.html`: the
  /// game loads `flutter_filament.js` from its own origin at startup.
  StepResult? _stageWebModule(BuildStepContext ctx, String artifact) {
    final out = Directory(artifact);
    if (!out.existsSync()) return StepResult.failed('flutter build web reported success but $artifact does not exist');
    final staged = webModule!.stageInto(out);
    for (final f in staged) {
      ctx.log('Staged ${f.uri.pathSegments.last} (${formatBytes(f.lengthSync())}) into $artifact');
    }
    return null;
  }

  /// `12.3 MB`-style sizes for the log and the Output section.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Why cooking [projectDir] would ship its editor-only `DerivedDataCache/`,
  /// or null. `flutter build` bundles only the pubspec's asset entries, so the cache stays out unless one of them names it.
  static String? derivedDataCacheLeak(String projectDir) {
    final pubspec = File('$projectDir/pubspec.yaml');
    if (!pubspec.existsSync()) return null;
    final entries = DerivedDataCache.packagedEntriesIncludingCache(pubspec.readAsStringSync());
    if (entries.isEmpty) return null;
    return 'Cannot cook: pubspec.yaml lists ${entries.join(', ')} under flutter: assets:, which would ship the '
        "editor's ${DerivedDataCache.directoryName}/ inside the game. Remove those asset entries.";
  }

  @override
  Future<StepResult> execute(BuildStepContext ctx) async {
    if (target == 'web') {
      final problem = _webPrecheck(ctx.projectDir);
      if (problem != null) return StepResult.failed(problem);
    }
    final leak = derivedDataCacheLeak(ctx.projectDir);
    if (leak != null) return StepResult.failed(leak);

    // 1. Code generation always precedes the spawn.
    ctx.log('Generating Dart code before packaging…');
    final gen = await _codeGen(ctx);
    if (!gen.ok) return StepResult.failed('Code generation failed: ${gen.message}');
    ctx.log(gen.message, level: 'success');
    if (ctx.token.isCancelled) return const StepResult.cancelled('Cook cancelled before flutter build started');

    // 2. Real flutter build as a child process. On Windows it runs through a
    // space-free alias of the project: the native-assets hooks cannot
    // compile under a path with a space (see SpaceFreeBuildDir).
    final args = buildArguments();
    ctx.log('Running $flutterExecutable ${args.join(' ')} (in ${ctx.projectDir})');
    var buildDir = ctx.projectDir;
    try {
      buildDir = SpaceFreeBuildDir.of(ctx.projectDir, aliasRoot: buildAliasRoot);
    } on FileSystemException catch (e) {
      ctx.log('Could not create a space-free alias of the project (${e.message}); building in place', level: 'warning');
    }
    if (buildDir != ctx.projectDir) ctx.log('Building through $buildDir -> ${ctx.projectDir}');
    Process proc;
    try {
      proc = await _starter(flutterExecutable, args, workingDirectory: buildDir);
    } catch (e) {
      return StepResult.failed('Failed to start $flutterExecutable: $e');
    }
    void onCancel() => proc.kill(ProcessSignal.sigterm);
    ctx.token.onCancel(onCancel);
    var lines = 0;
    void emit(String line, {required bool isErr, required bool replace}) {
      if (line.trim().isEmpty) return;
      lines++;
      ctx.log(line, level: isErr ? 'warning' : 'info', replaceLast: replace);
    }

    final outDone = proc.stdout.transform(utf8.decoder).transform(const _CarriageReturnLineSplitter()).listen((l) => emit(l.text, isErr: false, replace: l.replaceLast)).asFuture<void>();
    final errDone = proc.stderr.transform(utf8.decoder).transform(const _CarriageReturnLineSplitter()).listen((l) => emit(l.text, isErr: true, replace: l.replaceLast)).asFuture<void>();
    final code = await proc.exitCode; // reaped: no zombie
    await Future.wait([outDone, errDone]);
    ctx.token.removeListener(onCancel);

    if (ctx.token.isCancelled) {
      return StepResult.cancelled('flutter build $target cancelled (process killed, exit $code, $lines line(s) captured)');
    }
    if (code == 0) {
      final artifact = artifactPathFor(ctx.projectDir, target, configuration);
      if (target == 'web') {
        final failed = _stageWebModule(ctx, artifact);
        if (failed != null) return failed;
      }
      return StepResult.ok('flutter build $target ${configuration.flag} succeeded (exit 0) — artifact: $artifact', artifactPath: artifact);
    }
    return StepResult.failed('flutter build $target ${configuration.flag} exited with code $code');
  }
}

/// Packages every ticked target in turn: a target
/// the host, its toolchain or the engine cannot build is reported with its
/// reasons and never spawned; the others run [CookAndPackageStep] and are
/// copied into their own `<output dir>/package/<target>` folder. The game's
/// code is generated once for the whole run.
class PackageTargetsStep implements BuildStep {
  /// Platform ids ([kPackagingPlatforms]).
  final List<String> targets;
  final BuildConfiguration configuration;
  final String extraFlags;
  final String flutterExecutable;
  final BuildProcessStarter? processStarter;
  final CookCodeGenerator? codeGenerator;

  /// Why a target cannot be built (empty: buildable).
  final List<String> Function(String target) reasonsFor;

  /// The folder a target's package is copied into.
  final String Function(String target) packageDirFor;
  final FlutterFilamentWebModule? webModule;
  final bool bundleWebResources;

  /// Runs before a buildable target's `flutter build`; a non-null result
  /// fails the target with that message (e.g. the project icon becomes the
  /// platform's app icon).
  final Future<String?> Function(BuildStepContext ctx, String target)? beforeBuild;

  /// Runs once a target is copied into its package folder
  /// (e.g. a Linux bundle's `.desktop` entry and file-manager icon).
  final Future<void> Function(BuildStepContext ctx, String target, String artifactPath, String packageDir)? afterPackage;

  /// Windows: where the space-free alias each build runs through lives
  /// ([CookAndPackageStep.buildAliasRoot]).
  final Directory? buildAliasRoot;

  PackageTargetsStep({
    required this.targets,
    required this.reasonsFor,
    required this.packageDirFor,
    this.configuration = BuildConfiguration.shipping,
    this.extraFlags = '',
    this.flutterExecutable = 'flutter',
    this.processStarter,
    this.codeGenerator,
    this.webModule,
    this.bundleWebResources = false,
    this.beforeBuild,
    this.afterPackage,
    this.buildAliasRoot,
  });

  @override
  BuildStepKind get kind => BuildStepKind.cookAndPackage;

  /// The argv `flutter` gets for [target].
  List<String> argumentsFor(String target) => CookAndPackageStep(
        target: flutterBuildSubcommand(target),
        configuration: configuration,
        extraFlags: extraFlags,
        bundleWebResources: bundleWebResources,
      ).buildArguments();

  static String sourceFor(String target) => '${BuildStepKind.cookAndPackage.label} [$target]';

  @override
  Future<StepResult> execute(BuildStepContext ctx) async {
    if (targets.isEmpty) return const StepResult.failed('No packaging target is ticked: nothing to package');
    ctx.log('Packaging ${targets.length} target(s): ${targets.map(packagingPlatformLabel).join(', ')}');
    final generate = codeGenerator ?? CookAndPackageStep.levelFileCodeGenerator;
    CookCodeGenOutcome? generated;
    Future<CookCodeGenOutcome> once(BuildStepContext c) async {
      final done = generated;
      if (done != null) {
        return done.ok ? CookCodeGenOutcome(true, 'Dart code already generated for this run', writtenFiles: done.writtenFiles) : done;
      }
      return generated = await generate(c);
    }

    final outcome = <String, PackageTargetStatus>{};
    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      final label = packagingPlatformLabel(target);
      final tctx = ctx.withSource(sourceFor(target));
      if (ctx.token.isCancelled) {
        for (final rest in targets.skip(i)) {
          outcome[rest] = PackageTargetStatus.cancelled;
          ctx.emit(BuildTargetFinished(rest, status: PackageTargetStatus.cancelled, message: 'cancelled before it started', duration: Duration.zero));
        }
        break;
      }
      ctx.emit(BuildTargetStarted(target, index: i, count: targets.length));
      final sw = Stopwatch()..start();
      final reasons = reasonsFor(target);
      if (reasons.isNotEmpty) {
        for (final r in reasons) {
          tctx.log('$label is not buildable: $r', level: 'error');
        }
        outcome[target] = PackageTargetStatus.unbuildable;
        ctx.emit(BuildTargetFinished(target,
            status: PackageTargetStatus.unbuildable, message: 'not buildable: ${reasons.join(' ')}', duration: sw.elapsed, reasons: reasons));
        continue;
      }
      final before = beforeBuild;
      if (before != null) {
        String? problem;
        try {
          problem = await before(tctx, target);
        } catch (e) {
          problem = '$e';
        }
        if (problem != null) {
          outcome[target] = PackageTargetStatus.failed;
          final msg = '$label not built: $problem';
          tctx.log(msg, level: 'error');
          ctx.emit(BuildTargetFinished(target, status: PackageTargetStatus.failed, message: msg, duration: sw.elapsed));
          continue;
        }
      }
      final cook = CookAndPackageStep(
        target: flutterBuildSubcommand(target),
        configuration: configuration,
        extraFlags: extraFlags,
        flutterExecutable: flutterExecutable,
        processStarter: processStarter,
        codeGenerator: once,
        webModule: target == 'web' ? webModule : null,
        bundleWebResources: bundleWebResources,
        buildAliasRoot: buildAliasRoot,
      );
      StepResult result;
      try {
        result = await cook.execute(tctx);
      } catch (e) {
        result = StepResult.failed('$label threw: $e');
      }
      if (result.status == BuildStepStatus.cancelled) {
        outcome[target] = PackageTargetStatus.cancelled;
        tctx.log(result.message, level: 'warning');
        ctx.emit(BuildTargetFinished(target, status: PackageTargetStatus.cancelled, message: result.message, duration: sw.elapsed));
        for (final rest in targets.skip(i + 1)) {
          outcome[rest] = PackageTargetStatus.cancelled;
          ctx.emit(BuildTargetFinished(rest, status: PackageTargetStatus.cancelled, message: 'cancelled before it started', duration: Duration.zero));
        }
        return StepResult.cancelled('Packaging cancelled during $label');
      }
      if (result.status != BuildStepStatus.ok || result.artifactPath == null) {
        outcome[target] = PackageTargetStatus.failed;
        tctx.log(result.message, level: 'error');
        ctx.emit(BuildTargetFinished(target, status: PackageTargetStatus.failed, message: result.message, duration: sw.elapsed));
        continue;
      }
      final packageDir = packageDirFor(target);
      try {
        final bytes = copyArtifact(result.artifactPath!, packageDir);
        await afterPackage?.call(tctx, target, result.artifactPath!, packageDir);
        outcome[target] = PackageTargetStatus.ok;
        final msg = '$label packaged into $packageDir (${CookAndPackageStep.formatBytes(bytes)})';
        tctx.log(msg, level: 'success');
        ctx.emit(BuildTargetFinished(target, status: PackageTargetStatus.ok, message: msg, packageDir: packageDir, duration: sw.elapsed));
      } catch (e) {
        outcome[target] = PackageTargetStatus.failed;
        final msg = 'Could not copy ${result.artifactPath} into $packageDir: $e';
        tctx.log(msg, level: 'error');
        ctx.emit(BuildTargetFinished(target, status: PackageTargetStatus.failed, message: msg, duration: sw.elapsed));
      }
    }
    final summary = 'Packaged ${outcome.values.where((s) => s == PackageTargetStatus.ok).length}/${targets.length} target(s): '
        '${targets.map((t) => '${packagingPlatformLabel(t)} ${_statusWord(outcome[t])}').join(', ')}';
    if (ctx.token.isCancelled) return StepResult.cancelled(summary);
    return outcome.values.every((s) => s == PackageTargetStatus.ok) ? StepResult.ok(summary) : StepResult.failed(summary);
  }

  static String _statusWord(PackageTargetStatus? s) => switch (s) {
        PackageTargetStatus.ok => 'OK',
        PackageTargetStatus.unbuildable => 'not buildable',
        PackageTargetStatus.cancelled => 'cancelled',
        PackageTargetStatus.failed => 'failed',
        _ => 'not run',
      };

  /// Replaces [to] with a copy of [from] (a folder's contents, or a single
  /// file such as an APK); returns the bytes copied. Refuses to copy a folder
  /// into itself.
  static int copyArtifact(String from, String to) {
    String norm(String p) => Directory(p).absolute.path.replaceAll(RegExp(r'/+$'), '');
    final src = norm(from);
    final dst = norm(to);
    if (dst == src || dst.startsWith('$src/') || src.startsWith('$dst/')) {
      throw StateError('the package folder $dst and the build output $src overlap: choose another output directory');
    }
    final out = Directory(dst);
    if (out.existsSync()) out.deleteSync(recursive: true);
    out.createSync(recursive: true);
    final type = FileSystemEntity.typeSync(src, followLinks: false);
    if (type == FileSystemEntityType.file) {
      final copy = File(src).copySync('$dst/${src.split('/').last}');
      return copy.lengthSync();
    }
    if (type != FileSystemEntityType.directory) throw StateError('$src does not exist');
    var bytes = 0;
    for (final e in Directory(src).listSync(recursive: true, followLinks: false)) {
      final rel = e.path.substring(src.length + 1);
      final target = '$dst/$rel';
      if (e is Link) {
        Link(target).createSync(e.targetSync(), recursive: true);
      } else if (e is Directory) {
        Directory(target).createSync(recursive: true);
      } else if (e is File) {
        File(target).parent.createSync(recursive: true);
        bytes += e.copySync(target).lengthSync();
      }
    }
    return bytes;
  }
}

class _SplitLine {
  final String text;
  final bool replaceLast;
  const _SplitLine(this.text, this.replaceLast);
}

/// Splits on `\n` and treats a bare `\r` as "replace the last line" so
/// `flutter build`'s spinner updates do not flood the console.
class _CarriageReturnLineSplitter extends StreamTransformerBase<String, _SplitLine> {
  const _CarriageReturnLineSplitter();

  @override
  Stream<_SplitLine> bind(Stream<String> stream) {
    final controller = StreamController<_SplitLine>();
    final buf = StringBuffer();
    var replaceNext = false;
    void flush(bool replace) {
      controller.add(_SplitLine(buf.toString(), replace));
      buf.clear();
    }

    final sub = stream.listen((chunk) {
      for (var i = 0; i < chunk.length; i++) {
        final ch = chunk[i];
        if (ch == '\n') {
          if (buf.isNotEmpty || !replaceNext) flush(replaceNext);
          replaceNext = false;
        } else if (ch == '\r') {
          if (i + 1 < chunk.length && chunk[i + 1] == '\n') continue; // CRLF
          if (buf.isNotEmpty) {
            flush(replaceNext);
            replaceNext = true;
          }
        } else {
          buf.write(ch);
        }
      }
    }, onError: controller.addError, onDone: () {
      if (buf.isNotEmpty) flush(replaceNext);
      controller.close();
    });
    controller.onCancel = sub.cancel;
    return controller.stream;
  }
}
