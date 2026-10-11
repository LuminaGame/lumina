import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:lumina_plugin_process/lumina_plugin_process.dart';
import 'package:lumina_plugin_process/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A real kernel plugin folder in [tmp]: a pubspec, `bin/<entry>` and a
/// package config mapping the plugin to itself and every other package to
/// the workspace's real ones.
Directory _plugin(Directory tmp, String entrySource, {String name = 'pure_sample'}) {
  final dir = Directory(p.join(tmp.path, name))..createSync();
  File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: $name\nenvironment:\n  sdk: ^3.12.0\n');
  File(p.join(dir.path, 'bin', '${name}_process.dart'))
    ..createSync(recursive: true)
    ..writeAsStringSync(entrySource);
  File(p.join(dir.path, 'lib', '$name.dart'))
    ..createSync(recursive: true)
    ..writeAsStringSync('const String kGreeting = "hello";\n');
  final real = PluginPackageRoots.read();
  final packages = [
    for (final n in real.roots.keys)
      if (n != name) {'name': n, 'rootUri': real.roots[n]!.uri.toString(), 'packageUri': 'lib/'},
    {'name': name, 'rootUri': dir.uri.toString(), 'packageUri': 'lib/'},
  ];
  File(p.join(dir.path, '.dart_tool', 'package_config.json'))
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode({'configVersion': 2, 'packages': packages}));
  return dir;
}

String _pureSampleSource() {
  final candidates = [
    p.join(Directory.current.path, 'example', 'pure_process.dart'),
    p.join(Directory.current.path, 'lumina_plugin_process', 'example', 'pure_process.dart'),
  ];
  return File(candidates.firstWhere((c) => File(c).existsSync())).readAsStringSync();
}

void main() {
  final dart = Platform.resolvedExecutable;
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('kernel_compiler_'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold a handle; the temp dir is cleaned later.
    }
  });

  test('sdkVersionOf reads the version dart --version prints', () async {
    final r = await Process.run(dart, ['--version']);
    final printed = '${r.stdout}${r.stderr}';
    final version = await PluginKernelCompiler.sdkVersionOf(dart);
    expect(version, matches(RegExp(r'^\d+\.\d+\.\d+')));
    expect(printed, contains('Dart SDK version: $version '));
  });

  test('compiles the pure sample entry: a .dill, its .sha256 and the SDK version; the kernel runs on the VM',
      () async {
    final dir = _plugin(tmp, _pureSampleSource());
    final out = File(p.join(dir.path, 'bin', 'pure_sample_process.dill'));
    final progress = <String>[];
    final result = await PluginKernelCompiler(dart).compile(
      pluginDir: dir,
      entry: 'bin/pure_sample_process.dart',
      output: out,
      onProgress: progress.add,
    );
    expect(out.existsSync(), isTrue);
    expect(result.kernel.path, out.path);
    expect(result.sdkVersion, await PluginKernelCompiler.sdkVersionOf(dart));
    final sha = File('${out.path}.sha256');
    expect(sha.readAsStringSync().split(' ').first, sha256.convert(out.readAsBytesSync()).toString());
    expect(await PluginKernelCompiler.verifySha256(out), isNull, reason: 'the written hash matches');
    expect(progress, isNotEmpty);

    // The kernel runs: without launch flags the sample prints its usage.
    final run = await Process.run(dart, [out.path]);
    expect(run.exitCode, 64, reason: '${run.stdout}${run.stderr}');
    expect('${run.stderr}', contains('usage'));
  });

  test('a tampered kernel fails the hash check, naming why', () async {
    final dir = _plugin(tmp, _pureSampleSource());
    final out = File(p.join(dir.path, 'bin', 'pure_sample_process.dill'));
    await PluginKernelCompiler(dart).compile(pluginDir: dir, entry: 'bin/pure_sample_process.dart', output: out);
    out.writeAsBytesSync([...out.readAsBytesSync(), 1, 2, 3]);
    expect(await PluginKernelCompiler.verifySha256(out), contains('does not match'));
    File('${out.path}.sha256').deleteSync();
    expect(await PluginKernelCompiler.verifySha256(out), contains('no .sha256'));
  });

  test('an entry importing package:flutter/widgets.dart is refused by the reach guard before compiling', () async {
    final dir = _plugin(tmp, "import 'package:flutter/widgets.dart';\n\nvoid main() => runApp(const SizedBox());\n");
    final out = File(p.join(dir.path, 'bin', 'pure_sample_process.dill'));
    await expectLater(
      PluginKernelCompiler(dart).compile(pluginDir: dir, entry: 'bin/pure_sample_process.dart', output: out),
      throwsA(isA<PluginKernelCompileException>()
          .having((e) => e.message, 'message', allOf(contains('Flutter'), contains('flutter')))
          .having((e) => e.reachedFlutter, 'reachedFlutter', isTrue)),
    );
    expect(out.existsSync(), isFalse, reason: 'nothing was compiled');
  });

  test('an entry with a compile error fails with the compiler output', () async {
    final dir = _plugin(tmp, 'void main() { final int x = "not an int"; }\n');
    final out = File(p.join(dir.path, 'bin', 'pure_sample_process.dill'));
    await expectLater(
      PluginKernelCompiler(dart).compile(pluginDir: dir, entry: 'bin/pure_sample_process.dart', output: out),
      throwsA(isA<PluginKernelCompileException>().having((e) => e.output, 'output', contains('not an int'))),
    );
  });

  test('the source hash follows the entry, lib/ and pubspec.lock', () async {
    final dir = _plugin(tmp, _pureSampleSource());
    final a = await PluginKernelCompiler.sourceHash(dir, 'bin/pure_sample_process.dart');
    expect(await PluginKernelCompiler.sourceHash(dir, 'bin/pure_sample_process.dart'), a);
    File(p.join(dir.path, 'lib', 'pure_sample.dart')).writeAsStringSync('const String kGreeting = "hi";\n');
    final b = await PluginKernelCompiler.sourceHash(dir, 'bin/pure_sample_process.dart');
    expect(b, isNot(a));
    File(p.join(dir.path, 'pubspec.lock')).writeAsStringSync('packages: {}\n');
    expect(await PluginKernelCompiler.sourceHash(dir, 'bin/pure_sample_process.dart'), isNot(b));
  });
}
