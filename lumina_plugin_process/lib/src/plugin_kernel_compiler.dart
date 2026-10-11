import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'package:lumina_plugin_process/src/testing/process_reach.dart';

/// Why [PluginKernelCompiler.compile] did not produce a kernel.
class PluginKernelCompileException implements Exception {
  PluginKernelCompileException(this.message, {this.output = '', this.reachedFlutter = false});

  /// One line: what failed.
  final String message;

  /// What the failing tool printed (the compiler's diagnostics, `pub get`'s
  /// errors), or the import chains that reach Flutter.
  final String output;

  /// The entry's import graph reaches Flutter or `dart:ui`: a kernel plugin
  /// cannot run on the plain Dart VM.
  final bool reachedFlutter;

  @override
  String toString() => output.isEmpty ? message : '$message\n$output';
}

/// What [PluginKernelCompiler.compile] produced.
class PluginKernelCompileResult {
  const PluginKernelCompileResult({required this.kernel, required this.sha256File, required this.sdkVersion});

  /// The `.dill`.
  final File kernel;

  /// `<kernel>.sha256`: the kernel's SHA-256, hex.
  final File sha256File;

  /// The Dart SDK version that compiled it (e.g. `3.13.4`).
  final String sdkVersion;
}

/// Compiles a kernel plugin's process entry into a Dart kernel file
/// (`dart compile kernel`), for the pack script and for the editor's
/// startup recompile.
///
/// Before compiling, the plugin's packages are resolved when no
/// `.dart_tool/package_config.json` covers it (`dart pub get --offline`,
/// then online), and the entry's import graph is walked
/// ([PluginProcessReach.ofEntry]): an entry that reaches Flutter or
/// `dart:ui` is refused, since the kernel runs on the plain Dart VM. A
/// kernel only runs on the exact SDK that produced it, so the result names
/// that SDK's version.
class PluginKernelCompiler {
  PluginKernelCompiler(this.dartExecutable);

  /// `<dart-sdk>/bin/dart(.exe)`.
  final String dartExecutable;

  static final RegExp _version = RegExp(r'Dart SDK version:\s*(\S+)');

  /// The SDK version `<dartExecutable> --version` prints (`3.13.4`).
  static Future<String> sdkVersionOf(String dartExecutable) async {
    final r = await Process.run(dartExecutable, const ['--version'], runInShell: _needsShell(dartExecutable));
    final match = _version.firstMatch('${r.stdout}\n${r.stderr}');
    if (r.exitCode != 0 || match == null) {
      throw PluginKernelCompileException('could not read the Dart SDK version of $dartExecutable',
          output: '${r.stdout}${r.stderr}'.trim());
    }
    return match.group(1)!;
  }

  /// A hash of what a kernel is compiled from: the entry, every Dart file
  /// under the plugin's `lib/` and its `pubspec.lock` (paths included, so a
  /// rename counts). The editor's kernel cache is keyed by it.
  static Future<String> sourceHash(Directory pluginDir, String entry) async {
    final files = <File>[File(p.join(pluginDir.path, entry))];
    final lib = Directory(p.join(pluginDir.path, 'lib'));
    if (await lib.exists()) {
      final libFiles = await lib.list(recursive: true).where((e) => e is File && e.path.endsWith('.dart')).cast<File>().toList();
      libFiles.sort((a, b) => a.path.compareTo(b.path));
      files.addAll(libFiles);
    }
    files.add(File(p.join(pluginDir.path, 'pubspec.lock')));
    final sink = _DigestSink();
    final input = sha256.startChunkedConversion(sink);
    for (final f in files) {
      input.add(utf8.encode('${p.relative(f.path, from: pluginDir.path).replaceAll(r'\', '/')}\u0000'));
      if (await f.exists()) input.add(await f.readAsBytes());
      input.add(const [0]);
    }
    input.close();
    return sink.value.toString();
  }

  /// Writes `<kernel>.sha256` (`<hex>  <file name>`) and returns it.
  static Future<File> writeSha256(File kernel) async {
    final file = File('${kernel.path}.sha256');
    await file.writeAsString('${sha256.convert(await kernel.readAsBytes())}  ${p.basename(kernel.path)}\n');
    return file;
  }

  /// Null when `<kernel>.sha256` holds [kernel]'s SHA-256, else why not.
  static Future<String?> verifySha256(File kernel) async {
    final file = File('${kernel.path}.sha256');
    if (!await kernel.exists()) return '${p.basename(kernel.path)} is missing';
    if (!await file.exists()) return '${p.basename(kernel.path)} has no .sha256 file';
    final expected = (await file.readAsString()).trim().split(RegExp(r'\s+')).first.toLowerCase();
    final actual = sha256.convert(await kernel.readAsBytes()).toString();
    if (expected != actual) return 'the SHA-256 of ${p.basename(kernel.path)} does not match its .sha256 file';
    return null;
  }

