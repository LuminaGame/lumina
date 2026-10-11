import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/kernel_plugin_preparer.dart';
import 'package:path/path.dart' as p;

import 'kernel_plugin_harness.dart';
import 'plugin_process_harness.dart' show waitFor, waitForStatus;

/// The startup check of a kernel plugin, with a really compiled `.dill`
/// and the real Dart SDK: the shipped kernel runs when the SDKs match; a
/// kernel from another SDK is recompiled into the cache once.
void main() {
  late KernelPluginHarness h;

  setUp(() async => h = await KernelPluginHarness.create());
  tearDown(() => h.dispose());

  test('a kernel stamped with the VM SDK runs as shipped: no compile', () async {
    final d = await h.sample();
    final progress = <String>[];
    final prep = await h.kernels.prepare(d, onProgress: progress.add);
    expect(prep.source, KernelSource.shipped);
    expect(p.equals(prep.kernel, d.processKernelFile!.path), isTrue);
    expect(progress, isEmpty, reason: 'nothing to prepare');
    expect(h.cacheDir.existsSync(), isFalse);
    expect(h.kernels.stateOf(d.name)!.vmSdk, await PluginKernelCompiler.sdkVersionOf(sdkDart()));
  });

  test('a kernel stamped 2.19.0 is recompiled into the cache with progress, then reused', () async {
    final d = await h.sample(sdkStamp: '2.19.0');
    final progress = <String>[];
    final prep = await h.kernels.prepare(d, onProgress: progress.add);
    final vm = await PluginKernelCompiler.sdkVersionOf(sdkDart());
    expect(prep.source, KernelSource.recompiled);
    expect(progress.first, 'Preparing Kernel Sample for Dart $vm…');
    expect(progress.any((l) => l.contains('Compiling')), isTrue, reason: progress.join('\n'));
    final cachedPath = p.normalize(prep.kernel);
    expect(cachedPath, startsWith(p.normalize(p.join(h.cacheDir.path, 'kernel_sample', '1.0.0', vm))));
    expect(File(prep.kernel).existsSync(), isTrue);
    expect(await PluginKernelCompiler.verifySha256(File(prep.kernel)), isNull);

    // Second start: a cache hit, no compile.
    progress.clear();
    final again = await h.kernels.prepare(d, onProgress: progress.add);
    expect(again.source, KernelSource.cached);
    expect(p.normalize(again.kernel), cachedPath);
    expect(progress, isEmpty);

    // And it runs: the supervisor starts the cached kernel on the VM.
    await h.manager.syncKernelPlugins([d]);
    final s = h.manager.supervisorOf(d.name)!;
    await waitForStatus(s, PluginProcessStatus.running);
    expect(p.normalize(s.lastCommandLine![1]), cachedPath);
  });

  test("a corrupt kernel with a matching stamp: the VM's refusal triggers the same recompile", () async {
    final d = await h.sample();
    // Another SDK's hash in the kernel header; its .sha256 still matches
    // (the hash guards against corruption in transit, not this).
    final dill = d.processKernelFile!;
    final bytes = dill.readAsBytesSync();
    bytes.setRange(8, 18, '0123456789'.codeUnits);
    dill.writeAsBytesSync(bytes);
    await PluginKernelCompiler.writeSha256(dill);

    await h.manager.syncKernelPlugins([d]);
    final s = h.manager.supervisorOf(d.name)!;
    await waitForStatus(s, PluginProcessStatus.running, timeout: const Duration(seconds: 60));
    expect(s.logTail.join('\n'), contains('Invalid SDK hash'));
    expect(h.kernels.stateOf(d.name)!.source, KernelSource.recompiled);
    expect(p.normalize(s.lastCommandLine![1]), startsWith(p.normalize(h.cacheDir.path)));
    expect(h.crashReporter.filed, isEmpty, reason: 'a refused kernel is no crash');
  });

  test('an entry with a compile error: a Plugin Manager error with the compiler output, the editor unaffected', () async {
    final d = await h.sample(
      compile: false,
      sdkStamp: '2.19.0',
      entrySource: "import 'package:lumina_plugin_process/lumina_plugin_process.dart';\n\n"
          'Future<void> main(List<String> args) => runPluginProcessEntry(args, NoSuchProcess.new);\n',
    );
    await expectLater(
      h.kernels.prepare(d),
      throwsA(isA<KernelPrepareException>().having((e) => e.output, 'output', contains('NoSuchProcess'))),
    );
    final state = h.kernels.stateOf(d.name)!;
    expect(state.error, contains('could not be compiled'));
    expect(state.errorOutput, contains('NoSuchProcess'));

    // Through the supervisor: stopped with the reason, no crash report, no
    // restart loop.
    await h.manager.syncKernelPlugins([d]);
    final s = h.manager.supervisorOf(d.name)!;
    await waitFor(() => s.state.value.status == PluginProcessStatus.stopped && s.preparationError != null);
    expect(s.state.value.reason, contains('could not be prepared'));
    expect(s.preparationError, contains('NoSuchProcess'));
    expect(s.startCount, 0, reason: 'nothing was launched');
    expect(h.crashReporter.filed, isEmpty);
  });
}
