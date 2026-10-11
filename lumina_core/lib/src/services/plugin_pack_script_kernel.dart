/// The kernel-plugin part of [kPluginPackScript] (`tool/pack_plugin.dart`):
/// a plugin whose editor module is shell-less and names a `process_entry`
/// gets its process compiled with the packer's Dart SDK
/// (`dart compile kernel`), the `.dill` and its `.sha256` packed, the
/// manifest stamped with `process_kernel` / `process_kernel_sdk`, and its
/// `pubspec.lock` (a workspace member's from the workspace root, its
/// pubspec without `resolution: workspace`) packed so the editor can
/// recompile it for another SDK. An entry that imports Flutter or
/// `dart:ui` is refused.
library;

/// Appended to the main script's source (dart: libraries only).
const String kPluginPackScriptKernelPart = r'''

// ── Kernel plugins ─────────────────────────────────────────────────────────

/// The editor module of a kernel plugin (`"isolation": "process"`, a
/// `process_class` and `process_entry`, no `registration_class`), or null.
Map<String, Object?>? _kernelModule(Map<String, Object?> manifest) {
  if (manifest['isolation'] != 'process') return null;
  for (final m in (manifest['modules'] as List?) ?? const []) {
    if (m is Map &&
        m['type'] == 'editor' &&
        m['process_class'] is String &&
        m['registration_class'] == null &&
        m['process_entry'] is String) {
      return m.cast<String, Object?>();
    }
  }
  return null;
}

/// Compiles a kernel plugin's process entry with this Dart SDK and stamps
/// the manifest; adds the files the pack must carry to [include] and the
/// zip entries written from memory to [overrides]. Returns the problems
/// (empty when it worked).
Future<List<String>> _packKernel(
  Directory root,
  File manifestFile,
  Map<String, Object?> manifest,
  Map<String, Object?> module, {
  required bool dryRun,
  required List<String> include,
  required Map<String, List<int>> overrides,
}) async {
  final entry = (module['process_entry'] as String).replaceAll(r'\', '/');
  if (entry.startsWith('/') || entry.split('/').contains('..') || RegExp(r'^[A-Za-z]:').hasMatch(entry)) {
    return ['"process_entry" $entry must be a relative path inside the plugin folder'];
  }
  final entryFile = File(_join(root.path, entry));
  if (!entryFile.existsSync()) return ['"process_entry" names $entry, which does not exist'];
  final kernel = (module['process_kernel'] as String? ?? '${entry.substring(0, entry.length - 5)}.dill').replaceAll(r'\', '/');

  // The process runs on the plain Dart VM: no Flutter anywhere it imports.
  final pubspec = File(_join(root.path, 'pubspec.yaml'));
  final package = pubspec.existsSync() ? _yamlScalar(pubspec.readAsStringSync(), 'name') : null;
  final flutter = _flutterImports(root, entry, package);
  if (flutter.isNotEmpty) {
    return [
      'the kernel plugin process $entry reaches Flutter, which the plain Dart VM cannot run: ${flutter.join('; ')} '
          '(move the Flutter code out of the process part)',
    ];
  }

  // Packages resolved (which also writes the lock a recompile resolves
  // with); the lock travels even when a .gitignore leaves it out.
  if (!dryRun && !_hasPackageConfig(root)) {
    final get = await Process.run(_dartExecutable(), ['pub', 'get'], workingDirectory: root.path, runInShell: _viaShell());
    if (get.exitCode != 0) return ['dart pub get failed:\n${get.stdout}${get.stderr}'];
  }
  final lock = File(_join(root.path, 'pubspec.lock'));
  if (lock.existsSync()) {
    include.add('pubspec.lock');
  } else {
    final workspaceLock = _workspaceLock(root);
    if (workspaceLock == null) {
      return ['a kernel plugin packs its pubspec.lock (the editor recompiles with it): run dart pub get first'];
    }
    overrides['pubspec.lock'] = workspaceLock.readAsBytesSync();
  }
  if (pubspec.existsSync()) {
    final text = pubspec.readAsStringSync();
    if (RegExp(r'^resolution:\s*workspace\s*$', multiLine: true).hasMatch(text)) {
      overrides['pubspec.yaml'] =
          utf8.encode(text.replaceAll(RegExp(r'^resolution:\s*workspace\s*\r?\n?', multiLine: true), ''));
    }
  }
  include
    ..add(entry)
    ..add(kernel)
    ..add('$kernel.sha256')
    ..addAll(overrides.keys);
  if (dryRun) {
    stdout.writeln('Dry run: would compile $entry into $kernel with Dart ${_sdkVersion()}.');
    include.removeWhere((f) => f == kernel || f == '$kernel.sha256');
    return const [];
  }

  // The kernel.
  final out = File(_join(root.path, kernel));
  out.parent.createSync(recursive: true);
  final compile = await Process.run(
    _dartExecutable(),
    ['compile', 'kernel', '--verbosity=error', '-o', out.path, entryFile.path],
    workingDirectory: root.path,
    runInShell: _viaShell(),
  );
  if (compile.exitCode != 0 || !out.existsSync()) {
    return ['dart compile kernel failed for $entry:\n${compile.stdout}${compile.stderr}'];
  }
  File('${out.path}.sha256').writeAsStringSync('${_sha256Hex(out.readAsBytesSync())}  ${_name(out.path)}\n');
  final sdk = _sdkVersion();
  module['process_kernel'] = kernel;
  module['process_kernel_sdk'] = sdk;
  manifestFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(manifest)}\n');
  stdout.writeln('Compiled the process kernel $kernel with Dart $sdk.');
  return const [];
}

/// The Dart SDK running this script (`3.13.4`).
String _sdkVersion() => Platform.version.split(' ').first;

/// The `dart` running this script, else `dart` on PATH.
String _dartExecutable() {
  final exe = Platform.resolvedExecutable;
  final name = _name(exe).toLowerCase();
  return name == 'dart' || name == 'dart.exe' ? exe : 'dart';
}

/// `dart` from PATH is a batch file on Windows.
bool _viaShell() => Platform.isWindows && _dartExecutable() == 'dart';

bool _hasPackageConfig(Directory root) {
  var dir = root.absolute;
  while (true) {
    if (File(_join(dir.path, '.dart_tool/package_config.json')).existsSync()) return true;
    if (dir.parent.path == dir.path) return false;
    dir = dir.parent;
  }
}

/// The `pubspec.lock` of the pub workspace [root] belongs to, or null.
File? _workspaceLock(Directory root) {
  var dir = root.absolute.parent;
  while (dir.parent.path != dir.path) {
    final pubspec = File(_join(dir.path, 'pubspec.yaml'));
    final lock = File(_join(dir.path, 'pubspec.lock'));
    if (pubspec.existsSync() && RegExp(r'^workspace:', multiLine: true).hasMatch(pubspec.readAsStringSync())) {
      return lock.existsSync() ? lock : null;
    }
    dir = dir.parent;
  }
  return null;
}

/// The Flutter imports reached from [entry] through the plugin's own
/// libraries (relative imports and `package:<package>/`): `<file>: <uri>`.
List<String> _flutterImports(Directory root, String entry, String? package) {
  final found = <String>[];
  final seen = <String>{};
  final todo = [entry];
  final directive = RegExp(r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""", multiLine: true);
  while (todo.isNotEmpty) {
    final rel = todo.removeLast();
    if (!seen.add(rel)) continue;
    final file = File(_join(root.path, rel));
    if (!file.existsSync()) continue;
    for (final m in directive.allMatches(file.readAsStringSync())) {
      final uri = m.group(1)!;
      if (uri.startsWith('package:flutter/') || uri.startsWith('package:flutter_test/') || uri == 'dart:ui') {
        found.add('$rel: $uri');
      } else if (package != null && uri.startsWith('package:$package/')) {
        todo.add('lib/${uri.substring('package:$package/'.length)}');
      } else if (!uri.contains(':')) {
        final parts = [...rel.split('/')..removeLast(), ...uri.split('/')];
        final out = <String>[];
        for (final p in parts) {
          if (p == '..') {
            if (out.isNotEmpty) out.removeLast();
          } else if (p != '.') {
            out.add(p);
          }
        }
        todo.add(out.join('/'));
      }
    }
  }
  return found;
}

/// SHA-256 of [data], hex (FIPS 180-4; dart: libraries have none).
String _sha256Hex(List<int> data) {
  const k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, //
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];
  final h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
  final bitLength = data.length * 8;
  final padded = BytesBuilder(copy: false)
    ..add(data)
    ..addByte(0x80);
  var length = data.length + 1;
  while (length % 64 != 56) {
    padded.addByte(0);
    length++;
  }
  for (var i = 7; i >= 0; i--) {
    padded.addByte((bitLength >> (i * 8)) & 0xFF);
  }
  final bytes = padded.takeBytes();
  int rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;
  final w = List<int>.filled(64, 0);
  for (var chunk = 0; chunk < bytes.length; chunk += 64) {
    for (var i = 0; i < 16; i++) {
      final j = chunk + i * 4;
      w[i] = (bytes[j] << 24) | (bytes[j + 1] << 16) | (bytes[j + 2] << 8) | bytes[j + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ ((~e & 0xFFFFFFFF) & g);
      final t1 = (hh + s1 + ch + k[i] + w[i]) & 0xFFFFFFFF;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & 0xFFFFFFFF;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & 0xFFFFFFFF;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xFFFFFFFF;
    }
    final add = [a, b, c, d, e, f, g, hh];
    for (var i = 0; i < 8; i++) {
      h[i] = (h[i] + add[i]) & 0xFFFFFFFF;
    }
  }
  return h.map((v) => v.toRadixString(16).padLeft(8, '0')).join();
}
''';