  /// Compiles [entry] (relative to [pluginDir]) into [output] and writes
  /// `<output>.sha256`. [onProgress] gets one line per stage. Throws a
  /// [PluginKernelCompileException] naming the stage that failed.
  Future<PluginKernelCompileResult> compile({
    required Directory pluginDir,
    required String entry,
    required File output,
    void Function(String line)? onProgress,
  }) async {
    // A plugin linked into a plugin folder (a developer's checkout) resolves
    // its packages relative to the checkout, not the link.
    if (await pluginDir.exists()) pluginDir = Directory(await pluginDir.resolveSymbolicLinks());
    final entryFile = File(p.join(pluginDir.path, entry));
    if (!await entryFile.exists()) {
      throw PluginKernelCompileException('the process entry $entry is missing in ${pluginDir.path}');
    }
    final config = await _packageConfig(pluginDir, onProgress);

    onProgress?.call('Checking that $entry is pure Dart');
    final PluginProcessReach reach;
    try {
      reach = PluginProcessReach.ofEntry(entryFile, pluginDir: pluginDir, packages: PluginPackageRoots.read(config.parent.parent));
    } on Object catch (e) {
      throw PluginKernelCompileException('could not read the imports of $entry: $e');
    }
    if (reach.flutterPackages.isNotEmpty) {
      throw PluginKernelCompileException(
        '$entry reaches Flutter (${(reach.flutterPackages.toList()..sort()).join(', ')}): a kernel plugin runs on the '
        'plain Dart VM, so its process may not import Flutter or dart:ui',
        output: reach.describeFlutter(),
        reachedFlutter: true,
      );
    }

    final sdk = await sdkVersionOf(dartExecutable);
    onProgress?.call('Compiling $entry with Dart $sdk');
    await output.parent.create(recursive: true);
    final partial = File('${output.path}.part');
    final r = await Process.run(
      dartExecutable,
      ['compile', 'kernel', '--packages=${config.path}', '--verbosity=error', '-o', partial.path, entryFile.path],
      workingDirectory: pluginDir.path,
      runInShell: _needsShell(dartExecutable),
    );
    if (r.exitCode != 0 || !await partial.exists()) {
      if (await partial.exists()) await partial.delete();
      throw PluginKernelCompileException('dart compile kernel failed for $entry (exit ${r.exitCode})',
          output: '${r.stdout}${r.stderr}'.trim());
    }
    if (await output.exists()) await output.delete();
    await partial.rename(output.path);
    final shaFile = File('${output.path}.sha256');
    await shaFile.writeAsString('${sha256.convert(await output.readAsBytes())}  ${p.basename(output.path)}\n');
    onProgress?.call('Compiled ${p.basename(output.path)}');
    return PluginKernelCompileResult(kernel: output, sha256File: shaFile, sdkVersion: sdk);
  }

  /// The package config covering [pluginDir] (its own or a workspace
  /// root's); resolved with `dart pub get` (offline first) when none.
  Future<File> _packageConfig(Directory pluginDir, void Function(String line)? onProgress) async {
    File? find() {
      var dir = pluginDir.absolute;
      while (true) {
        final f = File(p.join(dir.path, '.dart_tool', 'package_config.json'));
        if (f.existsSync()) return f;
        if (File(p.join(dir.path, 'pubspec.yaml')).existsSync() && dir.path != pluginDir.absolute.path) {
          // A parent package that is not a workspace root of this one.
          if (!File(p.join(dir.path, 'pubspec.yaml')).readAsStringSync().contains('workspace:')) return null;
        }
        if (dir.parent.path == dir.path) return null;
        dir = dir.parent;
      }
    }

    final existing = find();
    if (existing != null) return existing;
    if (!await File(p.join(pluginDir.path, 'pubspec.yaml')).exists()) {
      throw PluginKernelCompileException('${pluginDir.path} has no pubspec.yaml: its packages cannot be resolved');
    }
    final outputs = <String>[];
    for (final offline in const [true, false]) {
      onProgress?.call(offline ? 'Resolving packages (offline)' : 'Resolving packages');
      final r = await Process.run(
        dartExecutable,
        ['pub', 'get', if (offline) '--offline'],
        workingDirectory: pluginDir.path,
        runInShell: _needsShell(dartExecutable),
      );
      outputs.add('${r.stdout}${r.stderr}'.trim());
      final found = find();
      if (r.exitCode == 0 && found != null) return found;
    }
    throw PluginKernelCompileException("the plugin's packages do not resolve (dart pub get failed)",
        output: outputs.join('\n'));
  }

  static bool _needsShell(String exe) => Platform.isWindows && !exe.toLowerCase().endsWith('.exe');
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
