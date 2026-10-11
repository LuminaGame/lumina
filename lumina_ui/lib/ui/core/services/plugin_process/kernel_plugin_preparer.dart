import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show PluginKernelCompileException, PluginKernelCompiler;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:path/path.dart' as p;

import 'package:lumina_ui/ui/core/services/plugin_process/kernel_dart_sdk.dart';

/// Where the kernel a kernel plugin runs came from.
enum KernelSource {
  /// The `.dill` the plugin ships, built by this Dart SDK.
  shipped,

  /// Recompiled from the plugin's source for this Dart SDK just now.
  recompiled,

  /// A kernel recompiled earlier for this plugin version, source and SDK.
  cached,
}

/// A kernel plugin's kernel as the Plugin Manager shows it.
class KernelPluginState {
  KernelPluginState(this.plugin);

  final String plugin;

  /// The Dart SDK version of the VM that runs it.
  String? vmSdk;

  /// The SDK stamp of the shipped kernel (`process_kernel_sdk`).
  String? shippedSdk;
  KernelSource? source;
  String? kernelPath;

  /// The stage of a running preparation ("Preparing … for Dart 3.13.4…"),
  /// null when none runs.
  String? progress;

  /// Why the last preparation failed (with [errorOutput], the compiler's or
  /// `pub get`'s output), null when it did not.
  String? error;
  String? errorOutput;
}

/// Why a kernel plugin cannot start: no Dart SDK, a kernel whose hash does
/// not match, an entry that does not compile. A Plugin Manager error, never
/// an editor error.
class KernelPrepareException implements Exception {
  KernelPrepareException(this.message, {this.output = ''});

  final String message;
  final String output;

  @override
  String toString() => output.isEmpty ? message : '$message\n$output';
}

/// What [KernelPluginPreparer.prepare] settled on.
class KernelPreparation {
  const KernelPreparation({required this.dart, required this.kernel, required this.source, required this.vmSdk});

  /// `<dart-sdk>/bin/dart(.exe)` that runs [kernel].
  final String dart;
  final String kernel;
  final KernelSource source;
  final String vmSdk;
}

/// Decides which kernel a kernel plugin runs on this machine's Dart VM, and
/// makes it when needed.
///
/// The shipped `.dill` must match its `.sha256` before anything runs. When
/// its `process_kernel_sdk` is the VM's SDK version it runs as shipped;
/// when it differs, the `.dill` is missing, or the VM refused it last time,
/// the plugin's `process_entry` is compiled with this SDK
/// ([PluginKernelCompiler], on a background isolate) into
/// `<LuminaDataDir>/plugin_kernels/<name>/<version>/<sdk>/<source hash>.dill`
/// and that runs; a cached kernel is reused while plugin version, source and
/// SDK match.
class KernelPluginPreparer extends ChangeNotifier {
  KernelPluginPreparer({String? Function()? dartExecutable, Directory? cacheRoot})
      : _dart = dartExecutable ?? KernelDartSdk.dartExecutable,
        _cacheRoot = cacheRoot; // ignore: prefer_initializing_formals

  final String? Function() _dart;
  final Directory? _cacheRoot;

  /// `<LuminaDataDir>/plugin_kernels`.
  Directory get cacheRoot => _cacheRoot ?? Directory(p.join(LuminaDataDir.resolve().path, 'plugin_kernels'));

  final Map<String, KernelPluginState> _states = {};
  final Map<String, Future<String>> _sdkVersions = {};

  /// [plugin]'s kernel state, or null before its first preparation.
  KernelPluginState? stateOf(String plugin) => _states[plugin];

  /// The SDK version of [dart] (`dart --version`), read once.
  Future<String> vmSdkVersion(String dart) => _sdkVersions.putIfAbsent(dart, () => PluginKernelCompiler.sdkVersionOf(dart));

  /// Whether a kernel run's [stderr] shows the Dart VM refusing the kernel
  /// (built by another SDK).
  static bool vmRefusedKernel(List<String> stderr) => stderr.any((l) =>
      l.contains('Invalid SDK hash') ||
      l.contains("Can't load Kernel binary") ||
      l.contains('Invalid kernel binary') ||
      l.contains('Unexpected Kernel Format Version'));

  /// The cache file of [d]'s kernel compiled by SDK [sdk] from sources
  /// hashing to [sourceHash].
  File cachedKernel(LuminaPluginDescriptor d, String sdk, String sourceHash) =>
      File(p.join(cacheRoot.path, d.name, d.version.toString(), sdk, '$sourceHash.dill'));

