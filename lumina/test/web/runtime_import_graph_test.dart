import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A game imports `package:lumina/lumina_runtime.dart`; nothing it
/// reaches may need `dart:ffi` directly (only through
/// `package:flutter_filament/ffi.dart`), Assimp, RigLogic, `package:ffi`, the
/// editor's repositories, the analyzer (the Blueprint function scanner) or the full
/// `lumina.dart` barrel — each of those breaks `flutter build web`.
final _directive = RegExp(r"^(?:import|export)\s+'([^'$]+)'", multiLine: true);

String? _resolve(String from, String uri) {
  if (uri.startsWith('package:lumina/')) return 'lib/${uri.substring('package:lumina/'.length)}';
  if (uri.startsWith('package:') || uri.startsWith('dart:')) return uri;
  return File(from).parent.uri.resolve(uri).toFilePath().replaceFirst('${Directory.current.path}/', '');
}

bool _forbidden(String uri) =>
    uri == 'dart:ffi' ||
    uri.startsWith('package:flutter_assimp/') ||
    uri.startsWith('package:flutter_riglogic/') ||
    uri.startsWith('package:ffi/') ||
    // The Blueprint function scanner is editor-only.
    uri.startsWith('package:analyzer/') ||
    uri.startsWith('package:flutter_filament/src/third_party/') ||
    uri.contains('/data/repositories/') ||
    uri == 'lib/lumina.dart';

void main() {
  test('lumina_runtime.dart reaches no FFI package, no editor repository and not lumina.dart', () {
    final parent = <String, String?>{'lib/lumina_runtime.dart': null};
    final stack = ['lib/lumina_runtime.dart'];
    while (stack.isNotEmpty) {
      final file = stack.removeLast();
      if (file.startsWith('package:') || file.startsWith('dart:') || !File(file).existsSync()) continue;
      for (final m in _directive.allMatches(File(file).readAsStringSync())) {
        final dep = _resolve(file, m.group(1)!);
        if (dep != null && !parent.containsKey(dep)) {
          parent[dep] = file;
          stack.add(dep);
        }
      }
    }
    final offenders = [
      for (final bad in parent.keys.where(_forbidden))
        [for (String? f = bad; f != null; f = parent[f]) f].join(' <- '),
    ];
    expect(parent.length, greaterThan(100), reason: 'the walk must cover the runtime');
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
