import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The newest `libflutter_filament.so` a Linux build left under [roots], or null.
File? _newestLinuxLibrary(List<String> roots) {
  final found = <File>[
    for (final root in roots)
      if (Directory(root).existsSync())
        for (final f in Directory(root).listSync(recursive: true, followLinks: false).whereType<File>())
          if (f.path.endsWith('/libflutter_filament.so') && !f.path.contains('/android')) f,
  ];
  if (found.isEmpty) return null;
  found.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  return found.first;
}

void main() {
  final hookSource = File('hook/build.dart').readAsStringSync();
  // The Linux branch of the hook's link flags.
  final linuxStart = hookSource.indexOf('] else if (targetOS == OS.linux) ...[');
  final linux = hookSource.substring(
    linuxStart,
    hookSource.indexOf('// Unquoted: engine_c.cpp stringizes it.', linuxStart),
  );

  group('Linux linking', () {
    test('the NGX entry-point archive is linked whole, whatever its place on the command line', () {
      // The hook's flags reach clang before the wrapper's object files, so a
      // plain archive there is scanned while nothing needs it yet and adds no
      // member: the shared library links and dlopen fails on NVSDK_NGX_*.
      final ngx = linux.indexOf(r"'$dlssSdk/lib/Linux_x86_64/libnvsdk_ngx.a'");
      expect(ngx, isNonNegative);
      expect(ngx, greaterThan(linux.indexOf("'-Wl,--whole-archive'")));
      expect(ngx, lessThan(linux.indexOf("'-Wl,--no-whole-archive'")));
    });

    test('libm is a declared dependency', () {
      // The wrapper and Filament call the math library; without -lm the symbols
      // resolve only because the host process happened to load libm first.
      expect(linux, contains("'-lm'"));
    });

    test('the libstdc++ the NGX archive was built against is a declared dependency', () {
      expect(linux, contains("if (dlssSdk != null) '-lstdc++',"));
    });

    test('a built Linux library resolves every symbol from the libraries it needs', () async {
      if (!Platform.isLinux) {
        markTestSkipped('Linux only');
        return;
      }
      // `flutter build linux` of the example or of Lumina Studio.
      final lib = _newestLinuxLibrary(['example/build/linux', '../lumina_ui/build/linux']);
      if (lib == null) {
        markTestSkipped('no Linux build of libflutter_filament.so');
        return;
      }
      // ldd -r loads only the library's own NEEDED entries: a symbol that
      // resolved only through whatever the host process loaded shows up here.
      final result = await Process.run('ldd', ['-r', lib.path]);
      final undefined = [
        for (final m in RegExp(r'undefined symbol: (\S+)').allMatches('${result.stdout}${result.stderr}')) m.group(1)!,
      ];
      expect(undefined, isEmpty, reason: '${lib.path} leaves symbols unresolved');
    });
  });
}