  /// The kernel [d] runs now; [vmRefused] when the VM refused the shipped
  /// one. [onProgress] gets each stage. Throws a [KernelPrepareException].
  Future<KernelPreparation> prepare(LuminaPluginDescriptor d,
      {bool vmRefused = false, void Function(String line)? onProgress}) async {
    final state = _states.putIfAbsent(d.name, () => KernelPluginState(d.name));
    final label = d.friendlyName ?? d.name;
    void step(String line) {
      state.progress = line;
      onProgress?.call(line);
      notifyListeners();
    }

    state
      ..error = null
      ..errorOutput = null
      ..shippedSdk = d.processModule?.processKernelSdk;
    try {
      final dart = _dart();
      if (dart == null) {
        throw KernelPrepareException('no Dart SDK found: kernel plugins run on the Dart SDK of the Flutter SDK '
            'Lumina builds projects with (install Flutter, put it on PATH or set FLUTTER_ROOT)');
      }
      final vm = state.vmSdk = await vmSdkVersion(dart);
      final shipped = d.processKernelFile;
      if (shipped != null && await shipped.exists()) {
        final mismatch = await PluginKernelCompiler.verifySha256(shipped);
        if (mismatch != null) throw KernelPrepareException('$label is not started: $mismatch');
        if (!vmRefused && d.processModule?.processKernelSdk == vm) {
          return _done(state, KernelPreparation(dart: dart, kernel: shipped.path, source: KernelSource.shipped, vmSdk: vm));
        }
      }
      final entry = d.processModule?.processEntry;
      if (entry == null) throw KernelPrepareException('$label names no process_entry to compile');
      final hash = await PluginKernelCompiler.sourceHash(d.pluginDir, entry);
      final cached = cachedKernel(d, vm, hash);
      if (await cached.exists() && await PluginKernelCompiler.verifySha256(cached) == null) {
        return _done(state, KernelPreparation(dart: dart, kernel: cached.path, source: KernelSource.cached, vmSdk: vm));
      }
      step('Preparing $label for Dart $vm…');
      await _compileInBackground(dart, d.pluginDir.path, entry, cached.path, (line) => step('Preparing $label for Dart $vm: $line'));
      return _done(state, KernelPreparation(dart: dart, kernel: cached.path, source: KernelSource.recompiled, vmSdk: vm));
    } on PluginKernelCompileException catch (e) {
      throw _failed(state, KernelPrepareException('$label could not be compiled for this Dart SDK: ${e.message}', output: e.output));
    } on KernelPrepareException catch (e) {
      throw _failed(state, e);
    } catch (e) {
      throw _failed(state, KernelPrepareException('$label could not be prepared: $e'));
    }
  }

  KernelPreparation _done(KernelPluginState state, KernelPreparation prep) {
    state
      ..source = prep.source
      ..kernelPath = prep.kernel
      ..progress = null;
    notifyListeners();
    return prep;
  }

  KernelPrepareException _failed(KernelPluginState state, KernelPrepareException e) {
    state
      ..error = e.message
      ..errorOutput = e.output
      ..progress = null;
    notifyListeners();
    return e;
  }

  /// Compiles on a background isolate (the reach walk and hashing read
  /// files; `pub get` and the compiler run as child processes): progress
  /// lines come back through a port.
  static Future<void> _compileInBackground(
      String dart, String pluginDir, String entry, String output, void Function(String line) progress) async {
    final port = ReceivePort();
    final sub = port.listen((m) {
      if (m is String) progress(m);
    });
    try {
      final failure = await Isolate.run(_compileTask(dart, pluginDir, entry, output, port.sendPort));
      if (failure != null) {
        throw PluginKernelCompileException(failure[0] as String, output: failure[1] as String, reachedFlutter: failure[2] as bool);
      }
    } finally {
      await sub.cancel();
      port.close();
    }
  }
}

/// The background isolate's job: only sendable values are captured (the
/// paths and the progress port). A failure comes back as
/// `[message, output, reachedFlutter]`.
Future<List<Object>?> Function() _compileTask(String dart, String pluginDir, String entry, String output, SendPort progress) =>
    () async {
      try {
        await PluginKernelCompiler(dart).compile(
          pluginDir: Directory(pluginDir),
          entry: entry,
          output: File(output),
          onProgress: progress.send,
        );
        return null;
      } on PluginKernelCompileException catch (e) {
        return [e.message, e.output, e.reachedFlutter];
      }
    };
