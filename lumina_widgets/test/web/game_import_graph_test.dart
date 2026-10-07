import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A game imports `package:lumina_widgets/lumina_game.dart`; nothing it
/// reaches in this package or the engine may need `dart:ffi` directly (only
/// through `package:flutter_filament/ffi.dart`), Assimp, RigLogic,
/// `package:ffi`, the editor data layer, the analyzer or the full
/// `lumina.dart` barrel — each of those breaks `flutter build web`. (The
/// engine's own `lumina_runtime.dart` is guarded by lumina's
/// `test/web/runtime_import_graph_test.dart`.)
final _directive = RegExp(r"^(?:import|export)\s+'([^'$]+)'(?:\s+if\s*\([^)]*\)\s*'([^']+)')?", multiLine: true);

/// Package URIs of the two walked packages → files; others are kept as URIs.
String _resolve(String from, String uri) {
  for (final (package, dir) in [('lumina_widgets', 'lib'), ('lumina', p.join('..', 'lumina', 'lib'))]) {
    final prefix = 'package:$package/';
    if (uri.startsWith(prefix)) return p.normalize(p.join(dir, uri.substring(prefix.length)));
  }
  if (uri.contains(':')) return uri;
  return p.normalize(p.join(p.dirname(from), uri));
}

bool _forbidden(String node) {
  final uri = node.replaceAll(r'\', '/');
  return uri == 'dart:ffi' ||
      uri.startsWith('package:flutter_assimp/') ||
      uri.startsWith('package:flutter_riglogic/') ||
      uri.startsWith('package:ffi/') ||
      uri.startsWith('package:lumina_editor_data/') ||
      uri.startsWith('package:analyzer/') ||
      uri.startsWith('package:flutter_filament/src/third_party/') ||
      uri.contains('/data/repositories/') ||
      uri.endsWith('lumina/lib/lumina.dart');
}

void main() {
  test('lumina_game.dart reaches no FFI package, no editor data and not lumina.dart', () {
    const root = 'lib/lumina_game.dart';
    final parent = <String, String?>{root: null};
    final stack = [root];
    while (stack.isNotEmpty) {
      final file = stack.removeLast();
      if (file.startsWith('package:') || file.startsWith('dart:') || !File(file).existsSync()) continue;
      for (final m in _directive.allMatches(File(file).readAsStringSync())) {
        for (final written in [m.group(1), m.group(2)].whereType<String>()) {
          final dep = _resolve(file, written);
          if (!parent.containsKey(dep)) {
            parent[dep] = file;
            stack.add(dep);
          }
        }
      }
    }
    final offenders = [
      for (final bad in parent.keys.where(_forbidden)) [for (String? f = bad; f != null; f = parent[f]) f].join(' <- '),
    ];
    expect(parent.keys.where((k) => k.contains('${p.separator}lumina${p.separator}lib')).length, greaterThan(100),
        reason: 'the walk must cover the engine runtime');
    expect(parent.keys.where((k) => k.startsWith('lib${p.separator}src')), isNotEmpty, reason: 'and this package');
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
